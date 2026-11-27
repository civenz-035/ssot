#!/usr/bin/env bash
# opencode.sh — OpenCode + AWS Bedrock Mantle Proxy manager for SSOT mesh nodes
# Auto-detects environment and configures proxy accordingly.
# Location: ~/ssot/modules/dev/opencode.sh

set -uo pipefail

# ── Guard: not an interactive shell ──
[[ $- != *i* ]] && return

# ── Version & Metadata ──
readonly OC_MODULE_VERSION="1.0.0"
readonly OC_MODULE_NAME="opencode"

# ── Paths ──
: "${OC_CONFIG_DIR:="${HOME}/.config/opencode"}"
: "${OC_AWS_DIR:="${HOME}/.aws"}"
: "${OC_PROXY_SCRIPT:="${OC_AWS_DIR}/opencode_bedrock_proxy.py"}"
: "${OC_PROXY_PIDFILE:="${OC_AWS_DIR}/bedrock_mantle_proxy.pid"}"

# ── Defaults ──
: "${BEDROCK_MANTLE_REGION:=ap-southeast-2}"
: "${BEDROCK_PROXY_HOST:=127.0.0.1}"
: "${BEDROCK_PROXY_PORT:=4098}"
: "${BEDROCK_PROXY_AUTO_START:=true}"

# ── Colors (source from core if available) ──
if [[ -n "${c:-}" ]] && type c &>/dev/null; then
    _oc_info() { c blue "[OC]" "$@"; }
    _oc_ok() { c green "[OC]" "$@"; }
    _oc_warn() { c yellow "[OC]" "$@"; }
    _oc_err() { c red "[OC]" "$@"; }
else
    _oc_info() { echo "[OC] $*" >&2; }
    _oc_ok() { echo "[OC] ✓ $*" >&2; }
    _oc_warn() { echo "[OC] ⚠ $*" >&2; }
    _oc_err() { echo "[OC] ✗ $*" >&2; }
fi

# ── Internal helpers ──
_oc_python() {
    if command -v python3 &>/dev/null; then
        echo "python3"
    elif command -v python &>/dev/null; then
        echo "python"
    else
        echo ""
    fi
}

_oc_check_proxy_running() {
    local host="${1:-${BEDROCK_PROXY_HOST}}"
    local port="${2:-${BEDROCK_PROXY_PORT}}"
    
    if command -v curl &>/dev/null; then
        curl -sf "http://${host}:${port}/health" &>/dev/null
    elif command -v wget &>/dev/null; then
        wget -qO- "http://${host}:${port}/health" &>/dev/null
    else
        # Fallback: check if port is listening
        if command -v nc &>/dev/null; then
            nc -z "${host}" "${port}" &>/dev/null
        elif [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" ]]; then
            netstat -an | grep -q ":${port}.*LISTENING"
        else
            ss -tlnp 2>/dev/null | grep -q ":${port} " || \
            netstat -tlnp 2>/dev/null | grep -q ":${port} "
        fi
    fi
}

_oc_start_proxy() {
    local python_bin
    python_bin="$(_oc_python)"
    
    if [[ -z "${python_bin}" ]]; then
        _oc_err "Python not found. Cannot start Bedrock proxy."
        return 1
    fi
    
    if [[ ! -f "${OC_PROXY_SCRIPT}" ]]; then
        _oc_warn "Proxy script not found: ${OC_PROXY_SCRIPT}"
        _oc_info "Run: oc-setup-bedrock"
        return 1
    fi
    
    if _oc_check_proxy_running; then
        _oc_ok "Bedrock proxy already running at ${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}"
        return 0
    fi
    
    _oc_info "Starting Bedrock proxy on ${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}..."
    
    local env_vars
    env_vars=(
        "BEDROCK_MANTLE_REGION=${BEDROCK_MANTLE_REGION}"
        "BEDROCK_PROXY_HOST=${BEDROCK_PROXY_HOST}"
        "BEDROCK_PROXY_PORT=${BEDROCK_PROXY_PORT}"
    )
    
    if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" || "${JOE_ENV:-}" == "GIT-BASH" ]]; then
        # Windows: hide window
        (
            cd "${OC_AWS_DIR}" || return 1
            # Use start /b for background on Windows
            cmd //c "start //b //min ${python_bin} ""${OC_PROXY_SCRIPT}"" start" 2>/dev/null
        ) &
    else
        # Unix-like: background with nohup or disown
        (
            cd "${OC_AWS_DIR}" || return 1
            exec ${env_vars[@]/*/-E} "${python_bin}" "${OC_PROXY_SCRIPT}" start >/dev/null 2>&1 &
        )
    fi
    
    # Wait for proxy to be ready
    local max_wait=10
    local waited=0
    while [[ ${waited} -lt ${max_wait} ]]; do
        if _oc_check_proxy_running; then
            _oc_ok "Bedrock proxy ready! (http://${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT})"
            return 0
        fi
        sleep 0.5
        ((waited++))
    done
    
    _oc_warn "Proxy started but health check timed out"
    return 1
}

_oc_stop_proxy() {
    if ! _oc_check_proxy_running; then
        _oc_info "Bedrock proxy not running"
        return 0
    fi
    
    _oc_info "Stopping Bedrock proxy..."
    
    local python_bin
    python_bin="$(_oc_python)"
    
    if [[ -n "${python_bin}" && -f "${OC_PROXY_SCRIPT}" ]]; then
        "${python_bin}" "${OC_PROXY_SCRIPT}" stop 2>/dev/null
    fi
    
    # Also try to kill by PID file
    if [[ -f "${OC_PROXY_PIDFILE}" ]]; then
        local pid
        pid="$(cat "${OC_PROXY_PIDFILE}" 2>/dev/null)"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null
            rm -f "${OC_PROXY_PIDFILE}"
        fi
    fi
    
    _oc_ok "Bedrock proxy stopped"
}

_oc_proxy_status() {
    local python_bin
    python_bin="$(_oc_python)"
    
    if [[ -n "${python_bin}" && -f "${OC_PROXY_SCRIPT}" ]]; then
        "${python_bin}" "${OC_PROXY_SCRIPT}" status 2>/dev/null
        return
    fi
    
    if _oc_check_proxy_running; then
        _oc_ok "Bedrock proxy is running at ${BEDROCK_PROXY_HOST}:${BEDROCK_PROXY_PORT}"
    else
        _oc_info "Bedrock proxy is not running"
    fi
}

# ── Public commands ──

# opencode-proxy-start — Manually start the proxy
alias opencode-proxy-start='_oc_start_proxy'

# opencode-proxy-stop — Stop the proxy
alias opencode-proxy-stop='_oc_stop_proxy'

# opencode-proxy-status — Check proxy status
alias opencode-proxy-status='_oc_proxy_status'

# opencode-proxy-restart — Restart the proxy
alias opencode-proxy-restart='_oc_stop_proxy; sleep 1; _oc_start_proxy'

# opencode-with-proxy — Start proxy then open opencode
opencode-with-proxy() {
    _oc_start_proxy && opencode "$@"
}

# oc-bedrock — Quick alias for bedrock-specific workflow
oc-bedrock() {
    local cmd="${1:-status}"
    shift 2>/dev/null || true
    
    case "${cmd}" in
        start|up)
            _oc_start_proxy
            ;;
        stop|down)
            _oc_stop_proxy
            ;;
        status)
            _oc_proxy_status
            ;;
        restart|reload)
            _oc_stop_proxy
            sleep 1
            _oc_start_proxy
            ;;
        open|code)
            opencode-with-proxy "$@"
            ;;
        setup|install)
            oc-setup-bedrock
            ;;
        *)
            _oc_info "Usage: oc-bedrock {start|stop|status|restart|open|setup}"
            _oc_proxy_status
            ;;
    esac
}

# ── Setup helper ──
oc-setup-bedrock() {
    _oc_info "Setting up Bedrock proxy for OpenCode..."
    
    # Check Python
    local python_bin
    python_bin="$(_oc_python)"
    if [[ -z "${python_bin}" ]]; then
        _oc_err "Python not found. Please install Python 3."
        return 1
    fi
    _oc_ok "Python found: ${python_bin}"
    
    # Check required packages
    local missing_pkgs=()
    for pkg in fastapi uvicorn httpx botocore; do
        if ! ${python_bin} -c "import ${pkg}" 2>/dev/null; then
            missing_pkgs+=("${pkg}")
        fi
    done
    
    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        _oc_warn "Missing Python packages: ${missing_pkgs[*]}"
        _oc_info "Install with: pip install ${missing_pkgs[*]}"
    else
        _oc_ok "All required packages installed"
    fi
    
    # Check/create directories
    mkdir -p "${OC_CONFIG_DIR}/agents" "${OC_AWS_DIR}"
    _oc_ok "Directories ready: ${OC_CONFIG_DIR}, ${OC_AWS_DIR}"
    
    # Check proxy script
    if [[ ! -f "${OC_PROXY_SCRIPT}" ]]; then
        _oc_warn "Proxy script not found at ${OC_PROXY_SCRIPT}"
        _oc_info "Please copy files from your package or run:"
        _oc_info "  curl -fsSL ... | bash"
    else
        _oc_ok "Proxy script found"
    fi
    
    # Create symlink from SSOT if available
    if [[ -d "${HOME}/ssot" && ! -L "${OC_AWS_DIR}/opencode_bedrock_proxy.py" ]]; then
        local ssot_proxy="${HOME}/ssot/config/opencode/bedrock_mantle_proxy.py"
        if [[ -f "${ssot_proxy}" ]]; then
            ln -sf "${ssot_proxy}" "${OC_AWS_DIR}/bedrock_mantle_proxy.py" 2>/dev/null
            ln -sf "${ssot_proxy/${HOME}\/ssot\/config\/opencode\//${HOME}\/ssot\/config\/opencode\/opencode_bedrock_proxy.py}" "${OC_PROXY_SCRIPT}" 2>/dev/null
            _oc_ok "Symlinked from SSOT"
        fi
    fi
    
    _oc_ok "Setup complete! Use: oc-bedrock start"
}

# ── Auto-start on shell init (optional) ──
if [[ "${BEDROCK_PROXY_AUTO_START:-}" == "true" ]] && \
   [[ -f "${OC_PROXY_SCRIPT}" ]] && \
   ! _oc_check_proxy_running 2>/dev/null; then
    # Only auto-start if opencode is likely to be used
    if [[ -n "${OPENCODE_SESSION:-}" ]] || \
       [[ "${PWD}" == *"opencode"* ]] || \
       [[ "${OLDPWD:-}" == *"opencode"* ]]; then
        _oc_start_proxy &>/dev/null &
    fi
fi

# ── Export key vars for child processes ──
export BEDROCK_MANTLE_REGION
export BEDROCK_PROXY_HOST
export BEDROCK_PROXY_PORT
export BEDROCK_PROXY_AUTO_START
