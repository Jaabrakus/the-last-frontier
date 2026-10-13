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

var width := 2.4
var height := 0.9
var matter := "stone"
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
	for i in CREST_N:
		_meshes.append(FormModels.spike_mesh(0.13 + 0.03 * float(i % 3), 0.5 + 0.14 * float(i % 2), 31 + i * 11, 0.0, matter))
	for i in CREST_N:
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[i]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_crest.append(mi)
	_lay_crest()
	var dust := BendLooks.emitter(self, "dust", Vector3(maxf(width * 0.5, 0.5), 0.1, 0.4), 28, 0.7, 0.9, 0.45)
	if dust != null:
		dust.position = Vector3(0.0, 0.15, 0.3)


func _lay_crest() -> void:
	for i in _crest.size():
		var x := lerpf(-width * 0.45, width * 0.45, float(i) / float(maxi(_crest.size() - 1, 1)))
		_crest[i].position = Vector3(x, -0.05, 0.0)


func _process(dt: float) -> void:
	_t += dt
	# (the ground breaking at the crest: its spikes jostle up and down and lean)
	for i in _crest.size():
		var s := 0.75 + 0.35 * sin(_t * 23.0 + float(i) * 1.7)
		_crest[i].scale = Vector3(1.0, s, 1.0)
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
	for i in ROW_N:
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[_rng.randi() % _meshes.size()]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scn.add_child(mi)
		mi.global_position = at + side * _rng.randf_range(-width * 0.4, width * 0.4) + Vector3.DOWN * 0.05
		mi.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-PI, PI), _rng.randf_range(-0.3, 0.3))
		mi.scale = Vector3(1.0, 0.05, 1.0)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1.0, _rng.randf_range(0.6, 1.0), 1.0), RISE_S)
		tw.tween_interval(HOLD_S)
		tw.tween_property(mi, "scale", Vector3(1.0, 0.02, 1.0), SINK_S)
		tw.tween_callback(mi.queue_free)
	GatherFx.stone_chips(scn, at, Vector3.UP, 4)
