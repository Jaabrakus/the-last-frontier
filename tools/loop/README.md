# The improvement loop's helpers

Copies of the scratchpad wrappers the build agents use: `godot_run.sh` and `blender_run.sh` (one heavy process at a
time, through a mkdir lock), `run_test.sh` / `run_test_fps.sh` (one headless test, its PASSED/FAILED line and SCRIPT
ERROR count), and `recover.py` (rebuilds the scratchpad's text files from the session transcripts). macOS empties
/private/tmp on reboot: copy these back to the scratchpad before restarting a round. The design specs they serve
are in docs/tidebreak/.
