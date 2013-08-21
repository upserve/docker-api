# This module holds shared logic that doesn't really belong anywhere else in the
# gem.
module Docker::Util
  include Docker::Error

  def parse_json(body)
    JSON.parse(body) unless body.nil? || body.empty? || (body == 'null')
  rescue JSON::ParserError => ex
    raise UnexpectedResponseError, ex.message
  end

  def camelize_keys!(hash)
    hash.transform_keys! { |k| k.is_a?(Symbol) ? k.to_s.camelize(:lower) : k }
  end

  def snakeify_keys!(hash)
    hash.transform_keys! { |k| k.is_a?(String) ? k.underscore.to_sym : k }
  end

  module_function :parse_json, :camelize_keys!, :snakeify_keys!
end
