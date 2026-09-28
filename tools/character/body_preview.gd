extends SceneTree
## Preview renders of the customizer body (assets/character/body/body.glb) and the hair
## styles (assets/character/hair/*.glb) with their shaders. Needs a window (not
## --headless); run it under a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/character/body_preview.gd -- out=/tmp/prev [only=bodies,tones,...]
##
## Groups (PNG per shot in <out>/<group>_*.png; contact sheets are composed afterwards):
##   bodies  female and male fit, front / three-quarter / back, idle pose
##   tones   the 12 skin tones on both fits (bust), plus the four undertones
##   faces   the face presets of both fits, front and three-quarter
##   hair    every hair style, back three-quarter and side, on a matching fit
##   colors  the hair colour presets and powder on the queue
##   regions region colours (debug) and hide masks (clothing coverage, a hat hiding the crown)
##   poses   both fits in run, crouch walk, musket aim, bow aim (deformation)
## Prints BODY PREVIEW DONE (or FAILED with the reasons).

const HAIR_STYLES := ["hair_queue_ribbon", "hair_club_ribbon", "hair_loose_tied", "hair_cropped_1758",
		"hair_natural_short", "hair_crown_lock_braided", "hair_crown_lock_silver", "hair_club_wrapped_f",
		"hair_braid_f", "hair_pinned_capped"]
const IDLE := "actor_b-p-stealth-idle"

var args := {}
var out := ""
var failures := PackedStringArray()
var world: Node3D
var cam: Camera3D
var chars: Array = []     # [inst, skeleton, anim player, body]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://body_preview")
	DirAccess.make_dir_recursive_absolute(out)
	# macOS throttles a window that is covered: keep it on top while rendering
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	await _studio()
	for g in ["bodies", "tones", "faces", "hair", "colors", "regions", "poses"]:
		if not _wanted(g):
			continue
		print("group ", g)
		match g:
			"bodies": await _bodies()
			"tones": await _tones()
			"faces": await _faces()
			"hair": await _hair()
			"colors": await _colors()
			"regions": await _regions()
			"poses": await _poses()
	print("BODY PREVIEW DONE" if failures.is_empty() else "BODY PREVIEW FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _wanted(g: String) -> bool:
	return not args.has("only") or g in String(args.only).split(",")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _studio() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.38, 0.40)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.53, 0.58)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for l in [[Vector3(-35, 30, 0), 1.05, true], [Vector3(-15, -60, 0), 0.3, false], [Vector3(-25, 160, 0), 0.55, false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		d.shadow_enabled = l[2]
		world.add_child(d)
	cam = Camera3D.new()
	cam.fov = 28.0
	cam.near = 0.02
	world.add_child(cam)
	cam.current = true


## A fresh Actor_B with the body (and hair) at `pos`, rotated by `yaw_deg`.
func _character(pos: Vector3, yaw_deg: float, look: Dictionary) -> Array:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach_parts(sk, ap, {"body": BodyMaterials.BODY_GLB})
	if body == null:
		failures.append("body.glb did not attach")
		return []
	BodyMaterials.apply_look(body, look)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	_pose(ap, IDLE, 0.0)
	var c := [inst, sk, ap, body]
	chars.append(c)
	return c


func _clear() -> void:
	for c in chars:
		(c[0] as Node).queue_free()
	chars.clear()
	await _frames(2)


func _pose(ap: AnimationPlayer, clip: String, frac: float) -> void:
	var anim := "actor_b/" + clip
	if not ap.has_animation(anim):
		failures.append("missing clip " + clip)
		return
	ap.play(anim)
	ap.seek(frac * ap.get_animation(anim).length, true)
	ap.advance(0.0)


func _bone(c: Array, bone: String) -> Vector3:
	var sk: Skeleton3D = c[1]
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func _look_at(target: Vector3, offset: Vector3, fov := 28.0) -> void:
	cam.fov = fov
	cam.global_position = target + offset
	cam.look_at(target)


func _shot(name: String) -> String:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	return p


func _male(look: Dictionary) -> Dictionary:
	var l := look.duplicate(true)
	l["sex"] = 1.0
	return l


# --- groups ---------------------------------------------------------------------

func _bodies() -> void:
	var looks := [{"sex": 0.0, "face": "f_face_1", "melanin": 0.32, "hair": {"style": "hair_braid_f", "color": "dark_brown"}},
			{"sex": 1.0, "face": "m_face_1", "melanin": 0.32, "hair": {"style": "hair_queue_ribbon", "color": "mid_brown"}}]
	var yaws := [0.0, 40.0, 180.0]
	for i in 2:
		for j in 3:
			_character(Vector3((i * 3 + j) * 0.95 - 2.4, 0, 0), yaws[j], looks[i])
	await _frames(2)
	_look_at(Vector3(0, 0.85, 0), Vector3(0, 0.35, 12.5), 27.0)
	await _shot("bodies_all")
	for i in 2:
		_look_at(Vector3((i * 3 + 1) * 0.95 - 2.4, 0.85, 0), Vector3(0, 0.3, 6.4), 25.0)
		await _shot("bodies_%s" % ["f", "m"][i])
	await _clear()


func _tones() -> void:
	var c := _character(Vector3.ZERO, 20.0, {})
	await _frames(1)
	var head := _bone(c, "headb")
	for sex in [0.0, 1.0]:
		for t in 12:
			BodyMaterials.apply_look(c[3], {"sex": sex, "face": "f_face_1" if sex < 0.5 else "m_face_1",
					"melanin": t / 11.0, "hair": {"style": "hair_pinned_capped" if sex < 0.5 else "hair_cropped_1758",
					"color": "black" if t > 5 else "dark_brown"}})
			_look_at(head + Vector3(0, -0.10, 0.04), Vector3(0.25, 0.05, 1.05), 26.0)
			await _shot("tones_%s_%02d" % ["f" if sex < 0.5 else "m", t + 1])
	for u in ["cool", "neutral", "warm", "olive"]:
		for t in [2, 6, 10]:
			BodyMaterials.apply_look(c[3], {"sex": 0.0, "face": "f_face_1", "melanin": t / 11.0, "undertone": u,
					"hair": {"style": "hair_pinned_capped", "color": "dark_brown"}})
			_look_at(head + Vector3(0, -0.02, 0), Vector3(0.0, 0.02, 0.62), 26.0)
			await _shot("tones_under_%s_%02d" % [u, t + 1])
	await _clear()


func _faces() -> void:
	var c := _character(Vector3.ZERO, 0.0, {})
	await _frames(1)
	var head := _bone(c, "headb")
	var presets: Dictionary = BodyMaterials.body_info().get("face_presets", {})
	var n := 0
	for id: String in presets:
		var male := id.begins_with("m")
		var look := {"sex": 1.0 if male else 0.0, "face": id, "melanin": [0.2, 0.45, 0.75][n % 3],
				"stubble": 0.5 if male else 0.0, "iris": ["brown", "dark_brown", "hazel"][n % 3],
				"hair": {"style": "hair_cropped_1758" if male else "hair_pinned_capped",
					"color": ["mid_brown", "black", "dark_brown"][n % 3]}}
		BodyMaterials.apply_look(c[3], look)
		for v in [["front", Vector3(0, 0.0, 0.62)], ["34", Vector3(0.44, 0.02, 0.46)], ["side", Vector3(0.62, 0.0, 0.0)]]:
			_look_at(head + Vector3(0, 0.005, 0.05), v[1], 26.0)
			await _shot("faces_%s_%s" % [id, v[0]])
		n += 1
	await _clear()


func _hair() -> void:
	var c := _character(Vector3.ZERO, 0.0, {})
	await _frames(1)
	var head := _bone(c, "headb")
	var cols := ["dark_brown", "mid_brown", "chestnut", "black", "blue_black", "blue_black", "black", "blue_black",
			"auburn", "fair"]
	for i in HAIR_STYLES.size():
		var style: String = HAIR_STYLES[i]
		var info := BodyMaterials.hair_info(style)
		if info.is_empty():
			failures.append("no catalog fragment for " + style)
			continue
		var tags: Array = info.get("tags", [])
		var female := "women" in tags and not "men" in tags
		var look := {"sex": 0.0 if female else 1.0, "face": "f_face_3" if female else "m_face_1",
				"melanin": [0.25, 0.5, 0.7, 0.9][i % 4], "hair": {"style": style, "color": cols[i]}}
		BodyMaterials.apply_look(c[3], look)
		for v in [["back34", Vector3(-0.55, 0.12, -0.75)], ["side", Vector3(0.95, 0.05, 0.0)], ["front34", Vector3(0.5, 0.05, 0.75)]]:
			_look_at(head + Vector3(0, -0.07, 0), v[1], 30.0)
			await _shot("hair_%s_%s" % [style, v[0]])
	await _clear()


func _colors() -> void:
	var c := _character(Vector3.ZERO, 0.0, {})
	await _frames(1)
	var head := _bone(c, "headb")
	var presets: Array = BodyMaterials.load_json(BodyMaterials.HAIR_COLORS).get("presets", [])
	for p: Dictionary in presets:
		BodyMaterials.apply_look(c[3], {"sex": 1.0, "face": "m_face_1", "melanin": 0.3,
				"hair": {"style": "hair_queue_ribbon", "color": p.id}})
		_look_at(head + Vector3(0, -0.06, 0), Vector3(-0.5, 0.1, -0.62), 30.0)
		await _shot("colors_%s" % p.id)
	for pw in [0.5, 0.9]:
		BodyMaterials.apply_look(c[3], {"sex": 1.0, "face": "m_face_1", "melanin": 0.3,
				"hair": {"style": "hair_queue_ribbon", "color": "dark_brown", "powder": pw}})
		await _shot("colors_powder_%d" % int(pw * 10))
	await _clear()


func _regions() -> void:
	var c1 := _character(Vector3(-0.5, 0, 0), 0.0, {"sex": 0.0, "debug_view": 1, "hair": {"style": "hair_queue_ribbon"}})
	var c2 := _character(Vector3(0.5, 0, 0), 180.0, {"sex": 1.0, "debug_view": 1, "hair": {"style": "hair_queue_ribbon"}})
	await _frames(1)
	_look_at(Vector3(0, 0.85, 0), Vector3(0, 0.3, 6.8), 26.0)
	await _shot("regions_debug")
	# clothing coverage: a militia outfit hides everything but the head, the upper neck,
	# wrists and hands; the Eastern Woodlands summer look (breechcloth, leggings,
	# moccasins) hides the breechcloth area, the lower thighs, shins and feet; a tricorn
	# hides the hair's crown zone.
	var ids := BodyMaterials.region_ids()
	var militia := []
	for n: String in ids:
		if not n.begins_with("hair_") and not (n in ["head", "neck_upper", "hand_l", "hand_r", "wrist_l", "wrist_r"]):
			militia.append(n)
	var woodlands := ["pelvis_center"]
	for s in ["l", "r"]:
		for n in ["thigh_lower", "shin_upper", "shin_lower", "ankle", "foot"]:
			woodlands.append(n + "_" + s)
	BodyMaterials.apply_look(c1[3], {"sex": 0.0, "melanin": 0.4, "hide_regions": militia, "hide_hair_zones": ["crown"],
			"hair": {"style": "hair_queue_ribbon", "color": "dark_brown"}})
	BodyMaterials.apply_look(c2[3], {"sex": 1.0, "melanin": 0.6, "hide_regions": woodlands,
			"hair": {"style": "hair_crown_lock_braided", "color": "black"}})
	(c2[0] as Node3D).rotation_degrees.y = 30.0
	await _shot("regions_hidden")
	# region 31 (foot_l) uses the sign bit of the mask's first half
	BodyMaterials.apply_look(c1[3], {"sex": 0.0, "melanin": 0.4, "hide_regions": ["foot_l", "hand_r", "thigh_upper_r"],
			"hair": {"style": "hair_queue_ribbon", "color": "dark_brown"}})
	_look_at(Vector3(-0.5, 0.5, 0), Vector3(0, 0.3, 4.0), 26.0)
	await _shot("regions_bits")
	await _clear()


func _poses() -> void:
	var clips := [["run", "actor_b-p-run-fw", 0.3], ["crouch", "actor_b-p-crouch-walk-fw", 0.5],
			["musket", "actor_b-p-rifle-idle-aim", 0.0], ["bow", "actor_b-p-bow-aim-idle", 0.0]]
	var looks := [{"sex": 0.0, "face": "f_face_2", "melanin": 0.55, "hair": {"style": "hair_club_wrapped_f", "color": "black"}},
			{"sex": 1.0, "face": "m_face_2", "melanin": 0.8, "hair": {"style": "hair_loose_tied", "color": "black"}}]
	for i in 2:
		for j in clips.size():
			var c := _character(Vector3(j * 1.2 - 1.8, 0, i * -0.01), 35.0, looks[i])
			_pose(c[2], clips[j][1], clips[j][2])
		await _frames(2)
		_look_at(Vector3(0, 0.72, 0), Vector3(0, 0.5, 7.2), 31.0)
		await _shot("poses_%s" % ["f", "m"][i])
		_look_at(Vector3(0, 0.72, 0), Vector3(-2.2, 1.0, -6.6), 31.0)
		await _shot("poses_%s_back" % ["f", "m"][i])
		await _clear()
