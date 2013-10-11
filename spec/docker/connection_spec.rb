require 'spec_helper'

describe Docker::Connection do
  subject { described_class.new('http://localhost:4243', {}) }

  describe '#initialize' do
    let(:url) { 'http://localhost:4243' }
    let(:options) { {} }
    subject { described_class.new(url, options) }

    context 'when the first argument is not a String' do
      let(:url) { :lol_not_a_string }

      it 'raises an error' do
        expect { subject }.to raise_error(Docker::Error::ArgumentError)
      end
    end

    context 'when the first argument is a String' do
      context 'and the url is a unix socket' do
        let(:url) { 'unix:///var/run/docker.sock' }

        it 'sets the socket path in the options' do
          expect(subject.url).to eq('unix:///')
          expect(subject.options).to include(:socket => '/var/run/docker.sock')
        end
      end

      context 'but the second argument is not a Hash' do
        let(:options) { :lol_not_a_hash }

        it 'raises an error' do
          expect { subject }.to raise_error(Docker::Error::ArgumentError)
        end
      end

      context 'and the second argument is a Hash' do
        it 'sets the url and options' do
          subject.url.should == url
          subject.options.should == options
        end
      end
    end
  end

  describe '#resource' do
    its(:resource) { should be_a Excon::Connection }
  end

  describe '#request' do
    let(:method) { :get }
    let(:path) { '/test' }
    let(:query) { { :all => true } }
    let(:options) { { :expects => 201, :lol => true } }
    let(:body) { rand(10000000) }
    let(:resource) { mock(:resource) }
    let(:response) { mock(:response, :body => body) }
    let(:expected_hash) {
      {
        :method  => method,
        :path    => "/v#{Docker::API_VERSION}#{path}",
        :query   => query,
        :headers => { 'Content-Type' => 'text/plain',
                      'User-Agent'   => "Swipely/Docker-API #{Docker::VERSION}",
                    },
        :expects => 201,
        :idempotent => true,
        :lol => true
      }
    }

    before do
      subject.stub(:resource).and_return(resource)
      resource.should_receive(:request).with(expected_hash).and_return(response)
    end

    it 'sends #request to #resource with the compiled params' do
      subject.request(method, path, query, options).should == body
    end
  end

  [:get, :put, :post, :delete].each do |method|
    describe "##{method}" do
      it 'is delegated to #request' do
        subject.should_receive(:request).with(method)
        subject.public_send(method)
      end
    end
  end

  describe '#to_s' do
    let(:url) { 'http://google.com:4000' }
    let(:options) { {} }
    let(:expected_string) {
      "Docker::Connection { :url => #{url}, :options => #{options} }"
    }
    subject { described_class.new(url, options) }

    it 'returns a pretty version with the url and port' do
      subject.to_s.should == expected_string
    end
  end
end
