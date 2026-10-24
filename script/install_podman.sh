#!/bin/sh
set -ex

# Ubuntu ships podman in the universe repository (4.9.3 on 24.04), so no
# third-party repository is required.
#
# This previously pulled podman from the openSUSE Build Service repo
# devel:kubic:libcontainers:stable. That project was retired and the repo now
# serves an HTML "Resource is no longer available!" page in place of
# Release.key, so `apt-key add` failed with "no valid OpenPGP data found".

apt-get update

apt-get install -y podman

podman --version
