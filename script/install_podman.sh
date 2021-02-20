#!/bin/sh
set -ex

. /etc/os-release

curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key | sudo apt-key add -

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_18.04/ /" > /etc/apt/sources.list.d/podman.list

apt-get update

apt-get install -y podman
