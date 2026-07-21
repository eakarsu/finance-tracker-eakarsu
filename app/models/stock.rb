class Stock < ActiveRecord::Base

  has_many :user_stocks
  has_many :users, through: :user_stocks

  validates :ticker, :name, presence: true
  validates :ticker, uniqueness: true
  before_validation { self.ticker = ticker.to_s.strip.upcase }

  def self.find_by_ticker(ticker_symbol)
    where(ticker: ticker_symbol.to_s.strip.upcase).first
  end

  def self.new_from_lookup(ticker_symbol)
    snapshot = MarketData::Ingestor.new.ingest_symbol(ticker_symbol)
    new(ticker: snapshot.symbol, name: snapshot.raw_payload["name"] || snapshot.symbol, last_price: snapshot.last)
  rescue MarketData::ProviderError
    nil
  end

  def price
    snapshot = MarketDataSnapshot.where(symbol: ticker.to_s.upcase).order(source_timestamp: :desc).first
    snapshot ? snapshot.last.to_d : nil
  end

end
