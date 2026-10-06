#!/usr/bin/env bash
# ============================================================
# 🔐 SSOT Secret Vault Manager (AES-256 PBKDF2)
# ============================================================
# File: bootstrap/vault/ssot-vault.sh
# Purpose: Zero-dependency credential vault for syncing shared
#          secrets across multi-device SSOT without polluting
#          or overwriting machine-specific configurations.
#
# Architecture (Separation of Concerns):
#   - Machine Config: ~/.env (JOE_ENV, MY_DEVICE, local paths - NEVER in vault)
#   - Shared Secrets: ~/.env.secret (API keys, tokens - ENCRYPTED in vault)
#   - Vault File:     $SSOT/core/.env.enc (AES-256-CBC PBKDF2)
#
# Non-interactive mode: export SSOT_VAULT_PASS="<passphrase>"
# ============================================================

set -eo pipefail 2>/dev/null || true

# ── 1. SSOT Root & Environment Resolution ──
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_SSOT_ROOT="${SSOT:-$_SCRIPT_DIR}"
if [[ ! -d "$_SSOT_ROOT" ]]; then
    _SSOT_ROOT="$_SCRIPT_DIR"
fi
export SSOT="$_SSOT_ROOT"

# ── 2. Load Color Engine ──
if [[ -f "$SSOT/core/01-colors.sh" ]]; then
    source "$SSOT/core/01-colors.sh"
fi

if ! declare -f cn >/dev/null 2>&1; then
    cn() {
        local col="${1:-}" style="${2:-}"
        shift 2 2>/dev/null || shift $#
        echo "$*"
    }
    c() {
        local col="${1:-}" style="${2:-}"
        shift 2 2>/dev/null || shift $#
        printf "%s" "$*"
    }
fi

# ── 3. Paths & Configurations ──
VAULT_FILE="$SSOT/core/.env.enc"
EXAMPLE_FILE="$SSOT/.env.example"
LOCAL_SECRET="$HOME/.env.secret"
SSOT_SECRET="$SSOT/.env.secret"
LOCAL_ENV="$HOME/.env"
SSOT_ENV="$SSOT/.env"
PBKDF2_ITER=100000

# ── 4. Helper Functions ──
_banner() {
    echo ""
    c 39 b "╔══════════════════════════════════════════════════════════╗" && echo ""
    c 39 b "║   🔐  SSOT Secret Vault (AES-256-CBC PBKDF2)           ║" && echo ""
    c 39 b "╚══════════════════════════════════════════════════════════╝" && echo ""
    echo ""
}

_resolve_active_secret() {
    if [[ -f "$LOCAL_SECRET" ]]; then
        echo "$LOCAL_SECRET"
    elif [[ -f "$SSOT_SECRET" ]]; then
        echo "$SSOT_SECRET"
    elif [[ -f "$LOCAL_ENV" ]]; then
        echo "$LOCAL_ENV"
    elif [[ -f "$SSOT_ENV" ]]; then
        echo "$SSOT_ENV"
    else
        echo ""
    fi
}

_ensure_openssl() {
    if ! command -v openssl >/dev/null 2>&1; then
        cn 196 b "❌ Error: 'openssl' is not installed."
        echo "Install: pkg install openssl / apt install openssl"
        exit 1
    fi
}

# ── 4.5 Machine-local vars (NEVER enter the shared vault) ──
# Single source of truth for "not a secret". Keep in sync with
# bootstrap/vault/secret-setup.sh::_is_machine_var.
# Covers: exact legacy names, HERMES_/PYTHON_/SDCARD_ prefixes,
# per-node connection vars (HOST/USER/PORT/ST_PORT/ST_ID/ST_URL —
# note: NODE_*_ST_KEY *is* a secret and stays in the vault),
# and generic path-like suffixes.
_MACHINE_VAR_RE='^(JOE_ENV|MY_DEVICE|SSOT|HERMES_DIR|HERMES_LOG_DIR|PYTHON_VENV|SDCARD_PATH|NODE_HOST|NODE_BIN|SCRIPTS_PATH|COLOR_PATH)$'
_MACHINE_VAR_PREFIX_RE='^(HERMES_|PYTHON_|SDCARD_)'
_MACHINE_VAR_SUFFIX_RE='(_PATH|_DIR|_BIN)$'
_MACHINE_VAR_NODE_RE='^NODE_[A-Z0-9_]+_(HOST|USER|PORT|ST_PORT|ST_ID|ST_URL)$'

_is_machine_var() {
    local _v="${1:?var name required}"
    [[ "$_v" =~ $_MACHINE_VAR_RE ]] && return 0
    [[ "$_v" =~ $_MACHINE_VAR_PREFIX_RE ]] && return 0
    [[ "$_v" =~ $_MACHINE_VAR_SUFFIX_RE ]] && return 0
    [[ "$_v" =~ $_MACHINE_VAR_NODE_RE ]] && return 0
    return 1
}

# Strip `export ` prefix + one layer of surrounding quotes.
_extract_value() {
    local _line="$1" _val
    _val="${_line#*=}"
    if [[ "$_val" =~ ^\"(.*)\"$ ]]; then
        _val="${BASH_REMATCH[1]}"
    elif [[ "$_val" =~ ^\'(.*)\'$ ]]; then
        _val="${BASH_REMATCH[1]}"
    fi
    _val="${_val//\\\"/\"}"
    _val="${_val//\\\$/\$}"
    _val="${_val//\\\`/\`}"
    _val="${_val//\\\\/\\}"
    printf '%s' "$_val"
}

# Upsert KEY into a secret file (append `export KEY="escaped"`).
_upsert_secret() {
    local _file="$1" _key="$2" _val="$3" _tmp
    _tmp="$(mktemp)"
    grep -vE "^[[:space:]]*(export[[:space:]]+)?${_key}=" "$_file" 2>/dev/null > "$_tmp" || true
    local _esc="${_val//\\/\\\\}"
    _esc="${_esc//\"/\\\"}"
    _esc="${_esc//\$/\\\$}"
    _esc="${_esc//\`/\\\`}"
    printf 'export %s="%s"\n' "$_key" "$_esc" >> "$_tmp"
    cat "$_tmp" > "$_file"
    rm -f "$_tmp"
}

# ── 5. Core Commands ──

# --- LOCK / ENCRYPT ---
cmd_lock() {
    _banner
    _ensure_openssl

    local target_secret="$(_resolve_active_secret)"
    if [[ -z "$target_secret" ]]; then
        cn 196 b "❌ No secret file found at $LOCAL_SECRET or $SSOT_SECRET"
        echo "Run: vault init to create secrets, or create ~/.env.secret"
        exit 1
    fi

    # Migration: if locking from legacy ~/.env, extract pure secrets to ~/.env.secret
    # Machine-local vars stay out of the shared vault (SSOT paths differ per device).
    if [[ "$target_secret" == "$LOCAL_ENV" || "$target_secret" == "$SSOT_ENV" ]]; then
        cn 214 b "⚡ Migrating pure secrets from $(basename "$target_secret") → $LOCAL_SECRET..."
        mkdir -p "$(dirname "$LOCAL_SECRET")"
        local _mig_tmp
        _mig_tmp="$(mktemp)"
        while IFS= read -r _mig_line || [[ -n "$_mig_line" ]]; do
            if [[ "$_mig_line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                _is_machine_var "${BASH_REMATCH[2]}" && continue
            fi
            printf '%s\n' "$_mig_line" >> "$_mig_tmp"
        done < "$target_secret"
        cat "$_mig_tmp" > "$LOCAL_SECRET"
        rm -f "$_mig_tmp"
        chmod 600 "$LOCAL_SECRET"
        ln -sf "$LOCAL_SECRET" "$SSOT_SECRET" 2>/dev/null || true
        target_secret="$LOCAL_SECRET"
        cn 82 b "✅ Extracted pure secrets to $LOCAL_SECRET (machine config kept intact in ~/.env)"
    fi

    cn 226 b "🔒 Locking secrets from: $target_secret"
    mkdir -p "$(dirname "$VAULT_FILE")"

    # Get passphrase (non-interactive via env var, or prompt)
    local pass1 pass2
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        pass1="$SSOT_VAULT_PASS"
    else
        read -r -s -p "Enter Vault Passphrase: " pass1 < /dev/tty
        echo ""
        if [[ -z "$pass1" ]]; then
            cn 196 b "❌ Passphrase cannot be empty."
            exit 1
        fi
        read -r -s -p "Confirm: " pass2 < /dev/tty
        echo ""
        if [[ "$pass1" != "$pass2" ]]; then
            cn 196 b "❌ Passphrases do not match!"
            exit 1
        fi
    fi

    # Encrypt
    if echo "$pass1" | openssl enc -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" -salt \
        -in "$target_secret" -out "$VAULT_FILE" -pass stdin 2>/dev/null; then
        chmod 644 "$VAULT_FILE"
        echo ""
        cn 82 b "✅ Vault locked!"
        echo "📦 $VAULT_FILE ($(wc -c < "$VAULT_FILE" | tr -d ' ') bytes)"
        echo ""
        cn 214 b "💡 Next: git add $VAULT_FILE && git commit && git push"
        echo ""
    else
        cn 196 b "❌ Encryption failed."
        exit 1
    fi
}

# --- UNLOCK / DECRYPT ---
cmd_unlock() {
    _banner
    _ensure_openssl

    if [[ ! -f "$VAULT_FILE" ]]; then
        cn 196 b "❌ Vault not found: $VAULT_FILE"
        echo "Clone the repo first, or create ~/.env.secret manually."
        exit 1
    fi

    cn 226 b "🔓 Unlocking: $VAULT_FILE"

    # Get passphrase
    local pass
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        pass="$SSOT_VAULT_PASS"
    else
        read -r -s -p "Enter Vault Passphrase: " pass < /dev/tty
        echo ""
    fi

    if [[ -z "$pass" ]]; then
        cn 196 b "❌ Passphrase cannot be empty."
        exit 1
    fi

    local tmp_out
    tmp_out="$(mktemp)"

    if echo "$pass" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
        -in "$VAULT_FILE" -out "$tmp_out" -pass stdin 2>/dev/null; then
        if [[ ! -s "$tmp_out" ]]; then
            rm -f "$tmp_out"
            cn 196 b "❌ Decryption empty — wrong passphrase?"
            exit 1
        fi

        # Write to LOCAL_SECRET (~/.env.secret) ONLY. Do NOT overwrite ~/.env!
        # Guard: back up a pre-existing local secret file before replacing it.
        if [[ -f "$LOCAL_SECRET" ]]; then
            local _bak="${LOCAL_SECRET}.bak.$(date +%Y%m%d_%H%M%S)"
            cp "$LOCAL_SECRET" "$_bak" 2>/dev/null || true
            chmod 600 "$_bak" 2>/dev/null || true
            echo "📦 Previous local secrets backed up: $_bak"
        fi
        mv "$tmp_out" "$LOCAL_SECRET"
        chmod 600 "$LOCAL_SECRET"
        ln -sf "$LOCAL_SECRET" "$SSOT_SECRET" 2>/dev/null || true

        echo ""
        cn 82 b "✅ Vault unlocked!"
        echo "📄 Secrets decrypted to: $LOCAL_SECRET (chmod 600)"
        echo "🔗 Symlink: $SSOT_SECRET → $LOCAL_SECRET"
        echo "🛡️  Machine config ($LOCAL_ENV) preserved untouched!"
        echo ""
    else
        rm -f "$tmp_out"
        cn 196 b "❌ Decryption failed — wrong passphrase or corrupted vault."
        exit 1
    fi
}

# --- STATUS (unified: health + audit + diff) ---
cmd_status() {
    _banner

    # ── Vault file ──
    echo "📦 Vault:"
    if [[ -f "$VAULT_FILE" ]]; then
        local v_size v_time
        v_size="$(wc -c < "$VAULT_FILE" | tr -d ' ')"
        v_time="$(stat -c "%y" "$VAULT_FILE" 2>/dev/null || stat -f "%Sm" "$VAULT_FILE" 2>/dev/null || echo "?")"
        echo "   $(c 82 b "EXISTS") $VAULT_FILE ($v_size bytes, $v_time)"
    else
        echo "   $(c 196 b "NOT FOUND") $VAULT_FILE"
    fi

    # ── Shared Secrets file ──
    local active_secret="$(_resolve_active_secret)"
    echo ""
    echo "🔐 Shared Secrets ($LOCAL_SECRET):"
    if [[ -f "$LOCAL_SECRET" ]]; then
        local s_size
        s_size="$(wc -c < "$LOCAL_SECRET" | tr -d ' ')"
        echo "   $(c 82 b "EXISTS") $LOCAL_SECRET ($s_size bytes)"
    elif [[ -n "$active_secret" ]]; then
        echo "   $(c 226 b "LEGACY") Using $(basename "$active_secret") — run 'vault lock' to migrate"
    else
        echo "   $(c 226 b "NOT FOUND") — Run: vault unlock"
    fi

    # ── Machine Config file ──
    echo ""
    echo "💻 Machine Config ($LOCAL_ENV):"
    if [[ -f "$LOCAL_ENV" ]]; then
        local e_size
        e_size="$(wc -c < "$LOCAL_ENV" | tr -d ' ')"
        echo "   $(c 82 b "EXISTS") $LOCAL_ENV ($e_size bytes) [JOE_ENV=${JOE_ENV:-?}]"
    else
        echo "   $(c 246 b "NOT FOUND")"
    fi

    # ── Symlink ──
    echo ""
    echo "🔗 Secret Symlink:"
    if [[ -L "$SSOT_SECRET" ]]; then
        echo "   $(c 82 b "HEALTHY") $SSOT_SECRET → $(readlink "$SSOT_SECRET")"
    elif [[ -f "$SSOT_SECRET" ]]; then
        echo "   $(c 226 b "REGULAR FILE") — Consider: ln -sf $LOCAL_SECRET $SSOT_SECRET"
    else
        echo "   $(c 246 b "NONE")"
    fi

    # ── Secret Audit ──
    if [[ -n "$active_secret" ]] && [[ -f "$EXAMPLE_FILE" ]]; then
        echo ""
        echo "🔍 Secret Audit (template vs actual):"
        local total=0 ok=0 empty=0 missing=0

        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                local var_name="${BASH_REMATCH[2]}"
                _is_machine_var "$var_name" && continue
                total=$((total+1))

                if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_secret" 2>/dev/null; then
                    local raw_val
                    raw_val="$(grep -m 1 "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$active_secret" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=//' | tr -d '"' | tr -d "'")"
                    if [[ -n "$raw_val" ]]; then
                        ok=$((ok+1))
                        local masked="${raw_val:0:4}..."
                        printf "   %-28s $(c 82 b "SET") %s\n" "$var_name" "$masked"
                    else
                        empty=$((empty+1))
                        printf "   %-28s $(c 226 b "EMPTY")\n" "$var_name"
                    fi
                else
                    missing=$((missing+1))
                    printf "   %-28s $(c 196 b "MISSING")\n" "$var_name"
                fi
            fi
        done < "$EXAMPLE_FILE"

        echo ""
        printf "   Total: %d | $(c 82 b "Set: %d") | $(c 226 b "Empty: %d") | $(c 196 b "Missing: %d")\n" \
            "$total" "$ok" "$empty" "$missing"

        # ── Extra (untracked) secrets: set locally but missing from .env.example ──
        # Informational only — shown even when the audit below fails.
        # Promote with: add key to .env.example, then `vault lock`.
        echo ""
        echo "🆕 Extra secrets (set locally, not in .env.example):"
        local _extra=0 _extra_src="$LOCAL_SECRET"
        if [[ ! -f "$_extra_src" ]]; then
            _extra_src="$active_secret"
        fi
        while IFS= read -r _sline || [[ -n "$_sline" ]]; do
            if [[ "$_sline" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                local _ek="${BASH_REMATCH[2]}"
                if _is_machine_var "$_ek"; then
                    continue
                fi
                if grep -qE "^[[:space:]]*(export[[:space:]]+)?${_ek}=" "$EXAMPLE_FILE" 2>/dev/null; then
                    continue
                fi
                _extra=$((_extra+1))
                printf "   %-28s $(c 39 b "UNTRACKED")\n" "$_ek"
            fi
        done < "$_extra_src"
        if (( _extra == 0 )); then
            echo "   (none)"
        else
            echo "   💡 Promote: add to .env.example, then vault lock → git push"
        fi

        # Exit code for CI/scripting
        if (( missing > 0 || empty > 0 )); then
            echo ""
            echo "   💡 Fix: edit ~/.env.secret or run vault init"
            return 1
        fi
    fi
    echo ""
}

# --- INIT (interactive wizard) ---
cmd_init() {
    _banner
    local target_secret="$LOCAL_SECRET"

    if [[ ! -f "$target_secret" ]]; then
        if [[ -f "$EXAMPLE_FILE" ]]; then
            cp "$EXAMPLE_FILE" "$target_secret"
            chmod 600 "$target_secret"
            ln -sf "$target_secret" "$SSOT_SECRET" 2>/dev/null || true
            cn 82 b "📄 Created $target_secret from .env.example"
        else
            cn 196 b "❌ .env.example not found"
            exit 1
        fi
    fi

    echo "🔧 Interactive Secret Setup — $target_secret"
    echo "   Press Enter to skip a value."
    echo ""

    local updated=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            local var_name="${BASH_REMATCH[2]}"
            _is_machine_var "$var_name" && continue

            # Check current value
            local current_val=""
            if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$target_secret" 2>/dev/null; then
                current_val="$(grep -m 1 "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$target_secret" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=//' | tr -d '"' | tr -d "'")"
            fi

            if [[ -n "$current_val" ]]; then
                printf "   %-28s %s (set)\n" "$var_name" "${current_val:0:4}..."
                continue
            fi

            printf "   %-28s = " "$var_name"
            read -r new_val < /dev/tty
            new_val="${new_val:-}"

            if [[ -n "$new_val" ]]; then
                if grep -q "^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=" "$target_secret" 2>/dev/null; then
                    sed -i "s|^[[:space:]]*\(export[[:space:]]\+\)\?${var_name}=.*|export ${var_name}=\"${new_val}\"|" "$target_secret"
                else
                    printf 'export %s="%s"\n' "$var_name" "$new_val" >> "$target_secret"
                fi
                updated=$((updated+1))
            fi
        fi
    done < "$EXAMPLE_FILE"

    echo ""
    cn 82 b "✅ Updated $updated secret(s)"
    echo "💡 Next: vault lock → git commit → git push"
    echo ""
}

# --- EXPORT (backup) ---
cmd_export() {
    _ensure_openssl
    local target_secret="$(_resolve_active_secret)"

    if [[ -z "$target_secret" ]]; then
        cn 196 b "❌ No secret file to export"
        exit 1
    fi

    local backup_dir="$SSOT/core/backups"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/.env.secret.$(date +%Y%m%d_%H%M%S).enc"

    cn 226 b "📦 Backing up to: $backup_file"

    local pass
    if [[ -n "${SSOT_VAULT_PASS:-}" ]]; then
        pass="$SSOT_VAULT_PASS"
    else
        read -r -s -p "Backup passphrase: " pass < /dev/tty
        echo ""
    fi

    if echo "$pass" | openssl enc -aes-256-cbc -pbkdf2 -iter "$PBKDF2_ITER" \
        -salt -in "$target_secret" -out "$backup_file" -pass stdin 2>/dev/null; then
        chmod 600 "$backup_file"
        cn 82 b "✅ Backup created ($(wc -c < "$backup_file" | tr -d ' ') bytes)"
    else
        cn 196 b "❌ Backup failed"
        exit 1
    fi
}

# --- SET / ADD (add or update one secret) ---
# Usage: vault set KEY [VALUE] [--force]
#        vault add KEY               (always prompts)
# No VALUE → prompt (silent). VALUE as arg → non-interactive (CI-safe).
# Machine-local-looking KEYs are rejected unless --force.
cmd_set() {
    local _force=false _key="" _val="" _a
    for _a in "$@"; do
        if [[ "$_a" == "--force" || "$_a" == "-f" ]]; then
            _force=true
        elif [[ -z "$_key" ]]; then
            _key="$_a"
        else
            _val="$_a"
        fi
    done

    if [[ -z "$_key" ]]; then
        echo "Usage: vault set KEY [VALUE] [--force]" >&2
        return 1
    fi
    if [[ ! "$_key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        cn 196 b "❌ Invalid variable name: $_key"
        return 1
    fi
    if ! $_force && _is_machine_var "$_key"; then
        cn 214 b "⚠️  '$_key' looks like machine-local config (kept out of the shared vault)."
        echo "   Re-run with --force to store it anyway."
        return 1
    fi

    mkdir -p "$(dirname "$LOCAL_SECRET")"
    if [[ ! -f "$LOCAL_SECRET" ]]; then
        touch "$LOCAL_SECRET"
        chmod 600 "$LOCAL_SECRET"
        ln -sf "$LOCAL_SECRET" "$SSOT_SECRET" 2>/dev/null || true
    fi

    if [[ -z "$_val" ]]; then
        if [[ -n "${SSOT_VAULT_VALUE:-}" ]]; then
            _val="$SSOT_VAULT_VALUE"
        elif [[ -t 0 || -e /dev/tty ]]; then
            read -r -s -p "Value for $_key: " _val < /dev/tty
            echo ""
        fi
    fi
    if [[ -z "$_val" ]]; then
        cn 196 b "❌ Empty value — aborted."
        return 1
    fi

    _upsert_secret "$LOCAL_SECRET" "$_key" "$_val"
    chmod 600 "$LOCAL_SECRET"
    cn 82 b "✅ Set $_key (in $LOCAL_SECRET)"
    echo "💡 Next: vault lock → git commit → git push"
}

# --- GET (print one secret value, for scripts) ---
# Usage: vault get KEY   → prints raw value to stdout, nothing else.
cmd_get() {
    local _key="${1:-}"
    if [[ -z "$_key" ]]; then
        echo "Usage: vault get KEY" >&2
        return 1
    fi
    local _src="$(_resolve_active_secret)"
    if [[ -z "$_src" ]]; then
        echo "❌ No secret file found" >&2
        return 1
    fi
    local _line
    _line="$(grep -m 1 -E "^[[:space:]]*(export[[:space:]]+)?${_key}=" "$_src" 2>/dev/null || true)"
    if [[ -z "$_line" ]]; then
        echo "❌ '$_key' not found in $(basename "$_src")" >&2
        return 1
    fi
    _extract_value "$_line"
    echo ""
}

# --- LIST (all secret names, values masked) ---
cmd_list() {
    local _src="$(_resolve_active_secret)"
    if [[ -z "$_src" ]]; then
        cn 196 b "❌ No secret file found"
        return 1
    fi
    echo "🔑 Secrets in $(basename "$_src"):"
    while IFS= read -r _line || [[ -n "$_line" ]]; do
        if [[ "$_line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]]; then
            local _k="${BASH_REMATCH[2]}"
            if _is_machine_var "$_k"; then
                continue
            fi
            local _v
            _v="$(_extract_value "$_line")"
            if [[ -n "$_v" ]]; then
                printf "   %-28s $(c 82 b "SET") %s\n" "$_k" "${_v:0:4}..."
            else
                printf "   %-28s $(c 226 b "EMPTY")\n" "$_k"
            fi
        fi
    done < "$_src"
    echo ""
}

# --- DEL (remove one secret) ---
# Usage: vault del KEY
cmd_del() {
    local _key="${1:-}"
    if [[ -z "$_key" ]]; then
        echo "Usage: vault del KEY" >&2
        return 1
    fi
    if [[ ! -f "$LOCAL_SECRET" ]]; then
        cn 196 b "❌ No local secret file: $LOCAL_SECRET"
        return 1
    fi
    if ! grep -qE "^[[:space:]]*(export[[:space:]]+)?${_key}=" "$LOCAL_SECRET" 2>/dev/null; then
        cn 196 b "❌ '$_key' not found in $LOCAL_SECRET"
        return 1
    fi
    local _tmp
    _tmp="$(mktemp)"
    grep -vE "^[[:space:]]*(export[[:space:]]+)?${_key}=" "$LOCAL_SECRET" > "$_tmp" || true
    cat "$_tmp" > "$LOCAL_SECRET"
    rm -f "$_tmp"
    cn 82 b "✅ Deleted $_key (run 'vault lock' to sync)"
}

# ── 6. CLI Dispatcher ──
case "${1:-}" in
    lock|encrypt)       cmd_lock ;;
    unlock|decrypt)     cmd_unlock ;;
    status)             cmd_status ;;
    init|setup)         cmd_init ;;
    export|backup)      cmd_export ;;
    set|add)            shift; cmd_set "$@" ;;
    get)                shift; cmd_get "$@" ;;
    list|ls)            cmd_list ;;
    del|rm|remove)      shift; cmd_del "$@" ;;
    verify|check)       cmd_status ;;   # alias: verify = status
    diff)               cmd_status ;;   # alias: diff = status
    audit)              cmd_status ;;   # alias: audit = status

    # Pubkey mesh (single tool: pubkey-corrector.sh — fingerprint dedup + repair)
    pubkey-audit|pubkey-fix|pubkey-collect|pubkey-sync|lock_pubkey|unlock_pubkey|pubkey-status)
        _CORRECTOR_SCRIPT="$SSOT/bootstrap/nodes/pubkey-corrector.sh"
        if [[ -f "$_CORRECTOR_SCRIPT" ]]; then
            _pc_cmd="${1}"
            shift
            case "$_pc_cmd" in
                pubkey-audit)   bash "$_CORRECTOR_SCRIPT" audit "$@" ;;
                pubkey-fix)     bash "$_CORRECTOR_SCRIPT" fix-local "$@" ;;
                pubkey-collect) bash "$_CORRECTOR_SCRIPT" collect "$@" ;;
                pubkey-sync)    bash "$_CORRECTOR_SCRIPT" install "$@" ;;
                lock_pubkey)    bash "$_CORRECTOR_SCRIPT" collect "$@" ;;   # legacy alias
                unlock_pubkey)  bash "$_CORRECTOR_SCRIPT" install "$@" ;;   # legacy alias
                pubkey-status)  bash "$_CORRECTOR_SCRIPT" status "$@" ;;    # legacy alias
            esac
        else
            cn 196 b "❌ pubkey-corrector.sh not found"
            exit 1
        fi
        ;;

    *)
        _banner
        echo "Usage: $(basename "$0") <command>"
        echo ""
        echo "Secret Commands:"
        echo "  lock    Encrypt ~/.env.secret → core/.env.enc"
        echo "  unlock  Decrypt core/.env.enc → ~/.env.secret"
        echo "  status  Vault health + secret audit (exit 1 if incomplete)"
        echo "  init    Interactive wizard to fill in secrets"
        echo "  export  Encrypted backup of ~/.env.secret"
        echo ""
        echo "Flexible Secret Commands (no template edit needed first):"
        echo "  set KEY [VALUE] [--force]"
        echo "          Add/update one secret (prompts silently if no VALUE;"
        echo "          rejects machine-local names unless --force)"
        echo "  add KEY Same as set (always prompts)"
        echo "  get KEY Print raw value (for scripts)"
        echo "  list    Show all secret names (values masked)"
        echo "  del KEY Remove one secret"
        echo ""
        echo "Aliases: add → set; ls → list; rm/remove → del"
        echo ""
        echo "Pubkey Mesh (single tool — fingerprint dedup + repair + fanout):"
        echo "  pubkey-audit    Read-only check of authorized_keys"
        echo "  pubkey-fix      Repair this node (backup + join splits + dedup + self key)"
        echo "  pubkey-collect [--add <key>] [--from <host>] [--scan-mesh] [--collect]"
        echo "                  Merge keys into vault (default: local only; --collect = pending/)"
        echo "  pubkey-sync [--fanout] [--only <node>]"
        echo "              Install vault keys (fingerprint merge;"
        echo "              --fanout = also pull+install on every other node over SSH)"
        echo ""
        echo "Legacy pubkey aliases: lock_pubkey → pubkey-collect; unlock_pubkey → pubkey-sync;"
        echo "                       pubkey-status → pubkey-audit"
        echo ""
        echo "Aliases: verify, check, diff, audit → status"
        echo ""
        echo "Non-interactive:"
        echo "  export SSOT_VAULT_PASS='<pass>'  (skip passphrase prompts)"
        echo "  export SSOT_VAULT_VALUE='<val>'  (value for 'vault set KEY')"
        echo "  vault set KEY \"value\"             (or pass VALUE as arg)"
        echo ""
        exit 0
        ;;
esac
