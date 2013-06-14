require 'spec_helper'

describe Docker::Connection do
  describe '#initialize' do
    subject { described_class }

    context 'with no arguments' do
      it 'defaults to port 4243' do
        subject.new.port.should == 4243
      end

      it 'defaults to \'localhost\' for the host' do
        subject.new.host.should == 'http://localhost'
      end
    end

    context 'with an argument' do
      context 'when the argument is not a Hash' do
        it 'raises a Docker::Error::ArgumentError' do
          expect { subject.new(:not_a_hash) }
              .to raise_error Docker::Error::ArgumentError
        end
      end

      context 'when the argument is a Hash' do
        let(:host) { 'google.com' }
        let(:port) { 80 }
        let(:options) { { :host => host, :port => port } }

        it 'sets the specified host' do
          subject.new(options).host.should == host
        end

        it 'sets the specified port' do
          subject.new(options).port.should == port
        end
      end
    end
  end

  describe '#resource' do
    its(:resource) { should be_a Excon::Connection }
  end

  [:get, :put, :post, :delete].each do |method|
    describe "##{method}" do
      it 'is delegated to #resource' do
        subject.resource.should_receive(method)
        subject.public_send(method)
      end
    end
  end

  describe '#==' do
    let(:host) { 'localhost' }
    let(:port) { 4243 }
    subject { described_class.new(:host => host, :port => port) }

    context 'when the argument is not a Docker::Connection' do
      let(:other_connection) { :not_a_connection }

      it 'returns false' do
        (subject == other_connection).should be_false
      end
    end

    context 'when the argument is a Docker::Connection' do
      let(:other_connection) { described_class.new(:host => other_host,
                                                   :port => other_port) }

      context 'and the host and/or port are the different' do
        let(:other_host) { 'google.com' }
        let(:other_port) { 1000 }

        it 'returns false' do
          (subject == other_connection).should be_false
        end
      end

      context 'and the host and port are the same' do
        let(:other_host) { host }
        let(:other_port) { port }

        it 'returns true' do
          (subject == other_connection).should be_true
        end
      end
    end
  end

  describe '#to_s' do
    let(:host) { 'google.com' }
    let(:port) { 4000 }
    let(:expected_string) do
      "Docker::Connection { :host => #{host}, :port => #{port} }"
    end
    subject { described_class.new(:host => host, :port => port) }

    it 'returns a pretty printed version with the host and port' do
      subject.to_s.should == expected_string
    end
  end
end
