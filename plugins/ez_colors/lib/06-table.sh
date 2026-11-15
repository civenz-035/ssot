#!/usr/bin/env bash
# ============================================================
# 06-table.sh — Table, Box & Layout Helpers
# ============================================================
# API:
#   ctab "<col-spec> ..." <value> <value> ...
#     col-spec = [style][color]:width
#       style  : b=bold d=dim u=underline (combinable: "bu")
#       color  : 0=default | 1-255=256-color | x=no wrap (arg has own color)
#       width  : 0=auto (%s) | N=fixed width (%-Ns)
#
#   hline [width] [color] [char]
#     Horizontal divider line (default char: ▬, default color: dim)
#
#   draw_ <char> <width>
#     Repeat a character N times; alias: d_
#
#   get_real_width <text>
#     Measure visible column width (strips ANSI + PS1 delimiters)
#     Uses python3 for emoji/CJK accuracy; falls back to wc -m.
#     Alias: _w
#
#   box_card [--border <color>] "line1" "---" "line2" ...
#     Auto-sized Unicode box. "---" becomes a mid-rule (├─────┤).
#     Accepts stdin if no arguments are given.
# ============================================================

# ctab — colored tabular output
ctab() {
    local -a spec=($1); shift
    local fmt="  " i=0 col c w st esc
    for col in "${spec[@]}"; do
        c="${col%%:*}"; w="${col##*:}"
        esc=""
        st=""
        while [[ "$c" =~ ^[bdu] ]]; do st+="${c:0:1}"; c="${c:1}"; done
        case "$st" in *b*) esc+="$(_b)";; esac
        case "$st" in *d*) esc+="$(_d)";; esac
        case "$st" in *u*) esc+="$(_u)";; esac
        if [[ "$c" == "x" ]]; then
            esc=""
        elif [[ "$c" =~ ^[0-9]+$ && "$c" != "0" ]]; then
            esc+="$(_c "$c")"
        fi
        if [[ "$w" =~ ^[0-9]+$ && "$w" != "0" ]]; then
            fmt+="${esc}%-${w}s$(_r)"
        else
            fmt+="${esc}%s$(_r)"
        fi
        (( i < ${#spec[@]} - 1 )) && fmt+="  "
        (( i++ ))
    done
    # Convert literal \e in args to real ESC
    local -a out=() a
    for a in "$@"; do out+=("${a//\\e/$'\e'}"); done
    printf "$fmt\n" "${out[@]}"
}

# hline — horizontal divider
hline() {
    local w="${1:-66}" c="${2:-0}" j dash="" char=${3:-"▬"}
    for ((j=0; j<w; j++)); do dash+="${char:-▬}"; done
    local esc="$(_d)"
    [[ "$c" != "0" ]] && esc="$(_c "$c")"
    printf "  %s%s%s\n" "$esc" "$dash" "$(_r)"
}

# draw_ — repeat a character N times
draw_() {
    printf "%*s\n" "$2" "" | sed "s/ /$1/g"
}
alias d_='draw_'

# get_real_width — measure visible column width of a string
get_real_width() {
    local text="$1"
    # Strip PS1 prompt delimiters \[ \] (two passes to work in both bash & zsh)
    text="${text//\\[/}"
    text="${text//\\]/}"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import re, sys, unicodedata

text = sys.argv[1]

# Strip ANSI sequences
text = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", text)
text = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", text)
text = re.sub(r"\x1b[@-Z\\\-_]", "", text)

w = 0
for ch in text:
    if unicodedata.combining(ch):
        continue
    if ch == "\ufe0f":  # VARIATION SELECTOR-16: zero-width
        continue
    if ch == "\ufe0e":  # VARIATION SELECTOR-15: zero-width
        continue
    w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
print(w)
' "$text" 2>/dev/null || echo "${#text}"
    else
        local plain
        plain=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' 2>/dev/null)
        printf '%s' "${plain:-$text}" | wc -m
    fi
}

_w() { get_real_width "$@"; }

# box_card — auto-sized Unicode box with optional mid-rules
box_card() {
    local border_color="240"
    local lines=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --border|-b)
                border_color="$2"
                shift 2
                ;;
            *)
                lines+=("$1")
                shift
                ;;
        esac
    done

    # Read from stdin if no lines given as arguments
    if [[ ${#lines[@]} -eq 0 ]]; then
        while IFS= read -r line; do
            lines+=("$line")
        done
    fi

    [[ ${#lines[@]} -eq 0 ]] && return 0

    if command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "${lines[@]}" | python3 -c '
import sys, re, unicodedata

def real_width(s):
    plain = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)", "", s)
    plain = plain.replace("\\[", "").replace("\\]", "")
    w = 0
    for ch in plain:
        if unicodedata.combining(ch) or ch == "\ufe0f":
            continue
        code = ord(ch)
        if (0x1F300 <= code <= 0x1FAFF) or (0x2600 <= code <= 0x27BF) or (0x2300 <= code <= 0x23FF):
            w += 2
        elif unicodedata.east_asian_width(ch) in ("W", "F"):
            w += 2
        else:
            w += 1
    return w

lines = sys.stdin.read().splitlines()
border_c = sys.argv[1] if len(sys.argv) > 1 else "240"
bc = f"\033[38;5;{border_c}m"
rst = "\033[0m"

widths = [real_width(line) if line != "---" else 0 for line in lines]
max_w = max(widths) if widths else 40
max_w = max(max_w, 32)

div = "─" * (max_w + 2)
print(f"{bc}╭{div}╮{rst}")
for line, w in zip(lines, widths):
    if line == "---":
        print(f"{bc}├{div}┤{rst}")
    else:
        pad = max_w - w
        sp = " " * pad
        print(f"{bc}│{rst} {line}{sp} {bc}│{rst}")
print(f"{bc}╰{div}╯{rst}")
' "$border_color"
    else
        # Fallback: fixed-width box without python
        local max_w=46
        local div
        div="$(draw_ "─" "$((max_w + 2))")"
        cn "$border_color" "╭${div}╮"
        for l in "${lines[@]}"; do
            if [[ "$l" == "---" ]]; then
                cn "$border_color" "├${div}┤"
            else
                printf "%s │\n" "$(cn "$border_color" "│") $l"
            fi
        done
        cn "$border_color" "╰${div}╯"
    fi
}

