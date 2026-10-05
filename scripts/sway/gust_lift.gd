class_name GustLift
extends Node
## Gust held on a stone (docs/main_story.md 11.10; the owner, 2026-10-02: "i dont think we should have a levitate i think it
## should be the gust"; data/sway/moves.json gust.stone): the stone held up by the Sway and hurled. SwayCaster runs it as a
## hold (its state HOLDING) from Gust's full lock on a stone to the aim let go:
##   tear    at the full lock the stone tears free of the ground (chips and dust, a crack) and comes up
##   held    while the aim is held it rises on to rise_m over where it lay, turning slowly; it is drawn like a bowstring (the bow's
##           feel, Bow.draw_time / fatigue_start): `draw` fills 0..1 over draw_s; past strain_start_s the `strain` builds 0..1
##           to break_s (it shakes harder, the caster's aim trembles); at 1 the power breaks: broken() (SwayCaster drops it, the
##           caster staggers, the motes are lost)
##   hurl    the aim let go: it flies from where it hangs toward the crosshair at hurl.<kind>.mps (none drawn .. full draw), its
##           own gravity. A spike turns along its flight and goes through people like a lance (pierce: each struck once) and
##           sticks where it meets the world; a cannonball is heavier and goes farther, knocks people aside and on the ground
##           rolls (a rigid body again); any other stone lands and rolls. Every strike is Hit.deliver's (damage by the draw and
##           the speed left), the caster the source
##   drop    the hold broken (a hit, the strain, the caster gone): it falls where it hangs
## The stones (is_stone): a FormStone (Stone Form's spike or cannonball), a node in group BOULDERS (a ship's ballast and shot) or
## with meta sway_stone, or a small rock (a RigidBody3D whose meta surface is "stone" or "rock"); a crate or any other prop is
## no stone (Gust pushes it). Up to the stone's mass_kg one caster lifts it; heavier needs two (casters_needed: the hint
## "heavy"; the second caster's assist is a hook, not built). Group GROUP while it lives.
## Any caster (the owner, 2026-10-04: the ring's bots throw the same stones as the player): `caster` is a BendCaster (begin
## takes a SwayCaster, a BendCaster or a body: BendCaster.wrap), its own bodies (a fighter's hit parts too: exclude()) left out
## of the flight, never struck by its own stone. Whoever a stone strikes is knocked through BendStatus.knock (the one knock: the
## player as the bots, credited to the caster for the ring), flat along the flight at hurl.<kind>.knock_mps (KNOCK_MPS when
## the data gives none) and a little up (knock_up_mps). While it is held and flies it does not touch its caster nor whom it
## has struck (collision exceptions, taken off as it comes to rest): a held stone never shoves its caster, and a lance through
## a man goes through him, not carrying him along on its point.
## Round 2: a burrower under the deck (meta bend_under_until) is flown over; two casters' stones meeting in the air, the
## heavier goes on and the lighter drops (_meet_lifts; equal ones both).

signal struck(who: Node, damage: float)
signal landed(at: Vector3)

const GROUP := &"gust_lifts"
const BOULDERS := &"sway_boulders"
## The stone's meta while it is held or in flight (no second lock on it).
const BUSY_META := &"sway_lifted"
const FLIGHT_MAX_S := 6.0
## A spike's sweep moves out from its foot to its point over the first this many seconds of a flight (a stone hurled the
## moment it tore free still lies in the ground it came out of: its point does not meet that ground at once).
const LEAD_IN_S := 0.1
## A struck man's knock (m/s) along the flight, and up, when the hurl's data gives none (knock_mps, knock_up_mps).
const KNOCK_MPS := 6.0
const KNOCK_UP_MPS := 1.0

enum Phase { HELD, FLIGHT, DONE }

var caster: BendCaster
var stone: Node3D
## "spike", "cannonball" or "stone" (anything else).
var kind := "stone"
## Gust's stone data (moves.json gust.stone: hold, hurl, mass_kg, range_m, lock_s).
var d := {}
var phase := Phase.HELD
## Seconds since the tear.
var t := 0.0
## 0..1: how far it is drawn (the hurl's power), and the strain past strain_start_s.
var draw := 0.0
var strain := 0.0
## Where the crosshair is (world): the hurl goes toward it (INF: straight ahead of the caster).
var aim := Vector3.INF
var velocity := Vector3.ZERO
## The hurl's draw (kept from the let go) and who it has struck (instance ids).
var power := 0.0
var hit := {}
var radius := 0.3

var _start := Transform3D.IDENTITY
var _rb: RigidBody3D
var _was_frozen := false
var _mode := RigidBody3D.FREEZE_MODE_STATIC
var _fly_t := 0.0
var _ex: Array[RID] = []
var _rng := RandomNumberGenerator.new()
var _q: PhysicsShapeQueryParameters3D       ## the flight's sweep (made once)
var _lead_was := Vector3.ZERO               ## the sweep's lead last frame (the sweep runs on from where it ended)
var _excepted: Array[PhysicsBody3D] = []    ## bodies the stone does not touch while held and flying (its caster, whom it struck)


## Gust's stone data (moves.json gust.stone).
static func data() -> Dictionary:
	return SwayMoves.move("gust").get("stone", {})


## Whether `n` itself is a stone Gust lifts (see the header).
static func is_stone(n: Node) -> bool:
	if n == null:
		return false
	if n is FormStone or n.is_in_group(BOULDERS) or n.has_meta(&"sway_stone"):
		return true
	if n is RigidBody3D and not (n is DroppedTorch) and not n.is_in_group(SwayCaster.TARGET_GROUP):
		return String(n.get_meta(&"surface", "")) in ["stone", "rock"]
	return false


## The stone behind collider `c` (itself or a parent; null: none).
static func stone_of(c: Object) -> Node3D:
	var n := c as Node
	var depth := 0
	while n != null and depth < 5:
		if n is Node3D and is_stone(n):
			return n as Node3D
		n = n.get_parent()
		depth += 1
	return null


## The stone's mass (kg): meta sway_mass_kg, a rigid body's mass, else 0 (a scripted boulder of no weight given).
static func mass_of(s: Node) -> float:
	if s == null:
		return 0.0
	if s.has_meta(&"sway_mass_kg"):
		return float(s.get_meta(&"sway_mass_kg"))
	return (s as RigidBody3D).mass if s is RigidBody3D else 0.0


## How many casters it takes to lift `s` (mass_kg each, gust.stone's by default): 1, 2, ...
static func casters_needed(s: Node, md: Dictionary = {}) -> int:
	if md.is_empty():
		md = data()
	var lim := maxf(float(md.get("mass_kg", 90.0)), 1.0)
	return maxi(1, ceili(mass_of(s) / lim - 1e-4))


## Whether `s` is held or in flight now (no second lock on it).
static func busy(s: Node) -> bool:
	return s != null and s.has_meta(BUSY_META)


## Whether `s` can be lifted now: not held or flying, a FormStone risen out of the ground.
static func liftable(s: Node) -> bool:
	return s != null and not busy(s) and not (s is FormStone and not (s as FormStone).is_risen())


static func kind_of(s: Node) -> String:
	if s is FormStone:
		return (s as FormStone).kind
	return "stone"


## The hold begun on stone `s` by caster `c` (a SwayCaster, a BendCaster, a body; gust.stone's data `md`): torn free now.
## Null when there is no caster or no stone.
static func begin(c: Variant, s: Node3D, md: Dictionary = {}) -> GustLift:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid() or s == null or not is_instance_valid(s):
		return null
	var l := GustLift.new()
	l.name = "GustLift"
	l.caster = bc
	l.stone = s
	l.d = md if not md.is_empty() else data()
	l.kind = kind_of(s)
	l.add_to_group(GROUP)
	bc.body.get_tree().current_scene.add_child(l)
	l._take()
	return l


## The caster's body (null: gone), the striker of its blows.
func by() -> Node:
	return caster.body if caster != null and caster.body != null and is_instance_valid(caster.body) else null


## The way the caster faces (the player's body's, as ever; any other's: its facing), when there is no aim.
func _fwd() -> Vector3:
	var b := by() as Node3D
	if caster is PlayerBendCaster or b == null:
		return -b.global_basis.z if b != null else Vector3.FORWARD
	return caster.facing()


func _hold_d() -> Dictionary:
	return d.get("hold", {})


func _hurl_d() -> Dictionary:
	return (d.get("hurl", {}) as Dictionary).get(kind, (d.get("hurl", {}) as Dictionary).get("stone", {}))


func _take() -> void:
	_rng.seed = stone.get_instance_id()
	stone.set_meta(BUSY_META, true)
	_start = stone.global_transform
	if stone is FormStone:
		(stone as FormStone).take()
		radius = maxf((stone as FormStone).radius, 0.18)
	var aabb := _bounds(stone)
	if not (stone is FormStone):
		radius = clampf(maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 0.45, 0.12, 0.8)
	_rb = stone as RigidBody3D
	if _rb != null:
		_was_frozen = _rb.freeze
		_mode = _rb.freeze_mode
		_rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		_rb.freeze = true
		_rb.linear_velocity = Vector3.ZERO
		_rb.angular_velocity = Vector3.ZERO
	var scn := get_tree().current_scene
	var foot := FormEffects.ground_at(stone, stone.global_position)
	GatherFx.stone_chips(scn, foot + Vector3.UP * 0.1, Vector3.UP, 14)
	GatherFx.soil(scn, foot, Vector3.UP, 10)
	GatherFx.fall_dust(scn, foot, radius * 2.0)
	FormEffects.sfx("tear", foot, -2.0, 1.1)
	_ex = caster.exclude()                         # (the caster's capsule, and a fighter's hit parts)
	_except(by())
	if stone is CollisionObject3D:
		_ex.append((stone as CollisionObject3D).get_rid())


static func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		b = AABB(b.position - n.global_position, b.size)
		out = b if first else out.merge(b)
		first = false
	return out if not first else AABB(Vector3(-0.3, -0.3, -0.3), Vector3(0.6, 0.6, 0.6))


## The power broke: held past break_s.
func broken() -> bool:
	return phase == Phase.HELD and strain >= 1.0


## Where it hangs now (world).
func at() -> Vector3:
	return stone.global_position if is_instance_valid(stone) else Vector3.ZERO


func _physics_process(dt: float) -> void:
	if stone == null or not is_instance_valid(stone) or not stone.is_inside_tree():
		phase = Phase.DONE
		queue_free()
		return
	match phase:
		Phase.HELD:
			_held(dt)
		Phase.FLIGHT:
			_fly(dt)


# ---------------------------------------------------------------- held
func _held(dt: float) -> void:
	t += dt
	var h := _hold_d()
	var tear := float(h.get("tear_s", 0.35))
	var draw_s := maxf(float(h.get("draw_s", 0.9)), 0.05)
	var s0 := float(h.get("strain_start_s", 2.5))
	var s1 := maxf(float(h.get("break_s", 5.0)), s0 + 0.1)
	draw = clampf((t - tear) / draw_s, 0.0, 1.0)
	# (hold.no_break: held as long as the aim is, no strain and no break; Gust's, the user, 2026-10-03: "gust its hard and
	# unenjoyable", chose "easier Gust everywhere")
	strain = 0.0 if bool(h.get("no_break", false)) else clampf((t - s0) / (s1 - s0), 0.0, 1.0)
	var up := float(h.get("rise_m", 1.5)) * smoothstep(0.0, tear + draw_s, t)
	var shake := (0.012 + 0.05 * strain * strain) * (1.0 if t > tear else 1.6)
	var jitter := Vector3(sin(t * 41.0 + 1.0), sin(t * 37.0) * 0.6, cos(t * 47.0)) * shake
	var p := _start.origin + Vector3.UP * up + jitter
	var b := _start.basis
	if kind == "spike":
		# (the lance drawn: as it comes up it turns its point toward the aim)
		var to := (aim - p) if aim != Vector3.INF else _fwd()
		if to.length_squared() > 1e-4:
			var want := _point_along(to.normalized())
			b = b.slerp(want, smoothstep(0.0, 1.0, draw)).orthonormalized()
	else:
		b = Basis(Vector3.UP, t * 0.7) * Basis(Vector3.RIGHT, t * 0.35) * _start.basis
	stone.global_transform = Transform3D(b, p)


## A basis whose +Y (a spike's point) runs along `dir`.
static func _point_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


# ---------------------------------------------------------------- hurl
## Let go: hurled toward `toward` (world; INF: the caster's facing), shaken off by the strain.
func hurl(toward := Vector3.INF) -> void:
	if phase != Phase.HELD:
		return
	var hd := _hurl_d()
	var mps: Array = hd.get("mps", [12.0, 30.0])
	power = draw
	var from := stone.global_position
	var dir := ((toward if toward != Vector3.INF else from + _fwd() * 30.0) - from)
	dir = dir.normalized() if dir.length_squared() > 1e-6 else _fwd()
	var trem := deg_to_rad(float(_hold_d().get("tremble_deg", 1.2)) * (0.3 + 3.0 * strain))
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-trem, trem))
	var side := dir.cross(Vector3.UP)
	if side.length_squared() > 1e-6:
		dir = dir.rotated(side.normalized(), _rng.randf_range(-trem, trem))
	velocity = dir * lerpf(float(mps[0]), float(mps[1]), power)
	phase = Phase.FLIGHT
	_fly_t = 0.0
	FormEffects.sfx("hurl", from, 0.0, 0.7 if kind == "cannonball" else 1.0)
	GatherFx.fall_dust(get_tree().current_scene, from, radius * 1.5)


## The point that leads the flight, from the stone's origin (world offset): a spike's (its origin is its foot) most of the
## way to its tip along the flight, so a man is struck as the point reaches him and a wall met at the point; a ball's middle.
func _lead() -> Vector3:
	if kind != "spike" or velocity.length_squared() < 1e-6:
		return Vector3.ZERO
	var h := (stone as FormStone).height if stone is FormStone else 1.0
	return velocity.normalized() * h * 0.85


func _fly(dt: float) -> void:
	_fly_t += dt
	if _meet_lifts():
		return
	var hd := _hurl_d()
	velocity.y -= float(hd.get("gravity", 6.0)) * dt
	var lead := _lead() * smoothstep(0.0, LEAD_IN_S, _fly_t)
	var from := stone.global_position
	var to := from + velocity * dt
	var start := from + _lead_was
	var end := to + lead
	_lead_was = lead
	var space := stone.get_world_3d().direct_space_state
	if _q == null:
		_q = PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = radius * 0.85
		_q.shape = sph
		_q.collision_mask = 0xFFFFFFFF
		_q.collide_with_areas = false
	var q := _q
	q.exclude = _ex
	q.transform = Transform3D(Basis.IDENTITY, start)
	q.motion = end - start
	var frac := space.cast_motion(q)
	if frac.size() == 2 and frac[1] < 1.0:
		var c_at := start + (end - start) * frac[1]
		q.transform = Transform3D(Basis.IDENTITY, c_at)
		q.motion = Vector3.ZERO
		var info := space.get_rest_info(q)
		var col := instance_from_id(int(info.get("collider_id", 0))) as Node if not info.is_empty() else null
		if col == null:
			# (met nothing it can name: flown on, never left hanging where it stopped; FLIGHT_MAX_S ends it)
			if info.has("rid"):
				_ex.append(info.rid)
			_place(to)
			if _fly_t > FLIGHT_MAX_S or to.y < -200.0:
				_land(to, Vector3.UP, to)
			return
		var who := FormSpikes.taker(col, caster)
		var body := who is CharacterBody3D or who is NpcFighter or who is WildAnimal
		if body and BendStatus.until(who, &"bend_under_until") > 0.0:
			# (a burrower under the deck: the stone passes over him; round 2's Burrow)
			_except(who)
			if info.has("rid"):
				_ex.append(info.rid)
			_place(to)
			return
		if body:
			_except(who)                        # (through him or past him: never carrying him on)
			_strike(col, who, c_at)
			if info.has("rid"):
				_ex.append(info.rid)
			if who is CollisionObject3D:
				_ex.append((who as CollisionObject3D).get_rid())
			if not bool(hd.get("pierce", false)):
				velocity *= 0.65                    # (a ball knocks a man down and goes on, slowed)
			_place(to)
			return
		# the world (a raised wall too: struck, then it stops there)
		if who != null:
			_strike(col, who, c_at)
		_land(from + (to - from) * frac[0], Vector3(info.get("normal", Vector3.UP)), Vector3(info.get("point", c_at)))     # (the touch itself)
		return
	_place(to)
	if _fly_t > FLIGHT_MAX_S or to.y < -200.0:
		_land(to, Vector3.UP, to)


## Another caster's flying stone met in the air (round 2: the bigger stone wins, light < medium < heavy, equal ones both
## break; BendBolt.weight_of): the lighter one drops where it is. True when this one dropped.
func _meet_lifts() -> bool:
	for o in get_tree().get_nodes_in_group(GROUP):
		var l := o as GustLift
		if l == null or l == self or l.phase != Phase.FLIGHT or l.get_instance_id() < get_instance_id() or l.stone == null \
				or not is_instance_valid(l.stone) or l.by() == by():
			continue
		if l.stone.global_position.distance_to(stone.global_position) > radius + l.radius + 0.25:
			continue
		var wa := int(BendBolt.WEIGHTS.get(BendBolt.weight_of(self), 1))
		var wb := int(BendBolt.WEIGHTS.get(BendBolt.weight_of(l), 1))
		BendLooks.burst((stone.global_position + l.stone.global_position) * 0.5, "stone", 22)
		if wb <= wa:
			l.drop()
		if wa <= wb:
			drop()
			return true
	return false


func _place(p: Vector3) -> void:
	var b := stone.global_basis
	if kind == "spike" and velocity.length_squared() > 0.5:
		b = _point_along(velocity)
	elif kind != "spike":
		var spin := velocity.length() * 0.05
		b = Basis(Vector3.UP.cross(velocity).normalized() if Vector3.UP.cross(velocity).length_squared() > 1e-6 else Vector3.RIGHT, spin) * b
	stone.global_transform = Transform3D(b.orthonormalized(), p)


## The damage of a strike at the speed it has now.
func damage_now() -> float:
	var hd := _hurl_d()
	var dm: Array = hd.get("damage", [20.0, 60.0])
	var mps: Array = hd.get("mps", [12.0, 30.0])
	var k := clampf(velocity.length() / maxf(float(mps[1]), 0.1), 0.25, 1.0)
	return lerpf(float(dm[0]), float(dm[1]), power) * k


func _strike(col: Node, who: Node, p: Vector3) -> void:
	if who == null or hit.has(who.get_instance_id()):
		return
	hit[who.get_instance_id()] = true
	var dmg := damage_now()
	var dir := velocity.normalized() if velocity.length_squared() > 1e-6 else Vector3.FORWARD
	var src := by()
	Hit.deliver(col, dmg, p, dir, src)
	struck.emit(who, dmg)
	FormEffects.sfx("strike", p, 0.0, 0.8 if kind == "cannonball" else 1.1)
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else Vector3.FORWARD
	var hd := _hurl_d()
	var kv := flat * float(hd.get("knock_mps", KNOCK_MPS)) + Vector3.UP * float(hd.get("knock_up_mps", KNOCK_UP_MPS))
	if who is NpcFighter and not (who as NpcFighter).is_dead():
		# (knocked as the player is, credited to the caster; staggered as ever)
		var f := who as NpcFighter
		if f.launch(kv, src) and f.action != "flinch":
			f._flinch(flat)
	elif who is FrontierPlayer:
		BendStatus.knock(who, kv, src)
	elif who is WildAnimal and not (who as WildAnimal).is_dead():
		SwayEffects.shove_animal(who as WildAnimal, flat * (5.0 if kind == "cannonball" else 2.5), p - flat)


## It meets the world at `p` (its middle; `contact` the touch): a spike sticks there along its flight; a ball or a stone is in
## the physics again with what is left of its speed (it rolls).
func _land(p: Vector3, n: Vector3, contact: Vector3) -> void:
	phase = Phase.DONE
	var scn := get_tree().current_scene
	GatherFx.stone_chips(scn, contact, n, 12)
	GatherFx.fall_dust(scn, contact, radius * 1.6)
	FormEffects.sfx("strike", contact, -2.0, 0.7)
	if kind == "spike":
		var dir := velocity.normalized() if velocity.length_squared() > 1e-6 else Vector3.DOWN
		var b := _point_along(dir)
		# (its point a third of the way into what it met, the rest standing out of it)
		var h := (stone as FormStone).height if stone is FormStone else 1.0
		stone.global_transform = Transform3D(b, contact - dir * h * 0.7)
		if stone is FormStone:
			(stone as FormStone).rest_again()
	else:
		_place(p)
		if _rb != null:
			_rb.freeze = false
			_rb.freeze_mode = _mode
			var v := velocity
			var vn := n * v.dot(n)
			v = (v - vn) * 0.8 - vn * 0.2               # (the bounce taken out, the roll kept)
			_rb.linear_velocity = v
			var axis := n.cross(v)
			_rb.angular_velocity = axis.normalized() * v.length() / maxf(radius, 0.1) if axis.length_squared() > 1e-6 else Vector3.ZERO
			_rb.sleeping = false
		if stone is FormStone:
			(stone as FormStone).rest_again()
	_release_stone()
	landed.emit(contact)
	queue_free()


## The hold broken: it falls where it hangs. In flight too (a Catch, a deflect, a cushion took it: BendZone): it stops there
## and falls, its flight over.
func drop(fx := true) -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	if stone != null and is_instance_valid(stone):
		if fx and is_inside_tree():
			var scn := get_tree().current_scene
			GatherFx.fall_dust(scn, stone.global_position, radius * 2.0)
			FormEffects.sfx("break", stone.global_position, 0.0, 0.9)
		if _rb != null:
			_rb.freeze_mode = _mode
			_rb.freeze = false
			_rb.linear_velocity = Vector3.DOWN * 0.5
			_rb.sleeping = false
		elif fx and stone.is_inside_tree():
			stone.global_position = FormEffects.ground_at(stone, stone.global_position)
		if stone is FormStone:
			(stone as FormStone).rest_again()
		_release_stone()
	if is_inside_tree():
		queue_free()


## The stone does not touch `b` until it comes to rest (a PhysicsBody3D: the caster, whom it struck).
func _except(b: Node) -> void:
	if stone is PhysicsBody3D and b is PhysicsBody3D and b != stone and is_instance_valid(b) and not _excepted.has(b):
		(stone as PhysicsBody3D).add_collision_exception_with(b)
		_excepted.append(b as PhysicsBody3D)


func _release_stone() -> void:
	if stone is PhysicsBody3D and is_instance_valid(stone):
		for b in _excepted:
			if is_instance_valid(b):
				(stone as PhysicsBody3D).remove_collision_exception_with(b)
	_excepted.clear()
	if stone != null and is_instance_valid(stone):
		stone.remove_meta(BUSY_META)
		if _rb != null and _was_frozen and stone.has_meta(&"sway_keep_frozen"):
			_rb.freeze = true


func _exit_tree() -> void:
	if phase == Phase.HELD:
		drop(false)
