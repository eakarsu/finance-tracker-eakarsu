require "test_helper"

class PaperOrderTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @snapshot = create_snapshot
    @processor = PaperTrading::OrderProcessor.new
  end

  test "duplicate client order returns one order" do
    attributes = order_attributes(snapshot: @snapshot)
    first = @processor.submit(account: @account, attributes: attributes)
    second = @processor.submit(account: @account, attributes: attributes)
    assert_equal first.id, second.id
    assert_equal 1, @account.paper_orders.where(client_order_id: attributes[:client_order_id]).count
  end

  test "changed order with reused client id is rejected" do
    attributes = order_attributes(snapshot: @snapshot)
    @processor.submit(account: @account, attributes: attributes)
    assert_raises(PaperTrading::IdempotencyConflict) do
      @processor.submit(account: @account, attributes: attributes.merge(quantity: 11))
    end
  end

  test "partial fill updates weighted state and balanced ledger" do
    order = approved_order(quantity: 10)
    fill = @processor.fill(order: order, event: fill_event(quantity: 4, price: "100.00"))
    assert_equal "partially_filled", order.reload.status
    assert_equal BigDecimal("4"), order.filled_quantity
    transaction = LedgerTransaction.find_by!(external_id: "fill:#{fill.source}:#{fill.provider_fill_id}")
    assert_equal BigDecimal("0"), transaction.ledger_entries.sum(:amount)
  end

  test "duplicate fill callback is idempotent" do
    order = approved_order
    event = fill_event(quantity: 2)
    first = @processor.fill(order: order, event: event)
    second = @processor.fill(order: order.reload, event: event)
    assert_equal first.id, second.id
    assert_equal 1, PaperFill.where(provider_fill_id: event[:fill_id]).count
  end

  test "fill beyond remaining quantity is rejected" do
    order = approved_order(quantity: 5)
    assert_raises(PaperTrading::InvalidTransition) { @processor.fill(order: order, event: fill_event(quantity: 6)) }
  end

  test "limit-price violation is rejected" do
    order = approved_order(quantity: 5)
    assert_raises(PaperTrading::InvalidTransition) { @processor.fill(order: order, event: fill_event(quantity: 2, price: "101")) }
  end

  test "approval re-evaluates stale data before releasing order" do
    order = @processor.submit(account: @account, attributes: order_attributes(snapshot: @snapshot, overrides: { quantity: 60 }))
    @snapshot.update_column(:source_timestamp, 5.minutes.ago)
    @processor.approve(order: order, actor: create_user(role: "approver"))
    assert_equal "rejected", order.reload.status
    assert_includes order.decision_reasons, "stale_market_data"
  end

  test "approved order remains idempotent after decision evidence changes" do
    attributes = order_attributes(snapshot: @snapshot, overrides: { quantity: 60 })
    order = @processor.submit(account: @account, attributes: attributes)
    @processor.approve(order: order, actor: create_user(role: "approver"))
    assert_equal order.id, @processor.submit(account: @account, attributes: attributes).id
  end

  private

  def approved_order(quantity: 10)
    @processor.submit(account: @account, attributes: order_attributes(snapshot: @snapshot, overrides: { quantity: quantity }))
  end

  def fill_event(quantity:, price: "100.00")
    { source: "paper-broker", fill_id: SecureRandom.uuid, quantity: quantity.to_s, price: price, occurred_at: Time.current.iso8601 }
  end
end
