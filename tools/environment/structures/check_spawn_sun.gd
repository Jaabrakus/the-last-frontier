extends SceneTree
## Spawn sunlight against the real structure meshes (look-dev spec 3.2 / 7.4; package D).
## tools/environment/lighting/spawn_sun_check.py models the fort as boxes; this builds
## FrontierStructures with its meshes (palisade points, shingle roofs, the taller chimney, log
## ends, props), turns every triangle into one trimesh collider and casts rays from 75 points on
## a character standing at the spawn (0, 0, 6) toward the sun at 19.1 deg elevation.
##
##   Godot --headless --path . -s tools/environment/structures/check_spawn_sun.gd -- --no-capture
##
## Prints lit points per azimuth (214..234 deg) and SPAWN SUN OK when all 75 are lit at
## EnvironmentRig.SUN_AZIMUTH_DEG (222.5).


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1776
	var s := FrontierStructures.new()
	s.force_visuals = true
	s.occluders = false
	root.add_child(s)
	s.build(WorldSettings.preset("high"), rng)
	await process_frame
	var faces := PackedVector3Array()
	_collect(s, faces)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	s.queue_free()     # its own colliders would count too; the meshes are what cast shadows
	await physics_frame
	await physics_frame
	print("SPAWN SUN triangles=%d" % (faces.size() / 3))
	var space := body.get_world_3d().direct_space_state
	var pts: Array[Vector3] = []
	for ix in 5:
		for iz in 5:
			for h: float in [0.1, 0.9, 1.7]:
				pts.append(Vector3(-0.3 + 0.15 * ix, h, 6.0 - 0.3 + 0.15 * iz))
	var el := deg_to_rad(EnvironmentRig.SUN_ELEVATION_DEG)
	var target := 0
	var azs: Array[float] = [EnvironmentRig.SUN_AZIMUTH_DEG]
	for a in range(214, 236, 2):
		azs.append(float(a))
	for az_deg in azs:
		var az := deg_to_rad(az_deg)
		var sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
		var lit := 0
		for p in pts:
			var q := PhysicsRayQueryParameters3D.create(p, p + sun * 80.0)
			if space.intersect_ray(q).is_empty():
				lit += 1
		print("SPAWN SUN az %.1f: %d/%d points lit" % [az_deg, lit, pts.size()])
		if az_deg == EnvironmentRig.SUN_AZIMUTH_DEG:
			target = lit
	print("SPAWN SUN OK" if target == pts.size() else "SPAWN SUN SHADOWED (%d/%d at %.1f)" % [target, pts.size(), EnvironmentRig.SUN_AZIMUTH_DEG])
	quit(0 if target == pts.size() else 1)


func _collect(n: Node, faces: PackedVector3Array) -> void:
	if n is TargetDummy:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var t := mi.global_transform
		for v in mi.mesh.get_faces():
			faces.append(t * v)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
		var mm := (n as MultiMeshInstance3D).multimesh
		var f := mm.mesh.get_faces()
		var base := (n as Node3D).global_transform
		for i in mm.instance_count:
			var t := base * mm.get_instance_transform(i)
			for v in f:
				faces.append(t * v)
	for c in n.get_children():
		_collect(c, faces)
