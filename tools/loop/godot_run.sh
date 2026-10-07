#!/bin/zsh
# Godot for every agent through a lock of SLOTS slots (the owner, 2026-10-06: "3 at once"; it was one at a time because the
# Mac overheated): waits for a free slot, runs Godot niced with a time limit (seconds, GODOT_TIMEOUT, default 900), frees
# its slot however it ends. Slot 1 is the old single lock dir, so older wrappers still share it.
#   zsh godot_run.sh --headless --fixed-fps 60 --path <worktree> -s tests/x.gd -- mode=duel
BASE=/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot.lock
SLOTS=${GODOT_SLOTS:-3}
LOCK=""
while [[ -z "$LOCK" ]]; do
  for i in $(seq 1 $SLOTS); do
    if [[ $i -eq 1 ]]; then L="$BASE"; else L="$BASE.$i"; fi
    if mkdir "$L" 2>/dev/null; then LOCK="$L"; break; fi
    # a lock left by a run that died: older than 20 minutes is taken back
    if [[ -n $(find "$L" -maxdepth 0 -mmin +20 2>/dev/null) ]]; then rmdir "$L" 2>/dev/null; fi
  done
  [[ -z "$LOCK" ]] && sleep 3
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
nice -n 10 perl -e 'alarm shift; exec @ARGV' "${GODOT_TIMEOUT:-900}" /Applications/Godot_mono.app/Contents/MacOS/Godot "$@"
