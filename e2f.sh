#!/usr/bin/env bash
source $HOME/ssot/core/01-colors.sh
source "/data/data/com.termux/files/home/ssot/shared/personal/daily_use.sh"

JOE_BANNER="\` αℓways ωith γσυ  ❤️  "
JOE="$(cn 45 b --bg 232 "\` ❤️ ICE ☆    ")"

e2f $JOE_BANNER
e2f $JOE

# for c_ in $(seq 1 256); do
# 	c "$c_" b --bg "$(( 256 - c_ ))" " $c_ "
# done	 


declare -A palettes=(
	[default]="196 208 226 46 51 21 129"
	[white]="236 236 237 238 239 240 241 241 242 243 244 245 246 247 252 254 255"
	[neon]="9 10 27 11 196 202 198 91 235 256 242"
)



pd=white
printf '%s\n' "${palettes[$pd]}"

read -r -a palette <<< "${palettes[$pd]}"
printf '%s\n' "${palette[@]}"


jmc() {
    local text="${1:-}"
    local style=""

    # ตัวแรกเป็น style ถ้าตรงแพทเทิร์น b/d/i/u (แบบเดียวกับ rc)
    if [[ -z "$1" ]] || [[ "$1" =~ ^[bdiu]{1,4}$ ]]; then
        style="$1"
        shift 1
        text="${1:-}"
    fi

    local length="${#text}"
    #local palette="("$palette")"
    local palette_size="${#palette[@]}"
    local result=""

    # สร้าง style prefix (b/d/i/u → escape)
    local st=""
    for (( i=0; i<${#style}; i++ )); do
        local char="${style:$i:1}"
        case "$char" in
            b) st+="$(_b)" ;; d) st+="$(_d)" ;;
            i) st+="$(_i)" ;; u) st+="$(_u)" ;;
        esac
    done

    # ต่อสีรุ้งทีละตัวอักษร (style ติดหน้าแต่ละตัว — กัน reset ระหว่างทาง)
    for (( i=0; i<length; i++ )); do
        local char="${text:$i:1}"
        local color_code="${palette[$(( i % palette_size ))]}"
        result+="${st}$(_c "$color_code")${char}"
    done

    # คืนค่าสีเดิม (\033[0m) ตบท้าย แล้วพ่นทีเดียวทั้งประโยค
    echo -e "${result}$(_r)"
}

jmc b "$JOE_BANNER"