class_name RingSteps
extends Node
## Another fighter's steps on the ring (the sound audit, 2026-10-13: the bots and the online opponents made no footsteps, no
## push-off and no landing; Footsteps is the player's own and reads the player's state): a step every stride of his own
## ground speed (Footsteps' STRIDE: walk under Footsteps.RUN_SPEED, else run; the knock's carry left out, as Footsteps
## does), a landing after AIR_S in the air falling faster than LAND_MPS (louder the harder, as Footsteps'), a push-off on
## leaving the floor upward; the surface under him (Footsteps' rule: the ring's deck is wood), DB under the player's own.
## attach(body) once (RingMode's bots).

const DB := -4.0
const AIR_S := 0.12
const LAND_MPS := 1.5
const TAKEOFF_MPS := 2.0
const NODE_NAME := &"RingSteps"

var body: CharacterBody3D
var _acc := 0.0
var _side := 1.0
var _was_floor := true
var _air_t := 0.0
var _fall := 0.0


## `b`'s steps heard from now on (null when it has them already or is not a body).
static func attach(b: Node) -> RingSteps:
	var cb := b as CharacterBody3D
	if cb == null or cb is FrontierPlayer or cb.get_node_or_null(NodePath(String(NODE_NAME))) != null:
		return null
	var s := RingSteps.new()
	s.name = NODE_NAME
	s.body = cb
	cb.add_child(s)
	return s


func _physics_process(dt: float) -> void:
	if body == null or not is_instance_valid(body) or not BendLooks.live():
		return
	var on := body.is_on_floor()
	if on:
		if not _was_floor and _air_t > AIR_S and _fall > LAND_MPS:
			var gain := 8.0 * clampf((_fall - 2.0) / 5.0, 0.0, 1.0)
			Sfx.play_3d(StringName("land_" + _surface()), body.global_position, DB + gain, 0.95 if _fall > 5.5 else 1.0)
		_air_t = 0.0
		_fall = 0.0
		var kn := BendKnock.peek(body)
		var own := kn.base_of(body.velocity) if kn != null else body.velocity
		var v := Vector2(own.x, own.z).length()
		if v > Footsteps.MIN_SPEED:
			_acc += v * dt
			var gait := "run" if v > Footsteps.RUN_SPEED else "walk"
			if _acc >= float(Footsteps.STRIDE.get(gait, 1.15)):
				_acc = 0.0
				_side = -_side
				Sfx.play_3d(StringName("step_%s_%s" % [_surface(), gait]),
						body.global_position + body.global_basis.x * Footsteps.FOOT_SPREAD * _side, DB, 1.0,
						{"group": "steps_others", "max": 4})
		else:
			_acc = float(Footsteps.STRIDE.run) * 0.6       # (the first step at 40 % of a stride, as Footsteps')
	else:
		if _was_floor and body.velocity.y > TAKEOFF_MPS:
			Sfx.play_3d(&"jump_takeoff", body.global_position, DB - 2.0)
		_air_t += dt
		_fall = maxf(_fall, -body.velocity.y)
	_was_floor = on


## The surface under him: Footsteps' rule (wood, dirt or grass; the ring has no snow).
func _surface() -> String:
	var from := body.global_position + Vector3.UP * 0.1
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.6)
	q.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "dirt" if Sfx.is_dirt(body.global_position) else "grass"
	match Sfx.surface_of(hit.collider, hit.position, hit.normal):
		"wood":
			return "wood"
		"dirt", "stone":
			return "dirt"
	return "grass"
