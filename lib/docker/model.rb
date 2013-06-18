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
  def create!(options = {})
    case
    when self.created?
      raise Docker::Error::StateError, "This #{self.class.name} already exists!"
    when !options.is_a?(Hash)
      raise Docker::Error::ArgumentError, 'Expected a Hash'
    else
      instance_exec(options, &self.class.create_request)
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
        params = compile_request_params(action, method, query, &block)
        body = self.connection.request(params).body
        unless body.nil? || body.empty? || (body == 'null')
          body = JSON.parse(body)
        end
        outer_block.nil? ? body : instance_exec(body, &outer_block)
      end
    end

  private
  end

private
  attr_writer :id, :connection

  # Raises an error unless the Model is created.
  def ensure_created!
    unless created?
      raise Docker::Error::StateError, "This #{self.class.name} is not created."
    end
  end

  # Create a query string from a Hash.
  def hash_to_params(hash)
    hash.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
  end

  # Given a name, http_method, query, and optional block, returns the
  # corresponding request parameters.
  def compile_request_params(name, http_method, query, &block)
    {
      :method  => http_method,
      :path    => "#{self.class.resource_prefix}/#{self.id}/#{name}",
      :query   => query,
      :headers => { 'Content-Type' => 'application/json' },
      :expects => (200..204),
      :response_block => block
    }.reject { |_, v| v.nil? }
  end
end
