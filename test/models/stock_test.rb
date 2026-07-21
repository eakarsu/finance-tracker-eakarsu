require "test_helper"

class StockTest < ActiveSupport::TestCase
  test "ticker is normalized and unique" do
    Stock.create!(ticker: " aapl ", name: "Apple", last_price: 100)
    duplicate = Stock.new(ticker: "AAPL", name: "Duplicate", last_price: 100)
    assert_equal "AAPL", Stock.first.ticker
    assert_not duplicate.valid?
  end

  test "price uses persisted sourced data instead of making an implicit network call" do
    snapshot = create_snapshot
    stock = Stock.create!(ticker: snapshot.symbol, name: "Apple", last_price: 1)
    assert_equal snapshot.last, stock.price
  end
end
