# This module is intended to be used as a Mixin for all objects exposed by the
# Remote API. Currently, these are limited to Containers and Images.
module Docker::Model
  include Docker::Error

  attr_reader :id, :connection

  def self.included(base)
    base.class_eval do
      extend ClassMethods
      private_class_method :new, :request, :set_create_request,
                           :set_resource_prefix
    end
  end

  # Creates a new Model with the specified id and Connection. If a Connection
  # is specified and it is not a Docker::Connection, a
  # Docker::Error::ArgumentError is raised.
  def initialize(options = {})
    if (options[:connection] ||= Docker.connection).is_a?(Docker::Connection)
      @id, @connection = options[:id], options[:connection]
    else
      raise ArgumentError, 'Expected a Docker::Connection.'
    end
  end

  def to_s
    "#{self.class.name} { :id => #{id}, :connection => #{connection} }"
  end

  # This defines the DSL for the including Classes.
  module ClassMethods
    include Docker::Error
    attr_reader :resource_prefix, :create_request

    # Define the Model's prefix for all requests.
    def set_resource_prefix(val)
      @resource_prefix = val
    end

    # Define how the Model should send a create request to the server.
    def set_create_request(&block)
      @create_request = block
    end

    # Define a method named `action` that sends an http `method` request to the
    # Docker Server.
    def request(method, action, opts = {}, &outer_block)
      define_method(action) do |query = nil, &block|
        new_opts = {
          :path => "#{self.class.resource_prefix}/#{self.id}/#{action}",
          :json => true
        }.merge(opts)
        body = connection.request(method, new_opts[:path], query,
                                  new_opts[:excon], &block)
        body = Docker::Util.parse_json(body) if new_opts[:json]
        outer_block.nil? ? body : instance_exec(body, &outer_block)
      end
    end

    # Create a Model with the specified body. Raises a
    # Docker::Error::ArgumentError if the argument is not a Hash. Otherwise,
    # instances execs the Class's #create_request method with the single
    # argument.
    def create(opts = {}, conn = Docker.connection)
      raise Docker::Error::ArgumentError, 'Expected a Hash' if !opts.is_a?(Hash)
      new(:connection => conn).instance_exec(opts, &create_request)
    end

    # Retrieve every Instance of a model for the given server.
    def all(options = {}, connection = Docker.connection)
      path = "#{resource_prefix}/json"
      hashes = Docker::Util.parse_json(connection.get(path, options)) || []
      hashes.map { |hash| new(:id => hash['Id'], :connection => connection) }
    end
  end
end
