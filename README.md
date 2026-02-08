# Dev Sandbox

Full-stack development environment based on **Microsoft DevContainers Universal** image, with integrated Claude Code Wrapper (Anthropic Messages API).

## Service Info

| Item | Value |
|------|-------|
| Base Image | `mcr.microsoft.com/devcontainers/universal:2-linux` |
| Service | dev-sandbox |
| Port | 8790 |
| Endpoint | `http://localhost:8790/v1/messages` |
| API Key | Set via `INTERNAL_API_KEY` in `.env` |
| Workspace | VS Code auto-mounts to `/workspaces/<project-name>` |
| AI Configs | `./config/` → `~/.claude`, `~/.codex`, `~/.gemini` |
| Docker | Docker-in-Docker (isolated, privileged mode) |

## Features

### Development Environment (DevContainers Universal)
- **Python 3.12** + pip, pipx, uv
- **Node.js 22** + npm, yarn, pnpm
- **Go 1.24**
- **Java 21** + Maven, Gradle
- **Rust** + cargo
- **.NET, PHP, Ruby** (additional languages)
- **Docker Engine** (Docker-in-Docker, isolated from host)
- **GitHub CLI, Azure CLI**

### Additional Tools
- ripgrep, fd, bat, fzf
- tmux, htop, tree, jq
- Database clients: psql, redis-cli

### Claude Code Wrapper
- Anthropic Messages API on port 8790
- All Claude tools enabled by default (Bash, Read, Write, Edit, etc.)
- MCP server support via `~/.claude.json`
- Session management with resume capability
- Configuration persistence via bind mounts

### Available Models

| Model ID | Description |
|----------|-------------|
| `claude-code` | Default (uses Claude's default model) |
| `claude-code-opus` | Routes to Opus |
| `claude-code-sonnet` | Routes to Sonnet |
| `claude-code-haiku` | Routes to Haiku |

## Directory Structure

```
dev-sandbox/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── .env
├── .devcontainer/
│   └── devcontainer.json
├── claude-code-wrapper/        # Claude Code Wrapper (git submodule)
│   ├── src/
│   └── requirements.txt
└── config/                     # AI tools config (bind mount)
    ├── .claude/                # Claude Code config
    ├── .claude.json            # MCP server config
    ├── .codex/                 # Codex config
    └── .gemini/                # Gemini config
```

## Quick Start

### Use as DevContainer

1. Open VS Code
2. Install "Dev Containers" extension
3. Open your project folder
4. Copy `.devcontainer/` directory to the project root
5. Click "Reopen in Container"

### Standalone Mode

Create a `docker-compose.yml`:

```yaml
services:
  dev-sandbox:
    image: ghcr.io/farewellsagittarius/dev-sandbox:latest
    container_name: dev-sandbox
    hostname: dev-sandbox
    restart: unless-stopped

    ports:
      - "8790:8790"  # Claude Code Wrapper (Anthropic Messages API)
      - "2222:22"    # SSH

    environment:
      - TZ=UTC
      - INTERNAL_API_KEY=${INTERNAL_API_KEY:-sk-internal-dev}
      - LOAD_USER_MCP=true
      - DEBUG_MODE=${DEBUG_MODE:-false}
      - CLAUDE_CWD=/home/codespace

    volumes:
      - ./config/.claude:/home/codespace/.claude
      - ./config/.claude.json:/home/codespace/.claude.json
      - ~/.claude/.credentials.json:/home/codespace/.claude/.credentials.json
      - ./config/.codex:/home/codespace/.codex
      - ./config/.gemini:/home/codespace/.gemini
      - ./config/.ssh:/home/codespace/.ssh
      - ~/.gitconfig:/home/codespace/.gitconfig:ro

    privileged: true

    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 2G

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8790/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
```

Then start:

```bash
docker compose up -d
```

## Usage

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/v1/models` | List available models |
| POST | `/v1/messages` | Create a message (Anthropic Messages API format) |
| GET | `/v1/sessions` | List active sessions |
| GET | `/v1/sessions/{id}` | Get session details |
| DELETE | `/v1/sessions/{id}` | Delete a session |

### Using curl

```bash
# Health check
curl http://localhost:8790/health

# List models
curl -H "x-api-key: $INTERNAL_API_KEY" http://localhost:8790/v1/models

# Send a message
curl -X POST http://localhost:8790/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $INTERNAL_API_KEY" \
  -d '{
    "model": "claude-code",
    "max_tokens": 4096,
    "messages": [{"role": "user", "content": "Hello from sandbox!"}]
  }'
```

### Using Anthropic Python SDK

```python
import anthropic

client = anthropic.Anthropic(
    base_url="http://localhost:8790/v1",
    api_key="<your INTERNAL_API_KEY>"
)

response = client.messages.create(
    model="claude-code",
    max_tokens=4096,
    messages=[{"role": "user", "content": "Hello from sandbox!"}]
)
print(response.content[0].text)
```

### Enter container shell

```bash
docker exec -it dev-sandbox bash
```

## Configuration

### Environment Variables (.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `INTERNAL_API_KEY` | API key for wrapper auth | `sk-internal-dev` |
| `DEBUG_MODE` | Enable debug logging | `false` |
| `LOAD_USER_MCP` | Load MCP servers from `~/.claude.json` | `true` |
| `TOOLS` | Comma-separated tool list (unset = all tools) | *(all)* |
| `CLAUDE_CWD` | Working directory inside container | `/home/codespace` |

### Volume Mounts

| Type | Mount | Purpose |
|------|-------|---------|
| bind | `./config/.claude` | Claude Code config |
| bind | `./config/.claude.json` | MCP server config |
| bind | `~/.claude/.credentials.json` | Claude credentials (read-write for token refresh) |
| bind | `./config/.codex` | Codex config |
| bind | `./config/.gemini` | Gemini config |
| bind | `./config/.ssh` | SSH authorized_keys |
| bind | `~/.gitconfig` (ro) | Git global config |

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                    Host Machine                       │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │           dev-sandbox container                 │  │
│  │           (DevContainers Universal)             │  │
│  │                                                 │  │
│  │  ┌──────────────────┐  ┌─────────────────────┐  │  │
│  │  │ Claude Code      │  │ Dev Environment     │  │  │
│  │  │ Wrapper :8790    │  │ Python/Node/Go/     │  │  │
│  │  │                  │  │ Rust/Java/.NET/     │  │  │
│  │  │ Anthropic        │  │ PHP/Ruby            │  │  │
│  │  │ Messages API     │  │ Docker Engine (DinD) │  │  │
│  │  └──────────────────┘  └─────────────────────┘  │  │
│  │                                                 │  │
│  │  SSH server :22                                 │  │
│  │  ~/.claude ◄──── ./config/.claude (bind)        │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  Ports: 8790 (API), 2222→22 (SSH)                     │
└──────────────────────────────────────────────────────┘
```

## Service Management

```bash
docker compose up -d        # Start
docker compose down         # Stop
docker compose restart      # Restart
docker compose logs -f      # View logs
docker compose pull         # Pull latest image
```

## Migration

```bash
# Backup AI configs (bind mount)
tar -czvf config_backup.tar.gz config/

# Restore
tar -xzvf config_backup.tar.gz
```

## Files

| File | Description |
|------|-------------|
| `Dockerfile` | Container image (based on DevContainers) |
| `docker-compose.yml` | Service configuration |
| `entrypoint.sh` | Container startup script |
| `.devcontainer/devcontainer.json` | VS Code DevContainer config |
| `claude-code-wrapper/` | Claude Code Wrapper source (git submodule) |
| `config/` | AI tools configuration (persistent bind mount) |
