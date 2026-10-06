class_name RingSpout
extends Node3D
## The respawn spout of the % ring (smash_r3 spec v2 §7.2; PERCENT's; RingMode raises one for each respawn): our own
## procedural water column rising from a grate on the competitor's end, carrying him rules.json respawn.spout_up_m over
## the deck while MOVE's RingMoves.ride_spout holds him there (until he moves, jumps, presses a cast key, or respawn.spout_s
## pass: RingMoves.left_spout), then sinking back into the grate.
##   the push    while it stands, anyone else within respawn.clear_m of its axis and under the rider is pushed away at a
##               set respawn.clear_mps (tag "spout/push": 0%), each at most once a half second
##   the look    a column of falling-water streaks (shaders/ring/ring_curtain.gdshader on our own cylinder), a white crown
##               where it holds him, spray at its foot; risen and sunk over RISE_S (headless: none, the push still runs)
##   safe hits   RingSpout.safe_hit(at): the hiss and the splash-through where a hit passed through a safe body (RingRules
##               hit_safe: an effect of the hit at its point, never a mark on him)
##   the drip    hud.json respawn_drip (default false): a drip of water off the respawned body for drip_s (drip(body))
## RingSpout.raise(parent, at, rider, max_s) -> RingSpout; sink() (it frees itself once down); riding() while it holds him.

const RISE_S := 0.35
const RADIUS := 0.5
const SEGS := 16

var rider: Node3D
var top_y := 0.0
var max_s := 3.0
var age := 0.0
var sinking := false
## Bodies pushed off its foot (tests).
var pushes := 0
var _column: MeshInstance3D
var _crown: MeshInstance3D
var _h := 0.0
var _pushed := {}


## A spout at `at` (world, on the deck) carrying `rider` up to respawn.spout_up_m, standing at most `max_s` s.
static func raise(parent: Node, at: Vector3, who: Node3D, hold_s: float) -> RingSpout:
	var s := RingSpout.new()
	s.name = "RingSpout"
	s.rider = who
	s.max_s = hold_s
	parent.add_child(s)
	s.global_position = at
	s.top_y = RingRules.sub_num("respawn", "spout_up_m", 3.0)
	s._build()
	return s


## The hiss and the splash-through at `at` (a hit that passed through a safe body): white water bursting through the
## point both ways and the steam's hiss.
static func safe_hit(at: Vector3, dir := Vector3.FORWARD) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 1e-3 else Vector3.FORWARD
	BendLooks.burst(at, "water", 22, d, 35.0, 5.0, 0.25)
	BendLooks.burst(at, "water", 12, -d, 50.0, 2.5, 0.2)
	BendSounds.event("steam", at, 2.0, 1.25)
	BendLooks.sound("water", "hit", at, -2.0)


## A drip of water off `body` for `s` seconds (hud.json respawn_drip, default off: it rides on a body).
static func drip(body: Node3D, s := 1.5) -> void:
	if body == null or not is_instance_valid(body):
		return
	var g := BendLooks.trail(body, "water", 0.12)
	if g == null:
		return
	g.position = Vector3(0.0, 1.0, 0.0)
	body.get_tree().create_timer(s, false).timeout.connect(func() -> void:
		if is_instance_valid(g):
			BendLooks.stop_trail(g))


func _build() -> void:
	if not BendLooks.live() and DisplayServer.get_name() == "headless":
		return
	var cd := RingArena.block("curtain")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ring/ring_curtain.gdshader")
	mat.set_shader_parameter(&"tint", RingArena._tint(cd.get("tint"), Color(0.62, 0.82, 0.86)))
	mat.set_shader_parameter(&"foam", RingArena._tint(cd.get("foam"), Color(0.92, 0.97, 1.0)))
	mat.set_shader_parameter(&"alpha", 0.9)
	mat.set_shader_parameter(&"flow_mps", -4.0)            # (the column's water rises)
	mat.set_shader_parameter(&"height", top_y + 0.8)
	_column = MeshInstance3D.new()
	_column.name = "Column"
	_column.mesh = _cylinder(RADIUS, top_y + 0.8)
	_column.material_override = mat
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.position = Vector3(0.0, -0.8, 0.0)
	add_child(_column)
	var crown := SphereMesh.new()
	crown.radius = RADIUS * 1.5
	crown.height = RADIUS * 1.1
	crown.radial_segments = 16
	crown.rings = 6
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.9, 0.96, 1.0, 0.85)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.roughness = 0.35
	crown.material = cm
	_crown = MeshInstance3D.new()
	_crown.name = "Crown"
	_crown.mesh = crown
	_crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crown)
	_set_h(0.0)
	BendLooks.burst(global_position + Vector3.UP * 0.1, "water", 30, Vector3.UP, 25.0, 7.0, 0.3)
	BendLooks.sound("water", "cast", global_position, 0.0)


## A cylinder open at both ends, UV.x metres round it, UV.y metres down from its top (the curtain shader's layout).
static func _cylinder(r: float, h: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var circ := TAU * r
	for i in SEGS + 1:
		var a := TAU * float(i) / float(SEGS)
		var n := Vector3(cos(a), 0.0, sin(a))
		verts.append(n * r + Vector3.UP * h)
		verts.append(n * r)
		uvs.append(Vector2(circ * float(i) / float(SEGS), 0.0))
		uvs.append(Vector2(circ * float(i) / float(SEGS), h))
		normals.append(n)
		normals.append(n)
	for i in SEGS:
		var b := i * 2
		idx.append_array([b, b + 2, b + 1, b + 1, b + 2, b + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _set_h(f: float) -> void:
	_h = clampf(f, 0.0, 1.0)
	if _column != null:
		_column.scale = Vector3(1.0, maxf(_h, 0.01), 1.0)
		_column.visible = _h > 0.01
	if _crown != null:
		_crown.position = Vector3(0.0, top_y * _h, 0.0)
		_crown.visible = _h > 0.05


## Whether it still holds its rider up (risen, not sinking).
func riding() -> bool:
	return not sinking


## Down into the grate again (it frees itself once down).
func sink() -> void:
	sinking = true


func _physics_process(dt: float) -> void:
	age += dt
	if sinking:
		_set_h(_h - dt / RISE_S)
		if _h <= 0.0:
			queue_free()
		return
	_set_h(age / RISE_S)
	if age >= max_s + 0.5:
		sink()
	_push()


## Anyone else within clear_m of its axis and under the rider: pushed away (a set clear_mps, 0%).
func _push() -> void:
	var clear := RingRules.sub_num("respawn", "clear_m", 2.0)
	var mps := RingRules.sub_num("respawn", "clear_mps", 6.0)
	var now := BendStatus.now()
	var pool: Array = get_tree().get_nodes_in_group(NpcFighter.GROUP) + get_tree().get_nodes_in_group(&"player")
	for n in pool:
		if n == rider or not (n is Node3D) or not is_instance_valid(n):
			continue
		var p := (n as Node3D).global_position
		var flat := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
		if flat.length() > clear or p.y > global_position.y + top_y:
			continue
		if now - float(_pushed.get(n.get_instance_id(), -INF)) < 0.5:
			continue
		_pushed[n.get_instance_id()] = now
		var way := flat.normalized() if flat.length() > 0.05 else Vector3.RIGHT
		# (no one's knock: a push off the spout never takes the credit of a fall)
		BendStatus.knock(n, way * mps + Vector3.UP * 0.5, null, {"tag": "spout/push"})
		pushes += 1
