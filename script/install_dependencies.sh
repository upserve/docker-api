#!/bin/bash
set -e

# Update bundler
gem install bundler

# Install docker
sudo mkdir -p /opt/docker
sudo curl -fo /opt/docker/docker "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}"
sudo chmod +x /opt/docker/docker
sudo /opt/docker/docker -d -D &
