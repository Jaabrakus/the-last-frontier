extends SceneTree
## Impostor capture for the canopy trees (package C). Needs a window (not --headless); wrap it in
## a time limit. Renders each tree's LOD0 mesh with shaders/vegetation/tree_bake.gdshader
## (unshaded: the albedo pass, then the view-space normal pass) from 8 azimuths (0, 45, ... 315 deg
## around +Y; view k looks at the tree from direction (sin, 0, cos)(k * 45 deg)) with an
## orthographic camera, at 2x the final frame size, into <work>/<row>_<k>_{albedo,normal}.png and
## <work>/impostor_rows.json. assemble_impostors.py then downsamples, pads and packs the atlas.
##
##   Godot --path . -s tools/environment/vegetation/bake_impostors.gd -- work=<dir> [frame=256] [style=painted]
## style=painted: the painted trees (painted_bake.gdshader), for the distant trees' painted impostors
## (assemble_impostors.py name=painted).

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

## Rows of the atlas: canopy species and variant (the conifers' edge variants have their own).
const ROWS := [
	["white_pine", 0, 0], ["white_pine", 0, 2], ["hemlock", 1, 0], ["hemlock", 1, 2],
	["oak", 2, 0], ["oak", 2, 1], ["maple", 3, 0], ["maple", 3, 1], ["birch", 4, 0], ["birch", 4, 1],
]
const VIEWS := 8


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var work: String = args.get("work", "user://impostor_work")
	var frame := int(args.get("frame", "256"))
	var painted: bool = args.get("style", "") == "painted"
	DirAccess.make_dir_recursive_absolute(work)
	OS.low_processor_usage_mode_sleep_usec = 0

	var vp := SubViewport.new()
	vp.size = Vector2i(frame * 2, frame * 4)   # per row: width follows the tree's aspect
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.use_debanding = false
	vp.scaling_3d_scale = 1.0
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.environment = env
	cam.near = 0.1
	cam.far = 200.0
	vp.add_child(cam)
	cam.current = true
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(mi)
	for i in 4:
		await process_frame

	var rows := []
	for r in ROWS.size():
		var sp: String = ROWS[r][0]
		var kind: int = ROWS[r][1]
		var variant: int = ROWS[r][2]
		var info := Assets.tree(kind, variant)
		var mesh := Assets.tree_mesh(kind, variant, 0)
		if mesh == null or info.is_empty():
			push_error("bake_impostors: missing %s v%d" % [sp, variant])
			continue
		mi.mesh = mesh
		var aabb := mesh.get_aabb()
		var radius := maxf(maxf(absf(aabb.position.x), absf(aabb.end.x)), maxf(absf(aabb.position.z), absf(aabb.end.z)))
		var y0 := -0.4
		var top := aabb.end.y * 1.01
		# Each frame covers the tree's own box (w x h m); the capture keeps that aspect and
		# assemble_impostors.py stretches it into the 1 : 2 atlas cell (the impostor quad undoes it).
		var fw_m := radius * 2.04
		var fh_m := top - y0
		vp.size = Vector2i(maxi(64, roundi(frame * 4.0 * fw_m / fh_m)), frame * 4)
		var centre_y := y0 + fh_m * 0.5
		cam.size = fh_m
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		rows.append({"name": "%s_v%d" % [sp, variant], "frame_w": fw_m, "frame_h": fh_m, "frame_y0": y0})
		for mode in 2:
			mi.material_override = Assets.painted_bake_material(kind, mode) if painted else Assets.tree_bake_material(kind, mode)
			for k in VIEWS:
				var a := k * TAU / VIEWS
				var back := Vector3(sin(a), 0.0, cos(a))
				cam.global_position = Vector3(0, centre_y, 0) + back * 80.0
				cam.look_at(Vector3(0, centre_y, 0), Vector3.UP)
				for f in 3:
					RenderingServer.force_draw(false)
					await process_frame
				var img := vp.get_texture().get_image()
				img.save_png(work.path_join("row%02d_%d_%s.png" % [r, k, "albedo" if mode == 0 else "normal"]))
		print("IMPOSTOR row %d %s_v%d frame %.2f x %.2f m (%d x %d px)" % [r, sp, variant, fw_m, fh_m, vp.size.x, vp.size.y])
	var f := FileAccess.open(work.path_join("impostor_rows.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": rows, "frames": VIEWS, "frame_px": [frame, frame * 2]}, " "))
	f.close()
	print("IMPOSTOR BAKE DONE")
	quit()
