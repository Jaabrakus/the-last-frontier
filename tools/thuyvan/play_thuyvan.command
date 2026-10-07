#!/bin/zsh
# Thủy Vân: the Still Water greybox (scenes/thuyvan_preview.tscn). Double-click in Finder to play.
# Walk to the river; F9 stills a reach of it (S0 <-> S1). Esc for the menu (no saving in the greybox).
# Optional: pass quality=high|medium|low after the command (default medium), and "r1" for R1's Đá Trắng vista instead
# (scenes/thuyvan_r1.tscn: the painted gorge, rope bridge and village; play_thuyvan_r1.command does the same).
LANE=${0:A:h:h:h}
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
if [[ ! -x $GODOT ]]; then
  print -u2 "Godot is not at $GODOT."
  read -k1 "?Press a key to close."
  exit 1
fi
SCENE=res://scenes/thuyvan_preview.tscn
QUALITY=quality=medium
for a in "$@"; do
  case $a in
    r1) SCENE=res://scenes/thuyvan_r1.tscn ;;
    quality=*) QUALITY=$a ;;
  esac
done
cd "$LANE" || exit 1
exec "$GODOT" --path "$LANE" "$SCENE" -- --no-creator "$QUALITY"
