# This module holds the Errors for the gem.
module Docker::Error

  # The default error. It's never actually raised, but can be used to catch all
  # gem-specific errors that are thrown as they all subclass from this.
  class DockerError < StandardError; end

  # Raised when invalid arguments are passed to a method.
  class ArgumentError < DockerError; end

  # Raised when there is a state issue with a Container, such as trying to
  # create a Container that already exists.
  class ContainerError < DockerError; end

  # Analogous to ContainerError for Images.
  class ImageError < DockerError; end
end
