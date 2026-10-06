#!/bin/zsh
# One Godot at a time for every agent (the user's Mac overheats with several): waits for the lock, runs Godot niced with a
# time limit (seconds, GODOT_TIMEOUT, default 900), frees the lock however it ends.
#   zsh godot_run.sh --headless --fixed-fps 60 --path <worktree> -s tests/x.gd -- mode=duel
LOCK=/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot.lock
while ! mkdir "$LOCK" 2>/dev/null; do
  # a lock left by a run that died: older than 20 minutes is taken back
  if [[ -n $(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null) ]]; then rmdir "$LOCK" 2>/dev/null; fi
  sleep 3
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
nice -n 10 perl -e 'alarm shift; exec @ARGV' "${GODOT_TIMEOUT:-900}" /Applications/Godot_mono.app/Contents/MacOS/Godot "$@"
