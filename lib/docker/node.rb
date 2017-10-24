# This class represents a Docker Node. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Node
  include Docker::Base

  def self.all(opts = {}, conn = Docker.connection)
    hashes = Docker::Util.parse_json(conn.get('/nodes', opts)) || []
    hashes.map { |hash| new(conn, hash) }
  end

  def self.get(id, conn = Docker.connection)
    node_json = conn.get("/nodes/#{URI.encode(id)}")
    new(conn, Docker::Util.parse_json(node_json) || {})
  end

  def remove(opts = {})
    connection.delete("/nodes/#{self.id}", opts)
    nil
  end

  def update(opts)
    filter = opts.delete 'filter' || opts.delete :filter
    query = {}
    query['filter'] = filter if filter 
    
    connection.post("/services/#{self.id}", query, body: opts.to_json)
  end
  
  private_class_method :new
end
