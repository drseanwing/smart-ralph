#!/bin/bash
# Test script for docker-setup.sh
# Validates the Docker container setup for Claude Code with Smart Ralph plugins

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test configuration
TEST_CONTAINER_NAME="test-claude-ralph-$$"
TEST_VOLUME_NAME="test-claude-data-$$"
TEST_IMAGE="node:20-bookworm"

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print test header
print_test() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo ""
    print_msg "$BLUE" "TEST $TESTS_TOTAL: $1"
}

# Mark test as passed
test_passed() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    print_msg "$GREEN" "✓ PASS: $1"
}

# Mark test as failed
test_failed() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    print_msg "$RED" "✗ FAIL: $1"
}

# Cleanup function
cleanup() {
    print_msg "$YELLOW" "Cleaning up test resources..."
    docker stop "$TEST_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$TEST_CONTAINER_NAME" 2>/dev/null || true
    docker volume rm "$TEST_VOLUME_NAME" 2>/dev/null || true
    print_msg "$GREEN" "Cleanup complete"
}

# Set up trap for cleanup
trap cleanup EXIT

print_msg "$BLUE" "=============================================="
print_msg "$BLUE" "  Docker Setup Test Suite"
print_msg "$BLUE" "=============================================="
echo ""

# Test 1: Check if Docker is available
print_test "Check Docker availability"
if command -v docker &> /dev/null; then
    test_passed "Docker command found"
else
    test_failed "Docker command not found"
    exit 1
fi

# Test 2: Check if Docker daemon is running
print_test "Check Docker daemon status"
if docker info &> /dev/null; then
    test_passed "Docker daemon is running"
else
    test_failed "Docker daemon is not running"
    exit 1
fi

# Test 3: Create named volume
print_test "Create named volume"
if docker volume create "$TEST_VOLUME_NAME" &> /dev/null; then
    test_passed "Volume created successfully"
else
    test_failed "Failed to create volume"
fi

# Test 4: Verify volume exists
print_test "Verify volume exists"
if docker volume inspect "$TEST_VOLUME_NAME" &> /dev/null; then
    test_passed "Volume exists and is inspectable"
else
    test_failed "Volume does not exist"
fi

# Test 5: Start container with named volume
print_test "Start container with named volume"
if docker run -d \
    --name "$TEST_CONTAINER_NAME" \
    --volume "$TEST_VOLUME_NAME:/workspace" \
    --workdir /workspace \
    "$TEST_IMAGE" \
    sleep 300 &> /dev/null; then
    test_passed "Container started successfully"
else
    test_failed "Failed to start container"
fi

# Test 6: Verify container is running
print_test "Verify container is running"
if docker ps --format '{{.Names}}' | grep -q "^${TEST_CONTAINER_NAME}$"; then
    test_passed "Container is running"
else
    test_failed "Container is not running"
fi

# Test 7: Verify container can execute commands
print_test "Execute command in container"
if docker exec "$TEST_CONTAINER_NAME" echo "test" &> /dev/null; then
    test_passed "Command executed successfully"
else
    test_failed "Failed to execute command"
fi

# Test 8: Test volume persistence - write file
print_test "Test volume persistence (write)"
if docker exec "$TEST_CONTAINER_NAME" bash -c "echo 'test data' > /workspace/test.txt"; then
    test_passed "File written to volume"
else
    test_failed "Failed to write file to volume"
fi

# Test 9: Test volume persistence - read file
print_test "Test volume persistence (read)"
CONTENT=$(docker exec "$TEST_CONTAINER_NAME" cat /workspace/test.txt 2>/dev/null || echo "")
if [ "$CONTENT" = "test data" ]; then
    test_passed "File read from volume successfully"
else
    test_failed "Failed to read file from volume or content mismatch"
fi

# Test 10: Test Node.js is available
print_test "Check Node.js availability"
if docker exec "$TEST_CONTAINER_NAME" node --version &> /dev/null; then
    NODE_VERSION=$(docker exec "$TEST_CONTAINER_NAME" node --version)
    test_passed "Node.js is available: $NODE_VERSION"
else
    test_failed "Node.js is not available"
fi

# Test 11: Test npm is available
print_test "Check npm availability"
if docker exec "$TEST_CONTAINER_NAME" npm --version &> /dev/null; then
    NPM_VERSION=$(docker exec "$TEST_CONTAINER_NAME" npm --version)
    test_passed "npm is available: $NPM_VERSION"
else
    test_failed "npm is not available"
fi

# Test 12: Test workdir is correctly set
print_test "Verify working directory"
WORKDIR=$(docker exec "$TEST_CONTAINER_NAME" pwd)
if [ "$WORKDIR" = "/workspace" ]; then
    test_passed "Working directory is /workspace"
else
    test_failed "Working directory is $WORKDIR, expected /workspace"
fi

# Test 13: Test container stop
print_test "Stop container"
if docker stop "$TEST_CONTAINER_NAME" &> /dev/null; then
    test_passed "Container stopped successfully"
else
    test_failed "Failed to stop container"
fi

# Test 14: Test container restart
print_test "Restart container"
if docker start "$TEST_CONTAINER_NAME" &> /dev/null; then
    # Wait for container to be ready
    sleep 2
    test_passed "Container restarted successfully"
else
    test_failed "Failed to restart container"
fi

# Test 15: Verify volume persists after restart
print_test "Verify volume persistence after restart"
CONTENT_AFTER_RESTART=$(docker exec "$TEST_CONTAINER_NAME" cat /workspace/test.txt 2>/dev/null || echo "")
if [ "$CONTENT_AFTER_RESTART" = "test data" ]; then
    test_passed "Volume data persisted after restart"
else
    test_failed "Volume data lost after restart"
fi

# Test 16: Test docker-setup.sh script exists and is executable
print_test "Check docker-setup.sh script"
if [ -x "./docker-setup.sh" ]; then
    test_passed "docker-setup.sh is executable"
elif [ -f "./docker-setup.sh" ]; then
    test_failed "docker-setup.sh exists but is not executable"
else
    test_failed "docker-setup.sh does not exist"
fi

# Test 17: Test docker-examples.sh script exists and is executable
print_test "Check docker-examples.sh script"
if [ -x "./docker-examples.sh" ]; then
    test_passed "docker-examples.sh is executable"
elif [ -f "./docker-examples.sh" ]; then
    test_failed "docker-examples.sh exists but is not executable"
else
    test_failed "docker-examples.sh does not exist"
fi

# Test 18: Verify DOCKER.md documentation exists
print_test "Check DOCKER.md documentation"
if [ -f "./DOCKER.md" ]; then
    test_passed "DOCKER.md exists"
else
    test_failed "DOCKER.md does not exist"
fi

# Test 19: Verify DOCKER.md contains essential sections
print_test "Verify DOCKER.md content"
REQUIRED_SECTIONS=("Quick Start" "Prerequisites" "Environment Variables" "Container Management" "Volume Management")
ALL_SECTIONS_FOUND=true
for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "$section" ./DOCKER.md; then
        print_msg "$RED" "  Missing section: $section"
        ALL_SECTIONS_FOUND=false
    fi
done
if [ "$ALL_SECTIONS_FOUND" = true ]; then
    test_passed "All required sections found in DOCKER.md"
else
    test_failed "Some required sections missing in DOCKER.md"
fi

# Print summary
echo ""
print_msg "$BLUE" "=============================================="
print_msg "$BLUE" "  Test Summary"
print_msg "$BLUE" "=============================================="
echo ""
print_msg "$BLUE" "Total tests: $TESTS_TOTAL"
print_msg "$GREEN" "Passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    print_msg "$RED" "Failed: $TESTS_FAILED"
else
    print_msg "$GREEN" "Failed: $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    print_msg "$GREEN" "✓ All tests passed!"
    exit 0
else
    print_msg "$RED" "✗ Some tests failed"
    exit 1
fi
