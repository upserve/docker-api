require 'spec_helper'

# WARNING if you're re-recording any of these VCRs, you must be running the
# Docker daemon and have the base Image pulled.
describe Docker::Container do
  describe '#to_s' do
    subject {
      described_class.send(:new, Docker.connection, 'id' => rand(10000).to_s)
    }

    let(:id) { 'bf119e2' }
    let(:connection) { Docker.connection }
    let(:expected_string) {
      "Docker::Container { :id => #{id}, :connection => #{connection} }"
    }
    before do
      {
        :@id => id,
        :@connection => connection
      }.each { |k, v| subject.instance_variable_set(k, v) }
    end

    its(:to_s) { should == expected_string }
  end

  describe '#json' do
    subject { described_class.create(:cmd => %w[true], :image => 'base') }
    let(:description) { subject.json }

    it 'returns the description as a Hash', :vcr do
      description.should be_a(Hash)
      description['ID'].should start_with(subject.id)
    end
  end

  describe '#changes' do
    subject {
      described_class.create(:cmd => %w[rm -rf /root], :image => 'base')
    }
    let(:changes) { subject.changes }

    before { subject.tap(&:start).tap(&:wait) }

    it 'returns the changes as an array', :vcr do
      changes.should == [
        {
          "Path" => "/dev",
          "Kind" => 0
        },
        {
          "Path" => "/dev/kmsg",
          "Kind" => 0
        },
        {
          "Path" => "/root",
          "Kind" => 2
        },
      ]
    end
  end

  describe '#top' do
    let(:dir) {
      File.join(File.dirname(__FILE__), '..', 'fixtures', 'top')
    }
    let(:image) { Docker::Image.build_from_dir(dir) }
    let(:top) { sleep 1; container.top }
    let!(:container) { image.run('/while') }

    it 'returns the top commands as an Array', :vcr do
      top.should be_a Array
      top.should_not be_empty
      top.first.keys.should == %w(UID PID PPID C STIME TTY TIME CMD)
    end
  end

  describe '#copy' do
    subject {
      Docker::Image.create(
        :from_image => 'base'
      ).run('touch /test').tap { |c| c.wait }
    }

    context 'when the file does not exist' do
      it 'raises an error', :vcr do
        pending 'Docker no longer returns a 500 when the file does not exist'
        expect { subject.copy('/lol/not/a/real/file') { |chunk| puts chunk } }
            .to raise_error
      end
    end

    context 'when the input is a file' do
      it 'yields each chunk of the tarred file', :vcr do
        chunks = []
        subject.copy('/test') { |chunk| chunks << chunk }
        chunks = chunks.join("\n")
        expect(chunks).to be_include('test')
      end
    end

    context 'when the input is a directory' do
      it 'yields each chunk of the tarred directory', :vcr do
        chunks = []
        subject.copy('/etc/vim') { |chunk| chunks << chunk }
        chunks = chunks.join("\n")
        %w[vimrc vimrc.tiny].should be_all { |file| chunks.include?(file) }
      end
    end
  end

  describe '#export' do
    subject {
      Docker::Container.create(
        :cmd => %w[rm -rf / --no-preserve-root],
        :image => 'base'
      )
    }
    before { subject.start }

    # If you have to re-record this VCR, PLEASE edit it so that it's only ~200
    # lines. This is only because we don't want our gem to be a few hundred
    # megabytes.
    it 'yields each chunk', :vcr do
      first = nil
      subject.export do |chunk|
        first ||= chunk
      end
      first[257..261].should == "ustar" # Make sure the export is a tar.
    end
  end

  describe '#attach' do
    subject {
      described_class.create(:cmd => %w[pwd], :image => 'base')
    }

    before { subject.start }

    context 'with normal sized chunks' do
      it 'yields each chunk', :vcr do
        chunk = nil
        subject.attach(:stdout => true) do |stream, c|
          chunk ||= c
        end
        expect(chunk).to eq("/\n")
      end
    end

    context 'with very small chunks' do
      before do
        Docker.options = { :chunk_size => 1 }
      end

      after do
        Docker.options = {}
      end

      it 'yields each chunk', :vcr do
        chunk = nil
        subject.attach do |stream, c|
          chunk ||= c
        end
        expect(chunk).to eq("/\n")
      end
    end
  end

  describe '#start' do
    subject {
      described_class.create(
        :cmd => %w[test -d /foo],
        :image => 'base',
        :volumes => {'/foo' => {}}
      )
    }
    let(:all) { Docker::Container.all }

    before { subject.start(:binds => ["/tmp:/foo"]) }

    it 'starts the container', :vcr do
      all.map(&:id).should be_any { |id| id.start_with?(subject.id) }
      subject.wait(10)['StatusCode'].should be_zero
    end
  end

  describe '#stop' do
    subject { described_class.create(:cmd => %w[true], :image => 'base') }

    before { subject.tap(&:start).stop(:timeout => '10') }

    it 'stops the container', :vcr do
      described_class.all(:all => true).map(&:id).should be_any { |id|
        id.start_with?(subject.id)
      }
      described_class.all.map(&:id).should be_none { |id|
        id.start_with?(subject.id)
      }
    end
  end

  describe '#kill' do
    subject { described_class.create(:cmd => ['ls'], :image => 'base') }

    it 'kills the container', :vcr do
      subject.kill
      described_class.all.map(&:id).should be_none { |id|
        id.start_with?(subject.id)
      }
      described_class.all(:all => true).map(&:id).should be_any { |id|
        id.start_with?(subject.id)
      }
    end
  end

  describe '#delete' do
    subject { described_class.create(:cmd => ['ls'], :image => 'base') }

    it 'deletes the container', :vcr do
      subject.delete(:force => true)
      described_class.all.map(&:id).should be_none { |id|
        id.start_with?(subject.id)
      }
    end
  end

  describe '#restart' do
    subject { described_class.create(:cmd => %w[sleep 50], :image => 'base') }

    before { subject.start }

    it 'restarts the container', :vcr do
      described_class.all.map(&:id).should be_any { |id|
        id.start_with?(subject.id)
      }
      subject.stop
      described_class.all.map(&:id).should be_none { |id|
        id.start_with?(subject.id)
      }
      subject.restart('timeout' => '10')
      described_class.all.map(&:id).should be_any { |id|
        id.start_with?(subject.id)
      }
    end
  end

  describe '#wait' do
    subject {
      described_class.create(:cmd => %w[tar nonsense], :image => 'base')
    }

    before { subject.start }

    it 'waits for the command to finish', :vcr do
      subject.wait['StatusCode'].should_not be_zero
    end

    context 'when an argument is given' do
      subject { described_class.create(:cmd => %w[sleep 5], :image => 'base') }

      it 'sets the :read_timeout to that amount of time', :vcr do
        subject.wait(6)['StatusCode'].should be_zero
      end

      context 'and a command runs for too long' do
        it 'raises a ServerError', :vcr do
          pending "VCR doesn't like to record errors"
          expect { subject.wait(4) }.to raise_error(Docker::Error::TimeoutError)
        end
      end
    end
  end

  describe '#run' do
    let(:run_command) { subject.run('ls') }
    context 'when the Container\'s command does not return status code of 0' do
      subject {
        described_class.create(
          :cmd => %w[lol not a real command],
          :image => 'base'
        )
      }

      it 'raises an error', :vcr do
        expect { run_command }
            .to raise_error(Docker::Error::UnexpectedResponseError)
      end
    end

    context 'when the Container\'s command returns a status code of 0' do
      subject { described_class.create(:cmd => %w[pwd], :image => 'base') }

      it 'creates a new container to run the specified command', :vcr do
        run_command.wait['StatusCode'].should be_zero
      end
    end
  end

  describe '#commit' do
    subject { described_class.create(:cmd => %w[true], :image => 'base') }
    let(:image) { subject.commit }

    before { subject.start }

    it 'creates a new Image from the  Container\'s changes', :vcr do
      image.should be_a Docker::Image
      image.id.should_not be_nil
    end

    context 'if run is passed, it saves the command in the image', :vcr do
      let(:image) { subject.commit }
      it 'saves the command' do
        pending 'This is no longer working in v0.8'
        expect(image.run('pwd').attach).to eql [["/\n"],[]]
      end
    end

  end

  describe '.create' do
    subject { described_class }

    context 'when the Container does not yet exist' do
      context 'when the HTTP request does not return a 200' do
        before do
          Docker.options = { :mock => true }
          Excon.stub({ :method => :post }, { :status => 400 })
        end
        after do
          Excon.stubs.shift
          Docker.options = {}
        end

        it 'raises an error' do
          expect { subject.create }.to raise_error(Docker::Error::ClientError)
        end
      end

      context 'when the HTTP request returns a 200' do
        let(:options) do
          {
            :hostname      => "",
            :user          => "",
            :memory        => 0,
            :memory_swap   => 0,
            :attach_stdin  => false,
            :attach_stdout => false,
            :attach_stderr => false,
            :port_specs    => nil,
            :tty           => false,
            :open_stdin    => false,
            :stdin_once    => false,
            :env           => nil,
            :cmd           => ["date"],
            :dns           => nil,
            :image         => "base",
            :volumes       => {},
            :volumes_from  => ""
          }
        end
        let(:container) { subject.create(options) }

        it 'sets the id', :vcr do
          container.should be_a Docker::Container
          container.id.should_not be_nil
          container.connection.should_not be_nil
        end
      end
    end

    context 'when creating a container named bob' do
      subject {
        described_class.create({:cmd => %w[true], :image => 'base'}.merge(opts))
      }

      let(:opts) { { :name => "bob" } }

      it 'should have name set to bob', :vcr do
        subject.json['Name'].should == "/bob"
      end
    end
  end

  describe '.get' do
    subject { described_class }

    context 'when the HTTP response is not a 200' do
      before do
        Docker.options = { :mock => true }
        Excon.stub({ :method => :get }, { :status => 500 })
      end
      after do
        Excon.stubs.shift
        Docker.options = {}
      end

      it 'raises an error' do
        expect { subject.get('randomID') }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response is a 200' do
      let(:container) { subject.create(:cmd => ['ls'], :image => 'base') }

      it 'materializes the Container into a Docker::Container', :vcr do
        subject.get(container.id).should be_a(Docker::Container)
      end
    end

  end

  describe '.all' do
    subject { described_class }

    context 'when the HTTP response is not a 200' do
      before do
        Docker.options = { :mock => true }
        Excon.stub({ :method => :get }, { :status => 500 })
      end
      after do
        Excon.stubs.shift
        Docker.options = {}
      end

      it 'raises an error' do
        expect { subject.all }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response is a 200' do
      before { described_class.create(:cmd => ['ls'], :image => 'base') }

      it 'materializes each Container into a Docker::Container', :vcr do
        subject.all(:all => true).should be_all { |container|
          container.is_a?(Docker::Container)
        }
        subject.all(:all => true).length.should_not be_zero
      end
    end
  end
end
