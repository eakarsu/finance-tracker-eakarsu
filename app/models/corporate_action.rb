class CorporateAction < ActiveRecord::Base
  has_many :position_adjustments, dependent: :restrict_with_error

  validates :source, :external_id, :license_id, :symbol, :action_type, :effective_on, :payload_digest, presence: true
  validates :external_id, uniqueness: { scope: :source }
  validates :action_type, inclusion: { in: %w[split dividend symbol_change] }
  validates :ratio, numericality: { greater_than: 0 }, if: -> { action_type == "split" }

  before_validation { self.symbol = symbol.to_s.strip.upcase }
end
