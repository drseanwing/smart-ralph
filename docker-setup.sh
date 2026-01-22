#!/bin/bash
set -euo pipefail

# Docker Setup Script for Claude Code with Smart Ralph Plugins
# This script starts a Docker container suitable for running Claude Code
# and installs the necessary Ralph plugins.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONTAINER_NAME="${CLAUDE_CONTAINER_NAME:-claude-code-ralph}"
IMAGE_NAME="${CLAUDE_IMAGE:-node:20-bookworm}"
VOLUME_NAME="${CLAUDE_VOLUME:-claude-code-data}"
WORK_DIR="/workspace"

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_msg "$BLUE" "==============================================="
print_msg "$BLUE" "  Claude Code + Smart Ralph Docker Setup"
print_msg "$BLUE" "==============================================="
echo

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_msg "$RED" "ERROR: Docker is not installed or not in PATH"
    print_msg "$YELLOW" "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

print_msg "$GREEN" "✓ Docker found"

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_msg "$YELLOW" "Container '$CONTAINER_NAME' already exists."
    read -p "Do you want to remove it and start fresh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_msg "$YELLOW" "Stopping and removing existing container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        print_msg "$GREEN" "✓ Container removed"
    else
        print_msg "$YELLOW" "Using existing container..."
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            print_msg "$YELLOW" "Starting existing container..."
            docker start "$CONTAINER_NAME"
        fi
        EXISTING_CONTAINER=true
    fi
fi

# Create named volume if it doesn't exist
if ! docker volume inspect "$VOLUME_NAME" &> /dev/null; then
    print_msg "$YELLOW" "Creating named volume: $VOLUME_NAME"
    docker volume create "$VOLUME_NAME"
    print_msg "$GREEN" "✓ Volume created"
else
    print_msg "$GREEN" "✓ Volume '$VOLUME_NAME' already exists"
fi

# Start container if not using existing one
if [ "${EXISTING_CONTAINER:-false}" != "true" ]; then
    print_msg "$YELLOW" "Starting Docker container..."
    print_msg "$BLUE" "  Container name: $CONTAINER_NAME"
    print_msg "$BLUE" "  Image: $IMAGE_NAME"
    print_msg "$BLUE" "  Volume: $VOLUME_NAME"
    print_msg "$BLUE" "  Work directory: $WORK_DIR"
    echo

    # Start container with named volume
    # Using named volumes for rootless Docker compatibility
    # Note: Using --network host for simplicity. For better isolation, consider:
    #   removing --network host and adding -p 8080:8080 or other specific port mappings
    docker run -d \
        --name "$CONTAINER_NAME" \
        --volume "$VOLUME_NAME:$WORK_DIR" \
        --workdir "$WORK_DIR" \
        --network host \
        "$IMAGE_NAME" \
        sleep infinity

    print_msg "$GREEN" "✓ Container started successfully"
fi

# Wait a moment for container to be ready
sleep 2

# Check if Claude Code is available in container
print_msg "$YELLOW" "Checking for Claude Code installation..."
if docker exec "$CONTAINER_NAME" bash -c "command -v claude" &> /dev/null; then
    print_msg "$GREEN" "✓ Claude Code is already installed"
else
    print_msg "$YELLOW" "Claude Code not found in container."
    print_msg "$YELLOW" "Please install Claude Code inside the container manually."
    print_msg "$BLUE" "You can enter the container with:"
    print_msg "$BLUE" "  docker exec -it $CONTAINER_NAME bash"
    print_msg "$BLUE" "Then follow Claude Code installation instructions."
    echo
    print_msg "$YELLOW" "This script will continue with plugin installation assuming Claude Code will be available..."
fi

# Function to run command in container
run_in_container() {
    docker exec -i "$CONTAINER_NAME" bash -c "$@"
}

# Install Ralph Loop plugin (ralph-wiggum)
print_msg "$YELLOW" "Installing Ralph Loop plugin (ralph-wiggum)..."
print_msg "$BLUE" "  This is the core execution loop dependency"

# Note: Plugin installation requires Claude Code CLI to be available
# and typically needs to be run interactively. The script provides
# installation commands for manual execution.

# Create a secure temporary file for the installation script
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
#!/bin/bash
set -e

echo "Checking for Claude Code CLI..."
if command -v claude &> /dev/null; then
    echo "Claude Code found!"
    echo ""
    echo "NOTE: Plugin installation typically requires an interactive session."
    echo "Please run these commands manually in Claude Code:"
    echo ""
    echo "  /plugin install ralph-wiggum@claude-plugins-official"
    echo "  /plugin marketplace add tzachbon/smart-ralph"
    echo "  /plugin install ralph-specum@smart-ralph"
    echo "  /plugin install ralph-speckit@smart-ralph"
else
    echo "Claude Code CLI not available yet."
    echo ""
    echo "After installing Claude Code, run these commands:"
    echo "  /plugin install ralph-wiggum@claude-plugins-official"
    echo "  /plugin marketplace add tzachbon/smart-ralph"
    echo "  /plugin install ralph-specum@smart-ralph"
    echo "  /plugin install ralph-speckit@smart-ralph"
fi
EOF

chmod +x "$TEMP_SCRIPT"
docker cp "$TEMP_SCRIPT" "$CONTAINER_NAME:/tmp/install_plugins.sh"
run_in_container "/tmp/install_plugins.sh" || print_msg "$YELLOW" "Plugin installation requires interactive Claude Code session"

# Clean up temporary file
rm -f "$TEMP_SCRIPT"

echo
print_msg "$GREEN" "==============================================="
print_msg "$GREEN" "  Setup Complete!"
print_msg "$GREEN" "==============================================="
echo
print_msg "$BLUE" "Container Information:"
print_msg "$BLUE" "  Name: $CONTAINER_NAME"
print_msg "$BLUE" "  Volume: $VOLUME_NAME"
print_msg "$BLUE" "  Work Directory: $WORK_DIR"
echo
print_msg "$BLUE" "To access the container:"
print_msg "$GREEN" "  docker exec -it $CONTAINER_NAME bash"
echo
print_msg "$BLUE" "After Claude Code is installed, run these commands:"
print_msg "$GREEN" "  /plugin install ralph-wiggum@claude-plugins-official"
print_msg "$GREEN" "  /plugin marketplace add tzachbon/smart-ralph"
print_msg "$GREEN" "  /plugin install ralph-specum@smart-ralph"
print_msg "$GREEN" "  /plugin install ralph-speckit@smart-ralph"
echo
print_msg "$BLUE" "To stop the container:"
print_msg "$GREEN" "  docker stop $CONTAINER_NAME"
echo
print_msg "$BLUE" "To start the container again:"
print_msg "$GREEN" "  docker start $CONTAINER_NAME"
echo
print_msg "$BLUE" "To remove the container (keeps volume):"
print_msg "$GREEN" "  docker rm -f $CONTAINER_NAME"
echo
print_msg "$BLUE" "To remove the volume (deletes all data):"
print_msg "$GREEN" "  docker volume rm $VOLUME_NAME"
echo
