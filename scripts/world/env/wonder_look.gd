class_name WonderLook
extends RefCounted
## The wonder look (user 2026-10-02: "can we do a treasure planet look actually? what it might feel like if that world
## was real"): the frontier as a world among the stars. Launch with look=wonder; the frontier look is the default and is
## not touched without it.
##   - the sky: a ringed giant wheeling round the pole star, two moons, the etherium's nebulae
##     (shaders/sky/wonder_sky.gdshaderinc, the dynamic sky's `wonder` uniforms);
##   - the grade: richer colour (the saturation up a little over the u10 LUT);
##   - the air: the dust motes gold and more of them (sparks in the sunbeams).
## EnvironmentRig.build() applies it after the sky is made.

const ARG := "look=wonder"
const SATURATION := 1.18
const MOTE_COLOR := Color(1.0, 0.78, 0.42)
## The giant's direction on the celestial sphere (equatorial): the sky's wonder_planet_eq default
## (shaders/sky/wonder_sky.gdshaderinc).
const GIANT_EQ := Vector3(0.21, 0.33, 0.92)


## look=reveal: the frontier's sky, then 5 s in the sky opens as the story's turn does it (look-dev of the reveal).
static func reveal_requested() -> bool:
	return "look=reveal" in OS.get_cmdline_user_args() or "--look=reveal" in OS.get_cmdline_user_args()


static func requested() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--") == ARG:
			return true
	return ProjectSettings.get_setting("frontier/graphics/look", "") == "wonder"


## Where the ringed giant stands now (world, unit, from the valley up): the sky's wonder_planet_eq (its default when the
## material has none) turned by the clock's celestial basis, as the sky draws it (transpose(celestial) * eq). ZERO when
## the rig has no clock (the story then places its reveal by itself).
static func giant_dir(rig: EnvironmentRig) -> Vector3:
	if rig == null or rig.clock_driver == null:
		return Vector3.ZERO
	var clock: Variant = rig.clock_driver.get("clock")
	if not (clock is WorldClock):
		return Vector3.ZERO
	var eq := GIANT_EQ
	var mat := rig._sky_material
	if mat != null and mat.get_shader_parameter(&"wonder_planet_eq") is Vector3:
		eq = mat.get_shader_parameter(&"wonder_planet_eq")
	return ((clock as WorldClock).celestial_basis().transposed() * eq.normalized()).normalized()


## The wonder at `amount` (0 the frontier's own look .. 1 the full wonder): the sky's layer, the grade, the motes' gold.
## The story fades it in (EnvironmentRig.reveal_wonder: the sky opens), look=wonder sets it at once.
static func apply(sky: ShaderMaterial, env: Environment, motes: GPUParticles3D, amount := 1.0) -> void:
	var a := clampf(amount, 0.0, 1.0)
	if sky:
		sky.set_shader_parameter(&"wonder", a)
	if env:
		env.adjustment_enabled = true
		env.adjustment_saturation = lerpf(1.0, SATURATION, a)
	if motes:
		var quad := motes.draw_pass_1 as PrimitiveMesh
		var draw := quad.material as ShaderMaterial if quad else null
		if draw:
			var c := Color(1.0, 0.93, 0.82).lerp(MOTE_COLOR, a)
			draw.set_shader_parameter(&"mote_color", Vector3(c.r, c.g, c.b))
			draw.set_shader_parameter(&"intensity", lerpf(0.35, 0.6, a))
