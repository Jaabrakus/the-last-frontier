extends SceneTree
## Every hair style on the head (a man and a woman, three-quarter view), under the creator's light.
##   Godot --path . --resolution 1280x720 -s tools/character/hair_check_shots.gd -- out=DIR [styles=a,b] [yaws=0.9,0,2.6]
var _out := ""
var _only := []
var _yaws := [0.9]
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("styles="):
			_only = Array(a.substr(7).split(","))
		elif a.begins_with("yaws="):
			_yaws = Array(a.substr(5).split(",")).map(func(x: String) -> float: return float(x))
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("hair_check_shots: needs out=DIR and a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, OS.has_environment("TB_ON_TOP"))
	_run.call_deferred()
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _run() -> void:
	var c := CharacterCreator.open(null)
	await _frames(10)
	var styles := []
	for f in DirAccess.get_files_at("res://assets/character/hair"):
		if f.ends_with(".glb") and (_only.is_empty() or f.get_basename() in _only):
			styles.append(f.get_basename())
	for bt in [1, 2]:
		c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, "english"), bt)
		c._refresh_all()
		c._set_focus("hair_style")
		c.stage.set_yaw(0.9)
		await _frames(90)
		for st: String in styles:
			c.look.hair["style"] = st
			c.stage.show_look(c.look, true)
			c._set_focus("hair_style")
			for yi in _yaws.size():
				c.stage.set_yaw(_yaws[yi])
				for i in 240:
					await process_frame
					if c.stage.settled() and i > 30:
						break
				await RenderingServer.frame_post_draw
				var tag := "" if _yaws.size() == 1 else "_y%d" % yi
				root.get_texture().get_image().save_png("%s/%s_%d%s.png" % [_out, st, bt, tag])
	c.close(false)
	await _frames(3)
	print("HAIR CHECK DONE")
	quit(0)
