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
## breeches, a shift and a petticoat); the id "-" = nothing. A "preset" key in the colours names one of the garment's
## catalog colour presets (its extra.presets: "marine", "canadian", "ithel" ...), which the other keys override
## (resolve_colors; the factions' and the story people's clothes use them).
##
## The catalog's sets ("colonial", "drift" ...) order the garments a slot offers (offered: set by set; set_label).
##
##   var res := PlayerOutfit.dress(body, look.get("outfit", {}), sex)     # PlayerAppearance.dress() calls it
##   res.has_hat, res.hide_regions, res.hide_hair_zones, res.bulk_slots (SlingRig), res.parts

const CATALOG := "res://assets/character/catalog.json"
const RUNTIME := "res://data/loadout/sling_runtime.json"
## Slots a character dresses in, in the customizer's order (the catalog's slots, 2026-10-03: "add the missing slots"):
## accessories.shoulder takes what is worn over the shoulders and across the body (a harness, a bandolier, cross-belts,
## a shoulder cape), accessories.arms what is worn on the arms (bracers, arm bands, a wrist gauntlet). The catalog's
## accessories.ears_nose is no garment slot: earrings and nose jewels are the creator's "jewellery" (FaceExtras places
## them on the head's own ear lobes, ear rims, septum and nostril as its face shapes move them), so a garment of that slot
## is not offered.
const SLOTS := ["shirt", "vest", "outer", "legs.lower", "legs.over", "feet", "head", "accessories.neck",
		"accessories.waist", "accessories.shoulder", "accessories.wrap", "accessories.arms", "accessories.hands"]
const SLOT_NAMES := {"shirt": "Shirt", "vest": "Waistcoat", "outer": "Coat", "legs.lower": "Breeches / skirt",
		"legs.over": "Leggings", "feet": "Shoes", "head": "Hat", "accessories.neck": "Neckwear",
		"accessories.waist": "Belt / sash", "accessories.shoulder": "Harness / bandolier",
		"accessories.wrap": "Cloak / blanket", "accessories.arms": "Bracers / arm bands", "accessories.hands": "Gloves"}
## Alternative slots a garment was given only while its own slot was not one of SLOTS (cloth2's rigging_harness: offered
## as a wrap until the shoulder slot came): own slot -> the stand-in. It is not offered there any more, and a look that
## has it there moves it to its own slot (validate).
const STAND_IN_SLOTS := {"accessories.shoulder": "accessories.wrap"}
## The basic dress: what a body wears when the look chooses nothing (the user, 2026-09-28: "the most basic clothes
## first"). Ids of the first cloth2 garments; a slot whose garment is missing from the catalog is left bare. A man's shirt
## is tucked into his breeches (2026-10-03: in the 1750s the tails served as drawers; shirt_linen's tails hanging over
## the breeches read as a nightshirt), shirt_linen stays in the catalog for sleeping or under a cut-away coat.
const BASIC := {
	"men": {"shirt": "shirt_tucked", "legs.lower": "breeches"},
	"women": {"shirt": "shift_linen", "legs.lower": "petticoat"},
}
## The genitals under clothes (the user, 2026-09-28: "only hide genitals if they wear underwear / pants; males hide
## genitals on all clothes"): a woman's are hidden only by a garment closed between the legs, underwear or pants
## (CLOSED_IDS, or a catalog tag in CLOSED_TAGS); a skirt, a shift or shirt tails leave them. A man's are hidden
## under any garment over the pelvis (its catalog occupies_regions has pelvis_center, or it is worn on the legs).
## "pelvis_center" in hide_regions is what hides them (the body's region, the pubic hair, BodyMaterials.apply_look's
## genital_swing), so the rule decides whether a garment's pelvis_center counts.
const CLOSED_IDS := ["breeches", "slops"]
const CLOSED_TAGS := ["underwear", "pants"]
const GENITALS := "pelvis_center"
## Colours used when the look does not choose them (over the catalog's zone defaults).
const DEFAULT_COLORS := {}

static var _catalog := {}
## The catalog's sets: id -> label, in the catalog's order; their tooltips.
static var _sets := {}
static var _set_tips := {}
## The garments' glb scenes by path (scene_of).
static var _scenes := {}


static func enabled() -> bool:
	return true


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) if FileAccess.file_exists(CATALOG) else null
		_catalog = (d.get("items", {}) if d is Dictionary else {}) as Dictionary
		_sets = (d.get("sets", {}) if d is Dictionary and d.get("sets") is Dictionary else {}) as Dictionary
		_set_tips = (d.get("set_tooltips", {}) if d is Dictionary and d.get("set_tooltips") is Dictionary else {}) as Dictionary
	return _catalog


static func entry(id: String) -> Dictionary:
	return catalog().get(id, {})


## The catalog's label of a set ("drift" -> "Drift sky crews"; the id capitalized when it has none), and its tooltip.
static func set_label(set_id: String) -> String:
	catalog()
	return String(_sets.get(set_id, set_id.capitalize()))


static func set_tip(set_id: String) -> String:
	catalog()
	return String(_set_tips.get(set_id, ""))


## A garment's glb scene, loaded once and kept (null when there is none): a part added by its path asks the resource loader
## for it each time, about 1 ms a garment in the level, where the loader is busy with the world's own loads; a fighter of
## eight or nine garments built in a frame (NpcSquad: a man a frame) paid it for each.
static func scene_of(path: String) -> PackedScene:
	var s: Variant = _scenes.get(path)
	if s is PackedScene:
		return s
	if path == "" or not ResourceLoader.exists(path):
		return null
	var sc := load(path) as PackedScene
	if sc != null:
		_scenes[path] = sc
	return sc


## The colours of garment `id` with a "preset" key resolved: the catalog preset's keys (its extra.presets[name]), the
## other keys over them. Colours without one come back as they are; an unknown preset name leaves the zone defaults.
static func resolve_colors(id: String, colors: Dictionary) -> Dictionary:
	if not colors.has("preset"):
		return colors
	var extra: Variant = entry(id).get("extra", {})
	var presets: Variant = (extra as Dictionary).get("presets", {}) if extra is Dictionary else {}
	var p: Variant = (presets as Dictionary).get(String(colors.preset)) if presets is Dictionary else null
	var out: Dictionary = (p as Dictionary).duplicate(true) if p is Dictionary else {}
	if not p is Dictionary:
		push_warning("PlayerOutfit: %s has no colour preset %s." % [id, colors.preset])
	for k: Variant in colors:
		if String(k) != "preset":
			out[k] = colors[k]
	return out


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


## The items of `slot` this build has: "" (the basic piece) first, "-" (none) last, the garments between set by set in
## the catalog's order of sets (its "set": colonial, then drift ...), by id in each. Every garment is offered to both body
## types (the owner, 2026-10-03: "give everyone the ability to wear anything on starting"; cloth2 builds every cut on
## both fits, docs/research/peoples_dress_1750s.md 1.2), and to every people; `sex` only names the body type asking (the
## basic piece stays the body type's). cut_for says whom a garment was cut for (the outfit presets keep to it).
static func offered(slot: String, _sex := -1.0) -> Array:
	var out := [""]
	var ids := []
	for id: String in catalog():
		var e: Dictionary = catalog()[id]
		if not usable(id):
			continue
		var own := String(e.get("slot", ""))
		if own != slot and (not slot in (e.get("alt_slots", []) as Array) or stand_in(id, slot)):
			continue
		ids.append(id)
	var order: Array = _sets.keys()
	var rank := func(id: String) -> int:
		var i := order.find(String(entry(id).get("set", "")))
		return i if i >= 0 else order.size()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = rank.call(a)
		var rb: int = rank.call(b)
		return ra < rb if ra != rb else a < b)
	out.append_array(ids)
	out.append("-")
	return out


## Whether garment `id` was cut for a body of `sex` (its catalog tags name that body type, or neither: a petticoat is a
## woman's, breeches a man's, a hat both). Anyone may wear it (offered); the creator's outfit presets keep to the cut.
static func cut_for(id: String, sex: float) -> bool:
	var tags: Array = entry(id).get("tags", [])
	return not ("men" in tags or "women" in tags) or body_type(sex) in tags


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


## Whether `slot` is only the stand-in of garment `id` (STAND_IN_SLOTS: its own slot is one of SLOTS now).
static func stand_in(id: String, slot: String) -> bool:
	var own := String(entry(id).get("slot", ""))
	return own != slot and own in SLOTS and String(STAND_IN_SLOTS.get(own, "")) == slot


## Drops unknown slots and ids (a save from another build still loads). A garment in its stand-in slot moves to its own
## slot when the look has nothing there (a harness picked as a wrap before the shoulder slot came).
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
	for slot: String in out.keys():
		var id := String(out[slot].id)
		var own := String(entry(id).get("slot", "")) if id != "" and id != "-" else ""
		if own != "" and stand_in(id, slot) and String((out.get(own, {}) as Dictionary).get("id", "")) == "":
			out[own] = out[slot]
			out.erase(slot)
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
			var glb := String(e.get("glb", ""))
			var sc := scene_of(glb)
			var added := body.add_part(tag, sc if sc != null else glb)
			for mi: MeshInstance3D in added:
				mi.set_meta("garment", id)
		var colors: Dictionary = (DEFAULT_COLORS.get(id, {}) as Dictionary).duplicate()
		if v is Dictionary and v.get("colors") is Dictionary:
			colors.merge(v.colors, true)
		_apply_materials(body.part_meshes(tag), e, resolve_colors(id, colors))
		worn[slot] = id
		res.parts.append(tag)
		var hides: Array = (e.get("hides_regions", []) as Array).filter(func(r: String) -> bool: return r != GENITALS)
		if hides_genitals(id, slot, sex):
			hides.append(GENITALS)
		for r: String in hides:
			if not r in res.hide_regions:
				res.hide_regions.append(r)
		res.hide_hair_zones.append_array(e.get("hides_hair_zones", []))
		if slot == "head":
			res.has_hat = true
	# a closed skirt (the petticoat: its catalog skirt.closed) hangs round both legs as one (CharacterBodyMesh)
	var skirt := {}
	for slot: String in worn:
		var s = entry(worn[slot]).get("skirt")
		if s is Dictionary and bool((s as Dictionary).get("closed", false)):
			skirt = s
	var hems: Array = []
	for h in skirt.get("hems_godot", []):
		hems.append(Vector3(float(h[0]), float(h[1]), float(h[2])))
	body.set_skirt_closed(not skirt.is_empty(), hems)
	res.bulk_slots = worn if not worn.is_empty() else {"bare": true}
	return res


## Whether garment `id`, worn in `slot`, hides the genitals of a body of `sex` (see CLOSED_IDS).
static func hides_genitals(id: String, slot: String, sex: float) -> bool:
	var e := entry(id)
	if e.is_empty():
		return false
	if body_type(sex) == "men":
		return slot == "legs.lower" or GENITALS in (e.get("occupies_regions", []) as Array) \
				or GENITALS in (e.get("hides_regions", []) as Array)
	if id in CLOSED_IDS:
		return true
	for t: String in e.get("tags", []):
		if t in CLOSED_TAGS:
			return true
	return false


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
