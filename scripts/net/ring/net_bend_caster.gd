class_name NetBendCaster
extends PlayerBendCaster
## A remote fighter's caster online (docs/tidebreak/ring_netcode.md, "Casts"): his puppet's, bound on it at its making
## (BendCaster.of returns it from then on), so a cast of his run here asks it, never this machine's keyboard, mouse or camera.
##   a cast's run  begin(ev) .. end() (NetCasts.run): every question the cast asks is answered from the event's tape, what his
##                 own caster answered his machine when he cast it, in the order it was asked (the same code asks the same
##                 questions in the same order here); its dice from the event's seed on (his were drawn from it too)
##   after it      a question asked later than his run (a volley's later bolts, a stone following his aim, Flowing's steer):
##                 from his streamed state: the point his crosshair is on (NetBody's aim slot: streamed_aim), the way he
##                 faces (his yaw), his chest; nothing held

## The cast being run here ({} none).
var ev := {}
## His crosshair's point as last streamed (INF none yet).
var streamed_aim := Vector3.INF
var _ev_rng := RandomNumberGenerator.new()
var _seeded := false
var _at := {}
const _NONE := &"_none"


func _init(sc: SwayCaster = null) -> void:
	super._init(sc)


## The cast `e` is run through this caster now (its tape answers, its seed's dice).
func begin(e: Dictionary) -> void:
	ev = e
	_ev_rng.seed = int(e.get("seed", 1))
	_seeded = true
	_at = {}


func end() -> void:
	ev = {}
	_at = {}


## The next answer to `key` on the cast's tape (_NONE: none left, or no cast running).
func _take(key: String) -> Variant:
	if ev.is_empty():
		return _NONE
	var tape: Dictionary = ev.get("tape", {})
	var list: Variant = tape.get(key)
	if not (list is Array):
		return _NONE
	var i := int(_at.get(key, 0))
	if i >= (list as Array).size():
		return _NONE
	_at[key] = i + 1
	return NetSpells.dec((list as Array)[i])


func chest() -> Vector3:
	var v: Variant = _take("chest")
	return v if v is Vector3 else super.chest()


func facing() -> Vector3:
	var v: Variant = _take("facing")
	if v is Vector3:
		return v
	if player == null:
		return super.facing()
	return Vector3(-sin(player.yaw), 0.0, -cos(player.yaw)).normalized()


func aim_ray() -> Array:
	var v: Variant = _take("aim_ray")
	if v is Array and (v as Array).size() == 2:
		return v
	var from := chest()
	var pt := streamed_aim
	return [from, (pt - from).normalized() if pt.is_finite() and pt.distance_to(from) > 0.01 else facing()]


func aim_point(_ex: Array = [], _from := Vector3.INF) -> Vector3:
	var v: Variant = _take("aim_point")
	if v is Vector3:
		return v
	if streamed_aim.is_finite():
		return streamed_aim
	return chest() + facing() * 20.0


## (his flights' point as his machine gave it; after his run his streamed crosshair point: aim_point's)
func flight_point(ex: Array = [], from := Vector3.INF) -> Vector3:
	var v: Variant = _take("flight_point")
	return v if v is Vector3 else aim_point(ex, from)


func aim_target() -> Node3D:
	var v: Variant = _take("aim_target")
	return v as Node3D if v is Node3D else null


func assist_target(_from: Vector3, _dir: Vector3, _ex: Array = []) -> Node3D:
	var v: Variant = _take("assist_target")
	return v as Node3D if v is Node3D else null


func target_point(t: Node3D, _mps := 0.0) -> Vector3:
	var v: Variant = _take("target_point")
	if v is Vector3:
		return v
	return NpcSenses.chest_of(t) if t != null else aim_point()


func launch_point(flat := Vector3.ZERO) -> Vector3:
	var v: Variant = _take("launch_point")
	return v if v is Vector3 else super.launch_point(flat)


func side_sign() -> float:
	var v: Variant = _take("side_sign")
	return float(v) if v is float or v is int else 1.0


func held_side() -> float:
	var v: Variant = _take("held_side")
	return float(v) if v is float or v is int else 0.0


func held_move() -> Vector2:
	var v: Variant = _take("held_move")
	return v if v is Vector2 else Vector2.ZERO


func jump_held() -> bool:
	var v: Variant = _take("jump_held")
	return bool(v) if v is bool else false


func feet_bound() -> bool:
	return bool(ev.bound) if ev.has("bound") else super.feet_bound()


func carry_ready() -> bool:
	return bool(ev.carry) if ev.has("carry") else super.carry_ready()


func mode_of(id: String) -> String:
	if not ev.is_empty():
		if id == String(ev.get("m", "")):
			return String(ev.get("mode", ""))
		var ms: Dictionary = (ev.get("tape", {}) as Dictionary).get("modes", {})
		if ms.has(id):
			return String(ms[id])
	return super.mode_of(id)


func tier(id: String) -> int:
	if not ev.is_empty():
		if id == String(ev.get("m", "")):
			return int(ev.get("tier", 1))
		var ts: Dictionary = (ev.get("tape", {}) as Dictionary).get("tiers", {})
		if ts.has(id):
			return int(ts[id])
	return super.tier(id)


func notice(_text: String, _s := 1.6) -> void:
	pass


func is_local() -> bool:
	return false


## His dice: from his last cast's seed on (a volley's later bolts draw from it as his did), the global ones before any.
func rand_f() -> float:
	return _ev_rng.randf() if _seeded else randf()


func rand_i() -> int:
	return _ev_rng.randi() if _seeded else randi()
