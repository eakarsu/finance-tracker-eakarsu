require "csv"

module Ledger
  class AuditExporter
    def initialize(account)
      @account = account
    end

    def chain_valid?
      previous_hash = nil
      LedgerTransaction.order(:id).includes(ledger_entries: :ledger_account).all? do |transaction|
        entries = transaction.ledger_entries.order(:id).map { |entry| { account_code: entry.ledger_account.code, amount: entry.amount.to_d.to_s("F"), memo: entry.memo } }
        payload = {
          account_id: transaction.paper_account_id, external_id: transaction.external_id, event_type: transaction.event_type,
          effective_at: transaction.effective_at.utc.iso8601(6), source: transaction.source, previous_hash: previous_hash,
          reversal_of_id: transaction.reversal_of_id, correction_reason: transaction.correction_reason,
          metadata: transaction.metadata, entries: entries
        }
        valid = transaction.previous_hash == previous_hash && transaction.event_hash == CanonicalJson.digest(payload)
        previous_hash = transaction.event_hash
        valid
      end
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << %w[transaction_id external_id event_type effective_at source event_hash account_code custody_boundary amount currency memo]
        @account.ledger_transactions.order(:id).includes(ledger_entries: :ledger_account).find_each do |transaction|
          transaction.ledger_entries.each do |entry|
            csv << [transaction.id, transaction.external_id, transaction.event_type, transaction.effective_at.iso8601,
              transaction.source, transaction.event_hash, entry.ledger_account.code, entry.ledger_account.custody_boundary,
              entry.amount.to_d.to_s("F"), entry.ledger_account.currency, entry.memo]
          end
        end
      end
    end
  end
end
