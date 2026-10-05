class_name RingDressing
extends Node3D
## The Tidebreak ring dressed as a sports arena (look task C; the owner, 2026-10-05: "the arena and the special effects
## ... more polish"). Drawn only: no colliders, nothing the match reads (RingArena keeps every rule; headless builds
## nothing). Under the ring (local to it), from data/ring/ring.json's numbers:
##   stands     stone piers rising from the stands' back to a lacquered beam, striped awnings over the top tiers on
##              timber poles with a scalloped valance, red paper lanterns hung under each bay, a painted parapet along
##              the front in the two sides' colours (each side's colour on its own half), banners on the piers
##   crowd      RingCrowd: about 900 low-poly fans on the tiers, swaying (the shader), three draws
##   gates      a gatehouse on each end wall: two towers with tile roofs and flags, a voussoired arch over a dark
##              tunnel with its portcullis raised, the side's plaque over it, braziers either side, four tall banners
##              in the side's colours along the wall and a painted frieze at its head
##   scoreboard RingBoard: a tower behind the middle of the far stand (-Z), the sport's name in our own block lettering,
##              the scores, a tile roof, a pennant; bunting strung from it across the arena
##   lights     braziers at the tank's corners and the gates (toon flames, embers, a halo), lamp posts along both
##              walks, lanterns under the awnings, two lamps on the scoreboard and two on the near stand pooling warm
##              light on the deck at night (the lights only at night: set_mood)
##   deck       a brass edge round the deck, the coursed band under it gilded, a painted frieze on the plinth (each half in
##              its side's colour), a gilded edge on its foot
##   water      a deeper colour on the tank's water, foam where it meets the walls and the plinth, the water's light
##              dancing on the stone over it
##   horizon    low wooded hills round the arena far off, and blue ridges past them (the plain no longer runs to the haze)
## Entry (the integrator wires it after wave 2; tools/ring/look_c_shots.gd shows it):
##   RingDressing.build(level, preset := "noon") -> RingDressing    level: a RingLevel (or the RingArena itself)
##   set_mood(name)            "noon", "golden", "night" (RingLook.apply calls it)
##   set_sides(e0, e1)         the two sides' elements ("earth", "water", "fire", "air"): banners, flags, plaques,
##                             friezes and parapet panels follow (the fans keep the colours they were built in)
##   set_score(a, b)           the scoreboard's numbers
##   set_cheer(v)              the stands' mood 0..1 (a roar on a ring-out)
## Cost (tools/ring/look_c_shots.gd, LOOK_C_COST; 1600x900 high, TAA, 2026-10-05, the deck view): +35 draws (64 -> 99),
## shadow draws 136 -> 212 (326 at night: two shadowed deck lamps), ~130k more triangles (the crowd most of it), frame
## 9.8 ms bare -> 10.9 noon / 11.1 golden / 12.5 night; 26 lights at night (2 shadowed), none by day; 8 GPU emitters.

const NAME := "RingDressing"
const GOLD := Color(1.0, 0.74, 0.32)
const CLOTH_SHADER := "res://shaders/ring/ring_cloth.gdshader"
const FLAME_SHADER := "res://shaders/ring/ring_flame.gdshader"
const HALO_SHADER := "res://shaders/ring/ring_halo.gdshader"
const FOAM_SHADER := "res://shaders/ring/ring_foam.gdshader"
const CAUSTIC_SHADER := "res://shaders/ring/ring_caustic.gdshader"
const BAYS := 10
const COLUMN_H := 7.8
const FRONT_Z := 19.35            ## the awnings' front poles (over the third tier)
const FRONT_Y := 6.6              ## the awnings' front edge

## Each element's banner: base cloth, trim, mark, the mark's glyph (ring_cloth.gdshader) and its team colour (the
## parapet, the frieze, the fans' clothes).
const ELEMENTS := {
	"earth": {"base": Color(0.36, 0.24, 0.1), "trim": Color(1.0, 0.74, 0.32), "mark": Color(0.95, 0.84, 0.58), "glyph": 0,
			"team": Color(0.6, 0.42, 0.18)},
	"water": {"base": Color(0.05, 0.2, 0.48), "trim": Color(0.95, 0.78, 0.4), "mark": Color(0.7, 0.9, 1.0), "glyph": 1,
			"team": Color(0.12, 0.34, 0.72)},
	"fire": {"base": Color(0.58, 0.07, 0.04), "trim": Color(1.0, 0.72, 0.28), "mark": Color(1.0, 0.82, 0.4), "glyph": 2,
			"team": Color(0.78, 0.16, 0.06)},
	"air": {"base": Color(0.9, 0.87, 0.78), "trim": Color(0.95, 0.52, 0.14), "mark": Color(0.22, 0.5, 0.8), "glyph": 3,
			"team": Color(0.92, 0.9, 0.82)},
}
## The moods (RingLook's presets): lit lamps, the glow of lamps / letters / coals, the flames, the halos, the water's
## light on the stone, the deck lamps.
const MOODS := {
	"noon": {"lights": false, "lamp": 0.0, "letters": 0.45, "coal": 1.5, "flame": 1.6, "halo": 0.0, "caustic": 0.7,
			"caustic_tint": Color(0.72, 0.95, 1.0), "cheer": 0.25, "tunnel": Color(0.1, 0.08, 0.06)},
	"golden": {"lights": false, "lamp": 0.6, "letters": 0.6, "coal": 2.2, "flame": 2.2, "halo": 0.25, "caustic": 0.5,
			"caustic_tint": Color(1.0, 0.78, 0.48), "cheer": 0.35, "tunnel": Color(0.12, 0.08, 0.05)},
	"night": {"lights": true, "lamp": 4.0, "letters": 1.3, "coal": 4.0, "flame": 3.6, "halo": 0.55, "caustic": 0.16,
			"caustic_tint": Color(1.0, 0.66, 0.36), "cheer": 0.45, "tunnel": Color(0.36, 0.17, 0.07)},
}

var ring: RingArena
var mats := {}
var mood := ""
var side_elements: Array[String] = ["water", "fire"]
var crowd: RingCrowd
var board: RingBoard
var lights: Array[Light3D] = []
var spots: Array[SpotLight3D] = []
var embers: Array[GPUParticles3D] = []

# the numbers (local to the ring)
var y0 := 0.0
var ox := 27.8
var oz := 16.8
var back := 22.2
var tiers := 6
var td := 0.9
var th := 0.5
var xs: Array[float] = []

var _groups := {}                  ## cloth group -> {st: SurfaceTool, mat: ShaderMaterial, shadow: bool}
var _pennants: Array = []          ## [Transform3D, Color]
var _flames: Array = []            ## [Vector3 base, Vector2 size]
var _halos: Array = []             ## [Vector3, Color, size]
var _lamps: Array = []             ## [Vector3, Color, energy, range]
var _flame_mat: ShaderMaterial
var _halo_mat: ShaderMaterial
var _foam_mat: ShaderMaterial
var _caustic_mat: ShaderMaterial


## The ring of `level` dressed (built once; a second call only sets the mood). Null when there is no ring.
static func build(level: Node, preset := "noon") -> RingDressing:
	var r := level as RingArena
	if r == null and level != null:
		r = level.get(&"ring") as RingArena
	if r == null:
		return null
	var d := r.get_node_or_null(NAME) as RingDressing
	if d == null:
		d = RingDressing.new()
		d.name = NAME
		d.ring = r
		r.add_child(d)
		if r.visuals:
			d._build()
	d.set_mood(preset)
	return d


static func find_in(level: Node) -> RingDressing:
	if level == null:
		return null
	var r := level as RingArena
	if r == null:
		r = level.get(&"ring") as RingArena
	return r.get_node_or_null(NAME) as RingDressing if r != null else null


# ---------------------------------------------------------------- the API
func set_mood(name: String) -> void:
	mood = name if MOODS.has(name) else "noon"
	if mats.is_empty():
		return
	var m: Dictionary = MOODS[mood]
	for l in lights:
		l.visible = m.lights
	(mats[&"lamp_red"] as StandardMaterial3D).emission_energy_multiplier = float(m.lamp)
	(mats[&"lamp_warm"] as StandardMaterial3D).emission_energy_multiplier = float(m.lamp)
	(mats[&"glow_gold"] as StandardMaterial3D).emission_energy_multiplier = float(m.letters)
	(mats[&"glow_coal"] as StandardMaterial3D).emission_energy_multiplier = float(m.coal)
	(mats[&"void"] as StandardMaterial3D).albedo_color = m["tunnel"]
	_flame_mat.set_shader_parameter(&"intensity", float(m.flame))
	_halo_mat.set_shader_parameter(&"strength", float(m.halo))
	_caustic_mat.set_shader_parameter(&"strength", float(m.caustic))
	_caustic_mat.set_shader_parameter(&"tint", m.caustic_tint)
	if crowd != null:
		crowd.set_cheer(float(m.cheer), true)


func set_sides(e0: String, e1: String) -> void:
	side_elements = [e0 if ELEMENTS.has(e0) else "water", e1 if ELEMENTS.has(e1) else "fire"]
	if mats.is_empty():
		return
	for s in 2:
		var e: Dictionary = ELEMENTS[side_elements[s]]
		for g: String in ["banner_%d" % s, "flag_%d" % s, "plaque_%d" % s]:
			var mat := _group(g).mat as ShaderMaterial
			mat.set_shader_parameter(&"base", e.base)
			mat.set_shader_parameter(&"trim", e.trim)
			mat.set_shader_parameter(&"mark", e.mark)
			mat.set_shader_parameter(&"glyph", int(e.glyph))
		var fr := _group("frieze_%d" % s).mat as ShaderMaterial
		fr.set_shader_parameter(&"base", (e.team as Color) * 0.7)
		fr.set_shader_parameter(&"trim", GOLD)
		fr.set_shader_parameter(&"mark", e.mark)
		(mats[StringName("team_%d" % s)] as StandardMaterial3D).albedo_color = e.team


func set_score(a: int, b: int) -> void:
	if board != null:
		board.set_score(a, b)


func set_cheer(v: float) -> void:
	if crowd != null:
		crowd.set_cheer(v)


# ---------------------------------------------------------------- the build
func _build() -> void:
	var sd: Dictionary = RingArena.data().get("surround", {})
	y0 = ring.top()
	var t := ring.tank_half()
	var wt := RingArena.num("tank_wall_m", 0.8)
	tiers = int(sd.get("tiers", 6))
	td = float(sd.get("tier_d", 0.9))
	th = float(sd.get("tier_h", 0.5))
	ox = t.x + wt + float(sd.get("plaza_end", 4.0))
	oz = t.y + wt + float(sd.get("plaza_side", 3.0))
	back = oz + td * float(tiers)
	xs.clear()
	for k in BAYS + 1:
		xs.append(-ox + float(k) * 2.0 * ox / float(BAYS))
	_materials()
	var kit := StructureMeshKit.new()
	for sz: float in [-1.0, 1.0]:
		_stand(kit, sz)
	for sg: float in [-1.0, 1.0]:
		_gate(kit, sg)
	_plinth(kit)
	_braziers(kit)
	_posts(kit)
	board = RingBoard.new()
	board.build(self, kit, Vector3(0.0, y0, -(back + 0.2 + 2.35)), 1.0)
	_bunting(kit)
	var mi := MeshInstance3D.new()
	mi.name = "DressingMesh"
	mi.mesh = kit.commit(mats)
	add_child(mi)
	_commit_cloth()
	_commit_pennants()
	_water(t)
	_fire()
	_lights()
	_horizon()
	var skip: Array = []
	for x in xs:
		skip.append(x)
	crowd = RingCrowd.make(self, sd, ox, oz, y0, [(ELEMENTS[side_elements[0]] as Dictionary).team,
			(ELEMENTS[side_elements[1]] as Dictionary).team], skip)
	set_sides(side_elements[0], side_elements[1])


func _materials() -> void:
	for k: StringName in ring.mats:
		mats[k] = ring.mats[k]
	mats[&"paint"] = _std(Color.WHITE, 0.7)
	mats[&"tile"] = _std(Color.WHITE, 0.35)
	var gold := _std(Color.WHITE, 0.3)
	gold.metallic = 0.85
	mats[&"gold"] = gold
	var metal := _std(Color.WHITE, 0.45)
	metal.metallic = 0.7
	mats[&"metal"] = metal
	mats[&"lamp_red"] = _glow(Color(1.0, 0.36, 0.14))
	mats[&"lamp_warm"] = _glow(Color(1.0, 0.68, 0.32))
	var lg := _glow(Color(1.0, 0.72, 0.3))
	lg.metallic = 0.35
	lg.roughness = 0.4
	mats[&"glow_gold"] = lg
	mats[&"glow_coal"] = _glow(Color(1.0, 0.36, 0.08))
	var v := StandardMaterial3D.new()
	v.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	v.vertex_color_use_as_albedo = true
	v.albedo_color = Color(0.04, 0.03, 0.025)
	mats[&"void"] = v
	for s in 2:
		var tm := _std(Color.WHITE, 0.6)
		tm.vertex_color_use_as_albedo = true
		mats[StringName("team_%d" % s)] = tm
	# the cloth groups (one merged mesh each)
	for s in 2:
		_cloth_group("banner_%d" % s, 0, 0.14, 2.8)
		_cloth_group("flag_%d" % s, 0, 0.16, 1.6)
		_cloth_group("plaque_%d" % s, 3, 0.0, 1.0, false)
		_cloth_group("frieze_%d" % s, 4, 0.0, 1.0, false)
	_cloth_group("awning_a", 1, 0.05, 1.0)
	_cloth_group("awning_b", 1, 0.05, 1.0)
	_cloth_group("flag_x", 0, 0.18, 3.2)
	var aa := _group("awning_a").mat as ShaderMaterial
	aa.set_shader_parameter(&"base", Color(0.66, 0.1, 0.07))
	aa.set_shader_parameter(&"trim", Color(0.93, 0.88, 0.76))
	aa.set_shader_parameter(&"mark", GOLD)
	aa.set_shader_parameter(&"stripes", 9.0)
	aa.set_shader_parameter(&"wave_k", 2.0)
	var ab := _group("awning_b").mat as ShaderMaterial
	ab.set_shader_parameter(&"base", Color(0.07, 0.36, 0.4))
	ab.set_shader_parameter(&"trim", Color(0.93, 0.88, 0.76))
	ab.set_shader_parameter(&"mark", GOLD)
	ab.set_shader_parameter(&"stripes", 9.0)
	ab.set_shader_parameter(&"wave_k", 2.0)
	var fx := _group("flag_x").mat as ShaderMaterial
	fx.set_shader_parameter(&"base", Color(0.62, 0.08, 0.06))
	fx.set_shader_parameter(&"trim", GOLD)
	fx.set_shader_parameter(&"mark", Color(0.72, 0.92, 1.0))
	fx.set_shader_parameter(&"glyph", 1)
	var pen := ShaderMaterial.new()
	pen.shader = load(CLOTH_SHADER)
	pen.set_shader_parameter(&"mode", 2)
	pen.set_shader_parameter(&"trim", Color(0.95, 0.92, 0.84))
	pen.set_shader_parameter(&"wave_amp", 0.06)
	pen.set_shader_parameter(&"wave_k", 3.0)
	pen.set_shader_parameter(&"wave_speed", 4.0)
	mats[&"pennant"] = pen


static func _std(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.roughness = rough
	return m


static func _glow(e: Color) -> StandardMaterial3D:
	var m := _std(Color.WHITE, 0.6)
	m.emission_enabled = true
	m.emission = e
	m.emission_energy_multiplier = 0.0
	return m


func _cloth_group(nm: String, mode: int, amp: float, aspect: float, shadow := true) -> void:
	var m := ShaderMaterial.new()
	m.shader = load(CLOTH_SHADER)
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"wave_amp", amp)
	m.set_shader_parameter(&"aspect", aspect)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_groups[nm] = {"st": st, "mat": m, "shadow": shadow, "n": 0}


func _group(nm: String) -> Dictionary:
	return _groups[nm]


## A cloth grid into group `nm`: from `o` along u (UV.x 0..1, times ux) and v (UV.y v0..v1), nx x ny cells, facing n;
## `phase` its own wave phase (0..1).
func cloth(nm: String, o: Vector3, u: Vector3, v: Vector3, nx: int, ny: int, n: Vector3, phase: float, v0 := 0.0,
		v1 := 1.0, ux := 1.0) -> void:
	var g := _group(nm)
	var st: SurfaceTool = g.st
	var base: int = g.n
	for j in ny + 1:
		for i in nx + 1:
			var fu := float(i) / float(nx)
			var fv := float(j) / float(ny)
			st.set_normal(n)
			st.set_uv(Vector2(fu * ux, lerpf(v0, v1, fv)))
			st.set_uv2(Vector2(phase, 0.0))
			st.add_vertex(o + u * fu + v * fv)
	for j in ny:
		for i in nx:
			var a := base + j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 2
			var d := a + nx + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(a)
			st.add_index(c)
			st.add_index(d)
	g.n = base + (nx + 1) * (ny + 1)


func _commit_cloth() -> void:
	var root := Node3D.new()
	root.name = "Cloth"
	add_child(root)
	for nm: String in _groups:
		var g: Dictionary = _groups[nm]
		if int(g.n) == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = nm
		mi.mesh = (g.st as SurfaceTool).commit()
		mi.material_override = g.mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		root.add_child(mi)


## A round plaque with side `s`'s mark, centred on xf (facing its +Z), `size` across.
func plaque(s: int, xf: Transform3D, size: float) -> void:
	var b := xf.basis.orthonormalized()
	cloth("plaque_%d" % s, xf.origin - b.x * size * 0.5 + b.y * size * 0.5, b.x * size, -b.y * size, 1, 1, b.z, 0.0)


## A long swallowtailed pennant flying from a staff, its hoist `length` m long hanging from `top`.
func pennant_staff(top: Vector3, fly: float, hoist: float, nm := "flag_x") -> void:
	var dir := Vector3(0.85, 0.0, 0.3).normalized()
	cloth(nm, top, Vector3.DOWN * hoist, dir * fly, 2, 8, dir.cross(Vector3.DOWN).normalized(), randf())


# ---------------------------------------------------------------- shapes
## A box (centre, size) under `key` turned by `b`; textured keys get the fort's world-projected UVs when not turned.
static func pbox(kit: StructureMeshKit, key: StringName, ctr: Vector3, size: Vector3, col: Color, b := Basis(), textured := false) -> void:
	if textured and b.is_equal_approx(Basis()):
		RingArena.wbox(kit, key, ctr, size, 1.6, col)
		return
	kit.box(key, Transform3D(b, ctr), size, StructureMeshKit.GRAIN_X, 0, 0.0, col, StructureMeshKit.KIND_TEX)


## An n-sided prism (or a frustum, or a cone when r1 is 0) standing on `base`: r0 at the foot, r1 at the top, h high,
## capped on top.
static func prism(kit: StructureMeshKit, key: StringName, base: Vector3, r0: float, r1: float, h: float, n: int, col: Color) -> void:
	var top := base + Vector3(0.0, h, 0.0)
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var out := (d0 + d1).normalized()
		var p0 := base + d0 * r0
		var p1 := base + d1 * r0
		var q1 := top + d1 * r1
		var q0 := top + d0 * r1
		if r1 > 0.001:
			kit.quad(key, p0, p1, q1, q0, Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), col, StructureMeshKit.KIND_TEX,
					0.0, PackedColorArray(), out)
			kit.tri(key, top, q0, q1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col, StructureMeshKit.KIND_TEX, 0.0, Vector3.UP)
		else:
			var nrm := (out * h + Vector3.UP * r0).normalized()
			kit.tri(key, p0, p1, top, Vector2.ZERO, Vector2(1, 0), Vector2(0.5, 1), col, StructureMeshKit.KIND_TEX, 0.0, nrm)


## A hipped roof over a rect (centre `c` of its eaves, size x z) rising `h` to a short ridge; in frame xf.
static func hip_roof(kit: StructureMeshKit, key: StringName, xf: Transform3D, c: Vector3, size: Vector2, h: float, col: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var r := maxf(hx - hz, 0.0)
	var e := [c + Vector3(-hx, 0, -hz), c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), c + Vector3(-hx, 0, hz)]
	var ra := c + Vector3(-r, h, 0.0)
	var rb := c + Vector3(r, h, 0.0)
	var w := func(p: Vector3) -> Vector3: return xf * p
	var up := xf.basis * Vector3.UP
	# the eaves' upturn: a thin lip all round
	kit.quad(key, w.call(e[0]), w.call(e[1]), w.call(rb), w.call(ra), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col,
			StructureMeshKit.KIND_TEX, 0.0, PackedColorArray(), xf.basis * Vector3(0, hz, -h).normalized() + up * 0.0)
	kit.quad(key, w.call(e[2]), w.call(e[3]), w.call(ra), w.call(rb), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col,
			StructureMeshKit.KIND_TEX, 0.0, PackedColorArray(), xf.basis * Vector3(0, hz, h).normalized())
	kit.tri(key, w.call(e[1]), w.call(e[2]), w.call(rb), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col * 0.9, StructureMeshKit.KIND_TEX,
			0.0, xf.basis * Vector3(h, hx - r, 0).normalized())
	kit.tri(key, w.call(e[3]), w.call(e[0]), w.call(ra), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col * 0.9, StructureMeshKit.KIND_TEX,
			0.0, xf.basis * Vector3(-h, hx - r, 0).normalized())
	# a ridge cap and gold ends on it
	var rc := (ra + rb) * 0.5
	pbox(kit, key, xf * rc, Vector3(2.0 * r + 0.3, 0.18, 0.22), col * 0.7, xf.basis)
	for p: Vector3 in [ra, rb]:
		pbox(kit, &"gold", xf * (p + Vector3(0, 0.15, 0)), Vector3(0.18, 0.3, 0.18), GOLD, xf.basis)


## A rope sagging `sag` m from a to b (a thin square tube), and pennants every `step` m along it.
func _string(kit: StructureMeshKit, a: Vector3, b: Vector3, sag: float, step := 0.62, flags := true) -> void:
	var l := a.distance_to(b)
	var n := maxi(ceili(l / 1.2), 2)
	var pt := func(f: float) -> Vector3: return a.lerp(b, f) + Vector3.DOWN * sag * 4.0 * f * (1.0 - f)
	for i in n:
		var p0: Vector3 = pt.call(float(i) / float(n))
		var p1: Vector3 = pt.call(float(i + 1) / float(n))
		var dir := (p1 - p0).normalized()
		var side := dir.cross(Vector3.UP).normalized() * 0.018
		var up := side.cross(dir).normalized() * 0.018
		var col := Color(0.32, 0.26, 0.18)
		kit.quad(&"paint", p0 - side + up, p1 - side + up, p1 + side + up, p0 + side + up, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
				Vector2.ZERO, col, StructureMeshKit.KIND_TEX, 0.0, PackedColorArray(), up)
		kit.quad(&"paint", p0 - side - up, p1 - side - up, p1 - side + up, p0 - side + up, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
				Vector2.ZERO, col, StructureMeshKit.KIND_TEX, 0.0, PackedColorArray(), -side)
		kit.quad(&"paint", p0 + side - up, p1 + side - up, p1 + side + up, p0 + side + up, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
				Vector2.ZERO, col, StructureMeshKit.KIND_TEX, 0.0, PackedColorArray(), side)
	if not flags:
		return
	var palette := [Color(0.78, 0.1, 0.07), Color(0.98, 0.74, 0.22), Color(0.07, 0.42, 0.46), Color(0.94, 0.9, 0.8),
			Color(0.14, 0.3, 0.66), Color(0.9, 0.42, 0.1)]
	var count := floori(l / step)
	for k in range(1, count):
		var f := float(k) / float(count)
		var p: Vector3 = pt.call(f)
		var q: Vector3 = pt.call(minf(f + 0.01, 1.0))
		var x := (q - p).normalized()
		var z := x.cross(Vector3.UP).normalized()
		var yv := z.cross(x).normalized()
		_pennants.append([Transform3D(Basis(x, yv, z), p), palette[(k + _pennants.size()) % palette.size()]])


func _commit_pennants() -> void:
	if _pennants.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# a triangle 0.36 wide at the rope, 0.46 down to its point, in rows (it waves)
	var rows := 3
	for j in rows:
		var y0r := -0.46 * float(j) / float(rows)
		var y1r := -0.46 * float(j + 1) / float(rows)
		var w0 := 0.18 * (1.0 - float(j) / float(rows))
		var w1 := 0.18 * (1.0 - float(j + 1) / float(rows))
		var v0 := float(j) / float(rows)
		var v1 := float(j + 1) / float(rows)
		var pts := [[Vector3(-w0, y0r, 0), Vector2(0, v0)], [Vector3(w0, y0r, 0), Vector2(1, v0)], [Vector3(w1, y1r, 0), Vector2(1, v1)],
				[Vector3(-w1, y1r, 0), Vector2(0, v1)]]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.BACK)
			st.set_uv(pts[idx][1])
			st.add_vertex(pts[idx][0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = st.commit()
	mm.instance_count = _pennants.size()
	for i in _pennants.size():
		mm.set_instance_transform(i, _pennants[i][0])
		mm.set_instance_color(i, _pennants[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Pennants"
	mi.multimesh = mm
	mi.material_override = mats[&"pennant"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The tier's top under a point `d` m back from the stands' front (y0 in front of them).
func _tier_y(d: float) -> float:
	if d < 0.0:
		return y0
	return y0 + th * float(mini(int(d / td), tiers - 1) + 1)


# ---------------------------------------------------------------- the stands
func _stand(kit: StructureMeshKit, sz: float) -> void:
	var stone := Color(0.86, 0.8, 0.72)
	var timber := Color(0.46, 0.12, 0.07)
	var wood := Color(0.3, 0.2, 0.13)
	var bz := sz * (back + 0.1)
	var top_back := th * float(tiers) + 1.4
	var bay := 2.0 * ox / float(BAYS)
	for k in xs.size():
		var x := xs[k]
		var cx := clampf(x, -ox + 0.4, ox - 0.4)
		# the pier: stone to over the stands' back, a moulded course, then a limewashed shaft to a stone capital
		RingArena.wbox(kit, &"ring_walk", Vector3(cx, y0 + top_back * 0.5, bz), Vector3(0.8, top_back, 0.8), 1.6, stone, 8)
		RingArena.wbox(kit, &"ring_walk", Vector3(cx, y0 + top_back + 0.15, bz), Vector3(1.05, 0.3, 1.05), 1.2, stone * 0.92, 8)
		var shaft := COLUMN_H - 0.4 - top_back - 0.3
		pbox(kit, &"paint", Vector3(cx, y0 + top_back + 0.3 + shaft * 0.5, bz), Vector3(0.72, shaft, 0.72), Color(0.9, 0.85, 0.76))
		RingArena.wbox(kit, &"ring_walk", Vector3(cx, y0 + COLUMN_H - 0.2, bz), Vector3(1.15, 0.4, 1.15), 1.2, stone * 0.95, 8)
		pbox(kit, &"gold", Vector3(cx, y0 + COLUMN_H - 0.48, bz), Vector3(0.88, 0.1, 0.88), GOLD)
		# the front pole and its gold cap
		var py := _tier_y(FRONT_Z - oz)
		prism(kit, &"paint", Vector3(cx, py, sz * FRONT_Z), 0.1, 0.08, FRONT_Y - py, 8, timber)
		prism(kit, &"gold", Vector3(cx, FRONT_Y - 0.05, sz * FRONT_Z), 0.11, 0.11, 0.12, 8, GOLD)
		# a banner on the pier's face toward the ring (none on the middle one, the scoreboard's)
		if k > 0 and k < xs.size() - 1 and k != int(BAYS / 2.0):
			var s := 0 if x < 0.0 else 1
			var fz := bz - sz * 0.42
			cloth("banner_%d" % s, Vector3(cx - 0.45, y0 + COLUMN_H - 0.75, fz), Vector3(0.9, 0, 0), Vector3(0, -2.6, 0), 2, 8,
					Vector3(0, 0, -sz), float(k) * 0.31)
	# the beam over the piers and its gold line; the front rail
	pbox(kit, &"paint", Vector3(0.0, y0 + COLUMN_H + 0.2, bz), Vector3(2.0 * ox + 0.6, 0.42, 0.55), timber)
	pbox(kit, &"gold", Vector3(0.0, y0 + COLUMN_H + 0.2, bz - sz * 0.29), Vector3(2.0 * ox + 0.5, 0.07, 0.04), GOLD)
	pbox(kit, &"paint", Vector3(0.0, FRONT_Y + 0.02, sz * FRONT_Z), Vector3(2.0 * ox - 0.4, 0.18, 0.2), timber)
	# the awnings: from the beam down to the front rail, a valance hanging at the front
	for k in BAYS:
		var x0 := xs[k] + (0.4 if k == 0 else 0.0)
		var x1 := xs[k + 1] - (0.4 if k == BAYS - 1 else 0.0)
		var nm := "awning_a" if k % 2 == 0 else "awning_b"
		var a := Vector3(x0, y0 + COLUMN_H + 0.05, sz * (back - 0.2))
		var f := Vector3(x0, FRONT_Y + 0.1, sz * FRONT_Z)
		var slope := f - a
		var nrm := Vector3(x1 - x0, 0, 0).cross(slope).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		cloth(nm, a, Vector3(x1 - x0, 0, 0), slope, 9, 6, nrm, float(k) * 0.17, 0.0, 0.86)
		cloth(nm, f, Vector3(x1 - x0, 0, 0), Vector3(0, -0.6, 0), 18, 1, Vector3(0, 0, -sz), float(k) * 0.17, 0.86, 1.0)
		# a paper lantern under the bay
		var lx := (x0 + x1) * 0.5
		var lz := sz * (FRONT_Z + 0.05)
		prism(kit, &"metal", Vector3(lx, FRONT_Y - 0.95, lz), 0.012, 0.012, 0.9, 4, Color(0.15, 0.12, 0.1))
		_paper_lantern(kit, Vector3(lx, FRONT_Y - 1.55, lz), 0.26, 0.62)
		_halos.append([Vector3(lx, FRONT_Y - 1.24, lz), Color(1.0, 0.42, 0.18), 1.2])
	# the parapet along the front: a framed panel per bay in the half's side colour, a gold lozenge on it
	var pz := sz * (oz - 0.07)
	pbox(kit, &"paint", Vector3(0.0, y0 + 0.5, pz), Vector3(2.0 * ox, 1.0, 0.14), wood)
	pbox(kit, &"paint", Vector3(0.0, y0 + 1.03, pz), Vector3(2.0 * ox, 0.08, 0.3), timber)
	pbox(kit, &"gold", Vector3(0.0, y0 + 1.08, pz), Vector3(2.0 * ox, 0.03, 0.31), GOLD)
	for k in BAYS * 2:
		var x0 := -ox + float(k) * bay * 0.5
		var cxp := x0 + bay * 0.25
		var s := 0 if cxp < 0.0 else 1
		var fz := pz - sz * 0.085
		pbox(kit, &"gold", Vector3(cxp, y0 + 0.52, fz), Vector3(bay * 0.5 - 0.3, 0.64, 0.025), GOLD)
		pbox(kit, StringName("team_%d" % s), Vector3(cxp, y0 + 0.52, fz - sz * 0.012), Vector3(bay * 0.5 - 0.4, 0.54, 0.02), Color.WHITE)
		pbox(kit, &"gold", Vector3(cxp, y0 + 0.52, fz - sz * 0.024), Vector3(0.28, 0.28, 0.02), GOLD, Basis(Vector3.BACK, PI * 0.25))


## A red paper lantern: a round-shouldered drum (lit by night), gold caps.
func _paper_lantern(kit: StructureMeshKit, c: Vector3, r: float, h: float) -> void:
	var red := Color(0.8, 0.14, 0.07)
	prism(kit, &"lamp_red", c + Vector3(0, -h * 0.5, 0), r * 0.7, r, h * 0.22, 10, red)
	prism(kit, &"lamp_red", c + Vector3(0, -h * 0.28, 0), r, r, h * 0.56, 10, red)
	prism(kit, &"lamp_red", c + Vector3(0, h * 0.28, 0), r, r * 0.7, h * 0.22, 10, red)
	prism(kit, &"gold", c + Vector3(0, h * 0.5, 0), r * 0.45, r * 0.45, 0.06, 8, GOLD)
	prism(kit, &"gold", c + Vector3(0, -h * 0.5 - 0.06, 0), r * 0.45, r * 0.45, 0.06, 8, GOLD)
	prism(kit, &"gold", c + Vector3(0, -h * 0.5 - 0.22, 0), 0.03, 0.0, 0.16, 6, GOLD)


# ---------------------------------------------------------------- the gates
func _gate(kit: StructureMeshKit, sg: float) -> void:
	var s := 0 if sg < 0.0 else 1
	var stone := Color(0.8, 0.76, 0.7)
	var tile := Color(0.14, 0.32, 0.34)
	var xc := sg * (ox - 0.8)               # the gatehouse's middle (x), its face toward the ring at ox - 1.6
	var face := sg * (ox - 1.6)
	var into := Basis(Vector3.UP, -sg * PI * 0.5)    # +Z of this frame faces the ring (-sg X)
	var aw := 2.6
	var ys := y0 + 2.8
	for tz: float in [-1.0, 1.0]:
		var zc := tz * (aw + 1.3)
		RingArena.wbox(kit, &"ring_walk", Vector3(xc, y0 + 4.0, zc), Vector3(1.6, 8.0, 2.6), 1.6, stone, 8)
		RingArena.wbox(kit, &"ring_walk", Vector3(xc, y0 + 0.4, zc), Vector3(1.8, 0.8, 2.8), 1.6, stone * 0.88, 8)
		RingArena.wbox(kit, &"ring_walk", Vector3(xc, y0 + 8.1, zc), Vector3(1.95, 0.3, 2.95), 1.2, stone * 0.92, 8)
		hip_roof(kit, &"tile", Transform3D.IDENTITY, Vector3(xc, y0 + 8.25, zc), Vector2(2.3, 3.3).rotated(0.0), 1.7, tile)
		pbox(kit, &"gold", Vector3(face - sg * 0.01, y0 + 7.6, zc), Vector3(0.04, 0.08, 2.62), GOLD)
		plaque(s, Transform3D(into, Vector3(face - sg * 0.02, y0 + 6.2, zc)), 1.1)
		# a staff on the roof with the side's flag
		prism(kit, &"metal", Vector3(xc, y0 + 9.6, zc), 0.035, 0.035, 2.6, 6, Color(0.2, 0.2, 0.2))
		prism(kit, &"gold", Vector3(xc, y0 + 12.2, zc), 0.09, 0.0, 0.25, 6, GOLD)
		var dir := Vector3(0.0, 0.0, tz).normalized() * 0.6 + Vector3(-sg, 0, 0) * 0.8
		dir = dir.normalized()
		cloth("flag_%d" % s, Vector3(xc, y0 + 12.1, zc), Vector3.DOWN * 1.0, dir * 1.7, 2, 6, dir.cross(Vector3.DOWN).normalized(),
				0.3 + tz * 0.2)
	# the arch: voussoirs round a half circle, a gold-faced keystone
	var n := 13
	for i in n:
		var a := PI * (float(i) + 0.5) / float(n)
		var radial := Vector3(0.0, sin(a), cos(a))
		var tangent := Vector3(0.0, -cos(a), sin(a))
		var b := Basis(Vector3.RIGHT, radial, tangent)
		var key := i == int(n / 2.0)
		var depth := 0.62 if key else 0.5
		var c := Vector3(xc, ys, 0.0) + radial * (aw + depth * 0.5)
		pbox(kit, &"ring_walk", c, Vector3(1.66 if key else 1.62, depth, PI * aw / float(n) + 0.12), stone * (1.02 if i % 2 == 0 else 0.94), b, true)
		if key:
			pbox(kit, &"gold", c + Vector3(-sg * 0.84, 0.0, 0.0), Vector3(0.03, depth * 0.8, 0.5), GOLD, b)
	# the wall over the arch (in slices round its curve) and a crenellated parapet
	var top_y := y0 + 7.0
	var slices := 26
	for i in slices:
		var z0 := -aw - 0.0 + 2.0 * aw * float(i) / float(slices)
		var z1 := z0 + 2.0 * aw / float(slices)
		var zm := (z0 + z1) * 0.5
		var r := aw + 0.45
		var bot := ys + sqrt(maxf(r * r - zm * zm, 0.0))
		RingArena.wbox(kit, &"ring_walk", Vector3(xc + sg * 0.05, (bot + top_y) * 0.5, zm), Vector3(1.5, top_y - bot, z1 - z0 + 0.01), 1.6,
				stone * 0.96, 8)
	RingArena.wbox(kit, &"ring_walk", Vector3(xc, top_y + 0.12, 0.0), Vector3(1.8, 0.24, 2.0 * aw + 0.2), 1.2, stone * 0.9, 8)
	for k in 5:
		var zm := -aw + 0.5 + float(k) * (2.0 * aw - 1.0) / 4.0
		RingArena.wbox(kit, &"ring_walk", Vector3(xc, top_y + 0.54, zm), Vector3(1.4, 0.6, 0.55), 1.2, stone * 0.95, 8)
	plaque(s, Transform3D(into, Vector3(face - sg * 0.03, ys + aw + 1.05, 0.0)), 0.95)
	# the tunnel's dark: a fan over the opening on the wall's face, warm at its foot
	var wall_x := sg * (ox - 0.02)
	var foot := Color(1.0, 0.75, 0.55)
	var head := Color(0.25, 0.22, 0.2)
	kit.quad(&"void", Vector3(wall_x, y0, -aw), Vector3(wall_x, y0, aw), Vector3(wall_x, ys, aw), Vector3(wall_x, ys, -aw),
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE, StructureMeshKit.KIND_TEX, 0.0,
			PackedColorArray([foot, foot, head * 1.6, head * 1.6]), Vector3(-sg, 0, 0))
	for i in 12:
		var a0 := PI * float(i) / 12.0
		var a1 := PI * float(i + 1) / 12.0
		kit.tri(&"void", Vector3(wall_x, ys, 0.0), Vector3(wall_x, ys + sin(a0) * aw, cos(a0) * aw), Vector3(wall_x, ys + sin(a1) * aw,
				cos(a1) * aw), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, head, StructureMeshKit.KIND_TEX, 0.0, Vector3(-sg, 0, 0))
	# the tunnel's floor going in, its walls (the towers' inner faces are there), the portcullis raised into the arch
	var bars := 13
	var px := sg * (ox - 0.55)
	for i in bars:
		var z := -aw + 0.2 + float(i) * (2.0 * aw - 0.4) / float(bars - 1)
		var top := ys + sqrt(maxf(aw * aw - z * z, 0.0)) - 0.02
		var bot := y0 + 3.9
		if top > bot:
			pbox(kit, &"metal", Vector3(px, (bot + top) * 0.5, z), Vector3(0.07, top - bot, 0.07), Color(0.12, 0.12, 0.13))
			prism(kit, &"metal", Vector3(px, bot - 0.2, z), 0.0001, 0.05, 0.2, 4, Color(0.12, 0.12, 0.13))
	for hy: float in [4.0, 4.55, 5.05]:
		var yy := y0 + hy
		var half := sqrt(maxf(aw * aw - (yy - ys) * (yy - ys), 0.0))
		if half > 0.1:
			pbox(kit, &"metal", Vector3(px, yy, 0.0), Vector3(0.06, 0.07, half * 2.0 - 0.05), Color(0.12, 0.12, 0.13))
	# the end wall: a painted frieze at its head, four tall banners on staffs, bunting between them
	var wf := sg * (ox - 0.012)
	for zr: Array in [[-ox + 0.5, -aw - 2.6], [aw + 2.6, ox - 0.5]]:
		var za: float = zr[0]
		var zb: float = zr[1]
		var lz := absf(zb - za)
		var o := Vector3(wf, y0 + 4.35, za if sg > 0.0 else zb)
		var u := Vector3(0, 0, lz) * (1.0 if sg > 0.0 else -1.0)
		cloth("frieze_%d" % s, o, u, Vector3(0, -0.55, 0), int(lz), 1, Vector3(-sg, 0, 0), 0.0, 0.0, 1.0, lz)
	var poles: Array[Vector3] = []
	for bz: float in [-12.8, -7.4, 7.4, 12.8]:
		var bx := sg * (ox - 0.12)
		prism(kit, &"paint", Vector3(sg * (ox - 0.08), y0 + 3.6, bz), 0.07, 0.06, 6.8, 8, Color(0.4, 0.11, 0.06))
		prism(kit, &"gold", Vector3(sg * (ox - 0.08), y0 + 10.4, bz), 0.12, 0.0, 0.4, 8, GOLD)
		pbox(kit, &"paint", Vector3(bx - sg * 0.05, y0 + 9.55, bz), Vector3(0.1, 0.1, 2.6), Color(0.4, 0.11, 0.06))
		for e: float in [-1.3, 1.3]:
			prism(kit, &"gold", Vector3(bx - sg * 0.05, y0 + 9.48, bz + e), 0.07, 0.07, 0.14, 8, GOLD)
		var side_u := Vector3(0, 0, 2.2) * (-1.0 if sg > 0.0 else 1.0)
		cloth("banner_%d" % s, Vector3(bx - sg * 0.12, y0 + 9.45, bz) - side_u * 0.5, side_u, Vector3(0, -6.2, 0), 3, 14,
				Vector3(-sg, 0, 0), absf(bz) * 0.11 + sg)
		poles.append(Vector3(sg * (ox - 0.08), y0 + 10.3, bz))
	_string(kit, poles[0], poles[1], 0.7)
	_string(kit, poles[2], poles[3], 0.7)
	_string(kit, Vector3(xc, y0 + 9.7, -aw - 1.3), Vector3(xc, y0 + 9.7, aw + 1.3), 1.0)
	_string(kit, poles[1], Vector3(xc, y0 + 9.7, -aw - 1.3), 0.5)
	_string(kit, poles[2], Vector3(xc, y0 + 9.7, aw + 1.3), 0.5)


# ---------------------------------------------------------------- the deck's trim
func _plinth(kit: StructureMeshKit) -> void:
	var hl := ring.half_l()
	var hw := ring.half_w()
	var fh := ring.foot_half()
	var step := y0 + RingArena.num("plinth_step_y", -0.65)
	var brass := Color(0.95, 0.7, 0.36)
	# a brass edge round the deck's laying
	for sgn: float in [-1.0, 1.0]:
		pbox(kit, &"gold", Vector3(sgn * (hl + 0.012), y0 - 0.05, 0.0), Vector3(0.024, 0.1, 2.0 * hw + 0.048), brass)
		pbox(kit, &"gold", Vector3(0.0, y0 - 0.05, sgn * (hw + 0.012)), Vector3(2.0 * hl + 0.048, 0.1, 0.024), brass)
		# the coursed band gilded top and bottom
		for by: float in [-0.115, -0.345]:
			pbox(kit, &"gold", Vector3(sgn * (hl + 0.09), y0 + by, 0.0), Vector3(0.02, 0.03, 2.0 * hw + 0.18), GOLD)
			pbox(kit, &"gold", Vector3(0.0, y0 + by, sgn * (hw + 0.09)), Vector3(2.0 * hl + 0.18, 0.03, 0.02), GOLD)
		# the foot's step gilded
		pbox(kit, &"gold", Vector3(sgn * (fh.x + 0.005), step - 0.02, 0.0), Vector3(0.03, 0.04, 2.0 * fh.y + 0.04), GOLD)
		pbox(kit, &"gold", Vector3(0.0, step - 0.02, sgn * (fh.y + 0.005)), Vector3(2.0 * fh.x + 0.04, 0.04, 0.03), GOLD)
		# bronze bosses along the foot over the water
		for k in 9:
			var x := -hl + 1.7 + float(k) * (2.0 * hl - 3.4) / 8.0
			pbox(kit, &"gold", Vector3(x, step - 0.32, sgn * (fh.y + 0.04)), Vector3(0.22, 0.22, 0.08), brass * 0.8, Basis(Vector3.BACK, PI * 0.25))
	# the painted frieze on the plinth's face, each half in its side's colour
	var fy := y0 - 0.37
	var fhh := 0.26
	for sgn: float in [-1.0, 1.0]:
		var zf := sgn * (hw + 0.006)
		for s in 2:
			var xa := -hl if s == 0 else 0.0
			var xb := 0.0 if s == 0 else hl
			var o := Vector3(xa if sgn > 0.0 else xb, fy, zf)
			var u := Vector3((xb - xa) * (1.0 if sgn > 0.0 else -1.0), 0, 0)
			cloth("frieze_%d" % s, o, u, Vector3(0, -fhh, 0), int(hl), 1, Vector3(0, 0, sgn), 0.0, 0.0, 1.0, hl)
		var s2 := 0 if sgn < 0.0 else 1
		var xf := sgn * (hl + 0.006)
		var o2 := Vector3(xf, fy, -hw if sgn < 0.0 else hw)
		cloth("frieze_%d" % s2, o2, Vector3(0, 0, 2.0 * hw * (1.0 if sgn < 0.0 else -1.0)), Vector3(0, -fhh, 0), int(hw * 2.0), 1,
				Vector3(sgn, 0, 0), 0.0, 0.0, 1.0, 2.0 * hw)


# ---------------------------------------------------------------- fire and lamps
func _braziers(kit: StructureMeshKit) -> void:
	var at: Array[Vector3] = []
	for sg: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			at.append(Vector3(sg * 25.8, y0, sz * 15.3))
			at.append(Vector3(sg * (ox - 2.2), y0, sz * 6.2))
	for p in at:
		var stone := Color(0.78, 0.74, 0.68)
		RingArena.wbox(kit, &"ring_walk", p + Vector3(0, 0.15, 0), Vector3(0.95, 0.3, 0.95), 1.2, stone * 0.9, 8)
		prism(kit, &"ring_walk", p + Vector3(0, 0.3, 0), 0.34, 0.26, 0.85, 8, stone)
		prism(kit, &"gold", p + Vector3(0, 1.12, 0), 0.32, 0.36, 0.08, 10, GOLD)
		prism(kit, &"metal", p + Vector3(0, 1.2, 0), 0.26, 0.62, 0.38, 12, Color(0.18, 0.14, 0.12))
		prism(kit, &"gold", p + Vector3(0, 1.56, 0), 0.65, 0.65, 0.06, 12, GOLD)
		prism(kit, &"glow_coal", p + Vector3(0, 1.5, 0), 0.56, 0.4, 0.1, 10, Color(0.25, 0.08, 0.03))
		_flames.append([p + Vector3(0, 1.55, 0), Vector2(1.05, 1.7)])
		_halos.append([p + Vector3(0, 2.2, 0), Color(1.0, 0.55, 0.22), 2.8])
		_lamps.append([p + Vector3(0, 2.6, 0), Color(1.0, 0.58, 0.28), 3.0, 12.0])


## Lamp posts along both walks between the tank and the stands, each a lantern on a bracket toward the water.
func _posts(kit: StructureMeshKit) -> void:
	var timber := Color(0.4, 0.11, 0.06)
	for sz: float in [-1.0, 1.0]:
		for k in 7:
			var x := -21.0 + 7.0 * float(k)
			var p := Vector3(x, y0, sz * 15.5)
			RingArena.wbox(kit, &"ring_walk", p + Vector3(0, 0.2, 0), Vector3(0.45, 0.4, 0.45), 1.2, Color(0.75, 0.72, 0.66), 8)
			prism(kit, &"paint", p + Vector3(0, 0.4, 0), 0.08, 0.065, 2.6, 8, timber)
			prism(kit, &"gold", p + Vector3(0, 3.0, 0), 0.1, 0.0, 0.22, 8, GOLD)
			var arm := Vector3(0, 0, -sz * 0.55)
			pbox(kit, &"paint", p + Vector3(0, 2.85, 0) + arm * 0.5, Vector3(0.06, 0.06, 0.6), timber)
			var lp := p + arm + Vector3(0, 2.45, 0)
			prism(kit, &"metal", lp + Vector3(0, 0.22, 0), 0.012, 0.012, 0.2, 4, Color(0.15, 0.15, 0.15))
			pbox(kit, &"metal", lp + Vector3(0, 0.2, 0), Vector3(0.32, 0.05, 0.32), Color(0.16, 0.14, 0.12))
			pbox(kit, &"metal", lp + Vector3(0, -0.22, 0), Vector3(0.3, 0.05, 0.3), Color(0.16, 0.14, 0.12))
			pbox(kit, &"lamp_warm", lp, Vector3(0.24, 0.38, 0.24), Color(0.95, 0.82, 0.55))
			prism(kit, &"gold", lp + Vector3(0, 0.22, 0), 0.22, 0.0, 0.18, 4, GOLD)
			_halos.append([lp, Color(1.0, 0.7, 0.35), 1.1])
			_lamps.append([lp + Vector3(0, -0.1, 0), Color(1.0, 0.68, 0.36), 1.1, 7.0])


## Bunting strung from the scoreboard across the arena to the gates and the near stand.
func _bunting(kit: StructureMeshKit) -> void:
	var tz := -(back + 0.2 + 2.35) + 1.9
	var ty := y0 + 14.2
	var near := back + 0.1
	_string(kit, Vector3(-5.0, ty, tz), Vector3(-ox + 0.8, y0 + 9.7, -3.9), 3.0, 0.7)
	_string(kit, Vector3(5.0, ty, tz), Vector3(ox - 0.8, y0 + 9.7, -3.9), 3.0, 0.7)
	_string(kit, Vector3(-5.0, ty, tz), Vector3(xs[2], y0 + COLUMN_H + 0.4, near), 3.6, 0.7)
	_string(kit, Vector3(5.0, ty, tz), Vector3(xs[8], y0 + COLUMN_H + 0.4, near), 3.6, 0.7)
	_string(kit, Vector3(0.0, ty + 0.4, tz), Vector3(0.0, y0 + COLUMN_H + 0.4, near), 3.8, 0.7)


# ---------------------------------------------------------------- the water
func _water(t: Vector2) -> void:
	var w := ring.water
	if w == null:
		return
	if w.material != null:
		w.material.set_shader_parameter(&"deep_color", Color(0.0, 0.05, 0.1))
		w.material.set_shader_parameter(&"shallow_tint", Color(0.42, 0.8, 0.86))
		w.material.set_shader_parameter(&"absorb", 0.95)
		w.material.set_shader_parameter(&"ripple_strength", 0.42)
	var wy := RingArena.num("water_y", -1.4)
	var fh := ring.foot_half()
	# foam: bands on the water along the tank's walls (inward) and round the plinth's foot (outward)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_foam_rect(st, t, -1.0, wy + 0.012, 1.1)
	_foam_rect(st, fh, 1.0, wy + 0.012, 1.3)
	_foam_mat = ShaderMaterial.new()
	_foam_mat.shader = load(FOAM_SHADER)
	_foam_mat.render_priority = 2
	var foam := MeshInstance3D.new()
	foam.name = "Foam"
	foam.mesh = st.commit()
	foam.material_override = _foam_mat
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)
	# the water's light on the stone over it: the tank's walls (facing in) and the plinth's foot (facing out)
	var cs := SurfaceTool.new()
	cs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := y0 + RingArena.num("plinth_step_y", -0.65)
	_caustic_rect(cs, t - Vector2(0.01, 0.01), -1.0, wy, y0 - 0.02, wy)
	_caustic_rect(cs, fh + Vector2(0.012, 0.012), 1.0, wy, step - 0.04, wy)
	_caustic_rect(cs, Vector2(ring.half_l() + 0.004, ring.half_w() + 0.004), 1.0, step, y0 - 0.39, wy)
	_caustic_mat = ShaderMaterial.new()
	_caustic_mat.shader = load(CAUSTIC_SHADER)
	var cm := MeshInstance3D.new()
	cm.name = "Caustics"
	cm.mesh = cs.commit()
	cm.material_override = _caustic_mat
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cm)


## A band `width` m wide on the water round a rect (half sizes h), going in (dir -1) or out (+1) from its edge. UV.x
## metres along, UV.y 0 at the stone .. 1 at the open edge.
static func _foam_rect(st: SurfaceTool, h: Vector2, dir: float, y: float, width: float) -> void:
	var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	var run := 0.0
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var along := (b - a).normalized()
		var outn := Vector2(along.y, -along.x)          # (the rect's outward normal on this edge)
		var off := outn * dir * width
		var l := a.distance_to(b)
		var segs := maxi(int(l / 2.0), 1)
		for k in segs:
			var f0 := float(k) / float(segs)
			var f1 := float(k + 1) / float(segs)
			var p0 := a.lerp(b, f0)
			var p1 := a.lerp(b, f1)
			# the far edge mitred at the corners (pulled along the edge so the bands meet)
			var e0 := p0 + off + (along * width * dir * -1.0 if k == 0 else Vector2.ZERO) * (1.0 if dir > 0.0 else -1.0)
			var e1 := p1 + off + (along * width * dir if k == segs - 1 else Vector2.ZERO) * (1.0 if dir > 0.0 else -1.0)
			var u0 := run + l * f0
			var u1 := run + l * f1
			var q := [[Vector3(p0.x, y, p0.y), Vector2(u0, 0)], [Vector3(p1.x, y, p1.y), Vector2(u1, 0)],
					[Vector3(e1.x, y, e1.y), Vector2(u1, 1)], [Vector3(e0.x, y, e0.y), Vector2(u0, 1)]]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(q[idx][1])
				st.add_vertex(q[idx][0])
		run += l


## Upright quads round a rect (half sizes h) from y_lo to y_hi, facing in (dir -1) or out (+1); UV.x metres along,
## UV.y the height over the water at wy.
static func _caustic_rect(st: SurfaceTool, h: Vector2, dir: float, y_lo: float, y_hi: float, wy: float) -> void:
	var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	var run := 0.0
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var l := a.distance_to(b)
		var along := (b - a).normalized()
		var n := Vector3(along.y, 0.0, -along.x) * dir
		var q := [[Vector3(a.x, y_lo, a.y), Vector2(run, y_lo - wy)], [Vector3(b.x, y_lo, b.y), Vector2(run + l, y_lo - wy)],
				[Vector3(b.x, y_hi, b.y), Vector2(run + l, y_hi - wy)], [Vector3(a.x, y_hi, a.y), Vector2(run, y_hi - wy)]]
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(q[idx][1])
			st.add_vertex(q[idx][0])
		run += l


func _fire() -> void:
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = load(FLAME_SHADER)
	var card := QuadMesh.new()
	card.size = Vector2(1.0, 1.0)
	card.center_offset = Vector3(0.0, 0.5, 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = card
	mm.instance_count = _flames.size()
	for i in _flames.size():
		var sz: Vector2 = _flames[i][1]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sz.x, sz.y, 1.0)), _flames[i][0]))
	var fl := MultiMeshInstance3D.new()
	fl.name = "Flames"
	fl.multimesh = mm
	fl.material_override = _flame_mat
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fl.custom_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 20, 80))
	add_child(fl)
	# the halos
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = load(HALO_SHADER)
	var hq := QuadMesh.new()
	hq.size = Vector2(1.0, 1.0)
	var hm := MultiMesh.new()
	hm.transform_format = MultiMesh.TRANSFORM_3D
	hm.use_colors = true
	hm.mesh = hq
	hm.instance_count = _halos.size()
	for i in _halos.size():
		var h: Array = _halos[i]
		hm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * float(h[2])), h[0]))
		hm.set_instance_color(i, h[1])
	var hi := MultiMeshInstance3D.new()
	hi.name = "Halos"
	hi.multimesh = hm
	hi.material_override = _halo_mat
	hi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hi.custom_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 25, 80))
	add_child(hi)
	# embers rising from each brazier (GPU particles, a few each)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0.4, 0.6, 0.2)
	pm.damping_min = 0.4
	pm.damping_max = 0.9
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	em.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	em.vertex_color_use_as_albedo = true
	em.albedo_color = Color(3.0, 2.0, 1.2)
	var dot := QuadMesh.new()
	dot.size = Vector2(0.07, 0.07)
	dot.material = em
	for f: Array in _flames:
		var p := GPUParticles3D.new()
		p.name = "Embers"
		p.amount = 14
		p.lifetime = 1.8
		p.preprocess = 2.0
		p.process_material = pm
		p.draw_pass_1 = dot
		p.position = (f[0] as Vector3) + Vector3(0, 0.3, 0)
		p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		embers.append(p)


## The lamps' lights (night only): the braziers', the posts', and four lamps pooling warm light on the deck.
func _lights() -> void:
	var root := Node3D.new()
	root.name = "Lights"
	add_child(root)
	for l: Array in _lamps:
		var o := OmniLight3D.new()
		o.light_color = l[1]
		o.light_energy = float(l[2])
		o.omni_range = float(l[3])
		o.omni_attenuation = 1.4
		o.shadow_enabled = false
		o.light_specular = 0.3
		o.light_volumetric_fog_energy = 0.5
		o.distance_fade_enabled = true
		o.distance_fade_begin = 70.0
		o.distance_fade_length = 20.0
		o.position = l[0]
		root.add_child(o)
		lights.append(o)
	# the deck's pools: two from the scoreboard's head (shadows: clean shapes), two from the near stand's piers
	var tower_z := -(back + 0.2 + 2.35) + 1.6
	var deck := [[Vector3(-3.2, y0 + 9.0, tower_z), Vector3(-9.0, y0, 0.5), true], [Vector3(3.2, y0 + 9.0, tower_z), Vector3(9.0, y0, 0.5), true],
			[Vector3(xs[3], y0 + COLUMN_H - 0.4, back - 0.4), Vector3(-6.0, y0, -0.5), false],
			[Vector3(xs[7], y0 + COLUMN_H - 0.4, back - 0.4), Vector3(6.0, y0, -0.5), false]]
	for dsp: Array in deck:
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.72, 0.42)
		var from: Vector3 = dsp[0]
		var to: Vector3 = dsp[1]
		s.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
		var dist := from.distance_to(to)
		s.spot_range = dist + 14.0
		s.spot_angle = 26.0
		s.spot_angle_attenuation = 0.6
		s.spot_attenuation = 0.6
		s.light_energy = 0.11 * dist * dist / 10.0
		s.shadow_enabled = bool(dsp[2])
		s.shadow_blur = 0.6
		s.light_specular = 0.25
		root.add_child(s)
		lights.append(s)
		spots.append(s)


# ---------------------------------------------------------------- the horizon
## Two rings of low-poly hills round the arena (wooded near, blue far) and dark cone trees on the near ones: one mesh
## and one MultiMesh, no shadows.
func _horizon() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 1765
	noise.frequency = 0.9
	var n := 120
	var rings := [[160.0, 205.0, 255.0, 16.0, 16.0, Color(0.3, 0.38, 0.22), Color(0.22, 0.3, 0.17)],
			[290.0, 360.0, 430.0, 38.0, 30.0, Color(0.36, 0.44, 0.5), Color(0.3, 0.38, 0.46)]]
	var trees: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1766
	for r: Array in rings:
		var r0: float = r[0]
		var r1: float = r[1]
		var r2: float = r[2]
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var h0: float = float(r[3]) + float(r[4]) * noise.get_noise_1d(a0 * (3.0 + r0 * 0.01))
			var h1: float = float(r[3]) + float(r[4]) * noise.get_noise_1d(a1 * (3.0 + r0 * 0.01))
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var lo: Color = r[6]
			var hi: Color = r[5]
			var pts := [[d0 * r0 + Vector3(0, y0 - 0.1, 0), lo], [d1 * r0 + Vector3(0, y0 - 0.1, 0), lo],
					[d1 * r1 + Vector3(0, y0 + h1, 0), hi], [d0 * r1 + Vector3(0, y0 + h0, 0), hi],
					[d0 * r2 + Vector3(0, y0 - 0.1, 0), lo], [d1 * r2 + Vector3(0, y0 - 0.1, 0), lo]]
			for idx: int in [0, 2, 1, 0, 3, 2, 3, 5, 2, 3, 4, 5]:
				st.set_color(pts[idx][1])
				st.add_vertex(pts[idx][0])
			if r0 < 200.0:
				for k in 3:
					var f := rng.randf_range(0.15, 0.85)
					var a := lerpf(a0, a1, rng.randf())
					var hh := lerpf(0.0, lerpf(h0, h1, 0.5), 1.0 - absf(f - 0.5) * 1.6)
					var p := Vector3(cos(a), 0, sin(a)) * lerpf(r0, r1, f) + Vector3(0, y0 + maxf(hh, 0.0) - 0.5, 0)
					var sc := rng.randf_range(5.0, 9.0)
					trees.append(Transform3D(Basis().scaled(Vector3(sc * 0.45, sc, sc * 0.45)), p))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var hills := MeshInstance3D.new()
	hills.name = "Hills"
	hills.mesh = st.commit()
	hills.material_override = m
	hills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hills)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.13, 0.22, 0.13)
	tm.roughness = 1.0
	cone.material = tm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = trees.size()
	for i in trees.size():
		mm.set_instance_transform(i, trees[i].translated_local(Vector3(0, 0.5, 0)))
	var tr := MultiMeshInstance3D.new()
	tr.name = "Trees"
	tr.multimesh = mm
	tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tr)
