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
# Without ACTOR_B_BLEND / ANIMATION_SOURCE_ROOT the rig is rebuilt from tools/character/rig/actor_b_skeleton.json
# (rig/make_rig_blend.py: the same bones, order and bind pose; the driver reference kept from body.json).
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1    # the tracked __pycache__ files stay as they are
HERE="$(cd "$(dirname "$0")" && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if [ -n "${ACTOR_B_BLEND:-}" ]; then
    : "${ANIMATION_SOURCE_ROOT:?Set ANIMATION_SOURCE_ROOT to the external animation source directory}"
    export ANIMATION_SOURCE_ROOT
    cp "$ACTOR_B_BLEND" "$TMP/actor_b_rig_copy.blend"
else
    unset ANIMATION_SOURCE_ROOT
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/rig/make_rig_blend.py" -- "$TMP/actor_b_rig_copy.blend" > /dev/null
    cp "$TMP/actor_b_rig_copy.blend" "$TMP/actor_b_bind.blend"   # (the bind clip loads from another file)
    export ACTOR_B_RIG_BLEND="$TMP/actor_b_bind.blend"
fi
"$BLENDER" -b "$TMP/actor_b_rig_copy.blend" --python-exit-code 1 --python "$HERE/build_character.py" -- "$@"
# cloth attributes (wear, dirt, sweat, seams, folds) for cloth.gdshader on every garment glb
# (plain python3; idempotent)
case " $* " in
    *" --garments "*|*" --all "*) python3 "$HERE/cloth_bake.py" garments > /dev/null ;;
esac
