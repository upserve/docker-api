#!/bin/bash
set -x
set -e

# argv[0]
DOCKER_VERSION=$1
# argv[1]
DOCKER_CE=$2

# disable travis default installation
#service docker stop
apt-get -y --purge remove docker docker-engine docker-ce

if [ "$DOCKER_CE" = "1" ]; then
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
	apt-get install docker-ce=${DOCKER_VERSION}~ce-0~ubuntu-trusty
else
	# install gpg key for docker rpo
	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv 58118E89F3A912897C070ADBF76221572C52609D

	# enable docker repo
	echo 'deb "https://apt.dockerproject.org/repo" ubuntu-trusty main' >> /etc/apt/sources.list.d/docker-main.list
	apt-get update -o Dir::Etc::sourcelist='sources.list.d/docker-main.list' -o Dir::Etc::sourceparts='-' -o APT::Get::List-Cleanup='0'
	apt-cache gencaches

	# install package
	apt-get -y --force-yes install docker-engine=${DOCKER_VERSION}-0~trusty
fi
echo 'DOCKER_OPTS="-H unix:///var/run/docker.sock --pidfile=/var/run/docker.pid"' > /etc/default/docker
cat /etc/default/docker
