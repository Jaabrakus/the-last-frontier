#!/bin/sh
# Build assets/bison/bison.glb (+ bison_meta.json, MANIFEST.json, textures) with headless Blender: the horse's
# generator (tools/horse/build_horse.py) on the bison's anatomy (tools/bison/anatomy.py).
#   tools/bison/build_bison.sh [--previews DIR] [--gaits-only] [--out PATH]
# Then re-import in Godot: Godot --headless --path . --import
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
FRONTIER_SPECIES=bison exec "$HERE/../horse/build_horse.sh" "$@"
