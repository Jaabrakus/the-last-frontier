class_name SkyMotionVectors
extends CompositorEffect
## The sky's motion vectors for the temporal AA (stars blur push, 2026-09-26; user: "fix the blur on the stars when we
## move").
##
## Why: Godot 4.7's native TAA (the high preset, the user's look) takes a velocity of 0 wherever no geometry was drawn.
## On the sky every turn of the camera then reprojects the history from the wrong place: the stars (points a pixel or
## two across) smear, ghost and are clipped away by the TAA's neighbourhood clamp (dim, blocky trails; the Milky Way
## streaks), measured at 0.4x their still brightness with 25-35% of them gone at any mouse-look speed
## (tools/environment/sky/star_motion.gd). Walking alone (the camera only moves, it does not turn) is not affected.
## FSR 2 derives those vectors from the depth buffer by itself (GODOT_DERIVE_INVALID_MOTION_VECTORS); this effect does
## the same for the TAA.
##
## What: after the opaque pass (which writes the geometry's vectors), a compute pass (shaders/sky/sky_motion_vectors.glsl)
## writes, on the sky's pixels only (depth still at the cleared far value), the motion of a direction at infinity: the
## camera's rotation since this viewport's previous frame, through the unjittered lens. Geometry keeps the engine's own
## vectors. It runs only on viewports with TAA on and MSAA off (the presets; FSR 2 / MetalFX / FXAA are left alone),
## only while the camera turns (a still view renders exactly as before), and costs one small compute dispatch: under
## 0.01 ms at 1600 x 900 on an Apple M-series GPU, frame time unchanged within noise (star_motion.gd STARCOST).
## With it the stars keep 0.75-0.9x their still brightness in a turn, their width within 1.25x (star_motion.gd).
##
##   var comp := Compositor.new(); comp.compositor_effects = [SkyMotionVectors.new()]
##   world_environment.compositor = comp          (EnvironmentRig does this; every camera of the world gets it)
##
## Assumes a symmetric perspective lens (Camera3D PROJECTION_PERSPECTIVE, no frustum offset): the lens's off-centre
## terms, where the TAA jitter lives, are taken as 0. A single view (no XR multiview).

const SHADER := "res://shaders/sky/sky_motion_vectors.glsl"
## The depth buffer's value where nothing was drawn (Godot's reverse Z: the far plane is 0).
const SKY_DEPTH := 0.0
## Viewports remembered at once (their previous camera); more is a sign of churn, and the table starts again.
const MAX_TARGETS := 16

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID
## render target RID -> [Basis (camera rotation), P00, P11] of that viewport's previous frame.
var _prev := {}


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
	needs_motion_vectors = false   # the TAA makes the velocity buffer; never force the motion pass without it
	RenderingServer.call_on_render_thread(_create)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		if _sampler.is_valid():
			_rd.free_rid(_sampler)
		if _shader.is_valid():
			_rd.free_rid(_shader)   # frees the pipeline too


func _create() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var file := load(SHADER) as RDShaderFile
	if file == null:
		push_error("SkyMotionVectors: cannot load %s" % SHADER)
		return
	var spirv := file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("SkyMotionVectors: %s" % spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if not _shader.is_valid():
		return
	_pipeline = _rd.compute_pipeline_create(_shader)
	var ss := RDSamplerState.new()
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_sampler = _rd.sampler_create(ss)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != effect_callback_type or _rd == null or not _pipeline.is_valid():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := render_data.get_render_scene_data() as RenderSceneDataRD
	if buffers == null or scene == null or not buffers.get_use_taa() or buffers.get_view_count() != 1 \
			or buffers.get_msaa_3d() != RenderingServer.VIEWPORT_MSAA_DISABLED:
		return
	var target := buffers.get_render_target()
	var cam := scene.get_cam_transform().basis.orthonormalized()
	var proj := scene.get_cam_projection()
	var now := [cam, absf(proj.x.x), absf(proj.y.y)]
	var before: Array = _prev.get(target, [])
	if _prev.size() >= MAX_TARGETS and not _prev.has(target):
		_prev.clear()
	_prev[target] = now
	if before.is_empty() or now[1] <= 0.0 or now[2] <= 0.0:
		return   # the viewport's first frame: nothing to reproject into (the TAA has no history either)
	var velocity := buffers.get_velocity_texture()
	var depth := buffers.get_depth_texture()
	if not velocity.is_valid() or not depth.is_valid():
		return
	var r: Basis = (before[0] as Basis).transposed() * cam   # current view -> previous view
	if r.is_equal_approx(Basis.IDENTITY):
		return   # the camera has not turned: the engine's 0 is the sky's motion (no pass while still)
	var size := buffers.get_internal_size()
	var pc := PackedFloat32Array([
		r.x.x, r.x.y, r.x.z, 0.0,
		r.y.x, r.y.y, r.y.z, 0.0,
		r.z.x, r.z.y, r.z.z, 0.0,
		1.0 / float(now[1]), 1.0 / float(now[2]), float(before[1]), float(before[2]),
		float(size.x), float(size.y), SKY_DEPTH, 0.0,
	]).to_byte_array()
	var u_depth := RDUniform.new()
	u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_depth.binding = 0
	u_depth.add_id(_sampler)
	u_depth.add_id(depth)
	var u_vel := RDUniform.new()
	u_vel.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_vel.binding = 1
	u_vel.add_id(velocity)
	var uset := UniformSetCacheRD.get_cache(_shader, 0, [u_depth, u_vel])
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	_rd.compute_list_bind_uniform_set(list, uset, 0)
	_rd.compute_list_set_push_constant(list, pc, pc.size())
	_rd.compute_list_dispatch(list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	_rd.compute_list_end()


## A Compositor carrying this effect (for a WorldEnvironment or a Camera3D).
static func compositor() -> Compositor:
	var effects: Array[CompositorEffect] = [SkyMotionVectors.new()]
	var c := Compositor.new()
	c.compositor_effects = effects
	return c
