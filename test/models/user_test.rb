require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "risk roles reject unknown privilege values" do
    user = create_user
    user.risk_role = "administrator"
    assert_not user.valid?
    assert_includes user.errors[:risk_role], "is not included in the list"
  end

  test "paper account creates isolated control accounts and opening capital" do
    account = create_account
    assert_equal %w[CASH EQUITY FEES REALIZED_PNL SECURITIES], account.ledger_accounts.order(:code).pluck(:code)
    assert_equal BigDecimal("100000"), account.cash_balance
    assert_equal "simulated", account.custody_boundary
    assert account.risk_policy.present?
  end
end
