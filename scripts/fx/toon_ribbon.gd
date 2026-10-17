class_name ToonRibbon
extends MeshInstance3D
## A trail drawn as strips along where `target` has been (ToonFx's flame, water, wind and lightning shaders turn each strip to
## the camera): the main strand (`width` m half wide at the head, `tail_w` of that at the tail) and `coils` strands winding
## round the path (`coil_r` m out, `coil_w` half wide) that stay where they were laid, so they read as a corkscrew. It keeps
## `life` s of the path (points at most MAX_PTS); stop() lets go of the target and it shrinks into its tail and hides.
## UV.x runs 0 at the head to 1 at the tail (by age), UV.y across, UV2.x the half width; NORMAL is along the strip.
## Not freed when done: ToonFxPool reuses it with its trail.
## Round 4 (LOOKS): lay_across(anchor, half_w) draws it instead as one line across `anchor` (its local X, from -half_w to
## half_w, `lift` m up, ACROSS_PTS points; UV.x m along it), following the anchor as it moves and widens: the bright lip
## along the deck under the Kick's crest (ToonFx "flame_lip").
## The anime pass (2026-10-16): lay_path(pts, w, w_tail) draws it along points its owner lays (the head first) and lays again
## every frame: the water's ribbon drawn from a grate to the hands (BendCharge). UV.x metres along from the head, UV2.y the
## share along (0 head .. 1 tail; the follow strands give it too, by age), the head narrowed to a point over `tip` of its
## length; its coils wind round the path by the metre and turn with time.

const MAX_PTS := 14
const STEP_M := 0.14
const ACROSS_PTS := 9

var target: Node3D
var life := 0.14
var width := 0.2
var tail_w := 0.15
var main_mat: Material
var coils := 0
var coil_r := 0.3
var coil_w := 0.04
var coil_spin := 18.0
var coil_mat: Material
var done := true
## Laid across an anchor (lay_across): the anchor, its half width (local m) and the line's height over it.
var across_anchor: Node3D
var across_hw := 1.0
var lift := 0.03

var _pts := PackedVector3Array()
var _ts := PackedFloat32Array()
## Laid along a path (lay_path): its points (the head first), half widths (head, tail), the head's point share.
var _path := PackedVector3Array()
## Laid along a path: how much of it shows (1 whole .. 0 torn away), carried in the strip's vertex colour.
var fade := 1.0
var _path_w := Vector2(0.15, 0.1)
var _path_tip := 0.12
var _t := 0.0
var _im := ImmediateMesh.new()


func _init() -> void:
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 3.0


## Follow `t` afresh (no old path).
func follow(t: Node3D) -> void:
	target = t
	_path = PackedVector3Array()
	_pts.clear()
	_ts.clear()
	_im.clear_surfaces()
	done = false
	visible = true
	set_process(true)


## A short path laid at once from `a` to `b` (the warm-up: its strips drawn on the first frame, their shaders compiled).
func prime(a: Vector3, b: Vector3) -> void:
	_pts = PackedVector3Array([a, b])
	_ts = PackedFloat32Array([_t, _t])


func stop() -> void:
	target = null
	across_anchor = null
	if not _path.is_empty():
		_path = PackedVector3Array()
		_im.clear_surfaces()
		done = true
		visible = false
		set_process(false)


## Drawn along `pts` (world, the head first) now, and kept until the next lay_path or stop(): its owner lays it again each
## frame. `w` its half width (m) along its body, `w_tail` at its tail, the head narrowed to a point over `tip` of its length.
func lay_path(pts: PackedVector3Array, w: float, w_tail: float, tip := 0.12) -> void:
	_path = pts
	_path_w = Vector2(w, w_tail)
	_path_tip = tip
	target = null
	across_anchor = null
	done = false
	visible = true
	set_process(true)
	_draw_path()


## Drawn as one line across `anchor` (see the header) until stop() or the anchor goes.
func lay_across(anchor: Node3D, half_w: float, p_lift := 0.03) -> void:
	across_anchor = anchor
	across_hw = half_w
	lift = p_lift
	target = null
	done = false
	visible = true
	set_process(true)


func _ready() -> void:
	global_transform = Transform3D.IDENTITY


func _process(dt: float) -> void:
	_t += dt
	if not _path.is_empty():
		return                                 # (laid by its owner each frame: lay_path draws it)
	if across_anchor != null:
		if not is_instance_valid(across_anchor) or not across_anchor.is_inside_tree():
			across_anchor = null
			_im.clear_surfaces()
			done = true
			visible = false
			set_process(false)
			return
		_across()
		return
	if target != null and not is_instance_valid(target):
		target = null
	if target != null:
		var p := target.global_position
		if _pts.size() >= 2 and _pts[0].distance_to(_pts[1]) < STEP_M:
			_pts[0] = p
		else:
			_pts.insert(0, p)
			_ts.insert(0, _t)
			if _pts.size() > MAX_PTS:
				_pts.resize(MAX_PTS)
				_ts.resize(MAX_PTS)
		if _pts.size() == 1:
			_pts.insert(0, p)
			_ts.insert(0, _t)
		_ts[0] = _t
	# what has aged out (the head too, once let go)
	while _pts.size() > 0 and _t - _ts[_pts.size() - 1] > life:
		_pts.resize(_pts.size() - 1)
		_ts.resize(_ts.size() - 1)
	_im.clear_surfaces()
	if _pts.size() < 2:
		if target == null:
			done = true
			visible = false
			set_process(false)
		return
	if main_mat != null and width > 0.0:
		_strand(main_mat, width, tail_w, 0.0, -1)
	for k in coils:
		_strand(coil_mat if coil_mat != null else main_mat, coil_w, 0.3, coil_r, k)


func _strand(m: Material, w: float, tw: float, off: float, k: int) -> void:
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, m)
	var n := _pts.size()
	for i in n:
		var p := _pts[i]
		var along := (_pts[maxi(i - 1, 0)] - _pts[mini(i + 1, n - 1)])
		if along.length_squared() < 1e-8:
			along = Vector3.FORWARD
		along = along.normalized()
		var u := clampf((_t - _ts[i]) / life, 0.0, 1.0)
		if k >= 0:
			var side := along.cross(Vector3.UP)
			side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
			var up := side.cross(along)
			var ph := _ts[i] * coil_spin + TAU * k / maxf(coils, 1)
			p += (side * cos(ph) + up * sin(ph)) * off * (1.0 - 0.4 * u)
		var hw := w * lerpf(1.0, tw, u)
		for a in 2:
			_im.surface_set_normal(along)
			_im.surface_set_uv(Vector2(u, float(a)))
			_im.surface_set_uv2(Vector2(hw, u))
			_im.surface_add_vertex(p)
	_im.surface_end()


func _draw_path() -> void:
	_im.clear_surfaces()
	var n := _path.size()
	if main_mat == null or n < 2:
		return
	var dist := PackedFloat32Array()
	dist.resize(n)
	var total := 0.0
	for i in range(1, n):
		total += _path[i].distance_to(_path[i - 1])
		dist[i] = total
	if total < 1e-4:
		return
	_path_strand(main_mat, 0.0, -1, dist, total)
	for k in coils:
		_path_strand(coil_mat if coil_mat != null else main_mat, coil_r, k, dist, total)


## One strand along the path: the main one (`k` -1) at the path's widths, or coil `k` winding `off` m round it.
func _path_strand(m: Material, off: float, k: int, dist: PackedFloat32Array, total: float) -> void:
	var n := _path.size()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, m)
	for i in n:
		var p := _path[i]
		var along := _path[maxi(i - 1, 0)] - _path[mini(i + 1, n - 1)]
		if along.length_squared() < 1e-8:
			along = Vector3.FORWARD
		along = along.normalized()
		var u := dist[i] / total
		var hw := lerpf(_path_w.x, _path_w.y, u)
		if _path_tip > 0.0 and u < _path_tip:
			hw *= sqrt(u / _path_tip)                # (the head to a point)
		if k >= 0:
			var side := along.cross(Vector3.UP)
			side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
			var up := side.cross(along)
			var ph := dist[i] * 9.0 + _t * coil_spin + TAU * k / maxf(coils, 1)
			p += (side * cos(ph) + up * sin(ph)) * off
			hw = coil_w * (0.4 + 0.6 * sqrt(minf(u / maxf(_path_tip, 0.01), 1.0)))
		for a in 2:
			_im.surface_set_normal(along)
			_im.surface_set_color(Color(fade, fade, fade, 1.0))
			_im.surface_set_uv(Vector2(dist[i], float(a)))
			_im.surface_set_uv2(Vector2(hw, u))
			_im.surface_add_vertex(p)
	_im.surface_end()


func _across() -> void:
	_im.clear_surfaces()
	if main_mat == null:
		return
	var xf := across_anchor.global_transform
	var n := ACROSS_PTS
	var a := xf * Vector3(-across_hw, lift, 0.0)
	var b := xf * Vector3(across_hw, lift, 0.0)
	var along := (b - a)
	var l := along.length()
	if l < 1e-4:
		return
	along /= l
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, main_mat)
	for i in n:
		var u := float(i) / float(n - 1)
		var p := a.lerp(b, u)
		var hw := width * (0.55 + 0.45 * sin(u * PI))
		for k in 2:
			_im.surface_set_normal(along)
			_im.surface_set_uv(Vector2(u * l, float(k)))
			_im.surface_set_uv2(Vector2(hw, 1.0))
			_im.surface_add_vertex(p)
	_im.surface_end()
