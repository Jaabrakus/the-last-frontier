#!/bin/zsh
# Blender headless under the same one-heavy-process lock as Godot (the Mac overheats with several), niced, time-limited.
#   zsh blender_run.sh -b -P tools/anim_author/blender/bend_clips.py -- --out /path/bend.json
LOCK=/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot.lock
while ! mkdir "$LOCK" 2>/dev/null; do
  if [[ -n $(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null) ]]; then rmdir "$LOCK" 2>/dev/null; fi
  sleep 3
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
nice -n 10 perl -e 'alarm shift; exec @ARGV' "${BLENDER_TIMEOUT:-900}" /Applications/Blender.app/Contents/MacOS/Blender "$@"
