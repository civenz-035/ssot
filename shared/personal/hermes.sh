#!/usr/bin/env bash
# ------------------------------------------------------------

# -- หา basebet  ที่ cover  losses streak ที่ต้องการยอมรับได้ โดยผลลัพที่ได้จะมี 2 ทางคือ ชนะทุก stake หรือ เจ๊งหมด
# ------------------------------------------------------------
# --- source maths functions ---
# ─────────────────────────────────────────
# [1.5] MATH HELPERS
# ─────────────────────────────────────────
fadd() {
    mth "$1+$2" 8 d
 }

fsub() {
    mth "$1-$2" 8 d
 }

fmul() {
    mth "$1*$2" 8 d
 }

float_div() {
    mth "$1/$2" 8 d
 }

fgt() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
 }

fgte() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
 }



test() {

     start_bal=$1  # ballance start
     basebet=$2  # basebet
    
     multiplier=$3  # multiplier
     chance=$4  # chance
    
 }

dobet(){

        local balance=${1:-$start_bal}
        local current_bet=${2:-$basebet}
        local current_loss_streak=${3:-$loss_streak}
        local current_multiplier=${4:-$multiplier}

        if (( ($current_bet * $current_multiplier) > $balance )); then
            cn 196 b "✗ need more balance"
            return 1
        fi
        
        if (( loss_streak > max_loss_streak )); then
            max_loss_streak=$loss_streak
        fi

        balance=$(fsub "$balance" "$bet")
       
        total_profit=$(fadd "$(fsub "$balance" "$START_BALANCE")" "$profit_vault")
        win_streak=0
       


        # calculate new basebet
        calculate_basebet "$balance" "$current_loss_streak" "$multiplier"
         nextbet=$newbasebet
        
        ((loss_streak++))
        ((lose_count++))   
    

    
    }


    
               


# --- maths resolve testing analyzing ---
calculate_basebet() {
    # formula: BASEBET * m^(n+1) = current_balance
    #          basebet = current_balance * (m - 1) / (m^n - 1)
    local current_balance_input="${1:-$start_bal}"
    local current_loss_streak_input="${2:-$loss_streak}"
    local current_multiplier_input="${3:-$multiplier}"
    
    newbasebet=$(slv -q "basebet/bal=(m-1)/(m^n-1)" "bal=$current_balance_input" "m=$current_multiplier_input" "n=$current_loss_streak_input" "8" d)
    
 }






dobet(){

        local balance=${1:-$start_bal}
        local current_bet=${2:-$basebet}
        local current_loss_streak=${3:-$loss_streak}
        local current_multiplier=${4:-$multiplier}

        if (( ($current_bet * $current_multiplier) > $balance )); then
            cn 196 b "✗ need more balance"
            return 1
        fi
        
        if (( loss_streak > max_loss_streak )); then
            max_loss_streak=$loss_streak
        fi

        balance=$(fsub "$balance" "$bet")
       
        total_profit=$(fadd "$(fsub "$balance" "$START_BALANCE")" "$profit_vault")
        win_streak=0
       


        # calculate new basebet
        calculate_basebet "$balance" "$current_loss_streak" "$multiplier"
         nextbet=$newbasebet
        
        ((loss_streak++))
        ((lose_count++))   
    

    
    }


    
               


# --- maths resolve testing analyzing ---
calculate_basebet() {
    # formula: BASEBET * m^(n+1) = current_balance
    #          basebet = current_balance * (m - 1) / (m^n - 1)
    local current_balance_input="${1:-$start_bal}"
    local current_loss_streak_input="${2:-$loss_streak}"
    local current_multiplier_input="${3:-$multiplier}"
    
    newbasebet=$(slv -q "basebet/bal=(m-1)/(m^n-1)" "bal=$current_balance_input" "m=$current_multiplier_input" "n=$current_loss_streak_input" "8" d)
    
 }












    while fgt $cur_bal $start_bal; do
        (( loss_streak++ ))

        calculate_basebet "$balance" "$loss_streak" "$multiplier"
         nextbet=$newbasebet
        dobet "$balance" "$bet_amount" "$loss_streak" "$multiplier"
        cn 196 b "you lose ${loss_streak} times"
        balance=$newbalance

   done     

        

    
    
    