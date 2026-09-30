extends Node3D
## A comparison room inside the isolated Frontier worktree.
const Names := preload("res://tools/agls_comparison/legacy_names.gd")
const CLIPS := [
	["Walk forward", "ALS_N_Walk_F", "actor_b-p-walk-fw"],
	["Run forward", "ALS_N_Run_F", "actor_b-p-run-fw"],
	["Sprint forward", "ALS_N_Sprint_F", "actor_b-p-sprint-fw"],
	["Jump", "ALSv2_JumpSeq_Idle", "actor_b-p-jump-long"],
	["Vault — left hand", "ALSv2_N_Vault_1m_LH", "actor_b-p-vault-1m"],
	["Vault — right hand", "ALSv2_N_Vault_1m_RH", "actor_b-p-vault-1m"],
	["Walk backward", "ALS_N_Walk_B", "actor_b-p-walk-bw"],
	["Walk left", "ALS_N_Walk_LF", "actor_b-p-walk-fw-lt"],
	["Walk right", "ALS_N_Walk_RF", "actor_b-p-walk-fw-rt"],
	["Run backward", "ALS_N_Run_B", "actor_b-p-run-bw"],
	["Run left", "ALS_N_Run_LF", "actor_b-p-run-fw-lt"],
	["Run right", "ALS_N_Run_RF", "actor_b-p-run-fw-rt"],
	["Crouch walk forward", "ALS_CLF_Walk_F", "actor_b-p-crouch-walk-fw"] ,
	["Crouch walk backward", "ALS_CLF_Walk_B", "actor_b-p-crouch-walk-bw"] ,
	["Crouch walk left", "ALS_CLF_Walk_L", "actor_b-p-crouch-walk-fw-lt"] ,
	["Crouch walk right", "ALS_CLF_Walk_R", "actor_b-p-crouch-walk-fw-rt"] ,
	["Bow aim sweep", "ALS_Props_Bow_Aim_Sweep", "actor_b-p-bow-aim-idle"] ,
	["Bow aim \u2014 crouched", "ALS_Props_Bow_Aim_Sweep_Crouched", "actor_b-p-bow-aim-crouch-idle"] ,
	["Bow draw", "ALS_Props_RecurveBow_Draw_Stand", "actor_b-p-bow-aim-idle"] ,
	["Bow draw \u2014 crouched", "ALS_Props_RecurveBow_Draw_Crouch", "actor_b-p-bow-aim-crouch-idle"] ,
	["Bow release", "ALS_Props_RecurveBow_Recoil", "actor_b-p-bow-aim-idle"] ,
	["Bow sheath", "ALS_Props_Bow_Sheath_Stand", "actor_b-p-relax-idle"] ,
	["Bow sheath \u2014 crouched", "ALS_Props_Bow_Sheath_Crouch", "actor_b-p-crouch-idle"] ,
	["Rifle aim sweep", "ALS_Props_Rifle_Aim_Sweep", "actor_b-p-rifle-idle-aim"] ,
	["Rifle aim \u2014 crouched", "ALS_Props_Rifle_Aim_Sweep_Crouched", "actor_b-p-rifle-aim-crouch-idle"] ,
	["Climb: mantle to idle", "ALSv2_Mantle_2m_Walking_01", "actor_b-p-ledge-chest-climb-up^idle"] ,
	["Climb: mantle to run", "ALSv2_Mantle_2m_Walking_02", "actor_b-p-ledge-chest-climb-up^run"] ,
	["Climb: ladder up", "LMv2_Movement_Up_01", "actor_b-p-ladder-climb-up"] ,
	["Climb: ladder down", "LMv2_Movement_Down_01", "actor_b-p-ladder-climb-down"] ,
	["Climb: ladder exit top", "LMv2_Exit_Ladder_Up_01", "actor_b-p-ladder-dismount--top-start"] ,
	["Climb: ladder mount top", "LMv2_Enter_Ladder_Down_01", "actor_b-p-ladder-mount-top"] ,
	["Climb: ledge hang idle", "CMC_Climb_Hanging_Idle_Loop", "actor_b-p-ledge-idle"] ,
	["Climb: ledge pull upward", "CMC_Shimmy_Long_LH_U", "actor_b-p-ledge-hang-climb-up^ledge-knee"] ,
]
const LANES := [-3.15, -1.05, 1.05, 3.15]
var rigs: Array[Node3D] = []
var lock_travel: CheckBox
var players: Array[AnimationPlayer] = []
var selection := 0
var time := 0.0
var paused := false
var speed := 1.0
var yaw := 0.2
var pitch := -0.08
var distance := 6.9
var camera: Camera3D
var details: Label
var dropdown: OptionButton
var pause_button: Button
var speed_label: Label
var align: CheckBox
var style_selector: OptionButton
var props: Array = []
var show_props: CheckBox
var variant_label: Label3D

func _ready() -> void:
	_setup_room()
	for i in 4:
		var rig: Node3D = load("res://characters/Actor_B.tscn").instantiate()
		rig.position.x = LANES[i]
		add_child(rig)
		rigs.append(rig)
		var ap: AnimationPlayer = rig.get_node("AnimationPlayer")
		ap.add_animation_library(&"reference", load("res://animations_extra/Frontier_Comparison_Reference.res"))
		if i == 1:
			ap.add_animation_library(&"updated", load("res://animations_extra/Frontier_Updated_Comparison.res"))
		if i == 2:
			ap.add_animation_library(&"blend", load("res://animations_extra/Frontier_Legacy/Frontier_Legacy.res"))
			ap.add_animation_library(&"grounded", load("res://animations_extra/Frontier_Legacy/Grounded/Frontier_Legacy_Grounded.res"))
			ap.add_animation_library(&"athletic", load("res://animations_extra/Frontier_Legacy/Athletic/Frontier_Legacy_Athletic.res"))
			ap.add_animation_library(&"upper", load("res://animations_extra/AGLS_Upper_Variants.res"))
		if i == 3:
			ap.add_animation_library(&"agls", load("res://animations_extra/AGLS_Preview.res"))
		players.append(ap)
		assert(CharacterBodyMesh.attach(rig.get_node("Skeleton3D"), ap) != null)
		var models := {}
		for weapon in ["bow", "musket"]:
			var socket := BoneAttachment3D.new()
			socket.bone_name = "l_hand_prop_attachment" if weapon == "bow" else "r_hand_prop_attachment"
			rig.get_node("Skeleton3D").add_child(socket)
			var model := WeaponModels.build(weapon)
			model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
			socket.add_child(model)
			model.visible = false
			models[weapon] = model
		props.append(models)
	_setup_ui()
	_select(12)
	_update_camera()
	if "--agls-capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()
	print("FRONTIER_FOUR_WAY_READY columns=old,updated,blend,agls clips=", CLIPS.size())

func _setup_room() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202b38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c6dded")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(18, 0.12, 18)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("637b86")
	mat.roughness = 0.9
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	for row in [[LANES[0], "FRONTIER OLD"], [LANES[1], "FRONTIER UPDATED"], [LANES[2], "FRONTIER BLEND"], [LANES[3], "AGLS RETARGETED"]]:
		var label := Label3D.new()
		label.text = row[1]
		label.font_size = 32
		label.pixel_size = 0.0038
		label.position = Vector3(float(row[0]), -0.16, 0)
		label.no_depth_test = true
		if float(row[0]) == LANES[2]:
			variant_label = label
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	camera = Camera3D.new()
	camera.fov = 43.0
	camera.current = true
	add_child(camera)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	canvas.add_child(panel)
	panel.add_theme_font_size_override("font_size", 14)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Frontier — old / updated / blended / AGLS"
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	var controls := HBoxContainer.new()
	vbox.add_child(controls)
	dropdown = OptionButton.new()
	for row in CLIPS:
		dropdown.add_item(row[0])
	dropdown.item_selected.connect(_select)
	controls.add_child(dropdown)
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_toggle_pause)
	controls.add_child(pause_button)
	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func(): time = 0.0)
	controls.add_child(restart)
	for delta in [-0.25, 0.25]:
		var button := Button.new()
		button.text = "Slower" if delta < 0 else "Faster"
		button.pressed.connect(func(): speed = clampf(speed + delta, 0.25, 2.0))
		controls.add_child(button)
	speed_label = Label.new()
	controls.add_child(speed_label)
	align = CheckBox.new()
	align.text = "Align phases"
	controls.add_child(align)
	style_selector = OptionButton.new()
	style_selector.add_item("Frontier Legacy — approved blend")
	style_selector.add_item("Frontier Legacy — Grounded")
	style_selector.add_item("Frontier Legacy — Athletic")
	style_selector.add_item("Previous: AGLS base + Frontier upper body")
	style_selector.select(0)
	style_selector.item_selected.connect(func(_index: int): _select(selection))
	vbox.add_child(style_selector)
	show_props = CheckBox.new()
	show_props.text = "Show weapon models"
	show_props.button_pressed = true
	show_props.toggled.connect(func(_on: bool): _update_props())
	vbox.add_child(show_props)
	lock_travel = CheckBox.new()
	lock_travel.text = "Keep horizontal travel in each lane"
	lock_travel.button_pressed = true
	controls.add_child(lock_travel)
	var side_view := Button.new()
	side_view.text = "Side view"
	side_view.pressed.connect(func(): yaw = 1.0; _update_camera())
	controls.add_child(side_view)
	details = Label.new()
	details.visible = false
	vbox.add_child(details)
	var help := Label.new()
	help.text = "1 walk · 2 run · 3 sprint · 4 jump · 5/6 vault · Space pause · R restart\nRight-drag orbit · Wheel zoom · G play Frontier base blend"
	help.visible = false
	vbox.add_child(help)
	var show_details := CheckBox.new()
	show_details.text = "Details"
	show_details.toggled.connect(func(on: bool): details.visible = on; help.visible = on)
	controls.add_child(show_details)
	var game := Button.new()
	game.text = "Play installed Frontier Legacy with weapons (approved locomotion blend)"
	game.pressed.connect(_play_game)
	vbox.add_child(game)

func _select(index: int) -> void:
	selection = index
	time = 0.0
	dropdown.select(index)
	for i in 4:
		var prefix: String = ["reference/", "updated/", ["blend/", "grounded/", "athletic/", "upper/"][style_selector.selected], "agls/"][i]
		var clip_name: String = Names.CLIPS[String(CLIPS[index][1])] if i == 2 and style_selector.selected < 3 else String(CLIPS[index][1])
		var name := String(prefix) + clip_name
		assert(players[i].has_animation(name), "Preview clip missing: " + name)
		players[i].play(name)
		players[i].pause()
	variant_label.text = ["FRONTIER BLEND", "BLEND — GROUNDED", "BLEND — ATHLETIC", "AGLS + FRONTIER UPPER"][style_selector.selected]
	details.text = "%s\nOld %.3fs · Updated %.3fs · Blend %.3fs · AGLS %.3fs" % [CLIPS[index][1], players[0].get_animation(players[0].assigned_animation).length, players[1].get_animation(players[1].assigned_animation).length, players[2].get_animation(players[2].assigned_animation).length, players[3].get_animation(players[3].assigned_animation).length]
	if index in [4, 5] or index >= 25:
		details.text += "\nTraversal clips are preview only; obstacle contacts need tuning."
	if index >= 16 and index < 25:
		details.text += "\nWeapon clip comparison; live grip / aim IK remains in gameplay."
	_update_props()
	_update_camera()

func _update_props() -> void:
	for models: Dictionary in props:
		models.bow.visible = show_props.button_pressed and selection >= 16 and selection <= 22
		models.musket.visible = show_props.button_pressed and selection in [23,24]

func _process(delta: float) -> void:
	if players.size() != 4:
		return
	if not paused:
		time += delta * speed
	speed_label.text = "%.2fx" % speed
	var cycle := 0.0
	for ap in players:
		cycle = maxf(cycle, ap.get_animation(ap.assigned_animation).length)
	for i in 4:
		var length := players[i].get_animation(players[i].assigned_animation).length
		var animation := players[i].get_animation(players[i].assigned_animation)
		var t := fmod(time, length) if animation.loop_mode != Animation.LOOP_NONE else minf(fmod(time, cycle + 0.55), length)
		if align.button_pressed:
			t = fmod(time, players[2].get_animation(players[2].assigned_animation).length) / players[2].get_animation(players[2].assigned_animation).length * length
		players[i].seek(t, true)
		var sk: Skeleton3D = rigs[i].get_node("Skeleton3D")
		var root_index := sk.find_bone("root")
		var p := sk.get_bone_pose_position(root_index)
		rigs[i].position = Vector3(LANES[i]-p.x if lock_travel.button_pressed else LANES[i], 0, -p.z if lock_travel.button_pressed else 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
			_select(event.physical_keycode - KEY_1)
		match event.physical_keycode:
			KEY_SPACE: _toggle_pause()
			KEY_R: time = 0.0
			KEY_G: _play_game()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x*0.005
		pitch = clampf(pitch-event.relative.y*0.005, -0.55, 0.8)
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.3, distance-0.3)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(12.0, distance+0.3)
		_update_camera()

func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "Resume" if paused else "Pause"

func _update_camera() -> void:
	var center := Vector3(0, 1.0 if selection < 25 else 1.8, 0)
	camera.position = center + Vector3(sin(yaw)*cos(pitch), sin(pitch)+0.14, cos(yaw)*cos(pitch))*distance
	camera.look_at(center, Vector3.UP)

func _play_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _capture() -> void:
	await get_tree().create_timer(1.0).timeout
	paused = true
	for row in [[12, 0.3, "crouch"], [1, 0.35, "run"], [16, 0.5, "bow-aim"], [18, 0.5, "bow-draw"], [23, 0.5, "rifle-aim"], [27, 0.25, "ladder"], [25, 0.5, "mantle"], [4, 0.65, "vault"]]:
		_select(row[0])
		time = float(row[1])
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.comparison-private/reports/four-way-" + row[2] + ".png")
	_select(12)
	if "--capture-all-styles" in OS.get_cmdline_user_args():
		for style in [1,2]:
			style_selector.select(style)
			for row in [[12,0.3,"crouch"],[1,0.35,"run"],[4,0.65,"vault"]]:
				_select(row[0]); time = float(row[1])
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://.comparison-private/reports/four-way-" + ["approved","grounded","athletic"][style] + "-" + row[2] + ".png")
	style_selector.select(0)
	_select(12)
	paused = false
	print("FRONTIER_FOUR_WAY_CAPTURE_READY")
