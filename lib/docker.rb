require 'json'
require 'excon'

# The top-level module for this gem. It's purpose is to hold global
# configuration variables that are used as defaults in other classes.
module Docker
  class << self
    def url
      @url ||= 'http://localhost'
    end

    def port
      @port ||= 4243
    end

    def url=(new_url)
      reset_connection!
      @url = new_url
    end

    def port=(new_port)
      reset_connection!
      @port = new_port
    end

    def connection
      @connection ||= Connection.new(:url => url, :port => port)
    end

    def reset_connection!
      @connection = nil
    end
  end
end

require 'docker/version'
require 'docker/error'
require 'docker/connection'
require 'docker/container'
