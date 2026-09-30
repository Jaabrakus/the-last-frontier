class_name ThrownProjectile
extends Node3D
## A thrown spear, tomahawk or atlatl dart in flight. Stepped and raycast like
## Projectile (gravity, then drag, then move, per physics tick), so the arc drawn by
## ThrowableArc and the zeroed launch (Weapon.ballistic_dir) match the flight.
##
## The node origin is the object's centre of mass (the model's COM marker), so a
## spinning tomahawk turns about the right point.
##
##   POINT_FIRST  spear, dart: weathervanes along the velocity; the ray runs from the
##                tip. Sticks when it hits wood, straw, a target or soft ground point
##                first, fast enough and not too glancing; else it skips off.
##   SPINNING     tomahawk: turns end over end about its local X at `spin_rate`; the ray
##                sweeps the head. Sticks only when the blade faces into the surface
##                (within `edge_window_deg`), else the haft or poll hits and it bounces
##                off doing blunt damage.
##
## Once it comes to rest (stuck, or lying where it fell) it becomes a pickup
## (ThrownPickup) that gives it back to the thrower's Throwable. Stuck objects are
## reparented to what they hit, so they move with a toppling target, and drop to
## the ground if that node is removed (_exit_tree).

enum Flight { POINT_FIRST, SPINNING }
enum Phase { FLYING, TUMBLING, STUCK, LYING }

signal hit(collider: Object, point: Vector3, stuck: bool)
signal rested(pickup: ThrownPickup)
## Sound hook for the audio integration: surface is Sfx.surface_of's name.
signal impact_sfx(surface: String, point: Vector3, speed: float, stuck: bool)

## How each model kind lies on the ground: [model-space axis that faces up, height of the
## centre of mass above the ground]. Kinds not listed lie with model X up, 0.02 m high
## (the tomahawk on the flat of its blade). The spear lies blade-flat (+Y up) on its grip
## wrap and thong bands (radius ~0.016 m).
const LIE_POSE := {"spear": [Vector3.UP, 0.016]}
## A model's "Trim" node (the spear's stroud tails and hair tuft; spear.py puts its pivot
## at the knot, hanging back and down at rest) is re-hung for each phase: streamed back in
## flight (a turn about its X), hanging at rest when stuck (and in the hand), and laid out
## sideways when the object lies on the ground (a turn about its Z, so nothing sinks in).
const TRIM_FLIGHT_ROT := Vector3(-0.52, 0.0, 0.0)
const TRIM_LIE_ROT := Vector3(0.0, 0.0, 1.40)

var kind := "spear"                 ## Ammo kind handed back by the pickup.
var model_kind := "spear"           ## ThrowableModels kind drawn.
var grade := ""                     ## A made spear's standard (StationPractice), handed back by the pickup.
var flight := Flight.POINT_FIRST
var velocity := Vector3.ZERO
var gravity := 9.8
var drag := 0.0
var damage := 60.0
var blunt_damage := 8.0             ## Haft / skip hits.
var min_damage_speed := 5.0
var stick_speed := 6.0              ## Slower hits never stick.
var stick_max_incidence_deg := 68.0 ## POINT_FIRST: angle between the flight and the surface normal.
var stick_depth := 0.12             ## How far the leading point sinks in (straw, soft ground).
## Into wood (trees, posts, boards): a thrown point bites only a few centimetres into
## timber. <= 0: same as stick_depth.
var stick_depth_wood := -1.0
var edge_window_deg := 50.0         ## SPINNING: blade facing within this of the surface normal.
var stick_surfaces: PackedStringArray = ["wood", "straw", "dirt", "grass", "flesh"]
var spin_rate := 0.0                ## rad/s about local X (+ = top of the model turns forward).
var restitution := 0.3
var impact_gain := 2.5              ## Placeholder impact sound: speed multiplier into Sfx.impact.
var whoosh_pitch := 0.75
var whoosh := true
var exclude: Array[RID] = []
var shooter: Node
## Seconds in the air before a throw that never hit anything is removed. One that is still
## tumbling by then (wedged, rolling down a steep slope) is laid down where it is instead,
## so a thrown weapon that landed in the world is never lost.
var max_flight_time := 10.0
## World point the first step's ray starts from: the thrower's hand (Throwable sets it).
## The held object reaches out past the hand (a spear's point 0.8 m, a seated dart's 1.1 m),
## so a wall, a tree or the ground closer than that is found on the first step instead of
## being passed through. INF: start from the object itself.
var sweep_from := Vector3.INF

var phase := Phase.FLYING
var pickup: ThrownPickup
var impacts := 0
## Set by the pickup before it frees us (no ground copy is left behind).
var collected := false

var _model: Node3D
var _com := Vector3.ZERO            ## Model-space centre of mass.
var _tip := Vector3.ZERO            ## Model-space leading point (tip / blade edge).
var _reach := 0.5                   ## COM -> leading point.
var _start_speed := 1.0
var _age := 0.0
var _whoosh_voice: AudioStreamPlayer3D
var _damaged := false
var _moving := false
var _trim: Node3D                   ## The model's hanging "Trim" node, if it has one.
## End of the last flight step's ray (POINT_FIRST). The next ray starts there, so the swept
## path stays continuous while the point turns down along the arc (else it skips through
## flat ground now and then).
var _ray_end := Vector3.INF


## Places the projectile at `com` (world centre of mass) with the model's world `basis`.
## Call after add_child.
func launch(com: Vector3, dir: Vector3, basis_hint: Basis) -> void:
	global_transform = Transform3D(basis_hint.orthonormalized(), com)
	if flight == Flight.POINT_FIRST and velocity.length_squared() < 0.01:
		velocity = dir
	_start_speed = maxf(velocity.length(), 0.01)
	if whoosh:
		_start_whoosh.call_deferred()


func _ready() -> void:
	_model = ThrowableModels.build(model_kind)
	add_child(_model)
	_com = ThrowableModels.marker_pos(_model, "COM")
	var edge := _model.get_node_or_null("Edge") as Node3D
	var muzzle := _model.get_node_or_null("Muzzle") as Node3D
	_tip = edge.position if edge else (muzzle.position if muzzle else Vector3.ZERO)
	_model.position = -_com
	_reach = maxf((_tip - _com).length(), 0.05)
	_start_speed = maxf(velocity.length(), 0.01)
	_trim = _model.find_child("Trim", true, false) as Node3D
	_hang_trim()


## Re-hangs the model's Trim node for the current phase (see TRIM_FLIGHT_ROT).
func _hang_trim() -> void:
	if _trim == null:
		return
	match phase:
		Phase.FLYING, Phase.TUMBLING:
			_trim.rotation = TRIM_FLIGHT_ROT
		Phase.LYING:
			_trim.rotation = TRIM_LIE_ROT
		_:
			_trim.rotation = Vector3.ZERO


func _start_whoosh() -> void:
	if phase == Phase.FLYING and is_inside_tree():
		_whoosh_voice = Sfx.attach(&"arrow_whoosh", self, linear_to_db(clampf(velocity.length() / 30.0, 0.3, 1.0)), whoosh_pitch)


## Leading point in world space.
func tip_position() -> Vector3:
	return global_transform * (_tip - _com)


## The other end (spear butt, dart nock, tomahawk haft end) in world space.
func tail_position() -> Vector3:
	for m in ["Butt", "Nock", "Mouthpiece"]:
		var n := _model.get_node_or_null(m) as Node3D if _model else null
		if n:
			return global_transform * (n.position - _com)
	return global_position


func _physics_process(delta: float) -> void:
	if phase == Phase.STUCK or phase == Phase.LYING:
		return
	_age += delta
	if global_position.y < -200.0:
		queue_free()
		return
	if _age > max_flight_time:
		if phase == Phase.TUMBLING:
			_settle_at(global_transform)
		else:
			queue_free()
		return
	velocity.y -= gravity * delta
	velocity *= maxf(1.0 - drag * delta, 0.0)
	var step := velocity * delta
	var from: Vector3
	var to: Vector3
	var dir := velocity.normalized() if velocity.length_squared() > 1e-6 else Vector3.DOWN
	if phase == Phase.FLYING and flight == Flight.POINT_FIRST:
		from = _ray_end if _ray_end.is_finite() else global_position + dir * _reach
		to = global_position + dir * _reach + step
	else:
		from = global_position
		to = global_position + step + dir * minf(_reach, 0.25)
	if sweep_from.is_finite():
		from = sweep_from
		sweep_from = Vector3.INF
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	var result := get_world_3d().direct_space_state.intersect_ray(q)
	if result:
		_on_impact(result.collider, result.position, result.normal, dir)
		return
	_ray_end = to if phase == Phase.FLYING and flight == Flight.POINT_FIRST else Vector3.INF
	global_position += step
	if phase == Phase.FLYING and flight == Flight.POINT_FIRST:
		if velocity.length_squared() > 0.01:
			global_basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK)
	else:
		rotate_object_local(Vector3.RIGHT, -spin_rate * delta)


func _on_impact(collider: Object, point: Vector3, normal: Vector3, dir: Vector3) -> void:
	impacts += 1
	var speed := velocity.length()
	var surface := Sfx.surface_of(collider, point, normal) if collider else "dirt"
	var stuck := _can_stick(surface, normal, dir, speed)
	if is_instance_valid(_whoosh_voice):
		Sfx.stop(_whoosh_voice, 0.03)
	_whoosh_voice = null
	Sfx.impact(Projectile.Kind.ARROW, collider, point, normal, speed * impact_gain)
	impact_sfx.emit(surface, point, speed, stuck)
	var gone := false
	if not _damaged and speed >= min_damage_speed and phase == Phase.FLYING:
		_damaged = true
		var falloff := clampf(speed / _start_speed, 0.35, 1.0)
		var dmg := (damage if stuck else blunt_damage) * falloff
		var was_valid := is_instance_valid(collider)
		# Listeners (the HUD hit marker) first, while the collider surely still exists: the
		# hit can remove the part it hit.
		if shooter and shooter.is_inside_tree():
			shooter.get_tree().call_group("hit_listeners", "on_projectile_hit", collider, point)
		Hit.deliver(collider, dmg, point, dir, shooter)
		if was_valid and not is_instance_valid(collider):
			gone = true                  # Freed by the hit (its owner's apply_hit): nothing to stick in.
			collider = null
	hit.emit(collider, point, stuck)
	if stuck and gone:
		phase = Phase.TUMBLING
		_settle_at(global_transform)     # Drops to the ground below where the target was.
	elif stuck:
		_stick(collider, point, normal, dir, surface)
	else:
		_bounce(point, normal, speed, dir)


func _can_stick(surface: String, normal: Vector3, dir: Vector3, speed: float) -> bool:
	if phase != Phase.FLYING or speed < stick_speed or not surface in stick_surfaces:
		return false
	if flight == Flight.POINT_FIRST:
		return rad_to_deg(dir.angle_to(-normal)) <= stick_max_incidence_deg
	var blade := -global_basis.z.normalized()
	return rad_to_deg(blade.angle_to(-normal)) <= edge_window_deg


## Sink depth of the leading point into `surface`.
func depth_for(surface: String) -> float:
	return stick_depth_wood if surface == "wood" and stick_depth_wood > 0.0 else stick_depth


func _stick(collider: Object, point: Vector3, normal: Vector3, dir: Vector3, surface := "") -> void:
	phase = Phase.STUCK
	_hang_trim()
	var bite := dir if flight == Flight.POINT_FIRST else -normal
	# Put the leading point depth_for(surface) into the surface.
	global_position = point + bite * depth_for(surface) - (global_basis * (_tip - _com))
	velocity = Vector3.ZERO
	var node := ThrownProjectile.stuck_parent(collider, global_position)
	if node and node.is_inside_tree():
		_moving = true
		reparent(node)
		_moving = false
	_make_pickup()


## What a weapon stuck in `collider` at `point` rides on: an animal's hit zone gives the animal's bone there
## (WildAnimal.stuck_anchor: the weapon moves with the body, alive, falling or hauled), anything else itself.
## Shared with the arrows (Projectile).
static func stuck_parent(collider: Object, point: Vector3) -> Node3D:
	var node := collider as Node3D
	if node == null:
		return null
	var owner_node := node.get_parent()
	if node.has_meta(&"hit_part") and owner_node != null and owner_node.has_method(&"stuck_anchor"):
		var a: Variant = owner_node.call(&"stuck_anchor", point)
		if a is Node3D:
			return a
	return node


## Glances off. A point-first object bounces from where its point touched (its centre
## stays `_reach` back along the flight, where it was), so it does not jump forward by its
## length into what it hit.
func _bounce(point: Vector3, normal: Vector3, speed: float, dir := Vector3.ZERO) -> void:
	var slow := speed * restitution
	if phase == Phase.TUMBLING and (slow < 1.2 or impacts > 5) and normal.y > 0.55:
		_lie(point, normal)
		return
	var back := dir * _reach if phase == Phase.FLYING and flight == Flight.POINT_FIRST else Vector3.ZERO
	phase = Phase.TUMBLING
	velocity = velocity.bounce(normal) * restitution
	velocity += Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	spin_rate = randf_range(-12.0, 12.0) * clampf(slow / 4.0, 0.2, 1.0)
	global_position = point - back + normal * 0.03 - velocity.normalized() * 0.01
	if slow < 0.6 and normal.y > 0.55:
		_lie(point, normal)


## Comes to rest lying on the ground (LIE_POSE: on its side, or the spear blade-flat).
func _lie(point: Vector3, normal: Vector3) -> void:
	phase = Phase.LYING
	velocity = Vector3.ZERO
	var along := Vector3(-global_basis.z.x, 0.0, -global_basis.z.z)
	if along.length_squared() < 1e-4:
		along = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1))
	along = (along - normal * along.dot(normal)).normalized()
	var pose: Array = LIE_POSE.get(model_kind, [Vector3.RIGHT, 0.02])
	# Model -Z along the ground and pose[0] up: its X (the blade's flat side for the
	# tomahawk) or its Y (the spear's blade lying flat).
	var z := -along
	var up := normal.normalized()
	if pose[0] == Vector3.UP:
		global_basis = Basis(up.cross(z).normalized(), up, z)
	else:
		global_basis = Basis(up, z.cross(up).normalized(), z)
	global_position = point + normal * float(pose[1])
	_hang_trim()
	_make_pickup()


## Stuck in something that is being removed (a freed target or enemy): leave a copy
## lying on the ground below, so the thrown weapon is not lost with it. The copy is
## made by a deferred static call, so nothing is created when the whole scene or the
## game is shutting down. A target only taken out of the tree (not freed) keeps no copy
## of it: see spawn_lying_copy. Freeing the thrown weapon itself (queue_free) drops nothing.
func _exit_tree() -> void:
	if _moving or collected or phase != Phase.STUCK or is_queued_for_deletion():
		return
	var tree := get_tree()
	var scene := tree.current_scene if tree else null
	if scene == null or scene == self or scene.is_queued_for_deletion() or not scene.is_inside_tree():
		return
	Callable(ThrownProjectile, &"spawn_lying_copy").call_deferred(scene.get_instance_id(), kind, model_kind, flight,
			exclude, global_transform, get_instance_id())


## `scene_id` is an instance id, so a scene freed before the deferred call runs (quitting,
## changing level) is simply skipped. `orig_id` is the stuck weapon's: when it still exists
## its target was only taken out of the tree, not freed. Back in the tree (a reparent) it
## stays where it is stuck; still out, the weapon itself is taken out and dropped. Either
## way no copy is made, so a target that comes back never brings a second one.
static func spawn_lying_copy(scene_id: int, p_kind: String, p_model: String, p_flight: Flight, p_exclude: Array[RID],
		xf: Transform3D, orig_id := 0) -> void:
	var scene := instance_from_id(scene_id) as Node
	if scene == null or not scene.is_inside_tree() or scene.is_queued_for_deletion():
		return
	var orig := instance_from_id(orig_id) as ThrownProjectile if orig_id != 0 else null
	if orig != null:
		if orig.is_inside_tree() or orig.collected or orig.phase != Phase.STUCK or orig.is_queued_for_deletion():
			return
		if orig.get_parent():
			orig.get_parent().remove_child(orig)
		orig.phase = Phase.TUMBLING
		scene.add_child(orig)
		orig._settle_at(xf)
		return
	var copy := ThrownProjectile.new()
	copy.kind = p_kind
	copy.model_kind = p_model
	copy.flight = p_flight
	copy.exclude = p_exclude
	copy.whoosh = false
	copy.phase = Phase.TUMBLING
	scene.add_child(copy)
	copy._settle_at(xf)


## Drops straight down from `xf` and lies where it lands.
func _settle_at(xf: Transform3D) -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	global_transform = xf
	var q := PhysicsRayQueryParameters3D.create(xf.origin + Vector3.UP * 0.2, xf.origin + Vector3.DOWN * 50.0)
	q.exclude = exclude
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		_lie(r.position, r.normal)
	else:
		queue_free()


func _make_pickup() -> void:
	if pickup != null:
		return
	pickup = ThrownPickup.new()
	pickup.kind = kind
	pickup.model_kind = model_kind
	pickup.grade = grade
	pickup.item = self
	add_child(pickup)
	rested.emit(pickup)


## Steps a throw like _physics_process until it hits something. Returns
## {time, point, collider} or {} when nothing is hit within max_time.
static func predict_impact(world: World3D, origin: Vector3, vel: Vector3, g: float, drag_k: float,
		excl: Array[RID], max_time := 4.0) -> Dictionary:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var space := world.direct_space_state
	var pos := origin
	var v := vel
	var t := 0.0
	while t < max_time:
		v.y -= g * dt
		v *= maxf(1.0 - drag_k * dt, 0.0)
		var next := pos + v * dt
		var q := PhysicsRayQueryParameters3D.create(pos, next)
		q.exclude = excl
		var r := space.intersect_ray(q)
		if r:
			var seg := pos.distance_to(next)
			var frac: float = pos.distance_to(r.position) / seg if seg > 1e-6 else 0.0
			return {"time": t + dt * frac, "point": r.position, "collider": r.collider}
		pos = next
		t += dt
	return {}
