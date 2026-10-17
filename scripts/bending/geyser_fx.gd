extends Node3D
## The Geyser's look (the owner, 2026-10-12: "like a column of water", "the water geyser needs to be like fissure water plus
## column of water to make it look legit"): the deck breaks at its foot as the Fissure's ground does (FissureFx's stone spikes,
## FormModels.spike_mesh, jostling up through the rumble, a cracked mark, dust), then a solid column of water bursts out of the
## crack along `dir` (up; leaning, for a Geyser thrown right or left; across the deck for one from the water, BendEffects.
## _spout_way: no crack, the water swelling out of the grate or the tank instead), holds and collapses in spray. Our own meshes:
## the column the respawn spout's (RingSpout._cylinder in shaders/ring/ring_curtain.gdshader, its water running up it) round a
## brighter core, a white crown at its tip. Looks only: the throw is BendEffects.spout's, at rise_s.
##   BendLooks.geyser(at, dir, length, radius, rise_s, crack)    loaded by its path (BendLooks.GEYSER_FX), as FissureFx

const SHOOT_S := 0.1
const HOLD_S := 0.45
const SINK_S := 0.4
const SPIKE_N := 5

var foot := Vector3.ZERO
var dir := Vector3.UP
var length := 3.2
var radius := 0.55
var rise_s := 0.35
var crack := true
var _t := 0.0
var _col: MeshInstance3D
var _core: MeshInstance3D
var _crown: MeshInstance3D
var _ribs: Array[ToonRibbon] = []
var _spikes: Array[MeshInstance3D] = []
var _lean: Array[Vector3] = []
var _burst := false
var _fell := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	global_position = foot
	var y := dir.normalized() if dir.length_squared() > 1e-4 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	global_basis = Basis(x, y, x.cross(y).normalized())
	# (the anime pass, 2026-10-16: the column in cel water, a drawn line round it and foam flecks running up it, a paler heart, two
	# ribbons spiralling up it, a torn crown of foam at its top)
	_col = _column(radius, "water_column")
	_core = _column(radius * 0.62, "water_column_core")
	# (round 2: ONE clear white crown at the top, torn spikes standing round the column's head)
	_crown = MeshInstance3D.new()
	_crown.mesh = ToonFx.band_mesh(1.0, 1.7, 1.1)
	_crown.material_override = ToonFx.mat("crown")
	_crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crown)
	FxParams.put(_crown, &"t", 0.3)
	FxParams.put(_crown, &"tint", Color(0.82, 0.94, 1.0))
	FxParams.put(_crown, &"tint2", Color(1.0, 1.0, 1.0))
	FxParams.put(_crown, &"seed", ToonFx.vis_rng.randf() * 10.0)
	for i in 2:
		var rb := ToonRibbon.new()
		rb.main_mat = ToonFx.mat("water_ribbon")
		rb.coils = 0
		add_child(rb)
		_ribs.append(rb)
	if crack:
		# (the deck breaking round the foot: stone spikes in a ring, leaning out, the cracks under them, dust rising)
		for i in SPIKE_N:
			var a := TAU * float(i) / float(SPIKE_N) + _rng.randf_range(-0.25, 0.25)
			var out := Vector3(cos(a), 0.0, sin(a))
			var mi := MeshInstance3D.new()
			mi.mesh = FormModels.spike_mesh(0.12 + 0.05 * float(i % 3), 0.55 + 0.2 * float(i % 2), 41 + i * 13, 0.0, "stone")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.global_position = global_position + out * (radius + 0.25 + _rng.randf_range(0.0, 0.3)) + Vector3.DOWN * 0.05
			mi.global_basis = Basis(out.cross(Vector3.UP).normalized(), _rng.randf_range(0.3, 0.55)) * Basis(Vector3.UP, _rng.randf_range(-PI, PI))
			mi.scale = Vector3(1.0, 0.05, 1.0)
			_spikes.append(mi)
			_lean.append(out)
		BendLooks.mark_at("cracks", global_position, Vector3.UP, radius * 3.2 + 0.6, rise_s + HOLD_S + 1.6)
		var dust := BendLooks.emitter(self, "dust", Vector3(radius + 0.4, 0.1, radius + 0.4), 8, 0.7, 0.9, 0.4)
		if dust != null:
			dust.global_basis = Basis.IDENTITY
	_shape(0.0, 1.0)


## A water column along the node's y (its root at the foot), in ToonFx material `mat`.
func _column(r: float, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ToonFx.column_mesh(r, length)
	mi.material_override = ToonFx.mat(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## The column `h` (0..1) of its length up, `w` its width's scale.
func _shape(h: float, w: float) -> void:
	var hh := maxf(h, 0.001)
	for m: MeshInstance3D in [_col, _core]:
		m.scale = Vector3(w, hh, w)
		m.visible = h > 0.01
	_crown.position = Vector3(0.0, length * h, 0.0)
	_crown.scale = Vector3.ONE * radius * clampf(w, 0.3, 1.6) * 1.55
	_crown.visible = h > 0.04
	_spiral(h, w)


## Two ribbons of water winding up the column from its foot to its top, turning with time (the anime pass).
func _spiral(h: float, w: float) -> void:
	for i in _ribs.size():
		if h < 0.2:
			_ribs[i].stop()
			continue
		var pts := PackedVector3Array()
		var n := 22
		for j in n + 1:
			var f := float(j) / float(n)             # (0 at the head, the top; 1 at the foot)
			var y := length * h * (1.0 - f)
			var a := _t * 5.5 + PI * float(i) + y * 2.4
			var rr := radius * w * 1.1
			pts.append(global_transform * Vector3(cos(a) * rr, y, sin(a) * rr))
		_ribs[i].fade = 1.0
		_ribs[i].lay_path(pts, 0.13, 0.13, 0.06)


func _process(dt: float) -> void:
	_t += dt
	var t := _t
	if t < rise_s:
		# the rumble: the water swelling low at the foot, the spikes working up through the deck
		var k := t / maxf(rise_s, 0.01)
		_shape(0.05 + 0.05 * k + 0.025 * sin(t * 42.0), 0.8 + 0.4 * k)
		for i in _spikes.size():
			_spikes[i].scale = Vector3(1.0, 0.1 + 0.4 * k + 0.08 * sin(t * 31.0 + float(i) * 1.9), 1.0)
		return
	if not _burst:
		_burst = true
		_burst_fx()
	var s := t - rise_s
	if s < SHOOT_S:
		var e := 1.0 - pow(1.0 - s / SHOOT_S, 3.0)
		_shape(e, 1.15 - 0.15 * e)
		for i in _spikes.size():
			_spikes[i].scale = Vector3(1.0, lerpf(0.5, 1.0, e), 1.0)
		return
	s -= SHOOT_S
	if s < HOLD_S:
		_shape(1.0, 1.0 + 0.07 * sin(s * 34.0))
		return
	s -= HOLD_S
	if not _fell:
		_fell = true
		BendLooks.burst(global_position + global_basis.y * 0.2, "water", 26, Vector3.UP, 70.0, 3.5, 0.3)
	if s < SINK_S:
		var k2 := s / SINK_S
		_shape(1.0 - k2, 1.0 + 0.4 * k2)        # (the water falls back, spreading at the foot)
		for i in _spikes.size():
			_spikes[i].scale = Vector3(1.0, lerpf(1.0, 0.02, k2), 1.0)
		return
	queue_free()


## The column bursting out: chips of the deck and spray thrown out round its foot, a splash where it ends.
func _burst_fx() -> void:
	var scn := get_tree().current_scene if is_inside_tree() else null
	if scn != null and crack:
		GatherFx.stone_chips(scn, global_position + Vector3.UP * 0.1, Vector3.UP, 6)
		BendLooks.burst(global_position + Vector3.UP * 0.15, "stone", 4, Vector3.UP, 60.0, 4.0, 0.3)
	BendLooks.burst(global_position + global_basis.y * 0.3, "water", 10, global_basis.y, 45.0, 6.0, 0.35)
	BendLooks.sound("water", "cast", global_position, 0.0)
