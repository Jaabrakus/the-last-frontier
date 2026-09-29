extends "res://scripts/world/frontier_level.gd"
## The climbing test scene (user 2026-09-27: "yea a test scene to see it in action"): the whole level, with the climbing
## yard (ClimbYard: rock step, cliff, slab, the woolly mammoth and a bison) at the far end of the range lane and the
## player standing in front of it. Open scenes/climb_yard.tscn and press F6. Press G at a rock face or the mammoth's fur
## to grip, W A S D to crawl, press G again to drop (on a flat part: stand up).
##   Godot --path . res://scenes/climb_yard.tscn [-- station=cliff|step|slab|giant|bison]

const YARD := Vector3(0.0, 0.0, -160.0)

var yard: ClimbYard


func _ready() -> void:
	super._ready()
	var p := get_node("Player") as FrontierPlayer
	yard = ClimbYard.new()
	yard.name = "ClimbYard"
	add_child(yard)
	yard.build(YARD, p)
	var at := YARD + Vector3(0.0, 0.1, 10.0)
	var look := YARD
	for a in OS.get_cmdline_user_args():
		if a.begins_with("station=") and yard.stations.has(a.substr(8)):
			var st: Dictionary = yard.stations[a.substr(8)]
			at = (st.stand as Vector3) + Vector3(0.0, 0.1, 0.0)
			look = st.look
	p.global_position = at
	var to := look - at
	p.yaw = atan2(-to.x, -to.z)
	p.rotation.y = p.yaw
