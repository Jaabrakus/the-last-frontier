#!/bin/bash
# Character generators (body, hair styles, garments): see build_character.py.
#
# Works on a temporary COPY of the Actor_B rig library; the original .blend in
# external animation source is only read (cp) and never opened for writing.
#
#   tools/character/build_character.sh --body
#   tools/character/build_character.sh --hair all [--previews DIR]
#   tools/character/build_character.sh --garments militia
#
# Env overrides: BLENDER (binary), ACTOR_B_BLEND (rig library to copy).
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1    # the tracked __pycache__ files stay as they are
HERE="$(cd "$(dirname "$0")" && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
: "${ANIMATION_SOURCE_ROOT:?Set ANIMATION_SOURCE_ROOT to the external animation source directory}"
export ANIMATION_SOURCE_ROOT
SRC="${ACTOR_B_BLEND:?Set ACTOR_B_BLEND to the rig library and ANIMATION_SOURCE_ROOT to its source directory}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$SRC" "$TMP/actor_b_rig_copy.blend"
"$BLENDER" -b "$TMP/actor_b_rig_copy.blend" --python-exit-code 1 --python "$HERE/build_character.py" -- "$@"
# cloth attributes (wear, dirt, sweat, seams, folds) for cloth.gdshader on every garment glb
# (plain python3; idempotent)
case " $* " in
    *" --garments "*|*" --all "*) python3 "$HERE/cloth_bake.py" garments > /dev/null ;;
esac
