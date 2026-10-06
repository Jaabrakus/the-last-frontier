#!/bin/zsh
# Thủy Vân: the Still Water greybox (scenes/thuyvan_preview.tscn). Double-click in Finder to play.
# Walk to the river; F9 stills a reach of it (S0 <-> S1). Esc for the menu (no saving in the greybox).
# Optional: pass quality=high|medium|low after the command (default medium).
LANE=${0:A:h:h:h}
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
if [[ ! -x $GODOT ]]; then
  print -u2 "Godot is not at $GODOT."
  read -k1 "?Press a key to close."
  exit 1
fi
QUALITY=${1:-quality=medium}
cd "$LANE" || exit 1
exec "$GODOT" --path "$LANE" res://scenes/thuyvan_preview.tscn -- --no-creator "$QUALITY"
