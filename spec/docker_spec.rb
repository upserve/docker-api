require 'spec_helper'

describe Docker do
  subject { Docker }

  before do
    ENV['DOCKER_URL'] = nil
  end

  it { should be_a Module }

  context 'default url and connection' do
    before do
      Docker.url = nil
      Docker.options = nil
    end

    context "when the DOCKER_* ENV variables aren't set" do
      its(:options) { {} }
      its(:url) { should == 'unix:///var/run/docker.sock' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_* ENV variables are set" do
      before do
        ENV['DOCKER_URL'] = 'unixs:///var/run/not-docker.sock'
      end

      its(:options) { {} }
      its(:url) { should == 'unixs:///var/run/not-docker.sock' }
      its(:connection) { should be_a Docker::Connection }
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
        subject.instance_variable_set(:@url, nil)
        subject.instance_variable_set(:@options, nil)
      end
      it 'calls #reset_connection!' do
        subject.should_receive(:reset_connection!)
        subject.public_send(method, {})
      end
    end
  end

  describe '#version' do
    before do
      subject.url = nil
      subject.options = nil
    end

    let(:version) { subject.version }
    it 'returns the version as a Hash', :vcr do
      version.should be_a Hash
      version.keys.sort.should == %w[GitCommit GoVersion Version]
    end
  end

  describe '#info' do
    before do
      subject.url = nil
      subject.options = nil
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
      subject.url = nil
      subject.options = nil
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
