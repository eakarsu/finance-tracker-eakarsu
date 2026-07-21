module Risk
  class Exposure
    def initialize(account)
      @account = account
    end

    def gross
      symbols.sum do |symbol|
        quantity = @account.quantity_for(symbol).abs
        snapshot = MarketDataSnapshot.where(symbol: symbol).order(source_timestamp: :desc).first
        snapshot ? quantity * snapshot.last.to_d : BigDecimal("0")
      end
    end

    def symbols
      (@account.paper_orders.where(status: %w[partially_filled filled]).distinct.pluck(:symbol) +
        @account.position_adjustments.distinct.pluck(:symbol)).uniq
    end
  end
end
