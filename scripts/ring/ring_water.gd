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
## ROUND 4 (IMPACT; the owner's ring-out moment, "the splash"): ko_splash(at, speed, k) for a fall (RingMoment calls it on
## every KO, and on a classic rang_out): a column of water 5-8 m tall from the body's entry speed (k 2 on a game's last fall:
## twice its size), a ring of spray sheets thrown out round it, a ripple ring running out over the tank and foam that lies on
## the water for foam_s, with ringout_splash at +3 dB and a low layer (knock_thud at pitch 0.6). Our own: ToonFx's water
## particles through ToonFxPool.shoot, and two flat meshes of our own (the ripple's ring, the foam's disc) in shaders written
## here (soft white water, lit, no outline). Its numbers in data/ring/feel.json ko_splash. Headless: counted (ko_splashes,
## last_ko) and nothing drawn.

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
## Round 4: the KO splashes made and the last one ({at, speed, k, column_m}) (tests, the review), and the ripples and foam
## lying on the water now: [mesh, t, life, kind, r0, r1].
var ko_splashes := 0
var last_ko := {}
var _ko_fx: Array = []
static var _ripple_shader: Shader
static var _foam_shader: Shader


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


# ---------------------------------------------------------------- round 4: the KO splash
## A fall into the water at `at` (world; its x, z on the water) at `speed` m/s, `k` its size (2: a game's last fall). See the
## header. The point is kept inside the tank (a body out past the curtain splashes just inside it).
func ko_splash(at: Vector3, speed := 10.0, k := 1.0, warming := false) -> void:
	var d := BendImpact.block("ko_splash")
	var l := to_local(at)
	l.x = clampf(l.x, -tank_half.x + 0.8, tank_half.x - 0.8)
	l.z = clampf(l.z, -tank_half.y + 0.8, tank_half.y - 0.8)
	l.y = level_y
	var p := to_global(l) + Vector3.UP * 0.05
	var cm := BendImpact.pair("ko_splash", "column_m", Vector2(5.0, 8.0))
	var sp := BendImpact.pair("ko_splash", "speed_mps", Vector2(6.0, 20.0))
	var f := clampf((speed - sp.x) / maxf(sp.y - sp.x, 0.01), 0.0, 1.0)
	var col_h := lerpf(cm.x, cm.y, f) * k
	if not warming:
		ko_splashes += 1
		last_ko = {"at": p, "speed": speed, "k": k, "column_m": col_h}
		BendSounds.play(&"ringout_splash", p, float(d.get("sound_db", 3.0)))
		BendSounds.play(&"knock_thud", p, float(d.get("low_db", 0.0)), float(d.get("low_pitch", 0.6)))
	if not visuals or DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var pool := ToonFxPool.of(get_tree().current_scene if get_tree().current_scene != null else self)
	if pool == null:
		return
	var g := float(d.get("gravity", 14.0))
	var vc := sqrt(2.0 * g * col_h)
	var life := 2.0 * vc / g
	var grav := Vector3(0.0, -g, 0.0)
	var drop := float(d.get("drop_m", 0.26)) * sqrt(k)
	# the column: a tight core of drops, a wider sheath, white water climbing inside it, mist off its top
	pool.shoot("drop", p, 48, Vector3.UP, 3.0, Vector2(vc * 0.82, vc), Vector2(drop * 0.8, drop * 1.4), life, grav, 0.0,
			{"r": 0.35 * k})
	pool.shoot("drop", p, 48, Vector3.UP, 9.0, Vector2(vc * 0.55, vc * 0.85), Vector2(drop * 0.6, drop * 1.1), life * 0.9, grav,
			0.0, {"r": 0.6 * k})
	pool.shoot("foam", p, 32, Vector3.UP, 6.0, Vector2(vc * 0.4, vc * 0.85), Vector2(1.1, 2.0) * k, life * 0.8, grav * 0.9,
			0.5, {"r": 0.5 * k})
	pool.shoot("foam", p, 32, Vector3.UP, 14.0, Vector2(vc * 0.2, vc * 0.5), Vector2(1.4, 2.4) * k, life * 0.7, grav * 0.8,
			0.8, {"r": 0.8 * k})
	pool.shoot("puff_steam", p + Vector3.UP * col_h * 0.6, 24, Vector3.UP, 50.0, Vector2(0.5, 2.0), Vector2(1.0, 2.0) * k,
			1.6, Vector3(0.0, -0.6, 0.0), 1.0, {"r": 0.8 * k})
	# the spray sheets: a ring thrown out and up round the column
	var n := int(d.get("sheets", 6))
	var rot := ToonFx.vis_rng.randf() * TAU
	var sv := float(d.get("sheet_mps", 8.0)) * sqrt(k)
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		var out := Vector3(cos(a), 0.0, sin(a))
		pool.shoot("drop", p + out * 0.5 * k, 40, (out + Vector3.UP * float(d.get("sheet_up", 1.3))).normalized(), 9.0,
				Vector2(sv * 0.6, sv), Vector2(drop * 0.5, drop * 0.9), 1.1, grav, 0.0, {"box": Vector3(0.5, 0.1, 0.5) * k})
	pool.shoot("foam", p, 32, Vector3.UP, 85.0, Vector2(2.0, 4.5) * sqrt(k), Vector2(0.6, 1.1) * k, 0.9, grav * 0.5, 2.0,
			{"r": 1.0 * k, "flat": 0.8})
	# the ripple's rings on the tank and the foam lying on it
	var rr := BendImpact.pair("ko_splash", "ripple_m", Vector2(0.8, 7.0))
	var rs := float(d.get("ripple_s", 1.4))
	var fm := float(d.get("foam_m", 2.6))
	_ko_mesh("ripple", p, rs, rr.x * k, rr.y * k)
	_ko_mesh("ripple", p, rs * 1.25, rr.x * k, rr.y * k * 0.7, 0.18)
	_ko_mesh("foam", p, float(d.get("foam_s", 3.0)), fm * k * 0.6, fm * k)


## One of the splash's flat meshes on the water (kind "ripple": a ring running out; "foam": a disc spreading and thinning),
## starting `delay` s from now.
func _ko_mesh(kind: String, p: Vector3, life: float, r0: float, r1: float, delay := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "KoRipple" if kind == "ripple" else "KoFoam"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 2.0)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _ko_shader(kind)
	mat.set_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	mi.global_position = p + Vector3.UP * (0.02 if kind == "ripple" else 0.03)
	mi.scale = Vector3.ONE * maxf(r0, 0.01)
	mi.visible = delay <= 0.0
	_ko_fx.append([mi, -delay, life, kind, r0, r1])


## The ripple's and the foam's shaders (ours, made once): soft white water lit by the ring's light (noon and night alike),
## alpha only; `t` 0..1 its age.
static func _ko_shader(kind: String) -> Shader:
	if kind == "ripple" and _ripple_shader != null:
		return _ripple_shader
	if kind == "foam" and _foam_shader != null:
		return _foam_shader
	var sh := Shader.new()
	var head := "shader_type spatial;\nrender_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;\n" \
			+ "uniform float t = 0.0;\nuniform float seed = 0.0;\n" \
			+ "float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }\n" \
			+ "float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);\n" \
			+ "  return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }\n"
	if kind == "ripple":
		sh.code = head + "void fragment() {\n  vec2 q = UV * 2.0 - 1.0; float r = length(q);\n" \
				+ "  float band = smoothstep(0.78, 0.9, r) * (1.0 - smoothstep(0.9, 1.0, r));\n" \
				+ "  float inner = smoothstep(0.55, 0.75, r) * (1.0 - smoothstep(0.75, 0.82, r)) * 0.45;\n" \
				+ "  float n = vn(vec2(atan(q.y, q.x) * 6.0, r * 4.0) + seed) * 0.5 + 0.5;\n" \
				+ "  ALBEDO = vec3(0.86, 0.95, 1.0); ROUGHNESS = 0.35;\n  ALPHA = (band + inner) * n * (1.0 - t) * (1.0 - t) * 0.9;\n}\n"
		_ripple_shader = sh
	else:
		sh.code = head + "void fragment() {\n  vec2 q = UV * 2.0 - 1.0; float r = length(q);\n" \
				+ "  float cells = vn(q * 7.0 + seed) * 0.6 + vn(q * 17.0 - seed) * 0.4;\n" \
				+ "  float lace = smoothstep(0.42 + t * 0.3, 0.62 + t * 0.25, cells);\n" \
				+ "  float edge = 1.0 - smoothstep(0.55, 1.0, r + (cells - 0.5) * 0.3);\n" \
				+ "  ALBEDO = vec3(0.9, 0.97, 1.0); ROUGHNESS = 0.6;\n  ALPHA = lace * edge * (1.0 - smoothstep(0.55, 1.0, t)) * 0.85;\n}\n"
		_foam_shader = sh
	return sh


## The splash's ripples and foam: grown, aged, gone at their end.
func _step_ko_fx(dt: float) -> void:
	var i := 0
	while i < _ko_fx.size():
		var e: Array = _ko_fx[i]
		var mi := e[0] as MeshInstance3D
		if not is_instance_valid(mi):
			_ko_fx.remove_at(i)
			continue
		e[1] = float(e[1]) + dt
		var age := float(e[1])
		if age < 0.0:
			i += 1
			continue
		mi.visible = true
		var t := clampf(age / maxf(float(e[2]), 0.01), 0.0, 1.0)
		var grow := 1.0 - pow(1.0 - t, 2.2) if String(e[3]) == "ripple" else 1.0 - pow(1.0 - t, 3.0)
		mi.scale = Vector3.ONE * maxf(lerpf(float(e[4]), float(e[5]), grow), 0.01)
		(mi.material_override as ShaderMaterial).set_shader_parameter(&"t", t)
		if t >= 1.0:
			mi.queue_free()
			_ko_fx.remove_at(i)
			continue
		i += 1


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
	if not visuals or arena.use_mesh:
		return                                   # (an arena mesh draws its own tank and rim)
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
	if not _ko_fx.is_empty():
		_step_ko_fx(_dt)
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
			if arena != null and RingArena.oval():
				# (the oval deck: a cell is left out only when all of it lies under the deck; the rest of the water is whole)
				if arena.inside_deck(x0, z0, 0.3) and arena.inside_deck(x1, z0, 0.3) and arena.inside_deck(x1, z1, 0.3) and arena.inside_deck(x0, z1, 0.3):
					continue
			elif absf(cx) < d.x and absf(cz) < d.y:
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
