require 'spec_helper'

describe Docker::Image do
  describe '#to_s' do
    subject { described_class.new(Docker.connection, info) }

    let(:id) { 'bf119e2' }
    let(:connection) { Docker.connection }

    let(:info) do
      {"id" => "bf119e2", "Repository" => "debian", "Tag" => "wheezy",
        "Created" => 1364102658, "Size" => 24653, "VirtualSize" => 180116135}
    end

    let(:expected_string) do
      "Docker::Image { :id => #{id}, :info => #{info.inspect}, "\
        ":connection => #{connection} }"
    end

    its(:to_s) { should == expected_string }
  end

  describe '#remove' do

    context 'when no name is given' do
      let(:id) { subject.id }
      subject { described_class.create('fromImage' => 'busybox') }

      it 'removes the Image', :vcr do
        subject.remove(:force => true)
        expect(Docker::Image.all.map(&:id)).to_not include(id)
      end
    end

    context 'when a valid tag is given' do
      it 'untags the Image'
    end

    context 'when an invalid tag is given' do
      it 'raises an error'
    end
  end

  describe '#insert_local' do
    include_context "local paths"

    subject { described_class.create('fromImage' => 'debian:wheezy') }

    let(:rm) { false }
    let(:new_image) {
      opts = {'localPath' => file, 'outputPath' => '/'}
      opts[:rm] = true if rm
      subject.insert_local(opts)
    }

    context 'when the local file does not exist' do
      let(:file) { '/lol/not/a/file' }

      it 'raises an error', :vcr do
        expect { new_image }.to raise_error(Docker::Error::ArgumentError)
      end
    end

    context 'when the local file does exist' do
      let(:file) { File.join(project_dir, 'Gemfile') }
      let(:gemfile) { File.read('Gemfile') }
      let(:container) { new_image.run('cat /Gemfile') }
      after do
        container.tap(&:wait).remove
        new_image.remove
      end

      it 'creates a new Image that has that file', :vcr do
        output = container.streaming_logs(stdout: true)
        expect(output).to eq(gemfile)
      end
    end

    context 'when a direcory is passed' do
      let(:new_image) {
        subject.insert_local(
          'localPath' => File.join(project_dir, 'lib'),
          'outputPath' => '/lib'
        )
      }
      let(:container) { new_image.run('ls -a /lib/docker') }
      let(:response) { container.streaming_logs(stdout: true) }
      after do
        container.tap(&:wait).remove
        new_image.remove
      end

      it 'inserts the directory', :vcr do
        expect(response.split("\n").sort).to eq(Dir.entries('lib/docker').sort)
      end
    end

    context 'when there are multiple files passed' do
      let(:file) {
        [File.join(project_dir, 'Gemfile'), File.join(project_dir, 'LICENSE')]
      }
      let(:gemfile) { File.read('Gemfile') }
      let(:license) { File.read('LICENSE') }
      let(:container) { new_image.run('cat /Gemfile /LICENSE') }
      let(:response) {
        container.streaming_logs(stdout: true)
      }
      after do
        container.tap(&:wait).remove
        new_image.remove
      end

      it 'creates a new Image that has each file', :vcr do
        expect(response).to eq("#{gemfile}#{license}")
      end
    end

    context 'when removing intermediate containers' do
      let(:rm) { true }
      let(:file) { File.join(project_dir, 'Gemfile') }
      after(:each) { new_image.remove }

      it 'leave no intermediate containers', :vcr do
        expect { new_image }.to change {
          Docker::Container.all(:all => true).count
        }.by 0
      end

      it 'creates a new image', :vcr do
        expect{new_image}.to change{Docker::Image.all.count}.by 1
      end
    end
  end

  describe '#push' do
    let(:credentials) {
      {
        'username' => ENV['DOCKER_API_USER'],
        'password' => ENV['DOCKER_API_PASS'],
        'serveraddress' => 'https://index.docker.io/v1',
        'email'    => ENV['DOCKER_API_EMAIL']
      }
    }
    let(:repo_tag) { "#{ENV['DOCKER_API_USER']}/true" }
    let(:build_script) { "FROM tianon/true\nENV TRIVIAL CHANGE\n" }
    let(:image) {
      described_class.build(build_script, "t" => repo_tag).refresh!
    }
    after { image.remove(:name => repo_tag, :noprune => true) }

    it 'pushes the Image', :vcr do
      image.push(credentials)
    end

    context 'when a tag is specified' do
      before { image.tag(repo: repo_tag, tag: 'also') }
      after { image.remove(:name => "#{repo_tag}:also", :noprune => true) }

      it 'pushes that specific tag', :vcr do
        image.push(credentials, :repo_tag => "#{repo_tag}:also")
      end
    end

    context 'when the image was retrived by get' do
      let(:image) {
        described_class.build(build_script, "t" => repo_tag).refresh!
        described_class.get(repo_tag)
      }

      context 'when no tag is specified' do
        it 'looks up the first repo tag', :vcr do
          expect { image.push(credentials) }.to_not raise_error
        end
      end
    end

    it 'raises an error if not found', :vcr do
      image.tag(repo: repo_tag, tag: 'also')
      image.remove(:name => "#{repo_tag}:also", :noprune => true)
      expect {
        image.push(credentials, :repo_tag => "#{repo_tag}:also")
      }.to raise_error(Docker::Error::NotFoundError)
    end

    it 'raises an error if alien name supplied', :vcr do
      expect {
        image.push(credentials, :repo_tag => "#{repo_tag}:nope")
      }.to raise_error(Docker::Error::ArgumentError, /#{repo_tag}:nope/)
    end

    it 'raises an error if unauthorized', :vcr do
      expect {
        image.push(credentials.merge('username' => 'no_yuo'))
      }.to raise_error(Docker::Error::UnauthorizedError)
    end

    it 'calls back to a supplied block', :vcr do
      calls = 0
      image.push(credentials) do |step, obj|
        calls += 1 if (obj == image) &&
          (step['status'] =~ /Pushing tag for rev/)
      end
      expect(calls).to eq(1)
    end

    context 'when there are no credentials' do
      let(:credentials) { nil }
      let(:repo_tag) { "localhost:5000/true" }

      it 'still pushes', :vcr do
        expect { image.push }.to_not raise_error
      end
    end
  end

  describe '#tag' do
    subject { described_class.create('fromImage' => 'debian:wheezy') }
    after { subject.remove(:name => 'teh:latest', :noprune => true) }

    it 'tags the image with the repo name', :vcr do
      subject.tag(:repo => :teh, :force => true)
      expect(subject.info['RepoTags']).to include 'teh:latest'
    end
  end

  describe '#json' do
    subject { described_class.create('fromImage' => 'debian:wheezy') }
    let(:json) { subject.json }

    it 'returns additional information about image image', :vcr do
      expect(json).to be_a Hash
      expect(json.length).to_not be_zero
    end
  end

  describe '#history' do
    subject { described_class.create('fromImage' => 'debian:wheezy') }
    let(:history) { subject.history }

    it 'returns the history of the Image', :vcr do
      expect(history).to be_a Array
      expect(history.length).to_not be_zero
      expect(history).to be_all { |elem| elem.is_a? Hash }
    end
  end

  describe '#run' do
    subject { described_class.create('fromImage' => 'debian:wheezy') }
    let(:container) { subject.run(cmd) }
    let(:output) { container.streaming_logs(stdout: true) }

    context 'when the argument is a String', :vcr do
      let(:cmd) { 'ls /lib64/' }
      after { container.tap(&:wait).remove }

      it 'splits the String by spaces and creates a new Container' do
        expect(output).to eq("ld-linux-x86-64.so.2\n")
      end
    end

    context 'when the argument is an Array' do
      let(:cmd) { %w[which pwd] }
      after { container.tap(&:wait).remove }

      it 'creates a new Container', :vcr do
        expect(output).to eq("/bin/pwd\n")
      end
    end

    context 'when the argument is nil', :vcr  do
      let(:cmd) { nil }
      context 'no command configured in image' do
        subject { described_class.create('fromImage' => 'scratch') }
        it 'should raise an error if no command is specified' do
          expect {container}.to raise_error(Docker::Error::ServerError,
                                         "No command specified.")
        end
      end

      context "command configured in image" do
        let(:cmd) { 'pwd' }
        after { container.tap(&:wait).remove }

        it 'should normally show result if image has Cmd configured' do
          expect(output).to eql "/\n"
        end
      end
    end
  end

  describe '#save' do
    let(:image) { Docker::Image.get('busybox') }

    it 'calls the class method', :vcr do
      expect(Docker::Image).to receive(:save)
        .with(image.id, 'busybox.tar', anything)
      image.save('busybox.tar')
    end
  end

  describe '#refresh!' do
    let(:image) { Docker::Image.create('fromImage' => 'debian:wheezy') }

    it 'updates the @info hash', :vcr do
      size = image.info.size
      image.refresh!
      expect(image.info.size).to be > size
    end

    context 'with an explicit connection' do
      let(:connection) { Docker::Connection.new(Docker.url, Docker.options) }
      let(:image) {
        Docker::Image.create({'fromImage' => 'debian:wheezy'}, nil, connection)
      }

      it 'updates using the provided connection', :vcr do
        expect(connection).to receive(:get)
          .with('/images/json', all: true).ordered
        expect(connection).to receive(:get)
          .with("/images/#{image.id}/json", {}).ordered.and_call_original
        image.refresh!
      end
    end
  end

  describe '.create' do
    subject { described_class }
    let(:creds) {
      {
        :username => ENV['DOCKER_API_USER'],
        :password => ENV['DOCKER_API_PASS'],
        :email => ENV['DOCKER_API_EMAIL']
      }
    }
    before { Docker.creds = creds }

    context 'when the Image does not yet exist and the body is a Hash' do
      let(:image) { subject.create('fromImage' => 'swipely/scratch') }

      after { image.remove(:name => 'swipely/scratch', :noprune => true) }

      it 'sets the id and sends Docker.creds', :vcr do
        expect(image).to be_a Docker::Image
        expect(image.id).to match(/\A[a-fA-F0-9]+\Z/)
        expect(image.id).to_not include('base')
        expect(image.id).to_not be_nil
        expect(image.id).to_not be_empty
        expect(image.info[:headers].keys).to include 'X-Registry-Auth'
      end
    end


    it 'calls back to a supplied block', :vcr do
      calls = 0
      image = subject.create('fromImage' => 'swipely/scratch') do |step, obj|
        puts step
        calls += 1 if (obj['fromImage'] == 'swipely/scratch') &&
          (step['status'] =~ /^Status: Image is up to date/)
      end
      expect(calls).to eq(1)
      image.remove(:name => 'swipely/scratch', :noprune => true)
    end

    it 'raises an error if not found', :vcr do
      expect{
        subject.create('fromImage' => 'swipely/nonesuchimage')
      }.to raise_error(Docker::Error::NotFoundError)
    end

  end

  describe '.get' do
    subject { described_class }
    let(:image) { subject.get(image_name) }

    context 'when the image does exist' do
      let(:image_name) { 'debian:wheezy' }

      it 'returns the new image', :vcr do
        expect(image).to be_a Docker::Image
      end
    end

    context 'when the image does not exist' do
      let(:image_name) { 'abcdefghijkl' }

      before do
        Docker.options = { :mock => true }
        Excon.stub({ :method => :get }, { :status => 404 })
      end

      after do
        Docker.options = {}
        Excon.stubs.shift
      end

      it 'raises a not found error', :vcr do
        expect { image }.to raise_error(Docker::Error::NotFoundError)
      end
    end
  end

  describe '.save' do
    include_context "local paths"

    context 'when a filename is specified' do
      let(:file) { "#{project_dir}/scratch.tar" }
      after { FileUtils.remove(file) }

      it 'exports tarball of image to specified file', :vcr do
        Docker::Image.save('scratch', file)
        expect(File.exist?(file)).to eq true
        expect(File.read(file)).to_not be_nil
      end
    end

    context 'when no filename is specified' do
      it 'returns raw binary data as string', :vcr do
        raw = Docker::Image.save('scratch:latest')
        expect(raw).to_not be_nil
      end
    end
  end

  describe '.exist?' do
    subject { described_class }
    let(:exists) { subject.exist?(image_name) }

    context 'when the image does exist' do
      let(:image_name) { 'debian:wheezy' }

      it 'returns true', :vcr do
        expect(exists).to eq(true)
      end
    end

    context 'when the image does not exist' do
      let(:image_name) { 'abcdefghijkl' }

      before do
        Docker.options = { :mock => true }
        Excon.stub({ :method => :get }, { :status => 404 })
      end

      after do
        Docker.options = {}
        Excon.stubs.shift
      end

      it 'return false', :vcr do
        expect(exists).to eq(false)
      end
    end
  end

  describe '.import' do
    include_context "local paths"

    subject { described_class }

    context 'when the file does not exist' do
      let(:file) { '/lol/not/a/file' }

      it 'raises an error' do
        expect { subject.import(file) }
          .to raise_error(Docker::Error::IOError)
      end
    end

    context 'when the file does exist' do
      let(:file) { File.join(project_dir, 'spec', 'fixtures', 'export.tar') }
      let(:import) { subject.import(file) }
      after { import.remove(:noprune => true) }

      it 'creates the Image', :vcr do
        expect(import).to be_a Docker::Image
        expect(import.id).to_not be_nil
      end
    end

    context 'when the argument is a URI' do
      context 'when the URI is invalid' do
        it 'raises an error', :vcr do
          expect { subject.import('http://google.com') }
            .to raise_error(Docker::Error::IOError)
        end
      end

      context 'when the URI is valid' do
        let(:uri) { 'http://swipely-pub.s3.amazonaws.com/tianon_true.tar' }
        let(:import) { subject.import(uri) }
        after { import.remove(:noprune => true) }

        it 'returns an Image', :vcr do
          expect(import).to be_a Docker::Image
          expect(import.id).to_not be_nil
        end
      end
    end
  end

  describe '.all' do
    subject { described_class }

    let(:images) { subject.all(:all => true) }
    before { subject.create('fromImage' => 'debian:wheezy') }

    it 'materializes each Image into a Docker::Image', :vcr do
      images.each do |image|
        expect(image).to_not be_nil

        expect(image).to be_a(described_class)

        expect(image.id).to_not be_nil

        %w(Created Size VirtualSize).each do |key|
          expect(image.info).to have_key(key)
        end
      end

      expect(images.length).to_not be_zero
    end
  end

  describe '.search' do
    subject { described_class }

    it 'materializes each Image into a Docker::Image', :vcr do
      expect(subject.search('term' => 'sshd')).to be_all { |image|
        !image.id.nil? && image.is_a?(described_class)
      }
    end
  end

  describe '.build' do
    subject { described_class }
    context 'with an invalid Dockerfile' do
      it 'throws a UnexpectedResponseError', :vcr do
        expect { subject.build('lololol') }
            .to raise_error(Docker::Error::UnexpectedResponseError)
      end
    end

    context 'with a valid Dockerfile' do
      context 'without query parameters' do
        let(:image) { subject.build("FROM debian:wheezy\n") }

        it 'builds an image', :vcr do
          expect(image).to be_a Docker::Image
          expect(image.id).to_not be_nil
          expect(image.connection).to be_a Docker::Connection
        end
      end

      context 'with specifying a repo in the query parameters' do
        let(:image) {
          subject.build(
            "FROM debian:wheezy\nRUN true\n",
            "t" => "#{ENV['DOCKER_API_USER']}/debian:true"
          )
        }
        after { image.remove(:noprune => true) }

        it 'builds an image and tags it', :vcr do
          expect(image).to be_a Docker::Image
          expect(image.id).to_not be_nil
          expect(image.connection).to be_a Docker::Connection
          image.refresh!
          expect(image.info["RepoTags"]).to eq(
            ["#{ENV['DOCKER_API_USER']}/debian:true"]
          )
        end
      end

      context 'with a block capturing build output' do
        let(:build_output) { "" }
        let(:block) { Proc.new { |chunk| build_output << chunk } }
        let!(:image) { subject.build("FROM debian:wheezy\n", &block) }

        it 'calls the block and passes build output', :vcr do
          expect(build_output).to match(/Step 0 : FROM debian:wheezy/)
        end
      end
    end
  end

  describe '.build_from_dir' do
    subject { described_class }

    context 'with a valid Dockerfile' do
      let(:dir) {
        File.join(File.dirname(__FILE__), '..', 'fixtures', 'build_from_dir')
      }
      let(:docker_file) { File.new("#{dir}/Dockerfile") }
      let(:image) { subject.build_from_dir(dir, opts, &block) }
      let(:opts) { {} }
      let(:block) { Proc.new {} }
      let(:container) do
        Docker::Container.create('Image' => image.id,
                                 'Cmd' => %w[cat /Dockerfile])
      end
      let(:output) { container.tap(&:start)
                              .streaming_logs(stdout: true) }
      after(:each) do
        container.tap(&:wait).remove
        image.remove(:noprune => true)
      end

      context 'with no query parameters' do
        it 'builds the image', :vcr do
          expect(output).to eq(docker_file.read)
        end
      end

      context 'with specifying a repo in the query parameters' do
        let(:opts) { { "t" => "#{ENV['DOCKER_API_USER']}/debian:from_dir" } }
        it 'builds the image and tags it', :vcr do
          expect(output).to eq(docker_file.read)
          image.refresh!
          expect(image.info["RepoTags"]).to eq(
            ["#{ENV['DOCKER_API_USER']}/debian:from_dir"]
          )
        end
      end

      context 'with a block capturing build output' do
        let(:build_output) { "" }
        let(:block) { Proc.new { |chunk| build_output << chunk } }

        it 'calls the block and passes build output', :vcr do
          image # Create the image variable, which is lazy-loaded by Rspec
          expect(build_output).to match(/Step 0 : FROM debian:wheezy/)
        end
      end

      context 'with credentials passed' do
        let(:creds) {
          {
            :username => ENV['DOCKER_API_USER'],
            :password => ENV['DOCKER_API_PASS'],
            :email => ENV['DOCKER_API_EMAIL'],
            :serveraddress => 'https://index.docker.io/v1'
          }
        }

        before { Docker.creds = creds }

        it 'sends X-Registry-Config header', :vcr do
          expect(image.info[:headers].keys).to include('X-Registry-Config')
        end
      end
    end
  end
end
