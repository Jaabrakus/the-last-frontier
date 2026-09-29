class_name BuiltPiece
extends Node3D
## One placed piece of building (scripts/building/): its mesh, its colliders (one StaticBody3D in BODY_GROUP;
## a door's or gate's leaves are their own bodies, BuildDoor), its sockets and inner boxes (BuildSnap), what it
## rests on (`supports`: taking that piece down needs this one gone first) and the context its look depends on
## (BuildWorld.ctx_for: notched corners, shared floor edges, roof ends), re-dressed when a neighbour comes or
## goes. Made by BuildWorld.add_piece().
## With Take down chosen in build mode, the piece under the crosshair is an E interactable of PlayerInteractor
## (group PlacedWeapon.GROUP, the "any other interactable" contract, like GatherTarget): its prompt says what E
## does ("E  Take down the notched log wall  (+3 logs)"), it glows, and a tap of E takes it down. Every other
## piece (and every piece outside Take down) has no prompt, so the interactor passes it by.

const GROUP := &"built_pieces"
const BODY_GROUP := &"built_piece_bodies"

var piece_id := 0
var type := ""
## Visual variation (0..2).
var variant := 0
## Stands on the ground (a wall's stone footing, a post set in the ground), not on a floor or a wall.
var grounded := true
## Ids of the pieces this one rests on.
var supports: Array[int] = []
## A palisade's or gate's ground heights over its origin, under each stake / post (BuildSnap.check).
var ground := PackedFloat32Array()
var ctx := {}
## A palisade's cut openings [[k (pair of stakes 0..3), h0, h1 (over the section's origin), covered 0 / 1]] (PalisadeCuts).
var cuts: Array = []
var door: BuildDoor
var body: StaticBody3D
var _visuals: Array[GeometryInstance3D] = []
var _detail := true


## The reach the interactor allows (build mode's reach).
var interact_reach := 9.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)


## (Re)builds the mesh and the colliders for `new_ctx`.
func dress(new_ctx: Dictionary, detail := true) -> void:
	ctx = new_ctx
	_detail = detail
	for v in _visuals:
		if is_instance_valid(v):
			v.queue_free()
	_visuals = build_visuals(self, type, variant, ctx, ground, detail, true, cuts)
	if body:
		remove_child(body)
		body.queue_free()
	body = StaticBody3D.new()
	body.name = "Body"
	body.add_to_group(BODY_GROUP)
	body.set_meta(&"built_piece_id", piece_id)
	var shapes: Array = PalisadeCuts.colliders(ctx, cuts) if type == "palisade" and not cuts.is_empty() else BuildGeometry.colliders(type, ctx)
	for c: Array in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = c[0]
		cs.transform = c[1]
		var meta: Dictionary = c[2]
		for k: String in meta:
			if k == "surface":
				body.set_meta(&"surface", meta[k])
			else:
				cs.set_meta(StringName(k), (meta[k] as Dictionary).duplicate() if meta[k] is Dictionary else meta[k])
		body.add_child(cs)
	add_child(body)
	if door == null and type in ["wall_door", "palisade_gate"]:
		door = BuildDoor.make(type)
		add_child(door)
	if type == "blockhouse" and door == null:
		# the lower storey is hollow: a hung door in its doorway (E opens it) and a dim light inside
		door = FortHollow.hang_door(self, FortPieces.HOLLOW)
		if DisplayServer.get_name() != "headless":
			FortHollow.light(self, FortPieces.HOLLOW)
	if type == "campfire" and get_node_or_null("Campfire") == null:
		var cf := Campfire.new()
		cf.name = "Campfire"
		add_child(cf)
	if type == "hearth" and get_node_or_null("Campfire") == null:
		# a fire in the hearth's mouth, its smoke out of the top of the stack
		var hf := Campfire.new()
		hf.name = "Campfire"
		hf.hearth = true
		hf.position = BuildGeometry.HEARTH_FIRE
		hf.smoke_at = BuildGeometry.HEARTH_SMOKE - BuildGeometry.HEARTH_FIRE
		add_child(hf)
	if type == "ladder" and get_node_or_null("Ladder") == null:
		# a climbable ladder (the fort's: a TravLadder marker over the rails)
		var m := TravLadder.new()
		m.name = "Ladder"
		m.debug_draw = false
		m.bottom = Vector3.ZERO
		m.top = Vector3(0.0, FortPieces.WALK_TOP, 0.0)
		m.outward = Vector3(0, 0, 1)
		m.width = FortPieces.LADDER_HALF_W * 2.0
		m.rung_pitch = TravLaneClimb.PITCH
		m.rung_offset = TravLaneClimb.first_rung_top()
		m.rung_radius = TravLaneClimb.RUNG_R
		add_child(m)
	if type == "lean_to":
		add_to_group(&"shelters")
	if type in ["musket_rack", "spear_barrel"] and get_node_or_null("Rack") == null:
		# the Furniture group's racks: a WeaponRack with the piece's own model
		var r := WeaponRack.new()
		r.name = "Rack"
		r.bare = true
		r.style = "rack" if type == "musket_rack" else "barrel"
		r.slots = BuildGeometry.RACK_SLOTS if type == "musket_rack" else BuildGeometry.BARREL_SLOTS
		add_child(r)
	if type == "woodpile" and get_node_or_null("Woodpile") == null:
		var wp := Woodpile.new()
		wp.name = "Woodpile"
		add_child(wp)
	if type == "smokehouse" and get_node_or_null("Smokehouse") == null:
		var sm := Smokehouse.new()
		sm.name = "Smokehouse"
		add_child(sm)
	if type == "cradle" and get_node_or_null("Cradle") == null:
		# the baby's cradle (BabyLink lays the baby in it)
		var cr := Cradle.new()
		cr.name = "Cradle"
		add_child(cr)
	if type == "storage_chest" and get_node_or_null("Chest") == null:
		var ch := StorageChest.new()
		ch.name = "Chest"
		add_child(ch)
	if type in TrapStation.KINDS and get_node_or_null("Trap") == null:
		# the trap line's traps: set, checked, the catch taken (the survival rules' trap line)
		var ts := TrapStation.new()
		ts.name = "Trap"
		ts.kind = type
		add_child(ts)
	if type in CampStation.KINDS and get_node_or_null("Station") == null:
		# beds and crafting stations: what they do and what lies on them
		var st := CampStation.new()
		st.name = "Station"
		st.kind = type
		add_child(st)


## The look of a piece under `parent`: its mesh, a palisade's stakes (MultiMeshes), for a ghost (`solid` off)
## also a door's or gate's leaves where they hang shut. Returns the GeometryInstance3Ds made.
static func build_visuals(parent: Node3D, p_type: String, p_variant: int, p_ctx: Dictionary, p_ground: PackedFloat32Array,
		detail: bool, solid: bool, p_cuts: Array = []) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = BuildGeometry.mesh(p_type, p_variant, p_ctx, detail, solid or p_type != "palisade")
	parent.add_child(mi)
	out.append(mi)
	if p_type in ["work_stone", "charcoal_mound", "forge", "flagpole"]:
		# the parts not drawn with the kit: the knapping stone's boulder, the mound's earth dome, the forge's bellows
		for part: Array in BuildGeometry.piece_parts(p_type):
			var pm := MeshInstance3D.new()
			pm.name = "Part%d" % out.size()
			pm.mesh = part[0]
			pm.transform = part[1]
			if part[2] != null:
				pm.material_override = part[2]
			parent.add_child(pm)
			out.append(pm)
	if p_type == "palisade":
		var per: Array = [[], [], []]
		var stakes := BuildGeometry.stake_transforms(p_ground, p_variant)
		for i in stakes.size():
			var s: Array = stakes[i]
			var gone := PalisadeCuts.removed(p_cuts, PalisadeCuts.pair_of(i)) if not p_cuts.is_empty() else []
			if gone.is_empty():
				(per[int(s[0])] as Array).append(s)
			else:
				# a stake with a hole in it: the pieces of it over and under the hole
				out.append_array(PalisadeCuts.stake_pieces(parent, s, gone))
		for v in 3:
			var list: Array = per[v]
			if list.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = BuildGeometry.stake_mesh(v)
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i][1])
				mm.set_instance_custom_data(i, list[i][2])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Stakes%d" % v
			mmi.multimesh = mm
			parent.add_child(mmi)
			out.append(mmi)
		if not p_cuts.is_empty():
			out.append_array(PalisadeCuts.cover_meshes(parent, p_cuts, p_variant))
	if not solid and p_type in ["wall_door", "palisade_gate"]:
		for lf: Array in BuildDoor.ghost_leaves(p_type):
			var lm := MeshInstance3D.new()
			lm.mesh = lf[0]
			lm.transform = lf[1]
			parent.add_child(lm)
			out.append(lm)
	return out


## Sets the palisade's cut openings (PalisadeCuts) and dresses it again: stakes with holes, the collider round them.
func set_cuts(new_cuts: Array) -> void:
	cuts = new_cuts
	dress(ctx, _detail)
	var w := get_parent() as BuildWorld
	if w:
		w.grass.mark()
		w.changed.emit()


## Its sockets in world space: [[kind, Transform3D]].
func sockets() -> Array:
	var out: Array = []
	var xf := global_transform
	for s: Array in BuildSnap.sockets_local(type):
		out.append([s[0], xf * (s[1] as Transform3D)])
	return out


## Its inner boxes in world space: [[Transform3D, half extents]].
func inner_boxes() -> Array:
	var out: Array = []
	var xf := global_transform
	for b: Array in BuildSnap.inner_local(type):
		out.append([xf * (b[0] as Transform3D), b[1]])
	return out


func body_rids() -> Array[RID]:
	var out: Array[RID] = []
	if body:
		out.append(body.get_rid())
	if door:
		out.append_array(door.body_rids())
	return out


## What glows when it is the target of Take down.
func highlight_targets() -> Array:
	var out: Array = []
	for v in _visuals:
		if is_instance_valid(v):
			out.append(v)
	if door:
		out.append_array(door.highlight_targets())
	return out


# --- Take down (interactable) -------------------------------------------------------------------------------

func _taker() -> BuildMode:
	var m := BuildMode.current
	return m if m and is_instance_valid(m) and m.aimed_piece == self else null


func interact_point() -> Vector3:
	var m := _taker()
	return m.aim_point() if m else global_position


func distance_from(p: Vector3) -> float:
	var m := _taker()
	if m == null:
		return INF
	var q := m.aim_point()
	return Vector2(q.x - p.x, q.z - p.z).length()


func interact_prompt(_player: Node) -> String:
	var m := _taker()
	return m.take_down_prompt() if m else ""


func interact(_player: Node) -> void:
	var m := _taker()
	if m:
		m.take_down(self)
