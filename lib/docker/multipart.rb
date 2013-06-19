# This Mixin provides the ability to do multipart post requests.
module Docker::Multipart
  include Docker::Error

  def multipart_request(path, name, io, connection)
    host, port = host_and_port(connection)
    res = Net::HTTP.start(host, port) { |http|
      req = build_multipart_post(path, io, 'application/octet-stream', name)
      http.request(req)
    }
    if (200..204).include?(res.code.to_i)
      res.body
    else
      raise UnexpectedResponseError, "Got status #{res.code}"
    end
  end

private
  def host_and_port(connection)
    [URI.parse(connection.url).host, connection.options[:port]]
  end

  def build_multipart_post(path, inner_io, content_type, file_name)
    io = UploadIO.new(inner_io, content_type, file_name)
    Net::HTTP::Post::Multipart.new(path, file_name => io)
  end
end
