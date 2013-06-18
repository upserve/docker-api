# This class represents a Docker Container. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Container
  include Docker::Model

  resource_prefix '/containers'

  create_request do |body|
    response = self.connection.post(
      :path    => '/containers/create',
      :headers => { 'Content-Type' => 'application/json' },
      :body    => body.to_json,
      :expects => (200..204)
    )
    self.id = JSON.parse(response.body)['Id']
    self
  end

  docker_request :export, :get
  docker_request :attach, :post
  docker_request :json, :get
  docker_request :wait, :post
  docker_request :start, :post
  docker_request :changes, :get
  docker_request :stop, :post
  docker_request :kill, :post
  docker_request :restart, :post

  def self.all(options = {}, connection = Docker.connection)
    response = connection.get(
      :path    => '/containers/json',
      :headers => { 'Content-Type' =>  'application/json' },
      :query   => options,
      :expects => (200..204)
    )
    JSON.parse(response.body).map { |container_hash|
      new(:id => container_hash['Id'], :connection => connection)
    }
  end
end
