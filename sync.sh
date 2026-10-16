#!/usr/bin/env bash
# ------------------------------------------------------------
# File: sync.sh
# ------------------------------------------------------------

source $HOME/.bashrc

# รับค่า Path ทั้งหมดเก็บลงตัวแปร array
mapfile -t my_projects < <(repo_ -win)

# นำไปใช้กับคำสั่งอื่นต่อ เช่น สั่ง git status ทุกโปรเจกต์ที่เจอ
for proj in "${my_projects[@]}"; do
    echo "$proj"
    # เช่น cd "$proj" && git status
done

