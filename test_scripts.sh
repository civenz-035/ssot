#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test_scripts.sh
# ------------------------------------------------------------

source "$HOME/.maths-helper/maths.sh" 
source "$HOME/ssot/shared/personal/joe_functions.sh"


mul() {
	mth "$1*$2" 8;
	}
add() {
	mth "$1+$2" 8;
	}
sub() {
	mth "$1-$2" 8;
	}
div() {
	mth "$1/$2" 8;
	}
rem() {
	mth "$1%$2" 8;
	}



bal=$1 roll=$2 multi=$3
loss_streak=0


base_bet=
dobet() {
    local current_bet="${1:-$nextbet}"
    if ! fgte "$balance" "$current_bet"; then
        cn 196 b "BUST: balance too low for next bet ($current_bet)"
        return 1
    fi
    balance=$(fsub "$balance" "$current_bet")
    total_loss=$(fsub "$start_bal" "$balance")
    (( loss_streak++ ))
    (( lose_count++ ))
    cn 214 "  Bet #${lose_count} | bet=$current_bet | balance=$balance | total_loss=$total_loss"
}


while (( loss_streak<=roll )) ; do
	(( loss_streak ++ ))
	dobet $balace $bet $multi
done



