# This class represents a Docker Image.
class Docker::Image
  include Docker::Model
  include Docker::Error
  include Docker::Multipart

  resource_prefix '/images'

  create_request do |options, excon_options|
    options['fromSrc'] ||= '-'
    body = self.connection.post(excon_options.merge(
      :path    => '/images/create',
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => "Docker-Client/1.2" },
      :query   => options,
      :expects => (200..204)
    )).body
    self.id = JSON.parse(body)['status']
    self
  end

  # Tag the Image.
  docker_request :tag, :post
  # Get more information about the Image.
  docker_request :json, :get
  # Get the history of the Image.
  docker_request :history, :get

  # Push the Image to the Docker registry.
  def push(options = {})
    ensure_created!
    self.connection.post(
      :path    => "/images/#{self.id}/push",
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => "Docker-Client/1.2" },
      :query   => options,
      :body    => Docker.creds,
      :expects => (200..204)
    )
    true
  end

  # Insert a file into the Image, returns a new Image that has that file.
  def insert(query = {})
    ensure_created!
    body = self.connection.post(
      :path    => "/images/#{self.id}/insert",
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => "Docker-Client/1.2" },
      :query   => query,
      :expects => (200..204)
    ).body
    if (id = body.match(/{"Id":"([a-f0-9]+)"}\z/)).nil? || id[1].empty?
      raise UnexpectedResponseError, "Could not find Id in '#{body}'"
    else
      Docker::Image.new(:id => id[1], :connection => self.connection)
    end
  end

  # Remove the Image from the server.
  def remove
    ensure_created!
    self.connection.json_request(:delete, "/images/#{self.id}", nil)
    self.id = nil
    true
  end

  # Given a Docker export and optional Hash of options, creates a new Image.
  def create_from_file(file, options = {})
    File.open(file, 'r') do |f|
      read_chunked = lambda { f.read(Excon.defaults[:chunk_size]).to_s }
      self.create!(options, :request_block => read_chunked)
    end
  end

  class << self
    include Docker::Error
    include Docker::Multipart

    # Given a query like `{ :term => 'sshd' }`, queries the Docker Registry for
    # a corresponiding Image.
    def search(query = {}, connection = Docker.connection)
      hashes = connection.json_request(:get, '/images/search', query) || []
      hashes.map { |hash| new(:id => hash['Name'], :connection => connection) }
    end

    # Given a Dockerfile as a string, builds an Image.
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
