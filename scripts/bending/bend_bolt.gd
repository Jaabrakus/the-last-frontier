class_name BendBolt
extends Node3D
## A bent element in flight (BendEffects' "bolt"; docs/bending_design.md): stone, ice, water, fire or air, flying straight
## (gravity on it), struck as its front meets someone (BendStatus: the blow, the knockback, a root or a slow), spent on the
## world with a burst. Group GROUP. What it does against the others (docs: "How moves meet"):
##   bolt vs bolt (meet)   water + fire: both gone in steam; water + water: both gone; fire + ice: the ice melts, the fire
##                         goes on weaker; stone + anything else: the other is gone, the stone goes on; stone + stone: both
##                         break; air + fire: the air takes the flame (it burns); air + water: the water scatters
##   a raised wall         worn by its kind against the wall's matter (WEAR: water erodes earth, fire melts ice, stone
##                         breaks both, air does nothing); the bolt is spent
##   a zone                BendZone.on_bolt: a bubble, a water wall, an air shield, a fire wall decide (stop, send back,
##                         take the flame)
## redirect(dir, by) turns it (a shield's, a parry's, a redirect's): it is then `by`'s, and can strike who first sent it.

signal struck(who: Node, dmg: float)
signal ended(why: String)

const GROUP := &"bend_bolts"
## How many hits a raised wall takes from a bolt of each kind ([earth-like, ice]): FormRaised.apply_hit per whole one, the
## rest kept (the wall's meta bend_wear).
const WEAR := {"water": [1.0, 0.5], "fire": [0.5, 3.0], "stone": [1.5, 2.0], "ice": [1.0, 1.0], "air": [0.0, 0.0]}

var kind := "fire"
var caster: Node3D
var velocity := Vector3.ZERO
var gravity := 0.0
var damage := 10.0
var knock_mps := 3.0
var up_mps := 1.0
var radius := 0.2
var range_m := 30.0
var long := false
## Extra wear on an earth wall (the water jet's erosion), a root or a slow on whom it strikes (s), fire it carries (air).
var erode := 1.0
var root_s := 0.0
var slow_s := 0.0
var burning := false
var travelled := 0.0
var spent := false

var _trail: GPUParticles3D
var _fire_trail: GPUParticles3D
var _q: PhysicsShapeQueryParameters3D


## A bolt of `spec` (BendEffects' bolt fields) from `from` along `dir` by `by`, under the current scene.
static func launch(by: Node3D, from: Vector3, dir: Vector3, spec: Dictionary) -> BendBolt:
	var b := BendBolt.new()
	b.name = "BendBolt"
	b.kind = String(spec.get("kind", "fire"))
	b.caster = by
	b.velocity = dir.normalized() * float(spec.get("mps", 30.0))
	b.gravity = float(spec.get("gravity", 0.0))
	b.damage = float(spec.get("damage", 10.0))
	b.knock_mps = float(spec.get("knock_mps", 3.0))
	b.up_mps = float(spec.get("up_mps", 1.0))
	b.radius = float(spec.get("radius_m", 0.2))
	b.range_m = float(spec.get("range_m", 30.0))
	b.long = bool(spec.get("long", false))
	b.erode = float(spec.get("erode", 1.0))
	b.root_s = float(spec.get("root_s", 0.0))
	b.slow_s = float(spec.get("slow_s", 0.0))
	b.add_to_group(GROUP)
	by.get_tree().current_scene.add_child(b)
	b.global_position = from
	b._face()
	BendLooks.bolt_body(b, b.kind, b.radius, b.long)
	b._trail = BendLooks.trail(b, b.kind, b.radius)
	return b


func _face() -> void:
	if velocity.length_squared() > 1e-6:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)


func _physics_process(dt: float) -> void:
	if spent:
		return
	velocity.y -= gravity * dt
	var from := global_position
	var step := velocity * dt
	# the others met on the way (bolts, zones)
	_meet_bolts()
	if spent:
		return
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		if (z as BendZone).on_bolt(self) or spent:
			if spent:
				return
	# the world and whom it meets
	if _q == null:
		_q = PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = radius
		_q.shape = sph
	_q.exclude = _exclude()
	_q.transform = Transform3D(Basis.IDENTITY, from)
	_q.motion = step
	var space := get_world_3d().direct_space_state
	var frac := space.cast_motion(_q)
	if frac.size() == 2 and frac[1] < 1.0:
		var at := from + step * frac[1]
		_q.transform = Transform3D(Basis.IDENTITY, at)
		_q.motion = Vector3.ZERO
		var info := space.get_rest_info(_q)
		var col := instance_from_id(int(info.get("collider_id", 0))) as Node if not info.is_empty() else null
		global_position = from + step * frac[0]
		_hit(col, at, Vector3(info.get("normal", -velocity.normalized())))
		return
	global_position = from + step
	travelled += step.length()
	_face()
	if travelled > range_m:
		end("range")


func _exclude() -> Array[RID]:
	var ex: Array[RID] = []
	if caster is CollisionObject3D and is_instance_valid(caster):
		ex.append((caster as CollisionObject3D).get_rid())
	return ex


func _hit(col: Node, at: Vector3, n: Vector3) -> void:
	var who := _taker(col)
	if who is FormRaised:
		wear(who as FormRaised, at)
		BendLooks.burst(at, kind, 14, n, 70.0, 3.0)
		BendLooks.sound(kind, "hit", at, -4.0)
		end("wall")
		return
	if who != null and BendStatus.can_take(who, caster):
		var dir := velocity.normalized()
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		BendStatus.hurt(who, damage + (6.0 if burning else 0.0), at, dir, caster)
		BendStatus.knock(who, flat * knock_mps + Vector3.UP * up_mps, caster)
		if root_s > 0.0:
			BendStatus.root(who, root_s)
		if slow_s > 0.0:
			BendStatus.slow(who, slow_s)
		struck.emit(who, damage)
	BendLooks.burst(at, kind, 16, n, 80.0, 3.5)
	BendLooks.sound(kind, "hit", at, -3.0)
	end("hit" if who != null else "world")


static func _taker(col: Node) -> Node:
	var n := col
	var depth := 0
	while n != null and depth < 6:
		if n is FormRaised or n is FrontierPlayer or n is NpcFighter or n is WildAnimal or (n is RigidBody3D and not (n is FormStone)):
			return n
		n = n.get_parent()
		depth += 1
	return null


## A raised wall worn by this bolt (WEAR by its kind and the wall's matter; the water jet's erode on an earth wall).
func wear(w: FormRaised, at: Vector3) -> void:
	if w.has_meta(&"bend_brace"):
		w.remove_meta(&"bend_brace")             # (braced: this one is taken free; Catch's brace)
		return
	var ice := w.has_meta(&"bend_ice") or w.matter == "snow"
	var k := float((WEAR.get(kind, [1.0, 1.0]) as Array)[1 if ice else 0])
	if kind == "water" and not ice:
		k *= erode
	var acc := float(w.get_meta(&"bend_wear", 0.0)) + k
	while acc >= 1.0 and is_instance_valid(w) and w.is_up():
		acc -= 1.0
		w.apply_hit(maxf(w.hit_min, damage), at, velocity.normalized())
	if is_instance_valid(w):
		w.set_meta(&"bend_wear", acc)


func _meet_bolts() -> void:
	for o in get_tree().get_nodes_in_group(GROUP):
		var b := o as BendBolt
		if b == null or b == self or b.spent or b.get_instance_id() < get_instance_id():
			continue
		if b.global_position.distance_to(global_position) > radius + b.radius + 0.25:
			continue
		meet(self, b)
		if spent:
			return


## Two bolts meet (see the header).
static func meet(a: BendBolt, b: BendBolt) -> void:
	var at := (a.global_position + b.global_position) * 0.5
	var ks := [a.kind, b.kind]
	if a.kind == b.kind and a.kind != "stone":
		if a.kind in ["water", "fire", "ice", "air"] and a.caster != b.caster:
			BendLooks.burst(at, a.kind, 20)
			a.end("cancel")
			b.end("cancel")
		return
	if "water" in ks and "fire" in ks:
		BendLooks.burst(at, "steam", 34, Vector3.UP, 120.0, 3.0, 0.9)
		BendLooks.sound("steam", "hit", at)
		a.end("steam")
		b.end("steam")
		return
	if "stone" in ks:
		if a.kind == "stone" and b.kind == "stone":
			BendLooks.burst(at, "stone", 24)
			a.end("broken")
			b.end("broken")
		else:
			var other := b if a.kind == "stone" else a
			BendLooks.burst(at, other.kind, 14)
			other.end("stone")
		return
	if "fire" in ks and "ice" in ks:
		var ice := a if a.kind == "ice" else b
		var fire := b if ice == a else a
		BendLooks.burst(at, "water", 14)
		ice.end("melted")
		fire.damage *= 0.5
		return
	if "air" in ks and "fire" in ks:
		var air := a if a.kind == "air" else b
		var fire := b if air == a else a
		air.burning = true
		if air._fire_trail == null:
			air._fire_trail = BendLooks.trail(air, "fire", air.radius)
		fire.end("carried")
		return
	if "air" in ks and "water" in ks:
		var water := a if a.kind == "water" else b
		BendLooks.burst(at, "water", 18, Vector3.UP, 180.0, 2.5)
		water.end("scattered")


## Turned along `dir` (its speed kept), now `by`'s.
func redirect(dir: Vector3, by: Node3D) -> void:
	velocity = dir.normalized() * velocity.length()
	caster = by
	travelled = 0.0
	_face()


func end(why: String) -> void:
	if spent:
		return
	spent = true
	remove_from_group(GROUP)
	BendLooks.stop_trail(_trail)
	BendLooks.stop_trail(_fire_trail)
	ended.emit(why)
	queue_free()
