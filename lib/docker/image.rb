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
    include Docker::Error

    def build(commands, connection = Docker.connection)
      host = URI.parse(connection.url).host
      res = Net::HTTP.start(host, connection.options[:port]) { |http|
        req = build_multipart_post('/build', "#{commands}\n",
                                   'application/octet-stream', 'Dockerfile')
        http.request(req)
      }
      if res.code == '200'
        self.new(:id => extract_id(res.body), :connection => connection)
      else
        raise UnexpectedResponseError, "Got status #{res.code}"
      end
    end

    def search(query = {}, connection = Docker.connection)
      body = connection.get(
        :path    => "/images/search",
        :headers => { 'Content-Type' =>  'application/json' },
        :query   => query,
        :expects => (200..204)
      ).body
      (body.nil? || body.empty? ? [] : JSON.parse(body)).map { |hash|
        new(:id => hash['Name'], :connection => connection)
      }
    end

  private
    def build_multipart_post(path, body, content_type, file_name)
      io = UploadIO.new(StringIO.new(body), content_type, file_name)
      Net::HTTP::Post::Multipart.new(path, file_name => io)
    end

    def extract_id(body)
      if match = body.lines.to_a[-1].match(/^===> ([a-f0-9]+)$/)
        match[1]
      else
        raise UnexpectedResponseError, "Couldn't find id: #{body}"
      end
    end
  end
end
