extends Node3D
## Tandem test: hold SPACE for Happy Baby, then a second player presses ENTER to
## join the plank flow above it. Further ENTER presses dip; BACKSPACE leaves.
## Run with `-- --auto` to play a scripted session and quit.

const GLB := preload("res://features/tandem/actor_b_yoga.glb")
const HB_OFFSET := 3.0            # hb_hold.tres breath_offset: inhale starts at clip 3 s

@export_group("Partner placement")
## Relative to Happy Baby: X = across the body, Y = height, Z = along the body.
## Keep Y at 0 to keep the plank's hands and feet on the mat.
@export var partner_offset := Vector3.ZERO:
	set(value):
		partner_offset = value
		if is_instance_valid(tandem):
			tandem.plank_offset = value
## 180 aligns the heads of these two authored clips in the same direction.
@export_range(-180.0, 180.0, 1.0) var partner_rotation_degrees := 180.0:
	set(value):
		partner_rotation_degrees = value
		if is_instance_valid(tandem):
			tandem.plank_yaw = deg_to_rad(value)

var hb: Node
var plank: Node
var tandem: TandemYogaStack
var plank_stamina := 10.0
const PLANK_MAX := 10.0
const PLANK_DRAIN := 1.0
const PLANK_PER_DIP := 1.6
var clock := 0.0
var auto := false
var status: Label
var bar: ProgressBar
var pstatus: Label
var pbar: ProgressBar
var flash: Label
var legend: Label
var flash_left := 0.0


func _ready() -> void:
	auto = "--auto" in OS.get_cmdline_user_args()
	if not InputMap.has_action("tandem_yoga_hold"):
		InputMap.add_action("tandem_yoga_hold")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		InputMap.action_add_event("tandem_yoga_hold", ev)
	if not InputMap.has_action("tandem_plank_dip"):
		InputMap.add_action("tandem_plank_dip")
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = KEY_ENTER
		InputMap.action_add_event("tandem_plank_dip", ev2)
	if not InputMap.has_action("tandem_plank_leave"):
		InputMap.add_action("tandem_plank_leave")
		var ev3 := InputEventKey.new()
		ev3.physical_keycode = KEY_BACKSPACE
		InputMap.action_add_event("tandem_plank_leave", ev3)
	_stage()
	var front := _mat(Vector3.ZERO, Color(0.9, 0.55, 0.35))
	var upper := _mannequin(Vector3.ZERO, Color(0.35, 0.6, 0.85), GLB)
	plank = load("res://features/tandem/plank_dip_controller.gd").new()
	plank.animation_player = upper.animation_player
	plank.auto_start = false
	plank.read_input = false # the first ENTER joins; subsequent presses dip
	plank.base_clip = &"flow"
	upper.add_child(plank)
	plank.dipped.connect(func(): plank_stamina = minf(plank_stamina + PLANK_PER_DIP, PLANK_MAX))
	hb = load("res://features/tandem/yoga_hold_controller.gd").new()
	hb.animation_player = front.animation_player
	front.add_child(hb)
	hb.flinched.connect(func(): _flash("FLINCH"))
	hb.collapsed.connect(func(): _flash("COLLAPSED  -  rest to recover"))
	tandem = TandemYogaStack.new()
	tandem.base_actor = front
	tandem.base_hold = hb
	tandem.partner_actor = upper
	tandem.partner_plank = plank
	tandem.plank_offset = partner_offset
	tandem.plank_yaw = deg_to_rad(partner_rotation_degrees)
	add_child(tandem)
	tandem.partner_joined.connect(func():
		plank_stamina = PLANK_MAX
		_flash("PARTNER JOINED"))
	tandem.partner_left.connect(func(): _flash("PARTNER LEFT"))
	if auto:
		hb.set_held(false)
	_ui()


func _process(delta: float) -> void:
	clock += delta
	if tandem.occupied:
		plank_stamina = maxf(plank_stamina - PLANK_DRAIN * delta, 0.0)
	if hb.state == hb.State.HOLD:
		hb.seek_hold(clock + HB_OFFSET)
	if auto:
		hb.set_held(clock > 1.0 and clock < 16.5)
		if tandem.can_join():
			tandem.try_join()
		elif tandem.occupied and fmod(clock, 2.2) < delta:
			tandem.request_dip()
		if clock > 21.0:
			get_tree().quit()
	var names: Array = hb.State.keys()
	status.text = "Happy baby: %s    stamina %d%%" % [names[hb.state], roundi(hb.stamina_fraction() * 100)]
	bar.value = hb.stamina_fraction() * 100
	if not auto:
		if Input.is_action_just_pressed("tandem_plank_leave"):
			tandem.leave()
		elif Input.is_action_just_pressed("tandem_plank_dip"):
			if tandem.occupied:
				tandem.request_dip()
			elif not tandem.try_join():
				_flash("WAIT FOR HAPPY BABY")
	if tandem.occupied:
		pstatus.text = "Partner: %s    stamina %d%%" % ["DIP" if plank.is_dipping() else "FLOW", roundi(plank_stamina / PLANK_MAX * 100)]
	elif tandem.can_join():
		pstatus.text = "Partner: ENTER to join above"
	else:
		pstatus.text = "Partner: waiting for Happy Baby"
	pbar.value = plank_stamina / PLANK_MAX * 100 if tandem.occupied else 0.0
	flash_left -= delta
	flash.modulate.a = clampf(flash_left, 0.0, 1.0)


func _mat(at: Vector3, color: Color, glb: PackedScene = GLB, size := Vector2(2.0, 0.75)) -> TandemPoseMannequin:
	var mat := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mat.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.35)
	mat.material_override = m
	mat.position = at + Vector3(0, 0.002, 0)
	add_child(mat)
	return _mannequin(at, color, glb)


func _mannequin(at: Vector3, color: Color, glb: PackedScene) -> TandemPoseMannequin:
	var man := TandemPoseMannequin.new()
	man.scene = glb
	man.color = color
	man.rotation.y = PI / 2                                    # lie along the mat (x)
	man.position = at
	add_child(man)
	return man


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.17, 0.18, 0.21)
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(8, 8)
	floor.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.32, 0.3, 0.28)
	floor.material_override = fmat
	add_child(floor)
	var cam := Camera3D.new()
	cam.position = Vector3(1.0, 1.65, 2.9)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 0.35, 0))


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var rows := []
	for i in 2:
		var l := Label.new()
		l.position = Vector2(24, 12 + i * 34)
		l.add_theme_font_size_override("font_size", 22)
		layer.add_child(l)
		var pb := ProgressBar.new()
		pb.position = Vector2(470, 18 + i * 34)
		pb.size = Vector2(300, 18)
		pb.show_percentage = false
		layer.add_child(pb)
		rows.append([l, pb])
	status = rows[0][0]
	bar = rows[0][1]
	pstatus = rows[1][0]
	pbar = rows[1][1]
	legend = Label.new()
	legend.text = "SPACE: Happy Baby    ENTER: partner join / dip    BACKSPACE: leave"
	legend.position = Vector2(24, 686)
	legend.add_theme_font_size_override("font_size", 18)
	layer.add_child(legend)
	var switch_button := Button.new()
	switch_button.text = _other_tandem_label()
	switch_button.position = Vector2(24, 90)
	switch_button.pressed.connect(func(): get_tree().change_scene_to_file(_other_tandem_scene()))
	layer.add_child(switch_button)
	flash = Label.new()
	flash.position = Vector2(820, 20)
	flash.add_theme_font_size_override("font_size", 24)
	flash.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	flash.modulate.a = 0
	layer.add_child(flash)


func _flash(text: String) -> void:
	flash.text = text
	flash_left = 1.6


func _other_tandem_label() -> String:
	return "Switch to Crawl + Kneel"


func _other_tandem_scene() -> String:
	return "res://features/tandem/crawl_demo.tscn"
