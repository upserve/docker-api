require 'spec_helper'

describe Docker do
  subject { Docker }

  before do
    ENV['DOCKER_URL'] = nil
    ENV['DOCKER_HOST'] = nil
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

    context "when the DOCKER_HOST is set and uses default tcp://" do
      before do
        ENV['DOCKER_HOST'] = 'tcp://'
      end

      its(:options) { {} }
      its(:url) { should == 'tcp://localhost:2375' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_HOST ENV variables is set" do
      before do
        ENV['DOCKER_HOST'] = 'tcp://someserver:8103'
      end

      its(:options) { {} }
      its(:url) { should == 'tcp://someserver:8103' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "DOCKER_URL should take precedence over DOCKER_HOST" do
      before do
        ENV['DOCKER_HOST'] = 'tcp://someserver:8103'
        ENV['DOCKER_URL'] = 'tcp://someotherserver:8103'

      end

      its(:options) { {} }
      its(:url) { should == 'tcp://someotherserver:8103' }
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
      before do
        subject.url = nil
        subject.options = nil
      end

      it 'calls #reset_connection!' do
        expect(subject).to receive(:reset_connection!)
        subject.public_send(method, {})
      end
    end
  end

  describe '#version' do
    before do
      subject.url = nil
      subject.options = nil
    end
    let(:expected) {
      %w[ApiVersion Arch GitCommit GoVersion KernelVersion Os Version]
    }

    let(:version) { subject.version }
    it 'returns the version as a Hash', :vcr do
      expect(version).to be_a Hash
      expect(version.keys.sort).to eq expected
    end
  end

  describe '#info' do
    before do
      subject.url = nil
      subject.options = nil
    end

    let(:info) { subject.info }
    let(:keys) do
      %w(Containers Debug Driver DriverStatus ExecutionDriver IPv4Forwarding
         Images IndexServerAddress InitPath InitSha1 KernelVersion MemoryLimit
         NEventsListener NFd NGoroutines SwapLimit)
    end

    it 'returns the info as a Hash', :vcr do
      expect(info).to be_a Hash
      expect(info.keys.sort).to eq keys
    end
  end

  describe '#authenticate!' do
    subject { described_class }

    let(:authentication) {
      subject.authenticate!(credentials)
    }

    after do
      Docker.creds = nil
    end

    context 'with valid credentials' do
      # Used valid credentials to record VCR and then changed
      # cassette to match these credentials
      let(:credentials) {
        {
          :username      => 'tlunter',
          :password      => '************',
          :email         => 'tlunter@gmail.com',
          :serveraddress => 'https://index.docker.io/v1/'
        }
      }

      it 'logs in and sets the creds', :vcr do
        expect(authentication).to be true
        expect(Docker.creds).to eq(credentials.to_json)
      end
    end

    context 'with invalid credentials' do
      # Recorded the VCR with these credentials
      # to purposely fail
      let(:credentials) {
        {
          :username      => 'test',
          :password      => 'password',
          :email         => 'test@example.com',
          :serveraddress => 'https://index.docker.io/v1/'
        }
      }

      it "raises an error and doesn't set the creds", :vcr do
        skip "VCR won't record when Excon::Expects fail"
        expect {
          authentication
        }.to raise_error(Docker::Error::AuthenticationError)
        expect(Docker.creds).to be_nil
      end
    end
  end

  describe '#validate_version' do
    before do
      subject.url = nil
      subject.options = nil
    end

    context 'when a Docker Error is raised' do
      before do
        allow(Docker).to receive(:info).and_raise(Docker::Error::ClientError)
      end

      it 'raises a Version Error' do
        expect { subject.validate_version! }
            .to raise_error(Docker::Error::VersionError)
      end
    end

    context 'when nothing is raised', :vcr do
      its(:validate_version!) { should be true }
    end
  end
end
