#!/usr/bin/env bash
# ============================================================
# colors.sh — ez_colors Plugin Entry Point
# Source this file to load the full color toolkit:
#
#   source /path/to/ez_colors/colors.sh
#   # or in ~/.bashrc / ~/.zshrc:
#   source "$HOME/.ez_colors/colors.sh"
#
# Version: 3.0.0
# Repo:    https://github.com/civenz-035/ez_colors
# ============================================================

# Resolve the directory this file lives in (works when sourced in bash or zsh)
_BC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" 2>/dev/null && pwd)"

# Load modules in dependency order
source "$_BC_DIR/lib/00-escapes.sh"   # ANSI escape helpers + color vars
source "$_BC_DIR/lib/01-palette.sh"   # Palette definitions + palettes_()
source "$_BC_DIR/lib/02-render.sh"    # _color_render / c / cn / psc / cbg
source "$_BC_DIR/lib/03-rainbow.sh"   # rainbow_palette / mc / jmc / mcbg / paint
source "$_BC_DIR/lib/04-random.sh"    # random_core / random_color / rc*
source "$_BC_DIR/lib/05-rcc.sh"       # rcc / rcc1 / rcc2 / Rcc / rc_char
source "$_BC_DIR/lib/06-table.sh"     # ctab / hline / draw_ / box_card / _w
source "$_BC_DIR/lib/07-utils.sh"     # _warn _er _sc _ok _ep / c256 / cmp*

unset _BC_DIR
