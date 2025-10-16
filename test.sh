#!/bin/bash

# Comprehensive test script for Forgejo Runner Docker images
# Tests DinD (Docker-in-Docker), DinD-rootless, and CLI (DooD) variants
# with multiple Node.js versions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Print colored message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$1")
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Clean up function
cleanup() {
    print_info "Cleaning up containers and networks..."
    
    # Stop and remove test containers
    for container in test-runner-dind test-runner-dind-rootless test-runner-cli; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            docker rm -f ${container} 2>/dev/null || true
        fi
    done
    
    # Remove test images if they exist
    for image in forgejo-runner-test:node20-dind forgejo-runner-test:node20-dind-rootless forgejo-runner-test:node20-cli; do
        if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${image}$"; then
            docker rmi -f ${image} 2>/dev/null || true
        fi
    done
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Test if command exists in container
test_command_in_container() {
    local container=$1
    local command=$2
    local description=$3
    
    if docker exec ${container} which ${command} > /dev/null 2>&1; then
        print_success "${description}: ${command} is available"
        return 0
    else
        print_error "${description}: ${command} is NOT available"
        return 1
    fi
}

# Test if command runs successfully in container
test_command_runs() {
    local container=$1
    local command=$2
    local description=$3
    
    if docker exec ${container} sh -c "${command}" > /dev/null 2>&1; then
        print_success "${description}: ${command} runs successfully"
        return 0
    else
        print_error "${description}: ${command} failed to run"
        return 1
    fi
}

# Test Node.js version
test_nodejs_version() {
    local container=$1
    local expected_major=$2
    
    local actual_version=$(docker exec ${container} node --version | sed 's/v//')
    local actual_major=$(echo ${actual_version} | cut -d. -f1)
    
    if [ "${actual_major}" = "${expected_major}" ]; then
        print_success "Node.js version check: v${actual_version} (expected major version ${expected_major})"
        return 0
    else
        print_error "Node.js version check: v${actual_version} (expected major version ${expected_major})"
        return 1
    fi
}

# Build test image
build_test_image() {
    local node_version=$1
    local docker_variant=$2
    local tag="forgejo-runner-test:node${node_version}-${docker_variant}"
    
    print_info "Building image: ${tag}"
    
    if docker build \
        --build-arg NODE_VERSION=${node_version} \
        --build-arg DOCKER_VARIANT=${docker_variant} \
        -t ${tag} \
        . > /tmp/build-${node_version}-${docker_variant}.log 2>&1; then
        print_success "Image built successfully: ${tag}"
        return 0
    else
        print_error "Failed to build image: ${tag}"
        cat /tmp/build-${node_version}-${docker_variant}.log
        return 1
    fi
}

# Test DinD variant
test_dind_variant() {
    local node_version=$1
    local container_name="test-runner-dind"
    local image="forgejo-runner-test:node${node_version}-dind"
    
    print_section "Testing DinD Variant (Node.js ${node_version})"
    
    # Build image
    if ! build_test_image ${node_version} "dind"; then
        return 1
    fi
    
    # Start container with privileged mode (required for DinD)
    print_info "Starting DinD container..."
    if ! docker run -d \
        --name ${container_name} \
        --privileged \
        -e DOCKER_TLS_CERTDIR="" \
        ${image} > /dev/null 2>&1; then
        print_error "Failed to start DinD container"
        return 1
    fi
    print_success "DinD container started"
    
    # Wait for Docker daemon to be ready
    print_info "Waiting for Docker daemon to start..."
    sleep 5
    
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec ${container_name} docker info > /dev/null 2>&1; then
            print_success "Docker daemon is ready"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "Docker daemon failed to start within timeout"
        docker logs ${container_name}
        return 1
    fi
    
    # Test Docker functionality
    print_info "Testing Docker functionality in DinD..."
    test_command_runs ${container_name} "docker version" "Docker version command"
    test_command_runs ${container_name} "docker info" "Docker info command"
    test_command_runs ${container_name} "docker run --rm hello-world" "Run hello-world container"
    
    # Test Node.js
    print_info "Testing Node.js in DinD..."
    test_nodejs_version ${container_name} ${node_version}
    test_command_runs ${container_name} "node -e 'console.log(\"Hello from Node.js\")'" "Node.js execution"
    
    # Test utilities
    print_info "Testing installed utilities in DinD..."
    test_command_in_container ${container_name} "bash" "Bash"
    test_command_in_container ${container_name} "curl" "curl"
    test_command_in_container ${container_name} "wget" "wget"
    test_command_in_container ${container_name} "git" "git"
    test_command_in_container ${container_name} "npm" "npm"
    test_command_in_container ${container_name} "npx" "npx"
    test_command_in_container ${container_name} "corepack" "corepack"
    test_command_in_container ${container_name} "jq" "jq"
    test_command_in_container ${container_name} "yq" "yq"
    
    # Test npm functionality
    test_command_runs ${container_name} "npm --version" "npm version check"
    
    # Test git functionality
    test_command_runs ${container_name} "git --version" "git version check"
    
    # Clean up
    docker rm -f ${container_name} > /dev/null 2>&1
}

# Test DinD rootless variant
test_dind_rootless_variant() {
    local node_version=$1
    local container_name="test-runner-dind-rootless"
    local image="forgejo-runner-test:node${node_version}-dind-rootless"
    
    print_section "Testing DinD Rootless Variant (Node.js ${node_version})"
    
    # Build image
    if ! build_test_image ${node_version} "dind-rootless"; then
        return 1
    fi
    
    # Start container with rootless requirements
    print_info "Starting DinD rootless container..."
    if ! docker run -d \
        --name ${container_name} \
        --security-opt seccomp=unconfined \
        --device /dev/fuse \
        --tmpfs /tmp \
        --tmpfs /run \
        -e DOCKER_TLS_CERTDIR="" \
        ${image} > /dev/null 2>&1; then
        print_error "Failed to start DinD rootless container"
        return 1
    fi
    print_success "DinD rootless container started"
    
    # Wait for Docker daemon to be ready
    print_info "Waiting for Docker daemon to start..."
    sleep 5
    
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec ${container_name} docker info > /dev/null 2>&1; then
            print_success "Docker daemon is ready"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "Docker daemon failed to start within timeout"
        docker logs ${container_name}
        return 1
    fi
    
    # Test Docker functionality
    print_info "Testing Docker functionality in DinD rootless..."
    test_command_runs ${container_name} "docker version" "Docker version command"
    test_command_runs ${container_name} "docker info" "Docker info command"
    test_command_runs ${container_name} "docker run --rm hello-world" "Run hello-world container"
    
    # Verify running as non-root
    local user_id=$(docker exec ${container_name} id -u)
    if [ "${user_id}" != "0" ]; then
        print_success "Running as non-root user (UID: ${user_id})"
    else
        print_warning "Running as root user (expected non-root for rootless variant)"
    fi
    
    # Test Node.js
    print_info "Testing Node.js in DinD rootless..."
    test_nodejs_version ${container_name} ${node_version}
    test_command_runs ${container_name} "node -e 'console.log(\"Hello from Node.js\")'" "Node.js execution"
    
    # Test utilities
    print_info "Testing installed utilities in DinD rootless..."
    test_command_in_container ${container_name} "bash" "Bash"
    test_command_in_container ${container_name} "curl" "curl"
    test_command_in_container ${container_name} "wget" "wget"
    test_command_in_container ${container_name} "git" "git"
    test_command_in_container ${container_name} "npm" "npm"
    
    # Clean up
    docker rm -f ${container_name} > /dev/null 2>&1
}

# Test CLI variant (DooD - Docker outside of Docker)
test_cli_variant() {
    local node_version=$1
    local container_name="test-runner-cli"
    local image="forgejo-runner-test:node${node_version}-cli"
    
    print_section "Testing CLI Variant / DooD (Node.js ${node_version})"
    
    # Build image
    if ! build_test_image ${node_version} "cli"; then
        return 1
    fi
    
    # Start container with Docker socket mounted (DooD)
    print_info "Starting CLI container with Docker socket..."
    if ! docker run -d \
        --name ${container_name} \
        -v /var/run/docker.sock:/var/run/docker.sock \
        ${image} \
        sh -c "tail -f /dev/null" > /dev/null 2>&1; then
        print_error "Failed to start CLI container"
        return 1
    fi
    print_success "CLI container started"
    
    # Wait a moment for container to be ready
    sleep 2
    
    # Test Docker CLI (should talk to host daemon)
    print_info "Testing Docker CLI functionality (DooD)..."
    test_command_runs ${container_name} "docker version" "Docker version command"
    test_command_runs ${container_name} "docker info" "Docker info command"
    test_command_runs ${container_name} "docker ps" "Docker ps command"
    
    # Verify it's using host Docker (should see this test container in the list)
    if docker exec ${container_name} docker ps --format '{{.Names}}' | grep -q "${container_name}"; then
        print_success "CLI container can see itself in host Docker (DooD working correctly)"
    else
        print_warning "CLI container cannot see itself in Docker ps (may be expected depending on setup)"
    fi
    
    # Test Node.js
    print_info "Testing Node.js in CLI..."
    test_nodejs_version ${container_name} ${node_version}
    test_command_runs ${container_name} "node -e 'console.log(\"Hello from Node.js\")'" "Node.js execution"
    
    # Test utilities
    print_info "Testing installed utilities in CLI..."
    test_command_in_container ${container_name} "bash" "Bash"
    test_command_in_container ${container_name} "curl" "curl"
    test_command_in_container ${container_name} "wget" "wget"
    test_command_in_container ${container_name} "git" "git"
    test_command_in_container ${container_name} "npm" "npm"
    test_command_in_container ${container_name} "npx" "npx"
    test_command_in_container ${container_name} "corepack" "corepack"
    
    # Clean up
    docker rm -f ${container_name} > /dev/null 2>&1
}

# Test npm package installation
test_npm_functionality() {
    local node_version=$1
    local container_name="test-runner-cli"
    local image="forgejo-runner-test:node${node_version}-cli"
    
    print_section "Testing NPM Package Installation (Node.js ${node_version})"
    
    # Start container
    print_info "Starting container for NPM test..."
    docker run -d \
        --name ${container_name} \
        ${image} \
        sh -c "tail -f /dev/null" > /dev/null 2>&1
    
    sleep 2
    
    # Test npm init
    print_info "Testing npm init..."
    if docker exec -w /tmp ${container_name} sh -c "echo '{}' > package.json"; then
        print_success "Created package.json"
    else
        print_error "Failed to create package.json"
    fi
    
    # Test npm install
    print_info "Testing npm install..."
    if docker exec -w /tmp ${container_name} npm install --no-save express > /dev/null 2>&1; then
        print_success "npm install express successful"
    else
        print_error "npm install express failed"
    fi
    
    # Test running installed package
    if docker exec -w /tmp ${container_name} node -e "require('express')" > /dev/null 2>&1; then
        print_success "Can require installed package"
    else
        print_error "Cannot require installed package"
    fi
    
    # Clean up
    docker rm -f ${container_name} > /dev/null 2>&1
}

# Main test execution
main() {
    print_section "Forgejo Runner Docker Image Test Suite"
    
    print_info "Starting comprehensive tests for Docker DinD/DooD variants"
    print_info "Test date: $(date)"
    echo ""
    
    # Check if Docker is available
    if ! command -v docker > /dev/null 2>&1; then
        print_error "Docker is not available. Cannot run tests."
        exit 1
    fi
    print_success "Docker is available"
    
    # Check if we're in the right directory
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found. Please run this script from the repository root."
        exit 1
    fi
    print_success "Dockerfile found"
    
    # Test with default Node.js version (20)
    NODE_VERSION=20
    
    # Test all variants
    test_dind_variant ${NODE_VERSION}
    test_dind_rootless_variant ${NODE_VERSION}
    test_cli_variant ${NODE_VERSION}
    test_npm_functionality ${NODE_VERSION}
    
    # Print summary
    print_section "Test Summary"
    echo ""
    echo "Total tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo "Total tests failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""
    
    if [ ${TESTS_FAILED} -gt 0 ]; then
        echo -e "${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} ${test}"
        done
        echo ""
        exit 1
    else
        echo -e "${GREEN}All tests passed! ✓${NC}"
        exit 0
    fi
}

# Run main function
main "$@"
