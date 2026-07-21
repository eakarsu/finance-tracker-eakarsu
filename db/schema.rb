# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_19_000000) do
  create_table "corporate_actions", force: :cascade do |t|
    t.string "action_type", null: false
    t.datetime "applied_at"
    t.decimal "cash_amount", precision: 20, scale: 8
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "effective_on", null: false
    t.string "external_id", null: false
    t.string "license_id", null: false
    t.string "payload_digest", null: false
    t.decimal "ratio", precision: 20, scale: 8
    t.string "source", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "external_id"], name: "index_corporate_actions_on_source_and_external_id", unique: true
  end

  create_table "friendships", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "friend_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["user_id", "friend_id"], name: "index_friendships_on_user_id_and_friend_id", unique: true
  end

  create_table "ledger_accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "custody_boundary", null: false
    t.string "name", null: false
    t.integer "paper_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_account_id", "code"], name: "index_ledger_accounts_on_paper_account_id_and_code", unique: true
    t.index ["paper_account_id"], name: "index_ledger_accounts_on_paper_account_id"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.decimal "amount", precision: 24, scale: 8, null: false
    t.datetime "created_at", null: false
    t.integer "ledger_account_id", null: false
    t.integer "ledger_transaction_id", null: false
    t.string "memo", null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_account_id"], name: "index_ledger_entries_on_ledger_account_id"
    t.index ["ledger_transaction_id"], name: "index_ledger_entries_on_ledger_transaction_id"
  end

  create_table "ledger_transactions", force: :cascade do |t|
    t.text "correction_reason"
    t.datetime "created_at", null: false
    t.datetime "effective_at", null: false
    t.string "event_hash", null: false
    t.string "event_type", null: false
    t.string "external_id", null: false
    t.json "metadata", default: {}, null: false
    t.integer "paper_account_id", null: false
    t.string "previous_hash"
    t.integer "reversal_of_id"
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["event_hash"], name: "index_ledger_transactions_on_event_hash", unique: true
    t.index ["paper_account_id", "external_id"], name: "idx_ledger_transactions_idempotent", unique: true
    t.index ["paper_account_id"], name: "index_ledger_transactions_on_paper_account_id"
    t.index ["reversal_of_id"], name: "index_ledger_transactions_on_reversal_of_id"
  end

  create_table "market_data_snapshots", force: :cascade do |t|
    t.decimal "ask", precision: 20, scale: 8, null: false
    t.decimal "bid", precision: 20, scale: 8, null: false
    t.datetime "created_at", null: false
    t.decimal "daily_volume", precision: 24, scale: 8, null: false
    t.datetime "ingested_at", null: false
    t.decimal "last", precision: 20, scale: 8, null: false
    t.string "license_id", null: false
    t.string "payload_digest", null: false
    t.json "raw_payload", default: {}, null: false
    t.string "source", null: false
    t.string "source_event_id", null: false
    t.datetime "source_timestamp", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "source_event_id"], name: "idx_market_events_idempotent", unique: true
    t.index ["symbol", "source_timestamp"], name: "index_market_data_snapshots_on_symbol_and_source_timestamp"
  end

  create_table "paper_accounts", force: :cascade do |t|
    t.string "base_currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.string "custody_boundary", default: "simulated", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_paper_accounts_on_user_id", unique: true
  end

  create_table "paper_fills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "occurred_at", null: false
    t.integer "paper_order_id", null: false
    t.string "payload_digest", null: false
    t.decimal "price", precision: 20, scale: 8, null: false
    t.string "provider_fill_id", null: false
    t.decimal "quantity", precision: 24, scale: 8, null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_order_id"], name: "index_paper_fills_on_paper_order_id"
    t.index ["source", "provider_fill_id"], name: "idx_paper_fills_idempotent", unique: true
  end

  create_table "paper_orders", force: :cascade do |t|
    t.datetime "approved_at"
    t.integer "approved_by_id"
    t.decimal "average_fill_price", precision: 20, scale: 8
    t.datetime "cancelled_at"
    t.string "client_order_id", null: false
    t.datetime "created_at", null: false
    t.json "decision_reasons", default: [], null: false
    t.decimal "filled_quantity", precision: 24, scale: 8, default: "0.0", null: false
    t.decimal "limit_price", precision: 20, scale: 8
    t.integer "market_data_snapshot_id", null: false
    t.string "order_type", default: "limit", null: false
    t.integer "paper_account_id", null: false
    t.decimal "quantity", precision: 24, scale: 8, null: false
    t.string "request_digest", null: false
    t.string "side", null: false
    t.string "status", default: "pending", null: false
    t.datetime "submitted_at"
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_paper_orders_on_approved_by_id"
    t.index ["market_data_snapshot_id"], name: "index_paper_orders_on_market_data_snapshot_id"
    t.index ["paper_account_id", "client_order_id"], name: "idx_paper_orders_idempotent", unique: true
    t.index ["paper_account_id"], name: "index_paper_orders_on_paper_account_id"
  end

  create_table "position_adjustments", force: :cascade do |t|
    t.integer "corporate_action_id", null: false
    t.datetime "created_at", null: false
    t.integer "paper_account_id", null: false
    t.decimal "quantity_delta", precision: 24, scale: 8, null: false
    t.string "reason", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["corporate_action_id"], name: "index_position_adjustments_on_corporate_action_id"
    t.index ["paper_account_id", "corporate_action_id"], name: "idx_corporate_action_once_per_account", unique: true
    t.index ["paper_account_id"], name: "index_position_adjustments_on_paper_account_id"
  end

  create_table "reconciliation_runs", force: :cascade do |t|
    t.datetime "as_of", null: false
    t.json "breaks", default: [], null: false
    t.datetime "created_at", null: false
    t.decimal "ledger_cash", precision: 24, scale: 8, null: false
    t.decimal "ledger_gross_exposure", precision: 24, scale: 8, null: false
    t.integer "paper_account_id", null: false
    t.string "payload_digest", null: false
    t.string "source", null: false
    t.decimal "source_cash", precision: 24, scale: 8, null: false
    t.decimal "source_gross_exposure", precision: 24, scale: 8, null: false
    t.string "source_run_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_account_id"], name: "index_reconciliation_runs_on_paper_account_id"
    t.index ["source", "source_run_id"], name: "idx_reconciliations_idempotent", unique: true
  end

  create_table "risk_policies", force: :cascade do |t|
    t.decimal "approval_notional", precision: 20, scale: 2, default: "5000.0", null: false
    t.datetime "created_at", null: false
    t.boolean "kill_switch", default: false, null: false
    t.datetime "kill_switch_changed_at"
    t.integer "kill_switch_changed_by_id"
    t.string "kill_switch_reason"
    t.decimal "max_daily_loss", precision: 20, scale: 2, default: "2500.0", null: false
    t.decimal "max_gross_exposure", precision: 20, scale: 2, default: "100000.0", null: false
    t.decimal "max_order_notional", precision: 20, scale: 2, default: "10000.0", null: false
    t.decimal "max_spread_bps", precision: 10, scale: 2, default: "100.0", null: false
    t.decimal "minimum_daily_volume", precision: 24, scale: 8, default: "10000.0", null: false
    t.integer "paper_account_id", null: false
    t.integer "stale_after_seconds", default: 60, null: false
    t.datetime "updated_at", null: false
    t.index ["kill_switch_changed_by_id"], name: "index_risk_policies_on_kill_switch_changed_by_id"
    t.index ["paper_account_id"], name: "index_risk_policies_on_paper_account_id", unique: true
  end

  create_table "stocks", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.decimal "last_price"
    t.string "name"
    t.string "ticker"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["ticker"], name: "index_stocks_on_ticker", unique: true
  end

  create_table "user_stocks", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "stock_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["user_id", "stock_id"], name: "index_user_stocks_on_user_id_and_stock_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.string "risk_role", default: "member", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "friendships", "users"
  add_foreign_key "friendships", "users", column: "friend_id"
  add_foreign_key "ledger_accounts", "paper_accounts"
  add_foreign_key "ledger_entries", "ledger_accounts"
  add_foreign_key "ledger_entries", "ledger_transactions"
  add_foreign_key "ledger_transactions", "ledger_transactions", column: "reversal_of_id"
  add_foreign_key "ledger_transactions", "paper_accounts"
  add_foreign_key "paper_accounts", "users"
  add_foreign_key "paper_fills", "paper_orders"
  add_foreign_key "paper_orders", "market_data_snapshots"
  add_foreign_key "paper_orders", "paper_accounts"
  add_foreign_key "paper_orders", "users", column: "approved_by_id"
  add_foreign_key "position_adjustments", "corporate_actions"
  add_foreign_key "position_adjustments", "paper_accounts"
  add_foreign_key "reconciliation_runs", "paper_accounts"
  add_foreign_key "risk_policies", "paper_accounts"
  add_foreign_key "risk_policies", "users", column: "kill_switch_changed_by_id"
  add_foreign_key "user_stocks", "stocks"
  add_foreign_key "user_stocks", "users"

  if ActiveRecord::Base.connection.adapter_name.match?(/sqlite/i)
    %w[ledger_transactions ledger_entries].each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_no_update BEFORE UPDATE ON #{table}
        BEGIN SELECT RAISE(ABORT, '#{table} is immutable'); END;
      SQL
      execute <<~SQL
        CREATE TRIGGER #{table}_no_delete BEFORE DELETE ON #{table}
        BEGIN SELECT RAISE(ABORT, '#{table} is immutable'); END;
      SQL
    end
  else
    execute <<~SQL
      CREATE FUNCTION reject_ledger_mutation() RETURNS trigger AS $$
      BEGIN RAISE EXCEPTION 'ledger records are immutable'; END;
      $$ LANGUAGE plpgsql;
    SQL
    %w[ledger_transactions ledger_entries].each do |table|
      execute "CREATE TRIGGER #{table}_immutable BEFORE UPDATE OR DELETE ON #{table} FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();"
    end
  end
end
