extends RefCounted
## CPU side of the Frontier dynamic sky (package A): the same atmosphere as
## shaders/sky/frontier_sky_dynamic.gdshader and tools/environment/lighting/atmosphere.py, used to
## light the world consistently with the sky that is drawn:
##   transmittance()          sun / moon light colour at the ground and at the cloud deck
##   sky_lut_*()              sky irradiance, horizon, zenith and upper-hemisphere radiance by sun
##                            elevation and haze (baked table assets/environment/sky/sky_lut.json,
##                            per unit sun intensity) -> ambient, fog colour, exposure, clouds
## No class_name: EnvironmentRig preloads it (no dependency on the global class cache).

const R_G := 6360e3
const H_R := 8000.0
const H_M := 1200.0
const BETA_R := Vector3(5.802e-6, 13.558e-6, 33.1e-6)
const BETA_M := 3.996e-6
const BETA_O := Vector3(0.650e-6, 1.881e-6, 0.085e-6)
const OZONE_COLUMN := 15000.0
const OZONE_R := 6385e3
const CAM_ALT := 200.0
const LUMA := Vector3(0.2126, 0.7152, 0.0722)
const LUT_PATH := "res://assets/environment/sky/sky_lut.json"

static var _lut := {}


static func chapman(X: float, h: float, mu: float) -> float:
	var c := sqrt(X + h)
	if mu >= 0.0:
		return c / (c * mu + 1.0) * exp(-h)
	var x0 := sqrt(maxf(1.0 - mu * mu, 0.0)) * (X + h)
	var c0 := sqrt(x0)
	return 2.0 * c0 * exp(minf(X - x0, 60.0)) - c / (1.0 - c * mu) * exp(-h)


## RGB optical depth from altitude `alt` (m) toward zenith cosine `mu`, out of the atmosphere.
static func depth_to_space(alt: float, mu: float, mie_density: float) -> Vector3:
	var r := R_G + alt
	var tr := H_R * chapman(R_G / H_R, alt / H_R, mu)
	var tm := H_M * chapman(R_G / H_M, alt / H_M, mu)
	var sin2 := (r / OZONE_R) * (r / OZONE_R) * (1.0 - mu * mu)
	var slant := 1.0 / sqrt(maxf(1.0 - sin2, 0.02))
	var grazing := 1.0 if mu >= -sqrt(maxf(1.0 - (R_G / r) * (R_G / r), 0.0)) else 2.0
	return BETA_R * tr + Vector3.ONE * (BETA_M * 1.11 * mie_density * tm) + BETA_O * (OZONE_COLUMN * slant * grazing)


## Transmittance (RGB 0..1) from altitude `alt` toward a direction with vertical component `mu`.
static func transmittance(mu: float, mie_density: float, alt := CAM_ALT) -> Vector3:
	var t := depth_to_space(alt, mu, mie_density)
	return Vector3(exp(-t.x), exp(-t.y), exp(-t.z))


static func luma(v: Vector3) -> float:
	return v.dot(LUMA)


static func _load_lut() -> Dictionary:
	if _lut.is_empty():
		var txt := FileAccess.get_file_as_string(LUT_PATH)
		var d = JSON.parse_string(txt) if txt != "" else null
		if typeof(d) == TYPE_DICTIONARY:
			_lut = d
		else:
			push_warning("SkyModel: %s missing or unreadable; run tools/environment/lighting/atmosphere.py lut" % LUT_PATH)
			_lut = {"mie": [4.0], "elevation_deg": [-20, 90], "irradiance": [[[0, 0, 0], [0.05, 0.08, 0.13]]],
					"horizon": [[[0, 0, 0], [0.1, 0.12, 0.14]]], "zenith": [[[0, 0, 0], [0.01, 0.018, 0.035]]],
					"upper_mean": [[[0, 0, 0], [0.02, 0.03, 0.05]]]}
	return _lut


## Table lookup: `key` in irradiance / horizon / zenith / upper_mean, bilinear in sun elevation
## (deg) and haze (mie_density), per unit sun intensity.
static func sky_lut(key: String, elevation_deg: float, mie_density: float) -> Vector3:
	var lut := _load_lut()
	var els: Array = lut.elevation_deg
	var mies: Array = lut.mie
	var tab: Array = lut[key]
	var e0 := float(els[0])
	var e1 := float(els[els.size() - 1])
	var fe := clampf((elevation_deg - e0) / (e1 - e0) * (els.size() - 1), 0.0, els.size() - 1.001)
	var ie := int(fe)
	var te := fe - ie
	var im := 0
	var tm := 0.0
	if mies.size() > 1:
		if mie_density <= float(mies[0]):
			im = 0
			tm = 0.0
		elif mie_density >= float(mies[mies.size() - 1]):
			im = mies.size() - 2
			tm = 1.0
		else:
			for k in mies.size() - 1:
				if mie_density <= float(mies[k + 1]):
					im = k
					tm = (mie_density - float(mies[k])) / (float(mies[k + 1]) - float(mies[k]))
					break
	var a := _row(tab, im, ie).lerp(_row(tab, im, ie + 1), te)
	if mies.size() > 1:
		var b := _row(tab, im + 1, ie).lerp(_row(tab, im + 1, ie + 1), te)
		a = a.lerp(b, tm)
	return a


static func _row(tab: Array, im: int, ie: int) -> Vector3:
	var r: Array = tab[mini(im, tab.size() - 1)][ie]
	return Vector3(float(r[0]), float(r[1]), float(r[2]))
