require 'cgi'
require 'json'
require 'excon'
require 'tempfile'
require 'archive/tar/minitar'

# The top-level module for this gem. It's purpose is to hold global
# configuration variables that are used as defaults in other classes.
module Docker
  extend self

  attr_reader :creds

  def url
    @url ||= 'http://localhost'
  end

  def options
    @options ||= { :port => 4243 }
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
    connection.json_request(:get, '/version')
  end

  # Get more information about the Docker server.
  def info
    connection.json_request(:get, '/info')
  end

  # Login to the Docker registry.
  def authenticate!(options = {})
    @creds = options.to_json
    connection.post(:path => '/auth', :body => @creds)
    true
  end
end

require 'docker/version'
require 'docker/error'
require 'docker/connection'
require 'docker/model'
require 'docker/container'
require 'docker/image'
