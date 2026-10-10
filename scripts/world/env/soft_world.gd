class_name SoftWorld
extends Node
## The world in the character study's light and colours (the owner, 2026-10-10, the study image beside the ring: "these colors
## everything about this palette the looks and everything this is the new default why come the world and everything looks like
## this"; "the background or the world lightning is to much right?"). The same setting as the characters' (SoftLook: Look
## Classic / Soft, Soft by default): in Soft the ring's world takes
##   the light    the study's own (its preview tool, local: tools/character/botw_style_preview.gd): a plain sky of three colours,
##                a flat ambient of one colour (no sky light, no reflections), one warm key light at a raking angle, a linear
##                tone curve at exposure 1, no auto exposure, no SSAO, no colour grade, no sun shafts; a haze of the horizon's
##                colour in the distance. Three moods like RingLook's: noon (the study's), golden and night (in its spirit)
##   the colours  every surface of the world (never a fighter, never an element's effect) in the study's colours: the deck's
##                zones, the ground, the trees and the water chosen (LOOKS, NODE_LOOKS, the shaders' own colours), every other
##                colour moved to the nearest of the study's (PALETTE) with a little of its own shade kept (KEEP); the stone
##                and planks' textures calmed (their light and dark at DETAIL), no moss, no dirt, no metal shine
##   characters  their share of the ambient back to the study's whole (SoftLook's global softlook_ambient: 1.0 here, SoftLook.
##                AMBIENT_SHARE under the classic sky), so a soft figure is lit exactly as in the study
## Nothing of the classic world is changed: the soft light is an Environment and a key light of its own put in place of the
## rig's (the rig and its DayNight keep running underneath, unseen), the soft surfaces are copies (materials, and meshes whose
## vertex colours carry the colour) swapped in, the world shaders' colours (banners, crowd, water) set on their own materials
## (their other uniforms stay live) and the lamps scaled; Classic puts every one back.
##   SoftWorld.sync(host, mood)     on a RingLevel (RingLook.set_preset calls it): Soft on or off as the setting says
##   SoftWorld.refresh(tree)        every host as the setting says now (SoftLook.refresh calls it when the setting changes)
##   SoftWorld.environment(mood)    the study's Environment (a new one), for a small world of its own (the lobby's fighter)
##   SoftWorld.key_light(sun, mood, travel)   a DirectionalLight3D as the study's key light
## A node that wants a call when the setting changes joins HOSTS and has soft_world_sync().

const NAME := "SoftWorld"
const HOSTS := &"soft_world_hosts"
## The study's colours (sRGB): its six swatches and fire's rust (SoftLook.PALETTE), and its scene's own: the sky's top and
## horizon, the ground and the ground's far edge, the ambient light.
const PALETTE := {
	"teal": "#4D9BA5", "cream": "#EDE3C6", "leather": "#735341", "slate": "#445962", "ochre": "#C8A75B", "sage": "#8C9F79",
	"rust": "#A9573C", "sky": "#87AEC2", "horizon": "#E7E8D7", "field": "#A3AF8A", "field_dark": "#8F9979", "mist": "#CDDCDD",
}
## The deck's parts (ring.json looks: the tint each part is laid with) in the study's colours: a name, or [a, b, t] a mix of two
## (Color.lerp in sRGB, t of the way to b). Read against the material it is laid in (LOOK_MATERIALS).
const LOOKS := {
	"neutral": "horizon", "zone_1": ["cream", "ochre", 0.45], "zone_2": ["mist", "sky", 0.5], "zone_3": "leather",
	"plinth": ["horizon", "field_dark", 0.35], "tank": ["slate", "sky", 0.35], "plaza": ["horizon", "field", 0.2],
	"stands": ["leather", "ochre", 0.4], "coping": "cream",
}
## Tints the arena lays that are not in ring.json looks (RingArena: the coping's, the plinth's default, the tank's edge x 1.25).
const LOOK_TINTS := {"coping": Color(0.93, 0.9, 0.82), "plinth": Color(0.72, 0.7, 0.66)}
## Which parts each of the arena's materials (RingArena.mats) is laid with; a tint of none of them is coloured as any other.
## The walk's stone (the coping, and the dressing's columns, plinths and pedestals: pale warm stones a little lighter or darker)
## is one colour, its shades kept.
const LOOK_MATERIALS := {
	&"ring_stone": ["neutral", "zone_2", "plinth"], &"ring_boards": ["zone_1", "zone_3", "stands"],
	&"ring_wall": ["tank", "plinth"], &"ring_walk": ["coping"],
}
## Nodes of the world by name, in one colour each (their own shades kept a little).
const NODE_LOOKS := {"Ground": "field", "Trees": ["sage", "field_dark", 0.5], "Hills": "field_dark"}
## The shaders' own colour uniforms in a chosen colour (shader file -> {uniform: colour}); every other colour uniform of a known
## world shader goes to its nearest.
const SHADER_LOOKS := {
	"res://shaders/ring/ring_curtain.gdshader": {"tint": ["sky", "teal", 0.25], "foam": "horizon"},
	"res://shaders/water/river.gdshader": {"shallow_tint": ["sky", "teal", 0.3], "deep_color": ["slate", "leather", 0.2]},
	"res://shaders/ring/ring_caustic.gdshader": {"tint": "mist"},
}
## World shaders whose colour uniforms are moved to the study's (the rest of a world shader's look is its own).
const SHADER_COLOURS := [
	"res://assets/ring_kit/ring_banner.gdshader", "res://shaders/ring/ring_crowd.gdshader", "res://shaders/ring/ring_curtain.gdshader",
	"res://shaders/water/river.gdshader", "res://shaders/sway/form_matter.gdshader", "res://shaders/ring/ring_caustic.gdshader",
]
## Never these (the crowd's people keep their skin and hair).
const KEEP_UNIFORMS := ["skin_light", "skin_dark", "hair_a", "hair_b"]
## The textured stone and planks (the fort's structure shader) and its soft copy's changes: the texture's light and dark at
## DETAIL of its own around its mean (the mean taken out: the vertex colour IS the colour), Lambert light.
const STRUCTURE := "res://shaders/structures/structure.gdshader"
const STRUCTURE_SWAPS := [
	["alb = texture(albedo_tex, UV).rgb;",
		"alb = mix(vec3(1.0), texture(albedo_tex, UV).rgb / max(textureLod(albedo_tex, UV, 12.0).rgb, vec3(0.02)), softworld_detail);"],
	["diffuse_burley", "diffuse_lambert"],
]
const DETAIL := 0.35
## ... the stone's less (its small stones read as speckle at 0.35): the arena's materials (RingArena.mats) by key.
const DETAIL_OF := {&"ring_stone": 0.12, &"ring_walk": 0.15, &"ring_wall": 0.2}
## ... and its baked shade (the ARM texture's AO) and bumps lower too: the gaps between the small stones read as speckle across
## the deck at a fighter's distance.
const STONE_CALM := {"texture_ao": 0.2}
const STONE_NORMAL := 0.15
## The soft structure's numbers (calm: no moss, lichen, streaks, bleach or soot; a little dirt; the normal map low; little shine).
const STRUCTURE_CALM := {"moss_strength": 0.0, "roof_moss": 0.0, "lichen": 0.0, "streak_strength": 0.0, "bleach_strength": 0.0,
	"dirt_strength": 0.12, "edge_wear": 0.15, "soot_y": 1000.0, "specular_level": 0.2, "roughness_offset": 0.15, "texture_ao": 0.6,
	"vertex_ao_diffuse": 0.25}
const STRUCTURE_NORMAL := 0.3
## Any other colour to its nearest study colour: as it showed under the classic light (GAIN: the classic exposure, about 1.5x),
## matched in OKLab with hue counted WC times lightness, then KEEP of its own difference kept (at most KEEP_L in lightness and
## KEEP_AB in hue).
const GAIN := 1.5
const WC := 2.0
const KEEP := 0.3
const KEEP_L := 0.05
const KEEP_AB := 0.02
## The moods: the sky (top, horizon, below the horizon), the ambient light, the key light (colour, strength, height in degrees;
## the rig's own sun or moon gives its bearing), the haze, the element effects' gain, the ring's lamps' strength (x their own).
const MOODS := {
	"noon": {"sky_top": "#87AEC2", "sky_horizon": "#E7E8D7", "ground_bottom": "#8F9979", "ambient": "#CDDCDD", "ambient_energy": 0.35,
		"sun": "#FFF0D4", "sun_energy": 0.95, "sun_el": 38.0, "fog": "#E7E8D7", "fog_density": 0.002, "fx_gain": 0.85, "lamp_gain": 1.0},
	"golden": {"sky_top": "#86A6B5", "sky_horizon": "#EFDCB6", "ground_bottom": "#8F8F70", "ambient": "#D9CFBC", "ambient_energy": 0.42,
		"sun": "#FFD9A8", "sun_energy": 1.35, "sun_el": 18.0, "fog": "#EBD8B4", "fog_density": 0.0025, "fx_gain": 0.85, "lamp_gain": 1.0},
	# (the night tuned for the owner, 2026-10-10, "tun the night": the first one read as a grey dusk with the deck pale all over; now
	# a deeper sky, a dimmer cooler moon and ambient, and the lamps' warm pools stronger, so the deck is lit where the lamps are)
	"night": {"sky_top": "#0F1921", "sky_horizon": "#2A3944", "ground_bottom": "#131A1E", "ambient": "#6F87A0", "ambient_energy": 0.15,
		"sun": "#B9CCE0", "sun_energy": 0.2, "sun_el": 40.0, "fog": "#2A3944", "fog_density": 0.004, "fx_gain": 0.6, "lamp_gain": 1.8},
}
## The characters' share of the ambient under this light (SoftLook's global).
const CHARACTER_AMBIENT := 1.0
## How often (s) a copied material's colour is checked against its original's (a side's team colour set at the match's start).
const RESYNC_S := 0.5

static var _pal_lab := {}
static var _active := 0

var host: Node
var mood := "noon"
var _rig: EnvironmentRig
var _we: WorldEnvironment
var _env_classic: Environment
var _attr_classic: CameraAttributes
var _sun: DirectionalLight3D
var _rays_strength: Variant = null
## Swapped in: [object, property or surface index, original, soft] (restored in reverse).
var _swaps: Array = []
## original Material -> its soft copy (null: kept as it is); a material's look key (RingArena.mats) by material.
var _mats := {}
var _mat_keys := {}
## Soft copies whose colour follows their original: [original, copy, the original's colour last seen, its node].
var _follow: Array = []
## The world shaders recoloured in place (their own material: the crowd's cheer, the banners' wave and every other uniform the game
## sets each frame stay live): {mat, names: its colour uniforms, classic: {name: its colour}, soft: {name: the study's}}.
var _inplace: Array = []
## The ring's lamps (RingDressing's lights): [light, its own strength].
var _lamps: Array = []
var _resync := 0.0
var _on := false


# ---------------------------------------------------------------- the API
## Soft on `host` (a RingLevel) in `mood` when the setting is Soft, off (everything as it was) when it is Classic.
static func sync(p_host: Node, p_mood := "noon") -> SoftWorld:
	if p_host == null:
		return null
	if not p_host.is_in_group(HOSTS):
		p_host.add_to_group(HOSTS)
	var sw := p_host.get_node_or_null(NAME) as SoftWorld
	if not SoftLook.on() or DisplayServer.get_name() == "headless":
		if sw != null:
			sw.restore()
			sw.queue_free()
			sw.name = NAME + "_gone"
		return null
	if sw == null:
		sw = SoftWorld.new()
		sw.name = NAME
		sw.process_priority = 110                # after RingLook (100) and DayNight
		p_host.add_child(sw)
	sw.host = p_host
	sw.set_mood(p_mood)
	return sw


## Every host as the setting says now.
static func refresh(tree: SceneTree = null) -> void:
	var t := tree if tree != null else Engine.get_main_loop() as SceneTree
	if t == null:
		return
	for n in t.get_nodes_in_group(HOSTS):
		if n.has_method(&"soft_world_sync"):
			n.call(&"soft_world_sync")
		else:
			var sw := n.get_node_or_null(NAME) as SoftWorld
			var look := n.get_node_or_null(RingLook.NAME) as RingLook
			sync(n, sw.mood if sw != null else (look.preset if look != null else "noon"))


## The study's light as an Environment of its own.
static func environment(p_mood := "noon") -> Environment:
	var m: Dictionary = MOODS.get(p_mood, MOODS.noon)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(String(m.sky_top))
	sm.sky_horizon_color = Color(String(m.sky_horizon))
	sm.ground_bottom_color = Color(String(m.ground_bottom))
	sm.ground_horizon_color = Color(String(m.sky_horizon))
	var sky := Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(String(m.ambient))
	env.ambient_light_energy = float(m.ambient_energy)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	# (only what burns glows: the element effects and the flames, over 1.0)
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = float(m.fog_density) > 0.0
	env.fog_light_color = Color(String(m.fog))
	env.fog_light_energy = 1.0
	env.fog_density = float(m.fog_density)
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	return env


## `sun` as the study's key light: its colour and strength, `travel`'s bearing at the mood's height.
static func key_light(sun: DirectionalLight3D, p_mood: String, travel: Vector3) -> void:
	var m: Dictionary = MOODS.get(p_mood, MOODS.noon)
	sun.light_color = Color(String(m.sun))
	sun.light_energy = float(m.sun_energy)
	var flat := Vector3(travel.x, 0.0, travel.z)
	if flat.length() < 0.01:
		flat = Vector3(0.0, 0.0, -1.0)
	var el := deg_to_rad(float(m.sun_el))
	var dir := flat.normalized() * cos(el) + Vector3.DOWN * sin(el)
	if sun.is_inside_tree():
		sun.look_at(sun.global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	else:
		sun.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)


## A palette name or a mix [a, b, t] as a Color (sRGB).
static func colour(v: Variant) -> Color:
	if v is Array:
		var a := v as Array
		return colour(a[0]).lerp(colour(a[1]), float(a[2]))
	return Color(String(PALETTE.get(String(v), v)))


## A linear colour moved to the nearest study colour (linear).
static func nearest(lin: Color, gain := GAIN) -> Color:
	var lab := SoftLook.lin_to_oklab(Vector3(lin.r, lin.g, lin.b) * gain)
	var best := ""
	var bd := INF
	for k: String in PALETTE:
		var p := _lab_of(k)
		var d := (lab.x - p.x) * (lab.x - p.x) + WC * ((lab.y - p.y) * (lab.y - p.y) + (lab.z - p.z) * (lab.z - p.z))
		if d < bd:
			bd = d
			best = k
	return _kept(lab, _lab_of(best))


## `lab` (OKLab) at `target` (OKLab), a little of its own difference kept (KEEP; at most KEEP_L, KEEP_AB): linear.
static func _kept(lab: Vector3, target: Vector3) -> Color:
	var o := Vector3(target.x + clampf((lab.x - target.x) * KEEP, -KEEP_L, KEEP_L),
			target.y + clampf((lab.y - target.y) * KEEP, -KEEP_AB, KEEP_AB),
			target.z + clampf((lab.z - target.z) * KEEP, -KEEP_AB, KEEP_AB))
	var l := SoftLook.oklab_to_lin(o)
	return Color(maxf(l.x, 0.0), maxf(l.y, 0.0), maxf(l.z, 0.0))


static func _lab_of(k: String) -> Vector3:
	if not _pal_lab.has(k):
		var c := Color(String(PALETTE[k])).srgb_to_linear()
		_pal_lab[k] = SoftLook.lin_to_oklab(Vector3(c.r, c.g, c.b))
	return _pal_lab[k]


## Whether a soft world is on anywhere (the characters take the study's whole ambient while one is).
static func active() -> bool:
	return _active > 0


# ---------------------------------------------------------------- on a level
func set_mood(p_mood: String) -> void:
	mood = p_mood if MOODS.has(p_mood) else "noon"
	if not _on:
		_attach()
	_light_now()
	ToonFx.set_gain(float((MOODS[mood] as Dictionary).fx_gain))
	_lamps_now()


func _lamps_now() -> void:
	var g := float((MOODS[mood] as Dictionary).get("lamp_gain", 1.0))
	for l: Array in _lamps:
		if is_instance_valid(l[0]):
			(l[0] as Light3D).light_energy = float(l[1]) * g


func _attach() -> void:
	_on = true
	_active += 1
	SoftLook.set_ambient_share(CHARACTER_AMBIENT)
	_rig = host.get(&"environment_rig") as EnvironmentRig if host != null else null
	if _rig != null:
		_we = _find_we(_rig)
	if _we != null:
		_env_classic = _we.environment
		_attr_classic = _we.camera_attributes
		_we.environment = environment(mood)
		var attrs := CameraAttributesPractical.new()
		attrs.auto_exposure_enabled = false
		_we.camera_attributes = attrs
	var rs := _rig.get_sun() if _rig != null else null
	if rs != null:
		_sun = DirectionalLight3D.new()
		_sun.name = "SoftSun"
		for p: String in ["shadow_enabled", "shadow_bias", "shadow_normal_bias", "shadow_blur", "directional_shadow_mode",
				"directional_shadow_max_distance", "directional_shadow_split_1", "directional_shadow_split_2",
				"directional_shadow_split_3", "directional_shadow_blend_splits", "directional_shadow_fade_start",
				"light_angular_distance", "sky_mode", "light_cull_mask"]:
			_sun.set(p, rs.get(p))
		_sun.shadow_enabled = true
		rs.get_parent().add_child(_sun)
		rs.visible = false
	var rays: Variant = _rig.get(&"_god_rays") if _rig != null else null
	if rays != null and rays is Object:
		_rays_strength = (rays as Object).get(&"strength")
		(rays as Object).set(&"strength", 0.0)
	var ring := host.get(&"ring") as RingArena if host != null else null
	if ring != null:
		for k: StringName in ring.mats:
			_mat_keys[ring.mats[k]] = k
	_walk(host)
	host.get_tree().node_added.connect(_on_node_added)


## Everything back as it was.
func restore() -> void:
	if not _on:
		return
	_on = false
	_active = maxi(_active - 1, 0)
	if _active == 0:
		SoftLook.set_ambient_share(SoftLook.AMBIENT_SHARE)
	if host != null and host.get_tree() != null and host.get_tree().node_added.is_connected(_on_node_added):
		host.get_tree().node_added.disconnect(_on_node_added)
	if _we != null and is_instance_valid(_we):
		_we.environment = _env_classic
		_we.camera_attributes = _attr_classic
	if _sun != null and is_instance_valid(_sun):
		_sun.queue_free()
	var rs := _rig.get_sun() if _rig != null and is_instance_valid(_rig) else null
	if rs != null:
		rs.visible = true
	var rays: Variant = _rig.get(&"_god_rays") if _rig != null and is_instance_valid(_rig) else null
	if rays != null and rays is Object and _rays_strength != null:
		(rays as Object).set(&"strength", _rays_strength)
	for i in range(_swaps.size() - 1, -1, -1):
		var s: Array = _swaps[i]
		if not is_instance_valid(s[0]):
			continue
		_put(s[0], s[1], s[2])
	_swaps.clear()
	_follow.clear()
	_restore_inplace()
	var look := host.get_node_or_null(RingLook.NAME) as RingLook if host != null else null
	ToonFx.set_gain(float(look.cfg.get("fx_gain", 1.0)) if look != null and not look.cfg.is_empty() else 1.0)


func _exit_tree() -> void:
	if _on:
		_restore_inplace()                   # (a world shader's material may outlive the level)
		_on = false
		_active = maxi(_active - 1, 0)
		if _active == 0:
			SoftLook.set_ambient_share(SoftLook.AMBIENT_SHARE)


func _process(dt: float) -> void:
	if not _on:
		return
	_light_now()
	# (every frame: a side's banners or the crowd's mood set by the game are in the study's colours the frame they change)
	for e: Dictionary in _inplace:
		_inplace_sync(e)
	_resync -= dt
	if _resync <= 0.0:
		_resync = RESYNC_S
		for f: Array in _follow:
			if not is_instance_valid(f[0]):
				continue
			if not (f[0] as BaseMaterial3D).albedo_color.is_equal_approx(f[2]):
				var b := f[0] as BaseMaterial3D
				f[2] = b.albedo_color
				(f[1] as BaseMaterial3D).albedo_color = Color(_target(b.albedo_color.srgb_to_linear(), f[3]).linear_to_srgb(), b.albedo_color.a)


## The key light every frame after DayNight (the rig's own sun hidden; its bearing kept: the sun's by day, the moon's at night).
func _light_now() -> void:
	if _sun == null or _rig == null:
		return
	var rs := _rig.get_sun()
	if rs == null:
		return
	rs.visible = false
	key_light(_sun, mood, -rs.global_basis.z)
	if _we != null and _we.environment != null and _we.environment != _env_classic:
		var m: Dictionary = MOODS[mood]
		var env := _we.environment
		var sm := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
		if sm != null and sm.sky_top_color != Color(String(m.sky_top)):
			_we.environment = environment(mood)


func _find_we(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n
	for c in n.get_children():
		var w := _find_we(c)
		if w != null:
			return w
	return null


# ---------------------------------------------------------------- the surfaces
func _on_node_added(n: Node) -> void:
	if host == null or not host.is_ancestor_of(n):
		return
	if n is GeometryInstance3D:
		_soften_node.call_deferred(n)
	elif _is_lamp(n):
		_add_lamp.call_deferred(n)


func _walk(n: Node) -> void:
	if n is GeometryInstance3D:
		_soften_node(n as GeometryInstance3D)
	elif _is_lamp(n):
		_add_lamp(n as Light3D)
	for c in n.get_children():
		if c == _sun:
			continue
		_walk(c)


## Whether `n` is one of the ring's lamps (a RingDressing light; never the sun, a fighter's or an effect's).
static func _is_lamp(n: Node) -> bool:
	if not (n is OmniLight3D or n is SpotLight3D):
		return false
	var at := n.get_parent()
	while at != null:
		if at is RingDressing:
			return true
		at = at.get_parent()
	return false


func _add_lamp(l: Light3D) -> void:
	if not _on or not is_instance_valid(l):
		return
	for e: Array in _lamps:
		if e[0] == l:
			return
	_lamps.append([l, l.light_energy])
	l.light_energy *= float((MOODS[mood] as Dictionary).get("lamp_gain", 1.0))


## Whether `n` is a fighter's (a body, a garment, the hair) or an effect's: never softened here (SoftLook has the fighters).
static func _skipped(n: Node) -> bool:
	if n is GPUParticles3D or n is CPUParticles3D:
		return true
	var at := n
	while at != null:
		if at is CharacterBody3D or at is CharacterBodyMesh:
			return true
		var s: Script = at.get_script()
		if s != null and String(s.get_global_name()).begins_with("ToonFx"):
			return true
		at = at.get_parent()
	return false


func _soften_node(g: GeometryInstance3D) -> void:
	if not _on or not is_instance_valid(g) or _skipped(g) or g.has_meta(&"soft_world"):
		return
	g.set_meta(&"soft_world", true)
	_swaps.append([g, &"_meta", null, null])
	if g.material_override != null:
		var soft := _soft(g.material_override, g)
		if soft != null:
			_swap(g, &"material_override", g.material_override, soft)
	elif g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null and mm.mesh.get_surface_count() == 1 and mm.mesh.surface_get_material(0) != null:
			var soft := _soft(mm.mesh.surface_get_material(0), g)
			if soft != null:
				_swap(g, &"material_override", null, soft)
	elif g is MeshInstance3D:
		_soften_mesh(g as MeshInstance3D)


func _soften_mesh(mi: MeshInstance3D) -> void:
	var am := mi.mesh as ArrayMesh
	if am == null:
		return
	var n := am.get_surface_count()
	var recolour := false
	var softs: Array = []
	for s in n:
		var m := mi.get_active_material(s)
		var soft := _soft(m, mi) if m != null else null
		softs.append(soft)
		if soft != null and _recolours(m) and (am.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR) != 0:
			recolour = true
	if recolour:
		var out := ArrayMesh.new()
		for s in n:
			var arrays := am.surface_get_arrays(s)
			var m := mi.get_active_material(s)
			if softs[s] != null and _recolours(m) and arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				arrays[Mesh.ARRAY_COLOR] = _recolour(arrays[Mesh.ARRAY_COLOR], arrays[Mesh.ARRAY_TEX_UV2], m, mi)
			out.add_surface_from_arrays(am.surface_get_primitive_type(s), arrays)
			out.surface_set_name(s, am.surface_get_name(s))
			out.surface_set_material(s, softs[s] if softs[s] != null else am.surface_get_material(s))
		out.custom_aabb = am.custom_aabb
		_swap(mi, &"mesh", am, out)
		for s in n:
			var ov := mi.get_surface_override_material(s)
			if ov != null:
				_swap(mi, s, ov, softs[s] if softs[s] != null else ov)
		return
	for s in n:
		if softs[s] == null:
			continue
		_swap(mi, s, mi.get_surface_override_material(s), softs[s])


func _swap(obj: Object, what: Variant, original: Variant, soft: Variant) -> void:
	_swaps.append([obj, what, original, soft])
	_put(obj, what, soft)


func _put(obj: Object, what: Variant, value: Variant) -> void:
	if what is int:
		(obj as MeshInstance3D).set_surface_override_material(int(what), value as Material)
	elif StringName(what) == &"_meta":
		(obj as Node).remove_meta(&"soft_world")
	else:
		obj.set(StringName(what), value)


## Whether `m`'s colour is in its mesh's vertex colours (the structure shader's; a white material's that draws them): then the
## mesh is copied with them recoloured. A coloured material that draws them too (a side's team colour over the shading) keeps
## its vertex colours, its own colour moved instead.
static func _recolours(m: Material) -> bool:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return b.vertex_color_use_as_albedo and b.albedo_color.is_equal_approx(Color.WHITE)
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		return (m as ShaderMaterial).shader.resource_path == STRUCTURE
	return false


## The soft copy of `m` (made once), or null when it stays as it is (an effect, a light, glass, an unknown shader).
func _soft(m: Material, g: GeometryInstance3D) -> Material:
	if m == null:
		return null
	if _mats.has(m):
		return _mats[m]
	var out: Material = null
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and not b.emission_enabled \
				and b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			var c := b.duplicate() as BaseMaterial3D
			c.metallic = 0.0
			c.metallic_specular = 0.3
			c.roughness = maxf(c.roughness, 0.85)
			c.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
			if not _recolours(b):
				c.albedo_color = Color(_target(b.albedo_color.srgb_to_linear(), g).linear_to_srgb(), b.albedo_color.a)
				_follow.append([b, c, b.albedo_color, g])
			out = c
	elif m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var sm := m as ShaderMaterial
		var path := sm.shader.resource_path
		if path == STRUCTURE:
			var sh := _structure_shader(sm.shader)
			if sh != null:
				var c := sm.duplicate() as ShaderMaterial
				c.shader = sh
				for k: String in STRUCTURE_CALM:
					c.set_shader_parameter(k, STRUCTURE_CALM[k])
				var key: StringName = _mat_keys.get(m, &"")
				var stone := DETAIL_OF.has(key)
				if stone:
					for k: String in STONE_CALM:
						c.set_shader_parameter(k, STONE_CALM[k])
				var ns: Variant = sm.get_shader_parameter(&"normal_strength")
				c.set_shader_parameter(&"normal_strength", float(ns if ns != null else 1.0) * (STONE_NORMAL if stone else STRUCTURE_NORMAL))
				c.set_shader_parameter(&"tint", Color.WHITE)
				c.set_shader_parameter(&"softworld_detail", float(DETAIL_OF.get(key, DETAIL)))
				out = c
		elif path in SHADER_COLOURS:
			var names: Array = []
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				if not String(u.name) in KEEP_UNIFORMS and sm.get_shader_parameter(u.name) is Color:
					names.append(String(u.name))
			var e := {"mat": sm, "names": names, "classic": {}, "soft": {}}
			_inplace.append(e)
			_inplace_sync(e)
	_mats[m] = out
	return out


static var _structure_shaders := {}


## The structure shader's soft copy (made once), or null when its code is no longer what STRUCTURE_SWAPS expects.
static func _structure_shader(original: Shader) -> Shader:
	if _structure_shaders.has(original):
		return _structure_shaders[original]
	var code := original.code
	var ok := true
	for sw: Array in STRUCTURE_SWAPS:
		if code.find(String(sw[0])) < 0:
			ok = false
		code = code.replace(String(sw[0]), String(sw[1]))
	var at := code.find("render_mode")
	var eol := code.find(";", at)
	var sh: Shader = null
	if ok and at >= 0 and eol > 0:
		code = code.substr(0, eol + 1) + "\nuniform float softworld_detail = %.3f;  // SoftWorld (scripts/world/env/soft_world.gd)" % DETAIL \
				+ code.substr(eol + 1)
		sh = Shader.new()
		sh.code = code
	else:
		push_warning("SoftWorld: the structure shader changed; its stone and planks keep the classic look")
	_structure_shaders[original] = sh
	return sh


## A world shader's colour uniforms in the study's colours, on its own material: a colour the game set since (not the one this
## put there) is taken as its classic colour and moved again.
static func _inplace_sync(e: Dictionary) -> void:
	var m := e.mat as ShaderMaterial
	if not is_instance_valid(m):
		return
	var chosen: Dictionary = SHADER_LOOKS.get(m.shader.resource_path, {})
	for nm: String in e.names:
		var v: Variant = m.get_shader_parameter(nm)
		if not v is Color:
			continue
		var cur := v as Color
		if (e.soft as Dictionary).has(nm) and cur.is_equal_approx(e.soft[nm]):
			continue
		e.classic[nm] = cur
		var out := colour(chosen[nm]) if chosen.has(nm) else nearest(cur.srgb_to_linear()).linear_to_srgb()
		out = Color(out, cur.a)
		e.soft[nm] = out
		m.set_shader_parameter(nm, out)


## The world shaders' classic colours back (a colour the game set since is left as it is) and the lamps' own strength.
func _restore_inplace() -> void:
	for e: Dictionary in _inplace:
		var m := e.mat as ShaderMaterial
		if not is_instance_valid(m):
			continue
		for nm: String in e.classic:
			var v: Variant = m.get_shader_parameter(nm)
			if v is Color and (v as Color).is_equal_approx(e.soft[nm]):
				m.set_shader_parameter(nm, e.classic[nm])
	_inplace.clear()
	for l: Array in _lamps:
		if is_instance_valid(l[0]):
			(l[0] as Light3D).light_energy = float(l[1])
	_lamps.clear()


## A linear colour of node `g`'s in the study's colours: the node's chosen one (NODE_LOOKS) or the nearest.
func _target(lin: Color, g: Node) -> Color:
	if g != null and NODE_LOOKS.has(String(g.name)):
		return colour(NODE_LOOKS[String(g.name)]).srgb_to_linear()
	return nearest(lin)


## A surface's vertex colours in the study's colours: the arena's stone and planks by the part they lay (LOOKS: the tint a part
## is laid with, its slab-to-slab shade kept), a named node's in its colour (NODE_LOOKS), anything else by its nearest (the
## material is white: the vertex colour is the colour).
func _recolour(cols: PackedColorArray, uv2: Variant, m: Material, g: Node) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(cols.size())
	var cache := {}
	var structure := m is ShaderMaterial
	var key: StringName = _mat_keys.get(m, &"")
	var parts: Array = LOOK_MATERIALS.get(key, [])
	var node_look := NODE_LOOKS.has(String(g.name))
	var uv2s := uv2 as PackedVector2Array if uv2 is PackedVector2Array else PackedVector2Array()
	var sm := m as ShaderMaterial
	for i in cols.size():
		var c := cols[i]
		var kind := int(uv2s[i].x + 0.5) if i < uv2s.size() else 0
		var ck := Vector4(snappedf(c.r, 0.002), snappedf(c.g, 0.002), snappedf(c.b, 0.002), float(kind))
		var rgb: Color
		if cache.has(ck):
			rgb = cache[ck]
		else:
			if structure:
				rgb = _structure_vertex(c, kind, parts, sm)
			elif node_look:
				var t := colour(NODE_LOOKS[String(g.name)]).srgb_to_linear()
				var lum := c.get_luminance()
				rgb = t * clampf(lum / 0.5, 0.85, 1.15) if lum > 0.0 else t
			else:
				rgb = nearest(c)
			cache[ck] = rgb
		out[i] = Color(minf(rgb.r, 1.0), minf(rgb.g, 1.0), minf(rgb.b, 1.0), c.a)
	return out


## A structure vertex: on a textured face (kind 0) the soft shader's texture averages 1, so the vertex colour is the colour: the
## part's look (by the tint it is laid with, its jitter kept); on clay, iron or end grain (kinds 1-3) the nearest study colour
## over the shader's own colour for that kind.
func _structure_vertex(c: Color, kind: int, parts: Array, sm: ShaderMaterial) -> Color:
	if kind == 0:
		var look := _look_of(c, parts)
		if look != "":
			var t := colour(LOOKS[look]).srgb_to_linear()
			var base := _look_tint(look)
			var k := clampf((c.r + c.g + c.b) / maxf(base.r + base.g + base.b, 0.01), 0.85, 1.15)
			return t * k
		return nearest(Color(c.r * 0.2, c.g * 0.2, c.b * 0.2))
	var u: StringName = {1: &"clay_color", 2: &"iron_color", 3: &"endgrain_color"}.get(kind, &"")
	var bc: Variant = sm.get_shader_parameter(u) if u != &"" else null
	if not bc is Color:
		return c
	var b := (bc as Color).srgb_to_linear()
	var want := nearest(Color(b.r * c.r, b.g * c.g, b.b * c.b))
	return Color(want.r / maxf(b.r, 0.01), want.g / maxf(b.g, 0.01), want.b / maxf(b.b, 0.01))


## The part (LOOKS) a tint is laid with: the nearest by hue (its share of r, g, b) and, a little, by how bright; "" when none
## is near.
func _look_of(c: Color, parts: Array) -> String:
	var s := c.r + c.g + c.b
	if s <= 0.0:
		return ""
	var best := ""
	var bd := 0.06
	for p: String in parts:
		var t := _look_tint(p)
		var ts := t.r + t.g + t.b
		var d := Vector3(c.r / s - t.r / ts, c.g / s - t.g / ts, c.b / s - t.b / ts).length() + 0.1 * absf(log(s / ts))
		if d < bd:
			bd = d
			best = p
	return best


static func _look_tint(p: String) -> Color:
	var looks: Dictionary = RingArena.data().get("looks", {})
	var l: Variant = (looks.get(p, {}) as Dictionary).get("tint")
	if l is Array and (l as Array).size() >= 3:
		var c := Color(float(l[0]), float(l[1]), float(l[2]))
		return c * 1.25 if p == "tank" else c
	return LOOK_TINTS.get(p, Color(0.8, 0.8, 0.8))
