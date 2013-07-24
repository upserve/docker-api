require 'spec_helper'

describe Docker do
  subject { Docker }

  before do
    ENV['DOCKER_HOST'] = nil
    ENV['DOCKER_PORT'] = nil
  end

  it { should be_a Module }
  its(:options) { should == { :port => 4243 } }
  its(:url) { should == 'http://localhost' }
  its(:connection) { should be_a Docker::Connection }

  context 'when the DOCKER_HOST ENV variable is set' do
    let(:host) { 'google.com' }
    let(:url) { "http://#{host}" }

    before do
      Docker.instance_variable_set(:@url, nil)
      ENV['DOCKER_HOST'] = host
    end

    it 'sets Docker.url to that variable' do
      subject.url.should == url
    end
  end

  context 'when the DOCKER_PORT ENV variable is set' do
    let(:port) { 1234 }

    before do
      Docker.instance_variable_set(:@options, nil)
      ENV['DOCKER_PORT'] = port.to_s
    end

    it 'sets Docker.options[:port] to that variable' do
      subject.options[:port].should == port
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
    let(:version) { subject.version }
    it 'returns the version as a Hash', :vcr do
      version.should be_a Hash
      version.keys.sort.should == %w[GoVersion Version]
    end
  end

  describe '#info' do
    let(:info) { subject.info }
    let(:keys) do
      ["Containers", "Debug", "Images", "MemoryLimit", "NFd", "NGoroutines"]
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
