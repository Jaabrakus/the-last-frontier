#!/bin/zsh
cd -- "${0:A:h}"
exec /Applications/Godot_mono.app/Contents/MacOS/Godot --path "$PWD" res://tools/agls_comparison/preview.tscn -- quality=medium --no-creator --agls-preview --frontier-blend --frontier-legacy
