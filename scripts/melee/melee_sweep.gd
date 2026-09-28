class_name MeleeSweep
extends RefCounted
## A melee weapon's path over the next tick, tested against the world before the pose is shown (user 2026-09-27: "we
## need a collision thing where it doesnt go thru the target", "if two weapons collide they both bounce back"). The
## swing's own clip says where the weapon will be (clip_bone: its prop bone down the clip's chain, where the pose
## now shown has it), a few steps along the tick; its edge's, head's and grip's paths and its haft and blade at each
## step are cast against bodies and against other weapons (WeaponBody). The first thing met is where the swing stops
## (AxeMelee, SparringPartner): held there a moment, then run back (pulled out of something soft, bounced off
## something hard or another weapon). How long and how hard by surface: data/melee/felling_axe.json "contact".

const DATA_PATH := "res://data/melee/felling_axe.json"

static var _chains := {}         ## [Animation id, bone, frame] -> [[bone index, rot track, pos track], ...]
static var _params := {}


## The place the clip `anim` gives `bone` at `t` in the frame of `frame_bone` ("" the skeleton's), its tracks'
## poses down the chain (the skeleton's current local pose where the clip keys nothing). As ToolPose.clip_relative,
## with the chain's tracks found once.
static func clip_bone(sk: Skeleton3D, anim: Animation, t: float, bone: String, frame_bone := "") -> Transform3D:
	var key := [anim.get_instance_id(), bone, frame_bone, sk.get_instance_id()]
	var chain: Array = _chains.get(key, [])
	if chain.is_empty():
		var b := sk.find_bone(bone)
		var f := sk.find_bone(frame_bone) if frame_bone != "" else -1
		var names := {}
		for i in anim.get_track_count():
			var nm := String(anim.track_get_path(i).get_concatenated_subnames())
			if not names.has(nm):
				names[nm] = [-1, -1]
			match anim.track_get_type(i):
				Animation.TYPE_ROTATION_3D:
					names[nm][0] = i
				Animation.TYPE_POSITION_3D:
					names[nm][1] = i
		while b >= 0 and b != f:
			var tr: Array = names.get(sk.get_bone_name(b), [-1, -1])
			chain.push_front([b, tr[0], tr[1]])
			b = sk.get_bone_parent(b)
		_chains[key] = chain
	var xf := Transform3D()
	var tt := clampf(t, 0.0, anim.length)
	for c: Array in chain:
		var pos := anim.position_track_interpolate(int(c[2]), tt) if int(c[2]) >= 0 else sk.get_bone_pose_position(int(c[0]))
		var rot := anim.rotation_track_interpolate(int(c[1]), tt) if int(c[1]) >= 0 else sk.get_bone_pose_rotation(int(c[0]))
		xf = xf * Transform3D(Basis(rot), pos)
	return xf


## The first thing the weapon meets along `frames` (its model's transforms through the tick, the pose shown now first),
## `pts` its model-local points {"edge", "head", "grip", "butt"}: {"k": the step it is met in (1..), "f": how far along
## it, "point", "normal", "collider", "weapon": the WeaponBody met or null, "line": "edge" | "head" | "grip" | "butt" |
## "haft" (butt to head) | "blade"} or {}.
static func first_contact(space: PhysicsDirectSpaceState3D, frames: Array, pts: Dictionary, skip_bodies: Array,
		skip_areas: Array) -> Dictionary:
	for k in range(1, frames.size()):
		var a: Transform3D = frames[k - 1]
		var b: Transform3D = frames[k]
		var butt: Vector3 = pts.get("butt", pts.grip)
		var lines := [[a * (pts.edge as Vector3), b * (pts.edge as Vector3), "edge"],
				[a * (pts.head as Vector3), b * (pts.head as Vector3), "head"],
				[a * (pts.grip as Vector3), b * (pts.grip as Vector3), "grip"],
				[a * butt, b * butt, "butt"],
				[b * butt, b * (pts.head as Vector3), "haft"],
				[b * (pts.head as Vector3), b * (pts.edge as Vector3), "blade"]]
		var best := {}
		var best_f := INF
		for ln: Array in lines:
			var r := ray(space, ln[0], ln[1], skip_bodies, skip_areas)
			if r.is_empty():
				continue
			var span := maxf(((ln[1] as Vector3) - (ln[0] as Vector3)).length(), 1e-5)
			var f := ((r.position as Vector3) - (ln[0] as Vector3)).length() / span
			if ln[2] in ["haft", "blade"]:
				f = 1.0          # (lying along the step's last pose, not along a path: met by its end; a path met in it is first)
			if f < best_f:
				best_f = f
				best = r
				best["line"] = ln[2]
				best["f"] = f
				best["from"] = ln[0]
				best["to"] = ln[1]
		if not best.is_empty():
			best["k"] = k
			return best
	return {}


## Whoever defends the body `col` is part of (block_power: a sparring partner, a player's melee), or null.
static func defender_of(col: Object) -> Object:
	var n := col as Node
	while n != null:
		if n.has_method(&"block_power"):
			return n
		var g = n.get("gather")
		if g is GatherTools and (g as GatherTools).melee != null:
			return (g as GatherTools).melee
		n = n.get_parent()
	return null


## Where a blow's head, along `frames` (its weapon's transforms through the tick, `pts` its points), first comes within
## AxeMelee.BLOCK_STOP_M of a defender other than `me` (a fighter: group melee_defender; across the ground from its
## middle, between its knees and the top of its head), coming at it: there a block by reaction is met (the space
## between them), not the body. {"k", "f" (the step and how far along it), "foe" (its block_power's holder), "point",
## "motion"} or {}. Only the fighters near the swing are looked at (the physics broadphase, a sphere round its path in
## `space`), not every one on the map: the cost stays the same with 2000 on it (user 2026-09-27, big servers;
## tests/melee/bench_block_scale.gd).
static func near_defender(space: PhysicsDirectSpaceState3D, frames: Array, pts: Dictionary, me: Object) -> Dictionary:
	var best := {}
	var h0: Vector3 = (frames[0] as Transform3D) * (pts.head as Vector3)
	var h1: Vector3 = (frames[frames.size() - 1] as Transform3D) * (pts.head as Vector3)
	if _probe == null:
		_probe = SphereShape3D.new()
	_probe.radius = h0.distance_to(h1) * 0.5 + AxeMelee.BLOCK_STOP_M + 0.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis(), (h0 + h1) * 0.5)
	q.collide_with_areas = false
	var looked := {}
	for hit: Dictionary in space.intersect_shape(q, 64):
		var n := _fighter_of(hit.collider)
		if n == null or looked.has(n.get_instance_id()):
			continue
		looked[n.get_instance_id()] = true
		var foe := defender_of(n)
		var body := n as Node3D
		if foe == null or foe == me or body == null or not body.is_inside_tree():
			continue
		var at := body.global_position
		var r := AxeMelee.BLOCK_STOP_M
		var prev: Vector3 = (frames[0] as Transform3D) * (pts.head as Vector3)
		for k in range(1, frames.size()):
			var h: Vector3 = (frames[k] as Transform3D) * (pts.head as Vector3)
			var d0 := Vector2(prev.x - at.x, prev.z - at.z).length()
			var d1 := Vector2(h.x - at.x, h.z - at.z).length()
			if d0 >= r and d1 < r and h.y > at.y + 0.4 and h.y < at.y + 1.9:
				var f := (d0 - r) / maxf(d0 - d1, 1e-5)
				if best.is_empty() or k < int(best.k) or k == int(best.k) and f < float(best.f):
					best = {"k": k, "f": f, "foe": foe, "point": prev.lerp(h, f), "motion": h - prev}
				break
			prev = h
	return best


static var _probe: SphereShape3D


## The fighter (group melee_defender) a collider is part of (its own body, or a part of it), or null.
static func _fighter_of(col: Object) -> Node:
	var n := col as Node
	while n != null:
		if n.is_in_group(&"melee_defender"):
			return n
		n = n.get_parent()
	return null


## Whether a weapon's part at `point`, moving `motion`, is coming at `foe` (its holder: a sparring partner, a player's
## melee; null: yes). A weapon drawn back past another's parry is not.
static func coming_at(foe: Object, point: Vector3, motion: Vector3) -> bool:
	var body := foe as Node3D
	if body == null and foe != null:
		body = foe.get("player") as Node3D
	if body == null:
		return true
	var to := body.global_position - point
	to.y = 0.0
	motion.y = 0.0
	return to.dot(motion) > 0.0


## The core of the shape a line met (for a cut to go in to): its axis for a capsule or a cylinder (a torso: the spine),
## its centre for a sphere (a head, an animal's zone), its long axis for a box; {} when there is no shape to read.
## {"node": the CollisionShape3D, "half": half the axis's length (0 a point), "axis": the node's local axis}.
static func core_of(col: Object, shape_idx: int) -> Dictionary:
	var co := col as CollisionObject3D
	if co == null:
		return {}
	var owner_id := co.shape_find_owner(shape_idx)
	var sn := co.shape_owner_get_owner(owner_id) as CollisionShape3D if owner_id >= 0 else null
	if sn == null or sn.shape == null:
		return {}
	var sh := sn.shape
	if sh is CapsuleShape3D:
		return {"node": sn, "half": maxf((sh as CapsuleShape3D).height * 0.5 - (sh as CapsuleShape3D).radius, 0.0), "axis": Vector3.UP}
	if sh is CylinderShape3D:
		return {"node": sn, "half": (sh as CylinderShape3D).height * 0.5, "axis": Vector3.UP}
	if sh is BoxShape3D:
		var z: Vector3 = (sh as BoxShape3D).size
		var ax := Vector3.RIGHT if z.x >= z.y and z.x >= z.z else (Vector3.UP if z.y >= z.z else Vector3.BACK)
		return {"node": sn, "half": maxf(maxf(z.x, z.y), z.z) * 0.5, "axis": ax}
	return {"node": sn, "half": 0.0, "axis": Vector3.UP}


## How far `p` is from a core (core_of), and the core's point nearest it: [distance, point].
static func to_core(core: Dictionary, p: Vector3) -> Array:
	var sn := core.get("node") as Node3D
	if sn == null or not is_instance_valid(sn) or not sn.is_inside_tree():
		return [INF, p]
	var g := sn.global_transform
	var ax := (g.basis * (core.axis as Vector3)).normalized()
	var half := float(core.half)
	var along := clampf((p - g.origin).dot(ax), -half, half)
	var q := g.origin + ax * along
	return [p.distance_to(q), q]


## A line against bodies (every layer) and weapons (WeaponBody.LAYER): the nearer, {} for none; "weapon" set when it
## is a weapon.
static func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, skip_bodies: Array, skip_areas: Array) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = skip_bodies
	q.collide_with_areas = false
	q.collision_mask = 0xFFFFFFFF & ~WeaponBody.LAYER
	var r := space.intersect_ray(q)
	var qa := PhysicsRayQueryParameters3D.create(from, to, WeaponBody.LAYER)
	qa.exclude = skip_areas
	qa.collide_with_areas = true
	qa.collide_with_bodies = false
	var ra := space.intersect_ray(qa)
	if not ra.is_empty() and (r.is_empty() or from.distance_to(ra.position) < from.distance_to(r.position)):
		ra["weapon"] = ra.collider as WeaponBody
		return ra
	if not r.is_empty():
		r["weapon"] = null
	return r


## How a swing takes meeting `surface` ("flesh", "straw", "wood", "stone", "dirt", "grass", "weapon"): {"bite_m" (how
## far a soft thing lets the edge in), "stop_s" (held there), "recoil_s", "recoil_rate" (run back that fast),
## "fade_s" (back to the guard)}.
static func params(surface: String) -> Dictionary:
	if _params.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_params = (d.get("contact", {}) as Dictionary) if d is Dictionary else {}
	var s: Dictionary = _params.get("surfaces", {})
	var base := {"bite_m": 0.0, "stop_s": 0.06, "recoil_s": 0.25, "recoil_rate": 1.4, "fade_s": 0.25}
	base.merge(s.get(surface, s.get("wood", {})), true)
	return base


## The data's contact window: [before the strike begins, after it ends] (s).
static func window() -> Array:
	params("wood")
	return _params.get("window", [0.12, 0.25])


## The edge reaching the core of something it cut into (`surface` the soft thing): the crunch.
## (flesh: axe_crunch_flesh, tools/sfx/impacts.py; straw: the chop into the dummy's post)
static func crunch(surface: String, point: Vector3) -> void:
	var id := &"axe_crunch_flesh" if surface == "flesh" else &"gather_rec_axe_chop"
	if not Sfx.has(id):
		id = &"gather_rec_axe_chop_big"
	if Sfx.has(id):
		Sfx.play_3d(id, point, 0.0, randf_range(0.92, 1.02))


## Cutting into something soft: {"surfaces", "rate" (the swing slowed to this share of its pace), "core_m" (how near
## the core's line the edge stops), "max_s" (the longest a cut goes on)}.
static func cut() -> Dictionary:
	params("wood")
	var c := {"surfaces": ["flesh", "straw"], "rate": 0.4, "core_m": 0.04, "max_s": 0.4}
	c.merge(_params.get("cut", {}), true)
	return c


## The sound of an edge meeting `surface` at `point`.
static func sound(surface: String, point: Vector3, hard := 1.0, id_override := "") -> void:
	var id := &""
	var pitch := randf_range(0.9, 1.05)
	match surface:
		"flesh":
			id = &"arrow_hit_flesh"
		"straw":
			id = &"arrow_hit_straw"
		"wood":
			id = &"gather_rec_axe_chop"
		"stone":
			id = &"ball_hit_stone"
		"dirt", "grass":
			id = &"arrow_hit_dirt"
		"weapon":
			id = &"axe_clash"               # (tools/sfx/impacts.py: two iron heads ringing, the hafts knocking)
			pitch = randf_range(0.95, 1.05)
	if id_override != "":
		id = StringName(id_override)     # (the weapon's own: the club's heavier thud on flesh)
	if id != &"" and Sfx.has(id):
		Sfx.play_3d(id, point, linear_to_db(clampf(hard, 0.3, 1.2)), pitch)


## A few sparks off steel meeting steel or stone.
static func spark(parent: Node, point: Vector3, normal: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.28
	p.explosiveness = 1.0
	p.direction = normal if normal.length_squared() > 0.01 else Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := QuadMesh.new()
	m.size = Vector2(0.018, 0.018)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1.0, 0.75, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 4.0
	m.material = mat
	p.mesh = m
	parent.add_child(p)
	p.global_position = point
	p.emitting = true
	p.get_tree().create_timer(0.6).timeout.connect(p.queue_free)
