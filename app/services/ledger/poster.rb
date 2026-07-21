module Ledger
  class UnbalancedTransaction < StandardError; end
  class IdempotencyConflict < StandardError; end

  class Poster
    def post(account:, external_id:, event_type:, effective_at:, source:, entries:, metadata: {}, reversal_of: nil, correction_reason: nil)
      raise UnbalancedTransaction, "at least two entries are required" if entries.length < 2
      total = entries.sum { |entry| entry.fetch(:amount).to_d }
      raise UnbalancedTransaction, "entries must sum to zero" unless total.zero?

      LedgerTransaction.transaction do
        existing = account.ledger_transactions.find_by(external_id: external_id)
        if existing
          expected = CanonicalJson.digest(metadata.deep_stringify_keys)
          actual = existing.metadata["payload_digest"]
          raise IdempotencyConflict, "ledger external id was reused" unless actual == expected
          return existing
        end

        previous_hash = LedgerTransaction.lock.order(id: :desc).pick(:event_hash)
        metadata_with_digest = metadata.deep_stringify_keys.merge("payload_digest" => CanonicalJson.digest(metadata.deep_stringify_keys))
        event_payload = {
          account_id: account.id, external_id: external_id, event_type: event_type,
          effective_at: effective_at.utc.iso8601(6), source: source, previous_hash: previous_hash,
          reversal_of_id: reversal_of&.id, correction_reason: correction_reason,
          metadata: metadata_with_digest,
          entries: entries.map { |entry| { account_code: entry.fetch(:account).code, amount: entry.fetch(:amount).to_d.to_s("F"), memo: entry.fetch(:memo) } }
        }
        transaction = account.ledger_transactions.create!(
          external_id: external_id, event_type: event_type, effective_at: effective_at, source: source,
          reversal_of: reversal_of, correction_reason: correction_reason, previous_hash: previous_hash,
          event_hash: CanonicalJson.digest(event_payload), metadata: metadata_with_digest
        )
        entries.each do |entry|
          transaction.ledger_entries.create!(ledger_account: entry.fetch(:account), amount: entry.fetch(:amount), memo: entry.fetch(:memo))
        end
        transaction
      end
    end

    def reverse(transaction:, external_id:, reason:, effective_at: Time.current)
      raise ArgumentError, "correction reason is required" if reason.blank?
      post(
        account: transaction.paper_account, external_id: external_id, event_type: "correction_reversal",
        effective_at: effective_at, source: "internal-correction", reversal_of: transaction,
        correction_reason: reason, metadata: { reversed_external_id: transaction.external_id },
        entries: transaction.ledger_entries.includes(:ledger_account).map do |entry|
          { account: entry.ledger_account, amount: -entry.amount, memo: "Reversal: #{reason}" }
        end
      )
    end
  end
end
