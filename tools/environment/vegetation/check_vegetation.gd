extends SceneTree
## Package C acceptance check C2 (look-dev spec, section 10). Headless is fine:
##
##   Godot --headless --path . -s tools/environment/vegetation/check_vegetation.gd -- --no-capture
##
## Prints one "ok" / "FAIL" line per check, the counts per species / variant / LOD budget, and ends
## with VEGETATION CHECK PASSED / FAILED (exit code 0 / 1).
##   sun        every protected point (spawn chest, firing line, the six dummy chests, the mover's
##              path at 1 m steps) sees the sun: its ray toward EnvironmentRig.sun_direction()
##              crosses no tree / sapling / shrub crown (sphere model of the layout) and hits no
##              vegetation collider within 200 m. Terrain or structure hits are reported (they are
##              other packages') but only vegetation fails the check.
##   zones      no vegetation collider in the flat zones (fort clearing |x|,|z| < 26, range lane
##              |x| < 14, -175 < z < -12) or within 1 m of them, none in the animation-test
##              corridors, and no vegetation instance of any kind standing in the flat zones
##   contract   trunks are Cylinder / Capsule shapes in bodies of group "trees"; rock bodies are in
##              group "rocks" with meta surface = "stone"; Sfx.surface_of gives wood / stone
##   determinism a second build of the layout is identical
##   counts     instances per species and variant, props per kind, triangle budgets per LOD

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const Layout := preload("res://scripts/world/vegetation/veg_layout.gd")
const RAY_LENGTH := 200.0

var failures := PackedStringArray()


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	var veg := lvl.get_node_or_null("Vegetation")
	if veg == null or veg.get("layout") == null:
		printerr("FAIL: no Vegetation node with a layout")
		print("VEGETATION CHECK FAILED")
		quit(1)
		return
	for i in 4:
		await physics_frame
	var layout: Layout = veg.get("layout")
	var space: PhysicsDirectSpaceState3D = (veg as Node3D).get_world_3d().direct_space_state
	var sun := EnvironmentRig.sun_direction()
	print("  sun direction ", sun, "  build stats ", JSON.stringify(veg.get("stats")))

	# The full layout including the clutter a windowed build adds (saplings, shrubs, ferns...).
	var full := Layout.new(layout.seed_value, sun)
	full.build(true, 1.0)
	_check_sun(full, space, sun, veg)
	_check_zones(full, veg)
	_check_contract(veg)
	_check_determinism(layout, sun)
	_print_counts(full)

	if failures.is_empty():
		print("VEGETATION CHECK PASSED")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("VEGETATION CHECK FAILED (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _check_sun(layout: Layout, space: PhysicsDirectSpaceState3D, sun: Vector3, veg: Node) -> void:
	var blocked_crowns := 0
	var blocked_colliders := 0
	var other_hits := PackedStringArray()
	for o: Vector3 in layout.protected_points():
		# Crowns (no colliders): every tree and plant of the layout.
		var hit := _crown_hit(layout, o, sun, layout.tree_pos, layout.tree_kind, layout.tree_variant, layout.tree_scale)
		if hit < 0:
			hit = _crown_hit(layout, o, sun, layout.plant_pos, layout.plant_kind, layout.plant_variant, layout.plant_scale)
			if hit >= 0:
				hit += 1000000
		if hit >= 0:
			blocked_crowns += 1
			print("    crown in the sun ray from %s: %s" % [o, "plant %d" % (hit - 1000000) if hit >= 1000000 else "tree %d" % hit])
		# Colliders: walk the ray, skipping non-vegetation hits (reported separately).
		var from := o
		var to := o + sun * RAY_LENGTH
		var exclude: Array[RID] = []
		for k in 8:
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.exclude = exclude
			var r := space.intersect_ray(q)
			if r.is_empty():
				break
			var c := r.collider as Node
			if c and veg.is_ancestor_of(c):
				blocked_colliders += 1
				print("    vegetation collider %s in the sun ray from %s at %s" % [c.name, o, (r.position as Vector3).snapped(Vector3.ONE * 0.1)])
				break
			other_hits.append("%s -> %s at %s" % [o, c.name if c else "?", (r.position as Vector3).snapped(Vector3.ONE * 0.1)])
			exclude.append((r.collider as CollisionObject3D).get_rid())
	_expect(blocked_crowns == 0, "sun: %d protected rays, crowns crossing them: %d" % [layout.protected_points().size(), blocked_crowns])
	_expect(blocked_colliders == 0, "sun: vegetation colliders in the protected rays: %d" % blocked_colliders)
	if not other_hits.is_empty():
		print("  note: non-vegetation hits on the protected sun rays (other packages): %d, e.g. %s" % [other_hits.size(), ", ".join(other_hits.slice(0, 4))])


func _crown_hit(layout: Layout, o: Vector3, sun: Vector3, pos: PackedVector3Array, kind: PackedInt32Array,
		variant: PackedInt32Array, scl: PackedFloat32Array) -> int:
	for i in pos.size():
		var p := pos[i]
		if p.distance_to(o) > RAY_LENGTH + 30.0:
			continue
		var cr: Array = layout.crown_spheres(kind[i], variant[i], p, scl[i])
		var cs: PackedVector3Array = cr[0]
		var rs: PackedFloat32Array = cr[1]
		for j in cs.size():
			var t := clampf((cs[j] - o).dot(sun), 0.0, RAY_LENGTH)
			if cs[j].distance_to(o + sun * t) < rs[j]:
				return i
	return -1


func _check_zones(layout: Layout, veg: Node) -> void:
	var bad := PackedStringArray()
	var shapes := 0
	for n in veg.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		shapes += 1
		var p := cs.global_position
		var r := _shape_radius(cs.shape)
		if FrontierTerrain.flat_distance(p.x, p.z) < 1.0 + r:
			bad.append("%s at %s (r %.2f)" % [cs.get_parent().name, p.snapped(Vector3.ONE * 0.1), r])
		for c: Vector2 in Layout.ANIM_CORRIDORS:
			# tests/anim/lib/foot_slip.gd walks north from c for (0.5 + settle + measure) * 6 + 3 m
			# (24 m by default); checked to the end of the range lane.
			if absf(p.x - c.x) < 0.7 + r and p.z < c.y + 1.0 + r and p.z > maxf(c.y - 150.0, FrontierTerrain.LANE_FLAT_Z_MIN):
				bad.append("anim corridor %s: %s" % [c, p.snapped(Vector3.ONE * 0.1)])
	_expect(bad.is_empty(), "zones: %d vegetation colliders, none in or within 1 m of the flat zones / anim corridors%s" % [
			shapes, "" if bad.is_empty() else " -- " + ", ".join(bad.slice(0, 6))])
	var inside := 0
	for arr: PackedVector3Array in [layout.tree_pos, layout.plant_pos, layout.prop_pos]:
		for p in arr:
			if FrontierTerrain.in_flat_zone(p.x, p.z):
				inside += 1
	_expect(inside == 0, "zones: vegetation instances standing in the flat zones: %d" % inside)


func _shape_radius(s: Shape3D) -> float:
	if s is CylinderShape3D:
		return (s as CylinderShape3D).radius
	if s is CapsuleShape3D:
		return (s as CapsuleShape3D).radius
	if s is BoxShape3D:
		var b := (s as BoxShape3D).size
		return Vector2(b.x, b.z).length() * 0.5
	if s is ConvexPolygonShape3D:
		var m := 0.0
		for q in (s as ConvexPolygonShape3D).points:
			m = maxf(m, Vector2(q.x, q.z).length())
		return m
	return 0.5


func _check_contract(veg: Node) -> void:
	var trunk_ok := true
	var rock_ok := true
	var n_trunk := 0
	var n_rock := 0
	for body in veg.find_children("*", "StaticBody3D", true, false):
		var b := body as StaticBody3D
		if b.is_in_group(&"trees"):
			for cs in b.get_children():
				n_trunk += 1
				if not ((cs as CollisionShape3D).shape is CylinderShape3D or (cs as CollisionShape3D).shape is CapsuleShape3D):
					trunk_ok = false
			if Sfx.surface_of(b, b.global_position + Vector3(0, 5, 0), Vector3.RIGHT) != "wood":
				trunk_ok = false
		if b.name.begins_with("Rocks"):
			n_rock += b.get_child_count()
			if not b.is_in_group(&"rocks") or String(b.get_meta(&"surface", "")) != "stone" \
					or Sfx.surface_of(b, b.global_position, Vector3.UP) != "stone":
				rock_ok = false
	_expect(trunk_ok and n_trunk > 300, "contract: %d trunk shapes are cylinders in group trees and sound as wood" % n_trunk)
	_expect(rock_ok and n_rock > 0, "contract: %d rock shapes in group rocks with surface stone" % n_rock)


func _check_determinism(layout: Layout, sun: Vector3) -> void:
	var again := Layout.new(layout.seed_value, sun)
	again.build(false)
	var same := again.tree_pos == layout.tree_pos and again.tree_kind == layout.tree_kind \
			and again.tree_scale == layout.tree_scale
	var collider_props := 0
	for k in layout.prop_kind:
		if Layout.prop_has_collider(k):
			collider_props += 1
	var again_colliders := 0
	for k in again.prop_kind:
		if Layout.prop_has_collider(k):
			again_colliders += 1
	_expect(same and collider_props == again_colliders,
			"determinism: a rebuild gives the same %d trees and %d collider props" % [layout.tree_pos.size(), collider_props])


func _print_counts(layout: Layout) -> void:
	var per := {}
	for i in layout.tree_pos.size():
		var key := "%s_v%d" % [Assets.SPECIES[layout.tree_kind[i]], layout.tree_variant[i]]
		per[key] = per.get(key, 0) + 1
	var plants := {}
	for i in layout.plant_pos.size():
		var key := "%s_v%d" % [Assets.SPECIES[layout.plant_kind[i]], layout.plant_variant[i]]
		plants[key] = plants.get(key, 0) + 1
	var props := {}
	for i in layout.prop_pos.size():
		var key: String = Assets.PROPS[layout.prop_kind[i]].name
		props[key] = props.get(key, 0) + 1
	print("  counts (full layout, clutter at density 1): trees %d, plants %d, props %d" % [
			layout.tree_pos.size(), layout.plant_pos.size(), layout.prop_pos.size()])
	var keys := per.keys()
	keys.sort()
	for k: String in keys:
		var info: Dictionary = Assets.tree_info().get(k, {})
		print("    %-18s %5d   LOD tris %s" % [k, per[k], str(info.get("lod_tris", []))])
	keys = plants.keys()
	keys.sort()
	for k: String in keys:
		print("    %-18s %5d" % [k, plants[k]])
	keys = props.keys()
	keys.sort()
	for k: String in keys:
		var info: Dictionary = Assets.props_info().get(k, {})
		print("    %-18s %5d   LOD tris %s" % [k, props[k], str(info.get("tris", []))])


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)
