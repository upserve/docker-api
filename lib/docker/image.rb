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
    self.connection.json_request(:delete, "/images/#{self.id}", nil)
    self.id = nil
    true
  end

  # Create a query string from a Hash.
  def hash_to_params(hash)
    hash.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
  end
  private :hash_to_params

  class << self
    include Docker::Error
    include Docker::Multipart

    def search(query = {}, connection = Docker.connection)
      hashes = connection.json_request(:get, '/images/search', query) || []
      hashes.map { |hash| new(:id => hash['Name'], :connection => connection) }
    end

    def build(commands, connection = Docker.connection)
      body = multipart_request(
        '/build',
        'Dockerfile',
        StringIO.new("#{commands}\n"),
        connection
      )
      new(:id => extract_id(body), :connection => connection)
    end

  private
    def extract_id(body)
      if match = body.lines.to_a[-1].match(/^===> ([a-f0-9]+)$/)
        match[1]
      else
        raise UnexpectedResponseError, "Couldn't find id: #{body}"
      end
    end
  end
end
