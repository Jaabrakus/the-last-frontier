extends SceneTree
## Faces close up (skin realism): each people's first preset, a man and a woman, the stage camera held
## still and narrowed on the face at a few angles, cropped round the head. Needs a window:
##
##   Godot --path . --resolution 1280x720 -s tools/character/skin_preview.gd -- out=DIR \
##       [people=english,west_african,chinese] [yaws=0.45,1.3] [sexes=1,2] [fov=11] [hair=] [skin=k:v;k:v]
##
## Writes <people>_<bt>_<i>.png (square crops) and prints SKIN PREVIEW DONE. hair= sets one hair style
## for every shot ("none" for no hair).

var _out := ""
var _people := ["english", "west_african", "chinese"]
var _yaws := [0.45, 1.3]
var _sexes := [1, 2]
var _fov := 11.0
var _hair := ""
var _skin := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("people="):
			_people = Array(a.substr(7).split(","))
		elif a.begins_with("yaws="):
			_yaws = Array(a.substr(5).split(",")).map(func(x: String) -> float: return float(x))
		elif a.begins_with("sexes="):
			_sexes = Array(a.substr(6).split(",")).map(func(x: String) -> int: return int(x))
		elif a.begins_with("fov="):
			_fov = float(a.substr(4))
		elif a.begins_with("hair="):
			_hair = a.substr(5)
		elif a.begins_with("skin="):
			# skin=param:value;param:value (skin.gdshader uniforms, for tuning)
			for kv in a.substr(5).split(";"):
				var p := kv.split(":")
				if p.size() == 2:
					_skin[p[0]] = float(p[1])
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("skin_preview: needs out=DIR and a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(c: CharacterCreator) -> void:
	for i in 300:
		await process_frame
		if c.stage.settled() and i > 40:
			break
	await _frames(6)


func _shot(c: CharacterCreator, name: String) -> void:
	var cam := c.stage.camera
	var head := c.stage.head_position()
	c.stage.set_process(false)
	cam.h_offset = 0.0
	cam.fov = _fov
	cam.look_at(head + Vector3(0, 0.0, 0))
	await _frames(8)
	await RenderingServer.frame_post_draw
	var img := c.stage.get_viewport().get_texture().get_image()
	var p := cam.unproject_position(head)
	var q := cam.unproject_position(head + cam.global_transform.basis.x * 0.12)
	var half := int(absf(q.x - p.x)) + 1
	var r := Rect2i(int(p.x) - half, int(p.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(480, 480, Image.INTERPOLATE_LANCZOS)
	crop.save_png("%s/%s.png" % [_out, name])
	c.stage.set_process(true)
	print("shot ", name)


func _apply_skin(n: Node) -> void:
	var mi := n as MeshInstance3D
	if mi and mi.mesh:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as ShaderMaterial
			if m and m.shader and m.shader.resource_path.ends_with("skin.gdshader"):
				for k in _skin:
					m.set_shader_parameter(k, _skin[k])
	for ch in n.get_children():
		_apply_skin(ch)


func _run() -> void:
	var c := CharacterCreator.open(null)
	await _frames(10)
	var blink := c.stage.find_child("FaceBlink", true, false) as FaceBlink
	if blink:
		blink.process_mode = Node.PROCESS_MODE_DISABLED
		blink.set_blink(0.0)
	for pid: String in _people:
		for bt: int in _sexes:
			c.look = CreatorOptions.with_people(CreatorOptions.with_body_type(c.look, bt), pid)
			if not _hair.is_empty():
				c.look.hair["style"] = "" if _hair == "none" else _hair
			c._refresh_all()
			c._set_focus("face")
			c.stage.show_look(c.look, true)
			if not _skin.is_empty():
				await _frames(2)
				_apply_skin(c.stage)
			for yi in _yaws.size():
				c.stage.set_yaw(_yaws[yi])
				await _settle(c)
				await _shot(c, "%s_%d_%d" % [pid, bt, yi])
	c.close(false)
	await _frames(3)
	print("SKIN PREVIEW DONE")
	quit(0)
