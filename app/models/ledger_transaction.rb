class LedgerTransaction < ActiveRecord::Base
  belongs_to :paper_account
  belongs_to :reversal_of, class_name: "LedgerTransaction", optional: true
  has_many :ledger_entries, dependent: :restrict_with_error

  validates :external_id, :event_type, :effective_at, :source, :event_hash, presence: true
  validates :external_id, uniqueness: { scope: :paper_account_id }
  validates :event_hash, uniqueness: true

  def readonly?
    persisted?
  end
end
