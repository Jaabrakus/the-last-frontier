#!/bin/bash
# One film of several systems clips: the game's painted start-up splash first (tools/showcase/splash_intro.py), the
# clips one after the other (each fades in and out already), and an end card with the credits.
#
#   tools/showcase/combine.sh <work dir> <out.mp4> <intro.mp4> "<credit lines, \n between>" <clip.mp4> <clip.mp4> ...
#
# The encoder (video_encode.swift) is built into the work dir if it is not there.
set -euo pipefail
cd "$(dirname "$0")/../.."
WORK="$1"; OUT="$2"; INTRO="$3"; CREDITS="$4"
shift 4
mkdir -p "$WORK"
[ -x "$WORK/video_encode" ] || swiftc -O tools/showcase/video_encode.swift -o "$WORK/video_encode" 2>/dev/null
rm -rf "$WORK/end"
python3 tools/showcase/card.py "$WORK/end" 6 "Frontier" "In development" "$CREDITS"
"$WORK/video_encode" encode "$WORK/end/frames" 30 "$WORK/end.mp4" "$WORK/end/audio.wav" > /dev/null
"$WORK/video_encode" join "$OUT" "$INTRO" "$@" "$WORK/end.mp4"
