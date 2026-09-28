class_name TargetDummy
extends Node3D
## Straw practice dummy on a post. Head shots do double damage. It topples
## when its health runs out and stands back up after a few seconds. Can
## slide back and forth to practise leading a moving target.

@export var max_health := 100.0
@export var respawn_time := 4.0
@export var move_offset := Vector3.ZERO
@export var move_period := 4.0

var health := 100.0
var _start: Vector3
var _t := 0.0
var _dead := false
var _flash := 0.0
var _body: AnimatableBody3D
var _straw: StandardMaterial3D
var _base_color := Color(0.78, 0.66, 0.38)


func _ready() -> void:
	health = max_health
	_start = position
	_build()


func _build() -> void:
	_straw = StandardMaterial3D.new()
	_straw.albedo_color = _base_color
	_straw.roughness = 1.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.25, 0.15)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.55, 0.16, 0.12)

	_body = AnimatableBody3D.new()
	add_child(_body)
	# Post: stops shots but takes no damage.
	_mesh(_body, _cyl(0.05, 1.9), Vector3(0, 0.95, 0), wood)
	var post := StaticBody3D.new()
	post.set_meta("hit_part", "post")
	post.set_meta("damage_mult", 0.0)
	_body.add_child(post)
	_shape(post, Vector3(0, 0.45, 0), 0.06, 0.9, "Post")
	_mesh(_body, _box(Vector3(0.9, 0.07, 0.07)), Vector3(0, 1.35, 0), wood)
	# Torso (straw with a red coat) and head.
	_mesh(_body, _cyl(0.2, 0.65), Vector3(0, 1.2, 0), cloth)
	_shape(_body, Vector3(0, 1.2, 0), 0.22, 0.7, "Torso")
	var head := StaticBody3D.new()
	head.set_meta("hit_part", "head")
	head.set_meta("damage_mult", 2.0)
	_body.add_child(head)
	var hm := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.13
	s.height = 0.28
	hm.mesh = s
	hm.material_override = _straw
	hm.position = Vector3(0, 1.68, 0)
	head.add_child(hm)
	var hs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.14
	hs.shape = sph
	hs.position = Vector3(0, 1.68, 0)
	head.add_child(hs)
	# Straw arms (solid: a swing stops on them, as on the rest; AxeMelee, MeleeSweep).
	for side: float in [-1.0, 1.0]:
		_mesh(_body, _box(Vector3(0.35, 0.1, 0.1)), Vector3(side * 0.35, 1.35, 0), _straw)
	var arms := CollisionShape3D.new()
	arms.name = "Arms"
	var ab := BoxShape3D.new()
	ab.size = Vector3(1.05, 0.1, 0.1)
	arms.shape = ab
	arms.position = Vector3(0, 1.35, 0)
	_body.add_child(arms)
	# Legs are just the post; a wide base keeps it upright.
	_mesh(self, _box(Vector3(0.6, 0.08, 0.6)), Vector3(0, 0.04, 0), wood)


func _physics_process(delta: float) -> void:
	if move_offset != Vector3.ZERO and not _dead:
		_t += delta
		position = _start + move_offset * (0.5 - 0.5 * cos(_t * TAU / move_period))
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		_straw.albedo_color = _base_color.lerp(Color(1, 1, 1), _flash)


func apply_hit(damage: float, point: Vector3, _dir: Vector3, _source: Node, part: String) -> void:
	if _dead or damage <= 0.0:
		return
	health -= damage
	# Layered over the projectile's straw impact; louder for harder hits, head hits brighter.
	Sfx.play_3d(&"dummy_hit_head" if part == "head" else &"dummy_hit", point,
			linear_to_db(clampf(damage / 100.0, 0.4, 1.2)))
	_flash = 1.0
	_popup(point, "%d%s" % [roundi(damage), "  HEAD" if part == "head" else ""], part == "head")
	if health <= 0.0:
		_die(_dir)


func _die(dir: Vector3) -> void:
	_dead = true
	Sfx.play_3d(&"dummy_topple", global_position + Vector3.UP * 0.8)   # Baked to the fall tween.
	get_tree().call_group("hit_listeners", "on_target_killed", self)
	var axis := Vector3.UP.cross(Vector3(dir.x, 0, dir.z).normalized())
	if axis.length_squared() < 0.01:
		axis = Vector3.RIGHT
	var t := create_tween()
	t.tween_property(_body, "quaternion", Quaternion(axis.normalized(), PI * 0.47), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_interval(respawn_time)
	t.tween_callback(func() -> void: Sfx.play_3d(&"dummy_reset", global_position + Vector3.UP))
	t.tween_property(_body, "quaternion", Quaternion.IDENTITY, 0.6).set_trans(Tween.TRANS_BACK)
	t.tween_callback(func() -> void:
		_dead = false
		health = max_health)


func _popup(pos: Vector3, text: String, crit: bool) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 48 if crit else 36
	l.outline_size = 8
	l.modulate = Color(1, 0.35, 0.25) if crit else Color(1, 0.95, 0.8)
	l.pixel_size = 0.004
	get_tree().current_scene.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.1, 0.1), 0.25, 0)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 0.7, 0), 1.0)
	t.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)


static func _shape(body: CollisionObject3D, pos: Vector3, r: float, h: float, nm: String) -> void:
	var cs := CollisionShape3D.new()
	cs.name = nm
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = pos
	body.add_child(cs)
