#!/bin/bash
# ============================================================
# 🚀 JOE'S PERSONAL COMMAND CENTER — Main Entry Point (joe.sh)
# ============================================================
# Works across: TERMUX · MUMU · OPPO · WSL · WSL2 · GIT-BASH · ACODEX · USERLAND
# Both Bash 4+ and Zsh 5+ supported.
# ============================================================

# Mark loaded during RC init so legacy ~/.local/bin/env + .bashrc never double-source
if [[ "${_SSOT_RC_LOADING:-0}" == "1" ]]; then
    if [[ "${_JOE_LOADED_IN_RC:-0}" == "1" ]]; then
        return 0 2>/dev/null || exit 0
    fi
    _JOE_LOADED_IN_RC=1
fi

# ── Step 0: Resolve SSOT root & load core runtime helper ──
if [[ -z "${SSOT:-}" ]]; then
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        _joe_self="${(%):-%x}"
    elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        _joe_self="${BASH_SOURCE[0]}"
    else
        _joe_self="$HOME/ssot/joe.sh"
    fi
    SSOT="$(cd "$(dirname "$_joe_self")" 2>/dev/null && pwd)"
    export SSOT="${SSOT:-$HOME/ssot}"
    unset _joe_self
fi

if ! typeset -f _check >/dev/null 2>&1; then
    [[ -f "$SSOT/core/runtime/helper.sh" ]] && source "$SSOT/core/runtime/helper.sh"
fi

# ── Step 1: Detect JOE_ENV (respects existing JOE_ENV pinned in ~/.env) ──
export JOE_ENV="$(_check_ -j 2>/dev/null)"

# ── Step 2: CRLF Self-Heal (protects against Windows/Syncthing CRLF injection) ──
crlf() {
    if [[ "$JOE_ENV" != "GIT-BASH" ]] && command -v grep >/dev/null 2>&1 && command -v sed >/dev/null 2>&1; then
        local _crlf_files="" _crlf_count=0 _f=""
        _crlf_files="$(grep -rlU $'\r' "$SSOT" --include="*.sh" 2>/dev/null)"
        if [[ -n "$_crlf_files" ]]; then
            while IFS= read -r _f; do
                [[ -f "$_f" ]] || continue
                sed -i 's/\r$//' "$_f"
                _crlf_count=$((_crlf_count + 1))
            done <<< "$_crlf_files"
            echo "⚠️  CRLF auto-fixed: ${_crlf_count} file(s) → LF" >&2
        fi
    fi
}

# ── Step 3: Auto-start SSH daemon (stderr only — p10k instant-prompt safe) ──
auto_start_ssh() {
    if [[ "$JOE_ENV" == "WSL" || "$JOE_ENV" == "WSL2" ]]; then
        if ! service ssh status >/dev/null 2>&1; then
            sudo service ssh start >/dev/null 2>&1 \
                && { command -v cn &>/dev/null && cn 10 b "SSH Service (WSL) started." >&2; } \
                || { command -v cn &>/dev/null && cn 9 b "Failed to start SSH Service." >&2; }
        else
            command -v cn &>/dev/null && cn 10 bi "ssh activated port : ${SSH_PORT}" >&2
        fi
    elif [[ "$JOE_ENV" == "TERMUX" || "$JOE_ENV" == "MUMU" || "$JOE_ENV" == "OPPO" ]]; then
        if ! pgrep -f "sshd.*-p.*${SSH_PORT}" >/dev/null 2>&1; then
            sshd -p "$SSH_PORT" >/dev/null 2>&1 \
                && { command -v cn &>/dev/null && cn 10 b "SSH Daemon started on port ${SSH_PORT}." >&2; } \
                || { command -v cn &>/dev/null && cn 9 b "Failed to start sshd on port ${SSH_PORT}." >&2; }
        else
            command -v cn &>/dev/null && cn 10 bi "ssh activated port : ${SSH_PORT}" >&2
        fi
    elif [[ "$JOE_ENV" != "GIT-BASH" ]]; then
        if [[ -x /usr/sbin/sshd ]] && ! pgrep -f "sshd.*-p.*${SSH_PORT}" >/dev/null 2>&1; then
            /usr/sbin/sshd -p "$SSH_PORT" >/dev/null 2>&1 || true
        fi
    fi
}

# ── Step 4: Canonical Module Loader ──
ssot_load() {
    if ! typeset -f _check >/dev/null 2>&1; then
        [[ -f "$SSOT/core/runtime/helper.sh" ]] && source "$SSOT/core/runtime/helper.sh"
    fi

    # Reset per-load cache so `pp` / `refresh_shell` cleanly reloads modified files
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        typeset -gA _SSOT_SOURCED_FILES=() 2>/dev/null || true
    else
        declare -gA _SSOT_SOURCED_FILES=() 2>/dev/null || true
    fi

    local SHOW_LOAD="${1:-}"
    local -a source_files=(
        "$SSOT/core/01-colors.sh"
        "$SSOT/core/00-env.sh"
        "$SSOT/core/ssh-config.sh"
        "$SSOT/core/ssh_toolkit.sh"
        "$SSOT/core/3worlds.sh"
        "$SSOT/core/aliases.sh"
        "$SSOT/core/profiles.sh"
        "$SSOT/core/loader.sh"
        "$SSOT/plugins/joe_theme/plugin.sh"
    )

    # Auto-discover modules in priority category order:
    #   1. modules/system       — cross-platform system helpers
    #   2. modules/dev          — git toolkit, project runners, inspector
    #   3. modules/file-manager — lazy fm loader & file transfer (bash-manager.sh is lazy-loaded!)
    #   4. modules/personal     — personal daily commands & shortcuts
    #   5. Any future custom subfolder added under modules/<category>/*.sh
    local _cat="" _mod_sh=""
    for _cat in system dev file-manager personal; do
        if [[ -d "$SSOT/modules/$_cat" ]]; then
            while IFS= read -r _mod_sh; do
                [[ -f "$_mod_sh" ]] || continue
                [[ "${_mod_sh##*/}" == "bash-manager.sh" ]] && continue
                source_files+=("$_mod_sh")
            done < <(find "$SSOT/modules/$_cat" -maxdepth 1 -type f -name "*.sh" ! -name ".*" | LC_ALL=C sort)
        fi
    done

    if [[ -d "$SSOT/modules" ]]; then
        local _extra_sh=""
        while IFS= read -r _extra_sh; do
            [[ -f "$_extra_sh" ]] && source_files+=("$_extra_sh")
        done < <(find "$SSOT/modules" -mindepth 2 -type f -name "*.sh" \
            ! -path "$SSOT/modules/system/*" \
            ! -path "$SSOT/modules/dev/*" \
            ! -path "$SSOT/modules/file-manager/*" \
            ! -path "$SSOT/modules/personal/*" \
            ! -name ".*" | LC_ALL=C sort)
    fi

    _check -f "source_files" "source" 2>/dev/null

    # Optional visual load summary: `pp 1` or `ssot_load true`
    if [[ -n "${SHOW_LOAD}" && "${SHOW_LOAD}" =~ ^(true|1|yes)$ ]]; then
        local -a basen_files=()
        local max_len=0 sf="" f_name="" file_name="" len=0 padding=0
        for sf in "${source_files[@]}"; do
            if [[ -f "$sf" ]]; then
                f_name="${sf##*/}"
                basen_files+=("$f_name")
                len=${#f_name}
                (( len > max_len )) && max_len=$len
            fi
        done
        for file_name in "${basen_files[@]}"; do
            padding=$((max_len - ${#file_name} + 5))
            printf "%s   %s%*s %s\n" \
                "$(c 202 b "source")" \
                "$(c 246 b "$file_name")" \
                "${padding}" "" \
                "$(c 46 b "done")"
        done
    fi
}

# ── Step 5: Global Shell Reload Helpers (pp / qpp / epp) ──
refresh_shell() {
    while (( $# > 0 )); do
        case "$1" in
            -p|--profile|-l|--load)
                LOAD_LIST="${2:-}"
                shift 2
                ;;
            -q|--quick)
                _C --shell -d "source \"$HOME/.zshrc\"" "source \"$HOME/.bashrc\""
                return
                ;;
            -e|--exec)
                _C --shell -d "exec zsh" "exec bash"
                return
                ;;
            *)
                LOAD_LIST="${1:-}"
                shift 1
                ;;
        esac
    done

    clear
    _C -s -d "[[ -f \"$HOME/.zshrc\" ]] && source \"$HOME/.zshrc\"" "[[ -f \"$HOME/.bashrc\" ]] && source \"$HOME/.bashrc\""
}
alias pp='refresh_shell'
alias qpp='refresh_shell -q'
alias epp='refresh_shell -e'

# ── Step 6: Startup Execution (silent — p10k instant-prompt safe) ──
ssot_load "${LOAD_LIST:-}"
{
    unbinding -a g
    pf "${AI_PROFILE:-mom}"
    case "$JOE_ENV" in
        TERMUX|MUMU|OPPO) rc_delete ;;
    esac
    unset LOAD_LIST AI_PROFILE
    auto_start_ssh
    crlf
} >/dev/null 2>&1

# Disable nounset after load (ble.sh compatibility)
set +u
