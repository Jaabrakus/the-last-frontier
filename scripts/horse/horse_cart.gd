class_name HorseCart
extends Node3D
## A two-wheeled horse cart (user 2026-09-27: "attach wheelbarrel to horse and create a carrage where we can add more
## things and then we can create trade routes"; picked the two-wheeled cart, "with this and wheelbarrel it allows for
## automation", the wheelbarrow riding in it): the frontier's cart, a box bed on two big wheels between shafts the horse
## stands in, the project's own model. One stands by the demo horse at the start (ensure_demo).
##
## The horse (Horse) draws it: whatever moves the horse moves the cart (ridden, led on foot, and so later a horse sent
## along a route by itself). The shafts' tips ride on the harness at the horse's shoulders (HARNESS); the cart pivots
## on them a little (PLAY_DEG either way of the horse's line), so it trails round a turn and swings behind; its wheels
## keep to the ground (each its own), the bed tilting with it. Its weight and what is in it, rolled over the ground and
## up the slope (CRR, the grade), is the pull (pull_kgf) the horse feels: HorseHaul caps the horse's pace by it as it
## does a log's, a light cart at a trot, a full one at a walk. A tree, a rock or a wall in the cart's way stops it: the
## horse stops too (stuck); turning the horse swings the cart clear, and after STUCK_FREE_S it is worked free.
##
## E (PlayerInteractor's "any other interactable" contract):
##   at the shafts, a horse standing by them (led there, or ridden up and stopped: in the saddle, a tap)
##       "Hitch the horse to the cart": the horse is put to it, the cart behind it
##   hitched, at the shafts or in the saddle with the horse stopped
##       "Unhitch the horse": the cart rests on its wheels and the shafts' tips where it stands
##   at the tailboard (CartBed; hold E for the list):
##       a dead animal lying by it          "Put the deer in the cart" (two side by side, one on top)
##       a log of a length by it            "Put the log in the cart" (up to six, along the bed)
##       the wheelbarrow parked by it       "Put the wheelbarrow in the cart" (it rides alone in the bed, whatever
##                                          is in it; take it out where the cart can go no further)
##       what went in last                  "Take out the deer" / "Take the wheelbarrow out"
##       otherwise                          "Load the cart": the chest screen, the pack beside the bed (what a chest
##                                          takes), shown in the bed
## At most CAPACITY_KG in it.

const GROUP := &"horse_carts"
## The model (its frame: the axle's middle at the origin, +Z forward to the horse, +X to the left).
const WHEEL_R := 0.62
const WHEEL_X := 0.8
const BED_Z := Vector2(-0.95, 0.95)
const BED_W := 1.24
const BED_FLOOR := 0.1
const SIDE_H := 0.42
## The shafts: their tips this far forward of the axle, this high over it (the cart level), this far either side.
const SHAFT_LEN := 3.2
const SHAFT_UP := 0.43
const SHAFT_X := 0.44
## Where the shafts' tips ride on the horse (its frame: -Z forward): at the shoulders, a saddle's height.
const HARNESS := Vector3(0.0, 1.05, -0.3)
## How far the cart may turn on the shafts from the horse's line (deg).
const PLAY_DEG := 25.0
## The horse's harness point within this of the shafts' tips to be put to the cart (m).
const HITCH_REACH := 4.5
const EMPTY_KG := 250.0
const CAPACITY_KG := 700.0
## Rolling over rough ground (x the weight: the pull on the level).
const CRR := 0.12
## Room in the bed: a dead animal takes 3, a log 1, of SPACE_MAX; the wheelbarrow the whole bed.
const SPACE := {"carcass": 3, "log": 1}
const SPACE_MAX := 6
const LOG_MAX_M := 3.3
const WHEELBARROW_KG := 30.0
## Held by a tree or a wall this long, the cart is worked free (passes it) for STUCK_FREE_FOR.
const STUCK_FREE_S := 2.5
## The most the axle rolls in a second: held back, it catches up no faster, and never hops past what held it.
const MAX_ROLL_MPS := 8.0
const STUCK_FREE_FOR := 2.0
const GOODS_SHOWN := 16

var horse: Horse = null
## Pack things in it, as the wheelbarrow's and a chest's: [{kind, count}].
var items: Array = []
## What rides in the bed besides: [{kind: "carcass" / "log" / "wheelbarrow", node}], in the order they went in.
var loads: Array = []
var stuck := false
var stuck_t := 0.0
## What held it last (the collider's name; tests, and the notice).
var caught_on := ""
## The pull (kgf) the horse feels now.
var pull_kgf := 0.0
var goods_shown := 0
var interact_reach := 2.6
var bed: CartBed

var _free_t := 0.0
var _body: StaticBody3D
var _wheels: Array[Node3D] = []
var _last_axle := Vector3.INF
var _spin := 0.0
var _goods: Node3D
var _horses: Array = []
var _horses_t := 0.0
var _barrow_layer := {}


static func find(tree: SceneTree) -> HorseCart:
	return tree.get_first_node_in_group(GROUP) as HorseCart if tree else null


## One beside the demo horse for the player to find, if the level has none (with the demo wheelbarrow).
static func ensure_demo(p: Node3D) -> void:
	var scene := p.get_tree().current_scene if p.is_inside_tree() else null
	if scene == null or scene.find_children("*", "HorseCart", true, false).size() > 0:
		return
	var c := HorseCart.new()
	c.name = "HorseCart"
	scene.add_child(c)
	var fwd := -p.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	# beside the demo horse (HorseMount.ensure_demo_horse: 4.5 m to the left, 5 m ahead, facing left), a little further
	# ahead and facing its way: out of its road and out of reach of its head. The first clear ground near there that
	# keeps well clear of the horse's line.
	var horse_at := p.global_position - right * 4.5 + fwd * 5.0
	var at := horse_at + fwd * 5.5
	c.park_at(c._clear_near(at, -right, func(q: Vector3) -> bool: return (q - horse_at).dot(fwd) > 5.0), -right)


## Ground near `at` with room for the cart facing `f` (its bed and shafts clear of walls, trunks and rocks): the first of
## a few rings round it (that `ok` passes, when given).
func _clear_near(at: Vector3, f: Vector3, ok := Callable()) -> Vector3:
	for r: float in [0.0, 2.5, 5.0, 7.5]:
		for k in (1 if r == 0.0 else 8):
			var c := at + Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * r
			if ok.is_valid() and not ok.call(c):
				continue
			c.y = FrontierTerrain.height_at(c.x, c.z)
			var xf := _pose(c, f, c.y + 0.3)
			if not _blocked(xf) and not _blocked(xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.2))):
				return c
	return at


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	process_physics_priority = 5            # after the horse has moved, before the wheelbarrow (6) and the loads (10)
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.set_meta(&"surface", "wood")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BED_W + 0.1, SIDE_H + 0.1, BED_Z.y - BED_Z.x)
	cs.shape = box
	cs.position = Vector3(0.0, BED_FLOOR + SIDE_H * 0.5, (BED_Z.x + BED_Z.y) * 0.5)
	_body.add_child(cs)
	add_child(_body)
	var b := CartBed.new()
	b.name = "Bed"
	b.cart = self
	add_child(b)
	bed = b
	if DisplayServer.get_name() != "headless":
		_build_model()


# --- Where it stands -----------------------------------------------------------------------------------------------

## Parked at `at` (the ground under the axle), facing `fwd`: on its wheels, the shafts' tips on the ground.
func park_at(at: Vector3, fwd: Vector3) -> void:
	var f := Vector3(fwd.x, 0.0, fwd.z)
	f = f.normalized() if f.length() > 1e-4 else Vector3.BACK
	var tip := Vector3(at.x, 0.0, at.z) + f * SHAFT_LEN
	global_transform = _pose(Vector3(at.x, 0.0, at.z), f, _ground(tip) + 0.05)
	_last_axle = global_position


## The pose with the axle's middle over `axle` (x, z), facing `f` (level, unit), pitched so the shafts' tips are at
## height `tip_y`, and rolled to its two wheels' ground.
func _pose(axle: Vector3, f: Vector3, tip_y: float) -> Transform3D:
	var left := Vector3.UP.cross(f).normalized()
	var gl := _ground(axle + left * WHEEL_X)
	var gr := _ground(axle - left * WHEEL_X)
	var ay := (gl + gr) * 0.5 + WHEEL_R
	var roll := atan2(gl - gr, WHEEL_X * 2.0)
	var pitch := _pitch_to(SHAFT_UP, SHAFT_LEN, tip_y - ay)
	var basis := Basis(Vector3.UP, atan2(f.x, f.z)) * Basis(Vector3.FORWARD, -roll) * Basis(Vector3.RIGHT, pitch)
	return Transform3D(basis, Vector3(axle.x, ay, axle.z))


## The pitch (about local +X) that puts local point (y, z), ahead of the axle (z > 0), `dy` over it: y cos a - z sin a
## = dy, the root nearest level.
static func _pitch_to(y: float, z: float, dy: float) -> float:
	var r := sqrt(y * y + z * z)
	return acos(clampf(dy / r, -1.0, 1.0)) - atan2(z, y)


## The ground under `p`: a ray down (not people, the cart, what is in it, the trees), else the terrain.
func _ground(p: Vector3) -> float:
	if not is_inside_tree():
		return FrontierTerrain.height_at(p.x, p.z)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 3.0)
	var ex: Array[RID] = []
	if _body:
		ex.append(_body.get_rid())
	for b in _load_bodies():
		ex.append((b as PhysicsBody3D).get_rid())
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


## The shafts' tips' middle (global).
func tips_point() -> Vector3:
	return global_transform * Vector3(0.0, SHAFT_UP, SHAFT_LEN)


## The tailboard's middle, a hand's height over the floor (global).
func tail_point() -> Vector3:
	return global_transform * Vector3(0.0, BED_FLOOR + 0.35, BED_Z.x - 0.1)


func bed_point() -> Vector3:
	return global_transform * Vector3(0.0, BED_FLOOR + 0.2, (BED_Z.x + BED_Z.y) * 0.5)


## Level forward (unit).
func forward() -> Vector3:
	var f := global_basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


# --- Hitched -------------------------------------------------------------------------------------------------------

func is_hitched() -> bool:
	return horse != null and is_instance_valid(horse)


static func harness_point(h: Horse) -> Vector3:
	return h.global_transform * HARNESS


static func _ridden(h: Horse) -> bool:
	var m := h.get_node_or_null("Mount")
	return m != null and m.get("rider") != null


static func haul_of(h: Horse) -> HorseHaul:
	return h.get_node_or_null("Haul") as HorseHaul if h else null


## Why `h` cannot be put to the cart now ("" when it can).
func why_not_hitch(h: Horse) -> String:
	if h == null or is_hitched():
		return "."
	var hh := haul_of(h)
	if hh == null:
		return "."
	if hh.load != null:
		return "Unhitch the %s from the horse first" % hh.load.load_name()
	if hh.cart != null and is_instance_valid(hh.cart):
		return "The horse is in another cart's shafts"
	if absf(h.speed) > 0.4:
		return "Stop the horse first"
	if tips_point().distance_to(harness_point(h)) > HITCH_REACH:
		return "."
	if _blocked(_hitched_pose(h, _horse_fwd(h))):
		return "No room behind the horse for the cart here"
	return ""


## `h` is put to the cart: the cart comes round behind it, the shafts at its shoulders. False when it cannot.
func hitch(h: Horse) -> bool:
	if why_not_hitch(h) != "":
		return false
	_attach(h)
	global_transform = _hitched_pose(h, _horse_fwd(h))
	_last_axle = global_position
	return true


## `h` in the shafts as the cart stands (hitch, and a save's cart put back to its horse).
func _attach(h: Horse) -> void:
	horse = h
	haul_of(h).cart = self
	h.add_collision_exception_with(_body)
	for b in _load_bodies():
		h.add_collision_exception_with(b)
	_last_axle = global_position
	stuck = false
	stuck_t = 0.0


## The horse out of the shafts: the cart rests where it stands, the tips on the ground.
func unhitch() -> void:
	if horse != null and is_instance_valid(horse):
		var hh := haul_of(horse)
		if hh and hh.cart == self:
			hh.cart = null
		horse.remove_collision_exception_with(_body)
		for b in _load_bodies():
			horse.remove_collision_exception_with(b)
	horse = null
	stuck = false
	pull_kgf = 0.0
	park_at(global_position, forward())


static func _horse_fwd(h: Horse) -> Vector3:
	var f := -h.global_basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


func _hitched_pose(h: Horse, f: Vector3) -> Transform3D:
	var hp := harness_point(h)
	var axle := Vector3(hp.x, 0.0, hp.z) - f * SHAFT_LEN
	return _pose(axle, f, hp.y)


func _physics_process(delta: float) -> void:
	if horse != null and not is_instance_valid(horse):
		horse = null
	if is_hitched():
		_follow(delta)
	_spin_wheels()
	_seat_loads()


## Behind the horse: the axle drawn after the shafts' tips (a trailer), within the shafts' play, clear of what stands
## in its way (swung round it if it can be, else held: stuck).
func _follow(delta: float) -> void:
	var hp := harness_point(horse)
	var hf := _horse_fwd(horse)
	var axle0 := _last_axle if _last_axle != Vector3.INF else global_position
	var to := Vector3(hp.x - axle0.x, 0.0, hp.z - axle0.z)
	var f := to.normalized() if to.length() > 0.05 else hf
	var ang := clampf(hf.signed_angle_to(f, Vector3.UP), -deg_to_rad(PLAY_DEG), deg_to_rad(PLAY_DEG))
	f = hf.rotated(Vector3.UP, ang)
	var want := _pose(_step(axle0, Vector3(hp.x, 0.0, hp.z) - f * SHAFT_LEN, delta), f, hp.y)
	var moved := Vector2(want.origin.x - axle0.x, want.origin.z - axle0.z).length()
	_free_t = maxf(_free_t - delta, 0.0)
	if _free_t > 0.0:
		# being worked free: it goes where it is drawn, through what held it
		_set_pose(want, axle0)
		stuck = false
		return
	if moved < 0.002:
		# the horse standing: held, it stays held (and the while runs on), else nothing to do
		if stuck:
			_held(delta)
		return
	if not _blocked(want):
		_set_pose(want, axle0)
		stuck_t = maxf(stuck_t - delta * 4.0, 0.0)
		stuck = false
		return
	# in the way: swung round it within the play, if one of those is clear
	for k: float in [8.0, -8.0, 16.0, -16.0, 24.0, -24.0]:
		var a2 := clampf(ang + deg_to_rad(k), -deg_to_rad(PLAY_DEG), deg_to_rad(PLAY_DEG))
		var f2 := hf.rotated(Vector3.UP, a2)
		var alt := _pose(_step(axle0, Vector3(hp.x, 0.0, hp.z) - f2 * SHAFT_LEN, delta), f2, hp.y)
		if not _blocked(alt):
			_set_pose(alt, axle0)
			stuck = false
			return
	# held: the horse stops (HorseHaul); after a while it is worked free
	_held(delta)


## From `from` toward `to` (level), no further than the axle rolls in `delta`.
func _step(from: Vector3, to: Vector3, delta: float) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var mx := MAX_ROLL_MPS * delta
	return Vector3(from.x, 0.0, from.z) + (d if d.length() <= mx else d.normalized() * mx)


func _held(delta: float) -> void:
	stuck = true
	stuck_t += delta
	if stuck_t >= STUCK_FREE_S:
		_free_t = STUCK_FREE_FOR
		stuck_t = 0.0
		stuck = false


func _set_pose(xf: Transform3D, axle0: Vector3) -> void:
	global_transform = xf
	# the pull: the weight rolled over the ground and lifted up the grade it went up
	var run := Vector2(xf.origin.x - axle0.x, xf.origin.z - axle0.z).length()
	var grade := clampf((xf.origin.y - axle0.y) / run, -0.5, 0.5) if run > 0.01 else 0.0
	pull_kgf = maxf(0.0, total_kg() * (CRR + grade))


## Whether the bed at pose `xf` runs into a tree, a rock or a wall (not the ground, people, animals or what rides in
## it).
func _blocked(xf: Transform3D) -> bool:
	if not is_inside_tree():
		return false
	var shape := BoxShape3D.new()
	shape.size = Vector3(BED_W, SIDE_H, BED_Z.y - BED_Z.x - 0.1)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, BED_FLOOR + SIDE_H * 0.5 + 0.05, (BED_Z.x + BED_Z.y) * 0.5))
	var ex: Array[RID] = [_body.get_rid()]
	for b in _load_bodies():
		ex.append((b as PhysicsBody3D).get_rid())
	q.exclude = ex
	for h in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c := h.collider as Node
		if c == null or c is CharacterBody3D or c is RigidBody3D or c.is_in_group(&"terrain"):
			continue
		if c is StaticBody3D or c is AnimatableBody3D:
			caught_on = str(c.get_path())
			return true
	return false


func _spin_wheels() -> void:
	var axle := global_position
	if _last_axle != Vector3.INF:
		var d := Vector2(axle.x - _last_axle.x, axle.z - _last_axle.z)
		var sgn := signf(d.dot(Vector2(global_basis.z.x, global_basis.z.z))) if d.length() > 1e-5 else 0.0
		_spin += sgn * d.length() / WHEEL_R
		for w in _wheels:
			w.rotation.x = _spin
	_last_axle = axle


# --- What is in it -------------------------------------------------------------------------------------------------

func load_kg() -> float:
	var kg := 0.0
	for e: Dictionary in items:
		kg += Wheelbarrow.kg_of(String(e.kind)) * int(e.count)
	for l: Dictionary in loads:
		var n: Node = l.node
		if not is_instance_valid(n):
			continue
		match String(l.kind):
			"log":
				kg += (n as SkidLoad).mass_kg
			"carcass":
				kg += CarcassLoad.mass_of_animal(n, HorseHaul.data())
			"wheelbarrow":
				kg += WHEELBARROW_KG + (n as Wheelbarrow).load_kg()
	return kg


## The cart and what is in it.
func total_kg() -> float:
	return EMPTY_KG + load_kg()


func space_used() -> int:
	var s := 0
	for l: Dictionary in loads:
		s += int(SPACE.get(String(l.kind), SPACE_MAX))
	return s


func has_barrow() -> bool:
	return loads.any(func(l: Dictionary) -> bool: return String(l.kind) == "wheelbarrow")


## Why `kind` (weighing `kg`) cannot go in ("" when it can).
func why_not_put(kind: String, kg: float) -> String:
	if has_barrow():
		return "The wheelbarrow fills the bed: put it in the wheelbarrow, or take the wheelbarrow out"
	if kind == "wheelbarrow" and not loads.is_empty():
		return "Take the rest out of the bed first"
	if kind != "wheelbarrow" and space_used() + int(SPACE.get(kind, 1)) > SPACE_MAX:
		return "No room left in the cart"
	if load_kg() + kg > CAPACITY_KG:
		return "Too heavy: the cart takes no more than about %d kg" % roundi(CAPACITY_KG)
	return ""


func name_of(l: Dictionary) -> String:
	match String(l.kind):
		"log":
			return "log"
		"wheelbarrow":
			return "wheelbarrow"
	return CarcassLoad.name_of(l.node) if is_instance_valid(l.node) else "load"


func put_carcass(a: Node3D) -> bool:
	if not CarcassLoad.haulable(a) or why_not_put("carcass", CarcassLoad.mass_of_animal(a, HorseHaul.data())) != "":
		return false
	_in_carcass(a)
	return true


## (put_carcass's taking it in, and a save's)
func _in_carcass(a: Node3D) -> void:
	a.set_meta(&"on_chain", true)
	var inter := a.is_in_group(PlacedWeapon.GROUP)
	a.remove_from_group(PlacedWeapon.GROUP)
	loads.append({"kind": "carcass", "node": a, "inter": inter, "seat": Transform3D.IDENTITY})
	_after_put()


static func log_fits(s: Node) -> bool:
	var l := s as SkidLoad
	return l != null and not (l is CarcassLoad) and l.bundle == 0 and not l.hitched and l.state == FelledTree.State.DOWN \
			and not l.has_meta(&"in_barrow") and l.length <= LOG_MAX_M and not l.is_queued_for_deletion() \
			and (not l.laid or l.resting_on_me().is_empty())


func put_log(s: SkidLoad) -> bool:
	if not log_fits(s) or why_not_put("log", s.mass_kg) != "":
		return false
	if s.laid:
		s.unlay()
	_in_log(s)
	return true


func _in_log(s: SkidLoad) -> void:
	s.laid = true                                 # not simulated while it rides
	s.set_meta(&"in_barrow", true)                # not offered to the axe, a pull or a horse while it rides
	loads.append({"kind": "log", "node": s})
	_after_put()


## The wheelbarrow, parked by the tailboard, into the bed (with whatever is in it).
func put_barrow(w: Wheelbarrow) -> bool:
	if w == null or w.is_pushed() or w.has_meta(&"in_cart") or why_not_put("wheelbarrow", WHEELBARROW_KG + w.load_kg()) != "":
		return false
	_in_barrow(w)
	return true


func _in_barrow(w: Wheelbarrow) -> void:
	w.set_meta(&"in_cart", self)
	w.remove_from_group(PlacedWeapon.GROUP)
	if w.bed:
		w.bed.remove_from_group(PlacedWeapon.GROUP)
	var body := w.get_node_or_null("Body") as CollisionObject3D
	if body:
		_barrow_layer = {"layer": body.collision_layer, "mask": body.collision_mask}
		body.collision_layer = 0
		body.collision_mask = 0
	loads.append({"kind": "wheelbarrow", "node": w})
	_after_put()


func _after_put() -> void:
	if is_hitched():
		for b in _load_bodies():
			horse.add_collision_exception_with(b)
	_seat_loads()


## What went in last, out onto the ground behind the tailboard. Returns it (null: nothing).
func take_out() -> Node3D:
	while not loads.is_empty():
		var l: Dictionary = loads.pop_back()
		var n: Node3D = l.node
		if n == null or not is_instance_valid(n):
			continue
		if is_hitched():
			for b in _bodies_of(n):
				horse.remove_collision_exception_with(b)
		var back := -forward()
		var left := Vector3.UP.cross(forward()).normalized()
		# a log laid along the cart on its left, a dead animal on its right, the wheelbarrow behind it
		var at := global_position + left * 1.5
		if String(l.kind) == "carcass":
			at = global_position - left * 1.6 + back * 0.3
		match String(l.kind):
			"log":
				var s := n as SkidLoad
				var a := at + back * s.length * 0.5
				var b := at - back * s.length * 0.5
				s.lay_at(Vector3(a.x, _ground(a) + s.r_front, a.z), Vector3(b.x, _ground(b) + s.r_back, b.z))
				s.laid = false
				s.remove_meta(&"in_barrow")
			"carcass":
				n.global_position = Vector3(at.x, _ground(at), at.z)
				n.remove_meta(&"on_chain")
				var sp: Variant = n.get(&"spawner")
				n.set_meta(&"hauled_at", float(sp.get(&"now")) if sp is Node and is_instance_valid(sp) else 0.0)
				if bool(l.get("inter", false)) and not n.is_in_group(PlacedWeapon.GROUP):
					n.add_to_group(PlacedWeapon.GROUP)
			"wheelbarrow":
				var w := n as Wheelbarrow
				w.remove_meta(&"in_cart")
				var body := w.get_node_or_null("Body") as CollisionObject3D
				if body and not _barrow_layer.is_empty():
					body.collision_layer = int(_barrow_layer.layer)
					body.collision_mask = int(_barrow_layer.mask)
				w.add_to_group(PlacedWeapon.GROUP)
				if w.bed:
					w.bed.add_to_group(PlacedWeapon.GROUP)
				w.park_at(global_position + back * (absf(BED_Z.x) + 1.9), back)
		return n
	return null


## What rides in the bed, set in its place (every tick): the logs along the floor three abreast, two deep; the dead
## animals along the bed side by side over them; the wheelbarrow alone, upright, its wheel to the front.
func _seat_loads() -> void:
	for i in range(loads.size() - 1, -1, -1):
		var n: Node = loads[i].node
		if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
			loads.remove_at(i)
	var xf := global_transform
	var logs := 0
	var beasts := 0
	var n_logs := loads.filter(func(l: Dictionary) -> bool: return String(l.kind) == "log").size()
	var log_top := BED_FLOOR + (0.3 * ceili(n_logs / 3.0) if n_logs > 0 else 0.0)
	for l: Dictionary in loads:
		match String(l.kind):
			"log":
				var s := l.node as SkidLoad
				var x := [-0.38, 0.0, 0.38][logs % 3] as float
				var c := xf * Vector3(x, BED_FLOOR + s.mean_radius() + 0.28 * (logs / 3), 0.0)
				var d := xf.basis.z.normalized() * s.length * 0.5
				s.lay_at(c + d, c - d)
				logs += 1
			"carcass":
				var a := l.node as Node3D
				if (l.seat as Transform3D) == Transform3D.IDENTITY:
					l["seat"] = _seat_for(a, [-0.3, 0.3][beasts % 2], log_top + 0.35 * (beasts / 2))
				a.global_transform = xf * (l.seat as Transform3D)
				beasts += 1
			"wheelbarrow":
				var w := l.node as Wheelbarrow
				var pitch := Wheelbarrow._pitch_for(-Wheelbarrow.WHEEL_R, Wheelbarrow.LEG_Z, -Wheelbarrow.WHEEL_R)
				w.global_transform = xf * Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0.0, BED_FLOOR + Wheelbarrow.WHEEL_R, 0.55))


## Where a dead animal lies in the bed (the cart's frame): along the bed, its middle over (x, 0), its lowest point at
## height `floor_y` (as the wheelbarrow seats one: Wheelbarrow._seat_for).
func _seat_for(a: Node3D, x: float, floor_y: float) -> Transform3D:
	var inv := a.global_transform.affine_inverse()
	var ends := CarcassLoad._ends_global(a)
	var neck := inv * ends[0]
	var rump := inv * ends[1]
	var ax := Vector3(neck.x - rump.x, 0.0, neck.z - rump.z)
	var yaw := atan2(ax.x, ax.z) if ax.length_squared() > 1e-6 else 0.0
	var rot := Basis(Vector3.UP, -yaw)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v in Wheelbarrow._pose_points(a, inv):
		var q := rot * v
		lo = lo.min(q)
		hi = hi.max(q)
	if lo.x == INF:
		var c0 := rot * ((neck + rump) * 0.5)
		lo = Vector3(c0.x - 0.2, 0.0, c0.z - 0.6)
		hi = Vector3(c0.x + 0.2, 0.4, c0.z + 0.6)
	var mid := (lo + hi) * 0.5
	return Transform3D(rot, Vector3(x, floor_y + 0.02, 0.05) - Vector3(mid.x, lo.y, mid.z))


func _load_bodies() -> Array:
	var out: Array = []
	for l: Dictionary in loads:
		if is_instance_valid(l.node):
			out.append_array(_bodies_of(l.node))
	return out


static func _bodies_of(n: Node) -> Array:
	var out: Array = []
	for b in n.find_children("*", "PhysicsBody3D", true, false):
		out.append(b)
	if n is PhysicsBody3D:
		out.append(n)
	if n is SkidLoad and (n as SkidLoad).body:
		out.append((n as SkidLoad).body)
	return out.filter(func(b: Variant) -> bool: return b is PhysicsBody3D and is_instance_valid(b) and not (b is CharacterBody3D and b is Horse))


# --- The chest screen's container side (as the wheelbarrow's) ------------------------------------------------------

func accepts(kind: String) -> bool:
	return StorageChest.can_store(kind)


func title() -> String:
	return "CART"


func column_name() -> String:
	return "CART"


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
	# no more than the cart takes
	var room := floori((CAPACITY_KG - load_kg()) / maxf(Wheelbarrow.kg_of(kind), 0.001))
	var got := inv.take(kind, mini(n, maxi(room, 0)))
	if got <= 0:
		return 0
	var found := false
	for e: Dictionary in items:
		if String(e.kind) == kind:
			e.count = int(e.count) + got
			found = true
	if not found:
		items.append({"kind": kind, "count": got})
	_refresh_goods()
	return got


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


## A few of each thing in it, shown over the front of the bed (the wheelbarrow's models).
func _refresh_goods() -> void:
	var place: Array = []
	var i := 0
	for e: Dictionary in items:
		for k in mini(int(e.count), 4):
			if i >= GOODS_SHOWN:
				break
			place.append([String(e.kind), Vector3(-0.42 + 0.28 * (i % 4), BED_FLOOR + 0.12 + 0.16 * (i / 8), 0.75 - 0.25 * ((i / 4) % 2))])
			i += 1
	goods_shown = place.size()
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if _goods and is_instance_valid(_goods):
		_goods.queue_free()
	_goods = Node3D.new()
	_goods.name = "Goods"
	add_child(_goods)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for p: Array in place:
		var m := Wheelbarrow._item_model(String(p[0]))
		var box := Wheelbarrow._aabb_of(m)
		var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
		var holder := Node3D.new()
		_goods.add_child(holder)
		holder.add_child(m)
		m.position = -box.get_center()
		holder.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (0.24 / maxf(longest, 1e-3))), p[1])


# --- E at the shafts -----------------------------------------------------------------------------------------------

## A horse near enough to be put to it (cached a second at a time).
func _near_horse() -> Horse:
	_horses_t -= get_physics_process_delta_time()
	if _horses_t <= 0.0:
		_horses_t = 1.0
		var scene := get_tree().current_scene
		_horses = scene.find_children("*", "Horse", true, false) if scene else []
	var best: Horse = null
	var bd := INF
	var tp := tips_point()
	for h in _horses:
		if not is_instance_valid(h):
			continue
		var d := tp.distance_to(harness_point(h))
		if d < bd and d <= HITCH_REACH:
			bd = d
			best = h
	return best


func interact_point() -> Vector3:
	return tips_point()


func distance_from(pt: Vector3) -> float:
	var t := tips_point()
	return Vector2(pt.x - t.x, pt.z - t.z).length()


func interact_prompt(p: Node) -> String:
	if p == null or not (p is Node3D) or bool(p.get("is_dead")) or p.get("riding") != null or p.get("pushing") != null:
		return ""
	if distance_from((p as Node3D).global_position) > 6.0:
		return ""
	if is_hitched():
		return "Unhitch the horse from the cart"
	var h := _near_horse()
	if h == null or _ridden(h):
		return ""
	return "Hitch the horse to the cart" if why_not_hitch(h) == "" else ""


## In the saddle: the ridden horse put to the cart (backed up to its shafts), or out of them.
func saddle_prompt(p: Node) -> String:
	var h := p.get("riding") as Horse if p else null
	if h == null:
		return ""
	if is_hitched():
		return "Unhitch the cart" if horse == h and absf(h.speed) < 0.4 else ""
	return "Hitch the cart" if why_not_hitch(h) == "" else ""


func highlight_targets() -> Array:
	return []


func interact(p: Node) -> bool:
	var h := p.get("riding") as Horse if p else null
	if is_hitched():
		if h != null and h != horse:
			return false
		unhitch()
		_notice(p, "The horse is out of the shafts")
		return true
	if h == null:
		h = _near_horse()
	if h == null:
		return false
	var why := why_not_hitch(h)
	if why != "":
		if why != ".":
			_notice(p, why)
		return false
	hitch(h)
	_notice(p, "The horse is put to the cart")
	return true


# --- E at the tailboard ----------------------------------------------------------------------------------------------

## What E at the tailboard can do now, the first the tap's: [{id, text, node}].
func bed_actions(p: Node) -> Array:
	var out: Array = []
	if p == null or bool(p.get("is_dead")) or p.get("riding") != null or p.get("pushing") != null:
		return out
	var tp := tail_point()
	var reach := 3.0
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		var a := n as Node3D
		if a == null or not CarcassLoad.haulable(a) or a.has_meta(&"on_chain"):
			continue
		if Vector2(a.global_position.x - tp.x, a.global_position.z - tp.z).length() < reach \
				and why_not_put("carcass", CarcassLoad.mass_of_animal(a, HorseHaul.data())) == "":
			out.append({"id": "carcass", "node": a, "text": "Put the %s in the cart" % CarcassLoad.name_of(a)})
			break
	for n in get_tree().get_nodes_in_group(FelledTree.GROUP):
		if not log_fits(n):
			continue
		var m := (n as SkidLoad).mid()
		if Vector2(m.x - tp.x, m.z - tp.z).length() < reach and why_not_put("log", (n as SkidLoad).mass_kg) == "":
			out.append({"id": "log", "node": n, "text": "Put the log in the cart"})
			break
	for n in get_tree().get_nodes_in_group(Wheelbarrow.GROUP):
		var w := n as Wheelbarrow
		if w == null or w.is_pushed() or w.has_meta(&"in_cart"):
			continue
		var g := w.global_position
		if Vector2(g.x - tp.x, g.z - tp.z).length() < reach and why_not_put("wheelbarrow", WHEELBARROW_KG + w.load_kg()) == "":
			out.append({"id": "wheelbarrow", "node": w, "text": "Put the wheelbarrow in the cart"})
	if not loads.is_empty():
		var last: Dictionary = loads[loads.size() - 1]
		out.append({"id": "take", "text": "Take the wheelbarrow out" if String(last.kind) == "wheelbarrow" else "Take out the %s" % name_of(last)})
	var n_items := total()
	out.append({"id": "open", "text": "Load the cart" + ("" if n_items == 0 else " (%d thing%s in it)" % [n_items, "" if n_items == 1 else "s"])})
	return out


func bed_action(p: Node, id: String) -> bool:
	for a: Dictionary in bed_actions(p):
		if String(a.id) != id:
			continue
		match id:
			"carcass":
				return put_carcass(a.node)
			"log":
				return put_log(a.node)
			"wheelbarrow":
				return put_barrow(a.node)
			"take":
				var n := take_out()
				if n:
					_notice(p, "The %s is out of the cart" % ("wheelbarrow" if n is Wheelbarrow else ("log" if n is SkidLoad else CarcassLoad.name_of(n))))
				return n != null
			"open":
				ChestScreen.open_for(p, self)
				return true
	return false


func _notice(p: Node, text: String) -> void:
	var it: Node = p.get("interactor") if p else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 2.5)


# --- The model -------------------------------------------------------------------------------------------------------

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
	var zl := BED_Z.y - BED_Z.x
	var zc := (BED_Z.x + BED_Z.y) * 0.5
	# the bed: a plank floor on two sills over the axle, sides and a front board, the tailboard
	_box(root, Vector3(BED_W, 0.04, zl), Vector3(0.0, BED_FLOOR, zc), Vector3.ZERO, wood)
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(0.09, 0.1, zl + 0.2), Vector3(s * 0.46, BED_FLOOR - 0.07, zc), Vector3.ZERO, dark)
		_box(root, Vector3(0.04, SIDE_H, zl), Vector3(s * (BED_W * 0.5), BED_FLOOR + SIDE_H * 0.5, zc), Vector3.ZERO, wood)
		# the stakes along the sides
		for k in 4:
			_box(root, Vector3(0.05, SIDE_H + 0.1, 0.05), Vector3(s * (BED_W * 0.5 + 0.03), BED_FLOOR + SIDE_H * 0.5,
					BED_Z.x + 0.15 + k * (zl - 0.3) / 3.0), Vector3.ZERO, dark)
	_box(root, Vector3(BED_W, SIDE_H, 0.04), Vector3(0.0, BED_FLOOR + SIDE_H * 0.5, BED_Z.y), Vector3.ZERO, wood)
	_box(root, Vector3(BED_W, SIDE_H * 0.7, 0.04), Vector3(0.0, BED_FLOOR + SIDE_H * 0.35, BED_Z.x), Vector3.ZERO, wood)
	# the axle
	_pole(root, Vector3(-WHEEL_X - 0.05, 0.0, 0.0), Vector3(WHEEL_X + 0.05, 0.0, 0.0), 0.04, iron)
	# the shafts: from under the bed forward to the tips, a crossbar at the front of the bed
	for s: float in [-1.0, 1.0]:
		var a := Vector3(s * 0.46, BED_FLOOR - 0.07, BED_Z.x + 0.1)
		var b := Vector3(s * SHAFT_X, SHAFT_UP, SHAFT_LEN)
		_pole(root, a, b, 0.035, wood)
	_pole(root, Vector3(-0.46, BED_FLOOR - 0.05, BED_Z.y + 0.15), Vector3(0.46, BED_FLOOR - 0.05, BED_Z.y + 0.15), 0.03, dark)
	# the wheels: a hub, twelve spokes, the felloes and an iron tyre
	for s: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "Wheel" + ("L" if s > 0.0 else "R")
		w.position = Vector3(s * WHEEL_X, 0.0, 0.0)
		root.add_child(w)
		_wheels.append(w)
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.08
		hm.bottom_radius = 0.1
		hm.height = 0.22
		hm.radial_segments = 12
		hub.mesh = hm
		hub.rotation = Vector3(0.0, 0.0, PI * 0.5)
		hub.material_override = dark
		w.add_child(hub)
		for k in 12:
			var ang := TAU * k / 12.0
			var d := Vector3(0.0, cos(ang), sin(ang))
			_pole(w, d * 0.08, d * (WHEEL_R - 0.06), 0.02, wood)
		var fel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = WHEEL_R - 0.08
		tm.outer_radius = WHEEL_R - 0.015
		tm.rings = 32
		fel.mesh = tm
		fel.rotation = Vector3(0.0, 0.0, PI * 0.5)
		fel.material_override = wood
		w.add_child(fel)
		var tyre := MeshInstance3D.new()
		var ty := TorusMesh.new()
		ty.inner_radius = WHEEL_R - 0.02
		ty.outer_radius = WHEEL_R
		ty.rings = 32
		tyre.mesh = ty
		tyre.rotation = Vector3(0.0, 0.0, PI * 0.5)
		tyre.material_override = iron
		w.add_child(tyre)


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


# --- Save (SaveParts "cart") --------------------------------------------------------------------------------------

## Where it stands, the goods in it, whether a horse is in the shafts, and what rides in the bed in the order it went
## in (the deer and the logs are saved where they lie by their own parts, the wheelbarrow by its own: each is found
## there again and taken back in).
func save_data() -> Dictionary:
	var ls := []
	for l: Dictionary in loads:
		var n: Node = l.node
		if not is_instance_valid(n):
			continue
		match String(l.kind):
			"log":
				ls.append({"kind": "log", "at": SaveParts.v3((n as SkidLoad).mid())})
			"carcass":
				ls.append({"kind": "carcass", "at": SaveParts.v3((n as Node3D).global_position)})
			"wheelbarrow":
				ls.append({"kind": "wheelbarrow"})
	return {"xf": SaveParts.xf(global_transform), "items": SaveParts.plain(items), "hitched": is_hitched(), "loads": ls}


## After the horse, the wildlife, the forest's loose logs and the wheelbarrow are back (SaveGame.PARTS).
func load_data(d: Dictionary) -> void:
	if is_hitched():
		unhitch()
	while take_out() != null:
		pass
	global_transform = SaveParts.to_xf(d.get("xf"))
	_last_axle = global_position
	items = (d.get("items", []) as Array).duplicate(true)
	_refresh_goods()
	var tree := get_tree()
	for e: Dictionary in d.get("loads", []):
		var at := SaveParts.to_v3(e.get("at"), bed_point())
		match String(e.get("kind", "")):
			"log":
				var s := _nearest(tree.get_nodes_in_group(FelledTree.GROUP), at,
						func(n: Node) -> bool: return n is SkidLoad and not (n is CarcassLoad) and not n.has_meta(&"in_barrow"),
						func(n: Node) -> Vector3: return (n as SkidLoad).mid()) as SkidLoad
				if s:
					_in_log(s)
			"carcass":
				var a := _nearest(tree.get_nodes_in_group(&"wildlife"), at,
						func(n: Node) -> bool: return n is Node3D and CarcassLoad.is_carcass(n) and not n.has_meta(&"on_chain"),
						func(n: Node) -> Vector3: return (n as Node3D).global_position) as Node3D
				if a:
					_in_carcass(a)
			"wheelbarrow":
				var w := Wheelbarrow.find(tree)
				if w and not w.has_meta(&"in_cart"):
					_in_barrow(w)
	if bool(d.get("hitched", false)):
		var best: Horse = null
		var bd := HITCH_REACH
		for h in (tree.current_scene if tree.current_scene else tree.root).find_children("*", "Horse", true, false):
			var hh := haul_of(h)
			var dd := tips_point().distance_to(harness_point(h))
			if hh and hh.load == null and (hh.cart == null or not is_instance_valid(hh.cart)) and dd < bd:
				best = h
				bd = dd
		if best:
			_attach(best)
	_seat_loads()


## The one of `nodes` that `ok` passes nearest `at` (by `where`), within 1.5 m (null: none).
static func _nearest(nodes: Array, at: Vector3, ok: Callable, where: Callable) -> Node:
	var best: Node = null
	var bd := 1.5
	for n: Node in nodes:
		if not ok.call(n):
			continue
		var dd := (where.call(n) as Vector3).distance_to(at)
		if dd < bd:
			best = n
			bd = dd
	return best


## The tailboard's own E (as the wheelbarrow's bed): the list of what it can do (hold E), the first on a tap.
class CartBed:
	extends Node
	var cart: HorseCart

	func _ready() -> void:
		add_to_group(PlacedWeapon.GROUP)

	func interact_point() -> Vector3:
		return cart.tail_point()

	func distance_from(pt: Vector3) -> float:
		var b := cart.tail_point()
		return Vector2(pt.x - b.x, pt.z - b.z).length()

	func interact_prompt(p: Node) -> String:
		# (asked of every interactable each tick: nothing to look for from afar)
		var b := cart.tail_point()
		if not (p is Node3D) or Vector2((p as Node3D).global_position.x - b.x, (p as Node3D).global_position.z - b.z).length() > 4.0:
			return ""
		var acts := cart.bed_actions(p)
		return String(acts[0].text) if not acts.is_empty() else ""

	func interact_actions(p: Node) -> Array:
		return cart.bed_actions(p).map(func(a: Dictionary) -> Dictionary: return {"id": String(a.id), "text": String(a.text)})

	func interact_action(p: Node, id: String) -> void:
		cart.bed_action(p, id)

	func highlight_targets() -> Array:
		return []

	func interact(p: Node) -> bool:
		var acts := cart.bed_actions(p)
		return not acts.is_empty() and cart.bed_action(p, String(acts[0].id))
