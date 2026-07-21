class PositionAdjustment < ActiveRecord::Base
  belongs_to :paper_account
  belongs_to :corporate_action

  validates :symbol, :reason, presence: true
  validates :quantity_delta, numericality: true
  validates :corporate_action_id, uniqueness: { scope: :paper_account_id }
end
