#!/bin/sh
[ -e /var/run/docker.sock ] && chown gradle /var/run/docker.sock
su gradle -c "$*"
