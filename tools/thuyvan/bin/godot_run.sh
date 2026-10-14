#!/bin/zsh
# Thủy Vân builders' Godot wrapper. It takes THE SAME lock as the Tidebreak loop's wrappers
# (84dd193e.../scratchpad/godot_run.sh and blender_run.sh), so Godot and Blender together run one heavy process at a time
# on the owner's Mac mini. Same stale rule as the loop (a lock older than 20 min is taken back), so the run limit is
# capped at 1100 s: a live run can never look stale. For a first project import that needs longer, run the import again
# (Godot continues where it stopped) instead of raising the cap.
#   zsh godot_run.sh --headless --path <thuyvan worktree> -s tests/x/test_y.gd
LOCK=/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot.lock
if [[ ! -d ${LOCK:h} ]]; then
  print -u2 "godot_run.sh: the shared lock's folder ${LOCK:h} is gone; ask the lead which lock is canonical now. Not running."
  exit 3
fi
T=${GODOT_TIMEOUT:-900}
if (( T > 1100 )); then print -u2 "godot_run.sh: GODOT_TIMEOUT $T > 1100 would outlive the 20-min stale rule; capped."; T=1100; fi
while ! mkdir "$LOCK" 2>/dev/null; do
  if [[ -n $(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null) ]]; then rmdir "$LOCK" 2>/dev/null; fi
  sleep 3
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
nice -n 10 perl -e 'alarm shift; exec @ARGV' "$T" /Applications/Godot_mono.app/Contents/MacOS/Godot "$@"
