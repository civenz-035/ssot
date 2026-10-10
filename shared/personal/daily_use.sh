#!/usr/bin/env bash

# --  ใไฟล์สำหรับสร้าง คอมมานไว้ใช้ส่วนตัวเพื่อนความรวดเร๋วแบบไม่เป็นทางการ
b20_bk(){
	local ads=${BEP20_BK:?'not found'}
		echo $ads
		cb_copy "$ads"
}

# -- ssot sync to git-bash || wsl || wsl2
ssot_update() {
	
	cd "$HOME/ssot" || return 1
	git add .
	git commit -m "Update from $JOE_ENV"
	git push &&
	
	local to_gb="cp -r "$hwsl2/ssot" "$hpc""
	local to_wsl="cp -r "$hwsl2/ssot" "$hwsl""
	local to_wsl2="cp -r "$hwsl2/ssot" "$hwsl2""

	case "${1:-}" in 
		"gb") eval "$to_gb" && echo "done sync to git-bash" ;;
		"wsl") eval "$to_wsl" && echo "done sync to wsl" ;;
		"wsl2") eval "$to_wsl2" && echo "done sync to wsl2" ;;
		*) echo "Usage: upssot [gb|wsl|wsl2]" ;;
	esac
	
	
}

alias dice="bash $sim/bin/roll.sh"
alias dicepy="$_py $sim/bin/roll.py"
alias dcf='micro $sim/config/dice.env'

banner_(){
	local _bn_='
🎲 DICE SIMULATOR SHORTCUT (d)
─────────────────────────────────────────────────────────────
Commands:
  d -py [args...]          Run simulator (Python engine)
  d -sh [args...]          Run simulator (Bash engine)
  d -cc [calc-args...]     BaseBet & Risk Calculator
  d -sv                    Start Web Config Editor UI
  d -h                     Show this help banner

─────────────────────────────────────────────────────────────
Calculator Flags (d -cc):
  -b,  --balance <num>     Starting balance (e.g. 10000)
  -m,  --mul <float>       Loss multiplier (e.g. 1.06, 2.0)
  -c,  --chance <pct>      Win chance % (e.g. 49.5, 3.96)
  -n,  --max-loss-n <N>    Manual streak target (จุดพัง N ไม้)
  -r,  --risk <prob>       Risk threshold for Auto N (0.001=0.1%, 0.0001=0.01%)
  -cov,--coverage <pct>    Balance coverage fraction (1.0 = 100%, 0.8 = 80%)
       --save              Auto-save solved BaseBet & N to config/dice.env

─────────────────────────────────────────────────────────────
Examples:
  # 1) Auto N from risk threshold (คำนวณ N อัตโนมัติจาก Risk):
  d -cc -b 10000 -m 2.0 -c 49.5 --risk 0.0001

  # 2) Manual Target N (กำหนดจุดพัง N ไม้ตรงๆ):
  d -cc -b 10000 -m 1.06 -c 3.96 -n 50

  # 3) Budget 80% coverage + Save to config:
  d -cc -b 10000 -m 1.06 -c 3.96 -n 50 -cov 0.8 --save
'
echo "$_bn_"
}

d(){
	local dice_dir="$sim/bin"
	local type=$1
	shift
	
	case "$type" in
		-sh|--bash)
				bash "$dice_dir/roll.sh" "$@"
				;;
		-py|--python)
				$_py "$dice_dir/roll.py" "$@"
				;;
		-cc|--cals)
				$_py "$dice_dir/roll.py" calc "$@"
				;;
		-sv|--server)
				cd "$$sim" && $_py server/dice-server.py
				;;
		-h|--help)
				banner_ 
				;;
	esac	
	
	
	
}


gclone() {
    local proj="${1:-ssot}"
    
    # เลื่อน argument เพื่อดึงตัวถัดไปมาใช้
    # หากมีการส่ง $1 มา ให้ตัด $1 ทิ้ง เพื่อให้ $@ เหลือเฉพาะค่าที่จะส่งต่อให้ installer
    [ $# -gt 0 ] && shift

    local dir=""
    local url=""
    local installer=""

    case "$proj" in
        ssot|-ssot|--SSOT)
            dir="$HOME/ssot"
            url="https://github.com/civenz-035/ssot.git"
            installer="$dir/bootstrap/install.sh"
            ;;
        mhp|-mhp|--maths-helper)
            dir="$HOME/.maths-helper"
            url="https://github.com/civenz-035/maths-helper.git"
            installer="$dir/install.sh"
            ;;
        sim|-sim|--simulator)
            dir="$HOME/simulator"
            url="https://github.com/civenz-035/math-simulator.git"
            installer="$dir/install.sh"
            ;;
        *)
            echo "Error: Unknown project '$proj'" >&2
            return 1
            ;;
    esac

    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is not installed." >&2
        return 1
    fi

    if [ -d "$dir" ]; then
        echo "Directory '$dir' already exists. Updating via git pull..."
        git -C "$dir" pull && bash "$installer" "$@"
    else
        echo "Cloning $proj into$dir..."
        git clone "$url" "$dir" && bash "$installer" "$@"
    fi
}

quick_git_update() {
    local selected_projects=()
    local git_args=()
    
    local ssot_dir="$HOME/ssot"
    local simulator_dir="$HOME/simulator"
    local maths_dir="$HOME/.maths-helper"

    # 1. คัดแยกชื่อโปรเจกต์
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -ssot|--SSOT|--ssot|ssot)
                selected_projects+=("ssot:$ssot_dir")
                shift
                ;;
            -sim|--simulator|-d|--dice-simulator|sim|simulator)
                selected_projects+=("simulator:$simulator_dir")
                shift
                ;;
            -mhp|--maths|-m|--maths-helper|maths)
                selected_projects+=("maths-helper:$maths_dir")
                shift
                ;;
            -a|--all|all)
                selected_projects=(
                    "ssot:$ssot_dir"
                    "simulator:$simulator_dir"
                    "maths-helper:$maths_dir"
                )
                shift
                ;;
            *)
                # พอเจอคำสั่งที่ไม่ใช่โปรเจกต์ ให้เบรกแล้วเก็บที่เหลือเป็นคำสั่ง Git
                git_args=("$@")
                break
                ;;
        esac
    done

    # 2. ถ้าไม่ได้ระบุโปรเจกต์เลย ให้เหมาหมด (All)
    if [ ${#selected_projects[@]} -eq 0 ]; then
        selected_projects=(
            "ssot:$ssot_dir"
            "simulator:$simulator_dir"
            "maths-helper:$maths_dir"
        )
    fi

    # ถ้าไม่ได้ใส่คำสั่งอะไรมา ให้ default เป็น status
    if [ ${#git_args[@]} -eq 0 ]; then
        git_args=("-s")
    fi

    # 3. ประมวลผลคำสั่ง Git วนลูปตามโปรเจกต์ที่ถูกเลือก
    set -- "${git_args[@]}"

    while [[ $# -gt 0 ]]; do
        local cmd="$1"

        for item in "${selected_projects[@]}"; do
            local p_name="${item%%:*}"
            local p_dir="${item#*:}"

            if [ ! -d "$p_dir" ]; then
                echo "⚠️ ไม่พบโฟลเดอร์สำหรับ $p_name ที่ $p_dir"
                continue
            fi

            case "$cmd" in
                -p|--push)
                    cn lg b "PUSHING ${p_name}"
                    git -C "$p_dir" push
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -ac|--add-commit)
                    local msg="${2:-update}"
                    cn lg b "ADD COMMIT ${p_name}"
                    git -C "$p_dir" add -A && git -C "$p_dir" commit -m "$msg"
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -pu|--pull)
                    cn lg b "PULLING ${p_name}"
                    git -C "$p_dir" pull
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -pure|--pull-rebase)
                    cn lg b "PULLING (rebase) ${p_name}"
                    git -C "$p_dir" config pull.rebase true && git -C "$p_dir" pull
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -s|--status)
                    cn lg b "GIT STATUS in ${p_name}"
                    git -C "$p_dir" status
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                *)
                    cn lg b "exec git $@ in ${p_name}"
                    git -C "$p_dir" "$@"
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
            esac
        done

        case "$cmd" in
            -ac|--add-commit) shift 2 ;;
            -p|--push|-pu|--pull|-pure|--pull-rebase|-s|--status) shift 1 ;;
            *) break ;;
        esac
    done
}

# ALIASES
alias gu='quick_git_update'
alias guall='gu all -ac "quick update of all projects" -s -p'
