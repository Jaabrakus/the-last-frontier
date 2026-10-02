extends SceneTree
## A look at the clouds (user 2026-10-01: grain on the cloud edges): the real level in a window, the camera turned up toward the
## horizon, frames saved after the temporal AA has settled.
##   Godot --path . --resolution 1600x900 -s tools/perf/sky_shot.gd -- out=/abs/dir [hour=14] [pitch=0.18] [name=sky]
func _initialize() -> void:
	var out := "/tmp"
	var nm := "sky"
	var pitch := 0.18
	var hour := 14.0
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("out="): out = s.get_slice("=", 1)
		elif s.begins_with("name="): nm = s.get_slice("=", 1)
		elif s.begins_with("pitch="): pitch = float(s.get_slice("=", 1))
		elif s.begins_with("hour="): hour = float(s.get_slice("=", 1))
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 300:
		await process_frame
	var p: FrontierPlayer = current_scene.get_node_or_null("Player")
	var clock = current_scene.find_child("WorldClock", true, false)
	if clock and clock.has_method("set_hour"):
		clock.set_hour(hour)
	if p:
		p.ignore_mouse_capture = true
		p.pitch = pitch
	for i in 240:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, nm])
	print("SKY SHOT ", out, "/", nm, ".png")
	quit()
