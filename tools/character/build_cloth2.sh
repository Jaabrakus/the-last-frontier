#!/bin/bash
# cloth2 garments (see build_cloth2.py). Works on a temporary COPY of the Actor_B rig library; the original
# .blend in Player_Animation_Project is only read.
#
#   tools/character/build_cloth2.sh shirt_linen,breeches
#   tools/character/build_cloth2.sh all
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
HERE="$(cd "$(dirname "$0")" && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
SRC="${ACTOR_B_BLEND:-$HOME/Downloads/Player_Animation_Project/blender_libraries/Actor_B_001.blend}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$SRC" "$TMP/actor_b_rig_copy.blend"
"$BLENDER" -b "$TMP/actor_b_rig_copy.blend" --python-exit-code 1 --python "$HERE/build_cloth2.py" -- "$@" | tee "$TMP/log.txt"
# the cloth shader's attributes (dirt, wear, sweat, seams, folds) in the new glbs only
for g in $(grep -o 'CLOTH2_GLB .*' "$TMP/log.txt" | cut -d' ' -f2); do
    python3 "$HERE/cloth_bake.py" "$g" > /dev/null
done
