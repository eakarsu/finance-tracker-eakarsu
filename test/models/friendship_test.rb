require "test_helper"

class FriendshipTest < ActiveSupport::TestCase
  test "self friendship is rejected" do
    user = create_user
    assert_not user.friendships.new(friend: user).valid?
  end

  test "duplicate friendship is rejected" do
    user = create_user
    friend = create_user
    user.friendships.create!(friend: friend)
    assert_not user.friendships.new(friend: friend).valid?
  end
end
