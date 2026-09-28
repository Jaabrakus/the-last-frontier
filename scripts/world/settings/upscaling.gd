extends RefCounted
## The upscaling graphics setting (user request, 2026-09-25: "make upscaling a setting").
## Static helpers only; WorldSettings holds the values, EnvironmentRig.apply_viewport() applies
## them and the in-game Graphics panel (graphics_panel.gd, F2) changes them live.
##
## Modes (WorldSettings.upscaling):
##   off      DEFAULT. Native resolution with the quality preset's own anti-aliasing; on the
##            default preset (high) that is native TAA, the look the user chose ("u10").
##            apply_viewport() then leaves every viewport value exactly as before this setting.
##   auto     MetalFX temporal on Apple Metal, else AMD FSR 2 (Windows / Linux on Vulkan or
##            Direct3D 12), else FSR 1, else off.
##   metalfx  Apple MetalFX temporal upscaler. Metal driver only (macOS / iOS).
##   fsr2     AMD FidelityFX Super Resolution 2.2, temporal: replaces TAA. Every Forward+
##            RenderingDevice driver (Metal, Vulkan, Direct3D 12).
##   fsr1     AMD FSR 1.0, spatial: the cheapest, for weak GPUs. Anti-aliasing (the preset's TAA
##            or FXAA) runs before it at the lower resolution, so it is softer than FSR 2.
## Levels (WorldSettings.upscaling_quality), the 3D render scale per axis (the 2D HUD always
## renders at native resolution): quality 0.77, balanced 0.67, performance 0.5.
##
## Where it comes from (WorldSettings.from_args() -> read_startup()):
##   1. user://settings.cfg, section [graphics], keys upscaling / upscaling_quality (the panel
##      writes it). Tool and test runs (a SceneTree script given with -s: benchmark.gd,
##      scenic_shots.gd, smoke_test.gd, ...) skip the file, so benchmarks and reference
##      screenshots never pick up a player's saved choice.
##   2. The argument upscale=<mode>[,<level>] (e.g. `Godot --path . -- upscale=auto,balanced`)
##      overrides it for one run and is not saved.
##
## Availability in Godot 4.7.2 (Viewport.Scaling3DMode: BILINEAR, FSR, FSR2, METALFX_SPATIAL,
## METALFX_TEMPORAL, NEAREST; verified on this Mac with Metal and with Vulkan through MoltenVK,
## and with the Forward+, Mobile and Compatibility renderers, 2026-09-25):
##   FSR 1, FSR 2 and MetalFX temporal need the Forward+ renderer ("only available when using the
##   Forward+ renderer" on Mobile / Compatibility). MetalFX temporal needs
##   RenderingDevice.SUPPORTS_METALFX_TEMPORAL (true on Metal, false on Vulkan) and a scale within
##   LIMIT_METALFX_TEMPORAL_SCALER_MIN/MAX_SCALE (millionths; Apple M4: 0.333333-1.0). DLSS, XeSS
##   and FSR 3 or later are not in Godot 4.7: they would need a third-party GDExtension.
## An unavailable mode falls back metalfx -> fsr2 -> fsr1 -> off and says why (the GFX log line,
## the panel), instead of relying on the engine's own silent fallbacks.

const MODES: PackedStringArray = ["off", "auto", "metalfx", "fsr2", "fsr1"]
const LEVELS: PackedStringArray = ["quality", "balanced", "performance"]
const SCALES := {"quality": 0.77, "balanced": 0.67, "performance": 0.5}
const DEFAULT_MODE := "off"
const DEFAULT_LEVEL := "quality"
const MODE_NAMES := {
	"off": "Off (native + TAA)",
	"auto": "Auto",
	"metalfx": "MetalFX temporal",
	"fsr2": "AMD FSR 2",
	"fsr1": "AMD FSR 1",
}
const LEVEL_NAMES := {"quality": "Quality (77%)", "balanced": "Balanced (67%)", "performance": "Performance (50%)"}
## Next mode to try when one is unavailable.
const FALLBACK := {"metalfx": "fsr2", "fsr2": "fsr1", "fsr1": "off"}
## Accepted spellings for the command-line argument.
const MODE_ALIASES := {"none": "off", "native": "off", "taa": "off", "0": "off", "on": "auto", "1": "auto",
		"mfx": "metalfx", "fsr": "fsr1", "fsr1.0": "fsr1", "fsr2.2": "fsr2"}
const LEVEL_ALIASES := {"q": "quality", "b": "balanced", "p": "performance", "perf": "performance"}

const CONFIG_SECTION := "graphics"
## Settings file. Tests point it at a scratch file.
static var config_path := "user://settings.cfg"


## True when a SceneTree script runs the process (-s tools/..., tests/...): skip the saved file.
static func is_tool_run() -> bool:
	var loop := Engine.get_main_loop()
	return loop != null and loop.get_script() != null


## Startup values into `s` (a WorldSettings): the saved file (not in tool runs unless
## `use_saved` is 1), then upscale=<mode>[,<level>].
static func read_startup(s: Object, use_saved := -1) -> void:
	var mode := DEFAULT_MODE
	var level := DEFAULT_LEVEL
	var source := "default"
	if use_saved == 1 or (use_saved == -1 and not is_tool_run()):
		var saved := load_saved()
		if not saved.is_empty():
			mode = saved.mode
			level = saved.level
			source = "settings.cfg"
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		var t := a.trim_prefix("--")
		if t.begins_with("upscale="):
			var p := parse_arg(t.get_slice("=", 1), level)
			mode = p[0]
			level = p[1]
			source = "arg"
	s.set("upscaling", mode)
	s.set("upscaling_quality", level)
	s.set("upscaling_source", source)


## "auto,balanced" -> ["auto", "balanced"]. Unknown words warn and keep the defaults.
static func parse_arg(value: String, level_default := DEFAULT_LEVEL) -> PackedStringArray:
	var parts := value.to_lower().replace(":", ",").split(",", false)
	var mode := DEFAULT_MODE
	var level := level_default
	if parts.size() >= 1:
		mode = normalize_mode(parts[0])
	if parts.size() >= 2:
		level = normalize_level(parts[1])
	return PackedStringArray([mode, level])


static func normalize_mode(m: String) -> String:
	m = m.strip_edges().to_lower()
	m = MODE_ALIASES.get(m, m)
	if not m in MODES:
		push_warning("Upscaling: unknown mode '%s' (off, auto, metalfx, fsr2, fsr1), using %s" % [m, DEFAULT_MODE])
		return DEFAULT_MODE
	return m


static func normalize_level(l: String) -> String:
	l = l.strip_edges().to_lower()
	l = LEVEL_ALIASES.get(l, l)
	if not l in LEVELS:
		push_warning("Upscaling: unknown level '%s' (quality, balanced, performance), using %s" % [l, DEFAULT_LEVEL])
		return DEFAULT_LEVEL
	return l


## {mode, level} from the settings file, or {} when there is none (or it has no [graphics]).
static func load_saved() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(config_path) != OK or not cf.has_section(CONFIG_SECTION):
		return {}
	return {
		"mode": normalize_mode(str(cf.get_value(CONFIG_SECTION, "upscaling", DEFAULT_MODE))),
		"level": normalize_level(str(cf.get_value(CONFIG_SECTION, "upscaling_quality", DEFAULT_LEVEL))),
	}


## Writes the setting, keeping any other section / key already in the file. Returns the Error.
static func save(mode: String, level: String) -> Error:
	var cf := ConfigFile.new()
	cf.load(config_path)   # Missing file: start empty.
	cf.set_value(CONFIG_SECTION, "upscaling", normalize_mode(mode))
	cf.set_value(CONFIG_SECTION, "upscaling_quality", normalize_level(level))
	return cf.save(config_path)


## Why `mode` cannot run on this renderer / GPU at `scale` ("" when it can).
static func unavailable_reason(mode: String, scale := 0.77) -> String:
	if mode == "off":
		return ""
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var rd := RenderingServer.get_rendering_device()
	if DisplayServer.get_name() == "headless":
		return "headless run, nothing is rendered"
	if rd == null:
		return "needs a RenderingDevice renderer (running %s, no Vulkan / Direct3D 12 / Metal)" % method
	if method != "forward_plus":
		return "needs the Forward+ renderer (running %s)" % method
	if mode == "metalfx":
		if not rd.has_feature(RenderingDevice.SUPPORTS_METALFX_TEMPORAL):
			return "Apple Metal only (driver: %s)" % driver
		var lo := rd.limit_get(RenderingDevice.LIMIT_METALFX_TEMPORAL_SCALER_MIN_SCALE) / 1e6
		var hi := rd.limit_get(RenderingDevice.LIMIT_METALFX_TEMPORAL_SCALER_MAX_SCALE) / 1e6
		if lo > 0.0 and hi <= 1.0 and (scale < lo - 1e-4 or scale > hi + 1e-4):
			return "scale %.2f outside this GPU's %.2f-%.2f" % [scale, lo, hi]
	return ""


## The upscaler that will actually run for a requested mode and level:
## {requested, level, mode, scale, note}. mode is "off", "metalfx", "fsr2" or "fsr1".
static func resolve(requested: String, level: String) -> Dictionary:
	var want := normalize_mode(requested)
	var lvl := normalize_level(level)
	var scale: float = SCALES[lvl]
	var notes := PackedStringArray()
	var m := want
	if want == "auto":
		m = "metalfx"
		var skipped := PackedStringArray()
		while m != "off" and unavailable_reason(m, scale) != "":
			skipped.append("%s: %s" % [MODE_NAMES[m], unavailable_reason(m, scale)])
			m = FALLBACK[m]
		notes.append("auto chose %s" % ("off (no upscaler available)" if m == "off" else MODE_NAMES[m]))
		if not skipped.is_empty():
			notes.append("skipped " + "; ".join(skipped))
	else:
		while m != "off":
			var why := unavailable_reason(m, scale)
			if why == "":
				break
			notes.append("%s unavailable (%s)" % [MODE_NAMES[m], why])
			m = FALLBACK[m]
		if m != want:
			notes.append("using %s" % ("native (off)" if m == "off" else MODE_NAMES[m]))
	return {"requested": want, "level": lvl, "mode": m, "scale": scale if m != "off" else 1.0,
			"note": ", ".join(notes)}


## Puts a resolved upscaler on `vp`, over the preset's values that EnvironmentRig.apply_viewport()
## has just set. `preset_aa` is the preset's anti-aliasing as apply_viewport resolved it ("taa",
## "fxaa", "msaa2x" or "metalfx"). "off" changes nothing.
static func apply(vp: Viewport, r: Dictionary, preset_aa: String) -> void:
	var m: String = r.get("mode", "off")
	if vp == null or m == "off":
		return
	# The engine already biases texture LOD by log2(scale) below native; no extra TAA sharpening.
	vp.texture_mipmap_bias = 0.0
	match m:
		"metalfx", "fsr2":
			# Temporal upscalers anti-alias themselves: TAA, MSAA and FXAA off (TAA first, so the
			# engine never sees TAA together with a temporal upscaler).
			vp.use_taa = false
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL if m == "metalfx" else Viewport.SCALING_3D_MODE_FSR2
		"fsr1":
			# Spatial: the preset's anti-aliasing runs first at the render resolution (TAA on high
			# and on medium, whose own MetalFX this replaces; FXAA on low).
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.use_taa = preset_aa == "taa" or preset_aa == "metalfx"
			vp.msaa_3d = Viewport.MSAA_2X if preset_aa == "msaa2x" else Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if preset_aa == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = float(r.scale)


## One line for the log and the panel, e.g.
## "upscaling=auto -> metalfx level=quality scale=0.77 3d=1232x693 -> 1600x900 source=arg (auto chose ...)".
static func describe(r: Dictionary, vp: Viewport, source := "") -> String:
	var out := Vector2i(vp.get_visible_rect().size) if vp else Vector2i.ZERO
	var s: float = r.get("scale", 1.0)
	var inner := Vector2i(roundi(out.x * s), roundi(out.y * s))
	var req: String = r.get("requested", "off")
	var m: String = r.get("mode", "off")
	var line := "upscaling=%s%s level=%s scale=%.2f 3d=%dx%d -> %dx%d" % [req,
			"" if req == m else " -> " + m, r.get("level", DEFAULT_LEVEL), s, inner.x, inner.y, out.x, out.y]
	if m == "off":
		line += " (native, preset AA)"
	if source != "":
		line += " source=" + source
	if String(r.get("note", "")) != "":
		line += " (%s)" % r.note
	return line
