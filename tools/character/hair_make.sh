#!/bin/bash
# Hair recipes, one command (2026-09-28): build the styles from their recipes (tools/character/hair/<id>.py,
# see hair/_recipe.py), import them and render a close preview of each on a man and a woman.
#
#   tools/character/hair_make.sh <id[,id...]> [people] [out_dir] [extra hair_preview args...]
#   tools/character/hair_make.sh hair_braid_f haudenosaunee /tmp/braid dz=-0.13 half=0.25 fov=26
#
# Writes <out_dir>/<id>_<body type>_<angle>.png. Every step runs under a time limit.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
IDS="$1"
PEOPLE="${2:-english}"
OUT="${3:-${TMPDIR:-/tmp}/hair_make}"
shift $(( $# < 3 ? $# : 3 ))
if [ -z "$IDS" ]; then
    sed -n '2,9p' "$0"
    exit 1
fi
perl -e 'alarm 1800; exec @ARGV' "$HERE/build_character.sh" --hair "$IDS"
perl -e 'alarm 600; exec @ARGV' "$GODOT" --headless --path "$ROOT" --import > /dev/null 2>&1 || true
mkdir -p "$OUT"
perl -e 'alarm 900; exec @ARGV' "$GODOT" --path "$ROOT" --resolution 1280x720 -s tools/character/hair_preview.gd -- \
    out="$OUT" styles="$IDS" people="$PEOPLE" "$@"
echo "previews in $OUT"
