class_name GodRays
extends CompositorEffect
## God rays: shafts of sunlight between the trees, the hills and the roofs (user 2026-10-02: "can we add god rays", a
## Three.js screen-space breakdown). On every preset, unlike the high preset's volumetric fog.
##
## What: after the transparent pass, on the HDR colour (before the tonemap and the glow), two compute passes:
##   shaders/env/god_rays.glsl            half resolution: each pixel marches toward the sun's place on the screen and
##                                        sums the open sky on the way (the sky's pixels near the sun; geometry blocks it)
##   shaders/env/god_rays_composite.glsl  full resolution: those rays, tinted by the sun's light, added to the frame
## Nothing runs while the sun is behind the camera, below the horizon or out of `strength` (night: the moon's faint key
## light gives faint rays). EnvironmentRig sets `sun_dir`, `tint` and `strength` every frame from the key light.
##
##   EnvironmentRig: we.compositor carries [SkyMotionVectors, GodRays]
## A single view (no XR multiview), MSAA off (the presets).

const RAYS_SHADER := "res://shaders/env/god_rays.glsl"
const COMPOSITE_SHADER := "res://shaders/env/god_rays_composite.glsl"
const CONTEXT := &"god_rays"
const SKY_DEPTH := 0.0         ## the depth buffer's value where nothing was drawn (reverse Z)

## Unit vector toward the light (world). EnvironmentRig: the key light's +Z.
var sun_dir := Vector3.UP
## The light's colour (linear) times its share of the day's full sun.
var tint := Color(1, 1, 1)
## The rays' brightness at the full sun.
@export var strength := 1.5
@export_range(8, 128) var steps := 48
## The fraction of the way to the sun each pixel's march covers.
@export var density := 0.9
@export var decay := 0.965
## The sky's light fades to 0 this far from the sun (screen heights).
@export var radius := 0.55
## The sky's HDR ceiling in the march (the sun's disc and its glare would otherwise drown the shafts).
@export var cap := 3.0
## The open sky takes this much of the rays (it already glows round the sun).
@export var sky_share := 0.35
## The light's own glow added to the open sky round it in the march (EnvironmentRig: 0 by day, the moon's at night,
## when the dark sky alone streams nothing).
var halo := 0.0
## The rays alone on a black frame (look-dev).
@export var debug_rays_only := false

var _rd: RenderingDevice
var _rays_shader: RID
var _rays_pipeline: RID
var _comp_shader: RID
var _comp_pipeline: RID
var _nearest: RID
var _linear: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_create)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		for rid: RID in [_nearest, _linear, _rays_shader, _comp_shader]:   # a shader frees its pipeline
			if rid.is_valid():
				_rd.free_rid(rid)


func _create() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	_rays_shader = _compile(RAYS_SHADER)
	_comp_shader = _compile(COMPOSITE_SHADER)
	if not _rays_shader.is_valid() or not _comp_shader.is_valid():
		return
	_rays_pipeline = _rd.compute_pipeline_create(_rays_shader)
	_comp_pipeline = _rd.compute_pipeline_create(_comp_shader)
	var ss := RDSamplerState.new()
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest = _rd.sampler_create(ss)
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_linear = _rd.sampler_create(ss)


func _compile(path: String) -> RID:
	var file := load(path) as RDShaderFile
	if file == null:
		push_error("GodRays: cannot load %s" % path)
		return RID()
	var spirv := file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("GodRays: %s" % spirv.compile_error_compute)
		return RID()
	return _rd.shader_create_from_spirv(spirv)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != effect_callback_type or _rd == null or not _comp_pipeline.is_valid():
		return
	var level := strength * maxf(tint.r, maxf(tint.g, tint.b))
	if level <= 0.001 or sun_dir.y < -0.05:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := render_data.get_render_scene_data() as RenderSceneDataRD
	if buffers == null or scene == null or buffers.get_view_count() != 1 \
			or buffers.get_msaa_3d() != RenderingServer.VIEWPORT_MSAA_DISABLED:
		return
	# the sun on the screen
	var view := scene.get_cam_transform().basis.inverse() * sun_dir
	if view.z > -0.05:
		return   # behind the camera (or level with its side): no shafts on screen
	# through the lens's scale alone (as SkyMotionVectors: the render device's projection may be flipped in y)
	var proj := scene.get_cam_projection()
	var ndc := Vector2(absf(proj.x.x) * view.x, absf(proj.y.y) * view.y) / -view.z
	var sun_uv := Vector2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5)
	# far off screen there is no open sky near the sun to stream: fade out before the work is wasted
	var off := maxf(maxf(-sun_uv.x, sun_uv.x - 1.0), maxf(-sun_uv.y, sun_uv.y - 1.0))
	var edge := 1.0 - smoothstep(0.0, radius * 1.2, off)
	# turned away from the sun the shafts thin (they stream toward the camera when facing it)
	var facing := smoothstep(0.05, 0.6, -view.normalized().z)
	level *= edge * facing
	if level <= 0.001:
		return
	var size := buffers.get_internal_size()
	var half := Vector2i(maxi(size.x / 2, 1), maxi(size.y / 2, 1))
	if not buffers.has_texture(CONTEXT, &"rays"):
		buffers.create_texture(CONTEXT, &"rays", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
				RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT,
				RenderingDevice.TEXTURE_SAMPLES_1, half, 1, 1, true, false)
	var rays := buffers.get_texture(CONTEXT, &"rays")
	var depth := buffers.get_depth_texture()
	var color := buffers.get_color_layer(0)
	if not rays.is_valid() or not depth.is_valid() or not color.is_valid():
		return

	var pc := PackedFloat32Array([
		sun_uv.x, sun_uv.y, float(half.x), float(half.y),
		float(size.x) / float(size.y), density, decay, radius,
		cap, SKY_DEPTH, float(steps), halo,
	]).to_byte_array()
	var set1 := UniformSetCacheRD.get_cache(_rays_shader, 0, [
		_sampled(0, _nearest, depth), _sampled(1, _linear, color), _image(2, rays)])
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _rays_pipeline)
	_rd.compute_list_bind_uniform_set(list, set1, 0)
	_rd.compute_list_set_push_constant(list, pc, pc.size())
	_rd.compute_list_dispatch(list, (half.x + 7) / 8, (half.y + 7) / 8, 1)
	_rd.compute_list_end()

	var pc2 := PackedFloat32Array([
		tint.r * strength * edge * facing, tint.g * strength * edge * facing, tint.b * strength * edge * facing, 1.0 if debug_rays_only else 0.0,
		float(size.x), float(size.y), SKY_DEPTH, sky_share,
	]).to_byte_array()
	var set2 := UniformSetCacheRD.get_cache(_comp_shader, 0, [
		_sampled(0, _linear, rays), _sampled(1, _nearest, depth), _image(2, color)])
	list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _comp_pipeline)
	_rd.compute_list_bind_uniform_set(list, set2, 0)
	_rd.compute_list_set_push_constant(list, pc2, pc2.size())
	_rd.compute_list_dispatch(list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	_rd.compute_list_end()


static func _sampled(binding: int, sampler: RID, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler)
	u.add_id(tex)
	return u


static func _image(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u
