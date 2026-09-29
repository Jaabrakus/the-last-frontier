class_name BuildGrass
extends RefCounted
## Keeps the grass out from under what the player builds (scripts/building/): the grass shader's blocker map
## (FrontierGrass.blocker_map, R8 at 0.25 m over the world, built once when the level loads) gets the footprints
## of the built pieces' colliders near the ground (a floor, the foot of a wall, a stake line, a hearth), the way
## the map marks the fort's. The level's own map is kept as it was loaded; after a piece is added or taken down
## the pieces' footprints are drawn again over a copy of it (at most once a frame) and the texture is updated.
## Nothing happens without grass (headless runs, grass off).

## Only the parts of a collider whose underside is within this height of the ground keep grass off.
const CLEAR := FrontierGrass.BLOCK_CLEAR
const RES := FrontierGrass.BLOCK_RES
const HALF := FrontierGrass.BLOCK_HALF
const GROW := FrontierGrass.BLOCK_GROW

var _dirty := false
var _base: PackedByteArray
var _n := 0
var _tex: ImageTexture
var _missing := false
var _tries := 0
## Texels the built pieces marked at the last update (tests).
var marked := 0


func mark() -> void:
	_dirty = true


## Redraws the footprints if something changed.
func flush(world: Node3D) -> void:
	if not _dirty or _missing:
		return
	_dirty = false
	if _tex == null and not _find(world):
		# (the level's own blocker map is made a moment after the level is built, and the fort's pieces are stamped with
		# the level: try again for a while before deciding there is no grass, headless runs, grass off)
		_tries += 1
		if _tries > 600:
			_missing = true
		else:
			_dirty = true
		return
	var data := _base.duplicate()
	marked = 0
	for c in world.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		if cs.shape == null or not (cs.get_parent() is StaticBody3D):
			continue
		marked += _raster(data, cs)
	_tex.update(Image.create_from_data(_n, _n, false, Image.FORMAT_R8, data))


func _find(world: Node3D) -> bool:
	var level := world.get_parent()
	var terrain: Node = level.get_node_or_null("Terrain") if level else null
	var g: Variant = terrain.get("grass") if terrain else null
	if not (g is FrontierGrass):
		return false
	var mat := (g as FrontierGrass).material
	var tex: Variant = mat.get_shader_parameter("blocker_map") if mat else null
	if not (tex is ImageTexture):
		return false
	_tex = tex
	var img := _tex.get_image()
	if img == null or img.get_format() != Image.FORMAT_R8:
		_tex = null
		return false
	_n = img.get_width()
	_base = img.get_data()
	return true


## Marks the texels under a box collider's footprint (grown by GROW) where its underside is near the ground.
func _raster(data: PackedByteArray, cs: CollisionShape3D) -> int:
	var xf := cs.global_transform
	var pts := PackedVector3Array()
	if cs.shape is BoxShape3D:
		var e := (cs.shape as BoxShape3D).size * 0.5
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					pts.append(xf * Vector3(e.x * sx, e.y * sy, e.z * sz))
	elif cs.shape is ConvexPolygonShape3D:
		for p in (cs.shape as ConvexPolygonShape3D).points:
			pts.append(xf * p)
	else:
		return 0
	var flat := PackedVector2Array()
	var y0 := INF
	for p in pts:
		flat.append(Vector2(p.x, p.z))
		y0 = minf(y0, p.y)
	var hull := Geometry2D.convex_hull(flat)
	var grown := Geometry2D.offset_polygon(hull, GROW)
	if not grown.is_empty():
		hull = grown[0]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in hull:
		lo = lo.min(p)
		hi = hi.max(p)
	if y0 > FrontierTerrain.height_at((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5) + CLEAR:
		return 0   # a roof, a gable, a wall on a floor: nothing on the ground
	var i0 := clampi(int(floor((lo.x + HALF) / RES)), 0, _n - 1)
	var i1 := clampi(int(floor((hi.x + HALF) / RES)), 0, _n - 1)
	var j0 := clampi(int(floor((lo.y + HALF) / RES)), 0, _n - 1)
	var j1 := clampi(int(floor((hi.y + HALF) / RES)), 0, _n - 1)
	var n := 0
	for j in range(j0, j1 + 1):
		var z := -HALF + (j + 0.5) * RES
		for i in range(i0, i1 + 1):
			var x := -HALF + (i + 0.5) * RES
			if not Geometry2D.is_point_in_polygon(Vector2(x, z), hull):
				continue
			var k := j * _n + i
			if data[k] == 0:
				data[k] = 255
				n += 1
	return n
