# This module holds shared logic that doesn't really belong anywhere else in the
# gem.
module Docker::Util
  include Docker::Error

  def parse_json(body)
    JSON.parse(body) unless body.nil? || body.empty? || (body == 'null')
  rescue JSON::ParserError => ex
    raise UnexpectedResponseError, ex.message
  end

  module_function :parse_json
end
