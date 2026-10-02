class_name VegHarvest
extends RefCounted
## Run-time changes to FrontierVegetation's placed trees, saplings and rocks for gathering (felling, cutting,
## breaking stone). The layout arrays themselves are never changed (the layout clean-up cache,
## veg_layout.gd _fix_key, hashes them); what is gone or smaller is kept here:
##
##   var h := VegHarvest.of(level.vegetation)
##   h.near(p, 2.0)                  # gatherables round a point: trees, saplings, rocks, nearest first
##   h.remove_tree(i)                # a felled tree: its instances hidden, its trunk collider gone
##   h.remove_sapling(src, i)        # a cut sapling ("tree" or "plant" array)
##   h.shrink_rock(i, f)             # a rock quarried down to f of its size (0 = gone)
##
## What a removal touches, and why that is all of it:
##  - the drawn LODs 0-2 (TreeLod*, per 12.5 m sub-cell), the shadow proxies (TreeShadow3_* / TreeShadow4_* /
##    TreeDapple_*, per 50 m cell), the impostors (TreeImpostors_*): the tree's instance in each is found by its
##    origin (the layout position, exact in the buffers) and scaled to nothing; saplings (Plant*) and rocks
##    (Prop*) the same; a felled tree's crown comes off the forest light's canopy map (CanopyMap.remove_crown);
##  - the trunk collider (one CollisionShape3D in the cell's "Trunks_x_z" body, found by position) is freed;
##    a rock's hull (in "Rocks_x_z") is replaced by a scaled copy, or freed when it is gone;
##  - traversal: trunks are never baked (gate "tree"); a rock's ledges and beams are dropped from the player's
##    ledge graph (TravLedgeGraph.remove_source) when it is first quarried (they no longer fit it);
##  - the grass blocker map (grass.gd, built at load from the layout) still keeps the grass off the spot: the
##    stump and the rubble stay there. Nothing else caches the vegetation at run time (the canopy map above
##    aside, and PerchBranches' climbing branches: a felled tree's are dropped, PerchBranches.forget_tree).
##    Changes are not saved: a new game grows the forest back.

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")
## Cell size of the gatherables lookup grid (m).
const GRID := 4.0
const HIDDEN_SCALE := 1e-4

var veg: FrontierVegetation
var lay: Object
## Tree index -> true once felled.
var felled := {}
## Stumps: the height each felled tree was cut at (its stump, saved) and the ones chopped or grubbed out (gone for good).
var stump_h := {}
var stump_gone := {}
## "tree:i" / "plant:i" -> true once cut (saplings).
var cut := {}
## Prop index -> fraction of the rock's size left (1 untouched, 0 gone).
var rock_size := {}
## Milliseconds the lookup grid took to build (the first query after the level loads).
var build_ms := 0.0

var _grid := {}                ## Vector2i -> [[type, src, i]]
var _mm_index := {}            ## MultiMesh instance id -> {Vector3i: instance}
var _mm_basis := {}            ## "mmid:j" -> the instance's original Basis
var _rock_shape := {}          ## prop index -> original Shape3D of its collider


static func of(v: FrontierVegetation) -> VegHarvest:
	if v == null:
		return null
	if v.has_meta(&"harvest"):
		return v.get_meta(&"harvest")
	var h := VegHarvest.new()
	h.veg = v
	h.lay = v.layout
	var t0 := Time.get_ticks_usec()
	h._build_grid()
	h.build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	v.set_meta(&"harvest", h)
	return h


## The level's vegetation under the scene root (null when there is none).
static func find(tree: SceneTree) -> VegHarvest:
	var scene := tree.current_scene if tree else null
	if scene == null:
		return null
	var v := scene.get_node_or_null("Vegetation") as FrontierVegetation
	if v == null:
		var found := scene.find_children("*", "FrontierVegetation", true, false)
		v = found[0] if not found.is_empty() else null
	return VegHarvest.of(v) if v and v.layout else null


func _build_grid() -> void:
	if lay == null:
		return
	for i in lay.tree_pos.size():
		var k: int = lay.tree_kind[i]
		if k < Assets.CANOPY_COUNT:
			_add(lay.tree_pos[i], ["tree", "tree", i])
		elif k != Assets.SHRUB_HAZEL:
			_add(lay.tree_pos[i], ["sapling", "tree", i])
	for i in lay.plant_pos.size():
		var k: int = lay.plant_kind[i]
		if k >= Assets.SAPLING_PINE and k <= Assets.SAPLING_BIRCH:
			_add(lay.plant_pos[i], ["sapling", "plant", i])
	for i in lay.prop_pos.size():
		var k: int = lay.prop_kind[i]
		if k >= Assets.ROCK_FIRST and k <= Assets.ROCK_LAST:
			_add(lay.prop_pos[i], ["rock", "prop", i])


func _add(p: Vector3, e: Array) -> void:
	var c := Vector2i(floori(p.x / GRID), floori(p.z / GRID))
	if not _grid.has(c):
		_grid[c] = []
	(_grid[c] as Array).append(e)


# --- Queries -------------------------------------------------------------------------------------

## Gatherables within `r` (m, horizontal, to their surface) of `p`, nearest first:
## [{type: "tree" | "sapling" | "rock", src: "tree" | "plant" | "prop", i, pos, radius, dist}].
func near(p: Vector3, r: float) -> Array:
	var out: Array = []
	var reach := r + 4.0   # the biggest rock's half width
	var c0 := Vector2i(floori((p.x - reach) / GRID), floori((p.z - reach) / GRID))
	var c1 := Vector2i(floori((p.x + reach) / GRID), floori((p.z + reach) / GRID))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for e: Array in _grid.get(Vector2i(cx, cz), []):
				var d := describe(String(e[0]), String(e[1]), int(e[2]))
				if d.is_empty():
					continue
				var pos: Vector3 = d.pos
				var dist := Vector2(pos.x - p.x, pos.z - p.z).length() - float(d.radius)
				if dist <= r:
					d["dist"] = dist
					out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.dist) < float(b.dist))
	return out


## One gatherable ({} when it is gone): type, src, i, pos, radius (trunk / rock half width), kind, variant,
## scale, height and for trees the species data (trees.json).
func describe(type: String, src: String, i: int) -> Dictionary:
	match type:
		"tree":
			if felled.has(i):
				return {}
			var k: int = lay.tree_kind[i]
			var v: int = lay.tree_variant[i]
			var s: float = lay.tree_scale[i]
			var t := Assets.tree(k, v)
			return {"type": type, "src": src, "i": i, "pos": lay.tree_pos[i], "kind": k, "variant": v, "scale": s,
					"species": String(Assets.SPECIES[k]), "radius": float(t.get("trunk_radius", 0.3)) * s,
					"height": float(t.get("height", 18.0)) * s, "crown_radius": float(t.get("crown_radius", 4.0)) * s,
					"crown_bottom": float(t.get("crown_bottom", 4.0)) * s, "yaw": lay.tree_yaw[i],
					"custom": lay.tree_custom[i]}
		"sapling":
			if cut.has("%s:%d" % [src, i]):
				return {}
			var tree_src := src == "tree"
			var k: int = lay.tree_kind[i] if tree_src else lay.plant_kind[i]
			var v: int = lay.tree_variant[i] if tree_src else lay.plant_variant[i]
			var s: float = lay.tree_scale[i] if tree_src else lay.plant_scale[i]
			var t := Assets.tree(k, v)
			return {"type": type, "src": src, "i": i, "pos": lay.tree_pos[i] if tree_src else lay.plant_pos[i],
					"kind": k, "variant": v, "scale": s, "species": String(Assets.SPECIES[k]),
					"radius": maxf(float(t.get("trunk_radius", 0.08)) * s, 0.05), "height": float(t.get("height", 3.5)) * s}
		"rock":
			var left := float(rock_size.get(i, 1.0))
			if left <= 0.0:
				return {}
			var k: int = lay.prop_kind[i]
			var s: float = lay.prop_scale[i]
			var size: Array = Assets.prop(k).get("size", [1.0, 1.0, 1.0])
			return {"type": type, "src": src, "i": i, "pos": lay.prop_pos[i], "kind": k, "scale": s, "left": left,
					"name": String(Assets.PROPS[k].name), "size": Vector3(float(size[0]), float(size[1]), float(size[2])) * s,
					"radius": 0.42 * maxf(float(size[0]), float(size[2])) * s * left, "height": float(size[1]) * s * left}
	return {}


# --- Changes -------------------------------------------------------------------------------------

## A felled tree: every drawn instance, shadow proxy and impostor of it scaled to nothing, its trunk collider
## freed. Returns the tree's describe() (taken before the removal), {} when it was already gone.
func remove_tree(i: int) -> Dictionary:
	var d := describe("tree", "tree", i)
	if d.is_empty():
		return d
	felled[i] = true
	var p: Vector3 = lay.tree_pos[i]
	var c := FrontierVegetation.tree_cell(p)
	for mmi in _visual_nodes(["TreeLod", "TreeShadow3_", "TreeShadow4_", "TreeDapple_", "TreeImpostors_"], c):
		_set_instance_scale(mmi, p, 0.0)
	CanopyMap.remove_crown(lay, i)
	var cs := _trunk_shape(p)
	if cs:
		cs.get_parent().remove_child(cs)
		cs.queue_free()
	if veg and veg.is_inside_tree():
		veg.get_tree().call_group(PerchBranches.GROUP, &"forget_tree", i)
	return d


## A cut sapling (src "tree": a sapling in the tree arrays, "plant": in the undergrowth). Returns its
## describe() before the removal.
func remove_sapling(src: String, i: int) -> Dictionary:
	var d := describe("sapling", src, i)
	if d.is_empty():
		return d
	cut["%s:%d" % [src, i]] = true
	var p: Vector3 = d.pos
	if src == "tree":
		var c := FrontierVegetation.tree_cell(p)
		for mmi in _visual_nodes(["TreeLod", "TreeShadow3_", "TreeShadow4_", "TreeDapple_", "TreeImpostors_"], c):
			_set_instance_scale(mmi, p, 0.0)
		var cs := _trunk_shape(p)
		if cs:
			cs.get_parent().remove_child(cs)
			cs.queue_free()
	else:
		var c := Vector2i(floori(p.x / FrontierVegetation.CLUTTER_CELL), floori(p.z / FrontierVegetation.CLUTTER_CELL))
		for mmi in _visual_nodes(["Plant"], c):
			_set_instance_scale(mmi, p, 0.0)
	return d


## A rock quarried down to `f` of its size (1 whole, 0 gone): its drawn instances scaled about their base, its
## hull collider replaced by a scaled copy (freed at 0), its traversal ledges dropped.
func shrink_rock(i: int, f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	var was := float(rock_size.get(i, 1.0))
	rock_size[i] = f
	var p: Vector3 = lay.prop_pos[i]
	var c := Vector2i(floori(p.x / FrontierVegetation.CLUTTER_CELL), floori(p.z / FrontierVegetation.CLUTTER_CELL))
	for mmi in _visual_nodes(["Prop"], c):
		_set_instance_scale(mmi, p, f)
	var cs := _rock_shape_node(p)
	if cs == null:
		return
	if was >= 1.0:
		_drop_ledges(cs)
	if f <= 0.0:
		cs.get_parent().remove_child(cs)
		cs.queue_free()
		return
	if not _rock_shape.has(i):
		_rock_shape[i] = cs.shape
	var base: Shape3D = _rock_shape[i]
	if base is ConvexPolygonShape3D:
		var pts := PackedVector3Array()
		for q in (base as ConvexPolygonShape3D).points:
			pts.append(q * f)
		var hull := ConvexPolygonShape3D.new()
		hull.points = pts
		cs.shape = hull
	elif base is BoxShape3D:
		var box := BoxShape3D.new()
		box.size = (base as BoxShape3D).size * f
		cs.shape = box
		cs.position = p + cs.basis * Vector3(0, box.size.y * 0.5, 0)


## The player's ledge graph loses the ledges and beams baked from `cs` (a quarried rock).
func _drop_ledges(cs: Node) -> void:
	var src := str(cs.get_path())
	for pl in cs.get_tree().get_nodes_in_group(&"player"):
		var trav: Variant = pl.get("traversal")
		if trav == null or not is_instance_valid(trav):
			continue
		var ctl: Variant = trav.get("controller")
		if ctl == null or not is_instance_valid(ctl):
			continue
		var g: Variant = ctl.get("ledges")
		if g is TravLedgeGraph:
			(g as TravLedgeGraph).remove_source(src)


# --- Instances and colliders ---------------------------------------------------------------------

## The vegetation's MultiMeshInstance3D nodes whose name starts with one of `prefixes` and names cell `c`
## (the two numbers after the prefix's LOD digit or underscore).
func _visual_nodes(prefixes: Array, c: Vector2i) -> Array:
	var out: Array = []
	var root := veg.get_node_or_null("Visuals")
	if root == null:
		return out
	for n in root.get_children():
		var mmi := n as MultiMeshInstance3D
		if mmi == null:
			continue
		var nm := String(mmi.name)
		for pre: String in prefixes:
			if not nm.begins_with(pre):
				continue
			var parts := nm.split("_")
			if parts.size() >= 3 and int(parts[1]) == c.x and int(parts[2]) == c.y:
				out.append(mmi)
			break
	return out


func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 200.0), roundi(p.y * 200.0), roundi(p.z * 200.0))


## Scales the instance of `mmi` at origin `p` to `f` of its original size (about its origin). False when the
## MultiMesh has no instance there.
func _set_instance_scale(mmi: MultiMeshInstance3D, p: Vector3, f: float) -> bool:
	var mm := mmi.multimesh
	if mm == null:
		return false
	var id := mm.get_instance_id()
	if not _mm_index.has(id):
		var idx := {}
		for j in mm.instance_count:
			idx[_key(mm.get_instance_transform(j).origin)] = j
		_mm_index[id] = idx
	var j: int = (_mm_index[id] as Dictionary).get(_key(p), -1)
	if j < 0:
		return false
	var bk := "%d:%d" % [id, j]
	if not _mm_basis.has(bk):
		_mm_basis[bk] = mm.get_instance_transform(j).basis
	var b: Basis = _mm_basis[bk]
	mm.set_instance_transform(j, Transform3D(b * maxf(f, HIDDEN_SCALE), p))
	return true


func _body_of(prefix: String, p: Vector3) -> Node:
	var c := Vector2i(floori(p.x / FrontierVegetation.CELL), floori(p.z / FrontierVegetation.CELL))
	return veg.get_node_or_null("%s_%d_%d" % [prefix, c.x, c.y])


func _trunk_shape(p: Vector3) -> CollisionShape3D:
	var body := _body_of("Trunks", p)
	if body == null:
		return null
	for n in body.get_children():
		var cs := n as CollisionShape3D
		if cs and Vector2(cs.position.x - p.x, cs.position.z - p.z).length() < 0.01:
			return cs
	return null


func _rock_shape_node(p: Vector3) -> CollisionShape3D:
	var body := _body_of("Rocks", p)
	if body == null:
		return null
	for n in body.get_children():
		var cs := n as CollisionShape3D
		if cs and cs.position.distance_to(p) < 0.01:
			return cs
	return null


## Counts for the tests: instances of `p` found in the vegetation's MultiMeshes whose name starts with one of
## `prefixes` in cell `c`, and how many of them are scaled below `below` of their original size.
func instances_at(prefixes: Array, c: Vector2i, p: Vector3, below := 0.01) -> Vector2i:
	var found := 0
	var small := 0
	for mmi: MultiMeshInstance3D in _visual_nodes(prefixes, c):
		var mm := mmi.multimesh
		for j in mm.instance_count:
			var xf := mm.get_instance_transform(j)
			if xf.origin.distance_to(p) < 0.005:
				found += 1
				var bk := "%d:%d" % [mm.get_instance_id(), j]
				var b0: Basis = _mm_basis.get(bk, xf.basis)
				if xf.basis.x.length() < b0.x.length() * below:
					small += 1
	return Vector2i(found, small)


## Whether the trunk collider of tree `i` is still in its body (tests).
func has_trunk_collider(i: int) -> bool:
	return _trunk_shape(lay.tree_pos[i]) != null


## The rock collider of prop `i` (tests; null when gone).
func rock_collider(i: int) -> CollisionShape3D:
	return _rock_shape_node(lay.prop_pos[i])
