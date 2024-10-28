require 'bundler/setup'

ENV['PATH'] = "/opt/docker/:#{ENV['PATH']}" if ENV['CI'] == 'true'

require 'docker'
require 'rspec/core/rake_task'

desc 'Run the full test suite from scratch'
task :default => [:unpack, :rspec]

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

desc 'Download the necessary base images'
task :unpack do
  %w( swipely/base registry busybox:uclibc tianon/true debian:stable ).each do |image|
    system "docker pull #{image}"
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
