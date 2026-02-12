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

# Check if config file exists, validate, and regenerate if necessary
CONFIG_FILE="$OPENCLAW_HOME/openclaw.json"
SHOULD_GENERATE=false

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Marking for generation."
    SHOULD_GENERATE=true
else
    # Validate existing JSON to prevent usage of corrupted files
    if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "⚠️  Existing configuration file is invalid/corrupted JSON. Regenerating..."
        SHOULD_GENERATE=true
    else
        echo "✅  Existing configuration file is valid JSON."
    fi
fi

# Read configuration from environment variables (with defaults)
MODEL_ID="${MODEL_ID}"
BASE_URL="${BASE_URL}"
API_KEY="${API_KEY}"
API_PROTOCOL="${API_PROTOCOL:-openai-completions}"
CONTEXT_WINDOW="${CONTEXT_WINDOW:-200000}"
MAX_TOKENS="${MAX_TOKENS:-8192}"
WORKSPACE="${WORKSPACE}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-3000}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-0.0.0.0}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN}"

if [ "$SHOULD_GENERATE" = true ]; then
    echo "Generating configuration file using jq..."
    
    # Ensure jq is installed
    if ! command -v jq &> /dev/null; then
        echo "❌ jq is not installed but required for config generation."
        exit 1
    fi

    # Generate JSON content safely with jq
    # Using a temporary file ensures atomic write
    TEMP_CONFIG="$(mktemp)"
    
    jq -n \
      --arg model_id "$MODEL_ID" \
      --arg base_url "$BASE_URL" \
      --arg api_key "$API_KEY" \
      --arg api_protocol "$API_PROTOCOL" \
      --argjson context_window "$CONTEXT_WINDOW" \
      --argjson max_tokens "$MAX_TOKENS" \
      --arg workspace "$WORKSPACE" \
      --argjson gateway_port "$OPENCLAW_GATEWAY_PORT" \
      --arg gateway_bind "$OPENCLAW_GATEWAY_BIND" \
      --arg gateway_token "$OPENCLAW_GATEWAY_TOKEN" \
      --arg date "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")" \
      '{
        "meta": {
          "lastTouchedVersion": "2026.1.29",
          "lastTouchedAt": $date
        },
        "update": {
          "checkOnStart": false
        },
        "models": {
          "mode": "merge",
          "providers": {
            "default": {
              "baseUrl": $base_url,
              "apiKey": $api_key,
              "api": $api_protocol,
              "models": [
                {
                  "id": $model_id,
                  "name": $model_id,
                  "reasoning": false,
                  "input": ["text", "image"],
                  "cost": {
                    "input": 0,
                    "output": 0,
                    "cacheRead": 0,
                    "cacheWrite": 0
                  },
                  "contextWindow": $context_window,
                  "maxTokens": $max_tokens
                }
              ]
            }
          }
        },
        "agents": {
          "defaults": {
            "model": {
              "primary": ("default/" + $model_id)
            },
            "imageModel": {
              "primary": ("default/" + $model_id)
            },
            "workspace": $workspace,
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
          "port": $gateway_port,
          "mode": "local",
          "bind": $gateway_bind,
          "controlUi": {
            "allowInsecureAuth": true
          },
          "auth": {
            "mode": "token",
            "token": $gateway_token
          }
        },
        "plugins": {
          "entries": {
            "telegram": {
              "enabled": true
            },
            "whatsapp": {
              "enabled": true
            }
          },
          "installs": {}
        }
      }' > "$TEMP_CONFIG"

    if [ $? -eq 0 ] && jq empty "$TEMP_CONFIG" >/dev/null 2>&1; then
        mv "$TEMP_CONFIG" "$CONFIG_FILE"
        echo "✅ Configuration file successfully generated."
    else
        echo "❌ Failed to generate valid JSON configuration."
        cat "$TEMP_CONFIG"
        exit 1
    fi
else
    echo "Configuration file exists, updating gateway token if provided..."
    
    # Always update gateway token from environment variable if set
    if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
        TEMP_CONFIG="$(mktemp)"
        jq --arg token "$OPENCLAW_GATEWAY_TOKEN" '.gateway.auth.token = $token' "$CONFIG_FILE" > "$TEMP_CONFIG"
        
        if [ $? -eq 0 ] && jq empty "$TEMP_CONFIG" >/dev/null 2>&1; then
            mv "$TEMP_CONFIG" "$CONFIG_FILE"
            echo "✅ Gateway token updated in configuration."
        else
            echo "❌ Failed to update gateway token."
            rm -f "$TEMP_CONFIG"
        fi
    else
        echo "⚠️  OPENCLAW_GATEWAY_TOKEN not set, skipping token update."
    fi
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