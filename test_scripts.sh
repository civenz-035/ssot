#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test_scripts.sh
# ------------------------------------------------------------

source "$HOME/.bashrc"


for f in $(find $hpc -iname "*bak*" -maxdepth 1  2>/dev/null); do

	echo -e "$f"\n
	#rm -f "$f" &>>/dev/null || { echo -e "$f \t Failed"; exit 1; } &&

	echo done
# rmdir 
# rmdir "$f"
done



           