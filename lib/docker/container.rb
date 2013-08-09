# This class represents a Docker Container. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Container
  include Docker::Error

  attr_accessor :id, :connection

  # The private new method accepts a connection and optional id.
  def initialize(connection, id = nil)
    if connection.is_a?(Docker::Connection)
      @connection, @id = connection, id
    else
      raise ArgumentError, "Expected a Docker::Connection, got: #{connection}."
    end
  end

  # Return a List of Hashes that represents the top running processes.
  def top(opts = {})
    resp = Docker::Util.parse_json(connection.get(path_for(:top), opts))
    if resp['Processes'].nil?
      []
    else
      resp['Processes'].map { |ary| Hash[resp['Titles'].zip(ary)] }
    end
  end

  # Wait for the current command to finish executing.
  def wait(time = 60)
    resp = connection.post(path_for(:wait), nil, :read_timeout => time)
    Docker::Util.parse_json(resp)
  end

  # Given a command and an optional number of seconds to wait for the currently
  # executing command, creates a new Container to run the specified command. If
  # the command that is currently executing does not return a 0 status code, an
  # UnexpectedResponseError is raised.
  def run(cmd, time = 1000)
    if (code = tap(&:start).wait(time)['StatusCode']).zero?
      commit.run(cmd).tap(&:start)
    else
      raise UnexpectedResponseError, "Command returned status code #{code}."
    end
  end

  # Export the Container as a tar.
  def export(&block)
    connection.get(path_for(:export), {}, :response_block => block)
    self
  end

  # Attach to a container's standard streams / logs.
  def attach(options = {}, &block)
    opts = { :stream => true, :stdout => true }.merge(options)
    connection.post(path_for(:attach), opts, :response_block => block)
  end

  # Create an Image from a Container's change.s
  def commit(options = {})
    options.merge!('container' => self.id[0..7])
    hash = Docker::Util.parse_json(connection.post('/commit', options))
    Docker::Image.send(:new, self.connection, hash['Id'])
  end

  # Return a String represntation of the Container.
  def to_s
    "Docker::Container { :id => #{self.id}, :connection => #{self.connection} }"
  end

  # #json returns information about the Container, #changes returns a list of
  # the changes the Container has made to the filesystem.
  [:json, :changes].each do |method|
    define_method(method) do |opts = {}|
      Docker::Util.parse_json(connection.get(path_for(method), opts))
    end
  end

  # #start!, #stop!, #kill!, and #restart! all perform the associated action and
  # return the Container. #start, #stop, #kill, and #restart all do the same,
  # but rescue from ServerErrors.
  [:start, :stop, :kill, :restart].each do |method|
    define_method(:"#{method}!") do |opts = {}|
      connection.post(path_for(method), {}, :body => opts.to_json)
      self
    end

    define_method(method) do |*args|
      begin; public_send(:"#{method}!", *args); rescue ServerError; self end
    end
  end

  # Create a new Container.
  def self.create(opts = {}, conn = Docker.connection)
    instance = new(conn)
    resp = conn.post('/containers/create', {}, :body => opts.to_json)
    if (instance.id = Docker::Util.parse_json(resp)['Id']).nil?
      raise UnexpectedResponseError, 'Create response did not contain an Id'
    else
      instance
    end
  end

  # Return all of the Containers.
  def self.all(opts = {}, conn = Docker.connection)
    hashes = Docker::Util.parse_json(conn.get('/containers/json', opts)) || []
    hashes.map { |hash| new(conn, hash['Id']) }
  end

  # Convenience method to return the path for a particular resource.
  def path_for(resource)
    "/containers/#{self.id}/#{resource}"
  end

  private :path_for
  private_class_method :new
end
