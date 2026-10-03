class_name MinimapBake
extends RefCounted
## The classic HUD minimap's picture of the land (HudMinimap; owner 2026-10-03: "can the hud be similar to world of warcraft
## vanilla?", in the game's own art): a hand-tinted survey map of every square with ground, baked ONCE per level from the
## baked terrain (FrontierTerrain's height field, splat weights and forest density: the arrays themselves, not the
## per-point statics), the river (WorldRiver: its centre, level, banks and rapids, row by row) and the woods (the canopy
## map's crowns where the level baked one, CanopyMap; the terrain's forest density elsewhere):
##   ground    the splat layers' tints (grass, dry grass, dirt, mud, forest floor, rock), the flat zones a trampled ochre,
##             the fort's floor and the range lane's dirt from the core detail map
##   relief    a hillshade from the north-west of the image and a contour every CONTOUR_M (each INDEX_EVERY-th darker)
##   woods     the crowns (or the density) a deep green over the ground, stippled so it reads as trees, not paint
##   water     the river blue, deeper darker, white at its rapids, a dark line along its banks
##   fort      the stockade's walls as a dark rule, its gate gap in the north (-Z) wall (not on a start with nothing)
##   past it   the leather of the frame (no square there), darkened past the world's walls
## Cheap at run time: one RGB8 image (+ mipmaps) at M_PER_PX over all the squares' rect, baked on a worker thread at the
## level's start (inputs() gathers the arrays on the main thread; bake_image() touches nothing else), and cached under
## CACHE_DIR by a key of its inputs (the next launch loads a PNG instead of baking).
##   var b := MinimapBake.new(); b.start()       # threaded (b.start(false): at once); b.poll() true when done
##   b.texture, b.rect (world x, z, width, depth: the image's corner and span), b.uv_of(Vector2(x, z)), b.ms, b.cached
##   MinimapBake.shared()                        # the level's one bake (every HUD shares it)

const M_PER_PX := 2.0
const CONTOUR_M := 5.0
const INDEX_EVERY := 5
const CACHE_DIR := "user://cache/minimap/"
const CACHE_VERSION := 3
const SELF_PATH := "res://scripts/ui/hud_classic/minimap_bake.gd"
const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")

## The tints (linear 0..1 RGB): an old survey map's washes, warm and a little faded.
const C_GRASS := Color(0.56, 0.6, 0.37)
const C_DRY := Color(0.7, 0.64, 0.42)
const C_DIRT := Color(0.6, 0.48, 0.33)
const C_MUD := Color(0.42, 0.35, 0.26)
const C_FLOOR := Color(0.44, 0.42, 0.28)
const C_ROCK := Color(0.6, 0.58, 0.54)
const C_FLAT := Color(0.68, 0.6, 0.42)
const C_WOOD := Color(0.14, 0.23, 0.12)
const C_WOOD_DARK := Color(0.08, 0.15, 0.08)
const C_WATER := Color(0.3, 0.47, 0.56)
const C_WATER_DEEP := Color(0.17, 0.3, 0.42)
const C_RAPID := Color(0.78, 0.84, 0.84)
const C_BANK := Color(0.16, 0.2, 0.2)
const C_WALL := Color(0.24, 0.15, 0.08)
const C_PARCH := Color(0.74, 0.66, 0.5)
const C_LEATHER := Color(0.13, 0.09, 0.06)

static var _shared: MinimapBake

var rect := Rect2()              ## world (x, z) of the image's corner, and its span (m)
var image: Image
var texture: ImageTexture
var ms := 0.0                    ## the bake's (or the cache load's) time
var cached := false              ## loaded from the cache
var done := false
var _task := -1
var _inputs := {}
var _result: Image
var _t0 := 0


## The level's one bake (begun on first ask, threaded); a new one when the ground changed (another level, a start with
## nothing after one with the fort).
static func shared() -> MinimapBake:
	var key := _key_now()
	if _shared == null or String(_shared._inputs.get("key", "")) != key:
		_shared = MinimapBake.new()
		_shared.start()
	return _shared


## Begins the bake: the cache when it has this key, else bake_image() on a worker thread (`threaded` false: here, now).
func start(threaded := true, use_cache := true) -> void:
	_t0 = Time.get_ticks_usec()
	_inputs = inputs()
	rect = _inputs.rect
	if use_cache and _load_cache():
		return
	if threaded:
		_task = WorkerThreadPool.add_task(_work, false, "minimap bake")
	else:
		_result = bake_image(_inputs)
		_finish(use_cache)


## Whether the picture is ready (takes a finished thread's image onto the texture).
func poll() -> bool:
	if done:
		return true
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish(true)
	return done


## Waits for a threaded bake (tests).
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish(true)


## The texture's uv of world (x, z).
func uv_of(xz: Vector2) -> Vector2:
	return (xz - rect.position) / rect.size if rect.size.x > 0.0 else Vector2(0.5, 0.5)


func _work() -> void:
	_result = bake_image(_inputs)


func _finish(save: bool) -> void:
	image = _result
	_result = null
	if image == null:
		image = Image.create(8, 8, false, Image.FORMAT_RGB8)
		image.fill(C_LEATHER)
	if save:
		_save_cache()
	_publish()


func _publish() -> void:
	if not image.has_mipmaps():
		image.generate_mipmaps()
	texture = ImageTexture.create_from_image(image)
	ms = (Time.get_ticks_usec() - _t0) / 1000.0
	done = true
	for big in ["sq", "core", "canopy", "river_x", "river_level", "river_rapid"]:
		_inputs.erase(big)       # (the big arrays go once the picture is made)


# --- Inputs (main thread) ----------------------------------------------------------------------------------------

## What the bake reads, gathered here so the thread touches no engine state: each square's arrays, the river row by row,
## the canopy's crowns, the flags; and the key that names the result.
static func inputs() -> Dictionary:
	var ok := FrontierTerrain.data_loaded()
	var sqs: Array[Vector2i] = [Vector2i.ZERO]
	if ok:
		sqs = FrontierTerrain.squares()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sq in sqs:
		var o := FrontierTerrain.square_origin(sq)
		lo = lo.min(Vector2(o.x, o.z) - Vector2.ONE * FrontierTerrain.GRID_HALF)
		hi = hi.max(Vector2(o.x, o.z) + Vector2.ONE * FrontierTerrain.GRID_HALF)
	var r := Rect2(lo, hi - lo)
	var w := int(ceil(r.size.x / M_PER_PX))
	var h := int(ceil(r.size.y / M_PER_PX))
	var d := {"rect": r, "w": w, "h": h, "ok": ok, "open": FrontierTerrain.open_ground, "key": _key_now()}
	if not ok:
		return d
	var squares := []
	for sq in sqs:
		var dir := "" if sq == Vector2i.ZERO else FrontierTerrain.SQUARE_DIR % [sq.x, sq.y]
		var hi_img := FrontierTerrain.data_image(dir + "terrain_height.res")
		var s0 := FrontierTerrain.data_image(dir + "terrain_splat0.res")
		var s1 := FrontierTerrain.data_image(dir + "terrain_splat1.res")
		if hi_img == null or s0 == null or s1 == null or hi_img.get_width() != FrontierTerrain.GRID_N:
			continue
		var o := FrontierTerrain.square_origin(sq)
		squares.append({"sq": sq, "ox": o.x, "oz": o.z, "h": hi_img.get_data().to_float32_array(),
				"s0": s0.get_data(), "s1": s1.get_data()})
	d["sq"] = squares
	var core := FrontierTerrain.data_image("terrain_core.res")
	d["core"] = core.get_data() if core != null else PackedByteArray()
	# the river: its centre and level for each row of the image (and its rapids' white), where it has ground
	var xc := PackedFloat32Array()
	var lv := PackedFloat32Array()
	var rp := PackedFloat32Array()
	xc.resize(h)
	lv.resize(h)
	rp.resize(h)
	var zr := WorldRiver.z_range() if WorldRiver.has_water() else Vector2.ZERO
	for j in h:
		var z := r.position.y + (j + 0.5) * M_PER_PX
		var wet := zr != Vector2.ZERO and z >= zr.x and z <= zr.y
		xc[j] = WorldRiver.x_at(z) if wet else 1e9
		lv[j] = WorldRiver.level_at(z) if wet else -1e9
		rp[j] = WorldRiver.rapid_at(z) if wet else 0.0
	d["river_x"] = xc
	d["river_level"] = lv
	d["river_rapid"] = rp
	d["bank"] = WorldRiver.bank() if WorldRiver.has_water() else 0.0
	# the crowns the level baked (windowed runs: CanopyMap), else the terrain's forest density
	var cimg: Image = CanopyMap.image
	if cimg != null and cimg.get_width() == CanopyMap.MAP_SIZE:
		var c := cimg.duplicate() as Image
		if c.get_format() != Image.FORMAT_RG8:
			c.convert(Image.FORMAT_RG8)
		d["canopy"] = c.get_data()
		d["leaves"] = CanopyMap.leaves
	return d


## The key of what the bake would read now (the squares, the terrain files' sizes, the river, a start with nothing, the
## crowns' presence): the cache's file name.
static func _key_now() -> String:
	var parts := PackedStringArray([str(CACHE_VERSION), str(M_PER_PX), str(FrontierTerrain.open_ground),
			str(FileAccess.get_modified_time(SELF_PATH))])      # (this file changed: the look may have)
	if FrontierTerrain.data_loaded():
		for sq in FrontierTerrain.squares():
			var dir := "" if sq == Vector2i.ZERO else FrontierTerrain.SQUARE_DIR % [sq.x, sq.y]
			var p := FrontierTerrain.DATA_DIR + dir + "terrain_height.res"
			parts.append("%s:%d" % [sq, FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else 0])
	else:
		parts.append("flat")
	parts.append(JSON.stringify(WorldRiver.data()))
	parts.append("canopy" if CanopyMap.image != null else "density")
	return "%08x" % ("|".join(parts)).hash()


func _cache_path() -> String:
	return CACHE_DIR + "map_%s.png" % String(_inputs.get("key", "none"))


func _load_cache() -> bool:
	var p := _cache_path()
	if not FileAccess.file_exists(p):
		return false
	var img := Image.load_from_file(p)
	if img == null or img.get_width() != int(_inputs.w) or img.get_height() != int(_inputs.h):
		return false
	image = img
	cached = true
	_publish()
	return true


func _save_cache() -> void:
	if image == null or image.get_width() < 16 or not bool(_inputs.get("ok", false)):
		return
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var copy := image.duplicate() as Image
	copy.clear_mipmaps()
	var path := _cache_path()
	if copy.save_png(path) != OK:
		return
	# (the pictures of other keys go: an older look, other ground; only this one is kept)
	for f in DirAccess.get_files_at(CACHE_DIR):
		if f.begins_with("map_") and f.ends_with(".png") and CACHE_DIR + f != path:
			DirAccess.remove_absolute(CACHE_DIR + f)


# --- The bake (any thread) -----------------------------------------------------------------------------------------

## The map image from inputs() (touches nothing but `d`).
static func bake_image(d: Dictionary) -> Image:
	var w := int(d.w)
	var h := int(d.h)
	var r: Rect2 = d.rect
	var out := PackedByteArray()
	out.resize(w * h * 3)
	if not bool(d.get("ok", false)):
		var img0 := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGB8)
		img0.fill(C_PARCH)
		return img0
	var n := FrontierTerrain.GRID_N
	var half := float(FrontierTerrain.GRID_HALF)
	var sqm := FrontierTerrain.SQUARE_M
	var squares: Array = d.sq
	var by_sq := {}
	for s: Dictionary in squares:
		by_sq[s.sq] = s
	var open := bool(d.open)
	var core: PackedByteArray = d.core
	var canopy: PackedByteArray = d.get("canopy", PackedByteArray())
	var leaves := float(d.get("leaves", 1.0))
	var cmap := CanopyMap.MAP_SIZE
	var corg := CanopyMap.ORIGIN
	var rx: PackedFloat32Array = d.river_x
	var rl: PackedFloat32Array = d.river_level
	var rr: PackedFloat32Array = d.river_rapid
	var bank := float(d.bank)
	var step := int(M_PER_PX)
	var fort_half := FrontierStructures.FORT_HALF
	var gate_half := FrontierStructures.GATE_HALF
	for j in h:
		var z := r.position.y + (j + 0.5) * M_PER_PX
		var row_xc := rx[j]
		var row_lv := rl[j]
		for i in w:
			var x := r.position.x + (i + 0.5) * M_PER_PX
			var o := (j * w + i) * 3
			var sq := Vector2i(floori((x + half) / sqm), floori((z + half) / sqm))
			var s: Variant = by_sq.get(sq)
			if s == null:
				out[o] = int(C_LEATHER.r * 255.0)
				out[o + 1] = int(C_LEATHER.g * 255.0)
				out[o + 2] = int(C_LEATHER.b * 255.0)
				continue
			var sd: Dictionary = s
			var lx := x - float(sd.ox)
			var lz := z - float(sd.oz)
			var gi := clampi(int(lx + half), 0, n - 1)
			var gj := clampi(int(lz + half), 0, n - 1)
			var hts: PackedFloat32Array = sd.h
			var s0: PackedByteArray = sd.s0
			var s1: PackedByteArray = sd.s1
			var k := gj * n + gi
			var flat := not open and sq == Vector2i.ZERO and ((absf(x) <= FrontierTerrain.FORT_FLAT_HALF and absf(z) <= FrontierTerrain.FORT_FLAT_HALF) \
					or (absf(x) <= FrontierTerrain.LANE_FLAT_HALF_X and z >= FrontierTerrain.LANE_FLAT_Z_MIN and z <= FrontierTerrain.LANE_FLAT_Z_MAX))
			var hh := 0.0 if flat else hts[k]
			# relief: the slope toward the north-west of the image lit, the far side shaded
			var ia := clampi(gi - step, 0, n - 1)
			var ib := clampi(gi + step, 0, n - 1)
			var ja := clampi(gj - step, 0, n - 1)
			var jb := clampi(gj + step, 0, n - 1)
			var dhx := (hts[gj * n + ib] - hts[gj * n + ia]) / float(maxi(ib - ia, 1))
			var dhz := (hts[jb * n + gi] - hts[ja * n + gi]) / float(maxi(jb - ja, 1))
			if flat:
				dhx = 0.0
				dhz = 0.0
			var lit := clampf(1.0 + (dhx + dhz) * 0.55, 0.6, 1.3)
			# the ground's layers
			var k4 := k * 4
			var wg := float(s0[k4])
			var wd := float(s0[k4 + 1])
			var wdi := float(s0[k4 + 2])
			var wm := float(s0[k4 + 3])
			var wf := float(s1[k4])
			var wr := float(s1[k4 + 1])
			var dens := float(s1[k4 + 2]) / 255.0
			var tot := maxf(wg + wd + wdi + wm + wf + wr, 1.0)
			var col := (C_GRASS * wg + C_DRY * wd + C_DIRT * wdi + C_MUD * wm + C_FLOOR * wf + C_ROCK * wr) / tot
			if flat:
				dens = 0.0
				col = C_FLAT
				# the fort's floor and the range lane: the core detail map's dirt and mud
				var cu := (x - FrontierTerrain.CORE_X0) / FrontierTerrain.CORE_W
				var cv := (z - FrontierTerrain.CORE_Z0) / FrontierTerrain.CORE_D
				if cu > 0.0 and cv > 0.0 and cu < 1.0 and cv < 1.0 and not core.is_empty():
					var ck := (int(cv * FrontierTerrain.CORE_NZ) * FrontierTerrain.CORE_NX + int(cu * FrontierTerrain.CORE_NX)) * 4
					col = col.lerp(C_DIRT, float(core[ck + 2]) / 255.0 * 0.8).lerp(C_MUD, float(core[ck]) / 255.0 * 0.6)
			# the woods: the crowns where the level baked them, else the density
			if not canopy.is_empty() and sq == Vector2i.ZERO:
				var ci := int(x - corg.x)
				var cj := int(z - corg.y)
				if ci >= 0 and cj >= 0 and ci < cmap and cj < cmap:
					var ck2 := (cj * cmap + ci) * 2
					var cr := float(canopy[ck2]) / 255.0
					var cg := float(canopy[ck2 + 1]) / 255.0
					dens = cg + (cr - cg) * leaves
			if dens > 0.02:
				# stippled: each pixel its own small darkening, so a wood reads as crowns
				var hsh := ((i * 73856093) ^ (j * 19349663)) & 1023
				var st := float(hsh) / 1023.0
				var wood := C_WOOD.lerp(C_WOOD_DARK, st * 0.8)
				col = col.lerp(wood, clampf(dens * 1.1, 0.0, 0.92))
			col *= lit
			# contours: a line where the band of CONTOUR_M changes to the next pixel east or south
			if not flat:
				var band := floori(hh / CONTOUR_M)
				var he := hts[gj * n + clampi(gi + step, 0, n - 1)]
				var hs := hts[clampi(gj + step, 0, n - 1) * n + gi]
				var be := floori(he / CONTOUR_M)
				var bs := floori(hs / CONTOUR_M)
				if be != band or bs != band:
					var top := maxi(band, maxi(be, bs))
					col *= 0.72 if posmod(top, INDEX_EVERY) == 0 else 0.86
			# the river: under its level within its banks
			if absf(x - row_xc) <= bank and hh < row_lv:
				var depth := row_lv - hh
				var wc := C_WATER.lerp(C_WATER_DEEP, clampf(depth / 1.6, 0.0, 1.0))
				wc = wc.lerp(C_RAPID, rr[j] * 0.75)
				# its banks: a dark line where the next pixel along the row is dry
				var gl := clampi(gi - step, 0, n - 1)
				var gr := clampi(gi + step, 0, n - 1)
				var edge := absf(x - M_PER_PX - row_xc) > bank or absf(x + M_PER_PX - row_xc) > bank \
						or hts[gj * n + gl] >= row_lv or hts[gj * n + gr] >= row_lv
				if not edge and j > 0 and j < h - 1:
					edge = absf(x - rx[j - 1]) > bank or absf(x - rx[j + 1]) > bank \
							or hts[clampi(gj - step, 0, n - 1) * n + gi] >= rl[j - 1] or hts[clampi(gj + step, 0, n - 1) * n + gi] >= rl[j + 1]
				col = C_BANK if edge else wc
			# the stockade: its walls a dark rule, the gate open in the north (-Z) wall
			if not open and sq == Vector2i.ZERO:
				var ax := absf(x)
				var az := absf(z)
				var on_ns := absf(az - fort_half) < M_PER_PX * 0.75 and ax <= fort_half + M_PER_PX * 0.5
				var on_ew := absf(ax - fort_half) < M_PER_PX * 0.75 and az <= fort_half + M_PER_PX * 0.5
				if (on_ns and not (z < 0.0 and ax < gate_half)) or on_ew:
					col = C_WALL
			# past the world's walls: darker (the land goes on, the player cannot)
			if absf(lx) > FrontierTerrain.WORLD_HALF or absf(lz) > FrontierTerrain.WORLD_HALF:
				var nb := Vector2i(sq.x + (1 if lx > 0.0 else -1), sq.y) if absf(lx) > FrontierTerrain.WORLD_HALF else sq
				var nb2 := Vector2i(sq.x, sq.y + (1 if lz > 0.0 else -1)) if absf(lz) > FrontierTerrain.WORLD_HALF else sq
				if (nb != sq and not by_sq.has(nb)) or (nb2 != sq and not by_sq.has(nb2)):
					col = col.lerp(C_LEATHER, 0.55)
			# the paper: every wash a little toward the parchment
			col = col.lerp(C_PARCH, 0.1)
			out[o] = clampi(int(col.r * 255.0), 0, 255)
			out[o + 1] = clampi(int(col.g * 255.0), 0, 255)
			out[o + 2] = clampi(int(col.b * 255.0), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, out)
