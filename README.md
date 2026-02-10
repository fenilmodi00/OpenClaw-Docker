# OpenClaw Docker Gateway

A minimal, production-ready Docker image for running OpenClaw as an AI gateway. Supports OpenAI, Claude, and Gemini-compatible APIs with automatic configuration generation and persistent storage.

## Features

- 🚀 **Quick Start**: One-command deployment with Docker Compose
- 🔧 **Flexible Configuration**: Environment variable-based setup
- 🐳 **Docker Native**: Optimized for containerized environments
- 📦 **Data Persistence**: Configuration and workspace data persistence
- 🌐 **Multi-Provider**: OpenAI, Claude, and Gemini protocol support
- ☁️ **Cloud Ready**: Works on Docker Compose, Kubernetes, and decentralized platforms

## Quick Start

### 1. Download Configuration Files

```bash
wget https://raw.githubusercontent.com/your-repo/openclaw-docker/main/docker-compose.yml
wget https://raw.githubusercontent.com/your-repo/openclaw-docker/main/.env.example
```

### 2. Configure Environment Variables

```bash
# Copy environment template
cp .env.example .env

# Edit configuration (at minimum, configure AI model parameters)
nano .env
```

**Minimum Configuration**:

| Variable | Description | Example |
|----------|-------------|---------|
| `MODEL_ID` | AI model name | `gpt-4` |
| `BASE_URL` | AI service API endpoint | `https://api.openai.com/v1` |
| `API_KEY` | AI service API key | `sk-xxx...` |

### 3. Start Service

```bash
docker-compose up -d
```

### 4. View Logs

```bash
docker-compose logs -f
```

### 5. Stop Service

```bash
docker-compose down
```

## Configuration Guide

### AI Model Configuration

This project supports **OpenAI protocol** and **Claude protocol** API formats.

#### Basic Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `MODEL_ID` | Model name | `gpt-4` |
| `BASE_URL` | Provider base URL | `https://api.openai.com/v1` |
| `API_KEY` | Provider API key | `your-api-key-here` |
| `API_PROTOCOL` | API protocol type | `openai-completions` |
| `CONTEXT_WINDOW` | Model context window size | `200000` |
| `MAX_TOKENS` | Model max output tokens | `8192` |

#### Protocol Types

| Protocol Type | Applicable Models | Base URL Format | Special Features |
|---------------|-------------------|-----------------|------------------|
| `openai-completions` | OpenAI, Gemini, etc. | Requires `/v1` suffix | - |
| `anthropic-messages` | Claude | No `/v1` suffix needed | Prompt Caching, Extended Thinking |

#### Configuration Examples

**OpenAI Protocol (OpenAI)**

```bash
MODEL_ID=gpt-4
BASE_URL=https://api.openai.com/v1
API_KEY=sk-your-api-key
API_PROTOCOL=openai-completions
CONTEXT_WINDOW=200000
MAX_TOKENS=8192
```

**OpenAI Protocol (Gemini)**

```bash
MODEL_ID=gemini-2.0-flash-exp
BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/v1
API_KEY=your-gemini-api-key
API_PROTOCOL=openai-completions
CONTEXT_WINDOW=1000000
MAX_TOKENS=8192
```

**Claude Protocol (Claude)**

```bash
MODEL_ID=claude-3-5-sonnet-20241022
BASE_URL=https://api.anthropic.com
API_KEY=your-anthropic-api-key
API_PROTOCOL=anthropic-messages
CONTEXT_WINDOW=200000
MAX_TOKENS=8192
```

### Gateway Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `OPENCLAW_GATEWAY_TOKEN` | Gateway access token | `your-secure-token-here` |
| `OPENCLAW_GATEWAY_BIND` | Bind address | `lan` |
| `OPENCLAW_GATEWAY_PORT` | Gateway port | `18789` |
| `OPENCLAW_BRIDGE_PORT` | Bridge port | `18790` |

### Workspace Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `WORKSPACE` | Workspace directory | `/home/node/.openclaw/workspace` |

## Common Issues

### Q: Modified environment variables but configuration not taking effect?

The container only generates new configuration when the config file doesn't exist. To regenerate:

```bash
# Delete config file
rm ~/.openclaw/openclaw.json
# Restart container
docker-compose restart
```

Or delete the entire data directory to start fresh:

```bash
rm -rf ~/.openclaw
docker-compose up -d
```

### Q: Permission denied errors?

This usually occurs when the host mount directory owner (UID/GID) doesn't match the container process user.

**Quick diagnosis:**

```bash
# Check host directory ownership (Linux)
ls -ln ~/.openclaw

# Check container running user
docker run --rm openclaw-gateway:latest id
```

**Solutions (in order of preference):**

1. **Fix host directory ownership (most direct)**

```bash
sudo chown -R 1000:1000 ~/.openclaw
```

2. **Explicitly specify container running user (optional)**

In `.env`:

```bash
OPENCLAW_RUN_USER=1000:1000
```

Then restart:

```bash
docker compose up -d
```

3. **SELinux scenario (CentOS/RHEL/Fedora)**

If permissions look correct but access is still denied, add `:z` or `:Z` label to volume mounts.

## Advanced Usage

### Using Docker Command Directly

If not using Docker Compose:

```bash
docker run -d \
  --name openclaw-gateway \
  --cap-add=CHOWN \
  --cap-add=SETUID \
  --cap-add=SETGID \
  --cap-add=DAC_OVERRIDE \
  -e MODEL_ID=gpt-4 \
  -e BASE_URL=https://api.openai.com/v1 \
  -e API_KEY=your-api-key \
  -e API_PROTOCOL=openai-completions \
  -e CONTEXT_WINDOW=200000 \
  -e MAX_TOKENS=8192 \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -e OPENCLAW_GATEWAY_BIND=lan \
  -e OPENCLAW_GATEWAY_PORT=18789 \
  -v ~/.openclaw:/home/node/.openclaw \
  -p 18789:18789 \
  -p 18790:18790 \
  --restart unless-stopped \
  openclaw-gateway:latest
```

### Data Persistence

The container uses the following volumes for data persistence:

- `/home/node/.openclaw` - OpenClaw configuration and data directory
- `/home/node/.openclaw/workspace` - Workspace directory

### Port Information

- `18789` - OpenClaw Gateway port
- `18790` - OpenClaw Bridge port

### Custom Configuration File

If you need complete control over the configuration:

1. Create config file on host: `~/.openclaw/openclaw.json`
2. Mount the directory to container: `-v ~/.openclaw:/home/node/.openclaw`
3. Container will detect existing config and skip auto-generation

## Developer Information

### Project Files

- `Dockerfile` - Docker image build file
- `init.sh` - Container initialization script (runs as main process)
- `docker-compose.yml` - Docker Compose configuration
- `.env.example` - Environment variable template
- `openclaw.json.example` - OpenClaw default configuration example

### Building the Image

```bash
docker build -t openclaw-gateway:latest .
```

### Initialization Script

The `init.sh` script performs the following on container startup:

1. Creates necessary directory structure
2. Dynamically generates config file from environment variables (if not exists)
3. Sets correct file permissions
4. Starts OpenClaw Gateway service (verbose mode)

### Configuration File Generation

On first startup, if `/home/node/.openclaw/openclaw.json` doesn't exist, the init script automatically generates a configuration file based on environment variables, including:

- **Model configuration**: Uses specified model and provider
- **Gateway configuration**: Port, bind address, authentication token
- **Workspace configuration**: Persistent workspace directory

### Startup Command

The container starts OpenClaw with:

```bash
openclaw gateway --verbose
```

This starts the Gateway service in verbose logging mode.

## Notes

1. Ensure host ports 18789 and 18790 are not in use
2. Sensitive information (API keys, tokens) should be kept secure
3. On first run, necessary directories and config files are created automatically
4. Container runs as `node` user; ensure mounted volumes have correct permissions
5. When using OpenAI protocol, Base URL needs `/v1` suffix
6. When using Claude protocol, Base URL doesn't need `/v1` suffix

## License

This project is built on OpenClaw and follows the GNU General Public License v3.0 (GPL-3.0). See `LICENSE` file for details.
