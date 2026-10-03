class_name CreatorOptions
extends RefCounted
## The option rows of the character creator (CharacterCreator): for a people and body type,
## the list of choices of each row and how a choice changes a look (BodyMaterials.apply_look
## keys, plus the creator's own keys below). Pure data and look logic: no nodes, so tests
## and tools can cycle every row headless.
##
##   var opts := CreatorOptions.options("hair_color", look)     # [{id, label, ...}]
##   CreatorOptions.select("hair_color", look, 2)              # look changed in place
##   CreatorOptions.step("face", look, 1)                      # next face, wraps
##   var i := CreatorOptions.current("skin", look)             # index, -1 when custom
##   look = CreatorOptions.with_people(look, "lenape")         # the people's first individual
##   look = CreatorOptions.randomized(look, rng)               # the dice
##
## Rows (ROWS), in the creator's order: face_style, skin, bust (body type 2 only), face, complexion
## (Stylized only), hair_style, hair_color, facial_hair (body type 1 only), eyebrows, eyes, markings,
## then what is worn on the body itself, from the head down: the jewellery rows jewel_ears,
## jewel_nose, jewel_neck, jewel_hands (Earrings, Nose, Neck, Rings: one piece at each place, all
## worn together) and tattoos last (the camera: the face, the bust, the hands, the bust; FACE_ROWS,
## BUST_ROWS, HANDS_ROWS). The garments are the Clothing view's (OutfitTab, PlayerOutfit.SLOTS).
## Faces, skin, eyes and hair colours come from the people
## (assets/character/body/peoples.json, CharacterPeoples); face styles, complexions, facial hair,
## eyebrows, markings and jewellery from data/customizer/creator.json, per people where a
## documented custom differs. Jewellery is for everyone (the owner, 2026-10-03: "nose and jewellery
## and earrings unlock for everyone"): every row offers every piece of its place to every people
## and both body types; the people's documented pieces (its jewellery_m / jewellery_f list) come
## first, marked `own`, and are what the dice choose from. In the Stylized
## face style (the default) the Face row lists the people's stylized faces first
## (CharacterPeoples.stylized_presets: six per body type for the East and Southeast Asian peoples,
## four for the others), then its presets and generated individuals. In the Realistic style it
## lists the presets (two per body type; six for the Vietnamese, Thai and Malay peoples, their two
## realistic showcase faces first), then generated individuals.
##
## Creator look keys (all optional; AppearanceStore.validate keeps them):
##   name          the character's name (String, at most NAME_MAX characters)
##   face_style    "stylized" (default) or "realistic" (BodyMaterials.FACE_STYLES)
##   complexion    creator.json complexion id (the stylized paint's lines and contrast)
##   face_variant  which face of the people's list (FACE_VARIANTS per body type)
##   facial_hair   creator.json facial_hair id (with `stubble`)
##   eyebrows      creator.json eyebrows id (with `brows`)
##   markings      creator.json markings id (with `freckles` and `marks` {pox, scar, paint})
##   jewel_ears, jewel_nose, jewel_neck, jewel_hands
##                 creator.json jewellery ids, one piece per place (JEWEL_ROWS; "none")
##   jewellery     (looks saved before the jewellery rows) one creator.json jewellery id, a piece
##                 or a set of pieces ("parts"); it still dresses (jewel_id), and
##                 upgrade_jewellery (AppearanceStore.validate, any jewellery row's select) turns it
##                 into the rows. options / select / current("jewellery") still pick a whole set.
##   tattoos       the Tattoos row: a list of {design, place, x, y, scale, rotation, ink, fade}
##                 (Tattoos, data/customizer/tattoos.json; for everyone, kept across people, body
##                 type and the dice like the name)
## Body type 1 is the male fit (sex 1), body type 2 the female fit (sex 0).

const PATH := "res://data/customizer/creator.json"
const ROWS := ["face_style", "skin", "bust", "face", "complexion", "hair_style", "hair_color", "facial_hair", "eyebrows", "eyes",
		"markings", "jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "tattoos"]
const ROW_LABELS := {
	"face_style": "Face style", "skin": "Skin colour", "bust": "Bust", "face": "Face", "complexion": "Complexion", "hair_style": "Hair style", "hair_color": "Hair colour",
	"facial_hair": "Facial hair", "eyebrows": "Eyebrows", "eyes": "Eye colour", "markings": "Markings",
	"jewellery": "Jewellery", "jewel_ears": "Earrings", "jewel_nose": "Nose", "jewel_neck": "Neck", "jewel_hands": "Rings",
	"tattoos": "Tattoos",
}
## Rows the creator's camera frames at the face (the rest: the upper body).
const FACE_ROWS := ["face_style", "face", "complexion", "hair_style", "hair_color", "facial_hair", "eyebrows", "eyes",
		"markings", "jewellery", "jewel_ears", "jewel_nose"]
## Rows the camera frames at the bust (the neck's jewellery shows with the shoulders).
const BUST_ROWS := ["skin", "jewel_neck", "tattoos"]
## Rows the camera frames at the hands (the rings; CreatorStage's "hands" framing).
const HANDS_ROWS := ["jewel_hands"]
## The jewellery rows (look keys) and the place of each: one piece at each place.
const JEWEL_ROWS := {"jewel_ears": "ears", "jewel_nose": "nose", "jewel_neck": "neck", "jewel_hands": "hands"}
## Where an item's `at` (creator.json jewellery items, FaceExtras) is worn.
const JEWEL_AT := {"ears": "ears", "ear_l": "ears", "ear_r": "ears", "ear_rims": "ears", "septum": "nose",
		"nostril_l": "nose", "nostril_r": "nose", "neck": "neck", "ring_l": "hands", "ring_r": "hands",
		"middle_l": "hands", "middle_r": "hands", "index_l": "hands", "index_r": "hands", "pinky_l": "hands", "pinky_r": "hands"}
## The dice: how often each jewellery row stays plain (then one of the people's own pieces).
const JEWEL_PLAIN := {"jewel_ears": 0.5, "jewel_nose": 0.75, "jewel_neck": 0.6, "jewel_hands": 0.7}
## The look key of a look saved before the jewellery rows (one jewellery id).
const LEGACY_JEWELLERY := "jewellery"
## Faces per people and body type: (Stylized) its stylized faces, then its presets, then
## generated individuals.
const FACE_VARIANTS := 10
## The bust gauge (body type 2): look "bust" per step (BodyMaterials: breast_small below 0, breast_large
## above; the fine-tune slider reaches -1..1).
const BUST := [[-1.0, "Very small"], [-0.6, "Small"], [-0.3, "Smaller"], [0.0, "Average"], [0.25, "Fuller"],
		[0.5, "Full"], [0.75, "Very full"]]
## Skin swatches reach this far past the people's melanin range (wide ranges: peoples overlap).
const SKIN_WIDEN := 0.08
const SKIN_STEP := 0.035
const NAME_MAX := 24
## Colours added to every people's hair list (age).
const AGE_HAIR := ["grizzled", "grey", "white"]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = d if d is Dictionary else {}
	return _data


static func is_male(look: Dictionary) -> bool:
	return float(look.get("sex", 0.0)) >= 0.5


## Body type 1 (male fit) or 2 (female fit).
static func body_type(look: Dictionary) -> int:
	return 1 if is_male(look) else 2


static func rows(look: Dictionary) -> Array:
	var out := []
	for r: String in ROWS:
		if r == "facial_hair" and not is_male(look):
			continue
		if r == "bust" and is_male(look):
			continue
		if r == "complexion" and not BodyMaterials.is_stylized(look):
			continue
		if r == "face_style" and BodyMaterials.FACE_STYLES.size() < 2:
			continue
		out.append(r)
	return out


static func _people(look: Dictionary) -> Dictionary:
	var p := CharacterPeoples.people(String(look.get("people", "")))
	return p if not p.is_empty() else CharacterPeoples.people("english")


## A list of the people's (then its group's, then the default) creator.json key `key`.
static func _list(look: Dictionary, key: String) -> Array:
	var d := data()
	var p := _people(look)
	var per: Dictionary = (d.get("peoples", {}) as Dictionary).get(String(p.get("id", "")), {})
	if per.has(key):
		return per[key]
	var grp: Dictionary = (d.get("groups", {}) as Dictionary).get(String(p.get("group", "")), {})
	if grp.has(key):
		return grp[key]
	return (d.get("defaults", {}) as Dictionary).get(key, [])


static func _sorted_by_weight(dist: Dictionary) -> Array:
	var keys := dist.keys()
	keys.sort_custom(func(a, b) -> bool:
		return float(dist[a]) > float(dist[b]) or (is_equal_approx(float(dist[a]), float(dist[b])) and String(a) < String(b)))
	return keys


## Choices of `row` for the look's people and body type: [{id, label, ...}]. Colour rows carry
## `color` (an sRGB swatch); every choice may carry `note` (period note for a tooltip).
static func options(row: String, look: Dictionary) -> Array:
	match row:
		"face_style":
			var fs := _table_options("face_styles", BodyMaterials.FACE_STYLES)
			return fs
		"complexion":
			return _table_options("complexion", (data().get("complexion", {}) as Dictionary).keys()) \
					if BodyMaterials.is_stylized(look) else []
		"skin":
			return _skin_options(look)
		"bust":
			var out := []
			if not is_male(look):
				for b: Array in BUST:
					out.append({"id": "bust_%d" % out.size(), "label": String(b[1]), "bust": float(b[0])})
			return out
		"face":
			return _face_options(look)
		"hair_style":
			return _hair_style_options(look)
		"hair_color":
			return _hair_color_options(look)
		"facial_hair":
			return _table_options("facial_hair", _list(look, "facial_hair")) if is_male(look) else []
		"eyebrows":
			var out := []
			for e: Dictionary in data().get("eyebrows", []):
				var o := e.duplicate()
				out.append(o)
			return out
		"eyes":
			var eyes: Dictionary = BodyMaterials.body_info().get("eyes", {})
			var out := []
			for k: String in _sorted_by_weight(_people(look).get("eyes", {"brown": 1.0})):
				out.append({"id": k, "label": k.replace("_", " ").capitalize(), "color": Color(String(eyes.get(k, "#4a2e1a")))})
			return out
		"markings":
			return _table_options("markings", _list(look, "markings_m" if is_male(look) else "markings_f"))
		"jewellery":
			# every piece and set (a whole look's jewellery at once; not a creator row)
			return _table_options("jewellery", (data().get("jewellery", {}) as Dictionary).keys())
		"jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands":
			return _jewel_options(look, row)
		"tattoos":
			return Tattoos.row_options(look)
	return []


static func _table_options(table: String, ids: Array) -> Array:
	var t: Dictionary = data().get(table, {})
	var out := []
	for id in ids:
		if not t.has(id):
			continue
		var o: Dictionary = (t[id] as Dictionary).duplicate()
		o["id"] = String(id)
		out.append(o)
	if out.is_empty() and t.has("none"):
		out.append({"id": "none", "label": "None"})
	return out


static func _skin_options(look: Dictionary) -> Array:
	var p := _people(look)
	var mel: Array = p.get("skin", {}).get("melanin", [0.0, 1.0])
	var lo := clampf(float(mel[0]) - SKIN_WIDEN, 0.0, 1.0)
	var hi := clampf(float(mel[1]) + SKIN_WIDEN, 0.0, 1.0)
	var n := clampi(int(round((hi - lo) / SKIN_STEP)) + 1, 8, 14)
	var tones := _sorted_by_weight(p.get("skin", {}).get("undertone", {"neutral": 1.0}))
	var out := []
	for i in n:
		var m := snappedf(lerpf(lo, hi, float(i) / float(n - 1)), 0.001)
		for u: String in tones:
			out.append({"id": "%s_%d" % [u, i], "label": "Tone %d, %s" % [int(round(m * 11.0)) + 1, u],
					"melanin": m, "undertone": u, "color": BodyMaterials.tone_color(m, u)})
	return out


static func _face_options(look: Dictionary) -> Array:
	var p := _people(look)
	var pid := String(p.get("id", ""))
	var sex := 1.0 if is_male(look) else 0.0
	var out := []
	var prs: Array = CharacterPeoples.presets(pid, sex)
	if BodyMaterials.is_stylized(look):
		prs = CharacterPeoples.stylized_presets(pid, sex) + prs
	for pr: Dictionary in prs:
		if out.size() >= FACE_VARIANTS:
			break
		var o := {"id": String(pr.id), "label": "Face %d" % (out.size() + 1), "face": (pr.face as Dictionary).duplicate(),
				"preset": String(pr.id)}
		if pr.get("showcase", false):
			o["note"] = "Showcase face: tuned one by one for the %s look." % ("stylized" if pr.has("face_style") else "realistic")
		out.append(o)
	var rng := RandomNumberGenerator.new()
	var k := 0
	while out.size() < FACE_VARIANTS:
		rng.seed = hash("%s:%d:%d" % [pid, int(sex), k])
		var lk := CharacterPeoples.random_look(pid, sex, rng)
		out.append({"id": "%s_%d_%d" % [pid, int(sex), k], "label": "Face %d" % (out.size() + 1),
				"face": lk.get("face", {})})
		k += 1
	return out


static func hair_style_tags(style: String) -> Array:
	return BodyMaterials.hair_info(style).get("tags", [])


static func all_hair_styles() -> Array:
	var out := []
	for f in DirAccess.get_files_at(BodyMaterials.HAIR_DIR):
		if f.ends_with(".glb"):
			out.append(f.get_basename())
	out.sort()
	return out


## The people's period styles for the body type first, then every other style made for it.
static func _hair_style_options(look: Dictionary) -> Array:
	var p := _people(look)
	var sx := "m" if is_male(look) else "f"
	var tag := "men" if is_male(look) else "women"
	var ids: Array = ((p.get("hair_styles", {}) as Dictionary).get(sx, []) as Array).duplicate()
	var own := ids.size()
	for s: String in all_hair_styles():
		if not s in ids and tag in hair_style_tags(s):
			ids.append(s)
	var out := []
	for i in ids.size():
		var s := String(ids[i])
		if not ResourceLoader.exists(BodyMaterials.HAIR_DIR + s + ".glb"):
			continue
		var info := BodyMaterials.hair_info(s)
		var o := {"id": s, "label": String(info.get("name", s)), "note": String(info.get("history", info.get("description", ""))),
				"own": i < own}
		if info.get("licence_note") != null:
			o.note = String(o.note) + " Artistic licence: " + String(info.licence_note)
		out.append(o)
	return out


static func _hair_color_options(look: Dictionary) -> Array:
	var ids := _sorted_by_weight(_people(look).get("hair_colors", {"dark_brown": 1.0}))
	for a: String in AGE_HAIR:
		if not a in ids:
			ids.append(a)
	var out := []
	for id: String in ids:
		var pr := BodyMaterials.hair_preset(id)
		out.append({"id": id, "label": String(pr.get("label", id.capitalize())),
				"color": BodyMaterials.hair_color(float(pr.eumelanin), float(pr.pheomelanin), float(pr.grey))})
	return out


static func _hair(look: Dictionary) -> Dictionary:
	if not look.get("hair") is Dictionary:
		look["hair"] = {}
	return look.hair


## Index of the look's current choice in options(row), or -1 when the look holds a value the
## list does not offer (fine-tuned or from another people).
static func current(row: String, look: Dictionary, opts := []) -> int:
	if opts.is_empty():
		opts = options(row, look)
	match row:
		"face_style":
			return _index_of(opts, BodyMaterials.face_style(look))
		"complexion":
			return _index_of(opts, String(look.get("complexion", "smooth")))
		"skin":
			var best := -1
			var bd := 0.02
			var m := float(look.get("melanin", 0.3))
			var u := String(look.get("undertone", "neutral")) if look.get("undertone") is String else ""
			for i in opts.size():
				var d := absf(float(opts[i].melanin) - m) + (0.0 if opts[i].undertone == u else 1.0)
				if d < bd:
					bd = d
					best = i
			return best
		"bust":
			var bu := float(look.get("bust", 0.0))
			for i in opts.size():
				if absf(float(opts[i].bust) - bu) < 0.01:
					return i
			return -1
		"face":
			var v := int(look.get("face_variant", -1))
			if v >= 0 and v < opts.size() and _same_face(look.get("face"), opts[v].face):
				return v
			for i in opts.size():
				if opts[i].has("preset") and String(look.get("preset", "")) == String(opts[i].preset) and _same_face(look.get("face"), opts[i].face):
					return i
			for i in opts.size():
				if _same_face(look.get("face"), opts[i].face):
					return i
			return -1
		"hair_style":
			return _index_of(opts, String(_hair(look).get("style", "")))
		"hair_color":
			return _index_of(opts, String(_hair(look).get("color", ""))) if not _hair(look).has("eumelanin") else -1
		"facial_hair":
			var id := String(look.get("facial_hair", ""))
			if id.is_empty():
				id = _stubble_id(float(look.get("stubble", 0.0)), opts)
			return _index_of(opts, id)
		"eyebrows":
			var i := _index_of(opts, String(look.get("eyebrows", "")))
			if i >= 0:
				return i
			var b: Dictionary = look.get("brows", {}) if look.get("brows") is Dictionary else {}
			for j in opts.size():
				if absf(float(opts[j].thickness) - float(b.get("thickness", -9.0))) < 0.01 \
						and absf(float(opts[j].arch) - float(b.get("arch", -9.0))) < 0.01:
					return j
			return -1
		"eyes":
			return _index_of(opts, String(look.get("iris", ""))) if look.get("iris") is String else -1
		"markings":
			var id := String(look.get("markings", ""))
			if id.is_empty():
				var f := float(look.get("freckles", 0.0))
				id = "none" if f < 0.05 else ("freckles_light" if f < 0.55 else "freckles")
			return _index_of(opts, id)
		"jewellery":
			return _index_of(opts, _jewel_set_id(look))
		"jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands":
			return _index_of(opts, jewel_id(look, row))
		"tattoos":
			return Tattoos.row_current(look, opts)
	return -1


static func _index_of(opts: Array, id: String) -> int:
	for i in opts.size():
		if String(opts[i].get("id", "")) == id:
			return i
	return -1


static func _stubble_id(s: float, opts: Array) -> String:
	var best := ""
	var bd := 9.0
	for o: Dictionary in opts:
		if o.has("regions"):
			continue
		var d := absf(float(o.get("stubble", 0.0)) - s)
		if d < bd:
			bd = d
			best = String(o.id)
	return best


static func _same_face(a, b) -> bool:
	if not a is Dictionary or not b is Dictionary:
		return false
	for k in (a as Dictionary).keys() + (b as Dictionary).keys():
		if absf(float((a as Dictionary).get(k, 0.0)) - float((b as Dictionary).get(k, 0.0))) > 0.002:
			return false
	return true


## Applies choice `i` of `row` to `look` (in place). Returns false when the row has no such
## choice.
static func select(row: String, look: Dictionary, i: int, opts := []) -> bool:
	if opts.is_empty():
		opts = options(row, look)
	if i < 0 or i >= opts.size():
		return false
	var o: Dictionary = opts[i]
	match row:
		"face_style":
			look["face_style"] = String(o.id)
		"complexion":
			look["complexion"] = String(o.id)
		"skin":
			look["melanin"] = float(o.melanin)
			look["undertone"] = String(o.undertone)
		"bust":
			look["bust"] = float(o.bust)
		"face":
			look["face"] = (o.face as Dictionary).duplicate()
			look["face_variant"] = i
			if o.has("preset"):
				look["preset"] = String(o.preset)
			else:
				look.erase("preset")
		"hair_style":
			_hair(look)["style"] = String(o.id)
		"hair_color":
			var h := _hair(look)
			for k in ["eumelanin", "pheomelanin", "grey"]:
				h.erase(k)
			h["color"] = String(o.id)
		"facial_hair":
			look["facial_hair"] = String(o.id)
			look["stubble"] = float(o.get("stubble", 0.0))
		"eyebrows":
			look["eyebrows"] = String(o.id)
			look["brows"] = {"thickness": float(o.thickness), "arch": float(o.arch), "density": float(o.density)}
		"eyes":
			look["iris"] = String(o.id)
		"markings":
			look["markings"] = String(o.id)
			look["freckles"] = float(o.get("freckles", 0.0))
			look["marks"] = {"pox": float(o.get("pox", 0.0)), "scar": int(o.get("scar", 0)), "paint": float(o.get("paint", 0.0))}
		"jewellery":
			upgrade_jewellery(look)
			var parts := jewel_parts(String(o.id))
			for r: String in JEWEL_ROWS:
				look[r] = String(parts.get(JEWEL_ROWS[r], "none"))
		"jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands":
			upgrade_jewellery(look)
			look[row] = String(o.id)
		"tattoos":
			return Tattoos.row_select(look, i, opts)
		_:
			return false
	return true


## Moves `row` by `d` choices (wrapping) and returns the new index. From a custom value
## (current -1) the first step goes to the first (d > 0) or last (d < 0) choice.
static func step(row: String, look: Dictionary, d: int) -> int:
	var opts := options(row, look)
	if opts.is_empty():
		return -1
	var i := current(row, look, opts)
	if i < 0:
		i = 0 if d > 0 else opts.size() - 1
	else:
		i = posmod(i + d, opts.size())
	select(row, look, i, opts)
	return i


## Keys that survive a change of people or body type (the rest come from the new individual).
const KEEP := ["name", "outfit", "weathering", "face_style", "complexion", "tattoos"]


static func _keep(from: Dictionary, to: Dictionary) -> Dictionary:
	for k: String in KEEP:
		if from.has(k):
			# (deep copies: the outfit's dictionary, the tattoos' list)
			to[k] = from[k].duplicate(true) if from[k] is Dictionary or from[k] is Array else from[k]
	return to


## The first individual (face 1) of `people_id` for the look's body type, keeping the name,
## clothes and face style; every row then holds a choice of the new people's lists.
static func with_people(look: Dictionary, people_id: String) -> Dictionary:
	var sex := 1.0 if is_male(look) else 0.0
	var pr: Array = CharacterPeoples.presets(people_id, sex)
	if BodyMaterials.is_stylized(look):
		pr = CharacterPeoples.stylized_presets(people_id, sex) + pr
	var out := CharacterPeoples.preset_look(String(pr[0].id)) if not pr.is_empty() else {"people": people_id, "sex": sex}
	out = _keep(look, out)
	_settle(out)
	return out


## The same people with body type 1 (male fit) or 2 (female fit).
static func with_body_type(look: Dictionary, bt: int) -> Dictionary:
	var lk := look.duplicate(true)
	lk["sex"] = 1.0 if bt == 1 else 0.0
	return with_people(lk, String(_people(look).get("id", "english")))


## Every row on a choice of its list (the nearest, or the first): a preset's continuous values
## snap to the swatches the creator shows.
static func _settle(look: Dictionary) -> void:
	for r: String in rows(look):
		var opts := options(r, look)
		if opts.is_empty():
			continue
		var i := current(r, look, opts)
		if i < 0 and r == "bust":
			var bu := float(look.get("bust", 0.0))
			i = 0
			for j in opts.size():
				if absf(float(opts[j].bust) - bu) < absf(float(opts[i].bust) - bu):
					i = j
		if i < 0:
			i = _nearest_skin(look, opts) if r == "skin" else (_nearest_brows(look, opts) if r == "eyebrows" else 0)
		select(r, look, i, opts)
	if not is_male(look):
		look["facial_hair"] = ""
		look["stubble"] = 0.0


static func _nearest_skin(look: Dictionary, opts: Array) -> int:
	var m := float(look.get("melanin", 0.3))
	var u := String(look.get("undertone", "neutral")) if look.get("undertone") is String else "neutral"
	var best := 0
	var bd := 99.0
	for i in opts.size():
		var d := absf(float(opts[i].melanin) - m) + (0.0 if opts[i].undertone == u else 0.5)
		if d < bd:
			bd = d
			best = i
	return best


static func _nearest_brows(look: Dictionary, opts: Array) -> int:
	var b: Dictionary = look.get("brows", {}) if look.get("brows") is Dictionary else {}
	var best := 0
	var bd := 99.0
	for i in opts.size():
		var d := absf(float(opts[i].thickness) - float(b.get("thickness", 0.7))) + absf(float(opts[i].arch) - float(b.get("arch", 0.5)))
		if d < bd:
			bd = d
			best = i
	return best


## Weighted pick of a style row: the first choice (clean-shaven, none) more often.
static func _pick_style(opts: Array, rng: RandomNumberGenerator, first_weight: float) -> int:
	if opts.size() <= 1 or rng.randf() < first_weight:
		return 0
	return 1 + rng.randi() % (opts.size() - 1)


## The dice: a new individual of the same people and body type (face, skin, eyes and hair
## colour from the people's ranges and frequencies, the people's own hair styles, style rows
## weighted toward the plain choice). Name and clothes are kept.
static func randomized(look: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pid := String(_people(look).get("id", "english"))
	var sex := 1.0 if is_male(look) else 0.0
	var lk := CharacterPeoples.random_look(pid, sex, rng)
	lk = _keep(look, lk)
	var faces := options("face", lk)
	select("face", lk, rng.randi() % faces.size(), faces)
	var skins := options("skin", lk)
	select("skin", lk, _nearest_skin(lk, skins), skins)
	var styles := options("hair_style", lk)
	var own := styles.filter(func(o: Dictionary) -> bool: return bool(o.get("own", false)))
	if not own.is_empty():
		_hair(lk)["style"] = String(own[rng.randi() % own.size()].id)
	var brows := options("eyebrows", lk)
	select("eyebrows", lk, rng.randi() % brows.size(), brows)
	if is_male(lk):
		var fh := options("facial_hair", lk)
		select("facial_hair", lk, _pick_style(fh, rng, 0.35), fh)
	else:
		lk["facial_hair"] = ""
		lk["stubble"] = 0.0
	var mk := options("markings", lk)
	select("markings", lk, _pick_style(mk, rng, 0.6), mk)
	for r: String in JEWEL_ROWS:
		var jw := options(r, lk)
		select(r, lk, _pick_own(jw, rng, float(JEWEL_PLAIN[r])), jw)
	_settle(lk)
	lk["face_variant"] = current("face", lk, faces)
	return lk


## The option's display name for `row` at index `i` ("Custom" for -1).
static func label(row: String, look: Dictionary, i: int, opts := []) -> String:
	if opts.is_empty():
		opts = options(row, look)
	if i < 0 or i >= opts.size():
		return "Custom"
	return String(opts[i].get("label", opts[i].get("id", "")))


## The jewellery items of the look (creator.json "jewellery" entries: every row's piece, or a saved
## look's single jewellery id), for FaceExtras.
static func jewellery_items(look: Dictionary) -> Array:
	var t: Dictionary = data().get("jewellery", {})
	var out := []
	for r: String in JEWEL_ROWS:
		out.append_array((t.get(jewel_id(look, r), {}) as Dictionary).get("items", []))
	return out


## The place of a jewellery piece (JEWEL_ROWS values: ears, nose, neck, hands), "" for none and for a
## set of pieces at several places (its "parts").
static func jewel_place(id: String) -> String:
	var e: Dictionary = (data().get("jewellery", {}) as Dictionary).get(id, {})
	if e.has("parts"):
		return ""
	var place := ""
	for it: Dictionary in e.get("items", []):
		var p := String(JEWEL_AT.get(String(it.get("at", "ears")), ""))
		if p.is_empty() or (not place.is_empty() and p != place):
			return ""
		place = p
	return place


## The pieces of a jewellery id by place: a set's "parts", a piece at its own place, {} for none.
static func jewel_parts(id: String) -> Dictionary:
	var e: Dictionary = (data().get("jewellery", {}) as Dictionary).get(id, {})
	if e.get("parts") is Dictionary:
		return (e.parts as Dictionary).duplicate()
	var p := jewel_place(id)
	return {} if p.is_empty() else {p: id}


## The piece the look wears in jewellery row `row` (a saved look's single jewellery id counts).
static func jewel_id(look: Dictionary, row: String) -> String:
	if look.get(LEGACY_JEWELLERY) is String:
		return String(jewel_parts(String(look[LEGACY_JEWELLERY])).get(JEWEL_ROWS.get(row, ""), "none"))
	var id = look.get(row, "none")
	return String(id) if id is String and not String(id).is_empty() else "none"


## A look saved before the jewellery rows: its single jewellery id becomes the rows (in place).
static func upgrade_jewellery(look: Dictionary) -> void:
	if not look.has(LEGACY_JEWELLERY):
		return
	var old = look[LEGACY_JEWELLERY]
	var parts := jewel_parts(String(old)) if old is String else {}
	for r: String in JEWEL_ROWS:
		look[r] = String(parts.get(JEWEL_ROWS[r], "none"))
	look.erase(LEGACY_JEWELLERY)


## The hand the look's Rings piece is worn on, "l" or "r" (its first ring's; the left with none): the creator turns that
## hand to the camera on the Rings row.
static func ring_hand(look: Dictionary) -> String:
	var e: Dictionary = (data().get("jewellery", {}) as Dictionary).get(jewel_id(look, "jewel_hands"), {})
	for it: Dictionary in e.get("items", []):
		var at := String(it.get("at", ""))
		if at.ends_with("_r"):
			return "r"
		if at.ends_with("_l"):
			return "l"
	return "l"


## The people's documented pieces at `place` (its jewellery_m / jewellery_f list; a set gives its part there).
static func jewel_own(look: Dictionary, place: String) -> Array:
	var out := []
	for id in _list(look, "jewellery_m" if is_male(look) else "jewellery_f"):
		var p := String(jewel_parts(String(id)).get(place, ""))
		if not p.is_empty() and not p in out:
			out.append(p)
	return out


## Every piece of the row's place, for every people and body type: none, the people's own pieces, then
## the rest in creator.json's order.
static func _jewel_options(look: Dictionary, row: String) -> Array:
	var place := String(JEWEL_ROWS.get(row, ""))
	var t: Dictionary = data().get("jewellery", {})
	var own := jewel_own(look, place)
	var ids := ["none"] + own
	for id: String in t:
		if not id in ids and jewel_place(id) == place:
			ids.append(id)
	var out := []
	for id: String in ids:
		if not t.has(id):
			continue
		var o: Dictionary = (t[id] as Dictionary).duplicate()
		o["id"] = id
		o["own"] = id in own
		out.append(o)
	return out


## The jewellery id (a piece or a set) that is what the look wears altogether: "none", the one piece,
## or the set whose parts are its pieces; "" when no id matches.
static func _jewel_set_id(look: Dictionary) -> String:
	var worn := {}
	for r: String in JEWEL_ROWS:
		var id := jewel_id(look, r)
		if id != "none":
			worn[JEWEL_ROWS[r]] = id
	if worn.is_empty():
		return "none"
	for id: String in data().get("jewellery", {}):
		if jewel_parts(id) == worn:
			return id
	return ""


## The dice for a jewellery row: plain (`plain_weight` of the time, or when the people has no piece of
## its own), else one of the people's own pieces.
static func _pick_own(opts: Array, rng: RandomNumberGenerator, plain_weight: float) -> int:
	var own := []
	for i in opts.size():
		if bool((opts[i] as Dictionary).get("own", false)):
			own.append(i)
	if own.is_empty() or rng.randf() < plain_weight:
		return 0
	return int(own[rng.randi() % own.size()])


## The facial hair style of the look: {regions [moustache, chin, jaw, sideburns], length (m),
## density}; empty regions for clean, plucked and stubble.
static func facial_hair_style(look: Dictionary) -> Dictionary:
	if not is_male(look):
		return {}
	var t: Dictionary = data().get("facial_hair", {})
	return t.get(String(look.get("facial_hair", "")), {})


static func clean_name(s: String) -> String:
	var out := ""
	for c in s.strip_edges():
		if c.unicode_at(0) >= 32 and c != "\u007f":
			out += c
	return out.substr(0, NAME_MAX)
