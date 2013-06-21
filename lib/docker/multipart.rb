# This Mixin provides the ability to do multipart post requests.
module Docker::Multipart
  include Docker::Error

  # Given a path, resource name, io, and Connection sends a multipart request.
  def multipart_request(connection, request)
    host, port = host_and_port(connection)
    res = Net::HTTP.start(host, port) { |http| http.request(request) }
    if (200..204).include?(res.code.to_i)
      res.body
    else
      raise UnexpectedResponseError, "Got status #{res.code}"
    end
  end

  def build_multipart_post(path, *io_opts_list)
    options = Hash[io_opts_list.map { |opts|
      [
        opts[:name],
        UploadIO.new(opts[:io], opts[:content_type], opts[:file_name])
      ]
    }]
    Net::HTTP::Post::Multipart.new(path, options)
  end

private
  # Return the host and port from a Connection.
  def host_and_port(connection)
    [URI.parse(connection.url).host, connection.options[:port]]
  end
end
