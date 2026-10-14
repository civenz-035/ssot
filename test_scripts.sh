#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test_scripts.sh
# ------------------------------------------------------------

source "$HOME/.maths-helper/maths.sh" 
source "$HOME/.bashrc" 


fadd()      { mth "$1+$2" 8 d; }
fsub()      { mth "$1-$2" 8 d; }
float_div() { mth "$1/$2" 8 d; }
fgte() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'; }


bbcalc() {

    # --- source maths functions ---
        

    # formula: BASEBET * m^(n+1) = cur_bal
    #          basebet = cur_bal * (m - 1) / (m^n - 1)

     usage="Usage: basecalc <cur_bal> <l_st> <mul> <scale>"

   
    case "${1:-}" in    
       -h|--help)
                 echo "$usage" 
                 return 0
       ;;
       -c|--calcl)
                  shift
                  local cur_bal="${1:-100}"
                  local l_st="${2:-10}"
                  local mul="${3:-2}"
                  local scale="${4:-8}"

                 # เรียกใช้ slv พร้อม flag -q และกำหนดทศนิยม + โหมดปัดเศษได้แบบเดียวกับ mth()
                 current_bet=$(slv -q "basebet/bal=(m-1)/(m^n-1)" "bal=$cur_bal" "m=$mul" "n=$l_st" "$scale" d)
                 echo "$current_bet"
        *)
                 echo "$usage" 
                 return 0      
       ;;
    esac
    }   


bal=$1 
loss_allowed=$2 
multi=$3 
basebet=$4
start_bal=$bal
loss_streak=0
lose_count=0


nextbet=$(bbcalc -c $bal $loss_allowed $multi 8)
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



