extends SubViewport
## Off-window render target for the environment tools (scenic_shots.gd, benchmark.gd).
##
## macOS stops drawing a window that is fully covered or on another Space: Godot then skips
## RenderingServer.draw() altogether, and even RenderingServer.force_draw() skips the root
## viewport (DisplayServer.window_can_draw() is false), so captures come back stale. A
## SubViewport is not tied to the window, so force_draw() always renders it. It shares the
## level's World3D (sky, environment, lights) and copies the root viewport's 3D settings
## (AA, upscaling, LOD, shadow atlas), which the EnvironmentRig sets from WorldSettings.
##
##   var view = preload("res://tools/environment/offscreen_view.gd").new()
##   root.add_child(view)
##   view.setup(root, Vector2i(1280, 720))
##   view.source = player.camera        # follow a camera, or place view.camera yourself
##   ...
##   var img: Image = view.get_texture().get_image()

var camera: Camera3D
## When set, `camera` copies this camera's transform and lens every frame.
var source: Camera3D


func setup(from: Viewport, px: Vector2i) -> void:
	size = px
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	camera = Camera3D.new()
	camera.far = 1500.0
	add_child(camera)
	camera.current = true
	copy_settings(from)
	_mirror(from)


## Shows this off-window render in the visible window as well, so a tool window shows what it
## is capturing instead of an empty grey rectangle (the tools set root.disable_3d). It costs one
## full-window textured quad while the window can draw, and nothing when it is covered.
## The user argument --no_mirror turns it off.
func _mirror(from: Viewport) -> void:
	if DisplayServer.get_name() == "headless" or "--no_mirror" in OS.get_cmdline_user_args():
		return
	var layer := CanvasLayer.new()
	layer.name = "OffscreenMirror"
	layer.layer = 128
	var rect := TextureRect.new()
	rect.texture = get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	from.add_child.call_deferred(layer)


func copy_settings(vp: Viewport) -> void:
	msaa_3d = vp.msaa_3d
	screen_space_aa = vp.screen_space_aa
	use_taa = vp.use_taa
	use_debanding = vp.use_debanding
	use_occlusion_culling = vp.use_occlusion_culling
	mesh_lod_threshold = vp.mesh_lod_threshold
	scaling_3d_mode = vp.scaling_3d_mode
	scaling_3d_scale = vp.scaling_3d_scale
	fsr_sharpness = vp.fsr_sharpness
	texture_mipmap_bias = vp.texture_mipmap_bias
	anisotropic_filtering_level = vp.anisotropic_filtering_level
	positional_shadow_atlas_size = vp.positional_shadow_atlas_size
	positional_shadow_atlas_16_bits = vp.positional_shadow_atlas_16_bits
	for q in 4:
		set_positional_shadow_atlas_quadrant_subdiv(q, vp.get_positional_shadow_atlas_quadrant_subdiv(q))


func sync_camera() -> void:
	if source == null or not is_instance_valid(source) or camera == null:
		return
	camera.global_transform = source.global_transform
	camera.fov = source.fov
	camera.near = source.near
	camera.far = source.far
	camera.h_offset = source.h_offset
	camera.v_offset = source.v_offset
	camera.keep_aspect = source.keep_aspect
	camera.attributes = source.attributes
	camera.environment = source.environment
	camera.cull_mask = source.cull_mask


func _process(_delta: float) -> void:
	sync_camera()
