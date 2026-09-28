extends SceneTree
## Same-session A/B captures of the u10 reference views (forest performance pass, 2026-09-25).
## Windowed; wrap it in a time limit (a script error leaves the window open):
##
##   Godot --path . --resolution 1280x720 -s tools/environment/perf/ab_shots.gd -- --no-capture \
##       out=<dir> [variants=near_fade_off,hard_switch] [views=spawn_gate,...] [settle=90] [freeze=1]
##
## For every view (scenic_shots.gd's viewpoints and placement) the reference state REF and each
## variant are captured in the same session, in the order REF, v1, v2, ..., REF (the second REF
## measures the capture noise of that view). freeze=1 (default) sets Engine.time_scale = 0, so the
## wind, the flag and the sky do not move between captures (shader TIME follows the scaled step).
## Saves <out>/<state>_<view>.png (REF2 for the second reference). Ends with AB SHOTS DONE.
##
## Variants (all reversible at runtime, nothing is rebuilt):
##   near_fade_off  the near-camera leaf fade off (the look before 2026-09-25)
##   fade_self_off  the tree LOD / impostor nodes with Godot's fade off (margins kept: hysteresis)
##   hard_switch    tree LODs and impostors switch at the band centre, no overlap, no fade
##   overlap_band   tree LODs and impostors overlap over [begin - margin, end + margin], fade off

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const VIEWS := {
	"spawn_gate": [Vector3(1.4, 1.7, 4.0), Vector3(0.0, 1.4, -45.0), 60.0],
	"firing_line": [Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), 55.0],
	"range_lookback": [Vector3(5.0, 1.7, -118.0), Vector3(0.0, 2.8, -16.0), 50.0],
	"forest": [Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), 65.0],
	"parade": [Vector3(7.0, 1.7, 11.0), Vector3(-8.0, 2.4, 3.0), 65.0],
	"aerial": [Vector3(48.0, 30.0, 48.0), Vector3(0.0, 0.0, -22.0), 55.0],
}

var args := {}
var view: SubViewport
var level: Node
var veg: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://ab_shots")
	var settle := int(args.get("settle", "90"))
	var variants: PackedStringArray = String(args.get("variants", "near_fade_off")).split(",", false)
	var views: PackedStringArray = String(args.get("views", ",".join(VIEWS.keys()))).split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	level = current_scene
	veg = level.get_node("Vegetation")
	var player: Node3D = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player.has_method("switch_weapon"):
		player.call("switch_weapon", "musket")
	player.set("yaw", 0.0)
	player.set("pitch", 0.0)
	if player.get("hud"):
		player.get("hud").visible = false
	var px := DisplayServer.window_get_size()
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, px)
	root.disable_3d = true
	var cam: Camera3D = view.camera
	var rig := level.get_node_or_null("EnvironmentRig")
	if rig and "follow_camera" in rig:
		rig.follow_camera = cam
	if rig and rig.has_method("get_camera_attributes") and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(120)
	if args.get("freeze", "1") == "1":
		Engine.time_scale = 0.0

	for vname: String in views:
		var v: Array = VIEWS[vname]
		cam.fov = v[2]
		_place(cam, v[0], v[1], player)
		var states: Array[String] = ["REF"]
		states.append_array(Array(variants))
		states.append("REF2")
		for st: String in states:
			var undo := Callable()
			if st != "REF" and st != "REF2":
				undo = _variant(st)
			await _frames(settle)
			view.sync_camera()
			RenderingServer.force_draw(false)
			var img: Image = view.get_texture().get_image()
			img.save_png(out.path_join("%s_%s.png" % [st, vname]))
			if undo.is_valid():
				undo.call()
		print("AB view %s done" % vname)
	Engine.time_scale = 1.0
	print("AB SHOTS DONE")
	quit()


func _place(cam: Camera3D, p: Vector3, target: Vector3, player: Node3D) -> void:
	if p.y < 10.0:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0)
		q.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit and p.y - hit.position.y < 1.6 and hit.position.y < p.y + 8.0:
			var lift: float = hit.position.y + 1.6 - p.y
			p.y += lift
			target.y += lift
	cam.global_position = p
	cam.look_at(target)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


func _lod_nodes() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for c in veg.get_node("Visuals").get_children():
		var n := String(c.name)
		if n.begins_with("TreeLod") or n.begins_with("TreeImpostors_"):
			out.append(c)
	return out


func _save_ranges(nodes: Array[MultiMeshInstance3D]) -> Callable:
	var saved := {}
	for n in nodes:
		saved[n] = [n.visibility_range_begin, n.visibility_range_end, n.visibility_range_begin_margin,
				n.visibility_range_end_margin, n.visibility_range_fade_mode]
	return func() -> void:
		for n: MultiMeshInstance3D in saved:
			var s: Array = saved[n]
			n.visibility_range_begin = s[0]
			n.visibility_range_end = s[1]
			n.visibility_range_begin_margin = s[2]
			n.visibility_range_end_margin = s[3]
			n.visibility_range_fade_mode = s[4]


func _variant(vname: String) -> Callable:
	match vname:
		"near_fade_off":
			var was := {}
			for c in veg.get_node("Visuals").get_children():
				var m := (c as GeometryInstance3D).material_override as ShaderMaterial
				if m and not was.has(m) and m.shader and _has_uniform(m.shader, "near_fade_end"):
					was[m] = [m.get_shader_parameter("near_fade_begin"), m.get_shader_parameter("near_fade_end")]
					m.set_shader_parameter("near_fade_begin", 0.0)
					m.set_shader_parameter("near_fade_end", 0.0)
			return func() -> void:
				for m: ShaderMaterial in was:
					m.set_shader_parameter("near_fade_begin", was[m][0])
					m.set_shader_parameter("near_fade_end", was[m][1])
		"fade_self_off":
			var nodes := _lod_nodes()
			var undo := _save_ranges(nodes)
			for n in nodes:
				n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			return undo
		"hard_switch", "overlap_band":
			var nodes := _lod_nodes()
			var undo := _save_ranges(nodes)
			var k := 0.0 if vname == "hard_switch" else 1.0
			for n in nodes:
				if n.visibility_range_begin > 0.0:
					n.visibility_range_begin = maxf(n.visibility_range_begin - k * n.visibility_range_begin_margin, 0.001)
				if n.visibility_range_end > 0.0:
					n.visibility_range_end += k * n.visibility_range_end_margin
				n.visibility_range_begin_margin = 0.0
				n.visibility_range_end_margin = 0.0
				n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			return undo
	push_error("ab_shots: unknown variant %s" % vname)
	return Callable()


func _has_uniform(sh: Shader, uname: String) -> bool:
	for u in sh.get_shader_uniform_list():
		if u.name == uname:
			return true
	return false
