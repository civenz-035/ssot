#!/usr/bin/env bash
# ------------------------------------------------------------
# File: solve.sh
# ------------------------------------------------------------

# --- source maths functions ---
source "$HOME/.bashrc"

joe_update(){

	local project=("ssot" "msim" "mhp")
	local ssot_dir="$HOME/ssot"
	local msim_dir="$HOME/dice-simulator"
	local mhp_dir="$HOME/.maths-helper"

	


	local cmd=$1 p
cn 240 b "∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎"
	for p in "${project[@]}"; do
		local dir=""
		case "$p" in
		"ssot")
			local dir="$ssot_dir"
			;;
		"msim")
			local dir="$msim_dir"
			;;
		"mhp")
			local dir="$mhp_dir"
			;;	
		esac

		case "$cmd" in
		-p|--push)
            cd "$dir" &&
            cn 45 b "PROJECT = ${p}"
            echo ""
            echo "DIR = $dir"
            echo ""
            git push
			;;
		-ac|--add-commit)
            cd "$dir" &&
            cn 45 b "PROJECT = ${p}"
            echo ""
            echo "DIR = $dir"
            echo ""
            git add -A
            git commit -m "$2"
            shift 2
			
			;;
		-pu|--pull)
            cd "$dir" &&
            cn 45 b "PROJECT = ${p}"
            echo ""
            echo "DIR = $dir"
            echo ""
            git pull
			;;
		-s|--status)
			cn 45 b "PROJECT = ${p}"
            echo ""
            echo "DIR = $dir"
            echo ""
            cd $dir && git status
            cn 240 b "∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎"
            shift   
			;;
		*)
			
			;;
		esac
		
	done
}

joe_update -ac "TESTING" -s

           