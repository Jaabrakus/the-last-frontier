extends RefCounted
## Colour grade for the Frontier level (look-dev spec 4.6, package A): a 3D LUT applied by the
## Environment after tonemapping (`adjustment_color_correction`), in display (sRGB) space.
## No class_name: EnvironmentRig preloads this file, so it never depends on the global class cache.
##
##   var lut := GradeLut.texture()           # baked 64^3 asset, or a 32^3 build if params changed
##   GradeLut.grade(Color c, params) -> Color  # the grade itself (display in, display out)
##   GradeLut.build(size, params) -> ImageTexture3D
##   GradeLut.identity_params()               # every strength 0: the LUT is the identity
##
## Steps (all in display space, input clamped to 0..1):
##   1. S-curve per channel: x - a sin(2 pi x) / 2pi (mid contrast 1 + a, toe/shoulder 1 - a), then a
##      toe lift (+toe at black, fading out by 0.5). Midpoint 0.5 stays 0.5; black and white stay put
##      except for the toe lift.
##   2. Split tone: shadows toward hue 215 deg (blue-grey), highlights toward hue 40 deg (amber),
##      luminance-weighted, and scaled by the pixel's own chroma so neutral greys stay neutral.
##   3. Greens (hue 70-150 deg, 15 deg feather): chroma x0.82, value x0.97 (olive, not lime).
##   4. Reds (hue 345-15 deg, 15 deg feather): chroma x1.05 (dummy coats stay readable).
##   5. Global chroma x1.06 (AgX reads slightly flat).
## Chroma scaling is about Rec.709 luma, so it never changes a pixel's brightness.
##
## Texel convention (measured on Godot 4.7, Metal): the tonemapper samples the LUT with plain
## texture(lut, color): texel i is hit at color (i + 0.5) / N, and colours outside [0.5/N, 1 - 0.5/N]
## clamp to the first/last texel. So texel i stores grade((i + 0.5) / N), except the two end
## texels, which store the value that halves the clamp error (grade at 0.25/N and 1 - 0.25/N).
## With N = 64 an identity LUT renders within 1/255 everywhere (tools/environment/lighting/check_lut.gd).

const BAKED_SIZE := 64
const RUNTIME_SIZE := 32
## Baked LUT (tools/environment/lighting/bake_lut.gd): an 8x8 grid of 64x64 slices (slice = blue,
## x = red, y = green) imported as a 3D texture. The file name carries the parameter hash, so a stale
## bake is never used: when the parameters change and nobody re-baked, texture() builds a 32^3 LUT
## at runtime instead (and warns).
const BAKED_DIR := "res://assets/environment/lut/"

const DEFAULT_PARAMS := {
	"s_curve": 0.12,            ## mid-contrast gain a (0 = linear)
	"toe_lift": 0.015,          ## added at black, fading to 0 at 0.5
	"shadow_hue": 215.0,
	"shadow_strength": 0.06,
	"highlight_hue": 40.0,
	"highlight_strength": 0.05,
	"neutral_chroma": 0.08,     ## split tone reaches full strength at this chroma (greys: none)
	"green_sat": 0.82,
	"green_value": 0.97,
	"red_sat": 1.05,
	"global_sat": 1.06,
}


static func identity_params() -> Dictionary:
	var p := DEFAULT_PARAMS.duplicate()
	p.s_curve = 0.0
	p.toe_lift = 0.0
	p.shadow_strength = 0.0
	p.highlight_strength = 0.0
	p.green_sat = 1.0
	p.green_value = 1.0
	p.red_sat = 1.0
	p.global_sat = 1.0
	return p


## Short stable hash of the parameters (names the baked file).
static func params_hash(params: Dictionary) -> String:
	var keys := params.keys()
	keys.sort()
	var s := ""
	for k in keys:
		s += "%s=%.5f;" % [k, float(params[k])]
	return s.md5_text().substr(0, 8)


static func baked_path(params: Dictionary = DEFAULT_PARAMS) -> String:
	return BAKED_DIR + "frontier_grade_%d_%s.png" % [BAKED_SIZE, params_hash(params)]


## The LUT texture for the Environment: the baked asset when it matches the parameters, else a
## runtime build.
static func texture(params: Dictionary = DEFAULT_PARAMS) -> Texture3D:
	var path := baked_path(params)
	if ResourceLoader.exists(path):
		var t := load(path) as Texture3D
		if t:
			return t
	push_warning("GradeLut: no baked LUT at %s (run tools/environment/lighting/bake_lut.gd); building %d^3 at runtime" % [path, RUNTIME_SIZE])
	return build(RUNTIME_SIZE, params)


static func build(size: int, params: Dictionary = DEFAULT_PARAMS) -> ImageTexture3D:
	var images: Array[Image] = []
	for b in size:
		images.append(slice_image(size, b, params))
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, size, size, size, false, images)
	return tex


## Slice b (blue) of an N^3 LUT: x = red, y = green.
static func slice_image(size: int, b: int, params: Dictionary) -> Image:
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var bv := texel_coord(b, size)
	var i := 0
	for g in size:
		var gv := texel_coord(g, size)
		for r in size:
			var c := grade(Color(texel_coord(r, size), gv, bv), params)
			data[i] = clampi(roundi(c.r * 255.0), 0, 255)
			data[i + 1] = clampi(roundi(c.g * 255.0), 0, 255)
			data[i + 2] = clampi(roundi(c.b * 255.0), 0, 255)
			data[i + 3] = 255
			i += 4
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)


## Input colour whose grade texel i stores (see the texel convention above).
static func texel_coord(i: int, size: int) -> float:
	if i == 0:
		return 0.25 / size
	if i == size - 1:
		return 1.0 - 0.25 / size
	return (i + 0.5) / size


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Chroma scale about luma (keeps brightness).
static func _sat(c: Color, s: float) -> Color:
	var l := _luma(c)
	return Color(l + (c.r - l) * s, l + (c.g - l) * s, l + (c.b - l) * s)


## Weight 0..1 of hue h (deg) inside [lo, hi] (wrapping), with a linear feather outside.
static func _hue_window(h: float, lo: float, hi: float, feather: float) -> float:
	var centre := lo + fposmod(hi - lo, 360.0) * 0.5
	var half := fposmod(hi - lo, 360.0) * 0.5
	var d := absf(fposmod(h - centre + 180.0, 360.0) - 180.0)
	return clampf(1.0 - (d - half) / feather, 0.0, 1.0)


## Zero-luma chroma direction of a fully saturated hue.
static func _tint(hue_deg: float) -> Color:
	var c := Color.from_hsv(fposmod(hue_deg, 360.0) / 360.0, 1.0, 1.0)
	var l := _luma(c)
	return Color(c.r - l, c.g - l, c.b - l)


static func _curve(x: float, a: float, toe: float) -> float:
	var y := x - a * sin(TAU * x) / TAU
	return y + toe * (1.0 - smoothstep(0.0, 0.5, x))


## The grade: display-space colour in, display-space colour out (0..1).
static func grade(c: Color, params: Dictionary = DEFAULT_PARAMS) -> Color:
	var a: float = params.s_curve
	var toe: float = params.toe_lift
	var o := Color(_curve(c.r, a, toe), _curve(c.g, a, toe), _curve(c.b, a, toe))

	# Split tone, scaled by the pixel's chroma so greys stay grey.
	var l := _luma(o)
	var chroma := maxf(o.r, maxf(o.g, o.b)) - minf(o.r, minf(o.g, o.b))
	var k := clampf(chroma / maxf(float(params.neutral_chroma), 1e-4), 0.0, 1.0)
	var ws := (1.0 - l) * (1.0 - l) * smoothstep(0.0, 0.1, l) * float(params.shadow_strength) * k
	var wh := l * l * (1.0 - smoothstep(0.92, 1.0, l)) * float(params.highlight_strength) * k
	var ts := _tint(params.shadow_hue)
	var th := _tint(params.highlight_hue)
	o = Color(o.r + ts.r * ws + th.r * wh, o.g + ts.g * ws + th.g * wh, o.b + ts.b * ws + th.b * wh)

	# Hue-selective chroma and value.
	var hue := o.h * 360.0
	if chroma > 1e-4:
		var wg := _hue_window(hue, 70.0, 150.0, 15.0)
		if wg > 0.0:
			o = _sat(o, lerpf(1.0, params.green_sat, wg))
			var v := lerpf(1.0, params.green_value, wg)
			o = Color(o.r * v, o.g * v, o.b * v)
		var wr := _hue_window(hue, 345.0, 15.0, 15.0)
		if wr > 0.0:
			o = _sat(o, lerpf(1.0, params.red_sat, wr))
	o = _sat(o, params.global_sat)
	return Color(clampf(o.r, 0.0, 1.0), clampf(o.g, 0.0, 1.0), clampf(o.b, 0.0, 1.0))
