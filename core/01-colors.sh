#!/usr/bin/env bash
# ============================================================
# core/01-colors.sh — SSOT Color Engine Loader (with Safe Fallback)
# ============================================================
# Priority:
#   1. Bundled SSOT plugin: $SSOT/plugins/ez_colors/colors.sh (works on fresh clone!)
#   2. Local override:      $HOME/.ez_colors/colors.sh (ifEZ_COLORS_LOCAL=1 or plugin missing)
#   3. Built-in minimal fallback (guarantees c/cn/color/psc/rc/hline never fail)
# ============================================================

_SSOT_COLOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" 2>/dev/null && pwd)"
_SSOT_ROOT_GUESS="$(cd "$_SSOT_COLOR_DIR/.." 2>/dev/null && pwd)"

if [[ "${EZ_COLORS_LOCAL:-0}" == "1" && -f "$HOME/.ez_colors/colors.sh" ]]; then
    source "$HOME/.ez_colors/colors.sh"
elif [[ -f "${SSOT:-$_SSOT_ROOT_GUESS}/plugins/ez_colors/colors.sh" ]]; then
    source "${SSOT:-$_SSOT_ROOT_GUESS}/plugins/ez_colors/colors.sh"
elif [[ -f "$HOME/.ez_colors/colors.sh" ]]; then
    source "$HOME/.ez_colors/colors.sh"
fi

unset _SSOT_COLOR_DIR _SSOT_ROOT_GUESS

# ── Minimal built-in fallback (only if ez_colors failed to load) ──
if ! command -v c >/dev/null 2>&1; then
    c() {
        local code="${1:-7}"; shift 2>/dev/null || true
        [[ "${1:-}" =~ ^[bdiu]+$ ]] && shift
        printf '\e[38;5;%sm%s\e[0m' "$code" "$*"
    }
    cn() { c "$@"; printf '\n'; }
    color() { c "$@"; printf '\n'; }
    psc() { c "$@"; }
    rc() { [[ "${1:-}" =~ ^[bdiu]+$ ]] && shift; printf '%s\n' "$*"; }
    rc1() { rc "$@"; }
    rc2() { rc "$@"; }
    hline() { printf '%s\n' "────────────────────────────────────────────────────"; }
    ctab() { printf '%s\n' "$@"; }
fi
