class_name FortPlan
extends Node
## The fort's furnishing from the build menu's own pieces (user 2026-09-28: "we want the fort to be maxed out so we can
## give the wife a lot of things to do"): when a new game starts, data/building/fort_plan.json's pieces are built in the
## fort by the same rules as the player's (BuildSnap.check settles each on the ground and refuses one that something is
## in the way of; it is then tried a little to each side), free of cost. They are ordinary pieces afterwards: they can be
## used (a chest keeps what is put in it, the fires burn, the racks and benches work), taken down, and they are saved
## with the rest of the building (BuildWorld.stamped says the plan has been built, so a loaded game is not given it
## twice). Off in -s tool and test runs unless they pass fort_plan=on.
##
## The fort itself is built from pieces too (user 2026-09-28: "the fort should be recreated from builder pieces, not
## hardcoded"): data/building/fort_structure.json lists the palisade sections (and runs of them), the gate, the firing step,
## the ramps, the ladders, the blockhouses and the flag pole. They are stamped when the level is built (free of cost, as
## ordinary pieces: the player can take them down, cut windows in the palisade, PalisadeCuts) EXACTLY where planned, with
## no checking and no jitter (a wall must not move a hand's width): the ground is read from the terrain's height, each
## piece sits on the highest ground under its footprint, a palisade's stakes follow the ground under each of them.
## BuildWorld.fort_built says the structure has been built (saved; SaveParts.load_building builds it for a save from
## before it existed). On in tool and test runs too, off with fort_plan=off or fort_structure=off.
##   FortPlan.install(level)

const PATH := "res://data/building/fort_plan.json"
const STRUCTURE_PATH := "res://data/building/fort_structure.json"
## Tries for a piece: its place, then rings of this many metres round it.
const OFFSETS := [Vector2.ZERO, Vector2(0.4, 0), Vector2(-0.4, 0), Vector2(0, 0.4), Vector2(0, -0.4), Vector2(0.8, 0), Vector2(-0.8, 0),
		Vector2(0, 0.8), Vector2(0, -0.8), Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]

var placed := 0
var skipped: Array = []


static func enabled() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("fort_plan="):
			var v := s.get_slice("=", 1)
			return v != "off" and v != "0"
	var args := OS.get_cmdline_args()
	return not ("-s" in args or "--script" in args)


## The fort's structure is built unless a tool run says fort_plan=off or fort_structure=off.
static func structure_enabled() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s == "fort_plan=off" or s == "fort_plan=0" or s == "fort_structure=off" or s == "fort_structure=0":
			return false
	return true


static func install(level: Node) -> FortPlan:
	if structure_enabled():
		var world := BuildWorld.of(level.get_tree())
		if world == null:
			world = BuildWorld.new()
			world.name = BuildWorld.NODE_NAME
			level.add_child(world)
		if not world.fort_built:
			stamp_structure(world)
	if not enabled():
		return null
	var f := FortPlan.new()
	f.name = "FortPlan"
	level.add_child(f)
	return f


func _ready() -> void:
	_stamp.call_deferred()


func _stamp() -> void:
	# the level's colliders are in the physics space a couple of steps after it is built
	for i in 3:
		await get_tree().physics_frame
	var world := BuildWorld.of(get_tree())
	if world == null:
		return
	# a save applied to this level says whether its building already has the plan
	for i in SaveGame.APPLY_AFTER_FRAMES + 4:
		await get_tree().physics_frame
	if world.stamped:
		queue_free()
		return
	build(world, get_viewport().get_camera_3d() != null)
	queue_free()


## Builds the plan into `world`; returns how many pieces went in (the ones left out are in `skipped`).
func build(world: BuildWorld, _rendering := true) -> int:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		return 0
	var data := BuildData.get_default()
	var space := world.get_world_3d().direct_space_state
	var have := {}
	for k in ["log", "stone", "pole", "branches", "firewood", "clay", "rawhide", "deer_hide"]:
		have[k] = 9999
	for e: Dictionary in (d as Dictionary).get("pieces", []):
		var type := String(e.type)
		if not data.has(type):
			skipped.append(type)
			continue
		var yaw := deg_to_rad(float(e.get("yaw", 0.0)))
		var ok := false
		for off: Vector2 in OFFSETS:
			var x := float(e.x) + off.x
			var z := float(e.z) + off.y
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, FrontierTerrain.height_at(x, z), z))
			var v := BuildSnap.check(type, {"xf": xf, "kind": "", "grounded": true}, world, space, have, data)
			if bool(v.ok):
				world.add_piece(type, v.xf, bool(v.grounded), -1, v.ground)
				placed += 1
				ok = true
				break
		if not ok:
			skipped.append("%s@%s,%s" % [type, e.x, e.z])
	world.stamped = true
	print("FortPlan: %d pieces built%s" % [placed, ("; left out: %s" % ", ".join(skipped)) if not skipped.is_empty() else ""])
	return placed


# --- The fort's structure -------------------------------------------------------------------------------------

## Builds the fort's structure (STRUCTURE_PATH) into `world` exactly where it is planned; returns how many pieces went in.
## Each entry: {type, x, z, yaw (degrees; a piece is worked from its +Z side), count, dx, dz (a run of `count` pieces, each
## step (dx, dz) further), open (a gate's door stands open)}.
static func stamp_structure(world: BuildWorld) -> int:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRUCTURE_PATH))
	if not d is Dictionary:
		push_warning("FortPlan: %s did not load" % STRUCTURE_PATH)
		return 0
	var data := BuildData.get_default()
	var n := 0
	for e: Dictionary in (d as Dictionary).get("pieces", []):
		var type := String(e.type)
		if not data.has(type):
			push_warning("FortPlan: no piece %s" % type)
			continue
		var yaw := deg_to_rad(float(e.get("yaw", 0.0)))
		for i in int(e.get("count", 1)):
			var x := float(e.x) + float(e.get("dx", 0.0)) * i
			var z := float(e.z) + float(e.get("dz", 0.0)) * i
			var xf := settle(type, Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z)))
			var p := world.add_piece(type, xf, true, -1, stake_ground(type, xf))
			if bool(e.get("open", false)) and p.door:
				p.door.set_open(true, true)
			n += 1
	world.fort_built = true
	return n


## `xf` (its x, z and turn) with the height it stands at on the terrain: a palisade at the ground under its middle, the other
## pieces at the highest ground under their footprints (the middle and the corners, BuildSnap._ground's rule).
static func settle(type: String, xf: Transform3D) -> Transform3D:
	var o := xf.origin
	if type in ["palisade", "palisade_gate"]:
		o.y = FrontierTerrain.height_at(o.x, o.z)
		return Transform3D(xf.basis, o)
	var f: Array = BuildSnap.FOOT[type] if BuildSnap.FOOT.has(type) else FortPieces.foot(type)
	var e: Vector2 = f[0]
	var hi := -INF
	for p: Vector3 in [Vector3.ZERO, Vector3(-e.x, 0, -e.y), Vector3(e.x, 0, -e.y), Vector3(-e.x, 0, e.y), Vector3(e.x, 0, e.y)]:
		var w := xf * p
		hi = maxf(hi, FrontierTerrain.height_at(w.x, w.z))
	o.y = hi
	return Transform3D(xf.basis, o)


## A palisade's (or gate's) ground heights over its origin under each stake (post): what BuildSnap.check gives a placed one.
static func stake_ground(type: String, xf: Transform3D) -> PackedFloat32Array:
	var rel := PackedFloat32Array()
	if type not in ["palisade", "palisade_gate"]:
		return rel
	var pts: Array = []
	if type == "palisade":
		var dx := BuildGeometry.L / BuildGeometry.STAKES
		for i in BuildGeometry.STAKES:
			pts.append(Vector3(-BuildGeometry.L * 0.5 + dx * (i + 0.5), 0, 0))
	else:
		pts = [Vector3(-BuildGeometry.GATE_POST_X, 0, 0), Vector3(BuildGeometry.GATE_POST_X, 0, 0), Vector3.ZERO]
	for p: Vector3 in pts:
		var w := xf * p
		rel.append(snappedf(FrontierTerrain.height_at(w.x, w.z) - xf.origin.y, 0.01))
	return rel
