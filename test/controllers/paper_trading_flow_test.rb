require "test_helper"

class PaperTradingFlowTest < ActionDispatch::IntegrationTest
  test "health endpoint does not require a session" do
    get "/health"
    assert_response :success
    assert_equal "ok", response.parsed_body["status"]
  end

  test "authenticated journey ingests licensed data, evaluates, approves, partially fills, and exports" do
    trader = create_user
    operator = create_user(role: "operator")
    approver = create_user(role: "approver")

    sign_in operator
    payload = market_payload
    post api_v1_market_data_path, params: { market_data: payload }, as: :json
    assert_response :created
    snapshot_id = response.parsed_body.fetch("id")
    sign_out operator

    sign_in trader
    get paper_trading_path
    assert_response :success
    assert_includes response.body, "No live orders"
    post paper_trading_path, params: { paper_order: {
      client_order_id: "flow-order-1", market_data_snapshot_id: snapshot_id,
      side: "buy", order_type: "limit", quantity: "60", limit_price: "100.10"
    } }
    assert_redirected_to paper_trading_path
    order = trader.paper_account.paper_orders.find_by!(client_order_id: "flow-order-1")
    assert_equal "pending_approval", order.status
    sign_out trader

    sign_in approver
    patch approve_paper_order_path(order)
    assert_redirected_to paper_trading_path
    assert_equal "approved", order.reload.status
    sign_out approver

    sign_in operator
    post api_v1_paper_fills_path, params: { paper_order_id: order.id, fill: {
      source: "paper-broker", fill_id: "flow-fill-1", quantity: "20", price: "100", occurred_at: Time.current.iso8601
    } }, as: :json
    assert_response :created
    assert_equal "partially_filled", order.reload.status
    sign_out operator

    sign_in trader
    get audit_export_paper_trading_path
    assert_response :success
    assert_equal "true", response.headers["X-Ledger-Chain-Valid"]
    assert_includes response.body, "flow-fill-1"
  end

  test "member cannot call operator ingestion endpoint" do
    sign_in create_user
    post api_v1_market_data_path, params: { market_data: market_payload }, as: :json
    assert_response :forbidden
    assert_equal "operator role required", response.parsed_body["error"]
  end
end
