#!/usr/bin/env bash
# ============================================================
# 05-rcc.sh — Random Color Per Character Engine
# ============================================================
# API:
#   rcc  [style] <text>  — random color each char, Vibrant (RC_PALETTE_DEFAULT)
#   rcc1 [style] <text>  — Pastel/earthy per char  (RC_PALETTE_PASTEL)
#   rcc2 [style] <text>  — Bold/neon per char       (RC_PALETTE_NEON)
#   Rcc  [style] <text>  — calls rc per char (uses random_color engine)
#   rc_char              — alias for rcc
#
# Style: b=bold d=dim i=italic u=underline (combinable)
# No adjacent duplicate colors — each character gets a different color
#   than the character before it.
# ============================================================

_rc_char_render() {
    [[ -n "${ZSH_VERSION:-}" ]] && emulate -L sh
    local palette_str="$1"; shift
    local -a palette=($palette_str)

    local input_style=""
    if [[ $# -gt 1 && "$1" =~ ^[bdiu]{1,4}$ ]]; then
        input_style="$1"
        shift 1
    elif [[ $# -eq 1 && "$1" =~ ^[bdiu]{1,4}$ ]]; then
        input_style="$1"
        shift 1
    fi

    local style="" i char
    for (( i=0; i<${#input_style}; i++ )); do
        char="${input_style:$i:1}"
        case "$char" in
            b) style+="$(_b)" ;; d) style+="$(_d)" ;;
            i) style+="$(_i)" ;; u) style+="$(_u)" ;;
        esac
    done

    local targets=()
    if [[ $# -gt 0 ]]; then
        targets=("${@}")
    else
        targets=("No text provided")
    fi

    local last_color=""
    for text in "${targets[@]}"; do
        local length="${#text}"
        local result=""
        for (( i=0; i<length; i++ )); do
            local ch="${text:$i:1}"
            if [[ "$ch" == " " ]]; then
                result+=" "
                continue
            fi
            local avail=() c
            for c in "${palette[@]}"; do
                [[ "$c" != "$last_color" ]] && avail+=("$c")
            done
            [[ ${#avail[@]} -eq 0 ]] && avail=("${palette[@]}")
            local rand_idx=$(( RANDOM % ${#avail[@]} ))
            local chosen="${avail[$rand_idx]}"
            last_color="$chosen"
            result+="${style}$(_c "$chosen")${ch}"
        done
        echo -e "${result}$(_r)"
    done
}

# rcc — Vibrant rainbow, one random color per character
rcc()  { _rc_char_render "45 82 190 196 208 201 39 226 129 48 203 141" "$@"; }

# rcc1 — Pastel/earthy per character
rcc1() { _rc_char_render "167 173 136 71 68 105 132 178 150 139 174 180" "$@"; }

# rcc2 — Bold/neon per character
rcc2() { _rc_char_render "21 10 196 200 225 27 202 123 229 205" "$@"; }

# rc_char — alias for rcc
rc_char() { rcc "$@"; }

# Rcc — calls random_color (rc) for each character individually
Rcc() {
    local style=""
    local text=""

    if [[ $# -eq 1 ]]; then
        text="$1"
    else
        style="$1"
        shift
        text="$*"
    fi

    local i char
    for (( i=0; i<${#text}; i++ )); do
        char="${text:i:1}"
        rc "$style" "$char"
    done
}

