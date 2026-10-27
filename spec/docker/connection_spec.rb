# frozen_string_literal: true

require 'spec_helper'

# Specs that are skipped on Podman leave one more line uncovered there.
SingleCov.covered! uncovered: (::Docker.podman? ? 13 : 12)

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
        let(:url) { ::Docker.env_url || ::Docker.default_socket_url }

        it 'sets the socket path in the options' do
          expect(subject.url).to eq('unix:///')
          expect(subject.options).to include(:socket => url.split('//').last)
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
          expect(subject.url).to eq url
          expect(subject.options).to eq options
        end
      end
    end

    context 'url conversion to uri' do
      context 'when the url does not contain a scheme' do
        let(:url) { 'localhost:4243' }

        it 'adds the scheme to the url' do
          expect(subject.url).to eq "http://#{url}"
        end
      end

      context 'when the url is a complete uri' do
        let(:url) { 'http://localhost:4243' }

        it 'leaves the url intact' do
          expect(subject.url).to eq url
        end
      end
    end
  end

  describe '#resource' do
    # #resource is private, so it cannot go through `its`, which uses
    # public_send on Ruby 3.0+.
    it 'is an Excon::Connection' do
      expect(subject.send(:resource)).to be_a Excon::Connection
    end
  end

  describe '#request' do
    let(:method) { :get }
    let(:path) { '/test' }
    let(:query) { { :all => true } }
    let(:options) { { :expects => 201, :lol => true } }
    let(:body) { rand(10000000) }
    let(:resource) { double(:resource) }
    let(:response) { double(:response, :body => body) }
    let(:expected_hash) {
      {
        :method  => method,
        :path    => path,
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
      allow(subject).to receive(:resource).and_return(resource)
      expect(resource).to receive(:request).
        with(expected_hash).
        and_return(response)
    end

    it 'sends #request to #resource with the compiled params' do
      expect(subject.request(method, path, query, options)).to eq body
    end
  end

  [:get, :put, :post, :delete].each do |method|
    describe "##{method}" do
      it 'is delegated to #request' do
        expect(subject).to receive(:request).with(method)
        subject.public_send(method)
      end
    end
  end

  describe '#rootless?' do
    subject { described_class.new('http://example.com:2375', {}) }

    # `@rootless ||= ...` cannot cache a false result, so on every non-rootless
    # daemon each call re-issued the /info request.
    it 'only queries /info once' do
      expect(subject).to receive(:get).with('/info').once
        .and_return('{"Rootless":false}')

      3.times { subject.rootless? }
    end

    it 'reports false for a non-rootless daemon' do
      allow(subject).to receive(:get).with('/info')
        .and_return('{"Rootless":false}')

      expect(subject.rootless?).to be false
    end

    it 'reports true for a rootless daemon' do
      allow(subject).to receive(:get).with('/info')
        .and_return('{"Rootless":true}')

      expect(subject.rootless?).to be true
    end
  end

  describe '#podman?' do
    subject { described_class.new('http://example.com:2375', {}) }

    it 'only queries /version once' do
      expect(subject).to receive(:get).with('/version').once
        .and_return('{"Components":[{"Name":"Engine"}]}')

      3.times { subject.podman? }
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
      expect(subject.to_s).to eq expected_string
    end
  end
end
