# ============================================================
# profiles/_common/zshrc.zsh — Shared SSOT Zsh Startup Engine
# ============================================================
# Sourced by profiles/<device>/.zshrc after setting default
# JOE_ENV / MY_DEVICE. Ensures zsh-compat loads BEFORE joe.sh,
# avoids double-loading, and is Powerlevel10k instant-prompt safe.
# ============================================================

_SSOT_RC_LOADING=1
unset _JOE_LOADED_IN_RC

unsetopt KSH_ARRAYS SH_WORD_SPLIT GLOB_SUBST 2>/dev/null || true
setopt NO_NOMATCH NULL_GLOB 2>/dev/null || true
typeset -g -U fpath path PATH 2>/dev/null || true

export SSOT="${SSOT:-$HOME/ssot}"
export TERM="${TERM:-xterm-256color}"
export COLORTERM="${COLORTERM:-truecolor}"

# ── 1. Base PATH & Termux Zsh fpath ──
export PATH="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
if [[ -d "/data/data/com.termux/files/usr/bin" ]]; then
    export PATH="/data/data/com.termux/files/usr/bin:$PATH"
fi

_tz_dir="/data/data/com.termux/files/usr/share/zsh"
if [[ -d "$_tz_dir" ]]; then
    for _d in "$_tz_dir"/site-functions(N) \
              "$_tz_dir"/*(N) \
              "$_tz_dir"/*/functions(N) \
              "$_tz_dir"/*/functions/*(N) \
              "$_tz_dir"/*/functions/*/*(N) \
              "$_tz_dir"/*/functions/*/*/*(N); do
        [[ -d "$_d" ]] && fpath+=("$_d")
    done
fi
unset _tz_dir _d

# ── 2. Powerlevel10k Instant Prompt (quiet) ──
export DISABLE_LS_COLORS="true"
export ZSH_DISABLE_COMPFIX="true"
unfunction color 2>/dev/null || true
unset color 2>/dev/null || true

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── 3. Oh My Zsh (sourced once per session, non-blocking updates) ──
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
if [[ -o interactive ]]; then
    zstyle ':omz:update' mode reminder
else
    zstyle ':omz:update' mode disabled
fi
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)
if [[ -d "$ZSH/custom/plugins/autoupdate" ]]; then
    plugins+=(autoupdate)
fi

if [[ -z "${_OMZ_SOURCED:-}" && -f "$ZSH/oh-my-zsh.sh" ]]; then
    export _OMZ_SOURCED=1
    source "$ZSH/oh-my-zsh.sh"
fi

# ── 4. Node Version Manager (NVM) ──
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    nvm use default >/dev/null 2>&1 || true
fi

# ── 5. Zsh Compatibility Layer & SSOT Runtime (MUST run before joe.sh) ──
[[ -f "$SSOT/core/runtime/zsh-compat.zsh" ]] && source "$SSOT/core/runtime/zsh-compat.zsh"
[[ -f "$SSOT/core/runtime/helper.sh" ]]     && source "$SSOT/core/runtime/helper.sh" 2>/dev/null

# ── 6. Global Environment Manager (~/.local/bin/env -> ~/.env & ~/.env.secret) ──
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# ── 7. CRLF Self-Heal & Single Load of joe.sh ──
if [[ -f "$SSOT/joe.sh" ]] && grep -qU $'\r' "$SSOT/joe.sh" 2>/dev/null; then
    sed -i 's/\r$//' "$SSOT/joe.sh"
    echo "⚠️  CRLF→LF: joe.sh (auto-fixed)" >&2
fi
if [[ -z "${_JOE_LOADED_IN_RC:-}" && -f "$SSOT/joe.sh" ]]; then
    source "$SSOT/joe.sh"
fi

# ── 8. Powerlevel10k Config & Safe History Keybindings ──
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

if [[ "${JOE_ENV:-}" == "TERMUX" || "${JOE_ENV:-}" == "MUMU" || "${JOE_ENV:-}" == "OPPO" ]]; then
    export POWERLEVEL9K_DISABLE_GITSTATUS=true
    export GITSTATUS_ENABLE=0
fi

if ! autoload +X -U up-line-or-beginning-search 2>/dev/null; then
    up-line-or-beginning-search() { zle up-line-or-history; }
    zle -N up-line-or-beginning-search 2>/dev/null
fi
if ! autoload +X -U down-line-or-beginning-search 2>/dev/null; then
    down-line-or-beginning-search() { zle down-line-or-history; }
    zle -N down-line-or-beginning-search 2>/dev/null
fi

if zle -la 2>/dev/null | grep -q history-substring-search; then
    bindkey '^[[A' history-substring-search-up   2>/dev/null
    bindkey '^[[B' history-substring-search-down 2>/dev/null
    [[ -n "${terminfo[kcuu1]:-}" ]] && bindkey "$terminfo[kcuu1]" history-substring-search-up   2>/dev/null
    [[ -n "${terminfo[kcud1]:-}" ]] && bindkey "$terminfo[kcud1]" history-substring-search-down 2>/dev/null
else
    bindkey '^[[A' up-line-or-history   2>/dev/null
    bindkey '^[[B' down-line-or-history 2>/dev/null
fi

(( ! ${+functions[p10k]} )) || p10k finalize

# ── 9. Micro Editor TTY-Safe Wrapper ──
micro() {
    if [[ -z "${TERM:-}" || "$TERM" == "dumb" ]]; then
        export TERM="xterm-256color"
        export COLORTERM="truecolor"
    fi
    if ! [ -t 0 ] || ! [ -t 1 ]; then
        if [[ -c /dev/tty ]]; then
            TERM="${TERM:-xterm-256color}" command micro "$@" </dev/tty >/dev/tty
            return $?
        else
            echo "ERROR: micro requires an interactive TTY (use ssh -t)" >&2
            return 1
        fi
    fi
    if command -v tput >/dev/null 2>&1; then
        tput rmcup 2>/dev/null || true
        tput sgr0  2>/dev/null || true
        tput cnorm 2>/dev/null || true
    fi
    TERM="${TERM:-xterm-256color}" command micro "$@"
    local ret=$?
    if command -v tput >/dev/null 2>&1; then
        tput rmcup 2>/dev/null || true
        tput sgr0  2>/dev/null || true
    fi
    return $ret
}

# ── 10. Optional User & Companion Integrations (all safely guarded) ──
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"
[[ -f "$HOME/.openclaw-2/completions/openclaw.bash" ]] && source "$HOME/.openclaw-2/completions/openclaw.bash" 2>/dev/null
[[ -f "$HOME/.maths-helper/maths.sh" ]] && source "$HOME/.maths-helper/maths.sh"
[[ -f "${DICE_SIM_DIR:-$HOME/simulator}/lib/alias.sh" ]] && source "${DICE_SIM_DIR:-$HOME/simulator}/lib/alias.sh"

for _extra_bin in \
    "$HOME/.local/bin" \
    "$HOME/.opencode/bin" \
    "$HOME/.local/lib/openclaw/bin" \
    "$HOME/.local/share/pnpm/bin"
do
    if [[ -d "$_extra_bin" ]]; then
        case ":${PATH}:" in
            *:"$_extra_bin":*) ;;
            *) export PATH="$_extra_bin:$PATH" ;;
        esac
    fi
done
unset _extra_bin
[[ -d "$HOME/.local/share/pnpm" ]] && export PNPM_HOME="$HOME/.local/share/pnpm"

unset _SSOT_RC_LOADING _JOE_LOADED_IN_RC
