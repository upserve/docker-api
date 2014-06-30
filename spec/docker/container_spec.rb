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
    subject { described_class.create('Cmd' => %w[true], 'Image' => 'base') }
    let(:description) { subject.json }

    it 'returns the description as a Hash', :vcr do
      expect(description).to be_a Hash
      expect(description['Id']).to start_with(subject.id)
    end
  end

  describe '#logs' do
    subject { described_class.create('Cmd' => "echo hello", 'Image' => 'base') }

    context "when not selecting any stream" do
      let(:non_destination) { subject.logs }
      it 'returns the error message', :vcr do
        expect(non_destination).to be_a String
        expect(non_destination).to match /You must choose at least one/
      end
    end

    context "when selecting stdout" do
      let(:stdout) { subject.logs(stdout: 1) }
      it 'returns blank logs', :vcr do
        expect(stdout).to be_a String
        expect(stdout).to eq ""
      end
    end
  end

  describe '#create' do
    subject {
      described_class.create({'Cmd' => %w[true], 'Image' => 'base'}.merge(opts))
    }

    context 'when creating a container named bob' do
      let(:opts) { {"name" => "bob"} }

      it 'should have name set to bob', :vcr do
        expect(subject.json["Name"]).to eq "/bob"
      end
    end
  end

  describe '#changes' do
    subject {
      described_class.create('Cmd' => %w[rm -rf /root], 'Image' => 'base')
    }
    let(:changes) { subject.changes }

    before { subject.tap(&:start).tap(&:wait) }

    it 'returns the changes as an array', :vcr do
      expect(changes).to eq [
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
      expect(top).to be_a Array
      expect(top).to_not be_empty
      expect(top.first.keys).to eq %w(UID PID PPID C STIME TTY TIME CMD)
    end
  end

  describe '#copy' do
    subject {
      Docker::Image.create(
        'fromImage' => 'base'
      ).run('touch /test').tap { |c| c.wait }
    }

    context 'when the file does not exist' do
      it 'raises an error', :vcr do
        skip 'Docker no longer returns a 500 when the file does not exist'
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
        expect(%w[vimrc vimrc.tiny]).to be_all { |file| chunks.include?(file) }
      end
    end
  end

  describe '#export' do
    subject { described_class.create('Cmd' => %w[rm -rf / --no-preserve-root],
                                     'Image' => 'base') }
    before { subject.start }

    # If you have to re-record this VCR, PLEASE edit it so that it's only ~200
    # lines. This is only because we don't want our gem to be a few hundred
    # megabytes.
    it 'yields each chunk', :vcr do
      first = nil
      subject.export do |chunk|
        first ||= chunk
      end
      expect(first[257..261]).to eq "ustar" # Make sure the export is a tar.
    end
  end

  describe '#attach' do
    subject { described_class.create('Cmd' => %w[pwd], 'Image' => 'base') }

    before { subject.start }

    context 'with normal sized chunks' do
      it 'yields each chunk', :vcr do
        chunk = nil
        subject.attach do |stream, c|
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

  describe '#attach with stdin' do
    # Because this uses HTTP socket hijacking, it is not compatible with
    # VCR, so it is currently pending until a good way to test it without
    # a running Docker daemon is discovered
    it 'yields the output' do
      skip 'HTTP socket hijacking not compatible with VCR'
      container = described_class.create(
        'Cmd'       => %w[cat],
        'Image'     => 'base',
        'OpenStdin' => true,
        'StdinOnce' => true
      )
      chunk = nil
      container.attach(stdin: StringIO.new("foo\nbar\n")) do |stream, c|
        chunk ||= c
      end
      expect(chunk).to eq("foo\nbar\n")
    end
  end

  describe '#start' do
    subject {
      described_class.create(
        'Cmd' => %w[test -d /foo],
        'Image' => 'base',
        'Volumes' => {'/foo' => {}}
      )
    }
    let(:all) { Docker::Container.all }

    before { subject.start('Binds' => ["/tmp:/foo"]) }

    it 'starts the container', :vcr do
      expect(all.map(&:id)).to be_any { |id| id.start_with?(subject.id) }
      expect(subject.wait(10)['StatusCode']).to be_zero
    end
  end

  describe '#stop' do
    subject { described_class.create('Cmd' => %w[true], 'Image' => 'base') }

    before { subject.tap(&:start).stop('timeout' => '10') }

    it 'stops the container', :vcr do
      expect(described_class.all(:all => true).map(&:id)).to be_any { |id|
        id.start_with?(subject.id)
      }
      expect(described_class.all.map(&:id)).to be_none { |id|
        id.start_with?(subject.id)
      }
    end
  end

  describe '#kill' do
    let(:command) { ['/bin/bash', '-c', 'while [ 1 ]; do echo hello; done'] }
    subject { described_class.create('Cmd' => command, 'Image' => 'base') }

    before do
      subject.start
    end

    it 'kills the container', :vcr do
      subject.kill
      expect(described_class.all.map(&:id)).to be_none { |id|
        id.start_with?(subject.id)
      }
      expect(described_class.all(:all => true).map(&:id)).to be_any { |id|
        id.start_with?(subject.id)
      }
    end

    context 'with a kill signal' do
      let(:command) {
        [
          '/bin/bash',
          '-c',
          'trap echo SIGTERM; while [ 1 ]; do echo hello; done'
        ]
      }
      it 'kills the container', :vcr do
        subject.kill(:signal => "SIGTERM")
        expect(described_class.all.map(&:id)).to be_any { |id|
          id.start_with?(subject.id)
        }
        expect(described_class.all(:all => true).map(&:id)).to be_any { |id|
          id.start_with?(subject.id)
        }

        subject.kill(:signal => "SIGKILL")
        expect(described_class.all.map(&:id)).to be_none { |id|
          id.start_with?(subject.id)
        }
        expect(described_class.all(:all => true).map(&:id)).to be_any { |id|
          id.start_with?(subject.id)
        }
      end
    end
  end

  describe '#delete' do
    subject { described_class.create('Cmd' => ['ls'], 'Image' => 'base') }

    it 'deletes the container', :vcr do
      subject.delete(:force => true)
      expect(described_class.all.map(&:id)).to be_none { |id|
        id.start_with?(subject.id)
      }
    end
  end

  describe '#restart' do
    subject { described_class.create('Cmd' => %w[sleep 50], 'Image' => 'base') }

    before { subject.start }

    it 'restarts the container', :vcr do
      expect(described_class.all.map(&:id)).to be_any { |id|
        id.start_with?(subject.id)
      }
      subject.stop
      expect(described_class.all.map(&:id)).to be_none { |id|
        id.start_with?(subject.id)
      }
      subject.restart('timeout' => '10')
      expect(described_class.all.map(&:id)).to be_any { |id|
        id.start_with?(subject.id)
      }
    end
  end

  describe '#pause' do
    subject {
      described_class.create('Cmd' => %w[sleep 50], 'Image' => 'base').start
    }

    it 'pauses the container', :vcr do
      subject.pause
      expect(described_class.get(subject.id).info['State']['Paused']).to be true
    end
  end

  describe '#unpause' do
    subject {
      described_class.create('Cmd' => %w[sleep 50], 'Image' => 'base').start
    }
    before { subject.pause }

    it 'unpauses the container', :vcr do
      subject.unpause
      expect(
        described_class.get(subject.id).info['State']['Paused']
      ).to be false
    end
  end

  describe '#wait' do
    subject { described_class.create('Cmd' => %w[tar nonsense],
                                     'Image' => 'base') }

    before { subject.start }

    it 'waits for the command to finish', :vcr do
      expect(subject.wait['StatusCode']).to_not be_zero
    end

    context 'when an argument is given' do
      subject { described_class.create('Cmd' => %w[sleep 5],
                                       'Image' => 'base') }

      it 'sets the :read_timeout to that amount of time', :vcr do
        expect(subject.wait(6)['StatusCode']).to be_zero
      end

      context 'and a command runs for too long' do
        it 'raises a ServerError', :vcr do
          skip "VCR doesn't like to record errors"
          expect { subject.wait(4) }.to raise_error(Docker::Error::TimeoutError)
        end
      end
    end
  end

  describe '#run' do
    let(:run_command) { subject.run('ls') }
    context 'when the Container\'s command does not return status code of 0' do
      subject { described_class.create('Cmd' => %w[lol not a real command],
                                       'Image' => 'base') }

      it 'raises an error', :vcr do
        expect { run_command }
            .to raise_error(Docker::Error::UnexpectedResponseError)
      end
    end

    context 'when the Container\'s command returns a status code of 0' do
      subject { described_class.create('Cmd' => %w[pwd],
                                       'Image' => 'base') }

      it 'creates a new container to run the specified command', :vcr do
        expect(run_command.wait['StatusCode']).to be_zero
      end
    end
  end

  describe '#commit' do
    subject { described_class.create('Cmd' => %w[true], 'Image' => 'base') }
    let(:image) { subject.commit }

    before { subject.start }

    it 'creates a new Image from the  Container\'s changes', :vcr do
      expect(image).to be_a Docker::Image
      expect(image.id).to_not be_nil
    end

    context 'if run is passed, it saves the command in the image', :vcr do
      let(:image) { subject.commit }
      it 'saves the command' do
        skip 'This is no longer working in v0.8'
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
            "Hostname"     => "",
            "User"         => "",
            "Memory"       => 0,
            "MemorySwap"   => 0,
            "AttachStdin"  => false,
            "AttachStdout" => false,
            "AttachStderr" => false,
            "PortSpecs"    => nil,
            "Tty"          => false,
            "OpenStdin"    => false,
            "StdinOnce"    => false,
            "Env"          => nil,
            "Cmd"          => ["date"],
            "Dns"          => nil,
            "Image"        => "base",
            "Volumes"      => {},
            "VolumesFrom"  => ""
          }
        end
        let(:container) { subject.create(options) }

        it 'sets the id', :vcr do
          expect(container).to be_a Docker::Container
          expect(container.id).to_not be_nil
          expect(container.connection).to_not be_nil
        end
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
      let(:container) { subject.create('Cmd' => ['ls'], 'Image' => 'base') }

      it 'materializes the Container into a Docker::Container', :vcr do
        expect(subject.get(container.id)).to be_a Docker::Container
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
      before { described_class.create('Cmd' => ['ls'], 'Image' => 'base') }

      it 'materializes each Container into a Docker::Container', :vcr do
        expect(subject.all(:all => true)).to be_all { |container|
          container.is_a?(Docker::Container)
        }
        expect(subject.all(:all => true).length).to_not be_zero
      end
    end
  end
end
