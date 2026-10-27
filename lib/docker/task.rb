# This class represents a Docker Service Tasks

class Docker::Task
  include Docker::Base

  # refresh current Task
  def refresh!(opts = {}, conn = Docker.connection)
    resp = conn.get("/tasks/#{URI.encode(self.id)}", opts)
    hash = Docker::Util.parse_json(resp) || {}
    info.merge!(hash)
    self
  end

  # Get all Tasks
  # example: Docker::Task.all({filters: '{"service":["user3-nginx"]}'})
  #
  def self.all(opts = {}, conn = Docker.connection)
    resp = conn.get('/tasks', opts)
    hashes = Docker::Util.parse_json(resp) || []
    hashes.map { |hash| new(conn, hash) }
  end

  # get a Service
  def self.get(id, opts = {}, conn = Docker.connection)
    resp = conn.get("/tasks/#{URI.encode(id)}", opts)
    hash = Docker::Util.parse_json(resp) || {}
    new(conn, hash)
  end

  # TODO: to think how to link it to the Docker::Service class
end


