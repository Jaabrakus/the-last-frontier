extends RefCounted
## Materials and coat variants of the procedural horse (assets/horse/horse.glb).
##
##   const HorseLook := preload("res://scripts/horse/horse_look.gd")
##   HorseLook.apply(visual, "bay")      # materials by glTF material name + a coat
##   HorseLook.set_coat(visual, "grey")  # another coat on the same instance
##
## The glTF carries geometry, UVs and named placeholder materials; the real materials are
## in assets/horse/materials (coat, hair and hoof shaders; Poly Haven CC0 leather, wool
## and hessian on the tack). A coat is a set of per-instance shader parameters, so every
## horse can have its own coat without duplicating materials.
##
## Coats of the period types (Canadian, Chickasaw and Narragansett horses): bay (default),
## brown (seal brown with tan soft points), black, chestnut (with lighter mane and tail),
## grey (dapple grey with dark legs) and dun (dorsal stripe, black points).

const MAT_DIR := "res://assets/horse/materials/"
const MATERIALS := {
	"horse_coat": "horse_coat.tres", "horse_hair": "horse_hair.tres", "horse_hoof": "horse_hoof.tres",
	"horse_eye": "horse_eye.tres", "tack_leather": "tack_leather.tres", "tack_bridle": "tack_bridle.tres",
	"tack_cloth": "tack_cloth.tres", "tack_girth": "tack_girth.tres", "tack_iron": "tack_iron.tres",
}
const HAIR_MESHES := ["Mane", "Forelock", "Tail", "Feathers"]

## sRGB colours. coat_*: body, topline, belly, points (legs, ear rims), mealy / soft areas,
## bare skin (muzzle, eyes), dapples. hair_*: mane and tail at the root and the tips.
const COATS := {
	"bay": {
		"coat_body": Color("62392a"), "coat_top": Color("45281c"), "coat_belly": Color("7a5038"),
		"coat_points": Color("17110e"), "coat_mealy": Color("8a6044"), "coat_skin": Color("221a17"),
		"coat_dapple": Color("704432"), "dapple_amount": 0.12, "points_amount": 1.0, "mealy_amount": 0.3,
		"stripe_amount": 0.0, "white_amount": 1.0, "coat_gloss": -0.03,
		"hair_color": Color("120d0b"), "hair_tip": Color("2c1b12"), "hair_var": 0.35,
		"hoof_dark": Color("2a2420"), "hoof_light": Color("b3a07f"),
	},
	"brown": {
		"coat_body": Color("3b2418"), "coat_top": Color("24160f"), "coat_belly": Color("5e3b24"),
		"coat_points": Color("110c0a"), "coat_mealy": Color("8a5a36"), "coat_skin": Color("1e1714"),
		"coat_dapple": Color("46301f"), "dapple_amount": 0.1, "points_amount": 1.0, "mealy_amount": 0.85,
		"stripe_amount": 0.0, "white_amount": 1.0, "coat_gloss": -0.04,
		"hair_color": Color("0e0a09"), "hair_tip": Color("21150e"), "hair_var": 0.3,
		"hoof_dark": Color("25201c"), "hoof_light": Color("b3a07f"),
	},
	"black": {
		"coat_body": Color("1f1a17"), "coat_top": Color("161211"), "coat_belly": Color("2a231f"),
		"coat_points": Color("121010"), "coat_mealy": Color("352b25"), "coat_skin": Color("1a1614"),
		"coat_dapple": Color("262120"), "dapple_amount": 0.15, "points_amount": 1.0, "mealy_amount": 0.4,
		"stripe_amount": 0.0, "white_amount": 0.0, "coat_gloss": -0.07,
		"hair_color": Color("0b0908"), "hair_tip": Color("1b1512"), "hair_var": 0.3,
		"hoof_dark": Color("221e1b"), "hoof_light": Color("221e1b"),
	},
	"chestnut": {
		"coat_body": Color("74432a"), "coat_top": Color("613722"), "coat_belly": Color("8c5a3c"),
		"coat_points": Color("633620"), "coat_mealy": Color("a27250"), "coat_skin": Color("2c211d"),
		"coat_dapple": Color("8d5636"), "dapple_amount": 0.2, "points_amount": 0.45, "mealy_amount": 0.3,
		"stripe_amount": 0.0, "white_amount": 1.0, "coat_gloss": -0.03,
		"hair_color": Color("7a3d1c"), "hair_tip": Color("b27a45"), "hair_var": 0.4,
		"hoof_dark": Color("3a312a"), "hoof_light": Color("b3a07f"),
	},
	"grey": {
		"coat_body": Color("5e5b58"), "coat_top": Color("514e4c"), "coat_belly": Color("85817b"),
		"coat_points": Color("3d3936"), "coat_mealy": Color("938f89"), "coat_skin": Color("2d2826"),
		"coat_dapple": Color("9d9993"), "dapple_amount": 0.75, "points_amount": 0.85, "mealy_amount": 0.2,
		"stripe_amount": 0.0, "white_amount": 1.0, "coat_gloss": -0.02,
		"hair_color": Color("6e6963"), "hair_tip": Color("d2cdc4"), "hair_var": 0.5,
		"hoof_dark": Color("3a3633"), "hoof_light": Color("b3a07f"),
	},
	# the plains bison on the horse's rig (assets/bison: its cape in the dapple channel, its head and legs in the points)
	"bison": {
		"coat_body": Color("2b1c13"), "coat_top": Color("261911"), "coat_belly": Color("33231a"),
		"coat_points": Color("120d0a"), "coat_mealy": Color("3e2c20"), "coat_skin": Color("0f0c0a"),
		"coat_dapple": Color("4e3420"), "dapple_amount": 0.9, "points_amount": 0.95, "mealy_amount": 0.1,
		"stripe_amount": 0.0, "white_amount": 0.0, "coat_gloss": -0.08,
		"hair_color": Color("15100d"), "hair_tip": Color("3a2818"), "hair_var": 0.3,
		"hoof_dark": Color("1c1916"), "hoof_light": Color("1c1916"),
	},
	"dun": {
		"coat_body": Color("866840"), "coat_top": Color("6c5231"), "coat_belly": Color("9e8157"),
		"coat_points": Color("1e1612"), "coat_mealy": Color("a58b63"), "coat_skin": Color("241c18"),
		"coat_dapple": Color("8f7349"), "dapple_amount": 0.15, "points_amount": 1.0, "mealy_amount": 0.35,
		"stripe_amount": 1.0, "white_amount": 0.0, "coat_gloss": -0.02,
		"hair_color": Color("1b1410"), "hair_tip": Color("4d3b2b"), "hair_var": 0.35,
		"hoof_dark": Color("2a2420"), "hoof_light": Color("2a2420"),
	},
}
const COAT_KEYS := ["coat_body", "coat_top", "coat_belly", "coat_points", "coat_mealy", "coat_skin", "coat_dapple",
		"dapple_amount", "points_amount", "mealy_amount", "stripe_amount", "white_amount", "coat_gloss"]
const HAIR_KEYS := ["hair_color", "hair_tip", "hair_var"]
const HOOF_KEYS := ["hoof_dark", "hoof_light", "white_amount"]

static var _cache := {}


static func coats() -> Array:
	return COATS.keys()


## Replaces the glTF placeholder materials with the horse's materials and applies a coat. `paths`: another animal's
## own materials by key (the bison's coat textures: {"horse_coat": "res://assets/bison/materials/bison_coat.tres"}).
static func apply(visual: Node3D, coat: String = "bay", paths := {}) -> void:
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var key := m.resource_name if m else ""
			if paths.has(key):
				mi.set_surface_override_material(s, _load(String(paths[key])))
			elif MATERIALS.has(key):
				mi.set_surface_override_material(s, material(key))
	set_coat(visual, coat)


static func material(key: String) -> Material:
	return _load(MAT_DIR + MATERIALS[key])


static func _load(path: String) -> Material:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Sets the per-instance coat parameters (unknown names fall back to bay).
static func set_coat(visual: Node3D, coat: String) -> void:
	var c: Dictionary = COATS.get(coat, COATS["bay"])
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		var keys: Array = []
		if n == "HorseBody":
			keys = COAT_KEYS
		elif n in HAIR_MESHES:
			keys = HAIR_KEYS
		elif n == "Hooves" or n == "Horns":
			keys = HOOF_KEYS
		for k: String in keys:
			mi.set_instance_shader_parameter(k, c[k])
