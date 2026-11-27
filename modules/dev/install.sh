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
        "moonshotai.kimi-k2.5": {
          "name": "Kimi K2.5 (Bedrock Mantle)"
        },
        "openai.gpt-oss-120b": {
          "name": "GPT-OSS 120B (Bedrock Mantle)"
        },
        "deepseek.v3.1": {
          "name": "DeepSeek V3.1 (Bedrock Mantle)"
        },
        "qwen.qwen3-coder-480b-a35b-instruct": {
          "name": "Qwen3 Coder 480B (Bedrock Mantle)"
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
