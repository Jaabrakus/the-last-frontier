class_name RingMoveLooks
extends Node3D
## The looks and sounds of Tidebreak's ring movement (round 3, smash_r3 spec §3.2, §3.4, §4.2, §4.6, §5.4; MOVE's file): a
## child of a body's RingMoves. Our own procedural effects (BendLooks) and our own sounds (BendSounds' synthesized table, and
## the few below made here by code: nothing recorded or downloaded).
##   on the body, seen by all    the double jump's flavour (earth a slab under the feet that crumbles in 0.3 s, no
##                               collider; water a splash ring; fire jets from both feet; air a gust ring), the dodge's
##                               element puff, each Rise's tell (shown ABOVE the lip, loud, heard by everyone: the move's own
##                               tell, not a cue) and its column, jet trail or whirl, the exhale's dull puff
##   his own (own: the local player only; never on another body)
##     sounds    a rushing whoosh for as long as he is in hitstun, cut on his first free frame; a short rising tick when
##               the escape opens; a dull "spent" when he presses Space, 3, E or a cast key while helpless; a short exhale
##               when his last air move goes
##     shadow    a soft dark blob under his own feet, on the deck and on the water
## heard: his own sounds as they played (the tests); whoosh_on.

var moves: RingMoves
## The local player's: his own sounds and shadow.
var own := false
## His own sounds as they played, oldest first (the tests read it).
var heard: Array[String] = []
var whoosh_on := false
## When an airborne cast last left his hands (AIR's air_cast; SwayPose plays the air legs from it).
var air_legs_at := -INF

static var _waves := {}
var _whoosh: AudioStreamPlayer
var _one: AudioStreamPlayer
var _shadow: MeshInstance3D
var _column: MeshInstance3D
var _column_el := ""
var _column_sink := -1.0
## The earth column leans back from the lip (the way back's Rise); the in-ring Rise's stands straight.
var _column_lean := true
var _trail: GPUParticles3D
## The water's Stream (the Rise's dragon of water, the owner 2026-10-12): its body from the water along the way he flew to
## his feet (_path, rebuilt as he goes), sinking once the Rise is over.
var _stream: MeshInstance3D
var _path := PackedVector3Array()
var _stream_sink := -1.0
var _stream_head := Vector3.ZERO
const STREAM_STEP_M := 0.3
const STREAM_R := Vector2(0.6, 0.32)        ## its thickness at the water and at his feet
const STREAM_SEGS := 10


func _ready() -> void:
	top_level = true
	if own:
		_whoosh = AudioStreamPlayer.new()
		_whoosh.name = "OwnWhoosh"
		_whoosh.stream = wave("whoosh")
		_whoosh.volume_db = RingMoves.num("sounds", "whoosh_db", -14.0)
		_whoosh.bus = _bus()
		add_child(_whoosh)
		_one = AudioStreamPlayer.new()
		_one.name = "OwnSound"
		_one.bus = _bus()
		add_child(_one)
		_shadow = MeshInstance3D.new()
		_shadow.name = "OwnShadow"
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		_shadow.mesh = q
		_shadow.material_override = _shadow_mat()
		_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadow.top_level = true
		add_child(_shadow)


static func _bus() -> StringName:
	return &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"


func _body() -> CharacterBody3D:
	return moves.body if moves != null else null


func _feet() -> Vector3:
	var b := _body()
	return b.global_position if b != null else global_position


static func _kind(el: String) -> String:
	return {"earth": "stone", "water": "water", "fire": "fire", "air": "air"}.get(el, "water")


# ---------------------------------------------------------------- on the body, seen by all
## The double jump's flavour under his feet.
func double_jump(el: String) -> void:
	var at := _feet()
	match el:
		"earth":
			_slab(at)
			BendLooks.burst(at, "stone", 12, Vector3.DOWN, 70.0, 2.5, 0.16)
			BendSounds.play(&"earth_cast_crack", at, -8.0, 1.2)
		"water":
			BendLooks.burst(at + Vector3.UP * 0.1, "water", 22, Vector3.UP, 85.0, 3.0, 0.14)
			BendSounds.play(&"water_slosh", at, -8.0, 1.2)
		"fire":
			BendLooks.burst(at + Vector3.UP * 0.05, "fire", 18, Vector3.DOWN, 18.0, 6.0, 0.2)
			BendSounds.play(&"fire_whoomph", at, -8.0, 1.3)
		_:
			BendLooks.burst(at + Vector3.UP * 0.1, "air", 22, Vector3.UP, 88.0, 3.5, 0.2)
			BendSounds.play(&"air_whoosh", at, -6.0, 1.4)


## An earth slab under the feet that crumbles in 0.3 s (a look: no collider).
func _slab(at: Vector3) -> void:
	if not BendLooks.live() or not is_inside_tree():
		return
	var m := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.9, 0.18, 0.9)
	m.mesh = bx
	m.material_override = BendLooks.material("stone")
	m.top_level = true
	add_child(m)
	m.global_position = at - Vector3.UP * 0.1
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(0.2, 0.2, 0.2), 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "global_position", at - Vector3.UP * 0.7, 0.3)
	tw.tween_callback(m.queue_free)


## The dodge's element puff on him, and its sound (the double jump's, lighter: the sound audit, 2026-10-13, the dodge was
## silent for everyone).
func dash(el: String) -> void:
	var at := _feet() + Vector3.UP * 0.8
	BendLooks.burst(at, _kind(el), 10, Vector3.UP, 120.0, 1.6, 0.18)
	match el:
		"earth":
			BendSounds.play(&"earth_grind", at, -9.0, 1.25)
		"water":
			BendSounds.play(&"water_slosh", at, -9.0, 1.25)
		"fire":
			BendSounds.play(&"fire_whoomph", at, -9.0, 1.35)
		_:
			BendSounds.play(&"air_whoosh", at, -8.0, 1.35)


## The Rise's tell (from `at`, the body; `lip`, the nearest lip point): shown above the lip and loud, for everyone. The in-ring
## Rise (`lean` false) shows it where he is, its column straight up.
func rise_tell(el: String, at: Vector3, lip: Vector3, lean := true) -> void:
	_column_lean = lean
	var r := RingMoves.rise_of(el)
	var tell := Vector3(lip.x, lip.y + 1.2, lip.z)
	BendSounds.play(StringName(String(r.get("sound", "air_swirl"))), Vector3(lip.x, lip.y, lip.z),
			RingMoves.num("sounds", "tell_db", 4.0), 0.9)
	BendSounds.play(StringName(String(r.get("sound", "air_swirl"))), at, RingMoves.num("sounds", "tell_db", 4.0) - 2.0)
	match el:
		"earth":
			_column_up("earth", at)
			BendLooks.rise(Vector3(lip.x, lip.y, lip.z), Vector3(1.4, 1.0, 1.4), Vector3.UP, "earth")
			BendLooks.burst(tell, "stone", 26, Vector3.UP, 25.0, 6.0, 0.25)
		"water":
			_stream_up(at, lean)
			BendLooks.spout(Vector3(lip.x, lip.y, lip.z), 0.9, 0.08)
			BendLooks.burst(tell, "water", 30, Vector3.UP, 20.0, 7.0, 0.2)
		"fire":
			_trail_on("fire")
			BendLooks.burst(tell, "fire", 36, Vector3.UP, 15.0, 8.5, 0.3)
			BendLooks.burst(at + Vector3.UP * 0.2, "fire", 24, Vector3.DOWN, 30.0, 5.0, 0.25)
		_:
			_trail_on("air")
			BendLooks.burst(tell, "air", 36, Vector3.UP, 30.0, 7.0, 0.35)


## The Rise over: its column sinks (rise.earth.sink_after_s), the trail stops, the Stream falls back.
func rise_end(el: String, _at: Vector3) -> void:
	_column_sink = float(RingMoves.rise_of(el).get("sink_after_s", 0.4))
	if _stream != null and is_instance_valid(_stream):
		_stream_sink = 0.25
	if _trail != null and is_instance_valid(_trail):
		BendLooks.stop_trail(_trail)
	_trail = null


func _trail_on(kind: String) -> void:
	var b := _body()
	if b == null or not BendLooks.live():
		return
	_trail = BendLooks.trail(b, kind, 0.4)


## The earth column (stone) or the water column from the water to his feet, following him while he rises; never a platform
## (a mesh only, no collider).
func _column_up(el: String, _at: Vector3) -> void:
	if not BendLooks.live() or not is_inside_tree():
		return
	if _column != null and is_instance_valid(_column):
		_column.queue_free()
	_column = MeshInstance3D.new()
	_column.name = "RiseColumn"
	var c := CylinderMesh.new()
	c.top_radius = 0.55 if el == "earth" else 0.45
	c.bottom_radius = 0.75 if el == "earth" else 0.6
	c.height = 1.0
	c.radial_segments = 10
	_column.mesh = c
	_column.material_override = BendLooks.material("stone" if el == "earth" else "water")
	_column.top_level = true
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_column)
	_column_el = el
	_column_sink = -1.0


## The column from the water up to `top` (stretched, leaning along it).
func _column_to(top: Vector3) -> void:
	if _column == null or not is_instance_valid(_column):
		return
	var g := moves.lip_near(top)
	var wy := top.y - 6.0
	if moves != null:
		var gg: Dictionary = moves._geo()
		if not gg.is_empty():
			wy = float(gg.water_y)
	var base := Vector3(top.x, wy, top.z)
	if not g.is_empty() and _column_el == "earth" and _column_lean:
		# (the leaning column: its foot back along the lean, away from the lip)
		var n: Vector3 = g.normal
		base += n * (top.y - wy) * tan(deg_to_rad(float(RingMoves.rise_of("earth").get("lean_deg", 20.0))))
	var axis := top - base
	var h := maxf(axis.length(), 0.1)
	var up := axis / h
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = up.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(up).normalized()
	_column.global_transform = Transform3D(Basis(x, up, z), (base + top) * 0.5)
	(_column.mesh as CylinderMesh).height = h


## The Stream begun: from the water under him (the in-ring Rise's, `from_water` false: from the deck at his feet) to his feet.
func _stream_up(at: Vector3, from_water: bool) -> void:
	if not BendLooks.live() or not is_inside_tree():
		return
	if _stream != null and is_instance_valid(_stream):
		_stream.queue_free()
	var wy := at.y - 6.0
	var gg: Dictionary = moves._geo() if moves != null else {}
	if not gg.is_empty():
		wy = float(gg.water_y)
	var feet := _feet()
	_path = PackedVector3Array([Vector3(feet.x, wy if from_water else feet.y - 0.3, feet.z)])
	_stream_head = feet
	_stream = MeshInstance3D.new()
	_stream.name = "RiseStream"
	_stream.top_level = true
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ring/ring_curtain.gdshader")
	mat.set_shader_parameter(&"tint", Color(0.3, 0.64, 0.95))
	mat.set_shader_parameter(&"foam", Color(0.92, 0.97, 1.0))
	mat.set_shader_parameter(&"alpha", 0.88)
	mat.set_shader_parameter(&"flow_mps", -8.0)       # (its water running up it toward him)
	mat.set_shader_parameter(&"height", 8.0)
	_stream.material_override = mat
	add_child(_stream)
	_stream_sink = -1.0
	_stream_mesh()


## The Stream's tube along _path and on to its head (his feet; thick at the water, thinner at his feet), UV.y metres back
## from his feet.
func _stream_mesh() -> void:
	if _stream == null or _path.is_empty():
		return
	var pts := _path.duplicate()
	if _stream_head.distance_to(pts[pts.size() - 1]) > 0.02:
		pts.append(_stream_head)
	if pts.size() < 2:
		return
	var n := pts.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist[n - 1] = 0.0
	for i in range(n - 2, -1, -1):
		dist[i] = dist[i + 1] + pts[i].distance_to(pts[i + 1])
	var total := maxf(dist[0], 0.01)
	(_stream.material_override as ShaderMaterial).set_shader_parameter(&"height", total)    # (its white water at the tank's end)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ref := Vector3.RIGHT
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		t = t.normalized() if t.length_squared() > 1e-6 else Vector3.UP
		var a := t.cross(ref)
		if a.length_squared() < 1e-4:
			a = t.cross(Vector3.FORWARD)
		a = a.normalized()
		var b := t.cross(a).normalized()
		ref = b.cross(t).normalized()             # (carried along: the tube never twists at a turn)
		var r := lerpf(STREAM_R.y, STREAM_R.x, dist[i] / total)
		for k in STREAM_SEGS + 1:
			var ang := TAU * float(k) / float(STREAM_SEGS)
			var nrm := a * cos(ang) + b * sin(ang)
			st.set_normal(nrm)
			st.set_uv(Vector2(TAU * r * float(k) / float(STREAM_SEGS), dist[i]))
			st.add_vertex(pts[i] + nrm * r)
	for i in n - 1:
		for k in STREAM_SEGS:
			var v0 := i * (STREAM_SEGS + 1) + k
			var v1 := v0 + STREAM_SEGS + 1
			st.add_index(v0)
			st.add_index(v1)
			st.add_index(v0 + 1)
			st.add_index(v0 + 1)
			st.add_index(v1)
			st.add_index(v1 + 1)
	_stream.mesh = st.commit()


## The exhale (his own ears) and a dull puff of his element (on him): his last air move gone.
func exhale(el: String) -> void:
	BendLooks.burst(_feet() + Vector3.UP * 1.4, _kind(el), 6, Vector3.UP, 60.0, 0.7, 0.14)
	_own_sound("exhale", RingMoves.num("sounds", "exhale_db", -14.0))


# ---------------------------------------------------------------- his own
## "Spent": a press while helpless.
func spent() -> void:
	_own_sound("spent", RingMoves.num("sounds", "spent_db", -12.0))


## The escape is open (0.6 s into a long hitstun): a short rising tick.
func escape_tick() -> void:
	_own_sound("tick", RingMoves.num("sounds", "tick_db", -10.0))


## The hitstun whoosh on (in hitstun) or cut (his first free frame).
func whoosh(on: bool) -> void:
	if not own or on == whoosh_on:
		return
	whoosh_on = on
	if on:
		heard.append("whoosh")
	else:
		heard.append("whoosh_end")
	if _whoosh != null:
		if on:
			_whoosh.play()
		else:
			_whoosh.stop()


func _own_sound(key: String, db: float) -> void:
	if not own:
		return
	heard.append(key)
	if heard.size() > 64:
		heard.remove_at(0)
	if _one == null or DisplayServer.get_name() == "headless":
		return
	var p := AudioStreamPlayer.new()
	p.stream = wave(key)
	p.volume_db = db
	p.bus = _bus()
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func tick(_dt: float) -> void:
	var b := _body()
	if b == null:
		return
	if _stream != null and is_instance_valid(_stream):
		if moves.mode == "rise" and _stream_sink < 0.0:
			_stream_head = _feet()
			if _stream_head.distance_to(_path[_path.size() - 1]) >= STREAM_STEP_M:
				_path.append(_stream_head)        # (a point of its body laid; the head follows his feet between them)
			_stream_mesh()
		elif _stream_sink >= 0.0:
			_stream_sink -= _dt
			if _stream_sink <= 0.0:
				var sm := _stream
				_stream = null
				var tw := sm.create_tween()
				tw.tween_property(sm, "global_position", sm.global_position - Vector3.UP * 7.0, 0.6).set_ease(Tween.EASE_IN)
				tw.tween_callback(sm.queue_free)
	if moves.mode == "rise" and _column != null and is_instance_valid(_column):
		_column_to(b.global_position)
	elif _column_sink >= 0.0 and _column != null and is_instance_valid(_column):
		_column_sink -= _dt
		if _column_sink <= 0.0:
			var c := _column
			_column = null
			var tw := c.create_tween()
			tw.tween_property(c, "global_position", c.global_position - Vector3.UP * 7.0, 0.6).set_ease(Tween.EASE_IN)
			tw.tween_callback(c.queue_free)
	if own and _shadow != null:
		_place_shadow(b)


## His own drop shadow: straight under him on the deck (a ray), else on the water; softer and wider the higher he is.
func _place_shadow(b: CharacterBody3D) -> void:
	var from := b.global_position + Vector3.UP * 0.3
	var y := -INF
	var n := Vector3.UP
	if b.is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 40.0)
		q.exclude = [b.get_rid()]
		var hit := b.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			y = (hit.position as Vector3).y
			n = hit.normal
	var g: Dictionary = moves._geo()
	if not g.is_empty():
		y = maxf(y, float(g.water_y))
	if y == -INF:
		_shadow.visible = false
		return
	var h := maxf(b.global_position.y - y, 0.0)
	var fade := clampf(1.0 - h / maxf(RingMoves.num("shadow", "fade_m", 9.0), 0.1), 0.15, 1.0)
	var r := RingMoves.num("shadow", "r", 0.45) * (1.0 + RingMoves.num("shadow", "grow", 0.6) * (1.0 - fade))
	_shadow.visible = true
	var up := n.normalized() if n.length() > 0.1 else Vector3.UP
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = Vector3.RIGHT
	x = x.normalized()
	_shadow.global_transform = Transform3D(Basis(x, up, x.cross(up)).scaled(Vector3(r * 2.0, 1.0, r * 2.0)),
			Vector3(b.global_position.x, y + 0.03, b.global_position.z))
	(_shadow.material_override as StandardMaterial3D).albedo_color.a = RingMoves.num("shadow", "alpha", 0.55) * fade


## The shadow's look: a soft dark round blob (a radial gradient, unshaded, no cel).
static func _shadow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.55, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = gr
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	m.render_priority = 1
	return m


# ---------------------------------------------------------------- our own synthesized sounds
## The sound `key` (whoosh: a loop of rushing filtered noise; tick: a short rising chirp; spent: a dull low thud; exhale: a
## soft breath of noise), made once by code from its own dice.
static func wave(key: String) -> AudioStreamWAV:
	if _waves.has(key):
		return _waves[key]
	var rate := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var out := PackedFloat32Array()
	match key:
		"whoosh":
			var n := rate
			out.resize(n)
			var lp := 0.0
			var lp2 := 0.0
			for i in n:
				var w := rng.randf_range(-1.0, 1.0)
				lp += (w - lp) * 0.12
				lp2 += (lp - lp2) * 0.3
				var swell := 0.75 + 0.25 * sin(TAU * float(i) / float(n) * 2.0)
				out[i] = (lp - lp2 * 0.6) * 1.6 * swell
		"tick":
			var n2 := int(rate * 0.09)
			out.resize(n2)
			var ph := 0.0
			for i in n2:
				var k := float(i) / float(n2)
				ph += TAU * lerpf(900.0, 1700.0, k) / float(rate)
				out[i] = sin(ph) * 0.6 * minf(k * 12.0, 1.0) * (1.0 - k)
		"spent":
			var n3 := int(rate * 0.14)
			out.resize(n3)
			var ph3 := 0.0
			var lp3 := 0.0
			for i in n3:
				var k3 := float(i) / float(n3)
				ph3 += TAU * lerpf(150.0, 85.0, k3) / float(rate)
				lp3 += (rng.randf_range(-1.0, 1.0) - lp3) * 0.08
				out[i] = (sin(ph3) * 0.7 + lp3 * 0.6) * exp(-k3 * 6.0)
		_:
			var n4 := int(rate * 0.38)
			out.resize(n4)
			var lp4 := 0.0
			var lp5 := 0.0
			for i in n4:
				var k4 := float(i) / float(n4)
				lp4 += (rng.randf_range(-1.0, 1.0) - lp4) * 0.25
				lp5 += (lp4 - lp5) * 0.05
				out[i] = (lp4 - lp5) * sin(PI * minf(k4 * 1.6, 1.0)) * (1.0 - k4 * 0.6) * 0.9
	var bytes := PackedByteArray()
	bytes.resize(out.size() * 2)
	for i in out.size():
		bytes.encode_s16(i * 2, int(clampf(out[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if key == "whoosh":
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = out.size()
	_waves[key] = s
	return s
