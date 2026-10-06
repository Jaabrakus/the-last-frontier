#!/bin/zsh
# Thủy Vân builders' Blender wrapper: the same single heavy-process lock as godot_run.sh and the Tidebreak loop's
# wrappers. Run limit capped at 1100 s (below the 20-min stale rule).
#   zsh blender_run.sh -b -P tools/asset_author/blender/x.py -- --out /path
LOCK=/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot.lock
if [[ ! -d ${LOCK:h} ]]; then
  print -u2 "blender_run.sh: the shared lock's folder ${LOCK:h} is gone; ask the lead which lock is canonical now. Not running."
  exit 3
fi
T=${BLENDER_TIMEOUT:-900}
if (( T > 1100 )); then print -u2 "blender_run.sh: BLENDER_TIMEOUT $T > 1100; capped."; T=1100; fi
while ! mkdir "$LOCK" 2>/dev/null; do
  if [[ -n $(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null) ]]; then rmdir "$LOCK" 2>/dev/null; fi
  sleep 3
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
nice -n 10 perl -e 'alarm shift; exec @ARGV' "$T" /Applications/Blender.app/Contents/MacOS/Blender "$@"
