# frozen_string_literal: true

require 'spec_helper'

SingleCov.covered! uncovered: 8

describe Docker do
  subject { Docker }

  it { should be_a Module }

  context 'default url and connection' do
    context "when the DOCKER_* ENV variables aren't set" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_HOST').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH').and_return(nil)
        allow(Docker).to receive(:context_url).and_return(nil)
        allow(Gem).to receive(:win_platform?).and_return(false)
        Docker.reset!
      end
      after { Docker.reset! }

      its(:options) { should == {} }
      its(:url) { should == 'unix:///var/run/docker.sock' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when on Windows with no DOCKER_* ENV variables set" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_HOST').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH').and_return(nil)
        allow(Docker).to receive(:context_url).and_return(nil)
        allow(Gem).to receive(:win_platform?).and_return(true)
        Docker.reset!
      end
      after { Docker.reset! }

      its(:url) { should == 'npipe:////./pipe/docker_engine' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_* ENV variables are set" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL')
          .and_return('unixs:///var/run/not-docker.sock')
        allow(ENV).to receive(:[]).with('DOCKER_HOST').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH').and_return(nil)
        Docker.reset!
      end
      after { Docker.reset! }

      its(:options) { should == {} }
      its(:url) { should == 'unixs:///var/run/not-docker.sock' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_HOST is set and uses default tcp://" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_HOST').and_return('tcp://')
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH').and_return(nil)
        Docker.reset!
      end
      after { Docker.reset! }

      its(:options) { should == {} }
      its(:url) { should == 'tcp://localhost:2375' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_HOST ENV variable is set" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_HOST')
          .and_return('tcp://someserver:8103')
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH').and_return(nil)
        Docker.reset!
      end
      after { Docker.reset! }

      its(:options) { should == {} }
      its(:url) { should == 'tcp://someserver:8103' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "DOCKER_URL should take precedence over DOCKER_HOST" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL')
          .and_return('tcp://someotherserver:8103')
        allow(ENV).to receive(:[]).with('DOCKER_HOST')
          .and_return('tcp://someserver:8103')
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH').and_return(nil)
        Docker.reset!
      end
      after { Docker.reset! }

      its(:options) { should == {} }
      its(:url) { should == 'tcp://someotherserver:8103' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_CERT_PATH and DOCKER_HOST ENV variables are set" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_HOST')
          .and_return('tcp://someserver:8103')
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH')
          .and_return('/boot2dockert/cert/path')
        allow(ENV).to receive(:[]).with('DOCKER_SSL_VERIFY').and_return(nil)
        Docker.reset!
      end
      after { Docker.reset! }

      its(:options) {
        should == {
          client_cert: '/boot2dockert/cert/path/cert.pem',
          client_key: '/boot2dockert/cert/path/key.pem',
          ssl_ca_file: '/boot2dockert/cert/path/ca.pem',
          scheme: 'https'
        }
      }
      its(:url) { should == 'tcp://someserver:8103' }
      its(:connection) { should be_a Docker::Connection }
    end

    context "when the DOCKER_CERT_PATH and DOCKER_SSL_VERIFY ENV variables are set" do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('DOCKER_HOST')
          .and_return('tcp://someserver:8103')
        allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH')
          .and_return('/boot2dockert/cert/path')
        allow(ENV).to receive(:[]).with('DOCKER_SSL_VERIFY')
          .and_return('false')
        Docker.reset!
      end
      after { Docker.reset! }

      its(:options) {
        should == {
          client_cert: '/boot2dockert/cert/path/cert.pem',
          client_key: '/boot2dockert/cert/path/key.pem',
          ssl_ca_file: '/boot2dockert/cert/path/ca.pem',
          scheme: 'https',
          ssl_verify_peer: false
        }
      }
      its(:url) { should == 'tcp://someserver:8103' }
      its(:connection) { should be_a Docker::Connection }
    end

  end

  context 'docker CLI context resolution' do
    let(:config_dir) { '/tmp/fake-docker-config' }
    let(:config_path) { File.join(config_dir, 'config.json') }
    let(:context_name) { 'remote' }
    let(:context_id) { Digest::SHA256.hexdigest(context_name) }
    let(:meta_path) { File.join(config_dir, 'contexts', 'meta', context_id, 'meta.json') }
    let(:context_host) { 'tcp://remote.example.com:2376' }

    before do
      allow(ENV).to receive(:[]).with('DOCKER_URL').and_return(nil)
      allow(ENV).to receive(:[]).with('DOCKER_HOST').and_return(nil)
      allow(ENV).to receive(:[]).with('DOCKER_CERT_PATH').and_return(nil)
      allow(ENV).to receive(:[]).with('DOCKER_API_SKIP_CONTEXT').and_return(nil)
      allow(ENV).to receive(:[]).with('DOCKER_CONTEXT').and_return(nil)
      allow(ENV).to receive(:[]).with('DOCKER_CONFIG').and_return(config_dir)
      Docker.reset!
    end
    after { Docker.reset! }

    context 'when currentContext in config.json points to a non-default context' do
      before do
        allow(File).to receive(:exist?).with(config_path).and_return(true)
        allow(File).to receive(:read).with(config_path)
          .and_return(MultiJson.dump('currentContext' => context_name))
        allow(File).to receive(:exist?).with(meta_path).and_return(true)
        allow(File).to receive(:read).with(meta_path)
          .and_return(MultiJson.dump('Endpoints' => { 'docker' => { 'Host' => context_host } }))
      end

      its(:url) { should == context_host }
    end

    context 'when DOCKER_CONTEXT env overrides currentContext' do
      let(:context_name) { 'staging' }
      let(:other_host) { 'tcp://staging.example.com:2376' }

      before do
        allow(ENV).to receive(:[]).with('DOCKER_CONTEXT').and_return(context_name)
        allow(File).to receive(:exist?).with(config_path).and_return(true)
        allow(File).to receive(:read).with(config_path)
          .and_return(MultiJson.dump('currentContext' => 'something-else'))
        allow(File).to receive(:exist?).with(meta_path).and_return(true)
        allow(File).to receive(:read).with(meta_path)
          .and_return(MultiJson.dump('Endpoints' => { 'docker' => { 'Host' => other_host } }))
      end

      its(:url) { should == other_host }
    end

    context 'when currentContext is "default"' do
      before do
        allow(File).to receive(:exist?).with(config_path).and_return(true)
        allow(File).to receive(:read).with(config_path)
          .and_return(MultiJson.dump('currentContext' => 'default'))
      end

      its(:url) { should == 'unix:///var/run/docker.sock' }
    end

    context 'when config.json is absent' do
      before do
        allow(File).to receive(:exist?).with(config_path).and_return(false)
      end

      its(:url) { should == 'unix:///var/run/docker.sock' }
    end

    context 'when context meta is absent' do
      before do
        allow(File).to receive(:exist?).with(config_path).and_return(true)
        allow(File).to receive(:read).with(config_path)
          .and_return(MultiJson.dump('currentContext' => context_name))
        allow(File).to receive(:exist?).with(meta_path).and_return(false)
      end

      its(:url) { should == 'unix:///var/run/docker.sock' }
    end

    context 'when DOCKER_HOST is set, env takes precedence over context' do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_HOST').and_return('tcp://from-env:2375')
        allow(File).to receive(:exist?).with(config_path).and_return(true)
        allow(File).to receive(:read).with(config_path)
          .and_return(MultiJson.dump('currentContext' => context_name))
        allow(File).to receive(:exist?).with(meta_path).and_return(true)
        allow(File).to receive(:read).with(meta_path)
          .and_return(MultiJson.dump('Endpoints' => { 'docker' => { 'Host' => context_host } }))
      end

      its(:url) { should == 'tcp://from-env:2375' }
    end

    context 'when DOCKER_API_SKIP_CONTEXT=1, context lookup is disabled' do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_API_SKIP_CONTEXT').and_return('1')
        allow(File).to receive(:exist?).with(config_path).and_return(true)
        allow(File).to receive(:read).with(config_path)
          .and_return(MultiJson.dump('currentContext' => context_name))
      end

      its(:url) { should == 'unix:///var/run/docker.sock' }
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
      before { Docker.reset! }

      it 'calls #reset_connection!' do
        expect(subject).to receive(:reset_connection!)
        subject.public_send(method, nil)
      end
    end
  end

  describe '#version' do
    before { Docker.reset! }

    let(:expected) {
      %w[ApiVersion Arch GitCommit GoVersion KernelVersion Os Version]
    }

    let(:version) { subject.version }
    it 'returns the version as a Hash' do
      expect(version).to be_a Hash
      expect(version.keys.sort).to include(*expected)
    end
  end

  describe '#info' do
    before { Docker.reset! }

    let(:info) { subject.info }
    let(:keys) do
      %w(Containers Debug DockerRootDir Driver DriverStatus ID IPv4Forwarding
         Images IndexServerAddress KernelVersion Labels MemTotal MemoryLimit
         NCPU NEventsListener NFd NGoroutines Name OperatingSystem SwapLimit)
    end

    it 'returns the info as a Hash' do
      expect(info).to be_a Hash
      expect(info.keys.sort).to include(*keys)
    end
  end

  describe '#ping' do
    before { Docker.reset! }

    let(:ping) { subject.ping}

    it 'returns the status as a String' do
      expect(ping).to eq('OK')
    end
  end

  describe '#authenticate!' do
    subject { described_class }

    let(:authentication) {
      subject.authenticate!(credentials)
    }

    after { Docker.creds = nil }

    context 'with valid credentials' do
      let(:credentials) {
        {
          :username      => ENV['DOCKER_API_USER'],
          :password      => ENV['DOCKER_API_PASS'],
          :email         => ENV['DOCKER_API_EMAIL'],
          :serveraddress => 'https://index.docker.io/v1/'
        }
      }

      it 'logs in and sets the creds' do
        skip_without_auth
        expect(authentication).to be true
        expect(Docker.creds).to eq(MultiJson.dump(credentials))
      end
    end

    context 'with invalid credentials' do
      let(:credentials) {
        {
          :username      => 'test',
          :password      => 'password',
          :email         => 'test@example.com',
          :serveraddress => 'https://index.docker.io/v1/'
        }
      }

      it "raises an error and doesn't set the creds" do
        skip('Not supported on podman') if ::Docker.podman?
        expect {
          authentication
        }.to raise_error(Docker::Error::AuthenticationError)
        expect(Docker.creds).to be_nil
      end
    end
  end
end
