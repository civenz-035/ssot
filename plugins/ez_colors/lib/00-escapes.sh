#!/usr/bin/env bash
# ============================================================
# 00-escapes.sh — Low-level ANSI escape helpers
# ============================================================
# Foreground 256-color
_fg()  { printf '\033[38;5;%sm' "$1"; }
# Background 256-color
_bg()  { printf '\033[48;5;%sm' "$1"; }
# Color (alias for _fg, used internally)
_c()   { printf '\e[38;5;%sm' "$1"; }
# Reset all attributes
_r()   { printf '\e[0m'; }
r_()   { printf '\033[0m'; }   # legacy alias
# Reset background only
_rbg() { printf '\e[49m'; }
# Reset foreground only
_rfg() { printf '\e[39m'; }
# Style helpers
_b()   { printf '\e[1m'; }     # bold
_d()   { printf '\e[2m'; }     # dim
_i()   { printf '\e[3m'; }     # italic
_u()   { printf '\e[4m'; }     # underline
# _c_apply <esc> <text> — wrap text with a precomputed color escape
_c_apply() { printf '%s%s\e[0m' "$1" "$2"; }

# ============================================================
# 16-COLOR BASE VARIABLES  (used by c/cn short-name syntax)
# ============================================================
R='\e[38;5;196m'  ; LR='\e[38;5;203m'
G='\e[38;5;82m'   ; LG='\e[38;5;46m'
Y='\e[38;5;226m'
CR='\e[38;5;51m'  ; LCR='\e[38;5;87m'
B='\e[38;5;33m'   ; LB='\e[38;5;75m'
M='\e[38;5;141m'  ; LM='\e[38;5;141m'
W='\e[38;5;255m'  ; GR='\e[38;5;244m'
ORA='\e[38;5;208m'

# Lowercase palette globals (used by JOE_BLOCK engine and cbg)
lr='\e[38;5;203m'   # light red
lb='\e[38;5;75m'    # light blue
lg='\e[38;5;46m'    # light green
ora='\e[38;5;208m'  # orange
gr='\e[38;5;244m'   # gray
lm='\e[38;5;141m'   # light magenta
lc='\e[38;5;87m'    # light cyan
y='\e[38;5;226m'    # yellow

