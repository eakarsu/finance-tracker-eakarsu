class LedgerEntry < ActiveRecord::Base
  belongs_to :ledger_transaction
  belongs_to :ledger_account

  validates :amount, numericality: { other_than: 0 }
  validates :memo, presence: true
  validate :same_paper_account

  def readonly?
    persisted?
  end

  private

  def same_paper_account
    return unless ledger_transaction && ledger_account
    errors.add(:ledger_account, "must share the transaction account") if ledger_transaction.paper_account_id != ledger_account.paper_account_id
  end
end
