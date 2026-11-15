# ============================================================
# ~/.zshrc — SSOT Device Profile: ACODEX (acodex)
# ============================================================
# Common startup logic lives in: profiles/_common/zshrc.zsh
# Add machine/device-specific Zsh overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-ACODEX}"
export MY_DEVICE="${MY_DEVICE:-acodex}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/zshrc.zsh" ]] && source "$SSOT/profiles/_common/zshrc.zsh"
