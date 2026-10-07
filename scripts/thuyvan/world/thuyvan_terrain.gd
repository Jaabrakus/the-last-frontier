class_name ThuyVanTerrain
extends FrontierTerrain
## A Thủy Vân region's painted ground (R1: WorldRegion "r1", its baked squares packed by tools/thuyvan_look/
## pack_r1_terrain.gd into the region block's terrain_dir). FrontierTerrain as it is (the statics, the collision, the
## chunk meshes and their LODs, the surface overlays, the edge walls; the square grid moved by the block's
## terrain_origin), with two changes:
##   material  shaders/thuyvan/tv_terrain.gdshader on the chunks (use_height_map: the frontier's flat grids lifted by the
##             square's height map), PAINT's 12-slice painted array, and the square's own painted splat (tv_splat0-2.res,
##             tools/thuyvan_art/terrain/r1_tv_splat.py) over the square: splat_rect is its 833 samples about its middle
##   grass     none of the frontier's (its atlas is the frontier's); ThuyVanDressing scatters PAINT's grass cards
## Used by ThuyVanR1Level and the vista shots (tools/thuyvan_look/vista_shots.gd). The frontier's ground and r1_grey's
## (today's valley) never come here.
##
##   var t := ThuyVanTerrain.new(); t.name = "Terrain"; add_child(t); t.build(settings)

const TV_SHADER := "res://shaders/thuyvan/tv_terrain.gdshader"
const TV_ARRAY := "res://assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp"
## Slices (terrain_slices.json) the shader falls back to past a square's splat (never met inside the region).
const FALLBACK_SLICE := 0
## The gorge walls a little warmer than the painted cliff face (under the sky's blue ambient they read cold).
const CLIFF_TINT := Vector3(1.14, 1.03, 0.82)
## The cliff face's plates stretched along the wall: they read as the sheets' level strata, not paving.
const CLIFF_STRETCH := 2.2


func build(world_settings: WorldSettings) -> void:
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	if not _ensure_data():
		push_warning("ThuyVanTerrain: no packed ground under %s (tools/thuyvan_look/pack_r1_terrain.gd)" % data_dir())
		return
	_build_collision()
	if DisplayServer.get_name() == "headless":
		return
	_build_meshes()


## Square `sq`'s painted-ground material (the root square's too: _build_meshes asks for it with sq (0, 0)).
func make_material(_ws: WorldSettings, sq := Vector2i.ZERO) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TV_SHADER)
	var dir := "" if sq == Vector2i.ZERO else SQUARE_DIR % [sq.x, sq.y]
	var tex := {}
	tex["height_map"] = ImageTexture.create_from_image(data_image(dir + "terrain_height.res"))
	tex["terrain_normal"] = ImageTexture.create_from_image(data_image(dir + "terrain_normal.res"))
	for k in 3:
		var img := data_image(dir + "tv_splat%d.res" % k)
		if img:
			tex["splat%d" % k] = ImageTexture.create_from_image(img)
	for k: String in tex:
		m.set_shader_parameter(k, tex[k])
	if sq == Vector2i.ZERO:
		textures = tex
	else:
		square_textures[sq] = tex
		square_materials[sq] = m
	var o := square_origin(sq)
	m.set_shader_parameter("use_height_map", true)
	m.set_shader_parameter("albedo_array", load(TV_ARRAY))
	m.set_shader_parameter("square_origin", Vector2(o.x, o.z))
	m.set_shader_parameter("grid_half", float(GRID_HALF))
	m.set_shader_parameter("grid_size", float(GRID_N))
	m.set_shader_parameter("skirt_depth", SKIRT_DEPTH)
	m.set_shader_parameter("splat_rect", Vector4(o.x - GRID_HALF - 0.5, o.z - GRID_HALF - 0.5, GRID_N, GRID_N))
	m.set_shader_parameter("fallback_slice", FALLBACK_SLICE)
	m.set_shader_parameter("cliff_tint", CLIFF_TINT)
	m.set_shader_parameter("cliff_stretch", CLIFF_STRETCH)
	return m
