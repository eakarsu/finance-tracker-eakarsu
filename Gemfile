source "https://rubygems.org"

ruby ">= 3.2.0"

gem "rails", "~> 8.1.3"
gem "puma", ">= 6.0"
gem "devise", "~> 5.0"
gem "jbuilder", "~> 2.14"
gem "sprockets-rails", "~> 3.5"
gem "jquery-rails", "~> 4.6"
gem "csv", "~> 3.3"

group :development, :test do
  gem "sqlite3", "~> 2.9"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end

group :production do
  gem "pg", "~> 1.6"
end
