class_name MammothButchery
extends Node
## Butchering the mammoth's carcass piece by piece (user 2026-09-27: "for the mammoth we have to chop it in pieces when
## we skin it and butcher it so the user has to look at the location of what they want to chop off"). Each part is an
## interactable of its own where it lies on the carcass, on the body it belongs to (the head's, a leg's, the torso's), so
## PlayerInteractor's look to pick takes the one the crosshair is on (of the parts on one body, the one nearest where it
## lands; the tusks and the trunk, which the living body has no collision for, get a body each along their length once
## the carcass lies still): the player looks at the tusk, the trunk, a leg or the flank and presses E:
##   tusks     the felling axe: ivory; the tusk is gone from the carcass
##   trunk     the felling axe: it drops, a carcass of its own (LimbCarcass: meat)
##   legs      the felling axe: each drops, a carcass of its own (LimbCarcass: meat and sinew; user 2026-09-27:
##             "chopped up limbs count as a carcass right like a smaller animal carcass"): hauled or butchered where it
##             lies, with the axe
##   hide      the knife, the flank it lies with up only: the mammoth hide; the flank shows raw red
##   meat      the felling axe, from a skinned flank, MEAT_CUTS times: meat; cut clean, the flank shows bone
## The axe's parts are chopped as a tree is felled (user 2026-09-27: "use the axe to butcher"): GatherTools takes them
## for targets (group "axe_work": axe_candidates, axe_describe, axe_strike, axe_prompt): E draws the axe and swings,
## LMB held keeps swinging, each stroke a crunch and blood (MeleeSweep.crunch), `strokes` of them (the woodcutting
## skill's power) and the part comes off. The hide is the knife's, FieldDressing's way: the player kneels at the flank
## (FrontierPlayer.begin_kneel; the same search-low clips) while a bar fills; moving, jumping, crouching, aiming, firing,
## drawing a weapon or E again stops it, a hit at once. Each part keeps its progress. The meat is the game's raw meat (venison: it cooks, smokes into jerky and feeds as
## any); ivory and the mammoth hide are pack items of their own.
## The scavengers' too (user 2026-09-27: "it should go for left animals"): a Carcass node on its middle (the group
## "carcasses": WildlifeSpawner) whose meat is the butchery's pools, in deer (MEAT_POOL: each flank, each leg, the
## trunk). Wolves, foxes and ravens eat the flank that lies up first, then the legs and the trunk still on it, the
## flank it lies on last; what they ate is gone from the player's cuts (fewer; a flank eaten away shows its bones, and a
## limb chopped off takes what is left on it to its LimbCarcass). Picked clean, and nothing touched for BONES_S, or
## left alone 10 minutes (WildlifeSpawner.UNTOUCHED_S), the whole mammoth is gone.
## Not kept in the save (the climbing yard builds its mammoth anew).

signal finished(part: String)

const KNIFE := "skinning_knife"
const AXE := "felling_axe"
const LIB := "actor_b"
const CLIP_IN := "actor_b-cap-ambi-search-low-in-place-entry"
const CLIP_LOOP := "actor_b-cap-ambi-search-low-in-place"
const CLIP_OUT := "actor_b-cap-ambi-search-low-in-place-exit"
const OUT_S := 1.5
const CANCEL_ACTIONS := ["jump", "crouch", "aim", "fire", "reload", "sprint"]
const MEAT_CUTS := 4
## The meat on it, in deer (WildAnimal.meat_left: 1 a whole deer): a flank (a cut takes 1), a leg, the trunk
## (LimbCarcass.MEAT).
const FLANK_MEAT := 4.0
## What drops for a leg and for the trunk (LimbCarcass): its kind (haul.json's carcass kg), its name, its thickness (m),
## what it yields when it is butchered and the axe strokes that takes.
const LEG_PIECE := {"kind": "mammoth_leg", "name": "mammoth leg", "r": 0.42, "give": {"venison": 5, "sinew": 2}, "strokes": 6.0}
const TRUNK_PIECE := {"kind": "mammoth_trunk", "name": "mammoth trunk", "r": 0.26, "give": {"venison": 3}, "strokes": 4.0,
		"bones": ["Bone", "Bone.001", "Bone.002"]}
## The parts: what it is called, the tool, the verb, the seconds, what it yields, and where it is on the carcass: a
## surface of the model (its middle, carried by `bone`; `r` its size; `line`: its length instead, root to tip) or a
## segment between two bones; `leg` the leg's
## index (StandInGiant.LEG_NAMES), `cut` the bone that goes with it, `side` the flank (only the one lying up can be
## worked), `after` the part that must be taken first.
const PARTS := {
	"tusk_l": {"name": "left tusk", "tool": AXE, "verb": "Chop off", "strokes": 6.0, "yield": {"ivory": 1},
			"surface": "Tusk_L", "bone": "spine.011", "line": true},
	"tusk_r": {"name": "right tusk", "tool": AXE, "verb": "Chop off", "strokes": 6.0, "yield": {"ivory": 1},
			"surface": "Tusk_R", "bone": "spine.011", "line": true},
	"trunk": {"name": "trunk", "tool": AXE, "verb": "Chop off", "strokes": 5.0, "yield": {},
			"seg": ["Bone", "Bone.002"], "cut": "Bone", "drops": TRUNK_PIECE},
	"foreleg_l": {"name": "left foreleg", "tool": AXE, "verb": "Chop off", "strokes": 8.0, "yield": {},
			"seg": ["front_thigh.L", "front_toe.L"], "cut": "front_thigh.L", "leg": 0, "drops": LEG_PIECE,
			"bones": ["front_thigh.L", "front_shin.L", "front_foot.L", "front_toe.L"]},
	"foreleg_r": {"name": "right foreleg", "tool": AXE, "verb": "Chop off", "strokes": 8.0, "yield": {},
			"seg": ["front_thigh.R", "front_toe.R"], "cut": "front_thigh.R", "leg": 1, "drops": LEG_PIECE,
			"bones": ["front_thigh.R", "front_shin.R", "front_foot.R", "front_toe.R"]},
	"hindleg_l": {"name": "left hind leg", "tool": AXE, "verb": "Chop off", "strokes": 8.0, "yield": {},
			"seg": ["thigh.L", "toe.L"], "cut": "thigh.L", "leg": 2, "drops": LEG_PIECE,
			"bones": ["thigh.L", "shin.L", "foot.L", "toe.L"]},
	"hindleg_r": {"name": "right hind leg", "tool": AXE, "verb": "Chop off", "strokes": 8.0, "yield": {},
			"seg": ["thigh.R", "toe.R"], "cut": "thigh.R", "leg": 3, "drops": LEG_PIECE,
			"bones": ["thigh.R", "shin.R", "foot.R", "toe.R"]},
	"hide_l": {"name": "hide off its left flank", "tool": KNIFE, "verb": "Skin", "s": 10.0, "yield": {"mammoth_hide": 1},
			"surface": "Hide_L", "bone": "spine.007", "r": 1.6, "side": "L"},
	"hide_r": {"name": "hide off its right flank", "tool": KNIFE, "verb": "Skin", "s": 10.0, "yield": {"mammoth_hide": 1},
			"surface": "Hide_R", "bone": "spine.007", "r": 1.6, "side": "R"},
	"meat_l": {"name": "meat from its left flank", "tool": AXE, "verb": "Cut", "strokes": 3.0, "yield": {"venison": 4},
			"surface": "Hide_L", "bone": "spine.007", "r": 1.6, "side": "L", "after": "hide_l", "times": MEAT_CUTS},
	"meat_r": {"name": "meat from its right flank", "tool": AXE, "verb": "Cut", "strokes": 3.0, "yield": {"venison": 4},
			"surface": "Hide_R", "bone": "spine.007", "r": 1.6, "side": "R", "after": "hide_r", "times": MEAT_CUTS},
}

var giant: StandInGiant
var player: FrontierPlayer
## Each part's state: {progress 0..1, done, left (cuts)}; the part nodes.
var state := {}
var parts := {}
## How fast the work goes (tests).
var speed := 1.0
var working := ""
## The pieces that have dropped (LimbCarcass), part -> piece.
var dropped := {}
## The meat left on it, in deer: part -> amount (the flanks meat_l / meat_r, the legs, the trunk); the scavengers'
## carcass node.
var pool := {}
var carcass: Carcass
var _blender: HorsePhaseBlender
var _ap: AnimationPlayer
var _phase := 0
var _t := 0.0
var _centres := {}                ## a surface's middle at rest (skeleton space)
var _layer: CanvasLayer
var _label: Label
var _bar: ProgressBar
var _settled := false
var _piece_bodies := {}           ## part -> StaticBody3D along it (the tusks, the trunk)
var _meat_mat: StandardMaterial3D
var _bone_mat: StandardMaterial3D
var _gone_mat: StandardMaterial3D


func _ready() -> void:
	player = giant.player
	add_to_group(&"axe_work")
	pool = {"meat_l": FLANK_MEAT, "meat_r": FLANK_MEAT}
	for id: String in PARTS:
		if PARTS[id].has("drops"):
			pool[id] = float(LimbCarcass.MEAT.get(String((PARTS[id].drops as Dictionary).kind), 1.0))
	carcass = Carcass.new()
	carcass.name = "Carcass"
	carcass.butchery = self
	add_child(carcass)
	for id: String in PARTS:
		state[id] = {"progress": 0.0, "done": false, "left": int(PARTS[id].get("times", 1))}
		if String(PARTS[id].tool) == AXE:
			continue                       # (GatherTools offers the axe's parts: axe_candidates)
		var p := Part.new()
		p.name = "Part_" + id
		p.id = id
		p.butchery = self
		_body_of(id).add_child(p)
		parts[id] = p
	_meat_mat = StandardMaterial3D.new()
	_meat_mat.albedo_color = Color(0.46, 0.08, 0.07)
	_meat_mat.roughness = 0.45
	_bone_mat = StandardMaterial3D.new()
	_bone_mat.albedo_color = Color(0.78, 0.72, 0.6)
	_bone_mat.roughness = 0.8
	_gone_mat = StandardMaterial3D.new()
	_gone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_gone_mat.albedo_color = Color(0, 0, 0, 0)
	_build_ui()
	if player:
		player.hurt.connect(_on_hurt)


## The body part `id` is on (the look to pick counts the crosshair landing on it): the head for the tusks and the trunk,
## its leg, else the torso.
func _body_of(id: String) -> Node:
	var d: Dictionary = PARTS[id]
	if d.has("leg"):
		return giant.legs[int(d.leg)]
	if id.begins_with("tusk") or id == "trunk":
		return giant.head
	return giant.torso


## The carcass lying still: a body along each tusk and the trunk (the crosshair lands on them), their parts moved onto them.
func _settle() -> void:
	_settled = true
	for id: String in ["tusk_l", "tusk_r", "trunk"]:
		var w := where(id)
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		if a.distance_to(b) < 0.1:
			continue
		var body := StaticBody3D.new()
		body.name = "Piece_" + id
		body.set_meta("surface", "bone" if id.begins_with("tusk") else "flesh")
		add_child(body)
		body.global_position = (a + b) * 0.5
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.18 if id.begins_with("tusk") else 0.22
		cap.height = a.distance_to(b) + cap.radius * 2.0
		cs.shape = cap
		cs.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		body.add_child(cs)
		_piece_bodies[id] = body


# --- The axe's parts (GatherTools' "carcass" targets) ----------------------------------------------------

## The axe's parts in reach of `chest` (their nearest point within AXE_REACH), as GatherTools targets: {type "carcass",
## key, work (this), pos (the nearest point), dist, radius, name, aim}: aim, of the parts on the body the crosshair (from
## `eye` along `look`) lands on, the one nearest where it lands (AIM_BONUS, less with the distance).
const AXE_REACH := 2.4
const AIM_BONUS := 0.9


func axe_candidates(chest: Vector3, eye: Vector3, look: Vector3, exclude: Array = []) -> Array:
	var out: Array = []
	if not ready_to_cut():
		return out
	var landed := {}
	var q := PhysicsRayQueryParameters3D.create(eye, eye + look.normalized() * 12.0)
	q.exclude = exclude
	var hit := giant.get_world_3d().direct_space_state.intersect_ray(q)
	for id: String in PARTS:
		if String(PARTS[id].tool) != AXE or not available(id):
			continue
		var c := axe_describe(id, chest)
		if c.is_empty() or float(c.dist) > AXE_REACH:
			continue
		if not hit.is_empty() and hit.collider == _body_for_axe(id):
			var w := where(id)
			var near := Geometry3D.get_closest_point_to_segment(hit.position, w[0], w[1])
			c["aim"] = AIM_BONUS * clampf(1.0 - near.distance_to(hit.position) / 2.0, 0.0, 1.0)
		out.append(c)
	return out


## The target `key` again as it is now ({} when it is done or cannot be worked).
func axe_describe(key: String, chest: Vector3) -> Dictionary:
	if not PARTS.has(key) or not available(key):
		return {}
	var w := where(key)
	var near := Geometry3D.get_closest_point_to_segment(chest, w[0], w[1])
	if (w[0] as Vector3).distance_to(w[1]) < 0.01:
		near = (w[0] as Vector3) + (chest - (w[0] as Vector3)).normalized() * minf(float(PARTS[key].get("r", 0.5)), chest.distance_to(w[0]))
	return {"type": "carcass", "key": key, "work": self, "pos": near, "dist": Vector2(near.x - chest.x, near.z - chest.z).length(),
			"radius": 0.0, "name": String(PARTS[key].name), "aim": 0.0}


## One axe stroke of `power` at target `c`: its work so far (1: the part comes off, its yield into the pack).
func axe_strike(c: Dictionary, power: float) -> float:
	var id := String(c.get("key", ""))
	if not PARTS.has(id) or not available(id):
		return 0.0
	if carcass:
		WildlifeSpawner.touch(carcass)
	var st: Dictionary = state[id]
	st.progress = float(st.progress) + power * speed / float(PARTS[id].get("strokes", 5.0))
	if float(st.progress) >= 1.0:
		_take(id)
		finished.emit(id)
		return 1.0
	return float(st.progress)


func axe_prompt(key: String) -> String:
	var d: Dictionary = PARTS[key]
	var st: Dictionary = state[key]
	var s := "%s the %s" % [String(d.verb), String(d.name)]
	if int(d.get("times", 1)) > 1:
		s += " (%d cuts left)" % int(st.left)
	if float(st.progress) > 0.0:
		s += "  %d%%" % int(clampf(float(st.progress), 0.0, 0.99) * 100.0)
	return s


## The body an axe part lies on (the crosshair lands on it): its own along it (a tusk, the trunk), its leg, the torso.
func _body_for_axe(id: String) -> Node:
	if _piece_bodies.has(id):
		return _piece_bodies[id]
	var d: Dictionary = PARTS[id]
	if d.has("leg"):
		return giant.legs[int(d.leg)]
	return giant.torso


## The carcass has come to rest (its death played out): the parts can be worked.
func ready_to_cut() -> bool:
	return giant != null and giant.anim != null and not giant.anim.active


## Whether part `id` can be worked now: not done, the one before it done, its flank lying up.
func available(id: String) -> bool:
	var d: Dictionary = PARTS[id]
	var st: Dictionary = state[id]
	if bool(st.done) or not ready_to_cut():
		return false
	if d.has("after") and not bool(state[String(d.after)].done):
		return false
	if d.has("side") and String(d.side) == giant.dead_side:
		return false                       # the flank it lies on
	return true


## Whether the player has the tool for `id`.
func has_tool(id: String) -> bool:
	var tool := String(PARTS[id].tool)
	if tool == AXE:
		return player.gather != null and player.gather.owns(AXE)
	if player.loadout and player.loadout.has_kind(KNIFE):
		return true
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) == KNIFE and int(e.get("count", 0)) > 0:
			return true
	return false


## Where part `id` is on the carcass: [a, b] (a segment; a == b with the size `r` for a surface's middle).
func where(id: String) -> Array:
	var d: Dictionary = PARTS[id]
	if d.has("seg"):
		return [giant.bone_at(String(d.seg[0])), giant.bone_at(String(d.seg[1]))]
	if bool(d.get("line", false)):
		var l := _line(String(d.surface), String(d.bone))
		return [giant.carried(String(d.bone), l[0]), giant.carried(String(d.bone), l[1])]
	var c := giant.carried(String(d.bone), _centre(String(d.surface)))
	return [c, c]


## A long surface's root and tip at rest (skeleton space): its vertices nearest to and farthest from bone `bone`.
func _line(nm: String, bone: String) -> Array:
	var key := nm + "|line"
	if _centres.has(key):
		return _centres[key]
	var h := giant.skeleton.get_bone_global_rest(giant.skeleton.find_bone(bone)).origin
	var near := Vector3.ZERO
	var far := Vector3.ZERO
	var s := giant.surface(nm)
	if not s.is_empty():
		var m := s[0] as MeshInstance3D
		var to_skel := giant.skeleton.global_transform.affine_inverse() * m.global_transform
		var v: PackedVector3Array = m.mesh.surface_get_arrays(int(s[1]))[Mesh.ARRAY_VERTEX]
		var dn := INF
		var df := -1.0
		for p in v:
			var q := to_skel * p
			var d := q.distance_to(h)
			if d < dn:
				dn = d
				near = q
			if d > df:
				df = d
				far = q
	_centres[key] = [near, far]
	return _centres[key]


## The middle of the model's surface `nm` at rest (skeleton space): the mean of its vertices.
func _centre(nm: String) -> Vector3:
	if _centres.has(nm):
		return _centres[nm]
	var c := Vector3.ZERO
	var s := giant.surface(nm)
	if not s.is_empty():
		var m := s[0] as MeshInstance3D
		var arr: Array = m.mesh.surface_get_arrays(int(s[1]))
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for p in v:
			c += p
		c /= maxf(v.size(), 1.0)
		# (the mesh's own frame to the skeleton's)
		c = (giant.skeleton.global_transform.affine_inverse() * m.global_transform) * c
	_centres[nm] = c
	return c


## Begins (or, on the part being worked, stops) the work on part `id`. False when it cannot start.
func toggle(id: String) -> bool:
	if working != "":
		if working == id:
			_get_up()
		return false
	if player == null or not available(id):
		return false
	var d: Dictionary = PARTS[id]
	if not has_tool(id):
		_notice("You need %s to %s the %s" % ["a felling axe" if String(d.tool) == AXE else "a knife",
				String(d.verb).to_lower().split(" ")[0], String(d.name)])
		return false
	var w := where(id)
	var at: Vector3 = ((w[0] as Vector3) + (w[1] as Vector3)) * 0.5
	_ap = player.begin_kneel(self, at)
	if _ap == null:
		return false
	working = id
	_phase = 0
	_t = 0.0
	_blender = HorsePhaseBlender.new(_ap, player, LIB)
	_blender.show_clip(CLIP_IN, 0.0, 0.0)
	_blender.update(0.0)
	_label.text = "%s the %s" % [String(d.verb), String(d.name)]
	_bar.value = float(state[id].progress)
	_layer.visible = true
	return true


func _physics_process(dt: float) -> void:
	if not _settled and ready_to_cut():
		_settle()
	if working == "":
		return
	if player.is_dead or player.kneeling != self:
		_stop()
		return
	if _phase < 2 and _cancel_pressed():
		_get_up()
	_t += dt
	match _phase:
		0:
			_blender.show_clip(CLIP_IN, minf(_t, _len(CLIP_IN)), 0.15)
			if _t >= _len(CLIP_IN):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(CLIP_LOOP, fposmod(_t, _len(CLIP_LOOP)), 0.3)
			var st: Dictionary = state[working]
			st.progress = minf(float(st.progress) + dt * speed / float(PARTS[working].s), 1.0)
			_bar.value = float(st.progress)
			if float(st.progress) >= 1.0:
				var id := working
				_take(id)
				finished.emit(id)
				_get_up()
		2:
			_blender.show_clip(CLIP_OUT, minf(_t, _len(CLIP_OUT)), 0.2)
			if _t >= minf(OUT_S, _len(CLIP_OUT)):
				_stop()
				return
	_blender.update(dt)


## Part `id` cut: what it yields into the pack, and the carcass shows it.
func _take(id: String) -> void:
	var d: Dictionary = PARTS[id]
	var st: Dictionary = state[id]
	var inv := InventoryState.from_player(player)
	var got: Array = []
	if carcass:
		WildlifeSpawner.touch(carcass)
	# a cut of meat takes 1 of its flank's (what the scavengers left: less meat when less is left)
	var share := 1.0
	if pool.has(id) and not d.has("drops"):
		share = minf(1.0, float(pool[id]))
		pool[id] = maxf(float(pool[id]) - share, 0.0)
	for k: String in d.yield:
		var n := int(d.yield[k])
		if share < 1.0:
			n = maxi(int(round(n * share)), 1 if share > 0.15 else 0)
		if n <= 0:
			continue
		inv.add(k, n)
		got.append("+%d %s" % [n, InventoryState.name_of(k)])
	player.inventory_pack = inv.pack.duplicate(true)
	if d.has("drops"):
		_drop_piece(id)
		got.append("the %s comes off" % String(d.name))
	_notice(", ".join(got))
	st.left = int(st.left) - 1
	if pool.has(id) and not d.has("drops"):
		st.left = mini(int(st.left), ceili(float(pool[id]) - 0.05))
	st.progress = 0.0
	_mark_bones()
	if int(st.left) > 0:
		return
	_part_done(id)


## Part `id` finished (cut off, cut clean, or eaten away): the carcass shows it.
func _part_done(id: String) -> void:
	var d: Dictionary = PARTS[id]
	var st: Dictionary = state[id]
	st.done = true
	if d.has("cut"):
		var bi := giant.skeleton.find_bone(String(d.cut))
		if bi >= 0:
			giant.skeleton.set_bone_pose_scale(bi, Vector3.ONE * 0.01)
	if d.has("leg"):
		for c in giant.legs[int(d.leg)].get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
	if _piece_bodies.has(id):
		for c in (_piece_bodies[id] as Node).get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
	if d.has("surface"):
		var s := giant.surface(String(d.surface))
		if not s.is_empty():
			var mat := _gone_mat if id.begins_with("tusk") else (_bone_mat if id.begins_with("meat") else _meat_mat)
			(s[0] as MeshInstance3D).set_surface_override_material(int(s[1]), mat)


## Part `id` falls off as a carcass of its own (LimbCarcass): the model's triangles on its bones, cut out as they lie
## (before its bone goes: _take), from the cut to its far end.
func _drop_piece(id: String) -> void:
	var d: Dictionary = PARTS[id]
	var pc: Dictionary = d.drops
	var names: Array = d.get("bones", pc.get("bones", []))
	var bones: Array = []
	for nm in names:
		var bi := giant.skeleton.find_bone(String(nm))
		if bi >= 0:
			bones.append(bi)
	var w := where(id)
	var cut: Vector3 = w[0]
	var far: Vector3 = w[1]
	var along := far - cut
	if along.length() < 0.1:
		return
	var up := Vector3.UP if absf(along.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var frame := Transform3D(Basis.looking_at(along, up), (cut + far) * 0.5)
	var mesh := ArrayMesh.new()
	for mi in giant.model.find_children("*", "MeshInstance3D", true, false):
		var part_mesh := LimbCarcass.cut_mesh(mi as MeshInstance3D, bones, frame)
		for si in part_mesh.get_surface_count():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part_mesh.surface_get_arrays(si))
			mesh.surface_set_material(mesh.get_surface_count() - 1, part_mesh.surface_get_material(si))
	# it falls clear of the carcass: out from its middle
	var out := frame.origin - giant.torso.global_position
	out.y = 0.0
	out = out.normalized() * (float(pc.r) + 0.9) if out.length() > 0.05 else Vector3.ZERO
	dropped[id] = LimbCarcass.make(String(pc.kind), String(pc.name), mesh, float(pc.r), along.length(), pc.give,
			float(pc.strokes), frame, get_tree().current_scene, out, float(pool.get(id, -1.0)))
	pool[id] = 0.0                         # (its meat went with it)


## The meat still on the carcass, in deer (the scavengers': Carcass.meat_left).
func meat_total() -> float:
	var n := 0.0
	for id: String in pool:
		n += float(pool[id])
	return n


## A scavenger takes up to `amount` of the meat: the flank that lies up first, then the legs on that side still on it,
## the trunk, the legs beneath, the flank beneath; returns what it got. A flank eaten away is done, its hide torn with
## it (its bones show).
func scavenge(amount: float) -> float:
	var up := "r" if giant.dead_side == "L" else "l"
	var dn := "l" if up == "r" else "r"
	var took := 0.0
	for id: String in ["meat_" + up, "foreleg_" + up, "hindleg_" + up, "trunk", "foreleg_" + dn, "hindleg_" + dn, "meat_" + dn]:
		if took >= amount:
			break
		var have := float(pool.get(id, 0.0))
		if have <= 0.0:
			continue
		var t := minf(amount - took, have)
		pool[id] = have - t
		took += t
		if id.begins_with("meat") and not bool(state[id].done):
			state[id].left = mini(int(state[id].left), ceili(float(pool[id]) - 0.05))
			if int(state[id].left) <= 0:
				_part_done(id)
				# torn open: its hide went with the meat
				var hid := String(PARTS[id].get("after", ""))
				if hid != "" and not bool(state[hid].done):
					state[hid].done = true
	if carcass:
		WildlifeSpawner.touch(carcass)
	_mark_bones()
	return took


## Picked clean (all the meat gone, by the knife or the scavengers): bones, for the scavengers' clean-up.
func _mark_bones() -> void:
	if carcass and meat_total() <= 0.02 and not carcass.get_meta("bones", false):
		carcass.set_meta("bones", true)


## The dead mammoth as a carcass (WildlifeSpawner's group "carcasses"): on the ground under its middle, its meat the
## butchery's pools; removed, the whole mammoth goes.
class Carcass extends Node3D:
	var butchery: MammothButchery
	var species := "mammoth"
	## Scavengers eat this far out from its middle: at its side (it lies on it).
	var eat_radius := 1.9
	var meat_left: float:
		get:
			return butchery.meat_total() if butchery else 0.0

	func _ready() -> void:
		add_to_group(&"carcasses")

	func _physics_process(_dt: float) -> void:
		if butchery == null or not is_instance_valid(butchery.giant):
			return
		var t := butchery.giant.torso
		var at: Vector3 = t.global_position if t else butchery.giant.where()
		global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)

	func eat(amount: float) -> float:
		return butchery.scavenge(amount) if butchery else 0.0

	func remove_carcass() -> void:
		if butchery and is_instance_valid(butchery.giant):
			butchery.giant.queue_free()


func _notice(text: String) -> void:
	if player and player.interactor:
		player.interactor.notice(text, 3.0)


func _cancel_pressed() -> bool:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3:
		return true
	for a: String in CANCEL_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return not player.hands_free


func _get_up() -> void:
	if _phase == 2:
		return
	_phase = 2
	_t = 0.0
	_layer.visible = false


func _on_hurt(_dir: Vector2, _amount: float, _heavy: bool) -> void:
	if working != "":
		_stop()


func _stop() -> void:
	working = ""
	_layer.visible = false
	if _blender and is_instance_valid(_blender.tree):
		_blender.tree.active = false
		_blender.tree.queue_free()
	_blender = null
	if player and player.kneeling == self:
		player.end_kneel()


func _len(clip: String) -> float:
	var full := "%s/%s" % [LIB, clip]
	return _ap.get_animation(full).length if _ap and _ap.has_animation(full) else 1.0


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.78
	box.anchor_bottom = 0.78
	box.offset_left = -170.0
	box.offset_right = 170.0
	_layer.add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 5)
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(340, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.62, 0.38)
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.07, 0.06, 0.7)
	back.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)


## One part of the carcass as an interactable where it lies (PlayerInteractor: the one looked at is the one E works).
class Part extends Node3D:
	var id := ""
	var butchery: MammothButchery
	var interact_reach := 3.2

	func _ready() -> void:
		add_to_group(PlacedWeapon.GROUP)

	func _seg() -> Array:
		return butchery.where(id)

	func interact_point() -> Vector3:
		var w := _seg()
		return ((w[0] as Vector3) + (w[1] as Vector3)) * 0.5

	## Distance from `p` to the part: to its segment (a leg, the trunk), or to its middle less its size (a tusk, a flank).
	func distance_from(p: Vector3) -> float:
		var w := _seg()
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		if a.distance_to(b) < 0.01:
			return maxf(p.distance_to(a) - float(MammothButchery.PARTS[id].get("r", 0.5)), 0.0)
		return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))

	func interact_prompt(_player: Node) -> String:
		if not butchery.available(id):
			return ""
		var d: Dictionary = MammothButchery.PARTS[id]
		var st: Dictionary = butchery.state[id]
		var s := "%s the %s" % [String(d.verb), String(d.name)]
		if int(d.get("times", 1)) > 1:
			s += " (%d cuts left)" % int(st.left)
		if not butchery.has_tool(id):
			s += " (needs %s)" % ("a felling axe" if String(d.tool) == MammothButchery.AXE else "a knife")
		elif float(st.progress) > 0.0:
			s += " (%d%% done)" % roundi(float(st.progress) * 100.0)
		return s

	func highlight_targets() -> Array:
		return []

	func interact(_player: Node) -> bool:
		return butchery.toggle(id)
