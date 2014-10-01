require 'cgi'
require 'json'
require 'excon'
require 'tempfile'
require 'base64'
require 'rubygems/package'
require 'archive/tar/minitar'
require 'uri'
require 'open-uri'

# Add the Hijack middleware at the top of the middleware stack so it can
# potentially hijack HTTP sockets (when attaching to stdin) before other
# middlewares try and parse the response.
require 'excon/middlewares/hijack'
Excon.defaults[:middlewares].unshift Excon::Middleware::Hijack

# The top-level module for this gem. It's purpose is to hold global
# configuration variables that are used as defaults in other classes.
module Docker
  attr_accessor :creds, :logger

  require 'docker/error'
  require 'docker/connection'
  require 'docker/base'
  require 'docker/container'
  require 'docker/event'
  require 'docker/image'
  require 'docker/messages'
  require 'docker/util'
  require 'docker/version'
  require 'docker/rake_task' if defined?(Rake::Task)

  def default_socket_url
    'unix:///var/run/docker.sock'
  end

  def env_url
    ENV['DOCKER_URL']
  end

  def url
    @url ||= ENV['DOCKER_URL'] || ENV['DOCKER_HOST'] || default_socket_url
    # docker uses a default notation tcp:// which means tcp://localhost:2375
    if @url == 'tcp://'
      @url = 'tcp://localhost:2375'
    end
    @url
  end

  def options
    @options ||= {}
  end

  def url=(new_url)
    @url = new_url
    reset_connection!
  end

  def options=(new_options)
    @options = new_options
    reset_connection!
  end

  def connection
    @connection ||= Connection.new(url, options)
  end

  def reset_connection!
    @connection = nil
  end

  # Get the version of Go, Docker, and optionally the Git commit.
  def version(connection = self.connection)
    Util.parse_json(connection.get('/version'))
  end

  # Get more information about the Docker server.
  def info(connection = self.connection)
    Util.parse_json(connection.get('/info'))
  end

  # Login to the Docker registry.
  def authenticate!(options = {}, connection = connection)
    creds = options.to_json
    connection.post('/auth', {}, :body => creds)
    @creds = creds
    true
  rescue Docker::Error::ServerError, Docker::Error::UnauthorizedError
    raise Docker::Error::AuthenticationError
  end

  # When the correct version of Docker is installed, returns true. Otherwise,
  # raises a VersionError.
  def validate_version!
    Docker.info
    true
  rescue Docker::Error::DockerError
    raise Docker::Error::VersionError, "Expected API Version: #{API_VERSION}"
  end

  module_function :default_socket_url, :env_url, :url, :url=, :options,
                  :options=, :creds, :creds=, :logger, :logger=,
                  :connection, :reset_connection!, :version, :info,
                  :authenticate!, :validate_version!
end
