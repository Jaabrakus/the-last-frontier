class_name InspectView
extends CanvasLayer
## A look inside one body (the user, 2026-10-03, showing another game's body viewer: "yes" to an inspect view like it; then "i
## want that to be how our game detects hits ... they have a perfect skeleton mesh"): the window onto the fitted body every shot
## is worked out in (Anatomy, BodyModel). Full screen on near-black, VIEWING FRONT / BACK / LEFT / RIGHT at the top:
##   the body    as it lies, a faint outline of its skin (its skin meshes as they are drawn now) over the skeleton (the bones
##               off-white), the organs in soft colours, the arteries red and the veins blue, the cord yellow
##   the shots   every shot's path: a red dot where it went in, a blue dot where it came out, a purple dot where it stopped
##               inside; the latest path green, the earlier white; what a shot reached drawn bright, a cut vessel pulsing (it
##               bleeds), a struck bone tinted from yellow to crimson by its damage, an orange dot where the cord was hurt; each
##               shot's labels (Anatomy's: "Heart, punctured", "Left rib 5, fractured") in the list at the top left
##   legend      bottom right, what each mark means; the controls along the bottom
##   controls    left drag turns round the body, the wheel closer, right drag or W A S D moves the view, R resets it (a person's
##               front, an animal's left side), M or Esc closes and gives the mouse back to the game
## How it opens: hold E on a dead body, "Inspect the body (M)" (NpcFighter, WildAnimal: the tap's when it has nothing else), or M
## while one is highlighted (the Hotkey, made once the first body falls); open_on(node) from code. debug_living (or
## inspect_living=on on the command line): offered on the living too (tests, dev).
## What it costs: nothing while closed. Open, the game is paused under it (the survival clock with it), the world's own 3D drawing
## is off (the view covers it), and the view draws its own small world in a SubViewport: the skin, the shapes, the paths.
## Not in a shared world (a co-op session: pausing one machine's game would put it out of step with the others).

signal closed

const ROW := "Inspect the body (M)"
const BG := Color(0.028, 0.03, 0.038)
const RED := Color(0.96, 0.12, 0.1)
const BLUE := Color(0.25, 0.52, 1.0)
const PURPLE := Color(0.74, 0.32, 0.98)
const ORANGE := Color(1.0, 0.56, 0.08)
const GREEN := Color(0.32, 1.0, 0.42)
const WHITE := Color(0.94, 0.94, 0.92)
const SKIN := Color(0.72, 0.84, 1.0, 1.0)
## A struck bone's tint, little damage to much.
const BONE_HIT := [Color(1.0, 0.88, 0.22), Color(0.8, 0.04, 0.14)]
const INK := Color(0.93, 0.9, 0.82)
const DIM := Color(0.66, 0.64, 0.6)
const CONTROLS := "LEFT DRAG turn  ·  WHEEL closer  ·  RIGHT DRAG / W A S D move  ·  R reset  ·  M / ESC close"

static var current: InspectView = null
static var debug_living := false
static var _hotkey: Node = null
static var _args_read := false
static var _pulse_shader: Shader
static var _rim_shader: Shader

var subject: Node
var sk: Skeleton3D
var anatomy: Anatomy
var model: BodyModel
var vp: SubViewport
var cam: Camera3D
var yaw := 0.0
var pitch := 0.06
var dist := 3.0
## The view moved off the body's middle (world metres).
var pan := Vector3.ZERO
## The body's axes now (world): x its left, y its up (to the head; an animal's back), z its front.
var frame := Basis()
var centre := Vector3.ZERO
var size_m := 1.8
var was_mouse := Input.MOUSE_MODE_CAPTURED
var was_paused := false
## What was drawn (the tests read it): shapes, bright, pulsing, tinted, outline, dot_in, dot_out, dot_stop, dot_cord, green, white.
var counts := {}
## The skin's outline (_outline): the bare skeleton its skin meshes hang on; null until it is made, two frames after opening.
var outline: Skeleton3D
var _was_3d := false
var _drag := 0
var _root3: Node3D
var _viewing: Label
var _closed := false
var _default_yaw := 0.0
var _mats := {}
var _ov := {}
var _memo := {}
var _outline_wait := 0


static func _read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for a in OS.get_cmdline_user_args():
		if a == "inspect_living=on":
			debug_living = true


## The skeleton a body's view looks into (its inspect_skeleton(); a Skeleton3D itself), null none.
static func skeleton_of(n: Node) -> Skeleton3D:
	if n == null or not is_instance_valid(n):
		return null
	if n.has_method("inspect_skeleton"):
		return n.call("inspect_skeleton") as Skeleton3D
	return n as Skeleton3D


## Whether `n` can be looked into now: a body on a rig the fitted body knows, dead (or debug_living), no view open, not in a
## shared world (NetSession: its time is everyone's, the view would pause this machine's game under it).
static func can_inspect(n: Node) -> bool:
	_read_args()
	if current != null and is_instance_valid(current):
		return false
	var s := skeleton_of(n)
	if s == null or not s.is_inside_tree() or _shared(s.get_tree()):
		return false
	var dead := n.has_method("is_dead") and bool(n.call("is_dead"))
	if not dead and not debug_living:
		return false
	return s.find_bone("spined") >= 0 or s.find_bone("Torso3") >= 0


## The view opened on `n` (a body with inspect_skeleton(), or a skeleton); null when it cannot be.
static func open_on(n: Node) -> InspectView:
	_read_args()
	var s := skeleton_of(n)
	if s == null or not s.is_inside_tree() or _shared(s.get_tree()):
		return null
	if current != null and is_instance_valid(current):
		current.close()
	var an := Anatomy.attach_to(s)
	if an == null:
		return null
	var v := InspectView.new()
	v.name = "InspectView"
	v.subject = n
	v.sk = s
	v.anatomy = an
	v.model = an.model
	current = v
	s.get_tree().root.add_child(v)
	return v


static func _shared(tree: SceneTree) -> bool:
	var ns := NetSession.find(tree) if tree != null else null
	return ns != null and ns.in_session()


## M on the highlighted dead body opens the view: the listener is made once (the first body to fall makes it).
static func ensure_hotkey(tree: SceneTree) -> void:
	_read_args()
	if tree == null or (_hotkey != null and is_instance_valid(_hotkey)):
		return
	_hotkey = Hotkey.new()
	_hotkey.name = "InspectHotkey"
	tree.root.add_child.call_deferred(_hotkey)


## M while the interactor has a body that can be looked into highlighted (paused with the game: the view's own M closes it).
class Hotkey extends Node:
	func _unhandled_input(e: InputEvent) -> void:
		if not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
			return
		var hit := e.is_action_pressed(&"inspect") if InputMap.has_action(&"inspect") else (e as InputEventKey).physical_keycode == KEY_M
		if not hit or (InspectView.current != null and is_instance_valid(InspectView.current)):
			return
		var p := get_tree().get_first_node_in_group(&"player")
		var it: Node = p.get("interactor") if p != null else null
		var t: Variant = it.get("target") if it != null else null
		if t is Node and is_instance_valid(t) and InspectView.can_inspect(t):
			get_viewport().set_input_as_handled()
			InspectView.open_on(t)


# ---------------------------------------------------------------------------------------------------------------------


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	was_paused = tree.paused
	tree.paused = true
	was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_3d = tree.root.disable_3d
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.4)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.02
	cam.far = 80.0
	vp.add_child(cam)
	cam.current = true
	_root3 = Node3D.new()
	_root3.name = "Body"
	vp.add_child(_root3)
	# (the world's own drawing off while the view covers it)
	tree.root.disable_3d = true
	_build()
	_ui()
	reset_view()


## The view back to its start: a person's front, an animal's left side, the whole body in it.
func reset_view() -> void:
	yaw = _default_yaw
	pitch = 0.06
	pan = Vector3.ZERO
	dist = size_m * (1.4 if model.human else 1.1) + 0.3
	_place()


## Turn round the body by `dyaw`, `dpitch` (rad).
func turn(dyaw: float, dpitch: float) -> void:
	yaw = wrapf(yaw + dyaw, -PI, PI)
	pitch = clampf(pitch + dpitch, -1.45, 1.45)
	_place()


## Closer (k < 1) or farther.
func zoom(k: float) -> void:
	dist = clampf(dist * k, 0.25, maxf(size_m * 4.0, 3.0))
	_place()


## The view moved across the screen by `v` (metres: x right, y up).
func move(v: Vector2) -> void:
	pan += cam.global_basis.x * v.x + cam.global_basis.y * v.y
	if pan.length() > size_m:
		pan = pan.normalized() * size_m
	_place()


## Which side of the body the view looks at: "FRONT", "LEFT", "BACK", "RIGHT".
func side() -> String:
	var a := rad_to_deg(wrapf(yaw, -PI, PI))
	if absf(a) <= 45.0:
		return "FRONT"
	if absf(a) >= 135.0:
		return "BACK"
	return "LEFT" if a > 0.0 else "RIGHT"


func _place() -> void:
	if cam == null:
		return
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var target := centre + pan
	var pos := target + frame * off
	var upv := frame.y
	if absf((target - pos).normalized().dot(upv)) > 0.98:
		upv = frame.z
	cam.global_transform = Transform3D(Basis.looking_at(target - pos, upv), pos)
	if _viewing != null:
		_viewing.text = "VIEWING " + side()


## Shut: the game goes on, the mouse back as the game had it.
func close() -> void:
	if _closed:
		return
	_closed = true
	var tree := get_tree()
	if tree != null:
		tree.root.disable_3d = _was_3d
		tree.paused = was_paused
	Input.mouse_mode = was_mouse
	if current == self:
		current = null
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if not _closed:
		close()


func _input(e: InputEvent) -> void:
	if _closed:
		return
	if e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo:
			var shut := k.physical_keycode == KEY_ESCAPE or k.keycode == KEY_ESCAPE or \
					(e.is_action_pressed(&"inspect") if InputMap.has_action(&"inspect") else k.physical_keycode == KEY_M)
			if shut:
				close()
			elif k.physical_keycode == KEY_R:
				reset_view()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_drag = 1 if mb.pressed else (0 if _drag == 1 else _drag)
			MOUSE_BUTTON_RIGHT:
				_drag = 2 if mb.pressed else (0 if _drag == 2 else _drag)
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom(1.0 / 0.9)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _drag == 1:
			turn(-mm.relative.x * 0.008, mm.relative.y * 0.006)
		elif _drag == 2:
			move(Vector2(-mm.relative.x, mm.relative.y) * dist * 0.0012)
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if _closed:
		return
	if _outline_wait > 0:
		_outline_wait -= 1
		if _outline_wait == 0:
			_outline()
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if v != Vector2.ZERO:
		move(v * dt * maxf(dist, 0.5) * 0.6)


# ---------------------------------------------------------------------------------------------------------------------
# What is drawn


## The body's frame and middle now, its outline, its shapes (bright where reached, tinted, pulsing), each shot's path and dots.
func _build() -> void:
	_drive_helpers()
	# (the pose as the body shows it: a ragdoll's bodies or its frozen pose over the skeleton's own)
	_ov = BodyModel.overrides(sk)
	_memo = {}
	var cb := model.chest_bone
	var rot := (BodyModel.pose(sk, cb, _ov, _memo).basis.orthonormalized() * sk.get_bone_global_rest(cb).basis.orthonormalized().inverse())
	var skb := sk.global_transform.basis.orthonormalized()
	var up_w := (skb * (rot * model.up)).normalized()
	var fwd_w := (skb * (rot * model.fwd)).normalized()
	var left_w := up_w.cross(fwd_w).normalized()
	fwd_w = left_w.cross(up_w).normalized()
	frame = Basis(left_w, up_w, fwd_w)
	_default_yaw = 0.0 if model.human else PI * 0.5
	var state := _states()
	var n := 0
	var c := Vector3.ZERO
	var pts: Array[Vector3] = []
	counts = {"shapes": 0, "bright": 0, "pulsing": 0, "tinted": 0, "outline": 0, "dot_in": 0, "dot_out": 0, "dot_stop": 0, "dot_cord": 0,
			"green": 0, "white": 0}
	for i in model.shapes.size():
		var s := model.shapes[i]
		if String(s.kind) == "flesh":
			continue
		var w := model.shape_world(sk, i, _ov, _memo)
		var mi := MeshInstance3D.new()
		mi.mesh = BodyMeshes.mesh_of(s)
		mi.material_override = _material_for(s, i, state)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root3.add_child(mi)
		mi.transform = w
		counts.shapes = int(counts.shapes) + 1
		c += w.origin
		pts.append(w.origin)
		n += 1
	centre = c / float(maxi(n, 1))
	var far := 0.0
	for p in pts:
		far = maxf(far, p.distance_to(centre))
	size_m = clampf(far * 2.0, 0.4, 6.0)
	_outline_soon()
	var r := clampf(size_m / 1.8, 0.6, 2.0)
	for e: Dictionary in anatomy.shots:
		_draw_shot(e, r)


## The body's own helper drivers (CharacterBodyMesh: the arms' twist bones and the like, root bones it places from the limbs) run
## once on its pose as it lies, so the skin drawn and outlined is whole: a man who fell far off or out of sight had them off, and
## his arms' skin stays pulled to the helpers' rest, where a standing man's arms would be (his body at rest is never updated
## again: what this updates stays drawn after, the corpse put right too).
func _drive_helpers() -> void:
	# (run outside the modifier pass: what a modifier sets in its own pass is undone after each update; set so, it stays)
	for c in sk.get_children():
		if c is CharacterBodyMesh and not (c as SkeletonModifier3D).active and c.has_method(&"_process_modification"):
			c.call(&"_process_modification")


## What the shots did to each structure: {key: {reached, dmg (a bone's, 0..1), cut (a vessel bleeding)}}, keyed by name (the cord's
## by its shape: only the stretch that was hurt), and the cord's levels hurt through a broken vertebra.
func _states() -> Dictionary:
	var st := {}
	for e: Dictionary in anatomy.shots:
		var rec: Dictionary = e.rec
		for row: Dictionary in rec.crossed:
			var kind := String(row.kind)
			if kind == "flesh":
				continue
			var key := "#%d" % int(row.i) if kind == "cord" else String(row.name)
			var d: Dictionary = st.get(key, {"reached": true, "dmg": 0.0, "cut": false})
			var res := String(row.res)
			if kind == "bone":
				var brk := float(model.shapes[int(row.i)].get("brk", 30.0))
				var k := clampf(0.4 + float(row.get("dep", 0.0)) / maxf(brk * 4.0, 1.0), 0.4, 1.0) if res == "fractured" else 0.25
				d.dmg = maxf(float(d.dmg), k)
				if res == "fractured" and String(row.name).contains("vertebra"):
					for j in model.shapes.size():
						if String(model.shapes[j].kind) == "cord" and int(model.shapes[j].get("lvl", 0)) == int(row.lvl):
							st["#%d" % j] = {"reached": true, "dmg": 0.0, "cut": false}
			if kind == "vessel" and (res == "cut" or res == "nicked"):
				d.cut = true
			st[key] = d
	return st


func _material_for(s: Dictionary, i: int, st: Dictionary) -> Material:
	var kind := String(s.kind)
	var key := "#%d" % i if kind == "cord" else String(s.name)
	var col: Color = s.col
	var d: Dictionary = st.get(key, {})
	if not d.is_empty():
		counts.bright = int(counts.bright) + 1
		if kind == "vessel" and bool(d.cut):
			counts.pulsing = int(counts.pulsing) + 1
			return _pulse(col)
		if kind == "bone":
			counts.tinted = int(counts.tinted) + 1
			var t: Color = (BONE_HIT[0] as Color).lerp(BONE_HIT[1], clampf((float(d.dmg) - 0.25) / 0.75, 0.0, 1.0))
			return _flat(t, 0.97, 20)
		return _flat(col.lightened(0.35), 0.72 if kind == "organ" else 0.95, 20)
	var a := 0.5
	match kind:
		"bone":
			a = 0.16 if String(s.get("sub", "")) == "skull" else 0.5
			col = Color(0.93, 0.92, 0.86)
		"organ":
			a = 0.5
		"vessel":
			a = 0.78
		"cord":
			a = 0.7
	return _flat(col, a, 0)


func _flat(col: Color, a: float, prio: int, on_top := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%d|%s" % [col.to_html(), a, prio, on_top]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = prio
	m.no_depth_test = on_top
	_mats[key] = m
	return m


## A cut vessel: its colour pulsing (it bleeds).
func _pulse(col: Color) -> ShaderMaterial:
	if _pulse_shader == null:
		_pulse_shader = Shader.new()
		_pulse_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 col : source_color;
void fragment() {
	float p = 0.5 + 0.5 * sin(TIME * 7.0);
	ALBEDO = mix(col.rgb, vec3(1.0, 0.86, 0.82), p * 0.5);
	ALPHA = 0.6 + 0.4 * p;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _pulse_shader
	m.set_shader_parameter("col", col)
	m.render_priority = 25
	return m


## The outline two frames on: the helpers driven (_drive_helpers) reach the skin the renderer draws in the skeleton's own deferred
## update, after this frame's work (_process counts them down).
func _outline_soon() -> void:
	_outline_wait = 2


## The skin's outline, faint with a bright rim: each skin mesh itself (its own mesh, skin and blend shapes as he wears them: a
## man's build or a woman's, the face) on a bare skeleton of its own in the view's world that holds every bone where the body is
## drawn now (_drawn_poses); the renderer skins it, as it does the body (none of the work here; the 90 000 points of a person's
## skin are not gone through by hand).
func _outline() -> void:
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform vec4 col : source_color;
void fragment() {
	float r = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = col.rgb;
	ALPHA = col.a * (0.03 + pow(r, 3.0) * 0.7);
}
"""
	var rim := ShaderMaterial.new()
	rim.shader = _rim_shader
	rim.set_shader_parameter("col", SKIN)
	rim.render_priority = 30
	var t0 := Time.get_ticks_usec()
	var poses := _drawn_poses()
	var bare := Skeleton3D.new()
	bare.name = "Outline"
	for b in sk.get_bone_count():
		bare.add_bone(sk.get_bone_name(b))     # (every bone a root: each holds its drawn pose as it is)
	_root3.add_child(bare)                      # (into the view's world, then posed)
	bare.global_transform = sk.global_transform
	for b in poses.size():
		var g := poses[b]
		bare.set_bone_pose_position(b, g.origin)
		bare.set_bone_pose_rotation(b, g.basis.get_rotation_quaternion())
		bare.set_bone_pose_scale(b, g.basis.get_scale())
	for nm in model.skin_names:
		for node in sk.find_children(nm, "MeshInstance3D", true, false):
			var src := node as MeshInstance3D
			if src.mesh == null or src.skin == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = src.mesh
			mi.skin = src.skin
			mi.material_override = rim
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bare.add_child(mi)
			mi.skeleton = NodePath("..")        # (its skeleton the parent; a new mesh's path is empty: no skin, its rest pose)
			mi.transform = sk.global_transform.affine_inverse() * src.global_transform
			for i in src.get_blend_shape_count():
				mi.set_blend_shape_value(i, src.get_blend_shape_value(i))
			counts.outline = int(counts.outline) + 1
	outline = bare
	counts["outline_ms"] = snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)


## Every bone where the body is drawn now (the skeleton's frame): from the renderer's skin transforms where it has them (what the
## modifiers did to the bones is in those: a ragdoll's, the body's helper drivers' that turn the arms' twist bones), else (no
## renderer: headless) the skeleton's own pose with the ragdoll's overrides (BodyModel.pose).
func _drawn_poses() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for b in sk.get_bone_count():
		out.append(BodyModel.pose(sk, b, _ov, _memo))
	for nm in model.skin_names:
		for node in sk.find_children(nm, "MeshInstance3D", true, false):
			var src := node as MeshInstance3D
			var sref := src.get_skin_reference()
			if src.skin == null or sref == null or not sref.get_skeleton().is_valid():
				continue
			var rid := sref.get_skeleton()
			for i in mini(RenderingServer.skeleton_get_bone_count(rid), src.skin.get_bind_count()):
				var t := RenderingServer.skeleton_bone_get_transform(rid, i)
				if t == Transform3D.IDENTITY:
					continue                        # (nothing drawn: the skeleton's own)
				var nm_b := src.skin.get_bind_name(i)
				var b := sk.find_bone(nm_b) if nm_b != &"" else src.skin.get_bind_bone(i)
				if b >= 0 and b < out.size():
					out[b] = t * src.skin.get_bind_pose(i).affine_inverse()
	return out


## A shot: its path (green the latest, white the earlier) through the points it went by, a red dot at each hole it went in by, a
## blue one at each it came out of, a purple one where it stopped, an orange one where it hurt the cord, its number by the entry.
func _draw_shot(e: Dictionary, r: float) -> void:
	var rec: Dictionary = e.rec
	var latest := bool(e.get("latest", false))
	var pts: Array[Vector3] = []
	for a: Dictionary in rec.path:
		pts.append(BodyModel.where(sk, a, _ov, _memo))
	var line_col := GREEN if latest else WHITE
	for i in range(1, pts.size()):
		if _segment(pts[i - 1], pts[i], 0.0035 * r, line_col):
			counts["green" if latest else "white"] = int(counts["green" if latest else "white"]) + 1
	var entry := BodyModel.where(sk, e.entry_a, _ov, _memo)
	if (rec.holes as Array).is_empty():
		_dot(entry, 0.013 * r, RED)
		counts.dot_in = int(counts.dot_in) + 1
	for h: Dictionary in rec.holes:
		var out := bool(h.out)
		_dot(BodyModel.where(sk, h.a, _ov, _memo), 0.013 * r, BLUE if out else RED)
		counts["dot_out" if out else "dot_in"] = int(counts["dot_out" if out else "dot_in"]) + 1
	if rec.has("stop_a"):
		_dot(BodyModel.where(sk, rec.stop_a, _ov, _memo), 0.014 * r, PURPLE)
		counts.dot_stop = int(counts.dot_stop) + 1
	# the cord: where the round crossed it, or the level of the vertebra it broke
	var cord_at := Vector3.INF
	for row: Dictionary in rec.crossed:
		if String(row.kind) == "cord" and String(row.res) == "injured":
			cord_at = BodyModel.where(sk, row.a, _ov, _memo)
			break
	if cord_at == Vector3.INF and int((e.fx as Dictionary).get("cord_lvl", 0)) > 0:
		var lvl := int((e.fx as Dictionary).cord_lvl)
		for j in model.shapes.size():
			if String(model.shapes[j].kind) == "cord" and int(model.shapes[j].get("lvl", 0)) == lvl:
				cord_at = model.shape_world(sk, j, _ov, _memo).origin
				break
	if cord_at != Vector3.INF:
		_dot(cord_at, 0.013 * r, ORANGE)
		counts.dot_cord = int(counts.dot_cord) + 1
	var tag := Label3D.new()
	tag.text = "%d" % int(e.n)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0009
	tag.font_size = 28
	tag.outline_size = 8
	tag.modulate = line_col
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.render_priority = 120
	_root3.add_child(tag)
	tag.position = entry + frame.x * 0.03 * r + frame.y * 0.03 * r


func _dot(at: Vector3, radius: float, col: Color) -> void:
	if at == Vector3.INF:
		return
	var sp := SphereMesh.new()
	sp.radius = radius
	sp.height = radius * 2.0
	sp.radial_segments = 12
	sp.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sp
	mi.material_override = _flat(col, 1.0, 110, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root3.add_child(mi)
	mi.position = at


func _segment(a: Vector3, b: Vector3, radius: float, col: Color) -> bool:
	if a == Vector3.INF or b == Vector3.INF or a.distance_to(b) < 0.002:
		return false
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 6
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _flat(col, 0.95, 100, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root3.add_child(mi)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)
	return true


# ---------------------------------------------------------------------------------------------------------------------
# The writing over it


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FrontierHUD.serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.border_color = Color(FrontierHUD.GOLD, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _ui() -> void:
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	# the top: which side, and whose body
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-300, 22)
	top.size = Vector2(600, 70)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top)
	_viewing = _label("VIEWING FRONT", 30, Color(FrontierHUD.GOLD, 1.0).lightened(0.25))
	_viewing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_viewing)
	var dead := subject != null and subject.has_method("is_dead") and bool(subject.call("is_dead"))
	var who := String(subject.call("inspect_title")) if subject != null and subject.has_method("inspect_title") else "Body"
	var n := anatomy.shots.size()
	var sub := _label("%s  ·  %s  ·  %d shot%s" % [who, "dead" if dead else "alive", n, "" if n == 1 else "s"], 16, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(sub)
	# the shots, the latest first
	if n > 0:
		var sp := _panel()
		sp.position = Vector2(18, 18)
		sp.custom_minimum_size = Vector2(380, 0)
		ui.add_child(sp)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.add_child(col)
		var shown_n := 0
		for k in range(n - 1, -1, -1):
			var e: Dictionary = anatomy.shots[k]
			if shown_n >= 4:
				col.add_child(_label("… %d earlier" % (k + 1), 14, DIM))
				break
			shown_n += 1
			var latest := bool(e.get("latest", false))
			col.add_child(_label("SHOT %d%s" % [int(e.n), "  ·  LATEST" if latest else ""], 17, GREEN if latest else WHITE))
			col.add_child(_label(_what(e), 14, DIM))
			var lines: Array = e.lines
			if lines.is_empty():
				col.add_child(_label("   Missed: it went by", 15, INK))
			for ln in lines:
				col.add_child(_label("   " + String(ln), 15, INK))
	# the legend, bottom right
	var lg := _panel()
	lg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lg.position = Vector2(-18, -58)
	ui.add_child(lg)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lg.add_child(rows)
	for r: Array in [["●", RED, "Where a round or an arrow went in"], ["●", BLUE, "Where it came out"],
			["●", PURPLE, "Where it stopped inside"], ["━", GREEN, "The latest shot's path"], ["━", WHITE, "An earlier shot's path"],
			["■", Color(1.0, 0.95, 0.75), "What a shot reached (bright)"], ["■", Color(1.0, 0.45, 0.45), "A cut vessel, bleeding (pulsing)"],
			["■", BONE_HIT[1], "A struck bone, yellow to crimson by damage"], ["●", ORANGE, "Where the spinal cord was hurt"],
			["━", BodyBuild.ARTERY, "Arteries"], ["━", BodyBuild.VEIN, "Veins"], ["━", BodyBuild.CORD, "The spinal cord"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sw := _label(String(r[0]), 16, r[1])
		sw.custom_minimum_size = Vector2(18, 0)
		sw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(sw)
		h.add_child(_label(String(r[2]), 15, INK))
		rows.add_child(h)
	# the controls, along the bottom
	var ctl := _label(CONTROLS, 15, DIM)
	ctl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl.position = Vector2(-450, -34)
	ctl.size = Vector2(900, 24)
	ui.add_child(ctl)


## What struck, how fast and how it went ("Ball, 320 m/s, 1638 J  ·  through and through").
static func _what(e: Dictionary) -> String:
	var nm: String = {"ball": "Ball", "arrow": "Arrow", "dart": "Dart", "spear": "Spear", "tomahawk": "Tomahawk", "blade": "Blade"}.get(String(e.kind), "Ball")
	var rec: Dictionary = e.rec
	var how := "missed"
	if Vector3(rec.exit) != Vector3.INF:
		how = "through and through"
	elif Vector3(rec.stop) != Vector3.INF:
		how = "stopped inside"
	elif String(e.get("graze", "")) != "":
		how = "a graze"
	return "%s, %d m/s, %d J  ·  %s" % [nm, roundi(float(e.speed)), roundi(float(e.energy)), how]
