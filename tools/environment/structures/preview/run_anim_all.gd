extends "res://tests/anim/run_all.gd"
## Runs res://tests/anim/run_all.gd against the level with FrontierStructures (package D
## preview, see preview_hook.gd). Same arguments as the original runner.


func _initialize() -> void:
	preload("res://tools/environment/structures/preview/preview_hook.gd").install()
	super()
