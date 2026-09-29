extends RefCounted
## The forest canopy as a map (forest lighting, 2026-09-26, "fix the lighting in the forest"): how much of the sky the
## tree crowns cover over every square metre of the level, baked once from the vegetation layout (VegLayout) when the
## level is built. No class_name: vegetation.gd and ForestLight preload this file.
##
## The map (MAP_SIZE x MAP_SIZE texels of TEXEL m, centred on the level, RG8 with mipmaps) is the union of every canopy
## tree's crown seen from below: a soft disc of the crown's radius round its centre (trees.json crown_center, turned by
## the tree's yaw, x its scale), as opaque as the species' crown (CROWN_OPACITY), stacked as 1 - prod(1 - a). Saplings
## and shrubs are not in it (they stand under the canopy). Its mip levels are the cover averaged over 2, 4, 8, 16 m.
## R: every crown; G: the evergreens' alone (the pines and the hemlocks keep theirs in winter). The broadleaves' year
## (SeasonLeaves, user 2026-09-28: bare in winter) sets `leaves` (the canopy_leaves global): the cover in use is
## G + (R - G) x leaves, so the woods under bare oaks and maples open to the sky while a pine stand stays dim.
##
## Shaders read it through res://shaders/common/canopy.gdshaderinc (the global uniforms canopy_map / canopy_rect,
## declared in project.godot [shader_globals]): the terrain, the grass, the ferns and the trees darken the sky light
## and its reflections under a closed canopy and take the light the canopy scatters down (ForestLight sets
## canopy_light every frame). A black map (no vegetation, other scenes) is no canopy: every term is neutral.
## The CPU copy (cover_at / cover_around) drives ForestLight's eye adaptation and fog under the trees.
##
## Also here: the dappled crown blobs (dapple_material), the near-camera shadow casters that turn the canopy's shade
## into shade with sunflecks.

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

const TEXEL := 1.0                      ## m per texel
const MAP_SIZE := 800                   ## texels: the terrain's +-400 m
const ORIGIN := Vector2(-400.0, -400.0) ## world xz of texel (0, 0)'s corner
## Crown opacity seen from below per species (the gaps inside a crown: pine open, hemlock and maple dense).
const CROWN_OPACITY := {Assets.WHITE_PINE: 0.72, Assets.HEMLOCK: 0.9, Assets.OAK: 0.85, Assets.MAPLE: 0.9, Assets.BIRCH: 0.6}
const DAPPLE_SHADER := "res://shaders/vegetation/canopy_dapple.gdshader"
## The sky's tileable noise (tools/environment/lighting/make_sky_noise.py): its cellular G channel cuts the sunflecks.
const DAPPLE_NOISE := "res://assets/environment/sky/sky_noise.png"

static var image: Image              ## the L8 map (mip 0), for the CPU queries
static var texture: ImageTexture
static var _stamps := {}
static var _dapple: ShaderMaterial
## How leafy the broadleaves' crowns are now, 1 summer .. 0 bare (SeasonLeaves sets it with the canopy_leaves global).
static var leaves := 1.0


## Bakes the map from the layout's trees and publishes it to the shaders (canopy_map, canopy_rect). Returns ms.
static func bake(layout: RefCounted) -> float:
	var t0 := Time.get_ticks_usec()
	var img := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	# the broadleaves first (red stamps: R only), then the evergreens (yellow: R and G): a blend takes from the other
	# channels what it adds to its own, and G is still 0 under every broadleaf stamp
	for ever: bool in [false, true]:
		for i in (layout.tree_pos as PackedVector3Array).size():
			if _evergreen(layout.tree_kind[i]) != ever:
				continue
			var crown := _crown(layout, i)
			if not crown.is_empty():
				var stamp: Image = crown[0]
				img.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), crown[1])
	img.convert(Image.FORMAT_RG8)
	image = img.duplicate() as Image
	img.generate_mipmaps()
	texture = ImageTexture.create_from_image(img)
	publish()
	return (Time.get_ticks_usec() - t0) / 1000.0


## A felled tree's crown off the map (VegHarvest.remove_tree): each texel's cover undone by the crown's stamp
## (the bake stacks them as 1 - prod(1 - a)), the texture and its mips updated. Returns ms (0 when the tree has no
## crown on the map or nothing is baked).
static func remove_crown(layout: Object, i: int) -> float:
	if image == null or texture == null:
		return 0.0
	var crown := _crown(layout, i)
	if crown.is_empty():
		return 0.0
	var t0 := Time.get_ticks_usec()
	var stamp: Image = crown[0]
	var at: Vector2i = crown[1]
	var ever := _evergreen(layout.tree_kind[i])
	for y in stamp.get_height():
		for x in stamp.get_width():
			var mx := at.x + x
			var my := at.y + y
			if mx < 0 or my < 0 or mx >= MAP_SIZE or my >= MAP_SIZE:
				continue
			var a := stamp.get_pixel(x, y).a
			if a <= 0.0:
				continue
			var c := image.get_pixel(mx, my)
			var r := clampf(1.0 - (1.0 - c.r) / maxf(1.0 - a, 0.05), 0.0, 1.0)
			var g := clampf(1.0 - (1.0 - c.g) / maxf(1.0 - a, 0.05), 0.0, 1.0) if ever else c.g
			image.set_pixel(mx, my, Color(r, minf(g, r), 0.0))
	var img := image.duplicate() as Image
	img.generate_mipmaps()
	texture.update(img)
	return (Time.get_ticks_usec() - t0) / 1000.0


## Tree i's crown as the bake stamps it: [stamp Image, its top-left texel], [] for a tree with no crown on the map.
static func _crown(layout: Object, i: int) -> Array:
	var k: int = layout.tree_kind[i]
	if not CROWN_OPACITY.has(k):
		return []
	var info := Assets.tree(k, layout.tree_variant[i])
	var s: float = layout.tree_scale[i]
	var cc: Array = info.get("crown_center", [0.0, 0.0, 0.0])
	var off := Vector3(float(cc[0]), 0.0, float(cc[2])).rotated(Vector3.UP, layout.tree_yaw[i]) * s
	var r := float(info.get("crown_radius", 4.0)) * s
	var stamp := _stamp(r, CROWN_OPACITY[k], _evergreen(k))
	var half := stamp.get_width() / 2
	var pos: Vector3 = layout.tree_pos[i]
	var c := (Vector2(pos.x + off.x, pos.z + off.z) - ORIGIN) / TEXEL
	return [stamp, Vector2i(roundi(c.x) - half, roundi(c.y) - half)]


## Sets the shader globals to the baked map (again after a scene that cleared them).
static func publish() -> void:
	if texture == null:
		return
	_set_global(&"canopy_map", texture)
	var span := MAP_SIZE * TEXEL
	_set_global(&"canopy_rect", Vector4(ORIGIN.x, ORIGIN.y, 1.0 / span, 1.0 / span))


## Crown cover 0..1 at world (x, z) now (bilinear on the 1 m map; the broadleaves' by `leaves`); 0 off the map or
## before a bake.
static func cover_at(x: float, z: float) -> float:
	if image == null:
		return 0.0
	var f := (Vector2(x, z) - ORIGIN) / TEXEL - Vector2(0.5, 0.5)
	var i := Vector2i(floori(f.x), floori(f.y))
	if i.x < 0 or i.y < 0 or i.x >= MAP_SIZE - 1 or i.y >= MAP_SIZE - 1:
		return 0.0
	var u := f - Vector2(i)
	var a := lerpf(_cover(image.get_pixel(i.x, i.y)), _cover(image.get_pixel(i.x + 1, i.y)), u.x)
	var b := lerpf(_cover(image.get_pixel(i.x, i.y + 1)), _cover(image.get_pixel(i.x + 1, i.y + 1)), u.x)
	return lerpf(a, b, u.y)


static func _cover(c: Color) -> float:
	return c.g + (c.r - c.g) * leaves


## Mean cover over a disc of `radius` m round (x, z): the centre and two rings of 8.
static func cover_around(x: float, z: float, radius: float) -> float:
	var sum := cover_at(x, z)
	for ring in 2:
		var rr := radius * (0.5 if ring == 0 else 1.0)
		for k in 8:
			var a := (k + 0.5 * ring) * TAU / 8.0
			sum += cover_at(x + cos(a) * rr, z + sin(a) * rr)
	return sum / 17.0


## Shadow-only material of the dappled crown blobs (the layout's LOD4 crown hulls near the camera):
## shaders/vegetation/canopy_dapple.gdshader cuts sunflecks through them.
static func dapple_material() -> ShaderMaterial:
	if _dapple == null:
		_dapple = ShaderMaterial.new()
		_dapple.shader = load(DAPPLE_SHADER)
		_dapple.set_shader_parameter(&"dapple_noise", load(DAPPLE_NOISE))
	return _dapple


static func _evergreen(kind: int) -> bool:
	return Assets.autumn_of(Assets.SPECIES[kind]).is_empty()


## A soft disc of radius r m (texels at TEXEL), alpha = opacity inside 0.55 r, falling to 0 at 1.05 r: yellow (R and G)
## for an evergreen, red (R) for a broadleaf.
static func _stamp(r: float, opacity: float, ever: bool) -> Image:
	var rq := snappedf(clampf(r, 0.5, 12.0), 0.25)
	var key := "%.2f_%.2f_%s" % [rq, opacity, ever]
	if _stamps.has(key):
		return _stamps[key]
	var half := ceili(rq * 1.05 / TEXEL) + 1
	var n := half * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - half, y - half).length() * TEXEL
			var a := opacity * (1.0 - smoothstep(0.55 * rq, 1.05 * rq, d))
			img.set_pixel(x, y, Color(1, 1.0 if ever else 0.0, 0, a))
	_stamps[key] = img
	return img


static func _set_global(uniform: StringName, value: Variant) -> void:
	if ProjectSettings.has_setting("shader_globals/" + String(uniform)):
		RenderingServer.global_shader_parameter_set(uniform, value)
