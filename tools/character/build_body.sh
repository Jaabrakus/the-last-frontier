#!/bin/bash
# Regenerate assets/character/actor_b_body.glb (+ actor_b_body.json).
#
# Works on a temporary COPY of the Actor_B rig library; the original .blend in
# external animation source is only read (cp) and never opened for writing.
# The bind clip (null-add) and preview clips are appended read-only from the
# other Actor_B_0xx.blend libraries.
#
#   tools/character/build_body.sh                      # glb + json
#   tools/character/build_body.sh --previews /tmp/prev # + PNG previews (bind pose + game clips)
#
# Afterwards tools/character/cloth_bake.py adds the cloth attributes (UVs in metres, piece
# codes, edge / seam distances, wear, dirt, sweat, folds) that cloth.gdshader reads.
#
# Env overrides: BLENDER (binary), ACTOR_B_BLEND (rig library to copy).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FRONTIER="$(cd "$HERE/../.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
: "${ANIMATION_SOURCE_ROOT:?Set ANIMATION_SOURCE_ROOT to the external animation source directory}"
export ANIMATION_SOURCE_ROOT
SRC="${ACTOR_B_BLEND:?Set ACTOR_B_BLEND to the rig library and ANIMATION_SOURCE_ROOT to its source directory}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$SRC" "$TMP/actor_b_rig_copy.blend"
"$BLENDER" -b "$TMP/actor_b_rig_copy.blend" --python "$HERE/build_body.py" -- \
    --out "$FRONTIER/assets/character/actor_b_body.glb" "$@"
# UVs, piece codes and wear / dirt / sweat masks for the cloth shader (plain python3)
python3 "$HERE/cloth_bake.py" legacy > /dev/null
