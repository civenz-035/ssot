# ============================================================
# ~/.zshrc — SSOT Device Profile: REDMI (redmi)
# ============================================================
# Common startup logic lives in: profiles/_common/zshrc.sh
# Add machine/device-specific Zsh overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-REDMI}"
export MY_DEVICE="${MY_DEVICE:-redmi}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/zshrc.sh" ]] && source "$SSOT/profiles/_common/zshrc.sh"
