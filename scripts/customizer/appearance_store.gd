class_name AppearanceStore
extends RefCounted
## The player's look on disk (design 11.2): user://appearance/current.json, plain JSON
## (data only; a save never fails to load: unknown or broken values fall back to the
## default look, key by key).
##
##   var look := AppearanceStore.load_current()
##   AppearanceStore.save_current(look)
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
	return look


## Missing keys filled from the default, numbers clamped, unknown hair styles replaced.
static func validate(look: Dictionary) -> Dictionary:
	var out := default_look()
	for k in look:
		out[k] = look[k]
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
	for k in ["facial_hair", "eyebrows", "markings", "jewellery"]:
		if out.has(k) and not out[k] is String:
			out.erase(k)
	if out.has("jewellery") and not (CreatorOptions.data().get("jewellery", {}) as Dictionary).has(out.jewellery):
		out["jewellery"] = "none"
	if out.has("facial_hair") and not String(out.facial_hair).is_empty() \
			and not (CreatorOptions.data().get("facial_hair", {}) as Dictionary).has(out.facial_hair):
		out.erase("facial_hair")
	var mk: Dictionary = out.get("marks", {}) if out.get("marks") is Dictionary else {}
	out["marks"] = {"pox": clampf(float(mk.get("pox", 0.0)), 0.0, 1.0), "scar": clampi(int(mk.get("scar", 0)), 0, 3),
			"paint": clampf(float(mk.get("paint", 0.0)), 0.0, 1.0)}
	return out


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
	return load_file(CURRENT)


static func save_current(look: Dictionary) -> bool:
	return save_file(CURRENT, look)


## Atomic write: a temp file, then a rename.
static func save_file(path: String, look: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"format": FORMAT, "version": VERSION, "saved": Time.get_datetime_string_from_system(true),
			"look": look}, " "))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
