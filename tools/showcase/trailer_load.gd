extends SceneTree
## The trailer's opening take (user 2026-09-29: "use the load screen as the beginning of the trailer"): the game's own
## loading screen (LoadingScreen: an oil painting drifting nearer, its title and caption, the gold line of the progress)
## as a new game loads, one frame saved per engine frame for the take's length.
##
##   Godot --path . --resolution 1920x1080 --fixed-fps 30 -s tools/showcase/trailer_load.gd -- out=<dir> [seconds=6]
##   <out>/load/frames/f00000.jpg ...   the take (1920x1080), <out>/load/frames.txt   (as trailer.gd's takes)

const SIZE := Vector2i(1920, 1080)

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var out := str(args.get("out", "user://trailer_load")).path_join("load")
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	var most := int(round(float(args.get("seconds", 6.0)) * 30.0))
	InputSetup.ensure()
	await process_frame
	var ls := LoadingScreen.go(self, "res://scenes/main.tscn")
	await process_frame
	# (a new game loads in well under a second of engine time: the screen is held here and its painting's drift and
	# the progress line are run for the take's length, at twice the game's drift so the move reads in a few seconds)
	ls.set_process(false)
	var f := FileAccess.open(out.path_join("frames.txt"), FileAccess.WRITE)
	f.store_line("# frame engine_frame shot t  (fps 30, size %dx%d, the loading screen)" % [SIZE.x, SIZE.y])
	var n := 0
	var pic: Control = ls.get("_pic")
	while n < most:
		var t := n / 30.0
		var sc := 1.0 + LoadingScreen.DRIFT * clampf(t * 2.0 / 20.0, 0.0, 1.0)
		pic.scale = Vector2(sc, sc)
		ls.call("_progress", 0.72 * smoothstep(0.0, 1.0, t / (most / 30.0)))
		await process_frame
		var img := root.get_texture().get_image()
		if img.get_size() != SIZE:
			img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		img.save_jpg(out.path_join("frames/f%05d.jpg" % n), 0.93)
		f.store_line("%d %d load %.4f" % [n, Engine.get_process_frames(), n / 30.0])
		n += 1
	f.close()
	print("TRAILER load: %d frames -> %s" % [n, out])
	quit()
