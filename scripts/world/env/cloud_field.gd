class_name CloudField
extends RefCounted
## CPU mirror of the cloud engine (shaders/sky/cloud_engine.gdshaderinc): the same weather envelope (ce_front,
## ce_patches, ce_column), the same density (the 3D Perlin-Worley noise, sampled here from the imported Texture3D
## with its mip levels) and the same view march, so what the sky draws and what the world does agree:
##   sun_transmittance()   DayNight's cloud shade: the share of the sun that gets through the clouds in front of it
##                         (as drawn: the half-res pass's march toward the sun, alpha = 1 - transmittance)
##   front_at()            the storm front at a world position (rain at the player, lightning, gusts)
## The fields are the shader's uniforms (WeatherSystem fills them, DayNight uploads them with apply()). Keep this
## file and the shader in step: tests/env/test_weather.gd checks the mirror against the GPU (windowed) and the
## weather logic (headless).

const NOISE_3D := "res://assets/environment/sky/cloud_noise_3d.png"
const R := 6371e3
const BASE_TILE := 7200.0
const DETAIL_TILE := 1200.0
const VSCALE := 1.5
const CB_BASE := 900.0
const NS_TOP := 5500.0
const N := 64
## Step jitters whose mean transmittance stands for the drawn (TAA-resolved) sky: DayNight cycles them.
const SHADE_JITTERS: Array[float] = [0.125, 0.625, 0.375, 0.875]

# --- the shader's uniforms --------------------------------------------------------------------------------------
var cu_cover := 0.3
var cu_base := 1500.0
var cu_top := 3000.0
var sc_cover := 0.0
var sc_base := 1100.0
var sc_top := 2300.0
var front := Vector4(1.0, 0.0, -1e7, 0.0)            ## xy direction of travel, z leading edge (m), w strength
var front_shape := Vector4(16000.0, 45000.0, 75000.0, 13000.0)
var cloud_ceiling := 4500.0
var cloud_extinction := 0.04
var cloud_evolve := 0.0
var cloud_steps := 28
var drift := Vector2.ZERO                            ## sky_cloud_offset.xy (m, wrapped at BASE_TILE)
var cirrus_drift := Vector2.ZERO                     ## sky_cloud_offset.zw
var cirrus_coverage := 0.3
var veil := 0.0
var haze_km := 30.0
var patch_offset := Vector2.ZERO                     ## unwrapped drift of the coverage patches (m)

var _line := 0.0

## Mip levels of the noise's base (R) and detail (G) channels: [size, PackedFloat32Array r, PackedFloat32Array g].
var _mips: Array = []


func _init(load_noise := true) -> void:
	if load_noise:
		load_noise_texture()


## Reads the 3D noise into float arrays with its mip chain: from the imported Texture3D (a real renderer), else
## from the source PNG's 8 x 8 slices (headless: the dummy renderer keeps no texture data). False if neither.
func load_noise_texture(path := NOISE_3D) -> bool:
	_mips.clear()
	var slices: Array[Image] = []
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture3D
		if tex:
			slices = tex.get_data()
	if slices.size() < N:
		slices.clear()
		var src := Image.load_from_file(ProjectSettings.globalize_path(path))
		if src == null or src.get_width() != N * 8 or src.get_height() != N * 8:
			return false
		for z in N:
			slices.append(src.get_region(Rect2i((z % 8) * N, (z / 8) * N, N, N)))
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	r.resize(N * N * N)
	g.resize(N * N * N)
	for z in N:
		var img: Image = slices[z]
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var data := img.get_data()
		for y in N:
			for x in N:
				var o := (y * N + x) * 4
				var i := (z * N + y) * N + x
				r[i] = data[o] / 255.0
				g[i] = data[o + 1] / 255.0
	_mips.append([N, r, g])
	var s := N
	while s > 4:
		var prev: Array = _mips[_mips.size() - 1]
		var ns := s / 2
		var r2 := PackedFloat32Array()
		var g2 := PackedFloat32Array()
		r2.resize(ns * ns * ns)
		g2.resize(ns * ns * ns)
		var pr: PackedFloat32Array = prev[1]
		var pg: PackedFloat32Array = prev[2]
		for z in ns:
			for y in ns:
				for x in ns:
					var sr := 0.0
					var sg := 0.0
					for k in 8:
						var j := ((z * 2 + (k >> 2)) * s + (y * 2 + ((k >> 1) & 1))) * s + x * 2 + (k & 1)
						sr += pr[j]
						sg += pg[j]
					var i2 := (z * ns + y) * ns + x
					r2[i2] = sr * 0.125
					g2[i2] = sg * 0.125
		_mips.append([ns, r2, g2])
		s = ns
	return true


func has_noise() -> bool:
	return not _mips.is_empty()


## Uploads the uniforms to the sky material and the drift to the global sky_cloud_offset.
func apply(mat: ShaderMaterial) -> void:
	RenderingServer.global_shader_parameter_set(&"sky_cloud_offset", Vector4(drift.x, drift.y, cirrus_drift.x, cirrus_drift.y))
	if mat == null:
		return
	mat.set_shader_parameter(&"cu_cover", cu_cover)
	mat.set_shader_parameter(&"cu_base", cu_base)
	mat.set_shader_parameter(&"cu_top", cu_top)
	mat.set_shader_parameter(&"sc_cover", sc_cover)
	mat.set_shader_parameter(&"sc_base", sc_base)
	mat.set_shader_parameter(&"sc_top", sc_top)
	mat.set_shader_parameter(&"front", front)
	mat.set_shader_parameter(&"front_shape", front_shape)
	mat.set_shader_parameter(&"cloud_ceiling", cloud_ceiling)
	mat.set_shader_parameter(&"cloud_extinction", cloud_extinction)
	mat.set_shader_parameter(&"cloud_evolve", cloud_evolve)
	mat.set_shader_parameter(&"cloud_steps", cloud_steps)
	mat.set_shader_parameter(&"cirrus_coverage", cirrus_coverage)
	mat.set_shader_parameter(&"veil", veil)
	mat.set_shader_parameter(&"haze_km", haze_km)
	mat.set_shader_parameter(&"patch_offset", patch_offset)


# --- the shader's functions ----------------------------------------------------------------------------------------

static func sphere(r0: float, mu: float, radius: float) -> float:
	var b := r0 * mu
	return -b + sqrt(maxf(b * b - r0 * r0 + radius * radius, 0.0))


static func column(h: float, base: float, top: float, round_from: float) -> float:
	var hf := (h - base) / maxf(top - base, 1.0)
	return smoothstep(0.0, 0.07, hf) * (1.0 - smoothstep(round_from, 1.0, hf))


static func patches(xz: Vector2) -> float:
	var q := xz * 1.3e-4
	var v := sin(q.x * 1.7 + 1.3) * sin(q.y * 1.3 + 0.4) + 0.5 * sin(q.x * 0.9 - q.y * 2.3 + 2.1)
	return clampf(0.5 + 0.4 * v, 0.0, 1.0)


## ce_front: x cumulonimbus cells, y the trailing rain deck, z anvil shield, w rain rate (x strength); the line's
## band (ce_front's `line`) is left in line_at_last().
func front_at(xz: Vector2) -> Vector4:
	_line = 0.0
	if front.w <= 0.0:
		return Vector4.ZERO
	var dir := Vector2(front.x, front.y)
	var a := xz.dot(Vector2(-dir.y, dir.x))
	var u := xz.dot(dir) - front.z + 5000.0 * sin(a * 2.2e-5 + 0.7)
	var cw := front_shape.x
	var tw := front_shape.y
	var k := a / front_shape.w + front.z * 3e-6
	var ci := floorf(k + 0.5)
	var kf := k - ci
	var strength := 0.55 + 0.45 * sin(ci * 2.39996 + 0.5)
	var uc := u + 0.45 * cw + 0.12 * cw * sin(ci * 1.7)
	var cb := exp(-kf * kf * 9.0 - uc * uc / (0.09 * cw * cw)) * strength
	var ul := u + 0.45 * cw
	var line := exp(-ul * ul / (0.16 * cw * cw))
	_line = line * front.w
	var deck := smoothstep(-cw - tw, -cw - 0.55 * tw, u) * (1.0 - smoothstep(-0.8 * cw, -0.35 * cw, u))
	var anvil := exp(-maxf(u, 0.0) / (0.3 * front_shape.z)) * smoothstep(-cw - 0.4 * tw, -0.9 * cw, u)
	var rain := minf(maxf(smoothstep(0.2, 0.6, cb), line * 0.55) + deck * 0.3, 1.0)
	return Vector4(cb, deck, anvil, rain) * front.w


func line_at_last() -> float:
	return _line


## Metres the point xz is ahead of the front's leading edge (> 0: not reached yet), with the line's bow.
func front_u(xz: Vector2) -> float:
	var dir := Vector2(front.x, front.y)
	var a := xz.dot(Vector2(-dir.y, dir.x))
	return xz.dot(dir) - front.z + 5000.0 * sin(a * 2.2e-5 + 0.7)


## ce_density without its lighting outputs: density 0..1 at world (x, h, z), h above the ground. `env` (optional
## one-element array) receives the envelope, as the shader's out parameter.
func density(wp: Vector3, lod: float, detail: bool, env: Array = []) -> float:
	var h := wp.y
	var xz := Vector2(wp.x, wp.z)
	var f := front_at(xz)
	var cu := minf(cu_cover * (0.5 + 1.0 * patches(xz - patch_offset)), 1.0)
	var hf_cb := clampf((h - CB_BASE) / 10100.0, 0.0, 1.0)
	var req := 0.95 * hf_cb * hf_cb * sqrt(hf_cb)
	var e_cb := smoothstep(0.0, 0.03, hf_cb) * smoothstep(maxf(req - 0.05, 0.0), req + 0.45, f.x) if f.x > 0.0 else 0.0
	var e_cu := column(h, cu_base, cu_top, 0.35) * cu
	var e_sc := column(h, sc_base, sc_top, 0.65) * sc_cover
	var e_ns := maxf(column(h, 1000.0, NS_TOP, 0.75) * f.y * 0.95, column(h, CB_BASE, 3200.0, 0.5) * _line * 0.7)
	var e_an := smoothstep(8200.0, 8900.0, h) * (1.0 - smoothstep(10600.0, 11400.0, h)) * f.z * f.z * 0.8
	var e := maxf(maxf(e_cu, e_sc), maxf(maxf(e_cb, e_ns), e_an))
	if not env.is_empty():
		env[0] = e
	if e < 0.02:
		return 0.0
	var ew := 1.0 / maxf(e_cu + e_sc + e_cb + e_ns + e_an, 1e-4)
	var dscale := (e_cu * 1.0 + e_sc * 0.55 + e_cb * 1.0 + e_ns * 0.55 + e_an * 0.035) * ew
	var sharp := (e_cu * 3.0 + e_sc * 1.2 + e_cb * 2.5 + e_ns * 1.5 + e_an * 1.0) * ew
	var q := Vector3(wp.x - drift.x, h * VSCALE - cloud_evolve, wp.z - drift.y)
	var n := _noise(q / BASE_TILE, lod, 1)
	var c := clampf((n - (1.0 - e)) / maxf(e, 0.05) * sharp, 0.0, 1.0) * dscale
	if detail and c > 0.0 and c < 0.5 * dscale:
		var qd := Vector3(q.x, h * VSCALE - cloud_evolve * 1.5, q.z) / DETAIL_TILE
		var dn := _noise(qd, lod, 2)
		var hf := clampf((h - cu_base) / maxf(cu_top - cu_base, 1.0), 0.0, 1.0)
		dn = lerpf(1.0 - dn, dn, smoothstep(0.05, 0.4, hf))
		c = clampf((c - dn * 0.4 * dscale) / (1.0 - dn * 0.4), 0.0, 1.0)
	return c


## Transmittance of the volumetric clouds along direction d from the camera at world position cam: the shader's
## ce_clouds march (same steps, segments and mip levels) with the step jitter `jitter` (the shader's is per pixel and
## per frame), so 1 - result is the alpha drawn over the sun.
func view_transmittance(d: Vector3, cam: Vector3, jitter := 0.5) -> float:
	if d.y < 0.0:
		return 1.0
	var r0 := R + maxf(cam.y, 0.0) + 2.0
	var mu := d.y
	var lo := minf(minf(cu_base, sc_base), CB_BASE if front.w > 0.0 else 1e5)
	var t0 := sphere(r0, mu, R + lo)
	var t1 := minf(sphere(r0, mu, R + cloud_ceiling), t0 + 160000.0)
	var n := int(lerpf(float(cloud_steps) * 0.55, float(cloud_steps), 1.0 - smoothstep(0.05, 0.5, mu)))
	var ta := minf(sphere(r0, mu, R + minf(cloud_ceiling, 5000.0)), t1)
	var na := int(float(n) * 0.65) if cloud_ceiling > 5000.0 else n
	var dta := (ta - t0) / float(na)
	var dtb := (t1 - ta) / float(maxi(n - na, 1))
	var dt := dta
	var lod := clampf(log(dt / 220.0) / log(2.0), 0.0, 4.0)
	var t := t0 + dt * jitter
	var tau := 0.0
	var env := [0.0]
	for i in n * 2:
		if t > t1:
			break
		if t > ta and dt != dtb:
			dt = dtb
			lod = clampf(log(dt / 220.0) / log(2.0), 0.0, 4.0)
		var p := Vector3(0.0, r0, 0.0) + d * t
		var wp := Vector3(cam.x + p.x, p.length() - R, cam.z + p.z)
		var c := density(wp, lod, t < 30000.0, env)
		var st := dt * 0.5 if float(env[0]) > 0.02 else dt
		if c > 0.003:
			# the shader's surface refinement: a step that would turn the ray opaque is re-sampled from the cloud's
			# surface (bisection), three short steps covering ~3 optical depths
			if c * cloud_extinction * st > 1.5 and exp(-tau) > 0.2:
				var a0 := t - st
				var a1 := t
				for b in 2:
					var am := 0.5 * (a0 + a1)
					var pm := Vector3(0.0, r0, 0.0) + d * am
					if density(Vector3(cam.x + pm.x, pm.length() - R, cam.z + pm.z), lod, true) > 0.003:
						a1 = am
					else:
						a0 = am
				var sst := minf(st, 3.0 / (c * cloud_extinction)) / 3.0
				var t_in := lerpf(a0, a1, jitter)
				for k in 3:
					var ts := t_in + (k + 0.5) * sst
					var ps := Vector3(0.0, r0, 0.0) + d * ts
					var cs := density(Vector3(cam.x + ps.x, ps.length() - R, cam.z + ps.z), lod, true, env)
					if cs > 0.003:
						tau += cs * cloud_extinction * sst
			else:
				tau += c * cloud_extinction * st
			if exp(-tau) < 0.015:
				return 0.0
		t += st
	return exp(-tau)


## Share of the direct sun that reaches the ground at cam (the clouds' transmittance toward it, the cirrostratus
## veil and the anvil shield: ce_cirrus's alpha without the streaks), for the step jitter `jitter`. The sky's jitter
## changes per pixel and per frame and TAA averages it; a low sun's march crosses cumulus in steps of about a
## kilometre, so one jitter can disagree with the drawn sun: DayNight averages SHADE_JITTERS over successive marches.
func sun_transmittance(sun_dir: Vector3, cam: Vector3, jitter := 0.5) -> float:
	if sun_dir.y <= 0.0:
		return 1.0
	var tr := view_transmittance(sun_dir, cam, jitter)
	var r0 := R + maxf(cam.y, 0.0) + 2.0
	var t := sphere(r0, sun_dir.y, R + 9000.0)
	var xz := Vector2(cam.x + sun_dir.x * t, cam.z + sun_dir.z * t)
	var v := maxf(veil, front_at(xz).z * 0.7)
	return tr * (1.0 - 0.6 * v)


## Trilinear sample of channel ch (1 base, 2 detail) at noise coordinate q (tiles), mip level lod (blended).
func _noise(q: Vector3, lod: float, ch: int) -> float:
	if _mips.is_empty():
		return 0.5
	var l0 := clampi(int(floor(lod)), 0, _mips.size() - 1)
	var l1 := mini(l0 + 1, _mips.size() - 1)
	var f := clampf(lod - l0, 0.0, 1.0)
	var a := _tri(_mips[l0], q, ch)
	if f <= 0.001 or l1 == l0:
		return a
	return lerpf(a, _tri(_mips[l1], q, ch), f)


static func _tri(m: Array, q: Vector3, ch: int) -> float:
	var s: int = m[0]
	var arr: PackedFloat32Array = m[ch]
	var x := fposmod(q.x, 1.0) * s - 0.5
	var y := fposmod(q.y, 1.0) * s - 0.5
	var z := fposmod(q.z, 1.0) * s - 0.5
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	var z0 := int(floor(z))
	var fx := x - x0
	var fy := y - y0
	var fz := z - z0
	var xa := posmod(x0, s)
	var xb := posmod(x0 + 1, s)
	var ya := posmod(y0, s) * s
	var yb := posmod(y0 + 1, s) * s
	var za := posmod(z0, s) * s * s
	var zb := posmod(z0 + 1, s) * s * s
	var c00 := lerpf(arr[za + ya + xa], arr[za + ya + xb], fx)
	var c10 := lerpf(arr[za + yb + xa], arr[za + yb + xb], fx)
	var c01 := lerpf(arr[zb + ya + xa], arr[zb + ya + xb], fx)
	var c11 := lerpf(arr[zb + yb + xa], arr[zb + yb + xb], fx)
	return lerpf(lerpf(c00, c10, fy), lerpf(c01, c11, fy), fz)
