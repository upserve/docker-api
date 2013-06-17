# This class represents a Docker Image.
class Docker::Image
  attr_reader :id, :connection

  def initialize(options = {})
    options[:connection] ||= Docker.connection
    unless options[:connection].is_a?(Docker::Connection)
      raise Docker::Error::ArgumentError, "Expected a Docker::Connection."
    end
    self.id = options[:id]
    self.connection = options[:connection]
  end

  def created?
    !!self.id
  end

  def create!(body = {})
    case
    when self.created?
      raise Docker::Error::ImageError, 'This Image already exists!'
    when !body.is_a?(Hash)
      raise Docker::Error::ArgumentError, 'Expected a Hash'
    else
      response = self.connection.post(
        :path    => '/images/create',
        :headers => { 'Content-Type' => 'application/json' },
        :body    => body.to_json,
        :expects => 201
      )
      self.id = JSON.parse(response.body)['Id']
      self
    end
  end

  def remove!
    ensure_created!
    self.connection.delete(
      :path => "/images/#{self.id}",
      :headers => { 'Content-Type' => 'application/json' },
      :expects => 204
    )
    self.id = nil
    true
  end

  {
    :tag => :post,
    :json => :get,
    :push => :post,
    :insert => :post,
    :history => :get,
  }.each do |method, http_method|
    define_method(method) do |query = {}|
      ensure_created!
      body = connection.request(
        :method  => http_method,
        :path    => "/images/#{self.id}/#{method}",
        :query   => query,
        :headers => { 'Content-Type' => 'application/json' },
        :expects => [200, 204]
      ).body
      JSON.parse(body) unless body.nil? || body.empty?
    end
  end

  def to_s
    "Docker::Image { :id => #{self.id}, :connection => #{self.connection} }"
  end

  class << self
    {
      :all => 'json',
      :search => 'search'
    }.each do |method, resource|
      define_method(method) do |options = {}, connection = Docker.connection|
        body = connection.get(
          :path    => "/images/#{resource}",
          :headers => { 'Content-Type' =>  'application/json' },
          :query   => options,
          :expects => 200
        ).body
        ((body.nil? || body.empty?) ? [] : JSON.parse(body)).map { |image_hash|
          new(:id => image_hash['Id'], :connection => connection)
        }
      end
    end
  end
private
  attr_writer :id, :connection

  def ensure_created!
    unless created?
      raise Docker::Error::ImageError, 'This Image is not created.'
    end
  end
end
