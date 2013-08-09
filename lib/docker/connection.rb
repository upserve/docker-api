# This class represents a Connection to a Docker server. The Connection is
# immutable in that once the url and options is set they cannot be changed.
class Docker::Connection
  include Docker::Error

  attr_reader :url, :options

  # Create a new Connection. This method takes a url (String) and options
  # (Hash). These are passed to Excon, so any options valid for `Excon.new`
  # can be passed here.
  def initialize(url, opts)
    case
    when !url.is_a?(String)
      raise ArgumentError, "Expected a String, got: '#{url}'"
    when !opts.is_a?(Hash)
      raise ArgumentError, "Expected a Hash, got: '#{opts}'"
    else
      @url, @options = url, opts
    end
  end

  # The actual client that sends HTTP methods to the Docker server. This value
  # is not cached, since doing so may cause socket errors after bad requests.
  def resource
    Excon.new(url, options)
  end
  private :resource

  # Send a request to the server with the `
  def request(*args, &block)
    resource.request(compile_request_params(*args, &block)).body
  rescue Excon::Errors::BadRequest => ex
    raise ClientError, ex.message
  rescue Excon::Errors::InternalServerError => ex
    raise ServerError, ex.message
  rescue Excon::Errors::Timeout => ex
    raise TimeoutError, ex.message
  end

  # Delegate all HTTP methods to the #request.
  [:get, :put, :post, :delete].each do |method|
    define_method(method) { |*args, &block| request(method, *args, &block) }
  end

  def to_s
    "Docker::Connection { :url => #{url}, :options => #{options} }"
  end

private
  # Given an HTTP method, path, optional query, extra options, and block,
  # compiles a request.
  def compile_request_params(http_method, path, query = nil, opts = nil, &block)
    query ||= {}
    opts ||= {}
    headers = opts.delete(:headers) || {}
    content_type = opts[:body].nil? ?  'text/plain' : 'application/json'
    user_agent = "Swipely/Docker-API #{Docker::VERSION}"
    {
      :method        => http_method,
      :path          => "/v#{Docker::API_VERSION}#{path}",
      :query         => query,
      :headers       => { 'Content-Type' => content_type,
                          'User-Agent'   => user_agent,
                        }.merge(headers),
      :expects       => (200..204),
      :idempotent    => http_method == :get,
      :request_block => block
    }.merge(opts).reject { |_, v| v.nil? }
  end
end
