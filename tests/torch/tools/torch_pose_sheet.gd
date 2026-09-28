extends SceneTree
## Contact sheet of Actor_B poses composed from clips (push n01b: choosing the source clips for the torch arm
## and the one-hand rifle hip carry). Needs a window (not --headless):
##   Godot --path . --resolution 1280x720 -s tests/torch/tools/torch_pose_sheet.gd -- out=<png> \
##       sets="<clip>@<t>[*w][+<clip>@<t>...]|<next set>|..." [views=front,left,right,top] [props=musket,torch]
##       [cell=320x400] [light=1.0]
## Each set is composed like LoadoutClipPoser (the first clip full body, later clips overwrite their channels;
## "*w" blends one in with weight w; "~" before a clip adds it as an additive). The musket rides on
## r_hand_prop_attachment (the player's musket_offset), the torch on l_hand_prop_attachment (TorchModels, the
## player's torch offset), so the props show where the clips put the hands. One row per set, one column per
## view; a label names the set.

var args := {}
const VIEWS := {
	"front": Vector3(0.35, 0.1, 2.3),
	"left": Vector3(2.3, 0.1, 0.25),
	"right": Vector3(-2.3, 0.1, 0.25),
	"top": Vector3(0.6, 1.9, 1.3),
	"back": Vector3(-0.4, 0.3, -2.3),
	"frontleft": Vector3(1.7, 0.3, 1.6),
	"frontright": Vector3(-1.7, 0.3, 1.6),
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var out: String = args.get("out", "user://torch_pose_sheet.png")
	var sets: PackedStringArray = String(args.get("sets", "actor_b-p-rifle-idle@0")).split("|")
	var views: PackedStringArray = String(args.get("views", "front,left,right")).split(",")
	var cell := Vector2i(320, 400)
	if args.has("cell"):
		cell = Vector2i(int(String(args.cell).get_slice("x", 0)), int(String(args.cell).get_slice("x", 1)))
	root.size = cell
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.17, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.58, 0.55)
	e.ambient_light_energy = 0.8
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	sun.light_energy = float(args.get("light", "1.2"))
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -30, 0)
	fill.light_energy = 0.5
	world.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.28, 0.25)
	floor_mesh.material_override = fm
	world.add_child(floor_mesh)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	CharacterBodyMesh.attach(sk, ap)
	var poser := LoadoutClipPoser.new(sk, ap)
	var props: PackedStringArray = String(args.get("props", "musket,torch")).split(",")
	if props.has("musket"):
		var att := BoneAttachment3D.new()
		att.bone_name = "r_hand_prop_attachment"
		sk.add_child(att)
		var m := WeaponModels.build("musket")
		m.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		att.add_child(m)
	if props.has("torch"):
		var att2 := BoneAttachment3D.new()
		att2.bone_name = "l_hand_prop_attachment"
		sk.add_child(att2)
		var t := TorchModels.build()
		t.transform = TorchModels.HAND_OFFSET
		att2.add_child(t)
	# ik=1: the game's TorchCarryIK corrections on top (torch=0 / hip=0 switch a side off; tilt=, out=, toff=x,y,z,
	# hp=, ho=, hoff=x,y,z its tunables)
	if args.get("ik", "0") == "1":
		var ik := TorchCarryIK.new()
		ik.name = "TorchCarryIK"
		sk.add_child(ik)
		ik.set_hand(ap.get_animation(LoadoutClipPoser.full_name(TorchCarryIK.HAND_CLIP)))
		ik.torch_on = args.get("torch", "1") == "1"
		ik.hip_on = args.get("hip", "1") == "1"
		ik.torch_tilt_deg = float(args.get("tilt", str(ik.torch_tilt_deg)))
		ik.torch_out_deg = float(args.get("out", str(ik.torch_out_deg)))
		ik.hip_pitch_deg = float(args.get("hp", str(ik.hip_pitch_deg)))
		ik.hip_out_deg = float(args.get("ho", str(ik.hip_out_deg)))
		ik.anchor_weight = float(args.get("anchor", "1"))
		if args.has("toff"):
			var v := String(args.toff).split_floats(",")
			ik.torch_offset = Vector3(v[0], v[1], v[2])
		if args.has("hoff"):
			var v2 := String(args.hoff).split_floats(",")
			ik.hip_offset = Vector3(v2[0], v2[1], v2[2])
		ik.snap()
		var body := sk.get_node_or_null("Body")
		if body:
			sk.move_child(body, sk.get_child_count() - 1)
	var cam := Camera3D.new()
	cam.fov = 34.0
	world.add_child(cam)
	cam.current = true
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	root.add_child(label)
	await process_frame
	var win := root.get_visible_rect().size
	var lw := win.y * float(cell.x) / cell.y
	label.position = Vector2((win.x - lw) * 0.5 + 4, 2)
	label.size = Vector2(lw - 8, 80)
	var sheet := Image.create(cell.x * views.size(), cell.y * sets.size(), false, Image.FORMAT_RGBA8)
	for si in sets.size():
		# compose like LoadoutClipPoser.pose(); "r:" / "l:" before a clip keeps only that side's bones of it
		sk.reset_bone_poses()
		for part in sets[si].split("+"):
			var add := part.begins_with("~")
			var p := part.trim_prefix("~")
			var only := ""
			if p.begins_with("r:") or p.begins_with("l:"):
				only = p.substr(0, 1) + "_"
				p = p.substr(2)
			var w := 1.0
			if "*" in p:
				w = float(p.get_slice("*", 1))
				p = p.get_slice("*", 0)
			var clip := p.get_slice("@", 0)
			var t := float(p.get_slice("@", 1)) if "@" in p else 0.0
			if not poser.has_clip(clip):
				print("missing clip ", clip)
				continue
			var keep := {}
			if only != "":
				for b in sk.get_bone_count():
					if not sk.get_bone_name(b).begins_with(only):
						keep[b] = [sk.get_bone_pose_position(b), sk.get_bone_pose_rotation(b)]
			var a := ap.get_animation(LoadoutClipPoser.full_name(clip))
			poser._apply(a, clampf(t, 0.0, a.length), add, w)
			for b in keep:
				sk.set_bone_pose_position(b, keep[b][0])
				sk.set_bone_pose_rotation(b, keep[b][1])
		var r := sk.find_bone("root")
		if r >= 0:
			sk.set_bone_pose_position(r, Vector3(sk.get_bone_rest(r).origin.x, sk.get_bone_pose_position(r).y, sk.get_bone_rest(r).origin.z))
		for vi in views.size():
			var v: String = views[vi]
			await process_frame
			var target := Vector3(0, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spined"))).origin.y - 0.15, 0)
			cam.global_position = target + (VIEWS.get(v, VIEWS.front) as Vector3)
			cam.look_at(target, Vector3.UP)
			label.text = "%d %s | %s" % [si, v, sets[si].replace("actor_b-", "")]
			var ikn := sk.get_node_or_null("TorchCarryIK") as TorchCarryIK
			if ikn and vi == 1:
				print("set %d: fist from neck %s, torch axis %.0f deg off vertical (turn %.0f), gun turn %.0f" % [si,
						ikn.last_fist.snapped(Vector3.ONE * 0.005), rad_to_deg(ikn.last_torch_axis.angle_to(Vector3.UP)),
						ikn.last_torch_turn_deg, ikn.last_gun_turn_deg])
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			# the window's own size wins over root.size on some platforms: crop its middle to the cell's aspect
			var hh := img.get_height()
			var ww := mini(int(hh * float(cell.x) / cell.y), img.get_width())
			var crop := img.get_region(Rect2i((img.get_width() - ww) / 2, 0, ww, hh))
			crop.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, cell), Vector2i(vi * cell.x, si * cell.y))
	sheet.save_png(out)
	print("saved ", out)
	quit()
