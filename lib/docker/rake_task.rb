require 'rake'
require 'docker'

# This class allows image-based tasks to be created.
class Docker::ImageTask
  def needed?
    Docker::Image.all(:all => true).any? { |image|
      image['RepoTags'].include?(repo_tag)
    }
  end

  def repo
    name.split(':')[0]
  end

  def tag
    name.split(':')[1] || 'latest'
  end

  def repo_tag
    "#{repo}:#{tag}"
  end
end

# Monkey patch Rake::DSL to add the `image` method.
module Rake::DSL
  def image(*args, &block)
    Docker::ImageTask.define_task(*args, &block)
  end
end
