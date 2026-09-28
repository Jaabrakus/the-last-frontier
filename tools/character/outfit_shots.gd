extends SceneTree
## Turnarounds of the player's outfit (the legacy clothes with the cloth shader, and the
## customizer garments worn over them: PlayerAppearance / PlayerOutfit, the in-game path). Needs
## a window (not --headless); run it under a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/character/outfit_shots.gd -- out=DIR \
##       [light=game|studio] [hour=17] [outfit=<slot>:<id>[:<zone colour>[:<fur>]],..] [looks=<json>]
##       [views=front,34,side,back,back34,close_chest,close_legs,close_back] [debug=1|2|3] [tag=<name>]
##       [compare=1] [raw=1] [settle=<frames>]
##
## light=game    the real player in main.tscn under the game's own light and grade, the DayNight
##               clock stopped at hour=<h> (default 17)
## light=studio  a plain Actor_B idling in a neutral three-point studio
## outfit=       garments to wear, e.g. outer:fur_coat_tailored:fur_wolf,head:fur_cap:fur_beaver
##               ("-" as the id takes a slot off); looks=<json file>: {"<tag>": outfit dict, ...}
##               renders every look in turn
## debug=1       dirt / wear / sweat masks as colours, 2 the UV grid (5 cm), 3 the zones
## compare=1     each view also with the legacy glb's flat materials (<tag>_<view>_before.png), same
##               light; raw=1 renders only those
## Writes <out>/<tag>_<view>.png and prints OUTFIT SHOTS DONE (or FAILED).

const IDLE := &"actor_b/actor_b-p-stealth-idle"
## [name, offset direction in the character's frame (+Z = the way it faces), distance, focus bone]
const VIEWS := {
	"front": [Vector3(0, 0.12, 1), 3.4, "pelvis"], "34": [Vector3(0.75, 0.2, 0.75), 3.4, "pelvis"],
	"side": [Vector3(1, 0.12, 0), 3.4, "pelvis"], "back": [Vector3(0, 0.15, -1), 3.4, "pelvis"],
	"back34": [Vector3(-0.7, 0.25, -0.7), 3.4, "pelvis"],
	"close_chest": [Vector3(0.35, 0.1, 1), 1.35, "spinec"], "close_legs": [Vector3(0.3, 0.05, 1), 1.5, "l_knee"],
	"close_back": [Vector3(-0.3, 0.2, -1), 1.4, "spinec"], "close_hands": [Vector3(0.2, 0.2, 1), 1.0, "r_wrist"],
	"close_feet": [Vector3(0.4, 0.25, 1), 1.0, "l_ankle"], "close_head": [Vector3(0.4, 0.1, 1), 0.9, "headb"],
}

var args := {}
var out := ""
var failures := PackedStringArray()
var cam: Camera3D
var world: Node3D
var actor: Node3D
var body: CharacterBodyMesh
var player: FrontierPlayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://outfit_shots")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	if String(args.get("light", "game")) == "game":
		await _game_stage()
	else:
		await _studio_stage()
	var looks := {}
	if args.has("looks"):
		var d = JSON.parse_string(FileAccess.get_file_as_string(String(args.looks)))
		looks = d if d is Dictionary else {}
	else:
		looks[String(args.get("tag", "look"))] = PlayerOutfit.parse_arg(String(args.get("outfit", "")))
	for tag: String in looks:
		await _render_look(tag, looks[tag])
	print("OUTFIT SHOTS DONE" if failures.is_empty() else "OUTFIT SHOTS FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _studio_stage() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34, 0.36, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for l in [[Vector3(-30, 25, 0), 1.1, true], [Vector3(-10, -50, 0), 0.35, false], [Vector3(-20, 165, 0), 0.6, false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		d.shadow_enabled = l[2] and args.get("shadows", "1") == "1"
		world.add_child(d)
	actor = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(actor)
	var sk := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	body = CharacterBodyMesh.attach(sk, ap)
	BindRest.ensure_character(actor)
	var clip := String(args.get("clip", IDLE))
	if not clip.contains("/"):
		clip = "actor_b/" + clip
	ap.play(clip)
	if args.has("t"):
		ap.seek(float(args.t), true)
		ap.pause()
	cam = Camera3D.new()
	cam.fov = 30.0
	world.add_child(cam)
	cam.current = true
	await _frames(4)


func _game_stage() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in current_scene.find_children("*", "", true, false):
		if n is DayNight:
			(n as DayNight).clock.running = false
			(n as DayNight).clock.set_time(float(args.get("hour", "17")))
	body = player.appearance.body
	if args.get("hands_free", "1") == "1" and player.has_method("toggle_hands_free"):
		player.toggle_hands_free()
	cam = Camera3D.new()
	cam.fov = 30.0
	current_scene.add_child(cam)
	cam.current = true
	await _frames(int(args.get("settle", "240")))


func _render_look(tag: String, outfit: Dictionary) -> void:
	var look := AppearanceStore.load_current()
	look["outfit"] = outfit
	if player:
		player.appearance.apply(look)
	else:
		PlayerAppearance.dress(body, look)
	if args.get("raw", "0") == "1":
		_set_raw(true)
	# set=<param>:<value>;<param>:<value> on every cloth material (floats; a vec4 param gets all four)
	if args.has("set"):
		for kv in String(args.set).split(";", false):
			var k := kv.get_slice(":", 0)
			var f := float(kv.get_slice(":", 1))
			for mi: MeshInstance3D in body.meshes:
				if is_instance_valid(mi) and mi.mesh:
					for s in mi.mesh.get_surface_count():
						var m := mi.get_surface_override_material(s)
						if m is ShaderMaterial and (m as ShaderMaterial).shader == ClothMaterials.CLOTH_SHADER:
							var cur = (m as ShaderMaterial).get_shader_parameter(k)
							(m as ShaderMaterial).set_shader_parameter(k, Vector4(f, f, f, f) if cur is Vector4 else f)
	if args.has("nstr"):
		for mi: MeshInstance3D in body.meshes:
			if is_instance_valid(mi) and mi.mesh:
				for s in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(s)
					if m is ShaderMaterial and (m as ShaderMaterial).shader == ClothMaterials.CLOTH_SHADER:
						var f := float(args.nstr)
						(m as ShaderMaterial).set_shader_parameter("normal_strength", Vector4(f, f, f, f))
	if args.has("debug"):
		for mi: MeshInstance3D in body.meshes:
			if not is_instance_valid(mi) or mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s)
				if m is ShaderMaterial and (m as ShaderMaterial).shader == ClothMaterials.CLOTH_SHADER:
					(m as ShaderMaterial).set_shader_parameter("debug_view", int(args.debug))
	await _frames(20)
	if args.get("nofur", "0") == "1":
		for mi: MeshInstance3D in body.meshes:
			if is_instance_valid(mi) and mi.mesh:
				for s in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(s)
					if m is ShaderMaterial and (m as ShaderMaterial).shader == ClothMaterials.FUR_SHADER:
						(m as ShaderMaterial).set_shader_parameter("hide_mask", Vector2i(-1, -1))
	if args.has("stride"):
		for mi: MeshInstance3D in body.meshes:
			if is_instance_valid(mi) and mi.mesh:
				for s in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(s)
					if m is ShaderMaterial and (m as ShaderMaterial).shader == ClothMaterials.FUR_SHADER:
						(m as ShaderMaterial).set_shader_parameter("shell_stride", int(args.stride))
	if args.get("furnoshadow", "0") == "1":
		for mi: MeshInstance3D in body.meshes:
			if is_instance_valid(mi) and String(mi.name).begins_with("outfit:"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# bench=N: render cost of this look (N forced draws from behind at the gameplay distance)
	if args.has("bench"):
		var sk0 := body.skeleton
		var f0 := (sk0.global_transform * sk0.get_bone_global_pose(sk0.find_bone("pelvis"))).origin
		cam.global_position = f0 + (sk0.global_basis * Vector3(0.0, 0.25, -1.0)).normalized() * 3.6 + Vector3.UP * 0.6
		cam.look_at(f0 + Vector3.UP * 0.4, Vector3.UP)
		await _frames(10)
		var n := int(args.bench)
		var best := INF
		for rep in 3:
			var t0 := Time.get_ticks_usec()
			for i in n:
				RenderingServer.force_draw(false)
			best = minf(best, float(Time.get_ticks_usec() - t0) / n / 1000.0)
		print("BENCH %s: %.3f ms per frame (best of 3 x %d forced draws)" % [tag, best, n])
		return
	var views := String(args.get("views", "front,34,side,back")).split(",")
	for v in views:
		if not VIEWS.has(v):
			failures.append("unknown view " + v)
			continue
		var spec: Array = VIEWS[v]
		var sk := body.skeleton
		var bi := sk.find_bone(String(spec[2]))
		var focus := (sk.global_transform * sk.get_bone_global_pose(bi)).origin
		var dir: Vector3 = (sk.global_basis * (spec[0] as Vector3)).normalized()
		cam.global_position = focus + dir * float(spec[1])
		cam.look_at(focus, Vector3.UP)
		# compare=1: the same view with the legacy glb's flat materials first (same light, same frame
		# of the idle), saved as <tag>_<view>_before.png
		if args.get("compare", "0") == "1":
			_set_raw(true)
			await _snap("%s_%s_before" % [tag, v])
			_set_raw(false)
		await _snap("%s_%s" % [tag, v])


func _snap(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out.path_join(name + ".png")
	if img == null or img.save_png(path) != OK:
		failures.append("could not save " + path)
	else:
		print("saved ", path)


var _cloth_mats := {}


## The legacy glb's own flat materials (before the cloth shader) on or off.
func _set_raw(on: bool) -> void:
	for mi: MeshInstance3D in body.meshes:
		if not is_instance_valid(mi) or mi.mesh == null or not String(mi.name) in ClothMaterials.LEGACY_MESHES:
			continue
		for s in mi.mesh.get_surface_count():
			var key := "%s/%d" % [mi.name, s]
			if on:
				if not _cloth_mats.has(key):
					_cloth_mats[key] = mi.get_surface_override_material(s)
				var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if src:
					var m := src.duplicate() as BaseMaterial3D
					m.vertex_color_use_as_albedo = true
					mi.set_surface_override_material(s, m)
			elif _cloth_mats.has(key):
				mi.set_surface_override_material(s, _cloth_mats[key])
