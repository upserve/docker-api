# This class represents a Connection to a Docker server. The Connection is
# immutable in that once the url and port is set they cannot be changed.
class Docker::Connection
  attr_reader :url, :port

  # Create a new Connection. By default, the Connection points to localhost at
  # port 4243, but this can be changed via an options Hash.
  def initialize(options = {})
    unless options.is_a?(Hash)
      raise Docker::Error::ArgumentError, "Expected a Hash, got: #{options}"
    end
    self.port = options[:port] || 4243
    self.url = options[:url] || 'http://localhost'
  end

  # The actual client that sends HTTP methods to the docker server.
  def resource
    @resource ||= Excon.new(self.url, :port => self.port)
  end

  def to_s
    "Docker::Connection { :url => #{self.url}, :port => #{self.port} }"
  end

  def ==(other_connection)
    other_connection.is_a?(self.class) &&
      (other_connection.url == self.url) &&
        (other_connection.port == self.port)
  end

  # Delegate all HTTP methods to the resource.
  [:get, :put, :post, :delete, :request].each do |method|
    define_method(method) do |*args, &block|
      self.resource.public_send(method, *args, &block)
    end
  end

private
  attr_writer :url, :port
end
