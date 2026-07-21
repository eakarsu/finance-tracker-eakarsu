require "test_helper"

class BacktestingScenarioTest < ActiveSupport::TestCase
  test "stale and duplicate-order scenarios have measurable pass criteria" do
    account = create_account
    stale = create_snapshot(source_timestamp: 10.minutes.ago.iso8601)
    fresh = create_snapshot(symbol: "MSFT", event_id: SecureRandom.uuid)
    runner = Backtesting::ScenarioRunner.new
    assert runner.stale_data(account: account, attributes: order_attributes(snapshot: stale)).passed
    assert runner.duplicate_order(account: account, attributes: order_attributes(snapshot: fresh)).passed
  end

  test "partial-fill scenario remains open with residual quantity" do
    account = create_account
    snapshot = create_snapshot
    processor = PaperTrading::OrderProcessor.new
    order = processor.submit(account: account, attributes: order_attributes(snapshot: snapshot))
    result = Backtesting::ScenarioRunner.new(order_processor: processor).partial_fill(order: order, events: [
      { source: "paper-broker", fill_id: SecureRandom.uuid, quantity: "3", price: "100", occurred_at: Time.current.iso8601 }
    ])
    assert result.passed
  end
end
