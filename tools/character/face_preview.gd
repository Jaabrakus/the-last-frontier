extends SceneTree
## Head v3 preview (2026-09-27): peoples on both body types (face 1, realistic), Fine-tune sweeps of
## face features at -1 / +1, and the blink. Needs a window:
##
##   Godot --path . --resolution 1280x720 -s tools/character/face_preview.gd -- out=DIR [set=peoples|sweep|blink|all]

const PEOPLES := ["english", "scots_irish", "spanish", "haudenosaunee", "lenape", "west_african", "african_american",
		"ethiopian", "japanese", "chinese", "korean", "south_asian", "filipino", "thai", "pacific_islander", "arab", "persian",
		"ottoman_turkish", "north_african", "metis"]
const SWEEP := ["length", "jaw_width", "chin_projection", "cheekbones", "cheek_fullness", "nose_width", "nose_length",
		"nose_hump", "lips_upper", "eye_height", "epicanthus", "ears"]

var _out := ""
var _set := "all"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("set="):
			_set = a.substr(4)
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("v3_preview: needs out=DIR and a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(c: CharacterCreator) -> void:
	for i in 240:
		await process_frame
		if c.stage.settled() and i > 20:
			break
	await _frames(4)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("shot ", name)


func _face(c: CharacterCreator, pid: String, bt: int) -> void:
	c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, pid), bt)
	c._refresh_all()
	c._set_focus("face")
	c.stage.show_look(c.look, true)


func _run() -> void:
	var c := CharacterCreator.open(null)
	await _frames(10)
	var blink := c.stage.find_child("FaceBlink", true, false) as FaceBlink
	if blink:
		blink.process_mode = Node.PROCESS_MODE_DISABLED
		blink.set_blink(0.0)
	if _set in ["peoples", "all"]:
		for pid: String in PEOPLES:
			for bt in [1, 2]:
				_face(c, pid, bt)
				c.stage.set_yaw(0.4)
				await _frames(40)
				await _settle(c)
				await _shot("p_%s_%d" % [pid, bt])
	if _set in ["sweep", "all"]:
		for base: Array in [["english", 1], ["haudenosaunee", 2]]:
			_face(c, base[0], base[1])
			c.stage.set_yaw(0.55)
			await _frames(40)
			var face0: Dictionary = (c.look.get("face", {}) as Dictionary).duplicate()
			for f: String in SWEEP:
				for w in [-1.0, 1.0]:
					var fc := face0.duplicate()
					fc["face_" + f] = w
					c.look["face"] = fc
					c.stage.show_look(c.look, true)
					await _frames(6)
					await _settle(c)
					await _shot("s_%s_%d_%s_%s" % [base[0], base[1], f, "m" if w < 0 else "p"])
			c.look["face"] = face0
	if _set in ["blink", "all"] and blink:
		for bt in [1, 2]:
			_face(c, "english", bt)
			c.stage.set_yaw(0.3)
			await _frames(40)
			for b in [0.0, 0.5, 1.0]:
				blink.set_blink(b)
				await _frames(4)
				await _shot("b_%d_%d" % [bt, int(b * 10)])
			blink.set_blink(0.0)
	c.close(false)
	await _frames(3)
	print("V3 PREVIEW DONE")
	quit(0)
