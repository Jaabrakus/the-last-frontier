extends SceneTree
## Measures, in game, how far each weapon model points from the line
## muzzle -> crosshair target while fully aimed, at several camera pitches,
## and where zeroed shots land relative to the crosshair.
##
##   Godot --headless --path . -s tests/aim_alignment.gd -- --no-capture
var player: FrontierPlayer
var hits := []

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	var l := Node.new()
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc _ready():\n\tadd_to_group('hit_listeners')\nfunc on_projectile_hit(c, p):\n\tget_meta('t').hits.append(p)\nfunc on_target_killed(t):\n\tpass\n"
	s.reload()
	l.set_script(s)
	l.set_meta("t", self)
	current_scene.add_child(l)
	var crouch := "--crouch" in OS.get_cmdline_user_args()
	if crouch:
		Input.action_press("crouch")
		for i in 3: await physics_frame
		Input.action_release("crouch")
		for i in 30: await physics_frame
		print("crouching: ", player.is_crouching)
	for w in ["bow", "musket", "pistol"]:
		await _measure(w)
	quit()


func _measure(key: String) -> void:
	player.switch_weapon(key)
	# The graph weapon switch (holster, finish, grab, then the draw; about 1-1.6 s) must be over
	# before the aimed weapon is measured.
	for i in 600:
		if not player.is_switching() and not player.weapon.is_equipping():
			break
		await physics_frame
	for i in 60: await physics_frame
	var w: Weapon = player.weapon
	var raise := "fire" if key == "bow" else "aim"     # RMB raises a firearm without firing.
	var yaws := []
	var pitches := []
	for pitch_deg in [-15.0, 0.0, 15.0]:
		player.yaw = 0.0
		player.pitch = deg_to_rad(pitch_deg)
		Input.action_press(raise)
		for i in 100: await physics_frame
		var target := player.get_aim_point()
		var to := (target - w.muzzle.global_position).normalized()
		var fwd := -w.model.global_basis.z.normalized()
		var dyaw := rad_to_deg(Vector2(to.x, to.z).angle_to(Vector2(fwd.x, fwd.z)))
		var dpitch := rad_to_deg(asin(fwd.y) - asin(to.y))
		# Bow cant: how far the limbs (model +Y) lean from vertical around the arrow.
		var up_m := w.model.global_basis.y.normalized()
		var side := fwd.cross(Vector3.UP).normalized()
		var cant := rad_to_deg(atan2(up_m.dot(side), up_m.dot(fwd.cross(side).normalized() * -1.0)))
		yaws.append(dyaw)
		pitches.append(dpitch)
		print("%-7s camera pitch %+3.0f  aim %.2f  weapon vs muzzle->target: yaw %+6.1f  pitch %+6.1f  cant %+6.1f" % [key, pitch_deg, w.aim, dyaw, dpitch, cant])
		Input.action_release(raise)
		for i in 60: await physics_frame
	var my := 0.0
	var mp := 0.0
	for i in yaws.size():
		my += yaws[i] / yaws.size()
		mp += pitches[i] / pitches.size()
	print("MEAN %s yaw %+.1f pitch %+.1f" % [key, my, mp])
