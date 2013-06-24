# This class represents a Connection to a Docker server. The Connection is
# immutable in that once the url and options is set they cannot be changed.
class Docker::Connection
  include Docker::Error

  attr_reader :url, :options

  # Create a new Connection. By default, the Connection points to localhost at
  # port 4243, but this can be changed via an options Hash.
  def initialize(url = 'http://localhost', options = {})
    unless options.is_a?(Hash)
      raise Docker::Error::ArgumentError, "Expected a Hash, got: #{options}"
    end
    self.url = url
    self.options = { :port => 4243 }.merge(options)
  end

  # The actual client that sends HTTP methods to the docker server.
  def resource
    @resource ||= Excon.new(self.url, self.options)
  end

  # Nil out the connection. This now happens on every request to prevent socket
  # errors.
  def reset!
    @resource = nil
  end

  # Delegate all HTTP methods to the resource.
  [:get, :put, :post, :delete, :request].each do |method|
    define_method(method) do |*args, &block|
      begin
        self.reset!
        self.resource.public_send(method, *args, &block)
      rescue Excon::Errors::BadRequest => ex
        raise ClientError, ex.message
      rescue Excon::Errors::InternalServerError => ex
        raise ServerError, ex.message
      end
    end
  end

  # Send a request to the server and then parse it into a Hash.
  def json_request(method, path, query = {}, &block)
    params = compile_request_params(method, path, query, &block)
    body = self.request(params).body
    JSON.parse(body) unless body.nil? || body.empty? || (body == 'null')
  rescue JSON::ParserError => ex
    raise UnexpectedResponseError, ex.message
  end

  def to_s
    "Docker::Connection { :url => #{self.url}, :options => #{self.options} }"
  end

private
  attr_writer :url, :options

  # Given an http_method, path, query, and optional block, returns the
  # corresponding request parameters.
  def compile_request_params(http_method, path, query, &block)
    {
      :method         => http_method,
      :path           => path,
      :query          => query,
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => "Docker-Client/0.4.6" },
      :expects        => (200..204),
      :idempotent     => http_method == :get,
      :response_block => block
    }.reject { |_, v| v.nil? }
  end
end
