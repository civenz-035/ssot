#!/bin/bash
# ============================================================
# opencode.sh — OpenCode & Bedrock Mantle Integration (SSOT Module)
# Module: dev/opencode
# ============================================================

export BEDROCK_MANTLE_REGION="${BEDROCK_MANTLE_REGION:-ap-southeast-2}"
export BEDROCK_PROXY_HOST="${BEDROCK_PROXY_HOST:-127.0.0.1}"
export BEDROCK_PROXY_PORT="${BEDROCK_PROXY_PORT:-4098}"

_oc_get_python() {
    if command -v python3 &>/dev/null; then
        echo "python3"
    elif command -v python &>/dev/null; then
        echo "python"
    else
        echo ""
    fi
}

_oc_proxy_script() {
    # Prefer SSOT env var (set by joe.sh), fallback to common paths
    local ssot_dir="${SSOT:-${SSOT_PATH:-${HOME}/ssot}}"
    local mod_script="${ssot_dir}/modules/opencode/bedrock_mantle_proxy.py"
    local cache_script="${HOME}/.aws/bedrock_mantle_proxy.py"
    if [[ -f "$mod_script" ]]; then
        # Always sync latest stdlib proxy from SSOT → cache (eliminates stale OpenSSL version)
        mkdir -p "${HOME}/.aws"
        cp -f "$mod_script" "$cache_script" 2>/dev/null || true
        echo "$cache_script"
    elif [[ -f "$cache_script" ]]; then
        echo "$cache_script"
    else
        echo ""
    fi
}

_oc_log_file() {
    echo "${HOME}/.aws/bedrock_proxy.log"
}

oc_proxy_status() {
    if curl -sf "http://${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}/health" &>/dev/null; then
        echo "Bedrock Mantle Proxy is RUNNING on http://${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}"
        return 0
    else
        echo "Bedrock Mantle Proxy is STOPPED"
        return 1
    fi
}

oc_proxy_start() {
    if oc_proxy_status &>/dev/null; then
        echo "Bedrock Mantle Proxy is already running on http://${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}"
        return 0
    fi

    local py
    py="$(_oc_get_python)"
    if [[ -z "$py" ]]; then
        echo "Error: Python is not installed or not in PATH." >&2
        return 1
    fi

    local script
    script="$(_oc_proxy_script)"
    if [[ ! -f "$script" ]]; then
        echo "Error: Proxy script not found at $script" >&2
        return 1
    fi

    # Auto-link credentials from Windows host on WSL if missing
    if [[ ! -f "${HOME}/.aws/credentials" && -d "/mnt/c/Users" ]]; then
        for u in /mnt/c/Users/*/.aws; do
            if [[ -f "${u}/credentials" ]]; then
                mkdir -p "${HOME}/.aws"
                cp -p "${u}/credentials" "${HOME}/.aws/credentials"
                [[ -f "${u}/config" ]] && cp -p "${u}/config" "${HOME}/.aws/config"
                chmod 600 "${HOME}/.aws/credentials"
                echo "Imported AWS credentials from Windows host."
                break
            fi
        done
    fi

    mkdir -p "${HOME}/.aws"
    local log_file
    log_file="$(_oc_log_file)"
    # Clear old log before starting
    : > "$log_file"

    echo "Starting Bedrock Mantle Proxy on ${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}..."
    if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" || "${JOE_ENV:-}" == "GIT-BASH" ]]; then
        cmd //c "start \"\" /b $py \"$script\"" 2>/dev/null
    else
        nohup "$py" "$script" > "$log_file" 2>&1 &
    fi

    local count=0
    while (( count < 10 )); do
        if oc_proxy_status &>/dev/null; then
            echo "Bedrock Mantle Proxy started successfully!"
            return 0
        fi
        sleep 0.5
        (( count++ ))
    done

    echo "Warning: Proxy started but healthcheck timed out. Check AWS credentials (~/.aws/credentials)." >&2
    if [[ -f "$log_file" && -s "$log_file" ]]; then
        echo "--- Last log output (${log_file}) ---" >&2
        tail -n 8 "$log_file" >&2
        echo "------------------------------------" >&2
    fi
    return 1
}

oc_proxy_stop() {
    if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" || "${JOE_ENV:-}" == "GIT-BASH" ]]; then
        powershell.exe -NoProfile -Command 'Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*bedrock_mantle_proxy*" } | Stop-Process -Force' 2>/dev/null
    else
        pkill -f "bedrock_mantle_proxy" 2>/dev/null
    fi
    echo "Bedrock Mantle Proxy stopped."
}

oc_proxy_install() {
    local ssot_dir="${SSOT_PATH:-${HOME}/ssot}"
    if [[ -f "${ssot_dir}/modules/opencode/install.sh" ]]; then
        bash "${ssot_dir}/modules/opencode/install.sh"
    elif [[ -f "${ssot_dir}/modules/opencode/install.ps1" && ( "${OSTYPE:-}" == "msys" || "${JOE_ENV:-}" == "GIT-BASH" ) ]]; then
        powershell.exe -ExecutionPolicy Bypass -File "${ssot_dir}/modules/opencode/install.ps1"
    else
        echo "Install script not found." >&2
        return 1
    fi
}

# ── CLI Wrapper (bedrock-cli) ──────────────────────────────────
_oc_bedrock_cli() {
    local ssot_dir="${SSOT:-${SSOT_PATH:-${HOME}/ssot}}"
    local cli_script="${ssot_dir}/modules/opencode/bedrock-cli.sh"
    if [[ ! -f "$cli_script" ]]; then
        echo "Error: bedrock-cli.sh not found at $cli_script" >&2
        return 1
    fi
    # shellcheck source=/dev/null
    source "$cli_script"
    bedrock_cli "$@"
}

oc() {
    local cmd="${1:-status}"
    shift 2>/dev/null || true
    case "$cmd" in
        start|up)
            oc_proxy_start
            ;;
        stop|down)
            oc_proxy_stop
            ;;
        restart)
            oc_proxy_stop
            sleep 1
            oc_proxy_start
            ;;
        status)
            oc_proxy_status
            ;;
        install|setup)
            oc_proxy_install
            ;;
        run|launch)
            oc_proxy_start && opencode "$@"
            ;;
        cli|ask|chat)
            _oc_bedrock_cli "$@"
            ;;
        env|export)
            oc_env_export "$@"
            ;;
        catalog|models)
            oc_model_catalog
            ;;
        *)
            echo "Usage: oc {start|stop|restart|status|install|run|cli|env|catalog} [args]"
            echo ""
            echo "Proxy commands:"
            echo "  oc start               Start Bedrock Mantle proxy"
            echo "  oc stop                Stop proxy"
            echo "  oc status              Check proxy status"
            echo "  oc run                 Start proxy + launch OpenCode"
            echo ""
            echo "AI Agent integration:"
            echo "  oc env                 Export env vars for AI agents"
            echo "  oc catalog             Show model catalog (JSON)"
            echo ""
            echo "CLI commands:"
            echo "  oc cli \"prompt\"        Chat with default model"
            echo "  oc cli deepseek \"...\"  Chat with specific model"
            echo "  oc cli models          List available models"
            echo "  cat file | oc cli qwen Pipe input to model"
            ;;
    esac
}

# ── Export for external use ─────────────────────────────────────
# Functions available when module is sourced
export -f oc_proxy_status oc_proxy_start oc_proxy_stop oc_proxy_install oc 2>/dev/null || true

# ── Environment Helper for AI Agents (Hermes, Claude, etc.) ─────
# Usage: source <(oc env) or eval "$(oc env)"
oc_env_export() {
    # Ensure proxy is running
    if ! _bcli_healthcheck &>/dev/null; then
        oc_proxy_start &>/dev/null || true
    fi
    
    # Find Python for bedrock-cli
    local py=""
    if command -v python3 &>/dev/null; then
        py="python3"
    elif command -v python &>/dev/null; then
        py="python"
    fi
    
    cat << EOF
# Bedrock Mantle Proxy Environment
# Auto-generated by: oc env
export OPENAI_API_KEY="sigv4-local"
export OPENAI_BASE_URL="http://${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}/v1"
export BEDROCK_MANTLE_REGION="${BEDROCK_MANTLE_REGION}"
export BEDROCK_PROXY_URL="http://${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}"
EOF

    # Add bedrock-cli to PATH if available
    local ssot_dir="${SSOT:-${SSOT_PATH:-${HOME}/ssot}}"
    if [[ -f "${ssot_dir}/modules/opencode/bedrock-cli.sh" ]]; then
        echo "export BEDROCK_CLI=\"${ssot_dir}/modules/opencode/bedrock-cli.sh\""
        echo "# CLI: bash \$BEDROCK_CLI \"your prompt\""
    fi
}

# ── Model Catalog for AI Agents ─────────────────────────────────
# Returns JSON suitable for Hermes/plugins to consume
oc_model_catalog() {
    cat << 'EOF'
{
  "provider": "bedrock-mantle",
  "base_url": "http://127.0.0.1:4098/v1",
  "api_key": "sigv4-local",
  "models": [
    {"id": "qwen.qwen3-coder-480b-a35b-instruct", "name": "Qwen 3 Coder 480B", "tags": ["coding"]},
    {"id": "qwen.qwen3-coder-next", "name": "Qwen 3 Coder Next", "tags": ["coding"]},
    {"id": "deepseek.v3.1", "name": "DeepSeek V3.1", "tags": ["coding", "general"], "default": true},
    {"id": "deepseek.v3.2", "name": "DeepSeek V3.2", "tags": ["coding", "general"]},
    {"id": "moonshotai.kimi-k2.5", "name": "Kimi K2.5", "tags": ["general", "reasoning"]},
    {"id": "moonshotai.kimi-k2-thinking", "name": "Kimi K2 Thinking", "tags": ["reasoning"]},
    {"id": "openai.gpt-oss-120b", "name": "GPT-OSS 120B", "tags": ["general"]},
    {"id": "openai.gpt-oss-20b", "name": "GPT-OSS 20B", "tags": ["general", "fast"]},
    {"id": "mistral.mistral-large-3-675b-instruct", "name": "Mistral Large 3", "tags": ["general", "large"]},
    {"id": "mistral.devstral-2-123b", "name": "Devstral 2", "tags": ["coding"]},
    {"id": "google.gemma-3-27b-it", "name": "Gemma 3 27B", "tags": ["general"]},
    {"id": "google.gemma-3-12b-it", "name": "Gemma 3 12B", "tags": ["general", "fast"]},
    {"id": "nvidia.nemotron-super-3-120b", "name": "Nemotron Super 3", "tags": ["general"]},
    {"id": "nvidia.nemotron-nano-3-30b", "name": "Nemotron Nano 3", "tags": ["general", "fast"]},
    {"id": "zai.glm-5", "name": "GLM-5", "tags": ["general"]},
    {"id": "zai.glm-4.7", "name": "GLM-4.7", "tags": ["general"]},
    {"id": "minimax.minimax-m2.5", "name": "MiniMax M2.5", "tags": ["general"]},
    {"id": "minimax.minimax-m2.1", "name": "MiniMax M2.1", "tags": ["general"]}
  ],
  "default_model": "deepseek.v3.1"
}
EOF
}
