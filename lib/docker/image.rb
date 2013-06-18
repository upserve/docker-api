# This class represents a Docker Image.
class Docker::Image
  include Docker::Model
  resource_prefix '/images'

  create_request do |options|
    body = self.connection.post(
      :path    => '/images/create',
      :headers => { 'Content-Type' => 'application/x-www-form-urlencoded' },
      :body    => hash_to_params(options),
      :expects => (200..204)
    ).body
    self.id = JSON.parse(body)['status']
    self
  end

  docker_request :tag, :post
  docker_request :json, :get
  docker_request :push, :post
  docker_request :insert, :post
  docker_request :history, :get

  def remove
    ensure_created!
    self.connection.delete(
      :path => "/images/#{self.id}",
      :headers => { 'Content-Type' => 'application/json' },
      :expects => (200..204)
    )
    self.id = nil
    true
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
          :expects => (200..204)
        ).body
        ((body.nil? || body.empty?) ? [] : JSON.parse(body)).map { |image_hash|
          new(:id => image_hash['Id'] || image_hash['Name'],
              :connection => connection)
        }
      end
    end
  end
end
