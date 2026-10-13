#!/usr/bin/env bash

# --  ใไฟล์สำหรับสร้าง คอมมานไว้ใช้ส่วนตัวเพื่อนความรวดเร๋วแบบไม่เป็นทางการ
bep20(){
	local ads=${BEP20_BK:?'not found'}
		echo $ads
		cb_copy "$ads"
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
        git clone "$url" "$dir" && perm "$installer" && bash "$installer" "$@"
    fi
}

multi_git_manager() {
    local selected_projects=()
    local git_args=()
    
    # 0. อ้างอิงตัวแปรสภาพแวดล้อม SSOT เป็นหลัก (Fallback เข้า Path เริ่มต้น)
    local ssot_dir="${SSOT_DIR:-$HOME/ssot}"
    local simulator_dir="${DICE_SIM_DIR:-${sim:-$HOME/simulator}}"
    local maths_dir="${MATHS_HELPER_DIR:-$HOME/.maths-helper}"

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
                git_args=("$@")
                break
                ;;
        esac
    done

    # 2. Default: เหมาหมดทุกโปรเจกต์ ถ้าไม่ได้ระบุ
    if [ ${#selected_projects[@]} -eq 0 ]; then
        selected_projects=(
            "ssot:$ssot_dir"
            "simulator:$simulator_dir"
            "maths-helper:$maths_dir"
        )
    fi

    # Default: ถ้าไม่มีคำสั่ง Git ให้ใช้ Quick Status (-q)
    if [ ${#git_args[@]} -eq 0 ]; then
        git_args=("-q")
    fi

    # 3. วนลูปประมวลผลคำสั่ง Git
    set -- "${git_args[@]}"

    while [[ $# -gt 0 ]]; do
        local cmd="$1"
        local shift_count=1
        local commit_msg="update"

        # ตรวจสอบ Message ของ -ac อย่างปลอดภัย (ไม่กลืนคำสั่งถัดไป)
        if [[ "$cmd" == "-ac" || "$cmd" == "--add-commit" || "$cmd" == "-sync" || "$cmd" == "--sync" ]]; then
            if [[ -n "${2:-}" && "$2" != -* ]]; then
                commit_msg="$2"
                shift_count=2
            fi
        fi

        for item in "${selected_projects[@]}"; do
            local p_name="${item%%:*}"
            local p_dir="${item#*:}"

            if [ ! -d "$p_dir" ]; then
                echo "⚠️ ไม่พบโฟลเดอร์สำหรับ $p_name ที่ $p_dir"
                continue
            fi

            # ดึงชื่อ branch ปัจจุบันเพื่อแสดงผล
            local current_branch
            current_branch="$(git -C "$p_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

            case "$cmd" in
                -q|--quick-status)
                    cn lg b "[$p_name @ $current_branch]"
                    git -C "$p_dir" status -sb
                    echo ""
                    ;;
                -s|--status)
                    cn lg b "GIT STATUS: $p_name ($current_branch)"
                    git -C "$p_dir" status
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -pu|--pull)
                    cn lg b "PULLING: $p_name ($current_branch)"
                    git -C "$p_dir" pull --rebase
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -p|--push)
                    cn lg b "PUSHING: $p_name ($current_branch)"
                    git -C "$p_dir" push
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -ac|--add-commit)
                    cn lg b "ADD & COMMIT: $p_name ($current_branch) -> \"$commit_msg\""
                    git -C "$p_dir" add -A
                    # ตรวจสอบก่อนว่ามีอะไรให้ commit หรือไม่ ป้องกัน error แดงหลอก
                    if git -C "$p_dir" diff --cached --quiet; then
                        echo "  (No changes to commit)"
                    else
                        git -C "$p_dir" commit -m "$commit_msg"
                    fi
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                -sync|--sync)
                    cn lg b "FULL SYNC: $p_name ($current_branch)"
                    echo "1. Adding and committing..."
                    git -C "$p_dir" add -A
                    if git -C "$p_dir" diff --cached --quiet; then
                        echo "  (Nothing to commit)"
                    else
                        git -C "$p_dir" commit -m "$commit_msg"
                    fi
                    echo "2. Pulling latest changes..."
                    if git -C "$p_dir" pull --rebase; then
                        echo "3. Pushing..."
                        git -C "$p_dir" push
                    else
                        echo "⚠️ Pull with rebase failed (check conflicts)"
                    fi
                    cn 235 b "-------------------------------"
                    echo ""
                    ;;
                *)
                    cn lg b "EXEC: git $@ in $p_name"
                    git -C "$p_dir" "$@"
                    cn 235 b "-------------------------------"
                    echo ""
                    shift_count=$#  # ส่ง arguments ที่เหลือให้คำสั่งนี้ทั้งหมด
                    ;;
            esac
        done

        shift "$shift_count"
    done
}


# ALIASES
alias gu='multi_git_manager'
alias guall='gu all -sync "quick update of all projects"'
git_note(){

    file_path="$hpc/Desktop/main_sync/git knowledge/Git basic.md"
    cat "$file_path"

}

# -- check funk,cmd
fcheck(){

	local main="$2"
	local true="("$2")"
	local false"("$3")"

	_yes_(){
		for cmd_t in "${true[@]}"; do
			eval "${cmd_t}" 
		done	
	 }
	_no_(){
		for cms_f in "${false[@]}"; do
			eval "${cmd_f}" 
		done	
	 }
	
	declare -f "$1" &> /dev/null  && $(_yes_ "${true[@]}" )  || $(_no_ "${false[@]}" )
					
}	

true=(
	"echo 1" 
	"cn 250 ok"
)

false=(
	"echo 2"
	"cn lg b not ok"
)