# Contributing to Testing

This guide explains how to add new tests or modify existing ones.

## Test Structure

### Main Test Suite (`test.sh`)

The comprehensive test suite is organized into functions:

1. **Helper Functions**
   - `print_*()` - Output formatting
   - `cleanup()` - Resource cleanup
   - `test_command_in_container()` - Check if command exists
   - `test_command_runs()` - Check if command executes successfully
   - `test_nodejs_version()` - Verify Node.js version

2. **Build Functions**
   - `build_test_image()` - Build Docker image with specific parameters

3. **Variant Test Functions**
   - `test_dind_variant()` - Tests for standard DinD
   - `test_dind_rootless_variant()` - Tests for rootless DinD
   - `test_cli_variant()` - Tests for CLI/DooD
   - `test_npm_functionality()` - Tests for npm package management

## Adding a New Test

### Example: Adding a Git Test

```bash
# Add this function to test.sh
test_git_functionality() {
    local node_version=$1
    local container_name="test-runner-cli"
    local image="forgejo-runner-test:node${node_version}-cli"
    
    print_section "Testing Git Functionality (Node.js ${node_version})"
    
    # Start container
    docker run -d \
        --name ${container_name} \
        ${image} \
        sh -c "tail -f /dev/null" > /dev/null 2>&1
    
    sleep 2
    
    # Test git commands
    test_command_runs ${container_name} "git --version" "Git version"
    test_command_runs ${container_name} "git config --global user.name 'Test User'" "Git config"
    
    # Test git operations
    print_info "Testing git operations..."
    if docker exec -w /tmp ${container_name} sh -c "
        git init test-repo &&
        cd test-repo &&
        echo 'test' > README.md &&
        git add . &&
        git commit -m 'Initial commit'
    " > /dev/null 2>&1; then
        print_success "Git operations successful"
    else
        print_error "Git operations failed"
    fi
    
    # Clean up
    docker rm -f ${container_name} > /dev/null 2>&1
}

# Add call to main() function
main() {
    # ... existing code ...
    
    # Add your new test
    test_git_functionality ${NODE_VERSION}
    
    # ... rest of code ...
}
```

### Example: Adding a Curl Test

```bash
test_curl_functionality() {
    local container_name=$1
    
    print_info "Testing curl connectivity..."
    
    # Test HTTP request
    if docker exec ${container_name} curl -f -s https://example.com > /dev/null 2>&1; then
        print_success "curl can make HTTP requests"
    else
        print_error "curl HTTP request failed"
    fi
    
    # Test with JSON output
    if docker exec ${container_name} curl -s https://api.github.com | \
       docker exec -i ${container_name} jq -e '.current_user_url' > /dev/null 2>&1; then
        print_success "curl + jq pipeline works"
    else
        print_error "curl + jq pipeline failed"
    fi
}
```

## Adding Tests to CI/CD

To add a new test job to the GitHub Actions workflow:

```yaml
# .github/workflows/test.yml

jobs:
  # ... existing jobs ...
  
  test-git-functionality:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Build test image
        run: |
          docker build \
            --build-arg NODE_VERSION=20 \
            --build-arg DOCKER_VARIANT=cli \
            -t test-image:node20-cli \
            .
      
      - name: Test Git functionality
        run: |
          docker run -d --name test-runner test-image:node20-cli sh -c "tail -f /dev/null"
          sleep 2
          
          # Your tests here
          docker exec test-runner git --version
          docker exec test-runner git config --global user.name "Test"
          
          # Cleanup
          docker rm -f test-runner
```

## Testing Best Practices

### 1. Always Clean Up

```bash
# Use trap to ensure cleanup happens
cleanup() {
    docker rm -f test-container 2>/dev/null || true
    docker rmi -f test-image 2>/dev/null || true
}
trap cleanup EXIT
```

### 2. Wait for Services

```bash
# Wait for Docker daemon in DinD
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec container docker info > /dev/null 2>&1; then
        break
    fi
    sleep 1
    attempt=$((attempt + 1))
done
```

### 3. Check Exit Codes

```bash
# Good
if docker exec container command; then
    print_success "Command succeeded"
else
    print_error "Command failed"
    return 1
fi

# Also good - exit on error
set -e
docker exec container command
print_success "Command succeeded"
```

### 4. Capture Output for Debugging

```bash
# Save output for debugging
output=$(docker exec container command 2>&1) || {
    print_error "Command failed"
    echo "Output: ${output}"
    return 1
}
```

### 5. Test Multiple Scenarios

```bash
# Test success case
test_command_runs container "npm install express" "npm install package"

# Test failure case (should fail gracefully)
if docker exec container npm install nonexistent-package-xyz > /dev/null 2>&1; then
    print_warning "Expected npm install to fail for nonexistent package"
else
    print_success "npm correctly failed for nonexistent package"
fi
```

## Variant-Specific Considerations

### DinD Tests
- Always use `--privileged` flag
- Wait for Docker daemon to start (5-10 seconds)
- Test that containers can be run inside
- Check that docker info works

### DinD Rootless Tests
- Use all required flags: `--security-opt`, `--device`, `--tmpfs`
- Verify running as non-root: `docker exec container id -u`
- May need longer startup time
- Test unprivileged operations

### CLI/DooD Tests
- Mount Docker socket: `-v /var/run/docker.sock:/var/run/docker.sock`
- Verify can see host containers
- Test that operations affect host Docker
- Be careful with cleanup (affects host)

## Debugging Failed Tests

### Check Container Logs
```bash
docker logs container-name
docker logs --tail 100 container-name
```

### Enter Container Interactively
```bash
docker exec -it container-name bash
```

### Check Docker Status
```bash
# For DinD variants
docker exec container-name docker info
docker exec container-name ps aux
```

### Review Build Logs
```bash
# Build logs are saved to /tmp
cat /tmp/build-*.log
```

## Test Matrix

When adding tests, consider testing across:
- Node.js versions: 18, 20, 22
- Docker variants: dind, dind-rootless, cli
- Operating systems: Linux (Ubuntu in CI)
- Architectures: amd64 (primary), arm64 (future)

## Performance Considerations

- Keep tests fast (< 5 minutes total)
- Run tests in parallel when possible
- Use Docker layer caching
- Clean up resources promptly

## Documentation

When adding new tests, also update:
- `TESTING.md` - If adding new test categories
- `TEST_RESULTS.md` - Expected outcomes
- `README.md` - If user-visible changes
- This file (`CONTRIBUTING_TESTS.md`) - Testing patterns
