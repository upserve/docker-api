require 'spec_helper'

describe Docker::Middleware::Casifier do
  let(:extra_options) {
    {
      :middlewares => [described_class] + Excon.defaults[:middlewares],
      :mock => true
    }
  }

  subject { Excon.new(Docker.url, extra_options.merge(Docker.options)) }

  describe '#requst_call' do
    let(:req) {
      {
        :method => :post,
        :query => { :symbol_key => 1, 'string_key' => 2 },
        :body => { :symbol_key => true, 'string_key' => false },
        :headers => { 'Content-Type' => content_type }
      }
    }

    before do
      Excon.stub({},
        lambda { |request|
          if request[:query]['symbolKey'] && request[:body]['symbolKey']
            { :status => 201, :body => 'success' }
          else
            { :status => 404 }
          end
        }
      )
    end

    after { Excon.stubs.shift }

    context 'when the "Content-Type" is not "application/json"' do
      let(:content_type) { 'text/plain' }

      it 'does not modify the query or body' do
        expect { subject.request(req).status }.to raise_error
      end
    end

    context 'when the "Content-Type" is "application/json"' do
      let(:content_type) { 'application/json' }

      it 'camelizes each Symbolic key in the query and body' do
        subject.request(req).status.should == 201
        req[:query].should == { 'symbolKey' => 1, 'string_key' => 2 }
        req[:body].should == { 'symbolKey' => true, 'string_key' => false }
      end
    end
  end

  describe '#response_call' do
    let(:body) { '{"keyName":"value"}' }
    let(:parsed_body) { { :key_name => 'value' } }

    let(:request) {
      {
        :method  => :post,
        :path    => '/lol',
        :body    => body,
      }
    }
    before do
      Excon.stub(
        {},
        lambda do |request|
          {
            :status => 201,
            :body => request[:body],
            :headers => { 'Content-Type' => content_type }
          }
        end
      )
    end

    after { Excon.stubs.shift }

    context 'when the "Content-Type" is not "application/json"' do
      let(:content_type) { 'text/plain' }

      it 'does not modify the response' do
        subject.request(request).body.should == body
      end
    end

    context 'when the "Content-Type" is "application/json"' do
      let(:content_type) { 'application/json' }

      it 'parses the result' do
        subject.request(request).body.should == parsed_body
      end
    end
  end

  describe '#snakeify!' do
    subject { described_class.new(Excon::Middleware::Base) }

    let(:hash) {
      {
        :body => body,
        :headers => { 'Content-Type' => content_type }
      }
    }
    let(:body) { 'body data' }

    context 'when `#is_json?` returns false' do
      let(:content_type) { 'text/plain' }

      it 'does not modify the Hash' do
        expect { subject.snakeify!(:body, hash) }.to_not change { hash }
      end
    end

    context 'when `#is_json?` returns true' do
      let(:content_type) { 'application/json' }

      context 'when the Hash does not have the specified key' do
        it 'does not modify the Hash' do
          subject.is_json?(hash).should be_true
          expect { subject.snakeify!(:query, hash) }.to_not change { hash }
        end
      end

      context 'when the Hash does have the specified key' do
        context 'when the value of that key is not a String' do
          it 'does not modify the Hash' do
            expect { subject.snakeify!(:query, hash) }.to_not change { hash }
          end
        end

        context 'when the value of that key is a Hash' do
          let(:body) { initial.dup }
          let(:initial) { { "laughOutLoud" => "lol" } }
          let(:expected) { { :laugh_out_loud =>  'lol' } }

          it 'converts the Hash into a snakified JSON String' do
            expect { subject.snakeify!(:body, hash) }
                .to change { hash[:body] }
                .from(initial)
                .to(expected)
          end
        end
      end
    end
  end

  describe '#camelize!' do
    subject { described_class.new(Excon::Middleware::Base) }

    let(:hash) {
      {
        :body => body,
        :headers => { 'Content-Type' => content_type }
      }
    }
    let(:body) { 'body data' }

    context 'when `#is_json?` returns false' do
      let(:content_type) { 'text/plain' }

      it 'does not modify the Hash' do
        expect { subject.camelize!(:body, hash) }.to_not change { hash }
      end
    end

    context 'when `#is_json?` returns true' do
      let(:content_type) { 'application/json' }

      context 'when the Hash does not have the specified key' do
        it 'does not modify the Hash' do
          subject.is_json?(hash).should be_true
          expect { subject.camelize!(:query, hash) }.to_not change { hash }
        end
      end

      context 'when the Hash does have the specified key' do
        context 'when the value of that key is not a Hash' do
          it 'does not modify the Hash' do
            expect { subject.camelize!(:query, hash) }.to_not change { hash }
          end
        end

        context 'when the value of that key is a Hash' do
          let(:body) { initial.dup }
          let(:initial) { { :laugh_out_loud =>  'lol' } }
          let(:expected) { { "laughOutLoud" => "lol" } }

          it 'converts the Hash into a camel-cased JSON String' do
            expect { subject.camelize!(:body, hash) }
                .to change { hash[:body] }
                .from(initial)
                .to(expected)
          end
        end
      end
    end
  end
end
