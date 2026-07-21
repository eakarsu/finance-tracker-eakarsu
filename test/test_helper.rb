ENV["RAILS_ENV"] ||= "test"
ENV["SECRET_KEY_BASE"] ||= "test-secret-key-base-that-is-at-least-sixty-four-characters-long-for-ci"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: 1)

  def create_user(role: "member", email: nil)
    User.create!(
      email: email || "user-#{SecureRandom.uuid}@example.test",
      password: "correct-horse-battery-staple",
      first_name: "Test", last_name: "User", risk_role: role
    )
  end

  def create_account(user: create_user)
    user.create_paper_account!(name: "Test Paper Account")
  end

  def market_payload(overrides = {})
    {
      source: "licensed-test-feed", event_id: SecureRandom.uuid, license_id: "test-license",
      licensed: true, symbol: "AAPL", bid: "99.90", ask: "100.10", last: "100.00",
      daily_volume: "1000000", source_timestamp: Time.current.iso8601, name: "Apple Inc."
    }.merge(overrides).stringify_keys
  end

  def create_snapshot(overrides = {})
    MarketData::Ingestor.new.ingest(market_payload(overrides))
  end

  def order_attributes(snapshot:, overrides: {})
    {
      client_order_id: SecureRandom.uuid, market_data_snapshot_id: snapshot.id,
      symbol: snapshot.symbol, side: "buy", order_type: "limit", quantity: "10", limit_price: "100.10"
    }.merge(overrides)
  end
end

class ActionController::TestCase
  include Devise::Test::ControllerHelpers
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
