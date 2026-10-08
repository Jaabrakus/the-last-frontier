extends Node3D
## Standalone reference-project viewer. No runtime dependency on Tidebreak.
var entries: Array = []
var filtered: Array = []
var rig: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var lines := ImmediateMesh.new()
var camera := Camera3D.new()
var picker := ItemList.new()
var status := Label.new()
var seek := HSlider.new()
var paused := false
var yaw := 0.6
var pitch := -0.12
var distance := 4.0
var capture_path := ""
var capture_frames := 0
var capture_time := 0.0
const HUMAN_BONES := ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://godot_library_report.json"))
	entries = data.clips
	add_child(camera)
	camera.current = true
	camera.fov = 45
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("152433")
	add_child(world)
	var wire := MeshInstance3D.new()
	wire.mesh = lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("8fefd3")
	wire.material_override = material
	add_child(wire)
	var floor_wire := ImmediateMesh.new()
	floor_wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-5, 6):
		floor_wire.surface_add_vertex(Vector3(i, 0, -5))
		floor_wire.surface_add_vertex(Vector3(i, 0, 5))
		floor_wire.surface_add_vertex(Vector3(-5, 0, i))
		floor_wire.surface_add_vertex(Vector3(5, 0, i))
	floor_wire.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = floor_wire
	var grid_mat := material.duplicate() as StandardMaterial3D
	grid_mat.albedo_color = Color("354c60")
	grid.material_override = grid_mat
	add_child(grid)
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := VBoxContainer.new()
	panel.position = Vector2(15, 15)
	panel.custom_minimum_size = Vector2(330, 0)
	ui.add_child(panel)
	var heading := Label.new()
	heading.text = "Spellbreak · Local motion reference"
	panel.add_child(heading)
	var search := LineEdit.new()
	search.placeholder_text = "Find a cast, jump, run or emote…"
	search.text_changed.connect(_filter)
	panel.add_child(search)
	picker.custom_minimum_size = Vector2(330, 370)
	picker.item_selected.connect(_select)
	panel.add_child(picker)
	var toggle := Button.new()
	toggle.text = "Pause / resume"
	toggle.pressed.connect(func(): paused = not paused)
	panel.add_child(toggle)
	seek.min_value = 0
	seek.max_value = 1
	seek.step = 0.001
	seek.value_changed.connect(_seek)
	panel.add_child(seek)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)
	var help := Label.new()
	help.text = "Drag right mouse to orbit · Scroll to zoom\nSource rig / motion. Retarget before using on another rig."
	panel.add_child(help)
	var initial := "BoulderAimStartR"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("capture="): capture_path = arg.trim_prefix("capture=")
		if arg.begins_with("clip="): initial = arg.trim_prefix("clip=")
		if arg.begins_with("time="): capture_time = float(arg.trim_prefix("time="))
		if arg.begins_with("yaw="): yaw = float(arg.trim_prefix("yaw="))
	_filter(initial if capture_path != "" else "")
	for i in filtered.size():
		if filtered[i].clip == initial:
			picker.select(i)
			_select(i)
			break
	if player == null and not filtered.is_empty(): _select(0)
	if capture_path != "":
		paused = true
		player.seek(capture_time, true)

func _path(value: String) -> String:
	var base := ProjectSettings.globalize_path("res://").trim_suffix("/")
	return "res://" + value.trim_prefix(base).trim_prefix("/")

func _filter(query: String) -> void:
	filtered.clear()
	picker.clear()
	for item: Dictionary in entries:
		if query.to_lower() in (item.clip as String).to_lower():
			filtered.append(item)
			picker.add_item(item.clip)

func _select(index: int) -> void:
	if rig != null: rig.free()
	var item: Dictionary = filtered[index]
	rig = (load(_path(item.rig)) as PackedScene).instantiate() as Node3D
	add_child(rig)
	skeleton = rig.get_node("Skeleton3D") as Skeleton3D
	player = AnimationPlayer.new()
	rig.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", load(_path(item.library)) as AnimationLibrary)
	player.play(item.clip)
	# Viewer clock controls playback and looping; saved source clips remain nonlooping.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	status.text = "%s\n%.2f seconds · %d bones\nThird-party reference: Spellbreak community client" % [item.clip, item.length, item.bones]

	if item.get("source_additive_type", "AAT_None") != "AAT_None":
		status.text += "\nAdditive motion: requires a base pose and blend setup."

func _seek(value: float) -> void:
	if player != null:
		player.seek(player.current_animation_length * value, true)

func _process(delta: float) -> void:
	camera.position = Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * distance + Vector3(0, 1, 0)
	camera.look_at(Vector3(0, 1, 0))
	if player == null: return
	if not paused:
		player.advance(delta)
		if not player.is_playing():
			player.play(player.assigned_animation)
			player.seek(0, true)
	seek.set_value_no_signal(player.current_animation_position / maxf(player.current_animation_length, 0.001))
	skeleton.force_update_all_bone_transforms()
	lines.clear_surfaces()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in skeleton.get_bone_count():
		if skeleton.find_bone("pelvis") >= 0 and skeleton.get_bone_name(i) not in HUMAN_BONES: continue
		var parent := skeleton.get_bone_parent(i)
		if parent < 0: continue
		var a := skeleton.get_bone_global_pose(i).origin
		var b := skeleton.get_bone_global_pose(parent).origin
		if a.distance_to(b) < 0.007 or a.distance_to(b) > 0.75: continue
		lines.surface_add_vertex(a)
		lines.surface_add_vertex(b)
	lines.surface_end()
	if capture_path != "":
		capture_frames += 1
		if capture_frames == 12:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_path)
			for bone in ["pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r"]:
				var index := skeleton.find_bone(bone)
				if index >= 0: print("REFERENCE_POSE ", bone, " ", skeleton.get_bone_global_pose(index).origin)
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.008, -1.2, 1.2)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(0.5, distance * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(20, distance * 1.1)
