extends SceneTree
## Overlap / grounding check of every scattered object and the structures (2026-09-24 playtest:
## "several other things graphically clip"). Headless is fine; wrap it in a time limit:
##
##   Godot --headless --path . -s tools/environment/check_clipping.gd -- --no-capture [verbose=1]
##       [out=<json>] [raw=1]
##
## It loads the level (for the structure colliders and the live vegetation colliders), rebuilds
## the full vegetation layout with clutter (VegLayout.build(true, 1.0), exactly what the high
## preset draws) and tests, with the footprint helpers the layout itself uses
## (scripts/world/vegetation/veg_geom.gd):
##
##   prop_vs_trunk      stumps, logs, rocks, roots, brush, ferns through a tree trunk
##   prop_vs_prop       stumps / logs / rocks / roots / brush through each other (ferns: core)
##   plant_vs_solid     sapling / shrub stems in a trunk, stump, log, rock, root cluster or brush
##   plant_vs_plant     two sapling / shrub stems grown into each other (2026-09-25)
##   veg_vs_structure   any vegetation footprint within 0.3 m of a wall, ramp, walkway, building,
##                      crate, barrel, hay, rail, dummy or other structure collider
##   veg_vs_fort_mesh   any vegetation footprint within 0.3 m of the textured fort's visual meshes
##                      (package D, built here with force_visuals: log ends, eaves, gable and
##                      gate overhangs, walkway joists, props without colliders), and tree crowns
##                      (core spheres) through them (2026-09-25)
##   veg_in_flat_zone   vegetation footprints (and low foliage < 3 m) inside the fort clearing or
##                      the range lane (the flat zones stay clear, spec 7.3)
##   on_path            anything but ferns on a trampled dirt path outside the flat zones
##   floating           a prop whose bottom points hang more than 6 cm over the terrain
##   sunk               stumps buried > 45 % / logs > 70 % of their thickness / roots, brush > 60 %
##   trunk_floating     a tree trunk, sapling stem or shrub base whose bottom (mesh space) does
##                      not reach the terrain all round it on a slope (2026-09-25)
##   foliage_in_ground  tree / sapling / shrub foliage cards (and low branches) more than 12 cm
##                      under the terrain. Measured from the plant's own base: parts its model
##                      puts below the base (a shrub's stems, the edge hemlock's skirt boughs, the
##                      hemlock saplings' lowest branches) count only for what a slope adds; they
##                      are listed on the "CLIP info below_base" line (2026-09-25)
##   crown_through_trunk a neighbour's bare trunk passing through the dense core of a crown
##   collider_mismatch  the live (headless) colliders differ from the layout's trunks / props, or
##                      the headless layout places trees / collider props differently from the
##                      full one (the clean-up pass must not depend on the clutter)
##   fix_cache          the baked clean-up results (assets/environment/vegetation/layout_fixes.json,
##                      tools/environment/vegetation/bake_layout_fixes.gd) differ from a live run of
##                      the pass, or are not used for this layout (rebake; 2026-09-25)
##   grass_in_solid     grass growing under a solid footprint (structures, stumps, logs, rocks)
##                      that the grass blocker map does not remove
##   grass_in_fort_mesh grass growing through a low (< 0.7 m over the ground) part of the fort's
##                      visual meshes that the blocker map does not remove (2026-09-25)
##   structure_floating a level structure collider standing on the ground (bottom < 0.15 m over
##                      it) with the terrain more than 6 cm under its bottom (2026-09-25)
##
## Prints CLIP <category> hits=<n> [examples] per category and ends with CLIPPING CHECK PASSED
## (exit 0) or CLIPPING CHECK FAILED (exit 1). out=<json> writes every hit with the layout index
## of the objects involved ([kind, index], kind = tree / prop / plant). raw=1 checks the layout
## without its clipping clean-up pass (VegLayout.fix_clipping = false: the layout before
## 2026-09-25).

const Layout := preload("res://scripts/world/vegetation/veg_layout.gd")
const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const Geom := preload("res://scripts/world/vegetation/veg_geom.gd")
const Grass := preload("res://scripts/world/terrain/grass.gd")

const SKIP := ["Terrain", "Vegetation", "Player", "EnvironmentRig"]
const CATEGORIES := ["prop_vs_trunk", "prop_vs_prop", "plant_vs_solid", "plant_vs_plant", "veg_vs_structure",
		"veg_vs_fort_mesh", "veg_in_flat_zone", "on_path", "floating", "sunk", "trunk_floating",
		"foliage_in_ground", "crown_through_trunk", "collider_mismatch", "fix_cache", "grass_in_solid",
		"grass_in_fort_mesh", "structure_floating"]
## Fort mesh occupancy grid (m per cell).
const MESH_CELL := 0.25

var hits := {}
var examples := {}
var records := []
var verbose := false
var L: Layout
var _mesh_cells := {}             ## Vector2i -> Vector2(ymin, ymax) of the fort's visual triangles
var _mesh_tris := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	verbose = args.get("verbose", "0") == "1"
	for c in CATEGORIES:
		hits[c] = 0
		examples[c] = []
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var level := current_scene
	var t0 := Time.get_ticks_msec()
	L = Layout.new(1776, EnvironmentRig.sun_direction())
	var ref := Layout.new(1776, EnvironmentRig.sun_direction())
	ref.use_fix_cache = false
	if args.get("raw", "0") == "1":
		L.fix_clipping = false
		ref.fix_clipping = false
	L.build(true, 1.0)
	var t_live := Time.get_ticks_msec()
	ref.build(true, 1.0)
	t_live = Time.get_ticks_msec() - t_live
	var structures := _structure_footprints(level)
	await _fort_mesh_cells()
	print("CLIP info trees=%d props=%d plants=%d structure_shapes=%d fort_mesh_tris=%d fort_mesh_cells=%d layout_ms=%d" % [
			L.tree_pos.size(), L.prop_pos.size(), L.plant_pos.size(), structures.size(), _mesh_tris,
			_mesh_cells.size(), Time.get_ticks_msec() - t0])
	print("CLIP fix %s" % JSON.stringify(L.stats.get("clip_fix", {})))
	print("CLIP fix_source %s (layout ms: %.1f + clutter %.1f with the bake; live pass %d ms)" % [JSON.stringify(L.fix_source),
			float(L.stats.get("ms_fix_colliders", 0.0)), float(L.stats.get("ms_clutter", 0.0)), t_live])
	if L.fix_clipping:
		for part: String in L.fix_source:
			if L.fix_source[part] != "cache":
				_hit("fix_cache", "%s ran live: the bake is missing or stale (tools/environment/vegetation/bake_layout_fixes.gd)" % part)
		if not _same_layout(L, ref):
			_hit("fix_cache", "the baked clean-up differs from the live pass (bump VegLayout.FIX_VERSION and rebake)")

	# Footprints of everything placed.
	var grid := Geom.Grid.new(4.0)
	const T_TRUNK := 0
	const T_SOLID := 1          # stumps, logs, rocks
	const T_PILE := 2           # roots, brush
	const T_FERN := 3
	const T_STEM := 4
	var desc := []
	var refs := []
	for i in L.tree_pos.size():
		grid.add(L.trunk_footprint(i), T_TRUNK)
		desc.append("tree %s_v%d at %s" % [Assets.SPECIES[L.tree_kind[i]], L.tree_variant[i], _v(L.tree_pos[i])])
		refs.append(["tree", i])
	for i in L.prop_pos.size():
		var k := L.prop_kind[i]
		var tag := T_FERN if k >= Assets.FERN_FIRST else (T_PILE if k == Assets.ROOTS or k == Assets.BRUSH else T_SOLID)
		grid.add(L.prop_footprint(i, tag == T_FERN), tag)
		desc.append("%s at %s" % [Assets.PROPS[k].name, _v(L.prop_pos[i])])
		refs.append(["prop", i])
	for i in L.plant_pos.size():
		grid.add(L.plant_stem_footprint(i), T_STEM)
		desc.append("%s_v%d at %s" % [Assets.SPECIES[L.plant_kind[i]], L.plant_variant[i], _v(L.plant_pos[i])])
		refs.append(["plant", i])

	# 1-3: overlaps between scattered objects.
	var n := grid.items.size()
	for id in n:
		var tag := grid.tags[id]
		if tag == T_TRUNK:
			continue
		var f := grid.items[id]
		for o in Geom.query(grid, f, 0.0):
			if o == id:
				continue
			var ot := grid.tags[o]
			if tag == T_STEM:
				if ot in [T_TRUNK, T_SOLID, T_PILE]:
					_hit("plant_vs_solid", "%s in %s" % [desc[id], desc[o]], [refs[id], refs[o]])
				elif ot == T_STEM and o > id:
					_hit("plant_vs_plant", "%s in %s" % [desc[id], desc[o]], [refs[id], refs[o]])
			elif ot == T_TRUNK:
				_hit("prop_vs_trunk", "%s through %s" % [desc[id], desc[o]], [refs[id], refs[o]])
			elif ot in [T_SOLID, T_PILE] and o > id and not (tag == T_PILE and ot == T_PILE):
				_hit("prop_vs_prop", "%s through %s" % [desc[id], desc[o]], [refs[id], refs[o]])
			elif tag == T_FERN and ot in [T_SOLID, T_PILE]:
				_hit("prop_vs_prop", "%s through %s" % [desc[id], desc[o]], [refs[id], refs[o]])

	# 4-6: structures (colliders and visual meshes), flat zones, paths.
	for id in n:
		var f := grid.items[id]
		var near_structures := absf(f[1]) < 45.0 and f[2] < 45.0 and f[2] > -200.0
		for s: Array in (structures if near_structures else []):
			if Geom.overlaps(f, s[0], 0.3):
				_hit("veg_vs_structure", "%s vs %s" % [desc[id], s[1]], [refs[id]])
		if near_structures:
			var m := _mesh_hit(f, 0.3)
			if m != Vector3.INF:
				_hit("veg_vs_fort_mesh", "%s vs the fort mesh at %s" % [desc[id], _v(m)], [refs[id]])
		for p in Geom.samples(f, 0.5):
			if FrontierTerrain.in_flat_zone(p.x, p.y):
				_hit("veg_in_flat_zone", "%s reaches %s" % [desc[id], _v2(p)], [refs[id]])
				break
		if grid.tags[id] != T_FERN:
			var c := Geom.centre(f)
			if not FrontierTerrain.in_flat_zone(c.x, c.y) and L.on_path(c.x, c.y):
				_hit("on_path", desc[id], [refs[id]])
	# Tree crowns vs structures (spheres).
	for i in L.tree_pos.size():
		var tp := L.tree_pos[i]
		if absf(tp.x) > 45.0 or tp.z > 45.0 or tp.z < -200.0:    # structures: |x| < 30, -180 < z < 30
			continue
		var cr: Array = L.crown_spheres(L.tree_kind[i], L.tree_variant[i], L.tree_pos[i], L.tree_scale[i])
		for k in (cr[0] as PackedVector3Array).size():
			var c: Vector3 = cr[0][k]
			var r: float = cr[1][k]
			var core := Geom.circle(Vector2(c.x, c.z), r * 0.8, c.y - r * 0.6, c.y + r * 0.6)
			for s: Array in structures:
				if Geom.overlaps(core, s[0], 0.0):
					_hit("veg_vs_structure", "crown of %s vs %s" % [desc[i], s[1]], [refs[i]])
			var m := _mesh_hit(core, 0.0)
			if m != Vector3.INF:
				_hit("veg_vs_fort_mesh", "crown of %s vs the fort mesh at %s" % [desc[i], _v(m)], [refs[i]])

	# 7-8: grounding of props.
	for i in L.prop_pos.size():
		var k := L.prop_kind[i]
		if k >= Assets.FERN_FIRST:
			continue
		if Layout.prop_hull(k).is_empty():
			continue
		var g := Layout.prop_gaps(k, L.prop_pos[i], L.prop_yaw[i], L.prop_tilt[i], L.prop_scale[i])
		var h := Layout.prop_height(k, L.prop_scale[i])
		var id := L.tree_pos.size() + i
		if g.x > Layout.FLOAT_TOL:
			_hit("floating", "%s floats %.2f m" % [desc[id], g.x], [refs[id]], g.x)
		if g.y > Layout.sink_limit(k) * h:
			_hit("sunk", "%s buried %.2f m of %.2f" % [desc[id], g.y, h], [refs[id]], g.y)

	# 7b: trunks and stems standing on slopes: the mesh bottom must reach the ground all round.
	for i in L.tree_pos.size():
		var gap := Layout.trunk_gap(L.tree_kind[i], L.tree_variant[i], L.tree_pos[i], L.tree_scale[i])
		if gap > Layout.FLOAT_TOL:
			_hit("trunk_floating", "%s: trunk bottom %.2f m over the ground" % [desc[i], gap], [refs[i]], gap)
	for i in L.plant_pos.size():
		var gap := Layout.trunk_gap(L.plant_kind[i], L.plant_variant[i], L.plant_pos[i], L.plant_scale[i])
		var id := L.tree_pos.size() + L.prop_pos.size() + i
		if gap > Layout.FLOAT_TOL:
			_hit("trunk_floating", "%s: stem bottom %.2f m over the ground" % [desc[id], gap], [refs[id]], gap)

	# 9: foliage under the ground and low foliage over the flat zones.
	var below := {}
	for pair: Array in [[L.tree_kind, L.tree_variant], [L.plant_kind, L.plant_variant]]:
		for i in (pair[0] as PackedInt32Array).size():
			var key := "%s_v%d" % [Assets.SPECIES[pair[0][i]], pair[1][i]]
			if not below.has(key):
				var lo := 0.0
				for p in Layout.low_foliage(pair[0][i], pair[1][i]):
					lo = minf(lo, p.y)
				below[key] = [lo, 0]
			below[key][1] += 1
	var below_txt := PackedStringArray()
	for key: String in below:
		if below[key][0] < -0.12:
			below_txt.append("%s x%d (%.2f m)" % [key, below[key][1], -below[key][0]])
	print("CLIP info below_base (model parts below the plant's base, deepest at scale 1): %s" % ", ".join(below_txt))
	var low := {}
	for i in L.tree_pos.size():
		var key := L.tree_kind[i] * 4 + L.tree_variant[i]
		if not low.has(key):
			low[key] = Layout.low_foliage(L.tree_kind[i], L.tree_variant[i])
		_check_foliage(low[key], L.tree_transform(i), desc[i], refs[i])
	var lowp := {}
	for i in L.plant_pos.size():
		var key := L.plant_kind[i] * 4 + L.plant_variant[i]
		if not lowp.has(key):
			lowp[key] = Layout.low_foliage(L.plant_kind[i], L.plant_variant[i])
		var id := L.tree_pos.size() + L.prop_pos.size() + i
		_check_foliage(lowp[key], L.plant_transform(i), desc[id], refs[id])

	# 10: a neighbour's bare trunk through the dense core of a crown.
	for i in L.tree_pos.size():
		var cr: Array = L.crown_spheres(L.tree_kind[i], L.tree_variant[i], L.tree_pos[i], L.tree_scale[i])
		var reach := 0.0
		for r: float in cr[1]:
			reach = maxf(reach, r)
		var probe := Geom.circle(Vector2(L.tree_pos[i].x, L.tree_pos[i].z), reach, -INF, INF)
		for o in Geom.query(grid, probe, 0.0, 1 << T_TRUNK):
			if o == i:
				continue
			if L.crown_hits_trunk(i, o):
				_hit("crown_through_trunk", "crown of %s through the trunk of %s" % [desc[i], desc[o]], [refs[i], refs[o]])

	# 11: live colliders vs layout (the level's headless build).
	var veg := level.get_node_or_null("Vegetation")
	if veg:
		var live_trunks := 0
		var live_props := 0
		for b in veg.get_children():
			if b is StaticBody3D:
				for cs in b.get_children():
					if cs is CollisionShape3D:
						if String(b.name).begins_with("Trunks_"):
							live_trunks += 1
						else:
							live_props += 1
		var want_props := 0
		for i in L.prop_pos.size():
			if Layout.prop_has_collider(L.prop_kind[i]):
				want_props += 1
		if live_trunks != L.tree_pos.size() - _count_no_collider() or live_props != want_props:
			_hit("collider_mismatch", "live trunks %d props %d vs layout %d / %d" % [live_trunks, live_props,
					L.tree_pos.size() - _count_no_collider(), want_props])
		# The live (collider-only) layout must place trees and collider props exactly like the
		# full one: the clean-up pass may not depend on the clutter.
		var live: Variant = veg.get("layout")
		if live != null and not _same_colliders(live, L):
			_hit("collider_mismatch", "the headless layout's trees / collider props differ from the full layout's")

	# 12: grass under solid footprints.
	var mask := Grass.blocker_map(level)
	var solid := []
	for s: Array in structures:
		if (s[0] as PackedFloat32Array)[7] < 0.7:
			solid.append([s[0], s[1], s[2]])
	for id in n:
		if grid.tags[id] in [T_TRUNK, T_SOLID]:
			solid.append([grid.items[id], desc[id], null])
	for s: Array in solid:
		var f: PackedFloat32Array = s[0]
		for p in Geom.samples(f, 0.3):
			if not Geom.contains(f, p, -0.08):
				continue
			if s[2] != null and _box_bottom(s[2], p) > FrontierTerrain.height_at(p.x, p.y) + 0.7:
				continue
			if FrontierTerrain.grass_height_at(p.x, p.y) * FrontierTerrain.GRASS_H_SCALE < 0.03:
				continue
			if Grass.blocked(mask, p.x, p.y):
				continue
			_hit("grass_in_solid", "grass under %s at %s" % [s[1], _v2(p)])
			break
	# 12b: grass through the low parts of the fort's visual meshes (cells whose triangles come
	# within 0.7 m of the ground over a tuft that the blocker map keeps), one hit per 1 m square.
	var grass_mesh := {}
	for c: Vector2i in _mesh_cells:
		var yr: Vector2 = _mesh_cells[c]
		var p := Vector2((c.x + 0.5) * MESH_CELL, (c.y + 0.5) * MESH_CELL)
		var g := FrontierTerrain.height_at(p.x, p.y)
		if yr.x > g + 0.7 or yr.y < g + 0.05:
			continue
		if FrontierTerrain.grass_height_at(p.x, p.y) * FrontierTerrain.GRASS_H_SCALE < 0.03:
			continue
		if Grass.blocked(mask, p.x, p.y):
			continue
		var key := Vector2i(floori(p.x), floori(p.y))
		if not grass_mesh.has(key):
			grass_mesh[key] = true
			_hit("grass_in_fort_mesh", "grass through the fort mesh at %s (mesh %.2f-%.2f m)" % [_v2(p), yr.x, yr.y])

	# 13: structures standing on the ground (level boxes and upright cylinders whose bottom is
	# within 15 cm of it; ramps rise on purpose, rails and walkways stand on posts).
	for s: Array in structures:
		var f: PackedFloat32Array = s[0]
		if s[2] != null and ((s[2][0] as Transform3D).basis.y.normalized().y < 0.98):
			continue
		var worst := -INF
		var lowest := INF
		for p in Geom.samples(f, 0.3):
			var b: float = f[7] if s[2] == null else _box_bottom(s[2], p)
			if b == INF:
				continue
			var gy := FrontierTerrain.height_at(p.x, p.y)
			lowest = minf(lowest, b - gy)
			worst = maxf(worst, b - gy)
		if lowest < 0.15 and worst > Layout.FLOAT_TOL:
			_hit("structure_floating", "%s: bottom up to %.2f m over the ground" % [s[1], worst])

	var failed := 0
	for c: String in CATEGORIES:
		var line := "CLIP %-19s hits=%d" % [c, hits[c]]
		if hits[c] > 0:
			failed += 1
			line += "  e.g. " + " | ".join(examples[c].slice(0, 3 if not verbose else 40))
		print(line)
	print("CLIP total_ms=%d" % (Time.get_ticks_msec() - t0))
	if args.has("out"):
		var fo := FileAccess.open(args["out"], FileAccess.WRITE)
		if fo:
			var flog := []
			for e: Array in ref.fix_log:
				flog.append([e[0], e[1], [e[2].x, e[2].y, e[2].z], null if e[3] == null else [e[3].x, e[3].y, e[3].z]])
			fo.store_string(JSON.stringify({"hits": hits, "records": records, "stats": L.stats, "fix_log": flog}, " "))
	print("CLIPPING CHECK PASSED" if failed == 0 else "CLIPPING CHECK FAILED (%d categories)" % failed)
	quit(0 if failed == 0 else 1)


func _count_no_collider() -> int:
	var k := 0
	for c in L.tree_collider:
		if c == 0:
			k += 1
	return k


## True when two layouts place the same trees and collider props (position, yaw, scale, kind).
func _same_colliders(a: Layout, b: Layout) -> bool:
	if a.tree_pos != b.tree_pos or a.tree_yaw != b.tree_yaw or a.tree_scale != b.tree_scale \
			or a.tree_kind != b.tree_kind or a.tree_variant != b.tree_variant:
		return false
	var pa := []
	var pb := []
	for pair: Array in [[a, pa], [b, pb]]:
		var l: Layout = pair[0]
		for i in l.prop_pos.size():
			if Layout.prop_has_collider(l.prop_kind[i]):
				(pair[1] as Array).append([l.prop_kind[i], l.prop_pos[i], l.prop_yaw[i], l.prop_scale[i], l.prop_tilt[i]])
	return pa == pb


## True when two layouts hold exactly the same trees, props and plants.
func _same_layout(a: Layout, b: Layout) -> bool:
	return a.tree_pos == b.tree_pos and a.tree_yaw == b.tree_yaw and a.tree_scale == b.tree_scale \
			and a.tree_kind == b.tree_kind and a.tree_variant == b.tree_variant and a.tree_collider == b.tree_collider \
			and a.prop_pos == b.prop_pos and a.prop_yaw == b.prop_yaw and a.prop_scale == b.prop_scale \
			and a.prop_kind == b.prop_kind and a.prop_tilt == b.prop_tilt and a.plant_pos == b.plant_pos \
			and a.plant_yaw == b.plant_yaw and a.plant_scale == b.plant_scale and a.plant_kind == b.plant_kind \
			and a.plant_variant == b.plant_variant


func _check_foliage(pts: PackedVector3Array, xf: Transform3D, what: String, ref: Array) -> void:
	var under := 0.0
	var flat := false
	var s := xf.basis.y.length()
	for p in pts:
		var q := xf * p
		var g := FrontierTerrain.height_at(q.x, q.z)
		# Below-base parts of the model count from the base (see the header).
		under = maxf(under, g - q.y - maxf(-p.y, 0.0) * s)
		if q.y - g < 3.0 and FrontierTerrain.in_flat_zone(q.x, q.z):
			flat = true
	if under > 0.12:
		_hit("foliage_in_ground", "%s: cards %.2f m under the ground" % [what, under], [ref], under)
	if flat:
		_hit("veg_in_flat_zone", "%s: low foliage over a flat zone" % what, [ref])


func _hit(cat: String, text: String, refs := [], value := 0.0) -> void:
	hits[cat] += 1
	if (examples[cat] as Array).size() < 40:
		examples[cat].append(text)
	records.append({"cat": cat, "text": text, "refs": refs, "value": value})


## [footprint, label, [Transform3D, half extents] or null] of every structure collider.
func _structure_footprints(level: Node) -> Array:
	var out := []
	for cs in level.find_children("*", "CollisionShape3D", true, false):
		var top := cs as Node
		while top.get_parent() != level:
			top = top.get_parent()
		if String(top.name) in SKIP:
			continue
		var shape: Shape3D = (cs as CollisionShape3D).shape
		if shape == null or (cs as CollisionShape3D).disabled:
			continue
		var xf: Transform3D = (cs as Node3D).global_transform
		var label := "%s %s" % [shape.get_class().trim_suffix("Shape3D"), _v(xf.origin)]
		if shape is BoxShape3D:
			var e: Vector3 = (shape as BoxShape3D).size * 0.5
			var pts := PackedVector3Array()
			for sx in [-1, 1]:
				for sy in [-1, 1]:
					for sz in [-1, 1]:
						pts.append(xf * Vector3(e.x * sx, e.y * sy, e.z * sz))
			var u := Vector2(xf.basis.x.x, xf.basis.x.z)
			out.append([Geom.from_points(pts, u), label, [xf, e]])
		elif shape is CylinderShape3D or shape is CapsuleShape3D:
			var r: float = shape.get("radius")
			var h: float = shape.get("height")
			out.append([Geom.circle(Vector2(xf.origin.x, xf.origin.z), r, xf.origin.y - h * 0.5, xf.origin.y + h * 0.5), label, null])
		elif shape is SphereShape3D:
			var r := (shape as SphereShape3D).radius
			out.append([Geom.circle(Vector2(xf.origin.x, xf.origin.z), r, xf.origin.y - r, xf.origin.y + r), label, null])
		else:
			var aabb := shape.get_debug_mesh().get_aabb()
			var pts := PackedVector3Array()
			for k in 8:
				pts.append(xf * aabb.get_endpoint(k))
			out.append([Geom.from_points(pts, Vector2(1, 0)), label, null])
	return out


# --- The textured fort's visual meshes ------------------------------------------------------------

## Builds a throwaway FrontierStructures with its meshes (force_visuals, as
## tools/environment/structures/check_fort_integration.gd does) and rasterises every triangle
## into a MESH_CELL grid of [ymin, ymax] (triangles sampled at < MESH_CELL spacing).
func _fort_mesh_cells() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1776
	var s := FrontierStructures.new()
	s.force_visuals = true
	s.occluders = false
	root.add_child(s)
	s.build(WorldSettings.preset("high"), rng)
	await process_frame
	var faces := PackedVector3Array()
	var headless_palisade := [false]
	_collect_faces(s, faces, headless_palisade)
	# (the palisade is a build-menu piece since 2026-09-28: it is not among FrontierStructures' meshes)
	s.queue_free()
	await process_frame
	_mesh_tris = faces.size() / 3
	for t in _mesh_tris:
		var a := faces[t * 3]
		var b := faces[t * 3 + 1]
		var c := faces[t * 3 + 2]
		var e := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var k := maxi(1, int(ceil(e / (MESH_CELL * 0.7))))
		for i in k + 1:
			for j in k + 1 - i:
				var p := a + (b - a) * (float(i) / k) + (c - a) * (float(j) / k)
				var cell := Vector2i(floori(p.x / MESH_CELL), floori(p.z / MESH_CELL))
				var cur: Variant = _mesh_cells.get(cell)
				if cur == null:
					_mesh_cells[cell] = Vector2(p.y, p.y)
				else:
					_mesh_cells[cell] = Vector2(minf(cur.x, p.y), maxf(cur.y, p.y))


func _collect_faces(n: Node, faces: PackedVector3Array, headless_palisade: Array) -> void:
	if n is GPUParticles3D or n is CPUParticles3D:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var t := mi.global_transform
		for v in mi.mesh.get_faces():
			faces.append(t * v)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm.instance_count > 1 and mm.get_instance_transform(0) == Transform3D() and mm.get_instance_transform(1) == Transform3D():
			headless_palisade[0] = true
			return
		var f := mm.mesh.get_faces()
		var base := (n as Node3D).global_transform
		for i in mm.instance_count:
			var t := base * mm.get_instance_transform(i)
			for v in f:
				faces.append(t * v)
	for c in n.get_children():
		_collect_faces(c, faces, headless_palisade)


## A fort-mesh point within `margin` of footprint f (XZ) and inside its vertical range, or
## Vector3.INF.
func _mesh_hit(f: PackedFloat32Array, margin: float) -> Vector3:
	var r := Geom.radius(f) + margin
	var c0 := Vector2i(floori((f[1] - r) / MESH_CELL), floori((f[2] - r) / MESH_CELL))
	var c1 := Vector2i(floori((f[1] + r) / MESH_CELL), floori((f[2] + r) / MESH_CELL))
	for j in range(c0.y, c1.y + 1):
		for i in range(c0.x, c1.x + 1):
			var yr: Variant = _mesh_cells.get(Vector2i(i, j))
			if yr == null:
				continue
			if yr.y < f[7] or yr.x > f[8]:
				continue
			var p := Vector2((i + 0.5) * MESH_CELL, (j + 0.5) * MESH_CELL)
			if Geom.contains(f, p, margin + MESH_CELL * 0.71):
				return Vector3(p.x, yr.x, p.y)
	return Vector3.INF


## Lowest y of a box collider on the vertical line through p (INF if the line misses it).
func _box_bottom(box: Array, p: Vector2) -> float:
	var xf: Transform3D = box[0]
	var e: Vector3 = box[1]
	var inv := xf.affine_inverse()
	var o := inv * Vector3(p.x, -1000.0, p.y)
	var d := inv.basis * Vector3.UP
	var t0 := -INF
	var t1 := INF
	for a in 3:
		if absf(d[a]) < 1e-9:
			if absf(o[a]) > e[a]:
				return INF
			continue
		var ta := (-e[a] - o[a]) / d[a]
		var tb := (e[a] - o[a]) / d[a]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t0 > t1:
		return INF
	return -1000.0 + t0


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _v2(p: Vector2) -> String:
	return "(%.1f, %.1f)" % [p.x, p.y]
