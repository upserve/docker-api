# frozen_string_literal: true

require 'bundler/setup'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec/its'

require 'single_cov'

# avoid coverage failure from lower docker versions not running all tests
SingleCov.setup :rspec

require 'docker'

# Hard-fail the build if we said we expected Podman but did not get it
if (ENV['EXPECT_PODMAN'] == 'true') && !Docker.podman?
  warn <<~MSG
    EXPECT_PODMAN=true was set, but Docker.podman? returned false.
    Connected engine information:
    #{Docker.version}
    Make sure the Podman API socket is running and DOCKER_HOST points to it.
  MSG
  exit 1
end

ENV['DOCKER_API_USER']  ||= 'debbie_docker'
ENV['DOCKER_API_PASS']  ||= '*************'
ENV['DOCKER_API_EMAIL'] ||= 'debbie_docker@example.com'

RSpec.shared_context "local paths" do
  def project_dir
    File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end
end

module SpecHelpers
  def skip_without_auth
    skip "Disabled because of missing auth" if ENV['DOCKER_API_USER'] == 'debbie_docker'
  end
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.color = true
  config.formatter = :documentation
  config.tty = true
  config.include SpecHelpers
end
