require "test_helper"

class UserStockTest < ActiveSupport::TestCase
  test "a user cannot add the same stock twice" do
    user = create_user
    stock = Stock.create!(ticker: "MSFT", name: "Microsoft", last_price: 500)
    user.user_stocks.create!(stock: stock)
    assert_not user.user_stocks.new(stock: stock).valid?
  end
end
