#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test_scripts.sh
# ------------------------------------------------------------

# --- source maths functions ---
source "$HOME/.bashrc"

joe_update() {
    local project=("ssot" "msim" "mhp")
    local ssot_dir="$HOME/ssot"
    local msim_dir="$HOME/dice-simulator"
    local mhp_dir="$HOME/.maths-helper"

    cn 235 b "∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎"

    # วน flag ทีละตัว
    while [[ $# -gt 0 ]]; do
        local cmd="$1"

        for p in "${project[@]}"; do
            local dir=""
            case "$p" in
                "ssot") dir="$ssot_dir" ;;
                "msim") dir="$msim_dir" ;;
                "mhp")  dir="$mhp_dir"  ;;
            esac

            case "$cmd" in
            -p|--push)
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git push
                ;;
            -ac|--add-commit)
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git add -A && git commit -m "$2"
                ;;
            -pu|--pull)
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git pull
                ;;
            -s|--status)
                cd "$dir" && cn 45 b "PROJECT = ${p}" && git status
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

joe_update -ac "TESTING" -s

           