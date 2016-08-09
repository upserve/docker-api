# Class to interface with Docker 1.12 /swarm endpoints.
class Docker::Swarm

  RESOURCE_BASE='/swarm'

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/initialize-a-new-swarm
  def self.init opts = {}
    new(opts).init
  end

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/join-an-existing-swarm
  def self.join opts = {}
    new(opts).join
  end

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/leave-a-swarm
  def self.leave opts = {}
    new(opts).leave
  end

  # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/update-a-swarm
  def self.update opts = {}
    new(opts).update
  end

  attr_accessor :connection, :options, :info

  def initialize opts
    @connection = Docker.connection
    @options = opts
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
                               {},
                               body: @options.to_json,
                               headers: {'Content-Type' => 'application/json'}
            )
    self
  end

end
