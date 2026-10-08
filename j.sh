#!/usr/bin/env bash
# Losing Streak Simulator - auto-calc nextbet from balance/streak/multiplier
source $HOME/.bashrc && _C -f slv $HOME/.maths-helper

fadd()      { mth "$1+$2" 8 d; }
fsub()      { mth "$1-$2" 8 d; }
float_div() { mth "$1/$2" 8 d; }
fgte() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'; }

# FORMULA: basebet = balance * (m-1) / (m^n_remain - 1)
# n_remain = จำนวน loss ที่รับได้อีก (max_allowed - streak_so_far)
calculate_basebet() {
    local bal="${1}" streak="${2}" m="${3}"
    local n_remain=$(( max_allowed_loss_streak - streak ))
    if [[ "$n_remain" -le 0 ]]; then nextbet=0; return; fi
    if [[ "$streak" -eq 0 ]]; then
        nextbet=$(float_div "$bal" "1000")
    else
        nextbet=$(slv -q "basebet/bal=(m-1)/(m^n-1)" \
            "bal=$bal" "m=$m" "n=$n_remain" "8" d)
    fi
}

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

# ─── INPUTS ─────────────────────────────
start_bal=100
wallet=0          # เงินสำรองในกระเป๋า (reload ได้)
multiplier=2
max_allowed_loss_streak=10

# ─── INIT ───────────────────────────────
balance=$start_bal
loss_streak=0
lose_count=0
nextbet=0

cn 33 b "=== Losing Streak Simulator ==="
cn 33   "  start=$start_bal | mult=$multiplier | max_streak=$max_allowed_loss_streak"
echo ""

# ─── LOSING LOOP ────────────────────────
while [[ $loss_streak -lt $max_allowed_loss_streak ]]; do
    calculate_basebet "$balance" "$loss_streak" "$multiplier"
    cn 245 "  [streak=$loss_streak] nextbet=$nextbet"
    dobet "$nextbet" || break
done

echo ""
cn 46 b "=== RESULT ==="
cn 46   "  Final balance  : $balance"
cn 46   "  Wallet left    : $wallet"
cn 46   "  Total bets     : $lose_count"
cn 46   "  Max streak hit : $loss_streak"
cn 46   "  Total loss     : $(fsub "$start_bal" "$balance")"

# ─── HUMAN STOP CONDITION ───────────────
if [[ $(echo "$balance == 0" | bc) -eq 1 && $(echo "$wallet == 0" | bc) -eq 1 ]]; then
    echo ""
    cn 196 b "  busted everything successfully"
    cn 196   "  good job 👏"
    exit 0
fi


  