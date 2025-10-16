ARG DOCKER_VARIANT=dind
ARG NODE_VERSION=20

# Use Node.js Alpine image to get the specific Node version
FROM node:${NODE_VERSION}-alpine AS node-source

# Build final image based on Docker variant
FROM docker:${DOCKER_VARIANT}

ARG NODE_VERSION

# Copy Node.js from the node-source stage
COPY --from=node-source /usr/local/bin/node /usr/local/bin/
COPY --from=node-source /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node-source /usr/local/bin/npm /usr/local/bin/
COPY --from=node-source /usr/local/bin/npx /usr/local/bin/
COPY --from=node-source /usr/local/bin/corepack /usr/local/bin/

USER root

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    openssh-client \
    python3 \
    py3-pip \
    build-base \
    git-lfs \
    jq \
    yq \
    ca-certificates \
    openssl \
    gnupg \
    rsync \
    which \
    tzdata \
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
    && npm install -g npm@latest \
    && corepack enable \
    && git lfs install

WORKDIR /workspace

ENTRYPOINT ["tail", "-f", "/dev/null"]
