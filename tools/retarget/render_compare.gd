extends SceneTree
## Side-by-side frames: Actor_A source clip (orange) | Actor_B retarget (blue) [| Actor_B
## native clip of the same motion (green)], drawn as capsule mannequins on the two
## unskinned rigs. Needs a window (a rendering driver); it opens on screen briefly.
##
##   Godot --path <Player_Animation_Project>/godot_export -s <Frontier>/tools/retarget/render_compare.gd -- \
##       lib=<Frontier>/animations_extra/actor_a_rt_proto.res out=<dir> \
##       jobs=<jobs.json>
##
## jobs.json: [{"group": "machete", "clips": [..], "native": {clip: native_b_clip}, "frames": 5,
##              "camera": [x, y, z], "target": [x, y, z], "floor": true, "weapon": 0.5,
##              "horse": true, "horse_proxy": true, "lift": 1.37, "mount": "left" | "right" | "auto",
##              "ortho": <view height in m, orthographic camera>}]
## lib_name=<library name the retarget library is added under> (default actor_a_rt).
## horse_proxy draws a translucent horse (barrel, neck, head, legs) under the saddle attach
## point (horse.md 2.2 landmarks), scaled to the saddle height the figure stands at.
## weapon: bar length; weapon_a / weapon_b: {"axis": "x"|"y"|"z", "from": m, "to": m} = the bar
## along that axis of the prop bone (default +Z from -0.08 to length - 0.08), per figure, because
## the library converts some weapon frames (weapon_frames.py: blades along +Y, long guns turned).
## mount: the retargeted mount clips are baked into the saddle frame (retarget.diag.mount_align):
## Actor_B is drawn at the saddle attach point with the floor reference_saddle_height_m below it;
## Actor_A's source clip is moved into the same frame with the solved align (source_yaw_deg,
## source_offset_m), its floor source_saddle_height_m below; with mount_recipe_h the third figure
## plays the retarget on a horse of that saddle height with the manifest's runtime recipe (origin
## shifted down by (H - reference) x (1 - ground_to_saddle)), i.e. what the game has to do.
## Writes <out>/<group>__<clip>__<i>.png (one image per sampled frame) and prints them.
## The Actor_A skeleton gets its true bind pose (clip `bindpose`) as rest before playing,
## the proposed Actor_A rest fix (only in this scene; nothing is saved).

const SEGMENTS := [
	["pelvis", "spinea", 0.075], ["spinea", "spineb", 0.075], ["spineb", "spinec", 0.08], ["spinec", "spined", 0.085],
	["spined", "neck", 0.05], ["neck", "heada", 0.04],
	["spined", "l_clavicle", 0.045], ["l_clavicle", "l_shoulder", 0.045], ["l_shoulder", "l_elbow", 0.04],
	["l_elbow", "l_wrist", 0.032], ["l_wrist", "l_middlea", 0.024], ["l_wrist", "l_thumba", 0.014],
	["spined", "r_clavicle", 0.045], ["r_clavicle", "r_shoulder", 0.045], ["r_shoulder", "r_elbow", 0.04],
	["r_elbow", "r_wrist", 0.032], ["r_wrist", "r_middlea", 0.024], ["r_wrist", "r_thumba", 0.014],
	["pelvis", "l_upper_leg", 0.07], ["l_upper_leg", "l_knee", 0.06], ["l_knee", "l_ankle", 0.045],
	["l_ankle", "l_ball", 0.035], ["l_heel", "l_ball", 0.03],
	["pelvis", "r_upper_leg", 0.07], ["r_upper_leg", "r_knee", 0.06], ["r_knee", "r_ankle", 0.045],
	["r_ankle", "r_ball", 0.035], ["r_heel", "r_ball", 0.03],
]

var args := {}


class Figure:
	var root: Node3D
	var sk: Skeleton3D
	var ap: AnimationPlayer
	var parts := []  # [bone_a, bone_b, MeshInstance3D, radius]
	var head: MeshInstance3D
	var weapon: MeshInstance3D
	var weapon_len := 0.0
	var weapon_axis := 2  # prop bone axis the bar runs along (0 x, 1 y, 2 z)
	var weapon_from := -0.08
	var weapon_to_m := 0.0  # bar end along the axis (0: weapon_len - 0.08)
	var weapon_to := ""  # draw the weapon from the prop bone toward this bone (source keys no prop)
	var grip_l := Vector3.ZERO  # grip point offsets in the palm frames (source keys no prop: the line through them)
	var grip_r := Vector3.ZERO
	var enabled := true

	func build(scene_root: Node3D, inst: Node3D, color: Color, offset: Vector3, scale_r: float) -> void:
		root = inst
		scene_root.add_child(inst)
		inst.position = offset
		sk = inst.get_node("Skeleton3D")
		ap = inst.get_node("AnimationPlayer")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.7
		for s in SEGMENTS:
			if sk.find_bone(s[0]) == -1 or sk.find_bone(s[1]) == -1:
				continue
			var m := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = s[2] * scale_r
			cap.height = 0.2
			cap.radial_segments = 12
			cap.rings = 3
			m.mesh = cap
			m.material_override = mat
			scene_root.add_child(m)
			parts.append([s[0], s[1], m, s[2] * scale_r])
		head = MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.1 * scale_r
		sp.height = 0.23 * scale_r
		head.mesh = sp
		head.material_override = mat
		scene_root.add_child(head)
		weapon = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.05, 1.0)
		weapon.mesh = box
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.15, 0.15, 0.17)
		wm.metallic = 0.6
		weapon.material_override = wm
		weapon.visible = false
		scene_root.add_child(weapon)

	func gbasis(bone: String) -> Basis:
		return (sk.global_transform.basis * sk.get_bone_global_pose(sk.find_bone(bone)).basis).orthonormalized()

	func gpos(bone: String) -> Vector3:
		return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin

	func update() -> void:
		weapon.visible = enabled and weapon_len > 0.0
		head.visible = enabled
		if not enabled:
			for p in parts:
				p[2].visible = false
			return
		for p in parts:
			var a := gpos(p[0])
			var b := gpos(p[1])
			var m: MeshInstance3D = p[2]
			var d := b - a
			var l := d.length()
			if l < 1e-4:
				m.visible = false
				continue
			m.visible = true
			(m.mesh as CapsuleMesh).height = maxf(l + 2.0 * p[3], 2.0 * p[3] + 0.001)
			var y := d / l
			var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
			var z := x.cross(y)
			m.global_transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
		var ha := gpos("heada")
		var hb := gpos("headb")
		head.global_position = hb + (hb - ha).normalized() * 0.02
		if weapon_len > 0.0:
			var pt := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_hand_prop_attachment"))
			var b0 := pt.basis.orthonormalized()
			var z: Vector3 = b0[weapon_axis]
			var a0 := weapon_from
			var a1 := weapon_to_m if weapon_to_m != 0.0 else weapon_len - 0.08
			var o := pt.origin
			if weapon_to != "":
				# the source keys no prop: the weapon line through the two hands' grip points (the palm plus the
				# haft clips' grip point offset, weapon_frames.py), from 0.155 m below the left grip point
				# through the right one (the library's two-handed convention: the bar of the retarget starts
				# 0.08 m below its prop origin, which is 0.075 m below the left grip point)
				var gl := gpos(weapon_to) + gbasis(weapon_to) * grip_l
				var gr := gpos("r_palm") + gbasis("r_palm") * grip_r
				z = (gr - gl).normalized()
				o = gl
				a0 = -0.155
				a1 = weapon_len - 0.155
			var x := z.cross(Vector3.UP if absf(z.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
			var bz := Basis(x, z.cross(x), z)
			weapon.visible = true
			(weapon.mesh as BoxMesh).size = Vector3(0.02, 0.045, a1 - a0)
			weapon.global_transform = Transform3D(bz, o + z * (0.5 * (a0 + a1)))


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	_run.call_deferred()


func _apply_bind_rest(sk: Skeleton3D, lib: AnimationLibrary) -> int:
	var bind := lib.get_animation(&"bindpose")
	var n := 0
	for t in bind.get_track_count():
		var bone := sk.find_bone(str(bind.track_get_path(t).get_concatenated_subnames()))
		if bone == -1:
			continue
		var rest := sk.get_bone_rest(bone)
		match bind.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				rest.origin = bind.position_track_interpolate(t, 0.0)
			Animation.TYPE_ROTATION_3D:
				rest.basis = Basis(bind.rotation_track_interpolate(t, 0.0).normalized())
			_:
				continue
		sk.set_bone_rest(bone, rest)
		n += 1
	sk.reset_bone_poses()
	return n


func _mount_diag(anim: Animation) -> Dictionary:
	var st: Dictionary = anim.get_meta("retarget", {})
	return st.get("diag", {}).get("mount_align", {})


func _curve(c: Array, t: float) -> float:
	if c.is_empty():
		return 0.0
	var f := clampf(t * 30.0, 0.0, c.size() - 1.0)
	var i := int(floor(f))
	var j := mini(i + 1, c.size() - 1)
	return lerpf(float(c[i]), float(c[j]), f - i)


func _source_align(ma: Dictionary, t: float) -> Transform3D:
	# the solved ground -> saddle align of the Actor_A source clip (yaw about +Y, then offset)
	var yaw := deg_to_rad(_curve(ma.get("source_yaw_deg", []), t))
	var off: Array = ma.get("source_offset_m", [])
	var o := Vector3.ZERO
	if not off.is_empty():
		var f := clampf(t * 30.0, 0.0, off.size() - 1.0)
		var i := int(floor(f))
		var j := mini(i + 1, off.size() - 1)
		o = Vector3(off[i][0], off[i][1], off[i][2]).lerp(Vector3(off[j][0], off[j][1], off[j][2]), f - i)
	return Transform3D(Basis(Vector3.UP, yaw), o)


func _horse_proxy(scene: Node3D) -> Node3D:
	# 15-hand horse, saddle attach point at the origin, facing +Z (horse.md 2.2, Godot axes)
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.38, 0.25, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var parts := [
		[Vector3(0, -0.33, -0.74), Vector3(0, -0.30, 0.82), 0.28],   # barrel
		[Vector3(0, -0.12, 0.70), Vector3(0, 0.33, 1.45), 0.13],     # neck
		[Vector3(0, 0.35, 1.50), Vector3(0, -0.13, 1.88), 0.09],     # head
		[Vector3(0.15, -0.45, 0.62), Vector3(0.15, -1.37, 0.66), 0.05],
		[Vector3(-0.15, -0.45, 0.62), Vector3(-0.15, -1.37, 0.66), 0.05],
		[Vector3(0.14, -0.45, -0.58), Vector3(0.13, -1.37, -0.52), 0.06],
		[Vector3(-0.14, -0.45, -0.58), Vector3(-0.13, -1.37, -0.52), 0.06],
	]
	for p in parts:
		var a: Vector3 = p[0]
		var b: Vector3 = p[1]
		var m := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = p[2]
		cap.height = a.distance_to(b) + 2.0 * p[2]
		m.mesh = cap
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var y := (b - a).normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		m.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
		n.add_child(m)
	n.visible = false
	scene.add_child(n)
	return n


func _run() -> void:
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(args["jobs"]))
	var out_dir: String = args["out"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var rt_lib: AnimationLibrary = load(args["lib"])
	root.size = Vector2i(int(args.get("w", "900")), int(args.get("h", "640")))
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.93, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.6
	env.environment = e
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.78, 0.76, 0.7)
	floor.material_override = fm
	scene.add_child(floor)
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-12, 13):
		var v := i * 0.5
		im.surface_add_vertex(Vector3(v, 0.002, -6)); im.surface_add_vertex(Vector3(v, 0.002, 6))
		im.surface_add_vertex(Vector3(-6, 0.002, v)); im.surface_add_vertex(Vector3(6, 0.002, v))
	im.surface_end()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.53, 0.48)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid.material_override = gm
	scene.add_child(grid)
	var cam := Camera3D.new()
	cam.fov = 40
	scene.add_child(cam)
	cam.current = true

	# Actor_A with its true bind pose as rest; Actor_B twice (retarget, native)
	var a_inst: Node3D = load("res://characters/Actor_A.tscn").instantiate()
	var fa := Figure.new()
	fa.build(scene, a_inst, Color(0.9, 0.55, 0.2), Vector3(-0.8, 0, 0), 1.1)
	var a_lib := fa.ap.get_animation_library("actor_a")
	print("render_compare: Actor_A bind rest channels set: ", _apply_bind_rest(fa.sk, a_lib))
	var fb := Figure.new()
	fb.build(scene, load("res://characters/Actor_B.tscn").instantiate(), Color(0.25, 0.45, 0.85), Vector3(0.8, 0, 0), 1.0)
	var lib_name: String = args.get("lib_name", "actor_a_rt")
	fb.ap.add_animation_library(lib_name, rt_lib)
	var fn := Figure.new()
	fn.build(scene, load("res://characters/Actor_B.tscn").instantiate(), Color(0.3, 0.65, 0.35), Vector3(2.4, 0, 0), 1.0)
	fn.ap.add_animation_library(lib_name, rt_lib)
	# the library manifest (next to the .res): the two-handed grip points of Actor_A's palms
	var man_path := str(args["lib"]).get_basename() + ".json"
	if FileAccess.file_exists(man_path):
		var man = JSON.parse_string(FileAccess.get_file_as_string(man_path))
		if man is Dictionary:
			var th: Dictionary = man.get("weapon_frames", {}).get("two_hand", {})
			if th.has("grip_l_point") and th.has("grip_r_point"):
				fa.grip_l = Vector3(th["grip_l_point"][0], th["grip_l_point"][1], th["grip_l_point"][2])
				fa.grip_r = Vector3(th["grip_r_point"][0], th["grip_r_point"][1], th["grip_r_point"][2])
	var proxies := []
	for f in [fa, fb, fn]:
		proxies.append(_horse_proxy(scene))
	var saddles := []
	for f in [fa, fb, fn]:
		var s := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, 0.08, 0.5)
		s.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.45, 0.3, 0.18)
		s.material_override = sm
		scene.add_child(s)
		saddles.append(s)
	await process_frame
	await process_frame

	for job: Dictionary in jobs:
		var has_native: bool = job.has("native")
		fn.enabled = has_native or job.has("mount_recipe_h")
		var horse: bool = job.get("horse", false)
		floor.visible = job.get("floor", not horse)
		grid.visible = floor.visible
		var lift := Vector3(0, float(job.get("lift", 0.0)), 0)
		for fig in [fa, fb, fn]:
			fig.root.transform = Transform3D.IDENTITY
		var sp: Array = job.get("spacing", [-0.8, 0.8, 2.4])
		fa.root.position = Vector3(sp[0], 0, 0) + lift
		fb.root.position = Vector3(sp[1], 0, 0) + lift
		fn.root.position = Vector3(sp[2], 0, 0) + lift
		var bases := [fa.root.position, fb.root.position, fn.root.position]
		var show_proxy: bool = job.get("horse_proxy", false)
		var mount_side: String = job.get("mount", "")
		if mount_side != "":
			floor.visible = true
			grid.visible = true
		for i in saddles.size():
			proxies[i].scale = Vector3.ONE * (float(job.get("lift", 1.37)) / 1.37 if horse else 1.0)
			saddles[i].visible = horse
			saddles[i].position = bases[i] + Vector3(0, 0.02, 0)
			proxies[i].visible = show_proxy and (i < 2 or has_native)
			proxies[i].position = bases[i]
		if not has_native and not job.has("mount_recipe_h"):
			saddles[2].visible = false
		var c: Array = job["camera"]
		var t: Array = job["target"]
		cam.position = Vector3(c[0], c[1], c[2])
		cam.look_at(Vector3(t[0], t[1], t[2]))
		if job.has("ortho"):  # orthographic: A and B drawn at the same scale wherever they stand
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = float(job["ortho"])
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		fa.weapon_len = float(job.get("weapon", 0.0))
		fb.weapon_len = fa.weapon_len
		fn.weapon_len = 0.0
		for pair in [[fa, job.get("weapon_a", {})], [fb, job.get("weapon_b", {})]]:
			var fig: Figure = pair[0]
			var wcfg: Dictionary = pair[1]
			fig.weapon_axis = {"x": 0, "y": 1, "z": 2}.get(str(wcfg.get("axis", "z")), 2)
			fig.weapon_from = float(wcfg.get("from", -0.08))
			fig.weapon_to_m = float(wcfg.get("to", 0.0))
		for clip: String in job["clips"]:
			var anim_a := "actor_a/" + clip
			var anim_b := lib_name + "/" + clip
			var length := fa.ap.get_animation(anim_a).length
			var n := int(job.get("frames", 5))
			var st_b: Dictionary = fb.ap.get_animation(anim_b).get_meta("retarget", {})
			fa.weapon_to = "l_palm" if st_b.get("diag", {}).has("synthetic_grip") else ""
			var native := ""
			if has_native and job["native"].has(clip):
				native = "actor_b/" + str(job["native"][clip])
			for i in n:
				var tt := length * i / float(maxi(n - 1, 1))
				if mount_side != "":
					var ma := _mount_diag(fb.ap.get_animation(anim_b))
					var h_a := float(ma.get("source_saddle_height_m", 1.37))
					var h_b := float(ma.get("reference_saddle_height_m", 1.37))
					fa.root.transform = Transform3D(Basis.IDENTITY, Vector3(bases[0].x, h_a, bases[0].z)) * _source_align(ma, tt)
					fb.root.transform = Transform3D(Basis.IDENTITY, Vector3(bases[1].x, h_b, bases[1].z))
					proxies[0].position = Vector3(bases[0].x, h_a, bases[0].z)
					proxies[0].scale = Vector3.ONE * (h_a / 1.37)
					proxies[1].position = Vector3(bases[1].x, h_b, bases[1].z)
					proxies[1].scale = Vector3.ONE * (h_b / 1.37)
					saddles[0].position = proxies[0].position + Vector3(0, 0.02, 0)
					saddles[1].position = proxies[1].position + Vector3(0, 0.02, 0)
					if job.has("mount_recipe_h"):
						var H := float(job["mount_recipe_h"])
						var g := _curve(ma.get("ground_to_saddle", []), tt)
						fn.root.transform = Transform3D(Basis.IDENTITY, Vector3(bases[2].x, H - (H - h_b) * (1.0 - g), bases[2].z))
						proxies[2].position = Vector3(bases[2].x, H, bases[2].z)
						proxies[2].scale = Vector3.ONE * (H / 1.37)
						proxies[2].visible = show_proxy
						saddles[2].position = proxies[2].position + Vector3(0, 0.02, 0)
						saddles[2].visible = horse
				for pair in [[fa, anim_a, tt], [fb, anim_b, tt]]:
					var fig: Figure = pair[0]
					fig.sk.reset_bone_poses()
					fig.ap.play(pair[1])
					fig.ap.seek(pair[2], true)
					fig.ap.pause()
				if mount_side != "" and job.has("mount_recipe_h"):
					fn.sk.reset_bone_poses()
					fn.ap.play(anim_b)
					fn.ap.seek(tt, true)
					fn.ap.pause()
				elif native != "":
					fn.sk.reset_bone_poses()
					var nl := fn.ap.get_animation(native).length
					fn.ap.play(native)
					fn.ap.seek(nl * i / float(maxi(n - 1, 1)), true)
					fn.ap.pause()
				await process_frame
				for fig in [fa, fb, fn]:
					fig.update()
				await RenderingServer.frame_post_draw
				await process_frame
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				var path := "%s/%s__%s__%d.png" % [out_dir, job["group"], clip.replace("^", "_"), i]
				img.save_png(path)
				print("render_compare: ", path, "  t=%.2f" % tt)
	quit(0)
