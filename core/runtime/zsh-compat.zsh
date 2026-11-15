# ============================================================
# core/runtime/zsh-compat.sh — Zsh -> Bash Compatibility Layer
# ============================================================
# Sourced by .zshrc BEFORE joe.sh so dual-shell modules work cleanly in Zsh.
# ============================================================

# ── 1. Safe Zsh shell options (TUI & micro safe: NO GLOB_SUBST / SH_WORD_SPLIT) ──
setopt NULL_GLOB 2>/dev/null
setopt NO_NOMATCH 2>/dev/null
unsetopt KSH_ARRAYS 2>/dev/null
unsetopt SH_WORD_SPLIT 2>/dev/null
unsetopt GLOB_SUBST 2>/dev/null

# ── 2. BASH_SOURCE array shim for Zsh top-level sourcing ──
if [[ -n "${ZSH_VERSION:-}" ]]; then
    typeset -g -a BASH_SOURCE 2>/dev/null
    BASH_SOURCE=("${(%):-%x}")
fi

# ── 3. Guard compdump for compinit ──
if ! autoload +X -U compdump 2>/dev/null && ! typeset -f compdump &>/dev/null; then
    compdump() { return 0; }
fi

# ── 4. Bash completion compatibility ──
if typeset -f compinit &>/dev/null || autoload +X -U compinit 2>/dev/null; then
    autoload -Uz bashcompinit 2>/dev/null && bashcompinit 2>/dev/null || true
fi

# ── 5. complete() & compgen() shims ──
if ! command -v complete &>/dev/null && ! typeset -f complete &>/dev/null; then
    complete() { :; }
fi
if ! command -v compgen &>/dev/null && ! typeset -f compgen &>/dev/null; then
    compgen() { :; }
fi

# ── 6. Unalias OMZ conflicts BEFORE SSOT load ──
unalias sudo sd rc stc _ ls ll la 2>/dev/null || true

# ── 7. Zsh-specific PATH helper ──
[[ -d /usr/local/bin ]] && export PATH="/usr/local/bin:$PATH"

# ── 8. mapfile / readarray shim (Bash 4+ builtin -> Zsh function) ──
if ! command -v mapfile &>/dev/null && ! typeset -f mapfile &>/dev/null; then
    mapfile() {
        local _var="" _line
        local -a _mf_lines=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -t) shift ;;
                -d|-n|-O|-s|-u|-C) shift 2 ;;
                -c) shift ;;
                --) shift; break ;;
                -*) shift ;;
                *)  _var="$1"; shift; break ;;
            esac
        done
        if [[ -z "$_var" ]]; then
            echo "mapfile: variable name required" >&2
            return 2
        fi
        if [[ -t 0 ]]; then
            eval "$_var=()"
            return 0
        fi
        while IFS= read -r _line; do
            _mf_lines+=("$_line")
        done
        eval "$_var=(\"\${_mf_lines[@]}\")"
    }
fi
if ! command -v readarray &>/dev/null && ! typeset -f readarray &>/dev/null; then
    readarray() {
        mapfile "$@"
    }
fi
