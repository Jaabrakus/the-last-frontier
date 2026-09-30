class_name RiverWater
extends Node3D
## The river's water (WorldRiver; user 2026-09-27: the open land "with a river", "i know theres some realistic
## peformance based water tech right?"). FrontierLevel adds it where the river has ground.
##   surface   a ribbon HALF_W m either side of its centre at its level (its edges run under the banks: the water meets
##             the ground at 9.5-10 m), in CHUNK_M m meshes culled on their own and drawn to DRAW_M, UV2 its flow;
##             shaders/water/river.gdshader: flow-mapped ripples, colour by depth, refraction, the sky's reflection,
##             foam at the banks (tiling noise normal maps made at load: nothing to download)
##   reflects  the sky, clouds and all: a ReflectionProbe over it that sees only the sky (cull mask 0), refreshed every
##             SKY_REFRESH_S s as the day goes; it stands in for the global illumination's reflections (SDFGI's
##             voxels, blocky and dark on water), no ambient of its own (the ground about it lit as before)
##   water     the group TorchState.WATER_GROUP: is_under_water(pos) (a torch put out, the mammoth's drink: TorchState)
##   rapids    white water (WorldRiver.rapid_at: the mesh's vertex colour red): the shader runs it faster, choppier
##             and foaming; wading there the current slows the player more (RAPID_SLOW); a rock on each of its boulders
##             (data/world/river_boulders.json, the bake's: the ground has a bump under each), the vegetation's own
##             rock models, the water foaming round them
##   sound     the river running (river_flow_loop, tools/sfx/ambience.py) from its nearest point to the listener (a
##             line source, moved as they go), and a louder roar at each rapid (river_rapids_loop)
##   wading    over the ankles the player slows, WADE_SLOW.x of a run at WADE_DEPTH.x of water to .y at .y (chest
##             deep): FrontierPlayer.drag_speed_cap, as FootDrag and the wheelbarrow cap it (never over a cap of
##             theirs, and let go on the bank); splashes about the legs as they go
##   drinking  hold E at the water's edge, looking down at it (PlayerInteractor's "any other interactable": "Drink from the river"): kneels at
##             it (FrontierPlayer.begin_kneel, the search-low clips), DRINK_S s, a drink (SurvivalFood.drink_water when
##             thirst is on); moving gets up. Not offered with fishing gear out (FishingGear.gear_out)
## Headless (tests): no meshes; the water, the wading and the drinking all the same.

const SHADER_PATH := "res://shaders/water/river.gdshader"
const BOULDERS_PATH := "res://data/world/river_boulders.json"
## The boulders' white water (tools/environment/water/bake_wake.py) and its box.
const WAKE_PATH := "res://assets/environment/water/river_wake.png"
const WAKE_BOX_PATH := "res://assets/environment/water/river_wake.json"
const VegAssets := preload("res://scripts/world/vegetation/veg_assets.gd")
## The rock models the boulders take, in turn (VegAssets.PROPS: rock_a .. rock_e, boulder).
const BOULDER_KINDS := [7, 2, 5, 3, 7, 4, 6]
const HALF_W := 12.0
const STEP := 2.0
const CHUNK_M := 64.0
const ACROSS := 7
const DRAW_M := 900.0
const SKY_REFRESH_S := 30.0
const RAPID_SLOW := 0.75
const WADE_DEPTH := Vector2(0.15, 1.2)
const WADE_SLOW := Vector2(0.85, 0.4)
const SPLASH_S := 0.32
## The camera pitch (rad; down is negative) at which they are looking down at the water: the drink is offered from here.
const LOOK_DOWN_RAD := -0.4
const DRINK_REACH := 2.4
const DRINK_S := 2.6
const OUT_S := 1.3
const LIB := MammothButchery.LIB
const CLIP_IN := MammothButchery.CLIP_IN
const CLIP_LOOP := MammothButchery.CLIP_LOOP
const CLIP_OUT := MammothButchery.CLIP_OUT

var material: ShaderMaterial
var chunks: Array[MeshInstance3D] = []
var rocks: Array[MeshInstance3D] = []
var sky_probe: ReflectionProbe
## The running water's voice (kept at the river's nearest point) and each rapid's.
var flow_voice: AudioStreamPlayer3D
var rapid_voices: Array[AudioStreamPlayer3D] = []
var _sky_t := 0.0
var _sky_frames := 0
var player: FrontierPlayer
## PlayerInteractor's reach for this (the water's edge from the chest).
var interact_reach := DRINK_REACH + 0.6
## Drinks taken, splashes made (tests).
var drinks := 0
var splashes := 0
var drinking := false
var _cap := INF
var _splash_t := 0.0
var _offer := {}
var _ap: AnimationPlayer
var _blender: HorsePhaseBlender
var _phase := 0
var _t := 0.0


func _ready() -> void:
	add_to_group(TorchState.WATER_GROUP)
	add_to_group(PlacedWeapon.GROUP)
	if DisplayServer.get_name() != "headless":
		build()
	_voices()


## Its sounds: the running water, and a roar at each rapid (each started at a random point of its loop).
func _voices() -> void:
	if not Sfx.has(&"river_flow_loop"):
		return
	flow_voice = Sfx.make_player_3d(&"river_flow_loop", self)
	if flow_voice:
		flow_voice.play(randf() * 7.0)
	for r: Dictionary in WorldRiver.rapids():
		var zr := WorldRiver.z_range()
		if float(r.z) < zr.x or float(r.z) > zr.y:
			continue
		var v := Sfx.make_player_3d(&"river_rapids_loop", self)
		if v == null:
			continue
		v.global_position = Vector3(WorldRiver.x_at(float(r.z)), WorldRiver.level_at(float(r.z)) + 0.5, float(r.z))
		v.play(randf() * 5.0)
		rapid_voices.append(v)


## Whether pos lies under the river's water.
func is_under_water(pos: Vector3) -> bool:
	return pos.y < WorldRiver.surface_at(pos.x, pos.z)


# --- The surface -------------------------------------------------------------------------------------------------

func build() -> void:
	material = make_material()
	var zr := WorldRiver.z_range()
	var z := zr.x
	while z < zr.y - 0.01:
		var z1 := minf(z + CHUNK_M, zr.y)
		var mi := MeshInstance3D.new()
		mi.name = "Water_%d" % chunks.size()
		mi.mesh = ribbon(z, z1)
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.visibility_range_end = DRAW_M
		add_child(mi)
		chunks.append(mi)
		z = z1
	# the sky to reflect: a probe over all its bends, sky only
	var xs := PackedFloat32Array()
	var zz := zr.x
	while zz <= zr.y:
		xs.append(WorldRiver.x_at(zz))
		zz += 8.0
	var x0 := INF
	var x1 := -INF
	for x in xs:
		x0 = minf(x0, x)
		x1 = maxf(x1, x)
	_place_boulders()
	sky_probe = ReflectionProbe.new()
	sky_probe.name = "SkyProbe"
	sky_probe.size = Vector3(x1 - x0 + 2.0 * (HALF_W + 20.0), 80.0, zr.y - zr.x + 16.0)
	sky_probe.cull_mask = 0
	sky_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	sky_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(sky_probe)
	sky_probe.global_position = Vector3((x0 + x1) * 0.5, WorldRiver.level_at((zr.x + zr.y) * 0.5) + 30.0, (zr.x + zr.y) * 0.5)


## A rock on each of the rapids' boulders: seated so its crown stands a little over the bump's, its width the bump's,
## turned at random (seeded by its place).
func _place_boulders() -> void:
	if not FileAccess.file_exists(BOULDERS_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOULDERS_PATH))
	if not (d is Dictionary):
		return
	var i := 0
	for b: Array in (d as Dictionary).get("boulders", []):
		var kind: int = BOULDER_KINDS[i % BOULDER_KINDS.size()]
		i += 1
		var mesh := VegAssets.prop_mesh(kind, 0)
		if mesh == null:
			continue
		var bb := mesh.get_aabb()
		var r := float(b[2])
		var s := r * 1.7 / maxf(maxf(bb.size.x, bb.size.z), 0.01)
		var mi := MeshInstance3D.new()
		mi.name = "Boulder_%d" % i
		mi.mesh = mesh
		mi.material_override = VegAssets.prop_material(kind)
		mi.visibility_range_end = DRAW_M * 0.5
		add_child(mi)
		var yaw := fposmod(float(b[0]) * 12.9898 + float(b[1]) * 78.233, TAU)
		var top := float(b[3]) + 0.08
		mi.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * 0.8, s)),
				Vector3(float(b[0]), top - bb.end.y * s * 0.8, float(b[1])))
		rocks.append(mi)


## The water between z0 and z1: rows STEP m apart, ACROSS vertices from -HALF_W to +HALF_W of its centre at its level;
## UV (across 0..1, along in metres), UV2 its flow (downstream, x and z).
static func ribbon(z0: float, z1: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var rows := maxi(int(ceil((z1 - z0) / STEP)), 1)
	for r in rows + 1:
		var z := lerpf(z0, z1, float(r) / float(rows))
		var cx := WorldRiver.x_at(z)
		var lv := WorldRiver.level_at(z)
		var f := WorldRiver.flow_at(z)
		var side := Vector3(f.z, 0.0, -f.x)          # across, level with the ground
		var rw := WorldRiver.rapid_at(z)
		for a in ACROSS:
			var u := float(a) / float(ACROSS - 1)
			var p := Vector3(cx, lv, z) + side * lerpf(-HALF_W, HALF_W, u)
			verts.append(Vector3(p.x, lv, p.z))
			uvs.append(Vector2(u, z))
			uv2s.append(Vector2(f.x, f.z))
			normals.append(Vector3.UP)
			colors.append(Color(rw, 0.0, 0.0))
	for r in rows:
		for a in ACROSS - 1:
			var i := r * ACROSS + a
			# (Godot's front faces: (B - A) x (C - A) points away from the viewer; seen from above)
			idx.append_array([i, i + 1, i + ACROSS, i + 1, i + ACROSS + 1, i + ACROSS])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH)
	m.set_shader_parameter("ripple_a", _noise_normals(1765, 0.035, 6.0))
	m.set_shader_parameter("ripple_b", _noise_normals(1766, 0.018, 3.5))
	var foam := NoiseTexture2D.new()
	foam.width = 256
	foam.height = 256
	foam.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = 1767
	fn.frequency = 0.03
	fn.fractal_octaves = 3
	foam.noise = fn
	m.set_shader_parameter("foam_noise", foam)
	# the boulders' white water
	if ResourceLoader.exists(WAKE_PATH) and FileAccess.file_exists(WAKE_BOX_PATH):
		var box: Variant = JSON.parse_string(FileAccess.get_file_as_string(WAKE_BOX_PATH))
		if box is Dictionary:
			m.set_shader_parameter("wake_map", load(WAKE_PATH))
			m.set_shader_parameter("wake_box", Vector4(float(box.x0), float(box.z0), 1.0 / float(box.width_m), 1.0 / float(box.depth_m)))
	return m


## A tiling ripple normal map from noise (made at load: no texture to ship).
static func _noise_normals(seed_: int, freq: float, bump: float) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = bump
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	t.noise = n
	return t


# --- Wading, drinking ------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_place_flow_voice()
	if sky_probe == null:
		return
	# the sky's reflection as the day goes: a few frames of updating every SKY_REFRESH_S
	if _sky_frames > 0:
		_sky_frames -= 1
		if _sky_frames == 0:
			sky_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		return
	_sky_t += dt
	if _sky_t >= SKY_REFRESH_S:
		_sky_t = 0.0
		sky_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
		_sky_frames = 8


func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as FrontierPlayer
		if player == null:
			return
	_wade(dt)
	_update_offer()
	_drink_tick(dt)


func _wade(dt: float) -> void:
	var pos := player.global_position
	var surf := WorldRiver.surface_at(pos.x, pos.z)
	var depth := surf - pos.y if surf != WorldRiver.NO_WATER else 0.0
	if depth > WADE_DEPTH.x and not player.is_dead and player.riding == null:
		var k := clampf((depth - WADE_DEPTH.x) / (WADE_DEPTH.y - WADE_DEPTH.x), 0.0, 1.0)
		var cap := float(player.run_speed) * lerpf(WADE_SLOW.x, WADE_SLOW.y, k) * lerpf(1.0, RAPID_SLOW, WorldRiver.rapid_at(pos.z))
		if player.drag_speed_cap == INF or is_equal_approx(player.drag_speed_cap, _cap):
			player.drag_speed_cap = cap
			_cap = cap
		var v := Vector2(player.velocity.x, player.velocity.z).length()
		_splash_t -= dt
		if v > 0.6 and _splash_t <= 0.0:
			_splash_t = SPLASH_S * clampf(2.5 / v, 0.5, 1.5)
			_splash(Vector3(pos.x, surf, pos.z), v)
	elif _cap != INF:
		if is_equal_approx(player.drag_speed_cap, _cap):
			player.drag_speed_cap = INF
		_cap = INF


## The running water's voice at the river's nearest point to the listener (the camera, else the player).
func _place_flow_voice() -> void:
	if flow_voice == null:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var at: Vector3 = cam.global_position if cam else (player.global_position if player else Vector3.ZERO)
	var zr := WorldRiver.z_range()
	var z := clampf(at.z, zr.x, zr.y)
	flow_voice.global_position = Vector3(WorldRiver.x_at(z), WorldRiver.level_at(z) + 0.3, z)


## Water thrown up about the legs.
func _splash(at: Vector3, speed: float) -> void:
	splashes += 1
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.6
	p.explosiveness = 0.9
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.6 + speed * 0.4
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.07
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.9, 0.95, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	s.material = m
	p.mesh = s
	get_tree().current_scene.add_child(p)
	p.global_position = at + Vector3.UP * 0.05
	Fx._emit(p, false)


## The water's edge nearest the player (in it: straight under them), within DRINK_REACH: what E offers. Not while
## the player fishes (FishingGear.gear_out: the rod or the spear out; user 2026-09-28, the prompt off the screen then).
func _update_offer() -> void:
	_offer = {}
	if drinking or player.is_dead or player.riding != null or player.climbing != null or FishingGear.gear_out(player):
		return
	# offered when they look down at the water (user 2026-09-29), never from a boat, where E is getting out
	if player.pitch > LOOK_DOWN_RAD or BoatRider.of(player) != null:
		return
	var pos := player.global_position
	var z := pos.z
	var zr := WorldRiver.z_range()
	if z < zr.x or z > zr.y:
		return
	var cx := WorldRiver.x_at(z)
	var dx := pos.x - cx
	if absf(dx) > WorldRiver.bank() + DRINK_REACH:
		return
	var side := signf(dx) if absf(dx) > 0.01 else 1.0
	var edge := -1.0
	var r := 0.0
	while r <= WorldRiver.bank():
		if WorldRiver.surface_at(cx + side * r, z) == WorldRiver.NO_WATER:
			break
		edge = r
		r += 0.5
	if edge < 0.0:
		return
	var pt := Vector3(cx + side * minf(edge, absf(dx)), WorldRiver.level_at(z), z)
	if Vector2(pt.x - pos.x, pt.z - pos.z).length() > DRINK_REACH:
		return
	_offer = {"point": pt, "text": "Drink from the river"}


func interact_point() -> Vector3:
	return _offer.get("point", Vector3.INF)


## Drinking is a hold-E interaction (user 2026-09-29: "drinking is a hold E, and when you look down an interaction icon shows like the other
## times"): never the tap's, in the list a hold brings up, its "Hold E" hint showing when they look down at the water.
func interact_hold_only() -> bool:
	return true


func distance_from(pt: Vector3) -> float:
	if _offer.is_empty():
		return INF
	var q: Vector3 = _offer.point
	return Vector2(q.x - pt.x, q.z - pt.z).length()


func interact_prompt(_p: Node) -> String:
	return String(_offer.get("text", ""))


## No glow: the water says what it is.
func highlight_targets() -> Array:
	return []


func interact(p: Node) -> bool:
	var fp := p as FrontierPlayer
	if _offer.is_empty() or drinking or fp == null:
		return false
	_ap = fp.begin_kneel(self, _offer.point)
	if _ap == null:
		return false
	player = fp
	drinking = true
	_phase = 0
	_t = 0.0
	_blender = HorsePhaseBlender.new(_ap, fp, LIB)
	_blender.show_clip(CLIP_IN, 0.0, 0.0)
	_blender.update(0.0)
	return true


func _drink_tick(dt: float) -> void:
	if not drinking:
		return
	if player.is_dead or player.kneeling != self:
		_end()
		return
	if _phase < 2 and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3:
		_phase = 2
		_t = 0.0
	_t += dt
	match _phase:
		0:
			_blender.show_clip(CLIP_IN, minf(_t, _len(CLIP_IN)), 0.15)
			if _t >= _len(CLIP_IN):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(CLIP_LOOP, fposmod(_t, _len(CLIP_LOOP)), 0.3)
			if _t >= DRINK_S:
				_sip()
				_phase = 2
				_t = 0.0
		2:
			_blender.show_clip(CLIP_OUT, minf(_t, _len(CLIP_OUT)), 0.2)
			if _t >= minf(OUT_S, _len(CLIP_OUT)):
				_end()
				return
	_blender.update(dt)


func _sip() -> void:
	drinks += 1
	var br := SurvivalBridge.find(get_tree())
	if br and br.core:
		SurvivalFood.drink_water(br.core)
	if player.interactor:
		player.interactor.notice("You drink from the river: cold and clean", 3.0)


func _end() -> void:
	drinking = false
	if player and player.kneeling == self:
		player.end_kneel()


func _len(clip: String) -> float:
	var full := "%s/%s" % [LIB, clip]
	return _ap.get_animation(full).length if _ap and _ap.has_animation(full) else 1.0
