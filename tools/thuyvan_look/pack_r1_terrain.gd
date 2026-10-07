extends SceneTree
## Packs T4's R1 bake (tools/environment/terrain/build_regions/r1/<cell>/, bake_region.py, plus the painted splat
## tools/thuyvan_art/terrain/r1_tv_splat.py wrote beside it) into the resources the game streams for WorldRegion "r1"
## (FrontierTerrain's formats, as tools/environment/terrain/pack_terrain.gd packs the frontier's squares):
##
##   python3 tools/environment/terrain/regions/bake_region.py      # (when the git-ignored raw bake is missing)
##   python3 tools/thuyvan_art/terrain/r1_tv_splat.py
##   Godot --headless --path . -s tools/thuyvan_look/pack_r1_terrain.gd
##
## The region's squares sit on FrontierTerrain's square grid moved by the region's terrain_origin (data/world/maps/r1/
## region.json: [0, -416], since R1's rows are centred on z -1248, -416, 416, 1248): square (col - 1, row - 2), so B2 is
## square (0, 0), packed into assets/thuyvan/terrain/r1/ itself, and every other cell into sq_X_Y/ there.
## Per square: terrain_height.res, terrain_splat0/1.res, terrain_normal.res, terrain_bounds.res, terrain_grass_cells.res,
## terrain_overlay_dirt/stone.res (FrontierTerrain's) and tv_splat0/1/2.res (the painted slices' weights, Image RGBA8
## with mips; ThuyVanTerrain binds them to tv_terrain.gdshader). The region squares' collision is their height (the bake
## writes the same file twice), so no terrain_collision.res: FrontierTerrain falls back to the height. No core map (the
## fort's detail map; a region has none). The macro noise once, at the root. Prints PACK R1 TERRAIN DONE.

const BUILD := "res://tools/environment/terrain/build_regions/r1/"
const OUT := "res://assets/thuyvan/terrain/r1/"
const COLS := ["A", "B", "C"]
const OVERLAY_LIFT := 0.015


func _initialize() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cells="):
			only = Array(a.substr(6).split(","))
	var done := 0
	for ci in COLS.size():
		for row in [1, 2, 3, 4]:
			var cid := "%s%d" % [COLS[ci], row]
			if not only.is_empty() and not cid in only:
				continue
			var sq := Vector2i(ci - 1, row - 2)
			var out := OUT if sq == Vector2i.ZERO else OUT + "sq_%d_%d/" % [sq.x, sq.y]
			if _pack(BUILD + cid + "/", out, sq == Vector2i.ZERO):
				done += 1
				print("  %s -> %s" % [cid, out])
	print("PACK R1 TERRAIN DONE (%d squares)" % done)
	quit(0 if done > 0 else 1)


func _pack(src: String, out: String, root_square: bool) -> bool:
	if not FileAccess.file_exists(src + "meta.json") or not FileAccess.file_exists(src + "tv_splat0.bin"):
		printerr("pack_r1_terrain: %s is not baked (bake_region.py, then r1_tv_splat.py)" % src)
		return false
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src + "meta.json"))
	var n := int(meta.N)
	var half := int(meta.half)
	var nch := (n - 1) / int(meta.chunk)
	DirAccess.make_dir_recursive_absolute(out)
	var height := Image.create_from_data(n, n, false, Image.FORMAT_RF, FileAccess.get_file_as_bytes(src + "height.bin"))
	_save(height, out + "terrain_height.res")
	for name in ["splat0", "splat1", "normal", "tv_splat0", "tv_splat1", "tv_splat2"]:
		var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, FileAccess.get_file_as_bytes(src + name + ".bin"))
		img.generate_mipmaps()
		_save(img, out + ("terrain_%s.res" % name if not name.begins_with("tv_") else name + ".res"))
	if root_square:
		var ms := int(meta.macro_size)
		var macro := Image.create_from_data(ms, ms, false, Image.FORMAT_RGBA8, FileAccess.get_file_as_bytes(src + "macro.bin"))
		macro.generate_mipmaps()
		_save(macro, out + "terrain_macro.res")
	_save(Image.create_from_data(nch, nch, false, Image.FORMAT_RGF, FileAccess.get_file_as_bytes(src + "bounds.bin")),
			out + "terrain_bounds.res")
	var gc := int(meta.grass_cells)
	_save(Image.create_from_data(gc, gc, false, Image.FORMAT_R8, FileAccess.get_file_as_bytes(src + "grass_cells.bin")),
			out + "terrain_grass_cells.res")
	var col := height.get_data().to_float32_array()
	for kind in ["dirt", "stone"]:
		var cells := FileAccess.get_file_as_bytes(src + "overlay_%s.bin" % kind).to_int32_array()
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
			faces[f] = p00; faces[f + 1] = p10; faces[f + 2] = p01
			faces[f + 3] = p10; faces[f + 4] = p11; faces[f + 5] = p01
			f += 6
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		_save(shape, out + "terrain_overlay_%s.res" % kind)
	return true


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("pack_r1_terrain: cannot save %s (%d)" % [path, err])
