class UserStock < ActiveRecord::Base
  belongs_to :user
  belongs_to :stock

  validates :stock_id, uniqueness: { scope: :user_id }
end
