# Using Docker Images in Forgejo Actions

This guide explains how to properly use the forgejo-runner-docker-image in Forgejo Actions workflows, particularly when you need to run Docker commands.

## The Problem

When using the `node20-dind` (Docker-in-Docker) image in Forgejo Actions, you might encounter this error:

```
ERROR: Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

This happens because Docker-in-Docker (DinD) containers require special configuration to work properly in CI/CD environments.

## Solutions

There are three main approaches to run Docker in Forgejo Actions:

### 1. Using Docker-in-Docker (DinD) with Container Job

This approach runs the entire job inside the DinD container with privileged mode.

```yaml
name: Build with DinD

on:
  push:
    branches:
      - master

jobs:
  build:
    runs-on: docker
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-dind
      options: --privileged
    steps:
      - name: Start Docker daemon
        run: |
          # Start Docker daemon in background
          dockerd-entrypoint.sh &
          
          # Wait for Docker daemon to be ready
          echo "Waiting for Docker daemon to start..."
          for i in {1..30}; do
            if docker info >/dev/null 2>&1; then
              echo "Docker daemon is ready!"
              break
            fi
            echo "Waiting... ($i/30)"
            sleep 1
          done
          
          docker info

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myimage:latest .
```

**Pros:**
- Complete isolation
- Works with complex Docker operations
- Doesn't affect host system

**Cons:**
- Requires privileged mode
- More resource intensive
- Requires manual daemon startup

### 2. Using Docker-on-Docker (DooD) with CLI Image

This approach uses the host's Docker daemon by mounting the Docker socket.

```yaml
name: Build with DooD

on:
  push:
    branches:
      - master

jobs:
  build:
    runs-on: docker
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-cli
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myimage:latest .
```

**Pros:**
- Simpler configuration
- No privileged mode needed
- Faster startup
- Shares Docker layer cache with host

**Cons:**
- Security considerations (container has access to host Docker)
- May conflict with host Docker operations

### 3. Using Services (Recommended for most cases)

This approach uses a DinD service container alongside your job container.

```yaml
name: Build with DinD Service

on:
  push:
    branches:
      - master

jobs:
  build:
    runs-on: ubuntu-latest
    services:
      docker:
        image: docker:dind
        options: --privileged
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-cli
      env:
        DOCKER_HOST: tcp://docker:2376
        DOCKER_TLS_CERTDIR: /certs
        DOCKER_TLS_VERIFY: 1
        DOCKER_CERT_PATH: /certs/client
      volumes:
        - docker-certs:/certs
    steps:
      - name: Wait for Docker
        run: |
          until docker info >/dev/null 2>&1; do
            echo "Waiting for Docker daemon..."
            sleep 1
          done
          docker info

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myimage:latest .
```

**Pros:**
- Good isolation
- Standard Docker setup
- Works with most CI/CD platforms

**Cons:**
- More complex configuration
- Requires proper network and volume setup

## Complete Example

Here's a complete example that builds and pushes a Docker image to the Forgejo Container Registry:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - master

jobs:
  build:
    runs-on: docker
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-dind
      options: --privileged
    steps:
      - name: Start Docker daemon
        run: |
          # Start Docker daemon in background
          dockerd-entrypoint.sh &
          
          # Wait for Docker daemon to be ready
          echo "Waiting for Docker daemon to start..."
          for i in {1..30}; do
            if docker info >/dev/null 2>&1; then
              echo "Docker daemon is ready!"
              break
            fi
            echo "Waiting... ($i/30)"
            sleep 1
          done
          
          docker info

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Forgejo Container Registry
        run: |
          echo "${{ secrets.FORGEJO_TOKEN }}" | docker login ${{ github.server_url }} -u ${{ github.actor }} --password-stdin

      - name: Build Docker image
        run: |
          docker build -t ${{ github.server_url }}/${{ github.repository }}:${{ github.sha }} .
          docker build -t ${{ github.server_url }}/${{ github.repository }}:latest .

      - name: Push Docker image
        run: |
          docker push ${{ github.server_url }}/${{ github.repository }}:${{ github.sha }}
          docker push ${{ github.server_url }}/${{ github.repository }}:latest
```

## Troubleshooting

### Docker daemon not starting

If the Docker daemon fails to start, check:

1. **Privileged mode**: Make sure the container is running with `--privileged` flag
2. **Timeout**: Increase the wait time if your system is slow
3. **Logs**: Check Docker daemon logs with `cat /var/log/dockerd.log` or `journalctl -u docker`

### Permission denied errors

If you get permission errors accessing Docker:

1. **Socket permissions**: Make sure `/var/run/docker.sock` is accessible
2. **User context**: Check if your user is in the docker group (for DooD approach)

### TLS certificate errors

If you encounter TLS certificate errors:

1. **Disable TLS**: Add `-e DOCKER_TLS_CERTDIR=""` to container options (for development only)
2. **Certificate path**: Ensure `DOCKER_CERT_PATH` is set correctly

## Image Variants

Choose the right image variant for your use case:

- **node20-dind**: For Docker-in-Docker setups (requires privileged mode)
- **node20-dind-rootless**: For rootless Docker-in-Docker (more secure, may have limitations)
- **node20-cli**: For Docker-on-Docker setups (uses host Docker via socket mount)

## Security Considerations

1. **DinD with privileged mode**: Provides the best isolation but requires elevated privileges
2. **DooD with socket mount**: Simpler but gives container full access to host Docker
3. **Rootless DinD**: More secure but may not work with all Docker features

Choose the approach that best balances your security requirements and operational needs.
