#!/usr/bin/env bash
# ------------------------------------------------------------
# File: sc.shs
# ------------------------------------------------------------
mf=""

for m in "mth" "slv" "solve" "calc"; do
	mf+="$bin/$m\n"
done	
m_="$(echo -e $mf)"

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

