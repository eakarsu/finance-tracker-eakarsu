require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module FinanceTracker
  class Application < Rails::Application
    config.load_defaults 8.1
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
    config.active_record.schema_format = :ruby
    # Rails' Ruby schema dumper omits triggers. db/schema.rb contains the
    # reviewed SQLite/PostgreSQL ledger guards, so do not overwrite them.
    config.active_record.dump_schema_after_migration = false
    config.active_storage.variant_processor = :disabled
    config.autoload_lib(ignore: %w[assets tasks])
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE")
    config.filter_parameters += %i[password password_confirmation token api_key authorization]
  end
end
