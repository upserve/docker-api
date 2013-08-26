# The module holds all of the Excon middleware for the gem.
module Docker::Middleware
  autoload :Base, 'docker/middleware/base'
  autoload :Casifier, 'docker/middleware/casifier'
  autoload :JSON, 'docker/middleware/json'
end
