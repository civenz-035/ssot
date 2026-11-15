# ============================================================
# profiles/_common/bashrc.sh — Shared SSOT Bash Startup Engine
# ============================================================
# Sourced by profiles/<device>/.bashrc after setting default
# JOE_ENV / MY_DEVICE. Works identically across all devices
# and never fails on missing optional tools on fresh clones.
# ============================================================

_SSOT_RC_LOADING=1
unset _JOE_LOADED_IN_RC

export SSOT="${SSOT:-$HOME/ssot}"

# ── 1. Core Bash History & Window Options ──
HISTCONTROL=ignoreboth
shopt -s histappend 2>/dev/null || true
HISTSIZE=2000
HISTFILESIZE=4000
shopt -s checkwinsize 2>/dev/null || true
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ── 2. Platform Locale & PATH Pre-setup ──
case "${JOE_ENV:-}" in
    TERMUX|MUMU|OPPO|ACODEX)
        export LC_ALL="C.UTF-8"
        export LC_CTYPE="C.UTF-8"
        export LANG="C.UTF-8"
        unset LC_COLLATE LC_MESSAGES LC_MONETARY LC_NUMERIC LC_TIME LC_PAPER LC_MEASUREMENT 2>/dev/null || true
        ;;
    GIT-BASH)
        for _gfw_p in "/usr/bin" "/mingw64/bin" "/mingw32/bin"; do
            [[ -d "$_gfw_p" ]] && case ":${PATH}:" in
                *:"$_gfw_p":*) ;;
                *) export PATH="$_gfw_p:$PATH" ;;
            esac
        done
        unset _gfw_p
        ;;
esac

export TERM="${TERM:-xterm-256color}"

# ── 3. Load SSOT Runtime Helper ──
[[ -f "$SSOT/core/runtime/helper.sh" ]] && source "$SSOT/core/runtime/helper.sh" 2>/dev/null

# ── 4. Bash Line Editor (ble.sh — source detached, attach at end) ──
if [[ $- == *i* && -f "$HOME/.local/share/blesh/ble.sh" && -z "${BLE_VERSION-}" ]]; then
    source "$HOME/.local/share/blesh/ble.sh" --attach=none
    case "${JOE_ENV:-}" in
        TERMUX|MUMU|OPPO|ACODEX)
            ble/util/.test-C-locale() { return 0; }
            _ble_util_locale_broken=
            _ble_util_locale_broken_notified=
            ;;
    esac
fi

# ── 5. Node Version Manager (NVM) ──
export NVM_DIR="$HOME/.nvm"
if [[ -d "$NVM_DIR" ]]; then
    if [[ "${JOE_ENV:-}" == "GIT-BASH" ]]; then
        # Lazy-load NVM on Windows Git Bash for instant startup
        _load_nvm() {
            unset -f nvm node npm npx _load_nvm 2>/dev/null
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        }
        nvm()  { _load_nvm && nvm "$@"; }
        node() { _load_nvm && node "$@"; }
        npm()  { _load_nvm && npm "$@"; }
        npx()  { _load_nvm && npx "$@"; }
    else
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm use default >/dev/null 2>&1 || true
    fi
fi

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

# ── 8. Optional User & Companion Integrations (all safely guarded) ──
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"
[[ -f "$HOME/.openclaw-2/completions/openclaw.bash" ]] && source "$HOME/.openclaw-2/completions/openclaw.bash"
[[ -f "$HOME/.maths-helper/maths.sh" ]] && source "$HOME/.maths-helper/maths.sh"
[[ -f "${DICE_SIM_DIR:-$HOME/simulator}/lib/alias.sh" ]] && source "${DICE_SIM_DIR:-$HOME/simulator}/lib/alias.sh"

# Extra PATH additions (deduplicated)
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

# ── 9. Attach ble.sh & Restore TTY Sanity ──
if [[ $- == *i* && -n "${BLE_VERSION-}" && -z "${BLE_ATTACHED:-}" ]]; then
    export BLE_ATTACHED=1
    ble-attach
fi

if [[ "${JOE_ENV:-}" == "WSL" || "${JOE_ENV:-}" == "WSL2" || "${JOE_ENV:-}" == "USERLAND" ]]; then
    [[ -t 0 ]] && stty sane 2>/dev/null || true
fi

unset _SSOT_RC_LOADING _JOE_LOADED_IN_RC
