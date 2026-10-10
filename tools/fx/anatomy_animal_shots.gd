extends "res://tools/fx/anatomy_shots.gd"
## Stills of the skeleton map on animals, spawned on the climbing yard's flat ground (a window):
##   zsh tools/loop/godot_run.sh --path . -s tools/fx/anatomy_animal_shots.gd -- shots=/some/dir
## The same as anatomy_shots.gd with animals=on (the scaffolding is shared there).


func _initialize() -> void:
	animals = true
	super()
