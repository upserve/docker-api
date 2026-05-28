# frozen_string_literal: true

require 'cgi'
require 'multi_json'
require 'excon'
require 'tempfile'
require 'base64'
require 'digest'
require 'find'
require 'rubygems/package'
require 'uri'
require 'open-uri'

# Add the Hijack middleware at the top of the middleware stack so it can
# potentially hijack HTTP sockets (when attaching to stdin) before other
# middlewares try and parse the response.
require 'excon/middlewares/hijack'
Excon.defaults[:middlewares].unshift Excon::Middleware::Hijack

Excon.defaults[:middlewares] << Excon::Middleware::RedirectFollower

# The top-level module for this gem. Its purpose is to hold global
# configuration variables that are used as defaults in other classes.
module Docker
  attr_accessor :creds, :logger

  require 'docker/error'
  require 'docker/connection'
  require 'docker/base'
  require 'docker/container'
  require 'docker/network'
  require 'docker/event'
  require 'docker/exec'
  require 'docker/image'
  require 'docker/messages_stack'
  require 'docker/messages'
  require 'docker/util'
  require 'docker/version'
  require 'docker/volume'
  require 'docker/rake_task' if defined?(Rake::Task)

  def default_socket_url
    if Gem.win_platform?
      'npipe:////./pipe/docker_engine'
    else
      'unix:///var/run/docker.sock'
    end
  end

  def env_url
    ENV['DOCKER_URL'] || ENV['DOCKER_HOST']
  end

  # Resolve the docker endpoint from the docker CLI config, mirroring the CLI
  # lookup: DOCKER_CONTEXT env first, then `currentContext` from config.json
  # under $DOCKER_CONFIG (or ~/.docker). Returns nil when no usable context is
  # found or when disabled via DOCKER_API_SKIP_CONTEXT=1.
  def context_url
    return nil if ENV['DOCKER_API_SKIP_CONTEXT'] == '1'

    name = ENV['DOCKER_CONTEXT'] || current_context_from_config
    return nil if name.nil? || name.empty? || name == 'default'

    endpoint_from_context(name)
  end

  def config_dir
    ENV['DOCKER_CONFIG'] || File.join(Dir.home, '.docker')
  end

  def current_context_from_config
    config_path = File.join(config_dir, 'config.json')
    return nil unless File.exist?(config_path)
    MultiJson.load(File.read(config_path))['currentContext']
  rescue StandardError
    nil
  end

  def endpoint_from_context(name)
    id = Digest::SHA256.hexdigest(name)
    meta_path = File.join(config_dir, 'contexts', 'meta', id, 'meta.json')
    return nil unless File.exist?(meta_path)
    MultiJson.load(File.read(meta_path)).dig('Endpoints', 'docker', 'Host')
  rescue StandardError
    nil
  end

  def env_options
    if cert_path = ENV['DOCKER_CERT_PATH']
      {
        client_cert: File.join(cert_path, 'cert.pem'),
        client_key: File.join(cert_path, 'key.pem'),
        ssl_ca_file: File.join(cert_path, 'ca.pem'),
        scheme: 'https'
      }.merge(ssl_options)
    else
      {}
    end
  end

  def ssl_options
    if ENV['DOCKER_SSL_VERIFY'] == 'false'
      {
        ssl_verify_peer: false
      }
    else
      {}
    end
  end

  def url
    @url ||= env_url || context_url || default_socket_url
    # docker uses a default notation tcp:// which means tcp://localhost:2375
    if @url == 'tcp://'
      @url = 'tcp://localhost:2375'
    end
    @url
  end

  def options
    @options ||= env_options
  end

  def url=(new_url)
    @url = new_url
    reset_connection!
  end

  def options=(new_options)
    @options = env_options.merge(new_options || {})
    reset_connection!
  end

  def connection
    @connection ||= Connection.new(url, options)
  end

  def reset!
    @url = nil
    @options = nil
    reset_connection!
  end

  def reset_connection!
    @connection = nil
  end

  # Get the version of Go, Docker, and optionally the Git commit.
  def version(connection = self.connection)
    connection.version
  end

  # Get more information about the Docker server.
  def info(connection = self.connection)
    connection.info
  end

  # Ping the Docker server.
  def ping(connection = self.connection)
    connection.ping
  end

  # Determine if the server is podman or docker.
  def podman?(connection = self.connection)
    connection.podman?
  end

  # Determine if the session is rootless.
  def rootless?(connection = self.connection)
    connection.rootless?
  end

  # Login to the Docker registry.
  def authenticate!(options = {}, connection = self.connection)
    creds = MultiJson.dump(options)
    connection.post('/auth', {}, body: creds)
    @creds = creds
    true
  rescue Docker::Error::ServerError, Docker::Error::UnauthorizedError
    raise Docker::Error::AuthenticationError
  end

  module_function :default_socket_url, :env_url, :context_url, :config_dir,
                  :current_context_from_config, :endpoint_from_context,
                  :url, :url=, :env_options,
                  :options, :options=, :creds, :creds=, :logger, :logger=,
                  :connection, :reset!, :reset_connection!, :version, :info,
                  :ping, :podman?, :rootless?, :authenticate!, :ssl_options
end
