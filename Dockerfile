# syntax=docker/dockerfile:1
FROM ruby:3.4.4-slim AS build

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libpq-dev git && rm -rf /var/lib/apt/lists/*
WORKDIR /rails
COPY Gemfile Gemfile.lock ./
RUN bundle config set without "development test" && bundle install
COPY . .
RUN SECRET_KEY_BASE=asset-build-secret-key-base-that-is-not-used-at-runtime \
    DATABASE_URL=postgresql://build:build@127.0.0.1/build \
    RAILS_ENV=production bundle exec rails assets:precompile

FROM ruby:3.4.4-slim
RUN apt-get update -qq && apt-get install --no-install-recommends -y libpq5 curl && rm -rf /var/lib/apt/lists/*
WORKDIR /rails
ENV RAILS_ENV=production RAILS_LOG_TO_STDOUT=true RAILS_SERVE_STATIC_FILES=true
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN useradd --create-home --shell /bin/bash rails && chown -R rails:rails /rails
USER rails
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD curl --fail http://127.0.0.1:3000/health || exit 1
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
