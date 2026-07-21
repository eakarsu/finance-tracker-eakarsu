require "test_helper"

class RiskPolicyTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @snapshot = create_snapshot
  end

  test "kill switch rejects every new order" do
    @account.risk_policy.update!(kill_switch: true)
    assert_rejected("kill_switch_active")
  end

  test "stale data is rejected" do
    @snapshot.update_column(:source_timestamp, 5.minutes.ago)
    assert_rejected("stale_market_data")
  end

  test "thin liquidity is rejected" do
    @snapshot.update_column(:daily_volume, 1)
    assert_rejected("insufficient_liquidity")
  end

  test "wide spread is rejected" do
    @snapshot.update_columns(bid: 90, ask: 110)
    assert_rejected("spread_limit_exceeded")
  end

  test "order notional limit is deterministic" do
    assert_rejected("order_notional_limit_exceeded", quantity: 200)
  end

  test "projected gross exposure includes existing paper positions" do
    processor = PaperTrading::OrderProcessor.new
    order = processor.submit(account: @account, attributes: order_attributes(snapshot: @snapshot))
    processor.fill(order: order, event: { source: "paper-broker", fill_id: SecureRandom.uuid, quantity: "10", price: "100", occurred_at: Time.current.iso8601 })
    @account.risk_policy.update!(max_gross_exposure: 1_500)
    assert_rejected("gross_exposure_limit_exceeded")
  end

  test "daily realized loss blocks new risk" do
    pnl = @account.ledger_accounts.find_by!(code: "REALIZED_PNL")
    cash = @account.ledger_accounts.find_by!(code: "CASH")
    Ledger::Poster.new.post(account: @account, external_id: SecureRandom.uuid, event_type: "realized_loss", effective_at: Time.current,
      source: "paper-broker", entries: [
        { account: pnl, amount: 3_000, memo: "Realized loss" },
        { account: cash, amount: -3_000, memo: "Cash loss" }
      ])
    assert_rejected("daily_loss_limit_exceeded")
  end

  test "paper buys cannot exceed simulated cash" do
    @account.risk_policy.update!(max_order_notional: 1_000_000, max_gross_exposure: 1_000_000, approval_notional: 900_000)
    assert_rejected("insufficient_simulated_cash", quantity: 1_100)
  end

  test "approval threshold creates pending approval without bypassing limits" do
    decision = evaluate(quantity: 60)
    assert_equal "pending_approval", decision.status
    assert_includes decision.reasons, "independent_approval_required"
  end

  test "authorized approver passes an otherwise valid approval threshold" do
    decision = evaluate(quantity: 60, approver: create_user(role: "approver"))
    assert_equal "approved", decision.status
  end

  test "only operators can change the kill switch" do
    assert_raises(ArgumentError) { @account.risk_policy.activate_kill_switch!(actor: create_user, reason: "test") }
    @account.risk_policy.activate_kill_switch!(actor: create_user(role: "operator"), reason: "feed integrity incident")
    assert @account.risk_policy.kill_switch?
  end

  private

  def evaluate(quantity: 10, approver: nil)
    Risk::Evaluator.new(account: @account, snapshot: @snapshot, symbol: "AAPL", side: "buy", quantity: quantity,
      order_type: "limit", limit_price: @snapshot.ask, approver: approver).call
  end

  def assert_rejected(reason, quantity: 10)
    decision = evaluate(quantity: quantity)
    assert_equal "rejected", decision.status
    assert_includes decision.reasons, reason
  end
end
