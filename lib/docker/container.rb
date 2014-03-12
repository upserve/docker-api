# This class represents a Docker Container. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Container
  include Docker::Base

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
    opts = {
      :stream => true, :stdout => true, :stderr => true
    }.merge(options)
    # Creates list to store stdout and stderr messages
    msgs = Docker::Messages.new
    connection.post(
      path_for(:attach),
      opts,
      :response_block => attach_for(block, msgs)
    )
    [msgs.stdout_messages, msgs.stderr_messages]
  end

  # Create an Image from a Container's change.s
  def commit(options = {})
    options.merge!('container' => self.id[0..7])
    # [code](https://github.com/dotcloud/docker/blob/v0.6.3/commands.go#L1115)
    # Based on the link, the config passed as run, needs to be passed as the
    # body of the post so capture it, remove from the options, and pass it via
    # the post body
    config = options.delete('run')
    hash = Docker::Util.parse_json(connection.post('/commit',
                                                   options,
                                                   :body => config.to_json))
    Docker::Image.send(:new, self.connection, hash)
  end

  # Return a String representation of the Container.
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

  # #start! and #kill! both perform the associated action and
  # return the Container. #start and #kill do the same,
  # but rescue from ServerErrors.
  [:start, :kill].each do |method|
    define_method(:"#{method}!") do |opts = {}|
      connection.post(path_for(method), {}, :body => opts.to_json)
      self
    end

    define_method(method) do |*args|
      begin; public_send(:"#{method}!", *args); rescue ServerError; self end
    end
  end

  # #stop! and #restart! both perform the associated action and
  # return the Container. #stop and #restart do the same,
  # but rescue from ServerErrors.
  [:stop, :restart].each do |method|
    define_method(:"#{method}!") do |opts = {}|
      timeout = opts.delete('timeout')
      query = {}
      query['t'] = timeout if timeout
      connection.post(path_for(method), query, :body => opts.to_json)
      self
    end

    define_method(method) do |*args|
      begin; public_send(:"#{method}!", *args); rescue ServerError; self end
    end
  end

  # remove container
  def remove(options = {})
    connection.delete("/containers/#{self.id}", options)
    nil
  end
  alias_method :delete, :remove

  def copy(path, &block)
    connection.post(path_for(:copy), {},
      :body => { "Resource" => path }.to_json,
      :response_block => block
    )
    self
  end

  # Create a new Container.
  def self.create(opts = {}, conn = Docker.connection)
    name = opts.delete('name')
    query = {}
    query['name'] = name if name
    resp = conn.post('/containers/create', query, :body => opts.to_json)
    hash = Docker::Util.parse_json(resp) || {}
    new(conn, hash)
  end

  # Return the container with specified ID
  def self.get(id, opts = {}, conn = Docker.connection)
    container_json = conn.get("/containers/#{URI.encode(id)}/json", opts)
    hash = Docker::Util.parse_json(container_json) || {}
    new(conn, hash)
  end

  # Return all of the Containers.
  def self.all(opts = {}, conn = Docker.connection)
    hashes = Docker::Util.parse_json(conn.get('/containers/json', opts)) || []
    hashes.map { |hash| new(conn, hash) }
  end

  # Convenience method to return the path for a particular resource.
  def path_for(resource)
    "/containers/#{self.id}/#{resource}"
  end

  # Method that takes chunks and calls the attached block for each mux'd message
  def attach_for(block, msg_stack)
    messages = Docker::Messages.new
    lambda do |c,r,t|
      messages = messages.decipher_messages(c)
      msg_stack.append(messages)

      unless block.nil?
        messages.stdout_messages.each do |msg|
          block.call(:stdout, msg)
        end
        messages.stderr_messages.each do |msg|
          block.call(:stderr, msg)
        end
      end
    end
  end

  private :path_for, :attach_for
  private_class_method :new
end
