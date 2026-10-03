class_name FrontierVegetation
extends Node3D
## Trees, saplings, undergrowth, fallen wood and rocks around the fort (look-dev spec,
## section 7). Owner: package C.
## Past the forest's square, the small woods of data/world/woodlots.json (VegWoodlots: the homestead's stand of oaks and pines
## across the ford) go into the same layout once it is built, after everything in it, and are drawn, solid and felled as it is.
##
## Integration API (frozen; see the spec, section 11):
##   var v := FrontierVegetation.new(); v.name = "Vegetation"; add_child(v)
##   v.build(settings, rng)        -- called after the terrain and the structures; places
##                                    everything on FrontierTerrain.height_at() and never in the
##                                    fort clearing, the range lane or the dummies' sun corridor.
##                                    Only rng.seed is used (1776), not its state, so the forest
##                                    does not move if the structure code draws more numbers.
## Collision / audio contract: every tree trunk has a CylinderShape3D collider in a StaticBody3D
## in group "trees" (reads as wood; GripSurface "bark": climbable with the grip up to the crown); rocks and boulders are StaticBody3D in group "rocks" with
## meta surface = "stone"; stumps and logs are wood, in group LOW_GROUP ("horse_step_over": at
## most 0.6 m high, a horse steps over them, HorseTerrain). Saplings, shrubs, ferns, brush and
## root clusters have no collider (a horse or the player goes through them). All bodies are
## children of this node (one body per 50 m cell and kind), built before they enter the tree so
## the physics server registers them in one go.
##
## Rendering (skipped headless, where only colliders are built):
##   - Trees: 50 m cells for the impostors and the shadow proxies; the drawn LODs 0-2 are split
##     further into LOD_CELL (12.5 m) sub-cells per species variant, each MultiMeshInstance3D with
##     its sub-cell's box as custom AABB, so a tree's LOD follows (nearly) its own distance
##     (visibility ranges from the sub-cell centre, x settings.vegetation_distance_scale):
##     LOD0 < 30 m, LOD1 < 60 m, LOD2 < 100 m, impostors beyond (one impostor MultiMesh per 50 m cell, all species).
##     The distant ones painted (user 2026-09-28: "the painted trees can be distant trees"): LOD2 and the impostors
##     take the painted look (painted_look.gd, painted_tree.gdshader, painted_impostor.gdshader), dissolving from the
##     realistic LOD1 at its switch; veg_far=real keeps them realistic.
##     LOD HAND-OVER (2026-09-28, user: "it jitters between the low res one and the high res"): every switch
##     dissolves over a band round its distance (LOD_BAND of it, at least LOD_BAND_MIN m), measured to each tree:
##     each drawn LOD has its own copy of the species' material with its bands (_lod_material, lod_fade in
##     shaders/vegetation/lod_fade.gdshaderinc), the two LODs share the tree's pixels by screen-space dither (each
##     pixel drawn once, the dither moving each frame under TAA / MetalFX so it averages out), and a tree outside a
##     LOD's bands collapses in that LOD's vertex shader. So the MultiMeshes stay visible LOD_REACH m past their
##     trees' bands (the distance is to their box's centre), with no engine fade.
##     Why sub-cells (package A performance pass, 2026-09-24, tools/environment/perf/forest_probe.gd):
##     with whole 50 m cells a tree 2-10 m from the camera could be drawn with the big clump
##     cards of LOD1/LOD2 (its cell centre was 30-60 m away); those screen-filling alpha cards
##     cost up to 25 ms more per frame at some forest poses (40 ms vs 15-19 ms) and made the
##     cost jump whenever the player crossed a cell line. Every tree within ~21 m is now LOD0.
##     Measured (veg_cost.gd, A/B of LOD sets): pulling the impostors closer than ~100 m costs
##     more than it saves (big alpha-tested billboards overlap heavily).
##     Before the hand-over the drawn LODs used the engine's visibility-range fade (FADE_SELF, 5 m margins): the
##     neighbouring LODs overlapped over 10 m, both drawn in full (the fade alpha never shows on alpha-scissor
##     materials) and in the TRANSPARENT pass (no depth prepass, no depth writes, no motion vectors), which cost ~2.5 ms
##     a frame in the forest and let the temporal AA smear the band's trees as it swept over the forest (the jitter).
##     The hand-over measured 2026-09-28 (medium, forest_probe.gd REF): the forest poses 2-3 ms cheaper, the fort
##     ~0.8 ms dearer, 1 ms cheaper on average; the jumpiness of the tree line at the near switch about halved
##     (tools/environment/perf/lod_pop_probe.gd, taa=1). The drawn LODs never cast shadows: shadow-only proxies per
##     cell for the conifers and the broadleaf trees do -- LOD3 (trunk + ~45 alpha cards, dappled
##     shadows) within 40 m, LOD4 (an opaque ~80-triangle crown blob, cheap in the big far
##     cascades) from there to settings.tree_shadow_distance. Impostors never cast. Forest lighting
##     (2026-09-26): over the LOD3 range the same LOD4 crown hulls cast instead, through a dappling
##     shader (TreeDapple_*, shaders/vegetation/canopy_dapple.gdshader): the cards let about two
##     thirds of a high sun through a closed canopy (the floor looked like a clearing); the hulls
##     shade it, with sunflecks where the noise opens them, solid again toward the far blobs, and
##     cost less than the cards' ~45 alpha-tested layers (about -1.5 ms in the forest).
##   - The canopy map (canopy_map.gd): the crowns' sky cover, baked once from the layout after the
##     visuals, for the forest light (shaders/common/canopy.gdshaderinc, scripts/world/env/forest_light.gd).
##   - Saplings, shrubs, ferns: 25 m cells, short ranges (ferns 40 m, shrubs 70 m, saplings 80 m);
##     saplings and shrubs cast from LOD0 only, ferns never.
##   - Rocks: 25 m cells, 3 LODs out to 130 m (cast from LOD0-1); stumps, logs, roots, brush:
##     2 LODs out to 70 m (cast from LOD0).
##   Materials: shaders/vegetation/tree.gdshader (bark + cards), impostor.gdshader,
##   plant.gdshader (ferns); ORMMaterial3D for the Poly Haven props.
##
## Near-camera fade (user-approved 2026-09-25): leaf / needle cards, limbs and ferns within ~1.5 m
## of the camera dither out (shaders/vegetation/near_fade.gdshaderinc); trunks stay solid.
##
## Debug / A-B switches (user args): vegetation=off (colliders only, nothing drawn),
## vegetation=noimpostors, vegetation=notrees (trees not drawn), veg_lod=<lod0>,<lod1>,<lod2>
## (tree LOD distances, m), veg_shadow=<m> (tree shadow distance), veg_gi=0 / 1 (shadow blobs out of / in
## SDFGI), veg_near_fade=0 (near-camera fade off), veg_clip_fix=0 (the layout without its clipping
## clean-up pass, veg_layout.gd _fix_clipping()), veg_log=1 (print the build summary), veg_dapple=0
## (the LOD3 cards near the camera, no dappled crowns: before the forest lighting) / veg_dapple=cards
## (both).

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const Layout := preload("res://scripts/world/vegetation/veg_layout.gd")
const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")

const CELL := 50.0
## Group of the stump and log bodies: low enough for a horse to step over (HorseTerrain.LOW_GROUP).
const LOW_GROUP := &"horse_step_over"
const CLUTTER_CELL := 25.0
## Tree LOD switch distances (camera to cell centre, m) at vegetation_distance_scale 1.
const TREE_LOD := [30.0, 60.0, 100.0]
## Sub-cell size (m) of the drawn tree LODs 0-2 (the impostors keep the 50 m CELL).
const LOD_CELL := 12.5
## Shadow proxies: alpha-tested LOD3 near the camera, opaque LOD4 blobs beyond (to
## settings.tree_shadow_distance).
const NEAR_SHADOW := 40.0
const FADE := 5.0
## The trees' LOD hand-over (shaders/vegetation/lod_fade.gdshaderinc): each switch dissolves over a band this share
## of its distance wide (at least LOD_BAND_MIN m), centred on it, measured to each tree.
const LOD_BAND := 0.12
const LOD_BAND_MIN := 3.0
## How much farther (or nearer) a tree can be than its MultiMesh's own visibility distance (to the centre of its box,
## which stands ~15 m over the ground): the box's half diagonal and its height. The drawn MultiMeshes stay visible this
## much past their trees' bands; outside its band each tree collapses in the shader.
const LOD_REACH := 18.0
## Props (25 m cells): LOD ends. Rocks keep 3 LODs; stumps, logs, roots and brush use LOD0 and
## LOD1 only.
const ROCK_LOD := [15.0, 60.0, 250.0]
const PROP_LOD := [20.0, 150.0]
## Undergrowth: LOD0 end, LOD1 end.
const FERN_LOD := [20.0, 90.0]
const SHRUB_LOD := [30.0, 160.0]
const SAPLING_LOD := [30.0, 180.0]   # (drawn far: user 2026-10-01, "all the vegetation to show up, not only where we walk")
## SDFGI sees the LOD1 trees (spec 4.1: crowns STATIC). Off makes all vegetation GI_MODE_DISABLED.
## Forest lighting (2026-09-26): the crowns stay out of SDFGI while the forest light runs (gi_blobs()).
const TREES_IN_GI := true

var settings: WorldSettings
var layout: Layout
var stats := {}
var visuals := true
var _mode := ""
var _shape_cache := {}


func build(world_settings: WorldSettings, level_rng: RandomNumberGenerator) -> void:
	var t0 := Time.get_ticks_usec()
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	var level_seed := level_rng.seed if level_rng else 1776
	_mode = _user_arg("vegetation")
	visuals = DisplayServer.get_name() != "headless" and _mode != "off"
	layout = Layout.new(int(level_seed & 0x7FFFFFFF), EnvironmentRig.sun_direction())
	layout.fix_clipping = _user_arg("veg_clip_fix") != "0"     # A/B: the layout before its clipping pass
	layout.build(visuals, settings.clutter_density)
	VegWoodlots.add(layout)                      # (the small woods past the forest's square: data/world/woodlots.json)
	var t1 := Time.get_ticks_usec()
	_colliders()
	var t2 := Time.get_ticks_usec()
	if visuals:
		_visuals()
		# the canopy's sky cover for the forest light (canopy_map.gd, shaders/common/canopy.gdshaderinc)
		stats["ms_canopy_map"] = CanopyMap.bake(layout)
	var t3 := Time.get_ticks_usec()
	stats.merge(layout.stats, true)
	stats["ms_layout"] = (t1 - t0) / 1000.0
	stats["ms_colliders"] = (t2 - t1) / 1000.0
	stats["ms_visuals"] = (t3 - t2) / 1000.0
	stats["ms_total"] = (t3 - t0) / 1000.0
	if _user_arg("veg_log") != "":
		print("VEG build %s" % JSON.stringify(stats))


# --- Colliders -----------------------------------------------------------------------------------

func _colliders() -> void:
	var trunks := {}
	var rocks := {}
	var stumps := {}
	var logs := {}
	var n_trunks := 0
	for i in layout.tree_pos.size():
		if layout.tree_collider[i] == 0:
			continue
		var k := layout.tree_kind[i]
		var info := Assets.tree(k, layout.tree_variant[i])
		var s := layout.tree_scale[i]
		var r := clampf(float(info.get("trunk_radius", 0.3)) * s * 0.92, 0.1, 0.75)
		var h := maxf(float(info.get("collider_height", 6.0)) * s, 3.3)
		var p := layout.tree_pos[i]
		# A tree the clipping pass raised off a slope (its base above the ground at its centre)
		# keeps its collider down to the ground all round (the trunk mesh reaches 0.6 x scale down).
		var sink := 0.3
		var g0 := FrontierTerrain.height_at(p.x, p.z)
		if p.y - g0 > 0.005:
			var lo := g0
			for k8 in 8:
				lo = minf(lo, FrontierTerrain.height_at(p.x + cos(k8 * TAU / 8.0) * r, p.z + sin(k8 * TAU / 8.0) * r))
			var extra := maxf(p.y - 0.3 - (lo - 0.1), 0.0)
			sink += extra
			h += extra
		var shape := _cylinder(r, h)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = p + Vector3(0, h * 0.5 - sink, 0)
		_body(trunks, p, "Trunks", &"trees").add_child(cs)
		n_trunks += 1
	var n_props := 0
	for i in layout.prop_pos.size():
		var k := layout.prop_kind[i]
		if not Layout.prop_has_collider(k):
			continue
		var p := layout.prop_pos[i]
		var s := layout.prop_scale[i]
		var info := Assets.prop(k)
		var size: Array = info.get("size", [1.0, 1.0, 1.0])
		var cs := CollisionShape3D.new()
		var basis := Basis.from_euler(Vector3(layout.prop_tilt[i].x, layout.prop_yaw[i], layout.prop_tilt[i].z))
		if k >= Assets.ROCK_FIRST and k <= Assets.ROCK_LAST:
			cs.shape = _hull(k, s, info.get("hull", []), size)
			cs.transform = Transform3D(basis, p)
			_body(rocks, p, "Rocks", &"rocks", "stone").add_child(cs)
		elif k == Assets.LOG:
			# The box follows the log's tilt (logs lie along the slope since the 2026-09-25
			# clipping pass, scripts/world/vegetation/veg_layout.gd).
			var box := BoxShape3D.new()
			box.size = Vector3(float(size[0]) * s * 0.96, float(size[1]) * s * 0.9, float(size[2]) * s * 0.9)
			cs.shape = box
			cs.transform = Transform3D(basis, p + basis * Vector3(0, float(size[1]) * s * 0.5, 0))
			_body(logs, p, "Logs", LOW_GROUP).add_child(cs)
		else:
			var h := float(size[1]) * s
			var tilt := Basis.from_euler(Vector3(layout.prop_tilt[i].x, 0.0, layout.prop_tilt[i].z))
			cs.shape = _cylinder(0.27 * minf(float(size[0]), float(size[2])) * s, maxf(h, 0.3))
			cs.transform = Transform3D(tilt, p + tilt * Vector3(0, h * 0.5, 0))
			_body(stumps, p, "Stumps", LOW_GROUP).add_child(cs)
		n_props += 1
	# the trunks can be climbed (PlayerGrip, hold G), up to where the crown starts (the collider's top)
	for key: Vector2i in trunks:
		GripSurface.tag(trunks[key], "bark")
	for group: Dictionary in [trunks, rocks, stumps, logs]:
		for key: Vector2i in group:
			add_child(group[key])
	stats["trunk_colliders"] = n_trunks
	stats["prop_colliders"] = n_props
	stats["bodies"] = trunks.size() + rocks.size() + stumps.size() + logs.size()


func _body(bodies: Dictionary, p: Vector3, prefix: String, group: StringName, surface := "") -> StaticBody3D:
	var c := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	if bodies.has(c):
		return bodies[c]
	var b := StaticBody3D.new()
	b.name = "%s_%d_%d" % [prefix, c.x, c.y]
	if group != &"":
		b.add_to_group(group)
	if surface != "":
		b.set_meta(&"surface", surface)
	bodies[c] = b
	return b


func _cylinder(r: float, h: float) -> CylinderShape3D:
	var key := "c%d_%d" % [roundi(r * 50.0), roundi(h * 4.0)]
	if not _shape_cache.has(key):
		var c := CylinderShape3D.new()
		c.radius = roundi(r * 50.0) / 50.0
		c.height = roundi(h * 4.0) / 4.0
		_shape_cache[key] = c
	return _shape_cache[key]


func _hull(kind: int, s: float, hull: Array, size: Array) -> Shape3D:
	var q := roundi(s * 10.0)
	var key := "h%d_%d" % [kind, q]
	if not _shape_cache.has(key):
		var sc := q / 10.0
		if hull.is_empty():
			var b := BoxShape3D.new()
			b.size = Vector3(float(size[0]), float(size[1]), float(size[2])) * sc * 0.8
			_shape_cache[key] = b
		else:
			var pts := PackedVector3Array()
			for h: Array in hull:
				pts.append(Vector3(float(h[0]), float(h[1]), float(h[2])) * sc)
			var c := ConvexPolygonShape3D.new()
			c.points = pts
			_shape_cache[key] = c
	return _shape_cache[key]


# --- Visuals -------------------------------------------------------------------------------------

func _visuals() -> void:
	var dist := settings.vegetation_distance_scale
	var impostors_ok := _mode != "noimpostors" and not Assets.impostor_info().is_empty()
	var mmis := 0
	var root := Node3D.new()
	root.name = "Visuals"
	add_child(root)

	# Trees: group by 50 m cell and species variant.
	if _mode != "notrees":
		var cells := {}
		for i in layout.tree_pos.size():
			var p := layout.tree_pos[i]
			var c := tree_cell(p)
			if not cells.has(c):
				cells[c] = {}
			var key := layout.tree_kind[i] * 4 + layout.tree_variant[i]
			if not cells[c].has(key):
				cells[c][key] = PackedInt32Array()
			cells[c][key].append(i)
		var lod_cfg: Array = TREE_LOD.duplicate()
		var lod_arg := _user_arg("veg_lod")           # A/B tuning: veg_lod=<lod0>,<lod1>,<lod2> (m)
		if lod_arg.get_slice_count(",") == 3:
			for k in 3:
				lod_cfg[k] = lod_arg.get_slice(",", k).to_float()
		var lod_end := [float(lod_cfg[0]) * dist, float(lod_cfg[1]) * dist, float(lod_cfg[2]) * dist]
		# the distant trees painted (LOD2 and the impostors; user 2026-09-28; veg_far=real: as before)
		var painted_far := Assets.PaintedLook.enabled()
		var shadow_end := settings.tree_shadow_distance
		var dapple_mode := _user_arg("veg_dapple")    # A/B: veg_dapple=0 (LOD3 cards, no dappled crowns) / cards (both)
		if _user_arg("veg_shadow") != "":             # A/B tuning: veg_shadow=<m>
			shadow_end = _user_arg("veg_shadow").to_float()
		for c: Vector2i in cells:
			var aabb := _cell_aabb(c, CELL, 14.0, 32.0, CELL * 0.5)
			var all_idx := PackedInt32Array()
			for key: int in cells[c]:
				var idx: PackedInt32Array = cells[c][key]
				all_idx.append_array(idx)
				var kind := key / 4
				var variant := key % 4
				var mat := Assets.tree_material(kind)
				# Drawn LODs per LOD_CELL sub-cell: the LOD follows the tree's own distance.
				var subs := {}
				for i in idx:
					var tp := layout.tree_pos[i]
					var sk := Vector2i(floori(tp.x / LOD_CELL), floori(tp.z / LOD_CELL))
					if not subs.has(sk):
						subs[sk] = PackedInt32Array()
					subs[sk].append(i)
				for sk: Vector2i in subs:
					var sidx: PackedInt32Array = subs[sk]
					var buf := _buffer(sidx, layout.tree_pos, layout.tree_yaw, layout.tree_scale, layout.tree_custom, null, -1)
					var saabb := _sub_aabb(sk, sidx)
					for lod in 3:
						var mesh := Assets.tree_mesh(kind, variant, lod)
						if mesh == null:
							continue
						# each tree dissolves from one LOD to the next over a band round the switch distance
						# (lod_fade.gdshaderinc): the MultiMesh stays drawn past its trees' bands, the shader
						# gives every tree to exactly one LOD (the impostors take LOD2's from lod_end[2] on)
						var band_in := _lod_band(lod_end, lod - 1) if lod > 0 else Vector2.ZERO
						var band_out := _lod_band(lod_end, lod) if (lod < 2 or impostors_ok) else Vector2.ZERO
						var begin: float = maxf(band_in.x - LOD_REACH, 0.0) if lod > 0 else 0.0
						var end: float = band_out.y + LOD_REACH if band_out.y > 0.0 else 0.0
						# the distant LOD painted (painted_look.gd), the nearer ones realistic
						var lod_mat := Assets.painted_tree_material(kind) if (lod == 2 and painted_far) else mat
						var mmi := _mmi(root, mesh, _lod_material(lod_mat, band_in, band_out), buf, sidx.size(), saabb, begin, end, false)
						_lod_node(mmi)
						mmi.name = "TreeLod%d_%d_%d_%d_%d_%d" % [lod, c.x, c.y, key, sk.x, sk.y]
						mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
						mmis += 1
			# Shadows come from proxies; the drawn LODs never cast. Near the camera (< NEAR_SHADOW)
			# the dappled crowns (below; veg_dapple=0 / cards: one LOD3 MultiMesh per cell for the
			# conifers and one for the broadleaf trees, trunk + ~45 alpha cards of the group's most
			# common species / variant, scaled to every tree's height). Beyond, to
			# tree_shadow_distance, ONE opaque LOD4 crown blob
			# MultiMesh per cell (the cell's most common species, scaled per tree to its own height
			# and crown radius): no alpha test and one draw per cell and cascade.
			# the dappled crowns cast the trees' shade over the whole shadow range (the same sunflecks everywhere, not only
			# near the player; user 2026-09-28); veg_dapple=0 / cards keep the LOD3 cards near the camera as before
			var near := shadow_end if not dapple_mode in ["0", "cards"] else minf(NEAR_SHADOW * dist, shadow_end)
			var cell_best := -1
			var cell_best_n := 0
			for group: Array in [[Assets.WHITE_PINE, Assets.HEMLOCK], [Assets.OAK, Assets.MAPLE, Assets.BIRCH]]:
				var idx := PackedInt32Array()
				var best_kind := -1
				var best_n := 0
				for key: int in cells[c]:
					if (key / 4) in group:
						idx.append_array(cells[c][key])
						if cells[c][key].size() > best_n:
							best_n = cells[c][key].size()
							best_kind = key
						if cells[c][key].size() > cell_best_n:
							cell_best_n = cells[c][key].size()
							cell_best = key
				if idx.is_empty() or near <= 0.0 or not dapple_mode in ["0", "cards"]:
					continue
				var proxy := Assets.tree_mesh(best_kind / 4, best_kind % 4, 3)
				if proxy == null:
					continue
				var buf := _proxy_buffer(idx, best_kind / 4, best_kind % 4, false)
				var smi := _mmi(root, proxy, Assets.tree_material(best_kind / 4), buf, idx.size(), aabb, 0.0, near, true)
				smi.name = "TreeShadow3_%d_%d_%d" % [c.x, c.y, best_kind]
				smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				smi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				mmis += 1
			# Dappled crowns near the camera (forest lighting, 2026-09-26): the cell's LOD4 crown hulls with sunfleck holes
			# (canopy_dapple.gdshader), shadow-only over the LOD3 range in place of the cards, so a closed canopy shades
			# the floor (the cards let about two thirds of a high sun through). veg_dapple=0: the cards; =cards: both.
			var blob_buf := PackedFloat32Array()
			if dapple_mode != "0" and cell_best >= 0 and near > 0.0:
				var dblob := Assets.tree_mesh(cell_best / 4, cell_best % 4, 4)
				if dblob:
					blob_buf = _proxy_buffer(all_idx, cell_best / 4, cell_best % 4, true)
					var dmi := _mmi(root, dblob, CanopyMap.dapple_material(), blob_buf, all_idx.size(), aabb, 0.0, near, true)
					dmi.name = "TreeDapple_%d_%d" % [c.x, c.y]
					dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
					dmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
					mmis += 1
			if cell_best >= 0 and shadow_end > near:
				var blob := Assets.tree_mesh(cell_best / 4, cell_best % 4, 4)
				if blob:
					if blob_buf.is_empty():
						blob_buf = _proxy_buffer(all_idx, cell_best / 4, cell_best % 4, true)
					var bmi := _mmi(root, blob, Assets.shadow_blob_material(), blob_buf, all_idx.size(), aabb, near, shadow_end, true)
					bmi.name = "TreeShadow4_%d_%d" % [c.x, c.y]
					bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
					bmi.gi_mode = GeometryInstance3D.GI_MODE_STATIC if gi_blobs() else GeometryInstance3D.GI_MODE_DISABLED
					mmis += 1
			if impostors_ok and not all_idx.is_empty():
				var buf := _impostor_buffer(all_idx)
				# from LOD2's band on (per tree, lod_fade.gdshaderinc); the 50 m cell's MultiMesh from that much nearer
				var band := _lod_band(lod_end, 2)
				var imp_mat := Assets.painted_impostor_material() if painted_far else Assets.impostor_material()
				var mmi := _mmi(root, Assets.impostor_quad(), _lod_material(imp_mat, band, Vector2.ZERO),
						buf, all_idx.size(), aabb, maxf(band.x - LOD_REACH - CELL * 0.5, 0.0), 0.0, false)
				_lod_node(mmi)
				mmi.name = "TreeImpostors_%d_%d" % [c.x, c.y]
				mmis += 1

	# Saplings and shrubs: 25 m cells, two LODs.
	var pcells := {}
	for i in layout.plant_pos.size():
		var p := layout.plant_pos[i]
		var c := Vector2i(floori(p.x / CLUTTER_CELL), floori(p.z / CLUTTER_CELL))
		if not pcells.has(c):
			pcells[c] = {}
		var key := layout.plant_kind[i] * 4 + layout.plant_variant[i]
		if not pcells[c].has(key):
			pcells[c][key] = PackedInt32Array()
		pcells[c][key].append(i)
	for c: Vector2i in pcells:
		var aabb := _cell_aabb(c, CLUTTER_CELL, 3.0, 6.0)
		for key: int in pcells[c]:
			var idx: PackedInt32Array = pcells[c][key]
			var kind := key / 4
			var variant := key % 4
			var lods: Array = SHRUB_LOD if kind == Assets.SHRUB_HAZEL else SAPLING_LOD
			var buf := _buffer(idx, layout.plant_pos, layout.plant_yaw, layout.plant_scale, layout.plant_custom, null, -1)
			for lod in 2:
				var mesh := Assets.tree_mesh(kind, variant, lod)
				if mesh == null:
					continue
				var begin: float = 0.0 if lod == 0 else float(lods[0]) * dist
				var mmi := _mmi(root, mesh, Assets.tree_material(kind), buf, idx.size(), aabb, begin,
						float(lods[lod]) * dist, lod == 0)
				mmi.name = "Plant%d_%d_%d_%d" % [lod, c.x, c.y, key]
				mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				mmis += 1

	# Props: stumps, logs, rocks, roots, brush in 50 m cells; ferns in 25 m cells.
	var prcells := {}
	for i in layout.prop_pos.size():
		var k := layout.prop_kind[i]
		var fern := k >= Assets.FERN_FIRST
		var size := CLUTTER_CELL
		var p := layout.prop_pos[i]
		var c := Vector3i(floori(p.x / size), floori(p.z / size), 1 if fern else 0)
		if not prcells.has(c):
			prcells[c] = {}
		if not prcells[c].has(k):
			prcells[c][k] = PackedInt32Array()
		prcells[c][k].append(i)
	for c: Vector3i in prcells:
		var fern_cell := c.z == 1
		var aabb := _cell_aabb(Vector2i(c.x, c.y), CLUTTER_CELL, 4.0, 6.0)
		for k: int in prcells[c]:
			var idx: PackedInt32Array = prcells[c][k]
			var buf := _buffer(idx, layout.prop_pos, layout.prop_yaw, layout.prop_scale, null, layout.prop_tilt, k)
			var lods: Array = FERN_LOD if fern_cell else (ROCK_LOD if k >= Assets.ROCK_FIRST and k <= Assets.ROCK_LAST else PROP_LOD)
			var mat := Assets.prop_material(k)
			for lod in lods.size():
				var mesh := Assets.prop_mesh(k, lod)
				if mesh == null:
					continue
				var begin: float = 0.0 if lod == 0 else float(lods[lod - 1]) * dist
				# Ferns never cast; rocks cast from LOD0 / LOD1, stumps, logs, roots, brush from LOD0.
				var rock := k >= Assets.ROCK_FIRST and k <= Assets.ROCK_LAST
				var shadow := not fern_cell and (lod == 0 or (rock and lod == 1))
				var mmi := _mmi(root, mesh, mat, buf, idx.size(), aabb, begin, float(lods[lod]) * dist, shadow)
				mmi.name = "%s%d_%d_%d_%d" % ["Fern" if fern_cell else "Prop", lod, c.x, c.y, k]
				var stone_or_wood := not fern_cell and k != Assets.BRUSH
				mmi.gi_mode = GeometryInstance3D.GI_MODE_STATIC if (stone_or_wood and lod == 1) else GeometryInstance3D.GI_MODE_DISABLED
				mmis += 1
	stats["multimeshes"] = mmis
	if _user_arg("veg_near_fade") == "0":
		_near_fade_off(root)


## A/B switch veg_near_fade=0: the near-camera leaf fade (shaders/vegetation/near_fade.gdshaderinc,
## user-approved 2026-09-25) off on every foliage material, i.e. the look before it.
func _near_fade_off(root: Node) -> void:
	var done := {}
	for c in root.get_children():
		var m := (c as GeometryInstance3D).material_override as ShaderMaterial
		if m == null or m.shader == null or done.has(m):
			continue
		done[m] = true
		for u in m.shader.get_shader_uniform_list():
			if u.name == "near_fade_end":
				m.set_shader_parameter("near_fade_begin", 0.0)
				m.set_shader_parameter("near_fade_end", 0.0)
				break


## Render cell of a tree: 50 m cells centred on the fort (cell (0, 0) = -25..25 m).
static func tree_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + CELL * 0.5) / CELL), floori((p.z + CELL * 0.5) / CELL))


## Sub-cell box of the drawn tree LODs: the sub-cell's xz square plus a crown margin, y from the
## trees' own bases (layout positions) to the tallest crown.
func _sub_aabb(sk: Vector2i, idx: PackedInt32Array) -> AABB:
	var ymin := INF
	var ymax := -INF
	for i in idx:
		ymin = minf(ymin, layout.tree_pos[i].y)
		ymax = maxf(ymax, layout.tree_pos[i].y)
	var margin := 10.0
	return AABB(Vector3(sk.x * LOD_CELL - margin, ymin - 3.0, sk.y * LOD_CELL - margin),
			Vector3(LOD_CELL + 2.0 * margin, ymax - ymin + 35.0, LOD_CELL + 2.0 * margin))


## Cell box (xz cell plus a margin for crowns, y from the terrain range) used as the custom AABB
## of every MultiMesh of the cell: identical centres make all LODs switch together.
func _cell_aabb(c: Vector2i, size: float, margin: float, height: float, offset := 0.0) -> AABB:
	var x0 := c.x * size - offset
	var z0 := c.y * size - offset
	var ymin := INF
	var ymax := -INF
	for sx in 3:
		for sz in 3:
			var y := FrontierTerrain.height_at(x0 + size * 0.5 * sx, z0 + size * 0.5 * sz)
			ymin = minf(ymin, y)
			ymax = maxf(ymax, y)
	return AABB(Vector3(x0 - margin, ymin - 3.0, z0 - margin),
			Vector3(size + 2.0 * margin, ymax - ymin + height + 3.0, size + 2.0 * margin))


func _mmi(parent: Node, mesh: Mesh, mat: Material, buf: PackedFloat32Array, count: int, aabb: AABB,
		begin: float, end: float, shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = aabb
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.visibility_range_begin_margin = FADE if begin > 0.0 else 0.0
	mmi.visibility_range_end_margin = FADE if end > 0.0 else 0.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## The hand-over band round the switch at lod_end[k] (m): its near and far end.
static func _lod_band(lod_end: Array, k: int) -> Vector2:
	var s := float(lod_end[k])
	var w := maxf(s * LOD_BAND, LOD_BAND_MIN)
	return Vector2(s - w * 0.5, s + w * 0.5)


## A drawn tree LOD: no engine fade (it drew the band's trees in the transparent pass, twice); its material's bands
## hand each tree over in the shader.
func _lod_node(mmi: MultiMeshInstance3D) -> void:
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mmi.visibility_range_begin_margin = 0.0
	mmi.visibility_range_end_margin = 0.0


## The species' material for one drawn LOD: a copy with that LOD's hand-over bands (lod_fade.gdshaderinc), one per
## species and band pair (the original stays for the saplings, the shrubs, the shadow proxies and felled trees).
var _lod_mats := {}


func _lod_material(base: ShaderMaterial, band_in: Vector2, band_out: Vector2) -> ShaderMaterial:
	var key := "%d|%s|%s" % [base.get_instance_id(), band_in, band_out]
	if not _lod_mats.has(key):
		var m := base.duplicate() as ShaderMaterial
		m.set_shader_parameter(&"lod_fade", Vector4(band_in.x, band_in.y, band_out.x, band_out.y))
		m.set_shader_parameter(&"lod_dither_anim", 1.0 if settings.antialiasing in ["taa", "metalfx"] else 0.0)
		_lod_mats[key] = m
	return _lod_mats[key]


## MultiMesh buffer: 12 floats of transform (rows of the 3x4 matrix) + 4 of custom data.
func _buffer(idx: PackedInt32Array, pos: PackedVector3Array, yaw: PackedFloat32Array, scl: PackedFloat32Array,
		custom: Variant, tilt: Variant, prop_kind: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(idx.size() * 16)
	var o := 0
	var has_custom := custom != null
	var cust: PackedColorArray = custom if has_custom else PackedColorArray()
	var has_tilt := tilt != null
	var tl: PackedVector3Array = tilt if has_tilt else PackedVector3Array()
	for i in idx:
		var e := Vector3(0.0, yaw[i], 0.0)
		if has_tilt:
			e.x = tl[i].x
			e.z = tl[i].z
		var b := Basis.from_euler(e).scaled(Vector3.ONE * scl[i])
		var p := pos[i]
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = p.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = p.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = p.z
		if has_custom:
			var cc := cust[i]
			buf[o + 12] = cc.r
			buf[o + 13] = cc.g
			buf[o + 14] = cc.b
			buf[o + 15] = cc.a
		else:
			var hsh := fposmod(p.x * 12.9898 + p.z * 78.233, 1.0)
			buf[o + 12] = hsh
			buf[o + 13] = 0.0
			buf[o + 14] = fposmod(hsh * 7.31, 1.0)
			buf[o + 15] = 0.0
		o += 16
	return buf


## Shadow-proxy instances: each tree's transform with the proxy (species pk, variant pv) scaled to
## the tree's own height, and with crowns = true also to its crown radius (x / z).
func _proxy_buffer(idx: PackedInt32Array, pk: int, pv: int, crowns: bool) -> PackedFloat32Array:
	var pinfo := Assets.tree(pk, pv)
	var ph := float(pinfo.get("height", 18.0))
	var pr := float(pinfo.get("crown_radius", 4.0))
	var buf := _buffer(idx, layout.tree_pos, layout.tree_yaw, layout.tree_scale, layout.tree_custom, null, -1)
	var o := 0
	for i in idx:
		var info := Assets.tree(layout.tree_kind[i], layout.tree_variant[i])
		var ky := float(info.get("height", ph)) / ph
		var kxz := float(info.get("crown_radius", pr)) / pr if crowns else ky
		# Rows of the 3x4 matrix: column 0 (x) = buf[o], [o+4], [o+8]; column 1 (y) = [o+1]...
		for j: int in [0, 4, 8]:
			buf[o + j] *= kxz
		for j: int in [1, 5, 9]:
			buf[o + j] *= ky
		for j: int in [2, 6, 10]:
			buf[o + j] *= kxz
		# the tree's season for the shadow crowns (canopy_dapple.gdshader: a bare broadleaf's shade thins)
		buf[o + 15] = Assets.leaf_code(layout.tree_kind[i])
		o += 16
	return buf


## Impostor instances: the trees' transforms; custom.x = atlas row, y = variation, z = dryness.
func _impostor_buffer(idx: PackedInt32Array) -> PackedFloat32Array:
	var buf := _buffer(idx, layout.tree_pos, layout.tree_yaw, layout.tree_scale, layout.tree_custom, null, -1)
	var o := 0
	for i in idx:
		var cc := layout.tree_custom[i]
		buf[o + 12] = float(maxi(Assets.impostor_row(layout.tree_kind[i], layout.tree_variant[i]), 0))
		buf[o + 13] = cc.r
		buf[o + 14] = cc.g
		buf[o + 15] = 0.0
		o += 16
	return buf


## Whether the crown blobs (TreeShadow4_*) go into SDFGI. Not while the forest light runs
## (scripts/world/env/forest_light.gd, 2026-09-26): its canopy terms take the sky light under the crowns
## in every preset, and SDFGI's blobs on top of them left black pockets where its probes sit in or
## under a blob (rocks and logs under the trees, the ground beside a conifer at a low sun). veg_gi=1
## puts them in anyway, veg_gi=0 keeps them out; forest_light=0 (the forest light off) puts them back.
static func gi_blobs() -> bool:
	var arg := _user_arg("veg_gi")
	if not TREES_IN_GI or arg == "0":
		return false
	return arg == "1" or _user_arg("forest_light") == "0"


static func _user_arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with(key + "="):
			return s.get_slice("=", 1)
	return ""
