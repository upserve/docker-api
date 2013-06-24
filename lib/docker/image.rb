# This class represents a Docker Image.
class Docker::Image
  include Docker::Model
  include Docker::Error

  resource_prefix '/images'

  create_request do |options|
    body = self.connection.post(
      :path    => '/images/create',
      :headers => { 'User-Agent' => 'Docker-Client/0.4.6' },
      :query   => options,
      :expects => (200..204)
    ).body
    @id = JSON.parse(body)['status'] rescue nil
    @id ||= options['fromImage']
    @id ||= "#{options['repo']}/#{options['tag']}"
    self
  end

  # Tag the Image.
  post :tag
  # Get more information about the Image.
  get :json
  # Get the history of the Image.
  get :history

  # Given a command and optional list of streams to attach to, run a command on
  # an Image. This will not modify the Image, but rather create a new Container
  # to run the Image.
  def run(cmd)
    cmd = cmd.split(/\s+/) if cmd.is_a?(String)
    Docker::Container.create({ 'Image' => self.id, 'Cmd' => cmd },
                             self.connection)
                     .tap(&:start)
  end

  # Push the Image to the Docker registry.
  def push(options = {})
    self.connection.post(
      :path    => "/images/#{self.id}/push",
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => 'Docker-Client/0.4.6' },
      :query   => options,
      :body    => Docker.creds,
      :expects => (200..204)
    )
    true
  end

  # Insert a file into the Image, returns a new Image that has that file.
  def insert(query = {})
    body = self.connection.post(
      :path    => "/images/#{self.id}/insert",
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => "Docker-Client/0.4.6" },
      :query   => query,
      :expects => (200..204)
    ).body
    if (id = body.match(/{"Id":"([a-f0-9]+)"}\z/)).nil? || id[1].empty?
      raise UnexpectedResponseError, "Could not find Id in '#{body}'"
    else
      self.class.send(:new, :id => id[1], :connection => self.connection)
    end
  end

  # Remove the Image from the server.
  def remove
    self.connection.json_request(:delete, "/images/#{self.id}", nil)
  end

  class << self
    include Docker::Error

    # Given a query like `{ :term => 'sshd' }`, queries the Docker Registry for
    # a corresponiding Image.
    def search(query = {}, connection = Docker.connection)
      hashes = connection.json_request(:get, '/images/search', query) || []
      hashes.map { |hash| new(:id => hash['Name'], :connection => connection) }
    end

    # Import an Image from the output of Docker::Container#export.
    def import(file, options = {}, connection = Docker.connection)
      File.open(file, 'r') do |io|
        body = connection.post(
          :path          => '/images/create',
          :headers       => { 'User-Agent' => 'Docker-Client/0.4.6',
                              'Transfer-Encoding' => 'chunked' },
          :query         => options.merge('fromSrc' => '-'),
          :request_block => proc { io.read(Excon.defaults[:chunk_size]).to_s },
          :expects       => (200..204)
        ).body
        new(:id => JSON.parse(body)['status'], :connection => connection)
      end
    end

    # Given a Dockerfile as a string, builds an Image.
    def build(commands, connection = Docker.connection)
      body = connection.post(
        :path => '/build',
        :body => create_tar(commands),
        :expects => (200..204)
      ).body
      new(:id => extract_id(body), :connection => connection)
    end

    # Given a directory that contains a Dockerfile, builds an Image.
    def build_from_dir(dir, connection = Docker.connection)
      tar = create_dir_tar(dir)
      body = connection.post(
        :path          => '/build',
        :headers       => { 'Content-Type'      => 'application/tar',
                            'Transfer-Encoding' => 'chunked' },
        :request_block => proc { tar.read(Excon.defaults[:chunk_size]).to_s },
        :expects       => (200..204),
      ).body
      new(:id => extract_id(body), :connection => connection)
    ensure
      tar.close
    end

  private
    def extract_id(body)
      line = body.lines.to_a[-1]
      if (id = line.match(/^Successfully built ([a-f0-9]+)$/)) && !id[1].empty?
        id[1]
      else
        raise UnexpectedResponseError, "Couldn't find id: #{body}"
      end
    end

    def create_tar(input)
      cwd = FileUtils.pwd
      path = "/tmp/docker/tar-#{rand(10000)}"
      string = StringIO.new
      tar = Archive::Tar::Minitar::Output.new(string)
      FileUtils.mkdir_p(path)
      FileUtils.cd(path)
      file = File.new('Dockerfile', 'w')
      file.write(input)
      file.close
      Archive::Tar::Minitar.pack_file("Dockerfile", tar)
      FileUtils.cd(cwd)
      FileUtils.rm_rf(path)
      string.tap(&:rewind)
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
  end
end
