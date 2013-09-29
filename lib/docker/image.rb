# This class represents a Docker Image.
class Docker::Image
  include Docker::Error

  attr_accessor :id, :connection, :info

  # The private new method accepts a connection and optional id.
  def initialize(connection, id = nil, info = {})
    if connection.is_a?(Docker::Connection)
      @connection, @id, @info = connection, id, info
    else
      raise ArgumentError, "Expected a Docker::Connection, got: #{connection}."
    end
  end

  # Given a command and optional list of streams to attach to, run a command on
  # an Image. This will not modify the Image, but rather create a new Container
  # to run the Image.
  def run(cmd)
    cmd = cmd.split(/\s+/) if cmd.is_a?(String)
    Docker::Container.create({ 'Image' => self.id, 'Cmd' => cmd }, connection)
                     .tap(&:start!)
  end

  # Push the Image to the Docker registry.
  def push(options = {})
    connection.post(path_for(:push), options, :body => Docker.creds)
    self
  end

  # Tag the Image.
  def tag(opts = {})
    Docker::Util.parse_json(connection.post(path_for(:tag), opts))
  end

  # Insert a file into the Image, returns a new Image that has that file.
  def insert(query = {})
    body = connection.post(path_for(:insert), query)
    if (id = body.match(/{"Id":"([a-f0-9]+)"}\z/)).nil? || id[1].empty?
      raise UnexpectedResponseError, "Could not find Id in '#{body}'"
    else
      self.class.send(:new, connection, id[1])
    end
  end

  # Given a path of a local file and the path it should be inserted, creates
  # a new Image that has that file.
  def insert_local(opts = {})
    local_paths = opts.delete('localPath')
    output_path = opts.delete('outputPath')

    local_paths = [ local_paths ] unless local_paths.is_a?(Array)

    file_hash = Docker::Util.file_hash_from_paths(local_paths)

    file_hash['Dockerfile'] = dockerfile_for(file_hash, output_path)

    tar = Docker::Util.create_tar(file_hash)
    body = connection.post('/build', {}, :body => tar)
    self.class.send(:new, connection, Docker::Util.extract_id(body))
  end

  # Remove the Image from the server.
  def remove
    connection.delete("/images/#{self.id}")
  end

  # Return a String representation of the Image.
  def to_s
    "Docker::Image { :id => #{self.id}, :info => #{self.info.inspect}, "\
      ":connection => #{self.connection} }"
  end

  # #json returns extra information about an Image, #history returns its
  # history.
  [:json, :history].each do |method|
    define_method(method) do |opts = {}|
      Docker::Util.parse_json(connection.get(path_for(method), opts))
    end
  end

  class << self
    include Docker::Error

    # Create a new Image.
    def create(opts = {}, conn = Docker.connection)
      instance = new(conn)
      conn.post('/images/create', opts)
      id = opts['repo'] ? "#{opts['repo']}/#{opts['tag']}" : opts['fromImage']
      if (instance.id = id).nil?
        raise UnexpectedResponseError, 'Create response did not contain an Id'
      else
        instance
      end
    end

    # Return every Image.
    def all(opts = {}, conn = Docker.connection)
      hashes = Docker::Util.parse_json(conn.get('/images/json', opts)) || []
      hashes.map { |hash| new(conn, hash['Id'], hash.tap{|h| h.delete('Id')}) }
    end

    # Given a query like `{ :term => 'sshd' }`, queries the Docker Registry for
    # a corresponding Image.
    def search(query = {}, connection = Docker.connection)
      body = connection.get('/images/search', query)
      hashes = Docker::Util.parse_json(body) || []
      hashes.map { |hash| new(connection, hash['Name']) }
    end

    # Import an Image from the output of Docker::Container#export.
    def import(file, options = {}, connection = Docker.connection)
      File.open(file, 'r') do |io|
        body = connection.post(
          '/images/create',
           options.merge('fromSrc' => '-'),
           :headers => { 'Content-Type' => 'application/tar',
                         'Transfer-Encoding' => 'chunked' }
        ) { io.read(Excon.defaults[:chunk_size]).to_s }
        new(connection, Docker::Util.parse_json(body)['status'])
      end
    end

    # Given a Dockerfile as a string, builds an Image.
    def build(commands, connection = Docker.connection)
      body = connection.post(
        '/build', {},
        :body => Docker::Util.create_tar('Dockerfile' => commands)
      )
      new(connection, Docker::Util.extract_id(body))
    end

    # Given a directory that contains a Dockerfile, builds an Image.
    def build_from_dir(dir, connection = Docker.connection)
      tar = Docker::Util.create_dir_tar(dir)
      body = connection.post(
        '/build', {},
        :headers => { 'Content-Type'      => 'application/tar',
                      'Transfer-Encoding' => 'chunked' }
      ) { tar.read(Excon.defaults[:chunk_size]).to_s }
      new(connection, Docker::Util.extract_id(body))
    ensure
      tar.close unless tar.nil?
    end
  end

  private

  # Convenience method to return the path for a particular resource.
  def path_for(resource)
    "/images/#{self.id}/#{resource}"
  end


  # Convience method to get the Dockerfile for a file hash and a path to
  # output to.
  def dockerfile_for(file_hash, output_path)
    dockerfile = "from #{self.id}\n"

    file_hash.keys.each do |basename|
      dockerfile << "add #{basename} #{output_path}\n"
    end

    dockerfile
  end
end
