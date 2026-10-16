#!/usr/bin/env bash
# ------------------------------------------------------------
# File: sc.sh
# ------------------------------------------------------------
mf=""

for m in "mth" "slv" "solve" "calc"; do
	mf+=("$bin/$m")
done	

printd '%s\n' "${mf[@]}"

#mapfile -t proj <<< "$(echo $m_)"
ssot_link=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.local/bin/joe"
    "$HOME/.local/bin/node-status"
    "$HOME/.local/bin/shared"
    "$HOME/.local/bin/env"
    "$SSOT/.env"
    "$SSOT/.env.secret"
		"$m_"
)

for f in "${ssot_link[@]}"; do
 		sf="${f/#$HOME/\~}"
		lf="$(readlink "${f}")"
 		slf="${lf/#$HOME/\~}"
		echo "$sf ---> $slf"
done	

joe_love(){

	echo "เด็ดดวง"

}

