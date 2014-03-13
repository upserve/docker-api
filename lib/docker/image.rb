# This class represents a Docker Image.
class Docker::Image < Docker::Base

  # Given a command and optional list of streams to attach to, run a command on
  # an Image. This will not modify the Image, but rather create a new Container
  # to run the Image. If the image has an embedded config, no command is
  # necessary, but it will fail with 500 if no config is saved with the image
  def run(cmd=nil)
    opts = { 'Image' => self.id }
    opts["Cmd"] = cmd.is_a?(String) ? cmd.split(/\s+/) : cmd
    begin
      Docker::Container.create(opts, connection)
                       .tap(&:start!)
    rescue ServerError => ex
      if cmd
        raise ex
      else
        raise ServerError, "No command specified."
      end
    end
  end

  # Push the Image to the Docker registry.
  def push(creds = nil, options = {})
    repository = self.info['RepoTags'].first.match(/(.+):(.+)/) rescue nil

    raise ArgumentError, "Image does not have a name to push." unless repository

    credentials = creds || Docker.creds
    headers = Docker::Util.build_auth_header(credentials)
    connection.post(
      "/images/#{repository[1]}/push",
      options,
      :headers => headers
    )
    self
  end

  # Tag the Image.
  def tag(opts = {})
    self.info['RepoTags'] ||= []
    connection.post(path_for(:tag), opts)
    repo = opts['repo'] || opts[:repo]
    tag = opts['tag'] || opts[:tag] || 'latest'
    self.info['RepoTags'] << "#{repo}:#{tag}"
  end

  # Insert a file into the Image, returns a new Image that has that file.
  def insert(query = {})
    body = connection.post(path_for(:insert), query)
    if id = Docker::Util.fix_json(body).last['status']
      self.class.send(:new, connection, 'id' => id)
    else
      raise UnexpectedResponseError, "Could not find Id in '#{body}'"
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
    body = connection.post('/build', opts, :body => tar)
    self.class.send(:new, connection, 'id' => Docker::Util.extract_id(body))
  end

  # Remove the Image from the server.
  def remove(opts = {})
    connection.delete("/images/#{self.id}", opts)
  end
  alias_method :delete, :remove

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

    # Create a new Image.
    def create(opts = {}, creds = nil, conn = Docker.connection)
      credentials = (creds.nil?) ? creds.to_json : Docker.creds
      headers = if credentials.nil?
        Docker::Util.build_auth_header(credentials)
      else
        {}
      end
      body = conn.post('/images/create', opts)
      id = Docker::Util.fix_json(body).last['id']
      new(conn, 'id' => id, :headers => headers)
    end

    # Return a specific image.
    def get(id, opts = {}, conn = Docker.connection)
      image_json = conn.get("/images/#{URI.encode(id)}/json", opts)
      hash = Docker::Util.parse_json(image_json) || {}
      new(conn, hash)
    end

    # Return every Image.
    def all(opts = {}, conn = Docker.connection)
      hashes = Docker::Util.parse_json(conn.get('/images/json', opts)) || []
      hashes.map { |hash| new(conn, hash) }
    end

    # Given a query like `{ :term => 'sshd' }`, queries the Docker Registry for
    # a corresponding Image.
    def search(query = {}, connection = Docker.connection)
      body = connection.get('/images/search', query)
      hashes = Docker::Util.parse_json(body) || []
      hashes.map { |hash| new(connection, 'id' => hash['name']) }
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
        new(connection, 'id'=> Docker::Util.parse_json(body)['status'])
      end
    end

    # Given a Dockerfile as a string, builds an Image.
    def build(commands, opts = {}, connection = Docker.connection, &block)
      body = ""
      connection.post(
        '/build', opts,
        :body => Docker::Util.create_tar('Dockerfile' => commands),
        :response_block => response_block_for_build(body, &block)
      )
      new(connection, 'id' => Docker::Util.extract_id(body))
    rescue Docker::Error::ServerError
      raise Docker::Error::UnexpectedResponseError
    end

    # Given a directory that contains a Dockerfile, builds an Image.
    #
    # If a block is passed, chunks of output produced by Docker will be passed
    # to that block.
    def build_from_dir(dir, opts = {}, connection = Docker.connection, &block)
      tar = Docker::Util.create_dir_tar(dir)

      # The response_block passed to Excon will build up this body variable.
      body = ""
      connection.post(
        '/build', opts,
        :headers => { 'Content-Type'      => 'application/tar',
                      'Transfer-Encoding' => 'chunked' },
        :response_block => response_block_for_build(body, &block)
      ) { tar.read(Excon.defaults[:chunk_size]).to_s }
      new(connection, 'id' => Docker::Util.extract_id(body))
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

  # Generates the block to be passed as a reponse block to Excon. The returned
  # lambda will append Docker output to the first argument, and yield output to
  # the passed block, if a block is given.
  def self.response_block_for_build(body)
    lambda do |chunk, remaining, total|
      body << chunk
      yield chunk if block_given?
    end
  end
end
