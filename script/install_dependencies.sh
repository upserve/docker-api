#!/bin/bash
set -x
set -e

# Update bundler
gem install bundler

# Install docker
# sudo mkdir -p /opt/docker
# sudo curl -fo /opt/docker/docker "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}"
# sudo chmod +x /opt/docker/docker

echo 'deb http://ftp.de.debian.org/debian vivid-backports main' >> /etc/apt/sources.list.d/docker-main.list
apt-get update
apt-get install docker-engine ${DOCKER_VERSION}-0~vivid
service docker start

# case "${DOCKER_VERSION}" in
#     "1.6.2" )        
#         DAEMON_ARG="-d"
#         ;;
#     *)
#         DAEMON_ARG="daemon"
#         ;;
# esac

# running=0
# for x in {1..3}
# do
#     [[ $running != 1 ]] || break
#     rm -rf /var/run/docker.pid
#     /opt/docker/docker ${DAEMON_ARG} -D &
#     DOCKER_PID=$!
#     sleep 5
#     echo "Checking if docker is running"
#     ps -p $DOCKER_PID && running=1 || echo "Couldn't start docker, retrying"
# done
# echo "Docker running, continuing"
