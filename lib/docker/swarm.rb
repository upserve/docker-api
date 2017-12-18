# This class represents a Docker Swarm instance. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Swarm
  include Docker::Base

  def self.inspect(conn = Docker.connection)
    new(conn, Docker::Util.parse_json(conn.get('/swarm')))
  end

  private_class_method :new
end
