class_name TorchFire
extends Node3D
## The fire of a torch (push n01b): the flame (a core card and rising tongues), embers, smoke and the light.
## Child of the torch model's "Flame" marker; it keeps itself upright (flames rise whatever way the torch is held
## or lies) and follows the TorchState it is given.
##
##   var fire := TorchFire.new(); marker.add_child(fire); fire.state = torch_state
##
## The light (OmniLight3D): warm (about 1900 K), LIGHT_RANGE m, flickering (layered noise on the energy, a
## centimetre of jitter), lighting the player, the ground and the trees. Cheap by design (user 2026-09-25: the
## forest runs about 31 fps): a limited range, a distance fade (DISTANCE_FADE_M), and a shadow only where
## `shadows` asks for it (budget_shadows(); off by default, see PlayerTorch.shadows). Measured at night in the
## forest (tests/torch/tools/torch_cost.gd, 1600x900): +0.55 ms a frame per torch light, +1.4 ms with its shadow. The flame bends with the shared wind (wind_direction / wind_strength globals) and
## trails against the torch's own motion.
## Everything here is the project's own (procedural shaders, no textures).

const LIGHT_COLOR := Color(1.0, 0.62, 0.34)
const LIGHT_ENERGY := 1.6
const LIGHT_RANGE := 10.0
const DISTANCE_FADE_M := Vector2(35.0, 15.0)      ## begin, length
## The light's centre above the flame's base (m): the middle of the fire.
const LIGHT_UP := 0.14
const FLAME_SIZE := Vector2(0.15, 0.32)
const FLAME_SHADER := "res://shaders/torch/flame.gdshader"
const SMOKE_SHADER := "res://shaders/torch/smoke.gdshader"
const GROUP := &"torch_fires"
const CRACKLE := &"torch_crackle_loop"
## At most this many torch lights cast shadows (budget_shadows()).
const MAX_SHADOWED := 1


## The burning torch's state (strength, lit); null = burns at full strength.
var state: TorchState
## The light casts shadows (the held torch; set before or after _ready).
var shadows := false:
	set(v):
		shadows = v
		if light:
			light.shadow_enabled = v
## Light energy at full fire (tests and tuning).
var energy := LIGHT_ENERGY
## A bigger fire from the same parts (set before _ready; a campfire, Campfire): the flame card, the tongues, embers and
## smoke scale by `fire_size` (their amount by amount_mult); the light reaches light_range from light_up over the base.
var fire_size := 1.0
var amount_mult := 1.0
var light_range := LIGHT_RANGE
var light_up := LIGHT_UP
## Where the smoke rises from, over the fire (a hearth's: the top of its chimney).
var smoke_offset := Vector3.ZERO
## The torch is in the player's hand (budget_shadows() gives it the shadow first).
var held := false
## Raised overhead (hold T, push n01c; 0..1): the light reaches up to RAISED_REACH times farther (one light, the same
## shadow budget: only its range grows).
var raised := 0.0
const RAISED_REACH := 1.2

var light: OmniLight3D
## The fire's crackle (tools/sfx/fire.py torch_crackle_loop; null without the sound files).
var crackle: AudioStreamPlayer3D
var core: MeshInstance3D
var tongues: CPUParticles3D
var embers: CPUParticles3D
var smoke: CPUParticles3D

var _core_mat: ShaderMaterial
var _tongue_mat: ShaderMaterial
var _smoke_mat: ShaderMaterial
var _t := 0.0
var _last_pos := Vector3.INF
var _vel := Vector3.ZERO
var _noise := FastNoiseLite.new()
var _shown := -1.0
var _crackle_db := 0.0


func _ready() -> void:
	name = "Fire" if name == "" else name
	add_to_group(GROUP)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = LIGHT_COLOR
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.3
	light.light_specular = 0.35
	light.shadow_enabled = shadows
	light.shadow_bias = 0.06
	light.shadow_normal_bias = 1.5
	light.light_size = 0.08
	light.distance_fade_enabled = true
	light.distance_fade_begin = DISTANCE_FADE_M.x
	light.distance_fade_length = DISTANCE_FADE_M.y
	light.distance_fade_shadow = 20.0
	light.position = Vector3(0, light_up, 0)
	add_child(light)
	# the core: one upright card of fire
	core = MeshInstance3D.new()
	core.name = "Core"
	var q := QuadMesh.new()
	q.size = FLAME_SIZE * fire_size
	q.center_offset = Vector3(0, (FLAME_SIZE.y * 0.5 - 0.03) * fire_size, 0)
	core.mesh = q
	_core_mat = ShaderMaterial.new()
	_core_mat.shader = load(FLAME_SHADER) as Shader
	_core_mat.set_shader_parameter(&"seed", randf() * 50.0)
	core.material_override = _core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.extra_cull_margin = 0.3
	add_child(core)
	tongues = _particles("Tongues", _tongue_material(), Vector2(0.11, 0.18) * fire_size, TONGUES)
	embers = _particles("Embers", _ember_material(), Vector2(0.014, 0.014) * sqrt(fire_size), EMBERS)
	smoke = _particles("Smoke", _smoke_material(), Vector2(0.3, 0.3) * sqrt(fire_size), SMOKE)
	smoke.position = smoke_offset
	if not Sfx.config(CRACKLE).is_empty() and Sfx.has(CRACKLE):
		crackle = Sfx.make_player_3d(CRACKLE, self)
		if crackle:
			crackle.position = Vector3(0, light_up, 0)
			_crackle_db = crackle.volume_db
	_apply(0.0)


## A CPUParticles3D system (as the game's own effects, scripts/fx/fx.gd: a few dozen particles, no GPU process
## shader to compile or keep): `cfg` holds its emission, motion, size and colour.
func _particles(nm: String, mat: Material, size: Vector2, cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	p.amount = maxi(int(float(cfg.amount) * amount_mult), 1)
	p.lifetime = float(cfg.life)
	p.lifetime_randomness = 0.3
	# the tongues ride with the fire (world-space tongues trailed 2 m behind a running torch); embers and smoke are
	# left behind in the air
	p.local_coords = nm == "Tongues"
	var q := QuadMesh.new()
	q.size = size
	p.mesh = q
	p.material_override = mat
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(cfg.radius) * fire_size
	p.direction = Vector3.UP
	p.spread = float(cfg.spread)
	p.initial_velocity_min = float(cfg.v[0]) * sqrt(fire_size)
	p.initial_velocity_max = float(cfg.v[1]) * sqrt(fire_size)
	p.gravity = cfg.gravity
	p.damping_min = float(cfg.damp[0])
	p.damping_max = float(cfg.damp[1])
	p.scale_amount_min = float(cfg.scale[0])
	p.scale_amount_max = float(cfg.scale[1])
	if cfg.has("scale_curve"):
		var c := Curve.new()
		c.max_value = 3.0
		for pt: Vector2 in cfg.scale_curve:
			c.add_point(pt)
		p.scale_amount_curve = c
	if cfg.has("angle"):
		p.angle_min = -180.0
		p.angle_max = 180.0
	var g := Gradient.new()
	var cols: Array = cfg.colors
	g.set_color(0, cols[0][1])
	g.set_offset(0, cols[0][0])
	g.set_color(1, cols[cols.size() - 1][1])
	g.set_offset(1, cols[cols.size() - 1][0])
	for k in range(1, cols.size() - 1):
		g.add_point(cols[k][0], cols[k][1])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5) * fire_size, Vector3(3, 4, 3) * fire_size)
	add_child(p)
	return p


## Rising tongues of flame round the core.
const TONGUES := {"amount": 16, "life": 0.42, "radius": 0.025, "spread": 12.0, "v": [0.25, 0.5],
		"gravity": Vector3(0, 1.2, 0), "damp": [0.5, 1.0], "scale": [0.8, 1.3],
		"scale_curve": [Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.15)],
		"colors": [[0.0, Color(1.0, 0.8, 0.45, 0.9)], [0.35, Color(1.0, 0.5, 0.12, 0.8)], [1.0, Color(0.8, 0.12, 0.02, 0.0)]]}
## Sparks thrown up by the resin.
const EMBERS := {"amount": 8, "life": 1.4, "radius": 0.04, "spread": 35.0, "v": [0.6, 1.4],
		"gravity": Vector3(0, 0.4, 0), "damp": [0.6, 1.2], "scale": [0.5, 1.2],
		"colors": [[0.0, Color(1.0, 0.8, 0.4, 1.0)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]]}
## Pine soot.
const SMOKE := {"amount": 10, "life": 2.6, "radius": 0.04, "spread": 10.0, "v": [0.5, 0.8],
		"gravity": Vector3(0, 0.25, 0), "damp": [0.3, 0.5], "scale": [0.8, 1.2], "angle": true,
		"scale_curve": [Vector2(0, 0.35), Vector2(1, 2.2)],
		"colors": [[0.0, Color(0.1, 0.09, 0.08, 0.0)], [0.12, Color(0.08, 0.07, 0.06, 0.2)], [0.6, Color(0.1, 0.09, 0.08, 0.08)],
				[1.0, Color(0.1, 0.09, 0.08, 0.0)]]}


func _tongue_material() -> ShaderMaterial:
	_tongue_mat = ShaderMaterial.new()
	_tongue_mat.shader = load(FLAME_SHADER) as Shader
	_tongue_mat.set_shader_parameter(&"particle", true)
	_tongue_mat.set_shader_parameter(&"seed", randf() * 50.0)
	return _tongue_mat


func _ember_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(4.0, 1.6, 0.4)
	m.albedo_texture = _dot_texture()
	m.disable_fog = true
	return m


func _smoke_material() -> ShaderMaterial:
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = load(SMOKE_SHADER) as Shader
	return _smoke_mat


static func _dot_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


func _process(delta: float) -> void:
	_apply(delta)


## One frame: upright, the carrier's velocity (the flame trails), the strength and the flicker.
func _apply(delta: float) -> void:
	_t += delta
	if is_inside_tree():
		# upright whatever the torch does (the parent is the torch's Flame marker)
		global_basis = Basis.IDENTITY
		var p := global_position
		if delta > 0.0 and _last_pos != Vector3.INF:
			var v := (p - _last_pos) / delta
			if v.length() > 20.0:
				v = Vector3.ZERO   # a teleport
			_vel = _vel.lerp(v, 1.0 - exp(-10.0 * delta))
		_last_pos = p
		if _smoke_mat:
			_smoke_mat.set_shader_parameter(&"fire_pos", p + smoke_offset + Vector3(0, light_up, 0))
	var s := state.strength() if state != null else 1.0
	var on := s > 0.001
	var flick := 1.0
	if on:
		var n1 := _noise.get_noise_1d(_t * 7.0)
		var n2 := _noise.get_noise_1d(_t * 23.0 + 50.0)
		var gust := _noise.get_noise_1d(_t * 0.8 + 100.0)
		flick = 0.86 + 0.11 * n1 + 0.05 * n2 - 0.06 * maxf(gust, 0.0)
		light.position = Vector3(0.012 * n2, light_up + 0.015 * n1, 0.012 * _noise.get_noise_1d(_t * 17.0 + 30.0)) * Vector3(fire_size, 1.0, fire_size)
	light.visible = on
	light.light_energy = energy * s * flick
	light.omni_range = light_range * (0.55 + 0.45 * s) * lerpf(1.0, RAISED_REACH, clampf(raised, 0.0, 1.0))
	var lean := -_vel * 0.09
	lean.y = 0.0
	lean = lean.limit_length(0.9)
	for m: ShaderMaterial in [_core_mat, _tongue_mat]:
		if m:
			m.set_shader_parameter(&"strength", s * (0.9 + 0.1 * flick))
			m.set_shader_parameter(&"lean", lean)
	core.visible = on
	core.scale = Vector3.ONE * (0.55 + 0.45 * s)
	var shown := 1.0 if on else 0.0
	if shown != _shown:
		_shown = shown
		tongues.emitting = on
		embers.emitting = on
	smoke.emitting = on or (state != null and state.burn_left > 0.0 and _t < 3.0)
	if crackle:
		if on and not crackle.playing:
			crackle.play(randf() * 7.0)
		elif not on and crackle.playing:
			crackle.stop()
		crackle.volume_db = _crackle_db + linear_to_db(maxf(s, 0.05))
	var wind := _wind()
	tongues.gravity = Vector3(0, 1.2, 0) + wind * 0.8 - Vector3(_vel.x, 0, _vel.z) * 0.8
	smoke.gravity = Vector3(0, 0.25, 0) + wind * 1.2
	embers.gravity = Vector3(0, 0.4, 0) + wind * 1.0


## Shadows on at most `max_n` torch lights (each shadowed omni light renders its casters again; PlayerTorch passes 0
## unless its `shadows` is on): the held torch's first (it lights the player and what is right around), else the lit
## torches nearest `from`.
static func budget_shadows(tree: SceneTree, from: Vector3, max_n := MAX_SHADOWED) -> void:
	if tree == null:
		return
	var lit: Array = []
	for n in tree.get_nodes_in_group(GROUP):
		var f := n as TorchFire
		if f == null or not f.is_inside_tree():
			continue
		var d := f.global_position.distance_to(from) - (1000.0 if f.held else 0.0)
		lit.append([d, f])
	lit.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in lit.size():
		var f: TorchFire = lit[i][1]
		var on := i < max_n and f.state != null and f.state.lit
		if f.shadows != on:
			f.shadows = on


static var _wind_v := Vector3.INF


## The shared wind (a push toward wind_direction at wind_strength, the shader globals the vegetation sways
## with; the flame's cards read the globals themselves). The particles take the project's values (EnvironmentRig
## sets the same constants; a weather system that changes the wind can set `wind` here too).
static func _wind() -> Vector3:
	if _wind_v == Vector3.INF:
		var d: Variant = (ProjectSettings.get_setting("shader_globals/wind_direction", {}) as Dictionary).get("value", Vector2.ZERO)
		var s: Variant = (ProjectSettings.get_setting("shader_globals/wind_strength", {}) as Dictionary).get("value", 0.0)
		var v := (d as Vector2).normalized() * float(s) if d is Vector2 else Vector2.ZERO
		_wind_v = Vector3(v.x, 0, v.y)
	return _wind_v


## Sets the wind the particles lean with (x/z push, world space).
static func set_wind(direction: Vector2, strength: float) -> void:
	var v := direction.normalized() * strength
	_wind_v = Vector3(v.x, 0, v.y)
