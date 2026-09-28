extends SceneTree
## Night shots and filmstrips of the torch (push n01b). Needs a window (not --headless):
##   Godot --path . --resolution 1280x720 -s tests/torch/tools/torch_shots.gd -- out=<dir> \
##       scenario=idle|walk|run|sprint|crouch|crouch_walk|jump|turn|aim_drop|pickup|pistol_aim|bow_draw|reload \
##       [weapon=musket|pistol|bow|over_under|spear|tomahawk] [hour=22.5] [place=fort|forest|range] [shots=6] [gap=0.12]
##       [views=game,front,left,right,top,frontleft,back] [settle=1.2] [strip=1] [cell=480x270] [notorch=1] [light=0]
## Saves <out>/<scenario>_<view>_<k>.png per shot, and with strip=1 one filmstrip per view
## (<scenario>_<view>_strip.png, the shots side by side). "game" is the player's own camera (the whole frame);
## the others are close cameras round the character (the game paused for each set, so every view of a set shows
## the same pose). No extra light: the torch lights the night scene (light=<energy> adds a dim camera fill).

var args := {}
const VIEWS := {
	"front": Vector3(0.5, 0.2, -2.3),
	"left": Vector3(-2.4, 0.2, -0.3),
	"right": Vector3(2.4, 0.2, -0.3),
	"top": Vector3(-0.3, 1.9, -1.2),
	"back": Vector3(0.5, 0.7, 2.5),
	"frontleft": Vector3(-1.7, 0.4, -1.8),
	"wide": Vector3(-2.5, 1.6, -4.5),
}
## Player-camera places: feet xz, yaw deg (as tools/environment/perf/forest_cost.gd's player poses).
const PLACES := {"fort": [Vector2(0.0, 6.0), 0.0], "forest": [Vector2(-68.5, -53.7), 129.7], "range": [Vector2(0.0, -20.0), 0.0],
		"forest_b": [Vector2(-85.3, -42.1), 90.0]}

var p: FrontierPlayer
var shots_by_view := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var out: String = args.get("out", "user://torch_shots")
	DirAccess.make_dir_recursive_absolute(out)
	var sc: String = args.get("scenario", "idle")
	var shots := int(args.get("shots", "6"))
	var gap := float(args.get("gap", "0.12"))
	var views: PackedStringArray = String(args.get("views", "game,front,left")).split(",")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	p = current_scene.get_node("Player")
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in current_scene.find_children("*", "DayNight", true, false):
		(n as DayNight).clock.running = false
		(n as DayNight).clock.set_time(float(args.get("hour", "22.5")))
	await _phys(60)
	var wk: String = args.get("weapon", "musket")
	if wk != p.weapon_key:
		p.switch_weapon(wk)
	await _phys(30)
	for i in 400:
		if not p.is_switching() and not (p.weapon and p.weapon.is_equipping()):
			break
		await _phys(1)
	var place: Array = PLACES.get(String(args.get("place", "fort")), PLACES.fort)
	var at: Vector2 = place[0]
	var hit := _ground(Vector3(at.x, 50, at.y))
	p.global_position = Vector3(at.x, hit + 0.05, at.y)
	p.velocity = Vector3.ZERO
	p.yaw = deg_to_rad(float(args.get("yaw", str(place[1]))))
	p.pitch = deg_to_rad(float(args.get("pitch", "-8")))
	await _phys(30)
	if args.get("notorch", "0") != "1":
		p.torch.take_out()
	await _phys(20)
	var crouch := sc.begins_with("crouch")
	if crouch != p.is_crouching:
		Input.action_press("crouch")
		await _phys(2)
		Input.action_release("crouch")
		await _phys(40)
	var held: Array = {"walk": ["walk", "move_forward"], "run": ["move_forward"], "sprint": ["sprint", "move_forward"],
			"crouch_walk": ["move_forward"], "jump": ["move_forward"], "turn": ["move_left"]}.get(sc, [])
	for a: String in held:
		Input.action_press(a)
	await _phys(int(float(args.get("settle", "1.2")) * Engine.physics_ticks_per_second))
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	current_scene.add_child(cam)
	var fill: OmniLight3D = null
	if float(args.get("light", "0")) > 0.0:
		fill = OmniLight3D.new()
		fill.omni_range = 6.0
		fill.light_energy = float(args.get("light", "0"))
		current_scene.add_child(fill)
	# scenario actions at given shots: [shot index, callable]
	var acts := {}
	match sc:
		"jump":
			acts[1] = func() -> void: await _tap("jump")
		"aim_drop", "pickup":
			acts[1] = func() -> void: Input.action_press("aim")
		"pistol_aim":
			acts[1] = func() -> void: Input.action_press("aim")
		"bow_draw":
			acts[1] = func() -> void: Input.action_press("fire")
		"reload":
			acts[0] = func() -> void:
				if p.weapon is Firearm:
					(p.weapon as Firearm).loaded = false
					(p.weapon as Firearm).state = Firearm.State.EMPTY
			acts[1] = func() -> void: await _tap("reload")
	var extra_after := int(args.get("after", "0"))
	for k in shots + extra_after:
		if acts.has(k):
			await (acts[k] as Callable).call()
		if sc == "pickup" and k == shots:
			# the aim let go, the player steps to the torch and taps E
			Input.action_release("aim")
			await _phys(40)
			await _walk_to_torch()
			await _tap("interact", 6)
			await _phys(30)
		var g := gap if k < shots else float(args.get("after_gap", "1.0"))
		await _phys(maxi(int(g * Engine.physics_ticks_per_second), 1))
		await process_frame
		await process_frame
		paused = true
		await process_frame
		print("shot %d: loco %s crouch %s torch in hand %s tossing %s dropped %s aim %.2f" % [k, p.anim.loco.state, p.is_crouching,
				p.torch.holding(), p.torch.tossing(), is_instance_valid(p.torch.last_dropped), p.weapon.aim if p.weapon else 0.0])
		var sk := p.skeleton
		var chest := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spined"))).origin
		var basis := Basis(Vector3.UP, p.yaw)
		for v in views:
			if v == "game":
				p.camera.current = true
			else:
				var off: Vector3 = VIEWS.get(v, VIEWS.front)
				var target := chest - Vector3(0, 0.15, 0)
				if v == "wide":
					target = p.global_position + basis * Vector3(0, 0.6, -1.2)
				cam.global_position = chest + basis * off
				cam.look_at(target, Vector3.UP)
				cam.current = true
				if fill:
					fill.global_position = cam.global_position + Vector3(0, 0.5, 0)
			await _shot(out, sc, v, k)
		paused = false
	for a: String in held:
		Input.action_release(a)
	Input.action_release("aim")
	Input.action_release("fire")
	if args.get("strip", "1") == "1":
		_strips(out, sc)
	quit()


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String, frames := 4) -> void:
	Input.action_press(action)
	await _phys(frames)
	Input.action_release(action)


func _ground(from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 100.0)
	q.exclude = [p.get_rid()]
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3).y if not h.is_empty() else 0.0


## Steps the player up to the dropped torch (1.2 m from it) and faces it, so the interactor targets it.
func _walk_to_torch() -> void:
	var d := p.torch.last_dropped
	if d == null or not is_instance_valid(d):
		return
	p.camera.current = true    # the interactor looks along the current camera (the close views take it over)
	var to := d.global_position - p.global_position
	to.y = 0.0
	var at := d.global_position - to.normalized() * 1.2
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.velocity = Vector3.ZERO
	p.yaw = atan2(-to.x, -to.z)
	p.pitch = deg_to_rad(-20.0)
	await _phys(50)
	print("pickup: target is the torch: ", p.interactor.target == d, " prompt: ", p.interactor._label.text)


func _shot(out: String, sc: String, v: String, k: int) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s_%s_%d.png" % [out, sc, v, k]
	img.save_png(path)
	if not shots_by_view.has(v):
		shots_by_view[v] = []
	shots_by_view[v].append(path)
	print("saved ", path)


func _strips(out: String, sc: String) -> void:
	var cell := Vector2i(480, 270)
	if args.has("cell"):
		cell = Vector2i(int(String(args.cell).get_slice("x", 0)), int(String(args.cell).get_slice("x", 1)))
	for v in shots_by_view:
		var paths: Array = shots_by_view[v]
		var strip := Image.create(cell.x * paths.size(), cell.y, false, Image.FORMAT_RGBA8)
		for i in paths.size():
			var img := Image.load_from_file(paths[i])
			img.convert(Image.FORMAT_RGBA8)
			if v != "game":
				# close views: the middle of the frame
				var w := img.get_width()
				var h := img.get_height()
				var cw := int(h * float(cell.x) / cell.y)
				if cw < w:
					img = img.get_region(Rect2i((w - cw) / 2, 0, cw, h))
			img.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(i * cell.x, 0))
		var path := "%s/%s_%s_strip.png" % [out, sc, v]
		strip.save_png(path)
		print("strip ", path)
