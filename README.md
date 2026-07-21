# Finance Tracker

Finance Tracker is a Rails 8.1 portfolio watchlist plus a controlled **paper-trading** workflow. It does not connect to a live brokerage and cannot place live orders. That boundary is deliberate: simulated orders must pass deterministic controls and produce ledger/audit evidence before any future brokerage integration is considered.

## Proven journey

1. An operator ingests a licensed market-data record at `POST /api/v1/market_data`. The record must carry its provider event ID, license ID, source timestamp, bid/ask/last, and volume. Identical replay is idempotent; reuse of an event ID with different data is rejected.
2. A user submits a paper order in `/paper_trading`. Stale data, thin volume, wide spread, order notional, projected gross exposure, daily loss, simulated cash, account status, and the kill switch are evaluated deterministically. No LLM participates.
3. Orders above the configured threshold remain `pending_approval` until an independent approver/operator re-runs every limit. Approval cannot override a failed limit.
4. Operator-authenticated paper-fill events support partial fills and idempotent replay. Limit violations, overfills, altered duplicates, and fills against non-approved orders fail.
5. Every fill posts two balanced entries to an append-only, hash-chained ledger with explicit simulated custody boundaries. Errors are corrected by a linked reversal, never mutation. Corporate actions and read-only reconciliation runs are also idempotent.
6. Users can export a CSV containing transaction hashes, entries, currencies, and custody boundaries. Reconciliation breaks remain durable records.

## Local verification

Ruby 3.4.4 is required.

```sh
cp .env.example .env
export SECRET_KEY_BASE="$(bin/rails secret)"
bundle install
bin/rails db:prepare
bin/rails test
bin/rails zeitwerk:check
bundle exec brakeman --no-pager --quiet
bundle exec bundle-audit check --update
bin/rails server
```

Development and tests use SQLite. Production uses only `DATABASE_URL` (PostgreSQL). Startup never creates, seeds, or migrates a database; run `bin/rails db:migrate` as an explicit release step after reviewing the target.

## Licensed market-data contract

Set `MARKET_DATA_API_URL`, `MARKET_DATA_API_TOKEN`, and `MARKET_DATA_SOURCE`. `GET {base}/v1/quotes/{SYMBOL}` must return JSON with:

```json
{
  "licensed": true,
  "license_id": "contract-identifier",
  "event_id": "provider-idempotency-key",
  "symbol": "AAPL",
  "name": "Apple Inc.",
  "bid": "199.90",
  "ask": "200.10",
  "last": "200.00",
  "daily_volume": "1000000",
  "source_timestamp": "2026-07-19T15:00:00Z"
}
```

Missing configuration, an unlicensed record, incomplete fields, timeouts, non-2xx responses, and malformed JSON fail closed. Provider entitlements, production credentials, SLAs, symbol mapping, and contractual redistribution rights must be validated with the selected vendor before launch.

## Production topology

`docker compose build` creates a pinned Ruby 3.4.4 image. Set `.env` and `POSTGRES_PASSWORD`, run migrations as a one-off release command, then start the services:

```sh
docker compose run --rm web bundle exec rails db:migrate
docker compose up -d
```

The web health check verifies database connectivity. Keep PostgreSQL private, terminate TLS at a trusted ingress, use a managed secret store, back up the database, and alert on kill-switch changes, rejected reconciliation, stale ingestion, and ledger-chain verification failures.
