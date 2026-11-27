#!/bin/bash
# ============================================================
# core/aliases.sh — Canonical Shell Aliases (SSOT)
# ============================================================
# Dependencies: core/00-env.sh
# ============================================================

# ── 1. Standard Colorized Listing & Search ──
alias ls='ls --color=auto'
alias la='ls -A'
alias l='ls -CF'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

case "${_SHELL:-}" in
    zsh)  unbinding -a g  >/dev/null 2>&1 || true ;;
    bash) unbinding -a ll >/dev/null 2>&1 || true ;;
esac

# ── 2. Directory Shortcuts (from 00-env.sh) ──
alias htm='cd "$htm"'
alias hwsl='cd "$HWSL"'
alias hpc='cd "$hpc"'
alias hmp='cd "$hmp"'
alias ssot='cd "$SSOT" && pwd'
alias cdrp='cd "$SSOT" && cn 45 b "$PWD"'
alias sim='cd "$sim" && pwd'
alias cdd='cd "$DICE_SIM_DIR" && pwd'
alias mhp='cd "$mhp" && pwd'
alias dbp='cd "$DASHBOARD_DIR"'
alias sdc='cd "$SDCARD_PATH" && pwd'
alias cdboom='cd "$boom"'
alias bkboom='cd "$bk_boom"'

# ── 3. System & File Manager ──
alias ktmux='tmux kill-server'
ll() { fm lsa "$@"; }

# Syncthing (WSL)
alias s-start="(syncthing serve --gui-address=0.0.0.0:${NODE_WSL_ST_PORT:-8385} &)"
alias s-stop="pkill -f 'syncthing serve' && echo 'WSL Syncthing stopped'"
alias s-status="ss -tlnp | grep ${NODE_WSL_ST_PORT:-8385} && echo 'WSL Syncthing: RUNNING' || echo 'WSL Syncthing: STOPPED'"
alias s-log="tail -20 \"$HOME/.local/state/syncthing/syncthing.log\" 2>/dev/null || echo 'No log found'"

# Build & Project runners
alias fbrun='full_pipe'
alias rbdb='rbfe && opdb'

# ── 4. SSOT Core CLI Tools (bin/) ──
alias jenv='cn lg b "$JOE_ENV"'
alias repos='cn lg b "$SSOT"'
alias envm='bash "${SSOT:-$HOME/ssot}/bin/env-manager.sh"'
alias envmgr='bash "${SSOT:-$HOME/ssot}/bin/env-manager.sh"'
alias ssotdb='bash "${SSOT:-$HOME/ssot}/bin/dashboard.sh"'
alias db='bash "${SSOT:-$HOME/ssot}/bin/dashboard.sh"'
alias cltui='bash "${SSOT:-$HOME/ssot}/bin/dist-tui.sh"'

# Mesh Sync (git across ssot nodes)
alias meshsync='bash "${SSOT:-$HOME/ssot}/bin/mesh-sync.sh"'
alias ms='bash "${SSOT:-$HOME/ssot}/bin/mesh-sync.sh"'
alias mst='bash "${SSOT:-$HOME/ssot}/bin/mesh-sync.sh" status'
alias msp='bash "${SSOT:-$HOME/ssot}/bin/mesh-sync.sh" pull'
alias mso='bash "${SSOT:-$HOME/ssot}/bin/mesh-sync.sh" push'
alias msfp='bash "${SSOT:-$HOME/ssot}/bin/mesh-sync.sh" fanpull'
alias msfq='bash "${SSOT:-$HOME/ssot}/bin/mesh-sync.sh" fanpush'

# ── 5. SSOT Vault, Nodes & SSH Audit (bootstrap/) ──
alias vault='bash "${SSOT:-$HOME/ssot}/bootstrap/vault/ssot-vault.sh"'
alias ssot-vault='bash "${SSOT:-$HOME/ssot}/bootstrap/vault/ssot-vault.sh"'
alias secret-setup='bash "${SSOT:-$HOME/ssot}/bootstrap/vault/secret-setup.sh"'
alias node-register='bash "${SSOT:-$HOME/ssot}/bootstrap/nodes/node-register.sh"'
alias node-status='bash "${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh"'
alias nodestatus='bash "${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh"'
alias ns='bash "${SSOT:-$HOME/ssot}/bootstrap/nodes/node-status.sh"'
alias ssh-audit='bash "${SSOT:-$HOME/ssot}/bootstrap/scripts/ssh_audit.sh"'

# ── 6. External Companion Projects (codetrans & dice-simulator) ──
alias py='python3'
export b2p_path="${CODETRANS_DIR:-$HOME/projects/codetrans}/codetrans.py"
alias b2p='bash "${CODETRANS_DIR:-$HOME/projects/codetrans}/b2p.sh"'
alias 2py='"${_py:-python3}" "$b2p_path"'

alias dice='bash "$DICE_SIM_DIR/bin/roll.sh"'
alias dicepy='"${_py:-python3}" "$DICE_SIM_DIR/bin/roll.py"'
alias dcf='micro "$DICE_SIM_DIR/config/dice.env"'

export spacing='<  >   copy  spacing inside <>'
alias agt='cd "$agt" && pwd'

alias wbot='cd "$wbot" && pwd'
alias wrc="winrate_cal"

# ── 7. Module Auto-Loaders ──
# NOTE: opencode.sh & daily_use.sh are auto-discovered by ssot_load() in joe.sh.
# No manual sourcing needed here — avoids double-load.
