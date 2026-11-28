#!/usr/bin/env bash
# ============================================================
# bedrock-cli.sh — Universal CLI for Bedrock Mantle Proxy
# SSOT Module: modules/opencode/bedrock-cli.sh
# Usage: bedrock-cli [model] "your prompt" [--options]
# ============================================================
# Design Goals:
#   - Zero-config: auto-starts proxy if not running
#   - SSOT-compliant: uses SSOT env vars, no hardcoded values
#   - Works everywhere: Git-Bash, WSL, Termux, Linux, macOS
# ============================================================

set -uo pipefail

# ── SSOT Environment ─────────────────────────────────────
BEDROCK_MANTLE_REGION="${BEDROCK_MANTLE_REGION:-ap-southeast-2}"
BEDROCK_PROXY_HOST="${BEDROCK_PROXY_HOST:-127.0.0.1}"
BEDROCK_PROXY_PORT="${BEDROCK_PROXY_PORT:-4098}"
BEDROCK_PROXY_URL="http://${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}"
SSOT_DIR="${SSOT:-${SSOT_PATH:-${HOME}/ssot}}"

# ── Colors (SSOT compliant: core/01-colors.sh style) ─────
if [[ -f "${SSOT_DIR}/core/01-colors.sh" ]]; then
    # shellcheck source=/dev/null
    source "${SSOT_DIR}/core/01-colors.sh" 2>/dev/null || true
fi
# Fallback if colors not loaded
if ! declare -f c &>/dev/null; then
    c() { printf '\033[0;%sm%s\033[0m\n' "${1:-0}" "${*:2}"; }
    cn() { printf '\033[1;%sm%s\033[0m\n' "${1:-37}" "${*:2}"; }
    rc() { printf '\033[0;%sm%s\033[0m' "${1:-32}" "${*:2}"; }
fi

# ── Default Model ────────────────────────────────────────
DEFAULT_MODEL="deepseek.v3.1"

# ── Available Models ─────────────────────────────────────
declare -A MODEL_ALIASES=(
    # DeepSeek
    ["deepseek"]="deepseek.v3.1"
    ["deepseek-v3"]="deepseek.v3.1"
    ["deepseek-v3.1"]="deepseek.v3.1"
    ["deepseek-v3.2"]="deepseek.v3.2"
    # Qwen
    ["qwen"]="qwen.qwen3-coder-480b-a35b-instruct"
    ["qwen-coder"]="qwen.qwen3-coder-480b-a35b-instruct"
    ["qwen-next"]="qwen.qwen3-coder-next"
    # Kimi
    ["kimi"]="moonshotai.kimi-k2.5"
    ["kimi-k2.5"]="moonshotai.kimi-k2.5"
    ["kimi-thinking"]="moonshotai.kimi-k2-thinking"
    # GPT-OSS
    ["gpt-oss"]="openai.gpt-oss-120b"
    ["gpt-oss-120b"]="openai.gpt-oss-120b"
    ["gpt-oss-20b"]="openai.gpt-oss-20b"
    # Mistral
    ["mistral"]="mistral.mistral-large-3-675b-instruct"
    ["mistral-large"]="mistral.mistral-large-3-675b-instruct"
    ["devstral"]="mistral.devstral-2-123b"
    # Gemma
    ["gemma"]="google.gemma-3-27b-it"
    ["gemma-27b"]="google.gemma-3-27b-it"
    ["gemma-12b"]="google.gemma-3-12b-it"
    # NVIDIA
    ["nemotron"]="nvidia.nemotron-super-3-120b"
    ["nemotron-120b"]="nvidia.nemotron-super-3-120b"
    ["nemotron-nano"]="nvidia.nemotron-nano-3-30b"
    # ZAI
    ["glm"]="zai.glm-5"
    ["glm-5"]="zai.glm-5"
    ["glm-4.7"]="zai.glm-4.7"
    # MiniMax
    ["minimax"]="minimax.minimax-m2.5"
    ["minimax-m2.5"]="minimax.minimax-m2.5"
    ["minimax-m2.1"]="minimax.minimax-m2.1"
)

# ── Helper Functions ─────────────────────────────────────

_bcli_info()  { c 36 "[bedrock-cli]" "$*" >&2; }
_bcli_ok()    { c 32 "[bedrock-cli] ✓" "$*" >&2; }
_bcli_warn()  { c 33 "[bedrock-cli] ⚠" "$*" >&2; }
_bcli_err()   { c 31 "[bedrock-cli] ✗" "$*" >&2; }

_bcli_get_python() {
    if command -v python3 &>/dev/null; then
        echo "python3"
    elif command -v python &>/dev/null; then
        echo "python"
    else
        echo ""
    fi
}

_bcli_proxy_script() {
    local mod_script="${SSOT_DIR}/modules/opencode/bedrock_mantle_proxy.py"
    local cache_script="${HOME}/.aws/bedrock_mantle_proxy.py"
    if [[ -f "$mod_script" ]]; then
        mkdir -p "${HOME}/.aws"
        cp -f "$mod_script" "$cache_script" 2>/dev/null || true
        echo "$cache_script"
    elif [[ -f "$cache_script" ]]; then
        echo "$cache_script"
    else
        echo ""
    fi
}

_bcli_healthcheck() {
    curl -sf "${BEDROCK_PROXY_URL}/health" &>/dev/null
}

_bcli_ensure_proxy() {
    if _bcli_healthcheck; then
        return 0
    fi

    _bcli_info "Proxy not running. Starting..."

    local py
    py="$(_bcli_get_python)"
    if [[ -z "$py" ]]; then
        _bcli_err "Python not found in PATH."
        return 1
    fi

    local script
    script="$(_bcli_proxy_script)"
    if [[ ! -f "$script" ]]; then
        _bcli_err "Proxy script not found. Run: oc install"
        return 1
    fi

    # Check AWS credentials
    if [[ ! -f "${HOME}/.aws/credentials" ]]; then
        # Try to import from Windows host on WSL
        if [[ -d "/mnt/c/Users" ]]; then
            for u in /mnt/c/Users/*/.aws; do
                if [[ -f "${u}/credentials" ]]; then
                    mkdir -p "${HOME}/.aws"
                    cp -p "${u}/credentials" "${HOME}/.aws/credentials"
                    [[ -f "${u}/config" ]] && cp -p "${u}/config" "${HOME}/.aws/config"
                    chmod 600 "${HOME}/.aws/credentials"
                    _bcli_info "Imported AWS credentials from Windows host."
                    break
                fi
            done
        fi
        if [[ ! -f "${HOME}/.aws/credentials" ]]; then
            _bcli_err "No AWS credentials. Run: oc install"
            return 1
        fi
    fi

    # Start proxy
    local log_file="${HOME}/.aws/bedrock_proxy.log"
    : > "$log_file"

    if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" || "${JOE_ENV:-}" == "GIT-BASH" ]]; then
        cmd //c "start \"\" /b $py \"$script\"" 2>/dev/null
    else
        nohup "$py" "$script" > "$log_file" 2>&1 &
    fi

    # Wait for health
    local count=0
    while (( count < 15 )); do
        if _bcli_healthcheck; then
            _bcli_ok "Proxy started on ${BEDROCK_PROXY_URL}"
            return 0
        fi
        sleep 0.5
        (( count++ ))
    done

    _bcli_err "Proxy failed to start. Check ${log_file}"
    [[ -f "$log_file" && -s "$log_file" ]] && tail -n 5 "$log_file" >&2
    return 1
}

_bcli_resolve_model() {
    local input="$1"
    local key
    # Check alias map (case-insensitive)
    for key in "${!MODEL_ALIASES[@]}"; do
        if [[ "${key,,}" == "${input,,}" ]]; then
            echo "${MODEL_ALIASES[$key]}"
            return 0
        fi
    done
    # Return as-is (assume full model ID)
    echo "$input"
}

_bcli_list_models() {
    cat << 'EOF'
Available models (use alias or full ID):

  Coding & Development:
    deepseek, deepseek-v3      → deepseek.v3.1
    deepseek-v3.2              → deepseek.v3.2
    qwen, qwen-coder           → qwen.qwen3-coder-480b-a35b-instruct
    qwen-next                  → qwen.qwen3-coder-next
    devstral                   → mistral.devstral-2-123b

  Reasoning & General:
    kimi, kimi-k2.5            → moonshotai.kimi-k2.5
    kimi-thinking              → moonshotai.kimi-k2-thinking (extended reasoning)
    gpt-oss, gpt-oss-120b      → openai.gpt-oss-120b
    gpt-oss-20b                → openai.gpt-oss-20b
    mistral, mistral-large     → mistral.mistral-large-3-675b-instruct

  Open Weights:
    gemma, gemma-27b           → google.gemma-3-27b-it
    gemma-12b                  → google.gemma-3-12b-it
    nemotron, nemotron-120b    → nvidia.nemotron-super-3-120b
    nemotron-nano              → nvidia.nemotron-nano-3-30b

  Other:
    glm, glm-5                 → zai.glm-5
    glm-4.7                    → zai.glm-4.7
    minimax, minimax-m2.5      → minimax.minimax-m2.5
    minimax-m2.1               → minimax.minimax-m2.1

Default: deepseek.v3.1
EOF
}

_bcli_chat() {
    local model="$1"
    local prompt="$2"
    local temperature="${3:-0.7}"
    local max_tokens="${4:-4096}"
    local stream="${5:-true}"

    local resolved_model
    resolved_model="$(_bcli_resolve_model "$model")"

    local json_payload
    json_payload=$(cat << EOF
{
  "model": "${resolved_model}",
  "messages": [{"role": "user", "content": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$prompt")}],
  "temperature": ${temperature},
  "max_tokens": ${max_tokens},
  "stream": ${stream}
}
EOF
)

    if [[ "$stream" == "true" ]]; then
        # Streaming response
        curl -sN "${BEDROCK_PROXY_URL}/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer sigv4-local" \
            -d "$json_payload" 2>/dev/null | while IFS= read -r line; do
                if [[ "$line" =~ ^data:\ \{ ]]; then
                    local content
                    content=$(echo "$line" | sed 's/^data: //' | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'choices' in d and d['choices'] and 'delta' in d['choices'][0] and 'content' in d['choices'][0]['delta']:
        print(d['choices'][0]['delta']['content'], end='')
except: pass
" 2>/dev/null)
                    printf '%s' "$content"
                elif [[ "$line" == "data: [DONE]" ]]; then
                    echo ""
                fi
            done
    else
        # Non-streaming response
        local response
        response=$(curl -s "${BEDROCK_PROXY_URL}/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer sigv4-local" \
            -d "$json_payload" 2>/dev/null)

        echo "$response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'choices' in d and d['choices'] and 'message' in d['choices'][0]:
        print(d['choices'][0]['message']['content'])
    elif 'error' in d:
        print(f\"Error: {d['error']}\", file=sys.stderr)
except Exception as e:
    print(f'Parse error: {e}', file=sys.stderr)
" 2>/dev/null
    fi
}

_bcli_pipe() {
    local model="$1"
    local temperature="${2:-0.7}"

    local prompt
    # Use cached stdin if available, otherwise read fresh
    if [[ -n "${_BCli_STDIN_CACHE:-}" ]]; then
        prompt="$_BCli_STDIN_CACHE"
        unset _BCli_STDIN_CACHE
    else
        prompt=$(cat)
    fi

    if [[ -z "$prompt" ]]; then
        _bcli_err "No input from stdin."
        return 1
    fi

    _bcli_chat "$model" "$prompt" "$temperature"
}

# ── Main Entry Point ─────────────────────────────────────

bedrock_cli() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        help|--help|-h)
            cat << 'EOF'
bedrock-cli — Universal CLI for Bedrock Mantle Proxy

Usage:
  bedrock-cli [model] "your prompt"          Chat with model
  bedrock-cli [model] < file.txt             Pipe input to model (stdin)
  echo "prompt" | bedrock-cli [model]        Pipe prompt to model

Commands:
  models, --models      List available models
  status               Check proxy status
  start                Start proxy if not running
  stop                 Stop proxy
  help                 Show this help

Options (after prompt):
  --temp 0.7           Set temperature (default: 0.7)
  --max 4096           Set max tokens (default: 4096)
  --no-stream          Disable streaming response

Examples:
  bedrock-cli "Hello, how are you?"
  bedrock-cli deepseek "Explain quantum computing"
  bedrock-cli kimi-thinking "Solve this puzzle: ..."
  cat code.py | bedrock-cli qwen "Review this code"
  git diff | bedrock-cli deepseek "Summarize changes"
EOF
            ;;

        models|--models|-m)
            _bcli_list_models
            ;;

        status)
            if _bcli_healthcheck; then
                _bcli_ok "Proxy running at ${BEDROCK_PROXY_URL}"
            else
                _bcli_warn "Proxy not running. Use: bedrock-cli start"
            fi
            ;;

        start)
            _bcli_ensure_proxy
            ;;

        stop)
            if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" || "${JOE_ENV:-}" == "GIT-BASH" ]]; then
                powershell.exe -NoProfile -Command 'Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*bedrock_mantle_proxy*" } | Stop-Process -Force' 2>/dev/null
            else
                pkill -f "bedrock_mantle_proxy" 2>/dev/null
            fi
            _bcli_ok "Proxy stopped."
            ;;

        *)
            # Treat all remaining args as prompt/model
            # Reconstruct original args since $cmd consumed first one
            set -- "$cmd" "$@"
            
            local model="$DEFAULT_MODEL"
            local prompt=""
            local temp="0.7"
            local max_tokens="4096"
            local stream="true"

            # Parse arguments first
            local positional=()
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --temp)
                        temp="$2"
                        shift 2
                        ;;
                    --max)
                        max_tokens="$2"
                        shift 2
                        ;;
                    --no-stream)
                        stream="false"
                        shift
                        ;;
                    *)
                        positional+=("$1")
                        shift
                        ;;
                esac
            done

            # Detect if stdin has data (only if no positional args)
            # Git-Bash/MSYS quirk: stdin detection via [Console]::IsInputRedirected
            # returns True when running under shell tools, which is misleading.
            # Solution: Trust positional args. If user wants pipe, they should
            # provide NO args (stdin will be read by _bcli_pipe).
            local is_piped=false
            if [[ ${#positional[@]} -eq 0 ]]; then
                # Heuristic: if no args and we're on Unix (not Git-Bash), check tty
                if [[ "${OSTYPE:-}" != "msys" && "${OSTYPE:-}" != "cygwin" && "${JOE_ENV:-}" != "GIT-BASH" ]]; then
                    if [[ ! -t 0 ]]; then
                        is_piped=true
                    fi
                fi
            fi

            # Determine model vs prompt
            if [[ ${#positional[@]} -eq 0 ]]; then
                if $is_piped; then
                    # Pipe mode
                    _bcli_ensure_proxy || return 1
                    _bcli_pipe "$model" "$temp"
                    return $?
                else
                    _bcli_err "No prompt provided."
                    return 1
                fi
            elif [[ ${#positional[@]} -eq 1 ]]; then
                # Could be model (if stdin) or prompt (if no stdin)
                # Heuristic: if it contains spaces, it's a prompt
                # If it matches a model alias and stdin has data, treat as model
                local first_arg="${positional[0]}"
                local is_model_alias=false
                
                # Check if it's a known model alias
                for key in "${!MODEL_ALIASES[@]}"; do
                    if [[ "${key,,}" == "${first_arg,,}" ]]; then
                        is_model_alias=true
                        break
                    fi
                done
                
                if $is_piped && $is_model_alias; then
                    model="$(_bcli_resolve_model "$first_arg")"
                else
                    # Treat single arg as prompt when no stdin
                    prompt="$first_arg"
                fi
            else
                # First is model, rest is prompt
                model="$(_bcli_resolve_model "${positional[0]}")"
                prompt="${positional[*]:1}"
            fi

            _bcli_ensure_proxy || return 1

            if [[ -n "$prompt" ]]; then
                _bcli_chat "$model" "$prompt" "$temp" "$max_tokens" "$stream"
            elif $is_piped; then
                _bcli_pipe "$model" "$temp"
            fi
            ;;
    esac
}

# ── Run if executed directly ─────────────────────────────
# Guard: only run main logic when executed, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    bedrock_cli "$@"
fi
