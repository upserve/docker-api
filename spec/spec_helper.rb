require 'bundler/setup'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec/its'

require 'single_cov'

# avoid coverage failure from lower docker versions not running all tests
if !ENV['DOCKER_VERSION'] || ENV['DOCKER_VERSION'] =~ /^1\.\d\d/
  SingleCov.setup :rspec, branches: false # https://github.com/grosser/single_cov/issues/19
end

require 'docker'

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

  case ENV['DOCKER_VERSION']
  when /^1\.6/
    config.filter_run_excluding :docker_1_7 => true
    config.filter_run_excluding :docker_1_8 => true
    config.filter_run_excluding :docker_1_9 => true
    config.filter_run_excluding :docker_1_10 => true
    config.filter_run_excluding :docker_1_11 => true
    config.filter_run_excluding :docker_1_12 => true
    config.filter_run_excluding :docker_1_13 => true
    config.filter_run_excluding :docker_17_03 => true
  when /^1\.7/
    config.filter_run_excluding :docker_1_8 => true
    config.filter_run_excluding :docker_1_9 => true
    config.filter_run_excluding :docker_1_10 => true
    config.filter_run_excluding :docker_1_11 => true
    config.filter_run_excluding :docker_1_12 => true
    config.filter_run_excluding :docker_1_13 => true
    config.filter_run_excluding :docker_17_03 => true
  when /^1\.8/
    config.filter_run_excluding :docker_1_9 => true
    config.filter_run_excluding :docker_1_10 => true
    config.filter_run_excluding :docker_1_11 => true
    config.filter_run_excluding :docker_1_12 => true
    config.filter_run_excluding :docker_1_13 => true
    config.filter_run_excluding :docker_17_03 => true
  when /^1\.9/
    config.filter_run_excluding :docker_1_10 => true
    config.filter_run_excluding :docker_1_11 => true
    config.filter_run_excluding :docker_1_12 => true
    config.filter_run_excluding :docker_1_13 => true
    config.filter_run_excluding :docker_17_03 => true
  when /^1\.10/
    config.filter_run_excluding :docker_1_11 => true
    config.filter_run_excluding :docker_1_12 => true
    config.filter_run_excluding :docker_1_13 => true
    config.filter_run_excluding :docker_17_03 => true
  when /^1\.11/
    config.filter_run_excluding :docker_1_12 => true
    config.filter_run_excluding :docker_1_13 => true
    config.filter_run_excluding :docker_17_03 => true
  when /^1\.12/
    config.filter_run_excluding :docker_1_12 => false
    config.filter_run_excluding :docker_1_13 => true
    config.filter_run_excluding :docker_17_03 => true
  when /^1\.13/
    config.filter_run_excluding :docker_1_12 => false
    config.filter_run_excluding :docker_17_03 => true
  when /^17\.03/
    config.filter_run_excluding :docker_1_12 => false
    config.filter_run_excluding :docker_old => true
  end
end
