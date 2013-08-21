# This class is used to transform Hashes into JSON on requests, and parse JSON
# Strings into Hashes on responses.
class Docker::Middleware::JSON < Excon::Middleware::Base

  # Transform the datum[:body] if the 'Content-Type' is 'application/json' and
  # it is a Hash.
  def request_call(datum)
    if is_json?(datum) && datum[:body].is_a?(Hash)
      datum[:body] = datum[:body].to_json
    end
    super
  end

  # Transform the datum[:response][:body] if the 'Content-Type' is
  # 'application/json' and it is a JSON String. If the parse fails, the body
  # remains unchanged.
  def response_call(datum)
    if !(response = datum[:response]).nil? && is_json?(response)
      begin
        response[:body] = Docker::Util.parse_json(response[:body])
      rescue Docker::Error::UnexpectedResponseError
        # The parse failed, do nothing.
      end
    end
    super
  end

  # Returns true if the datum[:headers]['Content-Type'] is 'application/json'.
  def is_json?(datum)
    datum.respond_to?(:[]) &&
      datum[:headers] &&
        (datum[:headers]['Content-Type'] == 'application/json')
  end
end
