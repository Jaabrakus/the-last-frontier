class_name FormHollow
extends Decal
## Where the earth a Form cast raised came from (FormEffects; "the matter comes from the place"): a shallow hollow on the ground,
## a Decal (dark, damp earth in a soft-edged pit, its own normal map so the light finds its rim and its floor) of width (x)
## by depth (z) laid along the ground, fading out over fade_s. Group GROUP (the tests count them). The texture is made once.

const GROUP := &"form_hollows"
const TEX_N := 96

var fade_s := 600.0
var _t := 0.0

static var _albedo: Texture2D
static var _normal: Texture2D


## A hollow of `w` x `d` at `at` (on the ground), its depth along `along` (flat), under `parent`.
static func dig(parent: Node, at: Vector3, along: Vector3, w: float, d: float, fade := 600.0) -> FormHollow:
	var h := FormHollow.new()
	h.name = "FormHollow"
	h.fade_s = fade
	h.size = Vector3(w, 0.9, d)
	_make_textures()
	h.texture_albedo = _albedo
	h.texture_normal = _normal
	h.albedo_mix = 1.0
	h.normal_fade = 0.35
	h.upper_fade = 0.25
	h.lower_fade = 0.25
	h.cull_mask = 1
	parent.add_child(h)
	var z := Vector3(along.x, 0.0, along.z)
	z = z.normalized() if z.length_squared() > 1e-6 else Vector3.FORWARD
	var x := Vector3.UP.cross(z).normalized()
	h.global_transform = Transform3D(Basis(x, Vector3.UP, z), at + Vector3.UP * 0.1)
	h.add_to_group(GROUP)
	return h


func _process(dt: float) -> void:
	_t += dt
	if fade_s > 0.0:
		var u := clampf((_t - fade_s * 0.7) / (fade_s * 0.3), 0.0, 1.0)
		modulate = Color(1, 1, 1, 1.0 - u)
		if _t >= fade_s:
			queue_free()


## The pit: a bowl, deepest at the middle, its rim a little raised; damp dark earth at the floor, turned earth on the rim.
static func _make_textures() -> void:
	if _albedo != null:
		return
	var n := FastNoiseLite.new()
	n.seed = 1761
	n.frequency = 0.08
	var hgt := PackedFloat32Array()
	hgt.resize(TEX_N * TEX_N)
	var alb := Image.create(TEX_N, TEX_N, false, Image.FORMAT_RGBA8)
	for y in TEX_N:
		for x in TEX_N:
			var u := (x + 0.5) / TEX_N * 2.0 - 1.0
			var v := (y + 0.5) / TEX_N * 2.0 - 1.0
			# (a rounded rectangle, so a long strip of pit keeps its ends round)
			var q := Vector2(maxf(absf(u) - 0.25, 0.0), maxf(absf(v) - 0.25, 0.0)).length() / 0.75
			var r := q + n.get_noise_2d(x, y) * 0.12
			var bowl := -(1.0 - smoothstep(0.0, 0.85, r))
			var rim := exp(-pow((r - 0.92) / 0.09, 2.0)) * 0.35
			hgt[y * TEX_N + x] = bowl + rim
			var deep := 1.0 - smoothstep(0.1, 0.9, r)
			var grain := 0.85 + 0.3 * (n.get_noise_2d(x * 4.0, y * 4.0) * 0.5 + 0.5)
			var c := Color(0.27, 0.2, 0.14).lerp(Color(0.1, 0.075, 0.055), deep) * grain
			var a := 1.0 - smoothstep(0.85, 1.05, r)
			alb.set_pixel(x, y, Color(c.r, c.g, c.b, a * 0.92))
	var nor := Image.create(TEX_N, TEX_N, false, Image.FORMAT_RGBA8)
	for y in TEX_N:
		for x in TEX_N:
			var xl := hgt[y * TEX_N + maxi(x - 1, 0)]
			var xr := hgt[y * TEX_N + mini(x + 1, TEX_N - 1)]
			var yu := hgt[maxi(y - 1, 0) * TEX_N + x]
			var yd := hgt[mini(y + 1, TEX_N - 1) * TEX_N + x]
			var nv := Vector3((xl - xr) * 6.0, (yu - yd) * 6.0, 1.0).normalized()
			nor.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5, 1.0))
	alb.generate_mipmaps()
	nor.generate_mipmaps()
	_albedo = ImageTexture.create_from_image(alb)
	_normal = ImageTexture.create_from_image(nor)
