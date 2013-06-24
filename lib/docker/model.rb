# This module is intended to be used as a Mixin for all objects exposed by the
# Remote API. Currently, these are limited to Containers and Images.
module Docker::Model
  attr_reader :id, :connection

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Creates a new Model with the specified id and Connection. If a Connection
  # is specified and it is not a Docker::Connection, a
  # Docker::Error::ArgumentError is raised.
  def initialize(options = {})
    options[:connection] ||= Docker.connection
    unless options[:connection].is_a?(Docker::Connection)
      raise Docker::Error::ArgumentError, "Expected a Docker::Connection."
    end
    self.id = options[:id]
    self.connection = options[:connection]
  end

  # Create a Model with the specified body. Raises A Docker::Error::StateError
  # if the model already exists, and a Docker::Error::ArgumentError if the
  # argument is not a Hash. Otherwise, instances exec the Class's
  # #create_request method with the single argument.
  def create!(options = {}, excon_options = {})
    case
    when self.created?
      raise Docker::Error::StateError, "This #{self.class.name} already exists!"
    when !options.is_a?(Hash)
      raise Docker::Error::ArgumentError, 'Expected a Hash'
    else
      instance_exec(options, excon_options, &self.class.create_request)
    end
  end

  # Returns true if the Container has been created, false otherwise.
  def created?
    !!self.id
  end

  def to_s
    "#{self.class.name} { :id => #{id}, :connection => #{connection} }"
  end

  # This defines the DSL for the including Classes.
  module ClassMethods
    # Define the Model's prefix for all requests.
    def resource_prefix(val = nil)
      val.nil? ? @resource_prefix : (@resource_prefix = val)
    end

    # Define how the Model should send a create request to the server.
    def create_request(&block)
      block.nil? ? @create_request : (@create_request = block)
    end

    # Define a method named `action` that sends an http `method` request to the
    # Docker Server.
    def docker_request(action, method, &outer_block)
      define_method(action) do |query = nil, &block|
        ensure_created!
        path = "#{self.class.resource_prefix}/#{self.id}/#{action}"
        body = self.connection.json_request(method, path, query, &block)
        outer_block.nil? ? body : instance_exec(body, &outer_block)
      end
    end

    # Retrieve every Instance of a model for the given server.
    def all(options = {}, connection = Docker.connection)
      path = "#{self.resource_prefix}/json"
      hashes = connection.json_request(:get, path, options) || []
      hashes.map { |hash| new(:id => hash['Id'], :connection => connection) }
    end
  end

private
  attr_writer :id, :connection

  # Raises an error unless the Model is created.
  def ensure_created!
    unless created?
      raise Docker::Error::StateError, "This #{self.class.name} is not created."
    end
  end
end
