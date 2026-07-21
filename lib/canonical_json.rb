require "digest"

module CanonicalJson
  module_function

  def dump(value)
    case value
    when Hash
      "{" + value.keys.map(&:to_s).sort.map { |key| "#{key.to_json}:#{dump(value[key] || value[key.to_sym])}" }.join(",") + "}"
    when Array
      "[" + value.map { |item| dump(item) }.join(",") + "]"
    when Time, ActiveSupport::TimeWithZone
      value.utc.iso8601(6).to_json
    else
      value.to_json
    end
  end

  def digest(value)
    Digest::SHA256.hexdigest(dump(value))
  end
end
