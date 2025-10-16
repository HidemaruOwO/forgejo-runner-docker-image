#!/bin/bash

# Quick test script for individual variant
# Usage: ./test-variant.sh [node-version] [docker-variant]
# Example: ./test-variant.sh 20 dind

set -e

NODE_VERSION=${1:-20}
DOCKER_VARIANT=${2:-dind}
IMAGE_TAG="forgejo-runner-test:node${NODE_VERSION}-${DOCKER_VARIANT}"
CONTAINER_NAME="test-runner-${DOCKER_VARIANT}-quick"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing Node.js ${NODE_VERSION} with ${DOCKER_VARIANT} variant${NC}"

# Clean up any existing container
docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

# Build the image
echo -e "${BLUE}Building image...${NC}"
docker build \
    --build-arg NODE_VERSION=${NODE_VERSION} \
    --build-arg DOCKER_VARIANT=${DOCKER_VARIANT} \
    -t ${IMAGE_TAG} \
    .

# Run the container based on variant
echo -e "${BLUE}Starting container...${NC}"
case ${DOCKER_VARIANT} in
    dind)
        docker run -d \
            --name ${CONTAINER_NAME} \
            --privileged \
            -e DOCKER_TLS_CERTDIR="" \
            ${IMAGE_TAG}
        ;;
    dind-rootless)
        docker run -d \
            --name ${CONTAINER_NAME} \
            --security-opt seccomp=unconfined \
            --device /dev/fuse \
            --tmpfs /tmp \
            --tmpfs /run \
            -e DOCKER_TLS_CERTDIR="" \
            ${IMAGE_TAG}
        ;;
    cli)
        docker run -d \
            --name ${CONTAINER_NAME} \
            -v /var/run/docker.sock:/var/run/docker.sock \
            ${IMAGE_TAG} \
            sh -c "tail -f /dev/null"
        ;;
    *)
        echo -e "${RED}Unknown variant: ${DOCKER_VARIANT}${NC}"
        exit 1
        ;;
esac

# Wait for container to be ready
echo -e "${BLUE}Waiting for container to be ready...${NC}"
sleep 5

# For DinD variants, wait for Docker daemon
if [[ ${DOCKER_VARIANT} == dind* ]]; then
    echo -e "${BLUE}Waiting for Docker daemon...${NC}"
    for i in {1..30}; do
        if docker exec ${CONTAINER_NAME} docker info > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Docker daemon is ready${NC}"
            break
        fi
        sleep 1
    done
fi

# Run tests
echo -e "${BLUE}Running tests...${NC}"
echo ""

# Test Node.js
echo -n "Node.js version: "
docker exec ${CONTAINER_NAME} node --version

# Test npm
echo -n "npm version: "
docker exec ${CONTAINER_NAME} npm --version

# Test Docker
echo -n "Docker version: "
docker exec ${CONTAINER_NAME} docker --version

if [[ ${DOCKER_VARIANT} == dind* ]]; then
    echo -e "${BLUE}Testing Docker functionality...${NC}"
    docker exec ${CONTAINER_NAME} docker run --rm hello-world
fi

# Test utilities
echo -e "${BLUE}Testing utilities...${NC}"
for cmd in bash curl wget git jq yq; do
    if docker exec ${CONTAINER_NAME} which ${cmd} > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} ${cmd}"
    else
        echo -e "${RED}✗${NC} ${cmd}"
    fi
done

echo ""
echo -e "${GREEN}Test completed successfully!${NC}"
echo ""
echo "Container ${CONTAINER_NAME} is still running."
echo "To interact with it: docker exec -it ${CONTAINER_NAME} bash"
echo "To stop and remove it: docker rm -f ${CONTAINER_NAME}"
