class Api::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :demo_credentials]
  skip_before_action :verify_authenticity_token, only: [:login, :demo_credentials]

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

  def demo_credentials
    enabled = ENV.fetch("ENABLE_DEMO_CREDENTIAL_AUTOFILL", "true") == "true"
    return render json: { error: "Not found" }, status: :not_found unless Rails.env.development? && enabled

    email = ENV["DEMO_EMAIL"].presence || ENV["PROVISION_ADMIN_EMAIL"].presence || ENV["ADMIN_EMAIL"].presence
    password = ENV["DEMO_PASSWORD"].presence || ENV["PROVISION_ADMIN_PASSWORD"].presence || ENV["ADMIN_PASSWORD"].presence
    return render json: { error: "Demo credentials unavailable" }, status: :service_unavailable if email.blank? || password.blank?

    response.set_header("Cache-Control", "no-store")
    render json: { email: email, password: password }
  end

  private

  def session_user(user)
    { id: user.id, email: user.email, role: user.risk_role }
  end
end
