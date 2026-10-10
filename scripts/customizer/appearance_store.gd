class_name AppearanceStore
extends RefCounted
## The player's look on disk (design 11.2): user://appearance/current.json, plain JSON
## (data only; a save never fails to load: unknown or broken values fall back to the
## default look, key by key).
##
##   var look := AppearanceStore.load_current()
##   AppearanceStore.save_current(look)
##
## The look also holds `element` (earth, water, fire, air; "" until the character's element is chosen: element(), set_element()).
##
## Command line (tests, tools): --appearance=default | preset:<peoples preset id> | <path>.

const FORMAT := "frontier-appearance"
const VERSION := 2
const DIR := "user://appearance/"
const CURRENT := DIR + "current.json"
## The default player: an English colonist of the backcountry with the legacy queue (the first
## stylized English face: the Stylized face style is the default).
const DEFAULT_PRESET := "english_m_a"   # realistic only since the v3 head (2026-09-27)


static func default_look() -> Dictionary:
	var look := CharacterPeoples.preset_look(DEFAULT_PRESET)
	if look.is_empty():
		look = {"sex": 1.0, "face": {}, "melanin": 0.12, "undertone": "neutral", "haemoglobin": 0.6, "iris": "brown"}
	look["hair"] = {"style": "hair_queue_ribbon", "color": "dark_brown"}
	look["weathering"] = 0.35
	# the brows on the creator's nearest Eyebrows choice (the preset's own are none of them: the row read "Custom")
	var brows := CreatorOptions.options("eyebrows", look)
	if not brows.is_empty():
		CreatorOptions.select("eyebrows", look, CreatorOptions.nearest_brows(look, brows), brows)
	return look


## Missing keys filled from the default, numbers clamped, unknown hair styles replaced.
static func validate(look: Dictionary) -> Dictionary:
	var out := default_look()
	for k in look:
		out[k] = look[k]
	# (brows of the look's own without an Eyebrows id: not the default's id, which names other brows)
	if look.has("brows") and not look.has("eyebrows"):
		out.erase("eyebrows")
	# (the creator's own face, kept only while it is open: CreatorOptions.OWN_FACE)
	out.erase(CreatorOptions.OWN_FACE)
	for k in ["sex", "melanin", "haemoglobin", "freckles", "weathering", "stubble"]:
		out[k] = clampf(float(out.get(k, 0.0)), 0.0, 1.0)
	for k in ["bust", "genital"]:
		if out.has(k):
			out[k] = clampf(float(out[k]), -1.0, 1.0)
	if out.has("body_hair"):
		out["body_hair"] = clampf(float(out.body_hair), 0.0, 1.0)
	if not out.get("face") is Dictionary and not out.get("face") is String:
		out["face"] = {}
	var h: Dictionary = out.get("hair", {}) if out.get("hair") is Dictionary else {}
	var style := String(h.get("style", "hair_queue_ribbon"))
	if not style.is_empty() and not ResourceLoader.exists(BodyMaterials.HAIR_DIR + style + ".glb"):
		push_warning("AppearanceStore: hair style %s not found, using the queue." % style)
		h["style"] = "hair_queue_ribbon"
	out["hair"] = h
	# garments over the legacy outfit (PlayerOutfit): unknown slots and ids dropped
	out["outfit"] = PlayerOutfit.validate(out.get("outfit", {}))
	# character creator keys (CreatorOptions): a name, and the ids of its rows
	out["name"] = CreatorOptions.clean_name(String(out.get("name", ""))) if out.get("name") is String else ""
	# the face style (a look saved before it existed is Stylized, the default) and the complexion
	out["face_style"] = BodyMaterials.face_style(out)
	if not (CreatorOptions.data().get("complexion", {}) as Dictionary).has(String(out.get("complexion", ""))):
		out["complexion"] = "smooth"
	for k in ["facial_hair", "eyebrows", "markings", "jewellery"] + CreatorOptions.JEWEL_ROWS.keys():
		if out.has(k) and not out[k] is String:
			out.erase(k)
	if out.has("jewellery") and not (CreatorOptions.data().get("jewellery", {}) as Dictionary).has(out.jewellery):
		out["jewellery"] = "none"
	# jewellery: a look saved before the rows (one id) wears the same pieces in the rows; a row holds a piece of its place
	CreatorOptions.upgrade_jewellery(out)
	for r: String in CreatorOptions.JEWEL_ROWS:
		if out.has(r) and out[r] != "none" and CreatorOptions.jewel_place(out[r]) != CreatorOptions.JEWEL_ROWS[r]:
			out[r] = "none"
	if out.has("facial_hair") and not String(out.facial_hair).is_empty() \
			and not (CreatorOptions.data().get("facial_hair", {}) as Dictionary).has(out.facial_hair):
		out.erase("facial_hair")
	var mk: Dictionary = out.get("marks", {}) if out.get("marks") is Dictionary else {}
	out["marks"] = {"pox": clampf(float(mk.get("pox", 0.0)), 0.0, 1.0), "scar": clampi(int(mk.get("scar", 0)), 0, 3),
			"paint": clampf(float(mk.get("paint", 0.0)), 0.0, 1.0)}
	# tattoos (the creator's Tattoos row): known designs at places they may go, numbers clamped (Tattoos.validate)
	out["tattoos"] = Tattoos.validate(out.get("tattoos", []))
	# the element the character fights with ("" until chosen: a look saved before the field existed reads as that)
	out["element"] = clean_element(out.get("element", ""))
	return out


## The element the character fights with (Tidebreak). Chosen once, in the step after the character is made (the main menu's "Choose
## your element"), kept in the look as `element`, and the default of every setup: the lobby's fighter, the match setup, Quick match,
## the advancement window. A match may play another (the setup's choice is that match's only; MatchSetup). "" until chosen.
static func clean_element(v: Variant) -> String:
	var s := String(v) if v is String else ""
	return s if s in Bending.ELEMENTS else ""


## The saved character's element ("" until chosen): read from the look's file alone (the setup reads it every time the menu is
## built, so no look is built or validated here). `--appearance` on the command line (tools) answers for the look it names.
static func element() -> String:
	var c := from_cmdline()
	if not c.is_empty():
		return clean_element(c.get("element", ""))
	return file_element(current_path())


## The element in the look file at `path` ("" when there is no file, it is not an appearance file or it names none).
static func file_element(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return ""                                # (a broken file: none, and no error in the log)
	var d: Variant = json.data
	if not d is Dictionary or (d as Dictionary).get("format", "") != FORMAT or not (d as Dictionary).get("look") is Dictionary:
		return ""
	return clean_element(((d as Dictionary).look as Dictionary).get("element", ""))


## Keeps `el` as the character's element: the saved look written again with it (the default look when none is saved yet).
## False for a name that is not an element or a write that failed.
static func set_element(el: String) -> bool:
	var e := clean_element(el)
	if e == "":
		return false
	var look := load_file(current_path())
	look["element"] = e
	return save_current(look)


static func from_cmdline() -> Dictionary:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--appearance="):
			var v := a.substr(13)
			if v == "default":
				return default_look()
			if v.begins_with("preset:"):
				var lk := CharacterPeoples.preset_look(v.substr(7))
				return validate(lk) if not lk.is_empty() else default_look()
			return load_file(v)
	return {}


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return default_look()
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary or d.get("format", "") != FORMAT:
		push_warning("AppearanceStore: %s is not an appearance file; using the default look." % path)
		return default_look()
	return validate(d.get("look", {}))


## The look to start with: --appearance on the command line, else the saved look, else the
## default.
static func load_current() -> Dictionary:
	var c := from_cmdline()
	if not c.is_empty():
		return c
	return load_file(current_path())


static func save_current(look: Dictionary) -> bool:
	return save_file(current_path(), look)


## Where the player's own look is kept: CURRENT, except in tool and test runs (-s), which keep theirs apart (TEST_CURRENT) so a
## test never writes over the player's character (2026-10-03: a headless test saved an empty look over it and every character
## the game made from it came out as the default body: the user, "all chars turned into women").
const TEST_CURRENT := "user://appearance_test/current.json"


static func current_path() -> String:
	var args := OS.get_cmdline_args()
	return TEST_CURRENT if ("-s" in args or "--script" in args) else CURRENT


## The first-run offer of the creator made once, however it closed (PlayerAppearance.offer_creator): a flag file beside the
## look (a tool or test run's beside its own look, current_path), not a save of the look: Back on the offer keeps no look
## (the default stays the default) and the offer does not come back at the next launch.
const OFFERED_FILE := "creator_offered"


static func offered_path() -> String:
	return current_path().get_base_dir().path_join(OFFERED_FILE)


static func was_offered() -> bool:
	return FileAccess.file_exists(offered_path())


static func mark_offered() -> bool:
	DirAccess.make_dir_recursive_absolute(offered_path().get_base_dir())
	var f := FileAccess.open(offered_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(Time.get_datetime_string_from_system(true) + "\n")
	f.close()
	return true


## Atomic write: a temp file, then a rename. A look with no body (empty, or without its sex: a look that was never built) is
## never written: it would replace a character with the default one.
static func save_file(path: String, look: Dictionary) -> bool:
	if look.is_empty() or not look.has("sex"):
		push_warning("AppearanceStore: not saving an empty look over %s" % path)
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"format": FORMAT, "version": VERSION, "saved": Time.get_datetime_string_from_system(true),
			"look": look}, " "))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
