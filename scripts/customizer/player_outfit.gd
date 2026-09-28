class_name PlayerOutfit
extends RefCounted
## The garments a character wears (cloth2, 2026-09-28: the garments were remade on the MakeHuman body, the legacy
## outfit is gone). A garment in a slot adds its glb as a part ("outfit:<slot>") of the character's
## CharacterBodyMesh (one shared Skin, the same helper driver); it follows the male fit and the bust gauge by its own
## morph targets ("sex", "breast_large", "breast_small": BodyMaterials.apply_look sets them on every part), gets its
## cloth and fur materials from its catalog entry (ClothMaterials), and hides the body regions it covers.
##
## The look's "outfit" key (AppearanceStore saves it): {slot: {"id": catalog id, "colors": {...}}} with colours per
## zone index ("0", "1": palette token or "#hex"), "fur" (a fur preset token) and "bands" / "bands_rows" (capot
## stripes). A missing slot or an empty id = the basic dress of that slot for the body type (BASIC: a shirt and
## breeches, a shift and a petticoat); the id "-" = nothing.
##
##   var res := PlayerOutfit.dress(body, look.get("outfit", {}), sex)     # PlayerAppearance.dress() calls it
##   res.has_hat, res.hide_regions, res.hide_hair_zones, res.bulk_slots (SlingRig), res.parts

const CATALOG := "res://assets/character/catalog.json"
const RUNTIME := "res://data/loadout/sling_runtime.json"
## Slots a character dresses in, in the customizer's order.
const SLOTS := ["shirt", "vest", "outer", "legs.lower", "legs.over", "feet", "head", "accessories.neck",
		"accessories.waist", "accessories.wrap", "accessories.hands"]
const SLOT_NAMES := {"shirt": "Shirt", "vest": "Waistcoat", "outer": "Coat", "legs.lower": "Breeches / skirt",
		"legs.over": "Leggings", "feet": "Shoes", "head": "Hat", "accessories.neck": "Neckwear",
		"accessories.waist": "Belt / sash", "accessories.wrap": "Cloak / blanket", "accessories.hands": "Gloves"}
## The basic dress: what a body wears when the look chooses nothing (the user, 2026-09-28: "the most basic clothes
## first"). Ids of the first cloth2 garments; a slot whose garment is missing from the catalog is left bare.
const BASIC := {
	"men": {"shirt": "shirt_linen", "legs.lower": "breeches"},
	"women": {"shirt": "shift_linen", "legs.lower": "petticoat"},
}
## Colours used when the look does not choose them (over the catalog's zone defaults).
const DEFAULT_COLORS := {}

static var _catalog := {}


static func enabled() -> bool:
	return true


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) if FileAccess.file_exists(CATALOG) else null
		_catalog = (d.get("items", {}) if d is Dictionary else {}) as Dictionary
	return _catalog


static func entry(id: String) -> Dictionary:
	return catalog().get(id, {})


## A garment the game dresses in: the cloth2 garments (catalog lib_version 2). The older ones (fitted to the old
## body; their gear, the horn, pouch and belts, is still the loadout's) stay in the catalog until each is replaced.
static func usable(id: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and int(e.get("lib_version", 1)) >= 2 and String(e.get("kind", "")) == "garment"


static func body_type(sex: float) -> String:
	return "men" if sex >= 0.5 else "women"


## The basic dress of a body type as an outfit ({slot: {id, colors}}, only garments this build has).
static func basic(sex: float) -> Dictionary:
	var out := {}
	var b: Dictionary = BASIC[body_type(sex)]
	for slot: String in b:
		if usable(String(b[slot])):
			out[slot] = {"id": String(b[slot]), "colors": {}}
	return out


## What is worn: the basic dress with the look's choices over it ("-" takes a slot off, "" keeps the basic piece).
static func effective(outfit: Dictionary, sex: float) -> Dictionary:
	var out := basic(sex)
	for slot: String in SLOTS:
		if not outfit.has(slot):
			continue
		var v = outfit[slot]
		var id := String(v.get("id", "")) if v is Dictionary else String(v)
		var cols: Dictionary = (v.colors as Dictionary).duplicate() if v is Dictionary and v.get("colors") is Dictionary else {}
		if id == "-":
			out.erase(slot)
		elif id != "" and usable(id):
			out[slot] = {"id": id, "colors": cols}
		elif id == "" and out.has(slot):
			(out[slot] as Dictionary).colors = cols
	return out


## The items of `slot` this build has for a body type (sex < 0: every one): "" (the basic piece) first, "-" (none) last.
static func offered(slot: String, sex := -1.0) -> Array:
	var out := [""]
	var ids := []
	for id: String in catalog():
		var e: Dictionary = catalog()[id]
		if not usable(id):
			continue
		if String(e.get("slot", "")) != slot and not slot in (e.get("alt_slots", []) as Array):
			continue
		var tags: Array = e.get("tags", [])
		if sex >= 0.0 and ("men" in tags or "women" in tags) and not body_type(sex) in tags:
			continue
		ids.append(id)
	ids.sort()
	out.append_array(ids)
	out.append("-")
	return out


static func item_name(slot: String, id: String, sex := 0.0) -> String:
	if id == "":
		var b := basic(sex)
		if b.has(slot):
			return "Basic (%s)" % String(entry(String(b[slot].id)).get("name", ""))
		return "Nothing (basic)"
	if id == "-":
		return "None"
	return String(entry(id).get("name", id))


## Colour choices of an item: [[key, [tokens...], default, label]] (the fur, then each cloth zone).
static func color_choices(id: String) -> Array:
	var e := entry(id)
	var out := []
	var fur: Dictionary = e.get("fur", {})
	var zones: Array = e.get("zones", [])
	for zd: Dictionary in zones:
		var pal: Array = zd.get("palette", [])
		if pal.size() < 2:
			continue
		var key := str(int(zd.get("zone", 0)))
		var label := String(zd.get("name", "colour")).capitalize()
		if not fur.is_empty() and int(zd.get("zone", 0)) == int(fur.get("palette_zone", 0)):
			label = "Fur"
		out.append([key, pal, String(zd.get("default", pal[0])), label])
		var b := ClothMaterials.hem_bands(zd)
		if not b.is_empty():
			out.append(["bands", b.get("palette", []), String(b.get("default", "")), "Stripes"])
	return out


## "shirt:shirt_linen:linen_white,legs.lower:breeches:0=drab" -> an outfit dictionary.
static func parse_arg(s: String) -> Dictionary:
	var out := {}
	for part in s.split(",", false):
		var f := part.split(":")
		if f.size() < 2:
			continue
		var cols := {}
		var zi := 0
		for i in range(2, f.size()):
			if "=" in f[i]:
				cols[f[i].get_slice("=", 0)] = f[i].get_slice("=", 1)
			else:
				cols[str(zi)] = f[i]
				zi += 1
		out[f[0]] = {"id": f[1], "colors": cols}
	return out


## Slot -> item id of an outfit, e.g. for SlingRig.set_outfit_from_appearance.
static func worn_ids(outfit: Dictionary) -> Dictionary:
	var out := {}
	for slot: String in outfit:
		var v = outfit[slot]
		var id := String(v.get("id", "")) if v is Dictionary else String(v)
		if id != "" and id != "-" and not entry(id).is_empty():
			out[slot] = id
	return out


## body_fit.json outfit bulk key of the worn items (SlingRig.set_outfit_from_appearance's rule on
## data/loadout/sling_runtime.json outfit_bulk_map: the wrap wins over the outer garment, the outer over the vest,
## the vest over the shirt); "bare" when nothing is worn.
static func bulk_key(slots: Dictionary) -> String:
	if slots.is_empty() or bool(slots.get("bare", false)):
		return "bare"
	var rt = JSON.parse_string(FileAccess.get_file_as_string(RUNTIME)) if FileAccess.file_exists(RUNTIME) else null
	var m: Dictionary = rt.get("outfit_bulk_map", {}) if rt is Dictionary else {}
	var wrap := String(slots.get("accessories.wrap", ""))
	var outer := String(slots.get("outer", ""))
	if wrap != "" and (m.get("wrap", {}) as Dictionary).has(wrap):
		return String(m.wrap[wrap])
	if outer != "":
		return String((m.get("outer", {}) as Dictionary).get(outer, "coat_or_frock"))
	if String(slots.get("vest", "")) != "":
		return String(m.get("vest", "waistcoat"))
	if String(slots.get("shirt", "")) != "":
		return String(m.get("shirt", "shirt_only"))
	return "bare"


## Drops unknown slots and ids (a save from another build still loads).
static func validate(outfit) -> Dictionary:
	var out := {}
	if not outfit is Dictionary:
		return out
	for slot: String in outfit:
		if not slot in SLOTS:
			continue
		var v = outfit[slot]
		var d: Dictionary = v if v is Dictionary else {"id": String(v)}
		var id := String(d.get("id", ""))
		if id == "-" or id == "" or usable(id):
			out[slot] = {"id": id, "colors": (d.get("colors", {}) as Dictionary).duplicate() if d.get("colors") is Dictionary else {}}
		else:
			push_warning("PlayerOutfit: %s not in the catalog; %s takes the basic piece." % [id, slot])
	return out


## Puts the outfit (over the basic dress) on `body`. Returns {has_hat, hide_regions (the body regions the garments
## cover), hide_hair_zones, bulk_slots (slot -> id, for SlingRig; {"bare": true} when nothing is worn), parts}.
static func dress(body: CharacterBodyMesh, outfit: Dictionary, sex := 0.0) -> Dictionary:
	var res := {"has_hat": false, "hide_regions": [], "hide_hair_zones": [], "bulk_slots": {}, "parts": []}
	var eff := effective(outfit, sex)
	var worn := {}
	for slot: String in SLOTS:
		var tag := "outfit:" + slot
		var v = eff.get(slot, {})
		var id := String(v.get("id", "")) if v is Dictionary else ""
		var e := entry(id) if id != "" else {}
		if e.is_empty():
			body.remove_part(tag)
			continue
		var cur: Array = body.part_meshes(tag)
		if cur.is_empty() or not is_instance_valid(cur[0]) or String((cur[0] as Node).get_meta("garment", "")) != id:
			var added := body.add_part(tag, String(e.get("glb", "")))
			for mi: MeshInstance3D in added:
				mi.set_meta("garment", id)
		var colors: Dictionary = (DEFAULT_COLORS.get(id, {}) as Dictionary).duplicate()
		if v is Dictionary and v.get("colors") is Dictionary:
			colors.merge(v.colors, true)
		_apply_materials(body.part_meshes(tag), e, colors)
		worn[slot] = id
		res.parts.append(tag)
		for r: String in e.get("hides_regions", []):
			if not r in res.hide_regions:
				res.hide_regions.append(r)
		res.hide_hair_zones.append_array(e.get("hides_hair_zones", []))
		if slot == "head":
			res.has_hat = true
	res.bulk_slots = worn if not worn.is_empty() else {"bare": true}
	return res


static func _apply_materials(meshes: Array, e: Dictionary, colors: Dictionary) -> void:
	var mats := ClothMaterials.garment_materials(e, colors)
	for mi: MeshInstance3D in meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var sname: String = src.resource_name if src else mi.mesh.surface_get_name(s)
			if mats.has(sname):
				mi.set_surface_override_material(s, mats[sname])
