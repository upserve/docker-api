n#!/bin/bash
set -x
set -e

# argv[0]
DOCKER_VERSION=$1

# enable docker repo
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
apt-get -y update

# enable backports
echo 'deb "https://apt.dockerproject.org/repo" ubuntu-trusty main' >> /etc/apt/sources.list.d/docker-main.list
apt-get -y update

# install package
apt-get -y install docker-engine=${DOCKER_VERSION}-0~trusty
