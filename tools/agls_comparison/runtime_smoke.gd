extends SceneTree
## Actual Frontier player, modifiers and Bow gameplay on a flat test floor.
var player: FrontierPlayer
var checks := 0
var failures := []
var rows := []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	collider.shape = box
	floor.add_child(collider)
	floor.position.y = -0.5
	level.add_child(floor)
	player = FrontierPlayer.new()
	player.name = "Player"
	player.is_local = false
	player.ignore_mouse_capture = true
	player.use_appearance = false
	player.show_gear = false
	player.demo_horse = false
	player.demo_wheelbarrow = false
	player.enable_grip = false
	player.position.y = 0.05
	level.add_child(player)
	await frames(200)
	player.switch_weapon("bow")
	await frames(260)
	check(player.weapon_key == "bow" and not player.is_switching(), "Bow equips using the existing gameplay sequence")
	var bow := player.weapon as Bow
	var paths := player.anim.data
	for st: String in ["stand", "crouch"]:
		check(String(paths.godot_anim(paths.aim_tree("bow", st).base.clip)).begins_with("frontier_legacy_runtime/"), "New bow aim active: " + st)
		check(String(paths.godot_anim(paths.runtime_clip("fire", "bow/" + st))).begins_with("frontier_legacy_runtime/"), "New bow recoil active: " + st)
	for crouch in [false, true]:
		if crouch:
			Input.action_press("crouch")
			await frames(1)
			Input.action_release("crouch")
			await frames(70)
		check(player.is_crouching == crouch, "Stance selected: " + str(crouch))
		for pitch_deg: float in [-40.0, 0.0, 40.0]:
			player.pitch = deg_to_rad(pitch_deg)
			Input.action_press("fire")
			await frames(100)
			var target := player.get_aim_point()
			var direction := (target - bow.muzzle.global_position).normalized()
			var barrel := -bow.model.global_basis.z.normalized()
			var error := rad_to_deg(direction.angle_to(barrel))
			rows.append({"crouch": crouch, "pitch": pitch_deg, "aim_error_deg": error, "charge": bow.charge})
			check(bow.charge >= 0.99, "Bow reaches full draw at pitch " + str(pitch_deg))
			check(error <= 3.0, "Bow aim within 3 degrees: " + str(error))
			check(bow.launch_origin().is_finite(), "Finite arrow launch position")
			check(bow._tip_valid and bow.launch_origin().distance_to(bow._nocked.global_position) < 0.001, "Arrow launch follows the rendered post-modifier tip")
			Input.action_press("aim")
			Input.action_release("fire")
			await frames(40)
			Input.action_release("aim")
			await frames(25)
			check(bow.charge == 0.0, "Let-down returns to zero draw")
		player.pitch = 0.0
		Input.action_press("fire")
		await frames(90)
		var ammo := bow.quiver
		Input.action_release("fire")
		await frames(2)
		check(bow.quiver == ammo - 1, "Release fires one arrow: " + str(crouch))
		await frames(120)
		check(bow.state == Bow.State.READY, "Bow returns to ready after recoil and nock")
		for b in player.skeleton.get_bone_count():
			check(player.skeleton.get_bone_global_pose(b).is_finite(), "Finite final pose " + str(b))
		player.switch_weapon("musket")
		await frames(260)
		check(player.weapon_key == "musket" and not player.is_switching(), "New bow sheath completes the normal switch: " + str(crouch))
		player.switch_weapon("bow")
		await frames(260)
	check(player.traversal.set_legacy_vault_hand("left"), "Left approved vault selectable")
	check(player.traversal._anim_name("actor_b-p-sprint-vault-1") == "frontier_legacy_runtime/vault_left_1", "Left approved vault routed to stage 1")
	check(player.traversal.set_legacy_vault_hand("right"), "Right approved vault selectable")
	check(player.traversal._anim_name("actor_b-p-sprint-vault-1") == "frontier_legacy_runtime/vault_right_1", "Right approved vault routed to stage 1")
	var report := {"checks": checks, "failures": failures, "bow_aim": rows}
	FileAccess.open("res://.comparison-private/reports/legacy-runtime-smoke.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("FRONTIER_LEGACY_RUNTIME_SMOKE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
