class AddPaperTradingCore < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :risk_role, :string, null: false, default: "member"
    add_index :stocks, :ticker, unique: true
    add_index :user_stocks, [:user_id, :stock_id], unique: true
    add_index :friendships, [:user_id, :friend_id], unique: true
    reversible do |direction|
      direction.up do
        add_foreign_key :user_stocks, :users
        add_foreign_key :user_stocks, :stocks
        add_foreign_key :friendships, :users, column: :user_id
        add_foreign_key :friendships, :users, column: :friend_id
      end
      direction.down do
        remove_foreign_key :friendships, column: :friend_id
        remove_foreign_key :friendships, column: :user_id
        remove_foreign_key :user_stocks, column: :stock_id
        remove_foreign_key :user_stocks, column: :user_id
      end
    end

    create_table :market_data_snapshots do |t|
      t.string :source, null: false
      t.string :source_event_id, null: false
      t.string :license_id, null: false
      t.string :symbol, null: false
      t.decimal :bid, precision: 20, scale: 8, null: false
      t.decimal :ask, precision: 20, scale: 8, null: false
      t.decimal :last, precision: 20, scale: 8, null: false
      t.decimal :daily_volume, precision: 24, scale: 8, null: false
      t.datetime :source_timestamp, null: false
      t.datetime :ingested_at, null: false
      t.string :payload_digest, null: false
      t.json :raw_payload, null: false, default: {}
      t.timestamps
    end
    add_index :market_data_snapshots, [:source, :source_event_id], unique: true, name: "idx_market_events_idempotent"
    add_index :market_data_snapshots, [:symbol, :source_timestamp]

    create_table :paper_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :base_currency, null: false, default: "USD"
      t.string :status, null: false, default: "active"
      t.string :custody_boundary, null: false, default: "simulated"
      t.timestamps
    end

    create_table :risk_policies do |t|
      t.references :paper_account, null: false, foreign_key: true, index: { unique: true }
      t.decimal :max_gross_exposure, precision: 20, scale: 2, null: false, default: 100_000
      t.decimal :max_order_notional, precision: 20, scale: 2, null: false, default: 10_000
      t.decimal :max_daily_loss, precision: 20, scale: 2, null: false, default: 2_500
      t.decimal :minimum_daily_volume, precision: 24, scale: 8, null: false, default: 10_000
      t.decimal :max_spread_bps, precision: 10, scale: 2, null: false, default: 100
      t.integer :stale_after_seconds, null: false, default: 60
      t.decimal :approval_notional, precision: 20, scale: 2, null: false, default: 5_000
      t.boolean :kill_switch, null: false, default: false
      t.string :kill_switch_reason
      t.datetime :kill_switch_changed_at
      t.references :kill_switch_changed_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :paper_orders do |t|
      t.references :paper_account, null: false, foreign_key: true
      t.references :market_data_snapshot, null: false, foreign_key: true
      t.string :client_order_id, null: false
      t.string :request_digest, null: false
      t.string :symbol, null: false
      t.string :side, null: false
      t.string :order_type, null: false, default: "limit"
      t.decimal :quantity, precision: 24, scale: 8, null: false
      t.decimal :limit_price, precision: 20, scale: 8
      t.decimal :filled_quantity, precision: 24, scale: 8, null: false, default: 0
      t.decimal :average_fill_price, precision: 20, scale: 8
      t.string :status, null: false, default: "pending"
      t.json :decision_reasons, null: false, default: []
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.datetime :submitted_at
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :paper_orders, [:paper_account_id, :client_order_id], unique: true, name: "idx_paper_orders_idempotent"

    create_table :paper_fills do |t|
      t.references :paper_order, null: false, foreign_key: true
      t.string :source, null: false
      t.string :provider_fill_id, null: false
      t.decimal :quantity, precision: 24, scale: 8, null: false
      t.decimal :price, precision: 20, scale: 8, null: false
      t.datetime :occurred_at, null: false
      t.string :payload_digest, null: false
      t.timestamps
    end
    add_index :paper_fills, [:source, :provider_fill_id], unique: true, name: "idx_paper_fills_idempotent"

    create_table :ledger_accounts do |t|
      t.references :paper_account, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :account_type, null: false
      t.string :currency, null: false, default: "USD"
      t.string :custody_boundary, null: false
      t.timestamps
    end
    add_index :ledger_accounts, [:paper_account_id, :code], unique: true

    create_table :ledger_transactions do |t|
      t.references :paper_account, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :event_type, null: false
      t.datetime :effective_at, null: false
      t.string :source, null: false
      t.references :reversal_of, foreign_key: { to_table: :ledger_transactions }
      t.text :correction_reason
      t.string :previous_hash
      t.string :event_hash, null: false
      t.json :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :ledger_transactions, [:paper_account_id, :external_id], unique: true, name: "idx_ledger_transactions_idempotent"
    add_index :ledger_transactions, :event_hash, unique: true

    create_table :ledger_entries do |t|
      t.references :ledger_transaction, null: false, foreign_key: true
      t.references :ledger_account, null: false, foreign_key: true
      t.decimal :amount, precision: 24, scale: 8, null: false
      t.string :memo, null: false
      t.timestamps
    end

    create_table :corporate_actions do |t|
      t.string :source, null: false
      t.string :external_id, null: false
      t.string :license_id, null: false
      t.string :symbol, null: false
      t.string :action_type, null: false
      t.date :effective_on, null: false
      t.decimal :ratio, precision: 20, scale: 8
      t.decimal :cash_amount, precision: 20, scale: 8
      t.string :currency, null: false, default: "USD"
      t.string :payload_digest, null: false
      t.datetime :applied_at
      t.timestamps
    end
    add_index :corporate_actions, [:source, :external_id], unique: true

    create_table :position_adjustments do |t|
      t.references :paper_account, null: false, foreign_key: true
      t.references :corporate_action, null: false, foreign_key: true
      t.string :symbol, null: false
      t.decimal :quantity_delta, precision: 24, scale: 8, null: false
      t.string :reason, null: false
      t.timestamps
    end
    add_index :position_adjustments, [:paper_account_id, :corporate_action_id], unique: true, name: "idx_corporate_action_once_per_account"

    create_table :reconciliation_runs do |t|
      t.references :paper_account, null: false, foreign_key: true
      t.string :source, null: false
      t.string :source_run_id, null: false
      t.string :payload_digest, null: false
      t.datetime :as_of, null: false
      t.string :status, null: false
      t.decimal :ledger_cash, precision: 24, scale: 8, null: false
      t.decimal :source_cash, precision: 24, scale: 8, null: false
      t.decimal :ledger_gross_exposure, precision: 24, scale: 8, null: false
      t.decimal :source_gross_exposure, precision: 24, scale: 8, null: false
      t.json :breaks, null: false, default: []
      t.timestamps
    end
    add_index :reconciliation_runs, [:source, :source_run_id], unique: true, name: "idx_reconciliations_idempotent"

    reversible do |direction|
      direction.up { install_ledger_immutability }
      direction.down { remove_ledger_immutability }
    end
  end

  private

  def install_ledger_immutability
    if connection.adapter_name.match?(/sqlite/i)
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

  def remove_ledger_immutability
    if connection.adapter_name.match?(/sqlite/i)
      %w[ledger_transactions ledger_entries].each do |table|
        execute "DROP TRIGGER IF EXISTS #{table}_no_update"
        execute "DROP TRIGGER IF EXISTS #{table}_no_delete"
      end
    else
      %w[ledger_transactions ledger_entries].each { |table| execute "DROP TRIGGER IF EXISTS #{table}_immutable ON #{table}" }
      execute "DROP FUNCTION IF EXISTS reject_ledger_mutation()"
    end
  end
end
