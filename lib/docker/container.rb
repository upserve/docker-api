# This class represents a Docker Container. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Container
  include Docker::Model
  include Docker::Error

  set_resource_prefix '/containers'

  set_create_request do |body|
    response = connection.post('/containers/create', nil, :body => body.to_json)
    @id = Docker::Util.parse_json(response)['Id']
    self
  end

  # Get more information about the Container.
  request :get, :json
  # Start the Container.
  request :post, :start
  # Inspect the Container's changes to the filesysetem
  request :get, :changes
  # Stop the Container.
  request :post, :stop
  # Kill the Container.
  request :post, :kill
  # Restart the Container
  request :post, :restart

  # For each method, `m`, define a method called `m?` that attempts the method,
  # but catches all Server errors.
  [:stop, :start, :kill, :restart].each do |method|
    define_method :"#{method}?" do |*args|
      begin; public_send(method, *args); rescue ServerError; end
    end
  end

  # Wait for the current command to finish executing.
  def wait(time = 60)
    resp = connection.post("/containers/#{id}/wait", nil, :read_timeout => time)
    Docker::Util.parse_json(resp)
  end

  # Given a command and an optional number of seconds to wait for the currently
  # executing command, creates a new Container to run the specified command. If
  # the command that is currently executing does not return a 0 status code, an
  # UnexpectedResponseError is raised.
  def run(cmd, time = 1000)
    if (code = tap(&:start?).wait(time)['StatusCode']).zero?
      commit.run(cmd).tap(&:start?)
    else
      raise UnexpectedResponseError, "Command returned status code #{code}."
    end
  end

  # Export the Container as a tar.
  def export(&block)
    connection.get("/containers/#{id}/export", nil, :response_block => block)
    true
  end

  # Attach to a container's standard streams / logs.
  def attach(options = {}, &block)
    options = { :stream => true, :stdout => true }.merge(options)
    connection.post("/containers/#{id}/attach", options,
                    :response_block => block)
  end

  # Create an Image from a Container's change.s
  def commit(options = {})
    options.merge!('container' => self.id[0..7])
    hash = Docker::Util.parse_json(connection.post('/commit', options))
    Docker::Image.send(:new, :id => hash['Id'], :connection => self.connection)
  end
end
