extends SceneTree
## The fishing rod's poses (user 2026-09-28: the rod held up and back "should only be like that when we have a fish on
## the line where it can bend the pole", "we need a animation for how they pull the line towards us", "the user will
## pull the tip of the rod closer to them"): this project's
## own, keyed by hand (tools/anim_author/pose_solver.gd, the rest pose and IK, no clip's data), for FishingGear:
##   rod_hold    the rod held out over the water in both hands, low, the butt by the right hip (the float out, waiting)
##   rod_fight   a fish on, scrubbed by how far the rod is pulled back (its time 0..1 is the pull, FishingGear.lift):
##               at 0 the rod lowered toward the fish, giving; at 1 its tip drawn up and back over the right shoulder,
##               toward the angler, the body leaning back against it (the pull that leads the fish in)
## The right hand holds the rod ROD_UP up from its butt, the left ROD_SPREAD below it (at the butt's end), and the
## right hand's prop bone carries the rod the clubbed musket's way (pose_solver carry "pipe"), so the game hangs it
## there as it does in the cast (the club's swings): FishingGear.ROD_IN_HANDS.
## Keys in the body's frame (+X its left, +Z ahead, heights from the ground), written into data/anim_author/fishing.json;
## a preview renders them with the rod on; the bake puts them in animations_extra/Frontier_Own.res beside the swings:
##   Godot --headless --path . -s tools/anim_author/author_fishing.gd                  (write the keys)
##   Godot --path . -s tools/anim_author/author_fishing.gd -- preview out=<abs dir>   (sheets of each clip, windowed)
##   Godot --headless --path . -s tools/anim_author/author_swings.gd -- bake data=res://data/anim_author/fishing.json

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const Swings := preload("res://tools/anim_author/author_swings.gd")
const FitRef := preload("res://tools/anim_author/fit_ref.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const DATA := "res://data/anim_author/fishing.json"
## The right hand's hold up the rod from its butt, and the left hand's below it.
const ROD_UP := 0.4
const ROD_SPREAD := 0.28
## The rod in the prop bone's pipe frame (FishingGear.ROD_IN_HANDS): its butt at the knob, along the haft.
const ROD_IN_HANDS := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
const CELL := Vector2i(360, 400)

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var data := {"format": "frontier_anim_author", "version": 1,
			"summary": "The fishing rod's poses, keyed by hand (tools/anim_author/author_fishing.gd): this project's own.",
			"clips": _clips()}
	var fa := FileAccess.open(DATA, FileAccess.WRITE)
	fa.store_string(FitRef.write_json(data))
	fa.close()
	print("FISHING KEYS -> ", DATA)
	if args.has("preview"):
		await _preview(data.clips)
	quit()


## A key: the rod's way (haft), the right hand's grip (the left at the butt), and the body.
static func _key(t: float, haft: Vector3, grip: Vector3, body: Dictionary, ease := "") -> Dictionary:
	var tool := {"grip": _a(grip), "haft": _a(haft.normalized()), "edge": _a(body.get("edge", Vector3(-1, 0, 0))),
			"up": ROD_UP, "spread": ROD_SPREAD}
	var k := {"t": t, "tool": tool,
		"chest": {"yaw": float(body.get("yaw", 0.0)), "pitch": float(body.get("pitch", 0.0)), "roll": float(body.get("roll", 0.0))},
		"head": {"yaw": float(body.get("head_yaw", 0.0)), "pitch": float(body.get("head_pitch", 0.0)), "roll": 0.0},
		"elbows": {"r": _a(body.get("er", Vector3(-0.7, -1.0, -0.1))), "l": _a(body.get("el", Vector3(0.6, -1.0, -0.1)))},
		"fist": 1.0}
	if ease != "":
		k["ease"] = ease
	return k


static func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func _clips() -> Dictionary:
	var out := {}
	# the rod held out over the water: a quarter up, a little across to the left; the butt beside the right hip, the
	# right hand out in front of the belly, the left at the butt; the chest turned a little to the right, bent over it,
	# the head down to the float; a slow breath (the loop's middle key)
	var hold_a := {"yaw": -10.0, "pitch": 9.0, "head_pitch": 12.0, "head_yaw": 8.0}
	var hold_b := {"yaw": -9.0, "pitch": 8.0, "head_pitch": 11.0, "head_yaw": 8.0}
	out["rod_hold"] = {"desc": "the rod held out over the water in both hands, low", "length": 2.4, "hold": "blade",
		"carry": "pipe", "space": "body", "authored": "keyed by hand (tools/anim_author/author_fishing.gd)",
		"keys": [
			_key(0.0, Vector3(0.1, 0.42, 0.9), Vector3(-0.17, 1.03, 0.44), hold_a),
			_key(1.2, Vector3(0.1, 0.44, 0.9), Vector3(-0.17, 1.04, 0.43), hold_b),
			_key(2.4, Vector3(0.1, 0.42, 0.9), Vector3(-0.17, 1.03, 0.44), hold_a),
		]}
	# a fish on: its time is the lift. Lowered toward the fish (giving it the rod's length), up to the chest, then
	# heaved up and back past the upright over the right shoulder (user: "i like it"), the body leaning back
	out["rod_fight"] = {"desc": "a fish on: the rod from lowered toward it (0) to heaved up and back (1)", "length": 1.0,
		"hold": "blade", "carry": "pipe", "space": "body", "authored": "keyed by hand (tools/anim_author/author_fishing.gd)",
		"keys": [
			_key(0.0, Vector3(0.06, 0.2, 0.98), Vector3(-0.18, 1.0, 0.46),
					{"yaw": -8.0, "pitch": 14.0, "head_pitch": 4.0, "head_yaw": 6.0}),
			_key(0.5, Vector3(0.0, 0.8, 0.6), Vector3(-0.15, 1.2, 0.36),
					{"yaw": -6.0, "pitch": 2.0, "head_pitch": 2.0, "head_yaw": 4.0}, "linear"),
			_key(1.0, Vector3(-0.14, 0.95, -0.3), Vector3(-0.19, 1.36, 0.2),
					{"yaw": -4.0, "pitch": -14.0, "head_pitch": 14.0, "head_yaw": 2.0, "er": Vector3(-0.8, -0.6, -0.1)},
					"linear"),
		]}
	return out


# --- preview -------------------------------------------------------------------------------------------------------

func _preview(clips: Dictionary) -> void:
	var out := str(args.get("out", "user://author_fishing"))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.56, 0.45)
	floor.material_override = fm
	world.add_child(floor)
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0] if not aps.is_empty() else null, "res://assets/character/actor_b_body.glb")
	var rod := FishModels.build("fishing_rod")
	world.add_child(rod)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, CELL)
	var cam: Camera3D = view.camera
	cam.fov = 50.0
	await process_frame
	await process_frame
	var solver = Solver.new(sk)
	for name: String in clips:
		var clip: Dictionary = clips[name]
		solver.hold = str(clip.hold)
		solver.carry = str(clip.get("carry", ""))
		solver.space = str(clip.get("space", "body"))
		var moments := [0.0, 0.25, 0.5, 0.75, 1.0] if name == "rod_fight" else [0.0]
		var views := {"side": [Vector3(-4.6, 1.5, 1.4), Vector3(0, 1.6, 1.4)],
				"front": [Vector3(-1.6, 1.4, 3.0), Vector3(0, 1.3, 0.4)],
				"back": [Vector3(1.2, 1.9, -2.4), Vector3(0, 1.4, 1.5)]}
		var grid := Image.create(CELL.x * views.size(), CELL.y * moments.size(), false, Image.FORMAT_RGB8)
		for i in moments.size():
			var t: float = moments[i]
			solver.pose(Swings.pose_at(clip, t))
			sk.force_update_all_bone_transforms()
			var prop := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_hand_prop_attachment"))
			rod.global_transform = prop * Solver.PIPE * ROD_IN_HANDS
			var j := 0
			for v: String in views:
				cam.global_position = views[v][0]
				cam.look_at(views[v][1])
				for f in 3:
					await process_frame
				var img: Image = view.get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				grid.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(j * CELL.x, i * CELL.y))
				j += 1
		grid.save_png(out.path_join(name + ".png"))
		print("  ", name, " -> ", out.path_join(name + ".png"))
	print("FISHING PREVIEW DONE")
