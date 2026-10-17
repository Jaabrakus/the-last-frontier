class_name BendMotion
extends Node
## The bender's own movement for a while (BendEffects' dash and buff; on any body that bends: BendMotion.of, the player's or a
## bot's): a dash's speed carried on through the body's own easing (carry), a slow fall (fall: hover, glide), a fast pace (run:
## wind run, the air scooter, along `facing`: the player's camera, a bot's own way). Each frame before the body moves
## (process_physics_priority): its own easing takes it from there.
## ROUND 2: a dash's END is kept (dash_began: a low dash ends with its carry, one thrown up as it lands again: a Leap, a
## Jets jump): an air fighter's Carried wind is charged then (BendZone.carry_wind; meta bend_dash_end), and glide(fall, s,
## held) is Leap's slow fall while `held` (jump) says so.

var body: CharacterBody3D
## The dash running: 0 none, 1 low (ends with its carry), 2 up (ends on landing, once it has left the ground).
var _dash := 0
var _dash_left := false
var _glide_held: Callable
## The way a run goes (a flat Vector3): the player's camera's; else the body's facing.
var facing: Callable
var _carry := Vector3.ZERO
var _carry_t := 0.0
var _fall := INF
var _fall_t := 0.0
var _run := 0.0
var _run_t := 0.0
var _fx: GPUParticles3D


static func of(n: CharacterBody3D) -> BendMotion:
	var m := n.get_node_or_null(^"BendMotion") as BendMotion
	if m == null:
		m = BendMotion.new()
		m.name = "BendMotion"
		m.body = n
		m.facing = m._default_facing
		m.process_physics_priority = -5
		n.add_child(m)
	return m


func carry(v: Vector3, s: float) -> void:
	_carry = Vector3(v.x, 0.0, v.z)
	_carry_t = s
	_watch_short(s)


## The slide after a dash, a run or a ride watched for a body in its way for `s` + SHORT_S (its own easing carries him on
## after the carry: _stop_short).
var _short_until := -INF
var _short_from := -INF
const SHORT_S := 1.0
func _watch_short(s: float) -> void:
	_short_from = BendStatus.now()
	_short_until = _short_from + s + SHORT_S


func fall(mps: float, s: float, kind: String) -> void:
	_fall = mps
	_fall_t = s
	_glide_held = Callable()
	_trail(kind)


func run(mps: float, s: float, kind: String) -> void:
	_run = mps
	_run_t = s
	_watch_short(s)
	_trail(kind)


## A dash began (BendEffects.dash) with `up_mps` up: its end watched (see the header).
func dash_began(up_mps: float) -> void:
	_dash = 2 if up_mps >= 2.0 else 1
	_dash_left = false


## Leap's glide: a fall no faster than `mps` for up to `s` while `held` (a Callable -> bool: the jump key) says so, once
## off the ground.
func glide(mps: float, s: float, held: Callable) -> void:
	_fall = mps
	_fall_t = s
	_glide_held = held


## The dash's end now (see the header): its time kept, Carried wind charged for an air fighter.
func _dash_end() -> void:
	_dash = 0
	body.set_meta(&"bend_dash_end", BendStatus.now())
	SbFx.dash_ended(body)                     # (its Spellbreak trails stopped, its end played: visual only)
	BendZone.carry_wind(body)
	if FireTalents.any(body):
		FireTalents.dash_ended(body)          # (a worn talent where the dash ends: Magma Landing's seam)


func active() -> bool:
	return _carry_t > 0.0 or _fall_t > 0.0 or _run_t > 0.0 or _ride_t > 0.0


## Carried by a ride now (SwayCaster lifts a cast pose's root meanwhile).
func riding() -> bool:
	return _ride_t > 0.0


## A ride (Ride the Wave, a skill tree technique): carried `m` m along `dir` (flat) over `s` s on top of his own way, then his own
## speed again (no carry eased on after it). Foam at his feet meanwhile. A knock's carry (BendKnock: kv, kept apart from his own
## way) is never his own way: the ride keeps it in his velocity as the knock left it (applied), so his controller takes out and
## adds back exactly the knock; a knock taken during the ride ends it there (the hit sets his motion as anyone's: _ride_step).
var _ride := Vector3.ZERO
var _ride_t := 0.0
var _ride_keep := Vector3.ZERO
var _ride_from := -INF
func ride(dir: Vector3, m: float, s: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var kn := BendKnock.peek(body)
	var own := kn.base_of(body.velocity) if kn != null else body.velocity     # (his own way: a knock's carry left out)
	_ride_keep = Vector3(own.x, 0.0, own.z)
	_ride = flat * m / maxf(s, 0.01)
	_ride_t = maxf(s, 0.01)
	_ride_from = BendStatus.now()
	_watch_short(s)
	_trail("water")


## A dash's speed being carried now (the player's legs' clip speed does not cap it meanwhile: FrontierPlayer).
func carrying() -> bool:
	return _carry_t > 0.0


func _trail(kind: String) -> void:
	if kind == "":
		return                                 # (a Spellbreak ride drawn instead: BendEffects.buff, SbFx)
	if _fx == null or not is_instance_valid(_fx):
		# (water's movement draws water's first trail, "surf": the Lash's is the charge's wisps, BendLooks._make_trail)
		_fx = BendLooks.trail(body, "surf" if kind == "water" else kind, 0.35, kind == "fire")
		if _fx != null:
			_fx.position = Vector3.UP * 0.3


## Down or out of it: a player's is_dead, a fighter's is_dead().
func _dead() -> bool:
	if body.has_method(&"is_dead"):
		return bool(body.call(&"is_dead"))
	return bool(body.get(&"is_dead"))


## The player's camera's way (as his run always went), else the body's facing.
func _default_facing() -> Vector3:
	var cam: Variant = body.get(&"camera")
	var fwd := -body.global_basis.z
	if cam is Camera3D and is_instance_valid(cam):
		fwd = -(cam as Camera3D).global_basis.z
	elif body.has_method(&"forward"):
		fwd = body.call(&"forward")
	return fwd


func _physics_process(dt: float) -> void:
	if body == null or _dead():
		return
	if not NetSpells.owns(body):
		_puppet_tick(dt)                          # (online another machine's fighter: his motion is his machine's)
		return
	if body.has_meta(&"bend_slam_lift") and body.is_on_floor():
		body.remove_meta(&"bend_slam_lift")       # (round 3: Down Gust's lift is once an airtime; landing gives it back)
	if _carry_t > 0.0:
		_carry_t -= dt
		var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if flat.length() < _carry.length():
			body.velocity.x = _carry.x
			body.velocity.z = _carry.z
	if _ride_t > 0.0:
		_ride_step(dt)
	if BendStatus.now() < _short_until:
		var kn := BendKnock.peek(body)
		if kn != null and kn.last_knock_at >= _short_from:
			_short_until = -INF                   # (knocked since: the blow's motion, never cut)
		else:
			_stop_short(dt)
	if _dash == 1 and _carry_t <= 0.0:
		_dash_end()
	elif _dash == 2:
		if not body.is_on_floor():
			_dash_left = true
		elif _dash_left:
			_dash_end()
	if _fall_t > 0.0:
		_fall_t -= dt
		var gliding := not _glide_held.is_valid() or bool(_glide_held.call())
		if not gliding:
			_fall_t = 0.0                          # (the jump key let go: the glide is over)
		elif body.velocity.y < -_fall:
			body.velocity.y = -_fall
	if _run_t > 0.0:
		_run_t -= dt
		var fwd: Vector3 = facing.call() if facing.is_valid() else -body.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
		var along := flat.dot(fwd)
		if along < _run and flat.length() > 0.5:
			body.velocity.x += fwd.x * (_run - along) * minf(1.0, dt * 8.0)
			body.velocity.z += fwd.z * (_run - along) * minf(1.0, dt * 8.0)
	if not active() and _fx != null and is_instance_valid(_fx):
		BendLooks.stop_trail(_fx)
		_fx = null


## A dash, a run or a ride (and the slide after it, _watch_short) stops SHORT_M before a body in its way (fighters pass
## through each other: Burrow, Surf and Jets ended inside the foe, the move review 2026-10-12): what is left of it ended,
## his speed toward that body cut to what reaches SHORT_M. Not one far above or below (a jet jump over him).
const SHORT_M := 1.0
func _stop_short(dt: float) -> void:
	var v := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var sp := v.length()
	if sp < 1.5:
		return
	var way := v / sp
	var at := body.global_position
	for e in BendCaster.near(body, at, SHORT_M + sp * dt + 0.8):
		var n: Node3D = e[0]
		if n == body or absf(n.global_position.y - at.y) > 1.5:
			continue
		var to := n.global_position - at
		to.y = 0.0
		var along := to.dot(way)
		if along <= 0.05 or (to - way * along).length() > 0.75:
			continue
		if along - sp * dt > SHORT_M:
			continue
		_carry_t = 0.0
		_run_t = 0.0
		_ride_t = 0.0
		var keep := maxf(along - SHORT_M, 0.0) / maxf(dt, 1e-3)
		var toward := to.normalized()
		var vt := v.dot(toward)
		if vt > keep:
			body.velocity.x -= toward.x * (vt - keep)
			body.velocity.z -= toward.z * (vt - keep)
		return


## The ride's frame: its own share on top of his own way (whatever his easing did since: its distance exact), the knock's carry
## in his velocity kept as it was (BendKnock.applied: his controller takes that out and adds the decayed carry back, as for
## anyone); his own way again at its end. A knock since it began ends it at once, his velocity left as the knock set it (the
## ring's RingMoves._on_knocked: his own run gone, the launch his motion), the ride's share with it.
func _ride_step(dt: float) -> void:
	var kn := BendKnock.peek(body)
	if kn != null and kn.last_knock_at >= _ride_from - 1e-6:
		_ride_t = 0.0                             # (hit while riding: the hit's motion, not the ride's)
		return
	var ap := kn.applied if kn != null else Vector3.ZERO
	var step := minf(dt, _ride_t)
	_ride_t -= dt
	body.velocity.x = _ride_keep.x + _ride.x * step / dt + ap.x
	body.velocity.z = _ride_keep.z + _ride.z * step / dt + ap.z
	if _ride_t <= 0.0:
		_ride_t = 0.0
		body.velocity.x = _ride_keep.x + ap.x
		body.velocity.z = _ride_keep.z + ap.z


## Online, another machine's fighter (RingNet's puppet: NetBody moves him as his machine does): only the looks run here, his
## dash's end played when its time is up or he is down again (RingMoves' puppet state), never his motion, never his Carried
## wind (his machine charges it).
func _puppet_tick(dt: float) -> void:
	_carry_t = maxf(_carry_t - dt, 0.0)
	_fall_t = maxf(_fall_t - dt, 0.0)
	_run_t = maxf(_run_t - dt, 0.0)
	_ride_t = maxf(_ride_t - dt, 0.0)            # (a ride's foam ends on time: his machine moves him)
	var rm := RingMoves.of(body)
	if _dash == 2 and rm != null and rm.airborne():
		_dash_left = true
	if (_dash == 1 and _carry_t <= 0.0) or (_dash == 2 and _dash_left and rm != null and not rm.airborne()):
		_dash = 0
		SbFx.dash_ended(body)
	if not active() and _fx != null and is_instance_valid(_fx):
		BendLooks.stop_trail(_fx)
		_fx = null
