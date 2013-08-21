require 'spec_helper'

describe Docker::Middleware::JSON do
  let(:extra_options) {
    {
      :middlewares => [described_class] + Excon.defaults[:middlewares],
      :mock => true
    }
  }

  subject { Excon.new(Docker.url, extra_options.merge(Docker.options)) }

  describe '#request_call' do
    let(:response) {
      lambda { |params| { :body => params[:body], :status => 200 } }
    }

    before { Excon.stub({}, response) }
    after { Excon.stubs.shift }

    context 'when the "Content-Type" is not "application/json"' do
      let(:body) { 'test body' }

      it 'does not modify the body' do
        body.should_not_receive(:to_json)
        subject.post(
          :path    => '/test',
          :body    => body,
          :headers => { 'Content-Type' => 'text/plain' }
        )
      end
    end

    context 'when the "Content-Type" is "application/json"' do
      context 'when the body is not a Hash' do
        let(:body) { '{"test":"hello"}' }

        it 'does not modify the body' do
          body.should_not_receive(:to_json)
          subject.post(
            :path    => '/test',
            :body    => body,
            :headers => { 'Content-Type' => 'application/json' }
          )
        end
      end

      context 'when the body is a Hash' do
        let(:body) { { :test => 'hello' } }

        it 'converts the body to a JSON String' do
          subject.post(
            :path    => '/test',
            :body    => body,
            :headers => { 'Content-Type' => 'application/json' }
          )
        end
      end
    end
  end

  describe '#response_call' do
    let(:body) { '{"It Works":true}' }
    let(:response) {
      lambda do |params|
        {
          :headers => { 'Content-Type' => content_type },
          :body => body,
          :status => 200
        }
      end
    }

    before { Excon.stub({}, response) }
    after { Excon.stubs.shift }

    context 'when the "Content-Type" is not "application/json"' do
      let(:content_type) { 'text/plain' }

      it 'does not modify the body' do
        subject.get(:path => '/test').body.should == body
      end
    end

    context 'when the "Content-Type" is "application/json"' do
      let(:content_type) { 'application/json' }

      context 'when the parse fails' do
        let(:body) { 'lol not json' }

        it 'does not modify the body' do
          subject.get(:path => '/test').body.should == body
        end
      end

      context 'when the parse succeeds' do
        let(:parsed) { { 'It Works' => true } }
        it 'parses the body' do
          subject.get(:path => '/test').body.should == parsed
        end
      end
    end
  end

  describe '#is_json?' do
    subject { described_class.new(Excon::Middleware::Base).is_json?(arg) }

    context 'when the Hash does not have a :headers key' do
      let(:arg) { { :not_headers => true } }

      it { should be_false }
    end

    context 'when the Hash does have a :headers key' do
      let(:arg) { { :headers => { 'Content-Type' => content_type } } }

      context 'when it\'s "Content-Type" is not "application/json"' do
        let(:content_type) { 'text/plain' }

        it { should be_false }
      end

      context 'when it\'s "Content-Type" is "application/json"' do
        let(:content_type) { 'application/json' }

        it { should be_true }
      end
    end
  end
end
