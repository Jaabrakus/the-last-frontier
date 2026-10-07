class_name ThuyVanWater
extends Node3D
## A Thủy Vân region's water as it looks (R1: data/world/maps/r1/water.json, T3's WaterNetwork data; the region block's
## "water"), drawn with shaders/thuyvan/tv_river.gdshader and PAINT's falls (ThuyVanCards):
##   channels  a ribbon along each channel's nodes (every ~8 m: x, z, half width, level), WATER_PAD m past its banks so
##             the ground cuts its edge; broken where the level drops in a few metres (a fall: cards there instead).
##             The frontier river's mesh contract: UV2 = the flow's direction, COLOR.r = rapids (none in R1's data),
##             COLOR.g = white water by hand (below the falls). The main channel's material takes the still reach
##             (still_band from WorldRiver, set_still_band) as RiverWater does today.
##   pounds    each pound's polygon flat at its level (the lock chamber and basin at their resting level; the paddy steps,
##             glassy and shallow over their mud)
##   falls     the channels' own (the torrent's, water.json "falls": a step of `drop` m at x) as card falls 2.5x the
##             stream's width (style guide 4: drawn 2-3x real), and the vista's wall falls (vista_spec D9: F1 the paddy
##             spill and F2 off the C1 gorge's west wall) hung down the wall from their lip to the river
## Only the look: WorldRiver (the main channel's nodes in region.json) keeps the player's river functions; the full port to
## WaterNetwork is plan M1.
##
##   var w := ThuyVanWater.new(); add_child(w); w.build("res://data/world/maps/r1/water.json")

const Cards := preload("res://scripts/thuyvan/world/thuyvan_cards.gd")
const SHADER := "res://shaders/thuyvan/tv_river.gdshader"
const WATER := "res://assets/thuyvan/paint/water/"
## Metres of ribbon past the banks (cut by the ground).
const WATER_PAD := 7.0
const ACROSS := 9
## A level change bigger than this between two nodes is a fall: the ribbon breaks there.
const FALL_STEP := 1.5
## The torrent's falls drawn this many times the stream's width.
const FALL_WIDTH_X := 2.5
## Vista D9: wall falls {lip (x, y, z), width (m), the side the wall faces (+1 east)}.
const WALL_FALLS := [
	{"id": "F1", "lip": Vector3(752.0, 205.0, -1150.0), "width": 11.0, "face": 1.0},
	{"id": "F2", "lip": Vector3(750.0, 203.0, -1330.0), "width": 15.0, "face": 1.0},
]

var data := {}
var river_mat: ShaderMaterial
var side_mat: ShaderMaterial
var pound_mat: ShaderMaterial
var fall_mats := {}
var rng := RandomNumberGenerator.new()


func build(path: String) -> void:
	rng.seed = 2207
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not d is Dictionary:
		push_warning("ThuyVanWater: no water at %s" % path)
		return
	data = d
	river_mat = _river_material(1.0)
	side_mat = _river_material(1.0)
	pound_mat = _river_material(0.0)
	pound_mat.set_shader_parameter("alpha_by_depth", Vector2(0.55, 0.85))
	var fields: Array = data.get("node_fields", ["s", "x", "z", "half_width", "level", "bed_depth", "speed"])
	for c: Dictionary in data.get("channels", []):
		var rows := _rows(c, fields)
		_ribbon(c, rows, river_mat if int(c.get("rank", 0)) == 0 else side_mat)
		for f: Dictionary in c.get("falls", []):
			_channel_fall(rows, f)
	for p: Dictionary in data.get("pounds", []):
		_pound(p)
	for f: Dictionary in WALL_FALLS:
		_wall_fall(f)


func _river_material(flow: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	m.set_shader_parameter("ramp", load(WATER + "tv_river_ramp.png"))
	m.set_shader_parameter("flow_tex", load(WATER + "tv_river_flow.png"))
	m.set_shader_parameter("foam_tex", load(WATER + "tv_river_foam.png"))
	m.set_shader_parameter("flow_scale", flow)
	return m


## The main channel's still reach (WorldRiver.still_band(): {z_from, z_to, ease_m, amount}; {} none).
func set_still_band(band: Dictionary) -> void:
	if river_mat == null:
		return
	var v := Vector4.ZERO
	if not band.is_empty():
		v = Vector4(float(band.z_from), float(band.z_to), float(band.ease_m), float(band.amount))
	river_mat.set_shader_parameter("still_band", v)


## The direction's water sky tint (ThuyVanLook's water_sky_tint).
func set_sky_tint(c: Color) -> void:
	for m: ShaderMaterial in [river_mat, side_mat, pound_mat]:
		if m:
			m.set_shader_parameter("sky_tint", c)


## A channel's node rows as dictionaries (s, x, z, hw, level).
func _rows(c: Dictionary, fields: Array) -> Array[Dictionary]:
	var is_ := fields.find("s")
	var ix := fields.find("x")
	var iz := fields.find("z")
	var ih := fields.find("half_width")
	var il := fields.find("level")
	var out: Array[Dictionary] = []
	for r: Array in c.get("nodes", []):
		out.append({"s": float(r[is_]), "x": float(r[ix]), "z": float(r[iz]), "hw": float(r[ih]), "level": float(r[il])})
	return out


## Where along the rows s lies: {p (on the water), dir (flat, downstream), hw, level}.
func _at_s(rows: Array[Dictionary], s: float) -> Dictionary:
	var i := 0
	while i < rows.size() - 2 and float(rows[i + 1].s) < s:
		i += 1
	var a: Dictionary = rows[i]
	var b: Dictionary = rows[i + 1]
	var t := clampf((s - float(a.s)) / maxf(float(b.s) - float(a.s), 1e-4), 0.0, 1.0)
	var dir := Vector3(float(b.x) - float(a.x), 0.0, float(b.z) - float(a.z)).normalized()
	return {"p": Vector3(lerpf(a.x, b.x, t), lerpf(a.level, b.level, t), lerpf(a.z, b.z, t)), "dir": dir,
			"hw": lerpf(a.hw, b.hw, t), "level": lerpf(a.level, b.level, t)}


func _ribbon(c: Dictionary, rows: Array[Dictionary], mat: ShaderMaterial) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var falls: Array = c.get("falls", [])
	for r in rows.size():
		var a: Dictionary = rows[r]
		var b: Dictionary = rows[mini(r + 1, rows.size() - 1)]
		var p: Dictionary = rows[maxi(r - 1, 0)]
		var f := Vector2(float(b.x) - float(p.x), float(b.z) - float(p.z)).normalized()
		var side := Vector3(f.y, 0.0, -f.x)
		# white water below a fall's foot (its first 40 m)
		var white := 0.0
		for fa: Dictionary in falls:
			var past := float(a.s) - float(fa.s_to)
			if past > -2.0 and past < 40.0:
				white = maxf(white, 1.0 - clampf(past / 40.0, 0.0, 1.0))
		var w := float(a.hw) + WATER_PAD
		for k in ACROSS:
			var u := float(k) / float(ACROSS - 1)
			verts.append(Vector3(float(a.x), float(a.level), float(a.z)) + side * lerpf(-w, w, u))
			normals.append(Vector3.UP)
			uv.append(Vector2(u, float(a.s)))
			uv2.append(f)
			colors.append(Color(0.0, white, 0.0))
	for r in rows.size() - 1:
		if absf(float(rows[r + 1].level) - float(rows[r].level)) > FALL_STEP:
			continue
		for k in ACROSS - 1:
			var i := r * ACROSS + k
			idx.append_array([i, i + ACROSS, i + 1, i + 1, i + ACROSS, i + ACROSS + 1])
	var mi := Cards.mesh_instance(self, verts, normals, idx, mat, "Water_" + String(c.id), colors, uv, uv2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pound(p: Dictionary) -> void:
	var poly: Array = p.get("polygon", [])
	if poly.size() < 3:
		return
	var level := float(p.get("level", 0.0))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for q: Array in poly:
		verts.append(Vector3(float(q[0]), level, float(q[1])))
		normals.append(Vector3.UP)
		uv2.append(Vector2(0.0, 1.0))
	for k in range(1, poly.size() - 1):
		idx.append_array([0, k + 1, k])
	var mat := pound_mat if String(p.get("kind", "")) == "paddy" else side_mat
	var mi := Cards.mesh_instance(self, verts, normals, idx, mat, "Pound_" + String(p.id), PackedColorArray(),
			PackedVector2Array(), uv2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A channel's own fall: the step at f.x from its upper level to its lower, facing downstream.
func _channel_fall(rows: Array[Dictionary], f: Dictionary) -> void:
	var top := _at_s(rows, float(f.s_from) - 1.0)
	var bot := _at_s(rows, float(f.s_to) + 1.0)
	var facing: Vector3 = top.dir
	var width := float(top.hw) * 2.0 * FALL_WIDTH_X
	var path := PackedVector3Array()
	var n := 6
	var a: Vector3 = top.p
	var b: Vector3 = bot.p
	for j in n + 1:
		var t := float(j) / n
		# from the pool (bottom) up to the lip, bowing out a little as falling water does
		var y := lerpf(b.y - 0.5, a.y + 0.3, t)
		var out := 2.0 * sin(t * PI) + 1.0
		path.append(Vector3(a.x, y, a.z) + facing * out)
	path.append(a + Vector3.UP * 0.5 - facing * 4.0)
	Cards.fall(self, path, width, facing, rng, fall_mats).name = "Fall_x%d" % int(f.x)


## A wall fall: from its lip down the gorge wall (the ground's first point under each height, going out from the lip) to
## the river, a few metres off the rock.
func _wall_fall(f: Dictionary) -> void:
	var lip: Vector3 = f.lip
	var face := Vector3(float(f.face), 0.0, 0.0)
	var level := WorldRiver.level_at(lip.z) if WorldRiver.has_water() else lip.y - 70.0
	var path := PackedVector3Array()
	var n := 16
	var x := lip.x
	var pts: Array[Vector3] = []
	for j in n + 1:
		var y := lerpf(lip.y - 0.6, level - 0.5, float(j) / n)
		# walk out from the lip until the ground is under y
		while FrontierTerrain.height_at(x, lip.z) > y and absf(x - lip.x) < 120.0:
			x += 0.5 * float(f.face)
		pts.append(Vector3(x + 2.4 * float(f.face), y, lip.z))
	pts.reverse()
	for p in pts:
		path.append(p)
	path.append(Vector3(lip.x - 4.0 * float(f.face), lip.y + 0.4, lip.z))
	Cards.fall(self, path, float(f.width), face, rng, fall_mats).name = "Fall_" + String(f.id)
