# This class represents a Docker Image.
class Docker::Image
  include Docker::Error

  attr_accessor :id, :connection, :repository, :repotag, :created, :size, :virtual_size

  # The private new method accepts a connection and optional id.
  def initialize(connection, id = nil, repository = nil, repotag = nil, created = nil, size = nil, virtual_size = nil)
    if connection.is_a?(Docker::Connection)
      @repotag, @repository, @id, @connection = repotag, repository, id, connection
      @created, @size, @virtual_size = created, size, virtual_size
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
  # Opts  :
  #   "repo"
  #   "tag"
  def tag(opts = {})
    if opts[:repo].nil?
      raise ArgumentError,
        "Expected a repository as repo argument (i.e. ubuntu)"
    end

    Docker::Util.parse_json(connection.post(path_for(:tag), opts))

    self.repository = opts[:repo]
    self.repotag = opts[:tag]
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

  # Remove the Image from the server.
  def remove
    param = self.id
    unless self.repository.nil?
      param = self.repository
      unless self.repotag.nil?
        param = "#{self.repository}:#{self.repotag}"
      end
    end
    connection.delete("/images/#{param}")
  end

  # Return a String representation of the Image.
  def to_s
    "Docker::Image { :id => #{self.id}, " +
      (self.repository.nil?   ? "" : ":repository => #{self.repository}, "    ) +
      (self.repotag.nil?      ? "" : ":repotag => #{self.repotag}, "          ) +
      (self.created.nil?      ? "" : ":created => #{self.created}, "          ) +
      (self.size.nil?         ? "" : ":size => #{self.size}, "                ) +
      (self.virtual_size.nil? ? "" : ":virtual_size => #{self.virtual_size}, ") +
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
      body = conn.post('/images/create', opts)
      instance.id = extract_id_from_create(body)

      if opts['fromImage']
        split_image = opts['fromImage'].split(":")
        instance.repository = split_image[0]
        instance.repotag = split_image[1]
      else
        instance.repository = opts['repo']
        instance.repotag = opts['tag']
      end

      if instance.id.nil?
        raise UnexpectedResponseError, 'Create response did not contain an Id'
      else
        instance
      end
    end

    # Return every Image.
    def all(opts = {}, conn = Docker.connection)
      hashes = Docker::Util.parse_json(conn.get('/images/json', opts)) || []
      hashes.map do |hash|
        new(conn, hash['Id'], hash['Repository'], hash['Tag'], hash['Created'], hash['Size'], hash['VirtualSize'] )
      end
    end

    # Given a query like `{ :term => 'sshd' }`, queries the Docker Registry for
    # a corresponding Image.
    def search(query = {}, connection = Docker.connection)
      body = connection.get('/images/search', query)
      hashes = Docker::Util.parse_json(body) || []
      hashes.map { |hash| new(connection, nil, hash['Name']) }
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
        # TODO repository/tag option
        new(connection, Docker::Util.parse_json(body)['status'])
      end
    end

    # Given a Dockerfile as a string, builds an Image.
    def build(commands, repository = nil, connection = Docker.connection)
      params = {"q" => true}
      repo = repotag = nil
      if repository
        params.merge!({"t" => repository})
        repo, repotag = split_repo(repository)
      end

      body = connection.post("/build", params , :body => create_tar(commands))

      new(connection, extract_id(body), repo, repotag)
    end

    # Given a directory that contains a Dockerfile, builds an Image.
    def build_from_dir(dir, repository = nil, connection = Docker.connection)
      params = {"q" => true}
      repo = repotag = nil
      if repository
        params.merge!({"t" => repository})
        repo, repotag = split_repo(repository)
      end
      tar = create_dir_tar(dir)
      body = connection.post(
        '/build', params,
        :headers => { 'Content-Type'      => 'application/tar',
                      'Transfer-Encoding' => 'chunked' }
      ) { tar.read(Excon.defaults[:chunk_size]).to_s }
      new(connection, extract_id(body), repo, repotag)
    ensure
      tar.close unless tar.nil?
    end

    def split_repo(repo)
      return "", "" if repo.nil?
      split = repo.split(":")
      return split[0], split[1]
    end
  private
    def extract_id_from_create(body)
      images = body.split("Pulling image ")
      if images.length != 0
        return images.last.split(" ").first
      else
        raise UnexpectedResponseError, "Couldn't find id: #{body}"
      end
    end

    def extract_id(body)
      line = body.lines.to_a[-1]
      if (id = line.match(/^Successfully built ([a-f0-9]+)$/)) && !id[1].empty?
        id[1]
      else
        raise UnexpectedResponseError, "Couldn't find id: #{body}"
      end
    end

    def create_tar(input)
      output = StringIO.new
      Gem::Package::TarWriter.new(output) do |tar|
        tar.add_file('Dockerfile', 0640) { |tar_file| tar_file.write(input) }
      end
      output.tap(&:rewind)
    end

    def create_dir_tar(directory)
      cwd = FileUtils.pwd
      tempfile = File.new('/tmp/out', 'wb')
      FileUtils.cd(directory)
      Archive::Tar::Minitar.pack('.', tempfile)
      File.new('/tmp/out', 'r')
    ensure
      FileUtils.cd(cwd)
    end
  end

  # Convenience method to return the path for a particular resource.
  def path_for(resource)
    "/images/#{self.id}/#{resource}"
  end

  private :path_for
end
