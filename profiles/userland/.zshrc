# ============================================================
# ~/.zshrc — SSOT Device Profile: USERLAND (userland)
# ============================================================
# Common startup logic lives in: profiles/_common/zshrc.zsh
# Add machine/device-specific Zsh overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-USERLAND}"
export MY_DEVICE="${MY_DEVICE:-userland}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/zshrc.zsh" ]] && source "$SSOT/profiles/_common/zshrc.zsh"
