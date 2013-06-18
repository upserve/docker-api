# This module is intended to be used as a Mixin for all objects exposed by the
# Remote API. Currently, these are limited to Containers and Images.
module Docker::Model
  attr_reader :id, :connection

  def self.included(base)
    base.extend(ClassMethods)
  end

  def initialize(options = {})
    options[:connection] ||= Docker.connection
    unless options[:connection].is_a?(Docker::Connection)
      raise Docker::Error::ArgumentError, "Expected a Docker::Connection."
    end
    self.id = options[:id]
    self.connection = options[:connection]
  end

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

  def created?
    !!self.id
  end

  def to_s
    "#{self.class.name} { :id => #{id}, :connection => #{connection} }"
  end

  module ClassMethods
    def resource_prefix(val = nil)
      val.nil? ? @resource_prefix : (@resource_prefix = val)
    end

    def create_request(&block)
      block.nil? ? @create_request : (@create_request = block)
    end

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

  def ensure_created!
    unless created?
      raise Docker::Error::StateError, "This #{self.class.name} is not created."
    end
  end

  def hash_to_params(hash)
    hash.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
  end

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
