class Docker::Swarm

  RESOURCE_BASE='/swarm'

  def self.init opts = {}
    new(opts).init
  end

  def self.join opts = {}
    new(opts).join
  end

  def self.leave opts = {}
    new(opts).leave
  end

  def self.update opts = {}
    new(opts).update
  end

  attr_accessor :connection, :options, :info

  def initialize opts
    @connection = Docker.connection
    @options = opts
  end

  def init
    @info = Docker::Util.parse_json(
              @connection.post "#{RESOURCE_BASE}/init", {}, @options.to_json
            )
    self
  end

  def join
    @info = Docker::Util.parse_json(
              @connection.post "#{RESOURCE_BASE}/join", {}, @options.to_json
            )
    self
  end

  def leave
    @info = Docker::Util.parse_json(
              @connection.post "#{RESOURCE_BASE}/leave", {}, @options.to_json
            )
    self
  end

  def update
    @info = Docker::Util.parse_json(
              @connection.post "#{RESOURCE_BASE}/update", {}, @options.to_json
            )
    self
  end

end
