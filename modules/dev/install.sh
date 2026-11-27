#!/usr/bin/env bash
# ============================================================
# install.sh — Setup OpenCode + Bedrock Mantle Proxy (Universal)
# Supports: Linux / WSL2 / Termux / macOS / Multi-machine SSOT
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
AWS_CREDS="${AWS_DIR}/credentials"
AWS_CONFIG="${AWS_DIR}/config"

mkdir -p "${AWS_DIR}" "${CONFIG_DIR}"

# ── 1. Check & Setup AWS Credentials across Environments ──
_info "Checking AWS credentials for Bedrock Mantle..."

_write_aws_credentials() {
    local key="$1"
    local secret="$2"
    cat << EOF > "$AWS_CREDS"
[default]
aws_access_key_id = ${key}
aws_secret_access_key = ${secret}
[civenz]
aws_access_key_id = ${key}
aws_secret_access_key = ${secret}
EOF
    chmod 600 "$AWS_CREDS"
    if [[ ! -f "$AWS_CONFIG" ]]; then
        cat << EOF > "$AWS_CONFIG"
[default]
region = ap-southeast-2
output = json
[profile civenz]
region = ap-southeast-2
output = json
EOF
    fi
}

# Source secrets if already decrypted by vault
for s_file in "${HOME}/.env.secret" "${SSOT_DIR}/.env.secret" "${HOME}/.env"; do
    if [[ -f "$s_file" ]]; then
        set +u
        source "$s_file" 2>/dev/null || true
        set -u
    fi
done

# Step 1A: Existing local credentials
if [[ -f "$AWS_CREDS" ]]; then
    _ok "Found existing AWS credentials at ${AWS_CREDS}"

# Step 1B: If on WSL, auto-import from Windows Host
elif [[ -d "/mnt/c/Users" ]]; then
    for u in /mnt/c/Users/*/.aws; do
        if [[ -f "${u}/credentials" ]]; then
            cp -p "${u}/credentials" "${AWS_CREDS}"
            [[ -f "${u}/config" ]] && cp -p "${u}/config" "${AWS_CONFIG}"
            chmod 600 "${AWS_CREDS}"
            _ok "Imported AWS credentials from Windows host (${u}/credentials)"
            break
        fi
    done
fi

# Step 1C: If credentials loaded from SSOT Vault / Environment
if [[ ! -f "$AWS_CREDS" && -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    _write_aws_credentials "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"
    _ok "Generated ${AWS_CREDS} from environment / SSOT secrets"
fi

# Step 1D: If on another clean machine with SSOT Vault (Interactive Unlock Offer)
if [[ ! -f "$AWS_CREDS" ]]; then
    VAULT_SH="${SSOT_DIR}/bootstrap/vault/ssot-vault.sh"
    if [[ -f "$VAULT_SH" && -f "${SSOT_DIR}/bootstrap/vault/.env.enc" ]]; then
        _warn "AWS credentials not found locally. SSOT Vault detected!"
        echo -n "[INSTALL] Would you like to unlock SSOT Vault now? [y/N]: "
        read -r do_unlock || do_unlock="n"
        if [[ "$do_unlock" =~ ^[Yy]$ ]]; then
            bash "$VAULT_SH" unlock
            for s_file in "${HOME}/.env.secret" "${SSOT_DIR}/.env.secret"; do
                if [[ -f "$s_file" ]]; then
                    set +u
                    source "$s_file" 2>/dev/null || true
                    set -u
                fi
            done
            if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
                _write_aws_credentials "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"
                _ok "Generated ${AWS_CREDS} after unlocking SSOT Vault!"
            fi
        fi
    fi
fi

# Step 1E: Interactive Manual Prompt if still missing
if [[ ! -f "$AWS_CREDS" ]]; then
    _warn "No AWS credentials detected."
    echo -n "[INSTALL] Enter AWS Access Key ID (or press Enter to skip): "
    read -r input_key || input_key=""
    if [[ -n "$input_key" ]]; then
        echo -n "[INSTALL] Enter AWS Secret Access Key: "
        read -rs input_secret || input_secret=""
        echo ""
        if [[ -n "$input_secret" ]]; then
            _write_aws_credentials "$input_key" "$input_secret"
            _ok "Saved credentials to ${AWS_CREDS}"
        fi
    fi
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

# Check botocore (only required dependency)
if ! "$PYTHON_BIN" -c "import botocore" 2>/dev/null; then
    _warn "Installing required package: botocore..."
    "$PYTHON_BIN" -m pip install --quiet botocore
    _ok "Installed botocore."
else
    _ok "botocore verified."
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
