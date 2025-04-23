# frozen_string_literal: true

# This class represents a Docker Event.
# @see https://github.com/moby/moby/blob/master/api/types/events/events.go
# @see https://docs.docker.com/reference/api/engine/version/v1.49/#tag/System/operation/SystemEvents
class Docker::Event
  include Docker::Error

  # Represents the actor object nested within an event
  class Actor
    attr_reader :info

    def initialize(actor_data = {})
      @info = actor_data.transform_keys { |k| k.downcase.to_sym }
    end

    def id
      info[:id]
    end
    alias_method :ID, :id

    def attributes
      info[:attributes] || {}
    end
    alias_method :Attributes, :attributes
  end

  class << self
    include Docker::Error

    def stream(opts = {}, conn = Docker.connection, &block)
      # Disable timeouts by default
      opts[:read_timeout] = nil unless opts.key? :read_timeout

      # By default, avoid retrying timeout errors. Set opts[:retry_errors] to override this.
      opts[:retry_errors] ||= Excon::DEFAULT_RETRY_ERRORS.reject do |cls|
        cls == Excon::Error::Timeout
      end

      opts[:response_block] = lambda do |chunk, remaining, total|
        chunk.each_line do |event_json|
          block.call(new_event(event_json, remaining, total))
        end
      end

      conn.get('/events', opts.delete(:query), opts)
    end

    def since(since, opts = {}, conn = Docker.connection, &block)
      stream(opts.merge(:since => since), conn, &block)
    end

    def new_event(body, remaining, total)
      return if body.nil? || body.empty?
      info = Docker::Util.parse_json(body)
      Docker::Event.new(info)
    end
  end

  attr_reader :info

  def initialize(event_data = {})
    @info = event_data.transform_keys { |k| k.downcase.to_sym }
  end

  def action
    info[:action]
  end
  alias_method :Action, :action

  def actor
    @actor = Actor.new(info[:actor] || {}) if !defined? @actor
    @actor
  end
  alias_method :Actor, :actor

  def from
    # @deprecated Use `actor.attributes['image']` instead
    #   Only applicable to container events. See Docker docs for details.
    info[:from] || actor.attributes['image']
  end

  def id
    # @deprecated Use `actor.id` instead
    info[:id] || actor.id
  end

  def scope
    info[:scope]
  end

  def status
    # @deprecated Use `action` instead
    info[:status] || action
  end

  def time
    info[:time]
  end

  def time_nano
    info[:timenano]
  end
  alias_method :timeNano, :time_nano

  def type
    info[:type]
  end
  alias_method :Type, :type

  def to_s
    if type.nil? && action.nil?
      to_s_legacy
    else
      to_s_actor_style
    end
  end

  private

  def to_s_legacy
    attributes = []
    attributes << "from=#{from}" unless from.nil?

    unless attributes.empty?
      attribute_string = "(#{attributes.join(', ')}) "
    end

    "Docker::Event { #{time} #{status} #{id} #{attribute_string}}"
  end

  def to_s_actor_style
    most_accurate_time = time_nano || time

    attributes = []
    actor.attributes.each do |attribute, value|
      attributes << "#{attribute}=#{value}"
    end

    unless attributes.empty?
      attribute_string = "(#{attributes.join(', ')}) "
    end

    "Docker::Event { #{most_accurate_time} #{type} #{action} #{actor.id} #{attribute_string}}"
  end
end
