#!/bin/zsh
# Runs one Godot test headless through the lock (godot_run.sh), in a worktree, and says plainly how it went.
#   zsh run_test.sh <worktree> <name> <test script res path, e.g. tests/sway/test_bending.gd> [user args after --] ...
#   GODOT_TIMEOUT=300 zsh run_test.sh /path/to/worktree bending tests/sway/test_bending.gd mode=duel
# The log: <scratchpad>/logs/<name>.log. Printed: EXIT, the PASSED/FAILED line, every FAIL line, the SCRIPT ERROR count.
# Green = EXIT 0 and a PASSED line and 0 SCRIPT ERROR.
S=/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad
W="$1"; NAME="$2"; SCRIPT="$3"; shift 3
mkdir -p "$S/logs"
LOG="$S/logs/$NAME.log"
FPS=60
zsh "$S/godot_run.sh" --headless --fixed-fps $FPS --path "$W" -s "$SCRIPT" -- "$@" > "$LOG" 2>&1
CODE=$?
echo "EXIT $CODE"
grep -E "PASSED|FAILED" "$LOG" | tail -3
grep -E "^\s*FAIL" "$LOG" | head -40
echo "SCRIPT ERROR count: $(grep -c 'SCRIPT ERROR' "$LOG")"
grep -A2 'SCRIPT ERROR' "$LOG" | head -20
echo "LOG $LOG"
