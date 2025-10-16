# Project Structure with Testing

## Repository Layout

```
forgejo-runner-docker-image/
├── .github/
│   └── workflows/
│       ├── docker-build-push.yml    # Build and publish images
│       └── test.yml                 # NEW: Automated testing workflow
├── docs/
│   └── docker-nodejs.png           # Project logo
├── Dockerfile                      # Multi-variant image definition
├── build-local.sh                  # Build script
├── README.md                       # Main documentation (updated)
├── .gitignore                      # Git ignore rules (updated)
│
├── test.sh                         # NEW: Comprehensive test suite
├── test-variant.sh                 # NEW: Quick variant testing
├── examples.sh                     # NEW: Usage examples
├── Makefile                        # NEW: Test automation
│
├── TESTING.md                      # NEW: Testing guide & DinD/DooD explanation
├── TEST_RESULTS.md                 # NEW: Test results template
├── CONTRIBUTING_TESTS.md           # NEW: How to add tests
└── SUMMARY_JP.md                   # NEW: Japanese summary
```

## What Each Variant Does

### Node.js Versions
- **18**: Node.js 18.x LTS
- **20**: Node.js 20.x LTS (default)
- **22**: Node.js 22.x Current

### Docker Variants

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Variant Types                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. DinD (Docker-in-Docker)                                     │
│     Base: docker:dind                                           │
│     • Runs Docker daemon inside container                       │
│     • Requires: --privileged                                    │
│     • Use case: Isolated CI/CD pipelines                        │
│     • Tags: node18-dind, node20-dind, node22-dind              │
│                                                                  │
│  2. DinD Rootless                                               │
│     Base: docker:dind-rootless                                  │
│     • Runs Docker daemon as non-root                            │
│     • Requires: --security-opt, --device /dev/fuse, --tmpfs     │
│     • Use case: Security-critical environments                  │
│     • Tags: node18-dind-rootless, node20-dind-rootless, etc.   │
│                                                                  │
│  3. CLI (DooD - Docker-outside-of-Docker)                       │
│     Base: docker:cli                                            │
│     • Docker client only, no daemon                             │
│     • Requires: -v /var/run/docker.sock:/var/run/docker.sock   │
│     • Use case: Development, trusted infrastructure             │
│     • Tags: node18-cli, node20-cli, node22-cli                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Test Coverage Matrix

```
                          │ Build │ Docker │ Node.js │ NPM │ Utils │
──────────────────────────┼───────┼────────┼─────────┼─────┼───────┤
Node 18 - DinD           │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 18 - DinD Rootless  │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 18 - CLI            │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 20 - DinD           │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 20 - DinD Rootless  │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 20 - CLI            │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 22 - DinD           │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 22 - DinD Rootless  │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
Node 22 - CLI            │   ✓   │   ✓    │    ✓    │  ✓  │   ✓   │
──────────────────────────┴───────┴────────┴─────────┴─────┴───────┘

Total: 9 variants × 5 test categories = 45 test scenarios
```

## Installed Utilities

Each image includes:
```
Core:
  ✓ Docker (daemon for dind variants, client for all)
  ✓ Node.js (version 18, 20, or 22)
  ✓ npm
  ✓ npx
  ✓ corepack

Development Tools:
  ✓ bash
  ✓ git
  ✓ git-lfs

Networking:
  ✓ curl
  ✓ wget

Data Processing:
  ✓ jq (JSON processor)
  ✓ yq (YAML processor)

Utilities:
  ✓ which
  ✓ zip/unzip
  ✓ xz
  ✓ zstd
  ✓ coreutils (ls, cat, etc.)
  ✓ findutils
  ✓ grep
  ✓ sed
  ✓ gawk
  ✓ sudo
  ✓ ca-certificates
  ✓ openssl
  ✓ gnupg
```

## Quick Start Guide

### For Users

```bash
# View examples
./examples.sh

# Test a variant quickly
./test-variant.sh 20 dind

# Run comprehensive tests
./test.sh

# Use Makefile
make test              # Run all tests
make test-dind         # Test DinD only
make clean             # Clean up test artifacts
```

### For CI/CD

```yaml
# Use in GitHub Actions / Forgejo Actions
jobs:
  build:
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-dind
      options: --privileged
    steps:
      - run: npm install
      - run: npm test
      - run: docker build -t myapp .
```

### For Development

```bash
# Use CLI variant for local development
docker run -d \
  --name dev \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-cli

# Interactive shell
docker exec -it dev bash
```

## Documentation Map

```
Entry Points:
├── README.md              → Overview, usage, available tags
└── examples.sh            → Practical examples for each variant

Testing:
├── TESTING.md             → Complete testing guide + DinD vs DooD
├── TEST_RESULTS.md        → Results template + troubleshooting  
├── CONTRIBUTING_TESTS.md  → How to add/modify tests
└── SUMMARY_JP.md          → Japanese implementation summary

Quick Reference:
├── test.sh                → Run comprehensive tests
├── test-variant.sh        → Quick variant test
└── Makefile               → make test, make clean, etc.

CI/CD:
└── .github/workflows/
    ├── docker-build-push.yml  → Build & publish images
    └── test.yml               → Automated testing
```

## Workflow

### Development Workflow
1. Make changes to Dockerfile
2. Test locally: `./test-variant.sh 20 dind`
3. Run full suite: `./test.sh` or `make test`
4. Commit and push
5. GitHub Actions runs full test matrix
6. Images are built and published

### Testing Workflow
1. Pull/build image
2. Start container with appropriate flags
3. Wait for services (if DinD)
4. Run tests
5. Verify output
6. Clean up

## Image Tags

Published to: `ghcr.io/hidemaruowo/forgejo-runner-docker-image`

```
Latest/Default:
  • latest → node20-dind

DinD variants:
  • node18-dind
  • node20-dind  
  • node22-dind

DinD Rootless:
  • node18-dind-rootless
  • node20-dind-rootless
  • node22-dind-rootless

CLI/DooD:
  • node18-cli
  • node20-cli
  • node22-cli
```

## Build Args

```dockerfile
ARG NODE_VERSION=20          # 18, 20, or 22
ARG DOCKER_VARIANT=dind      # dind, dind-rootless, or cli
```

## Summary

This project now has:
✅ Comprehensive test coverage for all variants
✅ Detailed documentation explaining DinD vs DooD
✅ Automated CI/CD testing
✅ Easy-to-use test scripts and Makefile
✅ Examples for common use cases
✅ Troubleshooting guides
✅ Contribution guidelines for tests

All 9 image variants (3 Node.js versions × 3 Docker variants) are thoroughly tested!
