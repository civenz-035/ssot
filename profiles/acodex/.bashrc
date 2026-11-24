# ============================================================
# ~/.bashrc — SSOT Device Profile: ACODEX (acodex)
# ============================================================
# Common startup logic lives in: profiles/_common/bashrc.sh
# Add machine/device-specific Bash overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-ACODEX}"
export MY_DEVICE="${MY_DEVICE:-acodex}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/bashrc.sh" ]] && source "$SSOT/profiles/_common/bashrc.sh"

# Added by simulator install script
[[ -f '/home/simulator/lib/alias.sh' ]] && source '/home/simulator/lib/alias.sh'
