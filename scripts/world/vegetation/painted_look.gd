extends RefCounted
## The painted look of the distant trees (user 2026-09-28: "the painted trees can be distant trees"): from LOD2 on
## (and the impostors) the realistic trees' own meshes are painted after the look test of 2026-09-26 (branch
## part/style-trees, after Alariko's paintings, artstation.com/alariko: inspiration only, none of their artwork is
## used): each foliage card one rounded dab of one of the species' greens, the light banded per dab
## (shaders/vegetation/painted_tree.gdshader, painted_impostor.gdshader, painted_light.gdshaderinc). The trees near the
## player keep their realistic materials; the hand-over between them dissolves (lod_fade.gdshaderinc).
## Off with the user arg veg_far=real (A/B: the realistic LOD2 and impostors as before).

## Albedo per look (sRGB): leaf_a / leaf_b are mixed dab by dab; the light and the cool shade fill come from the
## shader, so these carry hue, not value.
const LOOKS := {
	"oak": {"leaf_a": Color("3a8534"), "leaf_b": Color("6cae3c"), "bark": Color("6a5a48"), "bark_b": Color("2f2a22")},
	"maple": {"leaf_a": Color("459536"), "leaf_b": Color("84c043"), "bark": Color("6e604f"), "bark_b": Color("342d25")},
	"birch": {"leaf_a": Color("6aae3e"), "leaf_b": Color("a2cc4e"), "bark": Color("ece6d6"), "bark_b": Color("2b2723")},
	"white_pine": {"leaf_a": Color("27664a"), "leaf_b": Color("3f8752"), "bark": Color("5e5043"), "bark_b": Color("2c251e")},
	"hemlock": {"leaf_a": Color("225c44"), "leaf_b": Color("35784c"), "bark": Color("62503f"), "bark_b": Color("30261d")},
	"shrub_hazel": {"leaf_a": Color("4c9638"), "leaf_b": Color("86bd48"), "bark": Color("5e4e3e"), "bark_b": Color("342a21")},
}

static var _on := -1


## Whether the distant trees are painted (the default; veg_far=real: not).
static func enabled() -> bool:
	if _on < 0:
		_on = 1
		for a in OS.get_cmdline_user_args():
			if a.trim_prefix("--") == "veg_far=real":
				_on = 0
	return _on == 1


## The look's greens and bark on a painted material.
static func apply_palette(m: ShaderMaterial, look_key: String) -> void:
	var look: Dictionary = LOOKS.get(look_key, LOOKS["oak"])
	m.set_shader_parameter("leaf_a", look.leaf_a)
	m.set_shader_parameter("leaf_b", look.leaf_b)
	m.set_shader_parameter("bark_a", look.bark)
	m.set_shader_parameter("bark_b", look.bark_b)
