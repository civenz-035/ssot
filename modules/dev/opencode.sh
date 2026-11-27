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
    local ssot_dir="${SSOT_PATH:-${HOME}/ssot}"
    local mod_script="${ssot_dir}/modules/dev/bedrock_mantle_proxy.py"
    if [[ -f "$mod_script" ]]; then
        echo "$mod_script"
    else
        echo "${HOME}/.aws/bedrock_mantle_proxy.py"
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
    if [[ -f "$log_file" ]]; then
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
    if [[ -f "${ssot_dir}/modules/dev/install.sh" ]]; then
        bash "${ssot_dir}/modules/dev/install.sh"
    elif [[ -f "${ssot_dir}/modules/dev/install.ps1" && ( "${OSTYPE:-}" == "msys" || "${JOE_ENV:-}" == "GIT-BASH" ) ]]; then
        powershell.exe -ExecutionPolicy Bypass -File "${ssot_dir}/modules/dev/install.ps1"
    else
        echo "Install script not found." >&2
        return 1
    fi
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
        *)
            echo "Usage: oc {start|stop|restart|status|install|run} [args]"
            ;;
    esac
}
