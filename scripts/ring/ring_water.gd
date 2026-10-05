class_name RingWater
extends Node3D
## The Tidebreak ring's tank and its water (RingArena makes it; data/ring/ring.json; the owner, 2026-10-04: off the edge "into
## the water wins the round"):
##   tank      a stone tank tank_margin m round the deck on every side: its floor at floor_y and its four walls up to the
##             deck's height, StaticBody3D colliders on layer 1, drawn in the fort's fieldstone with a green stain at the
##             waterline (the floor is drawn too: the water's look reads the depth behind it)
##   surface   the water at water_y over the tank round the deck (a grid with the deck's hole), RiverWater's own shader
##             (shaders/water/river.gdshader) in a material of its own (RiverWater.make_material, ring.json "water": the
##             colour of 2 m of clear water over stone, a slow drift; no ice: the world's global water_ice and snow_cover held
##             at 0 here), a sky-only ReflectionProbe over it as the river's; the grates' wells take the same material
##   ring-out  an Area3D filling the water round the deck (layer-1 bodies: the fighters, the stones): a body coming into it
##             splashes (splash(at): BendLooks' water burst and sound) and `splashed(body, at)` is said, for the match
##             (RingMode) to call the round; holds(body) whether it is in now
##   water     in the group TorchState.WATER_GROUP with is_under_water(pos) (a torch put out, as the river's)
## Headless (tests): the colliders, the area and the group only.

signal splashed(body: Node3D, at: Vector3)

var arena: RingArena
var material: ShaderMaterial
var surface: MeshInstance3D
var area: Area3D
var probe: ReflectionProbe
var visuals := true
## Splashes made (tests).
var splashes := 0
var level_y := -1.4
var floor_y := -3.4
## The tank's inside and the deck's plinth (its foot: RingArena.foot_half), half sizes (local x, z).
var tank_half := Vector2(23.0, 13.0)
var deck_half := Vector2(17.0, 7.0)


func setup(a: RingArena) -> void:
	arena = a
	visuals = DisplayServer.get_name() != "headless"
	level_y = RingArena.num("water_y", -1.4)
	floor_y = RingArena.num("floor_y", -3.4)
	tank_half = a.tank_half()
	deck_half = a.foot_half()
	add_to_group(TorchState.WATER_GROUP)
	_tank()
	_area()
	if visuals:
		_hold_globals()
		_surface()


## Whether pos lies in the tank's water (round the deck, under its surface).
func is_under_water(pos: Vector3) -> bool:
	var l := to_local(pos)
	if l.y >= level_y or l.y < floor_y - 0.5:
		return false
	if absf(l.x) > tank_half.x or absf(l.z) > tank_half.y:
		return false
	return absf(l.x) > deck_half.x or absf(l.z) > deck_half.y


## Whether `body` is in the water now (the area's last physics step, or its position under the surface).
func holds(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if area != null and body is PhysicsBody3D and area.is_inside_tree() and area.overlaps_body(body):
		return true
	return is_under_water(body.global_position)


## Water thrown up where something falls in: BendLooks' water burst (a spout and a ring of spray) and its sound.
func splash(at: Vector3, speed := 5.0) -> void:
	splashes += 1
	var wd: Dictionary = RingArena.data().get("water", {})
	var n := int(wd.get("splash_n", 46))
	var mps := float(wd.get("splash_mps", 6.5)) * clampf(0.6 + speed * 0.08, 0.6, 1.6)
	var p := Vector3(at.x, to_global(Vector3(0.0, level_y, 0.0)).y + 0.05, at.z)
	BendLooks.burst(p, "water", n, Vector3.UP, 28.0, mps, 0.3)
	BendLooks.burst(p, "water", int(n * 0.5), Vector3.UP, 85.0, mps * 0.5, 0.22)
	BendLooks.sound("water", "hit", p, 3.0)


# ---------------------------------------------------------------- the tank
func _tank() -> void:
	var t := tank_half
	var wt := RingArena.num("tank_wall_m", 0.8)
	var top := arena.top()
	var body := StaticBody3D.new()
	body.name = "Tank"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"surface", "stone")
	add_child(body)
	var boxes: Array[AABB] = [
		AABB(Vector3(-t.x - wt, floor_y - 0.5, -t.y - wt), Vector3((t.x + wt) * 2.0, 0.5, (t.y + wt) * 2.0)),       # the floor
		AABB(Vector3(t.x, floor_y, -t.y - wt), Vector3(wt, top - floor_y, (t.y + wt) * 2.0)),                     # the ends
		AABB(Vector3(-t.x - wt, floor_y, -t.y - wt), Vector3(wt, top - floor_y, (t.y + wt) * 2.0)),
		AABB(Vector3(-t.x, floor_y, t.y), Vector3(t.x * 2.0, top - floor_y, wt)),                                  # the sides
		AABB(Vector3(-t.x, floor_y, -t.y - wt), Vector3(t.x * 2.0, top - floor_y, wt)),
	]
	for a in boxes:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = a.size
		cs.shape = box
		cs.position = a.get_center()
		body.add_child(cs)
	if not visuals:
		return
	var looks: Dictionary = RingArena.data().get("looks", {})
	var tint := RingArena._tint((looks.get("tank", {}) as Dictionary).get("tint"), Color(0.5, 0.52, 0.5))
	var kit := StructureMeshKit.new()
	RingArena.wbox(kit, &"ring_wall", boxes[0].get_center(), boxes[0].size, 1.6, tint * 0.8, 8)
	for i in range(1, boxes.size()):
		RingArena.wbox(kit, &"ring_wall", boxes[i].get_center(), boxes[i].size, 1.6, tint, 8)
	var mi := MeshInstance3D.new()
	mi.name = "TankMesh"
	mi.mesh = kit.commit(arena.mats)
	body.add_child(mi)


## The water round the deck as an Area3D (its four parts, clear of the deck and the walls).
func _area() -> void:
	area = Area3D.new()
	area.name = "RingOut"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	area.monitoring = true
	add_child(area)
	var t := tank_half
	var d := deck_half
	var e := 0.05
	var y0 := floor_y + e
	var y1 := level_y + 0.15
	var parts: Array[AABB] = [
		AABB(Vector3(d.x + e, y0, -t.y + e), Vector3(t.x - d.x - e * 2.0, y1 - y0, (t.y - e) * 2.0)),
		AABB(Vector3(-t.x + e, y0, -t.y + e), Vector3(t.x - d.x - e * 2.0, y1 - y0, (t.y - e) * 2.0)),
		AABB(Vector3(-d.x, y0, d.y + e), Vector3(d.x * 2.0, y1 - y0, t.y - d.y - e * 2.0)),
		AABB(Vector3(-d.x, y0, -t.y + e), Vector3(d.x * 2.0, y1 - y0, t.y - d.y - e * 2.0)),
	]
	for a in parts:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = a.size
		cs.shape = box
		cs.position = a.get_center()
		area.add_child(cs)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is StaticBody3D or not is_instance_valid(body):
		return
	var v := Vector3.ZERO
	if body is CharacterBody3D:
		v = (body as CharacterBody3D).velocity
	elif body is RigidBody3D:
		v = (body as RigidBody3D).linear_velocity
	var at := body.global_position
	splash(at, v.length())
	splashed.emit(body, at)


# ---------------------------------------------------------------- the surface
## The world's ice and snow (SnowCover's globals, left from a winter's world before) held off here.
func _hold_globals() -> void:
	for g: StringName in [&"water_ice", &"snow_cover"]:
		if ProjectSettings.has_setting("shader_globals/" + String(g)):
			RenderingServer.global_shader_parameter_set(g, 0.0)


func _surface() -> void:
	var wd: Dictionary = RingArena.data().get("water", {})
	material = RiverWater.make_material()
	material.set_shader_parameter(&"wake_box", Vector4.ZERO)          # (no boulders' white water here)
	material.set_shader_parameter(&"flow_speed", float(wd.get("flow_speed", 0.12)))
	material.set_shader_parameter(&"deep_color", RingArena._tint(wd.get("deep_color"), Color(0.02, 0.075, 0.095)))
	material.set_shader_parameter(&"shallow_tint", RingArena._tint(wd.get("shallow_tint"), Color(0.7, 0.86, 0.88)))
	material.set_shader_parameter(&"absorb", float(wd.get("absorb", 0.55)))
	material.set_shader_parameter(&"ripple_strength", float(wd.get("ripple_strength", 0.3)))
	material.set_shader_parameter(&"water_roughness", float(wd.get("water_roughness", 0.03)))
	var fl: Array = wd.get("flow", [0.8, 0.35])
	var flow := Vector2(float(fl[0]), float(fl[1])).normalized()
	# the water round the deck: grid_m cells over the tank, none over the deck
	var g := float(wd.get("grid_m", 2.0))
	var t := tank_half
	var d := deck_half
	var pts := PackedVector3Array()
	var nx := ceili(t.x * 2.0 / g)
	var nz := ceili(t.y * 2.0 / g)
	for i in nx:
		for j in nz:
			var x0 := -t.x + float(i) * g
			var z0 := -t.y + float(j) * g
			var x1 := minf(x0 + g, t.x)
			var z1 := minf(z0 + g, t.y)
			var cx := (x0 + x1) * 0.5
			var cz := (z0 + z1) * 0.5
			if absf(cx) < d.x and absf(cz) < d.y:
				continue
			pts.append_array([Vector3(x0, level_y, z0), Vector3(x1, level_y, z0), Vector3(x1, level_y, z1), Vector3(x0, level_y, z1)])
	surface = MeshInstance3D.new()
	surface.name = "Water"
	surface.mesh = quads(pts, flow)
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(surface)
	var wells := arena.get_node_or_null(^"Grates/GrateWater") as MeshInstance3D
	if wells != null:
		wells.material_override = material
	# the sky to reflect (as the river's: a probe that sees only the sky), round the water only
	probe = ReflectionProbe.new()
	probe.name = "SkyProbe"
	probe.size = Vector3(t.x * 2.0 + 2.0, 2.6, t.y * 2.0 + 2.0)
	probe.cull_mask = 0
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.position = Vector3(0.0, level_y, 0.0)
	add_child(probe)


## Flat quads (four corners each, seen from above) as one mesh in RiverWater's layout: UV2 the drift (`flow`), no rapids.
static func quads(pts: PackedVector3Array, flow: Vector2) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for q in int(pts.size() / 4.0):
		var base := verts.size()
		for k in 4:
			var p := pts[q * 4 + k]
			verts.append(p)
			uvs.append(Vector2(p.x, p.z))
			uv2s.append(flow)
			normals.append(Vector3.UP)
			colors.append(Color(0.0, 0.0, 0.0))
		# (Godot's front faces: clockwise seen from the front; corners x0z0, x1z0, x1z1, x0z1 seen from above)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
