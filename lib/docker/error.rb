# This module holds the Errors for the gem.
module Docker::Error

  # The default error. It's never actually raised, but can be used to catch all
  # gem-specific errors that are thrown as they all subclass from this.
  class DockerError < StandardError; end

  # Raised when invalid arguments are passed to a method.
  class ArgumentError < DockerError; end

  # Raised when a method requires a Model to be in a certain state (typically
  # created or not created), but the Model is not in that state.
  class StateError < DockerError; end

  # Raised when a request returns a 400.
  class ClientError < DockerError; end

  # Raised when a request returns a 500.
  class ServerError < DockerError; end
end
