#!/bin/bash
set -x
set -e

# enable backports
echo 'deb "https://apt.dockerproject.org/repo" wily-backports main' >> /etc/apt/sources.list.d/wily-backports.list

# enable docker repo
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb "https://apt.dockerproject.org/repo" ubuntu-wily main' >> /etc/apt/sources.list.d/docker-main.list

# update apt cache
apt-get -y update

# install package
apt-get -y install docker-engine=${DOCKER_VERSION}-0~wily
