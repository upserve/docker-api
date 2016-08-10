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
    # This is undocumented on docker's side and opened:
    #
    # https://github.com/docker/docker/issues/25543
    #
    # to address this. I am assuming the interface will be JSON in the body of
    # {"Force":true}. If they end up going with this, then we can delete the
    # whole `query` business.
    query = {
      force: @options.delete('Force') == true,
    }

    call 'leave', query
  end

  def update
    call 'update'
  end

  private

  def call endpoint, query = {}
    @info = Docker::Util.parse_json(
              @connection.post "#{RESOURCE_BASE}/#{endpoint}",
                               query,
                               body: @options.to_json,
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
