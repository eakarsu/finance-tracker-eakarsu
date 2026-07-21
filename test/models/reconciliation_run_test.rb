require "test_helper"

class ReconciliationRunTest < ActiveSupport::TestCase
  test "matching source balances reconcile" do
    account = create_account
    run = Reconciliation::Runner.new.run(account: account, source: "read-only-custodian", source_run_id: SecureRandom.uuid, as_of: Time.current,
      source_cash: account.cash_balance, source_gross_exposure: 0)
    assert_equal "matched", run.status
    assert_empty run.breaks
  end

  test "cash and exposure differences become explicit breaks" do
    account = create_account
    run = Reconciliation::Runner.new.run(account: account, source: "read-only-custodian", source_run_id: SecureRandom.uuid, as_of: Time.current,
      source_cash: 1, source_gross_exposure: 2)
    assert_equal "break", run.status
    assert_equal %w[cash gross_exposure], run.breaks.map { |item| item["field"] || item[:field] }
  end

  test "source reconciliation run is idempotent and collisions fail" do
    account = create_account
    run_id = SecureRandom.uuid
    attributes = { account: account, source: "read-only-custodian", source_run_id: run_id, as_of: Time.current,
      source_cash: account.cash_balance, source_gross_exposure: 0 }
    first = Reconciliation::Runner.new.run(**attributes)
    second = Reconciliation::Runner.new.run(**attributes)
    assert_equal first.id, second.id
    assert_raises(Reconciliation::IdempotencyConflict) { Reconciliation::Runner.new.run(**attributes.merge(source_cash: 1)) }
  end
end
