#!/bin/zsh
cd -- "${0:A:h}"
exec /Applications/Godot_mono.app/Contents/MacOS/Godot --path "$PWD" res://scenes/main.tscn -- quality=medium --no-creator --agls-preview --frontier-blend --frontier-legacy
