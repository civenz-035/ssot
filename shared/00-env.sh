#!/bin/bash
# ============================================================
# 00-env.sh — Environment Variables & Paths (CANONICAL)
# ============================================================
# This is the SINGLE SOURCE OF TRUTH for all environment
# variables. Set by boot.sh Stage 2, after JOE_ENV detected.
#
# NOTE: Core paths (SCRIPTS_PATH, JOE_ENV, hpc, htm, hwsl,
# NODE_BIN, dbp, OPENCLAW_BIN) are set by boot.sh Stage 0.
# This file ONLY sets derived/secondary variables.
#
# All paths use variables from boot.sh (no hardcoded paths).
# This ensures it works across all environments: WSL, Termux,
# Linux, and Git Bash on Windows.
#
# Stage: 2 (after boot.sh Stage 0 and 00-bootstrap.sh)
# Dependencies: JOE_ENV, hpc, htm, hwsl, dbp, HOME, SCRIPTS_PATH
# ============================================================

# ============================================================
# ── 0. LOCAL SECRETS & OVERRIDES (SSOT) ──
# Loads private credentials and machine overrides.
# 1. Machine Config (local only, never in git/vault): ~/.env
if [[ -f "$HOME/.env" ]]; then
    source "$HOME/.env"
elif [[ -f "${SSOT:-$HOME/ssot}/.env" ]]; then
    source "${SSOT:-$HOME/ssot}/.env"
elif [[ -f "${SCRIPTS_PATH:-$HOME/ssot}/.env" ]]; then
    source "${SCRIPTS_PATH:-$HOME/ssot}/.env"
fi

# 2. Shared Secrets (decrypted from vault): ~/.env.secret
if [[ -f "$HOME/.env.secret" ]]; then
    source "$HOME/.env.secret"
elif [[ -f "${SSOT:-$HOME/ssot}/.env.secret" ]]; then
    source "${SSOT:-$HOME/ssot}/.env.secret"
fi

# ============================================================
# 1. WORKSPACE PATHS (PATH RESOLVED NODE MESH NETWORK) 
# ============================================================


case "$JOE_ENV" in
    TERMUX)
         export HTM="/data/data/com.termux/files/home"
         export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
         export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
         export SDCARD_PATH="/storage/emulated/0/"
         export NODE_HOST="termux"
         export PYTHON_BIN="/data/data/com.termux/files/usr/bin/python3.14"
         
         ;;
    MUMU)
         export HTM="/data/data/com.termux/files/home"
         export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
         export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
         export SDCARD_PATH="/storage/emulated/0/"
         export NODE_HOST="mumu"
         ;;
    OPPO)
         export HTM="/data/data/com.termux/files/home"
         export HERMES_DIR="/data/data/com.termux/files/home/.hermes"
         export PYTHON_VENV="$HOME/.dash_venv/bin/activate"
         export SDCARD_PATH="/storage/emulated/0/"
         export NODE_HOST="oppo"
         ;;
    ACODEX)
         export HTM="/data/data/com.termux/files/home"
         export NODE_HOST="acodex"
         ;;
	WSL)
				 export HTM="/data/data/com.termux/files/home"
         export HERMES_DIR="$HOME/.hermes"
         export PYTHON_VENV="$HOME/.venv/bin/activate"
         export NODE_HOST="wsl"
         export WIN_PATH="/mnt/"
         export HWSL="$HOME"
         export HWSL2="unseen"
         export PYTHON_BIN="$HOME/.local/bin/python3"
         export hpc="/mnt/c/Users/User"
         ;;
    WSL2)

				 export HTM="/data/data/com.termux/files/home"		
         export HERMES_DIR="$HOME/.hermes"
         export PYTHON_VENV="$HOME/.venv/bin/activate"
         export NODE_HOST="wsl2"
         export WIN_PATH="/mnt/"
         export HWSL="unseen"
         export HWSL2="$HOME"
         export PYTHON_BIN="$HOME/.local/bin/python3.11"
         export hpc="/mnt/c/Users/User"
         ;;
    GIT-BASH)
				 export HTM="/data/data/com.termux/files/home"	
         export HERMES_DIR="$HOME/AppData/Local/hermes"
         export PYTHON_VENV="$HOME/.venv/bin/activate"
         export NODE_HOST="window"
         export WIN_PATH='/'
         export HWSL="//wsl.localhost/Ubuntu/home/usercivenz"
         export HWSL2="//wsl.localhost/Ubuntu-22.04/home/joez"
         export PYTHON_BIN="$HOME/AppData/Local/Programs/Python/Python39/python"
         export hpc="$HOME"

         ;;
    *)
				 export HTM="/data/data/com.termux/files/home"
         export PYTHON_VENV="$htm/.dash_venv/bin/activate"
         export NODE_HOST="linux"
         ;;
esac

# ============================================================
# 1.5 DERIVED PATHS (per JOE_ENV) — migrated from joe.sh
# ============================================================
case "$JOE_ENV" in
    TERMUX)
        export DASHBOARD_DIR="$HOME/dashboard"
        export OBSIDIAN_VAULT="/storage/emulated/0/syncthing/hermes_vault"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=8022
        ;;
    MUMU)
        export DASHBOARD_DIR="$HOME/dashboard"
        export OBSIDIAN_VAULT="/storage/emulated/0/syncthing/hermes_vault"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=8020
        ;;
    OPPO)
        export DASHBOARD_DIR="$HOME/dashboard"
        export OBSIDIAN_VAULT="/storage/emulated/0/syncthing/hermes_vault"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=8023
        ;;
    ACODEX)
        export DASHBOARD_DIR="$HOME/dashboard"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=8021
        ;;
    WSL)
        export DASHBOARD_DIR="$HOME/dashboard"
        export OBSIDIAN_VAULT="$hpc/DESKTOP/obsidian/alphadev_vaults"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$hpc/DESKTOP/main_sync"
        export SSH_PORT=2222
        ;;
    WSL2)
        export DASHBOARD_DIR="$HOME/dashboard"
        export OBSIDIAN_VAULT="$hpc/DESKTOP/obsidian/alphadev_vaults"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$hpc/DESKTOP/main_sync"
        export SSH_PORT=2223
        ;;
    GIT-BASH)
        export DASHBOARD_DIR="$HWSL2/dashboard"
        export OBSIDIAN_VAULT="$hpc/DESKTOP/obsidian/alphadev_vaults"
        export nexus_vault="$hpc/DESKTOP/nexus_vault"
        export MAIN_SYNC_DIR="$hpc/DESKTOP/main_sync"
        export home="$HOME"
        export SSH_PORT=2222
        ;;
    *)
        export DASHBOARD_DIR="$HOME/dashboard"
        export home="$HOME"
        export nexus_vault="$HOME/nexus_vault"
        export MAIN_SYNC_DIR="$HOME/main_sync"
        export SSH_PORT=22
        ;;
esac

export WIN="win"
export WSL="wsl"
export WSL2="wsl2"
export h="${HOME#$HOME/\~}"  # -- display string ~ instead of long path of home dir
export MATHS_HELPER_DIR="$HOME/.maths-helper"
export DICE_SIM_DIR="$HOME/simulator"
export dsd="$DICE_SIM_DIR"
export _py=${PYTHON_BIN}
export hwsl=${HWSL}
export hwsl2=${HWSL2}
export ssot="$HOME/ssot"
export profile=mom
export dpc="$hpc/Desktop"
export dtpc="$hpc/Desktop"          # compat alias ของ dpc
export hmp="${HERMES_DIR:-$HOME/.hermes}"   # AGENT.md: hmp = $HOME/.hermes
export HERMES_LOG_DIR="${HERMES_DIR}/logs"  # log dir สำหรับ tools/hermes.sh
export BRAVE_SEARCH_API_KEY="${BRAVE_SEARCH_API_KEY:-}"
export BRAVE_API_KEY="${BRAVE_API_KEY:-$BRAVE_SEARCH_API_KEY}"
export ALPHA_DIR="$msync/alpha-workspace"
export alpha=${ALPHA_DIR}
export storage="/storage/emulated/0/" # sdcrd
export ais_fiber="880-563-6522"
export ais_phone="0814764210"
export space="\u2003\u2003\u2003\u2003"
export bin="$HOME/.local/bin"
export pc_bin="$hpc/.local/bin"
export wsl_bin="$hwsl/.local/bin"
export wsl2_bin="$hwsl2/.local/bin"

if [[ -n "${ZSH_VERSION:-}" ]]; then
    export _SHELL="zsh"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    export _SHELL="bash"
else
    export _SHELL="${_SHELL:-${SHELL##*/}}"
fi
export _USER="${USER:-${USERNAME:-$(whoami 2>/dev/null)}}"

# ── Global constants migrated from joe.sh ──
export SCRIPTS_PATH="${SSOT:-$HOME/ssot}"
export COLOR_PATH="${SSOT:-$HOME/ssot}"
export htm="/data/data/com.termux/files/home"   # Termux home (cross-env ref)
export OP_DIR="${HOME}"
export msync="${MAIN_SYNC_DIR}"
# SSH port registry (machine-independent constants)
export SSH_MUMU_PORT=8020
export SSH_TERMUX_PORT=8022
export SSH_OPPO_PORT=8023
export SSH_ACODEX_PORT=8021
export SSH_WSL_PORT=2222
export SSH_WSL2_PORT=2223
export SSH_WIN_PORT=22
export pftermux="${SSOT}/profiles/termux"
export ptwsl="${SSOT}/profiles/wsl"
export pfmumu="${SSOT}/profiles/mumu"
export pfwin="${SSOT}/profiles/git-bash"
# ============================================================
# SupperBoom env
# ============================================================

export ssboom="${WIN_PATH}c/Users/User/Documents/mumusharedfolder/Screenshots"
export vdoboom="${WIN_PATH}c/Users/User/Documents/MuMuSharedFolder/VideoRecords"
export bk_vdoboom="${WIN_PATH}h/boom/VideoRecords"
export bk_ssboom="${WIN_PATH}h/boom/Screenshots"


# Dice Simulator — standalone repo (github.com/civenz-035/dice-simulator)
export DICE_SIM_DIR="${DICE_SIM_DIR:-$HOME/simulator}"

# ============================================================
# 3. PYTHON & VIRTUAL ENVIRONMENT
# ============================================================


# Python activation script
export DASHBOARD_PYTHON="$PYTHON_VENV"

# Python I/O encoding
export PYTHONIOENCODING="utf-8"

# ============================================================
# 3.5 MATH HELPER DEFAULTS (used by m() in 00.1-function-tools.sh)
# ============================================================
# Excel-style: default 2 decimals, round-half-up
# (was :-0 which truncated everything to integers; matches maths.sh fallback)
export MATH_DEFAULT_SCALE="${MATH_DEFAULT_SCALE:-2}"
export MATH_DEFAULT_MODE="${MATH_DEFAULT_MODE:-round}"   # round | up | down

# ============================================================
# 4. NODE & BUILD SETTINGS
# ============================================================

export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache

# ============================================================
# 5. OPENCLAW CONFIGURATION
# ============================================================

export OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1
export OPENCLAW_NO_RESPAWN=1
export CURRENT_OC_PROFILE="${CURRENT_OC_PROFILE:-None (Default)}"

# ============================================================
# 6. NODE REGISTRY & MESH NETWORK (Centralized in core/node-mesh.sh)
# ============================================================
if [[ -f "${SSOT:-$HOME/ssot}/core/node-mesh.sh" ]]; then
    source "${SSOT:-$HOME/ssot}/core/node-mesh.sh"
fi

# ============================================================
# EXPORTS COMPLETE — Ready for use in aliases and functions
# All paths are environment-aware and work across WSL, Termux, Linux, Git Bash
# ============================================================

# --- SHORT CUT FOR JOE-- #
export nx="$nexus_vault"
export USDT_BEP20_BITKUB="${USDT_BEP20_BITKUB:-}"
export SOL_BITKUB="${SOL_BITKUB:-}"
export SOL_METAMAS="${SOL_METAMAS:-}"
export BTC_BITKUB="${BTC_BITKUB:-}"
export HOME_ADDRESS="${HOME_ADDRESS:-}"


# ============================================================
#--FB PAGE
# ============================================================

# - lookforward
export FACEBOOK_PAGE_TOKEN="${FACEBOOK_PAGE_TOKEN:-}"

export FACEBOOK_PAGE_ID="${FACEBOOK_PAGE_ID:-}"

# -- Shpee page คัดแต่สิ่งที่คุณคู้ควร
export SHOPEE_PAGE_TOKEN="${SHOPEE_PAGE_TOKEN:-}"

export SHOPEE_PAGE_ID="${SHOPEE_PAGE_ID:-}"

# ── OpenCode Go zen (Joe's preferred AI provider) ──
# Key pool: แยกตาม profile เพื่อกันปนกันและ track อายุการใช้งาน
# Schema: $OC_KEY_<PROFILE>    — secret (per-profile)
#         $OC_BASE_URL         — OpenCode Go API endpoint (shared)

# ของแม่ (mom) — key ใหม่ต่อวันที่ 2026-07-25
export OC_KEY_MOM="${OC_KEY_MOM:-}"

# ของพี่โจ (joe) — key เก่า ใช้ได้ปกติ
export OC_KEY_JOE="${OC_KEY_JOE:-}"

# OpenCode Zen (joe เท่านั้น — ใช้ Claude Sonnet)
export OC_KEY_ZEN="${OC_KEY_ZEN:-}"

# Shared endpoint
export OC_BASE_URL="https://opencode.ai/zen/go/v1"

# Aliases กลาง — backward compat (alias เก่าที่หลายไฟล์เรียกใช้)
# Default follows $profile (mom). Override with:  pf joe  |  pf mom
# ai_profile() ใน joe.sh จะ overwrite ตอนสลับ profile
export OPENCODE_GO_API_KEY="$OC_KEY_MOM"
export OPENCODE_API_KEY="$OC_KEY_MOM"
export OPENCODE_ZEN_API_KEY="$OC_KEY_ZEN"
export OPENCODE_GO_BASE_URL="$OC_BASE_URL"

# ============================================================
# BACKUP — Single Source of Truth for backup paths
# ============================================================
# Override per-env by exporting BACKUP_DIR before sourcing.
# Default: ~/backups (cross-platform: works on WSL, Termux, Git Bash)
# Used by: bkp / bkpi / bkpl / bkls in functions/00.1-function-tools.sh
# ============================================================
export BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
mkdir -p "$BACKUP_DIR" 2>/dev/null

# ============================================================
# 7. DEFAULT EDITOR (JOE_ENV-aware)
# ============================================================
# SSOT rule: ตั้ง EDITOR/VISUAL ตาม environment เพื่อให้ทุก tool
# (git commit, crontab -e, sudoedit, npm config edit) เรียก editor
# ที่ถูกต้องอัตโนมัติ
#
# Joe's typical flow:
#   Windows Git Bash → ssh WSL (tw) → joe.sh loads → EDITOR=micro
#   WSL/TERMUX  → micro    (GUI-feel terminal editor)
#   GIT-BASH    → code     (VS Code ที่มีอยู่บน Windows) — fallback
#   fallback    → nano
# ============================================================

case "$JOE_ENV" in
    WSL|TERMUX|MUMU|WSL2)
        if command -v micro >/dev/null 2>&1; then
            export EDITOR="micro"
            export VISUAL="micro"
        else
            export EDITOR="nano"
            export VISUAL="nano"
        fi
        ;;
    GIT-BASH)
        # micro.exe ติดตั้งยากบน Git Bash → fallback เป็น VS Code
        if command -v code >/dev/null 2>&1; then
            export EDITOR="code --wait"
            export VISUAL="code --wait"
        elif command -v nano >/dev/null 2>&1; then
            export EDITOR="nano"
            export VISUAL="nano"
        else
            export EDITOR="notepad"
            export VISUAL="notepad"
        fi
        ;;
    *)
        export EDITOR="nano"
        export VISUAL="nano"
        ;;
esac
#-- Zshshell-setup



# -- cryto env

export BEP20_BK=0x5C7D1Da0862F8865C328c8CDE22B3C1168dA2740
export POL_BK=$BEP20_BK

export sim="$DICE_SIM_DIR"
export mhp="$MATHS_HELPER_DIR"

