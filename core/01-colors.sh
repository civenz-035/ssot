#!/usr/bin/env bash
# ============================================================
# 01-colors.sh — SSOT Color Engine Loader (ez_colors Shim)
# Seamlessly routes to the standalone modular ez_colors plugin
# ============================================================
if [[ -f "$HOME/.ez_colors/colors.sh" ]]; then
    source "$HOME/.ez_colors/colors.sh"
elif [[ -f "$HOME/colors_toolkit/colors.sh" ]]; then
    source "$HOME/colors_toolkit/colors.sh"
elif [[ -f "${BASH_SOURCE[0]%/*}/.01-colors.sh.bak" ]]; then
    source "${BASH_SOURCE[0]%/*}/.01-colors.sh.bak"
fi

