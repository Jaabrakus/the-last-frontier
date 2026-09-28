extends "res://tools/environment/benchmark.gd"
## Runs res://tools/environment/benchmark.gd against the level with FrontierStructures (package D preview, see
## preview_hook.gd). Same arguments as the original tool.


func _initialize() -> void:
	preload("res://tools/environment/structures/preview/preview_hook.gd").install()
	super()
