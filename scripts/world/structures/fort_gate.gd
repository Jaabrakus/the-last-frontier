class_name FortGate
extends Node3D
## The fort's gate leaves (user 2026-09-26: "i also want to be able to gate to be chopable where we can use the axe so
## it allows us to create a window to shoot weapons"; asked where, "Both": windows in the palisade and gate doors). Two
## plank leaves hang on the iron pintles of the gate posts (FrontierStructures._gate) and swing into the fort: E at the
## gate opens or closes them (they stand open at the start, the gate as it was). With a tool in the hand the gate is
## no E target; each leaf is a WallCuts wall: pieces chopped out of it where the axe aims (WallCuts.CUT_LOGS planks)
## split its planks and its collider around the openings, which swing with the leaf.

const GROUP := &"fort_gates"
const HINGE_X := 2.85               ## the pintles' x (FrontierStructures: GATE_HALF + 0.1 - 0.25)
const LEAF_W := 2.85                ## each leaf from its hinge to the middle
const LEAF_H := 4.6                 ## up to under the lintel (its foot at 4.8 m)
const LEAF_T := 0.12
const LEAF_Y0 := 0.04               ## the leaves clear the ground by this much
const PLANK_N := 10                 ## vertical planks per leaf
const BATTENS := [0.55, 2.3, 4.1]   ## the inner face's horizontal battens over the leaf's foot
const SWING_S := 1.6
const REACH := 2.0                  ## from the gateway's line (the ladders stand 2.25 m from its end)

var hinge_z := -15.88
var visuals := true
var materials := {}
var open := true
var _u := 1.0                       ## 0 closed .. 1 open
## {side, body: AnimatableBody3D, mesh: MeshInstance3D, wall: int (WallCuts), holes: [[u0, u1, h0, h1]]}
var leaves: Array = []
var interact_reach := REACH


static func find(tree: SceneTree) -> FortGate:
	return tree.get_first_node_in_group(GROUP) as FortGate if tree else null


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)


## Builds the two leaves (hinged at +-HINGE_X on hinge_z) and registers them with `cuts`. Each leaf's body is moved
## by its transform every tick it swings (an AnimatableBody3D synced to physics: a body under a turning parent kept
## its physics shape where it was built).
func build(cuts: WallCuts, meta: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var body := AnimatableBody3D.new()
		body.name = "Leaf" + ("E" if s > 0.0 else "W")
		body.sync_to_physics = true
		add_child(body)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(LEAF_W, LEAF_H, LEAF_T)
		cs.shape = bx
		cs.set_meta(&"trav", meta.duplicate())
		body.add_child(cs)
		var lf := {"side": s, "body": body, "mesh": null, "wall": -1, "holes": []}
		if visuals:
			var mi := MeshInstance3D.new()
			mi.name = "LeafMesh"
			body.add_child(mi)
			lf.mesh = mi
		leaves.append(lf)
		if cuts:
			# the wall's line along the leaf's foot (body frame, X across the leaf), its planks' centres along it
			var units := []
			var pw := LEAF_W / PLANK_N
			for k in PLANK_N:
				units.append(pw * (k + 0.5))
			var li := leaves.size() - 1
			lf.wall = cuts.register_local(body, Vector3(-LEAF_W * 0.5, -LEAF_H * 0.5, 0.0), Vector3(1, 0, 0), LEAF_W, LEAF_H,
					LEAF_T, units, pw, func(holes: Array) -> void: _on_cut(li, holes), "gate")
		_rebuild_mesh(leaves.size() - 1)
	_apply()


## A leaf's transform at swing angle `ang` (radians about its hinge; 0 closed).
func _leaf_xf(side: float, ang: float) -> Transform3D:
	var hinge := Transform3D(Basis(Vector3.UP, ang), Vector3(side * HINGE_X, 0.0, hinge_z))
	return hinge * Transform3D(Basis(), Vector3(-side * LEAF_W * 0.5, LEAF_Y0 + LEAF_H * 0.5, 0.0))


func _on_cut(li: int, holes: Array) -> void:
	leaves[li].holes = holes.duplicate(true)
	_rebuild_mesh(li)


func _rebuild_mesh(li: int) -> void:
	var lf: Dictionary = leaves[li]
	var mi: MeshInstance3D = lf.mesh
	if mi == null or materials.is_empty():
		return
	var kit := StructureMeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + li
	var pw := LEAF_W / PLANK_N
	var x0 := -LEAF_W * 0.5
	var y0 := -LEAF_H * 0.5
	for k in PLANK_N:
		var u0 := pw * k
		var u1 := pw * (k + 1)
		# vertical spans of this plank left by the windows through it (body frame: from the leaf's foot)
		var spans := [[0.0, LEAF_H]]
		for hl: Array in lf.holes:
			if float(hl[1]) <= u0 + 0.01 or float(hl[0]) >= u1 - 0.01:
				continue
			var nxt := []
			for sp: Array in spans:
				if float(hl[3]) <= float(sp[0]) or float(hl[2]) >= float(sp[1]):
					nxt.append(sp)
					continue
				if float(hl[2]) > float(sp[0]):
					nxt.append([float(sp[0]), float(hl[2])])
				if float(hl[3]) < float(sp[1]):
					nxt.append([float(hl[3]), float(sp[1])])
			spans = nxt
		var row := rng.randi_range(0, 3)
		var ph := rng.randf()
		var tint := rng.randf_range(0.86, 1.02)
		for sp: Array in spans:
			var h := float(sp[1]) - float(sp[0])
			if h < 0.02:
				continue
			kit.box(&"boards", Transform3D(Basis(), Vector3(x0 + 0.5 * (u0 + u1), y0 + 0.5 * (float(sp[0]) + float(sp[1])), 0.0)),
					Vector3(pw - 0.008, h, LEAF_T), StructureMeshKit.GRAIN_Y, row, ph, Color(tint, tint, tint * 0.98, 1.0),
					StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.8)
	# battens and strap hinges on the inner face (+Z of the body, the fort's side when closed)
	for by: float in BATTENS:
		kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, y0 + by, LEAF_T * 0.5 + 0.04)), Vector3(LEAF_W - 0.1, 0.18, 0.08),
				StructureMeshKit.GRAIN_X, rng.randi_range(0, 3), rng.randf(), Color(0.85, 0.83, 0.8, 1.0))
		var hx := x0 + 0.35 if float(lf.side) < 0.0 else -x0 - 0.35
		kit.box(&"boards", Transform3D(Basis(), Vector3(hx, y0 + by, LEAF_T * 0.5 + 0.085)), Vector3(0.7, 0.06, 0.01),
				StructureMeshKit.GRAIN_X, 0, 0.0, Color.WHITE, StructureMeshKit.KIND_IRON)
	mi.mesh = kit.commit(materials)


func _physics_process(delta: float) -> void:
	var want := 1.0 if open else 0.0
	if not is_equal_approx(_u, want):
		_u = move_toward(_u, want, delta / SWING_S)
		_apply()


func _apply() -> void:
	var e := smoothstep(0.0, 1.0, _u)
	for lf: Dictionary in leaves:
		(lf.body as Node3D).transform = _leaf_xf(float(lf.side), float(lf.side) * deg_to_rad(90.0) * e)


func set_open(on: bool, now := false) -> void:
	open = on
	if now:
		_u = 1.0 if on else 0.0
		_apply()


func is_closed() -> bool:
	return not open and _u <= 0.001


# --- PlayerInteractor's "any other interactable" contract --------------------------------------------------

func interact_point() -> Vector3:
	return Vector3(0.0, 1.5, hinge_z)


func distance_from(p: Vector3) -> float:
	# (to the gate's line between the hinges)
	var x := clampf(p.x, -HINGE_X, HINGE_X)
	return Vector2(p.x - x, p.z - hinge_z).length()


func interact_prompt(player: Node) -> String:
	var g: Variant = player.get("gather")
	if g != null and (g as GatherTools).in_hand() != "":
		return ""
	# (not from a ladder or a climb: E there is no gate)
	var tr: Variant = player.get("traversal")
	if tr != null and (tr as PlayerTraversal).controller != null and (tr as PlayerTraversal).controller.mode != TraversalController.Mode.OFF:
		return ""
	return "Open the gate" if not open else "Close the gate"


func interact(_player: Node) -> void:
	open = not open


func highlight_targets() -> Array:
	return []
