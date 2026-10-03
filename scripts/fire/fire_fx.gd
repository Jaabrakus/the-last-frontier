class_name FireFx
extends Node3D
## What a burning piece shows (scripts/fire; FireSpread makes one for each piece alight): tongues of flame over the
## piece (the torch's flame shader, shaders/torch/flame.gdshader, on big cards), dark smoke rolling off its top and
## embers thrown up, all bent by the wind. No light of its own: every fire shares FireSpread's one light.
## Cheap by design (the audit's raid budget: 20 pieces alight within a millisecond on medium): GPU particles (the
## CPU does nothing for them per frame), a few dozen each, one shared draw material per kind (one shader, one
## material: the pieces differ only in their emission box), how many it throws sized once from the piece (a change of
## `amount` restarts a system; `amount_ratio` follows the fire's strength smoothly). The smoke and embers are off past
## NEAR_M from the camera, the flames past FAR_M (a burning town at night is seen by its flames; the smoke column,
## FireFx.column(), shows from anywhere). Low quality throws half and no embers.
##
##   var fx := FireFx.make(parent, world_box, quality)     # a piece's world AABB
##   fx.catch_at(point)                                     # catching: small flames where it caught
##   fx.spread_over(world_box)                              # alight all over
##   fx.strength = 0.7                                      # 0..1 how hard it burns
##   fx.set_distance(d)                                     # from the camera (m)
##   fx.die()                                               # the flames go out; the smoke thins and it frees itself
##
## Everything is the project's own (procedural textures and shaders).

## Past these distances from the camera: the smoke and embers off, then the flames.
const NEAR_M := 170.0
const FAR_M := 380.0
## Seconds the smoke goes on thinning after the flames are out, before the node frees itself.
const SMOULDER_S := 14.0
const FLAME_LIFE := 0.9
const SMOKE_LIFE := 5.0
const EMBER_LIFE := 2.4
const COLUMN_LIFE := 30.0
## The wind's push on each (m/s² at the wind's full strength 1; ParticleProcessMaterial gravity keeps accelerating
## them, so these are small: at a usual 0.3 the smoke drifts 4-5 m in its life, the column 20 m in its 30 s).
const WIND_FLAME := 2.0
const WIND_SMOKE := 1.2
const WIND_EMBER := 1.0
const WIND_COLUMN := 0.15
const COLUMN_RISE := 0.05

var flames: GPUParticles3D
var smoke: GPUParticles3D
var embers: GPUParticles3D
## 0..1: how hard it burns (the share of the particles thrown).
var strength := 0.0:
	set(v):
		var nv := clampf(v, 0.0, 1.0)
		if absf(nv - strength) < 0.005 and flames != null:
			return              # (set every tick: the systems are only touched when it changes)
		strength = nv
		_apply_strength()
var quality := "medium"
var dying := false
var _fpm: ParticleProcessMaterial
var _spm: ParticleProcessMaterial
var _epm: ParticleProcessMaterial
var _show := 2                ## 2: all, 1: flames only, 0: nothing (set_distance)
var _die_t := 0.0
var _wind := Vector3.ZERO


static func make(parent: Node, box: AABB, p_quality := "medium") -> FireFx:
	var fx := FireFx.new()
	fx.name = "FireFx"
	fx.quality = p_quality
	parent.add_child(fx)
	fx._build(box)
	fx.spread_over(box)
	return fx


## The systems, sized for `box` (the piece's world AABB): a wall's face throws about 26 flames, a blockhouse 40.
func _build(box: AABB) -> void:
	var area := maxf(box.size.x, box.size.z) * maxf(box.size.y, 0.6)
	var k := clampf(area / 8.0, 0.5, 1.6)
	var q := 0.5 if quality == "low" else 1.0
	_fpm = _flame_process()
	flames = _system("Flames", _fpm, _flame_mesh(), int(clampf(26.0 * k, 10.0, 42.0) * q), FLAME_LIFE)
	_spm = _smoke_process()
	smoke = _system("Smoke", _spm, _smoke_mesh(), int(clampf(10.0 * k, 6.0, 16.0) * q), SMOKE_LIFE)
	if quality != "low":
		_epm = _ember_process()
		embers = _system("Embers", _epm, _ember_mesh(), int(clampf(12.0 * k, 6.0, 18.0)), EMBER_LIFE)
	_apply_strength()


func _system(nm: String, pm: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nm
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.local_coords = false
	add_child(p)
	return p


## Catching: small flames at `point` (world), on the piece's face.
func catch_at(point: Vector3) -> void:
	_set_box(point + Vector3(0, 0.25, 0), Vector3(0.35, 0.25, 0.35))


## Alight all over `box` (world AABB): the flames over its lower two thirds, the smoke off its top.
func spread_over(box: AABB) -> void:
	_set_box(box.get_center() - Vector3(0, box.size.y * 0.15, 0), Vector3(box.size.x * 0.45, box.size.y * 0.32, box.size.z * 0.45))


func _set_box(center: Vector3, ext: Vector3) -> void:
	global_position = center
	ext = ext.max(Vector3(0.1, 0.1, 0.1))
	_fpm.emission_box_extents = ext
	_spm.emission_box_extents = Vector3(ext.x, 0.2, ext.z)
	if _epm:
		_epm.emission_box_extents = ext
	var reach := Vector3(ext.x + 4.0, ext.y + 4.0, ext.z + 4.0)
	flames.visibility_aabb = AABB(-reach, reach * 2.0 + Vector3(0, 4, 0))
	smoke.position = Vector3(0, ext.y + 0.3, 0)
	smoke.visibility_aabb = AABB(Vector3(-reach.x - 12.0, -2.0, -reach.z - 12.0), Vector3(reach.x * 2.0 + 24.0, 24.0, reach.z * 2.0 + 24.0))
	if embers:
		embers.visibility_aabb = AABB(Vector3(-reach.x - 6.0, -2.0, -reach.z - 6.0), Vector3(reach.x * 2.0 + 12.0, 16.0, reach.z * 2.0 + 12.0))


## The wind (toward where it blows, its length the strength 0..1): flames lean, smoke and embers drift downwind.
func set_wind(w: Vector3) -> void:
	if w.distance_to(_wind) < 0.02:
		return
	_wind = w
	_fpm.gravity = Vector3(0, 2.4, 0) + w * WIND_FLAME
	_spm.gravity = Vector3(0, 0.5, 0) + w * WIND_SMOKE
	if _epm:
		_epm.gravity = Vector3(0, 0.5, 0) + w * WIND_EMBER


## How far the camera is (m): what shows from there.
func set_distance(d: float) -> void:
	var show := 2 if d < NEAR_M else (1 if d < FAR_M else 0)
	if show == _show:
		return
	_show = show
	_apply_strength()


## The flames go out; the smoke thins over SMOULDER_S and the node frees itself.
func die() -> void:
	if dying:
		return
	dying = true
	_die_t = 0.0
	flames.emitting = false
	if embers:
		embers.emitting = false
	smoke.amount_ratio = 0.4


## Called by FireSpread's tick (dt: seconds since the last). True while it is still there.
func tick(dt: float) -> bool:
	if not dying:
		return true
	_die_t += dt
	smoke.amount_ratio = 0.4 * clampf(1.0 - _die_t / SMOULDER_S, 0.0, 1.0)
	if _die_t >= SMOULDER_S:
		smoke.emitting = false
	if _die_t >= SMOULDER_S + SMOKE_LIFE:
		queue_free()
		return false
	return true


func _apply_strength() -> void:
	if flames == null or dying:
		return
	var lit := strength > 0.01
	for p: GPUParticles3D in [flames, smoke, embers]:
		if p == null:
			continue
		var shown := _show >= (1 if p == flames else 2)
		p.visible = shown
		if p.emitting != (shown and lit):
			p.emitting = shown and lit
	flames.amount_ratio = clampf(0.1 + 0.9 * strength, 0.0, 1.0)
	smoke.amount_ratio = clampf(0.35 + 0.65 * strength, 0.0, 1.0)
	if embers:
		embers.amount_ratio = clampf(strength, 0.05, 1.0)


# --- Shared materials -------------------------------------------------------------------------------------------

static var _flame_mat: ShaderMaterial
static var _smoke_mat: StandardMaterial3D
static var _ember_mat: StandardMaterial3D
static var _column_mat: StandardMaterial3D
static var _meshes := {}


## Lets go of the shared materials and meshes (FireSpread leaving the tree: the level is going; the next one makes them
## again).
static func release() -> void:
	_flame_mat = null
	_smoke_mat = null
	_ember_mat = null
	_column_mat = null
	_meshes.clear()
	_templates.clear()


## The flame cards' one material (the torch's flame shader as tongues; FireSpread sets its brightness for the eye).
static func flame_material() -> ShaderMaterial:
	if _flame_mat == null:
		_flame_mat = ShaderMaterial.new()
		_flame_mat.shader = load(TorchFire.FLAME_SHADER) as Shader
		_flame_mat.set_shader_parameter(&"particle", true)
		_flame_mat.set_shader_parameter(&"seed", 17.0)
		_flame_mat.set_shader_parameter(&"intensity", 2.0)
	return _flame_mat


static func _flame_mesh() -> Mesh:
	if not _meshes.has("flame"):
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 1.5)
		q.material = flame_material()
		_meshes["flame"] = q
	return _meshes["flame"]


## Lit smoke (the sun and the shared fire light light it; at night it is orange over the flames, black above).
static func _smoke_mesh() -> Mesh:
	if not _meshes.has("smoke"):
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_texture = Fx._puff()
		_smoke_mat.roughness = 1.0
		_smoke_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_smoke_mat.disable_receive_shadows = true
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.6)
		q.material = _smoke_mat
		_meshes["smoke"] = q
	return _meshes["smoke"]


static func _ember_mesh() -> Mesh:
	if not _meshes.has("ember"):
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_ember_mat.vertex_color_use_as_albedo = true
		_ember_mat.albedo_color = Color(3.0, 1.3, 0.35)
		_ember_mat.albedo_texture = Fx._soft_dot()
		_ember_mat.disable_fog = true
		var q := QuadMesh.new()
		q.size = Vector2(0.07, 0.07)
		q.material = _ember_mat
		_meshes["ember"] = q
	return _meshes["ember"]


static func _curve_tex(points: Array, max_v := 1.0) -> CurveTexture:
	var c := Curve.new()
	c.max_value = max_v
	for pt: Vector2 in points:
		c.add_point(pt)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _ramp_tex(stops: Array) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = Fx._ramp_at(stops)
	return t


# The process materials: one template each, copied for every fire (the copies share the template's shader: the same
# features make the same code), since each fire has its own emission box.
static var _templates := {}


static func _template(kind: String) -> ParticleProcessMaterial:
	if _templates.has(kind):
		return _templates[kind]
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3.ONE
	pm.direction = Vector3.UP
	match kind:
		"flame":
			pm.spread = 14.0
			pm.initial_velocity_min = 0.8
			pm.initial_velocity_max = 1.9
			pm.gravity = Vector3(0, 2.4, 0)
			pm.damping_min = 0.6
			pm.damping_max = 1.4
			pm.scale_min = 0.6
			pm.scale_max = 1.35
			pm.lifetime_randomness = 0.35
			pm.scale_curve = _curve_tex([Vector2(0, 0.45), Vector2(0.25, 1.0), Vector2(1, 0.2)])
			pm.color_ramp = _ramp_tex([[0.0, Color(1.0, 0.8, 0.45, 0.9)], [0.35, Color(1.0, 0.48, 0.12, 0.8)],
					[1.0, Color(0.75, 0.1, 0.02, 0.0)]])
		"smoke":
			pm.spread = 12.0
			pm.initial_velocity_min = 1.1
			pm.initial_velocity_max = 2.0
			pm.gravity = Vector3(0, 0.5, 0)
			pm.damping_min = 0.15
			pm.damping_max = 0.35
			pm.scale_min = 0.9
			pm.scale_max = 1.5
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.lifetime_randomness = 0.3
			pm.scale_curve = _curve_tex([Vector2(0, 0.35), Vector2(1, 3.0)], 3.0)
			pm.color_ramp = _ramp_tex([[0.0, Color(0.07, 0.065, 0.06, 0.0)], [0.12, Color(0.08, 0.072, 0.065, 0.55)],
					[0.6, Color(0.16, 0.15, 0.14, 0.28)], [1.0, Color(0.22, 0.21, 0.2, 0.0)]])
		"ember":
			pm.spread = 40.0
			pm.initial_velocity_min = 1.4
			pm.initial_velocity_max = 3.4
			pm.gravity = Vector3(0, 0.5, 0)
			pm.damping_min = 0.4
			pm.damping_max = 0.9
			pm.scale_min = 0.6
			pm.scale_max = 1.3
			pm.lifetime_randomness = 0.4
			pm.turbulence_enabled = false
			pm.color_ramp = _ramp_tex([[0.0, Color(1.0, 0.85, 0.45, 1.0)], [0.6, Color(1.0, 0.45, 0.1, 0.8)],
					[1.0, Color(0.5, 0.08, 0.0, 0.0)]])
		"column":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 2.0
			pm.spread = 8.0
			pm.initial_velocity_min = 2.6
			pm.initial_velocity_max = 4.0
			pm.gravity = Vector3(0, COLUMN_RISE, 0)
			pm.damping_min = 0.02
			pm.damping_max = 0.06
			pm.scale_min = 2.6
			pm.scale_max = 4.0
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.lifetime_randomness = 0.2
			pm.scale_curve = _curve_tex([Vector2(0, 0.5), Vector2(0.3, 1.4), Vector2(1, 4.5)], 5.0)
			pm.color_ramp = _ramp_tex([[0.0, Color(0.12, 0.11, 0.1, 0.0)], [0.05, Color(0.13, 0.12, 0.11, 0.6)],
					[0.45, Color(0.3, 0.29, 0.28, 0.4)], [1.0, Color(0.48, 0.47, 0.46, 0.0)]])
	_templates[kind] = pm
	return pm


static func _flame_process() -> ParticleProcessMaterial:
	return _template("flame").duplicate() as ParticleProcessMaterial


static func _smoke_process() -> ParticleProcessMaterial:
	return _template("smoke").duplicate() as ParticleProcessMaterial


static func _ember_process() -> ParticleProcessMaterial:
	return _template("ember").duplicate() as ParticleProcessMaterial


# --- The smoke column ---------------------------------------------------------------------------------------------

## A tall column of smoke over a burning place, seen from far off (FireSpread keeps one per burning area, CLUSTER_M
## square): a few dozen big lit puffs rising for half a minute, about 100 m up, spreading and greying as they go, leaning
## downwind (set_column_wind). `amount_ratio` is how much burns under it; it smoulders on thinly after the fires die.
static func column(parent: Node, at: Vector3, p_quality := "medium") -> GPUParticles3D:
	if _column_mat == null:
		_column_mat = StandardMaterial3D.new()
		_column_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_column_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_column_mat.vertex_color_use_as_albedo = true
		_column_mat.albedo_texture = Fx._puff()
		_column_mat.roughness = 1.0
		_column_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_column_mat.disable_receive_shadows = true
	if not _meshes.has("column"):
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.material = _column_mat
		_meshes["column"] = q
	var p := GPUParticles3D.new()
	p.name = "SmokeColumn"
	p.amount = 20 if p_quality == "low" else 32
	p.lifetime = COLUMN_LIFE
	p.process_material = _template("column").duplicate()
	p.draw_pass_1 = _meshes["column"]
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-90, -5, -90), Vector3(180, 150, 180))
	p.amount_ratio = 0.3
	parent.add_child(p)
	p.global_position = at
	return p


static func set_column_wind(p: GPUParticles3D, w: Vector3) -> void:
	var pm := p.process_material as ParticleProcessMaterial
	if pm:
		pm.gravity = Vector3(0, COLUMN_RISE, 0) + w * WIND_COLUMN
