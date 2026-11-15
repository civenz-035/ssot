# ============================================================
# ~/.zshrc — SSOT Device Profile: TERMUX (termux)
# ============================================================
# Common startup logic lives in: profiles/_common/zshrc.zsh
# Add machine/device-specific Zsh overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-TERMUX}"
export MY_DEVICE="${MY_DEVICE:-termux}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/zshrc.zsh" ]] && source "$SSOT/profiles/_common/zshrc.zsh"
