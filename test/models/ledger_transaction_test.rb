require "test_helper"

class LedgerTransactionTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @cash = @account.ledger_accounts.find_by!(code: "CASH")
    @equity = @account.ledger_accounts.find_by!(code: "EQUITY")
    @poster = Ledger::Poster.new
  end

  test "unbalanced postings are rejected before persistence" do
    assert_raises(Ledger::UnbalancedTransaction) do
      @poster.post(account: @account, external_id: "bad", event_type: "bad", effective_at: Time.current, source: "test", entries: [
        { account: @cash, amount: 10, memo: "one side" }, { account: @equity, amount: -9, memo: "wrong side" }
      ])
    end
  end

  test "database prevents ledger update and deletion" do
    transaction = @account.ledger_transactions.first
    assert_raises(ActiveRecord::StatementInvalid) { LedgerTransaction.where(id: transaction.id).update_all(source: "tampered") }
    assert_raises(ActiveRecord::StatementInvalid) { LedgerTransaction.where(id: transaction.id).delete_all }
  end

  test "correction is an explicit balanced reversal" do
    original = @account.ledger_transactions.first
    reversal = @poster.reverse(transaction: original, external_id: "correction-#{SecureRandom.uuid}", reason: "opening balance source correction")
    assert_equal original.id, reversal.reversal_of_id
    assert_equal BigDecimal("0"), reversal.ledger_entries.sum(:amount)
    assert_equal original.ledger_entries.sum(:amount), reversal.ledger_entries.sum(:amount)
  end

  test "audit chain verifies and CSV contains custody boundaries" do
    exporter = Ledger::AuditExporter.new(@account)
    assert exporter.chain_valid?
    csv = exporter.to_csv
    assert_includes csv, "custody_boundary"
    assert_includes csv, "simulated"
  end
end
