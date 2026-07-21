require "test_helper"

class CorporateActionTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    snapshot = create_snapshot
    processor = PaperTrading::OrderProcessor.new
    order = processor.submit(account: @account, attributes: order_attributes(snapshot: snapshot))
    processor.fill(order: order, event: { source: "paper-broker", fill_id: SecureRandom.uuid, quantity: "10", price: "100", occurred_at: Time.current.iso8601 })
    @processor = CorporateActions::Processor.new
  end

  test "split changes quantity exactly once" do
    action = @processor.ingest(source: "licensed-actions", event_id: "split-1", license_id: "actions-license", symbol: "AAPL", action_type: "split", effective_on: Date.current, ratio: "2", licensed: true)
    @processor.apply(action: action, accounts: PaperAccount.where(id: @account.id))
    @processor.apply(action: action, accounts: PaperAccount.where(id: @account.id))
    assert_equal BigDecimal("20"), @account.quantity_for("AAPL")
    assert_equal 1, PositionAdjustment.where(paper_account: @account, corporate_action: action).count
  end

  test "dividend posts balanced cash and income entries" do
    action = @processor.ingest(source: "licensed-actions", event_id: "dividend-1", license_id: "actions-license", symbol: "AAPL", action_type: "dividend", effective_on: Date.current, cash_amount: "1.50", licensed: true)
    before = @account.cash_balance
    @processor.apply(action: action, accounts: PaperAccount.where(id: @account.id))
    assert_equal before + BigDecimal("15"), @account.cash_balance
    transaction = @account.ledger_transactions.find_by!(external_id: "corporate-action:licensed-actions:dividend-1")
    assert_equal BigDecimal("0"), transaction.ledger_entries.sum(:amount)
  end

  test "altered duplicate corporate action is rejected" do
    payload = { source: "licensed-actions", event_id: "event-1", license_id: "actions-license", licensed: true, symbol: "AAPL", action_type: "split", effective_on: Date.current, ratio: "2" }
    @processor.ingest(payload)
    assert_raises(CorporateActions::IdempotencyConflict) { @processor.ingest(payload.merge(ratio: "3")) }
  end
end
