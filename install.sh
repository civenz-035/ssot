#!/usr/bin/env bash
# ============================================================
# 🚀 SSOT Quick Installer Entry Point
# ============================================================
# Usage:
#   bash ~/ssot/install.sh <device>
#   e.g. termux | mumu | oppo | wsl | wsl2 | git-bash | acodex | userland
# ============================================================
_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
exec bash "$_ROOT_DIR/bootstrap/install.sh" "$@"
