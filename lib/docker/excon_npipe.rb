# frozen_string_literal: true

require 'docker/npipe_socket'

# Teaches Excon::Connection to recognize the `npipe://` scheme by dispatching
# to Docker::NPipeSocket and computing a unix-style socket key. Loaded only
# when a Docker::Connection is constructed with an `npipe://` URL.
module Docker::ExconNPipe
  NPIPE = 'npipe'

  def initialize(params = {})
    super
    if @data[:scheme] == NPIPE
      @socket_key = "#{@data[:scheme]}://#{@data[:socket]}"
    end
  end

  def socket(datum = @data)
    if datum[:scheme] == NPIPE
      sockets[@socket_key] ||= Docker::NPipeSocket.new(datum)
    else
      super
    end
  end
end

Excon::Connection.prepend(Docker::ExconNPipe) unless Excon::Connection.include?(Docker::ExconNPipe)
