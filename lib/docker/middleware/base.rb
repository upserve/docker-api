# The base middleware for this gem; adds the correct User Agent, expectation,
# and adds the version to the path.
class Docker::Middleware::Base < Excon::Middleware::Base
  def request_call(datum)
    datum.deep_merge!(
      :path    => "/v#{Docker::API_VERSION}#{datum[:path]}",
      :headers => { 'User-Agent' => "Swipely/Docker-API #{Docker::VERSION}" },
      :expects => (200..204)
    )
    super
    datum
  end
end
