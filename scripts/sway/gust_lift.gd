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
## Online (NetStones, docs/tidebreak/ring_netcode.md "Stones"): a flight is run alike on every machine (its throw is in a
## cast's run, or the host's word); only the host's strikes, meets another stone, slows on a man or bursts on him. A ghost's
## flight passes bodies, lands and bursts on the world as the host's will, and is stopped by the host's word (net_stop: its
## stone's place told; net_burst: it burst where the host's did). No machine but the host lets a stone roll.

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
	if not bool(stone.get_meta(&"sbfx_rise", false)):        # (its Spellbreak rise played instead: FormEffects, SbFx)
		GatherFx.stone_chips(scn, foot + Vector3.UP * 0.1, Vector3.UP, 14)
		GatherFx.soil(scn, foot, Vector3.UP, 10)
		GatherFx.fall_dust(scn, foot, radius * 2.0)
	if stone.has_meta(&"sbfx_rise"):
		stone.remove_meta(&"sbfx_rise")
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
	_hurl_from = from
	FormEffects.sfx("hurl", from, 0.0, 0.7 if kind == "cannonball" else 1.0)
	GatherFx.fall_dust(get_tree().current_scene, from, radius * 1.5)
	# (the Spellbreak flight, SbFx: visual only, keyed by its Throw's hit info; a held stone thrown back by the catch's own)
	var sbk := SbFx.key_of(get_meta(&"bend_info", {}))
	var sbo := {"node": stone, "dir": velocity, "info": get_meta(&"bend_info", {})}
	if not (sbk.ends_with(".return") and SbFx.start(self, "flight", by(), "stone_catch/catch", "return_flight", sbo.merged({"el": "earth"}))):
		SbFx.start(self, "flight", by(), sbk, "flight", sbo)


## The point that leads the flight, from the stone's origin (world offset): a spike's (its origin is its foot) most of the
## way to its tip along the flight, so a man is struck as the point reaches him and a wall met at the point; a ball's middle.
func _lead() -> Vector3:
	if kind != "spike" or velocity.length_squared() < 1e-6:
		return Vector3.ZERO
	var h := (stone as FormStone).height if stone is FormStone else 1.0
	return velocity.normalized() * h * 0.85


func _fly(dt: float) -> void:
	_fly_t += dt
	var ghost := not NetSpells.decides()
	if not ghost and _meet_lifts():
		return
	if not heated and not ghost and BendLoadout.wears(by(), BendZone.KILN_STONE):
		_kiln_check()
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
		if body and ghost:
			# (a ghost's flight passes him: the host's strike and its word decide)
			_except(who)
			if info.has("rid"):
				_ex.append(info.rid)
			_place(to)
			return
		if body and BendStatus.until(who, &"bend_under_until") > 0.0:
			# (a burrower under the deck: the stone passes over him; round 2's Burrow)
			_except(who)
			if info.has("rid"):
				_ex.append(info.rid)
			_place(to)
			return
		if body:
			_except(who)                        # (through him or past him: never carrying him on)
			var first_hit := not hit.has(who.get_instance_id())
			_strike(col, who, c_at)
			# A fighter has a capsule, torso and head. Exclude all of them after
			# contact so its reaction pose cannot slow the same stone again.
			if who.has_method(&"ray_exclude"):
				_ex.append_array(who.call(&"ray_exclude"))
			if info.has("rid"):
				_ex.append(info.rid)
			if who is CollisionObject3D:
				_ex.append((who as CollisionObject3D).get_rid())
			if first_hit and _shatters():
				_shatter(c_at, -velocity.normalized() if velocity.length_squared() > 1e-6 else Vector3.UP)
				return                              # (the ring: it bursts on him)
			if first_hit and not bool(hd.get("pierce", false)):
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
		var mid := (stone.global_position + l.stone.global_position) * 0.5
		if not SbFx.fire(by(), "clash/stone", "clash", {"at": mid, "el": "earth", "node": stone}):
			BendLooks.burst(mid, "stone", 22)
		BendZone.BendGas.clash(by(), l.by(), mid)          # (the Sulphur set: a cloud where his stones clash with a foe's)
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
	SbFx.fire(src, SbFx.key_of(get_meta(&"bend_info", {})), "hit", {"at": p, "dir": dir, "node": stone})
	if RingRules.stock_on() and (who is FrontierPlayer or who is NpcFighter):
		# (round 3, the % ring: the hit with its info, meta bend_info from its Throw: BendR3.deliver; AIR)
		var fl := Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length_squared() > 1e-6 else Vector3.FORWARD
		var hd0 := _hurl_d()
		BendR3.deliver(who, dmg, p, dir, src, -1.0, fl * float(hd0.get("knock_mps", KNOCK_MPS)) + Vector3.UP * float(hd0.get("knock_up_mps", KNOCK_UP_MPS)),
				get_meta(&"bend_info", {}))
		struck.emit(who, dmg)
		FormEffects.sfx("strike", p, 0.0, 0.8 if kind == "cannonball" else 1.1)
		return
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
	if _shatters():
		_avalanche(contact, n)                   # (Avalanche worn: three stones roll on from where it lands)
		_shatter(contact, n)                     # (the ring: it bursts on what it met, nothing left lying)
		return
	phase = Phase.DONE
	_gas_end(contact)
	var scn := get_tree().current_scene
	var sbk := SbFx.key_of(get_meta(&"bend_info", {}))
	SbFx.stop(self, "flight")
	if not SbFx.fire(by(), sbk, "land", {"at": contact, "normal": n, "dir": velocity, "node": stone}):
		GatherFx.stone_chips(scn, contact, n, 12)
		GatherFx.fall_dust(scn, contact, radius * 1.6)
	if kind != "spike":
		SbFx.start(stone, "roll", by(), sbk, "roll", {"node": stone, "dir": velocity})
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
		if _rb != null and NetSpells.decides():
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


## Kiln Stone (BendZone.KILN_STONE): heated by fire it flew through (its hit info says so; a fire trail on the stone) until it
## lands; douse() a plain stone again (a Turn).
var heated := false
var _kiln_trail: GPUParticles3D
## Where its flight began (hurl), for Sulphur Boulder's trail (BendZone.BendGas.stone_end).
var _hurl_from := Vector3.INF


## Its stone stopped at `at` (a burst on a body, the deck, a wall; a landing): the Sulphur set's gas where a wearer's own Spike
## or Boulder stops (BendGas.stone_end; never a returned stone).
func _gas_end(at: Vector3) -> void:
	var inf: Dictionary = get_meta(&"bend_info", {})
	if String(inf.get("tag", "")).begins_with("stone_form/") and not bool(inf.get("returned", false)) and NetSpells.decides():
		BendZone.BendGas.stone_end(by() as Node3D, kind, at, _hurl_from)


func _kiln_check() -> void:
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind in BendZone.KILN_FIRES and not bz.is_queued_for_deletion() and bz.inside(stone.global_position):
			heat()
			return


func heat() -> void:
	if heated or stone == null or not is_instance_valid(stone):
		return
	heated = true
	var inf: Dictionary = (get_meta(&"bend_info", {}) as Dictionary).duplicate()
	inf["heated"] = true
	set_meta(&"bend_info", inf)
	_kiln_trail = BendLooks.trail(stone, "fire", radius)
	BendLooks.burst(stone.global_position, "fire", 10, -velocity.normalized(), 60.0, 2.0, 0.2)


func douse() -> void:
	if not heated:
		return
	heated = false
	var inf: Dictionary = (get_meta(&"bend_info", {}) as Dictionary).duplicate()
	inf.erase("heated")
	set_meta(&"bend_info", inf)
	BendLooks.stop_trail(_kiln_trail)
	_kiln_trail = null
	if stone != null and is_instance_valid(stone):
		BendLooks.burst(stone.global_position, "steam", 12, Vector3.UP, 90.0, 1.5, 0.4)


## Earth's Avalanche (data/sway/skill_tree.json earth.boulder.avalanche; the owner, 2026-10-11: "make sure all the talents
## work"): its wearer's Boulder that lands on the deck (a floor under it, not a wall's face; never a returned stone) breaks into
## three stones that roll on along the deck from there, fanned AVALANCHE_DEG apart about its flight: low stone bolts (BendBolt
## low: jumped, stopped by walls, taken by a Catch: BendZone keeps only one of a volley, the rest dropped at the catcher's feet,
## the thrower's loose stones), one volley (a fresh volley_id, volley_n 3: together the Boulder's %, only the first to hit
## knocks; the node's class base for its wearer). Online the host's. The Boulder in flight is one Boulder (its own hit whole:
## FormEffects marks its info volley_n 1).
const AVALANCHE := "earth.boulder.avalanche"
const AVALANCHE_DEG := 15.0
const AVALANCHE_ROLL := {"mps": 12.0, "range_m": 8.0, "radius_m": 0.18}


func _avalanche(at: Vector3, n: Vector3) -> void:
	var by_n := by() as Node3D
	var inf: Dictionary = get_meta(&"bend_info", {})
	if kind != "cannonball" or by_n == null or n.y < 0.5 or not BendLoadout.wears(by_n, AVALANCHE) \
			or not String(inf.get("tag", "")).begins_with("stone_form/cannonball") or bool(inf.get("returned", false)) \
			or not NetSpells.decides():
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.normalized() if flat.length_squared() > 1e-4 else caster.facing()
	var vi := inf.duplicate()
	vi.erase("heated")                           # (a Kiln Stone's heat ends where the Boulder lands)
	vi["volley_id"] = BendR3.new_volley()
	vi["volley_n"] = 3
	vi["avalanche"] = true
	var hd := _hurl_d()
	var r := float(AVALANCHE_ROLL.radius_m)
	for i in 3:
		var dir := flat.rotated(Vector3.UP, deg_to_rad(AVALANCHE_DEG * float(i - 1)))
		var spec := {"kind": "stone", "low": true, "mps": float(AVALANCHE_ROLL.mps), "range_m": float(AVALANCHE_ROLL.range_m),
				"radius_m": r, "damage": damage_now() / 3.0, "knock_mps": float(hd.get("knock_mps", KNOCK_MPS)), "up_mps": 1.0,
				"weight": "medium", "flight": "spinning", "spin_rate": float(AVALANCHE_ROLL.mps) / r, "spin_axis": Vector3.RIGHT,
				"_info": vi}
		BendBolt.launch(by_n, Vector3(at.x, at.y + BendBolt.LOW_M, at.z) + dir * 0.35, dir, spec)
	BendLooks.burst(at + Vector3.UP * 0.2, "stone", 16, Vector3.UP, 120.0, 3.0, 0.3)


## A stone piece's look for the bursts: jagged shards of each ground's stone (six, made once: about 0.25 m long, scaled per
## piece), so the burst reads as broken stone, not pebbles.
static var _chunk_cache := {}


static func _chunk_mesh(matter: String, i: int) -> Mesh:
	if not _chunk_cache.has(matter):
		var list: Array = []
		for j in 6:
			list.append(FormModels.spike_mesh(0.09 + 0.015 * float(j % 3), 0.2 + 0.05 * float(j % 2), 13 + j * 7, 0.0, matter))
		_chunk_cache[matter] = list
	var l: Array = _chunk_cache[matter]
	return l[i % l.size()]


## Whether this stone bursts on what it meets (moves.json stone_form.shatter; the owner, 2026-10-10: "the boulders and rocks
## they need to explode", shatter on impact): a Spike's or a Boulder's (a FormStone) in the ring (ring_only), a deck socket's
## stone hurled too.
func _shatters() -> bool:
	var sd := shatter_d()
	if sd.is_empty() or not (stone is FormStone) or not is_inside_tree():
		return false
	return not bool(sd.get("ring_only", true)) or RingArena.find(get_tree()) != null


static func shatter_d() -> Dictionary:
	var v: Variant = SwayMoves.move("stone_form").get("shatter", {})
	return v if v is Dictionary else {}


## It bursts at `at` (`n` the face it met): chips, dust, stone bits and a few pieces flung out that fade, a crack; the stone
## gone. Bigger for a grown one (its scale). Its hit was struck before (_strike); `landed` is told as a landing's is.
func _shatter(at: Vector3, n: Vector3) -> void:
	phase = Phase.DONE
	SbFx.stop(self, "flight")
	_gas_end(at)
	var sd := shatter_d()
	var k := float(stone.get_meta(FormEffects.GROWN_META, 1.0)) if stone != null and is_instance_valid(stone) else 1.0
	var scn := get_tree().current_scene
	var dir := velocity.normalized() if velocity.length_squared() > 1e-6 else Vector3.DOWN
	var out := (n - dir * 0.6).normalized() if (n - dir * 0.6).length_squared() > 1e-4 else Vector3.UP
	GatherFx.stone_chips(scn, at, n, int(float(sd.get("chips", 24)) * k))
	GatherFx.fall_dust(scn, at, float(sd.get("dust_m", 1.8)) * k)
	BendLooks.burst(at, "stone", int(float(sd.get("burst_n", 36)) * k), out, 150.0, float(sd.get("burst_mps", 6.5)) * sqrt(k),
			float(sd.get("burst_size", 0.5)) * k)
	GatherFx.fall_dust(scn, at + Vector3.UP * 0.4 * k, float(sd.get("dust_m", 1.8)) * k * 0.7)
	FormEffects.sfx("break", at, 2.0, 0.9 / sqrt(k))
	FormEffects.sfx("strike", at, -1.0, 0.75)
	var matter := (stone as FormStone).matter if stone is FormStone else "stone"
	_chunks(scn, at, out, k, matter, sd)
	_release_stone()
	landed.emit(at)
	if stone != null and is_instance_valid(stone):
		stone.queue_free()
	queue_free()


## A few pieces of the stone flung out from `at` round `out`, falling under the flight's own gravity and shrinking away over
## chunk_life_s (looks only: no body).
static func _chunks(scn: Node, at: Vector3, out: Vector3, k: float, matter: String, sd: Dictionary) -> void:
	if scn == null or DisplayServer.get_name() == "headless":
		return
	var n := int(float(sd.get("chunks", 7)) * k)
	var life := float(sd.get("chunk_life_s", 1.3))
	var ar := RingArena.find(scn.get_tree())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var side := out.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-4 else Vector3.RIGHT
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = _chunk_mesh(matter, i)
		var sz := rng.randf_range(0.8, 2.0) * k
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scn.add_child(mi)
		mi.global_position = at
		var a := rng.randf_range(-PI, PI)
		var d := (out + side.rotated(out, a) * rng.randf_range(0.4, 1.0)).normalized()
		var v0 := d * float(sd.get("chunk_mps", 5.5)) * rng.randf_range(0.6, 1.2) + Vector3.UP * float(sd.get("chunk_up_mps", 3.5)) * rng.randf_range(0.5, 1.1)
		var spin := Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		var tw := mi.create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(mi):
				var p := at + v0 * t + Vector3.DOWN * 9.0 * t * t
				if ar != null and is_instance_valid(ar) and ar.on_deck(p):
					p.y = maxf(p.y, ar.deck_y() + ar.floor_at(p) + 0.05)    # (it lands on the deck, a piece, a step)
				mi.global_position = p
				mi.rotation = spin * t
				mi.scale = Vector3.ONE * sz * clampf(1.0 - pow(t / life, 3.0), 0.01, 1.0), 0.0, life, life)
		tw.tween_callback(mi.queue_free)


## The hold broken: it falls where it hangs. In flight too (a Catch, a deflect, a cushion took it: BendZone): it stops there
## and falls, its flight over.
func drop(fx := true) -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	SbFx.stop(self, "flight")
	if stone != null and is_instance_valid(stone):
		if fx and is_inside_tree():
			var scn := get_tree().current_scene
			# (the entry grounds the point itself (at "ground"), only when it plays: no rays while the effects are off)
			if not SbFx.fire(by(), "stone_form/drop", "drop", {"at": stone.global_position, "el": "earth", "node": stone}):
				GatherFx.fall_dust(scn, stone.global_position, radius * 2.0)
			FormEffects.sfx("break", stone.global_position, 0.0, 0.9)
		if _rb != null and NetSpells.decides():
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
	if _kiln_trail != null:
		BendLooks.stop_trail(_kiln_trail)        # (Kiln Stone: the heat ends where it lands)
		_kiln_trail = null
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


# ---------------------------------------------------------------- online (see the header)
## The host's word that its flight is over (a ghost's): stopped where it is, nothing played (the stone's place is the word's).
func net_stop() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	SbFx.stop(self, "flight")
	_release_stone()
	if stone is FormStone and is_instance_valid(stone):
		(stone as FormStone).rest_again()
	queue_free()


## The host's word that its stone burst at `at` (a ghost's): its burst played there, the stone gone.
func net_burst(at: Vector3) -> void:
	if phase == Phase.DONE:
		return
	_shatter(at, -velocity.normalized() if velocity.length_squared() > 1e-6 else Vector3.UP)
