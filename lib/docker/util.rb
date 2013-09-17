# This module holds shared logic that doesn't really belong anywhere else in the
# gem.
module Docker::Util
  include Docker::Error

  module_function

  def parse_json(body)
    JSON.parse(body) unless body.nil? || body.empty? || (body == 'null')
  rescue JSON::ParserError => ex
    raise UnexpectedResponseError, ex.message
  end

  def create_tar(hash = {})
    output = StringIO.new
    Gem::Package::TarWriter.new(output) do |tar|
      hash.each do |file_name, input|
        tar.add_file(file_name, 0640) { |tar_file| tar_file.write(input) }
      end
    end
    output.tap(&:rewind)
  end

  def create_dir_tar(directory)
    cwd = FileUtils.pwd
    tempfile = File.new('/tmp/out', 'wb')
    FileUtils.cd(directory)
    Archive::Tar::Minitar.pack('.', tempfile)
    File.new('/tmp/out', 'r')
  ensure
    FileUtils.cd(cwd)
  end

  def extract_id(body)
    line = body.lines.to_a[-1]
    if (id = line.match(/^Successfully built ([a-f0-9]+)$/)) && !id[1].empty?
      id[1]
    else
      raise UnexpectedResponseError, "Couldn't find id: #{body}"
    end
  end

  # Convenience method to get the file hash corresponding to an array of
  # local paths.
  def file_hash_from_paths(local_paths)
    file_hash = {}

    local_paths.each do |local_path|
      if File.exist?(local_path)
        basename = File.basename(local_path)

        file_hash[basename] = File.read(local_path)
      else
        raise ArgumentError, "#{local_path} does not exist."
      end
    end

    file_hash
  end
end
