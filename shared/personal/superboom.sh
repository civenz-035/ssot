# ============================================================
# SupperBoom env function (moved from 00-env.sh)
# ============================================================

# ============================================================
# Boom env function (moved from 00-env.sh)
# ============================================================

_() {

    _C -q -f _config_def
    _C -q -f block_render
    _C -q -f bn_2
    _config_def "$@"

    local base_c="${WIN_PATH}c/Users/User/Documents/mumusharedfolder"
    local base_z="${WIN_PATH}z/MuMuSharedFolder"
    local base_backup="${WIN_PATH}h/boom"
    local base_hb="${WIN_PATH}h/MuMuSharedFolder"
    local list_=(
        "css|${base_c}/Screenshots"
        "cvdo|${base_c}/VideoRecords"
        "hss|${base_hb}/Screenshots"
        "hvdo|${base_hb}/VideoRecords"
        "bss|${base_backup}/Screenshots"
        "bvdo|${base_backup}/VideoRecords"
        "zss|${base_z}/Screenshots"
        "zvdo|${base_z}/VideoRecords"
        "h|--help"
    ) 
    case $1 in
        css)         printf "%s\n" "${base_c}/Screenshots" ;;
        cvdo)        printf "%s\n" "${base_c}/VideoRecords" ;;
        hss)         printf "%s\n" "${base_hb}/Screenshots" ;;
        hvdo)        printf "%s\n" "${base_hb}/VideoRecords" ;;
        bss)         printf "%s\n" "${base_backup}/Screenshots" ;;
        bvdo)        printf "%s\n" "${base_backup}/VideoRecords" ;;
        zss)         printf "%s\n" "${base_z}/Screenshots" ;;
        zvdo)        printf "%s\n" "${base_z}/VideoRecords" ;;
        -h|--help)    bn_2 "${list_[@]}" ;;
        *)            block_render "${list_[@]}" ;;
    esac
}

rn_lgr(){
    local space="  "
    local name="${1:-$space}"   
    local a b c d e

       case "$name" in  
            a) name='.7oEz' ;; 
            b) name='-MVP-#35' ;; 
            c) name='J1' ;; 
            d) name='J2' ;; 
            e) name='J3' ;;
            *) name="$name" ;; 
        esac
    echo "$name" | clip.exe
    cn lg b "ชื่อใหม่ = $(cn 45 b "$name") ถูก cp ไว้ใน clipboard แล้ว"

}
lgrn(){
    rn_lgr "$@"
}

bp_(){

	# -- text
		local text="${1:-$JOE_ENV}" 
		local lens_="${#text}"
	# -- dynamic width & object
		local _w=$(( 2+lens_+2 ))
		local _l='│' 
		local _r='│'
		local _b='─'
    
		# -- color configuration
		local random=1 
		local _bd_c=240
		local _l_c=240
		local _r_c=240
		local text_c=171
	# -- apply color and  -- sketup object
		
		local _bd="$(d_ "$_b" "$_w")"
		local t=$(cn "$text_c" "b" --bg 245 "$text")
	# -- random or no
		local bd l r blk
	 if [[ -n "$random" || "$random" == "1" ]]; then
	 	 bd=$(rc "b" "$_bd")
	 	 #lr=$(rc "b" "$_l")
		  #r=$(cn "b" "$_r")
		 #blk=$(printf '%s %s %s\n' "$lr" "$t" "$lr")
	 else	 
		 bd=$(cn "$_bd_c" "b" "$_bd")
		  #l=$(cn "$_l_c" "b" "$_l")
	#	  r=$(cn "$_r_c" "b" "$_r")
		 #blk=$(printf '%s %s %s\n' "$l" "$t" "$r")
	 fi	
		  l=$(cn "$_l_c" "b" "$_l")
		  r=$(cn "$_r_c" "b" "$_r")
		 blk=$(printf '%s %s %s\n' "$l" "$t") 
	# -- render
		local _bp_=""
		_bp_+="$bd\n"
		_bp_+="$blk\n"
		_bp_+="$bd"
		
		echo -e "$_bp_"
	  block_prompt="$_bp_"
}

winrate_cal(){
    #  Usage: winrate_cal <wins> <losses> [target_%]
    #  Example: winrate_cal 40 60      → auto target = next whole %
    #           winrate_cal 40 60 60   → target = 60%

    local w="${1:-}"
    local l="${2:-}"

    # Helper: เพิ่ม comma คั่นหลักพัน (Pure Bash)
    _comma() {
        local v="$1"
        while [[ "$v" =~ ^([0-9]+)([0-9]{3})(.*) ]]; do
            v="${BASH_REMATCH[1]},${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
        done
        echo "$v"
    }

    # Helper: Usage Card เมื่อไม่ใส่ argument
    if [[ -z "$w" || -z "$l" ]]; then
        box_card --border 240 \
            "$(c 214 b " 🎯 WIN RATE CALCULATOR — USAGE")" \
            "---" \
            "$(c 245 " Syntax  : ")$(c 51 "winrate_cal <wins> <losses> [target]")" \
            "$(c 245 " Example : ")$(c 141 "winrate_cal 40 60")" \
            "$(c 245 "           ")$(c 141 "winrate_cal 40000 2200 96")"
        return 1
    fi

    if (( w + l == 0 )); then
        _er "Total matches cannot be 0"
        return 1
    fi

    local cur_wr wc_tar winrate_need odd wins_needed check_need
    local total=$(( w + l ))

    # 1. Current win rate (2 decimal)
    cur_wr=$(mth "ROUND(100*($w/$total), 2)" 3)

    # 2. Target win rate (default = next whole %)
    wc_tar=$(mth "ROUNDUP($cur_wr, 0)" 0)
    wc_tar="${wc_tar%.*}"
    winrate_need=${3:-$wc_tar}
    winrate_need="${winrate_need%.*}"

    # Format ตัวเลข
    local w_fmt="$(_comma "$w")"
    local l_fmt="$(_comma "$l")"
    local tot_fmt="$(_comma "$total")"

    # Edge Case: เป้าหมาย <= ปัจจุบัน หรือเป็นไปไม่ได้
    local is_already_achieved=0
    local is_impossible=0

    if (( winrate_need >= 100 && l > 0 )); then
        is_impossible=1
        wins_needed="N/A"
        odd="∞"
    elif (( $(awk -v c="$cur_wr" -v t="$winrate_need" 'BEGIN{print (c >= t) ? 1 : 0}') )); then
        is_already_achieved=1
        wins_needed="0"
        odd=$(mth "ROUND((1/(1-($winrate_need/100)))-1, 2)")
    else
        # Implied fractional odds at target WR: 1/(1-t) - 1
        odd=$(mth "ROUND((1/(1-($winrate_need/100)))-1, 2)")

        # Wins needed to reach target WR: n = (target*(W+L) - 100*W) / (100 - target)
        wins_needed=$(mth "ROUNDUP(($winrate_need*$total - 100*$w) / (100-$winrate_need), 0)" 0)
        wins_needed="${wins_needed%.*}"

        check_need=$(mth "ROUND(100*(($wins_needed+$w)/($wins_needed+$total)), 0)" 0)
        check_need="${check_need%.*}"
    fi

    local need_fmt
    if [[ "$wins_needed" =~ ^[0-9]+$ ]]; then
        need_fmt="$(_comma "$wins_needed")"
    else
        need_fmt="$wins_needed"
    fi

    # ── Dynamic Box Card Rendering ──
    local -a card=()
    card+=(
        "$(c 51 b " 🎯 WIN RATE TARGET CALCULATOR")"
        "---"
        "$(c 245 " 📊 Matches     : ")$(c 229 b "$tot_fmt")$(c 245 " total (")$(c 46 b "${w_fmt}W")$(c 245 " - ")$(c 196 b "${l_fmt}L")$(c 245 ")")"
        "---"
        "$(c 245 " ⚡ Current WR   : ")$(c 226 b "$cur_wr%")"
        "$(c 245 " 🎯 Target WR    : ")$(c 45 b "$winrate_need%")"
        "$(c 245 " 🎲 Implied Odds : ")$(c 214 "$odd : 1")"
        "---"
    )

    if (( is_impossible )); then
        card+=( "$(c 196 b " ⛔ IMPOSSIBLE : 100% requires 0 losses!")" )
    elif (( is_already_achieved )); then
        local losses_allowed
        # สมการ: (winrate_need - 1.01) / 100 = w / (w + losses_allowed)
        # → solve for l (losses_allowed)
        local wr_floor
        wr_floor=$(awk -v wr="$winrate_need" 'BEGIN{printf "%.4f", (wr - 1.01)/100}')
        losses_allowed=$(slv "$wr_floor = $w/($w+l)" "w=$w" | grep -oP '(?<== )[\d.]+' | head -1)
        losses_allowed="${losses_allowed%.*}"
        local loss_fmt="$(_comma "$losses_allowed")"

        card+=(
            "$(c 245 " 🚀 Wins Needed  : ")$(c 46 b "0")$(c 248 " (Target already reached! 🎉)")"
            "$(c 245 " 🛡️  Loss Cushion : ")$(c 214 b "+$loss_fmt")$(c 248 " losses (to maintain ≥ $winrate_need%)")"
        )
    else
        # Penalty ต่อการแพ้ 1 ครั้ง = target / (100 - target) wins
        local penalty
        penalty=$(mth "ROUNDUP($winrate_need / (100 - $winrate_need), 0)" 0)
        penalty="${penalty%.*}"
        local pen_fmt="$(_comma "$penalty")"

        # คำนวณ losses_allowed: แพ้ได้อีกกี่เกมก่อน WR หลุดต่ำกว่า (winrate_need - 1.01)%
        # สมการ: threshold/100 = w/(w+losses_allowed)  →  losses_allowed = w*(100-threshold)/threshold
        local threshold
        threshold=$(awk -v wn="$winrate_need" 'BEGIN{printf "%.2f", wn - 1.01}')

        local losses_allowed=0
        losses_allowed=$(awk -v w="$w" -v t="$threshold" \
            'BEGIN{printf "%d", int(w * (100 - t) / t)}')
        local floor_fmt="$(_comma "$losses_allowed")"

        local drop_pct
        drop_pct=$(awk -v wn="$winrate_need" 'BEGIN{printf "%.2f", wn - 1.01}')
        card+=(
            "$(c 245 " 🚀 Wins Needed  : ")$(c 82 b "+$need_fmt")$(c 248 " in a row ")$(c 244 "• 1 loss = ")$(c 214 "+$pen_fmt")"
            "---"
            "$(c 245 " 💀 Losses Allowed : ")$(c 214 b "+$floor_fmt")$(c 248 " before dropping below ")$(c 196 "$drop_pct%")"
        )
    fi

    box_card --border 240 "${card[@]}"
}

move_() {
    local src="${1:-$(_ css)}"
    local dest="${2:-$(_ bss)}"
    local count=$(find "$src" -type f \( \
        -iname "* *.mp4" -o \
        -iname "* *.3gp" -o \
        -iname "* *.flv" -o \
        -iname "* *.avi" -o \
        -iname "* *.mov" -o \
        -iname "* *.mkv" -o \
        -iname "* *.wmv" -o \
        -iname "* *.FLV" -o \
        -iname "* *.AVI" -o \
        -iname "* *.MOV" -o \
        -iname "* *.MKV" -o \
        -iname "* *.WMV" -o \
        -iname "* *_tmp" -o \
        -iname "* *_TMP" -o \
        -iname "* *_Tmp" -o \
        -iname "*.PNG" -o \
        -iname "*.png" \
    \) | wc -l)

    # 1. แปลง Path รูปแบบ Windows (F:\...) ให้เป็น WSL (/mnt/f/...) อัตโนมัติ
    if [[ "$src" =~ ^[a-zA-Z]:\\ ]]; then
        src="$(wslpath -u "$src" 2>/dev/null || echo "$src")"
    fi

    if [[ "$dest" =~ ^[a-zA-Z]:\\ ]]; then
        dest="$(wslpath -u "$dest" 2>/dev/null || echo "$dest")"
    fi

    # 2. ตรวจสอบโฟลเดอร์ต้นทาง
    if [ ! -d "$src" ]; then
        cn r b "Error: Directory '$src' does not exist."
        return 1
    fi

    # 3. เคลียร์ช่องว่างในชื่อไฟล์ก่อน
    re_name "$src"

    # 4. ค้นหาไฟล์วิดีโอทั้งหมด
    local files=()

    mapfile -t files < <(find "$src" -type f \( \
        -iname "*.mp4" -o \
        -iname "*.3gp" -o \
        -iname "*.flv" -o \
        -iname "*.avi" -o \
        -iname "*.mov" -o \
        -iname "*.mkv" -o \
        -iname "*.wmv" -o \
        -iname "*.FLV" -o \
        -iname "*.AVI" -o \
        -iname "*.MOV" -o \
        -iname "*.MKV" -o \
        -iname "*.WMV" -o \
        -iname "*_tmp" -o \
        -iname "*_TMP" -o \
        -iname "*_Tmp" -o \
        -iname "*_*" -o \
        -iname "*.png" -o \
        -iname "*.PNG" \
    \))

    # 5. สร้างโฟลเดอร์ปลายทางถ้ายังไม่มี
    if [ ! -d "$dest" ]; then
        mkdir -p "$dest"
    fi

    # 6. เช็กว่าเจอไฟล์หรือไม่
    if [ "${#files[@]}" -eq 0 ]; then
        echo "No files found to move."
        return 0
    fi

    # 7. ย้ายไฟล์
    for f in "${files[@]}"; do
        [ -f "$f" ] || continue

        local file_name
        file_name="$(basename "$f")"

        mv "$f" "$dest/$file_name" \
            && cn 10 b "done moved $file_name" \
            || cn r b "cant moved $file_name"
    done
    c gr "" "ย้ายไฟล์แล้วทั้งหมด" ; c 10 b "$count" ; cn gr "" "files"
}


