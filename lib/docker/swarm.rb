module Docker
  # This class represents a Docker Swarm
  class Swarm
    include Docker::Base

    # Inspect swarm
    def self.inspect(conn = Docker.connection)
      hash = Docker::Util.parse_json(conn.get('/swarm'))
      new(conn, hash)
    end

    # Initialize a new swarm
    def self.init(opts = {}, conn = Docker.connection)
      query = {}
      resp = conn.post('/swarm/init', query, body: opts.to_json)
      Docker::Util.parse_json(resp)
    end

    # Join an existing swarm
    def self.join(opts = {}, conn = Docker.connection)
      query = {}
      resp = conn.post('/swarm/join', query, body: opts.to_json)
      Docker::Util.parse_json(resp)
    end

    # Update a swarm
    def self.update(opts = {}, conn = Docker.connection)
      query = {}
      resp = conn.post('/swarm/update', query, body: opts.to_json)
      Docker::Util.parse_json(resp)
    end

    # Unlock a locked manager
    def self.unlock(opts = {}, conn = Docker.connection)
      query = {}
      resp = conn.post('/swarm/unlock', query, body: opts.to_json)
      Docker::Util.parse_json(resp)
    end

    # Get the unlock key
    def self.unlockkey(opts = {}, conn = Docker.connection)
      query = {}
      resp = conn.get('/swarm/unlockkey', query, body: opts.to_json)
      Docker::Util.parse_json(resp)
    end

    # Leave a swarm
    def self.leave(force = false, opts = {}, conn = Docker.connection)
      query = { force: force }
      resp = conn.post('/swarm/leave', query, body: opts.to_json)
      Docker::Util.parse_json(resp)
    end
  end
end
