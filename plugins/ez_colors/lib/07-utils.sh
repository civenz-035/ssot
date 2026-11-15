#!/usr/bin/env bash
# ============================================================
# 07-utils.sh — Status Helpers, Color Charts & Comparisons
# ============================================================
# API:
#   _warn  <text>  — yellow bold warning   (⚠)
#   _er    <text>  — red bold error        (⛔)
#   _sc    <text>  — green bold success    (✅)   alias: _ok
#   _ep    <text>  — cyan bold explain     (ℹ)
#
#   c256            — print full 256-color fg chart (16 per row)
#   c256bg          — print full 256-color bg chart with auto-contrast labels
#   c256_           — verbose chart: block + code per color
#
#   color_comparison  <code...>  — solid bars for each color code  alias: cmp
#   color_comparison2 <code...>  — per-char random comparison       alias: cmp2
# ============================================================

# Status helpers
_warn() { cn y  b "$@ ⚠";  }
_er()   { cn 196 b "$@ ⛔"; }
_sc()   { cn lg  b "$@ ✅"; }
_ok()   { _sc "$@"; }
_ep()   { cn 45  b "$@ ";  }

# 256-color foreground chart
c256() {
    local i
    for i in {0..255}; do
        printf "%s%3d%s " "$(_c "$i")" "$i" "$(_r)"
        (( (i+1)%16==0 )) && echo
    done
}

# 256-color background chart (auto-contrast text color)
c256bg() {
    local i fg val r g b lum
    for i in {0..255}; do
        if (( i < 16 )); then
            case "$i" in 0|1|2|4|5|8) fg=15 ;; *) fg=0 ;; esac
        elif (( i >= 232 )); then
            (( i > 243 )) && fg=0 || fg=15
        else
            val=$(( i - 16 ))
            r=$(( val / 36 ))
            g=$(( (val % 36) / 6 ))
            b=$(( val % 6 ))
            lum=$(( r * 30 + g * 59 + b * 11 ))
            (( lum > 240 )) && fg=0 || fg=15
        fi
        printf "%s%s%3d%s " "$(_bg "$i")" "$(_c "$fg")" "$i" "$(_r)"
        (( (i+1)%16==0 )) && echo
    done
}

# c256_ — verbose chart: colored block + code per color
c256_() {
    local i
    for i in {0..255}; do
        local block
        block=$(color_comparison2 "$i")
        printf "%s code = %s\n" "$block" "$i"
        (( (i+1)%16==0 )) && echo
    done
}

# color_comparison — solid color bars
color_comparison() {
    local colors=("$@")
    for color_ in "${colors[@]}"; do
        local bar
        bar=$(color "$color_" b "█████████████████████████")
        printf "∎%s∎\n" "$bar"
    done
}
alias cmp='color_comparison'

# color_comparison2 — per-character random color bars
color_comparison2() {
    local colors=("$@")
    for color_ in "${colors[@]}"; do
        local b
        b=$(rcc b "█████████████████████████")
        printf "∎%s%s%s∎\n" "$b" "$b" "$b"
    done
}
alias cmp2='color_comparison2'

