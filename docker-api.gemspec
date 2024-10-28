# -*- encoding: utf-8 -*-
require File.expand_path('../lib/docker/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Swipely, Inc.']
  gem.email         = 'tomhulihan@swipely.com bright@swipely.com toddlunter@swipely.com'
  gem.description   = gem.summary = 'A simple REST client for the Docker Remote API'
  gem.homepage      = 'https://github.com/upserve/docker-api'
  gem.license       = 'MIT'
  gem.files         = `git ls-files lib README.md LICENSE`.split($\)
  gem.name          = 'docker-api'
  gem.version       = Docker::VERSION
  gem.add_dependency 'excon', '>= 0.64.0'
  gem.add_dependency 'multi_json'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'rspec-its'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'single_cov'
  gem.add_development_dependency 'webmock'
  gem.add_development_dependency 'parallel'
end
