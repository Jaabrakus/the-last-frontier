class_name BodyBendCaster
extends BendCaster
## Any body that bends (BendCaster): a CharacterBody3D aiming at `target` (a Node3D: the player, a fighter, a dummy), with no
## camera and no keys. The tests cast every move through it, and the ring's bots build on it (NpcBendCaster):
##   the aim        the target's chest (aim_point: live, as it moves); a thing sent flying at him led by his pace over its
##                  flight (lead: the share of it, 0 none) and scattered by the body's skill (scatter_deg, one sigma: the
##                  fighter's own scatter, its seeded rng); no target: straight along its facing
##   its modes      fixed (modes: id -> mode; else each move's first), its tier 1, no notices
##   the sidestep   `side` (-1 left, 1 right; 0: by its own chance)
##   its rays       its own capsule and hit parts left out (NpcFighter.ray_exclude)
## Bind it to its body (bind()) and BendCaster.of(body) returns it.

var target: Node3D
var lead := 0.8
var scatter_deg := 0.0
var modes := {}
var side := 0.0
var team_id := &""
## A dash by the keys held (round 2's dir "held"): the way it means to go (x right, y forward; ZERO none: the spec's none,
## back). The bots set it before such a dash (KITS: NpcBending).
var dash_dir := Vector2.ZERO


func _init(p_body: CharacterBody3D = null, p_target: Node3D = null, p_lead := 0.8, p_scatter_deg := 0.0) -> void:
	body = p_body
	target = p_target
	lead = p_lead
	scatter_deg = p_scatter_deg


func has_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()


func facing() -> Vector3:
	if has_target():
		var v := target.global_position - body.global_position
		v.y = 0.0
		if v.length_squared() > 1e-4:
			return v.normalized()
	return super.facing()


func aim_ray() -> Array:
	var from := chest()
	if has_target():
		var to := NpcSenses.chest_of(target) - from
		if to.length_squared() > 1e-4:
			return [from, to.normalized()]
	return [from, facing()]


## The target's chest now (live: a throw re-reads it), else along its facing.
func aim_point(ex: Array = [], from := Vector3.INF) -> Vector3:
	if has_target():
		return NpcSenses.chest_of(target)
	return super.aim_point(ex, from)


func aim_target() -> Node3D:
	return target if has_target() and NpcSenses.can_fight(target) else null


## His chest, ahead by his pace over a flight of `mps` (times lead), scattered by scatter_deg.
func target_point(t: Node3D, mps := 0.0) -> Vector3:
	var from := chest()
	var p := NpcSenses.chest_of(t)
	if mps > 0.1 and lead > 0.0:
		var v := NpcSenses.velocity_of(t)
		p += Vector3(v.x, 0.0, v.z) * (from.distance_to(p) / mps) * lead
	if scatter_deg > 0.0:
		p = _scatter(from, p, scatter_deg)
	return p


func side_sign() -> float:
	if absf(side) > 0.01:
		return signf(side)
	return super.side_sign()


func held_move() -> Vector2:
	return dash_dir


func mode_of(id: String) -> String:
	var ms := SwayCaster.modes_of(id, body)        # (a worn talent's own mode too: the Sulphur Vent, Mire; a bot's, a test's)
	var m := String(modes.get(id, ""))
	if m in ms:
		return m
	return super.mode_of(id)


func team() -> StringName:
	return team_id


## `p` seen from `origin`, its line off by a normal error of `sigma_deg` (the fighter's own scatter when it has one).
func _scatter(origin: Vector3, p: Vector3, sigma_deg: float) -> Vector3:
	if body.has_method(&"scatter"):
		return body.call(&"scatter", origin, p, sigma_deg)
	var to := p - origin
	var d := to.length()
	if d < 0.01:
		return p
	var dir := to / d
	var s := dir.cross(Vector3.UP)
	s = s.normalized() if s.length_squared() > 1e-6 else dir.cross(Vector3.RIGHT).normalized()
	var up := s.cross(dir).normalized()
	var r := deg_to_rad(sigma_deg) * sqrt(-2.0 * log(maxf(rand_f(), 1e-6)))
	var a := rand_f() * TAU
	return p + (s * cos(a) + up * sin(a)) * tan(r) * d
