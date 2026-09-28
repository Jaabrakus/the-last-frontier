extends "res://scripts/world/frontier_level.gd"
## Package D tool copy of the level. Since 2026-09-25 frontier_level.gd builds FrontierStructures
## itself (frontier_level_integration.diff applied), so this subclass is the real level plus the
## structure switches the tools use. Game code never uses this file; the run_*.gd wrappers and
## structure_shots.gd swap it in for res://scenes/main.tscn (see preview_hook.gd).
##
## User args:
##   structures=hide   build the fort as the game does, then hide it (Structures.visible = false:
##                     the no-fort render for masks; colliders stay). "off" means the same now:
##                     the placeholder fort left frontier_level.gd with the integration.
##   extras=0          FrontierStructures.extra_colliders = false (the original 59 colliders)
##   props=0           no props (and no prop colliders)
##   occluders=0       no occluders
##   visuals=0         colliders and gameplay nodes only (as headless)
## The old sun=target switch is gone: the lighting is package A's user-approved look.


func _ready() -> void:
	# The switches must be set between add_child() and build() in the parent's _ready().
	child_entered_tree.connect(_configure)
	super()
	child_entered_tree.disconnect(_configure)
	if structures:
		if _arg("structures") in ["hide", "off"]:
			structures.visible = false
			print("STRUCTURES hidden")
		print("STRUCTURES stats ", structures.stats)


func _configure(node: Node) -> void:
	var s := node as FrontierStructures
	if s == null:
		return
	s.extra_colliders = _arg("extras") != "0"
	s.props = _arg("props") != "0"
	s.occluders = _arg("occluders") != "0"
	if _arg("visuals") == "0":
		s.visuals = false


static func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with(key + "="):
			return s.get_slice("=", 1)
	return ""
