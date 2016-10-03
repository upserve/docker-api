# Class to interface with Docker 1.12 #{RESOURCE_BASE} endpoints.
class Docker::Service
  include Docker::Base
  private_class_method :new

  RESOURCE_BASE = '/services'

  # Create a new service.
  def self.create(opts = {}, conn = Docker.connection)
    name = opts.delete('name')
    query = {}
    query['name'] = name if name
    resp = conn.post("#{RESOURCE_BASE}/create", query, :body => opts.to_json)
    hash = Docker::Util.parse_json(resp) || {}
    new(conn, hash)
  end

  # Return the service with specified ID
  def self.get(id, opts = {}, conn = Docker.connection)
    services_json = conn.get("#{RESOURCE_BASE}/#{URI.encode(id)}", opts)
    hash = Docker::Util.parse_json(services_json) || {}
    new(conn, hash)
  end

  # Return all of the services.
  def self.all(opts = {}, conn = Docker.connection)
    hashes = Docker::Util.parse_json(conn.get("#{RESOURCE_BASE}", opts)) || []
    hashes.map { |hash| new(conn, hash) }
  end

  # remove service
  def remove(opts = {})
    connection.delete("#{RESOURCE_BASE}/#{self.id}", opts)
    nil
  end
  alias_method :delete, :remove

  def update(query, opts)
    connection.post(path_for(:update), query, body: opts.to_json)
  end

  # Convenience method to return the path for a particular resource.
  def path_for(resource)
    "#{RESOURCE_BASE}/#{self.id}/#{resource}"
  end
  private :path_for
end

