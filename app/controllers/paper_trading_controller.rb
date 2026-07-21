class PaperTradingController < ApplicationController
  before_action :set_account
  before_action :set_order, only: [:cancel, :approve]

  def show
    @policy = @account.risk_policy
    @orders = @account.paper_orders.includes(:market_data_snapshot, :paper_fills).order(created_at: :desc).limit(100)
    @snapshots = MarketDataSnapshot.order(source_timestamp: :desc).limit(50)
    @ledger_transactions = @account.ledger_transactions.includes(ledger_entries: :ledger_account).order(id: :desc).limit(20)
    @reconciliations = @account.reconciliation_runs.order(created_at: :desc).limit(10)
    @gross_exposure = Risk::Exposure.new(@account).gross
    @approval_queue = (current_user.approver? || current_user.operator?) ? PaperOrder.where(status: "pending_approval").includes(:paper_account).order(:created_at) : PaperOrder.none
  end

  def create
    snapshot = MarketDataSnapshot.find(params.require(:paper_order).fetch(:market_data_snapshot_id))
    attributes = order_params.to_h.merge(symbol: snapshot.symbol)
    order = PaperTrading::OrderProcessor.new.submit(account: @account, attributes: attributes, actor: current_user)
    redirect_to paper_trading_path, notice: "Order #{order.client_order_id} is #{order.status.tr('_', ' ')}."
  rescue ActiveRecord::RecordInvalid, KeyError, PaperTrading::IdempotencyConflict => error
    redirect_to paper_trading_path, alert: error.message
  end

  def approve
    PaperTrading::OrderProcessor.new.approve(order: @order, actor: current_user)
    redirect_to paper_trading_path, notice: "Order approved after deterministic limits were re-evaluated."
  rescue PaperTrading::InvalidTransition => error
    redirect_to paper_trading_path, alert: error.message
  end

  def cancel
    PaperTrading::OrderProcessor.new.cancel(order: @order)
    redirect_to paper_trading_path, notice: "Order cancelled."
  rescue PaperTrading::InvalidTransition => error
    redirect_to paper_trading_path, alert: error.message
  end

  def kill_switch
    return head :forbidden unless current_user.operator?
    policy = @account.risk_policy
    if ActiveModel::Type::Boolean.new.cast(params[:active])
      policy.activate_kill_switch!(actor: current_user, reason: params.require(:reason))
    else
      policy.release_kill_switch!(actor: current_user, reason: params.require(:reason))
    end
    redirect_to paper_trading_path, notice: "Kill switch updated."
  rescue ArgumentError, ActionController::ParameterMissing => error
    redirect_to paper_trading_path, alert: error.message
  end

  def audit_export
    exporter = Ledger::AuditExporter.new(@account)
    response.headers["X-Ledger-Chain-Valid"] = exporter.chain_valid?.to_s
    send_data exporter.to_csv, filename: "paper-ledger-#{@account.id}-#{Time.current.to_date}.csv", type: "text/csv"
  end

  private

  def set_account
    @account = current_user.paper_account || current_user.create_paper_account!(name: "#{current_user.full_name} Paper Account")
  end

  def set_order
    @order = if action_name == "approve" && (current_user.approver? || current_user.operator?)
      PaperOrder.find(params[:id])
    else
      @account.paper_orders.find(params[:id])
    end
  end

  def order_params
    params.require(:paper_order).permit(:client_order_id, :market_data_snapshot_id, :side, :order_type, :quantity, :limit_price)
  end

end
