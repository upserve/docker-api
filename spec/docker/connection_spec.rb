require 'spec_helper'

describe Docker::Connection do
  describe '#initialize' do
    subject { described_class }

    context 'with no arguments' do
      it 'defaults to port 4243' do
        subject.new.port.should == 4243
      end

      it 'defaults to \'localhost\' for the host' do
        subject.new.host.should == 'localhost'
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

  context '#resource' do
    its(:resource) { should be_a RestClient::Resource }
  end

  [:get, :put, :post, :delete, :[]].each do |method|
    context "##{method}" do
      it 'is delegated to #resource' do
        subject.resource.should_receive(method)
        subject.public_send(method)
      end
    end
  end
end
