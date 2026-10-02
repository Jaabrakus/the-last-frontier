class_name WorldSettings
extends Resource
## Environment quality settings (look-dev spec, section 9). frontier_level.gd builds one
## instance with from_args() and hands it to every environment builder (EnvironmentRig,
## FrontierTerrain, FrontierVegetation and the structure code). Nothing else parses the
## `quality=` argument.
##
##   Godot --path . -- quality=low          (or medium / high)
##   project setting frontier/graphics/quality overrides the default when present
## The default: in the game, the player's choice in user://settings.cfg ([display] quality), else GAME_QUALITY
## (medium: a steady 60 fps on an Apple M4 Mac mini; high's global illumination, volumetric fog and native TAA about
## double the forest's frame, 26-35 ms against 12-17: tools/environment/benchmark.gd, 2026-09-28; user: "make run
## smmothely"); in tool and test runs (-s), DEFAULT_QUALITY (high: the look-dev spec's, what the tools render).
##   Godot --path . -- upscale=auto,balanced  (the upscaling graphics setting, see below; default off)
##
## Owner: package A (lighting). Packages B-D only read their own groups below. Presets never
## change gameplay: tree positions, colliders and the layout are the same at every quality.

const QUALITIES := ["low", "medium", "high"]
const DEFAULT_QUALITY := "high"
const GAME_QUALITY := "medium"
const SETTINGS_PATH := "user://settings.cfg"
const Upscaling := preload("res://scripts/world/settings/upscaling.gd")

@export_enum("low", "medium", "high") var quality := DEFAULT_QUALITY

@export_group("Rendering (package A)")
## Anti-aliasing / upscaling: "taa" (native res + TAA), "metalfx" (MetalFX temporal on
## Apple, TAA elsewhere, at render_scale), "fxaa", "msaa2x".
@export_enum("taa", "metalfx", "fxaa", "msaa2x") var antialiasing := "taa"
@export_range(0.5, 1.0) var render_scale := 1.0
@export var shadow_atlas_size := 4096
@export_enum("2:2", "4:4") var shadow_splits := 4
@export var shadow_max_distance := 200.0
## RenderingServer.ShadowQuality (0 hard .. 5 soft ultra).
@export_range(0, 5) var soft_shadow_quality := 3
@export var sdfgi := true
@export var ssao := true
@export var ssil := false
@export var volumetric_fog := true
## Screen-space god rays (GodRays: shafts of sunlight between the trees; off on low, whose FXAA leaves their noise).
@export var god_rays := true
@export var glow := true
@export var auto_exposure := true

@export_group("Terrain and grass (package B)")
## Multiplies terrain LOD switch distances.
@export_range(0.25, 2.0) var terrain_lod_scale := 1.0
## Fraction of the full grass blade/tuft density.
@export_range(0.0, 1.0) var grass_density := 1.0
## Distance (m) where grass has faded out completely.
@export var grass_distance := 80.0
## Detail layers: close-up detail normals, triplanar rock on slopes, parallax-free height blend.
@export var terrain_detail := true

@export_group("Vegetation (package C)")
## Multiplies every vegetation visibility range (LOD and impostor switch distances).
@export_range(0.25, 2.0) var vegetation_distance_scale := 1.0
## Fraction of the non-colliding clutter (ferns, shrubs, saplings, twigs). Trees and every
## object with a collider are always placed.
@export_range(0.0, 1.0) var clutter_density := 1.0
## Trees beyond this distance (m) stop casting shadows (impostors never cast).
@export var tree_shadow_distance := 150.0

@export_group("Structures (package D)")
## Extra non-colliding structure detail (log ends, chinking, nails, shingles as geometry).
@export var structure_detail := true

@export_group("Upscaling (graphics setting)")
## The upscaling graphics setting (scripts/world/settings/upscaling.gd), not part of the quality
## presets: "off" (the DEFAULT: native resolution with the preset's anti-aliasing above; on high,
## native TAA, the user's chosen look), "auto" (MetalFX on Apple Metal, FSR 2 on Vulkan /
## Direct3D 12), "metalfx", "fsr2", "fsr1". from_args() reads it from user://settings.cfg (the
## in-game Graphics panel, F2) and the argument upscale=<mode>[,<level>];
## EnvironmentRig.apply_viewport() applies it over the preset's anti-aliasing and render scale.
@export_enum("off", "auto", "metalfx", "fsr2", "fsr1") var upscaling := "off"
## Render scale per axis: "quality" 0.77, "balanced" 0.67, "performance" 0.5.
@export_enum("quality", "balanced", "performance") var upscaling_quality := "quality"
## Where the upscaling value came from: "default", "settings.cfg", "arg" or "panel".
var upscaling_source := "default"


static func from_args() -> WorldSettings:
	var q := default_quality()
	if ProjectSettings.has_setting("frontier/graphics/quality"):
		q = String(ProjectSettings.get_setting("frontier/graphics/quality"))
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		var s := a.trim_prefix("--")
		if s.begins_with("quality="):
			q = s.get_slice("=", 1)
	var settings := preset(q)
	# The upscaling setting: user://settings.cfg (not in tool / test runs), then upscale=.
	Upscaling.read_startup(settings)
	return settings


## The quality when nothing asks for one: tool and test runs high (DEFAULT_QUALITY); the game the player's saved
## choice, else GAME_QUALITY.
static func default_quality(args: PackedStringArray = OS.get_cmdline_args(), path := SETTINGS_PATH) -> String:
	if "-s" in args or "--script" in args:
		return DEFAULT_QUALITY
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var q := String(cfg.get_value("display", "quality", GAME_QUALITY))
		if q in QUALITIES:
			return q
	return GAME_QUALITY


static func preset(q: String) -> WorldSettings:
	var s := WorldSettings.new()
	if not q in QUALITIES:
		push_warning("WorldSettings: unknown quality '%s', using %s" % [q, DEFAULT_QUALITY])
		q = DEFAULT_QUALITY
	s.quality = q
	match q:
		"low":
			s.antialiasing = "fxaa"
			s.render_scale = 1.0
			s.shadow_atlas_size = 2048
			s.shadow_splits = 2
			s.shadow_max_distance = 80.0
			s.soft_shadow_quality = 1
			s.sdfgi = false
			s.ssao = false
			s.ssil = false
			s.volumetric_fog = false
			s.god_rays = false
			s.glow = true
			s.auto_exposure = false
			s.terrain_lod_scale = 0.6
			s.grass_density = 0.35
			s.grass_distance = 35.0
			s.terrain_detail = false
			s.vegetation_distance_scale = 0.6
			s.clutter_density = 0.4
			s.tree_shadow_distance = 50.0
			s.structure_detail = false
		"medium":
			s.antialiasing = "metalfx"
			s.render_scale = 0.75
			s.shadow_atlas_size = 4096
			s.shadow_splits = 4
			s.shadow_max_distance = 150.0
			s.soft_shadow_quality = 2
			s.sdfgi = false
			s.ssao = true
			s.ssil = false
			s.volumetric_fog = false
			s.glow = true
			s.auto_exposure = true
			s.terrain_lod_scale = 0.8
			s.grass_density = 0.65
			s.grass_distance = 60.0
			s.terrain_detail = true
			s.vegetation_distance_scale = 0.8
			s.clutter_density = 0.7
			s.tree_shadow_distance = 100.0
			s.structure_detail = true
		"high":
			pass   # The defaults above.
	return s


func _to_string() -> String:
	return "WorldSettings(%s)" % quality
