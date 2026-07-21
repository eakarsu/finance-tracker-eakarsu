class Friendship < ActiveRecord::Base

  belongs_to :user
  belongs_to :friend, :class_name => 'User'

  validates :friend_id, uniqueness: { scope: :user_id }
  validate :cannot_friend_self

  private

  def cannot_friend_self
    errors.add(:friend_id, "cannot be the current user") if friend_id == user_id
  end

end
