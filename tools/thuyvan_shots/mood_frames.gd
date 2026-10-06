extends SceneTree
## The greybox's mood frames for the owner (plan phase 1, T5: he picks the render look before any kit is built): one
## camera at the still reach (shot_util.gd), S1, the early-rains morning, rendered three ways:
##   a_today      today's look, as the level builds it (AgX, the u10 grade LUT, the frontier's fog)
##   b_painterly  a painterly grade on the WorldEnvironment only: softer filmic tonemap, a little glow on the highlights,
##                lower contrast and saturation, the air thicker (fog x PAINT_FOG, more aerial perspective); nothing else
##                in the scene changed
##   c_look_a     the loop's toon preset, only once tb/LOOK-A has gated into spellcraft and been merged into thuyvan: not
##                rendered here. Pass look_a=<path to the loop's LOOK-A review image> to lay it beside the two.
## Writes a_today.png, b_painterly.png and mood_frames.png (the two or three side by side) to out=.
##
##   zsh PLAN/bin/godot_run.sh --path <lane> --resolution 1600x900 -s tools/thuyvan_shots/mood_frames.gd -- \
##       out=PLAN/review/T5 [hour=7.5] [state=S1] [look_a=<png>]

const U := preload("res://tools/thuyvan_shots/shot_util.gd")
const PAINT_FOG := 2.4


func _initialize() -> void:
	var a := U.args()
	var dir := U.out_dir()
	var lv: Node = await U.load_level(self)
	if lv == null:
		print("MOOD no level")
		quit(1)
		return
	lv.call("set_state", String(a.get("state", "S1")), true)
	U.reach_camera(lv)
	U.set_sky(lv, float(a.get("hour", "7.5")), "fair")
	await U.settle(self, 90)
	var shots: Array = []
	shots.append(await U.grab(self, dir, "a_today"))
	_painterly(lv)
	await U.settle(self, 60)
	shots.append(await U.grab(self, dir, "b_painterly"))
	if a.has("look_a"):
		var img := Image.load_from_file(String(a.look_a))
		if img:
			shots.append(img)
		else:
			print("MOOD look_a: could not read ", a.look_a)
	U.sheet(shots, shots.size()).save_png(dir.path_join("mood_frames.png"))
	print("MOOD wrote ", dir.path_join("mood_frames.png"), " (%d looks)" % shots.size())
	quit(0)


## The painterly grade: the WorldEnvironment's tonemap, glow, adjustments and fog only.
func _painterly(lv: Node) -> void:
	var rig: EnvironmentRig = lv.get("environment_rig")
	var env := rig.get_environment()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 0.86
	env.adjustment_saturation = 0.8
	env.adjustment_brightness = 1.05
	env.fog_aerial_perspective = 0.7
	# (DayNight sets the fog's density every frame from its base: the base thickened)
	if rig.clock_driver:
		rig.clock_driver.set("_fog_base", float(rig.clock_driver.get("_fog_base")) * PAINT_FOG)
	else:
		env.fog_density *= PAINT_FOG
