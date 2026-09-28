extends SceneTree
## Close-up shots of the musket holds while moving (push n01: the left hand on the fore-end, the crouch
## two-hand left elbow, the one-hand crouch hold). Needs a window (not --headless):
##   Godot --path . --resolution 1280x720 -s tests/anim/tools/rifle_hold_shots.gd -- out=<dir> \
##       scenario=crouch_two|crouch_one|walk|jog|sprint|idle|crouch_idle [shots=4] [gap=0.12] [views=front,left,top,back]
##       [settle=1.5] [tap=jump|crouch|+aim] [tap_at=<shot index>] [relax=<s>]
## tap presses the action before shot `tap_at` (a leading "+" keeps it held); relax sets
## PlayerAnim.relax_after_s; relax_at=<shot index> lets the relaxed one-hand hold come on before that shot.
## Saves <out>/<scenario>_<k>_<view>.png: the game is paused for each set, so every view of a set shows
## the same pose. An extra light near the camera makes the dark "u10" grade readable (tool only).

var args := {}
const VIEWS := {
	"front": [Vector3(0.45, 0.15, -1.9), Vector3.UP],
	"left": [Vector3(-1.9, 0.15, -0.25), Vector3.UP],
	"right": [Vector3(1.9, 0.15, -0.25), Vector3.UP],
	"top": [Vector3(-0.2, 1.6, -1.0), Vector3.UP],
	"back": [Vector3(0.5, 0.6, 2.1), Vector3.UP],
	"frontleft": [Vector3(-1.3, 0.35, -1.4), Vector3.UP],
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://rifle_shots")
	DirAccess.make_dir_recursive_absolute(out)
	var sc: String = args.get("scenario", "crouch_two")
	var shots := int(args.get("shots", "4"))
	var gap := float(args.get("gap", "0.12"))
	var views: PackedStringArray = String(args.get("views", "front,left,top,back")).split(",")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var p: FrontierPlayer = current_scene.get_node("Player")
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _phys(60)
	p.switch_weapon("musket")
	await _phys(30)
	for i in 400:
		if not p.is_switching() and not (p.weapon and p.weapon.is_equipping()):
			break
		await _phys(1)
	var one := sc == "crouch_one"
	if args.has("carry"):
		p.anim.long_gun_move_carry = String(args.carry)
	p.anim.relax_after_s = float(args.get("relax", "0.05" if one else "0.0"))
	Input.action_press("aim")
	await _phys(6)
	Input.action_release("aim")
	await _phys(60)
	var crouch := sc.begins_with("crouch")
	if crouch != p.is_crouching:
		Input.action_press("crouch")
		await _phys(2)
		Input.action_release("crouch")
		await _phys(60)
	var start = FootSlip._clear_start(p, 24.0)
	if start != null:
		p.global_position = Vector3(start.x, 0.05, start.y)
	p.velocity = Vector3.ZERO
	p.yaw = FootSlip._heading(FootSlip.TRAVEL)
	p.pitch = 0.0
	await _phys(60)
	var held: Array = {"crouch_two": ["move_forward"], "crouch_one": ["move_forward"], "walk": ["walk", "move_forward"],
			"jog": ["move_forward"], "sprint": ["sprint", "move_forward"]}.get(sc, [])
	for a: String in held:
		Input.action_press(a)
	await _phys(int(float(args.get("settle", "1.5")) * Engine.physics_ticks_per_second))
	var cam := Camera3D.new()
	cam.fov = 38.0
	current_scene.add_child(cam)
	var light := OmniLight3D.new()
	light.omni_range = 6.0
	light.light_energy = float(args.get("light", "1.5"))
	light.shadow_enabled = false
	current_scene.add_child(light)
	var sk := p.skeleton
	var chest_i := sk.find_bone("spined")
	var tap: String = args.get("tap", "")
	var tap_at := int(args.get("tap_at", "0"))
	for k in shots:
		if args.has("relax_at") and k == int(args.relax_at):
			p.anim.relax_after_s = 0.05
		if tap != "" and k == tap_at:
			Input.action_press(tap.trim_prefix("+"))
			await _phys(6)
			if not tap.begins_with("+"):
				Input.action_release(tap)
		await _phys(maxi(int(gap * Engine.physics_ticks_per_second), 1))
		# an idle step before pausing: PlayerAnim steps in _process, and at a low frame rate the physics ticks of
		# the gap can all fall in one main-loop iteration (the pose would stay where the last shot left it);
		# process_frame is emitted before the nodes' _process, so the second one follows a full idle step
		await process_frame
		await process_frame
		paused = true
		await process_frame
		print("shot %d: loco %s, at %s, crouch %s, one hand %s, relaxed %s" % [k, p.anim.loco.state,
				p.global_position.snapped(Vector3.ONE * 0.01), p.is_crouching, p.anim.one_hand, p.anim.relaxed])
		var chest := (sk.global_transform * sk.get_bone_global_pose(chest_i)).origin
		var basis := Basis(Vector3.UP, p.yaw)
		for v in views:
			if not VIEWS.has(v):
				continue
			var off: Vector3 = VIEWS[v][0]
			cam.global_position = chest + basis * off
			cam.look_at(chest - Vector3(0, 0.1, 0), basis * (VIEWS[v][1] as Vector3))
			cam.current = true
			light.global_position = cam.global_position + Vector3(0, 0.5, 0)
			await _shot("%s/%s_%d_%s.png" % [out, sc, k, v])
		paused = false
	for a: String in held:
		Input.action_release(a)
	if tap.begins_with("+"):
		Input.action_release(tap.trim_prefix("+"))
	quit()


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(path: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
