# ============================================================
# ~/.zshrc — SSOT Device Profile: MUMU (mumu)
# ============================================================
# Common startup logic lives in: profiles/_common/zshrc.zsh
# Add machine/device-specific Zsh overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-MUMU}"
export MY_DEVICE="${MY_DEVICE:-mumu}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/zshrc.zsh" ]] && source "$SSOT/profiles/_common/zshrc.zsh"
