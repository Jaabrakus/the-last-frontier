extends SceneTree
## Packs the terrain bake (tools/environment/terrain/build/*.bin, written by bake_terrain.py)
## into the resources FrontierTerrain loads at runtime (assets/environment/terrain/). Package B.
##
##   python3 tools/environment/terrain/bake_terrain.py [--square X,Y]
##   Godot --headless --path . -s tools/environment/terrain/pack_terrain.gd [-- square=X,Y]
##
## The fort's square (0, 0) packs from build/ into assets/environment/terrain/; another square from build/sq_X_Y/
## into assets/environment/terrain/sq_X_Y/ (no detail map there: only the fort has one). Coordinates stay the
## square's own (x = i - 416 about its middle): FrontierTerrain places each square at its origin.
##
## Writes (all native binary resources, no import step, export-safe):
##   terrain_height.res      Image RF 833x833   rendered height (m), 1 m grid, x = i - 416
##   terrain_collision.res   Image RF 833x833   TerrainBody heights (flat zones 5 cm down)
##   terrain_splat0.res      Image RGBA8 (mips) grass, dry grass, dirt, mud
##   terrain_splat1.res      Image RGBA8 (mips) forest floor, rock, forest density, grass height
##   terrain_normal.res      Image RGBA8 (mips) normal x/z, ambient occlusion, broadleaf litter
##   terrain_core.res        Image RGBA8 (mips) 0.25 m fort/lane detail: mud, wear, dirt, grass h
##   terrain_macro.res       Image RGBA8 (mips) 256 px tileable macro noise
##   terrain_bounds.res      Image RGF 13x13    chunk min/max height
##   terrain_grass_cells.res Image R8 104x104   max grass density per 8 m grass cell
##   terrain_overlay_dirt.res / terrain_overlay_stone.res  ConcavePolygonShape3D surface
##                           overlays (paths / brook bed, rock) 1.5 cm above the terrain
## and build/terrain_height.exr for inspection. Prints PACK TERRAIN DONE.

const BUILD_ROOT := "res://tools/environment/terrain/build/"
const OUT_ROOT := "res://assets/environment/terrain/"
const OVERLAY_LIFT := 0.015

var BUILD := BUILD_ROOT
var OUT := OUT_ROOT


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("square="):
			var xy := a.substr(7).split(",")
			if xy.size() == 2 and not (int(xy[0]) == 0 and int(xy[1]) == 0):
				BUILD = BUILD_ROOT + "sq_%d_%d/" % [int(xy[0]), int(xy[1])]
				OUT = OUT_ROOT + "sq_%d_%d/" % [int(xy[0]), int(xy[1])]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUILD + "meta.json"))
	var n := int(meta.N)
	var half := int(meta.half)
	var core_size: Array = meta.core_size
	var nch := (n - 1) / int(meta.chunk)

	var height := _image_f(BUILD + "height.bin", n, n, Image.FORMAT_RF)
	var collision := _image_f(BUILD + "collision.bin", n, n, Image.FORMAT_RF)
	_save(height, "terrain_height.res")
	_save(collision, "terrain_collision.res")
	height.save_exr(ProjectSettings.globalize_path(BUILD + "terrain_height.exr"), true)
	for name in ["splat0", "splat1", "normal"]:
		_save(_image_u8(BUILD + name + ".bin", n, n, true), "terrain_%s.res" % name)
	if int(core_size[0]) > 0:
		_save(_image_u8(BUILD + "core.bin", int(core_size[0]), int(core_size[1]), true), "terrain_core.res")
	_save(_image_u8(BUILD + "macro.bin", int(meta.macro_size), int(meta.macro_size), true), "terrain_macro.res")
	_save(_image_f(BUILD + "bounds.bin", nch, nch, Image.FORMAT_RGF), "terrain_bounds.res")
	var gc := int(meta.grass_cells)
	_save(Image.create_from_data(gc, gc, false, Image.FORMAT_R8, FileAccess.get_file_as_bytes(BUILD + "grass_cells.bin")), "terrain_grass_cells.res")

	var col := collision.get_data().to_float32_array()
	for kind in ["dirt", "stone"]:
		var cells := FileAccess.get_file_as_bytes(BUILD + "overlay_%s.bin" % kind).to_int32_array()
		var faces := PackedVector3Array()
		faces.resize(cells.size() * 6)
		var f := 0
		for c in cells:
			var j := c / n
			var i := c % n
			var x := float(i - half)
			var z := float(j - half)
			var p00 := Vector3(x, col[c] + OVERLAY_LIFT, z)
			var p10 := Vector3(x + 1.0, col[c + 1] + OVERLAY_LIFT, z)
			var p01 := Vector3(x, col[c + n] + OVERLAY_LIFT, z + 1.0)
			var p11 := Vector3(x + 1.0, col[c + n + 1] + OVERLAY_LIFT, z + 1.0)
			# Same diagonal as the height field ((x+1, z) - (x, z+1)).
			faces[f] = p00; faces[f + 1] = p10; faces[f + 2] = p01
			faces[f + 3] = p10; faces[f + 4] = p11; faces[f + 5] = p01
			f += 6
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		_save(shape, "terrain_overlay_%s.res" % kind)
		print("  overlay %s: %d cells" % [kind, cells.size()])
	print("PACK TERRAIN DONE")
	quit(0)


func _image_f(path: String, w: int, h: int, fmt: int) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	return Image.create_from_data(w, h, false, fmt, bytes)


func _image_u8(path: String, w: int, h: int, mips: bool) -> Image:
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, FileAccess.get_file_as_bytes(path))
	if mips:
		img.generate_mipmaps()
	return img


func _save(res: Resource, file: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var err := ResourceSaver.save(res, OUT + file, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("pack_terrain: cannot save %s (%d)" % [file, err])
	else:
		print("  saved %s" % file)
