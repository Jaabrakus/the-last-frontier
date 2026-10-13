#!/bin/zsh
# Play Tidebreak: Godot's index of the project refreshed first (an import, headless: a new script class another session added is
# registered), then the game in its own window. Without the import, pressing Run in Godot's Project Manager after new code has
# landed can start the game with the ring's scripts failing to load: no bending (the owner, 2026-10-11: "how come when i click
# run it doesnt have the bending stuff").
#   zsh tools/play.sh            GODOT_BIN overrides the Godot binary
REPO=${0:A:h:h}
GODOT=${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
echo "Refreshing the project's index (a few seconds)..."
"$GODOT" --headless --path "$REPO" --import > /dev/null 2>&1
echo "Starting Tidebreak."
nohup "$GODOT" --path "$REPO" > /dev/null 2>&1 &
disown
