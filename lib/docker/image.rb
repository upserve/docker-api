# This class represents a Docker Image.
class Docker::Image
  include Docker::Model
  include Docker::Error

  VALID_OPTIONS = [:id, :repository, :tag, :created, :size, :virtual_size]
  attr_reader *VALID_OPTIONS

  set_resource_prefix '/images'

  set_create_request do |options|
    body = connection.post('/images/create', options)
    @id = Docker::Util.parse_json(body)['status'] rescue nil
    @id ||= options['fromImage']
    @id ||= "#{options['repo']}/#{options['tag']}"
    self
  end

  # Tag the Image.
  request :post, :tag!
  # Get more information about the Image.
  request :get, :json
  # Get the history of the Image.
  request :get, :history

  # Given a command and optional list of streams to attach to, run a command on
  # an Image. This will not modify the Image, but rather create a new Container
  # to run the Image.
  def run(cmd)
    cmd = cmd.split(/\s+/) if cmd.is_a?(String)
    Docker::Container.create({ 'Image' => self.id, 'Cmd' => cmd }, connection)
                     .tap(&:start)
  end

  # Push the Image to the Docker registry.
  def push(options = {})
    connection.post("/images/#{self.id}/push", options, :body => Docker.creds)
    true
  end

  # Insert a file into the Image, returns a new Image that has that file.
  def insert(query = {})
    body = connection.post("/images/#{self.id}/insert", query)
    if (id = body.match(/{"Id":"([a-f0-9]+)"}\z/)).nil? || id[1].empty?
      raise UnexpectedResponseError, "Could not find Id in '#{body}'"
    else
      self.class.send(:new, :id => id[1], :connection => self.connection)
    end
  end

  # Remove the Image from the server.
  def remove
    connection.delete("/images/#{self.id}")
  end

  class << self
    include Docker::Error

    # Given a query like `{ :term => 'sshd' }`, queries the Docker Registry for
    # a corresponiding Image.
    def search(query = {}, connection = Docker.connection)
      body = connection.get('/images/search', query)
      hashes = Docker::Util.parse_json(body) || []
      hashes.map { |hash| new(:id => hash[:name], :connection => connection) }
    end

    # Import an Image from the output of Docker::Container#export.
    def import(file, options = {}, connection = Docker.connection)
      File.open(file, 'r') do |io|
        body = connection.post(
          '/images/create',
           options.merge('fromSrc' => '-'),
           :headers => { 'Transfer-Encoding' => 'chunked' }
        ) { io.read(Excon.defaults[:chunk_size]).to_s }
        new(:id => Docker::Util.parse_json(body)[:status],
            :connection => connection)
      end
    end

    # Given a Dockerfile as a string, builds an Image.
    def build(commands, connection = Docker.connection, &block)
      build_request(connection, :body => create_tar(commands), &block)
    end

    # Given a directory that contains a Dockerfile, builds an Image.
    def build_from_dir(dir, connection = Docker.connection, &block)
      tar = create_dir_tar(dir)
      build_request(
        connection,
        :headers => { 'Content-Type'      => 'application/tar',
                      'Transfer-Encoding' => 'chunked' },
        :request_block => lambda { tar.read(Excon.defaults[:chunk_size]).to_s },
        &block
      )
    ensure
      tar.close
    end

  private
    def extract_id(body)
      line = body.lines.to_a[-1]
      if (id = line.match(/^Successfully built ([a-f0-9]+)$/)) && !id[1].empty?
        id[1]
      else
        nil
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
      tempfile = File.new('/tmp/out', 'w')
      FileUtils.cd(directory)
      Archive::Tar::Minitar.pack('.', tempfile)
      File.new('/tmp/out', 'r')
    ensure
      FileUtils.cd(cwd)
    end

    def build_request(connection, opts = {}, &block)
      image = nil
      response_block = lambda do |line, _, _|
        if extract_id(line)
          image = new(:id => extract_id(line), :connection => connection)
        end
        yield(line) if block_given?
      end
      opts[:response_block] = response_block
      connection.post('/build', {}, opts, &opts[:request_block])
      image
    end
  end
end
