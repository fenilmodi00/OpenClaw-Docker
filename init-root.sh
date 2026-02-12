#!/bin/bash

# OpenClaw Initialization Script (ROOT MODE)
# Runs OpenClaw as ROOT user for full system access.

set -e

echo "=== OpenClaw Initialization (ROOT) ==="

# Define paths for Root
OPENCLAW_HOME="/root/.openclaw"
OPENCLAW_WORKSPACE="${WORKSPACE:-/root/.openclaw/workspace}"

# Ensure directories exist
mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_WORKSPACE"

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
        # EXISTING CONFIG VALIDATION
        # Check if critical configuration (Gateway Token) is present
        EXISTING_TOKEN=$(jq -r '.gateway.auth.token // empty' "$CONFIG_FILE")
        
        if [ -z "$EXISTING_TOKEN" ] || [ "$EXISTING_TOKEN" = "null" ]; then
             echo "⚠️ Existing configuration missing gateway token. Regenerating..."
             SHOULD_GENERATE=true
        else
             echo "✅  Existing configuration file is valid JSON."
        fi
    fi
fi

if [ "$SHOULD_GENERATE" = true ]; then
    echo "Generating configuration file using jq..."
    
    # Ensure jq is installed
    if ! command -v jq &> /dev/null; then
        echo "❌ jq is not installed but required for config generation."
        exit 1
    fi

    # Read configuration from environment variables (with defaults)
    MODEL_ID="${MODEL_ID}"
    BASE_URL="${BASE_URL}"
    API_KEY="${API_KEY}"
    API_PROTOCOL="${API_PROTOCOL:-openai-completions}"
    CONTEXT_WINDOW="${CONTEXT_WINDOW:-200000}"
    MAX_TOKENS="${MAX_TOKENS:-8192}"
    WORKSPACE="${OPENCLAW_WORKSPACE}" 
    OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-3000}"
    OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-0.0.0.0}"
    OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN}"
    
    # Telegram Configuration
    TELEGRAM_ENABLED="${TELEGRAM_ENABLED:-false}"
    TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
    
    # Generate JSON content safely with jq
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
      --arg telegram_enabled "$TELEGRAM_ENABLED" \
      --arg telegram_token "$TELEGRAM_BOT_TOKEN" \
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
        "channels": (if ($telegram_enabled == "true" and ($telegram_token | length > 0)) then {
          "telegram": {
            "botToken": $telegram_token,
            "polling": true
          }
        } else {} end),
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
          "entries": {},
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
    echo "Skipping configuration generation."
fi

echo "=== Initialization Complete ==="
echo "Model: default/$MODEL_ID"
echo "Protocol: ${API_PROTOCOL}"
echo "Running as User: $(whoami)"
echo "Home Directory: $HOME"

# Define cleanup function
cleanup() {
    echo "=== Received stop signal, shutting down ==="
    if [ -n "$GATEWAY_PID" ]; then
        kill -TERM "$GATEWAY_PID" 2>/dev/null || true
        wait "$GATEWAY_PID" 2>/dev/null || true
    fi
    exit 0
}

# Trap termination signals
trap cleanup SIGTERM SIGINT SIGQUIT

# Start OpenClaw Gateway directly as current user (ROOT)
echo "=== Starting OpenClaw Gateway ==="
openclaw gateway --verbose &
GATEWAY_PID=$!

echo "=== OpenClaw Gateway started (PID: $GATEWAY_PID) ==="
wait "$GATEWAY_PID"
EXIT_CODE=$?
echo "=== OpenClaw Gateway exited (exit code: $EXIT_CODE) ==="
exit $EXIT_CODE
