require 'spec_helper'

describe Docker::Middleware::Base do
  let(:extra_options) {
    {
      :middlewares => [described_class] + Excon.defaults[:middlewares],
      :mock => true
    }
  }

  subject { Excon.new(Docker.url, extra_options.merge(Docker.options)) }

  describe '#request_call' do
    before do
      Excon.stub(
        {},
        lambda do |request|
          {
            :status => 200,
            :body   => [request[:path],
                        request[:expects],
                        request[:headers]['User-Agent']]
          }
        end
      )
    end

    let(:response) { subject.get(:path => 'test').body }
    let(:path) { response[0] }
    let(:expects) { response[1] }
    let(:user_agent) { response[2] }

    after { Excon.stubs.shift }

    it 'adds the correct user agent' do
      user_agent.should == "Swipely/Docker-API #{Docker::VERSION}"
    end

    it 'sets the anticipated version in the path' do
      path.should == '/v1.4/test'
    end

    it 'expects a succeesful response' do
      expects.should == (200..204)
    end
  end
end
