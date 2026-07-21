class LedgerAccount < ActiveRecord::Base
  belongs_to :paper_account
  has_many :ledger_entries, dependent: :restrict_with_error

  validates :code, :name, :account_type, :currency, :custody_boundary, presence: true
  validates :code, uniqueness: { scope: :paper_account_id }
  validates :account_type, inclusion: { in: %w[asset liability equity income expense] }
end
