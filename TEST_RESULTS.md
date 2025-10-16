# Test Execution Results

## Overview
This document tracks test execution results for the Forgejo Runner Docker images.

## Test Environment Requirements

To run these tests successfully, you need:
- Docker installed and running
- Internet connectivity to pull base images and packages
- Sufficient disk space for multiple image variants
- For DinD tests: ability to run privileged containers
- For DinD rootless tests: kernel with user namespace support

## Running Tests Locally

### Quick Individual Variant Test

Test a single variant:
```bash
./test-variant.sh 20 cli      # Test CLI variant with Node.js 20
./test-variant.sh 20 dind     # Test DinD with Node.js 20
./test-variant.sh 18 dind-rootless  # Test rootless DinD with Node.js 18
```

### Comprehensive Test Suite

Run all tests:
```bash
./test.sh
```

This will build and test all three variants (dind, dind-rootless, cli) with Node.js 20.

## Expected Test Coverage

### Build Tests
- ✓ Image builds successfully for each variant
- ✓ Build args (NODE_VERSION, DOCKER_VARIANT) work correctly
- ✓ Multi-stage build completes without errors

### DinD (Docker-in-Docker) Tests
- ✓ Container starts with --privileged flag
- ✓ Docker daemon initializes successfully
- ✓ Can execute `docker version`
- ✓ Can execute `docker info`
- ✓ Can pull and run containers (hello-world)
- ✓ Node.js is installed and correct version
- ✓ npm is functional
- ✓ All utilities are available (bash, curl, wget, git, jq, yq, etc.)

### DinD Rootless Tests
- ✓ Container starts with security options
- ✓ Docker daemon initializes in rootless mode
- ✓ Running as non-root user (UID != 0)
- ✓ Can execute docker commands
- ✓ Can pull and run containers
- ✓ Node.js and utilities work correctly

### CLI/DooD Tests
- ✓ Container starts with Docker socket mounted
- ✓ Docker CLI connects to host daemon
- ✓ Can execute docker commands on host
- ✓ Can see host containers (including itself)
- ✓ Node.js is functional
- ✓ npm can install packages
- ✓ All utilities are available

### Utility Tests
All variants should include:
- bash
- curl
- wget
- git
- git-lfs
- jq
- yq
- npm
- npx
- corepack

## CI/CD Integration

Tests are automatically run via GitHub Actions on:
- Pull requests to master
- Pushes to master
- Manual workflow trigger

See `.github/workflows/test.yml` for the automated test configuration.

## Troubleshooting

### Network Timeouts During Build
If you experience network timeouts when pulling Alpine packages:
- Check your internet connection
- Try using a different DNS server
- Consider using Docker's buildx with retry options

### DinD Won't Start
- Ensure --privileged flag is used
- Add -e DOCKER_TLS_CERTDIR="" if needed
- Check Docker daemon logs

### DooD Permission Issues
- Verify Docker socket is mounted correctly
- Check socket permissions: `ls -l /var/run/docker.sock`
- User may need to be in docker group

## Manual Verification

After running tests, you can manually verify:

```bash
# For DinD
docker exec test-runner-dind docker run --rm alpine:latest echo "Hello from DinD"

# For CLI/DooD
docker exec test-runner-cli-quick docker ps

# Interactive shell
docker exec -it test-runner-dind bash
```

## Test Results Template

When running tests, document results like this:

```
Test Run: YYYY-MM-DD
Node Version: 20
Variant: dind

Build: ✓ PASS
Docker Daemon Start: ✓ PASS  
Docker Version: ✓ PASS
Docker Run: ✓ PASS
Node.js Version: ✓ PASS (v20.x.x)
npm Install: ✓ PASS
Utilities: ✓ PASS (bash, curl, wget, git, jq, yq)

Overall: PASS
```
