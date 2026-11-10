#!/usr/bin/env bash
# ------------------------------------------------------------
# File: sc.sh
# ------------------------------------------------------------

repo_dir="$HOME/colors_toolkit"

mkdir -p $repo_dir && cp $HOME/ssot/core/01-colors.sh $repo_dir &&
echo "Repo created: $repo_dir" &&
cd $repo_dir && ls

