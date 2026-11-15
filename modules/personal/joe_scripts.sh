#!/usr/bin/env bash
# ------------------------------------------------------------
# File: joe_scripts.sh
# ------------------------------------------------------------


reinstall() {
    local repo="${1:-ssot}"
    local device="${2:-}"
    local ssot_dir="$HOME/ssot"
    local bk_dir="$HOME/.ssot-backups/installationbk"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    # ── Single-repo mode: only ~/ssot is supported ──
    case "$repo" in
        ssot|"")
            repo="ssot"
            ;;
        bsc|bashscripts|all|both)
            echo "⚠️  '$repo' is deprecated — single-repo mode uses ~/ssot only." >&2
            echo "   Continuing with reinstall ssot…" >&2
            repo="ssot"
            ;;
        *)
            echo "Usage: reinstall [ssot] [device]"
            echo "  ssot  → reinstall ~/ssot (single repo)"
            return 1
            ;;
    esac

    local target_dir="$ssot_dir"
    local target_name="ssot"
    local link_list=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.local/bin/joe" "$HOME/.local/bin/env")

    # ── Remove existing symlinks ──
    for link in "${link_list[@]}"; do
        if [[ -L "$link" || -f "$link" ]]; then
            rm -f "$link"
        fi
    done


    # ── Backup if exists ──
    if [[ -d "$target_dir" ]]; then
        mkdir -p "$bk_dir"
        local bak_path="$bk_dir/${target_name}_${timestamp}"
        mv "$target_dir" "$bak_path"
        echo "📦 Backed up: $target_dir → $bak_path"
    fi

    # ── Clone fresh (single repo) ──
    local clone_url="https://github.com/civenz-035/ssot.git"

    echo "🔄 Cloning $repo → $target_dir"
    if ! git clone --depth=1 "$clone_url" "$target_dir"; then
        echo "❌ git clone failed — restoring backup"
        [[ -d "$bak_path" ]] && mv "$bak_path" "$target_dir"
        return 1
    fi

    # ── Run install.sh ──
    if [[ -f "$target_dir/bootstrap/install.sh" ]]; then
        echo "🚀 Running install.sh..."
        if ! bash "$target_dir/bootstrap/install.sh" $device; then
            echo "⚠️  install.sh had warnings (check output above)"
        fi
    else
        echo "❌ install.sh not found in $target_dir"
        return 1
    fi

    echo "✅ Reinstall complete: $repo"
}



link_bin() {
    case "$1" in
        -c|--check)
            shift
            local check_dirs=("$@")
            if [[ ${#check_dirs[@]} -eq 0 ]]; then
                check_dirs=("${bin:-$HOME/.local/bin}" "$HOME")
            fi

            for dir in "${check_dirs[@]}"; do
                dir="${dir/#\~/$HOME}"
                if [[ ! -d "$dir" ]]; then
                    echo "⚠️  Directory not found: $dir"
                    continue
                fi

                echo "📁 Symlinks in: $dir"
                local found=0
                while IFS= read -r link; do
                    [[ -z "$link" ]] && continue
                    found=1
                    local base_name target_path status
                    base_name="${link##*/}"
                    target_path="$(readlink "$link" 2>/dev/null)"

                    if [[ -e "$link" ]]; then
                        status="[OK]"
                    else
                        status="[BROKEN]"
                    fi

                    printf "  %-25s → %-45s %s\n" "$base_name" "$target_path" "$status"
                done < <(find "$dir" -maxdepth 1 -type l 2>/dev/null | sort)

                if [[ $found -eq 0 ]]; then
                    echo "  (No symlinks found)"
                fi
                echo ""
            done
            return 0
            ;;

        *)
            [[ $# -ne 1 ]] && echo "Usage: link_bin <src> | link_bin -c [dir...]" && return 1
            local src="${1:?}"
            if [[ -d "$src" ]]; then
                echo "$src is a directory" && return 1
            fi
            local src_name="$(basename "$src")"
            local target_dir="${bin:-$HOME/.local/bin}"
            local target="$target_dir/$src_name"
            if [[ ! -d "$target_dir" ]]; then
                mkdir -p "$target_dir" && echo "Created directory $target_dir" || { echo "Failed to create directory $target_dir" ; return 1 ; }
            fi
            ln -sf "$src" "$target" && 
            if find "$target_dir" -maxdepth 1 -name "$src_name" -type l > /dev/null 2>&1; then
                echo "Symlinked $src >>> $target done" 
            else
                echo "FAIL"
            fi
            ;;
    esac
}

# ============================================================
# sync-shared — DEPRECATED shim (single-repo mode)
# ============================================================
sync_shared() {
    echo "ℹ️  sync_shared is retired (single-repo ~/ssot). Use 'gt sync ssot' or 'mesh-sync' instead." >&2
    return 0
}
alias sshare='sync_shared'
alias ssync='sync_shared'
# ============================================================
# usdt_bk — Copy USDT_BEP20_BITKUB / BEP20_BK to clipboard
# ============================================================
usdt_bk(){
    local addr="${USDT_BEP20_BITKUB:-${BEP20_BK:-}}"
    if [[ -n "$addr" ]]; then
        cb_copy "$addr"
        cn lg b "copied "
        echo "$addr"
    else
        cn 196 b "❌ Wallet address not set (configure USDT_BEP20_BITKUB or BEP20_BK in ~/.env.secret)" >&2
        return 1
    fi
}
alias usdt=usdt_bk
