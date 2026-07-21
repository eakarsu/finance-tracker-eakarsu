class PaperAccount < ActiveRecord::Base
  scope :active, -> { where(status: "active") }

  belongs_to :user
  has_one :risk_policy, dependent: :destroy
  has_many :paper_orders, dependent: :restrict_with_error
  has_many :ledger_accounts, dependent: :restrict_with_error
  has_many :ledger_transactions, dependent: :restrict_with_error
  has_many :position_adjustments, dependent: :restrict_with_error
  has_many :reconciliation_runs, dependent: :restrict_with_error

  validates :name, :base_currency, presence: true
  validates :status, inclusion: { in: %w[active suspended closed] }
  validates :custody_boundary, inclusion: { in: %w[simulated external_read_only] }

  after_create :create_control_records

  def quantity_for(symbol)
    normalized = symbol.to_s.upcase
    buys = paper_orders.joins(:paper_fills).where(symbol: normalized, side: "buy").sum("paper_fills.quantity")
    sells = paper_orders.joins(:paper_fills).where(symbol: normalized, side: "sell").sum("paper_fills.quantity")
    buys.to_d - sells.to_d + position_adjustments.where(symbol: normalized).sum(:quantity_delta).to_d
  end

  def cash_balance
    account = ledger_accounts.find_by(code: "CASH")
    account ? account.ledger_entries.sum(:amount).to_d : BigDecimal("0")
  end

  private

  def create_control_records
    create_risk_policy!
    ledger_accounts.create!(code: "CASH", name: "Simulated client cash", account_type: "asset", currency: base_currency, custody_boundary: custody_boundary)
    ledger_accounts.create!(code: "SECURITIES", name: "Simulated securities value", account_type: "asset", currency: base_currency, custody_boundary: custody_boundary)
    equity = ledger_accounts.create!(code: "EQUITY", name: "Simulated opening capital", account_type: "equity", currency: base_currency, custody_boundary: custody_boundary)
    ledger_accounts.create!(code: "REALIZED_PNL", name: "Realized P&L", account_type: "income", currency: base_currency, custody_boundary: custody_boundary)
    ledger_accounts.create!(code: "FEES", name: "Simulated fees", account_type: "expense", currency: base_currency, custody_boundary: custody_boundary)
    cash = ledger_accounts.find_by!(code: "CASH")
    opening_cash = BigDecimal(ENV.fetch("PAPER_OPENING_CASH", "100000"))
    Ledger::Poster.new.post(
      account: self, external_id: "opening-capital:#{id}", event_type: "opening_capital",
      effective_at: created_at, source: "internal",
      metadata: { custody_boundary: custody_boundary, amount: opening_cash.to_s("F") },
      entries: [
        { account: cash, amount: opening_cash, memo: "Opening simulated cash" },
        { account: equity, amount: -opening_cash, memo: "Opening simulated equity" }
      ]
    )
  end
end
