class_name BendThrow
extends RefCounted
## A bending move thrown like the throwables (BendEffects' "throw"; docs/bending_design.md; the owner's own throw clips:
## own-bend-throw-overhand for a spear, -sidearm for a disc, -underhand for pebbles, data/bending/poses.json): a BendBolt (its
## kind's meeting rules, guards, catches and wear as every bolt's) launched at the caster's aim with a throw's flight:
##   point_first  a spear (the ice spear): its point leads along its arc (BendBolt faces its flight)
##   spinning     a disc (the stone disc, a tomahawk's turn; the fire wheel kicked along the ground): its body turned about its
##                own right axis, whole turns to the aim (ThrowableTomahawk.spin_for's idea: the turn the throw's speed gives,
##                rounded to whole turns over the flight to the aim), tilted tilt_deg about its flight for a side-arm throw
##   flick        pebbles (Rock Jab, an atlatl's flick): `count` small stones, every_s apart, fanned spread_deg, each
##                tumbling on its own axis, tossed a little up (lift_deg) as an underhand flick leaves the hand
## The aim: a gravity throw is sent on the arc that lands it on the aim point (Weapon.ballistic_dir: its mps and gravity, as
## a thrown tomahawk's), and close in the line from the hand is blended toward the one from the chest (Throwable._throw_dir's
## point-blank rule: a hand off to the side does not miss a man at arm's length). `low` (along the ground: the fire wheel)
## leaves at the feet as a low bolt does.
## THE TIMING: it launches at once. The player's release already waits for his pose's strike (SwayCaster defers every
## STRIKE_DOS spec, "throw" among them, until SwayPose says struck: the one deferral); a bot's NpcBending times its clip's
## strike to its release (NpcBody.play_cast). Nothing here waits again (no double delay).
## Keys of the spec (moves.json, a mode's bend): do "throw", kind, shape (spear, disc, ball, crescent: round 2's High Kick,
## width_m across, its body BendLooks' crescent), flight, mps, gravity, damage, knock_mps, up_mps, radius_m, range_m, count,
## every_s, spread_deg, lift_deg, m_per_turn, tilt_deg, low, long.

## The High Kick's crescent (shape "crescent"): the top of its lob over the higher of hand and aim by default (m: a 2 m
## wall between is cleared), and the share of its width it is met by (its ball's radius; its look is the whole width).
const CRESCENT_APEX_M := 2.0
const CRESCENT_HIT := 0.3
## A spinning throw turns once per this many metres of its flight by default (m).
const M_PER_TURN := 3.2
## Close in (the aim within this many hand-to-chest lengths), the hand's line blended toward the chest's.
const POINT_BLANK_K := 2.0


## Caster `c` (any: BendCaster.wrap) throws `spec` along aim `a` (BendEffects.aim: from, dir, flat, point, target). The first
## bolt (the rest follow every_s apart); null when there is no caster.
static func throw(c: Variant, a: Dictionary, spec: Dictionary) -> BendBolt:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return null
	var n := maxi(int(spec.get("count", 1)), 1)
	var every := float(spec.get("every_s", 0.0))
	var first: BendBolt = null
	for i in n:
		if every > 0.0 and i > 0:
			var later := func() -> void:
				if bc.valid():
					one(bc, BendEffects.aim(bc, spec), spec, i, n)
			bc.body.get_tree().create_timer(every * i, false).timeout.connect(later)
		else:
			var b := one(bc, a, spec, i, n)
			if first == null:
				first = b
	return first


## Throw number `i` of `n` (the fan's place for pebbles) along aim `a`.
static func one(bc: BendCaster, a: Dictionary, spec: Dictionary, i := 0, n := 1) -> BendBolt:
	var p := bc.body
	var mps := float(spec.get("mps", 30.0))
	var g := float(spec.get("gravity", 0.0))
	var from: Vector3 = a.from
	var point: Vector3 = a.point
	var low := bool(spec.get("low", false))
	var dir: Vector3
	var lob := String(spec.get("shape", "")) == "crescent" or spec.has("apex_m")
	if low:
		from = Vector3(from.x, p.global_position.y + BendBolt.LOW_M, from.z)
		dir = Vector3((a.flat as Vector3).x, -0.02, (a.flat as Vector3).z).normalized()
	elif lob and g > 0.0 and point.is_finite():
		# (the High Kick: a lob over walls onto the aim; its speed the arc's, mps at most)
		var v := lob_velocity(from, point, float(spec.get("apex_m", CRESCENT_APEX_M)), g, mps * 1.5)
		mps = v.length()
		dir = v.normalized()
	else:
		dir = aim_dir(from, bc.chest(), point, mps, g)
	var flight := String(spec.get("flight", "point_first"))
	var spread := deg_to_rad(float(spec.get("spread_deg", 0.0)))
	if spread > 0.0 and n > 1:
		var off := (float(i) - float(n - 1) * 0.5) / maxf(float(n - 1) * 0.5, 1.0)
		dir = dir.rotated(Vector3.UP, off * spread + bc.rand_range(-0.2, 0.2) * spread)
		var side := dir.cross(Vector3.UP)
		if side.length_squared() > 1e-6:
			dir = dir.rotated(side.normalized(), bc.rand_range(-0.5, 0.5) * spread)
	var lift := deg_to_rad(float(spec.get("lift_deg", 0.0)))
	if lift > 0.0 and not low:
		var side2 := dir.cross(Vector3.UP)
		if side2.length_squared() > 1e-6:
			dir = dir.rotated(side2.normalized(), lift)
	var s := spec.duplicate()
	s["flight"] = flight
	s["mps"] = mps
	if String(spec.get("shape", "")) == "crescent" and not spec.has("radius_m"):
		# (the High Kick's crescent: drawn its width across, met as a thinner ball, a flat arc of flame passing a wall's top)
		s["look_r"] = float(spec.get("width_m", 1.6)) * 0.5
		s["radius_m"] = float(spec.get("width_m", 1.6)) * CRESCENT_HIT
	match flight:
		"spinning":
			s["spin_rate"] = spin_for(from, point, mps, float(spec.get("m_per_turn", M_PER_TURN)))
		"flick":
			# (a pebble tumbles: fast, on its own slanted axis)
			s["spin_rate"] = TAU * mps / maxf(float(spec.get("m_per_turn", 1.2)), 0.2)
			s["spin_axis"] = Vector3(1.0, 0.35 * (float(i) - float(n - 1) * 0.5), 0.25).normalized()
	var b := BendBolt.launch(p, from, dir, s)
	return b


## The line from `from` (the throwing hand) that lands a throw of `mps` under `g` on `point` (Weapon.ballistic_dir), blended
## close in toward the one from `chest` (Throwable._throw_dir): the hand's own line only once the aim is POINT_BLANK_K
## hand-to-chest lengths off, so a throw at arm's length goes where the eyes are.
static func aim_dir(from: Vector3, chest: Vector3, point: Vector3, mps: float, g: float) -> Vector3:
	var d := Weapon.ballistic_dir(from, point, mps, g, 0.0)
	var r := from.distance_to(chest)
	if r < 0.05 or not chest.is_finite():
		return d
	var t := clampf((chest.distance_to(point) - POINT_BLANK_K * r) / (POINT_BLANK_K * r), 0.0, 1.0)
	if t >= 1.0:
		return d
	var dc := Weapon.ballistic_dir(chest, point, mps, g, 0.0)
	return dc.slerp(d, t).normalized()


## A lob from `from` that lands on `to` under gravity `g` with its top `apex_m` over the higher of the two (round 2's High
## Kick: "over walls and into jumpers"; spec apex_m): the launch velocity (its speed capped at `cap` by lowering the top).
static func lob_velocity(from: Vector3, to: Vector3, apex_m: float, g: float, cap: float) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dist := flat.length()
	if dist < 0.5:
		return (to - from).normalized() * cap
	var top := maxf(from.y, to.y) + maxf(apex_m, 0.1)
	var v := Vector3.ZERO
	for i in 6:
		var vy := sqrt(2.0 * g * (top - from.y))
		var t_up := vy / g
		var t_down := sqrt(2.0 * maxf(top - to.y, 0.0) / g)
		var t := t_up + t_down
		v = flat / dist * (dist / t) + Vector3.UP * vy
		if v.length() <= cap or top <= maxf(from.y, to.y) + 0.15:
			break
		top = lerpf(maxf(from.y, to.y) + 0.1, top, 0.7)
	return v


## A spinning throw's turn (rad/s): the turn its speed gives (a whole turn per `m_per_turn` m), rounded to whole turns over
## its flight to `point` (it arrives edge first, as a tomahawk does).
static func spin_for(from: Vector3, point: Vector3, mps: float, m_per_turn := M_PER_TURN) -> float:
	var natural := TAU * mps / maxf(m_per_turn, 0.1)
	var t := from.distance_to(point) / maxf(mps, 0.1)
	if t < 0.05 or not point.is_finite():
		return natural
	var turns := maxf(roundf(natural * t / TAU), 1.0)
	return TAU * turns / t
