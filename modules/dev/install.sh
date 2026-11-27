#!/usr/bin/env bash
# ============================================================
# install.sh — Setup OpenCode + Bedrock Mantle Proxy (Linux/WSL/macOS)
# ============================================================

set -uo pipefail

_info() { echo -e "\033[0;34m[INSTALL]\033[0m $*"; }
_ok()   { echo -e "\033[0;32m[INSTALL] ✓\033[0m $*"; }
_warn() { echo -e "\033[0;33m[INSTALL] ⚠\033[0m $*"; }
_err()  { echo -e "\033[0;31m[INSTALL] ✗\033[0m $*" >&2; }

_info "Setting up OpenCode + Bedrock Mantle Proxy..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_DIR="${HOME}/.aws"
CONFIG_DIR="${HOME}/.config/opencode"

mkdir -p "${AWS_DIR}" "${CONFIG_DIR}"

PYTHON_BIN=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        PYTHON_BIN="$cmd"
        break
    fi
done

if [[ -z "$PYTHON_BIN" ]]; then
    _err "Python is not installed. Please install Python 3.9+."
    exit 1
fi
_ok "Using Python: $PYTHON_BIN"

MISSING=()
for pkg in fastapi uvicorn httpx botocore requests; do
    if ! "$PYTHON_BIN" -c "import $pkg" 2>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    _warn "Installing required Python packages: ${MISSING[*]}..."
    "$PYTHON_BIN" -m pip install --quiet "${MISSING[@]}"
    _ok "Installed packages."
else
    _ok "All Python packages verified."
fi

# Copy proxy script to ~/.aws for backward compatibility
cp "${SCRIPT_DIR}/bedrock_mantle_proxy.py" "${AWS_DIR}/bedrock_mantle_proxy.py"
chmod +x "${AWS_DIR}/bedrock_mantle_proxy.py"
_ok "Deployed proxy script to ${AWS_DIR}/bedrock_mantle_proxy.py"

# Configure opencode.jsonc
CONFIG_FILE="${CONFIG_DIR}/opencode.jsonc"
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    _info "Backed up existing config to ${CONFIG_FILE}.bak"
fi

cat << 'EOF' > "$CONFIG_FILE"
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "bash",
  "provider": {
    "bedrock-mantle": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Bedrock Mantle (Local SigV4)",
      "options": {
        "baseURL": "http://127.0.0.1:4098/v1",
        "apiKey": "sigv4-local"
      },
      "models": {
        "qwen.qwen3-coder-480b-a35b-instruct": {
          "name": "Qwen 3 Coder 480B (Top Coding)"
        },
        "qwen.qwen3-coder-next": {
          "name": "Qwen 3 Coder Next"
        },
        "deepseek.v3.2": {
          "name": "DeepSeek V3.2 (Latest)"
        },
        "deepseek.v3.1": {
          "name": "DeepSeek V3.1"
        },
        "moonshotai.kimi-k2.5": {
          "name": "Kimi K2.5"
        },
        "moonshotai.kimi-k2-thinking": {
          "name": "Kimi K2 Thinking (Reasoning)"
        },
        "openai.gpt-oss-120b": {
          "name": "GPT-OSS 120B (Flagship)"
        },
        "openai.gpt-oss-20b": {
          "name": "GPT-OSS 20B (Fast)"
        },
        "mistral.mistral-large-3-675b-instruct": {
          "name": "Mistral Large 3 675B"
        },
        "mistral.devstral-2-123b": {
          "name": "Devstral 2 123B (Code Specialist)"
        },
        "google.gemma-3-27b-it": {
          "name": "Google Gemma 3 27B"
        },
        "google.gemma-3-12b-it": {
          "name": "Google Gemma 3 12B"
        },
        "nvidia.nemotron-super-3-120b": {
          "name": "NVIDIA Nemotron Super 3 120B"
        },
        "nvidia.nemotron-nano-3-30b": {
          "name": "NVIDIA Nemotron Nano 3 30B"
        },
        "zai.glm-5": {
          "name": "ZAI GLM-5"
        },
        "zai.glm-4.7": {
          "name": "ZAI GLM-4.7"
        },
        "minimax.minimax-m2.5": {
          "name": "MiniMax M2.5"
        },
        "minimax.minimax-m2.1": {
          "name": "MiniMax M2.1"
        }
      }
    }
  },
  "mcp": {
    "browse": {
      "type": "local",
      "enabled": true,
      "command": [
        "C:\\Users\\User\\.local\\bin\\browse.exe",
        "mcp"
      ],
      "cwd": "C:\\Users\\User",
      "pool": true,
      "environment": {
        "OPENCODE_BROWSER_RUNTIME": "auto-update"
      }
    }
  }
}
EOF
_ok "Configured ${CONFIG_FILE}"

_ok "Setup Complete! Use: source ~/ssot/modules/dev/opencode.sh && oc start"
