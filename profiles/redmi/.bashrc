# ============================================================
# ~/.bashrc — SSOT Device Profile: REDMI (redmi)
# ============================================================
# Common startup logic lives in: profiles/_common/bashrc.sh
# Add machine/device-specific Bash overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-REDMI}"
export MY_DEVICE="${MY_DEVICE:-redmi}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/bashrc.sh" ]] && source "$SSOT/profiles/_common/bashrc.sh"
