extends SceneTree
## Renders a move's reference path as a picture strip (side view) for the hero contact
## annotations (design 8.4): the Actor_B body plays each part of the move on its reference
## root (traversal_runtime.json align, or the rig origin with `static`), in front of a 10 cm grid,
## one frame every `step` seconds. Windowed only (it renders); the strip is saved as a PNG.
##
##   Godot --path . -s tools/traversal/clip_strip.gd -- move=climb_hang_3m [step=0.1] [static]
##         [t0=0] [t1=inf] [out=/path.png] [cols=12]

const TABLE := "res://data/traversal/traversal_runtime.json"
const W := 240
const H := 360

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	var mid := str(_args.get("move", ""))
	var m: Dictionary = table.moves[mid]
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.93, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -60, 0)
	world.add_child(sun)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	BindRest.ensure(sk, ap)
	CharacterBodyMesh.attach(sk, ap)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Grid (10 cm) in the side plane behind the character, ground line.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in range(-10, 41):
		var y := k * 0.1
		im.surface_set_color(Color(0.3, 0.3, 0.3) if k % 5 == 0 else Color(0.75, 0.75, 0.75))
		im.surface_add_vertex(Vector3(0.8, y, -2.0))
		im.surface_add_vertex(Vector3(0.8, y, 4.0))
	for k in range(-20, 41):
		var z := k * 0.1
		im.surface_set_color(Color(0.3, 0.3, 0.3) if k % 5 == 0 else Color(0.75, 0.75, 0.75))
		im.surface_add_vertex(Vector3(0.8, -1.0, z))
		im.surface_add_vertex(Vector3(0.8, 4.0, z))
	im.surface_end()
	var gm := MeshInstance3D.new()
	gm.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	gm.material_override = mat
	world.add_child(gm)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(_args.get("size", "3.6"))
	world.add_child(cam)
	cam.current = true
	var tr: Dictionary = m.track
	var hz := float(tr.hz)
	var step := float(_args.get("step", "0.1"))
	var t0 := float(_args.get("t0", "0"))
	var t1 := minf(float(_args.get("t1", "999")), float(m.duration))
	var frames := []
	var t := t0
	while t <= t1 + 1e-6:
		frames.append(t)
		t += step
	var cols := int(_args.get("cols", "12"))
	var rows := int(ceil(frames.size() / float(cols)))
	var strip := Image.create(W * cols, H * rows, false, Image.FORMAT_RGBA8)
	strip.fill(Color(1, 1, 1))
	var parts: Array = m.parts
	for fi in frames.size():
		var ft: float = frames[fi]
		var k := 0
		while k < parts.size() - 1 and ft >= float(parts[k + 1].t0) - 1e-9:
			k += 1
		var p: Dictionary = parts[k]
		var ct := clampf(ft - float(p.t0), 0.0, float(p.clip_length))
		var an := "actor_b/" + str(p.clip)
		if ap.current_animation != an:
			ap.play(an, 0.0)
		ap.seek(ct, true, true)
		var i := clampi(int(round(ft * hz)), 0, int(tr.n) - 1)
		var al := Vector3(float(tr.align[3 * i]), float(tr.align[3 * i + 1]), float(tr.align[3 * i + 2]))
		if _args.has("static"):
			al = Vector3.ZERO
		inst.position = al
		var focus := Vector3(al.x, al.y + 0.9, al.z)
		match str(_args.get("view", "side")):
			"top":
				cam.position = focus + Vector3(0.0, 6.0, 0.0)
				cam.look_at(focus, Vector3(0, 0, 1))
			"front":
				cam.position = focus + Vector3(0.0, 0.0, 6.0)
				cam.look_at(focus, Vector3.UP)
			_:
				cam.position = focus + Vector3(-6.0, 0.0, 0.0)
				cam.look_at(focus, Vector3.UP)
		if fi == 0:
			await process_frame
			await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var x := (fi % cols) * W
		var y := (fi / cols) * H
		strip.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(x, y))
		print("frame %d t %.2f part %d clip %s ct %.2f align y %.2f" % [fi, ft, k, str(p.clip).trim_prefix("actor_b-"), ct, al.y])
	var out := str(_args.get("out", "user://clip_strip_%s.png" % mid))
	strip.save_png(out)
	print("saved ", out)
	quit(0)
