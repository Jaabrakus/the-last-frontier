#!/bin/zsh
# run_test.sh with the physics rate chosen by env FPS (default 60, as run_test.sh; "none" = no --fixed-fps, as some tests'
# headers run them) and the "TEST OK" result lines grepped too. Log place: <scratchpad>/logs/<name>.log (TB_SCRATCH
# overrides the scratchpad; the default is the one the older gates used).
#   GODOT_TIMEOUT=420 FPS=120 zsh run_test_fps.sh <worktree> <name> <tests/x.gd> [user args after --] ...
# Runs the godot_run.sh next to this file (the lock). Exits with Godot's exit code, and says "NO RESULT LINE" when the log
# holds no PASSED / FAILED / TEST OK line (a missing wrapper, a timeout, a crash), so that never reads as green.
R=${0:A:h}
S=${TB_SCRATCH:-${TMPDIR:-/tmp}/tidebreak-scratch}
W="$1"; NAME="$2"; SCRIPT="$3"; shift 3
mkdir -p "$S/logs"
LOG="$S/logs/$NAME.log"
F="${FPS:-60}"
T0=$(date +%s)
if [[ "$F" == "none" ]]; then
  zsh "$R/godot_run.sh" --headless --path "$W" -s "$SCRIPT" -- "$@" > "$LOG" 2>&1
else
  zsh "$R/godot_run.sh" --headless --fixed-fps "$F" --path "$W" -s "$SCRIPT" -- "$@" > "$LOG" 2>&1
fi
CODE=$?
T1=$(date +%s)
echo "EXIT $CODE"
echo "WALL $((T1 - T0)) s (includes any wait for the lock)"
RESULT=$(grep -E "PASSED|FAILED|TEST OK|TESTS OK" "$LOG" | tail -3)
if [[ -n "$RESULT" ]]; then echo "$RESULT"; else echo "NO RESULT LINE (no PASSED / FAILED / TEST OK in the log)"; fi
grep -E "^\s*FAIL" "$LOG" | head -40
echo "SCRIPT ERROR count: $(grep -c 'SCRIPT ERROR' "$LOG")"
grep -A2 'SCRIPT ERROR' "$LOG" | head -20
echo "LOG $LOG"
exit $CODE
