# This module holds shared logic that doesn't really belong anywhere else in the
# gem.
module Docker::Util
  extend self
  include Docker::Error

  def parse_json(body)
    return if body.nil? || body.empty? || (body == 'null')
    underscore_symbolize_keys(JSON.parse(body))
  rescue JSON::ParserError => ex
    raise UnexpectedResponseError, ex.message
  end

  def underscore(str)
    str.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def transform_keys(obj, &block)
    if obj.is_a? Hash
      return obj.inject({}) do |res, (k, v)|
        res[yield(k)] = transform_keys(v, &block)
        res
      end
    elsif obj.is_a? Array
      return obj.inject([]) do |res,     v |
        res << transform_keys(v, &block)
        res
      end
    else
      return obj
    end
  end

  def underscore_symbolize_keys(obj)
    transform_keys(obj) { |key| underscore(key).to_sym rescue key }
  end

  def camelize_keys(obj)
    transform_keys(obj) { |key| camelize(key, )}
  end

  def camelize(str, mode = :upper)
    if mode == :lower
      str.first + camelize(str)[1..-1]
    else
      str.to_s.gsub(/\/(.?)/) { $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
    end
  end
end
