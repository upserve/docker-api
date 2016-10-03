# Class to interface with Docker 1.12 #{RESOURCE_BASE} endpoints.
class Docker::Task
  include Docker::Base
  private_class_method :new

  RESOURCE_BASE = '/tasks'

  # Return the task with specified ID
  def self.get(id, opts = {}, conn = Docker.connection)
    json = conn.get("#{RESOURCE_BASE}/#{URI.encode(id)}", opts)
    hash = Docker::Util.parse_json(json) || {}
    new(conn, hash)
  end

  # Return all of the tasks.
  def self.all(opts = {}, conn = Docker.connection)
    hashes = Docker::Util.parse_json(conn.get("#{RESOURCE_BASE}", opts)) || []
    hashes.map { |hash| new(conn, hash) }
  end

end

