class ReconciliationRun < ActiveRecord::Base
  belongs_to :paper_account

  validates :source, :source_run_id, :payload_digest, :as_of, :status, presence: true
  validates :source_run_id, uniqueness: { scope: :source }
  validates :status, inclusion: { in: %w[matched break] }
  validates :ledger_cash, :source_cash, :ledger_gross_exposure, :source_gross_exposure, numericality: true
end
