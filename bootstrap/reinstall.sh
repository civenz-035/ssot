reinstall() {
    local repo="${1:-ssot}"
    local device="${2:-}"
    local ssot_dir="$HOME/ssot"
    local bk_dir="$HOME/.ssot-backups/installationbk"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    # ── Single-repo mode: only ~/ssot is supported ──
    # Legacy args (bsc|bashscripts|all|both) are kept as deprecated shims.
    case "$repo" in
        ssot|"")
            repo="ssot"
            ;;
        bsc|bashscripts|all|both)
            echo "⚠️  '$repo' is deprecated — single-repo mode uses ~/ssot only." >&2
            echo "   Continuing with reinstall ssot…" >&2
            repo="ssot"
            # device may have been passed as $1 on legacy calls like `reinstall all wsl`
            # (already handled: $device holds $2, keep as-is)
            ;;
        *)
            echo "Usage: reinstall [ssot] [device]"
            echo "  ssot  → reinstall ~/ssot (default, single repo)"
            return 1
            ;;
    esac

    local target_dir="$ssot_dir"
    local target_name="ssot"

    # ── Backup if exists ──
    if [[ -d "$target_dir" ]]; then
        mkdir -p "$bk_dir"
        local bak_path="$bk_dir/${target_name}_${timestamp}"
        mv "$target_dir" "$bak_path"
        echo "📦 Backed up: $target_dir → $bak_path"
    fi

    # ── Clone fresh ──
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
