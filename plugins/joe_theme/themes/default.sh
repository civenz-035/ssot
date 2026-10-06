#!/bin/bash
# ======================================================
# 🎨 JOE'S TERMINAL THEME & PROMPT (WSL Ubuntu Edition)
# ======================================================

# 1. Colors & escape helpers (PS1-safe: ทุก escape sequence ต้องหุ้มด้วย \[ ... \])
# รองรับ psc <color> [style] <text...> ตามมาตรฐาน SSOT Color Engine V3 (core/01-colors.sh)
if ! command -v psc >/dev/null 2>&1; then
    _color_src="${SSOT:-${SCRIPTS_PATH:-$HOME/ssot}}/core/01-colors.sh"
    [[ -f "$_color_src" ]] && source "$_color_src" 2>/dev/null
fi

# Fallback escape helper กรณีรันแยกเดี่ยวและยังไม่ได้ source 01-colors.sh
if ! command -v psc >/dev/null 2>&1; then
    psc() {
        local c="${1:-}" s="${2:-}" t="${3:-}"
        local num="$c"
        case "$c" in
            r) num=196;; lr) num=203;; g) num=82;; lg) num=46;; y) num=226;;
            cr) num=51;; b) num=33;; ora) num=208;; gr) num=244;;
        esac
        local st=""
        [[ "$s" =~ b ]] && st+="\e[1m"
        [[ "$s" =~ d ]] && st+="\e[2m"
        printf '\[\e[38;5;%sm%b\]%s\[\e[0m\]' "$num" "$st" "$t"
    }
fi

# -- helper color
_gr(){
	psc 235 d "$@"
}
_lw(){
	psc 15 b "$@"
}
# 2. ฟังก์ชันตรวจสอบ Git Branch แบบไม่หน่วงเครื่อง (Lightweight Git Status)
_git_prompt() {
    if command -v git >/dev/null 2>&1; then
        local branch
        branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                psc y b " 🌿 ${branch}*"
            else
                psc 82 b " 🌿 ${branch}"
            fi
        fi
    fi
}

# 3. ฟังก์ชันสร้างเส้นแบ่ง (Border line)
_draw_border() {
    local char="${1:-┈}"
    local count="${2:-40}"
    (( count < 1 )) && count=1
    printf '%.0s'"$char" $(seq 1 "$count")
}

# 4. ประกอบร่างเป็น Dynamic PS1 (Prompt) — BASH ONLY
if [[ -n "${BASH_VERSION:-}" ]]; then

_set_prompt() {
    local exit_code=$?
    local _cur_row=0

    # 1. อ่านตำแหน่ง Cursor ปัจจุบัน
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        local _old_stty
        _old_stty=$(stty -g 2>/dev/null)
        stty -echo 2>/dev/null
        printf '\033[6n' >/dev/tty 2>/dev/null
        IFS='[;R' read -r -d 'R' _ _cur_row _ </dev/tty 2>/dev/null
        stty "$_old_stty" 2>/dev/null
    fi

    [[ "$_cur_row" =~ ^[0-9]+$ ]] || _cur_row=0

    local _prev_row=${_SSOT_LAST_ROW:-0}
    _SSOT_LAST_ROW=$_cur_row

    local _max_lines
    _max_lines=$(tput lines 2>/dev/null || echo "${LINES:-24}")

    # คำสั่งถูกรันจริงไหม (Enter เปล่า HISTCMD ไม่เพิ่ม)
    local _ran=0
    [[ "$HISTCMD" != "${_SSOT_LAST_HIST:-}" ]] && _ran=1
    _SSOT_LAST_HIST=$HISTCMD

    # _SSOT_USED = ระยะจากหัว full banner ถึง cursor ปัจจุบัน
    if (( _cur_row <= 1 || _cur_row < _prev_row )); then
        _SSOT_USED=$_max_lines            # clear / cursor กระโดดขึ้น -> บังคับ full
    else
        local _d
        if (( _cur_row < _max_lines )); then
            _d=$(( _cur_row - _prev_row ))            # ยังไม่ชนขอบ วัดตรง
        elif (( _prev_row < _max_lines )); then
            _d=$(( _max_lines - _prev_row ))          # เพิ่งชนขอบ
        else
            _d=1                                      # ติดขอบต่อเนื่อง (Enter 1 แถว)
        fi
        (( _cur_row >= _max_lines && _ran )) && _d=$(( _d + 1 ))  # เดา output ขั้นต่ำ 1 บรรทัด
        _SSOT_USED=$(( ${_SSOT_USED:-99999} + _d ))
    fi

    local show_mini=0
    if (( _SSOT_USED < _max_lines )); then
        show_mini=1
    else
        _SSOT_USED=3                      # full สูง 4 แถว หัวอยู่เหนือ cursor 3 แถว
    fi

    # ถ้าเข้าเงื่อนไข Mini Prompt: พิมพ์แค่ -→ แล้วจบฟังก์ชันทันที
    if (( show_mini == 1 )); then
        if [ $exit_code -eq 0 ]; then
            PS1=" $(psc lg b "  -→  ") "
        else
            PS1=" $(psc lr b "  -→  ") "
        fi
        return
    fi

    local last_status_raw='(ﾉ◕ .7oEz ◕)ﾉ*:･ﾟ✧'
    local last_status
    if [ $exit_code -eq 0 ]; then
        last_status="$(mc b "$last_status_raw")"
    else
        last_status="$(psc lr b "$last_status_raw")"
    fi
    # -- environment / current shell
    local cur_env="${JOE_ENV:-${MY_DEVICE:-WSL2}}"
    #local cur_shell="${_SHELL:-${SHELL##*/}}"
    local env_tag="< $(psc 202 d "$cur_env") : $(psc 240 d "$cur_shell") >"

    # -- USER@HOST
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-wsl2}"

    # -- Current Dir & Git
    local current_dir="$(psc 242 d "${PWD/#$HOME/\~}")"
    local git_info="$(_git_prompt)"

		# ---ปิดแถวหัวท้ายทาสีเดียวกับขอบบนล่าง
		local c_box
    c_box=$(random_core roll border "$RC_PALETTE_DIM")
    local sep="$(psc "$c_box" "b" '|')"

    # -- 1. รวมเนื้อหาของแถวกลางจริงที่จะแสดงผล
    local prompt_content="${sep} ${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info} ${sep}"

    # -- 2. Dynamic border calculation: ยิงวัดความกว้างรอบเดียว (One-Shot)
    local term_w
    term_w=$(tput cols 2>/dev/null || echo $COLUMNS)
    (( term_w < 37 )) && term_w=37

    local text_len
		# -- วัด Width จริง ( ANSI escape codes ??? OSC sequences)
    text_len=$(_w "$prompt_content")

    local lens=$text_len
    (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))

    local BN_BORDER_CHAR_TOP="${BOT_LINE:-$'\u2581'}"
    local BN_BORDER_CHAR_BOT="${TOP_LINE:-$'\u2594'}"

    local _str_t="" _str_b=""
    for (( _i = 1; _i <= lens; _i++ )); do
        _str_t+="${BN_BORDER_CHAR_TOP}"
        _str_b+="${BN_BORDER_CHAR_BOT}"
    done

    # Random border color (Single color for both top bottom and also sep)
    
    local border_top="$(psc "$c_box" "b" "${_str_t}")"
    local border_bot="$(psc "$c_box" "b" "${_str_b}")"

    # -- 3. ประกอบร่าง Dynamic PS1 (Prompt)
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="${prompt_content}\n"
    PS1_+="${border_bot}\n"
    PS1_+=" -→ "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

# ✅ FIX 4: ลบ duplicate — เหลือแค่ชุดเดียว
_SSOT_LAST_ROW=0
_SSOT_USED=99999      # ค่าสูง = prompt แรกได้ full เสมอ
_SSOT_LAST_HIST=
export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_set_prompt

elif [[ -n "${ZSH_VERSION:-}" ]]; then
    unset PROMPT_COMMAND
    export -n PROMPT_COMMAND 2>/dev/null || true
fi

# 5. Show Fastfetch (only in interactive WSL shells with logo)
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    if [ "$JOE_ENV" = "WSL" ]; then
        #clear
        fastfetch --logo ubuntu
    fi
fi

echo

