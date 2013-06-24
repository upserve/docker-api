require 'spec_helper'

describe Docker::Connection do
  describe '#initialize' do
    subject { described_class }

    context 'with no arguments' do
      it 'defaults to port 4243' do
        subject.new.options.should == { :port => 4243 }
      end

      it 'defaults to \'http://localhost\' for the url' do
        subject.new.url.should == 'http://localhost'
      end
    end

    context 'with an argument' do
      context 'when the second argument is not a Hash' do
        it 'raises a Docker::Error::ArgumentError' do
          expect { subject.new('http://localhost', :lol) }
              .to raise_error Docker::Error::ArgumentError
        end
      end

      context 'when the argument is a Hash' do
        let(:url) { 'google.com' }
        let(:port) { 80 }
        let(:options) { { :port => port } }

        it 'sets the specified url' do
          subject.new(url, options).url.should == url
        end

        it 'sets the specified port' do
          subject.new(url, options).options[:port].should == port
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
        subject.should_receive(:reset!)
        subject.stub_chain(:resource, :public_send).and_return(:lol)
        subject.public_send(method).should == :lol
      end
    end
  end

  describe '#to_s' do
    let(:url) { 'google.com' }
    let(:port) { 4000 }
    let(:options) { { :port => port } }
    let(:expected_string) do
      "Docker::Connection { :url => #{url}, :options => #{options} }"
    end
    subject { described_class.new(url, options) }

    it 'returns a pretty printed version with the url and port' do
      subject.to_s.should == expected_string
    end
  end
end
