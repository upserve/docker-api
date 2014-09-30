require 'spec_helper'

describe Docker::Image do
  describe '#to_s' do
    subject { described_class.new(Docker.connection, info) }

    let(:id) { 'bf119e2' }
    let(:connection) { Docker.connection }

    let(:info) do
      {"id" => "bf119e2", "Repository" => "base", "Tag" => "latest",
        "Created" => 1364102658, "Size" => 24653, "VirtualSize" => 180116135}
    end

    let(:expected_string) do
      "Docker::Image { :id => #{id}, :info => #{info.inspect}, "\
        ":connection => #{connection} }"
    end

    its(:to_s) { should == expected_string }
  end

  describe '#remove' do
    let(:id) { subject.id }
    subject { described_class.create('fromImage' => 'base') }

    it 'removes the Image', :vcr do
      subject.remove(:force => true)
      expect(Docker::Image.all.map(&:id)).to_not include(id)
    end
  end

  describe '#insert_local' do
    subject { described_class.build('from base') }

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
      let(:file) { './Gemfile' }
      let(:gemfile) { File.read('Gemfile') }

      it 'creates a new Image that has that file', :vcr do
        chunk = nil
        new_image.run('cat /Gemfile').attach { |stream, c|
          chunk ||= c
        }
        expect(chunk).to eq(gemfile)
      end
    end

    context 'when a direcory is passed' do
      let(:new_image) {
        subject.insert_local('localPath' => './lib', 'outputPath' => '/lib')
      }
      let(:response) { new_image.run('ls -a /lib/docker').attach.flatten.first }

      it 'inserts the directory', :vcr do
        expect(response.split("\n").sort).to eq(Dir.entries('lib/docker').sort)
      end
    end

    context 'when there are multiple files passed' do
      let(:file) { ['./Gemfile', './Rakefile'] }
      let(:gemfile) { File.read('Gemfile') }
      let(:rakefile) { File.read('Rakefile') }
      let(:response) {
        new_image.run('cat /Gemfile /Rakefile').attach
      }

      it 'creates a new Image that has each file', :vcr do
        expect(response).to eq([[gemfile, rakefile],[]])
      end
    end

    context 'when removing intermediate containers' do
      let(:rm) { true }
      let(:file) { './Gemfile' }

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
        'username' => 'nahiluhmot',
        'password' => '******',
        'serveraddress' => 'https://index.docker.io/v1',
        'email'    => 'tomhulihan@swipely.com'
      }
    }
    let(:base_image) {
      described_class.create('fromImage' => 'base')
    }
    let(:container) {
      base_image.run('true')
    }
    let(:new_image) {
      container.commit('repo' => 'nahiluhmot/base2')
      Docker::Image.all(:all => true).select { |image|
        image.info['RepoTags'].include?('nahiluhmot/base2:latest')
      }.first
    }

    it 'pushes the Image', :vcr do
      new_image.push(credentials)
    end

    context 'when there are no credentials' do
      let(:credentials) { nil }
      let(:image) {
        Docker::Image.create('fromImage' => 'registry', 'tag' => 'latest')
      }

      before do
        image.tag('repo' => 'localhost:5000/registry', 'tag' => 'test')
      end

      it 'still pushes', :vcr do
        expect { image.push }.to_not raise_error
      end
    end
  end

  describe '#tag' do
    subject { described_class.create('fromImage' => 'base') }

    it 'tags the image with the repo name', :vcr do
      subject.tag(:repo => :base2, :force => true)
      expect(subject.info['RepoTags']).to include 'base2:latest'
    end
  end

  describe '#json' do
    subject { described_class.create('fromImage' => 'base') }
    let(:json) { subject.json }

    it 'returns additional information about image image', :vcr do
      expect(json).to be_a Hash
      expect(json.length).to_not be_zero
    end
  end

  describe '#history' do
    subject { described_class.create('fromImage' => 'base') }
    let(:history) { subject.history }

    it 'returns the history of the Image', :vcr do
      expect(history).to be_a Array
      expect(history.length).to_not be_zero
      expect(history).to be_all { |elem| elem.is_a? Hash }
    end
  end

  describe '#run' do
    subject { described_class.create('fromImage' => 'base') }
    let(:output) { subject.run(cmd).attach }

    context 'when the argument is a String', :vcr do
      let(:cmd) { 'ls /lib64/' }
      it 'splits the String by spaces and creates a new Container' do
        expect(output).to eq([["ld-linux-x86-64.so.2\n"],[]])
      end
    end

    context 'when the argument is an Array' do
      let(:cmd) { %w[which pwd] }

      it 'creates a new Container', :vcr do
        expect(output).to eq([["/bin/pwd\n"],[]])
      end
    end

    context 'when the argument is nil', :vcr  do
      let(:cmd) { nil }
      context 'no command configured in image'do
        it 'should raise an error if no command is specified' do
          expect {output}.to raise_error(Docker::Error::ServerError,
                                         "No command specified.")
        end
      end

      context "command configured in image" do
        let(:container) {Docker::Container.create('Cmd' => %w[true],
                                                  'Image' => 'base')}
        subject { container.commit('run' => {"Cmd" => %w[pwd]}) }

        it 'should normally show result if image has Cmd configured' do
          skip 'The docs say this should work, but it clearly does not'
          expect(output).to eql [["/\n"],[]]
        end
      end
    end
  end

  describe '#refresh!' do
    let(:image) { Docker::Image.create('fromImage' => 'base') }

    it 'updates the @info hash', :vcr do
      size = image.info.size
      image.refresh!
      expect(image.info.size).to be > size
    end
  end

  describe '.create' do
    subject { described_class }

    context 'when the Image does not yet exist and the body is a Hash' do
      let(:image) { subject.create('fromImage' => 'ubuntu') }
      let(:creds) {
        {
          :username => 'tlunter',
          :password => '************',
          :email => 'tlunter@gmail.com'
        }
      }

      before { Docker.creds = creds }

      it 'sets the id and sends Docker.creds', :vcr do
        expect(image).to be_a Docker::Image
        expect(image.id).to match(/\A[a-fA-F0-9]+\Z/)
        expect(image.id).to_not include('base')
        expect(image.id).to_not be_nil
        expect(image.id).to_not be_empty
        expect(image.info[:headers].keys).to include 'X-Registry-Auth'
      end
    end
  end

  describe '.get' do
    subject { described_class }
    let(:image) { subject.get(image_name) }

    context 'when the image does exist' do
      let(:image_name) { 'base' }

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

  describe '.exist?' do
    subject { described_class }
    let(:exists) { subject.exist?(image_name) }

    context 'when the image does exist' do
      let(:image_name) { 'base' }

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
    subject { described_class }

    context 'when the file does not exist' do
      let(:file) { '/lol/not/a/file' }

      it 'raises an error' do
        expect { subject.import(file) }
          .to raise_error(Docker::Error::IOError)
      end
    end

    context 'when the file does exist' do
      let(:file) { 'spec/fixtures/export.tar' }
      let(:body) { StringIO.new }

      before do
        allow(Docker::Image).to receive(:open).with(file).and_yield(body)
      end

      it 'creates the Image', :vcr do
        import = subject.import(file)
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
        let(:uri) { 'http://swipely-pub.s3.amazonaws.com/ubuntu.tar' }

        it 'returns an Image', :vcr do
          image = subject.import(uri)
          expect(image).to be_a Docker::Image
          expect(image.id).to_not be_nil
        end
      end
    end
  end

  describe '.all' do
    subject { described_class }

    let(:images) { subject.all(:all => true) }
    before { subject.create('fromImage' => 'base') }

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
        let(:image) { subject.build("from base\n") }

        it 'builds an image', :vcr do
          expect(image).to be_a Docker::Image
          expect(image.id).to_not be_nil
          expect(image.connection).to be_a Docker::Connection
        end
      end

      context 'with specifying a repo in the query parameters' do
        let(:image) {
          subject.build("from base\nrun true\n", "t" => "swipely/base")
        }
        let(:images) { subject.all }

        it 'builds an image and tags it', :vcr do
          expect(image).to be_a Docker::Image
          expect(image.id).to_not be_nil
          expect(image.connection).to be_a Docker::Connection
          expect(images.first.info["RepoTags"]).to eq(["swipely/base:latest"])
        end
      end

      context 'with a block capturing build output' do
        let(:build_output) { "" }
        let(:block) { Proc.new { |chunk| build_output << chunk } }
        let!(:image) { subject.build("FROM base\n", &block) }

        it 'calls the block and passes build output', :vcr do
          expect(build_output).to match(/Step 0 : FROM base/)
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
                              .attach(:stderr => true) }
      let(:images) { subject.all }

      context 'with no query parameters' do
        it 'builds the image', :vcr do
          expect(output).to eq([[docker_file.read],[]])
        end
      end

      context 'with specifying a repo in the query parameters' do
        let(:opts) { { "t" => "swipely/base2" } }
        it 'builds the image and tags it', :vcr do
          expect(output).to eq([[docker_file.read],[]])
          expect(images.first.info["RepoTags"]).to eq(["swipely/base2:latest"])
        end
      end

      context 'with a block capturing build output' do
        let(:build_output) { "" }
        let(:block) { Proc.new { |chunk| build_output << chunk } }

        it 'calls the block and passes build output', :vcr do
          image # Create the image variable, which is lazy-loaded by Rspec
          expect(build_output).to match(/Step 0 : from base/)
        end
      end

      context 'with credentials passed' do
        let(:creds) {
          {
            :username => 'nahiluhmot',
            :password => '*********',
            :email => 'hulihan.tom159@gmail.com',
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
