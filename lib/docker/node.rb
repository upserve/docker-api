module Docker
  # This class represents Docker Nodes
  class Node
    include Docker::Base

    # Nodes are instances of the Engine participating in a swarm.
    # Swarm mode must be enabled for these endpoints to work.
    def self.nodes(conn = Docker.connection)
      Docker::Util.parse_json(conn.get('/nodes'))
    end

    # Inspect a node
    def self.node(id = '', conn = Docker.connection)
      id = Docker.info['Swarm']['NodeID'] if id.empty?
      hash = Docker::Util.parse_json(conn.get("/nodes/#{id}"))
      new(conn, hash)
    end

    # Delete a node
    def self.delete(id = '', conn = Docker.connection)
      id = Docker.info['Swarm']['NodeID'] if id.empty?
      Docker::Util.parse_json(conn.delete("/nodes/#{id}"))
    end

    # Update a swarm
    def self.update(id = '', opts = {}, conn = Docker.connection)
      query = { 'version' => node.info['Version']['Index'] }
      id = Docker.info['Swarm']['NodeID'] if id.empty?
      resp = conn.post("/nodes/#{id}/update", query, body: opts.to_json)
      Docker::Util.parse_json(resp)
      new(conn, node.info)
    end
  end
end
