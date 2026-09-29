extends RefCounted
## The snow over the land, square by square (user 2026-09-28: "we need to make it procedure beacuse we have the great
## planes as well as the water"; data/snow/snow.json): the region map the shaders sample (the snow_region global:
## RGBA8 over the world's squares, a texel TEXEL_M across, bilinear, so neighbouring squares blend over a texel) and its
## CPU twin for SnowCover.depth_at(). Per point (snow.gdshaderinc snow_depth_k, mirrored in depth_k() here):
##   hold      the square type's share of the core's depth (the deep woods keep more, the wind-swept open less)
##   exposure  the type's wind, opened up in a clearing and sheltered under the trees (the terrain's forest density)
##   face      a slope facing into the prevailing wind is scoured (thin, patchy, grass tips through it), its lee drifted
##             deep; bare wind-swept streaks lie along the wind on the open ground
##   shed      the cliffs' faces shed their snow (the shaders' slope limit)
## Also the prevailing winter wind (the snow_wind global) and the water's ice (ice_target_m: how deep the water the ice
## covers is, from the month's mean temperature). No class_name: SnowCover preloads it.

const PATH := "res://data/snow/snow.json"
## m a texel of the region map.
const TEXEL_M := 52.0

static var _data := {}
## The region map (CPU twin of the texture) and its world rect (x0, z0, width, depth).
static var image: Image
static var rect := Vector4.ZERO
## The shaders' texture: kept for the whole run (SnowPrints.texture).
static var texture: ImageTexture
## World xz the winter wind blows toward (unit).
static var wind := Vector2(1.0, 0.0)


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		_data = d if d is Dictionary else {"types": {}}
	return _data


## The type's numbers: [hold, wind, shed].
static func type_values(type_id: String) -> Vector3:
	var t: Dictionary = (data().get("types", {}) as Dictionary).get(type_id, {})
	return Vector3(float(t.get("hold", 1.0)), float(t.get("wind", 0.2)), float(t.get("shed", 0.0)))


## Bakes the region map over every square of WorldSquares' grid (one texel's margin past it: the edge squares' values)
## and the wind; publishes both to the shaders.
static func bake() -> void:
	var s := WorldSquares.size_m()
	var sqs := WorldSquares.squares()
	var lo := Vector2i(0, 0)
	var hi := Vector2i(0, 0)
	for q in sqs:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var x0 := (float(lo.x) - 0.5) * s - TEXEL_M
	var z0 := (float(lo.y) - 0.5) * s - TEXEL_M
	var w := float(hi.x - lo.x + 1) * s + 2.0 * TEXEL_M
	var d := float(hi.y - lo.y + 1) * s + 2.0 * TEXEL_M
	var nx := int(ceil(w / TEXEL_M))
	var nz := int(ceil(d / TEXEL_M))
	rect = Vector4(x0, z0, float(nx) * TEXEL_M, float(nz) * TEXEL_M)
	image = Image.create(nx, nz, false, Image.FORMAT_RGBA8)
	for j in nz:
		for i in nx:
			var p := Vector3(x0 + (i + 0.5) * TEXEL_M, 0.0, z0 + (j + 0.5) * TEXEL_M)
			var q := WorldSquares.square_at(p)
			q = Vector2i(clampi(q.x, lo.x, hi.x), clampi(q.y, lo.y, hi.y))
			var v := type_values(WorldSquares.type_id(q))
			image.set_pixel(i, j, Color(clampf(v.x * 0.5, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0), 1.0))
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	var from := deg_to_rad(float(data().get("prevailing_from_deg", 290.0)))
	# the wind blows toward the bearing opposite its source: east (x) and north (y) in the level's compass
	var toward := WorldClock.enu_to_world(Vector3(-sin(from), -cos(from), 0.0))
	wind = Vector2(toward.x, toward.z).normalized()
	publish()


static func publish() -> void:
	if texture == null:
		return
	SnowCover._global(&"snow_region", texture)
	SnowCover._global(&"snow_region_rect", Vector4(rect.x, rect.y, 1.0 / rect.z, 1.0 / rect.w))
	SnowCover._global(&"snow_wind", wind)


## The region's [hold, wind, shed] at world xz (bilinear, as the shaders' filter); the neutral [1, 0, 0] without a map.
static func region_at(x: float, z: float) -> Vector3:
	if image == null:
		return Vector3(1.0, 0.0, 0.0)
	var f := Vector2((x - rect.x) / TEXEL_M - 0.5, (z - rect.y) / TEXEL_M - 0.5)
	var w := image.get_width()
	var h := image.get_height()
	var i0 := clampi(floori(f.x), 0, w - 1)
	var j0 := clampi(floori(f.y), 0, h - 1)
	var i1 := clampi(i0 + 1, 0, w - 1)
	var j1 := clampi(j0 + 1, 0, h - 1)
	var u := clampf(f.x - floorf(f.x), 0.0, 1.0)
	var v := clampf(f.y - floorf(f.y), 0.0, 1.0)
	var c := image.get_pixel(i0, j0).lerp(image.get_pixel(i1, j0), u).lerp(
			image.get_pixel(i0, j1).lerp(image.get_pixel(i1, j1), u), v)
	return Vector3(c.r * 2.0, c.g, c.b)


## snow.gdshaderinc snow_exposure: the region's wind opened up in a clearing, sheltered under trees (`open` 0 .. 1).
static func exposure(region_wind: float, open: float) -> float:
	return lerpf(region_wind, 1.0, 0.35 * open) * (0.25 + 0.75 * open)


## snow.gdshaderinc snow_depth_k: the depth at world xz over the core's (0 scoured bare .. ~2 a deep drift), the
## ground's normal `n`, `open` 0 under a closed forest .. 1 open ground.
static func depth_k(x: float, z: float, n: Vector3, open: float) -> float:
	var r := region_at(x, z)
	var e := exposure(r.y, open)
	var face := clampf((n.x * -wind.x + n.z * -wind.y) * 6.0, -1.0, 1.0)
	var along := x * wind.x + z * wind.y
	var across := -x * wind.y + z * wind.x
	var bend := vnoise(along * 0.012 + 3.1, across * 0.012 + 3.1)
	var streak := vnoise(along * 0.02, across * 0.09 + (bend - 0.5) * 3.0)
	var k := r.x * (1.0 - 0.6 * e * maxf(face, 0.0)) * (1.0 + 0.9 * e * maxf(-face, 0.0))
	k *= 1.0 - 0.55 * e * smoothstep(0.45, 0.85, streak)
	return maxf(k, 0.0)


## The depth factor where the level stands (the terrain's normal and forest density).
static func depth_k_at(pos: Vector3) -> float:
	return depth_k(pos.x, pos.z, FrontierTerrain.normal_at(pos.x, pos.z), 1.0 - FrontierTerrain.forest_density(pos.x, pos.z))


## snow.gdshaderinc snow_hash2: a hash of a lattice point (no sine: float32 on the GPU and float64 here agree).
static func hash2(x: float, y: float) -> float:
	var a := fposmod(x * 0.1031, 1.0)
	var b := fposmod(y * 0.1031, 1.0)
	var c := a
	var dd := a * (b + 33.33) + b * (c + 33.33) + c * (a + 33.33)
	a += dd
	b += dd
	c += dd
	return fposmod((a + b) * c, 1.0)


## snow.gdshaderinc snow_vnoise: value noise on hash2's lattice, 0..1.
static func vnoise(x: float, y: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(hash2(ix, iy), hash2(ix + 1.0, iy), ux), lerpf(hash2(ix, iy + 1.0), hash2(ix + 1.0, iy + 1.0), ux), uy)


## How deep the water the ice covers is (m) at the core's date: none above freeze_c's monthly mean, reach_m below
## full_c's (the slow water frozen across).
static func ice_target_m(core: SurvivalCore) -> float:
	if core == null:
		return 0.0
	var ice: Dictionary = data().get("ice", {})
	var mean := 0.5 * (SurvivalClock.month_value(core, "low_c") + SurvivalClock.month_value(core, "high_c"))
	var fc := float(ice.get("freeze_c", 1.5))
	var full := float(ice.get("full_c", -5.5))
	return clampf((fc - mean) / maxf(fc - full, 0.1), 0.0, 1.0) * float(ice.get("reach_m", 1.6))
