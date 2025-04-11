# This class represents a Docker Service

class Docker::Service
  include Docker::Base

  # refresh current Service
  def refresh!(opts = {}, conn = Docker.connection)
    resp = conn.get("/services/#{URI.encode(self.id)}", opts)
    hash = Docker::Util.parse_json(resp) || {}
    info.merge!(hash)
    self
  end

  # destroy current Service
  def delete!(opts = {}, conn = Docker.connection)
    resp = conn.delete("/services/#{URI.encode(self.id)}", opts)
    Docker::Util.parse_json(resp) || {}
  end

  # Get all Services
  def self.all(opts = {}, conn = Docker.connection)
    resp = conn.get('/services', opts)
    hashes = Docker::Util.parse_json(resp) || []
    hashes.map { |hash| new(conn, hash) }
  end

  # Create new Service
  def self.create(opts = {}, conn = Docker.connection)
    resp = conn.post('/services/create', {}, :body => opts.to_json)
    hash = Docker::Util.parse_json(resp) || {}
    new(conn, hash)
  end

  # get a Service
  def self.get(id_or_name, opts = {}, conn = Docker.connection)
    resp = conn.get("/services/#{URI.encode(id_or_name)}", opts)
    hash = Docker::Util.parse_json(resp) || {}
    new(conn, hash)
  end

  # TODO: create the "update" method
  # according to this doc:
  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/update-a-service

  # TODO: create "ps" when it is available on the docker api
  # https://docs.docker.com/engine/reference/commandline/service_ps
end
