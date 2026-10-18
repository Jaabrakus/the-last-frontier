#!/bin/zsh
set -eu
task_dir="${0:A:h}"
task_root="${task_dir:h:h}"
exec /Applications/Godot_mono.app/Contents/MacOS/Godot \
  --path "$task_root" scenes/labs/extracted_assets_lab.tscn -- --no-creator
