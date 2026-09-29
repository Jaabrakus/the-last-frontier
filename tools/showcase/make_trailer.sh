#!/bin/bash
# The trailer (user 2026-09-28: "lets create a trailer for the game we have a lot going on"): records the takes
# (tools/showcase/trailer.gd), then cuts them to the score with the titles (trailer_edit.py, trailer_score.py).
#
#   tools/showcase/make_trailer.sh <work dir> <out.mp4> [size, default 1920x1080] [only=a,b]
#
# The takes are recorded from a snapshot of the last commit, not the working tree (other work in progress there may
# not even parse): an APFS clone of the project (instant, no space until changed) reset to HEAD, with the trailer's
# own tools copied in. SNAPSHOT=0 records the working tree as it is; KEEP=1 re-cuts the takes already in <work dir>
# (after a change to the edit or the score) without recording again.
#
# Needs Godot (GODOT, default the Godot_mono app), swiftc, python3 with numpy and Pillow. The work dir keeps the
# frames (several GB at 1080p): delete it once the film is checked.
set -euo pipefail
cd "$(dirname "$0")/../.."
WORK="$1"
OUT="$2"
SIZE="${3:-1920x1080}"
ONLY="${4:-}"
GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"
TAKES="$WORK/takes"
if [ "${KEEP:-0}" != "1" ]; then
	SRC="$(pwd)"
	if [ "${SNAPSHOT:-1}" = "1" ]; then
		SRC="$WORK/snapshot"
		rm -rf "$SRC"
		cp -cR . "$SRC" 2>/dev/null || cp -R . "$SRC"
		(cd "$SRC" && git checkout -q -- . && git clean -qfd -e .godot)
		for f in trailer.gd trailer_edit.py trailer_score.py video_encode.swift; do
			cp "tools/showcase/$f" "$SRC/tools/showcase/$f"
		done
		# the clone's .godot (the global class cache, the imports) is the working tree's: rescanned for HEAD's scripts
		(cd "$SRC" && "$GODOT" --headless --path . --import > "$WORK/import.txt" 2>&1) || true
		echo "snapshot of $(cd "$SRC" && git log --oneline -1)"
	fi
	rm -rf "$TAKES"
	mkdir -p "$TAKES/yard"
	(cd "$SRC" && "$GODOT" --path . --resolution 320x180 --fixed-fps 30 --write-movie "$TAKES/raw.avi" \
		-s tools/showcase/trailer.gd -- out="$TAKES" new_game size="$SIZE" survival=on survival_seed=7 wildlife=on \
		birdlife=on $ONLY > "$TAKES/log.txt" 2>&1) || true
	grep "SHOWCASE seg\|SHOWCASE DONE\|SCRIPT ERROR" "$TAKES/log.txt" || true
	if [ -z "$ONLY" ] || echo "$ONLY" | grep -q mammoth; then
		(cd "$SRC" && "$GODOT" --path . --resolution 320x180 --fixed-fps 30 --write-movie "$TAKES/yard/raw.avi" \
			-s tools/showcase/trailer.gd -- out="$TAKES/yard" new_game size="$SIZE" \
			scene=res://scenes/climb_yard.tscn only=mammoth > "$TAKES/yard/log.txt" 2>&1) || true
	fi
fi
python3 tools/showcase/trailer_edit.py "$TAKES,$TAKES/yard" "$OUT" "$WORK"
