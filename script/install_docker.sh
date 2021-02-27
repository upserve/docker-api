#!/bin/bash
set -ex

declare -a SEMVER

# argv[0]
DOCKER_VERSION=$1
# argv[1]
DOCKER_CE=$2

# disable travis default installation
systemctl stop docker.service
apt-get -y --purge remove docker docker-engine docker.io containerd runc

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

set +e
# install package
apt-get install docker-ce=${DOCKER_VERSION}

if [ $? -ne 0 ]; then
  echo "Error: Could not install ${DOCKER_VERSION}"
  echo "Available docker versions:"
  apt-cache madison docker-ce
  exit 1
fi
set -e

systemctl stop docker.service

echo 'DOCKER_OPTS="-H unix:///var/run/docker.sock --pidfile=/var/run/docker.pid"' > /etc/default/docker
cat /etc/default/docker

systemctl start docker.service
