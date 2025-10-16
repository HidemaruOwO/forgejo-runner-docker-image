ARG DOCKER_VARIANT=dind
ARG NODE_VERSION=20

# Use Node.js Alpine image to get the specific Node version
FROM node:${NODE_VERSION}-alpine AS node-source

# Build final image based on Docker variant
FROM docker:${DOCKER_VARIANT}

ARG NODE_VERSION

# Copy Node.js binaries and libraries from the node-source stage
COPY --from=node-source /usr/local/bin/node /usr/local/bin/node
COPY --from=node-source /usr/local/lib/node_modules/ /usr/local/lib/node_modules/

USER root

# Symlink npm and other tools to make them available in PATH
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    ln -sf /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack && \
    chmod +x /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack


# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    git-lfs \
    jq \
    yq \
    ca-certificates \
    openssl \
    gnupg \
    which \
    zip \
    unzip \
    xz \
    zstd \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    sudo \
    && corepack enable

WORKDIR /workspace

ENTRYPOINT ["tail", "-f", "/dev/null"]
