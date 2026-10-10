#!/bin/zsh
# Runs one Godot test headless through the lock (godot_run.sh), in a worktree, and says plainly how it went:
# run_test_fps.sh (next to this file) at 60 fps.
#   zsh run_test.sh <worktree> <name> <test script res path, e.g. tests/sway/test_bending.gd> [user args after --] ...
#   GODOT_TIMEOUT=300 zsh run_test.sh /path/to/worktree bending tests/sway/test_bending.gd mode=duel
# The log: <scratchpad>/logs/<name>.log. Printed: EXIT, WALL, the PASSED/FAILED line, every FAIL line, the SCRIPT ERROR count.
# Green = EXIT 0 and a PASSED line and 0 SCRIPT ERROR.
FPS=60 exec zsh "${0:A:h}/run_test_fps.sh" "$@"
