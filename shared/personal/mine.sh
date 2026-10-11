#!/usr/bin/env bash
# ------------------------------------------------------------
# File: mine.sh
# Mines Probability Engine CLI
# Based on 25 tiles grid (5x5), default 1% House Edge
# ------------------------------------------------------------

mine() {
    python3 - "$@" << 'EOF'
import sys
import math

def print_help():
    help_text = """💣 Mines Probability Engine CLI

Usage:
  mine -mode payout -mine <bombs> -dimond <picks> [-bet <amount>] [-he <house_edge>]
  mine -mode invers -payout <target> [-he <house_edge>]

Options:
  -mode       Mode to run: 'payout' or 'invers' (or 'inverse')
  -mine, -m   Number of bombs / mines (1-24)
  -dimond, -d Number of diamonds / picks (1-24)
  -bomb       Alternative flag for bombs
  -bet, -b    Bet amount (default: 1)
  -payout, -p Target payout multiplier for inverse search
  -he         House edge (default: 0.01 / 1%)
  -h, --help  Show this help message

Examples:
  mine -mode payout -mine 10 -dimond 10 -bet 1
  mine -mode invers -payout 3000
"""
    print(help_text.strip())

def parse_args(args):
    params = {
        'mode': None,
        'mine': None,
        'bomb': None,
        'diamond': None,
        'bet': 1.0,
        'payout': None,
        'he': 0.01,
    }

    i = 0
    while i < len(args):
        arg = args[i]
        lower = arg.lower()
        if lower in ('-mode', '--mode'):
            i += 1
            if i < len(args):
                params['mode'] = args[i].lower()
        elif lower in ('payout', 'invers', 'inverse') and params['mode'] is None:
            params['mode'] = lower
        elif lower in ('-mine', '--mine', '-m'):
            i += 1
            if i < len(args):
                try:
                    params['mine'] = int(args[i])
                except ValueError:
                    pass
        elif lower in ('-bomb', '--bomb'):
            i += 1
            if i < len(args):
                try:
                    params['bomb'] = int(args[i])
                except ValueError:
                    pass
        elif lower in ('-dimond', '--dimond', '-diamond', '--diamond', '-pick', '--pick', '-picks', '--picks', '-d', '-k'):
            i += 1
            if i < len(args):
                try:
                    params['diamond'] = int(args[i])
                except ValueError:
                    pass
        elif lower in ('-bet', '--bet', '-b'):
            i += 1
            if i < len(args):
                try:
                    params['bet'] = float(args[i])
                except ValueError:
                    pass
        elif lower in ('-payout', '--payout', '-p'):
            i += 1
            if i < len(args):
                try:
                    params['payout'] = float(args[i])
                except ValueError:
                    pass
        elif lower in ('-he', '--he'):
            i += 1
            if i < len(args):
                try:
                    val = float(args[i].rstrip('%'))
                    params['he'] = val / 100.0 if val >= 1.0 else val
                except ValueError:
                    pass
        elif lower in ('-h', '--help', 'help'):
            params['mode'] = 'help'
        i += 1

    return params

def run():
    args = sys.argv[1:]
    if not args:
        print_help()
        return

    params = parse_args(args)

    if params['mode'] == 'help':
        print_help()
        return

    # Auto-detect mode if not explicitly set
    if not params['mode']:
        if params['payout'] is not None:
            params['mode'] = 'invers'
        elif params['mine'] is not None or params['diamond'] is not None or params['bomb'] is not None:
            params['mode'] = 'payout'
        else:
            print_help()
            return

    he = params['he']

    if params['mode'] == 'payout':
        # Resolve M (Bombs) and K (Diamonds / Picks)
        if params['bomb'] is not None:
            M = params['bomb']
            K = params['diamond'] if params['diamond'] is not None else params['mine']
        else:
            M = params['mine']
            K = params['diamond']

        if M is None or K is None:
            print("Error: Missing -mine and/or -dimond parameters.\n", file=sys.stderr)
            print_help()
            sys.exit(1)

        if M < 1 or M > 24 or K < 1 or K > 24 or (M + K) > 25:
            print(f"Error: Invalid combination. Mine={M}, Diamond={K}. Must satisfy 1 <= M,K <= 24 and M + K <= 25.", file=sys.stderr)
            sys.exit(1)

        bet = params['bet']
        chance = math.comb(25 - M, K) / math.comb(25, K)
        if chance <= 0:
            print("Error: Probability is 0.", file=sys.stderr)
            sys.exit(1)

        payout = (1.0 - he) / chance
        win_amount = bet * payout
        inc_pct = ((payout / (payout - 1.0)) - 1.0) * 100.0 if payout > 1.0 else 0.0

        he_str = f"{int(he * 100)}%" if (he * 100).is_integer() else f"{he * 100:.2f}%"

        print("Win Chance")
        print(f"{chance * 100:.6f} %")
        print(f"Payout (HE {he_str})")
        print(f"{payout:.2f}x")
        print("Win Amount")
        print(f"{win_amount:.8f}")
        print("% Increase Bet")
        print(f"{inc_pct:.2f} %")

    elif params['mode'] in ('invers', 'inverse'):
        target = params['payout']
        if target is None:
            print("Error: Missing -payout parameter.\n", file=sys.stderr)
            print_help()
            sys.exit(1)

        min_diff = float("inf")
        res = []

        for M in range(1, 25):
            for K in range(1, 26 - M):
                chance = math.comb(25 - M, K) / math.comb(25, K)
                p = (1.0 - he) / chance
                d = abs(p - target)
                if d < min_diff - 1e-9:
                    min_diff = d
                    res = [(M, K, p)]
                elif abs(d - min_diff) < 1e-9:
                    res.append((M, K, p))

        target_str = int(target) if target.is_integer() else target
        print(f"Input Payout = {target_str}\n")
        if res:
            print(f"Closest Payout = {res[0][2]:.2f}x\n")
            print("Symbol:")
            for M, K, p in res:
                print(f"- Mine {K}, Bomb {M} ({p:.2f}x)")
        else:
            print("No valid combination found.")
    else:
        print(f"Unknown mode: {params['mode']}\n", file=sys.stderr)
        print_help()
        sys.exit(1)

if __name__ == '__main__':
    run()
EOF
}

# Allow script to be executed directly if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -uo pipefail
    mine "$@"
fi
