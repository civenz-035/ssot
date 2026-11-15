#!/usr/bin/env bash
# ============================================================
# 02-render.sh — Core Color Render Engine
# ============================================================
# API:
#   c   <color> [style] <text...>  — print colored text, NO newline
#   cn  <color> [style] <text...>  — print colored text + newline
#   psc <color> [style] <text...>  — PS1-safe (wraps escapes in \[...\])
#   color <color> [style] <text...> — legacy alias (with newline)
#
#   cbg  [-ps] [-n] [-e] <color> <text>  — background-only color, preserve fg
#   cbgl [-ps] [-e] <color> <text>       — same + newline
#
# Color argument:
#   0-255          → 256-color number
#   r g y cr b m w gr ora lr lb lg lm lc → named short aliases
#   rc rc1 rc2 rc3 rc4 rand  → random palette colors
#   rc:<slot>                → random, slot-pinned
# Style argument (optional, before text):
#   b=bold  d=dim  i=italic  u=underline  (combinable: "bu" "bdi" etc.)
# ============================================================

_color_render() {
    local nl="$1"; shift
    local input_color="${1:-""}"

    local is_ps=0
    [[ "$nl" == "ps" ]] && is_ps=1

    # 0. Pre-scan: extract --bg <num|rc|rc:slot> and --reset-bg / --rbg
    local bg_esc=""
    local reset_bg=0
    local _args_new=()
    local _skip_next=0
    for _a in "$@"; do
        if [[ $_skip_next -eq 1 ]]; then
            if [[ "$_a" =~ ^(rc|rand)$ ]]; then
                _a="$(random_core roll default)"
            elif [[ "$_a" =~ ^(rc|rand): ]]; then
                _a="$(random_core get "${_a#*:}")"
            fi
            if [[ "$_a" =~ ^[0-9]+$ && "$_a" -ge 0 && "$_a" -le 255 ]]; then
                bg_esc="$(_bg "$_a")"
            fi
            _skip_next=0
            continue
        fi
        if [[ "$_a" == "--bg" ]]; then
            _skip_next=1
            continue
        fi
        if [[ "$_a" == "--reset-bg" || "$_a" == "--rbg" ]]; then
            reset_bg=1
            continue
        fi
        _args_new+=("$_a")
    done
    set -- "${_args_new[@]}"

    local eol="\n"
    [[ "$nl" == "0" || $is_ps -eq 1 ]] && eol=""

    # Standalone reset-bg without extra arguments
    if [[ $# -eq 0 ]]; then
        if [[ $reset_bg -eq 1 ]]; then
            if [[ $is_ps -eq 1 ]]; then
                printf '\[%b%b\]%s' "${bg_esc}" "$(_rbg)" "${eol}"
            else
                printf "${bg_esc}$(_rbg)${eol}"
            fi
            return 0
        fi
        input_color=""
    else
        input_color="${1:-""}"
    fi

    # 1. Resolve color (Keywords, Named slots, & Short names)
    local color_=""
    case "$input_color" in
        rc|rand)
            input_color="$(random_core roll default)"
            ;;
        rc1|rand1)
            input_color="$(random_core roll default "$RC_PALETTE_PASTEL")"
            ;;
        rc2|rand2)
            input_color="$(random_core roll default "$RC_PALETTE_NEON")"
            ;;
        rc3|rand3)
            input_color="$(random_core roll default "$RC_PALETTE_DIM")"
            ;;
        rc4|rand4)
            input_color="$(random_core roll default "$RC_PALETTE_DIM")"
            ;;
        rc:*|rand:*)
            local _slot="${input_color#*:}"
            input_color="$(random_core get "$_slot")"
            ;;
        r)   color_="$R"   ;;  lr)  color_="$LR"  ;;
        g)   color_="$G"   ;;  lg)  color_="$LG"  ;;
        y)   color_="$Y"   ;;
        cr)  color_="$CR"  ;;  lcr|lc) color_="$LCR" ;;
        b)   color_="$B"   ;;  lb)  color_="$LB"  ;;
        m)   color_="$M"   ;;  lm)  color_="$LM"  ;;
        w)   color_="$W"   ;;  gr)  color_="$GR"  ;;
        ora) color_="$ORA" ;;
        *)   color_=""     ;;
    esac

    # 2. Build style prefix — only when arg 2 is a real style token
    local style=""
    if [[ $# -ge 2 && ("$2" == "" || "$2" =~ ^[bdiu]{1,4}$) ]]; then
        local s="$2"
        for (( i=0; i<${#s}; i++ )); do
            local char="${s:$i:1}"
            case "$char" in
                b) style+="$(_b)" ;;
                d) style+="$(_d)" ;;
                i) style+="$(_i)" ;;
                u) style+="$(_u)" ;;
            esac
        done
        shift 2
    else
        shift 1
    fi

    local targets=()
    if [[ $# -gt 0 ]]; then
        targets=("${@}")
    elif [[ $is_ps -eq 1 ]]; then
        local _active_esc="${bg_esc}${color_}${style}"
        if [[ "$input_color" =~ ^[0-9]+$ ]] && [[ "$input_color" -ge 0 ]] && [[ "$input_color" -le 255 ]]; then
            _active_esc="${bg_esc}${style}$(_c "$input_color")"
        fi
        if [[ -n "$_active_esc" ]]; then
            printf '\[%b\]' "$_active_esc"
        else
            printf '\[%b\]' "$(_r)"
        fi
        return 0
    else
        targets=("No text provided")
    fi

    # 4. Render
    local rst="$(_r)"
    [[ $reset_bg -eq 1 ]] && rst="$(_rbg)"
    [[ $is_ps -eq 1 ]] && rst="\[${rst}\]"

    for text in "${targets[@]}"; do
        if [[ "$input_color" =~ ^[0-9]+$ ]] && [[ "$input_color" -ge 0 ]] && [[ "$input_color" -le 255 ]]; then
            # 256-color path
            if [[ $is_ps -eq 1 ]]; then
                printf '\[%b\]%s%b' "${bg_esc}${style}$(_c "$input_color")" "$text" "$rst"
            else
                printf "${bg_esc}${style}$(_c "$input_color")%s${rst}${eol}" "$text"
            fi
        else
            # Short-name path (V2 vars)
            if [[ $is_ps -eq 1 ]]; then
                printf '\[%b\]%s%b' "${bg_esc}${color_}${style}" "$text" "$rst"
            else
                printf "%b" "${bg_esc}${color_}${style}${text}${rst}${eol}"
            fi
        fi
    done
}

# Public render functions
c()     { _color_render 0  "$@"; }   # no newline
cn()    { _color_render 1  "$@"; }   # with newline
psc()   { _color_render ps "$@"; }   # PS1-safe
color() { _color_render 1  "$@"; }   # legacy alias (with newline)

# ============================================================
# BACKGROUND-ONLY COLOR HELPERS
#   cbg  [-ps] [-n] [-e] <color> <text>
#   cbgl [-ps] [-e] <color> <text>  (shorthand: same + newline)
# ============================================================
cbg() {
    local is_ps=0
    local nl=0
    local exp=0
    while [[ $# -gt 0 && "$1" =~ ^- ]]; do
        case "$1" in
            -p|-ps|--ps) is_ps=1; shift ;;
            -h|-H|--help)
                echo "cbg: set background color only, print content, reset bg"
                echo "Usage: cbg [-ps] [-n] [-e] <color> <text>"
                return 0
                ;;
            -n|-nl|--new) nl=1; shift ;;
            -e|-exp|--escape) exp=1; shift ;;
            -ne|-en) nl=1; exp=1; shift ;;
            -np|-pn|-psn) nl=1; is_ps=1; shift ;;
            -pe|-ep|-pse) is_ps=1; exp=1; shift ;;
            -pne|-pen|-nep|-npe|-epn|-enp|-psne|-psen) nl=1; exp=1; is_ps=1; shift ;;
            --) shift; break ;;
            -[0-9]*) break ;;
            *) break ;;
        esac
    done

    (( $# == 0 )) && return 0

    local bg_num="$1"; shift
    local str="$*"

    case "$bg_num" in
        rc|rand) command -v random_core >/dev/null 2>&1 && bg_num="$(random_core roll default)" || bg_num=16 ;;
        rc:*|rand:*) command -v random_core >/dev/null 2>&1 && bg_num="$(random_core get "${bg_num#*:}")" || bg_num=16 ;;
        r) bg_num=196 ;; lr) bg_num=203 ;;
        g) bg_num=82  ;; lg) bg_num=46  ;;
        y) bg_num=226 ;; cr) bg_num=51  ;;
        b) bg_num=33  ;; ora) bg_num=208 ;;
        gr) bg_num=244 ;;
    esac

    local esc
    esc=$(printf '\033')
    local bg_seq="${esc}[48;5;${bg_num}m"
    local reset="${esc}[0m"
    local reset_short="${esc}[m"
    local reset_bg="${esc}[49m"

    if (( exp == 1 )); then
        printf -v str "%b" "$str"
    fi

    local pfx sfx inner_bg_seq
    if [[ $is_ps -eq 1 || "$str" == *'\]'* || "$str" == *'\['* ]]; then
        pfx="\[${bg_seq}\]"
        sfx="\[${reset_bg}\]"
        inner_bg_seq="\[${bg_seq}\]"
    else
        pfx="${bg_seq}"
        sfx="${reset_bg}"
        inner_bg_seq="${bg_seq}"
    fi

    local res="${str//"$reset"/"$reset$inner_bg_seq"}"
    res="${res//"$reset_short"/"$reset_short$inner_bg_seq"}"
    res="${res//"$reset_bg"/"$inner_bg_seq"}"

    printf "%s%s%s" "$pfx" "$res" "$sfx"
    (( nl )) && printf "\n"
    return 0
}

cbgl() { cbg -n "$@"; }

