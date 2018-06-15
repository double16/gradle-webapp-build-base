#!/bin/bash

IGNORE="$1"
PRIVATE="$2"

echo "$0 [repository_ignore_prefix] [repository_private_prefix]"
echo "$0 '${IGNORE}' '${PRIVATE}'"

echo Building Docker Public Image Cache ...
mkdir -p /home/gradle/docker/public
REPOS="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v "^${IGNORE:-never%more}\|:<none>\$")"
rm -f /home/gradle/docker/public/image.tar*
if [ -n "${REPOS}" ]; then
    docker save ${REPOS} | gzip -9 > /home/gradle/docker/public/image.tar.gz
fi
echo Built Docker Public Image Cache

rm -f /home/gradle/docker/private/image.tar*
if [ -n "${PRIVATE}" ]; then
    echo Building Docker Private Image Cache ...
    mkdir -p /home/gradle/docker/private
    PRIV_REPOS="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${PRIVATE}")"
    if [ -n "${PRIV_REPOS}" ]; then
        docker save ${PRIV_REPOS} | gzip -9 > /home/gradle/docker/private/image.tar.gz
    fi
    echo Built Docker Private Image Cache
fi
