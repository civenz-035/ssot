#!/usr/bin/env bash
# ============================================================
# 01-palette.sh — Palette Definitions (Single Source of Truth)
# ============================================================

RC_PALETTE_DEFAULT="45 82 190 196 208 201 39 226 129 48 203 141"
RC_PALETTE_PASTEL="167 173 136 71 68 105 132 178 150 139 174 180"
RC_PALETTE_NEON="21 10 196 200 225 27 202 123 229 205"
RC_PALETTE_DIM="53 22 23 17 54 58 236 64 61"
RC_PALETTE_BDRAW="$RC_PALETTE_DIM"  # Alias for backward compatibility

# palettes_ <flag> — Return a space-separated list of 256-color codes
# Flags: -w/white  -b/blue  -c/cyan  -g/green  -r/red  -m/purple
#        -o/orange  -y/yellow  -pk/pink  --fire  --ice  --sunset
#        -n/neon  -p/pastel  --dim  -d/default
palettes_() {
    case "$1" in
        -w|--white|white)
            echo "236 237 238 239 240 241 242 243 244 245 246 247 250 252 254 255"
            ;;
        -b|--blue|blue)
            echo "17 18 19 20 21 27 33 39 45 51 87 123 159"
            ;;
        -c|--cyan|cyan)
            echo "23 24 30 31 37 38 44 45 50 51 86 87 122 123 159"
            ;;
        -g|--green|green)
            echo "22 28 34 40 46 82 83 118 119 154 155 190 191"
            ;;
        -r|--red|red)
            echo "52 88 124 160 196 202 203 209 210 216 217 223"
            ;;
        -m|--magenta|-v|--violet|--purple|purple)
            echo "53 54 55 56 57 93 129 165 201 207 213 219 225"
            ;;
        -o|--orange|orange)
            echo "52 88 94 130 166 172 202 208 214 220 226"
            ;;
        -y|--yellow|--gold|gold|yellow)
            echo "58 94 100 136 142 178 184 214 220 226 227 228 229"
            ;;
        -pk|--pink|pink)
            echo "53 89 125 161 197 198 199 205 206 212 218 224 225"
            ;;
        --fire|fire)
            echo "52 88 124 160 196 202 208 214 220 226"
            ;;
        --ice|ice)
            echo "17 18 19 21 27 33 39 45 51 87 123 159 231 255"
            ;;
        --sunset|sunset)
            echo "53 54 93 129 161 197 202 208 214 220 226"
            ;;
        -n|--neon|neon)
            echo "9 10 27 11 196 202 198 91 235 226 242"
            ;;
        -p|--pastel|pastel)
            echo "${RC_PALETTE_PASTEL:-167 173 136 71 68 105 132 178 150 139 174 180}"
            ;;
        --dim|dim)
            echo "${RC_PALETTE_DIM:-53 22 23 17 54 58 236 64 61}"
            ;;
        -d|--default|default|*)
            echo "196 208 226 46 51 21 129"
            ;;
    esac
}

