#!/usr/bin/env bash
# ------------------------------------------------------------
# File: mc_test.sh
# ------------------------------------------------------------
source /home/joez/ssot/core/01-colors.sh
# โทนสีเดี่ยวไล่ระดับ
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



