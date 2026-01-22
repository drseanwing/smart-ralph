#!/bin/bash
# Example configurations for docker-setup.sh

echo "Example 1: Default configuration"
echo "./docker-setup.sh"
echo ""

echo "Example 2: Custom container name"
echo "CLAUDE_CONTAINER_NAME=my-claude ./docker-setup.sh"
echo ""

echo "Example 3: Use Alpine Linux (smaller image)"
echo "CLAUDE_IMAGE=node:20-alpine ./docker-setup.sh"
echo ""

echo "Example 4: Custom volume name"
echo "CLAUDE_VOLUME=my-claude-data ./docker-setup.sh"
echo ""

echo "Example 5: All custom settings"
echo "CLAUDE_CONTAINER_NAME=dev-claude CLAUDE_IMAGE=node:20-alpine CLAUDE_VOLUME=dev-data ./docker-setup.sh"
echo ""

echo "After setup, connect to the container:"
echo "docker exec -it claude-code-ralph bash"
echo ""

echo "For rootless Docker users:"
echo "The script uses named volumes which work perfectly with rootless Docker."
echo "No special configuration needed!"
