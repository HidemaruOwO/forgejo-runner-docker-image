# Testing Guide

This document explains how to test the Forgejo Runner Docker images and understand the differences between DinD and DooD.

## Understanding Docker-in-Docker (DinD) vs Docker-outside-of-Docker (DooD)

### What is DinD (Docker-in-Docker)?

**DinD** runs a complete Docker daemon inside a container. This provides full isolation but requires:
- `--privileged` mode for standard DinD
- Special security options for rootless DinD
- More resources (each container runs its own daemon)

**Use cases:**
- CI/CD pipelines that need isolated Docker environments
- Testing Docker itself
- Building Docker images in isolated environments

**Variants:**
1. **docker:dind** - Standard DinD with privileged mode
2. **docker:dind-rootless** - Rootless DinD for better security

### What is DooD (Docker-outside-of-Docker)?

**DooD** mounts the host's Docker socket into the container, allowing the container to control the host's Docker daemon. This:
- Uses fewer resources (no daemon in container)
- Containers created are siblings, not children
- Less isolated (containers can affect host)

**Use cases:**
- CI/CD pipelines on trusted infrastructure
- Build automation where isolation isn't critical
- Development environments

**Variant:**
- **docker:cli** - Only the Docker CLI tools, no daemon

## Running the Tests

### Comprehensive Test Suite

Run all tests for Node.js 20 with all variants:

```bash
./test.sh
```

This will:
1. Build images for dind, dind-rootless, and cli variants
2. Test Docker functionality in each variant
3. Verify Node.js and npm installation
4. Test all utilities (bash, curl, wget, git, etc.)
5. Test npm package installation

### Quick Variant Test

Test a specific variant quickly:

```bash
# Test Node.js 20 with dind
./test-variant.sh 20 dind

# Test Node.js 18 with dind-rootless
./test-variant.sh 18 dind-rootless

# Test Node.js 22 with cli (DooD)
./test-variant.sh 22 cli
```

This will:
- Build the specified image
- Start a container with appropriate settings
- Run basic functionality tests
- Leave the container running for manual testing

### Manual Testing

#### Testing DinD (Standard)

```bash
# Build the image
docker build --build-arg NODE_VERSION=20 --build-arg DOCKER_VARIANT=dind -t test:dind .

# Run with privileged mode
docker run -d --name runner-dind --privileged -e DOCKER_TLS_CERTDIR="" test:dind

# Wait a moment for Docker daemon to start
sleep 5

# Test Docker functionality
docker exec runner-dind docker version
docker exec runner-dind docker run --rm hello-world

# Test Node.js
docker exec runner-dind node --version
docker exec runner-dind npm --version

# Interactive shell
docker exec -it runner-dind bash

# Clean up
docker rm -f runner-dind
```

#### Testing DinD (Rootless)

```bash
# Build the image
docker build --build-arg NODE_VERSION=20 --build-arg DOCKER_VARIANT=dind-rootless -t test:dind-rootless .

# Run with rootless requirements
docker run -d --name runner-rootless \
    --security-opt seccomp=unconfined \
    --device /dev/fuse \
    --tmpfs /tmp \
    --tmpfs /run \
    -e DOCKER_TLS_CERTDIR="" \
    test:dind-rootless

# Wait for Docker daemon
sleep 5

# Test Docker functionality
docker exec runner-rootless docker version
docker exec runner-rootless docker run --rm hello-world

# Verify running as non-root
docker exec runner-rootless id

# Clean up
docker rm -f runner-rootless
```

#### Testing CLI (DooD)

```bash
# Build the image
docker build --build-arg NODE_VERSION=20 --build-arg DOCKER_VARIANT=cli -t test:cli .

# Run with Docker socket mounted
docker run -d --name runner-cli \
    -v /var/run/docker.sock:/var/run/docker.sock \
    test:cli \
    sh -c "tail -f /dev/null"

# Test Docker CLI (talks to host daemon)
docker exec runner-cli docker version
docker exec runner-cli docker ps  # Should see the runner-cli container itself!

# Test Node.js
docker exec runner-cli node --version
docker exec runner-cli npm --version

# Clean up
docker rm -f runner-cli
```

## Test Matrix

The test suite validates:

| Component | Test |
|-----------|------|
| **Docker Variants** | dind, dind-rootless, cli |
| **Node.js Versions** | 18, 20, 22 |
| **Docker Functionality** | version, info, run containers |
| **Node.js Functionality** | version, execute code, npm |
| **Utilities** | bash, curl, wget, git, git-lfs, jq, yq, corepack |
| **Package Management** | npm install, require packages |

## Expected Results

### DinD Tests
- ✓ Docker daemon starts successfully
- ✓ Can run `docker info`
- ✓ Can pull and run images (e.g., `hello-world`)
- ✓ Node.js and npm work correctly
- ✓ All utilities are available

### DinD Rootless Tests
- ✓ Docker daemon starts as non-root user
- ✓ Can run `docker info`
- ✓ Can pull and run images
- ✓ UID is not 0 (not root)
- ✓ Node.js and npm work correctly

### CLI/DooD Tests
- ✓ Docker CLI connects to host daemon
- ✓ Can see host containers in `docker ps`
- ✓ Can run Docker commands
- ✓ Node.js and npm work correctly
- ✓ No Docker daemon running in container

## Troubleshooting

### DinD daemon won't start
- Ensure `--privileged` flag is used
- Try adding `-e DOCKER_TLS_CERTDIR=""`
- Check logs: `docker logs <container-name>`

### DinD rootless issues
- Ensure all required flags are present:
  - `--security-opt seccomp=unconfined`
  - `--device /dev/fuse`
  - `--tmpfs /tmp`
  - `--tmpfs /run`
- Check kernel support for user namespaces

### DooD permission errors
- Ensure Docker socket is mounted: `-v /var/run/docker.sock:/var/run/docker.sock`
- Check socket permissions on host
- Container user may need to be in docker group

## CI/CD Integration

The test suite can be integrated into CI/CD pipelines:

```yaml
- name: Run tests
  run: |
    chmod +x test.sh
    ./test.sh
```

See `.github/workflows/test.yml` for the automated test workflow.
