# This class represents a Docker Container. It's important to note that nothing
# is cached so that the information is always up to date. For more information
# about the specific methods, see:
# http://docs.docker.io/en/latest/api/docker_remote_api_v1.2.html.
class Docker::Container
  attr_reader :id, :connection

  # Creates a new Container with the specified id and Connection. If a
  # Connection is specified and it is not a Docker::Connection, a
  # Docker::Error::ArgumentError is raised.
  def initialize(options = {})
    options[:connection] ||= Docker.connection
    unless options[:connection].is_a?(Docker::Connection)
      raise Docker::Error::ArgumentError, "Expected a Docker::Connection."
    end
    self.id = options[:id]
    self.connection = options[:connection]
  end

  # Returns true if the Container has been created, false otherwise.
  def created?
    !!self.id
  end

  # Create a Container with the specified body. If the Container is created
  # successfully, self is returned.
  def create!(body = {})
    case
    when self.created?
      raise Docker::Error::ContainerError, 'This Container already exists!'
    when !body.is_a?(Hash)
      raise Docker::Error::ArgumentError, 'Expected a Hash'
    else
      response = self.connection.post(
        :path    => '/containers/create',
        :headers => { 'Content-Type' => 'application/json' },
        :body    => body.to_json,
        :expects => 201
      )
      self.id = JSON.parse(response.body)['Id']
      self
    end
  end

  # Export the Container. Since the export will naturally be a lot of data,
  # you must pass a block to process each chunk of the response. Each chunk,
  # along with the remaining and total block is yielded several times, but
  # handling only the chunk will suffice.
  def export(&block)
    ensure_created!
    self.connection.get(
      :path           => "/containers/#{self.id}/export",
      :headers        => { 'Content-Type' => 'application/octet-stream' },
      :expects        => 200,
      :response_block => block
    )
    self
  end

  # Given a Hash of options about which streams to connect to, attaches to the
  # Container. By default, attaches to STDOUT and STDERR. Much like #export,
  # this method accepts a block with which it processes the stream.
  def attach(query = {}, &block)
    ensure_created!
    query = { :stdout => true, :stderr => true, :stream => true }.merge(query)
    self.connection.post(
      :path    => "/containers/#{self.id}/attach",
      :query   => query,
      :headers => { 'Content-Type' => 'application/vnd.docker.raw-stream' },
      :expects => 200,
      :response_block => block
    )
    self
  end

  {
    :json => :get,   # Get a description of the Container.
    :wait => :post,  # Block until the command finishes.
    :start => :post, # Start the Container.
    :changes => :get # See the Container's changes to the filesystem.
  }.each do |method, http_method|
    define_method(method) do
      ensure_created!
      body = self.connection.request(
        :method  => http_method,
        :path    => "/containers/#{self.id}/#{method}",
        :headers => { 'Content-Type' => 'application/json' },
        :expects => [200, 204]
      ).body
      JSON.parse(body) unless body.nil? || body.empty? || (body == 'null')
    end
  end

  # Stop, kill, or restart the Container. Each of the followng generated methods
  # takes an option parameter which represents the time Docker should wait
  # before performing the action. The default is 0.
  [:stop, :kill, :restart].each do |method|
    define_method(method) do |time = 0|
      ensure_created!
      body = self.connection.request(
        :method  => :post,
        :path    => "/containers/#{self.id}/#{method}",
        :headers => { 'Content-Type' => 'application/json' },
        :query   => { :t => time },
        :expects => 204
      ).body
      JSON.parse(body) unless body.nil? || body.empty? || (body == 'null')
    end
  end

  def to_s
    "Docker::Container { :id => #{self.id}, :connection => #{self.connection} }"
  end

  def self.all(options = {}, connection = Docker.connection)
    response = connection.get(
      :path    => '/containers/json',
      :headers => { 'Content-Type' =>  'application/json' },
      :query   => options,
      :expects => 200
    )
    JSON.parse(response.body).map { |container_hash|
      new(:id => container_hash['Id'], :connection => connection)
    }
  end
private
  attr_writer :id, :connection

  def ensure_created!
    unless created?
      raise Docker::Error::ContainerError, 'This Container is not created.'
    end
  end
end
