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
## ROUND 3, the stock overlay (smash_r3 spec v2 §5.1-5.2; PERCENT's; RingArena.stock()): the water 6 m down in a tank 10 m
## round the deck, and the tank's edge a CURTAIN of falling water: a rim channel curtain_up_m over the deck spilling a sheet
## down to the water all round (shaders/ring/ring_curtain.gdshader, our own; its sound a low rush). The tank's walls hold
## the water only up to its surface (a collider no higher), so a body thrown at the curtain crosses its plane at any height
## and is out there (RingArena.is_out; curtain_splash(at) where it went through). The lip's sound: within lip_sound.near_m of
## any lip the lapping grows louder on that side, for the local player's ears only (a lapping loop at his nearest lip point).

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
## Round 3 (stock): the curtain (null in classic), the curtain's rush and the lip's lapping (the local player's), the
## curtain's splashes made (tests).
var curtain: MeshInstance3D
var curtain_splashes := 0
var lap: AudioStreamPlayer3D
var rush: Array[AudioStreamPlayer3D] = []
## Round 3 (stock): how loud the lip's lapping is now (dB; -INF silent) and the side it plays on (RingArena LIP_*; -1 none).
var lap_db := -INF
var lap_side := -1


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
		if RingArena.stock():
			_curtain()
	if RingArena.stock():
		_sounds()


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
	if RingArena.stock():
		_stock_tank()
		return
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


## The stock tank: its floor, and walls whose colliders hold the water only up to its surface (the curtain over them is
## water: a body crossing its plane is out, RingArena.is_out); drawn up to the rim channel curtain_up_m over the deck, the
## channel's stone trough along their top.
func _stock_tank() -> void:
	var t := tank_half
	var wt := RingArena.num("tank_wall_m", 0.8)
	var top := arena.top()
	var up := RingArena.num("curtain_up_m", 3.0)
	var hold := level_y + 0.3
	var body := StaticBody3D.new()
	body.name = "Tank"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"surface", "stone")
	add_child(body)
	var floor_box := AABB(Vector3(-t.x - wt, floor_y - 0.5, -t.y - wt), Vector3((t.x + wt) * 2.0, 0.5, (t.y + wt) * 2.0))
	var walls: Array[AABB] = []
	for y1: float in [hold, top + up]:
		walls.append_array([
			AABB(Vector3(t.x, floor_y, -t.y - wt), Vector3(wt, y1 - floor_y, (t.y + wt) * 2.0)),
			AABB(Vector3(-t.x - wt, floor_y, -t.y - wt), Vector3(wt, y1 - floor_y, (t.y + wt) * 2.0)),
			AABB(Vector3(-t.x, floor_y, t.y), Vector3(t.x * 2.0, y1 - floor_y, wt)),
			AABB(Vector3(-t.x, floor_y, -t.y - wt), Vector3(t.x * 2.0, y1 - floor_y, wt)),
		])
	for a: AABB in [floor_box] + walls.slice(0, 4):
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
	var cd := RingArena.block("curtain")
	var cw := float(cd.get("channel_w", 0.9))
	var ch := float(cd.get("channel_h", 0.5))
	var kit := StructureMeshKit.new()
	RingArena.wbox(kit, &"ring_wall", floor_box.get_center(), floor_box.size, 1.6, tint * 0.8, 8)
	for i in range(4, 8):
		RingArena.wbox(kit, &"ring_wall", walls[i].get_center(), walls[i].size, 1.6, tint, 8)
	# the rim channel: a stone trough over the walls' inner edge, its lip the curtain's
	var ct := tint * 1.25
	var y0 := top + up
	for a: AABB in [AABB(Vector3(t.x - cw * 0.5, y0, -t.y - cw * 0.5), Vector3(cw + wt * 0.5, ch, (t.y + cw * 0.5) * 2.0)),
			AABB(Vector3(-t.x - wt * 0.5 - cw * 0.5, y0, -t.y - cw * 0.5), Vector3(cw + wt * 0.5, ch, (t.y + cw * 0.5) * 2.0)),
			AABB(Vector3(-t.x, y0, t.y - cw * 0.5), Vector3(t.x * 2.0, ch, cw + wt * 0.5)),
			AABB(Vector3(-t.x, y0, -t.y - wt * 0.5 - cw * 0.5), Vector3(t.x * 2.0, ch, cw + wt * 0.5))]:
		RingArena.wbox(kit, &"ring_walk", a.get_center(), a.size, 1.2, ct, 0)
	var mi := MeshInstance3D.new()
	mi.name = "TankMesh"
	mi.mesh = kit.commit(arena.mats)
	body.add_child(mi)


## The curtain: a sheet of falling water from the rim channel's inner lip down to the tank's water, all round, facing in.
func _curtain() -> void:
	var cd := RingArena.block("curtain")
	var t := tank_half - Vector2(0.06, 0.06)
	var y_top := arena.top() + RingArena.num("curtain_up_m", 3.0) + 0.02
	var y_bot := level_y - 0.05
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var corners := [Vector2(-t.x, -t.y), Vector2(t.x, -t.y), Vector2(t.x, t.y), Vector2(-t.x, t.y)]
	var run := 0.0
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var l := a.distance_to(b)
		var along := (b - a) / l
		var inward := Vector3(-along.y, 0.0, along.x)
		var segs := maxi(int(l / 4.0), 1)
		for k in segs:
			var p0 := a.lerp(b, float(k) / float(segs))
			var p1 := a.lerp(b, float(k + 1) / float(segs))
			var u0 := run + l * float(k) / float(segs)
			var u1 := run + l * float(k + 1) / float(segs)
			var base := verts.size()
			verts.append_array([Vector3(p0.x, y_top, p0.y), Vector3(p1.x, y_top, p1.y), Vector3(p1.x, y_bot, p1.y), Vector3(p0.x, y_bot, p0.y)])
			uvs.append_array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, y_top - y_bot), Vector2(u0, y_top - y_bot)])
			normals.append_array([inward, inward, inward, inward])
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		run += l
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ring/ring_curtain.gdshader")
	mat.set_shader_parameter(&"tint", RingArena._tint(cd.get("tint"), Color(0.62, 0.82, 0.86)))
	mat.set_shader_parameter(&"foam", RingArena._tint(cd.get("foam"), Color(0.92, 0.97, 1.0)))
	mat.set_shader_parameter(&"alpha", float(cd.get("alpha", 0.82)))
	mat.set_shader_parameter(&"flow_mps", float(cd.get("flow_mps", 5.5)))
	mat.set_shader_parameter(&"height", y_top - y_bot)
	curtain = MeshInstance3D.new()
	curtain.name = "Curtain"
	curtain.mesh = mesh
	curtain.material_override = mat
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curtain)


## A body gone through the curtain at `at` (world): white water bursting out of the sheet there, and its sound.
func curtain_splash(at: Vector3, speed := 8.0) -> void:
	curtain_splashes += 1
	var l := to_local(at)
	var t := tank_half
	var n := Vector3.ZERO
	if absf(l.x) - t.x > absf(l.z) - t.y:
		n = Vector3(signf(l.x), 0.0, 0.0)
		l.x = signf(l.x) * t.x
	else:
		n = Vector3(0.0, 0.0, signf(l.z))
		l.z = signf(l.z) * t.y
	l.y = clampf(l.y, level_y, arena.top() + RingArena.num("curtain_up_m", 3.0))
	var p := to_global(l)
	var wn := global_basis * n
	var wd: Dictionary = RingArena.data().get("water", {})
	var k := int(wd.get("splash_n", 46))
	var mps := float(wd.get("splash_mps", 6.5)) * clampf(0.6 + speed * 0.06, 0.6, 1.6)
	BendLooks.burst(p, "water", k, -wn, 40.0, mps, 0.3)
	BendLooks.burst(p, "water", int(k * 0.5), wn, 60.0, mps * 0.5, 0.22)
	BendLooks.sound("water", "hit", p, 3.0)


## The curtain's rush (a quiet loop at each long side's middle) and the lip's lapping (the local player's: _process moves
## it to his nearest lip and sets its level).
func _sounds() -> void:
	var ls := RingArena.block("lip_sound")
	var s: Variant = load(String(ls.get("stream", ""))) if ResourceLoader.exists(String(ls.get("stream", ""))) else null
	if s is AudioStream:
		lap = AudioStreamPlayer3D.new()
		lap.name = "LipLap"
		lap.stream = _looped(s as AudioStream)
		lap.unit_size = 3.0
		lap.max_distance = 12.0
		lap.volume_db = -80.0
		lap.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
		add_child(lap)
	var cs := RingArena.block("curtain_sound")
	var r: Variant = load(String(cs.get("stream", ""))) if ResourceLoader.exists(String(cs.get("stream", ""))) else null
	if r is AudioStream:
		for sz: float in [-1.0, 1.0]:
			var p := AudioStreamPlayer3D.new()
			p.name = "CurtainRush"
			p.stream = _looped(r as AudioStream)
			p.unit_size = 14.0
			p.max_distance = 90.0
			p.volume_db = float(cs.get("db", -16.0))
			p.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
			p.position = Vector3(0.0, arena.top(), sz * tank_half.y)
			p.autoplay = true
			add_child(p)
			rush.append(p)


static func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			var bytes := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
			w.loop_end = int(w.data.size() / (bytes * (2 if w.stereo else 1)))
		return w
	return s


## The lip's lapping for the local player: near a lip (lip_sound.near_m) it plays from his nearest lip point, louder the
## nearer he is (quiet_db at near_m, loud_db at the lip); silent farther in and off the deck.
func _process(_dt: float) -> void:
	if lap == null or arena == null or not is_inside_tree():
		return
	var p := _local_player()
	var ls := RingArena.block("lip_sound")
	var near := float(ls.get("near_m", 4.0))
	lap_db = -INF
	lap_side = -1
	if p != null:
		var lip := arena.nearest_lip(p.global_position)
		var inside := -float(lip.out_m)
		if inside >= -0.5 and inside <= near:
			var f := clampf(1.0 - inside / near, 0.0, 1.0)
			lap_db = lerpf(float(ls.get("quiet_db", -34.0)), float(ls.get("loud_db", -4.0)), f)
			lap_side = int(lip.side)
			lap.global_position = (lip.point as Vector3) + Vector3.DOWN * 1.0
	if lap_db == -INF:
		if lap.playing:
			lap.stop()
		return
	lap.volume_db = lap_db
	if not lap.playing:
		lap.play()


## The player at this machine (the first in group "player" that is not another machine's).
func _local_player() -> Node3D:
	for n in get_tree().get_nodes_in_group(&"player"):
		if n is Node3D and not n.has_meta(&"net_peer"):
			return n as Node3D
	return null


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
