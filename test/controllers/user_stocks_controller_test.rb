require "test_helper"

class UserStocksControllerTest < ActionController::TestCase
  tests UserStocksController

  setup do
    @user = create_user
    @other = create_user
    @stock = Stock.create!(ticker: "MSFT", name: "Microsoft", last_price: 500)
    @other_holding = @other.user_stocks.create!(stock: @stock)
    sign_in @user
  end

  test "index never exposes another user's holdings" do
    get :index
    assert_response :success
    assert_not_includes response.body, "<td>#{@other.id}</td>"
  end

  test "destroy is scoped to the authenticated user" do
    assert_no_difference("UserStock.count") do
      assert_raises(ActiveRecord::RecordNotFound) { delete :destroy, params: { id: @other_holding.id } }
    end
  end
end
