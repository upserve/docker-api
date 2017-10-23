# This class represents a Docker Service. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Service
  include Docker::Base

  def self.all(opts = {}, conn = Docker.connection)
    hashes = Docker::Util.parse_json(conn.get('/services', opts)) || []
    hashes.map { |hash| new(conn, hash) }
  end

  def self.get(id, opts = {}, conn = Docker.connection)
    service_json = conn.get("/services/#{URI.encode(id)}", opts)
    new(conn, Docker::Util.parse_json(service_json) || {})
  end

  def self.create(opts = {}, conn = Docker.connection)
    name = opts.delete('name') || opts.delete(:name)
    query = {}
    query['name'] = name if name

    response = conn.post('/services/create', query, :body => opts.to_json)
    hash = Docker::Util.parse_json(response) || {}
    new(conn, hash)
  end
  
  def remove(opts = {})
    connection.delete("/services/#{self.id}", opts)
    nil
  end

  def update(opts)
    connection.post("/services/#{self.id}/update", {}, body: opts.to_json)
  end

  def logs(opts = {})
    connection.get("/services/#{self.id}/logs", opts)
  end
  
  private_class_method :new
end
