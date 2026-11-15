#!/usr/bin/env bash
# ============================================================
# 04-random.sh — Random Color Engine (Stateful, Slot-based)
# ============================================================
# API:
#   random_core [-n|-e|-p] [roll|get|last] [slot] [palette]
#     roll  — pick a new color and store in slot (default: "default")
#     get   — read slot's current color (auto-rolls if empty)
#     last  — read the most recently rolled color
#     -n    → return 256-color number  (default)
#     -e    → return ANSI escape sequence
#     -p    → return PS1-safe escape
#
#   random_color [-s slot] [-k] [-p] [-0] [--palette str] [style] [text...]
#     -s/--slot <name>   — bind color to a named slot
#     -k/--keep          — reuse the last rolled color
#     -p/--ps            — PS1-safe render
#     -0                 — no newline (like c)
#     --palette <str>    — override palette
#
#   rc  [style] <text>  — Vibrant rainbow (RC_PALETTE_DEFAULT)
#   rc1 [style] <text>  — Pastel/earthy   (RC_PALETTE_PASTEL)
#   rc2 [style] <text>  — Bold/neon       (RC_PALETTE_NEON)
#   rc3 [style] <text>  — Dim/dark        (RC_PALETTE_DIM)
#   rc4                 — alias for rc3
# ============================================================

random_core() {
    [[ -n "${ZSH_VERSION:-}" ]] && emulate -L sh

    local out_mode="num"
    local action="get"
    local slot="default"
    local palette_str="$RC_PALETTE_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--num) out_mode="num"; shift ;;
            -e|--esc) out_mode="esc"; shift ;;
            -p|--ps)  out_mode="ps";  shift ;;
            roll|get|last) action="$1"; shift ;;
            *)
                if [[ "$slot" == "default" ]]; then
                    slot="$1"
                else
                    palette_str="$1"
                fi
                shift
                ;;
        esac
    done

    # PID-scoped state directory (shared across subshells, isolated per session)
    local state_dir="$HOME/tmp_rc/.rc_state_$$"
    [[ ! -d "$state_dir" ]] && mkdir -m 700 -p "$state_dir" 2>/dev/null

    local selected=""

    if [[ "$action" == "last" ]]; then
        [[ -f "$state_dir/_last" ]] && read -r selected < "$state_dir/_last" 2>/dev/null || true
        [[ -z "$selected" ]] && action="roll"
    elif [[ "$action" == "get" ]]; then
        [[ -f "$state_dir/$slot" ]] && read -r selected < "$state_dir/$slot" 2>/dev/null || true
        [[ -z "$selected" ]] && action="roll"
    fi

    if [[ "$action" == "roll" ]]; then
        [[ -z "$palette_str" ]] && palette_str="${RC_PALETTE_DEFAULT:-45 82 190 196 208 201 39 226 129 48 203 141}"

        local -a palette=($palette_str)
        local offset=0
        local test_arr=(x)
        [[ "${test_arr[0]}" != "x" ]] && offset=1

        local last_color=""
        [[ -f "$state_dir/_last" ]] && read -r last_color < "$state_dir/_last" 2>/dev/null || true

        local avail=() c
        for c in "${palette[@]}"; do
            [[ "$c" != "$last_color" ]] && avail+=("$c")
        done
        [[ ${#avail[@]} -eq 0 ]] && avail=("${palette[@]}")

        if (( ${#avail[@]} == 0 )); then
            avail=(45)
        fi

        local rand_val
        rand_val=$(date +%s%N 2>/dev/null | tr -dc '0-9' | tail -c 4)
        local ri=$(( (10#${rand_val:-$$} + RANDOM) % ${#avail[@]} ))
        selected="${avail[$(( ri + offset ))]}"

        printf "%s\n" "$selected" > "$state_dir/$slot" 2>/dev/null
        printf "%s\n" "$selected" > "$state_dir/_last" 2>/dev/null
    fi

    case "$out_mode" in
        num) printf "%s" "$selected" ;;
        esc) _c "$selected" ;;
        ps)  printf '\[\e[38;5;%sm\]' "$selected" ;;
    esac
}

# Legacy wrapper for backward compatibility
_rc_core() {
    random_core -e roll default "${1:-$RC_PALETTE_DEFAULT}"
}

# random_color — Presentation & Rendering Layer
random_color() {
    local slot=""
    local use_last=0
    local is_ps=0
    local nl=1
    local style=""
    local palette_str="$RC_PALETTE_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--slot)   slot="$2"; shift 2 ;;
            -k|--keep)   use_last=1; shift ;;
            -p|--ps)     is_ps=1; nl=0; shift ;;
            -0)          nl=0; shift ;;
            --palette)   palette_str="$2"; shift 2 ;;
            b|d|i|u|bd|bi|bu|di|du|iu|bdi|bdu|biu|diu|bdiu)
                         style="$1"; shift ;;
            *)           break ;;
        esac
    done

    local col_num
    if [[ $use_last -eq 1 ]]; then
        col_num=$(random_core last)
    elif [[ -n "$slot" ]]; then
        col_num=$(random_core get "$slot" "$palette_str")
    else
        col_num=$(random_core roll default "$palette_str")
    fi

    if [[ $is_ps -eq 1 ]]; then
        psc "$col_num" "$style" "$@"
    elif [[ $nl -eq 0 ]]; then
        c "$col_num" "$style" "$@"
    else
        cn "$col_num" "$style" "$@"
    fi
}

# Convenience wrappers — one per palette
rc()  { random_color --palette "$RC_PALETTE_DEFAULT" "$@"; }
rc1() { random_color --palette "$RC_PALETTE_PASTEL"  "$@"; }
rc2() { random_color --palette "$RC_PALETTE_NEON"    "$@"; }
rc3() { random_color --palette "$RC_PALETTE_DIM"     "$@"; }
rc4() { random_color --palette "$RC_PALETTE_DIM"     "$@"; }  # alias for rc3

