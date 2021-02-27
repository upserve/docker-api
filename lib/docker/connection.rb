# This class represents a Connection to a Docker server. The Connection is
# immutable in that once the url and options is set they cannot be changed.
class Docker::Connection
  require 'docker/util'
  require 'docker/error'

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
      uri = URI.parse(url)
      if uri.scheme == "unix"
        @url, @options = 'unix:///', {:socket => uri.path}.merge(opts)
      elsif uri.scheme =~ /^(https?|tcp)$/
        @url, @options = url, opts
      else
        @url, @options = "http://#{uri}", opts
      end
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
    retries ||= 0
    request = compile_request_params(*args, &block)
    log_request(request)
    begin
      resource.request(request).body
    rescue Excon::Errors::BadRequest => ex
      if retries < 2
        response_cause = ''
        begin
          response_cause = JSON.parse(ex.response.body)['cause']
        rescue JSON::ParserError
          #noop
        end

        if response_cause.is_a?(String)
          # The error message will tell the application type given and then the
          # application type that the message should be
          #
          # This is not perfect since it relies on processing a message that
          # could change in the future. However, it should be a good stop-gap
          # until all methods are updated to pass in the appropriate content
          # type.
          #
          # A current example message is:
          #   * 'Content-Type: application/json is not supported. Should be "application/x-tar"'
          matches = response_cause.delete('"\'').scan(%r{(application/\S+)})
          unless matches.count < 2
            Docker.logger.warn(
              <<~RETRY_WARNING
              Automatically retrying with content type '#{response_cause}'
                Original Error: #{ex}
              RETRY_WARNING
            ) if Docker.logger

            request[:headers]['Content-Type'] = matches.last.first
            retries += 1
            retry
          end
        end
      end
      raise ClientError, ex.response.body
    rescue Excon::Errors::Unauthorized => ex
      raise UnauthorizedError, ex.response.body
    rescue Excon::Errors::NotFound => ex
      raise NotFoundError, ex.response.body
    rescue Excon::Errors::Conflict => ex
      raise ConflictError, ex.response.body
    rescue Excon::Errors::InternalServerError => ex
      raise ServerError, ex.response.body
    rescue Excon::Errors::Timeout => ex
      raise TimeoutError, ex.message
    end
  end

  def log_request(request)
    if Docker.logger
      Docker.logger.debug(
        [request[:method], request[:path], request[:query], request[:body]]
      )
    end
  end

  def to_s
    "Docker::Connection { :url => #{url}, :options => #{options} }"
  end

  # Delegate all HTTP methods to the #request.
  [:get, :put, :post, :delete].each do |method|
    define_method(method) { |*args, &block| request(method, *args, &block) }
  end

  # Common attribute requests
  def info
    Docker::Util.parse_json(get('/info'))
  end

  def ping
    get('/_ping')
  end

  def podman?
    @podman ||= !(
      Array(version['Components']).find do |component|
        component['Name'].include?('Podman')
      end
    ).nil?
  end

  def rootless?
    @rootless ||= (info['Rootless'] == true)
  end

  def version
    @version ||= Docker::Util.parse_json(get('/version'))
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
      :path          => path,
      :query         => query,
      :headers       => { 'Content-Type' => content_type,
                          'User-Agent'   => user_agent,
                        }.merge(headers),
      :expects       => (200..204).to_a << 301 << 304,
      :idempotent    => http_method == :get,
      :request_block => block,
    }.merge(opts).reject { |_, v| v.nil? }
  end
end
