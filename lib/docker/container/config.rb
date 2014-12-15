require 'shellwords'
#
# === Introduction
# This is a class that you can use to build an option hash you can pass in to
# Docker::Container.create using the same option syntax that you use for the
# Docker CLI.
#
# @example Passing config into Docker::Container.create
#   config = Docker::Container::Config.new
#   config.image('ubuntu:12.04').command('true')
#   Docker::Container.create(config.to_hash)
#
# === Method Chaining
# The class is built so you can chain together the methods calls. This is done
# to simulate the behavior of the CLI.
#
# @example Chaining together method calls (on a single line)
#   config = Docker::Container::Config.new
#   config.image('mysql:latest').expose('3306').volume('/backup')
#
# @example Chaning together method calls (mulitple lines)
#   config = Docker::Container::Config.new
#   config.image('mysql:latest')
#         .expose('3306')
#         .volume('/backup')
#
# === Method Aliases
# Many methods have multiple aliases that correspond directly to the short and
# long form names in the CLI.
#
# @example Setting hostname using short-form method name
#   config.h('localhost')
#
# @example Setting hostname using long-form method name
#   config.hostname('localhost')
#
# In addition, some methods will include more human readable names that include
# both a singular and plural form. The plural form is available to be more
# syntactically pleasing when entering multiple values but both refer to the
# same method.
#
# @example Adding a single Linux capability (--cap-add)
#   config.add_capability('CAP_AUDIT_CONTROL')
#
# @example Assing multiple Linux capabilities at once (--cap-add)
#   config.add_capability('CAP_AUDIT_CONTROL', 'CAP_AUDIT_WRITE')
#   config.add_capabilities('CAP_AUDIT_CONTROL', 'CAP_AUDIT_WRITE')
#
# === Method Validation
# The methods in this class do minimal verification of the values you are
# passing into them. For example, it will not check for collissions between
# conflicting values (i.e. interactive and detach). It may be wise to test the
# values directly in the CLI before passing them into an instance of this class
# to ensure that they will work properly.
#
class Docker::Container::Config

  # The options hash is where the main body is kept. It is read/write so that,
  # if you so desire, you can modify it directly. Make sure to aim away from
  # foot.
  #
  # @example Modifying the options Hash directly
  #   config.options['Cmd'] = ['true']
  #
  # @return [Hash]
  attr_accessor :options

  # Instantiate a new Docker::Container::Config object to use to create a Hash
  # you can pass in to Docker::Container.create
  #
  # @example Instantiate a new, empty Config
  #   Docker::Container::Config.new
  #
  # @example Instantiate a new Config with a few starting values
  #   Docker::Container::Config.new('Image' => 'ubuntu:12.04')
  #
  # @param hash [Hash] An initial configuration Hash.
  def initialize(hash = {})
    @options = hash
    @options['HostConfig'] ||= {}
  end

  # Instantiate a new Docker::Container::Config object by parsing the contents
  # of a CLI `docker run` or `docker create` command.
  #
  # @note This method will ignore the terms 'docker', 'run' and 'create'. You
  #   can include them in your command but they will simply be ignored.
  #
  # @example CLI command using a mix of long and short-codes
  #   config = Docker::Container::Config.from_cli(
  #     '-p 8080:80 -v /tmp:/tmp busybox --name="busybody"'
  #   )
  #
  #   config.to_hash
  #   # => {
  #     "name" => "busybody",
  #     "ExposedPorts" => {
  #       "80/tcp" => {}
  #     },
  #     "Image" => "busybox"
  #     "Volumes" => {
  #       "/tmp" => {}
  #     },
  #     "HostConfig" => {
  #       "Binds": ["/tmp:/tmp"],
  #       "PortBindings" => {
  #         "80/tcp" => [{
  #           "HostPort" => "8080"
  #         }]
  #       }
  #     }
  #   }
  #
  # @example CLI command using long-codes and setting image and command.
  #   config = Docker::Container::Config.from_cli(
  #     '--publish=8080:80 --privileged my_image /my_start.sh param'
  #   )
  #
  #   config.to_hash
  #   # => {
  #     "Image" => "my_image",
  #     "Cmd" => [
  #       "/my_start.sh",
  #       "param"
  #     ],
  #     "ExposedPorts" => {
  #       "80/tcp" => {}
  #     },
  #     "HostConfig" => {
  #       "Privileged" => true,
  #       "PortBindings" => {
  #         "80/tcp" => [{
  #           "HostPort" => "8080"
  #         }]
  #       }
  #     }
  #   }
  #
  # @param cli_string [String] A Docker CLI statement
  # @return [Docker::Container::Config]
  def self.from_cli(cli_string)
    index = 0
    image = nil
    config = self.new
    array = Shellwords.split(cli_string)

    while index < array.length
      # Grab the next parameter in the Docker CLI command
      value = array[index]

      if %w(docker run create).include?(value)
         # ignore these values, skip
         index += 1
      elsif match = value.match(/^[\-]{1}([a-z])/)
        # Single-letter parameter - call method
        config.send(match[1].to_sym, array[index+1])
        index += 2
      elsif match = value.match(/^[\-]{2}([a-z\-]+)$/)
        # Full-word boolean parameter - call method
        config.send(match[1].gsub(/\-/,'_').to_sym)
        index += 1
      elsif match = value.match(/^[\-]{2}([a-z\-]+)=(.+)/)
        # Full-word parameter with value - call method
        config.send(match[1].gsub(/\-/,'_').to_sym, match[2])
        index += 1
      elsif image.nil?
        # If we've gotten this far, its likely we've hit the image
        image = true
        config.send(:image, value)
        index += 1
      else
        # We've already gotten the image, so the rest is the command
        config.send(:cmd, *array[index..-1])
        break
      end
    end
    config
  end

  # Return the Config object as a Hash
  #
  # @return [Hash]
  def to_hash
    @options
  end

  # Return the current Config object as a JSON string
  #
  # @return [String]
  def to_json
    @options.to_json
  end

  # Add an additional entry to the hostsfile. There are two method names you can
  # use for this method: add_host or extra_host. add_host is the naming
  # convention used in the CLI but the API uses the convention extra_hosts. As
  # such, this method will support both naming conventions.
  #
  # @example Adding a single host
  #   config.add_host('example.com:1.1.1.1')
  #
  # @example Specifying multiple extra hosts
  #   config.extra_hosts('example.com:1.1.1.1', 'example2.com:2.2.2.2')
  #
  # @param hosts [String, Array<String>] Extra host(s) to add to hostsfile
  # @return [Docker::Container::Config]
  def add_host(*hosts)
    @options['HostConfig']['ExtraHosts'] ||= []
    @options['HostConfig']['ExtraHosts'].concat Array(hosts)
    self
  end
  alias_method :extra_host, :add_host
  alias_method :extra_hosts, :add_host
  alias_method :add_hosts, :add_host

  # Specify which container I/O streams should be active.
  #
  # @example Specify a stream
  #   config.attach('STDIN')
  #
  # @example Specify multiple streams
  #   config.attach('STDOUT', 'STDIN')
  #
  # @example Open all streams
  #   config.attach('all')
  #
  # @param streams [String, Symbol] The I/O stream to connect to.
  # @raise [Docker::Error::ArgumentError] If the specified stream is invalid.
  # @return [Docker::Container::Config]
  def attach(*streams)
    streams.each do |stream|
      case stream
      when /stdin/
        @options['AttachStdin'] = true
      when /stdout/
        @options['AttachStdout'] = true
      when /stderr/
        @options['AttachStderr'] = true
      else
        raise ArgumentError, "#{stream} is not a valid stream for #attach"
      end
    end
    self
  end
  alias_method :a, :attach

  # Enable one or more Linux Kernel capabilities
  # @see {http://man7.org/linux/man-pages/man7/capabilities.7.html}
  #
  # @example Enabling a single capability
  #   config.add_capability('CAP_AUDIT_CONTROL')
  #
  # @example Enabling multiple capabilities at once
  #   config.add_capabilities('CAP_AUDIT_CONTROL', 'CAP_AUDIT_READ')
  #
  # @param capabilities [String, Array<String>] One or more Linux Kernel
  #   capabilities
  # @return [Docker::Container::Config]
  def cap_add(*capabilities)
    @options['HostConfig']['CapAdd'] ||= []
    @options['HostConfig']['CapAdd'].concat capabilities
    self
  end
  alias_method :add_capability, :cap_add
  alias_method :add_capabilities, :cap_add

  # Disable one or more Linux Kernel capabilities
  # @see {http://man7.org/linux/man-pages/man7/capabilities.7.html}
  #
  # @example Disabling a single capability
  #   config.drop_capability('CAP_AUDIT_CONTROL')
  #
  # @example Disabling multiple capabilities at once
  #   config.drop_capabilities('CAP_AUDIT_CONTROL', 'CAP_AUDIT_READ')
  #
  # @param capabilities [String, Array<String>] One or more Linux Kernel
  #   capabilities
  # @return [Docker::Container::Config]
  def cap_drop(*capabilities)
    @options['HostConfig']['CapDrop'] ||= []
    @options['HostConfig']['CapDrop'].concat capabilities
    self
  end
  alias_method :drop_capability, :cap_drop
  alias_method :drop_capabilities, :cap_drop

  # Specify which file (locally) to write the container ID to.
  #
  # @example
  #   config.cidfile('/tmp/my_container.id')
  #
  # @param path [String] The absolute path for the cid file.
  # @raise [Docker::Error::ArgumentError] If the path specified is not an
  #   absolute path.
  # @return [Docker::Container::Config]
  def cidfile(path)
    if path[0] != '/'
      raise ArgumentError, "ContainerID file path is not absolute: #{path}"
    end
    @options['ContainerIDFile'] = path
    self
  end

  # Specify the command to run when the container launches. When a string is
  # specified, that string is parsed using Shellwords into an array.
  #
  # @see {http://ruby-doc.org/stdlib-2.0/libdoc/shellwords/rdoc/Shellwords.html}
  #
  # @example Using a string
  #   config.command('/my_start_script.sh')
  #
  # @example Using an array
  #   config.command('/my_start_script.sh', 'my_param')
  #
  # @param cmd [String, Array<String>] The command to run.
  # @return [Docker::Container::Config]
  def cmd(*cmd)
    cmd = Shellwords.split(cmd[0]) if cmd.length == 1
    @options['Cmd'] = cmd
    self
  end
  alias_method :command, :cmd

  # Specify the relative proportion of CPU Share this container should receive.
  #
  # @example
  #   config.cpu_shares(512)
  #
  # @param share [String, Fixnum] The relative CPU share to provide this
  #   container.
  # @return [Docker::Container::Config]
  def cpu_shares(share)
    share = share.to_i if share.is_a?(String)
    @options['CpuShares'] = share
    self
  end
  alias_method :c, :cpu_shares

  # Specify which cgroup Cpuset to utilize.
  #
  # @example
  #   config.cpuset('0,1')
  #
  # @param set [String] The cgroups Cpuset
  # @return [Docker::Container::Config]
  def cpuset(set)
    @options['Cpuset'] = set
    self
  end

  # Whether or not to attach to STDOUT or STDERR. The default value for this
  # method is +true+.
  #
  # @example
  #   config.detach
  #
  # @return [Docker::Container::Config]
  def detach
    @options['AttachStdout'] = false
    @options['AttachStderr'] = false
    @options['AttachStdin']  = false
    @options['Tty'] = false
    @options['StdinOnce'] = false
    self
  end
  alias_method :d, :detach

  # Specify one or more host device(s) that should be added to the container.
  #
  # @example Add a single device
  #   config.device('/dev/sdc:/dev/xvdf')
  #
  # @example Add multiple devices simultaneoulsy
  #   config.devices('/dev/sdc:/dev/xvdf', '/dev/sdd:/dev/svdg')
  #
  # @param devices [String, Array<String>] One or more devices to add to the
  #   container.
  # @raise [Docker::Error::ArgumentError] If the format of the device statement
  #   is invalid.
  # @return [Docker::Container::Config]
  def device(*devices)
    @options['HostConfig']['Devices'] ||= []

    devices.each do |device|
      # Set default values
      src = nil
      dst = nil
      permissions = "rwm"

      # Parse the device string
      parts = device.split(':')
      case parts.length
      when 3
        src = parts[0]
        dst = parts[1]
        permissions = parts[2]
      when 2
        src = parts[0]
        dst = parts[1]
      when 1
        src = dst = parts[0]
      else
        raise ArgumentError, "Invalid device specification: #{device}"
      end

      # Add the device mapping to the config Hash
      mapping = {
        'PathOnHost' => src,
        'PathInContainer' => dst,
        'CgroupPermissions' => permissions
      }
      @options['HostConfig']['Devices'] << mapping
    end
    self
  end
  alias_method :devices, :device

  # Specify one or more custom DNS servers
  #
  # @example Add a single DNS server
  #   config.dns('8.8.8.8')
  #
  # @example Add multiple DNS servers
  #   config.dns('8.8.8.8', '9.9.9.9')
  #
  # @param dns [String, Array<String>] Custom dns server(s)
  # @return [Docker::Config::Config]
  def dns(*dns)
    @options['HostConfig']['Dns'] ||= []
    @options['HostConfig']['Dns'].concat dns
    self
  end

  # Specify one or more custom DNS search domains
  #
  # @example Add a single DNS search domain
  #   config.dns('8.8.8.8')
  #
  # @example Add multiple DNS search domains
  #   config.dns('8.8.8.8', '9.9.9.9')
  #
  # @param dns [String, Array<String>] Custom dns search domain(s)
  # @return [Docker::Config::Config]
  def dns_search(*dns)
    @options['HostConfig']['DnsSearch'] ||= []
    @options['HostConfig']['DnsSearch'].concat dns
    self
  end

  # Add one or more environment variables
  #
  # @example Specify a single environment variable using both the key and value
  #   config.env('MY_VAR=example')
  #   config.to_hash
  #   {
  #     "Env": [
  #       "MY_VAR=example"
  #     ]
  #   }
  #
  # @example Specify an existing Environment Variable
  #   config.env('DOCKER_HOST')
  #   config.to_hash
  #   {
  #     "Env": [
  #       "DOCKER_HOST=unix:///var/run/docker.sock"
  #     ]
  #   }
  #
  # @example Specify multiple environment variables using a mix of key/value and
  #   existing.
  #
  #   config.env('MY_VAR=example', 'DOCKER_HOST')
  #   config.to_hash
  #   {
  #     "Env": [
  #       "MY_VAR=example",
  #       "DOCKER_HOST=unix:///var/run/docker.sock"
  #     ]
  #   }
  #
  # @param vars [String, Array<String>] An environment variable statement
  #   (i.e. <key>=<value>), or the name of an existing local environment
  #   variable to be copied.
  # @raise [Docker::Error::ArgumentError] If the variable declaration has an
  #   invalid syntax.
  # @return [Docker::Container::Config]
  def env(*vars)
    @options['Env'] ||= []

    vars.each do |var|
      parts = var.split('=')
      if parts.length == 2
        @options['Env'] << var
      elsif parts.length == 1
        @options['Env'] << "#{var}=#{ENV[var]}"
      else
        raise ArgumentError, "Invalid environment variable declaration: #{var}"
      end
    end
    self
  end
  alias_method :e, :env

  # Parse one or more files with environment variables
  #
  # @example Specify a single file to be parsed
  #   config.env_file('/tmp/my_file')
  #
  # @example Specify multiple files to be parsed
  #   config.env_files('/tmp/my_file1', '/tmp/my_file2')
  #
  # @param filenames [String, Array<String>] The file(s) to parse
  # @raise [Docker::Error::ArgumentError] If the file does not exist or one of
  #   the variables inside the file does not have proper syntax.
  # @return [Docker::Container::Config]
  def env_file(*filenames)
    @options['Env'] ||= []

    filenames.each do |filename|
      if !::File.exist?(filename)
        raise ArgumentError, "Environment file does not exist: #{filename}"
      end

      # Open the file and iterate through each line
      ::File.open(filename, 'r') do |file|
        file.each_line do |line|
          if line.length > 0 && line[0] != '#'
            # Strip leading and trailing whitespace from line
            line.strip!

            if line.include?('=')
              # key/value variable
              data = line.split('=')
              if data[0].match(/\s/)
                raise ArgumentError, "Variable #{data[0]} has white spaces"
              end
              @options['Env'] << "#{data[0]}=#{data[1]}"
            else
              # pass through variable
              @options['Env'] << "#{line}=#{ENV[line]}"
            end
          end
        end
      end
    end
    self
  end
  alias_method :env_files, :env_file

  # Expose one or more ports (or range of ports) from the container without
  # publishing them to your host.
  #
  # @example Expose a single port
  #   config.expose_port('8080')
  #
  # @example Expose multiple single ports
  #   config.expose_ports('8080', '8443')
  #
  # @example Expose a single port and multiple ranges of ports
  #   config.expose_ports('8080', '9000-1000', '1010-1020'))
  #
  # @param ports [String, Array<String>] One or more ports or range of ports to
  #   expose.
  # @raise [Docker::Error::ArgumentError] If the port format is invalid.
  # @return [Docker::Config::Config]
  def expose(*ports)
    @options['ExposedPorts'] ||= {}

    ports.each do |port|
      if port.include?(':')
        raise ArgumentError, "Invalid port format for #expose: #{port}"
      end

      if port.include?('-')
        # A range has been specified. We need to expose the entire range.
        port, proto = split_proto_port(port)
        parts = port.split('-')
        for p in (parts[0].to_i)..(parts[1].to_i) do
          @options['ExposedPorts']["#{p}/#{proto}"] ||= {}
        end
      else
        # A single port has been specified.
        port, proto = split_proto_port(port)
        @options['ExposedPorts']["#{port}/#{proto}"] ||= {}
      end
    end
    self
  end
  alias_method :expose_port, :expose
  alias_method :expose_ports, :expose

  # Set the hostname for the container
  #
  # @example
  #   config.hostname('myhost')
  #
  # @param name [String] The hostname for the container
  # @return [Docker::Container::Config]
  def hostname(name)
    @options['Hostname'] = name
    self
  end
  alias_method :h, :hostname

  # Specify which Docker Image to launch the container from.
  #
  # @example Using an image name
  #   config.image('ubuntu:12.04')
  #
  # @example Using an image ID
  #   config.image('d940f6fef591')
  #
  # @param id [String] The identifier for the Docker Image to use.
  # @return [Docker::Container::Config]
  def image(id)
    @options['Image'] = id
    self
  end

  # Keep STDIN open even if not attached
  #
  # @example
  #   config.interactive
  #
  # @return [Docker::Container::Config]
  def interactive
    @options['AttachStdin'] = true
    self
  end
  alias_method :i, :interactive

  # Add one or more links to another container in the form of name:alias
  #
  # @example Add a single link
  #   config.link('my_db:mysql')
  #
  # @example Add multiple links
  #   config.links('my_db:mysql', 'monitoring:monitoring')
  #
  # @param links [String, Array<String>] The link identifier(s)
  # @raise [Docker::Error::ArgumentError] If the link format is invalid.
  # @return [Docker::Container::Config]
  def link(*links)
    @options['HostConfig']['Links'] ||= []

    links.each do |link|
      if !link.include?(':')
        raise ArgumentError, "Invalid link format: #{link}"
      end
      @options['HostConfig']['Links'] << link
    end
    self
  end
  alias_method :links, :link

  # Add one or more custom lxc options
  #
  # @example Add a single LXC configuration
  #   config.lxc_conf('lxc.cgroup.cpuset.cpus = 0,1')
  #
  # @example Add multiple LXC configurations
  #   config.lxc_confs(
  #     'lxc.cgroup.cpuset.cpus = 0,1',
  #     'lxc.utsname = docker'
  #   )
  #
  # @param confs [String, Array<String>] Custom LXC configuration(s)
  # @return [Docker::Container::Config]
  def lxc_conf(*confs)
    @options['HostConfig']['LxcConf'] ||= {}

    confs.each do |conf|
      data = conf.split('=')
      key = data[0].strip
      value = data[1].strip
      @options['HostConfig']['LxcConf'][key] = value
    end
    self
  end

  # Set the memory limit
  #
  # @example
  #   config.memory('1g')
  #
  # @param ram [String] The Memory Limit in the format <number><optional unit>.
  #   Valid optional units are 'b', 'k', 'm' or 'g'.
  # @raise [Docker::Error::ArgumentError] If the memory limit format is invalid.
  # @return [Docker::Container::Config]
  def memory(ram)
    case ram
    when /\d+b/
      @options['Memory'] = ram.to_i
    when /\d+k/
      @options['Memory'] = ram.to_i * 1000
    when /\d+m/
      @options['Memory'] = ram.to_i * (1000**2)
    when /\d+g/
      @options['Memory'] = ram.to_i * (1000**3)
    else
      raise ArgumentError, "Invalid memory limit format: #{ram}"
    end
    self
  end
  alias_method :m, :memory

  # Specify the name of the container.
  #
  # @example
  #   config.name('my_container')
  #
  # @param name [String] The name to assign to the container
  # @return [Docker::Container::Config]
  def name(name)
    @options['name'] = name
    self
  end

  # Set the Network mode for the container
  #
  # @example
  #   config.network_mode('host')
  #
  # @param mode [String] The network mode
  # @raise [Docker::Error::ArgumentError] If the network mode value has an
  #   invalid syntax.
  # @return [Docker::Container::Config]
  def net(mode)
    parts = mode.split(':')
    case parts[0]
    when 'bridge', 'none', 'host'
    when 'container'
      if parts.length < 2 || parts[1] == ''
        raise ArgumentError, "Invalid container format container:<name|id>"
      end
    else
      raise ArgumentError, "invalid option for #net: #{mode}"
    end
    @options['HostConfig']['NetworkMode'] = mode
    self
  end
  alias_method :network_mode, :net

  # Run the container in privileged mode
  #
  # @example
  #   config.privileged
  #
  # @return [Docker::Container::Config]
  def privileged
    @options['HostConfig']['Privileged'] = true
    self
  end

  # Publish and expose one or more ports to the host
  #
  # @example Publish a single port
  #   config.publish_port('8080:80')
  #
  # @example Publish multiple ports
  #   config.publish_ports('8080:80', '3306')
  #
  # @param ports [String, Array<String>] One or more ports to publish to the
  #   host. The expected format for each port is ip:hostPort:containerPort/proto
  # @return [Docker::Container::Config]
  def publish(*ports)
    @options['ExposedPorts'] ||= {}
    @options['HostConfig']['PortBindings'] ||= {}

    ports.each do |port_string|
      proto     = 'tcp'
      raw_port  = port_string

      # Check to see if a protocol was specified. If it was, capture it and
      # readjust the value of raw_port.
      if (i = raw_port.rindex('/')) != nil
        proto     = raw_port[i+1..-1]
        raw_port  = raw_port[0..i-1]
      end

      # Standardize the port_string so it can be parsed
      if !raw_port.include?(':')
        raw_port = "::#{raw_port}"
      elsif raw_port.split(':').length == 2
        raw_port = ":#{raw_port}"
      end

      # Parse the port_string
      parts = raw_port.split(':')
      ip              = parts[0]
      host_port       = parts[1]
      container_port  = parts[2]

      # Compose return hash
      key = "#{container_port}/#{proto}"
      @options['ExposedPorts'][key] ||= {}
      @options['HostConfig']['PortBindings'][key] ||= []

      mapping = {}
      mapping['HostPort'] = host_port
      mapping['HostIp']   = ip
      @options['HostConfig']['PortBindings'][key] << mapping
    end
    self
  end
  alias_method :p, :publish
  alias_method :publish_port, :publish
  alias_method :publish_ports, :publish

  # Publish all exposed ports to the host interfaces.
  #
  # @example
  #   config.publish_all_ports
  #
  # @return [Docker::Container::Config]
  def publish_all
    @options['HostConfig']['PublishAllPorts'] = true
    self
  end
  alias_method :P, :publish_all
  alias_method :publish_all_ports, :publish_all

  # Set the restart policy
  #
  # @example Specify a policy without a retry count
  #   config.restart_policy('always')
  #
  # @example Specify a policy with a retry count
  #   config.restart_policy('on-failure:5')
  #
  # @param policy [String] The restart policy
  # @raise [Docker::Error::ArgumentError] If the restart policy is invalid.
  # @return [Docker::Container::Config]
  def restart(policy)
    if policy == "" || policy.nil?
      raise ArgumentError, "Restart Policy cannot be empty"
    end

    # Set defaults
    parts = policy.split(':')
    name = parts[0]
    max_retry_count = 0

    case name
    when "always"
      if parts.length == 2
        raise ArgumentError, "Maximum restart count not valid with restart " \
                             "policy of \"always\""
      end
    when "no"
      # do nothing
    when "on-failure"
      if parts.length == 2
        max_retry_count = parts[1].to_i
      end
    else
      raise ArgumentError, "Invalid restart policy: #{policy}"
    end

    # Build the Restart Policy mapping
    policy_mapping = { 'Name' => name }
    policy_mapping['MaximumRetryCount'] = max_retry_count if max_retry_count

    @options['HostConfig']['RestartPolicy'] = policy_mapping
    self
  end
  alias_method :restart_policy, :restart

  # Set one or more security options
  #
  # @param opts [String, Array<String>] One or more security options
  # @return [Docker::Container::Config]
  def security_opt(*opts)
    @options['HostConfig']['SecurityOpt'] ||= []
    @options['HostConfig']['SecurityOpt'].concat opts
    self
  end
  alias_method :security_option, :security_opt
  alias_method :security_options, :security_opt

  # Set the TTY
  #
  # @example
  #   config.tty
  #
  # @return [Docker::Container::Config]
  def tty
    @options['Tty'] = true
    self
  end
  alias_method :t, :tty

  # Set the user
  #
  # @example
  #   config.user('ubuntu')
  #
  # @param id [String]
  # @return [Docker::Container::Config]
  def user(id)
    @options['User'] = id
    self
  end
  alias_method :u, :user

  # Bind one or more volumes to the container
  #
  # @example Mount a single volume from the host into the container.
  #   config.volume('/tmp:/tmp')
  #
  # @example Create a volume inside the container and mount a volume from the
  #   host.
  #   config.volumes('/tmp:/tmp', '/logs')
  #
  # @param volumes [String, Array<String>] The volume string to parse. To mount
  #   a volume from the host the format is '/host:/container'. To simply specify
  #   a volume inside the container the format is '/container'.
  # @raise [Docker::Error::ArgumentError] If the volume string given is invalid.
  # @return [Docker::Container::Config]
  def volume(*volumes)
    @options['Volumes'] ||= {}
    @options['HostConfig']['Binds'] ||= []

    volumes.each do |volume_string|
      # Parse the volume string
      paths = volume_string.split(':')

      if paths.length > 1
        # We want to bind a volume form the host.
        if paths[1] == '/'
          raise ArgumentError, "Invalid bind mount: destination can't be '/'"
        end

        @options['Volumes'][paths[1]] ||= {}
        @options['HostConfig']['Binds'] << volume_string
      elsif volume_string == '/'
        raise ArgumentError, "Invalid bind mount: destination can't be '/'"
      else
        # We just want to declare a volume inside the container.
        @options['Volumes'][volume_string] ||= {}
      end
    end
    self
  end
  alias_method :v, :volume
  alias_method :volumes, :volume

  # Specify one or more containers to import volumes from
  #
  # @example Import from one container
  #   config.volumes_from('my_container')
  #
  # @example Import from multiple containers
  #   config.volumes_from('my_container', 'your_container:ro')
  #
  # @param containers [String, Array<string>] The container(s) to import volumes
  #   from.
  # @return [Docker::Container::Config]
  def volumes_from(*containers)
    @options['HostConfig']['VolumesFrom'] ||= []
    @options['HostConfig']['VolumesFrom'].concat containers
    self
  end

  # Set the working directory
  #
  # @example
  #   config.working_directory('/home')
  #
  # @param dir [String] The working directory
  # @return [Docker::Container::Config]
  def workdir(dir)
    @options['WorkingDir'] = dir
    self
  end
  alias_method :w, :workdir
  alias_method :working_directory, :workdir

  private

  # Split a Port string into its protocol and port number
  #
  # @param port [String] string with protocol (and port)
  # @return [Array] the port number and protocol
  def split_proto_port(port)
    parts = port.split('/')
    case parts.length
    when 0
      return "", ""
    when 1
      return port, "tcp"
    else
      return parts[0], parts[1]
    end
  end
end
