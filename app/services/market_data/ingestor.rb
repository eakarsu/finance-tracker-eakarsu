module MarketData
  class IdempotencyConflict < StandardError; end

  class Ingestor
    def initialize(client: nil, clock: -> { Time.current })
      @client = client
      @clock = clock
    end

    def ingest_symbol(symbol)
      ingest((@client || LicensedClient.new).quote(symbol))
    end

    def ingest(payload)
      normalized = payload.deep_stringify_keys
      digest = CanonicalJson.digest(normalized)
      source = normalized.fetch("source")
      event_id = normalized.fetch("event_id")

      MarketDataSnapshot.transaction do
        existing = MarketDataSnapshot.find_by(source: source, source_event_id: event_id)
        if existing
          raise IdempotencyConflict, "market event id was reused with different data" unless existing.payload_digest == digest
          return existing
        end

        MarketDataSnapshot.create!(
          source: source,
          source_event_id: event_id,
          license_id: normalized.fetch("license_id"),
          symbol: normalized.fetch("symbol"),
          bid: normalized.fetch("bid"),
          ask: normalized.fetch("ask"),
          last: normalized.fetch("last"),
          daily_volume: normalized.fetch("daily_volume"),
          source_timestamp: Time.iso8601(normalized.fetch("source_timestamp")),
          ingested_at: @clock.call,
          payload_digest: digest,
          raw_payload: normalized
        )
      end
    rescue KeyError, ArgumentError => error
      raise ProviderError, "invalid market event: #{error.message}"
    end
  end
end
