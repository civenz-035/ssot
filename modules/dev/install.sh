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
SSOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AWS_DIR="${HOME}/.aws"
CONFIG_DIR="${HOME}/.config/opencode"

mkdir -p "${AWS_DIR}" "${CONFIG_DIR}"

# ── 1. Check & Setup AWS Credentials (WSL / Windows Host / Vault / Env) ──
_info "Checking AWS credentials for Bedrock Mantle..."

AWS_CREDS="${AWS_DIR}/credentials"
WIN_USER="$(whoami 2>/dev/null || echo "")"
WIN_AWS_DIR="/mnt/c/Users/${WIN_USER}/.aws"

# If current user dir on Windows doesn't match whoami, look for existing mount
if [[ ! -d "$WIN_AWS_DIR" && -d "/mnt/c/Users" ]]; then
    for u in /mnt/c/Users/*/.aws; do
        if [[ -f "${u}/credentials" ]]; then
            WIN_AWS_DIR="${u}"
            break
        fi
    done
fi

if [[ -f "$AWS_CREDS" ]]; then
    _ok "Found local AWS credentials at ${AWS_CREDS}"
elif [[ -d "$WIN_AWS_DIR" && -f "${WIN_AWS_DIR}/credentials" ]]; then
    _info "Detected Windows host AWS credentials at ${WIN_AWS_DIR}/credentials"
    cp -p "${WIN_AWS_DIR}/credentials" "${AWS_CREDS}"
    [[ -f "${WIN_AWS_DIR}/config" ]] && cp -p "${WIN_AWS_DIR}/config" "${AWS_DIR}/config"
    chmod 600 "${AWS_CREDS}"
    _ok "Imported AWS credentials from Windows host into WSL/Linux (~/.aws/credentials)"
elif [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    _info "Detected AWS credentials in environment variables. Writing to ${AWS_CREDS}..."
    cat << EOF > "$AWS_CREDS"
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
[civenz]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
    chmod 600 "${AWS_CREDS}"
    _ok "Generated ${AWS_CREDS} from environment variables"
elif [[ -f "${HOME}/.env.secret" || -f "${SSOT_DIR}/.env.secret" ]]; then
    # Try sourcing SSOT secret file
    SECRET_FILE="${HOME}/.env.secret"
    [[ ! -f "$SECRET_FILE" ]] && SECRET_FILE="${SSOT_DIR}/.env.secret"
    
    # Source without breaking execution
    set +u
    source "$SECRET_FILE" 2>/dev/null || true
    set -u
    
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        cat << EOF > "$AWS_CREDS"
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
[civenz]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
        chmod 600 "${AWS_CREDS}"
        _ok "Generated ${AWS_CREDS} from ${SECRET_FILE}"
    fi
fi

# If still missing, check if vault script exists to offer unlocking
if [[ ! -f "$AWS_CREDS" ]]; then
    VAULT_SH="${SSOT_DIR}/bootstrap/vault/ssot-vault.sh"
    if [[ -f "$VAULT_SH" && -f "${SSOT_DIR}/bootstrap/vault/.env.enc" ]]; then
        _warn "AWS credentials missing. SSOT vault detected at ${VAULT_SH}"
        _info "To unlock shared secrets, run: bash ${VAULT_SH} unlock"
    fi
    _warn "No AWS credentials found yet at ${AWS_CREDS}."
    _warn "Please ensure AWS keys are present before starting Bedrock proxy."
fi

# ── 2. Check Python Environment ──
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

# ── 3. Deploy Proxy Script ──
cp "${SCRIPT_DIR}/bedrock_mantle_proxy.py" "${AWS_DIR}/bedrock_mantle_proxy.py"
chmod +x "${AWS_DIR}/bedrock_mantle_proxy.py"
_ok "Deployed proxy script to ${AWS_DIR}/bedrock_mantle_proxy.py"

# ── 4. Configure opencode.jsonc ──
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
