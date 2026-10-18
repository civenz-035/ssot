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
_gr() {
    psc 235 d "$@"
}
_lw() {
    psc 15 b "$@"
}
export joe-logo="\` αℓways ωith γσυ"
# ======================================================
# 2. THEME DEFAULTS & CONFIGURATION SYSTEM
# ======================================================
: "${THEME_DEF_BORDER_TOP:=${BOT_LINE:-$'\u2581'}}"
: "${THEME_DEF_BORDER_BOT:=${TOP_LINE:-$'\u2594'}}"
: "${THEME_DEF_BORDER_SEP:=|}"
: "${THEME_DEF_BORDER_COLOR:=random}"
: "${THEME_DEF_BORDER_STYLE:=b}"
: "${THEME_DEF_STATUS:=❤️ ICE}"
: "${THEME_DEF_ENV:=${JOE_ENV:-${MY_DEVICE:-WSL2}}}"
: "${THEME_DEF_ENV_COLOR:=202}"
: "${THEME_DEF_POINTER:=-→}"
: "${THEME_DEF_DIR_COLOR:=242}"
: "${THEME_DEF_DIR_STYLE:=d}"
: "${THEME_DEF_GIT:=1}"
: "${THEME_DEF_MINI:=1}"
: "${THEME_DEF_FETCH:=1}"

theme_default_config() {
    while (( $# > 0 )); do
        case "$1" in
            -b|--border)
                # รองรับทั้งตัวเดียว หรือ "top,bot,sep,color"
                local _val="${2:-}"
                if [[ "$_val" == *,* ]]; then
                    IFS=',' read -r _t _b _s _c <<< "$_val"
                    [[ -n "$_t" ]] && THEME_DEF_BORDER_TOP="$_t"
                    [[ -n "$_b" ]] && THEME_DEF_BORDER_BOT="$_b"
                    [[ -n "$_s" ]] && THEME_DEF_BORDER_SEP="$_s"
                    [[ -n "$_c" ]] && THEME_DEF_BORDER_COLOR="$_c"
                elif [[ -n "$_val" ]]; then
                    THEME_DEF_BORDER_TOP="$_val"
                    THEME_DEF_BORDER_BOT="$_val"
                fi
                shift 2 ;;
            -bc|--border-color)
                THEME_DEF_BORDER_COLOR="${2:-random}" ; shift 2 ;;
            -bs|--border-style)
                THEME_DEF_BORDER_STYLE="${2:-b}" ; shift 2 ;;
            -sep|--border-sep)
                THEME_DEF_BORDER_SEP="${2:-|}" ; shift 2 ;;
            -s|--status|--title|-t)
                THEME_DEF_STATUS="${2:-'(ﾉ◕ .7oEz ◕)ﾉ*:･ﾟ✧'}" ; shift 2 ;;
            -p|--pointer|--arrow)
                THEME_DEF_POINTER="${2:--→}" ; shift 2 ;;
            -e|--env)
                THEME_DEF_ENV="${2:-WSL2}" ; shift 2 ;;
            -ec|--env-color)
                THEME_DEF_ENV_COLOR="${2:-202}" ; shift 2 ;;
            -d|--dir-color)
                THEME_DEF_DIR_COLOR="${2:-242}" ; shift 2 ;;
            -ds|--dir-style)
                THEME_DEF_DIR_STYLE="${2:-d}" ; shift 2 ;;
            --git)
                THEME_DEF_GIT=1 ; shift ;;
            --no-git)
                THEME_DEF_GIT=0 ; shift ;;
            --mini)
                THEME_DEF_MINI=1 ; shift ;;
            --no-mini)
                THEME_DEF_MINI=0 ; shift ;;
            --fetch)
                THEME_DEF_FETCH=1 ; shift ;;
            --no-fetch)
                THEME_DEF_FETCH=0 ; shift ;;
            -r|--reset)
                THEME_DEF_BORDER_TOP="${BOT_LINE:-$'\u2581'}"
                THEME_DEF_BORDER_BOT="${TOP_LINE:-$'\u2594'}"
                THEME_DEF_BORDER_SEP='|'
                THEME_DEF_BORDER_COLOR='random'
                THEME_DEF_BORDER_STYLE='b'
                THEME_DEF_STATUS='(ﾉ◕ .7oEz ◕)ﾉ*:･ﾟ✧'
                THEME_DEF_ENV="${JOE_ENV:-${MY_DEVICE:-WSL2}}"
                THEME_DEF_ENV_COLOR=202
                THEME_DEF_POINTER='-→'
                THEME_DEF_DIR_COLOR=242
                THEME_DEF_DIR_STYLE=d
                THEME_DEF_GIT=1
                THEME_DEF_MINI=1
                THEME_DEF_FETCH=1
                shift ;;
            -h|--help)
                cat <<'EOF'
Usage: tdc [OPTIONS] (or theme_default_config)
  -b,  --border <str|t,b,s,c>   Border char(s) (e.g. "━" or "━,━,|,92")
  -bc, --border-color <col>     Border color (256-color num or 'random')
  -bs, --border-style <style>   Border style (b=bold, d=dim)
  -sep,--border-sep <char>      Border separator (default '|')
  -s,  --status <text>          Custom status/kaomoji text
  -p,  --pointer <symbol>       Prompt pointer symbol (default: -→)
  -e,  --env <name>             Environment label
  -ec, --env-color <col>        Environment label color
  -d,  --dir-color <col>        Current directory color
  -ds, --dir-style <style>      Current directory style
  --git / --no-git              Toggle git branch in prompt
  --mini / --no-mini            Toggle smart mini prompt mode
  --fetch / --no-fetch          Toggle fastfetch on startup
  -r,  --reset                  Reset all theme settings to defaults
  -h,  --help                   Display this help message
EOF
                return 0 ;;
            *)
                shift ;;
        esac
    done
}

# Alias สะดวกสำหรับปรับแต่งทันทีจาก Terminal
alias tdc='theme_default_config'

# 3. ฟังก์ชันตรวจสอบ Git Branch แบบไม่หน่วงเครื่อง (Lightweight Git Status)
_git_prompt() {
    if (( THEME_DEF_GIT != 1 )); then
        return 0
    fi
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

# 4. ฟังก์ชันสร้างเส้นแบ่ง (Border line)
_draw_border() {
    local char="${1:-┈}"
    local count="${2:-40}"
    (( count < 1 )) && count=1
    printf '%.0s'"$char" $(seq 1 "$count")
}

# 5. ประกอบร่างเป็น Dynamic PS1 (Prompt) — BASH ONLY
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
    if (( THEME_DEF_MINI == 1 && _SSOT_USED < _max_lines )); then
        show_mini=1
    else
        _SSOT_USED=3                      # full สูง 4 แถว หัวอยู่เหนือ cursor 3 แถว
    fi

    # ถ้าเข้าเงื่อนไข Mini Prompt: พิมพ์เฉพาะ pointer ย่อแล้วจบฟังก์ชันทันที
    if (( show_mini == 1 )); then
        if [ $exit_code -eq 0 ]; then
            PS1=" $(psc lg b "  ${THEME_DEF_POINTER}  ") "
        else
            PS1=" $(psc lr b "  ${THEME_DEF_POINTER}  ") "
        fi
        return
    fi

    local last_status_raw="$THEME_DEF_STATUS"
    local last_status
    if [ $exit_code -eq 0 ]; then
        if command -v mc >/dev/null 2>&1; then
            last_status="$(psc 45 b --bg "233" "$last_status_raw")"
        else
            last_status="$(psc 82 b "$last_status_raw")"
        fi
    else
        last_status="$(psc lr b "$last_status_raw")"
    fi

    # -- Environment / Current shell
    local cur_env="$THEME_DEF_ENV"
    local cur_shell="${_SHELL:-${SHELL##*/}}"
    local env_tag="< $(psc "$THEME_DEF_ENV_COLOR" d "$cur_env") : $(psc 240 d "$cur_shell") >"

    # -- USER@HOST
    local cur_user="${USER:-$(id -un)}"
    local cur_host="${NODE_HOST:-wsl2}"
    local user_host="$(psc 33 b "$cur_user")@$(psc 245 d "$cur_host")"

    # -- Current Dir & Git
    local current_dir="$(psc "$THEME_DEF_DIR_COLOR" "$THEME_DEF_DIR_STYLE" "${PWD/#$HOME/\~}")"
    local git_info="$(_git_prompt)"

    # --- ปิดแถวหัวท้ายทาสีเดียวกับขอบบนล่าง
    local c_box
    if [[ "$THEME_DEF_BORDER_COLOR" == "random" ]] && command -v random_core >/dev/null 2>&1; then
        c_box=$(random_core roll border "$RC_PALETTE_DIM")
    else
        c_box="${THEME_DEF_BORDER_COLOR:-240}"
        [[ "$c_box" =~ ^[0-9]+$ ]] || c_box=240
    fi
    local sep="$(psc "$c_box" "$THEME_DEF_BORDER_STYLE" "$THEME_DEF_BORDER_SEP")"

    # -- 1. รวมเนื้อหาของแถวกลางจริงที่จะแสดงผล
    local prompt_content="${sep} ${last_status} ${env_tag} ${user_host} in ${current_dir}${git_info} ${sep}"

    # -- 2. Dynamic border calculation: ยิงวัดความกว้างรอบเดียว (One-Shot)
    local term_w
    term_w=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
    (( term_w < 37 )) && term_w=37

    local text_len
    if command -v _w >/dev/null 2>&1; then
        text_len=$(_w "$prompt_content")
    else
        text_len=${#prompt_content}
    fi

    local lens=$text_len
    (( lens > (term_w - 2) )) && lens=$(( term_w - 2 ))

    local _str_t="" _str_b=""
    for (( _i = 1; _i <= lens; _i++ )); do
        _str_t+="${THEME_DEF_BORDER_TOP}"
        _str_b+="${THEME_DEF_BORDER_BOT}"
    done

    local border_top="$(psc "$c_box" "$THEME_DEF_BORDER_STYLE" "${_str_t}")"
    local border_bot="$(psc "$c_box" "$THEME_DEF_BORDER_STYLE" "${_str_b}")"

    # -- 3. ประกอบร่าง Dynamic PS1 (Prompt)
    local PS1_=""
    PS1_+="${border_top}\n"
    PS1_+="$(c "" "" --bg "235" "${prompt_content}")\n"
    PS1_+="${border_bot}\n"
    PS1_+=" ${THEME_DEF_POINTER} "

    export -n PS1 2>/dev/null || true
    PS1="$PS1_"
}

_SSOT_LAST_ROW=0
_SSOT_USED=99999      # ค่าสูง = prompt แรกได้ full เสมอ
_SSOT_LAST_HIST=
export -n PROMPT_COMMAND 2>/dev/null || true
PROMPT_COMMAND=_set_prompt

elif [[ -n "${ZSH_VERSION:-}" ]]; then
    unset PROMPT_COMMAND
    export -n PROMPT_COMMAND 2>/dev/null || true
fi

# 6. Apply configuration from arguments if provided
if (( $# > 0 )); then
    theme_default_config "$@"
fi

# 7. Show Fastfetch (only in interactive WSL shells with logo)
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    if [ "$JOE_ENV" = "WSL" ] && (( THEME_DEF_FETCH == 1 )); then
        fastfetch --logo ubuntu
    fi
fi
