module Backtesting
  ScenarioResult = Struct.new(:name, :passed, :details, keyword_init: true)

  class ScenarioRunner
    def initialize(order_processor: PaperTrading::OrderProcessor.new)
      @order_processor = order_processor
    end

    def stale_data(account:, attributes:, now: Time.current)
      order = @order_processor.submit(account: account, attributes: attributes, now: now)
      ScenarioResult.new(name: "stale_data", passed: order.status == "rejected" && order.decision_reasons.include?("stale_market_data"), details: order.decision_reasons)
    end

    def duplicate_order(account:, attributes:)
      first = @order_processor.submit(account: account, attributes: attributes)
      second = @order_processor.submit(account: account, attributes: attributes)
      ScenarioResult.new(name: "duplicate_order", passed: first.id == second.id && account.paper_orders.where(client_order_id: attributes[:client_order_id]).count == 1, details: { order_id: first.id })
    end

    def partial_fill(order:, events:)
      events.each { |event| @order_processor.fill(order: order, event: event) }
      order.reload
      ScenarioResult.new(name: "partial_fill", passed: order.filled_quantity.positive? && order.filled_quantity < order.quantity && order.status == "partially_filled", details: { filled: order.filled_quantity.to_s, requested: order.quantity.to_s })
    end
  end
end
