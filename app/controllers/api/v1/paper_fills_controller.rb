class Api::V1::PaperFillsController < ApplicationController
  before_action :authorize_operator!

  def create
    order = PaperOrder.find(params.require(:paper_order_id))
    fill = PaperTrading::OrderProcessor.new.fill(order: order, event: params.require(:fill).to_unsafe_h)
    render json: fill.slice(:id, :paper_order_id, :source, :provider_fill_id, :quantity, :price, :occurred_at, :payload_digest), status: :created
  rescue PaperTrading::InvalidTransition, PaperTrading::IdempotencyConflict, ActiveRecord::RecordInvalid => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  private

  def authorize_operator!
    render json: { error: "operator role required" }, status: :forbidden unless current_user.operator?
  end
end
