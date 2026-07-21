require "net/http"
require "json"

module MarketData
  class LicensedClient
    REQUIRED_FIELDS = %w[event_id license_id symbol bid ask last daily_volume source_timestamp].freeze

    def initialize(base_url: ENV["MARKET_DATA_API_URL"], token: ENV["MARKET_DATA_API_TOKEN"], source: ENV.fetch("MARKET_DATA_SOURCE", "licensed-provider"))
      @base_url = base_url
      @token = token
      @source = source
      raise ProviderError, "MARKET_DATA_API_URL and MARKET_DATA_API_TOKEN are required" if @base_url.blank? || @token.blank?
    end

    def quote(symbol)
      uri = URI.join(@base_url.end_with?("/") ? @base_url : "#{@base_url}/", "v1/quotes/#{URI.encode_uri_component(symbol.to_s.upcase)}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
      raise ProviderError, "market data provider returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      missing = REQUIRED_FIELDS.reject { |field| payload[field].present? }
      raise ProviderError, "market data response missing: #{missing.join(', ')}" if missing.any?
      raise ProviderError, "market data record is not licensed for application use" unless payload["licensed"] == true
      payload.merge("source" => @source)
    rescue JSON::ParserError, URI::InvalidURIError => error
      raise ProviderError, "invalid market data response: #{error.message}"
    end
  end
end
