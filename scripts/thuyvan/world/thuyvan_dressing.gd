class_name ThuyVanDressing
extends Node3D
## R1's dressing for the Đá Trắng vista (docs/thuyvan/plan/look/vista_spec.md section 3, placements D1-D21), on the
## packed ground (ThuyVanTerrain; FrontierTerrain's statics give the heights) with the kits (ThuyVanKit: ROCK, VILLAGE,
## PAINT's vegetation):
##   backdrop   a painted low-poly skirt from the region's edge out to BACKDROP_M (tv_terrain on its own coarse splat),
##              continuing the rim's heights and rising to the far ranks' plateau west and north
##   karst      D13 north rim (hero towers K1-K4), D14 west backdrop K5-K12, D15 K13-K14, the C4 footprints, and the far
##              ranks filling 2.4-6 km in the look's four fog steps (tv_rock_far, rank_fog per tower), skyline cards past
##   gorge      ROCK's cliff modules down C1's walls and the torrent's slot (standing proud of the height field's slope,
##              their backs reaching the lip), the notch module at each wall fall's lip
##   reach      D16 the white stones (assets/thuyvan/rock/white_stones_c1.json), D17 the sampan on its beach
##   bridges    D1-D4 the rope bridge (VILLAGE's assembled rope_bridge_r1) on D2 the needle; D11-D12 the Two Heights
##              bridge with its stone heads (beside the deck's ends, ROCK's head note) and their gate towers
##   village    D6 cliff houses on the west lip, D7 stilt houses and the clan house on B1's terrace steps, D5 the
##              waystone with its prayer-flag ropes, banners, lanterns, fences and clutter, D18 the survey camp, D19 the
##              burial cairns
##   mist       D20 the look's mist bands (set_look): flat puff layers in the gorge, standing bands (turning to the camera)
##              over the terraces and round the far karst's waists
##   plants     D21 PAINT's broadleaf, pines, bamboo, banana, ferns and shrubs by the bake's forest density and the painted
##              splat, and PAINT's grass cards round the places people stand; MultiMesh tiles with near / far LODs
##
##   var d := ThuyVanDressing.new(); add_child(d); d.build(settings); d.set_look(look)

const Kit := preload("res://scripts/thuyvan/look/thuyvan_kit.gd")
const Look := preload("res://scripts/thuyvan/look/thuyvan_look.gd")
const Cards := preload("res://scripts/thuyvan/world/thuyvan_cards.gd")
const Region := preload("res://scripts/world/world_region.gd")
const TV_SHADER := "res://shaders/thuyvan/tv_terrain.gdshader"
const TV_ARRAY := "res://assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp"
const FAR_SHADER := "res://shaders/thuyvan/tv_rock_far.gdshader"
const ROCK_MAT := "res://assets/thuyvan/rock/materials/rock_karst.tres"
const FOLIAGE_SHADER := "res://shaders/thuyvan/tv_foliage.gdshader"
const GRASS_ATLAS := "res://assets/thuyvan/paint/foliage/tv_grass_atlas.png"
const GRASS_VARIANTS := "res://assets/thuyvan/paint/foliage/tv_grass_variants.json"
const HERB_ATLAS := "res://assets/thuyvan/paint/foliage/tv_herb_atlas.png"
const HERB_VARIANTS := "res://assets/thuyvan/paint/foliage/tv_herb_variants.json"

## The region's ground (layout: columns A-C at x -832..832, rows 1-4 at z -1248..1248, 832 m squares).
const REGION := Rect2(-1248.0, -1664.0, 2496.0, 3328.0)
const BACKDROP_M := 7000.0
const BACKDROP_STEP := 125.0
## The skirt's height inside the region (under its lowest ground, 85 m).
const SKIRT_UNDER := 20.0
## Where the far ranks are measured from (the vista's middle: between the gorge and the Two Heights).
const RANK_FROM := Vector2(300.0, -900.0)

## D13-D15: [id, x, z, height m, kind ("hero" near, "far" backdrop)]
const KARST := [
	["K1", -260.0, -1620.0, 160.0, "hero"], ["K2", 130.0, -1700.0, 120.0, "hero"], ["K3", -640.0, -1560.0, 200.0, "hero"],
	["K4", 420.0, -1640.0, 110.0, "hero"],
	["K5", -1450.0, -1200.0, 180.0, "far"], ["K6", -1700.0, -700.0, 240.0, "far"], ["K7", -1600.0, -300.0, 200.0, "far"],
	["K8", -2100.0, -1500.0, 260.0, "far"], ["K9", -2400.0, -900.0, 300.0, "far"], ["K10", -2600.0, -200.0, 280.0, "far"],
	["K11", -3200.0, -1300.0, 350.0, "far"], ["K12", -3500.0, -500.0, 320.0, "far"],
	["K13", 600.0, -2100.0, 220.0, "far"], ["K14", -200.0, -2300.0, 260.0, "far"],
	# the C4 karst footprints (layout karst_footprints): the river's exit, the first karst
	["C4a", 1000.0, 1100.0, 150.0, "hero"], ["C4b", 700.0, 1300.0, 190.0, "hero"], ["C4c", 1100.0, 1500.0, 130.0, "hero"],
	# the rim's own towers west and north of the village (dressing, on the rim band outside the walkable ground)
	["R1", -1190.0, -1050.0, 170.0, "hero"], ["R2", -1170.0, -150.0, 140.0, "hero"], ["R3", 1180.0, -1500.0, 150.0, "hero"],
	["R4", -1000.0, -1640.0, 190.0, "hero"],
	# the ring of towers round the village's hill (the sheet's hero: the village on its terraces among karst in mist), on
	# the high pass, B1's north rim and the A2 plateau: off the trails and the terraces
	["H1", -380.0, -1480.0, 230.0, "hero"], ["H2", -640.0, -1180.0, 260.0, "hero"], ["H3", -470.0, -870.0, 190.0, "hero"],
	["H4", -900.0, -1250.0, 210.0, "hero"], ["H5", -1050.0, -700.0, 240.0, "hero"],
	["H7", -700.0, -760.0, 170.0, "hero"],
	# the gorge's north end (V3 looks up it): two towers past the region's edge
	["N1", 900.0, -1760.0, 220.0, "hero"], ["N2", 700.0, -1730.0, 170.0, "hero"], ["N3", 1060.0, -1700.0, 160.0, "hero"],
]
## The far ranks' procedural towers: how many per rank, in the arc (degrees, 0 north, 90 west) round RANK_FROM.
const RANK_COUNT := [10, 14, 18, 22]
const RANK_ARC := Vector2(-60.0, 230.0)

## The rope bridge (VILLAGE's assembled D1-D4, its origin on the west anchor's deck) and the needle (D2).
const ROPE_BRIDGE_AT := Vector3(757.0, 200.0, -1215.0)
const NEEDLE_AT := Vector3(820.0, 135.0, -1215.0)
## D11: the Two Heights bridge's deck (its origin) over the torrent's slot, the deck north-south.
const TWO_HEIGHTS_AT := Vector3(-832.0, 296.0, -462.0)
## D12: the stone heads beside the deck's ends (offset off the road: ROCK's head note).
const HEADS := [["two_heights_head_n", Vector3(-872.0, 0.0, -560.0), 200.0], ["two_heights_head_s", Vector3(-790.0, 0.0, -372.0), 20.0]]
## D6: the cliff houses' z on the west lip.
const CLIFF_HOUSES := [-1245.0, -1288.0, -1180.0]
## D7: the village and the clan house.
const VILLAGE_AT := Vector2(0.0, -1248.0)
const CLAN_HOUSE_AT := Vector2(60.0, -1330.0)
const VILLAGE_HOUSES := 11
## D5: the waystone, its flag pole.
const WAYSTONE_AT := Vector2(905.0, -1228.0)
const FLAG_POLE_AT := Vector2(915.0, -1240.0)
## D17-D19.
const SAMPAN_AT := Vector3(818.0, 134.0, -1290.0)
const SURVEY_AT := Vector2(650.0, -1000.0)
const CAIRNS_AT := Vector2(700.0, -1580.0)
## Wall falls' lips (ThuyVanWater.WALL_FALLS): the notch module goes there.
const FALL_LIPS := [Vector2(752.0, -1150.0), Vector2(750.0, -1330.0)]

## The painted rock stretched along the walls (tv_rock's strata_stretch) on the gorge modules; the towers a little less.
const STRATA_STRETCH := 2.2
## Gorge walls: [channel id, along-axis ("z" or "x"), from, to] stretches where modules stand.
const WALLS := [["main", "z", -1660.0, -960.0], ["torrent", "x", -1150.0, -620.0]]
const WALL_STEP := 36.0
## Where nothing tall stands (the bridge heads, the decks): [x, z, radius].
const KEEP_CLEAR := [[757.0, -1215.0, 26.0], [893.0, -1215.0, 26.0], [820.0, -1215.0, 18.0], [-832.0, -462.0, 70.0]]

## Plants: the grid step (m) of the scatter, its tiles (m), the near LOD's reach and the far LOD's.
const PLANT_STEP := 11.0
const TILE := 256.0
const LOD0_END := 280.0
## Ferns and shrubs: their own small tiles (seen to 90 m).
const SMALL_TILE := 48.0
const LOD1_END := 2200.0
## Places people stand (grass cards round them): [x, z, radius, grid step m, ferns and shrubs]. The V1 lip is the
## owner's foreground: thickest there.
const GRASS_SPOTS := [[930.0, -1245.0, 110.0, 1.1, 160], [740.0, -1215.0, 90.0, 1.6, 50], [0.0, -1248.0, 170.0, 1.9, 60],
		[880.0, -1560.0, 90.0, 1.9, 40], [-560.0, -560.0, 90.0, 1.9, 40], [-600.0, -420.0, 110.0, 1.5, 120], [-832.0, -560.0, 70.0, 1.9, 30], [860.0, -1300.0, 60.0, 1.6, 30]]

var settings: WorldSettings
var rng := RandomNumberGenerator.new()
## Scatter buckets: "species|variant|tx|tz" -> Array[Transform3D] (near and far LODs share the tile).
var _plants := {}
var _plant_meshes := {}
var _far_mat: ShaderMaterial
var _mist: Node3D
var _mist_key := ""
var _mist_mats: Array[ShaderMaterial] = []
var _seats_meta := {}
## Footprints kept clear of trees: [x, z, radius].
var _clear: Array = []
var _grass_mat: ShaderMaterial
var _herb_mat: ShaderMaterial
var _tower_count := 0


func build(world_settings: WorldSettings = null) -> void:
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	rng.seed = 1603
	_clear = KEEP_CLEAR.duplicate(true)
	for z: float in CLIFF_HOUSES:
		_clear.append([748.0, z, 18.0])        # (the cliff houses hang over the wall itself: no module there)
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(Kit.ROCK_DIR + "rock_kit.json"))
	_seats_meta = (meta as Dictionary).get("pieces", {}) if meta is Dictionary else {}
	_backdrop()
	_karst()
	_gorge_walls()
	_white_stones()
	_bridges()
	_village()
	_waystone()
	_camp_and_cairns()
	_boulders()
	_scatter_plants()
	_flush_plants()
	_grass()


## The look's mist bands (heights per direction; rebuilt when they change) and the water's tint.
func set_look(look: Dictionary) -> void:
	var bands: Array = look.get("mist_bands_m", [])
	var key := str(bands)
	var col: Color = look.get("mist_color", Color(0.9, 0.93, 0.93))
	if key != _mist_key:
		_mist_key = key
		_build_mist(bands, col)
	for m in _mist_mats:
		m.set_shader_parameter("card_color", col)


static func ground(x: float, z: float) -> float:
	return FrontierTerrain.height_at(x, z)


func _in_region(x: float, z: float, inset := 0.0) -> bool:
	return REGION.grow(-inset).has_point(Vector2(x, z))


func _place(n: Node3D, at: Vector3, yaw_deg: float, sc := 1.0) -> Node3D:
	if n == null:
		return null
	n.position = at
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * sc
	add_child(n, true)
	return n


## Yaw (degrees) that turns a piece's front (+Z) toward `to` from `from`.
static func yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return rad_to_deg(atan2(d.x, d.y))


# --- the backdrop ground -------------------------------------------------------------------------------------------

## The far ground's height: the region's edge height carried out and eased to the far plateau (west and north higher,
## south falling away), with broad hills.
func _far_height(x: float, z: float) -> float:
	var cx := clampf(x, REGION.position.x + 2.0, REGION.end.x - 2.0)
	var cz := clampf(z, REGION.position.y + 2.0, REGION.end.y - 2.0)
	var edge := ground(cx, cz)
	var d := Vector2(x - cx, z - cz).length()
	var west := clampf(-x / 3000.0, 0.0, 1.0)
	var north := clampf(-z / 3000.0, 0.0, 1.0)
	var south := clampf(z / 3000.0, 0.0, 1.0)
	var plateau := 250.0 + 70.0 * maxf(west, north) - 120.0 * south
	plateau += 35.0 * sin(x / 610.0 + 1.3) * sin(z / 480.0 - 0.4) + 18.0 * sin(x / 230.0 - z / 310.0)
	return lerpf(edge, plateau, smoothstep(0.0, 900.0, d))


func _backdrop() -> void:
	var n := int(BACKDROP_M * 2.0 / BACKDROP_STEP) + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var inner := REGION.grow(-40.0)
	for j in n:
		for i in n:
			var x := -BACKDROP_M + i * BACKDROP_STEP
			var z := -BACKDROP_M + j * BACKDROP_STEP
			# inside the region the skirt sinks well under the ground (the region's own mesh is there)
			if inner.has_point(Vector2(x, z)):
				hs[j * n + i] = SKIRT_UNDER      # (far under every gorge: a 125 m triangle spans one)
			elif REGION.has_point(Vector2(x, z)):
				hs[j * n + i] = ground(x, z) - 3.0
			else:
				hs[j * n + i] = _far_height(x, z)
	for j in n:
		for i in n:
			var hl := hs[j * n + maxi(i - 1, 0)]
			var hr := hs[j * n + mini(i + 1, n - 1)]
			var hd := hs[maxi(j - 1, 0) * n + i]
			var hu := hs[mini(j + 1, n - 1) * n + i]
			verts.append(Vector3(-BACKDROP_M + i * BACKDROP_STEP, hs[j * n + i], -BACKDROP_M + j * BACKDROP_STEP))
			normals.append(Vector3(hl - hr, 2.0 * BACKDROP_STEP, hd - hu).normalized())
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	# its splat: forest and meadow in broad patches (a 256 px map over the whole skirt)
	var res := 256
	var sp := [Image.create(res, res, false, Image.FORMAT_RGBA8), Image.create(res, res, false, Image.FORMAT_RGBA8),
			Image.create(res, res, false, Image.FORMAT_RGBA8)]
	for j in res:
		for i in res:
			var x := -BACKDROP_M + (i + 0.5) * BACKDROP_M * 2.0 / res
			var z := -BACKDROP_M + (j + 0.5) * BACKDROP_M * 2.0 / res
			var f := 0.5 + 0.5 * sin(x / 420.0 + 0.7) * sin(z / 360.0 - 1.1) + 0.25 * sin(x / 130.0 - z / 170.0)
			var forest := smoothstep(0.35, 0.6, f)
			(sp[0] as Image).set_pixel(i, j, Color(1.0 - forest, 0.0, forest, 0.0))
			(sp[2] as Image).set_pixel(i, j, Color(0.0, 0.0, 0.0, (1.0 - forest) * 0.6))
	var mat := ShaderMaterial.new()
	mat.shader = load(TV_SHADER)
	mat.set_shader_parameter("albedo_array", load(TV_ARRAY))
	for q in 3:
		mat.set_shader_parameter("splat%d" % q, ImageTexture.create_from_image(sp[q]))
	mat.set_shader_parameter("splat_rect", Vector4(-BACKDROP_M, -BACKDROP_M, BACKDROP_M * 2.0, BACKDROP_M * 2.0))
	var mi := Cards.mesh_instance(self, verts, normals, idx, mat, "Backdrop")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# far forest: puffs of the far broadleaf over the skirt's forest within 2.5 km of the region
	for k in 2600:
		var x := rng.randf_range(-3800.0, 3800.0)
		var z := rng.randf_range(-4300.0, 4300.0)
		if REGION.grow(10.0).has_point(Vector2(x, z)) or REGION.grow(2500.0).has_point(Vector2(x, z)) == false:
			continue
		var f := 0.5 + 0.5 * sin(x / 420.0 + 0.7) * sin(z / 360.0 - 1.1) + 0.25 * sin(x / 130.0 - z / 170.0)
		if f < 0.5:
			continue
		_add_plant("tv_broadleaf", rng.randi_range(1, 2), Vector3(x, _far_height(x, z) - 0.5, z), rng.randf_range(1.6, 2.4), true)


# --- karst ---------------------------------------------------------------------------------------------------------

func _far_material() -> ShaderMaterial:
	if _far_mat == null:
		_far_mat = ShaderMaterial.new()
		_far_mat.shader = load(FAR_SHADER)
		var rm := load(ROCK_MAT) as ShaderMaterial
		if rm:
			for p: Dictionary in rm.shader.get_shader_uniform_list():
				var v: Variant = rm.get_shader_parameter(String(p.name))
				if v != null:
					_far_mat.set_shader_parameter(String(p.name), v)
		Look.register_rank(_far_mat)
	return _far_mat


## The look's fog step (karst_ranks) for a tower at distance `d` from RANK_FROM: 0 inside the first rank's start.
static func rank_fog(d: float) -> float:
	var fog := 0.0
	for r: Dictionary in Look.data().get("karst_ranks", []):
		if d >= float(r.from_m) * 0.85:
			fog = float(r.fog)
	return fog


func _karst() -> void:
	for k: Array in KARST:
		var x := float(k[1])
		var z := float(k[2])
		var h := float(k[3])
		var hero := String(k[4]) == "hero"
		var y := (ground(x, z) if _in_region(x, z) else _far_height(x, z)) - 3.0
		var piece := ""
		if hero:
			piece = ["karst_hero_a", "karst_hero_b", "karst_hero_c", "karst_hero_d", "karst_hero_e"][_tower_count % 5]
		else:
			piece = ["karst_far_a", "karst_far_b", "karst_far_c", "karst_far_d", "karst_far_e", "karst_far_f"][_tower_count % 6]
		_tower(piece, Vector3(x, y, z), rng.randf() * 360.0, h, hero)
		_clear.append([x, z, 45.0 * h / 150.0])
	# the far ranks: towers in an arc round the vista, each rank in its distance band and fog step
	var ranks: Array = Look.data().get("karst_ranks", [])
	for ri in ranks.size():
		var r: Dictionary = ranks[ri]
		var count: int = RANK_COUNT[mini(ri, RANK_COUNT.size() - 1)]
		for i in count:
			var ang := deg_to_rad(lerpf(RANK_ARC.x, RANK_ARC.y, (float(i) + rng.randf_range(0.15, 0.85)) / count))
			var dist := rng.randf_range(float(r.from_m), float(r.to_m))
			# compass: 0 north (-Z), 90 west (-X)
			var p := RANK_FROM + Vector2(-sin(ang), -cos(ang)) * dist
			if REGION.grow(300.0).has_point(p):
				continue
			# (WoW's exaggeration: the far ranks tower, so they still read as ranks through the fog)
			var h := rng.randf_range(220.0, 380.0) * (1.0 + 0.35 * ri)
			var piece: String = ["karst_far_a", "karst_far_b", "karst_far_c", "karst_far_d", "karst_far_e", "karst_far_f"][rng.randi() % 6]
			_tower(piece, Vector3(p.x, _far_height(p.x, p.y) - 4.0, p.y), rng.randf() * 360.0, h, false)
	# skyline cards past the last rank (painted silhouettes, already fogged)
	for i in 9:
		var ang := deg_to_rad(lerpf(RANK_ARC.x - 10.0, RANK_ARC.y + 10.0, (float(i) + 0.5) / 9.0))
		var dist := 6600.0 + rng.randf_range(-300.0, 300.0)
		var p := RANK_FROM + Vector2(-sin(ang), -cos(ang)) * dist
		var m := Cards.material("res://assets/thuyvan/paint/sky/tv_skyline_karst_%d.png" % (i % 3), Vector2.ZERO, 1.0, 1.0,
				{"proximity_fade": 0.0, "near_fade": 0.0, "end_fade": 0.2, "fog_mix": 0.35, "light_tint_amount": 0.3})
		var width := 3600.0
		var face := Vector3(RANK_FROM.x - p.x, 0.0, RANK_FROM.y - p.y).normalized()
		var base := Vector3(p.x, 180.0, p.y)
		Cards.card(self, base, base + Vector3.UP * width / 8.0 * 1.4, width, face, m).name = "Skyline%d" % i


## A tower `h` m tall (scaled from its modelled height) at `at`; a hero carries pines on its seats; a far one wears
## tv_rock_far at its fog step.
func _tower(piece: String, at: Vector3, yaw: float, h: float, hero: bool) -> Node3D:
	var n := Kit.rock(piece, hero)
	if n == null:
		return null
	_tower_count += 1
	var meta: Dictionary = _seats_meta.get(piece, {})
	var top := float(meta.get("size", {}).get("y", [0.0, 200.0])[1])
	var sc := h / maxf(top, 1.0)
	_place(n, at, yaw, sc)
	_stretch(n, STRATA_STRETCH * 0.75)
	if not hero:
		var fog := rank_fog(Vector2(at.x, at.z).distance_to(RANK_FROM))
		for mi in Kit._meshes(n):
			mi.material_override = _far_material()
			mi.set_instance_shader_parameter("rank_fog", fog)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s: Dictionary in meta.get("seats", []):
		if String(s.kind) != "pine":
			continue
		var lp := Vector3(s.pos[0], s.pos[1], s.pos[2])
		var wp := n.transform * lp
		var r := float(s.get("r", 3.0))
		var v := 2 if r > 4.0 else (1 if r > 2.0 else 0)
		var crown := bool(s.get("crown", false))
		if not hero and not crown and rng.randf() < 0.6:
			continue
		_add_plant("tv_karst_pine", v, wp, sc * rng.randf_range(1.1, 1.7) * (1.4 if crown else 1.0), not hero)
	return n


# --- the gorge's walls ---------------------------------------------------------------------------------------------

func _rows(channel: String) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(water_path()))
	if not d is Dictionary:
		return []
	for c: Dictionary in (d as Dictionary).get("channels", []):
		if String(c.id) == channel:
			return c.nodes
	return []


## The region's water network file (its block's "water").
static func water_path() -> String:
	return String(Region.info().get("water", "res://data/world/maps/r1/water.json"))


func _gorge_walls() -> void:
	var lips: Array = []
	for w: Array in WALLS:
		var rows := _rows(String(w[0]))
		if rows.is_empty():
			continue
		var along := String(w[1])
		var a0 := float(w[2])
		var a1 := float(w[3])
		var last := -1e9
		for r: Array in rows:
			var x := float(r[1])
			var z := float(r[2])
			var key := z if along == "z" else x
			if key < a0 or key > a1 or absf(key - last) < WALL_STEP:
				continue
			last = key
			var hw := float(r[3])
			var level := float(r[4])
			for side in [-1.0, 1.0]:
				var lip := _wall_at(x, z, level, hw, side, along)
				if not lip.is_empty():
					lips.append(lip)
	for lip: Dictionary in lips:
		_module(lip)


## Where a wall stands beside the water at (x, z): walking out across the channel (side -1 west/north, +1 east/south),
## the lip (where the slope eases off after the drop): {lip, foot (the face's position), depth, normal}; {} where the
## ground is no wall (under 28 m of drop).
func _wall_at(x: float, z: float, level: float, hw: float, side: float, along: String) -> Dictionary:
	var out := Vector2(side, 0.0) if along == "z" else Vector2(0.0, side)
	var p := Vector2(x, z) + out * hw
	var prev := ground(p.x, p.y)
	var steep := false
	var lip := Vector2.ZERO
	var lip_h := 0.0
	for k in 70:
		var q := p + out * 2.0
		var h := ground(q.x, q.y)
		var s := (h - prev) / 2.0
		if s > 0.9:
			steep = true
		elif steep and s < 0.35:
			lip = p
			lip_h = prev
			break
		p = q
		prev = h
	if not steep or lip_h - level < 28.0:
		return {}
	for c: Array in _clear:
		if Vector2(lip.x - float(c[0]), lip.y - float(c[1])).length() < float(c[2]):
			return {}
	var depth := lip_h - level
	# the face stands where the slope is 55 % of the way down from the lip
	var f := lip
	for k in 60:
		var q := f - out * 1.0
		if ground(q.x, q.y) < lip_h - depth * 0.55:
			break
		f = q
	return {"lip": Vector3(lip.x, lip_h, lip.y), "face": Vector3(f.x, lip_h, f.y), "depth": depth,
			"normal": Vector3(-out.x, 0.0, -out.y)}


func _module(w: Dictionary) -> void:
	var lip: Vector3 = w.lip
	var face: Vector3 = w.face
	var depth := float(w.depth)
	var nrm: Vector3 = w.normal
	var piece := "cliff_straight_75"
	var notch := false
	for fl: Vector2 in FALL_LIPS:
		if Vector2(lip.x, lip.z).distance_to(fl) < WALL_STEP * 0.5:
			notch = true
	if notch:
		piece = "cliff_notch_75"
	elif depth < 45.0:
		piece = "cliff_straight_60" if rng.randf() < 0.5 else "cliff_convex_60"
	else:
		piece = ["cliff_straight_75", "cliff_concave_75", "cliff_straight_75", "cliff_ledge_30"][rng.randi() % 4]
		if piece == "cliff_ledge_30" and depth > 60.0:
			piece = "cliff_straight_75"
	var n := Kit.rock(piece, true)
	if n == null:
		return
	var meta: Dictionary = _seats_meta.get(piece, {})
	var zs: Array = meta.get("size", {}).get("z", [-13.0, 6.0])
	# its back reaches the lip: stretch its depth (the paint is world-space, so it does not stretch)
	var reach := Vector2(lip.x - face.x, lip.z - face.z).length() + 3.0
	var zscale := clampf(reach / maxf(-float(zs[0]), 1.0), 1.0, 4.0)
	n.position = Vector3(face.x, lip.y + rng.randf_range(0.6, 1.6), face.z)
	n.rotation.y = atan2(nrm.x, nrm.z) + deg_to_rad(rng.randf_range(-7.0, 7.0))
	n.scale = Vector3(rng.randf_range(0.95, 1.1), rng.randf_range(0.95, 1.08), zscale)
	add_child(n, true)
	_stretch(n, STRATA_STRETCH)
	for s: Dictionary in meta.get("seats", []):
		if String(s.kind) == "pine" and rng.randf() < 0.7:
			var wp := n.transform * Vector3(s.pos[0], s.pos[1], s.pos[2])
			_add_plant("tv_karst_pine" if rng.randf() < 0.6 else "tv_shrub", rng.randi_range(0, 2), wp, rng.randf_range(0.9, 1.4))


func _stretch(n: Node3D, k: float) -> void:
	for mi in Kit._meshes(n):
		mi.set_instance_shader_parameter("strata_stretch", k)


# --- the reach -----------------------------------------------------------------------------------------------------

func _white_stones() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(Kit.ROCK_DIR + "white_stones_c1.json"))
	var ps := Kit.scene(Kit.ROCK_DIR + "white_stones.glb")
	if not meta is Dictionary or ps == null:
		return
	var src := ps.instantiate()
	var by := {}
	for mi in Kit._meshes(src):
		by[String(mi.name)] = mi.mesh
	src.free()
	var xs := {}
	for s: Dictionary in (meta as Dictionary).get("stones", []):
		var nm := String(s.node)
		if not by.has(nm):
			continue
		if not xs.has(nm):
			xs[nm] = []
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(s.yaw_deg))).scaled(Vector3.ONE * float(s.scale)),
				Vector3(s.pos[0], s.pos[1], s.pos[2]))
		(xs[nm] as Array).append(t)
	for nm: String in xs:
		_multimesh(by[nm], null, xs[nm], "WhiteStones_" + nm, 0.0, 0.0, true)
	# D17: the sampan on its beach, a pole and the fish basket beside it
	_place(Kit.village("sampan"), Vector3(SAMPAN_AT.x, ground(SAMPAN_AT.x, SAMPAN_AT.z) - 0.1, SAMPAN_AT.z), 168.0)
	_place(Kit.village("basket_set"), Vector3(SAMPAN_AT.x + 3.0, ground(SAMPAN_AT.x + 3.0, SAMPAN_AT.z - 3.0), SAMPAN_AT.z - 3.0), 30.0)


# --- the bridges ---------------------------------------------------------------------------------------------------

func _bridges() -> void:
	_place(Kit.village("rope_bridge_r1"), ROPE_BRIDGE_AT, 0.0)
	var needle := _place(Kit.rock("bridge_needle", true), NEEDLE_AT, 0.0)
	if needle:
		for s: Dictionary in _seats_meta.get("bridge_needle", {}).get("seats", []):
			if String(s.kind) == "pine":
				_add_plant("tv_karst_pine", 0, needle.transform * Vector3(s.pos[0], s.pos[1], s.pos[2]), rng.randf_range(0.8, 1.2))
	# D1: the gate pavilion at the west bridge head; lantern posts at both heads
	_place(Kit.village("gate_pavilion"), Vector3(745.0, ground(745.0, -1215.0), -1215.0), 90.0)
	for p: Vector2 in [Vector2(752.0, -1222.0), Vector2(898.0, -1207.0)]:
		_place(Kit.village("lantern_post"), Vector3(p.x, ground(p.x, p.y), p.y), 90.0)
	# D11-D12: the Two Heights
	var th := _place(Kit.rock("two_heights_bridge", true), TWO_HEIGHTS_AT, 0.0)
	if th:
		for s: Dictionary in _seats_meta.get("two_heights_bridge", {}).get("seats", []):
			if String(s.kind) == "banner":
				_place(Kit.village("banner_ochre"), th.transform * Vector3(s.pos[0], s.pos[1], s.pos[2]),
						90.0 if float(s.pos[0]) > 0.0 else -90.0)
	for hd: Array in HEADS:
		var at: Vector3 = hd[1]
		at.y = ground(at.x, at.z) - 4.0
		var head := Kit.rock(String(hd[0]), true)
		if head == null:
			continue
		_place(head, at, float(hd[2]))
		_clear.append([at.x, at.z, 40.0])
		for s: Dictionary in _seats_meta.get(String(hd[0]), {}).get("seats", []):
			var wp := head.transform * Vector3(s.pos[0], s.pos[1], s.pos[2])
			match String(s.kind):
				"gate_tower":
					_place(Kit.village("gate_tower"), wp, float(hd[2]) + 180.0)
				"pine":
					_add_plant("tv_karst_pine", rng.randi_range(1, 2), wp, rng.randf_range(1.1, 1.6))


# --- the village ---------------------------------------------------------------------------------------------------

## A piece on uneven ground: its origin at the mean of the ground under its footprint (stilts take the rest).
func _seat(x: float, z: float, r: float) -> float:
	var hs := [ground(x, z), ground(x + r, z), ground(x - r, z), ground(x, z + r), ground(x, z - r)]
	var s := 0.0
	for h: float in hs:
		s += h
	return s / hs.size() - 0.25


func _village() -> void:
	# D6: the cliff houses on the west lip, hung toward the gorge (their front, +Z, east)
	for z: float in CLIFF_HOUSES:
		var x := 760.0
		while ground(x, z) < ground(700.0, z) - 2.5 and x > 700.0:
			x -= 1.0
		_place(Kit.village("cliff_house"), Vector3(x + 1.5, ground(x, z) + 0.3, z), 90.0 + rng.randf_range(-6.0, 6.0))
		_clear.append([x, z, 12.0])
		_add_plant("tv_bamboo", rng.randi_range(0, 1), Vector3(x - 12.0, ground(x - 12.0, z + 6.0), z + 6.0), 1.0)
	# D7: the clan house on its plinth, facing down the terraces toward the gorge
	var ch := CLAN_HOUSE_AT
	_place(Kit.village("clan_house"), Vector3(ch.x, _seat(ch.x, ch.y, 6.0), ch.y), yaw_to(ch, Vector2(800.0, -1250.0)))
	_clear.append([ch.x, ch.y, 18.0])
	for k in 2:
		var bp := ch + Vector2(-6.0 + 12.0 * k, 12.0)
		_place(Kit.village("banner_indigo"), Vector3(bp.x, ground(bp.x, bp.y), bp.y), 90.0)
	# the stilt houses on the steps between y 170 and 190, not on the paddies or the path
	var placed: Array[Vector2] = [ch]
	var tries := 0
	while placed.size() < VILLAGE_HOUSES + 1 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(18.0, 120.0)
		var p := VILLAGE_AT + Vector2(cos(a), sin(a)) * r
		var g := ground(p.x, p.y)
		if g < 168.0 or g > 194.0:
			continue
		if p.x > 38.0 and p.x < 122.0 and p.y > -1172.0 and p.y < -1008.0:
			continue
		var ok := true
		for q: Vector2 in placed:
			if q.distance_to(p) < 19.0:
				ok = false
				break
		if not ok or _slope(p.x, p.y) > 0.45:
			continue
		placed.append(p)
		var big := placed.size() % 3 != 0
		var face := yaw_to(p, Vector2(820.0, -1250.0)) + rng.randf_range(-35.0, 35.0)
		var house := _place(Kit.village("stilt_house_large" if big else "stilt_house_small"),
				Vector3(p.x, _seat(p.x, p.y, 4.0), p.y), face)
		_clear.append([p.x, p.y, 11.0])
		# a lantern at its door, clutter beside it, bamboo or a banana behind
		if house:
			var door := house.transform * Vector3(0.95, 3.4 if big else 2.6, 4.7 if big else 3.9)
			_place(Kit.village("lantern_round"), door, face)
			var side := house.transform * Vector3(rng.randf_range(5.0, 7.0) * (1 if rng.randf() < 0.5 else -1), 0.0, 1.0)
			var clutter: String = ["drying_rack", "water_jars", "firewood_pile", "basket_set"][rng.randi() % 4]
			_place(Kit.village(clutter), Vector3(side.x, ground(side.x, side.z), side.z), face + rng.randf_range(-30.0, 30.0))
			var back := house.transform * Vector3(rng.randf_range(-6.0, 6.0), 0.0, -9.0)
			_add_plant("tv_bamboo" if rng.randf() < 0.6 else "tv_banana", rng.randi_range(0, 1),
					Vector3(back.x, ground(back.x, back.z) - 0.2, back.z), rng.randf_range(0.9, 1.25))
	# lantern posts and fences along the path down to the bridge; banners at the village's edge
	for k in 9:
		var x := lerpf(90.0, 700.0, (float(k) + 0.5) / 9.0)
		var z := lerpf(-1252.0, -1219.0, (float(k) + 0.5) / 9.0) + 6.0
		_place(Kit.village("lantern_post"), Vector3(x, ground(x, z), z), rng.randf() * 360.0)
	for k in 14:
		var x := lerpf(60.0, 360.0, float(k) / 14.0)
		var z := lerpf(-1262.0, -1244.0, float(k) / 14.0) - 5.0
		var fence := _place(Kit.village("fence_bamboo_3m"), Vector3(x, ground(x, z), z), yaw_to(Vector2(x, z), Vector2(x + 30.0, z + 2.0)) - 90.0)
		if fence:
			fence.rotation_degrees.z = rng.randf_range(-4.0, 4.0)
	for p: Vector2 in [Vector2(120.0, -1215.0), Vector2(-40.0, -1190.0), Vector2(30.0, -1310.0)]:
		_place(Kit.village(["banner_indigo", "banner_jade", "banner_ochre"][rng.randi() % 3]), Vector3(p.x, ground(p.x, p.y), p.y),
				rng.randf() * 360.0)
	# terrace walls along the paddies' lower edges (the steps the V1 camera sees)
	for k in 5:
		var z := -1135.0 + 30.0 * k
		for i in 18:
			var x := 45.0 + i * 4.0
			_place(Kit.village("terrace_wall_straight_4m"), Vector3(x + 2.0, ground(x + 2.0, z + 1.0) - 0.9, z + 1.0), 0.0)


func _slope(x: float, z: float) -> float:
	return Vector2(ground(x + 2.0, z) - ground(x - 2.0, z), ground(x, z + 2.0) - ground(x, z - 2.0)).length() / 4.0


## D5: the waystone, its cairn, two prayer-flag ropes (to the east anchor's post and to the pole), banners.
func _waystone() -> void:
	var w := WAYSTONE_AT
	_place(Kit.village("clan_waystone"), Vector3(w.x, ground(w.x, w.y) - 0.2, w.y), yaw_to(w, Vector2(820.0, -1215.0)))
	_clear.append([w.x, w.y, 8.0])
	var pole := FLAG_POLE_AT
	_place(Kit.village("banner_indigo"), Vector3(pole.x, ground(pole.x, pole.y), pole.y), 120.0)
	var top := Vector3(w.x, ground(w.x, w.y) + 4.2, w.y)
	_flags(top, Vector3(893.0, 204.6, -1212.0))
	_flags(top, Vector3(pole.x, ground(pole.x, pole.y) + 6.0, pole.y))
	_flags(Vector3(pole.x, ground(pole.x, pole.y) + 6.0, pole.y), Vector3(930.0, ground(930.0, -1262.0) + 3.5, -1262.0))
	_place(Kit.village("banner_jade"), Vector3(930.0, ground(930.0, -1262.0), -1262.0), 60.0)
	for k in 3:
		var p := w + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(2.0, 4.0))
		_place(Kit.rock("cairn_%s" % ["a", "c", "e"][k], false), Vector3(p.x, ground(p.x, p.y), p.y), rng.randf() * 360.0)


## A prayer-flag rope from `a` to `b` (VILLAGE's 4, 8 or 12 m rope, stretched to fit).
func _flags(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var L := d.length()
	var piece := "prayer_flags_12m" if L > 9.0 else ("prayer_flags_8m" if L > 5.0 else "prayer_flags_4m")
	var nominal := 12.0 if L > 9.0 else (8.0 if L > 5.0 else 4.0)
	var n := Kit.village(piece)
	if n == null:
		return
	var x := d.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x).normalized()
	n.transform = Transform3D(Basis(x * (L / nominal), y, z), a)
	add_child(n)


func _camp_and_cairns() -> void:
	var s := SURVEY_AT
	_place(Kit.village("survey_camp"), Vector3(s.x, _seat(s.x, s.y, 3.0), s.y), yaw_to(s, Vector2(820.0, -1100.0)))
	_clear.append([s.x, s.y, 14.0])
	_place(Kit.village("porter_standing"), Vector3(s.x + 6.0, ground(s.x + 6.0, s.y + 2.0), s.y + 2.0), 70.0)
	var c := CAIRNS_AT
	for k in 5:
		var p := c + Vector2(cos(k * 1.3) * (3.0 + k * 1.6), sin(k * 1.3) * (3.0 + k * 1.6))
		_place(Kit.rock("cairn_%s" % ["a", "b", "c", "d", "e"][k], false), Vector3(p.x, ground(p.x, p.y) - 0.05, p.y),
				rng.randf() * 360.0, rng.randf_range(1.3, 1.8))
	_clear.append([c.x, c.y, 14.0])


## Boulders on the lips the cameras stand on (vista_spec V1's foreground: "shrubs, ferns, boulders on the lip") and by
## the bridge heads, sunk a fifth into the ground.
func _boulders() -> void:
	for spot: Array in [[925.0, -1262.0, 45.0, 9], [900.0, -1190.0, 30.0, 5], [745.0, -1240.0, 30.0, 5], [-560.0, -420.0, 40.0, 6],
			[820.0, -1560.0, 40.0, 5]]:
		for k in int(spot[3]):
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * float(spot[2])
			var p := Vector2(float(spot[0]) + cos(a) * r, float(spot[1]) + sin(a) * r)
			if _cleared(p.x, p.y) or _slope(p.x, p.y) > 0.7 or _near_camera(p.x, p.y, 28.0):
				continue
			var sc := rng.randf_range(1.0, 1.8)
			var piece: String = ["boulder_c", "boulder_d", "boulder_e", "boulder_f"][rng.randi() % 4]
			_place(Kit.rock(piece, true), Vector3(p.x, ground(p.x, p.y) - 0.3 * sc, p.y), rng.randf() * 360.0, sc)


# --- mist ----------------------------------------------------------------------------------------------------------

func _build_mist(bands: Array, col: Color) -> void:
	if _mist:
		_mist.queue_free()
	_mist_mats.clear()
	_mist = Node3D.new()
	_mist.name = "Mist"
	add_child(_mist)
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 77
	var rows := _rows("main")
	for bi in bands.size():
		var lo := float(bands[bi][0])
		var hi := float(bands[bi][1])
		var mid := (lo + hi) * 0.5
		if mid < 175.0:
			# in the gorge: flat layers of soft puffs over the water (band 1 over the still reach, thickest there)
			var puffs := Cards.material("tv_mist_puffs.png", Vector2.ZERO, 0.5, 1.0,
					{"atlas_grid": Vector2(2, 2), "proximity_fade": 10.0, "near_fade": 30.0, "light_tint_amount": 0.0,
					"card_color": col})
			_mist_mats.append(puffs)
			for r: Array in rows:
				var z := float(r[2])
				if z < -1640.0 or z > -940.0 or mrng.randf() < 0.55:
					continue
				var dense := 2 if z > -1500.0 and z < -1100.0 else 1
				for k in dense:
					var at := Vector3(float(r[1]) + mrng.randf_range(-14.0, 14.0), lerpf(lo, hi, mrng.randf()), z + mrng.randf_range(-6.0, 6.0))
					var q := Cards.quad(_mist, at, mrng.randf_range(45.0, 85.0), puffs)
					q.rotation_degrees = Vector3(-90.0, mrng.randf() * 360.0, 0.0)
					q.set_instance_shader_parameter("atlas_cell", float(mrng.randi() % 4))
			continue
		# standing bands that turn to the camera: across B1's low terraces (band 2), round the Two Heights and the far
		# karst's waists (band 3)
		var spots: Array = []
		if mid < 215.0:
			spots = [Vector2(150.0, -1150.0), Vector2(-120.0, -1080.0), Vector2(300.0, -1300.0), Vector2(-60.0, -880.0)]
		else:
			spots = [Vector2(-832.0, -470.0), Vector2(-600.0, -520.0), Vector2(-1500.0, -900.0), Vector2(-2200.0, -600.0),
					Vector2(-1900.0, -1400.0), Vector2(-2800.0, -1100.0), Vector2(-300.0, -1950.0), Vector2(-3300.0, -200.0)]
		var hgt := maxf((hi - lo) * 2.2, 30.0)
		for k in spots.size():
			var p: Vector2 = spots[k]
			var width := 420.0 + 60.0 * k
			var tex := "tv_mist_band_%s.png" % ["a", "b", "c"][(bi + k) % 3]
			var m := Cards.material(tex, Vector2(0.5 / width * 2.0, 0.0), 0.55, 1.0,
					{"end_fade": 0.25, "proximity_fade": 20.0, "near_fade": 40.0, "uv_scale": Vector2(2.0, 1.0),
					"light_tint_amount": 0.0, "card_color": col, "billboard": true, "billboard_y": true})
			_mist_mats.append(m)
			var q := Cards.quad(_mist, Vector3(p.x, mid, p.y), 1.0, m)
			q.scale = Vector3(width, hgt, 1.0)


# --- plants --------------------------------------------------------------------------------------------------------

## A plant into the scatter (`far`: the far LOD only, everywhere: far towers' crowns and the backdrop's forest).
func _add_plant(species: String, variant: int, at: Vector3, sc: float, far := false) -> void:
	var tile := TILE * (4.0 if far else 1.0)
	if species in ["tv_fern", "tv_shrub"]:
		tile = SMALL_TILE                 # (their reach is short: a tile's middle must be near them)
	var tx := floori(at.x / tile)
	var tz := floori(at.z / tile)
	var key := "%s|%d|%d|%d|%d" % [species, variant, tx, tz, 1 if far else 0]
	if not _plants.has(key):
		_plants[key] = []
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
	(_plants[key] as Array).append(Transform3D(b, at))


func _plant_mesh(species: String, variant: int, lod: int) -> Mesh:
	var key := "%s|%d|%d" % [species, variant, lod]
	if not _plant_meshes.has(key):
		var mi := Kit.plant(species, variant, lod)
		_plant_meshes[key] = mi.mesh if mi else null
		if mi:
			mi.free()
	return _plant_meshes[key]


## The painted splat's weights at (x, z) (the packed tv_splat maps, nearest sample), 12 floats.
func _splat_at(x: float, z: float) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(12)
	var o := FrontierTerrain.origin
	var sq := Vector2i(floori((x - o.x + 416.0) / 832.0), floori((z - o.y + 416.0) / 832.0))
	var dir := "" if sq == Vector2i.ZERO else FrontierTerrain.SQUARE_DIR % [sq.x, sq.y]
	var c := FrontierTerrain.square_origin(sq)
	var i := clampi(roundi(x - c.x + 416.0), 0, 832)
	var j := clampi(roundi(z - c.z + 416.0), 0, 832)
	for k in 3:
		var img := FrontierTerrain.data_image(dir + "tv_splat%d.res" % k)
		if img == null:
			continue
		var p := img.get_pixel(i, j)
		w[k * 4] = p.r
		w[k * 4 + 1] = p.g
		w[k * 4 + 2] = p.b
		w[k * 4 + 3] = p.a
	return w


## No tall plant in the cameras' sight lines (vista_spec 1: V1 over the gorge to the village and the Two Heights, V2 to
## the bridge): wedges [from x, z, to x, z, half width at the far end]; shrubs and ferns are still allowed.
const VIEW_WEDGES := [[938.0, -1250.0, 0.0, -1248.0, 140.0], [938.0, -1250.0, 60.0, -1330.0, 90.0],
		[938.0, -1250.0, 760.0, -1120.0, 60.0],
		[-540.0, -400.0, -832.0, -462.0, 110.0], [857.0, -1211.0, 830.0, -1640.0, 60.0]]
## Around the cameras themselves, nothing tall: [x, z, radius].
const VIEW_CLEAR := [[938.0, -1250.0, 70.0], [-540.0, -400.0, 95.0], [857.0, -1211.0, 30.0]]


## Whether (x, z) is within `r` m of a camera (nothing bulky right in front of the lens).
static func _near_camera(x: float, z: float, r: float) -> bool:
	for c: Array in VIEW_CLEAR:
		if Vector2(x - float(c[0]), z - float(c[1])).length() < r:
			return true
	return false


## Whether (x, z) lies in a camera's sight line (no tall plant there).
static func in_view(x: float, z: float) -> bool:
	for c: Array in VIEW_CLEAR:
		if Vector2(x - float(c[0]), z - float(c[1])).length() < float(c[2]):
			return true
	for w: Array in VIEW_WEDGES:
		var a := Vector2(float(w[0]), float(w[1]))
		var b := Vector2(float(w[2]), float(w[3]))
		var ab := b - a
		var t := clampf((Vector2(x, z) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if t > 0.0 and t < 1.0 and Vector2(x, z).distance_to(a + ab * t) < float(w[4]) * t:
			return true
	return false


func _cleared(x: float, z: float) -> bool:
	for c: Array in _clear:
		if absf(x - float(c[0])) < float(c[2]) and absf(z - float(c[1])) < float(c[2]) \
				and Vector2(x - float(c[0]), z - float(c[1])).length() < float(c[2]):
			return true
	return false


func _scatter_plants() -> void:
	var nx := int(REGION.size.x / PLANT_STEP)
	var nz := int(REGION.size.y / PLANT_STEP)
	for j in nz:
		for i in nx:
			var x := REGION.position.x + (i + rng.randf()) * PLANT_STEP
			var z := REGION.position.y + (j + rng.randf()) * PLANT_STEP
			if not _in_region(x, z, 6.0) or _cleared(x, z):
				continue
			var y := ground(x, z)
			var w := _splat_at(x, z)
			# no trees on paths, paddies, white stone, terraces' steps (a few at their edges), banks
			if w[3] > 0.35 or w[5] > 0.3 or w[7] > 0.3 or w[9] > 0.5:
				continue
			var sl := _slope(x, z)
			var fd := FrontierTerrain.forest_density(x, z)
			var r := rng.randf()
			if sl > 1.0:
				if r < 0.06 and not in_view(x, z):
					_add_plant("tv_karst_pine", rng.randi_range(0, 2), Vector3(x, y - 0.3, z), rng.randf_range(0.9, 1.5))
				continue
			if w[1] > 0.4:
				if r < 0.012 and not in_view(x, z):
					_add_plant("tv_broadleaf", rng.randi_range(0, 1), Vector3(x, y - 0.3, z), rng.randf_range(1.0, 1.3))
				continue
			var p := lerpf(0.035, 0.62, smoothstep(0.3, 0.75, fd))
			if in_view(x, z):
				p = 0.0
			if r > p:
				# under-storey in the open: shrubs and ferns now and then
				if r < p + 0.03:
					_add_plant("tv_shrub" if rng.randf() < 0.6 else "tv_fern", rng.randi_range(0, 2), Vector3(x, y - 0.1, z), rng.randf_range(1.0, 1.6))
				continue
			var q := rng.randf()
			if sl > 0.55 or q < 0.14:
				_add_plant("tv_karst_pine", rng.randi_range(1, 2), Vector3(x, y - 0.3, z), rng.randf_range(1.2, 1.8))
			elif q < 0.2 and y < 190.0:
				_add_plant("tv_bamboo", rng.randi_range(0, 1), Vector3(x, y - 0.2, z), rng.randf_range(1.0, 1.3))
			elif q < 0.23:
				_add_plant("tv_banana", 0, Vector3(x, y - 0.2, z), rng.randf_range(1.1, 1.5))
			else:
				_add_plant("tv_broadleaf", rng.randi_range(0, 2), Vector3(x, y - 0.4, z), rng.randf_range(1.15, 1.6))
	# ferns and moss shrubs in the falls' spray, ferns along the lips the cameras stand on
	for fl: Vector2 in FALL_LIPS:
		for k in 30:
			var p := fl + Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-25.0, 25.0))
			_add_plant("tv_fern", rng.randi_range(0, 2), Vector3(p.x, ground(p.x, p.y) - 0.1, p.y), rng.randf_range(1.2, 2.0))
	for spot: Array in GRASS_SPOTS:
		for k in int(spot[4]):
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * float(spot[2]) * 0.8
			var p := Vector2(float(spot[0]) + cos(a) * rr, float(spot[1]) + sin(a) * rr)
			if _cleared(p.x, p.y) or _splat_at(p.x, p.y)[7] > 0.3 or _slope(p.x, p.y) > 0.8:
				continue
			_add_plant("tv_fern" if rng.randf() < 0.5 else "tv_shrub", rng.randi_range(0, 2), Vector3(p.x, ground(p.x, p.y) - 0.1, p.y),
					rng.randf_range(1.1, 1.8))


## Every scatter bucket as MultiMesh tiles: the near LOD to LOD0_END, the far one from there to LOD1_END (the far-only
## buckets: their far LOD everywhere).
func _flush_plants() -> void:
	var s := settings.vegetation_distance_scale if settings else 1.0
	for key: String in _plants:
		var parts := key.split("|")
		var species := parts[0]
		var variant := int(parts[1])
		var far := parts[4] == "1"
		var xs: Array = _plants[key]
		var mat := Kit.foliage_material(species)
		if far:
			_multimesh(_plant_mesh(species, variant, 1), mat, xs, "Far_" + key, 0.0, 0.0, false)
			continue
		var small := species in ["tv_fern", "tv_shrub"]
		var end0 := (90.0 if small else LOD0_END) * s
		_multimesh(_plant_mesh(species, variant, 0), mat, xs, "Near_" + key, 0.0, end0, not small)
		if not small:
			_multimesh(_plant_mesh(species, variant, 1), mat, xs, "Mid_" + key, end0, LOD1_END * s, false)
	_plants.clear()


func _multimesh(mesh: Mesh, mat: Material, xs: Array, nm: String, begin: float, end: float, shadows: bool) -> void:
	if mesh == null or xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for k in xs.size():
		mm.set_instance_transform(k, xs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm.replace("|", "_")
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- grass cards ---------------------------------------------------------------------------------------------------

## A crossed pair of cards `h` m tall for an atlas rect (u0, v0, u1, v1), in the foliage shader's tree format (COLOR r
## AO dark at the root, a = 1 leaf; UV2 x the height for the wind).
static func card_mesh(rect: Array, aspect: float, h: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var w := h * aspect
	for k in 2:
		var ang := PI * 0.5 * k + 0.4
		var r := Vector3(cos(ang), 0.0, sin(ang)) * w * 0.5
		var n := Vector3(-sin(ang), 0.35, cos(ang)).normalized()
		var base := verts.size()
		for c: Array in [[-1.0, 0.0], [1.0, 0.0], [1.0, 1.0], [-1.0, 1.0]]:
			verts.append(r * float(c[0]) + Vector3.UP * h * float(c[1]))
			normals.append(n)
			uv.append(Vector2(lerpf(float(rect[0]), float(rect[2]), (float(c[0]) + 1.0) * 0.5),
					lerpf(float(rect[3]), float(rect[1]), float(c[1]))))
			uv2.append(Vector2(h * float(c[1]), 0.0))
			cols.append(Color(lerpf(0.6, 1.0, float(c[1])), float(c[1]), 0.5, 1.0))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _card_material(atlas: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(FOLIAGE_SHADER)
	m.set_shader_parameter("leaf_atlas", load(atlas))
	m.set_shader_parameter("bark_tex", load(atlas))
	m.set_shader_parameter("ao_strength", 0.6)
	m.set_shader_parameter("sway", 0.03)
	return m


func _grass() -> void:
	var gv: Variant = JSON.parse_string(FileAccess.get_file_as_string(GRASS_VARIANTS))
	var hv: Variant = JSON.parse_string(FileAccess.get_file_as_string(HERB_VARIANTS))
	if not gv is Array:
		return
	_grass_mat = _card_material(GRASS_ATLAS)
	_herb_mat = _card_material(HERB_ATLAS)
	var kinds := {}
	for v: Dictionary in gv:
		var k := String(v.kind)
		if not kinds.has(k):
			kinds[k] = []
		if (kinds[k] as Array).size() >= 2:
			continue          # (two cards of a kind: draw calls)
		(kinds[k] as Array).append(card_mesh(v.uv_rect, float(v.aspect), 0.75 if k in ["grass", "meadow"] else 0.45))
	var herbs: Array = []
	if hv is Array:
		for v: Dictionary in hv:
			if String(v.kind) in ["flower", "flower_mix"] and v.has("uv_rect") and herbs.size() < 2:
				herbs.append(card_mesh(v.uv_rect, float(v.aspect), 0.6))
	var buckets := {}
	for spot: Array in GRASS_SPOTS:
		var c := Vector2(float(spot[0]), float(spot[1]))
		var rad := float(spot[2])
		var step := float(spot[3])
		var n := int(rad * 2.0 / step)
		for j in n:
			for i in n:
				var p := c + Vector2(-rad + (i + rng.randf()) * step, -rad + (j + rng.randf()) * step)
				if p.distance_to(c) > rad or not _in_region(p.x, p.y, 2.0):
					continue
				var w := _splat_at(p.x, p.y)
				if w[7] > 0.3 or w[5] > 0.3 or _slope(p.x, p.y) > 0.9:
					continue
				var kind := ""
				if w[1] > 0.5:
					kind = "rice"
				elif w[0] + w[11] > 0.45 and w[3] < 0.3:
					kind = "meadow" if w[11] > w[0] else ("grass" if rng.randf() < 0.7 else "grass_short")
				elif w[8] > 0.4:
					kind = "moss_tuft"
				elif w[2] > 0.4 and rng.randf() < 0.55:
					kind = "grass_short"
				if kind == "" or not kinds.has(kind) or rng.randf() < 0.25:
					continue
				var list: Array = kinds[kind]
				var mesh: Mesh = list[rng.randi() % list.size()]
				var herb := not herbs.is_empty() and kind in ["meadow", "grass"] and rng.randf() < 0.08
				if herb:
					mesh = herbs[rng.randi() % herbs.size()]
				var kstr := "%d|%d|%d" % [mesh.get_instance_id(), floori(p.x / 96.0), floori(p.y / 96.0)]
				if not buckets.has(kstr):
					buckets[kstr] = [mesh, herb, []]
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.35))
				(buckets[kstr][2] as Array).append(Transform3D(b, Vector3(p.x, ground(p.x, p.y) - 0.05, p.y)))
	for kstr: String in buckets:
		var b: Array = buckets[kstr]
		_multimesh(b[0], _herb_mat if b[1] else _grass_mat, b[2], "Grass_" + kstr, 0.0, 140.0, false)
