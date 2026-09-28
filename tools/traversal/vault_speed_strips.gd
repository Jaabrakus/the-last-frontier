extends SceneTree
## Side-view frames of the player vaulting (VaultSpeedHarness, windowed: it renders), for the before / after
## filmstrips of the vault speed push (user 2026-09-26: "also when we vault the char model should not slow
## down"). An orthographic camera looks at the obstacle from the side (the run goes left to right, 1 m lines
## on the ground); a frame is saved every `every` physics ticks while the body is in view, with the tick's
## speeds and traversal state in frames.json. tools/traversal/vault_speed_compose.py turns two such runs into
## a chronophotograph (every 0.1 s over one background) and a filmstrip.
##
##   Godot --fixed-fps 120 --resolution 1280x720 --path . -s tools/traversal/vault_speed_strips.gd -- \
##       obstacle=wall90 gait=sprint out=/abs/dir [every=4]
## This tool only renders the animation data.

const VIEW_BACK := 4.5            ## m of the approach in view (before the obstacle's face)
const VIEW_FWD := 5.5             ## m after it
const CAM_X := 12.0

var _args := {}
var _out := ""
var _every := 4
var _cam: Camera3D
var _shots: Array = []            ## [tick index, file]
var _plate := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	InputSetup.ensure()
	_out = str(_args.get("out", OS.get_user_data_dir() + "/vault_strips"))
	_every = int(_args.get("every", "4"))
	DirAccess.make_dir_recursive_absolute(_out)
	var h := VaultSpeedHarness.new(self)
	h.on_frame = _on_frame
	var r: Dictionary = await h.run(str(_args.get("obstacle", "wall90")), str(_args.get("gait", "sprint")), true)
	var meta := {"obstacle": r.get("obstacle"), "gait": r.get("gait"), "move": r.get("move", ""), "began": r.get("began"),
			"ended": r.get("ended"), "summary": {}, "view": [VaultSpeedHarness.OBSTACLE_Z + VIEW_BACK, VaultSpeedHarness.OBSTACLE_Z - VIEW_FWD],
			"frames": []}
	for k in ["steady", "entry", "min_cap", "min_cap_t", "min_model", "min_model_t", "exit", "end", "duration", "slide_max"]:
		meta.summary[k] = r.get(k)
	for s: Array in _shots:
		var f: Dictionary = h.frames[int(s[0])]
		meta.frames.append({"file": s[1], "t": float(f.t), "t_rel": float(f.t) - float(r.get("began", 0.0)),
				"v_cap": float(f.get("v_cap", 0.0)), "v_model": float(f.get("v_model_s", 0.0)), "mode": str(f.mode),
				"move": str(f.move), "rate": float(f.rate), "z": (f.pos as Vector3).z})
	var prof := []
	for f: Dictionary in h.frames:
		prof.append([float(f.t) - float(r.get("began", 0.0)), float(f.get("v_cap", 0.0)), float(f.get("v_model_s", 0.0)), str(f.mode)])
	meta["profile"] = prof
	var fa := FileAccess.open(_out + "/frames.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(meta, " "))
	fa.close()
	print("VAULT STRIPS %s %s: %d frames -> %s" % [meta.obstacle, meta.gait, _shots.size(), _out])
	quit(0)


func _on_frame(h: VaultSpeedHarness, rec: Dictionary) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = (VIEW_BACK + VIEW_FWD) * 720.0 / 1280.0
		var zc := VaultSpeedHarness.OBSTACLE_Z + (VIEW_BACK - VIEW_FWD) * 0.5
		h.arena.add_child(_cam)
		# (a little from above: the ground shows as a band, the metre stakes behind the running line)
		_cam.global_position = Vector3(CAM_X, 1.35 + CAM_X * tan(deg_to_rad(8.0)), zc)
		_cam.look_at(Vector3(0, 1.35, zc))
	_cam.current = true
	if h.player.hud:
		h.player.hud.visible = false
	var z := (rec.pos as Vector3).z
	if _args.has("debug") and h.frames.size() % 60 == 1:
		print("  dbg t %.2f pos %s vel %s fwd %s vec %s dead %s floor %s focus %s" % [float(rec.t), str(rec.pos), str(h.player.velocity),
				str(Input.is_action_pressed("move_forward")), str(Input.get_vector("move_left", "move_right", "move_forward", "move_back")),
				str(h.player.is_dead), str(h.player.is_on_floor()), str(DisplayServer.window_is_focused())])
	var in_view := z < VaultSpeedHarness.OBSTACLE_Z + VIEW_BACK + 1.0 and z > VaultSpeedHarness.OBSTACLE_Z - VIEW_FWD - 1.0
	if not _plate and z > VaultSpeedHarness.OBSTACLE_Z + VIEW_BACK + 3.0 and h.frames.size() > 30:
		# the background without the player (it is still out of view)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(_out + "/plate.png")
		_plate = true
		return
	if not in_view or (h.frames.size() - 1) % _every != 0:
		return
	await RenderingServer.frame_post_draw
	var file := "f_%04d.png" % (h.frames.size() - 1)
	root.get_viewport().get_texture().get_image().save_png(_out + "/" + file)
	_shots.append([h.frames.size() - 1, file])
