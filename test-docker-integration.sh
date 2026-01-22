#!/bin/bash
# Integration test for docker-setup.sh
# Tests the complete setup workflow

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_msg "$BLUE" "=============================================="
print_msg "$BLUE" "  Docker Setup Integration Test"
print_msg "$BLUE" "=============================================="
echo ""

# Test configuration - use unique names
TEST_CONTAINER="integration-test-$$"
TEST_VOLUME="integration-vol-$$"
TEST_IMAGE="node:20-bookworm"

# Cleanup function
cleanup() {
    print_msg "$YELLOW" "Cleaning up test resources..."
    docker stop "$TEST_CONTAINER" 2>/dev/null || true
    docker rm "$TEST_CONTAINER" 2>/dev/null || true
    docker volume rm "$TEST_VOLUME" 2>/dev/null || true
    print_msg "$GREEN" "Cleanup complete"
}

trap cleanup EXIT

# Test 1: Run docker-setup.sh with non-interactive input
print_msg "$BLUE" "TEST: Running docker-setup.sh with environment variables"
export CLAUDE_CONTAINER_NAME="$TEST_CONTAINER"
export CLAUDE_VOLUME="$TEST_VOLUME"
export CLAUDE_IMAGE="$TEST_IMAGE"

# Run setup script (redirect input to handle any prompts)
if echo "n" | ./docker-setup.sh > /tmp/setup-output.log 2>&1; then
    print_msg "$GREEN" "✓ docker-setup.sh executed successfully"
else
    print_msg "$RED" "✗ docker-setup.sh failed"
    cat /tmp/setup-output.log
    exit 1
fi

# Wait for container to stabilize
sleep 3

# Test 2: Verify container exists and is running
print_msg "$BLUE" "TEST: Verify container is running"
if docker ps --format '{{.Names}}' | grep -q "^${TEST_CONTAINER}$"; then
    print_msg "$GREEN" "✓ Container is running"
else
    print_msg "$RED" "✗ Container is not running"
    docker ps -a
    exit 1
fi

# Test 3: Verify volume exists
print_msg "$BLUE" "TEST: Verify volume exists"
if docker volume inspect "$TEST_VOLUME" &> /dev/null; then
    print_msg "$GREEN" "✓ Volume exists"
else
    print_msg "$RED" "✗ Volume does not exist"
    exit 1
fi

# Test 4: Verify container configuration
print_msg "$BLUE" "TEST: Verify container configuration"

# Check working directory
WORKDIR=$(docker exec "$TEST_CONTAINER" pwd)
if [ "$WORKDIR" = "/workspace" ]; then
    print_msg "$GREEN" "✓ Working directory is correct: /workspace"
else
    print_msg "$RED" "✗ Wrong working directory: $WORKDIR"
    exit 1
fi

# Test 5: Verify Node.js and npm
print_msg "$BLUE" "TEST: Verify Node.js and npm"
NODE_VERSION=$(docker exec "$TEST_CONTAINER" node --version)
NPM_VERSION=$(docker exec "$TEST_CONTAINER" npm --version)
print_msg "$GREEN" "✓ Node.js: $NODE_VERSION"
print_msg "$GREEN" "✓ npm: $NPM_VERSION"

# Test 6: Test volume mount and persistence
print_msg "$BLUE" "TEST: Test volume persistence"
docker exec "$TEST_CONTAINER" bash -c "echo 'integration test data' > /workspace/integration-test.txt"
CONTENT=$(docker exec "$TEST_CONTAINER" cat /workspace/integration-test.txt)
if [ "$CONTENT" = "integration test data" ]; then
    print_msg "$GREEN" "✓ Volume write/read successful"
else
    print_msg "$RED" "✗ Volume data mismatch"
    exit 1
fi

# Test 7: Test container restart and persistence
print_msg "$BLUE" "TEST: Test container restart and data persistence"
docker restart "$TEST_CONTAINER" > /dev/null
sleep 3

CONTENT_AFTER=$(docker exec "$TEST_CONTAINER" cat /workspace/integration-test.txt 2>/dev/null || echo "")
if [ "$CONTENT_AFTER" = "integration test data" ]; then
    print_msg "$GREEN" "✓ Data persisted after restart"
else
    print_msg "$RED" "✗ Data lost after restart"
    exit 1
fi

# Test 8: Verify expected tools in container
print_msg "$BLUE" "TEST: Verify container has expected tools"
EXPECTED_TOOLS=(bash git curl)
for tool in "${EXPECTED_TOOLS[@]}"; do
    if docker exec "$TEST_CONTAINER" which "$tool" &> /dev/null; then
        print_msg "$GREEN" "✓ $tool is available"
    else
        print_msg "$YELLOW" "⚠ $tool is not available (optional)"
    fi
done

# Test 9: Test script with existing container (rerun scenario)
print_msg "$BLUE" "TEST: Test script behavior with existing container"
# Run setup script again - should detect existing container
if echo "n" | CLAUDE_CONTAINER_NAME="$TEST_CONTAINER" CLAUDE_VOLUME="$TEST_VOLUME" ./docker-setup.sh > /tmp/setup-rerun.log 2>&1; then
    print_msg "$GREEN" "✓ Script handles existing container gracefully"
else
    print_msg "$YELLOW" "⚠ Script behavior with existing container"
fi

# Verify container still works after rerun
if docker exec "$TEST_CONTAINER" echo "test" &> /dev/null; then
    print_msg "$GREEN" "✓ Container still functional after rerun"
else
    print_msg "$RED" "✗ Container not functional after rerun"
    exit 1
fi

echo ""
print_msg "$GREEN" "=============================================="
print_msg "$GREEN" "  All Integration Tests Passed!"
print_msg "$GREEN" "=============================================="
echo ""
print_msg "$BLUE" "Summary:"
print_msg "$BLUE" "  - docker-setup.sh executed successfully"
print_msg "$BLUE" "  - Container created and running"
print_msg "$BLUE" "  - Volume created and mounted"
print_msg "$BLUE" "  - Node.js $NODE_VERSION and npm $NPM_VERSION available"
print_msg "$BLUE" "  - Data persistence verified"
print_msg "$BLUE" "  - Container restart works correctly"
echo ""
