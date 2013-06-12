require 'rest_client'
require 'active_support/core_ext'

# The top-level module for this gem. It's purpose is to hold global
# configuration variables that are used as defaults in other classes.
module Docker
  class << self
    def host
      @host ||= 'localhost'
    end

    def port
      @port ||= 4243
    end

    def host=(new_host)
      reset_connection!
      @host = new_host
    end

    def port=(new_port)
      reset_connection!
      @port = new_port
    end

    def connection
      @connection ||= Connection.new(:host => host, :port => port)
    end

    def reset_connection!
      @connection = nil
    end
  end
end

require 'docker/version'
require 'docker/error'
require 'docker/connection'
