module CorporateActions
  class IdempotencyConflict < StandardError; end

  class Processor
    def ingest(payload)
      normalized = payload.to_h.deep_stringify_keys
      raise ArgumentError, "corporate action is not licensed for application use" unless normalized["licensed"] == true
      digest = CanonicalJson.digest(normalized)
      existing = CorporateAction.find_by(source: normalized.fetch("source"), external_id: normalized.fetch("event_id"))
      if existing
        raise IdempotencyConflict, "corporate action id was reused" unless existing.payload_digest == digest
        return existing
      end
      CorporateAction.create!(
        source: normalized.fetch("source"), external_id: normalized.fetch("event_id"), license_id: normalized.fetch("license_id"), symbol: normalized.fetch("symbol"),
        action_type: normalized.fetch("action_type"), effective_on: normalized.fetch("effective_on"),
        ratio: normalized["ratio"], cash_amount: normalized["cash_amount"],
        currency: normalized.fetch("currency", "USD"), payload_digest: digest
      )
    end

    def apply(action:, accounts: PaperAccount.active)
      CorporateAction.transaction do
        accounts.find_each { |account| apply_to_account(action, account) }
        action.update!(applied_at: Time.current) unless action.applied_at
      end
      action
    end

    private

    def apply_to_account(action, account)
      return if PositionAdjustment.exists?(paper_account: account, corporate_action: action)
      quantity = account.quantity_for(action.symbol)
      return if quantity.zero?

      case action.action_type
      when "split"
        account.position_adjustments.create!(
          corporate_action: action, symbol: action.symbol,
          quantity_delta: quantity * (action.ratio.to_d - 1), reason: "#{action.ratio}:1 split"
        )
      when "dividend"
        post_dividend(account, action, quantity)
        account.position_adjustments.create!(corporate_action: action, symbol: action.symbol, quantity_delta: 0, reason: "cash dividend recorded")
      else
        account.position_adjustments.create!(corporate_action: action, symbol: action.symbol, quantity_delta: 0, reason: "manual symbol-change review required")
      end
    end

    def post_dividend(account, action, quantity)
      cash = account.ledger_accounts.find_by!(code: "CASH")
      pnl = account.ledger_accounts.find_by!(code: "REALIZED_PNL")
      amount = quantity * action.cash_amount.to_d
      Ledger::Poster.new.post(
        account: account, external_id: "corporate-action:#{action.source}:#{action.external_id}", event_type: "dividend",
        effective_at: action.effective_on.beginning_of_day, source: action.source,
        metadata: { corporate_action_id: action.id, symbol: action.symbol, quantity: quantity.to_s },
        entries: [
          { account: cash, amount: amount, memo: "#{action.symbol} dividend cash" },
          { account: pnl, amount: -amount, memo: "#{action.symbol} dividend income" }
        ]
      )
    end
  end
end
