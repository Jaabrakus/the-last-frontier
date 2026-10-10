#!/bin/zsh
# Keeps the owner's app in front while agents' windowed Godot runs start (the owner, 2026-10-10: "i keep seeing a gray
# screen when u run the task"). macOS brings every new Godot window forward while it loads, a gray window over whatever
# the owner was watching. This watcher remembers the last app in front that is not Godot; when a NEW Godot process has
# just started and Godot is in front, it hands the front back to that app. A Godot window the owner clicks on later (a
# game they launched) is left alone: only the first few seconds after a Godot process starts are guarded.
# Needs no permissions (lsappinfo, open). Stop it with Ctrl-C.
#   zsh tools/loop/focus_guard.sh
GUARD_S=${FOCUS_GUARD_S:-6}
last_app=""
typeset -A seen
while true; do
  front_asn=$(lsappinfo front 2>/dev/null)
  front_info=$(lsappinfo info -only name -only bundlepath "$front_asn" 2>/dev/null)
  front_name=$(print -r -- "$front_info" | sed -n 's/.*"LSDisplayName"="\([^"]*\)".*/\1/p' | head -1)
  front_path=$(print -r -- "$front_info" | sed -n 's/.*"LSBundlePath"="\([^"]*\)".*/\1/p' | head -1)
  if [[ -n "$front_name" && "$front_name" != Godot* ]]; then
    last_app="$front_path"
  fi
  young=0
  # (only scripted runs, " -s <script>": an agent's capture or test; a game the owner starts has no -s and is never pushed back)
  for line in ${(f)"$(ps -axo pid=,etime=,command= | grep -E 'Godot(_mono)?\.app/Contents/MacOS/Godot' | grep -- ' -s ' | grep -v -- '--headless' | grep -v grep)"}; do
    pid=${${(z)line}[1]}
    et=${${(z)line}[2]}
    secs=0
    if [[ "$et" == *:* && "$et" != *-* && "$et" != *:*:* ]]; then secs=$(( 10#${et%%:*} * 60 + 10#${et##*:} )); else secs=99999; fi
    if (( secs <= GUARD_S )); then young=1; fi
  done
  if (( young )) && [[ "$front_name" == Godot* && -n "$last_app" ]]; then
    open "$last_app" 2>/dev/null
  fi
  sleep 0.4
done
