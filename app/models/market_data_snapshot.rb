class MarketDataSnapshot < ActiveRecord::Base
  has_many :paper_orders, dependent: :restrict_with_error

  validates :source, :source_event_id, :license_id, :symbol, :source_timestamp, :ingested_at, :payload_digest, presence: true
  validates :bid, :ask, :last, :daily_volume, numericality: { greater_than: 0 }
  validates :source_event_id, uniqueness: { scope: :source }
  validate :ask_not_below_bid

  before_validation { self.symbol = symbol.to_s.strip.upcase }

  def stale?(seconds:, now: Time.current)
    source_timestamp < now - seconds.seconds
  end

  def spread_bps
    return BigDecimal("0") if last.to_d.zero?
    ((ask.to_d - bid.to_d) / last.to_d) * 10_000
  end

  private

  def ask_not_below_bid
    errors.add(:ask, "must be at least bid") if bid && ask && ask < bid
  end
end
