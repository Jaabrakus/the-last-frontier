class_name Wheelbarrow
extends Node3D
## A wooden wheelbarrow (user 2026-09-27: "wheel borrows where we can use to add items in so instead of dragging if
## the has a wheel borrow it can be faster"): a box bed on one wheel between two long handles, the project's own model.
## One stands by the fort at the start (ensure_demo); it is saved (SaveParts "wheelbarrow").
##
## E at its handles, "Push the wheelbarrow": both hands take the handles (the gun or the axe goes on the back, a torch
## back into the pack), the handles come up and it goes before the player as they walk, the wheel on the ground. The
## load sets the pace (haul.json "wheelbarrow"): empty at a jog, a doe at a brisk walk (faster than dragging her), a
## log length slower, heavier slower still; no sprint. While pushed it is part of the player's body (a box in front):
## it stops at a trunk or a wall. E again ("Set the wheelbarrow down"), a jump, a weapon key, a heavy hit, sleep or
## death set it down where it is.
##
## E at its bed: what goes in, one at a time, and what comes out:
##   a dead animal lying by it    "Put the deer in the wheelbarrow"   (it rides in the bed, head to the wheel)
##   a log of one length by it    "Put the log in the wheelbarrow"    (along the bed)
##   otherwise                    "Load the wheelbarrow": the chest screen, the pack beside the bed (what a chest
##                                takes: stone, firewood, meat, hides, ...)
##   with a deer or a log in it   "Tip out the deer" / "... the log": laid on the ground beside it
## The arms reach the handles (a PalmReachIK on each palm); the legs walk the player's own locomotion.

const GROUP := &"wheelbarrows"
## The model (its frame: the wheel's axle at the origin, +Z forward to the wheel, +X to the pusher's left).
const WHEEL_R := 0.2
## The grips: this far behind the axle, this high over it (the barrow level), this far either side.
const GRIP_BACK := 1.45
const GRIP_UP := 0.26
const GRIP_W := 0.29
## The legs (parked on them and the wheel).
const LEG_Z := -0.8
## The bed: from BED_Z.x to BED_Z.y along it, its floor this high over the axle.
const BED_Z := Vector2(-0.95, -0.1)
const BED_FLOOR := 0.02
## Pushing: the grips' middle this far in front of the pusher's feet and this high.
const GRIP_FWD := 0.24
const GRIP_H := 0.8
## Seconds for the arms to take the handles or let them go.
const ARM_FADE_S := 0.2
## A dead animal's rump end no further back than this (the grips are at -GRIP_BACK; the bed starts at BED_Z.x).
const CARCASS_BACK := -1.12

var player: FrontierPlayer = null          ## pushing it (null: parked)
## Pack things in the bed: [{kind, count}] (the chest screen's container side).
var items: Array = []
var open := false
## A dead animal or a log in the bed ("carcass" / "log"; "" none) and the node.
var load_kind := ""
var load_node: Node3D = null
## A dead animal's place in the bed, in the barrow's frame (_seat_for: from its shape as it lies).
var _carcass_seat := Transform3D.IDENTITY
## The pace the load gives (m/s) while pushed.
var cap := INF
## Why it was last set down ("e", "jump", "weapon", "hit", "died", "mounted", "kneeling", "vault"); tests.
var last_set_down := ""

var interact_reach := 2.2
## How many models of the pack things show in the bed (tests; counted headless too).
var goods_shown := 0
var _goods: Node3D
var _body: StaticBody3D
var _push_shape: CollisionShape3D
var _wheel: Node3D
var _spin := 0.0
var _last_axle := Vector3.INF
var _ik: PalmReachIK
var _ik_w := 0.0
var _gun := ""
var _pending_t := 0.0
var _pending_p: FrontierPlayer = null
var _was_inter := false
var _exceptions: Array[PhysicsBody3D] = []
var bed: Node


static func find(tree: SceneTree) -> Wheelbarrow:
	return tree.get_first_node_in_group(GROUP) as Wheelbarrow if tree else null


static func cfg() -> Dictionary:
	return HorseHaul.data().get("wheelbarrow", {})


## One by the fort for the player to find, if the level has none (FrontierPlayer's _ready, as the demo horse).
static func ensure_demo(p: Node3D) -> void:
	var scene := p.get_tree().current_scene if p.is_inside_tree() else null
	# the horse cart beside the demo horse, with the wheelbarrow (HorseCart)
	HorseCart.ensure_demo(p)
	if scene == null or scene.find_children("*", "Wheelbarrow", true, false).size() > 0:
		return
	var w := Wheelbarrow.new()
	w.name = "Wheelbarrow"
	scene.add_child(w)
	var fwd := -p.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	w.park_at(_clear_spot(p, fwd), fwd)


## A spot a few metres from `p` with nothing to take or stand in the way near it (not by the weapon racks or the
## horse, not into a wall): the first of a ring of candidates, in front first.
static func _clear_spot(p: Node3D, fwd: Vector3) -> Vector3:
	var tree := p.get_tree()
	var space := p.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 2.2)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.exclude = [(p as CollisionObject3D).get_rid()] if p is CollisionObject3D else []
	for r: float in [3.5, 5.0, 6.5]:
		for k in 12:
			var ang := float(k) * TAU / 12.0 * (1.0 if k % 2 == 0 else -1.0) * 0.5
			var d := fwd.rotated(Vector3.UP, ang)
			var at: Vector3 = p.global_position + d * r
			at.y = FrontierTerrain.height_at(at.x, at.z)
			var busy := false
			for n in tree.get_nodes_in_group(PlacedWeapon.GROUP) + tree.get_nodes_in_group(WeaponRack.GROUP):
				if n is Node3D and (n is PlacedWeapon or n is WeaponRack or n is Horse or n is PackDrop) \
						and (n as Node3D).global_position.distance_to(at) < 3.5:
					busy = true
					break
			if busy:
				continue
			q.transform = Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)), at + Vector3.UP * 0.7)
			var hits := space.intersect_shape(q, 4)
			var blocked := false
			for h in hits:
				var c: Node = h.collider
				if c != null and not c.is_in_group(&"terrain"):
					blocked = true
					break
			if not blocked:
				return at
	return p.global_position + fwd * 3.0


## The pace (m/s) for `kg` in it (haul.json "wheelbarrow" pace pairs; past the last, down toward extreme_mps).
static func pace_for(kg: float) -> float:
	var c := cfg()
	var pts: Array = c.get("pace", [[0, 2.4], [400, 0.45]])
	var prev: Array = pts[0]
	if kg <= float(prev[0]):
		return float(prev[1])
	for i in range(1, pts.size()):
		var q: Array = pts[i]
		if kg <= float(q[0]):
			return lerpf(float(prev[1]), float(q[1]), (kg - float(prev[0])) / maxf(float(q[0]) - float(prev[0]), 1e-3))
		prev = q
	return maxf(float(prev[1]) * float(prev[0]) / kg, float(c.get("extreme_mps", 0.1)))


static func kg_of(kind: String) -> float:
	var t: Dictionary = cfg().get("kg", {})
	return float(t.get(kind, t.get("default", 1.0)))


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	process_physics_priority = 6              # after the player (0) and the foot pulls (5), before the loads (10)
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.set_meta(&"surface", "wood")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.66, 0.42, 1.25)
	cs.shape = box
	cs.position = Vector3(0.0, 0.12, -0.5)
	_body.add_child(cs)
	add_child(_body)
	var b := BedSpot.new()
	b.name = "Bed"
	b.barrow = self
	add_child(b)
	bed = b
	if DisplayServer.get_name() != "headless":
		_build_model()


# --- Where it stands -----------------------------------------------------------------------------------------

## Parked at `at` (the ground under the axle), facing `fwd`: on its wheel and legs.
func park_at(at: Vector3, fwd: Vector3) -> void:
	var f := Vector3(fwd.x, 0.0, fwd.z)
	f = f.normalized() if f.length() > 1e-4 else Vector3.BACK
	var axle := Vector3(at.x, _ground(at) + WHEEL_R, at.z)
	var legs := axle - f * absf(LEG_Z)
	var dy := _ground(legs) - axle.y
	# the legs' feet on the ground: local (y -WHEEL_R, z LEG_Z) raised by the pitch a to dy
	var a := _pitch_for(-WHEEL_R, LEG_Z, dy)
	global_transform = Transform3D(Basis(Vector3.UP, atan2(f.x, f.z)) * Basis(Vector3.RIGHT, a), axle)
	_last_axle = axle


## The pitch (about local +X) that puts local point (y, z) `dy` over the axle.
static func _pitch_for(y: float, z: float, dy: float) -> float:
	# rotated: y cos a - z sin a = dy
	var A := y
	var B := -z
	var R := sqrt(A * A + B * B)
	return asin(clampf(dy / R, -1.0, 1.0)) - atan2(A, B)


## Pushed: the grips in the hands, the wheel on the ground ahead.
func _push_pose() -> Transform3D:
	var fwd := -player.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var grips := player.global_position + fwd * GRIP_FWD + Vector3.UP * GRIP_H
	# the axle as far ahead as the handles reach at the pitch they take (two passes: the pitch shortens it)
	var a := 0.0
	var axle := grips
	for i in 2:
		var h := GRIP_BACK * cos(a) - GRIP_UP * sin(a)
		axle = grips + fwd * h
		axle.y = _ground(axle) + WHEEL_R
		a = _pitch_for(GRIP_UP, -GRIP_BACK, grips.y - axle.y)
	return Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)) * Basis(Vector3.RIGHT, a), axle)


## The ground under `p`: a ray down (not people, the barrow, what is in it), else the terrain.
func _ground(p: Vector3) -> float:
	if not is_inside_tree():
		return FrontierTerrain.height_at(p.x, p.z)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 3.0)
	var ex: Array[RID] = []
	if _body:
		ex.append(_body.get_rid())
	for n in _exceptions:
		if is_instance_valid(n):
			ex.append(n.get_rid())
	var space := get_world_3d().direct_space_state
	for _try in 4:
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var col := hit.collider as Node
		if col is CharacterBody3D or (col != null and (col.is_in_group(&"trees") or col.get_parent() is SkidLoad)):
			ex.append(hit.rid)
			continue
		return (hit.position as Vector3).y
	return FrontierTerrain.height_at(p.x, p.z)


func grips_point() -> Vector3:
	return global_transform * Vector3(0.0, GRIP_UP, -GRIP_BACK)


func bed_point() -> Vector3:
	return global_transform * Vector3(0.0, BED_FLOOR + 0.15, (BED_Z.x + BED_Z.y) * 0.5)


# --- Pushing -------------------------------------------------------------------------------------------------

func is_pushed() -> bool:
	return player != null


## `p` takes the handles. False when they cannot now (true while a gun goes on the back first).
func start(p: FrontierPlayer) -> bool:
	if player != null or p == null or p.is_dead or p.riding != null or p.kneeling != null or p.get("pushing") != null \
			or has_meta(&"in_cart"):
		return false
	if p.foot_drag and p.foot_drag.load != null:
		return false
	if not p.hands_free:
		if _pending_p == null and p.weapon and p.weapon.active and p.is_carried(p.weapon_key):
			_gun = p.weapon_key
			p.toggle_hands_free()
		if not p.hands_free:
			if _pending_p == null and p._held_switch != "":
				_pending_p = p                   # the gun goes on the back as soon as the hands are ready
				_pending_t = 1.5
				return true
			if _pending_p == null:
				_gun = ""
				_notice(p, "Your hands are busy")
			return false
	_pending_p = null
	if p.gather and p.gather.in_hand() != "":
		p.gather.drop_now()                      # the axe onto the back: both hands on the handles
	if p.torch and p.torch.holding():
		p.torch.put_away()
		_notice(p, "Both hands on the handles: the torch goes back in the pack")
	player = p
	p.set("pushing", self)
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_push_shape = CollisionShape3D.new()
	_push_shape.name = "WheelbarrowShape"
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.36, 1.2)
	_push_shape.shape = box
	# in the player's frame (forward -Z): the bed and the wheel ahead, over the ground's rise
	_push_shape.position = Vector3(0.0, 0.64, -(GRIP_FWD + GRIP_BACK * 0.5 + 0.55))
	p.add_child(_push_shape)
	_except_load(true)
	_ensure_ik()
	cap = pace_for(load_kg())
	return true


## Sets it down where it is (why: see last_set_down); after E the gun put away for it comes back.
func set_down(why := "") -> void:
	var p := player
	if p == null:
		return
	last_set_down = why
	player = null
	cap = INF
	if is_instance_valid(p):
		p.set("pushing", null)
		p.drag_speed_cap = INF
	if _push_shape and is_instance_valid(_push_shape):
		_push_shape.get_parent().remove_child(_push_shape)
		_push_shape.queue_free()
	_push_shape = null
	_except_load(false, p)
	var fwd := global_basis.z
	park_at(global_position, fwd)
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	var gun := _gun
	_gun = ""
	if why == "e" and gun != "" and is_instance_valid(p) and p.hands_free and p.weapon_key == gun and not p.is_dead:
		p.toggle_hands_free()


func _set_down_reason() -> String:
	var p := player
	if p.is_dead:
		return "died"
	if p.riding != null:
		return "mounted"
	if p.kneeling != null:
		return "kneeling"
	if not p.hands_free:
		return "weapon"
	if p.traversal and p.traversal.showing:
		return "vault"
	if Input.is_action_just_pressed("jump"):
		return "jump"
	return ""


func _physics_process(delta: float) -> void:
	if _pending_p != null:
		_pending_t -= delta
		if not is_instance_valid(_pending_p) or _pending_t <= 0.0 or _pending_p.is_dead:
			_pending_p = null
			_gun = ""
		elif _pending_p.hands_free:
			start(_pending_p)
	if player != null:
		if not is_instance_valid(player):
			player = null
		else:
			var why := _set_down_reason()
			if why != "":
				set_down(why)
	if player != null:
		global_transform = _push_pose()
		cap = pace_for(load_kg())
		player.drag_speed_cap = cap
	var axle := global_position
	if _last_axle != Vector3.INF and _wheel:
		var d := Vector2(axle.x - _last_axle.x, axle.z - _last_axle.z)
		var sgn := signf(d.dot(Vector2(global_basis.z.x, global_basis.z.z))) if d.length() > 1e-5 else 0.0
		_spin += sgn * d.length() / WHEEL_R
		_wheel.rotation.x = _spin
	_last_axle = axle
	_seat_load()
	_ik_w = move_toward(_ik_w, 1.0 if player != null else 0.0, delta / ARM_FADE_S)
	if _ik:
		_ik.set_target("l", Callable(self, "_grip_target"), _ik_w)
		_ik.set_target("r", Callable(self, "_grip_target"), _ik_w)


func _on_hurt(_dir: Vector2, _amount: float, heavy: bool) -> void:
	if heavy and player != null:
		set_down("hit")


## Both palms to the grips (skeleton space). The player whose skeleton it is (the IK stays on it after).
func _grip_target(side: String) -> Vector3:
	var p: FrontierPlayer = _ik.get_meta(&"player") if _ik and _ik.has_meta(&"player") else null
	if p == null or not is_instance_valid(p):
		return Vector3.INF
	var g := global_transform * Vector3(GRIP_W if side == "l" else -GRIP_W, GRIP_UP, -GRIP_BACK)
	return p.skeleton.global_transform.affine_inverse() * g


func _ensure_ik() -> void:
	var sk := player.skeleton
	if sk == null:
		return
	var existing := sk.get_node_or_null("BarrowGripIK") as PalmReachIK
	if existing:
		_ik = existing
	else:
		_ik = PalmReachIK.new()
		_ik.name = "BarrowGripIK"
		sk.add_child(_ik)
		for i in sk.get_child_count():
			var c := sk.get_child(i)
			if c is CharacterBodyMesh or String(c.name) == "HandPropsFinal":
				sk.move_child(_ik, i)
				break
	_ik.set_meta(&"player", player)
	if not player.hurt.is_connected(_on_hurt):
		player.hurt.connect(_on_hurt)


# --- What is in it -------------------------------------------------------------------------------------------

func load_kg() -> float:
	var kg := 0.0
	for e: Dictionary in items:
		kg += kg_of(String(e.kind)) * int(e.count)
	if load_node != null and is_instance_valid(load_node):
		if load_kind == "log":
			kg += (load_node as SkidLoad).mass_kg
		else:
			kg += CarcassLoad.mass_of_animal(load_node, HorseHaul.data())
	return kg


func load_name() -> String:
	if load_node == null or not is_instance_valid(load_node):
		return ""
	return "log" if load_kind == "log" else CarcassLoad.name_of(load_node)


## A dead animal into the bed. False when something is in it or it cannot be taken.
func put_carcass(a: Node3D) -> bool:
	if load_node != null or player != null or not CarcassLoad.haulable(a):
		return false
	load_node = a
	load_kind = "carcass"
	a.set_meta(&"on_chain", true)
	_carcass_seat = _seat_for(a)
	_was_inter = a.is_in_group(PlacedWeapon.GROUP)
	a.remove_from_group(PlacedWeapon.GROUP)
	_seat_load()
	return true


## A log of one length into the bed.
func put_log(s: SkidLoad) -> bool:
	if load_node != null or player != null or not log_fits(s):
		return false
	if s.laid:
		s.unlay()
	load_node = s
	load_kind = "log"
	s.laid = true                                 # not simulated while it rides
	s.set_meta(&"in_barrow", true)                # not offered to the axe, a pull or the horse while it rides
	_seat_load()
	return true


static func log_fits(s: Node) -> bool:
	var l := s as SkidLoad
	return l != null and not (l is CarcassLoad) and l.bundle == 0 and not l.hitched and l.state == FelledTree.State.DOWN \
			and not l.has_meta(&"in_barrow") \
			and l.length <= float(cfg().get("log_max_m", 2.7)) and not l.is_queued_for_deletion() \
			and (not l.laid or l.resting_on_me().is_empty())


## What is in the bed onto the ground beside it (the right of it). Returns it.
func tip_out() -> Node3D:
	var n := load_node
	var kind := load_kind
	load_node = null
	load_kind = ""
	if n == null or not is_instance_valid(n):
		return null
	var side := -global_basis.x
	side.y = 0.0
	side = side.normalized()
	var at := bed_point() + side * 1.0
	if kind == "log":
		var s := n as SkidLoad
		var f := global_basis.z
		f.y = 0.0
		f = f.normalized() * s.length * 0.5
		var a := at - f
		var b := at + f
		s.lay_at(Vector3(a.x, _ground(a) + s.r_front, a.z), Vector3(b.x, _ground(b) + s.r_back, b.z))
		s.laid = false                            # loose: it settles
		s.remove_meta(&"in_barrow")
	else:
		n.global_position = Vector3(at.x, _ground(at), at.z)
		n.remove_meta(&"on_chain")
		var sp: Variant = n.get(&"spawner")
		n.set_meta(&"hauled_at", float(sp.get(&"now")) if sp is Node and is_instance_valid(sp) else 0.0)
		if _was_inter and not n.is_in_group(PlacedWeapon.GROUP):
			n.add_to_group(PlacedWeapon.GROUP)
	return n


## What rides in the bed, placed there (every tick).
func _seat_load() -> void:
	if load_node == null:
		return
	if not is_instance_valid(load_node) or load_node.is_queued_for_deletion():
		load_node = null
		load_kind = ""
		return
	var xf := global_transform
	if load_kind == "log":
		var s := load_node as SkidLoad
		# along the bed, forward over the wheel (its back end short of the hands)
		var c := xf * Vector3(0.0, BED_FLOOR + s.mean_radius(), 0.05)
		var d := xf.basis.z.normalized() * s.length * 0.5
		s.lay_at(c + d, c - d)
	else:
		load_node.global_transform = xf * _carcass_seat


## Where a dead animal lies in the bed (user 2026-09-27: "the carcass in the wheelbarrow is off": it sat by its feet'
## point, which is not where a body lying on its side is, half back over the handles and through the bed). In the
## barrow's frame: the body along the bed (the neck toward the wheel, from its bones: CarcassLoad), its middle over the
## bed's middle, its lowest point on the floor, and its rump end short of the hands (the head may lie out over the
## wheel, as a deer is longer than the bed).
func _seat_for(a: Node3D) -> Transform3D:
	var inv := a.global_transform.affine_inverse()
	var ends := CarcassLoad._ends_global(a)
	var neck := inv * ends[0]
	var rump := inv * ends[1]
	var ax := Vector3(neck.x - rump.x, 0.0, neck.z - rump.z)
	var yaw := atan2(ax.x, ax.z) if ax.length_squared() > 1e-6 else 0.0
	var rot := Basis(Vector3.UP, -yaw)                       # the body's line onto the barrow's +Z
	# its shape as it lies, in its own frame turned so: the lowest point, the ends and the sides
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v in _pose_points(a, inv):
		var q := rot * v
		lo = lo.min(q)
		hi = hi.max(q)
	if lo.x == INF:
		var c0 := rot * ((neck + rump) * 0.5)
		lo = Vector3(c0.x - 0.2, 0.0, c0.z - 0.6)
		hi = Vector3(c0.x + 0.2, 0.4, c0.z + 0.6)
	var mid := (lo + hi) * 0.5
	var zc := (BED_Z.x + BED_Z.y) * 0.5
	# the rump end no further back than CARCASS_BACK (clear of the hands on the grips)
	var z := maxf(zc, CARCASS_BACK + (hi.z - lo.z) * 0.5)
	var at := Vector3(0.0, BED_FLOOR + 0.03, z)
	return Transform3D(rot, at - Vector3(mid.x, lo.y, mid.z))


## The dead animal's skinned meshes as they lie now, in its own frame (every few vertices).
static func _pose_points(a: Node3D, inv: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in a.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		var m: Mesh = mi.bake_mesh_from_current_skeleton_pose() if mi.skin != null else mi.mesh
		if m == null:
			continue
		var xf := inv * mi.global_transform
		for si in m.get_surface_count():
			var verts: PackedVector3Array = m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for i in range(0, verts.size(), 3):
				out.append(xf * verts[i])
	return out


func _except_load(on: bool, p: FrontierPlayer = null) -> void:
	var who := p if p != null else player
	if on:
		_exceptions.clear()
		if load_node and is_instance_valid(load_node):
			var bodies: Array = load_node.find_children("*", "PhysicsBody3D", true, false)
			if load_node is PhysicsBody3D:
				bodies.append(load_node)
			if load_node is SkidLoad and (load_node as SkidLoad).body:
				bodies.append((load_node as SkidLoad).body)
			for b in bodies:
				if b is PhysicsBody3D and b != who:
					who.add_collision_exception_with(b)
					_exceptions.append(b)
	else:
		for b in _exceptions:
			if is_instance_valid(b) and who and is_instance_valid(who):
				who.remove_collision_exception_with(b)
		_exceptions.clear()


# --- The chest screen's container side ------------------------------------------------------------------------

func accepts(kind: String) -> bool:
	return StorageChest.can_store(kind)


func title() -> String:
	return "WHEELBARROW"


func count_of(kind: String) -> int:
	for e: Dictionary in items:
		if String(e.kind) == kind:
			return int(e.count)
	return 0


func total() -> int:
	var n := 0
	for e: Dictionary in items:
		n += int(e.count)
	return n


func put(inv: InventoryState, kind: String, n: int) -> int:
	if not accepts(kind):
		return 0
	var got := inv.take(kind, n)
	if got <= 0:
		return 0
	for e: Dictionary in items:
		if String(e.kind) == kind:
			e.count = int(e.count) + got
			return got
	items.append({"kind": kind, "count": got})
	_refresh_goods()
	return got


func column_name() -> String:
	return "WHEELBARROW"


func take(inv: InventoryState, kind: String, n: int) -> int:
	for i in items.size():
		var e: Dictionary = items[i]
		if String(e.kind) != kind:
			continue
		var got := mini(int(e.count), maxi(n, 0))
		e.count = int(e.count) - got
		if int(e.count) <= 0:
			items.remove_at(i)
		inv.add(kind, got)
		_refresh_goods()
		return got
	return 0


# --- The pack things, shown in the bed (user 2026-09-27: "the items are not in the wheel borrow") ------------

## Long things (a log, a pole) lie along the bed, side by side, two deep; the rest sit in a grid over the floor, two
## deep. A few of each kind show (GOODS_PER_KIND), their models the pack icons' (GatherModels, ProvisionModels,
## ForageModels; a tied sack for anything else), each fitted to its place.
const GOODS_PER_KIND := 5
const LONG_KINDS := ["log", "pole", "branches"]


## The places in the bed: long things side by side on the floor, two deep; the rest over the floor (on top of the
## long things, `lift`), two deep, heaped a little in the middle.
func _goods_slots(long: bool, lift := 0.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if long:
		for layer in 2:
			for x in [-0.16, 0.0, 0.16]:
				out.append(Vector3(x, BED_FLOOR + 0.07 + 0.13 * layer, (BED_Z.x + BED_Z.y) * 0.5))
	else:
		for layer in 2:
			for z in [-0.78, -0.55, -0.32]:
				for x in [-0.17, 0.0, 0.17]:
					out.append(Vector3(x, BED_FLOOR + 0.09 + 0.14 * layer + lift + (0.04 if x == 0.0 else 0.0), z))
	return out


func _refresh_goods() -> void:
	var long_n := 0
	for e: Dictionary in items:
		if String(e.kind) in LONG_KINDS:
			long_n += mini(int(e.count), GOODS_PER_KIND)
	var long_slots := _goods_slots(true)
	var slots := _goods_slots(false, 0.0 if long_n == 0 else (0.13 if long_n <= 3 else 0.26))
	var li := 0
	var si := 0
	var place: Array = []            # [kind, Vector3, long]
	for e: Dictionary in items:
		var kind := String(e.kind)
		var long := kind in LONG_KINDS
		for i in mini(int(e.count), GOODS_PER_KIND):
			if long and li < long_slots.size():
				place.append([kind, long_slots[li], true])
				li += 1
			elif not long and si < slots.size():
				place.append([kind, slots[si], false])
				si += 1
	goods_shown = place.size()
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if _goods and is_instance_valid(_goods):
		_goods.queue_free()
	_goods = Node3D.new()
	_goods.name = "Goods"
	add_child(_goods)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for p: Array in place:
		var m := _item_model(String(p[0]))
		var box := _aabb_of(m)
		var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
		var holder := Node3D.new()
		_goods.add_child(holder)
		holder.add_child(m)
		m.position = -box.get_center()
		if bool(p[2]):
			# its longest side along the bed, 0.7 m of it
			var basis := Basis.IDENTITY
			if box.size.x >= box.size.y and box.size.x >= box.size.z:
				basis = Basis(Vector3.UP, PI * 0.5)
			elif box.size.y >= box.size.z:
				basis = Basis(Vector3.RIGHT, PI * 0.5)
			holder.transform = Transform3D(basis.scaled(Vector3.ONE * (0.7 / maxf(longest, 1e-3))), p[1])
		else:
			holder.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (0.2 / maxf(longest, 1e-3))), p[1])


static func _item_model(kind: String) -> Node3D:
	if GatherModels.has(kind):
		return GatherModels.build(kind)
	if ProvisionModels.has(kind):
		return ProvisionModels.build(kind)
	if ForageModels.has(kind):
		return ForageModels.build(kind)
	# a tied sack
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.16
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.53, 0.38)
	mat.roughness = 0.95
	mi.material_override = mat
	root.add_child(mi)
	return root


static func _aabb_of(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var q: Node = mi
		while q != null and q != n:
			xf = (q as Node3D).transform * xf
			q = q.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))


# --- E at the handles ----------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	if player != null:
		return player.global_position + Vector3.UP * 1.3 - player.global_basis.z * 0.2
	return grips_point()


func distance_from(pt: Vector3) -> float:
	if player != null:
		return 0.0
	var g := grips_point()
	return Vector2(pt.x - g.x, pt.z - g.z).length()


func interact_prompt(p: Node) -> String:
	if player != null:
		return "Set the wheelbarrow down" if p == player else ""
	if p == null or p.get("pushing") != null or bool(p.get("is_dead")):
		return ""
	var what := load_name()
	if what == "" and total() > 0:
		what = "%d thing%s" % [total(), "" if total() == 1 else "s"]
	return "Push the wheelbarrow" + ("" if what == "" else " (%s in it)" % ("a " + what if load_node else what))


func highlight_targets() -> Array:
	return []


func interact(p: Node) -> bool:
	if player != null:
		if p == player:
			set_down("e")
			return true
		return false
	return start(p as FrontierPlayer)


## The bed's E (BedSpot): {kind, text, node}.
func bed_offer(p: Node) -> Dictionary:
	if player != null or p == null or p.get("pushing") != null or bool(p.get("is_dead")):
		return {}
	if load_node != null and is_instance_valid(load_node):
		return {"kind": "tip", "text": "Tip out the %s" % load_name()}
	var bp := bed_point()
	var reach := float(cfg().get("reach_m", 2.2))
	var best := {}
	var bd := INF
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		var a := n as Node3D
		if a == null or not CarcassLoad.haulable(a):
			continue
		var d := Vector2(a.global_position.x - bp.x, a.global_position.z - bp.z).length()
		if d < reach and d < bd:
			bd = d
			best = {"kind": "carcass", "node": a, "text": "Put the %s in the wheelbarrow" % CarcassLoad.name_of(a)}
	for n in get_tree().get_nodes_in_group(FelledTree.GROUP):
		if not log_fits(n):
			continue
		var m := (n as SkidLoad).mid()
		var d := Vector2(m.x - bp.x, m.z - bp.z).length()
		if d < reach and d < bd:
			bd = d
			best = {"kind": "log", "node": n, "text": "Put the log in the wheelbarrow"}
	if not best.is_empty():
		return best
	var n := total()
	return {"kind": "open", "text": "Load the wheelbarrow" + ("" if n == 0 else " (%d thing%s in it)" % [n, "" if n == 1 else "s"])}


func bed_interact(p: Node) -> bool:
	var o := bed_offer(p)
	match String(o.get("kind", "")):
		"tip":
			var nm := load_name()
			tip_out()
			_notice(p, "The %s is out of the wheelbarrow" % nm)
			return true
		"carcass":
			return put_carcass(o.node)
		"log":
			return put_log(o.node)
		"open":
			ChestScreen.open_for(p, self)
			return true
	return false


func _notice(p: Node, text: String) -> void:
	var it: Node = p.get("interactor") if p else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 2.5)


# --- Save ----------------------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"xf": SaveParts.xf(global_transform), "items": SaveParts.plain(items), "load": load_kind,
			"load_at": SaveParts.v3(load_node.global_position if load_node and is_instance_valid(load_node) else bed_point())}


func load_data(d: Dictionary) -> void:
	if player != null:
		set_down("")
	var t := SaveParts.to_xf(d.get("xf"))
	park_at(t.origin - Vector3.UP * WHEEL_R, t.basis.z)
	items = (d.get("items", []) as Array).duplicate(true)
	_refresh_goods()
	# what rode in it lies where it was saved: taken back into the bed
	var kind := String(d.get("load", ""))
	var at := SaveParts.to_v3(d.get("load_at"), bed_point())
	if kind == "carcass":
		for n in get_tree().get_nodes_in_group(&"wildlife"):
			if n is Node3D and (n as Node3D).global_position.distance_to(at) < 1.5 and CarcassLoad.is_carcass(n):
				if n.has_meta(&"on_chain"):
					n.remove_meta(&"on_chain")
				put_carcass(n)
				break
	elif kind == "log":
		for n in get_tree().get_nodes_in_group(FelledTree.GROUP):
			if n is SkidLoad and (n as SkidLoad).mid().distance_to(at) < 1.5 and log_fits(n):
				put_log(n)
				break


# --- The model -----------------------------------------------------------------------------------------------

func _build_model() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.46, 0.33, 0.21)
	wood.roughness = 0.85
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.21, 0.13)
	dark.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.19, 0.18)
	iron.metallic = 0.6
	iron.roughness = 0.5
	var root := Node3D.new()
	root.name = "Model"
	add_child(root)
	# the bed: a floor and four boards, splayed a little
	var zl := BED_Z.y - BED_Z.x
	var zc := (BED_Z.x + BED_Z.y) * 0.5
	_box(root, Vector3(0.56, 0.035, zl), Vector3(0.0, BED_FLOOR, zc), Vector3.ZERO, wood)
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.03, 0.3, zl), Vector3(s * 0.3, BED_FLOOR + 0.15, zc), Vector3(0.0, 0.0, deg_to_rad(-8.0) * s), wood)
	_box(root, Vector3(0.62, 0.3, 0.03), Vector3(0.0, BED_FLOOR + 0.15, BED_Z.x), Vector3(deg_to_rad(8.0), 0.0, 0.0), wood)
	_box(root, Vector3(0.56, 0.26, 0.03), Vector3(0.0, BED_FLOOR + 0.13, BED_Z.y + 0.02), Vector3(deg_to_rad(-25.0), 0.0, 0.0), wood)
	# the handles: from beside the wheel back to the grips, under the bed
	for s in [-1.0, 1.0]:
		var a := Vector3(s * 0.12, 0.0, 0.05)
		var b := Vector3(s * GRIP_W, GRIP_UP, -GRIP_BACK)
		_pole(root, a, b, 0.024, dark)
		# the grip, rounded
		_pole(root, b + (a - b).normalized() * 0.16, b - (a - b).normalized() * 0.02, 0.019, wood)
		# a leg
		_pole(root, Vector3(s * 0.24, -0.02, LEG_Z + 0.05), Vector3(s * 0.25, -WHEEL_R + 0.01, LEG_Z), 0.02, dark)
	# the wheel: a wooden disc with an iron tyre, on its axle
	_wheel = Node3D.new()
	_wheel.name = "Wheel"
	root.add_child(_wheel)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = WHEEL_R - 0.012
	cm.bottom_radius = WHEEL_R - 0.012
	cm.height = 0.045
	cm.radial_segments = 20
	disc.mesh = cm
	disc.rotation = Vector3(0.0, 0.0, PI * 0.5)
	disc.material_override = wood
	_wheel.add_child(disc)
	var tyre := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = WHEEL_R - 0.016
	tm.outer_radius = WHEEL_R
	tm.rings = 24
	tyre.mesh = tm
	tyre.rotation = Vector3(0.0, 0.0, PI * 0.5)
	tyre.material_override = iron
	_wheel.add_child(tyre)
	_pole(root, Vector3(-0.13, 0.0, 0.0), Vector3(0.13, 0.0, 0.0), 0.015, iron)


func _box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	parent.add_child(m)


func _pole(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 8
	m.mesh = cm
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	m.transform = Transform3D(Basis(x, y, x.cross(y)).orthonormalized(), (a + b) * 0.5)
	m.material_override = mat
	parent.add_child(m)


## The bed's own E (its middle, as the horse's PackSpot is the hitch's).
class BedSpot:
	extends Node
	var barrow: Wheelbarrow
	var _offer := {}

	func _ready() -> void:
		add_to_group(PlacedWeapon.GROUP)

	func interact_point() -> Vector3:
		return barrow.bed_point()

	func distance_from(pt: Vector3) -> float:
		var b := barrow.bed_point()
		return Vector2(pt.x - b.x, pt.z - b.z).length()

	func interact_prompt(p: Node) -> String:
		# (asked of every interactable each tick: nothing to look for from afar)
		var b := barrow.bed_point()
		if not (p is Node3D) or Vector2((p as Node3D).global_position.x - b.x, (p as Node3D).global_position.z - b.z).length() > 4.0:
			return ""
		_offer = barrow.bed_offer(p)
		return String(_offer.get("text", ""))

	func highlight_targets() -> Array:
		return []

	func interact(p: Node) -> bool:
		return barrow.bed_interact(p)
