#!/bin/zsh
# run_test.sh with the physics rate chosen by env FPS (default 60, as run_test.sh; "none" = no --fixed-fps, as some tests'
# headers run them) and the "TEST OK" result lines grepped too. Same log place: <scratchpad>/logs/<name>.log.
#   GODOT_TIMEOUT=420 FPS=120 zsh run_test_fps.sh <worktree> <name> <tests/x.gd> [user args after --] ...
S=/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad
W="$1"; NAME="$2"; SCRIPT="$3"; shift 3
mkdir -p "$S/logs"
LOG="$S/logs/$NAME.log"
F="${FPS:-60}"
T0=$(date +%s)
if [[ "$F" == "none" ]]; then
  zsh "$S/godot_run.sh" --headless --path "$W" -s "$SCRIPT" -- "$@" > "$LOG" 2>&1
else
  zsh "$S/godot_run.sh" --headless --fixed-fps "$F" --path "$W" -s "$SCRIPT" -- "$@" > "$LOG" 2>&1
fi
CODE=$?
T1=$(date +%s)
echo "EXIT $CODE"
echo "WALL $((T1 - T0)) s (includes any wait for the lock)"
grep -E "PASSED|FAILED|TEST OK|TESTS OK" "$LOG" | tail -3
grep -E "^\s*FAIL" "$LOG" | head -40
echo "SCRIPT ERROR count: $(grep -c 'SCRIPT ERROR' "$LOG")"
grep -A2 'SCRIPT ERROR' "$LOG" | head -20
echo "LOG $LOG"
