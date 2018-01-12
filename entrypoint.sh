#!/bin/sh
set -e

# only run docker if we're in privileged mode
if ip link add dummy0 type dummy >/dev/null 2>&1; then
    # from https://github.com/aws/aws-codebuild-docker-images/blob/master/ubuntu/docker/17.09.0/dockerd-entrypoint.sh
    /usr/local/bin/dockerd \
        --host=unix:///var/run/docker.sock \
        --host=tcp://0.0.0.0:2375 \
        --storage-driver=overlay >/var/log/docker.log 2>&1 &


    tries=0
    d_timeout=60
    until docker info >/dev/null 2>&1
    do
        if [ "$tries" -gt "$d_timeout" ]; then
                    cat /var/log/docker.log
            echo 'Timed out trying to connect to internal docker host.' >&2
            exit 1
        fi
            tries=$(( $tries + 1 ))
        sleep 1
    done
fi

su gradle -c "$*"
