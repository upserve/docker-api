# Class to interface with Docker 1.12 #{RESOURCE_BASE} endpoints.
class Docker::Swarm

  RESOURCE_BASE='/swarm'

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/initialize-a-new-swarm
  def self.init body = {}, query = {}
    new(body, query).init
  end

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/join-an-existing-swarm
  def self.join body = {}, query = {}
    new(body, query).join
  end

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/leave-a-swarm
  def self.leave body = {}, query = {}
    new(body, query).leave
  end

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/update-a-swarm
  def self.update body = {}, query = {}
    new(body, query).update
  end

  attr_accessor :connection, :body, :info, :query

  def initialize body = {}, query = {}
    @connection = Docker.connection
    @body = body
    @query = query
  end

  def init
    call 'init'
  end

  def join
    call 'join'
  end

  def leave
    call 'leave'
  end

  def update
    call 'update'
  end

  private

  def call endpoint
    @info = Docker::Util.parse_json(
              @connection.post "#{RESOURCE_BASE}/#{endpoint}",
                               @query,
                               body: @body.to_json,
                               headers: headers
            )
    self
  end

  def headers
    {
      'Content-Type' => 'application/json',
    }
  end

end
