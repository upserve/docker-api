# This class represents a Docker Image.
class Docker::Event
  include Docker::Error

  attr_accessor :status, :id, :from, :time
  
  def initialize(status, id, from, time)
    @status, @id, @from, @time = status, id, from, time
  end

  def to_s
    "Docker::Event { :status => #{self.status}, :id => #{self.id}, "\
      ":from => #{self.from}, :time => #{self.time} }"
  end

  class << self
    include Docker::Error

    def stream(conn = Docker.connection)
      conn.get('/events', :response_block => method(:yield_event))
    end

    def since(since, conn = Docker.connection)
    end

    def yield_event(body, remaining, total)
      json = Docker::Util.parse_json(body)
      yield Docker::Event.new(
        json['status'],
        json['id'],
        json['from'],
        json['time']
      )
    end
  end
end
