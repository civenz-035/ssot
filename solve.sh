#!/usr/bin/env bash
# ------------------------------------------------------------
# File: solve.sh
# ------------------------------------------------------------

# --- source maths functions ---
source "$HOME/maths-helper/maths.sh"

# --- maths resolve testing analyzing ---
calculate_basebet() {
    # formula: BASEBET * m^(n+1) = cur_bal
    #          basebet = cur_bal * (m - 1) / (m^n - 1)
    local cur_bal l_st mul scale result
    cur_bal="${1:-100}"
    l_st="${2:-10}"
    mul="${3:-2}"
    scale="${4:-8}"

    # เรียกใช้ slv พร้อม flag -q และกำหนดทศนิยม + โหมดปัดเศษได้แบบเดียวกับ mth()
    result=$(slv -q "basebet/bal=(m-1)/(m^n-1)" "bal=$cur_bal" "m=$mul" "n=$l_st" "$scale" d)
    # เก็บไว้ที่ variable ที่ชื่อ 
    nextbet="$result"
}

calculate_basebet "$1" "$2" "$3" "$4" 
echo "type 1"
echo "$nextbet"


calculate_basebet_() {

    # --- source maths functions ---
    source "$HOME/maths-helper/maths.sh"
    
    # formula: BASEBET * m^(n+1) = cur_bal
    #          basebet = cur_bal * (m - 1) / (m^n - 1)

     usage="Usage: calculate_basebet <cur_bal> <l_st> <mul> <scale>"

   
    case "${1:-}" in    
       -h|--help)
                 echo "$usage" 
                 shift
                 exit 0
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
       ;;
    esac
}   
alias basecalc="calculate_basebet_"
echo "type 2"
calculate_basebet_ -c $1 $2 $3 $4
echo "-h|--help for usage"
calculate_basebet_ -h

           