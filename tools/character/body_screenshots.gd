extends SceneTree
## Renders the player body (CharacterBodyMesh) in chosen animations. It needs a window,
## not --headless. Wrap it in a time limit, because a script error leaves the window open.
##
##   Godot --path . --resolution 1280x720 -s tools/character/body_screenshots.gd -- \
##       --no-capture out=/tmp/body [mode=game|clips|close|all] [only=walk,run,...]
##
## mode=game (default): loads scenes/main.tscn and drives the real player (FrontierPlayer +
##   PlayerAnim + weapons) with simulated input through SCENARIOS. Each scenario waits
##   (in physics frames, so the result does not depend on the frame rate) until the
##   scenario's state is reached and held (speed range, aim >= 0.99, crouch, reloading;
##   see _state()), then renders one frame from eight cameras at once: the gameplay camera
##   (the window), four orbit cameras at 4.4 m (front, side, back, three-quarter) and three
##   close-ups at 1.3-1.6 m (chest and armpits, hip and knees, nape and back) in
##   SubViewports that share the world. Saves <out>/game_<scenario>_<view>.png and a 4x2
##   sheet <out>/game_<scenario>.png. A scenario that does not reach its state is still
##   rendered, but the run ends with BODY SCREENSHOTS FAILED and exit code 1.
## mode=clips: a plain studio. A fresh Actor_B with the body plays each clip in CLIPS on
##   its AnimationPlayer (deterministic, no weapons) and renders from the four orbit
##   cameras. Saves <out>/clip_<clip>_<view>.png and a 2x2 sheet <out>/clip_<clip>.png.
## mode=close: the same studio, close-ups of the places where skinning fails first
##   (armpits with raised arms, wrists when aiming, knees and garters when crouching,
##   hair queue, hips, the coat skirt in crouches, a hard landing, a sitting knockdown and
##   the deaths, belt and straps in crouches): CLOSE_SHOTS, six views each at 0.7-2 m, 3x2
##   sheet <out>/close_<label>.png (front, left, back / right, top, under).

## [name, clip, time as a fraction of the clip length].
const CLIPS := [
	["idle", "actor_b-p-stealth-idle", 0.0],
	["walk-fw", "actor_b-p-walk-fw", 0.3],
	["run-fw", "actor_b-p-run-fw", 0.3],
	["sprint-fw", "actor_b-p-sprint-fw", 0.3],
	["crouch-walk-fw", "actor_b-p-crouch-walk-fw", 0.3],
	["crouch-idle", "actor_b-p-crouch-idle", 0.0],
	["rifle-aim", "actor_b-p-rifle-idle-aim", 0.0],
	["pistol-aim", "actor_b-p-pistol-aim-idle", 0.0],
	["bow-aim", "actor_b-p-bow-aim-idle", 0.0],
	["rifle-reload", "actor_b-p-rifle-idle-aim-reload-mid--part", 0.5],
	["bow-reload", "actor_b-p-bow-reload--part", 0.5],
	["fall", "actor_b-p-fall", 0.3],
	["death", "actor_b-death-standing-generic", 1.0],
]
## [label, clip, fraction, focus bone, camera distance (m)].
const CLOSE_SHOTS := [
	["armpit_reload_begin", "actor_b-p-rifle-idle-aim-reload-begin--part", 0.5, "spined", 1.4],
	["armpit_reload_over", "actor_b-p-rifle-idle-aim-reload-over--part", 0.5, "spined", 1.4],
	["armpit_musket_equip", "actor_b-lg-stealth-draw^idle--arm-r", 0.0, "spined", 1.4],
	["armpit_bow_grab", "actor_b-p-bow-draw-grab^idle--part", 0.2, "r_shoulder", 1.2],
	["armpit_bow_quiver", "actor_b-p-bow-reload--part", 0.35, "r_shoulder", 1.2],
	["armpit_ledge_hang", "actor_b-p-idle-jump-up-3m^ledge-hang-mid", 0.5, "spined", 1.4],
	["armpit_pistol_aim", "actor_b-p-pistol-aim-idle", 0.0, "spined", 1.3],
	["wrist_rifle_aim", "actor_b-p-rifle-idle-aim", 0.25, "l_wrist", 0.7],
	["wrist_bow_crouch", "actor_b-p-bow-aim-crouch-idle", 0.25, "r_wrist", 0.7],
	["knee_crouch_idle", "actor_b-p-crouch-idle", 0.0, "l_knee", 1.1],
	["knee_crouch_walk", "actor_b-p-crouch-walk-fw", 0.5, "pelvis", 1.6],
	["knee_run", "actor_b-p-run-fw", 0.3, "l_knee", 1.2],
	["nape_rifle_aim", "actor_b-p-rifle-idle-aim", 0.0, "neck", 0.8],
	["nape_crouch", "actor_b-p-crouch-idle", 0.3, "neck", 0.8],
	["hip_sprint", "actor_b-p-sprint-fw", 0.25, "pelvis", 1.3],
	["skirt_crouch_walk", "actor_b-p-crouch-walk-fw", 0.0, "pelvis", 1.9],
	["skirt_crouch_idle", "actor_b-p-crouch-idle", 0.0, "pelvis", 1.9],
	["skirt_crouch_aim", "actor_b-p-rifle-aim-crouch-idle", 0.0, "pelvis", 1.9],
	["skirt_land_hard_dmg", "actor_b-p-land-hard-damage^idle", 0.15, "pelvis", 1.9],
	["skirt_crouch_hr", "actor_b-p-crouch-hr-fw", 0.4, "pelvis", 2.0],
	["skirt_death_back", "actor_b-p-death-back", 1.0, "pelvis", 2.0],
	["skirt_death_front", "actor_b-p-death-front", 1.0, "pelvis", 2.0],
	["skirt_death_crouch", "actor_b-p-death-crouch-generic", 1.0, "pelvis", 2.0],
	["strap_crouch_idle", "actor_b-p-crouch-idle", 0.0, "spinec", 1.1],
	["strap_bow_aim_crouch", "actor_b-p-bow-aim-crouch-idle", 0.0, "spinec", 1.1],
]
const CLOSE_VIEWS := [["front", Vector3(0, 0.1, 1)], ["left", Vector3(1, 0.1, 0)], ["back", Vector3(0, 0.2, -1)],
		["right", Vector3(-1, 0.1, 0)], ["top", Vector3(0.3, 1.0, 0.4)], ["under", Vector3(0.6, -0.5, 0.6)]]
## Game scenarios, run in order by _scenario().
## Reloads come last: they leave the firearms mid-reload, which blocks aiming.
const SCENARIOS := ["idle", "walk", "run", "sprint", "crouch_walk", "musket_aim",
		"crouch_musket_aim", "bow_stance_change", "crouch_bow_aim", "bow_aim_then_crouch", "pistol_aim", "bow_draw", "musket_reload", "pistol_reload"]
## Game views: [name, offset in the character's frame (+Z = the way it faces), focus]
## focus: "hips" (orbit), "chest" (spined), "knees" (between hips and knees), "nape" (neck).
const VIEWS := [["front", Vector3(0.0, 0.25, 4.4), "hips"], ["side", Vector3(4.4, 0.25, 0.0), "hips"],
		["back", Vector3(0.0, 0.25, -4.4), "hips"], ["34", Vector3(3.1, 0.6, 3.1), "hips"],
		["close_chest", Vector3(0.9, 0.25, 1.15), "chest"], ["close_hips", Vector3(-1.1, 0.2, 1.0), "knees"],
		["close_back", Vector3(-0.55, 0.45, -1.05), "nape"]]
const VIEW_SIZE := Vector2i(960, 540)
const CELL := Vector2i(640, 360)
## Physics frames a scenario may take to reach its state, and how long it must hold.
const STATE_TIMEOUT := 420
const STATE_HOLD := 20

var args := {}
var out := ""
var failures := PackedStringArray()
var _vps: Array[SubViewport] = []
var _cams: Array[Camera3D] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://body_shots")
	DirAccess.make_dir_recursive_absolute(out)
	var mode: String = args.get("mode", "game")
	if mode in ["game", "both", "all"]:
		await _game()
	if mode in ["clips", "both", "all"]:
		await _clips()
	if mode in ["close", "all"]:
		await _close()
	if failures.is_empty():
		print("BODY SCREENSHOTS DONE")
	else:
		print("BODY SCREENSHOTS FAILED: ", "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _wanted(name: String) -> bool:
	return not args.has("only") or name in String(args.only).split(",")


# --- Cameras ------------------------------------------------------------------

func _make_views(n: int, fov := 32.0) -> void:
	for i in n:
		var vp := SubViewport.new()
		vp.size = VIEW_SIZE
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)   # No own World3D: renders the root viewport's world.
		var cam := Camera3D.new()
		cam.fov = fov
		cam.near = 0.02
		vp.add_child(cam)
		cam.current = true
		_vps.append(vp)
		_cams.append(cam)


func _free_views() -> void:
	for vp in _vps:
		vp.queue_free()
	_vps.clear()
	_cams.clear()


func _place(cam: Camera3D, center: Vector3, offset: Vector3) -> void:
	cam.global_position = center + offset
	if absf(offset.normalized().y) > 0.9:
		cam.look_at(center, Vector3(0, 0, 1))
	else:
		cam.look_at(center)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


## Renders one frame and saves the views (and the window when `with_main`), in order.
func _capture(prefix: String, with_main: bool, names: Array) -> Array:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var paths := []
	if with_main:
		var p := "%s/%s_play.png" % [out, prefix]
		root.get_viewport().get_texture().get_image().save_png(p)
		paths.append(p)
	for i in names.size():
		var p := "%s/%s_%s.png" % [out, prefix, names[i]]
		_vps[i].get_texture().get_image().save_png(p)
		paths.append(p)
	return paths


func _sheet(paths: Array, path: String, cols: int) -> void:
	var rows := ceili(paths.size() / float(cols))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in paths.size():
		var img := Image.load_from_file(paths[i])
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % cols * CELL.x, i / cols * CELL.y))
	sheet.save_png(path)
	print("saved ", path)


# --- Game mode ----------------------------------------------------------------

func _game() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(2)
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_make_views(VIEWS.size())
	var start := player.global_position
	for s: String in SCENARIOS:
		if not _wanted(s):
			continue
		player.global_position = start
		player.velocity = Vector3.ZERO
		player.yaw = 0.0
		player.pitch = 0.0
		await _physics(30)
		var paths: Array = await _scenario(player, s)
		_release_all()
		if player.is_crouching:
			await _tap_now("crouch")
		await _physics(40)
		if not paths.is_empty():
			_sheet(paths, "%s/game_%s.png" % [out, s], 4)
	_free_views()
	await _frames(2)


## [ok, description] of the scenario's target state right now.
func _state(player: FrontierPlayer, s: String) -> Array:
	var v := player.horizontal_speed()
	var w := player.weapon
	var aim := w.aim if w else 0.0
	var desc := "weapon %s, aim %.2f, crouch %s, speed %.2f" % [player.weapon_key, aim, player.is_crouching, v]
	var ok := false
	match s:
		"idle":
			ok = v < 0.05 and aim < 0.05 and not player.is_crouching
		"walk":
			ok = player.is_walking and v > 0.75 * player.walk_speed and v < player.walk_speed + 0.3
		"run":
			ok = v > 0.8 * player.run_speed and v < player.run_speed + 0.3 and not player.is_sprinting
		"sprint":
			ok = player.is_sprinting and v > 0.8 * player.sprint_speed
		"crouch_walk":
			ok = player.is_crouching and v > 0.6 * player.crouch_speed and v < player.crouch_speed + 0.3
		"musket_aim", "crouch_musket_aim":
			ok = player.weapon_key == "musket" and aim >= 0.99 and v < 0.1 \
					and player.is_crouching == s.begins_with("crouch")
		"bow_aim_then_crouch":
			ok = player.weapon_key == "bow" and aim >= 0.99 and v < 0.1 and player.is_crouching
		"crouch_bow_aim":
			ok = player.weapon_key == "bow" and aim >= 0.99 and v < 0.1 and player.is_crouching
		"bow_stance_change":
			ok = player.weapon_key == "bow" and v < 0.1
		"pistol_aim":
			ok = player.weapon_key == "pistol" and aim >= 0.99 and v < 0.1
		"bow_draw":
			ok = player.weapon_key == "bow" and aim >= 0.99 and v < 0.1
		"musket_reload", "pistol_reload":
			var f := w as Firearm
			ok = f != null and f.state == Firearm.State.RELOADING and v < 0.1
			desc += ", state %s" % (Firearm.State.keys()[f.state] if f else "-")
	return [ok, desc]


## Waits until the scenario's state holds for STATE_HOLD physics frames (at most
## STATE_TIMEOUT). Returns [reached, description].
func _reach(player: FrontierPlayer, s: String) -> Array:
	var held := 0
	var st := []
	for i in STATE_TIMEOUT:
		await physics_frame
		st = _state(player, s)
		held = held + 1 if st[0] else 0
		if held >= STATE_HOLD:
			return [true, st[1]]
	return [false, st[1]]


## Runs one scenario and captures it. The character's frame: the rig faces +Z of the
## Actor_B node (Visual rotates it 180 degrees to face the player's -Z).
func _scenario(player: FrontierPlayer, s: String) -> Array:
	match s:
		"idle":
			player.switch_weapon("musket")
		"walk":
			player.switch_weapon("musket")
			Input.action_press("walk")
			Input.action_press("move_forward")
		"run":
			player.switch_weapon("musket")
			Input.action_press("move_forward")
		"sprint":
			player.switch_weapon("musket")
			Input.action_press("move_forward")
			Input.action_press("sprint")
		"crouch_walk":
			player.switch_weapon("musket")
			await _tap_now("crouch")
			await _physics(20)
			Input.action_press("move_forward")
		"musket_aim", "crouch_musket_aim":
			player.switch_weapon("musket")
			if s.begins_with("crouch"):
				await _tap_now("crouch")
			await _physics(40)
			Input.action_press("aim")
		"bow_aim_then_crouch":
			player.switch_weapon("bow")
			await _physics(60)
			Input.action_press("fire")
			await _physics(60)
			await _tap_now("crouch")
			await _physics(180)
		"crouch_bow_aim":
			player.switch_weapon("bow")
			await _tap_now("crouch")
			await _physics(60)
			Input.action_press("fire")
		"bow_stance_change":
			player.switch_weapon("bow")
			await _physics(60)
			await _tap_now("crouch")
		"pistol_aim":
			player.switch_weapon("pistol")
			await _physics(40)
			Input.action_press("aim")
		"bow_draw":
			player.switch_weapon("bow")
			await _physics(60)
			Input.action_press("fire")
		"musket_reload", "pistol_reload":
			var w := "musket" if s == "musket_reload" else "pistol"
			player.switch_weapon(w)
			var f := player.weapon as Firearm
			await _until(func() -> bool: return not f.is_equipping() and f.state == Firearm.State.READY, 300)
			# Fire the loaded weapon (hold to shoulder, release to fire), then reload.
			for attempt in 3:
				if not f.loaded:
					break
				Input.action_press("fire")
				await _until(func() -> bool: return f.aim >= 1.0, 180)
				Input.action_release("fire")
				await _until(func() -> bool: return not f.loaded, 120)
			await _physics(300)   # Let the powder smoke clear.
			Input.action_press("reload")
			await _physics(3)
			Input.action_release("reload")
		_:
			return []
	var reached: Array = await _reach(player, s)
	if s.ends_with("_reload"):
		# Mid-reload: 45 % of the whole reload (the ramrod / priming stages).
		var f := player.weapon as Firearm
		var total := 0.0
		for st: Array in f.reload_stages:
			total += st[1]
		await _physics(int(total * 0.45 * Engine.physics_ticks_per_second))
		reached = [f.state == Firearm.State.RELOADING, _state(player, s)[1]]
	if not reached[0]:
		failures.append("%s did not reach its state (%s)" % [s, reached[1]])
	var model := player.skeleton.get_parent() as Node3D
	var sk := player.skeleton
	var hips := sk.to_global(sk.get_bone_global_pose(sk.find_bone("pelvis")).origin)
	var focus := {
		"hips": Vector3(hips.x, player.global_position.y + (0.6 if player.is_crouching else 0.9), hips.z),
		"chest": sk.to_global(sk.get_bone_global_pose(sk.find_bone("spined")).origin),
		"knees": (hips + sk.to_global(sk.get_bone_global_pose(sk.find_bone("l_knee")).origin)) * 0.5,
		"nape": sk.to_global(sk.get_bone_global_pose(sk.find_bone("neck")).origin),
	}
	var frame := model.global_basis.orthonormalized()
	var names := []
	for i in VIEWS.size():
		_place(_cams[i], focus[VIEWS[i][2]], frame * (VIEWS[i][1] as Vector3))
		names.append(VIEWS[i][0])
	var paths := await _capture("game_" + s, true, names)
	print("%s: %s%s" % [s, reached[1], "" if reached[0] else "  <-- STATE NOT REACHED"])
	return paths


## Waits (physics frames) until `cond` holds, at most `max_frames`. Returns whether it did.
func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _release_all() -> void:
	for a in ["walk", "move_forward", "sprint", "aim", "fire", "reload"]:
		Input.action_release(a)


func _tap_now(action: String) -> void:
	# Pressed for one physics frame is enough for is_action_just_pressed.
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


# --- Studio (clip and close modes) ---------------------------------------------

## A plain studio with a fresh Actor_B + body on a deterministic AnimationPlayer.
## Returns [world, skeleton, animation player].
func _studio() -> Array:
	if current_scene:   # The studio shares the root World3D; drop the level.
		current_scene.queue_free()
		await _frames(2)
	var world := Node3D.new()
	world.name = "Studio"
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 210, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.44, 0.40)
	ground.material_override = gm
	world.add_child(ground)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach(sk, ap)
	print("studio body: ", body.report if body else "MISSING")
	if body == null:
		failures.append("no body in the studio")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	return [world, sk, ap]


func _pose(ap: AnimationPlayer, clip: String, frac: float) -> bool:
	var anim := "actor_b/" + clip
	if not ap.has_animation(anim):
		failures.append("missing clip " + clip)
		return false
	ap.play(anim)
	ap.seek(frac * ap.get_animation(anim).length, true)
	ap.advance(0.0)
	return true


func _clips() -> void:
	var st: Array = await _studio()
	var sk: Skeleton3D = st[1]
	var ap: AnimationPlayer = st[2]
	_make_views(4)
	await _frames(2)
	for c: Array in CLIPS:
		if not _wanted(c[0]) or not _pose(ap, c[1], c[2]):
			continue
		var hips := sk.to_global(sk.get_bone_global_pose(sk.find_bone("pelvis")).origin)
		var center := Vector3(hips.x, 0.85 if hips.y > 0.7 else 0.6, hips.z)
		for i in 4:
			_place(_cams[i], center, VIEWS[i][1])
		var paths := await _capture("clip_" + String(c[0]), false, ["front", "side", "back", "34"])
		_sheet(paths, "%s/clip_%s.png" % [out, c[0]], 2)
	_free_views()
	(st[0] as Node).queue_free()
	await _frames(2)


func _close() -> void:
	var st: Array = await _studio()
	var sk: Skeleton3D = st[1]
	var ap: AnimationPlayer = st[2]
	_make_views(CLOSE_VIEWS.size(), 35.0)
	await _frames(2)   # (run alone, the views enter the tree only after a frame)
	var names := CLOSE_VIEWS.map(func(v: Array) -> String: return v[0])
	for c: Array in CLOSE_SHOTS:
		if not _wanted(c[0]) or not _pose(ap, c[1], c[2]):
			continue
		var center := sk.to_global(sk.get_bone_global_pose(sk.find_bone(String(c[3]))).origin)
		for i in CLOSE_VIEWS.size():
			_place(_cams[i], center, (CLOSE_VIEWS[i][1] as Vector3).normalized() * float(c[4]))
		var paths := await _capture("close_" + String(c[0]), false, names)
		_sheet(paths, "%s/close_%s.png" % [out, c[0]], 3)
	_free_views()
	(st[0] as Node).queue_free()
	await _frames(2)
