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

alias dice="bash $DICE_SIM_DIR/bin/roll.sh"
alias dicepy="$_py $DICE_SIM_DIR/bin/roll.py"
alias dcf='micro $DICE_SIM_DIR/config/dice.env'

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
	local dice_dir="$DICE_SIM_DIR/bin"
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
				cd "$DICE_SIM_DIR" && $_py server/dice-server.py
				;;
		-h|--help)
				banner_ 
				;;
	esac	
	
	
	
}

ms(){
	local mode=$1
	shift
	case "$mode" in
		-s|-status) mesh-sync status ;; # ดูทุก node
		-pl|--pull) mesh-sync pull ;;  # ของเครื่องนี้ (เหมือน git pull)
		-pu|--push) mesh-sync push ;; # ของเครื่องนี้ (เหมือน git push)
		-sy|--sync) mesh-sync sync ;; # git pull แล้ว push
		-fp|--fanpull) mesh-sync fanpull ;; # pull จากทุกเครื่อง ที่ออนไลน์
		-fpn|--fanpush) mesh-sync fanpush ;; # push ไปยังทุกเครื่อง ที่ออนไลน์
		-b|--broadcast) mesh-sync broadcast ;; # fanpull ทุกเครื่อง แล้วค่อย push
		-pn|--pull-node) mesh-sync pull-node ;; # เจาะจง node
		-h|--help) echo "Usage: ms [options]" ;;  
		*) echo "Usage: ms [options]" ;;  
	esac


}

go2(){
	local ssot_dir=$ssot
	cd ${ssot_dir} && pwd 
	git status
	case "$1" in
			-a
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
            dir="$HOME/math-simulator"
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
