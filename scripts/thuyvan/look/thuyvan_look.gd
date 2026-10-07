class_name ThuyVanLook
extends Node
## Thủy Vân's light, sky, fog and grade (style_guide.md 5.4 and 10; data/thuyvan/look_directions.json, written by
## tools/thuyvan_art/godot/write_look_directions.py from the art director's palettes.json). Three directions (Jade Mist
## Morning, Bright Saturated Noon, Golden Lantern Dusk) and a night proposal; the owner chose a day cycle of all three
## (owner_answers.md 7), so a look is either one direction or the clock's blend of two.
##
## As data (static, no scene needed):
##   ThuyVanLook.resolve("bright_saturated_noon")   # a flat look: Colors, floats, the sun's direction, the sky and LUT
##   ThuyVanLook.at_hour(6.5)                         # the day cycle's look at that hour (two directions blended)
##   ThuyVanLook.mix_looks(a, b, t)                   # any two looks blended
##   ThuyVanLook.apply(look, env, sun)                # onto an Environment and a DirectionalLight3D (the sky becomes
##                                                      shaders/thuyvan/tv_sky.gdshader; the grade LUT, blended on a
##                                                      worker thread between directions; the lanterns' glow; the
##                                                      registered effect cards' light_tint and rank-fog colour)
## In the game (region-gated: the frontier never sees it):
##   ThuyVanLook.attach(rig)   # after EnvironmentRig.build(): only when the region's block names a look
##                             # (WorldRegion.info() "look": a direction key, or "cycle" for the clock's day cycle);
##                             # today's world (no region) and regions without "look" get null and nothing changes.
##                             # The node runs after DayNight every frame and overrides what DayNight sets (the sun, the
##                             # sky, ambient, fog, tonemap, grade); the clock and the weather keep running under it.
## Effect cards (tv_card.gdshader) and the backdrop karst (tv_rock_far.gdshader) register their materials
## (register_card / register_rank) so every apply keeps their tint and fog colour in step with the light.

const DATA := "res://data/thuyvan/look_directions.json"
const SKY_SHADER := "res://shaders/thuyvan/tv_sky.gdshader"
const Region := preload("res://scripts/world/world_region.gd")
## LUT blends are cached at this many steps between two directions.
const LUT_STEPS := 8

static var _data := {}
static var _cards: Array[WeakRef] = []
static var _ranks: Array[WeakRef] = []
static var _luts := {}           ## "a|b|step" -> ImageTexture3D (or a Texture3D for a whole direction)
static var _lut_pending := {}    ## key -> task id
static var _lut_mutex := Mutex.new()
static var _lut_done := {}       ## key -> Array[Image] finished on the worker, made a texture on the main thread
static var _lanterns := {}       ## path -> the lantern material (kept loaded)

## What this node shows: a direction key, or "cycle" (the clock's hour through the day cycle).
var mode := "cycle"
var rig: Node
var env: Environment
var sun: DirectionalLight3D
## The look applied last (for the HUD, tests and tools).
var current := {}
var _hour := -1.0


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = d if d is Dictionary else {}
	return _data


## The three directions' keys, in the palette's order.
static func directions() -> Array:
	return data().get("directions", [])


static func has_look(key: String) -> bool:
	return (data().get("looks", {}) as Dictionary).has(key)


## Whether this region wants the Thủy Vân look (its block's "look"), and which.
static func region_look() -> String:
	return String(Region.info().get("look", ""))


## One direction as a flat look, ready to apply or blend.
static func resolve(key: String) -> Dictionary:
	var d: Dictionary = data().get("looks", {}).get(key, {})
	if d.is_empty():
		push_warning("ThuyVanLook: no look %s" % key)
		return {}
	var s: Dictionary = d.sun
	var f: Dictionary = d.fog
	var a: Dictionary = d.ambient
	var t: Dictionary = d.tonemap
	var r: Dictionary = data().get("render", {})
	var glow: Dictionary = r.get("glow", {})
	return {
		"key": key, "keys": [key], "weights": [1.0],
		"sun_dir": sun_vector(float(s.azimuth_deg), float(s.elevation_deg)),
		"sun_color": Color(String(s.color)), "sun_energy": float(s.energy), "sun_angular": float(s.angular_deg),
		"sky_a": String(d.sky.panorama), "sky_b": String(d.sky.panorama), "sky_blend": 0.0,
		"sky_tint": Color(String(d.sky.get("tint", "#ffffff"))), "sky_energy": float(d.sky.get("energy", 1.0)),
		"ambient_color": Color(String(a.color)), "ambient_energy": float(a.energy),
		"sky_contribution": float(a.sky_contribution),
		"fog_color": Color(String(f.color)), "fog_density": float(f.density), "fog_light_energy": float(f.light_energy),
		"fog_aerial": float(f.aerial_perspective), "fog_sun_scatter": float(f.sun_scatter),
		"fog_sky_affect": float(f.get("sky_affect", 0.5)), "fog_height": float(f.height),
		"fog_height_density": float(f.height_density),
		"contrast": float(t.contrast), "exposure": float(t.get("exposure", 1.0)),
		"lut_a": String(d.grade.lut), "lut_b": String(d.grade.lut), "lut_blend": 0.0,
		"glow_threshold": float(glow.get("threshold", 0.9)), "glow_intensity": float(glow.get("intensity", 0.4)),
		"glow_bloom": float(glow.get("bloom", 0.05)),
		"light_tint": Color(String(d.light_tint)),
		"water_sky_tint": Color(String(d.water.get("sky_tint", "#cde9f4"))),
		"lantern_paper": float(d.lanterns.get("paper", 0.0)), "lantern_window": float(d.lanterns.get("window", 0.0)),
		"lantern_lamp": float(d.lanterns.get("lamp", 0.0)),
		"mist_bands_m": d.get("mist_bands_m", []),
		"mist_color": Color(String(d.get("targets", {}).get("mist", f.color))),
	}


## Unit vector toward the sun from a compass azimuth (0 north = -Z, 90 east = +X) and an elevation.
static func sun_vector(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var az := deg_to_rad(azimuth_deg)
	var el := deg_to_rad(elevation_deg)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


## Two looks blended (t 0 = a, 1 = b): colours and numbers lerped, the sun's direction slerped, the skies and the LUTs
## cross-faded (a look carries at most two of each: a's first and b's first).
static func mix_looks(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	if t <= 0.0 or b.is_empty():
		return a.duplicate()
	if t >= 1.0 or a.is_empty():
		return b.duplicate()
	var o := {}
	for k: String in a:
		var va: Variant = a[k]
		var vb: Variant = b.get(k, va)
		if va is float and vb is float:
			o[k] = lerpf(va, vb, t)
		elif va is Color and vb is Color:
			o[k] = (va as Color).lerp(vb, t)
		else:
			o[k] = va if t < 0.5 else vb
	o.sun_dir = (a.sun_dir as Vector3).slerp(b.sun_dir, t).normalized()
	o.key = String(a.key) if t < 0.5 else String(b.key)
	o.keys = [a.keys[0], b.keys[0]]
	o.weights = [1.0 - t, t]
	o.sky_a = a.sky_a
	o.sky_b = b.sky_a
	o.sky_blend = t
	o.lut_a = a.lut_a
	o.lut_b = b.lut_a
	o.lut_blend = t
	return o


## The day cycle's look at `hour` (0-24): the two keys either side, blended by smoothstep (owner_answers.md 7).
static func at_hour(hour: float) -> Dictionary:
	var cyc: Array = data().get("day_cycle", [])
	if cyc.is_empty():
		return resolve("bright_saturated_noon")
	var h := fposmod(hour, 24.0)
	for i in cyc.size() - 1:
		var h0 := float(cyc[i][0])
		var h1 := float(cyc[i + 1][0])
		if h >= h0 and h <= h1:
			var k0 := String(cyc[i][1])
			var k1 := String(cyc[i + 1][1])
			if k0 == k1 or h1 <= h0:
				return resolve(k0)
			return mix_looks(resolve(k0), resolve(k1), smoothstep(h0, h1, h))
	return resolve(String(cyc[0][1]))


## The cards' tint now (sun x 0.6 + ambient x 0.4, as the data's light_tint).
static func light_tint(look: Dictionary) -> Color:
	return look.get("light_tint", Color.WHITE)


static func register_card(mat: ShaderMaterial) -> void:
	_cards.append(weakref(mat))


static func register_rank(mat: ShaderMaterial) -> void:
	_ranks.append(weakref(mat))


## The look onto an Environment and a sun (either may be null). The sky becomes tv_sky.gdshader (made once per
## Environment, kept after); `instant` makes a blended LUT on this thread instead of the worker (tools, tests).
static func apply(look: Dictionary, e: Environment, s: DirectionalLight3D, instant := false) -> void:
	if look.is_empty():
		return
	if s:
		s.visible = true
		var to_sun: Vector3 = look.sun_dir
		var up := Vector3.UP if absf(to_sun.y) < 0.999 else Vector3.FORWARD
		s.basis = Basis.looking_at(-to_sun, up)
		s.light_color = look.sun_color
		s.light_energy = look.sun_energy
		s.light_angular_distance = look.sun_angular
		s.shadow_enabled = true
	if e:
		_apply_sky(look, e)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		e.ambient_light_color = look.ambient_color
		e.ambient_light_energy = look.ambient_energy
		e.ambient_light_sky_contribution = look.sky_contribution
		e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		e.tonemap_exposure = look.exposure
		e.tonemap_agx_contrast = look.contrast
		e.fog_enabled = true
		e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		e.fog_light_color = look.fog_color
		e.fog_light_energy = look.fog_light_energy
		e.fog_density = look.fog_density
		e.fog_aerial_perspective = look.fog_aerial
		e.fog_sun_scatter = look.fog_sun_scatter
		e.fog_sky_affect = look.fog_sky_affect
		e.fog_height = look.fog_height
		e.fog_height_density = look.fog_height_density
		var r: Dictionary = data().get("render", {})
		var ao: Dictionary = r.get("ssao", {})
		e.ssao_enabled = bool(ao.get("enabled", true))
		e.ssao_radius = float(ao.get("radius", 1.0))
		e.ssao_intensity = float(ao.get("intensity", 0.6))
		e.ssao_power = float(ao.get("power", 1.5))
		e.ssao_light_affect = float(ao.get("light_affect", 0.0))
		e.sdfgi_enabled = bool(r.get("sdfgi", false))
		e.ssil_enabled = bool(r.get("ssil", false))
		e.ssr_enabled = bool(r.get("ssr", false))
		e.volumetric_fog_enabled = bool(r.get("volumetric_fog", false))
		e.glow_enabled = bool(r.get("glow", {}).get("enabled", true))
		e.glow_hdr_threshold = look.glow_threshold
		e.glow_intensity = look.glow_intensity
		e.glow_bloom = look.glow_bloom
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		var lut := lut_for(look, instant)
		if lut:
			e.adjustment_enabled = true
			e.adjustment_color_correction = lut
	_apply_lanterns(look)
	_apply_cards(look)


static func _apply_sky(look: Dictionary, e: Environment) -> void:
	var mat: ShaderMaterial = null
	if e.sky and e.sky.sky_material is ShaderMaterial and (e.sky.sky_material as ShaderMaterial).shader \
			and (e.sky.sky_material as ShaderMaterial).shader.resource_path == SKY_SHADER:
		mat = e.sky.sky_material
	else:
		mat = ShaderMaterial.new()
		mat.shader = load(SKY_SHADER)
		var sky := Sky.new()
		sky.sky_material = mat
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		sky.radiance_size = Sky.RADIANCE_SIZE_256
		e.sky = sky
	e.background_mode = Environment.BG_SKY
	var pa: String = look.sky_a
	var pb: String = look.sky_b
	if mat.get_meta(&"pa", "") != pa:
		mat.set_shader_parameter(&"panorama", load(pa))
		mat.set_meta(&"pa", pa)
	if mat.get_meta(&"pb", "") != pb:
		mat.set_shader_parameter(&"panorama_b", load(pb))
		mat.set_meta(&"pb", pb)
	mat.set_shader_parameter(&"blend", look.sky_blend if pa != pb else 0.0)
	mat.set_shader_parameter(&"tint", look.sky_tint)
	mat.set_shader_parameter(&"energy", look.sky_energy)
	mat.set_shader_parameter(&"ground_tint", look.fog_color)


static func _apply_lanterns(look: Dictionary) -> void:
	var mats: Dictionary = data().get("lantern_materials", {})
	for kind: String in mats:
		var energy := float(look.get("lantern_" + kind, 0.0))
		for path: String in mats[kind]:
			# held here: the shared material keeps its glow while nothing else holds it yet (a scene loaded later)
			if not _lanterns.has(path):
				_lanterns[path] = load(path) as BaseMaterial3D
			var m: BaseMaterial3D = _lanterns[path]
			if m:
				m.emission_energy_multiplier = energy


static func _apply_cards(look: Dictionary) -> void:
	var tint := light_tint(look)
	var keep: Array[WeakRef] = []
	for w in _cards:
		var m := w.get_ref() as ShaderMaterial
		if m:
			m.set_shader_parameter(&"light_tint", tint)
			m.set_shader_parameter(&"fog_color", look.fog_color)
			keep.append(w)
	_cards = keep
	var keep_r: Array[WeakRef] = []
	for w in _ranks:
		var m := w.get_ref() as ShaderMaterial
		if m:
			m.set_shader_parameter(&"rank_fog_color", look.fog_color)
			keep_r.append(w)
	_ranks = keep_r


## The grade for a look: the direction's own LUT, or two blended at the nearest of LUT_STEPS steps (made on a worker
## thread; until it is ready the nearer direction's own LUT stands in).
static func lut_for(look: Dictionary, instant := false) -> Texture3D:
	var a: String = look.lut_a
	var b: String = look.lut_b
	var step := roundi(float(look.get("lut_blend", 0.0)) * LUT_STEPS)
	if a == b or step <= 0:
		return load(a) as Texture3D
	if step >= LUT_STEPS:
		return load(b) as Texture3D
	var key := "%s|%s|%d" % [a, b, step]
	if _luts.has(key):
		return _luts[key]
	_lut_mutex.lock()
	var done: Variant = _lut_done.get(key)
	_lut_mutex.unlock()
	if done != null:
		_luts[key] = _texture3d(done)
		_lut_mutex.lock()
		_lut_done.erase(key)
		_lut_mutex.unlock()
		_lut_pending.erase(key)
		return _luts[key]
	var ta := load(a) as Texture3D
	var tb := load(b) as Texture3D
	if ta == null or tb == null:
		return ta
	var t := float(step) / LUT_STEPS
	var sa := _slices(a, ta)
	var sb := _slices(b, tb)
	if sa.is_empty() or sb.is_empty():
		return ta if t < 0.5 else tb
	if instant:
		_luts[key] = _texture3d(_blend_slices(sa, sb, t))
		return _luts[key]
	if not _lut_pending.has(key):
		_lut_pending[key] = WorkerThreadPool.add_task(func() -> void:
			var out := _blend_slices(sa, sb, t)
			_lut_mutex.lock()
			_lut_done[key] = out
			_lut_mutex.unlock())
	return ta if t < 0.5 else tb


## A LUT's 64 slices: from the imported texture, or (no renderer to read it back: headless) from the painted PNG's
## 8 x 8 grid of 64 x 64 slices (slice i at column i % 8, row i / 8, as the import's slices/horizontal=8).
static func _slices(path: String, tex: Texture3D) -> Array:
	var out: Array = tex.get_data() if tex else []
	if not out.is_empty():
		return out
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return []
	img.convert(Image.FORMAT_RGBA8)
	var n := img.get_width() / 8
	for i in 64:
		out.append(img.get_region(Rect2i((i % 8) * n, (i / 8) * n, n, n)))
	return out


static func _blend_slices(sa: Array, sb: Array, t: float) -> Array[Image]:
	var out: Array[Image] = []
	var n := mini(sa.size(), sb.size())
	for i in n:
		var ia: Image = sa[i]
		var ib: Image = sb[i]
		if ia.is_compressed() or ib.is_compressed() or ia.get_format() != ib.get_format():
			out.append(ia if t < 0.5 else ib)
			continue
		var da := ia.get_data()
		var db := ib.get_data()
		for j in da.size():
			da[j] = int(da[j] + (db[j] - da[j]) * t + 0.5)
		out.append(Image.create_from_data(ia.get_width(), ia.get_height(), false, ia.get_format(), da))
	return out


static func _texture3d(slices: Array) -> ImageTexture3D:
	var imgs: Array[Image] = []
	for im: Image in slices:
		imgs.append(im)
	var tex := ImageTexture3D.new()
	tex.create(imgs[0].get_format(), imgs[0].get_width(), imgs[0].get_height(), imgs.size(), false, imgs)
	return tex


## The look on the rig's world, region-gated: null (and nothing changed) unless the region's block names a look.
static func attach(environment_rig: Node, force_mode := "") -> ThuyVanLook:
	var want := force_mode if force_mode != "" else region_look()
	if want == "" or environment_rig == null:
		return null
	if want != "cycle" and not has_look(want):
		push_warning("ThuyVanLook: the region's look %s is not in %s" % [want, DATA])
		return null
	var node := ThuyVanLook.new()
	node.name = "ThuyVanLook"
	node.mode = want
	node.rig = environment_rig
	node.env = environment_rig.call(&"get_environment")
	node.sun = environment_rig.call(&"get_sun")
	# after DayNight (a child of the rig at priority 0): our values are the frame's last word
	node.process_priority = 100
	environment_rig.add_child(node)
	node.refresh(true)
	return node


func _process(_delta: float) -> void:
	refresh()


## The look now: the fixed direction, or the clock's hour through the day cycle.
func refresh(instant := false) -> void:
	var look := {}
	if mode == "cycle":
		var h := _clock_hour()
		look = at_hour(h)
		_hour = h
	else:
		look = resolve(mode)
	current = look
	apply(look, env, sun, instant)


func _clock_hour() -> float:
	var drv: Variant = rig.get(&"clock_driver") if rig else null
	if drv is Node and (drv as Node).get(&"clock") != null:
		return float((drv as Node).get(&"clock").hour)
	return float(Region.info().get("start_hour", 12.0))
