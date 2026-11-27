#!/usr/bin/env bash
# Install OpenCode + Bedrock Proxy config from SSOT
# Run this on any SSOT node to setup OpenCode integration

set -uo pipefail

# ── Colors ──
if [[ -t 2 ]]; then
    _c_red='\033[0;31m'
    _c_green='\033[0;32m'
    _c_yellow='\033[0;33m'
    _c_blue='\033[0;34m'
    _c_reset='\033[0m'
else
    _c_red='' _c_green='' _c_yellow='' _c_blue='' _c_reset=''
fi

_info() { echo -e "${_c_blue}[INSTALL]${_c_reset} $*" >&2; }
_ok() { echo -e "${_c_green}[INSTALL]${_c_reset} ✓ $*" >&2; }
_warn() { echo -e "${_c_yellow}[INSTALL]${_c_reset} ⚠ $*" >&2; }
_err() { echo -e "${_c_red}[INSTALL]${_c_reset} ✗ $*" >&2; }

# ── Paths ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSOT_ROOT="${SCRIPT_DIR}/../.."

AWS_DIR="${HOME}/.aws"
CONFIG_DIR="${HOME}/.config/opencode"
MODULES_DIR="${SSOT_ROOT}/modules/dev"

_info "Installing OpenCode + Bedrock Proxy configuration..."

# ── Check dependencies ──
_info "Checking dependencies..."

MISSING=()
for cmd in python3 python; do
    if command -v "${cmd}" &>/dev/null; then
        PYTHON="${cmd}"
        break
    fi
done

if [[ -z "${PYTHON:-}" ]]; then
    MISSING+=("python")
fi

# Check required Python packages
if [[ -n "${PYTHON:-}" ]]; then
    for pkg in fastapi uvicorn httpx botocore; do
        if ! ${PYTHON} -c "import ${pkg}" 2>/dev/null; then
            MISSING+=("python:${pkg}")
        fi
    done
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    _warn "Missing dependencies: ${MISSING[*]}"
    _info "Install with: pip install fastapi uvicorn httpx botocore"
fi

# ── Create directories ──
_info "Creating directories..."
mkdir -p "${AWS_DIR}"
mkdir -p "${CONFIG_DIR}/agents"
mkdir -p "${MODULES_DIR}"
_ok "Directories ready"

# ── Copy files ──
_info "Installing files..."

# Proxy scripts
cp "${SCRIPT_DIR}/bedrock_mantle_proxy.py" "${AWS_DIR}/"
cp "${SCRIPT_DIR}/opencode_bedrock_proxy.py" "${AWS_DIR}/"
_ok "Proxy scripts → ${AWS_DIR}"

# Config
cp "${SCRIPT_DIR}/settings.json" "${CONFIG_DIR}/"
_ok "Config → ${CONFIG_DIR}"

# Module
cp "${SSOT_ROOT}/modules/dev/opencode.sh" "${MODULES_DIR}/" 2>/dev/null || \
    _warn "Module file not found, skipping..."

# ── Make scripts executable ──
chmod +x "${AWS_DIR}/bedrock_mantle_proxy.py"
chmod +x "${AWS_DIR}/opencode_bedrock_proxy.py"
chmod +x "${MODULES_DIR}/opencode.sh" 2>/dev/null || true

# ── Create symlinks for updates ──
_info "Setting up SSOT sync..."

# Create marker file
echo "${SCRIPT_DIR}" > "${CONFIG_DIR}/.ssot_source"
_ok "SSOT sync configured"

# ── Module loader integration ──
_info "Checking module loader..."

if [[ -f "${SSOT_ROOT}/core/loader.sh" ]]; then
    _ok "Module loader found (will auto-load on next shell init)"
else
    _warn "Module loader not found. Add to your shell RC:"
    _info "  source ${MODULES_DIR}/opencode.sh"
fi

# ── Summary ──
echo ""
echo "=========================================="
_ok "Installation Complete!"
echo "=========================================="
echo ""
echo "Files installed:"
echo "  ${AWS_DIR}/bedrock_mantle_proxy.py"
echo "  ${AWS_DIR}/opencode_bedrock_proxy.py"
echo "  ${CONFIG_DIR}/settings.json"
echo "  ${MODULES_DIR}/opencode.sh"
echo ""
echo "Commands available:"
echo "  oc-bedrock start      - Start proxy"
echo "  oc-bedrock stop       - Stop proxy"
echo "  oc-bedrock status     - Check status"
echo "  oc-bedrock open       - Start proxy + OpenCode"
echo "  opencode-proxy-start  - Direct start"
echo "  opencode-with-proxy   - Proxy + OpenCode"
echo ""
echo "SSOT Benefits:"
echo "  ✓ Config syncs with your SSOT mesh"
echo "  ✓ Same settings on all devices"
echo "  ✓ Auto-detects environment"
echo "  ✓ SSH session aware"
echo ""
echo "Test installation:"
echo "  ${AWS_DIR}/opencode_bedrock_proxy.py status"
echo ""
