#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test_scripts.sh
# ------------------------------------------------------------

source "$HOME/.bashrc"

joe_update() {
    local project=("ssot" "dice-simulator" "maths-helper")
    local ssot_dir="$HOME/ssot"
    local dice-simulator_dir="$HOME/dice-simulator"
    local maths-helper_dir="$HOME/.maths-helper"


    while [[ $# -gt 0 ]]; do
        local cmd="$1"

        for p in "${project[@]}"; do
            local dir=""
            case "$p" in
                "ssot") dir="$ssot_dir" ;;
                "dice-simulator") dir="$dice-simulator_dir" ;;
                "maths-helper")  dir="$maths-helper_dir"  ;;
            esac

            case "$cmd" in
            -p|--push)
				cn lg b "PUSHING ${p}"
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git push
                cn 235 b "-------------------------------"  
                echo ""
                ;;
            -ac|--add-commit)
                cn lg b "ADD COMMIT ${p}"
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git add -A && git commit -m "$2"
                cn 235 b "-------------------------------"  
                echo ""
                ;;
            -pu|--pull)
                cn lg b "PULLING ${p}"
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git pull
                cn 235 b "-------------------------------"  
                echo ""
                ;;
            -s|--status)
                cn lg b "GIT STATUS in ${p}"
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git status
                cn 235 b "-------------------------------"  
                echo ""
                ;;
            esac
        done

        # shift หลังจาก for loop รันครบทุก project
        case "$cmd" in
            -ac|--add-commit) shift 2 ;;  # กิน 2 args (flag + message)
            *)                shift 1 ;;  # กิน 1 arg
        esac
    done
}

joe_update -pu -ac "TESTING" -p

           