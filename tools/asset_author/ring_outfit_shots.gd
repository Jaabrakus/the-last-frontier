extends SceneTree
## Turnaround lineups of the Tidebreak ring dress (PlayerAppearance.arena_outfit, the same dress the ring's bots wear:
## data/npc/factions.json element_dress): the four elements on both body types side by side (women first, then men),
## the game's own body and garments (PlayerAppearance.dress), standing in the creator's display idle, in a plain daylight
## studio. Needs a window:
##
##   Godot --path . --resolution 1920x760 -s tools/asset_author/ring_outfit_shots.gd -- out=DIR [views=front,34,side,back]
##       [close=1] [action=1] [prefix=assets_outfits_]
##
## Writes <out>/<prefix><view>.png (all eight), with close=1 <prefix>close_<element>.png (the pair from the front-left)
## and with action=1 <prefix>action.png (all eight in a frame of an own stance clip, own-bend-earth-stomp, to show the
## cut moving). Prints RING OUTFIT SHOTS DONE.

const IDLE := &"actor_b/actor_b-p-relax-idle"
const IDLE_FALLBACK := &"actor_b/actor_b-p-stealth-idle"
const ACTION_CLIP := "own-bend-earth-stomp"
const ELEMENTS := ["earth", "water", "fire", "air"]
## faces for the shots only (any people wears any side's dress)
const FACES := {0.0: ["english_f_a", "chinese_f_a", "south_asian_f_a", "korean_f_a"],
		1.0: ["japanese_m_a", "english_m_a", "vietnamese_m_a", "south_asian_m_a"]}
const VIEWS := {"front": 0.0, "34": 40.0, "side": 90.0, "back34": 145.0, "back": 180.0}
const SPACING := 0.95

var args := {}
var out := ""
var cam: Camera3D
var figs: Array = []          ## [{node, ap, element, sex}]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = String(args.get("out", ""))
	if out == "" or DisplayServer.get_name() == "headless":
		push_error("ring_outfit_shots: needs out=DIR and a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s%s.png" % [out, String(args.get("prefix", "assets_outfits_")), name]
	root.get_texture().get_image().save_png(path)
	print("shot ", path)


func _stage() -> void:
	var world := Node3D.new()
	world.name = "Studio"
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.76, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.84)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 200.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.8, 0.86, 1.0)
	world.add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.6, 0.56)
	gm.roughness = 0.95
	ground.material_override = gm
	world.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 30.0
	world.add_child(cam)
	cam.current = true


func _figure(i: int, element: String, sex: float) -> Dictionary:
	var pivot := Node3D.new()
	pivot.position = Vector3((float(i) - 3.5) * SPACING, 0.0, 0.0)
	root.get_node("Studio").add_child(pivot)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	pivot.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
	var body := CharacterBodyMesh.attach(sk, ap)
	BindRest.ensure_character(inst)
	var faces: Array = FACES[sex]
	var look := CharacterPeoples.preset_look(String(faces[ELEMENTS.find(element)]))
	look["sex"] = sex
	look["outfit"] = PlayerAppearance.arena_outfit(element, sex)
	PlayerAppearance.dress(body, look)
	inst.scale = Vector3.ONE * float(look.get("stature", 1.0))
	if ap:
		var clip := IDLE if ap.has_animation(IDLE) else IDLE_FALLBACK
		if ap.has_animation(clip):
			ap.play(clip)
			ap.seek(0.4, true)
			ap.pause()
	var lab := Label3D.new()
	lab.text = "%s %s" % [element.capitalize(), "F" if sex < 0.5 else "M"]
	lab.font_size = 40
	lab.pixel_size = 0.003
	lab.modulate = Color(0.12, 0.12, 0.14)
	lab.outline_size = 0
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 0.12, 0.45)
	lab.no_depth_test = true
	pivot.add_child(lab)
	return {"node": pivot, "ap": ap, "element": element, "sex": sex, "label": lab}


func _frame_all() -> void:
	var w := SPACING * 8.0
	cam.fov = 24.0
	var dist := (w * 0.5) / tan(deg_to_rad(cam.fov * 0.5)) / (float(root.size.x) / float(root.size.y)) * 1.04
	cam.position = Vector3(0.0, 1.05, maxf(dist, 4.0))
	cam.look_at(Vector3(0.0, 0.9, 0.0))


func _run() -> void:
	_stage()
	var i := 0
	for sex: float in [0.0, 1.0]:
		for el: String in ELEMENTS:
			figs.append(_figure(i, el, sex))
			i += 1
	# women first, then men: reorder so each element's pair stands together (F, M)
	var order := []
	for el: String in ELEMENTS:
		for f: Dictionary in figs:
			if f.element == el:
				order.append(f)
	for k in order.size():
		(order[k].node as Node3D).position.x = (float(k) - 3.5) * SPACING
	_frame_all()
	await _frames(90)
	var views := String(args.get("views", "front,34,side,back")).split(",")
	for v: String in views:
		for f: Dictionary in figs:
			(f.node as Node3D).rotation_degrees.y = float(VIEWS.get(v, 0.0))
		await _frames(12)
		await _shot(v)
	if String(args.get("close", "1")) == "1":
		for k in 4:
			var el: String = ELEMENTS[k]
			for f: Dictionary in figs:
				(f.node as Node3D).rotation_degrees.y = 20.0
			var cx := (float(k * 2) + 0.5 - 3.5) * SPACING
			cam.fov = 30.0
			cam.position = Vector3(cx - 0.3, 1.15, 4.0)
			cam.look_at(Vector3(cx, 0.92, 0.0))
			await _frames(12)
			await _shot("close_" + el)
		_frame_all()
	if String(args.get("action", "1")) == "1":
		var anim := BendPoses.animation(ACTION_CLIP)
		if anim != null:
			for f: Dictionary in figs:
				var ap: AnimationPlayer = f.ap
				if ap == null:
					continue
				var lib := AnimationLibrary.new()
				lib.add_animation(&"pose", anim)
				if not ap.has_animation_library(&"shots"):
					ap.add_animation_library(&"shots", lib)
				ap.play(&"shots/pose")
				ap.seek(anim.length * 0.45, true)
				ap.pause()
				(f.node as Node3D).rotation_degrees.y = 30.0
			await _frames(12)
			await _shot("action")
		else:
			print("no clip ", ACTION_CLIP)
	print("RING OUTFIT SHOTS DONE")
	quit(0)
