class_name RtsMode
extends Node
## Command mode (user 2026-09-30: "we need to make npc logic like rts logic ... lets build a rts mode"): F1 lifts the camera over
## the land, the player's own controls rest, and the household is commanded like an RTS army.
##   camera   WASD or the arrows pan (along the view), Q and E turn it, the wheel zooms, the middle button turns it by the mouse,
##            the screen's edge pans (RtsMode.EDGE_PX)
##   select   a click picks a unit, a drag draws a box, Shift adds to the selection, a double click picks every unit in view,
##            Ctrl+1..9 keeps the selection as a group and 1..9 recalls it (twice: the camera goes to it), Esc lets go
##   orders   a right click sends the selection there (spread in a formation, Shift: after the places they have), X stops
##            them; the order is WorkerOrders.order (the plan once, walked with rays: the leader planner's orders)
## The units are the workers (Spouse, in the group Spouse.KEEP). RtsOrders turns a click into the right order for what is under
## the cursor (the ground: go; a tree: fell it; a beast: hunt it; a foe: attack it).
## One under each player (RtsMode.install); `active` is the mode.

const ACTION := &"rts"
const KEY := KEY_F1
const PITCH_DEG := 58.0
const DIST_MIN := 6.0
const DIST_MAX := 140.0
const PAN_MPS := 0.9                 ## of the zoom's distance a second
const TURN_RAD_S := 1.6
const EDGE_PX := 6
const PICK_PX := 34.0
const REACH_M := 600.0
const FORMATION_M := 1.4
const DRAG_PX := 8.0
const DOUBLE_S := 0.35

signal changed(active: bool)
signal selection_changed(units: Array)

var player: FrontierPlayer
var active := false
var cam: Camera3D
var focus := Vector3.ZERO
var yaw := 0.0
var dist := 38.0
var selected: Array[Spouse] = []
var groups := {}                     ## 1..9 -> Array of Spouse
var hud: RtsHud
var _rings: Array[MeshInstance3D] = []
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _was_cam: Camera3D
var _drag_from := Vector2.INF
var _drag_to := Vector2.INF
var _last_click_t := -9.0
var _turning := false
var _pulse: MeshInstance3D
var _pulse_t := 9.0
var _marker_mat: StandardMaterial3D


static func install(p: FrontierPlayer) -> RtsMode:
	var m := RtsMode.new()
	m.name = "RtsMode"
	m.player = p
	p.add_child(m)
	return m


static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY
	InputMap.action_add_event(ACTION, e)


func _ready() -> void:
	ensure_input()
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.name = "RtsCamera"
	cam.fov = 55.0
	cam.far = 1500.0
	cam.top_level = true
	add_child(cam)
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.albedo_color = Color(0.3, 0.9, 0.4, 0.9)
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.no_depth_test = true
	_marker_mat.render_priority = 20
	if DisplayServer.get_name() != "headless":
		hud = RtsHud.new()
		hud.name = "RtsHud"
		hud.mode = self
		add_child(hud)
		hud.visible = false


## All the commandable units, nearest the camera's focus first.
func units() -> Array[Spouse]:
	var out: Array[Spouse] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group(Spouse.KEEP):
		if n is Spouse and is_instance_valid(n):
			out.append(n as Spouse)
	return out


# --- the mode ----------------------------------------------------------------------------------------------------

func set_active(on: bool) -> void:
	if on == active or player == null:
		return
	if on and (player.is_dead or player.riding != null or player.climbing != null):
		return
	active = on
	if on:
		_was_mouse = Input.mouse_mode
		_was_cam = get_viewport().get_camera_3d()
		player.controls.from_input = false          # (the player's own keys rest: he stands where he is)
		player.controls.release_all()
		focus = player.global_position
		yaw = player.rotation.y
		dist = clampf(dist, DIST_MIN, DIST_MAX)
		cam.current = true
		_place_camera()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		player.controls.from_input = true
		cam.current = false
		if _was_cam != null and is_instance_valid(_was_cam):
			_was_cam.current = true
		elif player.camera:
			player.camera.current = true
		Input.mouse_mode = _was_mouse if _was_mouse != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
		_drag_from = Vector2.INF
		deselect()
	_draw_rings()
	if hud:
		hud.visible = on
	changed.emit(on)


func toggle() -> void:
	set_active(not active)


func _place_camera() -> void:
	var pitch := deg_to_rad(PITCH_DEG)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var ground := FrontierTerrain.height_at(focus.x, focus.z)
	focus.y = ground
	cam.global_position = focus + off
	cam.look_at(focus, Vector3.UP)


# --- selection -----------------------------------------------------------------------------------------------------

func deselect() -> void:
	selected.clear()
	_draw_rings()
	selection_changed.emit(selected)


func select(units_: Array, add := false) -> void:
	if not add:
		selected.clear()
	for u in units_:
		if u is Spouse and not selected.has(u):
			selected.append(u as Spouse)
	_draw_rings()
	selection_changed.emit(selected)


## The unit nearest the screen point `p` within PICK_PX, or null.
func unit_at(p: Vector2) -> Spouse:
	var best: Spouse = null
	var bd := PICK_PX
	for u in units():
		if cam.is_position_behind(u.global_position):
			continue
		var sp := cam.unproject_position(u.global_position + Vector3.UP * 0.9)
		var d := sp.distance_to(p)
		if d < bd:
			bd = d
			best = u
	return best


## The units whose screen place is inside `r`.
func units_in(r: Rect2) -> Array[Spouse]:
	var out: Array[Spouse] = []
	for u in units():
		if cam.is_position_behind(u.global_position):
			continue
		if r.has_point(cam.unproject_position(u.global_position + Vector3.UP * 0.9)):
			out.append(u)
	return out


func _on_screen_units() -> Array[Spouse]:
	return units_in(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))


func _draw_rings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	while _rings.size() < selected.size():
		var m := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.55
		tm.outer_radius = 0.65
		tm.rings = 24
		tm.ring_segments = 6
		m.mesh = tm
		m.material_override = _marker_mat
		m.top_level = true
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_rings.append(m)
	for i in _rings.size():
		_rings[i].visible = active and i < selected.size() and is_instance_valid(selected[i])
		if _rings[i].visible:
			_rings[i].global_position = selected[i].global_position + Vector3.UP * 0.06


# --- orders ----------------------------------------------------------------------------------------------------------

## The ground under the screen point `p` (a ray from the camera), or INF.
func ground_at(p: Vector2) -> Vector3:
	var from := cam.project_ray_origin(p)
	var to := from + cam.project_ray_normal(p) * REACH_M
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return Vector3.INF
	return hit.position


## Where unit `k` of `n` stands in a formation round `at` (a grid, facing along the way they go).
static func formation_spot(at: Vector3, k: int, n: int, facing: Vector3) -> Vector3:
	if n <= 1:
		return at
	var cols := ceili(sqrt(float(n)))
	var fwd := Vector3(facing.x, 0.0, facing.z)
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var row := k / cols
	var col := k % cols
	var rows := ceili(float(n) / cols)
	var o := side * (float(col) - (cols - 1) * 0.5) * FORMATION_M - fwd * (float(row) - (rows - 1) * 0.5) * FORMATION_M
	return at + o


## Sends the selection to `at` (spread there), after what they have with `queue`; `act` is a job the place is for ("": only go).
func order_to(at: Vector3, queue := false, act := "") -> int:
	if selected.is_empty() or not at.is_finite():
		return 0
	var mid := Vector3.ZERO
	for u in selected:
		mid += u.global_position
	mid /= float(selected.size())
	var facing := at - mid
	var n := 0
	for k in selected.size():
		var u := selected[k]
		if not is_instance_valid(u):
			continue
		var spot := formation_spot(at, k, selected.size(), facing)
		spot.y = FrontierTerrain.height_at(spot.x, spot.z)
		if not queue:
			RtsFell.cancel(u)
		WorkerOrders.order(u, spot, queue, PackedVector3Array(), act)
		n += 1
	_pulse_at(at)
	return n


func stop() -> void:
	for u in selected:
		if is_instance_valid(u):
			u.orders.clear()
			u.order_ways.clear()
			u.order_acts.clear()
			u._order_set = false
			if u.nav != null:
				u.nav.reset()
			RtsFell.cancel(u)
			u.sc.cancel("told to stop")


func _pulse_at(p: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _pulse == null:
		_pulse = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.7
		tm.outer_radius = 0.82
		tm.rings = 28
		tm.ring_segments = 6
		_pulse.mesh = tm
		_pulse.material_override = _marker_mat
		_pulse.top_level = true
		add_child(_pulse)
	_pulse.global_position = p + Vector3.UP * 0.08
	_pulse_t = 0.0


# --- groups ------------------------------------------------------------------------------------------------------------

func keep_group(n: int) -> void:
	groups[n] = selected.duplicate()


func recall_group(n: int, goto := false) -> void:
	var g: Array = []
	for u in (groups.get(n, []) as Array):
		if is_instance_valid(u):
			g.append(u)
	if g.is_empty():
		return
	select(g)
	if goto:
		var mid := Vector3.ZERO
		for u in g:
			mid += (u as Spouse).global_position
		focus = mid / float(g.size())


# --- the frame -----------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		var n := -1
		if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
			n = int(k.physical_keycode - KEY_1) + 1
		if n > 0:
			if k.ctrl_pressed:
				keep_group(n)
			else:
				var again := _last_group == n and Time.get_ticks_msec() * 0.001 - _last_group_t < DOUBLE_S * 2.0
				recall_group(n, again)
				_last_group = n
				_last_group_t = Time.get_ticks_msec() * 0.001
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_ESCAPE:
			deselect()
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_X:
			stop()
			get_viewport().set_input_as_handled()
	var mb := event as InputEventMouseButton
	if mb:
		_mouse_button(mb)
	var mm := event as InputEventMouseMotion
	if mm:
		if _turning:
			yaw -= mm.relative.x * 0.006
		if _drag_from != Vector2.INF:
			_drag_to = mm.position
			if hud:
				hud.queue_redraw()


var _last_group := -1
var _last_group_t := -9.0


func _mouse_button(mb: InputEventMouseButton) -> void:
	var now := Time.get_ticks_msec() * 0.001
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				dist = clampf(dist * 0.9, DIST_MIN, DIST_MAX)
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				dist = clampf(dist / 0.9, DIST_MIN, DIST_MAX)
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_MIDDLE:
			_turning = mb.pressed
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			if hud and hud.over_panel(mb.position):
				return
			if mb.pressed:
				_drag_from = mb.position
				_drag_to = mb.position
			elif _drag_from != Vector2.INF:
				var moved := _drag_from.distance_to(mb.position)
				if moved > DRAG_PX:
					select(units_in(Rect2(_drag_from, mb.position - _drag_from).abs()), mb.shift_pressed)
				else:
					var u := unit_at(mb.position)
					if u != null and now - _last_click_t < DOUBLE_S:
						select(_on_screen_units(), mb.shift_pressed)
					elif u != null:
						if mb.shift_pressed and selected.has(u):
							selected.erase(u)
							_draw_rings()
							selection_changed.emit(selected)
						else:
							select([u], mb.shift_pressed)
					elif not mb.shift_pressed:
						deselect()
					_last_click_t = now
				_drag_from = Vector2.INF
				_drag_to = Vector2.INF
				if hud:
					hud.queue_redraw()
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			if mb.pressed and not selected.is_empty():
				RtsOrders.command(self, mb.position, mb.shift_pressed)
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if player == null:
		return
	if not active:
		return
	var pan := Vector2.ZERO
	pan.y -= float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	pan.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	pan.x -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	pan.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	if DisplayServer.get_name() != "headless":
		var m := get_viewport().get_mouse_position()
		var s := get_viewport().get_visible_rect().size
		if m.x <= EDGE_PX:
			pan.x -= 1.0
		elif m.x >= s.x - EDGE_PX:
			pan.x += 1.0
		if m.y <= EDGE_PX:
			pan.y -= 1.0
		elif m.y >= s.y - EDGE_PX:
			pan.y += 1.0
	if pan != Vector2.ZERO:
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		focus += (right * pan.x + fwd * -pan.y).normalized() * PAN_MPS * dist * delta * (2.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	if Input.is_physical_key_pressed(KEY_Q):
		yaw -= TURN_RAD_S * delta
	if Input.is_physical_key_pressed(KEY_E):
		yaw += TURN_RAD_S * delta
	_place_camera()
	_draw_rings()
	if _pulse != null:
		_pulse_t += delta
		_pulse.visible = _pulse_t < 0.8
		_pulse.scale = Vector3.ONE * (0.6 + _pulse_t * 1.4)
		_marker_mat.albedo_color.a = clampf(1.0 - _pulse_t / 0.8, 0.0, 1.0) * 0.9 + 0.0
	selected = selected.filter(func(u: Spouse) -> bool: return is_instance_valid(u))
