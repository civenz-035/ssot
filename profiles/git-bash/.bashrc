# ============================================================
# ~/.bashrc — SSOT Device Profile: GIT-BASH (git-bash)
# ============================================================
# Common startup logic lives in: profiles/_common/bashrc.sh
# Add machine/device-specific Bash overrides below if needed.
# ============================================================
export JOE_ENV="${JOE_ENV:-GIT-BASH}"
export MY_DEVICE="${MY_DEVICE:-git-bash}"
export SSOT="${SSOT:-$HOME/ssot}"

[[ -f "$SSOT/profiles/_common/bashrc.sh" ]] && source "$SSOT/profiles/_common/bashrc.sh"
