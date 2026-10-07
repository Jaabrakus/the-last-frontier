class_name PhotoMode
extends CanvasLayer
## PHOTO MODE (round 4 VIRAL; Esc, Photo): the match stops, the screens go, and a free camera flies where the player was
## looking from: WASD, the mouse to look, Q / E down / up, the wheel for the field of view, Shift faster; T takes a picture
## (a PNG in user://photos/, its path printed and shown), M puts the Tidebreak wordmark in its corner or takes it off (kept:
## GameSettings section "ring", key "wordmark"), Esc goes back: the camera that was in use is current again exactly as it
## was, the screens come back and the match goes on. Every number and word in data/ring/replay.json "photo".
##   PhotoMode.install(mode) (RingReplay.install does it), find(tree), enter(), leave(), take() (a coroutine: the path),
##   is_active(), row_text() / row_line() (RingMenu's row), wordmark_on() / set_wordmark()

signal entered
signal left
signal taken(path: String)

const NODE_NAME := "PhotoMode"
const GROUP := &"ring_photo_mode"

var _cam: Camera3D = null
var _prev_cam: Camera3D = null
var _active := false
var _was_paused := false
var _mouse := Input.MOUSE_MODE_VISIBLE
var _layers: Array = []
var _yaw := 0.0
var _pitch := 0.0
var _help: Label
var _mark: Label
var _note: Label
var _note_t := 0.0
var _taking := false
var _count := 0
## Tests: the last picture's path.
var last_path := ""


static func install(m: Node) -> PhotoMode:
	if m == null:
		return null
	var have := m.get_node_or_null(NODE_NAME) as PhotoMode
	if have != null:
		return have
	var p := PhotoMode.new()
	p.name = NODE_NAME
	m.add_child(p)
	return p


static func find(tree: SceneTree) -> PhotoMode:
	return tree.get_first_node_in_group(GROUP) as PhotoMode if tree != null else null


static func cfg() -> Dictionary:
	var d: Variant = RingReplay.data().get("photo", {})
	return d if d is Dictionary else {}


static func pnum(key: String, def := 0.0) -> float:
	return float(cfg().get(key, def))


static func pword(key: String, def := "") -> String:
	return String(cfg().get(key, def))


static func row_text() -> String:
	return pword("row", "Photo")


static func row_line() -> String:
	return pword("row_line")


static func wordmark_on() -> bool:
	return bool(RingReplay.ring_setting("wordmark", true))


static func set_wordmark(v: bool) -> void:
	RingReplay.set_ring_setting("wordmark", v)


static func _key(name: String) -> Key:
	var k := String((cfg().get("keys", {}) as Dictionary).get(name, ""))
	return OS.find_keycode_from_string(k) if k != "" else KEY_NONE


func _ready() -> void:
	add_to_group(GROUP)
	layer = 97
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_help = MenuUI.label("", 16, MenuUI.INK)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_top = -46.0
	_help.offset_bottom = -18.0
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.add_theme_constant_override("outline_size", 5)
	_help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	root.add_child(_help)
	_note = MenuUI.label("", 16, MenuUI.GOLD)
	_note.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_note.offset_top = -74.0
	_note.offset_bottom = -48.0
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_constant_override("outline_size", 5)
	_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	root.add_child(_note)
	_mark = MenuUI.label(pword("wordmark", "TIDEBREAK"), int(pnum("wordmark_size", 30.0)), Color(1.0, 0.97, 0.9, 0.92))
	_mark.add_theme_font_override("font", Callouts.font())
	_mark.add_theme_constant_override("outline_size", 6)
	_mark.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.7))
	_mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_mark.offset_left = -360.0
	_mark.offset_right = -36.0
	_mark.offset_top = -78.0
	_mark.offset_bottom = -30.0
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_mark)
	visible = false


func is_active() -> bool:
	return _active


func camera() -> Camera3D:
	return _cam


## Into photo mode: the match held, the screens hidden, the free camera where the current one is. False when it cannot (a
## replay playing, already in it, no camera).
func enter() -> bool:
	if _active or RingReplay.playing_now() != null:
		return false
	var vp := get_viewport()
	_prev_cam = vp.get_camera_3d()
	if _prev_cam == null or get_tree().current_scene == null:
		return false
	_active = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_mouse = Input.mouse_mode
	_cam = Camera3D.new()
	_cam.name = "PhotoCamera"
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	_cam.fov = _prev_cam.fov
	_cam.near = _prev_cam.near
	_cam.far = _prev_cam.far
	_cam.environment = _prev_cam.environment
	_cam.attributes = _prev_cam.attributes
	_cam.cull_mask = _prev_cam.cull_mask
	get_tree().current_scene.add_child(_cam)
	_cam.global_transform = _prev_cam.global_transform
	var e := _cam.global_basis.get_euler(EULER_ORDER_YXZ)
	_pitch = e.x
	_yaw = e.y
	_cam.make_current()
	_layers.clear()
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl != self and cl.visible:
			_layers.append(cl)
			cl.visible = false
	visible = true
	_paint()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	entered.emit()
	return true


## Back to the match: the camera in use before current again (never moved), the screens back, the match going on.
func leave() -> void:
	if not _active:
		return
	_active = false
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_prev_cam = null
	if _cam != null and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	for cl in _layers:
		if is_instance_valid(cl):
			(cl as CanvasLayer).visible = true
	_layers.clear()
	visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse
	left.emit()


func _paint() -> void:
	_help.text = pword("help") % pword("on" if wordmark_on() else "off")
	_mark.visible = wordmark_on()


## The free camera's flight (wall-clock: it flies the same in a slowed match).
func _process(delta: float) -> void:
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t <= 0.0:
			_note.text = ""
	if not _active or _cam == null or _taking:
		return
	var dt := delta / maxf(Engine.time_scale, 0.01)
	var mv := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		mv.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		mv.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		mv.x += 1.0
	var up := 0.0
	if Input.is_physical_key_pressed(_key("up")):
		up += 1.0
	if Input.is_physical_key_pressed(_key("down")):
		up -= 1.0
	var sp := pnum("speed_mps", 4.0) * (pnum("fast_mult", 3.5) if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	move(mv, up, sp * dt)


## The camera moved `step` m along local `mv` (x right, z back) and world `up` (tests drive it here too).
func move(mv: Vector3, up: float, step: float) -> void:
	if _cam == null:
		return
	var d := _cam.global_basis * mv
	if mv.length_squared() > 1e-6:
		d = d.normalized()
	_cam.global_position += (d + Vector3.UP * up) * step


## Turned by mouse motion `rel` (pixels).
func look(rel: Vector2) -> void:
	if _cam == null:
		return
	var k := pnum("turn", 0.0035)
	_yaw -= rel.x * k
	_pitch = clampf(_pitch - rel.y * k, -1.5, 1.5)
	_cam.global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)


func zoom(steps: float) -> void:
	if _cam != null:
		_cam.fov = clampf(_cam.fov + steps * pnum("fov_step", 3.0), pnum("fov_min", 18.0), pnum("fov_max", 95.0))


func _input(e: InputEvent) -> void:
	if not _active:
		return
	get_viewport().set_input_as_handled()            # (nothing reaches the held match or the Esc menu)
	if e is InputEventMouseMotion:
		look((e as InputEventMouseMotion).relative)
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom(1.0)
		return
	if not (e is InputEventKey) or not (e as InputEventKey).pressed or (e as InputEventKey).echo:
		return
	var k := (e as InputEventKey).physical_keycode
	if e.is_action_pressed(&"ui_cancel") or k == KEY_ESCAPE:
		leave()
	elif k == _key("take"):
		take()
	elif k == _key("wordmark"):
		set_wordmark(not wordmark_on())
		_paint()


## A picture of the view as it is (the help line out of it, the wordmark in its corner when on), saved as a PNG under
## photo.dir; its path printed and returned ("" when nothing was saved). Headless (nothing drawn) the PNG is the
## viewport's size, blank.
func take() -> String:
	if not _active or _taking:
		return ""
	_taking = true
	_help.visible = false
	_note.visible = false
	_mark.visible = wordmark_on()
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(true)
		await RenderingServer.frame_post_draw
		img = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		var sz := Vector2i(get_viewport().get_visible_rect().size)
		img = Image.create(maxi(sz.x, 2), maxi(sz.y, 2), false, Image.FORMAT_RGB8)
	_help.visible = true
	_note.visible = true
	_paint()
	var dir := pword("dir", "user://photos")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_count += 1
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path := dir.path_join("tidebreak_%s_%d.png" % [stamp, _count])
	var err := img.save_png(path)
	_taking = false
	if err != OK:
		return ""
	last_path = ProjectSettings.globalize_path(path)
	print("PHOTO %s" % last_path)
	_note.text = pword("saved", "Saved %s") % last_path
	_note_t = 3.0
	taken.emit(last_path)
	return last_path
