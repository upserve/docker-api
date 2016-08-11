$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
ENV['PATH'] = "/opt/docker/:#{ENV['PATH']}" if ENV['CI'] == 'true'

require 'rake'
require 'docker'
require 'rspec/core/rake_task'
require 'cane/rake_task'
require 'docker_machine'


desc 'Run the full test suite from scratch'
default = ['docker_machine:eval_env', :unpack, :rspec, :quality]
default.shift if ENV['TRAVIS'] == 'true'
task :default => default

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

Cane::RakeTask.new(:quality) do |cane|
  cane.canefile = '.cane'
end

desc 'Download the necessary base images'
task :unpack do
  %w(
    swipely/base:latest
    tianon/true:latest
    debian:wheezy
    registry:latest
    busybox:latest
  ).each do |image|
    # doing this instead of #system because need it to work against a
    # docker-machine if we use that.
    puts "Pulling #{image}"
    Docker::Image.create 'fromImage' => image
  end
end

desc 'Run spec tests with a registry'
task :rspec do
  begin
    registry = Docker::Container.create(
      'name' => 'registry',
      'Image' => 'registry',
      'Env' => ["GUNICORN_OPTS=[--preload]"],
      'ExposedPorts' => {
        '5000/tcp' => {}
      },
      'HostConfig' => {
        'PortBindings' => { '5000/tcp' => [{ 'HostPort' => '5000' }] }
      }
    )
    registry.start
    Rake::Task["spec"].invoke
  ensure
    registry.kill!.remove unless registry.nil?
  end
end

desc 'Pull an Ubuntu image'
image 'ubuntu:13.10' do
  puts "Pulling ubuntu:13.10"
  image = Docker::Image.create('fromImage' => 'ubuntu', 'tag' => '13.10')
  puts "Pulled ubuntu:13.10, image id: #{image.id}"
end

desc 'Used to setup docker-machines for test suite.'
namespace :docker_machine do

  def docker_version
    ENV['DOCKER_VERSION'] || Docker.version['Version'] || 'unknown'
  end

  def name number
    "docker-api-#{docker_version}-node-#{number}"
  end

  def no_docker_machine?
    ENV['DOCKER_API_NO_DOCKER_MACHINE'] == 'true'
  end

  desc 'Check if docker-machine is installed.'
  task :check do
    unless no_docker_machine? || system('which', 'docker-machine')
      warn "docker-machine is not installed. Consider setting it up in order "\
        "for the test suite to be more robust. Refer to "\
        "https://docs.docker.com/machine/install-machine/ for installation "\
        "instructions."
      ENV['DOCKER_API_NO_DOCKER_MACHINE'] = 'true'
      puts 'Sleeping to allow time to read above...'
      sleep 8
    end
  end

  desc 'Remove docker-machines'
  task :remove => :check do
    unless no_docker_machine?
      dm = DockerMachine.new
      2.times do |i|
        begin
          dm.call "rm -f #{name i}", stream_logs: true
        rescue DockerMachine::CLIError => err
          p err
        end
      end
    end
  end

  desc 'Create 2 docker machines for testing. 2 so we can do swarm testing.'\
         "\nThis is opionated and only creates virtualbox VMs."
  task :create_or_start => :check do
    unless no_docker_machine?
      dm = DockerMachine.new
      2.times do |i|
        begin
          dm.call "status #{name i}"

          case dm.out
          when /stopped/i
            dm.call "start #{name i}", stream_logs: true
          end

          puts "#{name i} is #{dm.out}"
        rescue DockerMachine::CLIError => err
          case dm.err
          when /does not exist/
            cmd = "create --driver virtualbox --virtualbox-boot2docker-url "\
              "https://github.com/boot2docker/boot2docker/releases/download/v#{docker_version}/boot2docker.iso "\
              "#{name i}"
            dm.call cmd, stream_logs: true
          end
        end
      end
    end
  end

  desc 'Eval the docker-machine into runtime.'
  task :eval_env => :create_or_start do
    unless no_docker_machine?
      dm = DockerMachine.new
      dm.call "env #{name 0}"
      env_vars = dm.out.scan /export\s+(\S+)=(\S+)/
			env_vars.each { |v| ENV[v.first] = v.last.gsub /\A['"]|['"]\Z/, '' }
      p Docker.options
    end
  end

end # docker_machine namespace
