#!/bin/zsh
# Godot for every agent through a lock of SLOTS slots (the owner, 2026-10-06: "3 at once"; it was one at a time because the
# Mac overheated): waits for a free slot, runs Godot niced with a time limit (seconds, GODOT_TIMEOUT, default 900), frees
# its slot however it ends. Slot 1 is the old single lock dir, so older wrappers still share it.
#   zsh godot_run.sh --headless --fixed-fps 60 --path <worktree> -s tests/x.gd -- mode=duel
# Windowed runs get --disable-vsync --max-fps 60 (a window behind a video keeps drawing); a perf probe that reads the frame rate
# passes --max-fps 0 itself (an argument given is kept) and --headless runs get neither.
BASE="${TB_LOCK_DIR:-${TMPDIR:-/tmp}/tidebreak-locks}/godot.lock"   # one lock for Godot and Blender; TB_LOCK_DIR moves it
SLOTS=${GODOT_SLOTS:-3}
# a reboot empties /private/tmp: without the lock's parent folder mkdir never succeeds and this waits forever
mkdir -p "$(dirname "$BASE")"
LOCK=""
# the traps are in before the first mkdir: a kill between taking a slot and installing them would leak the slot. LOCK is empty
# while waiting, so a waiting wrapper that dies touches no lock; INT and TERM must end the script (a trap that only ran
# rmdir would leave a waiting wrapper waiting), and the EXIT trap gives the slot back however it ends.
trap 'if [[ -n "$LOCK" ]]; then rmdir "$LOCK" 2>/dev/null; fi' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# a lock left by a run that died is taken back once it is older than twice the run's own time limit (at least 20 minutes:
# a lock must never look stale while its Godot may still be inside GODOT_TIMEOUT)
STALE_MIN=$(( ${GODOT_TIMEOUT:-900} * 2 / 60 ))
[[ $STALE_MIN -lt 20 ]] && STALE_MIN=20
while [[ -z "$LOCK" ]]; do
  for i in $(seq 1 $SLOTS); do
    if [[ $i -eq 1 ]]; then L="$BASE"; else L="$BASE.$i"; fi
    if mkdir "$L" 2>/dev/null; then LOCK="$L"; break; fi
    # a lock left by a run that died
    if [[ -n $(find "$L" -maxdepth 0 -mmin +$STALE_MIN 2>/dev/null) ]]; then rmdir "$L" 2>/dev/null; fi
  done
  [[ -z "$LOCK" ]] && sleep 3
done
# The owner watches videos while agents run: a game window must never pin itself over other apps. Drop
# --always-on-top / -t before the script's "--" (scripts gate their own window flag on TB_ON_TOP, unset here), and give
# windowed runs --disable-vsync --max-fps 60 so a window behind the browser keeps drawing instead of stalling on vsync.
ARGS=() ; SEEN_DD=0 ; HEADLESS=0 ; HAS_MAXFPS=0
for a in "$@"; do
  if [[ $SEEN_DD -eq 0 ]]; then
    case "$a" in
      --) SEEN_DD=1 ;;
      --always-on-top|-t) continue ;;
      --headless) HEADLESS=1 ;;
      --max-fps) HAS_MAXFPS=1 ;;
    esac
  fi
  ARGS+=("$a")
done
EXTRA=()
if [[ $HEADLESS -eq 0 ]]; then
  EXTRA+=(--disable-vsync)
  [[ $HAS_MAXFPS -eq 0 ]] && EXTRA+=(--max-fps 60)
fi
unset TB_ON_TOP
nice -n 10 perl -e 'alarm shift; exec @ARGV' "${GODOT_TIMEOUT:-900}" "${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}" "${EXTRA[@]}" "${ARGS[@]}"
