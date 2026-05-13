#!/bin/bash

CLUSTER_NAME=${1:-"opa-agent"}
SHARED_VOLUME=$(pwd)/.volume

mkdir -p ${SHARED_VOLUME}

# this is manadatory in order to fluent-bit work
uuidgen -r -x | tr -d '-' > ${SHARED_VOLUME}/machine-id

# --registry-create k3d-registry.localhost:5000 \
k3d cluster create $CLUSTER_NAME \
    --api-port "localhost:6443" \
    --registry-create "k3d-registry.localhost:5000" \
    --port "9090:9090@loadbalancer" \
    --port "3000:3000@loadbalancer" \
    --port "3100:3100@loadbalancer" \
    --port "4318:4320@loadbalancer" \
    --port "4566:4566@loadbalancer" \
    --servers 1 \
    --agents 1 \
    --k3s-arg '--disable=metrics-server@server:*' \
    --volume "${SHARED_VOLUME}/machine-id:/etc/machine-id@server:*;agent:*" \
    --volume "$(pwd)/manifests:/var/lib/rancher/k3s/server/manifests/custom@server:*"
