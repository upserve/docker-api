require 'spec_helper'

describe Docker do
  subject { Docker }

  before do
    ENV['DOCKER_HOST'] = nil
    ENV['DOCKER_PORT'] = nil
    ENV['DOCKER_SOCKET'] = nil
  end

  it { should be_a Module }
  context 'without calling with_socket or with_port' do
    before do
      subject.instance_variable_set(:@url, nil)
      subject.instance_variable_set(:@options, nil)
    end

    context "when the DOCKER_* ENV variables aren't set" do
      before do
      end

      its(:options) {
        should == { :port => nil, :socket => '/var/run/docker.sock' }
      }
      its(:url) { should == 'unix:///' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_* ENV variables are set" do
      before do
        ENV['DOCKER_HOST'] = 'unixs:///'
        ENV['DOCKER_PORT'] = '1234'
        ENV['DOCKER_SOCKET'] = '/var/run/not-docker.sock'
      end

      its(:options) {
        should == { :port => "1234", :socket => '/var/run/not-docker.sock' }
      }
      its(:url) { should == 'unixs:///' }
      its(:connection) { should be_a Docker::Connection }
    end
  end

  context 'when Docker.with_socket is called' do
    context 'when the DOCKER_SOCKET ENV variable is set' do
      let(:socket) { '/var/run/not-docker.sock' }
      before do
        Docker.instance_variable_set(:@url, nil)
        Docker.instance_variable_set(:@options, nil)
        ENV['DOCKER_SOCKET'] = socket
        Docker.with_socket
      end

      it 'sets Docker.url to "unix:///"' do
        expect(subject.url).to eq('unix:///')
      end

      it 'sets Docker.options[:socket] to that variable' do
        expect(subject.options[:socket]).to eq(socket)
      end
    end
  end

  context 'when Docker.with_port is called' do
    context 'when the DOCKER_HOST ENV variable is set' do
      let(:host) { 'http://google.com' }

      before do
        Docker.instance_variable_set(:@url, nil)
        ENV['DOCKER_HOST'] = host
        Docker.with_port
      end

      it 'sets Docker.url to that variable' do
        expect(subject.url).to eq(host)
      end
    end

    context 'when the DOCKER_PORT ENV variable is set' do
      let(:port) { 1234 }

      before do
        Docker.instance_variable_set(:@options, nil)
        ENV['DOCKER_PORT'] = port.to_s
        Docker.with_port
      end

      it 'sets Docker.options[:port] to that variable' do
        expect(subject.options[:port]).to eq(port.to_s)
      end
    end
  end

  describe '#reset_connection!' do
    before { subject.connection }
    it 'sets the @connection to nil' do
      expect { subject.reset_connection! }
          .to change { subject.instance_variable_get(:@connection) }
          .to nil
    end
  end

  [:options=, :url=].each do |method|
    describe "##{method}" do
      after(:all) do
        subject.options = { :port => 4243 }
        subject.url = 'http://localhost'
      end
      it 'calls #reset_connection!' do
        subject.should_receive(:reset_connection!)
        subject.public_send(method, {})
      end
    end
  end

  describe '#version' do
    before do
      subject.instance_variable_set(:@url, nil)
      subject.instance_variable_set(:@options, nil)
      subject.reset_connection!
    end

    let(:version) { subject.version }
    it 'returns the version as a Hash', :vcr do
      version.should be_a Hash
      version.keys.sort.should == %w[GitCommit GoVersion Version]
    end
  end

  describe '#info' do
    before do
      subject.instance_variable_set(:@url, nil)
      subject.instance_variable_set(:@options, nil)
      subject.reset_connection!
    end

    let(:info) { subject.info }
    let(:keys) do
      %w(Containers Debug IPv4Forwarding Images IndexServerAddress
         KernelVersion LXCVersion MemoryLimit NEventsListener NFd
         NGoroutines)
    end

    it 'returns the info as a Hash', :vcr do
      info.should be_a Hash
      info.keys.sort.should == keys
    end
  end

  describe '#authenticate!' do
    it 'logs in' do
      pending
    end
  end

  describe '#validate_version' do
    before do
      subject.instance_variable_set(:@url, nil)
      subject.instance_variable_set(:@options, nil)
      subject.reset_connection!
    end

    context 'when a Docker Error is raised' do
      before { Docker.stub(:info).and_raise(Docker::Error::ClientError) }

      it 'raises a Version Error' do
        expect { subject.validate_version! }
            .to raise_error(Docker::Error::VersionError)
      end
    end

    context 'when nothing is raised', :vcr do
      its(:validate_version!) { should be_true }
    end
  end
end
