#!/usr/bin/env bash
# ------------------------------------------------------------
# File: dicebot.sh
# ------------------------------------------------------------
dice_dir="$hpc/AppData/Local/Gambler.Bot"
dice_sim="$dice_dir/simulator"
conf_dir="$dice_dir/simulator/config/dice.env"

link_dice(){
    [[ -f "$dice_sim" ]] && {
    rm -rf "$dice_sim" &&
    echo "removing old dicebot and simulator"
    }
    ln -s "$sim" "$dice_sim" &&
    echo "done symlink dicebot and simulator"
    readlink "$dice_sim" || echo "failed to symlink dicebot and simulator"
}




