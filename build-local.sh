#!/bin/bash

# Script to build Docker images locally
# Usage: ./build-local.sh [node-version] [docker-variant]
# Example: ./build-local.sh 20 dind

NODE_VERSION=${1:-20}
DOCKER_VARIANT=${2:-dind}

echo "Building Docker image with Node.js ${NODE_VERSION} and ${DOCKER_VARIANT}"

docker build \
  --build-arg NODE_VERSION=${NODE_VERSION} \
  --build-arg DOCKER_VARIANT=${DOCKER_VARIANT} \
  -t forgejo-runner:node${NODE_VERSION}-${DOCKER_VARIANT} \
  .

echo "Build completed!"
echo "Image tag: forgejo-runner:node${NODE_VERSION}-${DOCKER_VARIANT}"
