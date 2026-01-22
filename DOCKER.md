# Docker Setup for Claude Code with Smart Ralph

This guide explains how to run Claude Code with Smart Ralph plugins in a Docker container.

## Quick Start

```bash
# Run the setup script
./docker-setup.sh
```

The script will:
1. Create a Docker container with Node.js 20
2. Create a named volume for persistent storage (rootless Docker compatible)
3. Provide instructions for installing Claude Code and plugins

## Prerequisites

- Docker installed and running
- For rootless Docker: Docker configured in rootless mode

## Environment Variables

You can customize the setup using environment variables:

```bash
# Custom container name
CLAUDE_CONTAINER_NAME=my-claude docker-setup.sh

# Custom Docker image
CLAUDE_IMAGE=node:20-alpine docker-setup.sh

# Custom volume name
CLAUDE_VOLUME=my-data docker-setup.sh

# Combine multiple options
CLAUDE_CONTAINER_NAME=my-claude CLAUDE_VOLUME=my-data docker-setup.sh
```

## Default Configuration

- **Container Name**: `claude-code-ralph`
- **Docker Image**: `node:20-bookworm` (Debian-based Node.js 20)
- **Volume Name**: `claude-code-data`
- **Work Directory**: `/workspace`

## Rootless Docker

This script uses **named volumes** which are fully compatible with rootless Docker. Named volumes are managed by Docker and work correctly without requiring special UID/GID mapping.

### Why Named Volumes?

- ✅ Full rootless Docker support
- ✅ Managed by Docker daemon
- ✅ No permission issues
- ✅ Persistent across container restarts
- ✅ Easy backup and migration

## Manual Setup Steps

If you prefer to set up manually:

### 1. Create Volume

```bash
docker volume create claude-code-data
```

### 2. Start Container

```bash
docker run -d \
  --name claude-code-ralph \
  --volume claude-code-data:/workspace \
  --workdir /workspace \
  --network host \
  node:20-bookworm \
  sleep infinity
```

### 3. Enter Container

```bash
docker exec -it claude-code-ralph bash
```

### 4. Install Claude Code

Inside the container, install Claude Code according to the official installation instructions.

### 5. Install Plugins

Once Claude Code is installed, run these commands:

```bash
# Install Ralph Loop dependency first
/plugin install ralph-wiggum@claude-plugins-official

# Add Smart Ralph marketplace
/plugin marketplace add tzachbon/smart-ralph

# Install Smart Ralph plugins
/plugin install ralph-specum@smart-ralph
/plugin install ralph-speckit@smart-ralph
```

## Container Management

### Access the Container

```bash
docker exec -it claude-code-ralph bash
```

### Stop the Container

```bash
docker stop claude-code-ralph
```

### Start the Container

```bash
docker start claude-code-ralph
```

### View Container Logs

```bash
docker logs claude-code-ralph
```

### Remove Container (keeps volume)

```bash
docker rm -f claude-code-ralph
```

### Remove Volume (deletes all data)

```bash
docker volume rm claude-code-data
```

## Volume Management

### List Volumes

```bash
docker volume ls
```

### Inspect Volume

```bash
docker volume inspect claude-code-data
```

### Backup Volume

```bash
# Create a backup tarball
docker run --rm \
  --volume claude-code-data:/data \
  --volume $(pwd):/backup \
  node:20-bookworm \
  tar czf /backup/claude-data-backup.tar.gz -C /data .
```

### Restore Volume

```bash
# Restore from backup
docker run --rm \
  --volume claude-code-data:/data \
  --volume $(pwd):/backup \
  node:20-bookworm \
  tar xzf /backup/claude-data-backup.tar.gz -C /data
```

## Troubleshooting

### Container Already Exists

If the container already exists, the script will prompt you to remove it or use the existing one.

### Docker Not Found

Ensure Docker is installed and in your PATH:

```bash
docker --version
```

### Permission Denied (Rootless Docker)

If using rootless Docker and encountering permission issues:

```bash
# Ensure rootless Docker is properly configured
docker context use rootless
```

### Plugin Installation Fails

Plugin installation requires an interactive Claude Code session. If the automated installation fails:

1. Enter the container: `docker exec -it claude-code-ralph bash`
2. Start Claude Code
3. Run the plugin install commands manually

## Working with Projects

### Clone a Repository into the Volume

```bash
docker exec -it claude-code-ralph bash -c "cd /workspace && git clone <repo-url>"
```

### Copy Files to Container

```bash
docker cp /local/path claude-code-ralph:/workspace/
```

### Copy Files from Container

```bash
docker cp claude-code-ralph:/workspace/file /local/path
```

## Advanced Usage

### Custom Dockerfile

If you need additional tools or configuration, create a custom Dockerfile:

```dockerfile
FROM node:20-bookworm

# Install additional tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code (if available via package manager)
# RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

CMD ["sleep", "infinity"]
```

Build and use:

```bash
docker build -t claude-code-custom .
CLAUDE_IMAGE=claude-code-custom ./docker-setup.sh
```

### Mount Additional Volumes

```bash
docker run -d \
  --name claude-code-ralph \
  --volume claude-code-data:/workspace \
  --volume /host/path:/container/path:ro \
  --workdir /workspace \
  --network host \
  node:20-bookworm \
  sleep infinity
```

### Network Configuration

The script uses `--network host` for simplicity. For more isolation:

```bash
# Create a custom network
docker network create claude-network

# Run container on custom network
docker run -d \
  --name claude-code-ralph \
  --network claude-network \
  --volume claude-code-data:/workspace \
  --workdir /workspace \
  -p 8080:8080 \
  node:20-bookworm \
  sleep infinity
```

## Testing

### Automated Tests

Run the automated test suite to verify Docker setup functionality:

```bash
# Run unit tests
./test-docker-setup.sh

# Run integration tests (tests the full docker-setup.sh workflow)
./test-docker-integration.sh
```

The **unit test suite** (`test-docker-setup.sh`) validates:
- Docker availability and daemon status
- Volume creation and management
- Container lifecycle (start, stop, restart)
- Volume persistence across restarts
- Node.js and npm availability
- Working directory configuration
- Script permissions and documentation

The **integration test suite** (`test-docker-integration.sh`) validates:
- Complete docker-setup.sh execution workflow
- Container creation with environment variables
- Volume mounting and configuration
- Data persistence across container restarts
- Tool availability (bash, git, curl)
- Script behavior with existing containers

### Manual Testing

#### Test Basic Setup

```bash
# Run the setup script
./docker-setup.sh

# Verify container is running
docker ps | grep claude-code-ralph

# Enter the container
docker exec -it claude-code-ralph bash

# Inside container - verify Node.js
node --version
npm --version

# Exit container
exit
```

#### Test Volume Persistence

```bash
# Create a test file
docker exec claude-code-ralph bash -c "echo 'test data' > /workspace/test.txt"

# Restart container
docker restart claude-code-ralph

# Verify data persists
docker exec claude-code-ralph cat /workspace/test.txt
# Should output: test data
```

#### Test Custom Configuration

```bash
# Clean up any existing test resources
docker rm -f test-claude 2>/dev/null || true
docker volume rm test-data 2>/dev/null || true

# Run with custom settings
CLAUDE_CONTAINER_NAME=test-claude \
CLAUDE_VOLUME=test-data \
CLAUDE_IMAGE=node:20-alpine \
./docker-setup.sh

# Verify custom setup
docker ps | grep test-claude
docker volume ls | grep test-data
```

### CI/CD Testing

The repository includes a GitHub Actions workflow (`.github/workflows/docker-test.yml`) that automatically tests:

- Docker setup script functionality
- Named volume creation and persistence
- Container lifecycle management
- Multiple configurations (default and custom)
- Rootless Docker compatibility
- Documentation completeness

Tests run automatically on:
- Pushes to `main` branch
- Pull requests to `main` branch
- Changes to Docker-related files

View test results in the [Actions tab](https://github.com/drseanwing/smart-ralph/actions).

## See Also

- [Smart Ralph README](README.md) - Main plugin documentation
- [Contributing Guide](CONTRIBUTING.md) - Development setup
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
