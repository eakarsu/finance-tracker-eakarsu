class Api::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: :login
  skip_before_action :verify_authenticity_token, only: :login

  def login
    user = User.find_by(email: params[:email].to_s.downcase.strip)
    if user&.valid_password?(params[:password].to_s)
      sign_in(user)
      render json: { success: true, user: session_user(user) }
    else
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end

  def me
    render json: { user: session_user(current_user) }
  end

  private

  def session_user(user)
    { id: user.id, email: user.email, role: user.risk_role }
  end
end
