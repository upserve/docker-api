require 'cgi'
require 'json'
require 'excon'
require 'tempfile'
require 'rubygems/package'
require 'archive/tar/minitar'
require 'active_support/core_ext'

# The top-level module for this gem. It's purpose is to hold global
# configuration variables that are used as defaults in other classes.
module Docker
  autoload :Error, 'docker/error'
  autoload :Util, 'docker/util'
  autoload :Middleware, 'docker/middleware'
  autoload :Connection, 'docker/connection'
  autoload :Container, 'docker/container'
  autoload :Image, 'docker/image'

  attr_reader :creds

  def url
    @url ||= "http://#{ENV['DOCKER_HOST'] || 'localhost'}"
  end

  def options
    port = (ENV['DOCKER_PORT'].nil? ? 4243 : ENV['DOCKER_PORT']).to_i
    @options ||= { :port => port.to_i }
  end

  def url=(new_url)
    @url = new_url
    reset_connection!
  end

  def options=(new_options)
    @options = { :port => 4243 }.merge(new_options)
    reset_connection!
  end

  def connection
    @connection ||= Connection.new(url, options)
  end

  def reset_connection!
    @connection = nil
  end

  # Get the version of Go, Docker, and optionally the Git commit.
  def version
    Util.parse_json(connection.get('/version'))
  end

  # Get more information about the Docker server.
  def info
    Util.parse_json(connection.get('/info'))
  end

  # Login to the Docker registry.
  def authenticate!(options = {})
    @creds = options.to_json
    connection.post(:path => '/auth', :body => @creds)
    true
  end

  # When the correct version of Docker is installed, returns true. Otherwise,
  # raises a VersionError.
  def validate_version!
    Docker.info
    true
  rescue Docker::Error::DockerError
    raise Docker::Error::VersionError, "Expected API Version: #{API_VERSION}"
  end

  module_function :url, :url=, :options, :options=, :connection,
                  :reset_connection!, :version, :info, :authenticate!,
                  :validate_version!
end
