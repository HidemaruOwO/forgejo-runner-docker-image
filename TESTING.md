# Testing Guide

## Local Build Testing

To test the Docker image builds locally, use the provided `build-local.sh` script:

```bash
# Build with default Node.js 20 and dind
./build-local.sh

# Build with Node.js 18 and dind
./build-local.sh 18 dind

# Build with Node.js 22 and dind-rootless
./build-local.sh 22 dind-rootless
```

Or use Docker directly:

```bash
docker build --build-arg NODE_VERSION=20 --build-arg DOCKER_VARIANT=dind -t test-image .
```

## Testing the Built Image

Once built, you can test the image to verify all components are installed:

```bash
# Run the container
docker run -d --name test-runner test-image

# Check Node.js version
docker exec test-runner node --version

# Check npm version
docker exec test-runner npm --version

# Check Docker
docker exec test-runner docker --version

# Check git
docker exec test-runner git --version

# Check Python
docker exec test-runner python3 --version

# Check bash
docker exec test-runner bash --version

# Clean up
docker stop test-runner
docker rm test-runner
```

## GitHub Actions Workflow Testing

The workflow can be tested by:

1. **Push to main branch**: Automatically triggers on push to main
2. **Manual trigger**: Go to Actions tab and use "workflow_dispatch"
3. **Monthly schedule**: Runs automatically on the 1st of each month

## Expected Outputs

The workflow will create the following image tags in ghcr.io:

- `node18-dind`
- `node18-dind-YYYYMMDD`
- `node18-dind-rootless`
- `node18-dind-rootless-YYYYMMDD`
- `node20-dind`
- `node20-dind-YYYYMMDD`
- `node20-dind-rootless`
- `node20-dind-rootless-YYYYMMDD`
- `node22-dind`
- `node22-dind-YYYYMMDD`
- `node22-dind-rootless`
- `node22-dind-rootless-YYYYMMDD`
- `latest` (points to node20-dind)

## Verification Checklist

- [ ] All Node.js versions (18, 20, 22) build successfully
- [ ] Both Docker variants (dind, dind-rootless) build successfully
- [ ] Node.js is accessible and correct version
- [ ] npm is installed and updated to latest
- [ ] Docker commands work
- [ ] All utilities (git, curl, wget, bash, python3) are available
- [ ] Images are pushed to ghcr.io successfully
