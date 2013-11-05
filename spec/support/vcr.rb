require 'vcr'

VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = false
  c.hook_into :excon
  c.cassette_library_dir = File.join(File.dirname(__FILE__), '..', 'vcr')
  c.configure_rspec_metadata!
end
