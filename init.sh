#!/bin/bash

set -e

echo "=== OpenClaw Initialization ==="

OPENCLAW_HOME="/home/node/.openclaw"
OPENCLAW_WORKSPACE="${WORKSPACE:-/home/node/.openclaw/workspace}"
NODE_UID="$(id -u node)"
NODE_GID="$(id -g node)"

# Create necessary directories
mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_WORKSPACE"

# Pre-check mount volume permissions
if [ "$(id -u)" -eq 0 ]; then
    CURRENT_OWNER="$(stat -c '%u:%g' "$OPENCLAW_HOME" 2>/dev/null || echo unknown:unknown)"
    echo "Mount directory: $OPENCLAW_HOME"
    echo "Current owner (UID:GID): $CURRENT_OWNER"
    echo "Target owner (UID:GID): ${NODE_UID}:${NODE_GID}"

    if [ "$CURRENT_OWNER" != "${NODE_UID}:${NODE_GID}" ]; then
        echo "Detected ownership mismatch, attempting to fix..."
        chown -R node:node "$OPENCLAW_HOME" || true
    fi

    # Verify write permissions
    if ! gosu node test -w "$OPENCLAW_HOME"; then
        echo "❌ Permission check failed: node user cannot write to $OPENCLAW_HOME"
        echo "Please run on host (Linux):"
        echo "  sudo chown -R ${NODE_UID}:${NODE_GID} <your-openclaw-data-dir>"
        echo "Or specify user at startup:"
        echo "  docker run --user \$(id -u):\$(id -g) ..."
        echo "If SELinux is enabled, add :z or :Z to volume mount"
        exit 1
    fi
fi

# Check if config file exists, generate if not
if [ ! -f /home/node/.openclaw/openclaw.json ]; then
    echo "Generating configuration file..."
    
    # Read configuration from environment variables
    MODEL_ID="${MODEL_ID}"
    BASE_URL="${BASE_URL}"
    API_KEY="${API_KEY}"
    API_PROTOCOL="${API_PROTOCOL:-openai-completions}"
    CONTEXT_WINDOW="${CONTEXT_WINDOW:-200000}"
    MAX_TOKENS="${MAX_TOKENS:-8192}"
    WORKSPACE="${WORKSPACE}"
    OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT}"
    OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND}"
    OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN}"
    
    # Generate configuration file
    cat > /home/node/.openclaw/openclaw.json <<EOF
{
  "meta": {
    "lastTouchedVersion": "2026.1.29",
    "lastTouchedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
  },
  "update": {
    "checkOnStart": false
  },
  "models": {
    "mode": "merge",
    "providers": {
      "default": {
        "baseUrl": "$BASE_URL",
        "apiKey": "$API_KEY",
        "api": "$API_PROTOCOL",
        "models": [
          {
            "id": "$MODEL_ID",
            "name": "$MODEL_ID",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": $CONTEXT_WINDOW,
            "maxTokens": $MAX_TOKENS
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "default/$MODEL_ID"
      },
      "imageModel": {
        "primary": "default/$MODEL_ID"
      },
      "workspace": "$WORKSPACE",
      "compaction": {
        "mode": "safeguard"
      },
      "elevatedDefault": "full",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "channels": {},
  "gateway": {
    "port": $OPENCLAW_GATEWAY_PORT,
    "mode": "local",
    "bind": "$OPENCLAW_GATEWAY_BIND",
    "controlUi": {
      "allowInsecureAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "$OPENCLAW_GATEWAY_TOKEN"
    }
  },
  "plugins": {
    "entries": {},
    "installs": {}
  }
}
EOF

    echo "✅ Configuration file generated"
else
    echo "Configuration file exists, skipping generation"
fi

# Ensure correct permissions (root only)
if [ "$(id -u)" -eq 0 ]; then
    chown -R node:node "$OPENCLAW_HOME" || true
fi

echo "=== Initialization Complete ==="
echo "Model: default/$MODEL_ID"
echo "API Protocol: ${API_PROTOCOL:-openai-completions}"
echo "Base URL: ${BASE_URL}"
echo "Context Window: ${CONTEXT_WINDOW:-200000}"
echo "Max Tokens: ${MAX_TOKENS:-8192}"
echo "Gateway Port: $OPENCLAW_GATEWAY_PORT"
echo "Gateway Bind: $OPENCLAW_GATEWAY_BIND"

# Start OpenClaw Gateway (switch to node user)
echo "=== Starting OpenClaw Gateway ==="

# Define cleanup function
cleanup() {
    echo "=== Received stop signal, shutting down ==="
    if [ -n "$GATEWAY_PID" ]; then
        kill -TERM "$GATEWAY_PID" 2>/dev/null || true
        wait "$GATEWAY_PID" 2>/dev/null || true
    fi
    echo "=== Service stopped ==="
    exit 0
}

# Trap termination signals
trap cleanup SIGTERM SIGINT SIGQUIT

# Start OpenClaw Gateway in background as subprocess
gosu node env HOME=/home/node openclaw gateway --verbose &
GATEWAY_PID=$!

echo "=== OpenClaw Gateway started (PID: $GATEWAY_PID) ==="

# Main process waits for subprocess
wait "$GATEWAY_PID"
EXIT_CODE=$?

echo "=== OpenClaw Gateway exited (exit code: $EXIT_CODE) ==="
exit $EXIT_CODE
