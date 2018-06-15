#!/bin/bash

echo Restore Docker Public Image Cache
if [ -s /home/gradle/docker/public/image.tar ]; then
    docker load -i /home/gradle/docker/public/image.tar
elif [ -s /home/gradle/docker/public/image.tar.gz ]; then
    zcat /home/gradle/docker/public/image.tar.gz | docker load
fi

echo Restore Docker Private Image Cache
if [ -s /home/gradle/docker/private/image.tar ]; then
    docker load -i /home/gradle/docker/private/image.tar
elif [ -s /home/gradle/docker/private/image.tar.gz ]; then
    zcat /home/gradle/docker/private/image.tar.gz | docker load
fi

echo Docker Image Cache Loaded
