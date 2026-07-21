class UsersController < ApplicationController

  def my_portfolio
    @user_stocks = current_user.stocks
    @user = current_user
  end

  def my_friends
    @friendships = current_user.friends
  end

  def search
    @users = User.search(params[:search_param])
    if @users
      @users = current_user.except_current_user(@users)
      render partial: 'friends/lookup'
    else
     render status: :not_found, nothing: true
    end
  end

  def add_friend
    @friend = User.find(params[:friend])
    friendship = current_user.friendships.build(friend_id: @friend.id)
    if friendship.save
      redirect_to my_friends_path, notice: "Friend was successfully added."
    else
     redirect_to my_friends_path, flash[:error] = "There was an error with adding user as friend."
    end
  end

  def show
    @user = User.find(params[:id])
    return head :forbidden unless @user == current_user || !current_user.not_friends_with?(@user.id)
    @user_stocks = @user.stocks
  end
end
