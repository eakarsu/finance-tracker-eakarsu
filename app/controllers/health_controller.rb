class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render json: { status: "ok", time: Time.current.iso8601 }
  rescue ActiveRecord::ActiveRecordError
    render json: { status: "unavailable" }, status: :service_unavailable
  end
end
