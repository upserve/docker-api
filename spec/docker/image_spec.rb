require 'spec_helper'

describe Docker::Image do
  describe '#to_s' do
    subject { described_class.send(:new, Docker.connection, id) }

    let(:id) { 'bf119e2' }
    let(:connection) { Docker.connection }
    let(:info) { {"Repository" => "base", "Tag" => "latest", "Created" => 1364102658, "Size" => 24653, "VirtualSize" => 180116135}}
    let(:expected_string) do
      "Docker::Image { :id => #{id}, :info => #{info.inspect}, :connection => #{connection} }"
    end
    before do
      {
        :@id => id,
        :@connection => connection,
        :@info => info
      }.each { |k, v| subject.instance_variable_set(k, v) }
    end

    its(:to_s) { should == expected_string }
  end

  describe '#remove' do
    let(:id) { subject.id }
    subject { described_class.create('fromImage' => 'base') }

    it 'removes the Image', :vcr do
      subject.remove
      Docker::Image.all.map(&:id).should_not include(id)
    end
  end

  describe '#insert' do
    subject { described_class.build('from base') }
    let(:new_image) { subject.insert(:path => '/stallman',
                                     :url => 'http://stallman.org') }
    let(:ls_output) { new_image.run('ls /').attach.split("\n") }

    it 'inserts the url\'s file into a new Image', :vcr do
      ls_output.should include('stallman')
    end
  end

  describe '#insert_local' do
    subject { described_class.build('from base') }

    let(:new_image) {
      subject.insert_local('localPath' => file, 'outputPath' => '/')
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
        new_image.run('cat /Gemfile').start.attach { |chunk|
          chunk.should == gemfile
        }
      end
    end

    context 'when there are multiple files passed' do
      let(:file) { ['./Gemfile', './Rakefile'] }
      let(:gemfile) { File.read('Gemfile') }
      let(:rakefile) { File.read('Rakefile') }

      it 'creates a new Image that has each file', :vcr do
        new_image.run('cat /Gemfile /Rakefile').start.attach do |chunk|
          chunk.should == gemfile + rakefile
        end
      end
    end
  end

  describe '#push' do
    subject { described_class.create('fromImage' => 'base') }

    it 'pushes the Image', :vcr do
      pending 'I don\'t want to push the Image to the Docker Registry'
      subject.push
    end
  end

  describe '#tag' do
    subject { described_class.create('fromImage' => 'base') }

    it 'tags the image with the repo name', :vcr do
      expect { subject.tag(:repo => 'base2', :force => true) }
          .to_not raise_error
    end
  end

  describe '#json' do
    subject { described_class.create('fromImage' => 'base') }
    let(:json) { subject.json }

    it 'returns additional information about image image', :vcr do
      json.should be_a Hash
      json.length.should_not be_zero
    end
  end

  describe '#history' do
    subject { described_class.create('fromImage' => 'base') }
    let(:history) { subject.history }

    it 'returns the history of the Image', :vcr do
      history.should be_a Array
      history.length.should_not be_zero
      history.should be_all { |elem| elem.is_a? Hash }
    end
  end

  describe '#run' do
    subject { described_class.create('fromImage' => 'base') }
    let(:output) { subject.run(cmd).attach }

    context 'when the argument is a String', :vcr do
      let(:cmd) { 'ls /lib64/' }
      it 'splits the String by spaces and creates a new Container' do
        output.should == "ld-linux-x86-64.so.2\n"
      end
    end

    context 'when the argument is an Array' do
      let(:cmd) { %[which pwd] }

      it 'creates a new Container', :vcr do
        output.should == "/bin/pwd\n"
      end
    end
  end

  describe '.create' do
    subject { described_class }

    context 'when the Image does not yet exist and the body is a Hash' do
      let(:image) { subject.create('fromImage' => 'base') }

      it 'sets the id', :vcr do
        image.should be_a Docker::Image
        image.id.should_not be_nil
      end
    end
  end

  describe '.import' do
    subject { described_class }

    context 'when the file does not exist' do
      let(:file) { '/lol/not/a/file' }

      it 'raises an error' do
        expect { subject.import(file) }
            .to raise_error Errno::ENOENT
      end
    end

    context 'when the file does exist' do
      let(:file) { 'spec/fixtures/export.tar' }

      before { File.stub(:open).with(file, 'r').and_yield(mock(:read => '')) }

      it 'creates the Image', :vcr do
        pending 'This works, but recording a streaming request breaks VCR'
        import = subject.import(file)
        import.should be_a Docker::Image
        import.id.should_not be_nil
      end
    end
  end

  describe '.all' do
    subject { described_class }

    let(:images) { subject.all(:all => true) }
    before { subject.create('fromImage' => 'base') }

    it 'materializes each Image into a Docker::Image', :vcr do
      images.should be_all { |image|
        puts image
        !image.id.nil? && image.is_a?(described_class) && !image.id.nil? && %q[Repository Tag Created Size VirtualSize].split(' ').all?{|k|puts k; image.info.has_key? k}
      }
      images.length.should_not be_zero
    end
  end

  describe '.search' do
    subject { described_class }

    it 'materializes each Image into a Docker::Image', :vcr do
      subject.search('term' => 'sshd').should be_all { |image|
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
      let(:image) { subject.build("from base\n") }

      it 'builds an image', :vcr do
        image.should be_a Docker::Image
        image.id.should_not be_nil
        image.connection.should be_a Docker::Connection
      end
    end
  end

  describe '.build_from_dir' do
    subject { described_class }

    context 'with a valid Dockerfile' do
      let(:dir) { File.join(File.dirname(__FILE__), '..', 'fixtures') }
      let(:docker_file) { File.new("#{dir}/Dockerfile") }
      let(:image) { subject.build_from_dir(dir) }
      let(:container) do
        Docker::Container.create('Image' => image.id,
                                 'Cmd' => %w[cat /Dockerfile])
      end
      let(:output) { container.tap(&:start)
                              .attach(:stderr => true) }

      it 'builds the image', :vcr do
        pending 'webmock / vcr issue'
        output.should == docker_file.tap(&:rewind).read
      end
    end
  end
end
