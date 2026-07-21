class PaperFill < ActiveRecord::Base
  belongs_to :paper_order

  validates :source, :provider_fill_id, :occurred_at, :payload_digest, presence: true
  validates :provider_fill_id, uniqueness: { scope: :source }
  validates :quantity, :price, numericality: { greater_than: 0 }
end
