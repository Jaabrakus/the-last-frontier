#!/bin/zsh
# Blender headless under the same slotted lock as Godot (godot_run.sh: SLOTS slots, the owner's "3 at once"), niced,
# time-limited.
#   zsh blender_run.sh -b -P tools/anim_author/blender/bend_clips.py -- --out /path/bend.json
BASE="${TB_LOCK_DIR:-${TMPDIR:-/tmp}/tidebreak-locks}/godot.lock"   # one lock for Godot and Blender; TB_LOCK_DIR moves it
SLOTS=${GODOT_SLOTS:-3}
# a reboot empties /private/tmp: without the lock's parent folder mkdir never succeeds and this waits forever
mkdir -p "$(dirname "$BASE")"
LOCK=""
while [[ -z "$LOCK" ]]; do
  for i in $(seq 1 $SLOTS); do
    if [[ $i -eq 1 ]]; then L="$BASE"; else L="$BASE.$i"; fi
    if mkdir "$L" 2>/dev/null; then LOCK="$L"; break; fi
    if [[ -n $(find "$L" -maxdepth 0 -mmin +20 2>/dev/null) ]]; then rmdir "$L" 2>/dev/null; fi
  done
  [[ -z "$LOCK" ]] && sleep 3
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
nice -n 10 perl -e 'alarm shift; exec @ARGV' "${BLENDER_TIMEOUT:-900}" "${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}" "$@"
