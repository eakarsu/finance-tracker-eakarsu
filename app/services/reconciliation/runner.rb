module Reconciliation
  class IdempotencyConflict < StandardError; end

  class Runner
    def run(account:, source:, source_run_id:, as_of:, source_cash:, source_gross_exposure:, tolerance: BigDecimal("0.01"))
      payload = { account_id: account.id, source: source, source_run_id: source_run_id, as_of: as_of.iso8601,
        source_cash: source_cash.to_d.to_s("F"), source_gross_exposure: source_gross_exposure.to_d.to_s("F") }
      digest = CanonicalJson.digest(payload)
      existing = ReconciliationRun.find_by(source: source, source_run_id: source_run_id)
      if existing
        raise IdempotencyConflict, "reconciliation run id was reused" unless existing.payload_digest == digest
        return existing
      end
      ledger_cash = account.cash_balance
      ledger_gross = Risk::Exposure.new(account).gross
      breaks = []
      cash_difference = ledger_cash - source_cash.to_d
      exposure_difference = ledger_gross - source_gross_exposure.to_d
      breaks << { field: "cash", difference: cash_difference.to_s("F") } if cash_difference.abs > tolerance
      breaks << { field: "gross_exposure", difference: exposure_difference.to_s("F") } if exposure_difference.abs > tolerance
      account.reconciliation_runs.create!(
        source: source, source_run_id: source_run_id, payload_digest: digest, as_of: as_of, status: breaks.empty? ? "matched" : "break",
        ledger_cash: ledger_cash, source_cash: source_cash, ledger_gross_exposure: ledger_gross,
        source_gross_exposure: source_gross_exposure, breaks: breaks
      )
    end
  end
end
