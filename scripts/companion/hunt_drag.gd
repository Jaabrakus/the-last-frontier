class_name HuntDrag
extends Node
## A household hunter dragging her kill home on a rope (HuntRun): the player's foot drag (FootDrag) for a worker's body, the same
## CarcassLoad on SkidLoad's rod (the ground, friction, trunks and rocks, a trail of blood) with her left hip for the hand. What
## pulls gives hitch_point(), puller() and puller_speed() and has `load` and unhitch() (SkidLoad.hitch). The pull caps her walk
## (FootDrag.cap_for: haul.json "foot"); caught on a trunk, the rope holds her and the load is worked free after a moment.

var body: Spouse
## The carcass on the rope, or null.
var load: CarcassLoad = null
var jam_t := 0.0
var _exceptions: Array[PhysicsBody3D] = []
var _mi: MeshInstance3D
var _mesh: ImmediateMesh


func _ready() -> void:
	process_physics_priority = 6            # after her body has moved, before the load
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "Rope"
	_mi.mesh = _mesh
	_mi.top_level = true
	_mi.visible = false
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)


## The rope's end at her left hip (the Spouse faces -Z: -X is her left).
func hitch_point() -> Vector3:
	return body.global_position + Vector3.UP * 0.85 + body.global_basis.x * -0.25 + body.global_basis.z * 0.1


func puller() -> CollisionObject3D:
	return body


func puller_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


## The load went from under the rope (CarcassLoad: its animal was cleaned up).
func unhitch() -> Node3D:
	return let_go()


## Her walk cap with the load (m/s; INF without one).
func cap() -> float:
	return FootDrag.cap_for(load.pull_kgf) if load != null and is_instance_valid(load) else INF


## Takes dead animal `a` on the rope (CarcassLoad.haulable). False when it cannot be taken.
func start(a: Node3D) -> bool:
	if load != null or body == null or not CarcassLoad.haulable(a):
		return false
	var s := CarcassLoad.from_carcass(a, HorseHaul.data(), DisplayServer.get_name() != "headless")
	a.get_parent().add_child(s)
	var rope := float(FootDrag.cfg().get("rope_m", 1.2))
	s.hitch(self, clampf(hitch_point().distance_to(s.front), rope, rope + 1.5))
	load = s
	jam_t = 0.0
	_exceptions.clear()
	for b in [s.body] + a.find_children("*", "PhysicsBody3D", true, false) + ([a] if a is PhysicsBody3D else []):
		if b is PhysicsBody3D and is_instance_valid(b) and b != body:
			body.add_collision_exception_with(b)
			_exceptions.append(b)
	return true


## Lets the load go: it lies where it stopped (to be butchered, dragged again or scavenged). Returns the animal.
func let_go() -> Node3D:
	var s := load
	load = null
	jam_t = 0.0
	if s == null:
		return null
	for b in _exceptions:
		if is_instance_valid(b) and is_instance_valid(body):
			body.remove_collision_exception_with(b)
	_exceptions.clear()
	var a: Node3D = null
	if is_instance_valid(s):
		a = s.release()
		s.queue_free()
	return a


func _physics_process(delta: float) -> void:
	if load != null and not is_instance_valid(load):
		load = null
	if load == null:
		return
	var c := FootDrag.cfg()
	load.chain_len = move_toward(load.chain_len, float(c.get("rope_m", 1.2)), FootDrag.REEL_MPS * delta)
	var js := float(c.get("jam_stretch_m", 0.35))
	var after := float(c.get("jam_free_after_s", 1.5))
	if load.stretch > js:
		if jam_t + delta > after:
			load.work_free(float(c.get("jam_free_for_s", 1.0)), jam_t <= after)
		jam_t += delta
		_hold(js)
	else:
		jam_t = maxf(jam_t - delta * 4.0, 0.0)


## Caught: the rope holds her within its length (and `slack`) of the load.
func _hold(slack: float) -> void:
	var d := hitch_point() - load.front
	d.y = 0.0
	var over := d.length() - (load.chain_len + slack)
	if over <= 0.0 or d.length() < 1e-4:
		return
	var n := d.normalized()
	body.global_position -= n * over
	var away := body.velocity.dot(n)
	if away > 0.0:
		body.velocity -= n * away


func _process(_delta: float) -> void:
	var on := load != null and is_instance_valid(load) and DisplayServer.get_name() != "headless"
	_mi.visible = on
	if not on:
		return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, CarcassLoad.rope_material())
	HorseHaul.ribbon(_mesh, HorseHaul.sag(hitch_point(), load.chain_point(), load.chain_len + 0.01, 14), 0.02, 0.01)
	_mesh.surface_end()
