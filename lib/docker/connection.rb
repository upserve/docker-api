# This class represents a connection to a Docker server. The connection is
# immutable in that once the host and port is set they cannot be changed.
class Docker::Connection
  attr_reader :host, :port

  # Create a new connection. By default, the connection points to localhost at
  # port 4243, but this can be changed via an options Hash.
  def initialize(options = {})
    unless options.is_a?(Hash)
      raise Docker::Error::ArgumentError, "Expected a Hash, got: #{options}"
    end
    @host = options[:host] || 'localhost'
    @port = options[:port] || 4243
  end

  # The actual client that sends HTTP methods to the docker server.
  def resource
    @resource ||= RestClient::Resource.new("#{host}:#{port}")
  end

  # Delegate all HTTP methods to the resource.
  delegate :get, :put, :post, :delete, :[], :to => :resource
end
