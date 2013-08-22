docker-api
==========
[![Gem Version](https://badge.fury.io/rb/docker-api.png)](http://badge.fury.io/rb/docker-api) [![travis-ci](https://travis-ci.org/swipely/docker-api.png?branch=master)](https://travis-ci.org/swipely/docker-api) [![Code Climate](https://codeclimate.com/github/swipely/docker-api.png)](https://codeclimate.com/github/swipely/docker-api) [![Dependency Status](https://gemnasium.com/swipely/docker-api.png)](https://gemnasium.com/swipely/docker-api)

This gem provides an object-oriented interface to the [Docker Remote API](http://docs.docker.io/en/latest/api/docker_remote_api_v1.4/). Every method listed there is implemented, with the exception of attaching to the STDIN of a Container. At the time of this writing, docker-api is meant to interface with Docker version 0.5.*.

Installation
------------

Add this line to your application's Gemfile:

```ruby
gem 'docker-api', :require => 'docker'
```

And then run:

```shell
$ bundle install
```

Alternatively, if you wish to just use the gem in a script, you can run:

```shell
$ gem install docker-api
```

Finally, just add `require 'docker'` to the top of the file using this gem.

Usage
-----

docker-api is designed to be very lightweight. Almost no state is cached (aside from id's which are immutable) to ensure that each method call's information is up to date. As such, just about every extrenal method represents an API call.

## Starting up

Follow the [installation instructions](http://www.docker.io/gettingstarted/), and then run:

```shell
$ sudo docker -d
```

This will daemonize Docker so that it can be used for the remote API calls.

If you're running Docker locally, there is no setup to do in Ruby. If you're not, you'll have to point the gem to your server. For example:

```ruby
Docker.url = 'http://example.com'
Docker.options = { :port => 5422 }
```

Two things to note here. The first is that this gem uses [excon](http://www.github.com/geemus/excon), so any of the options that are valid for `Excon.new` are alse valid for `Docker.options`. Second, by default Docker runs on port 4243. The gem will assume you want to connnect to port 4243 unless you specify otherwise.

Also, you may set the above variables via `ENV` variables. For example:

```shell
$ DOCKER_HOST=example.com DOCKER_PORT=1000 irb
irb(main):001:0> require 'docker'
=> true
irb(main):002:0> Docker.url
=> http://example.com
irb(main):003:0> Docker.options
=> {:port=>1000}
```

Before doing anything else, ensure you have the correct version of the Docker API. To do this, run `Docker.validate_version!`. If your installed version is not supported, a `Docker::Error::VersionError` is raised.

## Global calls

All of the following examples require a connection to a Docker server. See the <a href="#starting-up">Starting up</a> section above for more information.

```ruby
require 'docker'
# => true

Docker.version
# => { 'Version' => '0.5.2', 'GoVersion' => 'go1.1' }

Docker.info
# => { "Debug" => false, "Containers" => 187, "Images" => 196, "NFd" => 10, "NGoroutines" => 9, "MemoryLimit" => true }

Docker.authenticate!('username' => 'docker-fan-boi', 'password' => 'i<3docker', 'email' => 'dockerboy22@aol.com')
# => true
```

## Images
Just about every method here has a one-to-one mapping with the [Images](http://docs.docker.io/en/latest/api/docker_remote_api_v1.2/#images) section of the API. If an API call accepts query parameters, these can be passed as an Hash to it's corresponding method. Also, note that `Docker::Image.new` is a private method, so you must use `.create`, `.build`, `.build_from_dir`, or `.import` to make an instance.

```ruby
require 'docker'
# => true

# Create an Image.
Docker::Image.create('fromRepo' => 'base')
# => Docker::Image { :id => ae7ffbcd1, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Insert a file into an Image. Returns a new Image that contains that file.
image.insert('path' => '/google', 'url' => 'http://google.com')
# => Docker::Image { :id => 11ef6c882, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Tag an Image.
image.tag('repo' => 'base2', 'force' => true)
# => nil

# Get more information about the Image.
image.json
# => {"id"=>"67859327bf22ef8b5b9b4a6781f72b2015acd894fa03ce07e0db7af170ba468c", "comment"=>"Imported from -", "created"=>"2013-06-19T18:42:58.287944526-04:00", "container_config"=>{"Hostname"=>"", "User"=>"", "Memory"=>0, "MemorySwap"=>0, "CpuShares"=>0, "AttachStdin"=>false, "AttachStdout"=>false, "AttachStderr"=>false, "PortSpecs"=>nil, "Tty"=>false, "OpenStdin"=>false, "StdinOnce"=>false, "Env"=>nil, "Cmd"=>nil, "Dns"=>nil, "Image"=>"", "Volumes"=>nil, "VolumesFrom"=>""}, "docker_version"=>"0.4.0", "architecture"=>"x86_64"}

# View the history of the Image.
image.history
# => [{"Id"=>"67859327bf22", "Created"=>1371681778}]

# Push the Image to the Docker registry. Note that you have to login using
# `Docker.authenticate!` and tag the Image first.
image.push
# => true

# Given a command, create a new Container to run that command in the Image.
image.run('ls -l')
# => Docker::Container { id => aaef712eda, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Remove the Image from the server.
image.remove
# => true

# Given a Container's export, creates a new Image.
Docker::Image.import('some-export.tar')
# => Docker::Image { :id => 66b712aef, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Create an Image from a Dockerfile as a String.
Docker::Image.build("from base\nrun touch /test")
# => Docker::Image { :id => b750fe79269d2ec9a3c593ef05b4332b1d1a02a62b4accb2c21d589ff2f5f2dc, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Create an Image from a Dockerfile.
Docker::Image.build_from_dir('.')
# => Docker::Image { :id => 1266dc19e, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Load all Images on your Docker server.
Docker::Image.all
# => [Docker::Image { :id => b750fe79269d2ec9a3c593ef05b4332b1d1a02a62b4accb2c21d589ff2f5f2dc, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => 8dbd9e392a964056420e5d58ca5cc376ef18e2de93b5cc90e868a1bbc8318c1c, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }]

# Search the Docker registry.
Docker::Image.search('term' => 'sshd')
# => [Docker::Image { :id => cespare/sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => johnfuller/sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => dhrp/mongodb-sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => rayang2004/sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => dhrp/sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => toorop/daemontools-sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => toorop/daemontools-sshd-nginx, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => toorop/daemontools-sshd-nginx-php-fpm, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => mbkan/lamp, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => toorop/golang, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => wma55/u1210sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => jdswinbank/sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }, Docker::Image { :id => vgauthier/sshd, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }]
```

## Containers
Much like the Images, this object also has a one-to-one mapping with the [Containers](http://docs.docker.io/en/latest/api/docker_remote_api_v1.2/#containers) section of the API. Also like Images, `.new` is a private method, so you must use `.create` to make an instance.

```ruby
require 'docker'

# Create a Container. 
Docker::Container.create('Cmd' => ['ls'], 'Image' => 'base')
# => Docker::Container { :id => 492510dd38e4, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Get more information about the Container.
container.json
# => {"ID"=>"492510dd38e4da7703f36dfccd013de672b8250f57f59d1555ced647766b5e82", "Created"=>"2013-06-20T10:46:02.897548-04:00", "Path"=>"ls", "Args"=>[], "Config"=>{"Hostname"=>"492510dd38e4", "User"=>"", "Memory"=>0, "MemorySwap"=>0, "CpuShares"=>0, "AttachStdin"=>false, "AttachStdout"=>false, "AttachStderr"=>false, "PortSpecs"=>nil, "Tty"=>false, "OpenStdin"=>false, "StdinOnce"=>false, "Env"=>nil, "Cmd"=>["ls"], "Dns"=>nil, "Image"=>"base", "Volumes"=>nil, "VolumesFrom"=>""}, "State"=>{"Running"=>false, "Pid"=>0, "ExitCode"=>0, "StartedAt"=>"0001-01-01T00:00:00Z", "Ghost"=>false}, "Image"=>"b750fe79269d2ec9a3c593ef05b4332b1d1a02a62b4accb2c21d589ff2f5f2dc", "NetworkSettings"=>{"IpAddress"=>"", "IpPrefixLen"=>0, "Gateway"=>"", "Bridge"=>"", "PortMapping"=>nil}, "SysInitPath"=>"/usr/bin/docker", "ResolvConfPath"=>"/etc/resolv.conf", "Volumes"=>nil}

# Start running the Container.
container.start
# => Docker::Container { :id => 492510dd38e4, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Stop running the Container.
container.stop
# => Docker::Container { :id => 492510dd38e4, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Restart the Container.
container.restart
# => Docker::Container { :id => 492510dd38e4, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Kill the command running in the Container.
container.kill
# => Docker::Container { :id => 492510dd38e4, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Return the currently executing processes in a Container.
container.top
# => [{"PID"=>"4851", "TTY"=>"pts/0", "TIME"=>"00:00:00", "CMD"=>"lxc-start"}]

# Export a Container. Since an export is typically at least 300M, chunks of the
# export are yielded instead of just returning the whole thing.
File.open('export.tar', 'w') do |f|
  container.export { |chunk| file.write(chunk) }
end
# => nil

# Inspect a Container's changes to the file system.
container.changes
# => [{'Path'=>'/dev', 'Kind'=>0}, {'Path'=>'/dev/kmsg', 'Kind'=>1}]

# Wait for the current command to finish executing. If an argument is given,
# will timeout after that number of seconds. The default is one minute.
container.wait(15)
# => {'StatusCode'=>0}

# Attach to the Container. Currently, the below options are the only valid ones.
# By default, :stream and :stdout are set.
container.attach(:stream => true, :stdout => true, :stderr => true, :logs => true)
# => "bin\nboot\ndev\netc\nhome\nlib\nlib64\nmedia\nmnt\nopt\nproc\nroot\nrun\nsbin\nselinux\nsrv\nsys\ntmp\nusr\nvar"

# If you wish to stream the attach method, a block may be supplied.
container = Docker::Container.create('Image' => 'base', 'Cmd' => %[find / -name *])
container.tap(&:start).attach { |chunk| puts chunk }
# => nil

# Create an Image from a Container's changes.
container.commit
# => Docker::Image { :id => eaeb8d00efdf, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Commit the Container and run a new command. The second argument is the number
# of seconds the Container should wait before stopping its current command.
container.run('pwd', 10)
# => Docker::Image { :id => 4427be4199ac, :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }

# Request all of the Containers. By default, will only return the running Containers.
Docker::Container.all(:all => true)
# => [Docker::Container { :id => , :connection => Docker::Connection { :url => http://localhost, :options => {:port=>4243} } }]
```

## Connecting to Multiple Servers

By default, each object connects to the connection specified by `Docker.connection`. If you need to connect to multiple servers, you can do so by specifying the connection on `#new` or in the utilizing class method. For example:

```ruby
require 'docker'

Docker::Container.all({}, Docker::Connection.new(:url => 'http://example.com'))
```

## Known Issues
- `Docker::Container#attach` cannot attach to STDIN
