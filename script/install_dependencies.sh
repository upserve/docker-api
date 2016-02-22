# echo "Docker running, continuing"
# done
#     ps -p $DOCKER_PID && running=1 || echo "Couldn't start docker, retrying"
#     echo "Checking if docker is running"
#     sleep 5
#     DOCKER_PID=$!
#     /opt/docker/docker ${DAEMON_ARG} -D &
#     rm -rf /var/run/docker.pid
#     [[ $running != 1 ]] || break
# do
# for x in {1..3}
# running=0

# esac
#         ;;
#         DAEMON_ARG="daemon"
#     *)
#         ;;
#         DAEMON_ARG="-d"
#     "1.6.2" )
# case "${DOCKER_VERSION}" in

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb "https://apt.dockerproject.org/repo" ubuntu-wily main' >> /etc/apt/sources.list.d/docker-main.list
apt-get -y update
apt-get -y install docker-engine=${DOCKER_VERSION}-0~wily
# service docker start

# sudo chmod +x /opt/docker/docker
# sudo curl -fo /opt/docker/docker "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}"
# sudo mkdir -p /opt/docker
# Install docker

# gem install bundler
# Update bundler

set -e
set -x
#!/bin/bash
