class Api::V1::MarketDataController < ApplicationController
  before_action :authorize_operator!

  def create
    snapshot = MarketData::Ingestor.new.ingest(params.require(:market_data).to_unsafe_h)
    render json: snapshot.slice(:id, :source, :source_event_id, :license_id, :symbol, :bid, :ask, :last, :daily_volume, :source_timestamp, :ingested_at, :payload_digest), status: :created
  rescue MarketData::ProviderError, MarketData::IdempotencyConflict, ActiveRecord::RecordInvalid => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  private

  def authorize_operator!
    render json: { error: "operator role required" }, status: :forbidden unless current_user.operator?
  end
end
