class_name FireRuin
extends Node3D
## What a fire leaves of a piece (scripts/fire; FireSpread makes it when a burning piece falls): the piece's own look
## (BuiltPiece.build_visuals, the same mesh and stakes it had) in charred wood (shaders/fire/charred.gdshader) cut off
## raggedly a little over the ground (RUIN_H over the ground under each point of it, the ground's slope under the piece
## followed: a palisade's stubs on a hillside stand as high on the uphill end as downhill; a wall's bottom courses, a
## floor's charred boards; a roof or a gable, all above that, leaves nothing standing), embers glowing in it that die
## over GLOW_S, and a scorched patch on the ground under it (a Decal). No colliders: the way through is open. A
## burnable that is not a built piece (FireSpread.BURNABLE_GROUP: a story's cabin) is charred and cut where it stands
## (`in_place`).
## Cleared away: by a piece built over it (FireSpread._on_built: covered_by), or in build mode with Take down chosen and
## the crosshair on it (an E interactable of PlayerInteractor, like a BuiltPiece in Take down: "E  Clear away the burnt
## notched log wall"; nothing comes back). A burnable's ruin in place is the story's and stays.
## Saved by FireSpread (to_save / from_save): the piece's type, place, variant, look context, ground and cuts.

## How much of each piece stands over the ground under it (m; the rest is cut off, ragged).
const RUIN_H := {"wall": 0.85, "wall_window": 0.85, "wall_door": 0.7, "palisade": 1.15, "palisade_gate": 0.9,
		"blockhouse": 1.1, "floor": 0.55, "post": 0.9, "walkway": 0.5, "walkway_ramp": 0.45, "ladder": 0.4,
		"flagpole": 1.4, "woodpile": 0.35, "smokehouse": 0.6, "storage_chest": 0.3, "boat_stand": 0.5}
const DEFAULT_H := 0.5
## Seconds the embers in the ruin glow (fading).
const GLOW_S := 240.0
const SHADER := "res://shaders/fire/charred.gdshader"
## Of a new piece's footprint over a ruin's (the smaller's): this much covered clears the ruin (a wall rebuilt on its
## stubs, a floor over them; not the next wall along touching its end, nor one crossing its corner).
const COVER := 0.3

## The save's record of it.
var data := {}
## Seconds since it fell.
var age := 0.0
## The burnable it was, charred where it stands (not a built piece).
var in_place: Node3D
## The reach the interactor allows (build mode's, as a BuiltPiece's).
var interact_reach := 9.0
var _gis: Array[GeometryInstance3D] = []
var _decal: Decal
var _glow := -1.0
var _box := AABB()
var _cut := 0.0


static var _mat: ShaderMaterial
static var _scorch: Texture2D


static func release() -> void:
	_mat = null
	_scorch = null


## The one charred material (its per-piece values are instance uniforms: cut_y, cut_slope, cut_at, glow, seed; its
## `dim`, the eye's exposure, FireSpread sets for all).
static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load(SHADER) as Shader
	return _mat


## Turns `gis` to charred wood (cut over `cut_y`, world, at `at` (xz) and rising `slope` (per m along x and z) away from
## it: the ground's; INF: whole), embers glowing at `glow`.
static func char_geometry(gis: Array, cut_y := INF, glow := 1.0, seed := 0.0, slope := Vector2.ZERO, at := Vector2.ZERO) -> void:
	var m := material()
	for g in gis:
		var gi := g as GeometryInstance3D
		if gi == null or not is_instance_valid(gi):
			continue
		gi.material_override = m
		gi.set_instance_shader_parameter(&"cut_y", cut_y if cut_y != INF else 100000.0)
		gi.set_instance_shader_parameter(&"cut_slope", slope)
		gi.set_instance_shader_parameter(&"cut_at", at)
		gi.set_instance_shader_parameter(&"glow", glow)
		gi.set_instance_shader_parameter(&"seed", seed)


## The height over the ground under `xf` that a `type` leaves standing.
static func cut_for(type: String, xf: Transform3D) -> float:
	return FrontierTerrain.height_at(xf.origin.x, xf.origin.z) + float(RUIN_H.get(type, DEFAULT_H))


## The ground's slope under `box` (rise per m along x and z: from its height at the box's ends).
static func ground_slope(box: AABB) -> Vector2:
	var x0 := box.position.x
	var x1 := box.end.x
	var z0 := box.position.z
	var z1 := box.end.z
	var gx := 0.0
	var gz := 0.0
	if x1 - x0 > 0.2:
		var zc := (z0 + z1) * 0.5
		gx = (FrontierTerrain.height_at(x1, zc) - FrontierTerrain.height_at(x0, zc)) / (x1 - x0)
	if z1 - z0 > 0.2:
		var xc := (x0 + x1) * 0.5
		gz = (FrontierTerrain.height_at(xc, z1) - FrontierTerrain.height_at(xc, z0)) / (z1 - z0)
	return Vector2(gx, gz)


## What a ruin of `p` (a built piece about to be taken down) is made from: its type, place, variant, look context
## (kept exactly, var_to_str: the mesh's cache key and its matches are typed), ground and cuts; `box` its world AABB
## (the scorch's size). JSON-safe: the save keeps it as it is.
static func record(p: BuiltPiece, box: AABB) -> Dictionary:
	return {"type": p.type, "xf": SaveParts.xf(p.global_transform), "variant": p.variant, "ctx": var_to_str(p.ctx),
			"ground": Array(p.ground), "cuts": var_to_str(p.cuts), "box": [SaveParts.v3(box.position), SaveParts.v3(box.size)]}


## The ruin of `p` under `parent`.
static func of_piece(parent: Node, p: BuiltPiece, box: AABB, detail := true) -> FireRuin:
	return from_save(parent, record(p, box), detail)


## A ruin from its save record (of_piece's `data`), under `parent`.
static func from_save(parent: Node, d: Dictionary, detail := true) -> FireRuin:
	var r := FireRuin.new()
	r.name = "Ruin_%s" % String(d.get("type", "piece"))
	r.data = d.duplicate(true)
	r.age = float(d.get("age", 0.0))
	parent.add_child(r)
	var xf := SaveParts.to_xf(d.get("xf"))
	r.global_transform = xf
	var type := String(d.get("type", ""))
	var b: Array = d.get("box", [])
	var box := AABB(SaveParts.to_v3(b[0]), SaveParts.to_v3(b[1])) if b.size() == 2 else AABB(xf.origin - Vector3(1.5, 0, 1.5), Vector3(3, 2.5, 3))
	var cut := cut_for(type, xf)
	r.data["cut"] = cut
	r._box = box
	r._cut = cut
	var slope := ground_slope(box)
	var at := Vector2(xf.origin.x, xf.origin.z)
	if box.position.y < r._cut_max(slope, at):
		# (a roof, a gable: all of it over the cut; nothing of it stands)
		var ctx: Variant = str_to_var(String(d.get("ctx", "{}")))
		var cuts: Variant = str_to_var(String(d.get("cuts", "[]")))
		var g := PackedFloat32Array()
		for x in d.get("ground", []):
			g.append(float(x))
		var gis := BuiltPiece.build_visuals(r, type, int(d.get("variant", 0)), ctx if ctx is Dictionary else {}, g, detail, true,
				cuts if cuts is Array else [])
		for gi in gis:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			r._gis.append(gi)
		char_geometry(r._gis, cut, r.glow(), float(absi(hash(xf.origin)) % 1000) * 0.37, slope, at)
	r._scorch_decal(box)
	return r


## A burnable charred and cut where it stands (not a built piece: it stays the node it is, its colliders off).
static func of_node(parent: Node, n: Node3D, box: AABB, path: String) -> FireRuin:
	var r := FireRuin.new()
	r.name = "Ruin_%s" % n.name
	r.in_place = n
	r.data = {"path": path, "box": [SaveParts.v3(box.position), SaveParts.v3(box.size)]}
	parent.add_child(r)
	r.global_position = box.get_center()
	var c := box.get_center()
	var cut := FrontierTerrain.height_at(c.x, c.z) + DEFAULT_H * 2.0
	r.data["cut"] = cut
	r._box = box
	r._cut = cut
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if not (g is GPUParticles3D or g is CPUParticles3D or g is Label3D or g is SpriteBase3D):
			r._gis.append(g as GeometryInstance3D)
	char_geometry(r._gis, cut, 1.0, 0.0, ground_slope(box), Vector2(c.x, c.z))
	for cs in n.find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).set_deferred(&"disabled", true)
	r._scorch_decal(box)
	return r


## The highest the cut stands over the box's corners (whether anything of it is under the cut).
func _cut_max(slope: Vector2, at: Vector2) -> float:
	var m := -INF
	for x: float in [_box.position.x, _box.end.x]:
		for z: float in [_box.position.z, _box.end.z]:
			m = maxf(m, _cut + slope.dot(Vector2(x, z) - at))
	return m


## 0..1: how hot its embers still are.
func glow() -> float:
	var k := clampf(1.0 - age / GLOW_S, 0.0, 1.0)
	return k * k


## FireSpread's slow tick: the embers die down.
func step(dt: float) -> void:
	age += dt
	var g := snappedf(glow(), 0.02)
	if g == _glow:
		return
	_glow = g
	for gi in _gis:
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter(&"glow", g)


func to_save() -> Dictionary:
	var d := data.duplicate(true)
	d["age"] = age
	return d


## Whether a piece with world box `box`, built now, stands over this ruin (COVER of the smaller footprint, at the
## ruin's height: its stubs and its scorch, not a roof high over them). Never a burnable's ruin in place.
func covered_by(box: AABB) -> bool:
	if in_place != null:
		return false
	var gy := FrontierTerrain.height_at(_box.get_center().x, _box.get_center().z)
	var low := AABB(Vector3(_box.position.x, gy - 0.5, _box.position.z), Vector3(_box.size.x, maxf(_cut - gy, 0.0) + 1.0, _box.size.z))
	var o := low.intersection(box)
	if o.size.x <= 0.0 or o.size.y <= 0.0 or o.size.z <= 0.0:
		return false
	var mine := maxf(_box.size.x * _box.size.z, 0.01)
	var theirs := maxf(box.size.x * box.size.z, 0.01)
	return o.size.x * o.size.z >= COVER * minf(mine, theirs)


# --- Clear away (build mode's Take down; PlayerInteractor's "any other interactable") ------------------------------

func _ready() -> void:
	if in_place == null:
		add_to_group(PlacedWeapon.GROUP)


## Build mode with Take down chosen, nothing built under the crosshair and the crosshair on this ruin's ground.
func _taker() -> BuildMode:
	if in_place != null:
		return null
	var m := BuildMode.current
	if m == null or not is_instance_valid(m) or not m.active or not m.taking_down() or m.aimed_piece != null:
		return null
	var q := m.aim_point()
	var r := Rect2(_box.position.x, _box.position.z, _box.size.x, _box.size.z).grow(0.4)
	return m if r.has_point(Vector2(q.x, q.z)) else null


func interact_point() -> Vector3:
	var m := _taker()
	return m.aim_point() if m else global_position


func distance_from(p: Vector3) -> float:
	var m := _taker()
	if m == null:
		return INF
	var q := m.aim_point()
	return Vector2(q.x - p.x, q.z - p.z).length()


func interact_prompt(_player: Node) -> String:
	return "Clear away the burnt %s" % _name() if _taker() else ""


func highlight_targets() -> Array:
	return _gis.filter(func(g: Variant) -> bool: return is_instance_valid(g))


func interact(player: Node) -> void:
	if _taker() == null:
		return
	var it: Node = player.get("interactor") if player else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", "Cleared away the burnt %s" % _name(), 2.5)
	var f := FireSpread.find(get_tree())
	if f:
		f.clear_ruin(self)
	else:
		queue_free()


func _name() -> String:
	var t := String(data.get("type", ""))
	var nm := BuildData.get_default().name_of(t) if t != "" else ""
	return nm.to_lower() if nm != "" else "remains"


## A scorched patch of ground under the piece (a Decal, a soft dark blot a little wider than the piece).
func _scorch_decal(box: AABB) -> void:
	if _scorch == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.09
		n.seed = 1757
		for y in 64:
			for x in 64:
				var u := (x + 0.5) / 64.0 - 0.5
				var v := (y + 0.5) / 64.0 - 0.5
				var r := sqrt(u * u + v * v) * 2.0 + (n.get_noise_2d(x, y)) * 0.25
				var a := (1.0 - smoothstep(0.45, 1.0, r)) * 0.9
				var c := 0.025 + 0.05 * (n.get_noise_2d(x * 3.0, y * 3.0) * 0.5 + 0.5)
				img.set_pixel(x, y, Color(c, c * 0.95, c * 0.9, a))
		img.generate_mipmaps()
		_scorch = ImageTexture.create_from_image(img)
	_decal = Decal.new()
	_decal.name = "Scorch"
	_decal.texture_albedo = _scorch
	_decal.albedo_mix = 1.0
	# (on the ground only, as the animals' blood drops: faded off upright faces and anything standing in it)
	_decal.cull_mask = 1
	_decal.upper_fade = 6.0
	_decal.lower_fade = 0.5
	_decal.normal_fade = 0.3
	_decal.distance_fade_enabled = true
	_decal.distance_fade_begin = 120.0
	_decal.distance_fade_length = 30.0
	var c := box.get_center()
	var gy := FrontierTerrain.height_at(c.x, c.z)
	_decal.size = Vector3(box.size.x + 1.8, 2.4, box.size.z + 1.8)
	add_child(_decal)
	_decal.global_transform = Transform3D(Basis(), Vector3(c.x, gy, c.z))
