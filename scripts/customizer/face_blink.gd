class_name FaceBlink
extends Node
## Blinks: drives the `blink` blend shape (both lids, lashes follow) of a CharacterBodyMesh
## every 2-6 s (about 15 a minute, the resting rate), sometimes twice. A blink closes in
## 0.07 s and opens in 0.11 s. The source clips' facial idles are not in the animation
## graph; this keeps the eyes alive without them. The stylized head's larger eyes need the
## `blink_style` corrective as well (blink x the mesh's `style` value), so its lids close on the
## scaled eyeball.

var body: CharacterBodyMesh
var rate_min := 2.0
var rate_max := 6.0
var _t := 0.0
var _next := 3.0
var _double := false
var _rng := RandomNumberGenerator.new()
var _last := -1.0
## [MeshInstance3D, blink index, blink_style index or -1, style index or -1] of every body mesh
## with a `blink` shape.
var _targets: Array = []
var _mesh_count := -1

const CLOSE := 0.07
const OPEN := 0.11


func _ready() -> void:
	_rng.randomize()
	_next = _rng.randf_range(rate_min, rate_max)


func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	_t += delta
	var v := 0.0
	var s := _t - _next
	if s >= 0.0:
		if s < CLOSE:
			v = s / CLOSE
		elif s < CLOSE + OPEN:
			v = 1.0 - (s - CLOSE) / OPEN
		else:
			_t = 0.0
			if not _double and _rng.randf() < 0.12:
				_double = true
				_next = 0.12
			else:
				_double = false
				_next = _rng.randf_range(rate_min, rate_max)
	if v != _last:           # open most of the time: no shape writes then
		set_blink(v)


## Sets the blink shape directly (0 open .. 1 closed).
func set_blink(v: float) -> void:
	_last = v
	if body.meshes.size() != _mesh_count:
		_find_targets()
	for t: Array in _targets:
		if is_instance_valid(t[0]):
			var mi := t[0] as MeshInstance3D
			mi.set_blend_shape_value(t[1], v)
			if t[2] >= 0:
				mi.set_blend_shape_value(t[2], v * (mi.get_blend_shape_value(t[3]) if t[3] >= 0 else 0.0))


func _find_targets() -> void:
	_mesh_count = body.meshes.size()
	_targets.clear()
	for mi: MeshInstance3D in body.meshes:
		if is_instance_valid(mi) and mi.mesh:
			var i := mi.find_blend_shape_by_name(&"blink")
			if i >= 0:
				_targets.append([mi, i, mi.find_blend_shape_by_name(&"blink_style"), mi.find_blend_shape_by_name(&"style")])
