module PaperTrading
  class IdempotencyConflict < StandardError; end
  class InvalidTransition < StandardError; end

  class OrderProcessor
    def submit(account:, attributes:, actor: nil, now: Time.current)
      attrs = attributes.to_h.deep_symbolize_keys
      snapshot = MarketDataSnapshot.find(attrs.fetch(:market_data_snapshot_id))
      fingerprint = CanonicalJson.digest(attrs.except(:approved_by_id).transform_values(&:to_s))

      PaperOrder.transaction do
        existing = account.paper_orders.find_by(client_order_id: attrs.fetch(:client_order_id))
        if existing
          raise IdempotencyConflict, "client_order_id was reused with different order data" unless existing.request_digest == fingerprint
          return existing
        end

        decision = Risk::Evaluator.new(
          account: account, snapshot: snapshot, symbol: attrs.fetch(:symbol), side: attrs.fetch(:side), quantity: attrs.fetch(:quantity),
          order_type: attrs.fetch(:order_type, "limit"), limit_price: attrs[:limit_price], approver: actor, now: now
        ).call
        account.paper_orders.create!(
          attrs.slice(:client_order_id, :symbol, :side, :order_type, :quantity, :limit_price).merge(
            request_digest: fingerprint, market_data_snapshot: snapshot, status: decision.status, decision_reasons: decision.reasons,
            approved_by: decision.approved? ? actor : nil, approved_at: decision.approved? && actor ? now : nil,
            submitted_at: decision.approved? ? now : nil
          )
        )
      end
    end

    def approve(order:, actor:, now: Time.current)
      raise InvalidTransition, "approver or operator role required" unless actor.approver? || actor.operator?
      order.with_lock do
        raise InvalidTransition, "order is not pending approval" unless order.status == "pending_approval"
        decision = Risk::Evaluator.new(
          account: order.paper_account, snapshot: order.market_data_snapshot, symbol: order.symbol, side: order.side,
          quantity: order.quantity, order_type: order.order_type, limit_price: order.limit_price,
          approver: actor, now: now
        ).call
        order.update!(
          status: decision.status, decision_reasons: decision.reasons,
          approved_by: decision.approved? ? actor : nil, approved_at: decision.approved? ? now : nil,
          submitted_at: decision.approved? ? now : nil
        )
        order
      end
    end

    def cancel(order:, now: Time.current)
      order.with_lock do
        raise InvalidTransition, "terminal orders cannot be cancelled" if order.terminal?
        order.update!(status: "cancelled", cancelled_at: now)
      end
      order
    end

    def fill(order:, event:)
      payload = event.to_h.deep_stringify_keys
      digest = CanonicalJson.digest(payload)
      PaperFill.transaction do
        order.lock!
        raise InvalidTransition, "only approved orders can fill" unless %w[approved partially_filled].include?(order.status)
        existing = PaperFill.find_by(source: payload.fetch("source"), provider_fill_id: payload.fetch("fill_id"))
        if existing
          raise IdempotencyConflict, "fill id was reused with different data" unless existing.payload_digest == digest
          return existing
        end
        quantity = payload.fetch("quantity").to_d
        price = payload.fetch("price").to_d
        raise InvalidTransition, "fill exceeds remaining quantity" if quantity > order.remaining_quantity
        enforce_limit_price!(order, price)

        fill = order.paper_fills.create!(
          source: payload.fetch("source"), provider_fill_id: payload.fetch("fill_id"),
          quantity: quantity, price: price, occurred_at: Time.iso8601(payload.fetch("occurred_at")), payload_digest: digest
        )
        post_fill_ledger(order, fill)
        old_notional = order.filled_quantity.to_d * order.average_fill_price.to_d
        new_quantity = order.filled_quantity.to_d + quantity
        order.update!(
          filled_quantity: new_quantity,
          average_fill_price: (old_notional + quantity * price) / new_quantity,
          status: new_quantity == order.quantity ? "filled" : "partially_filled"
        )
        fill
      end
    rescue KeyError, ArgumentError => error
      raise InvalidTransition, "invalid fill event: #{error.message}"
    end

    private

    def enforce_limit_price!(order, price)
      return unless order.order_type == "limit"
      invalid = order.side == "buy" ? price > order.limit_price : price < order.limit_price
      raise InvalidTransition, "fill violates order limit price" if invalid
    end

    def post_fill_ledger(order, fill)
      account = order.paper_account
      cash = account.ledger_accounts.find_by!(code: "CASH")
      securities = account.ledger_accounts.find_by!(code: "SECURITIES")
      notional = fill.quantity.to_d * fill.price.to_d
      sign = order.side == "buy" ? -1 : 1
      Ledger::Poster.new.post(
        account: account, external_id: "fill:#{fill.source}:#{fill.provider_fill_id}", event_type: "paper_fill",
        effective_at: fill.occurred_at, source: fill.source,
        metadata: { order_id: order.id, fill_id: fill.provider_fill_id, symbol: order.symbol, side: order.side, quantity: fill.quantity.to_s, price: fill.price.to_s },
        entries: [
          { account: cash, amount: sign * notional, memo: "#{order.side} #{fill.quantity} #{order.symbol} cash leg" },
          { account: securities, amount: -sign * notional, memo: "#{order.side} #{fill.quantity} #{order.symbol} securities leg" }
        ]
      )
    end
  end
end
