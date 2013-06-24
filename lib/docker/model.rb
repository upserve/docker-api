# This module is intended to be used as a Mixin for all objects exposed by the
# Remote API. Currently, these are limited to Containers and Images.
module Docker::Model
  include Docker::Error

  attr_reader :id, :connection

  def self.included(base)
    base.class_eval do
      extend ClassMethods
      private_class_method :new, :request, :get, :put, :post, :delete,
                           :create_request, :resource_prefix
    end
  end

  # Creates a new Model with the specified id and Connection. If a Connection
  # is specified and it is not a Docker::Connection, a
  # Docker::Error::ArgumentError is raised.
  def initialize(options = {})
    options[:connection] ||= Docker.connection
    if !options[:connection].is_a?(Docker::Connection)
      raise ArgumentError, 'Expected a Docker::Connection.'
    else
      @id = options[:id]
      @connection = options[:connection]
    end
  end

  def to_s
    "#{self.class.name} { :id => #{id}, :connection => #{connection} }"
  end

  # This defines the DSL for the including Classes.
  module ClassMethods
    include Docker::Error

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
    def request(method, action, opts = {}, &outer_block)
      define_method(action) do |query = nil, &block|
        path = opts[:path]
        path ||= "#{self.class.send(:resource_prefix)}/#{self.id}/#{action}"
        body = self.connection.json_request(method, path, query, &block)
        outer_block.nil? ? body : instance_exec(body, &outer_block)
      end
    end

    [:get, :put, :post, :delete].each do |method|
      define_method(method) { |*args, &block| request(method, *args, &block) }
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
      hashes = connection.json_request(:get, path, options) || []
      hashes.map { |hash| new(:id => hash['Id'], :connection => connection) }
    end
  end
end
