class_name FissureFx
extends Node3D
## Earth's Fissure on the deck (the owner, 2026-10-10: "make the 2 shove skill like the a fissure type attack like the kick in
## fire where its a on the ground fire line"): the look of a floor wave of kind "stone" (BendBolt's floor_wave; fire's is
## BendLooks.floor_wave_body's flame tongues). At its crest, jagged spikes of stone jostle up across its width; every STEP_M of
## its way a row of spikes bursts up where it passed and sinks back; chips and dust along it. Looks only: the hit, the jump
## over it and the grow are the wave's own (BendBolt). Our own meshes (FormModels.spike_mesh), no particles from elsewhere.
##   BendLooks.fissure_body(bolt, width, height)    made by BendBolt for a stone floor wave; set_width(w) as it widens
## Earth in the show's cel style (2026-10-16; the owner: "as close to Anime Style Avatar: The Last Airbender as possible"): the
## stone Fissure is a crack racing along the deck (a jagged dark line with a pale lip, forks off it, CrackTrail: it stays, fading,
## 2 s after the wave is gone), the crest of cel spikes (a dark drawn line round each), and behind the crest, every STEP_M, two
## slabs of the deck heaved up on either side of the crack, tilting on their outer edges (TILT_DEG), hanging a beat and settling
## back (SLAB_*), dust and chips with them. The mud Fissure (a guard's fusion) is as it was.

const STEP_M := 0.9
const CREST_N := 5
const ROW_N := 3
const RISE_S := 0.07
const HOLD_S := 0.12
const SINK_S := 0.55
## The stone Fissure's slabs: how far out from the crack (a share of the width), how far they tilt (deg), up and back times (s),
## the hold between, and how many ride the pool at most.
const SLAB_REACH := Vector2(0.22, 0.42)
const TILT_DEG := 38.0
const TILT_UP_S := 0.12
const TILT_HOLD_S := 0.28
const TILT_BACK_S := 0.5
const SLAB_POOL := 24
## The crack's width (m), the length of the forks off it and how often one forks, the time it stays after the wave is gone (s).
const CRACK_W := 0.7
const FORK_M := Vector2(0.7, 1.3)
const CRACK_LIFE_S := 2.0
## A mud fissure's end (spike_burst): this many spikes, the middle ones tallest, held up this long.
const END_N := 7
const END_HOLD_S := 0.35

var width := 2.4
var height := 0.9
var matter := "stone"
## "mud": a wave of mud (where earth and water met in a guard; the owner, 2026-10-12: "either mud spear or a mud wave"): its
## spikes squat lumps of wet mud, splashes of water and mud where its rows burst up. Set before it enters the tree.
var look := "stone"
## The crest drawn with our mud meshes (look "mud": squat lumps and clods) rather than spikes made squat.
var _mud_meshes := false
var _crest: Array[MeshInstance3D] = []
var _meshes: Array[Mesh] = []
var _last := Vector3.INF
var _rng := RandomNumberGenerator.new()
var _t := 0.0
## The stone look's crack and the slabs it heaves (cel: not mud).
var _trail: CrackTrail
## Free slab holders, shared (a slab is taken for its heave and given back).
static var _slabs: Array = []


## The wave's width now (m): the crest laid across it, the rows left behind as wide.
func set_width(w: float) -> void:
	width = w
	_lay_crest()


func _ready() -> void:
	_rng.randomize()
	if look == "mud" and BendLooks.mud_mesh("mud_lump") != null:
		# (our mud lump and clods: tools/fx/blender/mud_meshes.py)
		for nm: String in ["mud_lump", "mud_clod_a", "mud_lump", "mud_clod_b", "mud_clod_c"]:
			_meshes.append(BendLooks.mud_mesh(nm))
		_mud_meshes = true
	else:
		for i in CREST_N:
			_meshes.append(ToonFx.spike_cel_mesh(0.15 + 0.03 * float(i % 3), 0.55 + 0.16 * float(i % 2), 31 + i * 11 % 5, 0.0))
	for i in CREST_N:
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[i]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mud(mi)
		add_child(mi)
		if look != "mud":
			mi.material_override = ToonFx.mat("rock")
			BendLooks.outline(mi, mi.mesh)
		_crest.append(mi)
	if look != "mud" and BendLooks.live() and is_inside_tree():
		_trail = CrackTrail.new()
		_trail.width = CRACK_W
		_trail.life = CRACK_LIFE_S
		get_tree().current_scene.add_child(_trail)
	_lay_crest()
	var dust := BendLooks.emitter(self, "mud" if look == "mud" else "dust", Vector3(maxf(width * 0.5, 0.5), 0.1, 0.4), 28, 0.7,
			0.9, 0.45)
	if dust != null:
		dust.position = Vector3(0.0, 0.15, 0.3)


## A mud wave's lump (look "mud"): squat and wide, in mud's wet look.
func _mud(mi: MeshInstance3D) -> void:
	if look != "mud":
		return
	mi.material_override = ToonFx.mat("mud")
	mi.set_meta(&"squat", true)


func _lay_crest() -> void:
	for i in _crest.size():
		var x := lerpf(-width * 0.45, width * 0.45, float(i) / float(maxi(_crest.size() - 1, 1)))
		_crest[i].position = Vector3(x, -0.05, 0.0)


func _process(dt: float) -> void:
	_t += dt
	# (the ground breaking at the crest: its spikes jostle up and down and lean)
	var wide := (0.5 if _mud_meshes else 1.5) if look == "mud" else 1.0
	var tall := (0.75 if _mud_meshes else 0.55) if look == "mud" else 1.0
	for i in _crest.size():
		var s := 0.75 + 0.35 * sin(_t * 23.0 + float(i) * 1.7)
		_crest[i].scale = Vector3(wide, s * tall, wide)
		_crest[i].rotation = Vector3(0.25 * sin(_t * 17.0 + float(i)), 0.0, 0.18 * sin(_t * 13.0 + float(i) * 2.1))
	var p := global_position
	if _trail != null and is_instance_valid(_trail):
		_trail.add(p)
	if _last == Vector3.INF:
		_last = p
	if p.distance_to(_last) >= STEP_M:
		_last = p
		_row(p)


## The wave is over: its crack is let go to fade where it lies, and a last heave of rubble where it stopped.
func _exit_tree() -> void:
	if _trail != null and is_instance_valid(_trail):
		_trail.release()
		if look != "mud" and _t > 0.25:
			_rubble(global_position)


## The stone Fissure's end: a few chunks of the deck thrown up and settling, dust (the rubble it leaves, looks only).
func _rubble(at: Vector3) -> void:
	var pool := ToonFxPool.of(_trail.get_parent() if _trail != null and is_instance_valid(_trail) else null)
	if pool == null:
		return
	pool.shoot("chunk", at + Vector3.UP * 0.1, 10, Vector3.UP, 55.0, Vector2(2.0, 4.5), Vector2(0.08, 0.16), 0.9,
			Vector3(0, -14.0, 0), 0.0, {"r": 0.4, "ang": 400.0})
	pool.shoot("puff_dust", at + Vector3.UP * 0.1, 7, Vector3.UP, 80.0, Vector2(0.8, 2.0), Vector2(0.16, 0.34), 0.7,
			Vector3(0, 0.4, 0), 3.0, {"r": 0.4, "flat": 0.9, "radial": 1.2})


## A row of spikes left where the crest passed: up in RISE_S, held HOLD_S, back down over SINK_S, then gone (looks only).
func _row(at: Vector3) -> void:
	var scn := get_tree().current_scene if is_inside_tree() else null
	if scn == null or _meshes.is_empty():
		return
	if look != "mud":
		_heave(at, scn)
		return
	var side := global_basis.x.normalized()
	var wide := (0.42 if _mud_meshes else 1.5) if look == "mud" else 1.0
	var tall := (0.6 if _mud_meshes else 0.55) if look == "mud" else 1.0
	for i in ROW_N:
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[_rng.randi() % _meshes.size()]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mud(mi)
		scn.add_child(mi)
		mi.global_position = at + side * _rng.randf_range(-width * 0.4, width * 0.4) + Vector3.DOWN * 0.05
		mi.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-PI, PI), _rng.randf_range(-0.3, 0.3))
		mi.scale = Vector3(wide, 0.05, wide)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(wide, _rng.randf_range(0.6, 1.0) * tall, wide), RISE_S)
		tw.tween_interval(HOLD_S)
		tw.tween_property(mi, "scale", Vector3(wide, 0.02, wide), SINK_S)
		tw.tween_callback(mi.queue_free)
	if look == "mud":
		BendLooks.burst(at + Vector3.UP * 0.1, "mud", 6, Vector3.UP, 70.0, 2.5, 0.2)
	else:
		GatherFx.stone_chips(scn, at, Vector3.UP, 4)


## The stone look's row at `at`: two slabs of the deck heaved up on either side of the crack, tilting on their outer edges, a
## fork off the crack, dust and chips where they rise.
func _heave(at: Vector3, scn: Node) -> void:
	var fwd := -global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized() if Vector3(fwd.x, 0.0, fwd.z).length_squared() > 1e-6 else Vector3.FORWARD
	var side := Vector3.UP.cross(fwd).normalized()
	var pool := ToonFxPool.of(scn)
	for sgn in [-1.0, 1.0]:
		var out := side * float(sgn)
		var reach := width * _rng.randf_range(SLAB_REACH.x, SLAB_REACH.y)
		var base := at + out * reach + fwd * _rng.randf_range(-0.2, 0.2) + Vector3.DOWN * 0.02
		_slab_up(scn, base, out, fwd, _rng.randf_range(0.8, 1.15))
		if pool != null:
			pool.shoot("puff_dust", base + Vector3.UP * 0.1, 3, Vector3.UP, 75.0, Vector2(0.6, 1.6), Vector2(0.14, 0.28), 0.6,
					Vector3(0, 0.4, 0), 3.0, {"r": 0.2, "flat": 0.9, "radial": 0.8})
			pool.shoot("chunk", base + Vector3.UP * 0.15, 3, Vector3.UP, 45.0, Vector2(1.8, 3.6), Vector2(0.06, 0.12), 0.75,
					Vector3(0, -14.0, 0), 0.0, {"r": 0.15, "ang": 400.0})
	if _trail != null and is_instance_valid(_trail):
		var a := _rng.randf_range(0.5, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var dir := fwd.rotated(Vector3.UP, a)
		_trail.fork(at, at + dir * _rng.randf_range(FORK_M.x, FORK_M.y))


## A slab (a pooled holder) laid on the deck at `at`, its outer edge the hinge, heaved up by TILT_DEG over TILT_UP_S toward the
## crack side (`out` points away from the crack, `fwd` along the wave), held, then settled back and given back to the pool.
func _slab_up(scn: Node, at: Vector3, out: Vector3, fwd: Vector3, size: float) -> void:
	var h := _slab_take(scn)
	h.global_position = at
	var base := Basis(out, Vector3.UP, out.cross(Vector3.UP)).orthonormalized()
	h.basis = base
	h.scale = Vector3.ONE * size
	h.visible = true
	var rock := h.get_child(0) as Node3D
	rock.position = Vector3(-0.3, 0.0, 0.0)                 # (the plate lies from the hinge back toward the crack)
	var axis := fwd
	var ang := deg_to_rad(TILT_DEG)
	if (Basis(axis, ang) * (-out)).y < 0.0:
		ang = -ang                                            # (the crack side up)
	var tw := h.create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(h):
			h.basis = (Basis(axis, ang * k) * base).scaled(Vector3.ONE * size), 0.0, 1.0, TILT_UP_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(TILT_HOLD_S)
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(h):
			h.basis = (Basis(axis, ang * k) * base).scaled(Vector3.ONE * size), 1.0, 0.0, TILT_BACK_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: _slab_give(h))


static func _slab_take(scn: Node) -> Node3D:
	while not _slabs.is_empty():
		var h: Node3D = _slabs.pop_back()
		if is_instance_valid(h) and h.is_inside_tree():
			return h
	var holder := Node3D.new()
	holder.name = "FissureSlab"
	holder.top_level = true
	var mi := BendLooks.cel_rock(holder, ToonFx.slab_mesh(ToonFx.vis_rng.randi() % 4))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	scn.add_child(holder)
	return holder


static func _slab_give(h: Node3D) -> void:
	if not is_instance_valid(h):
		return
	h.visible = false
	if _slabs.size() < SLAB_POOL:
		_slabs.append(h)
	else:
		h.queue_free()


## The spikes a mud fissure ends in (the owner, 2026-10-12, of earth's wave of mud: "make it spikes at the end then", "mude
## spikes"; BendBolt's end): END_N spikes of mud (our mud spear, BendLooks.mud_mesh, stood up in ToonFx "mud"; stone spikes
## made squat-free where the mesh is missing) burst up out of the deck at `at` across `width` and a little on along `dir`,
## leaning out from the middle, the middle first and tallest; up in RISE_S, held END_HOLD_S, back down over SINK_S. Mud thrown
## up, earth's crack. Looks only (no hit of their own).
static func spike_burst(from: Node, at: Vector3, dir: Vector3, width := 2.4) -> void:
	if from == null or not from.is_inside_tree() or not BendLooks.live():
		return
	var scn := from.get_tree().current_scene
	var fwd := Vector3(dir.x, 0.0, dir.z)
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	var side := Vector3.UP.cross(fwd).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(at * 10.0))
	var spear := BendLooks.mud_mesh("mud_spear")
	for i in END_N:
		var u := float(i) / float(END_N - 1) * 2.0 - 1.0
		var big := 1.0 - 0.4 * absf(u)
		# (each spike under a holder whose +Y is the spike's way up: the holder's height scaled for the rise and the sink)
		var holder := Node3D.new()
		scn.add_child(holder)
		holder.global_position = at + side * u * width * 0.45 + fwd * rng.randf_range(0.0, 0.8) + Vector3.DOWN * 0.08
		holder.basis = Basis(fwd, -u * 0.4) * Basis(side, rng.randf_range(0.12, 0.38)) * Basis(Vector3.UP, rng.randf_range(-PI, PI))
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var tall := 0.8 + 0.8 * big
		if spear != null:
			mi.mesh = spear
			mi.material_override = ToonFx.mat("mud")
			FxParams.put(mi, &"seed", rng.randf() * 5.0)
			mi.rotation.x = PI / 2.0                   # (the spear's point, -Z, up; the mesh about 1.1 m long, 0.4 m thick)
			var w := 0.8 + 0.4 * big
			mi.scale = Vector3(w, w, tall / 1.1)
			mi.position = Vector3.UP * tall * 0.5
		else:
			mi.mesh = FormModels.spike_mesh(0.14 + 0.06 * big, tall, 101 + i * 13, 0.0, "stone")
			mi.material_override = ToonFx.mat("mud")
		holder.add_child(mi)
		holder.scale = Vector3(1.0, 0.05, 1.0)
		var tw := holder.create_tween()
		tw.tween_interval(0.05 * absf(u))
		tw.tween_property(holder, "scale", Vector3.ONE, RISE_S * 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(END_HOLD_S)
		tw.tween_property(holder, "scale", Vector3(1.0, 0.02, 1.0), SINK_S)
		tw.tween_callback(holder.queue_free)
	BendLooks.burst(at + Vector3.UP * 0.15, "mud", 20, Vector3.UP, 100.0, 3.5, 0.26, false)
	BendSounds.play(&"earth_cast_crack", at, 2.0)


## A crack that grows as the wave goes (the stone look): its centre line's points added as the wave moves, forks off it, drawn as
## strips of toon_crack's shader (UV.x 0..1 along, UV2.x the metres, UV.y across); rebuilt as it grows, left to fade over `life`
## s after release(), then freed.
class CrackTrail:
	extends MeshInstance3D

	const STEP_M := 0.32
	const JAG_M := 0.07
	var width := 0.7
	var life := 2.0
	var _pts := PackedVector3Array()
	var _forks: Array = []
	var _dirty := false
	var _age := -1.0
	var _im := ImmediateMesh.new()

	func _init() -> void:
		top_level = true
		mesh = _im
		material_override = ToonFx.mat("crack")
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extra_cull_margin = 8.0

	func _ready() -> void:
		global_transform = Transform3D.IDENTITY
		FxParams.put(self, &"reveal", 1.0)
		FxParams.put(self, &"t", 0.0)
		FxParams.put(self, &"seed", ToonFx.vis_rng.randf() * 10.0)

	## A point of the line (at the deck): taken when it is STEP_M from the last, a little pushed aside.
	func add(p: Vector3) -> void:
		if _pts.size() >= 1 and p.distance_to(_pts[_pts.size() - 1]) < STEP_M:
			return
		var q := p
		if _pts.size() >= 1:
			var d := (p - _pts[_pts.size() - 1])
			var side := Vector3(-d.z, 0.0, d.x).normalized()
			q += side * ToonFx.vis_rng.randf_range(-JAG_M, JAG_M)
		_pts.append(q)
		_dirty = true

	## A fork off the crack from `a` to `b` (a jagged line of three points).
	func fork(a: Vector3, b: Vector3) -> void:
		if _forks.size() >= 24:
			_forks.pop_front()
		_forks.append(BendLooks.crack_line(a, b, 0.4, 0.06))
		_dirty = true

	## The wave is over: it fades where it lies.
	func release() -> void:
		if _age < 0.0:
			_age = 0.0

	func _process(dt: float) -> void:
		if _dirty:
			_dirty = false
			_build()
		if _age >= 0.0:
			_age += dt
			if _age >= life:
				queue_free()
				return
			FxParams.put(self, &"t", clampf(_age / life, 0.0, 1.0))

	func _build() -> void:
		_im.clear_surfaces()
		if _pts.size() >= 2:
			_strip(_pts, width)
		for f: PackedVector3Array in _forks:
			if f.size() >= 2:
				_strip(f, width * 0.6)

	func _strip(pts: PackedVector3Array, w: float) -> void:
		var total := 0.0
		for i in range(1, pts.size()):
			total += pts[i].distance_to(pts[i - 1])
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, ToonFx.mat("crack"))
		var run := 0.0
		for i in pts.size():
			if i > 0:
				run += pts[i].distance_to(pts[i - 1])
			var a := pts[maxi(i - 1, 0)]
			var b := pts[mini(i + 1, pts.size() - 1)]
			var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
			along = along.normalized() if along.length_squared() > 1e-8 else Vector3.RIGHT
			var side := Vector3(-along.z, 0.0, along.x) * w * 0.5
			for k in 2:
				_im.surface_set_uv(Vector2(run / maxf(total, 1e-3), float(k)))
				_im.surface_set_uv2(Vector2(run + float(pts.size()) * 0.13, 0.0))
				_im.surface_add_vertex(pts[i] + side * (1.0 if k == 1 else -1.0) + Vector3.UP * 0.035)
		_im.surface_end()
