class_name BendCaster
extends RefCounted
## Whoever bends (the owner, 2026-10-04: an elemental ring sport, "1v1 first", the bots casting the same moves as the
## player): what BendEffects, BendBolt, BendZone and BendMotion ask of a caster, the same for the player (PlayerBendCaster:
## his camera's aim, the aim's help: assist_target) and for any body that bends (BodyBendCaster: a fighter aiming at a target
## node, led by its pace and scattered by its skill; the tests' and the bots'). No move reads the player's own fields: it asks
## its caster.
##   body            the CharacterBody3D that casts
##   chest()         where ranges are measured from; facing() its flat way (the aim's when it has one)
##   aim_ray()       [from, dir]: the line the aim looks along (the camera's for the player; the chest to the target's for a body)
##   aim_point(ex, from)  where the aim falls NOW (live: a throw re-reads it while the stone rises); `ex` RIDs left out of its ray
##   aim_target()    a fighter or the player the aim is on (null: none); target_point(t, mps) where to send a thing at him
##                   (his chest; a body's led by his pace over the flight, scattered by its skill)
##   launch_point(f) where a bolt leaves from (the chest a little along `f`; the player's: the pose's strike point when it has
##                   one: the animation hooks' contract)
##   exclude()       its own RIDs, left out of its rays and its bolts' (a fighter's hit parts too)
##   side_sign()     a sidestep's side (-1 left, 1 right): the player's keys, a body's own (or by chance)
##   mode_of(id), tier(id)   the move's variation and the caster's mastery of it
##   water()         its water (Bending.of(body)); notice(text, s) a word on the screen (the local player's only);
##   is_local()      the player at this screen; team() its side (&"" none)
##   rand_f(), rand_i(), rand_range(a, b)  its chances (the player: the global ones, as ever; a body: its own seeded rng: the tests repeat)
## BendCaster.of(n) the caster of node n, made once and kept in its meta (META); BendCaster.wrap(c) takes a BendCaster, a
## SwayCaster or a CharacterBody3D, so a helper can take any of them (untyped) and ask its caster.
## near(caster, at, r): whom a bend can reach about `at` (BendStatus.near, and the player found through his group "player").

const META := &"bend_caster"

var body: CharacterBody3D


func _init(p_body: CharacterBody3D = null) -> void:
	body = p_body


## The caster of `n` (a SwayCaster's player, a fighter, any CharacterBody3D), made on first call and kept in its meta; null
## for anything else. The player with a SwayCaster gets a PlayerBendCaster, everyone else a BodyBendCaster aimed at no one
## (the bots set their own: bind()).
static func of(n: Node) -> BendCaster:
	if n == null or not is_instance_valid(n):
		return null
	if n is SwayCaster:
		n = (n as SwayCaster).player
		if n == null:
			return null
	if not n is CharacterBody3D:
		return null
	var sc := SwayCaster.of(n)
	if n.has_meta(META):
		var had: Variant = n.get_meta(META)
		if had is BendCaster and (had as BendCaster).body == n and (sc == null or had is PlayerBendCaster):
			return had as BendCaster
	var c: BendCaster
	if sc != null and n is FrontierPlayer:
		c = PlayerBendCaster.new(sc)
	else:
		c = BodyBendCaster.new(n as CharacterBody3D)
	return c.bind()


## Any caster made one: a BendCaster as it is, a SwayCaster (its player's), a CharacterBody3D (of); null else.
static func wrap(c: Variant) -> BendCaster:
	if c == null:
		return null
	if c is BendCaster:
		return c as BendCaster
	if c is Node and is_instance_valid(c):
		return of(c as Node)
	return null


## This caster kept on its body (of(body) returns it from now on). Itself.
func bind() -> BendCaster:
	if body != null and is_instance_valid(body):
		body.set_meta(META, self)
	return self


func valid() -> bool:
	return body != null and is_instance_valid(body) and body.is_inside_tree()


# ---------------------------------------------------------------- the aim (virtual; a body's defaults)
func chest() -> Vector3:
	return body.global_position + Vector3.UP * 1.35


func facing() -> Vector3:
	var f := -body.global_basis.z
	if body.has_method(&"forward"):
		f = body.call(&"forward")
	f.y = 0.0
	return f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD


func aim_ray() -> Array:
	return [chest(), facing()]


func aim_point(ex: Array = [], from := Vector3.INF) -> Vector3:
	var r := aim_ray()
	return ray_point(r[0] if from == Vector3.INF else from, r[1], ex)


func aim_target() -> Node3D:
	return null


## Where to send a thing flying `mps` at `t` (his chest).
func target_point(t: Node3D, _mps := 0.0) -> Vector3:
	return NpcSenses.chest_of(t)


func launch_point(flat := Vector3.ZERO) -> Vector3:
	var f := flat if flat.length_squared() > 1e-6 else facing()
	return chest() + f * 0.6


func exclude() -> Array[RID]:
	var ex: Array[RID] = []
	if body == null or not is_instance_valid(body):
		return ex
	if body.has_method(&"ray_exclude"):
		ex.append_array(body.call(&"ray_exclude"))
	else:
		ex.append(body.get_rid())
	return ex


func side_sign() -> float:
	return 1.0 if rand_f() < 0.5 else -1.0


func mode_of(id: String) -> String:
	var ms := SwayCaster.modes_of(id)
	return String(ms[0]) if not ms.is_empty() else ""


func tier(_id: String) -> int:
	return 1


func water() -> Bending:
	return Bending.of(body)


func notice(_text: String, _s := 1.6) -> void:
	pass


func is_local() -> bool:
	return false


func team() -> StringName:
	return &""


func rand_f() -> float:
	return _rng().randf()


func rand_i() -> int:
	return _rng().randi()


func rand_range(a: float, b: float) -> float:
	return a + (b - a) * rand_f()


var _own_rng: RandomNumberGenerator


## The body's own seeded rng (NpcFighter.rng) when it has one, else this caster's (seeded from its body's name: repeatable).
func _rng() -> RandomNumberGenerator:
	var r: Variant = body.get(&"rng") if body != null and is_instance_valid(body) else null
	if r is RandomNumberGenerator:
		return r as RandomNumberGenerator
	if _own_rng == null:
		_own_rng = RandomNumberGenerator.new()
		_own_rng.seed = hash(String(body.name) if body != null else "bend") + 1750
	return _own_rng


# ---------------------------------------------------------------- shared
## Along the ray from `from` along `dir` past this caster and `ex` (RIDs): what it meets within 120 m, else 80 m along it.
func ray_point(from: Vector3, dir: Vector3, ex: Array = []) -> Vector3:
	if not valid() or dir.length_squared() < 1e-6:
		return Vector3.INF
	var exl: Array[RID] = exclude()
	for r in ex:
		exl.append(r)
	var h := body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * 120.0, 0xFFFFFFFF, exl))
	return h.position if not h.is_empty() else from + dir.normalized() * 80.0


## The aim's help (FormEffects.assist_target's rule, for any caster): a fighter, or the player, who can still fight within
## FormEffects.ASSIST_DEG of the ray from `from` along `dir` and FormEffects.ASSIST_M, in plain sight of it (nothing solid
## between), the nearest the ray's line; null none. Never the caster. Nothing is drawn for it (no target cues: the owner's
## rule).
func assist_target(from: Vector3, dir: Vector3, ex: Array = []) -> Node3D:
	if not valid() or dir.length_squared() < 1e-6:
		return null
	var best: Node3D = null
	var best_a := deg_to_rad(FormEffects.ASSIST_DEG)
	var space := body.get_world_3d().direct_space_state
	var pool: Array = []
	pool.append_array(body.get_tree().get_nodes_in_group(NpcFighter.GROUP))
	for pl in body.get_tree().get_nodes_in_group(&"player"):
		if not pool.has(pl):
			pool.append(pl)
	for n in pool:
		var f := n as CharacterBody3D
		if f == null or f == body or not NpcSenses.can_fight(f):
			continue
		var to := NpcSenses.chest_of(f) - from
		var dist := to.length()
		if dist < 1.0 or dist > FormEffects.ASSIST_M:
			continue
		var a := to.angle_to(dir)
		if a >= best_a:
			continue
		var exl: Array[RID] = exclude()
		exl.append(f.get_rid())
		for r in ex:
			exl.append(r)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + to, 1, exl)).is_empty():
			continue
		best = f
		best_a = a
	return best


## Whom a bend of `caster` (a Node; a BendCaster: its body) can reach within `r` of `at`: BendStatus.near (fighters and the
## group "players"), and the player found through his own group "player" (BendStatus looks for him by the scene's "Player"
## child only: a light scene or a renamed node was missed). [node, flat distance], each once.
static func near(caster: Variant, at: Vector3, r: float) -> Array:
	var cn: Node = (caster as BendCaster).body if caster is BendCaster else caster as Node
	var out := BendStatus.near(cn, at, r)
	if cn == null or not is_instance_valid(cn) or not cn.is_inside_tree():
		return out
	var have: Array = []
	for e in out:
		have.append(e[0])
	for n in cn.get_tree().get_nodes_in_group(&"player"):
		if have.has(n) or not n is Node3D or not BendStatus.can_take(n, cn):
			continue
		var q := (n as Node3D).global_position
		var d := Vector2(q.x - at.x, q.z - at.z).length()
		if d <= r and absf(q.y - at.y) < 3.0:
			out.append([n, d])
	return out
