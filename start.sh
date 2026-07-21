#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_dir"

if [[ -d /opt/homebrew/opt/ruby/bin ]]; then
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
fi

# Runtime acceptance uses a dedicated SQLite file. Normal startup remains
# migration- and seed-free as documented by the project.
if [[ "${NODE_ENV:-}" == "test" && -n "${DB_PATH:-}" ]]; then
  case "$DB_PATH" in
    /*) ;;
    *) echo "DB_PATH must be absolute in test mode" >&2; exit 1 ;;
  esac
  export RAILS_ENV=test TEST_DATABASE_PATH="$DB_PATH"
  export SECRET_KEY_BASE="${SECRET_KEY_BASE:-${SESSION_SECRET:-runtime-finance-tracker-secret-key-base}}"
  unset DATABASE_URL
  bundle exec rails db:prepare

  if [[ -n "${ADMIN_EMAIL:-}" && -n "${ADMIN_PASSWORD:-}" ]]; then
    bundle exec rails runner '
      user = User.find_or_initialize_by(email: ENV.fetch("ADMIN_EMAIL").downcase.strip)
      user.assign_attributes(
        password: ENV.fetch("ADMIN_PASSWORD"),
        password_confirmation: ENV.fetch("ADMIN_PASSWORD"),
        first_name: "Runtime",
        last_name: "Acceptance",
        risk_role: "operator"
      )
      user.save!
    '
  fi
fi

exec bundle exec puma -C config/puma.rb
