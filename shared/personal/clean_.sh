del_cache(){
    sudo apt-get clean
    sudo apt-get autoremove -y
    rm -rf ~/.cache/*
    sudo rm -rf /tmp/*
    echo "Done!"
    echo "Free space: $(df -h / | awk 'NR==2 {print $4}')"
    df -h /
}
alias cc='del_cache'

pgb(){
    if [[ "$#" -gt 0 ]]; then
        g "$@"
    fi
    
    rm -rf "$hpc/ssot/" && cn lg b "removed hpc/ssot " && \
    cp -r "$hwsl/ssot/" "$hpc" && cn 45 b "done copy ssot from wsl to hpc" 
}

alias ssh_ad="$SSOT/bootstrap/script/ssh_audit.sh"

bk_clean(){
		local tar=${1:-}
		local files f 
		files=$(find "$tar" -type f -iname "*bak*" | sort)
		for f in ${files[@]}; do
			echo $f
		done	
}

# รายการ Symlink ทั้งหมดภายใต้การจัดการของ SSOT
SSOT="${SSOT:-$HOME/ssot}"
ssot_link=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.local/bin/joe"
    "$HOME/.local/bin/node-status"
    "$HOME/.local/bin/shared"
    "$HOME/.local/bin/env"
    "$SSOT/.env"
    "$SSOT/.env.secret"
)

link_check(){
    local link_to=""
    local f_path=""
    for f in "${ssot_link[@]}"; do
        f_path="${f/#$HOME/\~}"
        if [[ -L "$f" ]]; then
            link_to=$(readlink "$f" 2>/dev/null)
            if [[ -e "$f" ]]; then
                cn 250 b "$f_path -> $(cn lg "" "${link_to/#$HOME/\~}")"
            else
                cn 1 b "$f_path -> $(cn 1 "" "${link_to/#$HOME/\~} [BROKEN]")"
            fi
        elif [[ -e "$f" ]]; then
            cn 214 b "$f_path not a symlink (regular file)"
        else
            cn 240 b "$f_path not found"
        fi
    done
}


# ─── Inner helper: run one subcommand for a given HOME_DIR ───────────────────
_link_all_run(){
    local HOME_DIR="$1"; shift    # first arg = resolved home path
    local subcmd="$1";  shift     # second arg = subcommand flag
    local extra_arg="${1:-}"      # optional arg (e.g. directory for -c)

    cn 45 b "── [${HOME_DIR}] ──"

    case "$subcmd" in
        -r|--relink-ssot)
            local ssot_dir="$HOME_DIR/ssot"
            local node_host="${NODE_HOST:-$(echo "${JOE_ENV:-wsl2}" | tr '[:upper:]' '[:lower:]')}"

            if [[ ! -d "$ssot_dir" ]]; then
                cn 1 b "SSOT directory not found: $ssot_dir"; return 1
            fi

            local -A links=(
                ["$HOME_DIR/.bashrc"]="$ssot_dir/profiles/$node_host/.bashrc"
                ["$HOME_DIR/.zshrc"]="$ssot_dir/profiles/$node_host/.zshrc"
                ["$HOME_DIR/.local/bin/joe"]="$ssot_dir/joe.sh"
                ["$HOME_DIR/.local/bin/node-status"]="$ssot_dir/bootstrap/nodes/node-status.sh"
                ["$HOME_DIR/.local/bin/shared"]="$ssot_dir/tools/sync_shared.sh"
                ["$HOME_DIR/.local/bin/env"]="$ssot_dir/bootstrap/templates/env"
                ["$ssot_dir/.env"]="$HOME_DIR/.env"
                ["$ssot_dir/.env.secret"]="$HOME_DIR/.env.secret"
            )

            for target in "${!links[@]}"; do
                local target_path="${target/#$HOME_DIR/\~}"
                if [[ -L "$target" ]]; then
                    rm -f "$target" && cn 250 b "cleaned symlink: $target_path"
                elif [[ -e "$target" ]]; then
                    cn 214 b "skip non-symlink (preserving): $target_path"
                fi
            done

            mkdir -p "$HOME_DIR/.local/bin"

            for target in "${!links[@]}"; do
                local source="${links[$target]}"
                if [[ -e "$source" ]]; then
                    ln -sf "$source" "$target" && cn lg b "linked ${source/#$HOME_DIR/\~} -> ${target/#$HOME_DIR/\~}"
                else
                    cn 1 b "source not found: ${source/#$HOME_DIR/\~}"
                fi
            done
            ;;

        -rm|--relink-math)
            local mth_dir="${mhp:-$HOME_DIR/.maths-helper}"

            if [[ ! -d "$mth_dir" ]]; then
                cn 1 b "maths helper not found: $mth_dir"; return 1
            fi

            local -A links=(
                ["$HOME_DIR/.local/bin/mth"]="$mth_dir/bin/mth"
                ["$HOME_DIR/.local/bin/slv"]="$mth_dir/bin/slv"
                ["$HOME_DIR/.local/bin/cals"]="$mth_dir/bin/mth"
                ["$HOME_DIR/.local/bin/solve"]="$mth_dir/bin/slv"
                ["$mth_dir/.env"]="$HOME_DIR/.env"
                ["$mth_dir/.env.secret"]="$HOME_DIR/.env.secret"
            )

            for target in "${!links[@]}"; do
                local target_path="${target/#$HOME_DIR/\~}"
                if [[ -L "$target" ]]; then
                    rm -f "$target" && cn 250 b "cleaned symlink: $target_path"
                elif [[ -e "$target" ]]; then
                    cn 214 b "skip non-symlink (preserving): $target_path"
                fi
            done

            mkdir -p "$HOME_DIR/.local/bin"

            for target in "${!links[@]}"; do
                local source="${links[$target]}"
                if [[ -e "$source" ]]; then
                    ln -sf "$source" "$target" && cn lg b "linked ${source/#$HOME_DIR/\~} -> ${target/#$HOME_DIR/\~}"
                else
                    cn 1 b "source not found: ${source/#$HOME_DIR/\~}"
                fi
            done
            ;;

        -c|--check)
            local directory="${extra_arg:-$HOME_DIR/.local/bin}"
            if [[ ! -d "$directory" ]]; then
                cn 1 b "directory not found: $directory"; return 1
            fi
            local count=0
            local file_to=""
            while IFS= read -r -d '' f; do
                file_to=$(readlink "$f" 2>/dev/null)
                if [[ -e "$f" ]]; then
                    cn 250 b "${f/#$HOME_DIR/\~} -> $(cn 45 b "${file_to/#$HOME_DIR/\~}")"
                else
                    cn 1 b "${f/#$HOME_DIR/\~} -> $(cn 1 b "${file_to/#$HOME_DIR/\~} [BROKEN]")"
                fi
                (( count++ ))
            done < <(find "$directory" -maxdepth 1 -type l -print0 2>/dev/null)
            [[ $count -eq 0 ]] && echo "No links found in $directory" || echo "Total links: $count"
            ;;

        -s|--show)
            _link_all_run "$HOME_DIR" -c "$HOME_DIR/.local/bin"
            ;;

        *)
            echo "Usage: link_all {[-wsl|-wsl2|-gb]...} {-r|--relink-ssot | -rm|--relink-math | -c|--check [dir] | -s|--show}"
            ;;
    esac
}

# ─── Public entry: collect devices → loop ────────────────────────────────────
link_all(){
    local -a devices=()   # เก็บ resolved home paths ทุก device ที่ระบุ
    local subcmd=""
    local extra_arg=""

    # Phase 1: collect device flags (รับได้หลายตัว ลำดับใดก็ได้)
    while (( $# > 0 )); do
        case "$1" in
            -wsl|--wsl)      devices+=("${hwsl:-$HOME}");  shift ;;
            -wsl2|--wsl2)    devices+=("${hwsl2:-$HOME}"); shift ;;
            -gb|--git-bash)  devices+=("${hpc:-$HOME}");   shift ;;
            *) break ;;
        esac
    done

    # ถ้าไม่ได้ระบุ device เลย → ใช้ current HOME
    [[ ${#devices[@]} -eq 0 ]] && devices+=("$HOME")

    # Phase 2: parse subcommand
    subcmd="${1:-}"; shift || true
    extra_arg="${1:-}"

    # Phase 3: run subcommand for each device
    for HOME_DIR in "${devices[@]}"; do
        _link_all_run "$HOME_DIR" "$subcmd" "$extra_arg"
    done
}