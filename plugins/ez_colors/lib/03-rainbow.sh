#!/usr/bin/env bash
# ============================================================
# 03-rainbow.sh — Rainbow / Multi-Color Gradient Engine
# ============================================================
# API:
#   rainbow_palette [FLAGS] [style] <text>
#   mc [FLAGS] [style] <text>   — alias for rainbow_palette
#   jmc [-d|-w|-n] [style] <text>  — inline gradient (fg only, palette-keyed)
#   mcbg [-d|-w|-n] <text>         — background gradient (bg only)
#   paint -t <style> <text>        — fg gradient
#         -b <palette> <text>      — bg gradient
#         -tb <palette> <style> <text> — combined
#
# Gradient flags: -w -b -c -g -r -m -v -o -y -pk --fire --ice --sunset -n -p -d
# Style:          b=bold d=dim i=italic u=underline (combinable: "bu")
# ============================================================

rainbow_palette() {
    local -a palette_types=()
    local style=""

    while (( $# > 0 )); do
        case "$1" in
            -d|--default|-w|--white|-b|--blue|-c|--cyan|-g|--green|-r|--red|\
            -m|--magenta|-v|--violet|--purple|-o|--orange|-y|--yellow|--gold|\
            -pk|--pink|--fire|--ice|--sunset|-n|--neon|-p|--pastel|--dim)
                palette_types+=("$1")
                shift
                ;;
            -h|--help)
                cat <<'EOF'
Usage: mc [FLAGS...] [STYLE] <text...>
Gradient & Palette Flags:
  -w,  --white     Monochrome white/gray gradient
  -b,  --blue      Deep navy -> bright sky blue gradient
  -c,  --cyan      Teal -> aqua -> light cyan gradient
  -g,  --green     Forest -> emerald -> lime green gradient
  -r,  --red       Crimson -> fire red -> coral gradient
  -m,  --purple    Violet -> magenta -> lavender gradient
  -o,  --orange    Rust -> amber -> gold gradient
  -y,  --yellow    Bronze -> bright yellow gradient
  -pk, --pink      Plum -> hot pink -> baby pink gradient
  --fire           Dark red -> orange -> bright yellow
  --ice            Navy -> cyan -> crisp white
  --sunset         Violet -> red -> orange -> yellow
  -n,  --neon      Multi-color neon
  -p,  --pastel    Soft pastel
  -d,  --default   Classic 7-color rainbow
Styles:
  b (bold), d (dim), i (italic), u (underline), or combinations (e.g. bu)
Note: Multiple flags can be combined (e.g. mc -b -c "Blue to Cyan")
EOF
                return 0
                ;;
            *)
                if [[ "$1" =~ ^[bdiu]{1,4}$ && -z "$style" && $# -gt 1 ]]; then
                    style="$1"
                    shift
                else
                    break
                fi
                ;;
        esac
    done

    (( ${#palette_types[@]} == 0 )) && palette_types=("default")

    local palette_str=""
    for pt in "${palette_types[@]}"; do
        palette_str+="$(palettes_ "$pt") "
    done

    local text="$*"
    local length="${#text}"
    local -a palette
    read -r -a palette <<< "$palette_str"
    local palette_size="${#palette[@]}"
    local result=""

    local st=""
    for (( i=0; i<${#style}; i++ )); do
        local char="${style:$i:1}"
        case "$char" in
            b) st+="$(_b)" ;; d) st+="$(_d)" ;;
            i) st+="$(_i)" ;; u) st+="$(_u)" ;;
        esac
    done

    for (( i=0; i<length; i++ )); do
        local char="${text:$i:1}"
        local color_code="${palette[$(( i % palette_size ))]}"
        result+="${st}$(_c "$color_code")${char}"
    done

    echo -e "${result}$(_r)"
}

# mc = multi-color (alias for rainbow_palette)
mc() { rainbow_palette "$@"; }

# jmc — Palette-keyed gradient (fg text, 3 built-in presets)
jmc() {
    declare -A p=(
        [default]="196 208 226 46 51 21 129"
        [white]="236 236 237 238 239 240 241 241 242 243 244 245 246 247 252 254 255"
        [neon]="9 10 27 11 196 202 198 91 235 256 242"
    )

    local pd=default
    while (( $# > 0 )); do
        case "$1" in
            -d|--default) pd=default; shift ;;
            -w|--white)   pd=white;   shift ;;
            -n|--neon)    pd=neon;    shift ;;
            *)  break ;;
        esac
    done
    read -r -a palette <<< "${p[$pd]}"

    local style=""
    if [[ -z "$1" ]] || [[ "$1" =~ ^[bdiu]{1,4}$ ]]; then
        style="$1"
        shift 1
    fi

    local text="$*"
    local length="${#text}"
    local palette_size="${#palette[@]}"
    local result=""

    local st=""
    for (( i=0; i<${#style}; i++ )); do
        local char="${style:$i:1}"
        case "$char" in
            b) st+="$(_b)" ;; d) st+="$(_d)" ;;
            i) st+="$(_i)" ;; u) st+="$(_u)" ;;
        esac
    done

    for (( i=0; i<length; i++ )); do
        local char="${text:$i:1}"
        local color_code="${palette[$(( i % palette_size ))]}"
        result+="${st}$(_c "$color_code")${char}"
    done

    echo -e "${result}$(_r)"
}

# mcbg — Background gradient (each character gets its own bg color)
mcbg() {
    declare -A jk=(
        [default_bg]="196 208 226 46 51 21 129"
        [white_bg]="236 236 237 238 239 240 241 241 242 243 244 245 246 247 252 254 255"
        [neon_bg]="9 10 27 11 196 202 198 91 235 256 242"
    )

    local bg=default_bg
    while (( $# > 0 )); do
        case "$1" in
            -d|--default) bg=default_bg; shift ;;
            -w|--white)   bg=white_bg;   shift ;;
            -n|--neon)    bg=neon_bg;    shift ;;
            *)  break ;;
        esac
    done

    local text="$*"
    read -r -a palette <<< "${jk[$bg]}"
    local length="${#text}"
    local palette_size="${#palette[@]}"
    local result=""

    for (( i=0; i<length; i++ )); do
        local char="${text:$i:1}"
        local color_code="${palette[$(( i % palette_size ))]}"
        result+="$(_bg "$color_code")${char}$(_rbg)"
    done
    echo -e "${result}$(_r)"
}

# paint — Unified gradient entry point
#   paint -t <style> <text>          — fg gradient via jmc
#   paint -b <palette> <text>        — bg gradient via mcbg
#   paint -tb <palette> <style> <text> — combined fg+bg
paint() {
    local flag="" text="" style="" tx=""

    while (( $# > 0 )); do
        case "$1" in
            -t|--text)
                style="$2"; text="$3"
                jmc "$style" "$text"
                shift 3
                ;;
            -b|--bg)
                flag="$2"; text="$3"
                mcbg "$flag" "$text"
                shift 3
                ;;
            -tb|--textbg)
                flag="$2"; style="$3"; text="$4"
                tx="$(jmc "$style" "$text")"
                mcbg "$flag" "$tx"
                shift 4
                ;;
            -h|--help)
                echo "Usage: paint [options] <text>"
                echo "  -t, --text   <style> <text>           fg gradient"
                echo "  -b, --bg     <palette> <text>         bg gradient"
                echo "  -tb,--textbg <palette> <style> <text> combined"
                return 0
                ;;
            *) break ;;
        esac
    done
}

