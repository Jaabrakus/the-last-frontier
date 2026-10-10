extends SceneTree
## Hair styles close up (hair v3): each style on a man and a woman of a people, framed on the face,
## turned to several angles, each shot cropped round the head (its position projected by the stage
## camera). Needs a window:
##
##   Godot --path . --resolution 1280x720 -s tools/character/hair_preview.gd -- out=DIR \
##       styles=hair_queue_ribbon,hair_long_loose [people=english] [yaws=0.5,1.6,3.14] [sexes=1,2] [fov=14] [dz=0 (look lower: -0.15)] [half=0.14 (crop half size, m)]
##
## Writes <style>_<bt>_<i>.png (square crops) and prints HAIR PREVIEW DONE.

var _out := ""
var _styles := []
var _people := "english"
var _yaws := [0.5, 1.6, 3.14]
var _sexes := [1, 2]
var _fov := 14.0
var _dz := 0.0
var _half := 0.14


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("styles="):
			_styles = Array(a.substr(7).split(","))
		elif a.begins_with("people="):
			_people = a.substr(7)
		elif a.begins_with("yaws="):
			_yaws = Array(a.substr(5).split(",")).map(func(x: String) -> float: return float(x))
		elif a.begins_with("fov="):
			_fov = float(a.substr(4))
		elif a.begins_with("dz="):
			_dz = float(a.substr(3))
		elif a.begins_with("half="):
			_half = float(a.substr(5))
		elif a.begins_with("sexes="):
			_sexes = Array(a.substr(6).split(",")).map(func(x: String) -> int: return int(x))
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("hair_preview: needs out=DIR and a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, OS.has_environment("TB_ON_TOP"))
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
	# a close shot: the stage's camera held still, narrowed on the head (the window's pixels on the hair)
	var cam := c.stage.camera
	var head := c.stage.head_position()
	c.stage.set_process(false)
	cam.h_offset = 0.0
	cam.fov = _fov
	cam.look_at(head + Vector3(0, 0.02 + _dz, 0))
	await _frames(4)
	await RenderingServer.frame_post_draw
	# the stage's own viewport: the figure without the creator's panels
	var img := c.stage.get_viewport().get_texture().get_image()
	var p := cam.unproject_position(head + Vector3(0, 0.02 + _dz, 0))
	var q := cam.unproject_position(head + Vector3(0, 0.02 + _dz, 0) + cam.global_transform.basis.x * _half)
	var half := int(absf(q.x - p.x)) + 1
	var r := Rect2i(int(p.x) - half, int(p.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(420, 420, Image.INTERPOLATE_LANCZOS)
	crop.save_png("%s/%s.png" % [_out, name])
	c.stage.set_process(true)
	print("shot ", name)


func _run() -> void:
	var c := CharacterCreator.open(null)
	await _frames(10)
	var blink := c.stage.find_child("FaceBlink", true, false) as FaceBlink
	if blink:
		blink.process_mode = Node.PROCESS_MODE_DISABLED
		blink.set_blink(0.0)
	for st: String in _styles:
		for bt: int in _sexes:
			c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, _people), bt)
			c.look.hair["style"] = st
			c._refresh_all()
			c._set_focus("face")
			c.stage.show_look(c.look, true)
			for yi in _yaws.size():
				c.stage.set_yaw(_yaws[yi])
				await _settle(c)
				await _shot(c, "%s_%d_%d" % [st, bt, yi])
	c.close(false)
	await _frames(3)
	print("HAIR PREVIEW DONE")
	quit(0)
