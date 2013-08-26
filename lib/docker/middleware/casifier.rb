# This class converts all Hashes with snake_case keys to camelCase.
class Docker::Middleware::Casifier < Docker::Middleware::JSON

  # Camelize each symbol key in the query and body if the "Content-Type" is
  # "application/json"
  def request_call(datum)
    camelize! :query, :body, datum
    super
    datum
  end

  # Parse the body and snakeify each key in the body if the "Content-Type" is
  # "application/json".
  def response_call(datum)
    super
    snakeify! :body, datum[:response]
    datum
  end

  # Convert each key to/fro snake and camel case.
  [:camelize, :snakeify].each do |method|
    define_method(:"#{method}!") do |*keys, datum|
      with_hashes(*keys, datum) { |arg|
        Docker::Util.public_send(:"#{method}_keys!", arg)
      }
    end
  end

  # Select the keys of the given Hash that are also Hashes and yield them.
  def with_hashes(*keys, datum, &block)
    if is_json?(datum)
      keys.map { |key| datum[key] }
          .select { |val| val.is_a?(Hash) }
          .each(&block)
    end
  end
end
