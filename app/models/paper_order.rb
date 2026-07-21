class PaperOrder < ActiveRecord::Base
  belongs_to :paper_account
  belongs_to :market_data_snapshot
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :paper_fills, dependent: :restrict_with_error

  SIDES = %w[buy sell].freeze
  STATUSES = %w[pending pending_approval approved rejected partially_filled filled cancelled].freeze

  validates :client_order_id, :request_digest, :symbol, :side, :order_type, :status, presence: true
  validates :client_order_id, uniqueness: { scope: :paper_account_id }
  validates :side, inclusion: { in: SIDES }
  validates :order_type, inclusion: { in: %w[limit market] }
  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { greater_than: 0 }
  validates :limit_price, numericality: { greater_than: 0 }, allow_nil: true
  validate :limit_orders_have_price

  before_validation { self.symbol = symbol.to_s.strip.upcase }

  def remaining_quantity
    quantity.to_d - filled_quantity.to_d
  end

  def terminal?
    %w[filled rejected cancelled].include?(status)
  end

  private

  def limit_orders_have_price
    errors.add(:limit_price, "is required for limit orders") if order_type == "limit" && limit_price.blank?
  end
end
