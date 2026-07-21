module Risk
  Decision = Struct.new(:status, :reasons, :notional, keyword_init: true) do
    def approved? = status == "approved"
  end

  class Evaluator
    def initialize(account:, snapshot:, symbol:, side:, quantity:, order_type:, limit_price: nil, approver: nil, now: Time.current)
      @account = account
      @snapshot = snapshot
      @symbol = symbol.to_s.upcase
      @side = side.to_s
      @quantity = quantity.to_d
      @order_type = order_type.to_s
      @limit_price = limit_price&.to_d
      @approver = approver
      @now = now
    end

    def call
      policy = @account.risk_policy
      price = execution_reference_price
      notional = @quantity * price
      reasons = []
      reasons << "kill_switch_active" if policy.kill_switch?
      reasons << "account_not_active" unless @account.status == "active"
      reasons << "invalid_quantity" unless @quantity.positive?
      reasons << "symbol_snapshot_mismatch" unless @snapshot.symbol == @symbol
      reasons << "stale_market_data" if @snapshot.stale?(seconds: policy.stale_after_seconds, now: @now)
      reasons << "insufficient_liquidity" if @snapshot.daily_volume < policy.minimum_daily_volume
      reasons << "spread_limit_exceeded" if @snapshot.spread_bps > policy.max_spread_bps
      reasons << "order_notional_limit_exceeded" if notional > policy.max_order_notional
      reasons << "gross_exposure_limit_exceeded" if projected_gross(notional) > policy.max_gross_exposure
      reasons << "daily_loss_limit_exceeded" if daily_loss > policy.max_daily_loss
      reasons << "insufficient_simulated_cash" if @side == "buy" && notional > @account.cash_balance
      return Decision.new(status: "rejected", reasons: reasons, notional: notional) if reasons.any?

      if notional >= policy.approval_notional && !(@approver&.approver? || @approver&.operator?)
        return Decision.new(status: "pending_approval", reasons: ["independent_approval_required"], notional: notional)
      end
      Decision.new(status: "approved", reasons: [], notional: notional)
    end

    private

    def execution_reference_price
      return @limit_price if @order_type == "limit" && @limit_price&.positive?
      @side == "buy" ? @snapshot.ask.to_d : @snapshot.bid.to_d
    end

    def projected_gross(order_notional)
      Risk::Exposure.new(@account).gross + order_notional
    end

    def daily_loss
      pnl = @account.ledger_accounts.find_by(code: "REALIZED_PNL")
      return BigDecimal("0") unless pnl
      value = pnl.ledger_entries.joins(:ledger_transaction).where(ledger_transactions: { effective_at: @now.beginning_of_day..@now.end_of_day }).sum(:amount).to_d
      value.positive? ? value : BigDecimal("0")
    end
  end
end
