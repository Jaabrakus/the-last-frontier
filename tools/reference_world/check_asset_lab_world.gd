extends SceneTree
## Real physics ray comparisons, including points inside both cell triangles.

const Stage := preload("res://scripts/labs/asset_lab_world.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _non_terrain_rids(node: Node, terrain: StaticBody3D) -> Array[RID]:
	var result: Array[RID] = []
	if node is CollisionObject3D and node != terrain:
		result.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		result.append_array(_non_terrain_rids(child, terrain))
	return result


func _run() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	var stage_report := stage.build()
	_check(bool(stage_report.terrain.source_loaded), "Reference height sample must match retained SHA-256")
	_check(stage.terrain_heights.size() == 4225, "65x65 terrain sample count")
	_check(stage.terrain_shape.map_width == 65 and stage.terrain_shape.map_depth == 65, "HeightMapShape dimensions")
	var height_values := Array(stage.terrain_heights)
	_check(absf(float(height_values.min())) < 0.000001 and absf(float(height_values.max()) - 6.0) < 0.000001, "Preview normalization is 0..6 m")
	_check(stage_report.props.size() == 21, "Existing project tree and rock instances load")
	_check(int(stage_report.grass.clusters) > 2500 and not bool(stage_report.grass.collision), "Authored grass covers terrain without changing movement collision")
	_check(not bool(stage_report.surround.collision), "Authored backdrop remains presentation only")
	await physics_frame
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	var maximum_error := 0.0
	var excluded_props := _non_terrain_rids(stage, stage.terrain_body)
	var ray_points: Array[Vector2] = []
	for z in [-27, -19, -5, 0, 5, 17, 27]:
		for x in [-27, -19, -5, 0, 5, 17, 27]:
			for offset in [Vector2.ZERO, Vector2(0.2, 0.3), Vector2(0.7, 0.6)]:
				ray_points.append(Vector2(float(x), float(z)) + offset)
	for point in ray_points:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 15.0, point.y), Vector3(point.x, -5.0, point.y), 1)
		query.exclude = excluded_props
		var hit := space.intersect_ray(query)
		_check(not hit.is_empty(), "Terrain ray must hit at %s" % point)
		if hit.is_empty():
			continue
		_check(hit.collider == stage.terrain_body, "Terrain ray must hit height shape at %s" % point)
		var error := absf(float(hit.position.y) - stage.height_at(point))
		maximum_error = maxf(maximum_error, error)
		_check(error < 0.0001, "Terrain visual/physics height mismatch %.8f at %s" % [error, point])
	for point in [Vector2(80.0, 0.0), Vector2(86.0, 6.0), Vector2(89.0, 6.0), Vector2(77.0, -4.0), Vector2(83.0, -4.0)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 5.0, point.y), Vector3(point.x, -2.0, point.y), 1)
		var hit := space.intersect_ray(query)
		_check(not hit.is_empty() and absf(float(hit.get("position", Vector3.ONE).y)) < 0.00001, "Arena feet plane is Y=0 at %s" % point)
	for area in ["map", "arena"]:
		var position := stage.spawn_at(area)
		var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2.0, position - Vector3.UP * 2.0, 1)
		var hit := space.intersect_ray(query)
		_check(not hit.is_empty() and absf(position.y - float(hit.position.y) - 0.25) < 0.0001, "Spawn rests 0.25 m above %s surface" % area)
	var pools := get_nodes_in_group(Bending.POOLS)
	_check(pools.size() == 2, "Two visible water sources join Bending.POOLS")
	for point in [Vector3(70.0, 0.0, -10.0), Vector3(70.0, 0.0, 10.0), Vector3(90.0, 0.0, -10.0), Vector3(90.0, 0.0, 10.0), stage.spawn_at("map")]:
		var in_reach := false
		for pool in pools:
			if (pool as Node3D).global_position.distance_to(point) <= float(pool.get_meta(&"reach_m")):
				in_reach = true
		_check(in_reach, "Water source reaches arena corners and map spawn %s" % point)
	var result := {"checks": checks, "passed": failures.is_empty(), "failures": failures,
		"terrain_ray_count": ray_points.size(), "max_terrain_height_error_m": maximum_error, "stage": stage_report,
		"engine": Engine.get_version_info().string}
	var path := "res://artifacts/world_reference/lab_world_check.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print(JSON.stringify({"checks": checks, "failures": failures.size(), "max_height_error_m": maximum_error, "report": ProjectSettings.globalize_path(path)}))
	quit(0 if failures.is_empty() else 1)
