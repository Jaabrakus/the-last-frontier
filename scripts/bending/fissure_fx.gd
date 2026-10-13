class_name FissureFx
extends Node3D
## Earth's Fissure on the deck (the owner, 2026-10-10: "make the 2 shove skill like the a fissure type attack like the kick in
## fire where its a on the ground fire line"): the look of a floor wave of kind "stone" (BendBolt's floor_wave; fire's is
## BendLooks.floor_wave_body's flame tongues). At its crest, jagged spikes of stone jostle up across its width; every STEP_M of
## its way a row of spikes bursts up where it passed and sinks back; chips and dust along it. Looks only: the hit, the jump
## over it and the grow are the wave's own (BendBolt). Our own meshes (FormModels.spike_mesh), no particles from elsewhere.
##   BendLooks.fissure_body(bolt, width, height)    made by BendBolt for a stone floor wave; set_width(w) as it widens

const STEP_M := 0.9
const CREST_N := 5
const ROW_N := 3
const RISE_S := 0.07
const HOLD_S := 0.12
const SINK_S := 0.55
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
			_meshes.append(FormModels.spike_mesh(0.13 + 0.03 * float(i % 3), 0.5 + 0.14 * float(i % 2), 31 + i * 11, 0.0, matter))
	for i in CREST_N:
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[i]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mud(mi)
		add_child(mi)
		_crest.append(mi)
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
	if _last == Vector3.INF:
		_last = p
	if p.distance_to(_last) >= STEP_M:
		_last = p
		_row(p)


## A row of spikes left where the crest passed: up in RISE_S, held HOLD_S, back down over SINK_S, then gone (looks only).
func _row(at: Vector3) -> void:
	var scn := get_tree().current_scene if is_inside_tree() else null
	if scn == null or _meshes.is_empty():
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
			mi.set_instance_shader_parameter(&"seed", rng.randf() * 5.0)
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
