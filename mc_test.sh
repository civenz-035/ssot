#!/usr/bin/env bash
# ------------------------------------------------------------
# File: mc_test.sh
# ------------------------------------------------------------
source "$ssot/core/01-colors.sh"
# โทนสีเดี่ยวไล่ระดับ
mc_test(){

mc -b  "Deep Blue to Ice Sky"
mc -c  "Teal to Bright Cyan"
mc -g  "Forest to Neon Lime"
mc -r  "Crimson to Bright Coral"
mc -pk "Plum to Soft Pink"
mc --fire "Burning Fire Gradient"
mc --ice  "Frozen Ice Gradient"

# ใช้งานร่วมกับ Style (Bold, Underline ฯลฯ)
mc -b bu "Bold Underline Blue"
mc --ice b "Bold Ice"

# ผสมหลายโทนสีเข้าด้วยกัน (Sequential Combined)
mc -b -c "Blue ต่อด้วย Cyan"
mc --fire --ice "ไฟปะทะน้ำแข็ง"

# ดู Help Cheat Sheet ได้ตลอดเวลา
mc -h

}


insert_bg(){
    local c_=$1
    local text="$2"
    ibg="$(_bg "$c_") "${text}" "$(_rbg)""
    echo -e "${ibg}"
}

insert_bg "232" "$( mc -w " hello world ")"

mc_t="$(mc_test)"

insert_bg "232" "$mc_t"


