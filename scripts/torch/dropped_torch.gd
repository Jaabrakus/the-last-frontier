class_name DroppedTorch
extends RigidBody3D
## A torch on the ground (push n01b): tossed down when the player aims a long gun, draws the bow or reloads with
## it in the hand (PlayerTorch), or let fall (a vault, death). It falls, tumbles and settles under physics, and
## keeps burning where it lies, the flame rising (TorchFire keeps itself upright) and its light on the ground and
## the trees around, until its burn time is up. A tap of E picks it up again into the left hand (the interactor's
## generic interactable: PlacedWeapon.GROUP with interact_point / interact_prompt / interact / highlight_targets /
## distance_from); with a torch already in the hand, E puts this one out and packs it (burn time kept).
## A burnt-out torch is a charred stick: no prompt, gone after BURNT_KEEP_S.
## Set down (PlayerTorch.set_down: user 2026-09-27, "places to set a lit torch"), it stands where it was set, pushed
## into the ground or wedged in a wall, frozen from the start (standing(): frozen, the head up; saves keep it so).

## Physics layer of loose items (layer 10): the player's capsule, the camera's spring arm and the traversal
## probes do not collide with it; it collides with the world (layer 1) and thin props (layer 3).
const LAYER := 1 << 9
const MASK := 1 | 4
const BURNT_KEEP_S := 45.0
## Settled: slower than this (m/s, rad/s) for SETTLE_S, then frozen (no physics cost while it burns).
const SETTLE_SPEED := 0.05
const SETTLE_S := 0.6
const INTERACT_REACH := 2.3
## Under water / rain checks every POLL_S.
const POLL_S := 0.25
## Its linear damping (PlayerTorch's throw reckons with it).
const LINEAR_DAMP := 0.3

## Thrown (the torch mode's throw, PlayerTorch.throw_at; mark_thrown()): its first touch of the ground stops it short
## (a torch lands on its head in the grass, it does not skid on), so it lies by the ring the arc showed.
const LAND_KEEP := 0.2
## A thrown torch passes through its thrower this long (s) and until it is THROWER_CLEAR m away: at a low frame rate
## the hand lets go at the back of the wind-up, inside the body's capsule, and the torch hit its own thrower and
## dropped at the feet (the throw test failed at 30 fps).
const THROWER_S := 0.5
const THROWER_CLEAR := 1.2

var state: TorchState
var model: Node3D
var _thrown := false
var _thrower: PhysicsBody3D = null
var _thrower_t := 0.0
var fire: TorchFire
var interact_reach := INTERACT_REACH
var _still := 0.0
var _burnt_t := 0.0
var _poll := 0.0
var _rain := 0.0
var _sheltered := false
var _wet := false


## A burning (or burnt) torch at `xf` (the model's transform: origin at the grip, the head toward -Z), moving at
## `vel` and turning at `ang_vel`, added under `parent`.
static func spawn(parent: Node, xf: Transform3D, vel: Vector3, ang_vel: Vector3, s: TorchState) -> DroppedTorch:
	var d := DroppedTorch.new()
	d.state = s if s != null else TorchState.new()
	parent.add_child(d)
	d.global_transform = xf
	d.linear_velocity = vel
	d.angular_velocity = ang_vel
	return d


func _ready() -> void:
	name = "DroppedTorch"
	mass = TorchModels.MASS_KG
	collision_layer = LAYER
	collision_mask = MASK
	continuous_cd = true
	linear_damp = LINEAR_DAMP
	angular_damp = 2.5
	can_sleep = true
	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.9
	pmat.bounce = 0.12
	physics_material_override = pmat
	# the resin-soaked head is the heavier end
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0, -0.12)
	# boxes, not capsules: a round shaft rolls on and on (there is no rolling friction), a split stave lies still
	var zl := TorchModels.LENGTH
	var shaft := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(TorchModels.SHAFT_R * 2.0, TorchModels.SHAFT_R * 2.0, zl - TorchModels.HEAD_LEN)
	shaft.shape = bx
	shaft.position = Vector3(0, 0, TorchModels.GRIP_FROM_BUTT - (zl - TorchModels.HEAD_LEN) * 0.5)
	add_child(shaft)
	var head := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(TorchModels.HEAD_R * 1.8, TorchModels.HEAD_R * 1.8, TorchModels.HEAD_LEN)
	head.shape = hb
	head.position = Vector3(0, 0, -(zl - TorchModels.GRIP_FROM_BUTT) + TorchModels.HEAD_LEN * 0.5)
	add_child(head)
	model = TorchModels.build()
	add_child(model)
	fire = TorchFire.new()
	fire.state = state
	(model.get_node("Flame") as Node3D).add_child(fire)
	add_to_group(PlacedWeapon.GROUP)
	add_to_group(&"dropped_torches")
	_update_look()


func _physics_process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0 and state.lit:
		_poll = POLL_S
		var fp := flame_position()
		_rain = TorchState.rain_at(get_tree(), fp)
		_sheltered = _rain > 0.0 and TorchState.sheltered(get_world_3d(), fp, [get_rid()])
		_wet = TorchState.under_water(get_world_3d(), get_tree(), fp)
	state.tick(delta, _rain, _sheltered, _wet)
	_update_look()
	if _thrower != null:
		_thrower_t -= delta
		if not is_instance_valid(_thrower):
			_thrower = null
		elif _thrower_t <= 0.0 and global_position.distance_to(_thrower.global_position) > THROWER_CLEAR:
			remove_collision_exception_with(_thrower)
			_thrower = null
	if not freeze:
		if linear_velocity.length() < SETTLE_SPEED and angular_velocity.length() < SETTLE_SPEED * 4.0:
			_still += delta
			if _still >= SETTLE_S:
				freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				freeze = true
		else:
			_still = 0.0
		if global_position.y < -200.0:
			queue_free()
	if not state.lit:
		_burnt_t += delta
		if state.burnt_out() and _burnt_t >= BURNT_KEEP_S:
			queue_free()


func _update_look() -> void:
	if model:
		TorchModels.set_burn(model, state.strength(), state.used())


## Where the flame sits (world).
func flame_position() -> Vector3:
	var f := model.get_node_or_null("Flame") as Node3D if model else null
	return f.global_position if f else global_position


## Thrown: stops short where it first comes down (see LAND_KEEP), and passes through `thrower` as it leaves the hand
## (see THROWER_S).
func mark_thrown(thrower: PhysicsBody3D = null) -> void:
	_thrown = true
	if thrower != null:
		_thrower = thrower
		_thrower_t = THROWER_S
		add_collision_exception_with(thrower)
	contact_monitor = true
	max_contacts_reported = 2
	if not body_entered.is_connected(_on_landed):
		body_entered.connect(_on_landed)


func _on_landed(body: Node) -> void:
	if not _thrown or (body != null and body == _thrower):
		return
	_thrown = false
	linear_velocity *= LAND_KEEP
	angular_velocity *= LAND_KEEP * 2.0
	contact_monitor = false


## Settled and frozen on the ground.
func settled() -> bool:
	return freeze


## Set standing (in the ground or a wall), not lying: frozen with the head up. (A torch let fall lies flat.)
func standing() -> bool:
	return freeze and (-global_basis.z).normalized().y > 0.5


# --- interactable (PlayerInteractor: a tap of E) ------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position


func distance_from(p: Vector3) -> float:
	var a := global_transform * Vector3(0, 0, TorchModels.GRIP_FROM_BUTT)
	var b := global_transform * Vector3(0, 0, -(TorchModels.LENGTH - TorchModels.GRIP_FROM_BUTT))
	return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))


func interact_prompt(p: Node) -> String:
	if state.burnt_out() or p == null or p.get("torch") == null:
		return ""
	var pt: PlayerTorch = p.get("torch")
	if pt.holding():
		return "Put out and pack the torch" if state.lit else "Pack the torch"
	return "Take the torch" if state.lit else "Take the torch (unlit)"


func interact(p: Node) -> void:
	var pt: PlayerTorch = p.get("torch") if p else null
	if pt:
		pt.take_from_ground(self)


func highlight_targets() -> Array:
	var m := model.get_node_or_null("Mesh") if model else null
	return [m] if m else []
