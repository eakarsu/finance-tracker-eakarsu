require "test_helper"

class MarketDataSnapshotTest < ActiveSupport::TestCase
  test "ingestion is idempotent for an identical provider event" do
    payload = market_payload
    first = MarketData::Ingestor.new.ingest(payload)
    second = MarketData::Ingestor.new.ingest(payload)
    assert_equal first.id, second.id
    assert_equal 1, MarketDataSnapshot.where(source: payload["source"], source_event_id: payload["event_id"]).count
  end

  test "provider event id collision with altered data is rejected" do
    payload = market_payload
    MarketData::Ingestor.new.ingest(payload)
    assert_raises(MarketData::IdempotencyConflict) { MarketData::Ingestor.new.ingest(payload.merge("last" => "101")) }
  end

  test "source timestamps drive stale data evaluation" do
    snapshot = create_snapshot(source_timestamp: 5.minutes.ago.iso8601)
    assert snapshot.stale?(seconds: 60)
  end

  test "licensed client fails closed without configuration" do
    old_url, old_token = ENV.delete("MARKET_DATA_API_URL"), ENV.delete("MARKET_DATA_API_TOKEN")
    assert_raises(MarketData::ProviderError) { MarketData::LicensedClient.new }
  ensure
    ENV["MARKET_DATA_API_URL"], ENV["MARKET_DATA_API_TOKEN"] = old_url, old_token
  end
end
