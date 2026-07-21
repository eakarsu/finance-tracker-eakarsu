class Api::V1::ReconciliationsController < ApplicationController
  before_action :authorize_operator!

  def create
    account = PaperAccount.find(params.require(:paper_account_id))
    run = Reconciliation::Runner.new.run(
      account: account, source: params.require(:source), source_run_id: params.require(:source_run_id), as_of: Time.iso8601(params.require(:as_of)),
      source_cash: params.require(:source_cash), source_gross_exposure: params.require(:source_gross_exposure)
    )
    render json: run, status: :created
  rescue ArgumentError, Reconciliation::IdempotencyConflict, ActiveRecord::RecordInvalid => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  private

  def authorize_operator!
    render json: { error: "operator role required" }, status: :forbidden unless current_user.operator?
  end
end
