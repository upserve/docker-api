$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'rake'
require 'docker'
require 'rspec/core/rake_task'
require 'cane/rake_task'

task :default => [:spec, :quality]

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

Cane::RakeTask.new(:quality) do |cane|
  cane.canefile = '.cane'
end

desc 'Pull an Ubuntu image'
image 'ubuntu:13.10' do
  puts "Pulling ubuntu:13.10"
  image = Docker::Image.create('fromImage' => 'ubuntu', 'tag' => '13.10')
  puts "Pulled ubuntu:13.10, image id: #{image.id}"
end
