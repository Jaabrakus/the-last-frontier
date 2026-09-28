#!/bin/sh
# Build assets/horse/horse.glb (+ horse_meta.json, MANIFEST.json) with headless Blender.
#   tools/horse/build_horse.sh [--previews DIR] [--gaits-only] [--out PATH]
# Then re-import in Godot: Godot --headless --path . --import
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
exec perl -e 'alarm shift; exec @ARGV' 600 "$BLENDER" -b --factory-startup --python "$HERE/build_horse.py" -- "$@"
