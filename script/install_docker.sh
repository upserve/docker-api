#!/bin/bash
set -ex

declare -a SEMVER

# argv[0]
DOCKER_VERSION=$1
# argv[1]
DOCKER_CE=$2

# disable travis default installation
systemctl stop docker.service
apt-get -y --purge remove docker docker-engine docker-ce

# install gpg key for docker rpo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88

# enable docker repo
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
apt-get update
apt-cache gencaches

# install package
apt-get install docker-ce=${DOCKER_VERSION}
systemctl stop docker.service

echo 'DOCKER_OPTS="-H unix:///var/run/docker.sock --pidfile=/var/run/docker.pid"' > /etc/default/docker
cat /etc/default/docker

systemctl start docker.service
