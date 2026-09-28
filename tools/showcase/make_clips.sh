#!/bin/bash
# Records the systems clips (tools/showcase/clips.gd) and makes the films: for every clip <nn>_<clip>.mp4 (clean) and
# <nn>_<clip>_tutorial.mp4 (the tutorial drawn over it), with the game's sound.
#
#   [EXTRA="wildlife=on"] tools/showcase/make_clips.sh <work dir> <films dir> [size, default 1920x1080] [only=a,b]
#
# Always with the survival rules on, as the game plays (the health panel and its rested bar in the picture); the UI laid
# out at the game's window size (project.godot 1600x900, no stretch mode) and scaled to the film's.
#
# Needs Godot (GODOT, default the Godot_mono app) and swiftc (the encoder is built into the work dir). The work dir
# keeps the frames and raw sound (several GB at 1080p): delete it once the films are checked.
set -euo pipefail
cd "$(dirname "$0")/../.."
WORK="$1"
FILMS="$2"
SIZE="${3:-1920x1080}"
ONLY="${4:-}"
GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
mkdir -p "$WORK" "$FILMS"
[ -x "$WORK/video_encode" ] || swiftc -O tools/showcase/video_encode.swift -o "$WORK/video_encode" 2>/dev/null
"$GODOT" --path . --resolution 640x360 --fixed-fps 30 --write-movie "$WORK/raw.avi" \
	-s tools/showcase/clips.gd -- out="$WORK" new_game size="$SIZE" ui=1600x900 survival=on survival_seed=7 $ONLY ${EXTRA:-} > "$WORK/log.txt" 2>&1 || true
grep "SHOWCASE\|CLIPS" "$WORK/log.txt" || true
ALL=$(awk '/^const CLIPS :=/{on=1} on{print} on&&/\]/{exit}' tools/showcase/clips.gd | tr -d '\n\t' | sed 's/.*\[//; s/\].*//; s/[", ]/ /g')
for clip in $(grep -o "SHOWCASE [0-9]* segments: .*" "$WORK/log.txt" | sed 's/.*segments: //; s/,//g'); do
	n=0
	i=0
	for c in $ALL; do i=$((i + 1)); [ "$c" = "$clip" ] && n=$i; done
	d="$WORK/$clip"
	[ -f "$d/frames.txt" ] || { echo "no frames for $clip"; continue; }
	name=$(printf "%02d_%s" "$n" "$clip")
	python3 tools/showcase/video_audio.py "$WORK/raw.avi" "$d/frames.txt" "$d/audio.wav" > "$d/audio_log.txt"
	"$WORK/video_encode" encode "$d/clean" 30 "$FILMS/$name.mp4" "$d/audio.wav"
	"$WORK/video_encode" encode "$d/tut" 30 "$FILMS/${name}_tutorial.mp4" "$d/audio.wav"
	echo "made $FILMS/$name.mp4 and ${name}_tutorial.mp4"
done
