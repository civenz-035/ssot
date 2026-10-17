#!/usr/bin/env bash
# ============================================================
# 🌐 node-mesh.sh — SSOT Node Registry, Mesh Network & Path Resolution
# ============================================================
# Purpose: Central Single Source of Truth for:
#   1. SSH Port Registry (machine-independent constants)
#   2. Tailscale IPs & Mesh network detection
#   3. Dynamic Node Registry Loader (bootstrap/nodes/*.node.env)
#   4. Cross-Platform Path Resolution (Termux ↔ WSL ↔ Git-Bash)
#   5. Backward-Compatible Node Aliases (NODE_* -> legacy vars)
#
# Load order: Sourced by shared/00-env.sh
# Compatible: TERMUX · MUMU · OPPO · WSL · WSL2 · GIT-BASH · ACODEX
# ============================================================

# ============================================================
# 1. SSH PORT REGISTRY (Standard Multi-Node Ports)
# ============================================================
export SSH_WIN_PORT=22
export SSH_MUMU_PORT=8020
export SSH_ACODEX_PORT=8021
export SSH_TERMUX_PORT=8022
export SSH_OPPO_PORT=8023
export SSH_WSL_PORT=2222
export SSH_WSL2_PORT=2223

# ============================================================
# 2. TAILSCALE MESH NETWORK DETECTION & FIXED NODE IPS
# ============================================================
if command -v tailscale >/dev/null 2>&1; then
    export TAILSCALE_BIN="tailscale"
    if [[ "${JOE_ENV:-}" != "GIT-BASH" ]]; then
        export TAILSCALE_STATUS="$(tailscale status 2>/dev/null || echo "tailscale not running")"
        export TAILSCALE_IP="$(tailscale ip -4 2>/dev/null || echo "tailscale not running")"
    else
        export TAILSCALE_STATUS="available"
        export TAILSCALE_IP="100.69.181.45"
    fi
else
    export TAILSCALE_STATUS="tailscale not running"
    export TAILSCALE_IP="tailscale not running"
fi

# Canonical Tailscale IPs (Fallback if DNS/MagicDNS is slow)
export TAILSCALE_IP_TERMUX=100.110.26.16
export TAILSCALE_IP_WINDOW=100.69.181.45
export TAILSCALE_IP_WSL=100.80.195.120
export TAILSCALE_IP_MUMU=100.100.176.94
export TAILSCALE_IP_OPPO=100.82.29.18
export TAILSCALE_IP_WSL2=100.93.45.16

# ============================================================
# 3. DYNAMIC NODE REGISTRY LOADER
# ============================================================
# Auto-loads drop-in node profiles from $SSOT/bootstrap/nodes/*.node.env
# Schema per node: NODE_<NAME>_{HOST,USER,PORT,ST_PORT,ST_KEY,ST_ID,ST_URL}
_SSOT_ROOT="${SSOT:-$HOME/ssot}"
if [[ -f "${_SSOT_ROOT}/bootstrap/nodes/loader.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_SSOT_ROOT}/bootstrap/nodes/loader.sh"
fi

# ============================================================
# 4. CROSS-PLATFORM PATH RESOLUTION (THE 3 WORLDS)
# ============================================================
# When transferring files (rsync, scp) cross-device, path format depends on
# the TARGET machine's filesystem driver:
#
# ┌──────────────┬─────────────────────────────┬────────────────────────────────────┐
# │ Target Node  │ Path Style                  │ Example                            │
# ├──────────────┼─────────────────────────────┼────────────────────────────────────┤
# │ window (GB)  │ MSYS / Git-Bash (/c/...)    │ /c/Users/User/Desktop/project      │
# │ wsl / wsl2   │ Linux native / mount (/mnt) │ /mnt/c/Users/User or /home/joez    │
# │ termux/mumu  │ Android Termux / sdcard     │ /data/data/com.termux/files/home   │
# └──────────────┴─────────────────────────────┴────────────────────────────────────┘
#
# NOTE: Over SSH/rsync to Windows, NEVER use 'C:\...' (colon breaks remote rsync).
#       ALWAYS use '/c/...' for Windows node target!

# Convert any Windows path (C:\..., /mnt/c/..., \...) to Git-Bash MSYS format (/c/...)
path_to_win() {
    local p="${1:-}"
    # Replace backslashes with slashes
    p="${p//\\//}"
    # Convert /mnt/c/... -> /c/...
    p="${p/#\/mnt\/c\//\/c\/}"
    # Convert C:/... or c:/... -> /c/...
    if [[ "$p" =~ ^[a-zA-Z]:/(.*) ]]; then
        local drive="${p:0:1}"
        drive="$(echo "$drive" | tr '[:upper:]' '[:lower:]')"
        p="/${drive}/${p:3}"
    fi
    printf '%s' "$p"
}

# Convert any Windows path (C:\..., /c/..., \...) to WSL format (/mnt/c/...)
path_to_wsl() {
    local p="${1:-}"
    p="${p//\\//}"
    # Convert /c/... -> /mnt/c/...
    p="${p/#\/c\//\/mnt\/c\/}"
    # Convert C:/... -> /mnt/c/...
    if [[ "$p" =~ ^[a-zA-Z]:/(.*) ]]; then
        local drive="${p:0:1}"
        drive="$(echo "$drive" | tr '[:upper:]' '[:lower:]')"
        p="/mnt/${drive}/${p:3}"
    fi
    printf '%s' "$p"
}

# Universal cross-node path resolver
# Usage: resolve_remote_path <node> <path>
resolve_remote_path() {
    local node="${1:-}"
    local path="${2:-}"
    case "$node" in
        w|win|window|WINDOW|gb|gitbash)
            path_to_win "$path"
            ;;
        wsl|WSL|wsl2|WSL2)
            path_to_wsl "$path"
            ;;
        *)
            printf '%s' "$path"
            ;;
    esac
}

# ============================================================
# 5. BACKWARD-COMPATIBILITY LAYER (Phase 1)
# ============================================================
# Legacy consumers expect these variable names.
# Mapped directly from Node Registry (loader.sh).

# Windows (Host / Git-Bash)
export WINDOWS_IP="${NODE_WIN_HOST:-${NODE_WIN_IP:-100.69.181.45}}"
export WINDOWS_USER="${NODE_WIN_USER:-User}"
export ST_KEY_WIN="${NODE_WIN_ST_KEY:-}"
export ST_PORT_WIN="${NODE_WIN_ST_PORT:-8384}"
export URL_WIN="${NODE_WIN_ST_URL:-http://window:8384}/"

# Canonical 8.3 short path (prevents quoting & space bugs over SSH / PowerShell)
export WIN_GIT_BASH="C:/PROGRA~1/Git/bin/bash.exe"

# Termux
export TERMUX_IP="${NODE_TERMUX_HOST:-${NODE_TERMUX_IP:-100.110.26.16}}"
export TERMUX_USER="${NODE_TERMUX_USER:-u0_a331}"
export TERMUX_PORT="${NODE_TERMUX_PORT:-8022}"
export TERMUX_TELSCAIL_IP="${NODE_TERMUX_HOST:-termux}"
export ST_KEY_TERMUX="${NODE_TERMUX_ST_KEY:-}"
export ST_PORT_TERMUX="${NODE_TERMUX_ST_PORT:-8384}"
export URL_TERMUX="${NODE_TERMUX_ST_URL:-http://termux:8384}/"

# WSL (Ubuntu)
export WSL_IP="${NODE_WSL_HOST:-${NODE_WSL_IP:-100.80.195.120}}"
export WSL_USER="${NODE_WSL_USER:-usercivenz}"
export WSL_TELSCAIL_IP="${NODE_WSL_HOST:-wsl}"
export ST_KEY_WSL="${NODE_WSL_ST_KEY:-}"
export ST_PORT_WSL="${NODE_WSL_ST_PORT:-8384}"
export URL_WSL="${NODE_WSL_ST_URL:-http://wsl:8384}/"

# WSL2 (Ubuntu-22.04)
export WSL2_IP="${NODE_WSL2_HOST:-${NODE_WSL2_IP:-100.93.45.16}}"
export WSL2_USER="${NODE_WSL2_USER:-joez}"
export WSL2_TELSCAIL_IP="${NODE_WSL2_HOST:-wsl2}"
export ST_KEY_WSL2="${NODE_WSL2_ST_KEY:-}"
export ST_PORT_WSL2="${NODE_WSL2_ST_PORT:-8384}"
export URL_WSL2="${NODE_WSL2_ST_URL:-http://wsl2:8384}/"

# MUMU Player
export MUMU_IP="${NODE_MUMU_HOST:-${NODE_MUMU_IP:-100.100.176.94}}"
export MUMU_USER="${NODE_MUMU_USER:-u0_a62}"
export MUMU_PORT="${NODE_MUMU_PORT:-8020}"
export MUMU_TELSCAIL_IP="${NODE_MUMU_HOST:-mumu}"
export ST_KEY_MUMU="${NODE_MUMU_ST_KEY:-}"
export ST_PORT_MUMU="${NODE_MUMU_ST_PORT:-8384}"
export URL_MUMU="${NODE_MUMU_ST_URL:-http://mumu:8384}/"

# OPPO
export OPPO_IP="${NODE_OPPO_HOST:-${NODE_OPPO_IP:-100.82.29.18}}"
export OPPO_USER="${NODE_OPPO_USER:-u0_a88}"
export OPPO_PORT="${NODE_OPPO_PORT:-8023}"

# ACODEX
export ACODEX_IP="${NODE_ACODEX_HOST:-${NODE_ACODEX_IP:-100.110.26.16}}"
export ACODEX_USER="${NODE_ACODEX_USER:-root}"
export ACODEX_PORT="${NODE_ACODEX_PORT:-8021}"
