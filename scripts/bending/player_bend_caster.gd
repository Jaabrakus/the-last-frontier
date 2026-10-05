class_name PlayerBendCaster
extends BendCaster
## The player as a caster (BendCaster; his SwayCaster's lock and modes): the aim his camera's (the crosshair: its ray past him,
## FormEffects.aim_point's rule), the aim's help on a fighter near the crosshair (BendCaster.assist_target: FormEffects'
## rule), his chest SwayCaster.chest, the sidestep's side his keys (move_left / move_right; none held: by chance), his notices
## on his screen, his water his Bending. A bolt leaves from his pose's strike point when the pose has one (strike_point(), not
## Vector3.INF: the animation hooks), else from his chest a little along the aim. Exactly what the player's bends did before
## the caster was made one (the owner: "no behaviour change for the player").

var sway: SwayCaster
var player: FrontierPlayer


func _init(sc: SwayCaster = null) -> void:
	sway = sc
	player = sc.player if sc != null else null
	body = player


func chest() -> Vector3:
	return sway.chest() if sway != null and is_instance_valid(sway) else super.chest()


func facing() -> Vector3:
	var cam := _cam()
	var f := -cam.global_basis.z if cam != null else -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 1e-6 else -player.global_basis.z


func aim_ray() -> Array:
	var cam := _cam()
	if cam == null:
		return super.aim_ray()
	return [cam.global_position, -cam.global_basis.z]


## The crosshair's point now: the camera's ray (from `from`, else the camera) past the player and `ex`, its hit, else 80 m along
## it; INF with no camera (FormEffects.aim_point).
func aim_point(ex: Array = [], from := Vector3.INF) -> Vector3:
	var cam := _cam()
	if cam == null:
		return Vector3.INF
	if from == Vector3.INF:
		from = cam.global_position
	var dir := -cam.global_basis.z
	var exl: Array[RID] = [player.get_rid()]
	for r in ex:
		exl.append(r)
	var h := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, 0xFFFFFFFF, exl))
	return h.position if not h.is_empty() else from + dir * 80.0


func aim_target() -> Node3D:
	var cam := _cam()
	if cam == null:
		return null
	return assist_target(cam.global_position, -cam.global_basis.z)


func launch_point(flat := Vector3.ZERO) -> Vector3:
	var pose: Variant = sway.get(&"pose") if sway != null and is_instance_valid(sway) else null
	if pose is Object and is_instance_valid(pose) and (pose as Object).has_method(&"strike_point"):
		var sp: Variant = (pose as Object).call(&"strike_point")
		if sp is Vector3 and sp != Vector3.INF:
			return sp
	return super.launch_point(flat)


func exclude() -> Array[RID]:
	var ex: Array[RID] = [player.get_rid()]
	return ex


func side_sign() -> float:
	var lr := Input.get_axis(&"move_left", &"move_right") if InputMap.has_action(&"move_left") and InputMap.has_action(&"move_right") else 0.0
	if absf(lr) > 0.1:
		return signf(lr)
	return 1.0 if rand_f() < 0.5 else -1.0


func mode_of(id: String) -> String:
	return sway.mode_of(id) if sway != null and is_instance_valid(sway) else super.mode_of(id)


func tier(id: String) -> int:
	return sway.tier(id) if sway != null and is_instance_valid(sway) else 1


func notice(text: String, s := 1.6) -> void:
	if player != null and player.interactor != null and player.is_local:
		player.interactor.notice(text, s)


func is_local() -> bool:
	return player != null and player.is_local


## The player's chances are the global ones (as his bends' were).
func rand_f() -> float:
	return randf()


func rand_i() -> int:
	return randi()


func _cam() -> Camera3D:
	var cam := player.camera if player != null else null
	return cam if cam != null and cam.is_inside_tree() else null
