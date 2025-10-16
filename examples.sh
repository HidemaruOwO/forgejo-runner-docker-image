#!/bin/bash

# Examples of using Forgejo Runner Docker images
# Demonstrates DinD, DinD rootless, and DooD (CLI) variants

set -e

echo "=========================================="
echo "Forgejo Runner Docker Image Examples"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_example() {
    echo -e "${BLUE}Example: $1${NC}"
    echo -e "${YELLOW}$2${NC}"
    echo ""
}

echo "These are example commands for using the Forgejo Runner Docker images."
echo "The images support three variants: DinD, DinD Rootless, and CLI (DooD)."
echo ""

print_example "DinD (Docker-in-Docker) - Standard" \
    "Runs a complete Docker daemon inside the container with privileged mode."

cat << 'EOF'
# Build locally
docker build --build-arg NODE_VERSION=20 --build-arg DOCKER_VARIANT=dind \
  -t forgejo-runner:node20-dind .

# Or use pre-built image from GitHub Container Registry
docker run -d \
  --name forgejo-runner \
  --privileged \
  -e DOCKER_TLS_CERTDIR="" \
  ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-dind

# Wait for Docker daemon to start
sleep 5

# Verify Docker is working
docker exec forgejo-runner docker version
docker exec forgejo-runner docker run --rm hello-world

# Run a Node.js project build inside
docker exec forgejo-runner sh -c "cd /workspace && npm install && npm test"

# Interactive shell
docker exec -it forgejo-runner bash

# Cleanup
docker rm -f forgejo-runner
EOF

echo ""
echo "=========================================="
echo ""

print_example "DinD Rootless - Enhanced Security" \
    "Runs Docker daemon as non-root user for better security."

cat << 'EOF'
# Build locally
docker build --build-arg NODE_VERSION=20 --build-arg DOCKER_VARIANT=dind-rootless \
  -t forgejo-runner:node20-dind-rootless .

# Or use pre-built image
docker run -d \
  --name forgejo-runner-rootless \
  --security-opt seccomp=unconfined \
  --device /dev/fuse \
  --tmpfs /tmp \
  --tmpfs /run \
  -e DOCKER_TLS_CERTDIR="" \
  ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-dind-rootless

# Wait for Docker daemon to start
sleep 5

# Verify Docker is working
docker exec forgejo-runner-rootless docker version

# Verify running as non-root
docker exec forgejo-runner-rootless id

# Run containers
docker exec forgejo-runner-rootless docker run --rm alpine:latest echo "Hello from rootless!"

# Cleanup
docker rm -f forgejo-runner-rootless
EOF

echo ""
echo "=========================================="
echo ""

print_example "CLI/DooD (Docker-outside-of-Docker)" \
    "Uses host Docker daemon via socket mount. No daemon inside container."

cat << 'EOF'
# Build locally
docker build --build-arg NODE_VERSION=20 --build-arg DOCKER_VARIANT=cli \
  -t forgejo-runner:node20-cli .

# Or use pre-built image
docker run -d \
  --name forgejo-runner-cli \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-cli \
  sh -c "tail -f /dev/null"

# Docker commands talk to host daemon
docker exec forgejo-runner-cli docker ps

# You can see the runner-cli container itself!
docker exec forgejo-runner-cli docker ps --filter name=forgejo-runner-cli

# Build a project
docker exec -w /workspace forgejo-runner-cli npm install
docker exec -w /workspace forgejo-runner-cli npm run build

# Cleanup
docker rm -f forgejo-runner-cli
EOF

echo ""
echo "=========================================="
echo ""

print_example "Using in CI/CD Pipeline" \
    "Example Forgejo Actions workflow configuration."

cat << 'EOF'
# .forgejo/workflows/build.yml
name: Build and Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-dind
      options: --privileged
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Wait for Docker
        run: |
          for i in {1..30}; do
            if docker info > /dev/null 2>&1; then
              echo "Docker is ready"
              break
            fi
            sleep 1
          done
      
      - name: Install dependencies
        run: npm install
      
      - name: Run tests
        run: npm test
      
      - name: Build Docker image
        run: docker build -t my-app:latest .
      
      - name: Test Docker image
        run: docker run --rm my-app:latest npm test
EOF

echo ""
echo "=========================================="
echo ""

print_example "Comparison Table" \
    "When to use each variant:"

cat << 'EOF'
┌──────────────────┬─────────────┬──────────────────┬──────────────┐
│ Feature          │ DinD        │ DinD Rootless    │ CLI (DooD)   │
├──────────────────┼─────────────┼──────────────────┼──────────────┤
│ Isolation        │ High        │ High             │ Low          │
│ Security         │ Medium      │ High             │ Low-Medium   │
│ Resource Usage   │ High        │ High             │ Low          │
│ Setup Complexity │ Medium      │ High             │ Low          │
│ Requires         │ --privileged│ Special flags    │ Socket mount │
│ Use Case         │ CI/CD       │ Secure CI/CD     │ Dev/Trusted  │
└──────────────────┴─────────────┴──────────────────┴──────────────┘

Recommendations:
- Use DinD for general CI/CD pipelines with good isolation
- Use DinD Rootless for security-critical environments
- Use CLI (DooD) for development or trusted infrastructure
EOF

echo ""
echo "=========================================="
echo ""
echo -e "${GREEN}For more information:${NC}"
echo "- See TESTING.md for detailed testing guide"
echo "- See TEST_RESULTS.md for troubleshooting"
echo "- Run ./test.sh to test all variants"
echo "- Run ./test-variant.sh [node-version] [variant] for quick tests"
echo ""
