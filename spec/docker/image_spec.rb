require 'spec_helper'

describe Docker::Image do
  describe '#to_s' do
    subject { described_class.send(:new, id: rand(10000).to_s) }

    let(:id) { 'bf119e2' }
    let(:connection) { Docker.connection }
    let(:expected_string) do
      "Docker::Image { :id => #{id}, :connection => #{connection} }"
    end
    before do
      {
        :@id => id,
        :@connection => connection
      }.each { |k, v| subject.instance_variable_set(k, v) }
    end

    its(:to_s) { should == expected_string }
  end

  describe '#remove' do
    let(:id) { subject.id }
    subject { described_class.create(from_image: 'base') }

    it 'removes the Image', :vcr do
      subject.remove
      Docker::Image.all.map(&:id).should_not include(id)
    end
  end

  describe '#insert' do
    subject { described_class.build('from base') }
    let(:new_image) { subject.insert(path: '/stallman',
                                     url: 'http://stallman.org') }
    let(:ls_output) { new_image.run('ls /').attach.split("\n") }

    it 'inserts the url\'s file into a new Image', :vcr do
      ls_output.should include('stallman')
    end
  end

  describe '#push' do
    subject { described_class.create(from_image: 'base') }

    it 'pushes the Image', :vcr do
      pending 'I don\'t want to push the Image to the Docker Registry'
      subject.push
    end
  end

  describe '#tag' do
    subject { described_class.create(from_image: 'base')}

    it 'tags the image with the repo name', :vcr do
      expect { subject.tag!(repo: 'base2', force: true) }
          .to_not raise_error
    end
  end

  describe '#json' do
    subject { described_class.create(from_image: 'base') }
    let(:json) { subject.json }

    it 'returns additional information about image image', :vcr do
      json.should be_a Hash
      json.length.should_not be_zero
    end
  end

  describe '#history' do
    subject { described_class.create(from_image: 'base') }
    let(:history) { subject.history }

    it 'returns the history of the Image', :vcr do
      history.should be_a Array
      history.length.should_not be_zero
      history.should be_all { |elem| elem.is_a? Hash }
    end
  end

  describe '#run' do
    subject { described_class.create(from_image: 'base') }
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

    context 'when the body is not a Hash' do
      it 'raises an error' do
        expect { subject.create(:not_a_hash) }
            .to raise_error(Docker::Error::ArgumentError)
      end
    end

    context 'when the Image does not yet exist and the body is a Hash' do
      let(:image) { subject.create(from_image: 'base') }

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

      before { File.stub(:open).with(file, 'r').and_yield(mock(read: '')) }

      # WARNING if you delete this VCR, make sure you set VCR to hook into
      # :excon instead of :webmock, run only this spec, and then switch the
      # hooks # back to :webmock.
      it 'creates the Image', :vcr do
        import = subject.import(file)
        import.should be_a Docker::Image
        import.id.should_not be_nil
      end
    end
  end

  describe '.all' do
    subject { described_class }

    let(:images) { subject.all(all: true) }
    before { subject.create(from_image: 'base') }

    it 'materializes each Image into a Docker::Image', :vcr do
      images.should be_all { |image|
        !image.id.nil? && image.is_a?(described_class)
      }
      images.length.should_not be_zero
    end
  end

  describe '.search' do
    subject { described_class }

    it 'materializes each Image into a Docker::Image', :vcr do
      subject.search(term: 'sshd').should be_all { |image|
        !image.id.nil? && image.is_a?(described_class)
      }
    end
  end

  describe '.build' do
    subject { described_class }
    context 'with an invalid Dockerfile' do
      let(:image) { subject.build('lololol') }

      it 'returns nil', :vcr do
        image.should be_nil
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

    context 'with a valid Dockerfile and a response block' do
      let(:id) { "b750fe79269d" } # no easier way tthan to hardcode

      it 'calls the response block', :vcr do
        msg = "Step 1 : FROM base\n ---> #{id}\nSuccessfully built #{id}\n"
        expect { |b| subject.build("from base\n", &b) }.to yield_with_args msg
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
        Docker::Container.create(image: image.id,
                                 cmd: %w[cat /Dockerfile])
      end
      let(:output) { container.tap(&:start)
                              .attach(stderr: true) }

      it 'builds the image', :vcr do
        pending 'webmock / vcr issue'
        output.should == docker_file.tap(&:rewind).read
      end
    end
  end
end
