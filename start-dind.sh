#!/bin/bash -e

pgrep dockerd >/dev/null && exit 0
nohup /usr/local/bin/dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 --storage-driver=overlay >/var/log/docker.log &
timeout 60 sh -c "until docker info >/dev/null 2>&1; do echo .; sleep 1; done"
echo Docker-in-Docker Started
