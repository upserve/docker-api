# This class represents a Docker Network.
class Docker::Network
  include Docker::Base

  def connect(container, opts = {})
    Docker::Util.parse_json(
      connection.post(path_for('connect'), opts,
                      body: { container: container }.to_json)
    )
  end

  def disconnect(container, opts = {})
    Docker::Util.parse_json(
      connection.post(path_for('disconnect'), opts,
                      body: { container: container }.to_json)
    )
  end

  # remove network
  def remove(opts = {})
    connection.delete(path_for, opts)
    nil
  end
  alias_method :delete, :remove

  def json(opts = {})
    Docker::Util.parse_json(connection.get(path_for, opts))
  end

  def to_s
    "Docker::Network { :id => #{id}, :info => #{info.inspect}, "\
      ":connection => #{connection} }"
  end

  class << self
    def create(opts = {}, conn = Docker.connection)
      default_opts = {
        'CheckDuplicate' => true
      }
      name = opts.delete('name')
      query = {}
      query['name'] = name if name
      resp = conn.post('/networks/create', query,
                       body: default_opts.merge(opts).to_json)
      hash = Docker::Util.parse_json(resp) || {}
      new(conn, hash)
    end

    def get(id, opts = {}, conn = Docker.connection)
      network_json = conn.get("/networks/#{URI.encode(id)}", opts)
      hash = Docker::Util.parse_json(network_json) || {}
      new(conn, hash)
    end

    def all(opts = {}, conn = Docker.connection)
      hashes = Docker::Util.parse_json(conn.get('/networks', opts)) || []
      hashes.map { |hash| new(conn, hash) }
    end
  end

  # Convenience method to return the path for a particular resource.
  def path_for(resource = nil)
    ["/networks/#{id}", resource].compact.join('/')
  end

  private :path_for
  private_class_method :new
end
