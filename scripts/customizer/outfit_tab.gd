class_name OutfitTab
extends ScrollContainer
## The customizer's Outfit tab (CustomizerOverlay, the character creator's Clothing button): what the character wears
## (PlayerOutfit), one row per slot (shirt, breeches or skirt, coat, shoes, hat ...) with the garments this build has
## for the body type and their colours (the costume bible's palette). A slot left on "Basic" wears the basic dress of
## the body type (a shirt and breeches, a shift and a petticoat); "None" takes it off. Items of evidence grade C say so
## ("Artistic licence") and name the documented forms. A slot's garments are listed set by set under the catalog's set
## names (Colonial, Drift sky crews).
##
##   tabs.add_child(OutfitTab.create(look_getter, changed_callback))

## Outfits one click away: [name, the look's "outfit" dictionary], shown for a body type when it offers each of their garments
## (their catalog tags: a petticoat for women, breeches for men). Colours may name a garment's catalog colour preset
## ({"preset": ...}: PlayerOutfit.resolve_colors). The clothes agents' assembled outfits.
const PRESETS := [
	["Basic dress", {}],
	["Settler", {"shirt": {"id": "shirt_tucked", "colors": {"0": "tow", "1": "tow"}},
			"legs.lower": {"id": "breeches", "colors": {"0": "buckskin_pale", "1": "buckskin_pale"}},
			"vest": {"id": "waistcoat_sb"}, "outer": {"id": "frock_coat", "colors": {"preset": "palatine_brown"}},
			"accessories.neck": {"id": "neckerchief", "colors": {"preset": "checked"}},
			"legs.over": {"id": "stockings", "colors": {"preset": "settler"}}, "feet": {"id": "shoes_buckled"},
			"head": {"id": "round_hat"}}],
	["Settler", {"vest": {"id": "stays_laced", "colors": {"0": "madder_red", "3": "linen_unbleached"}},
			"legs.lower": {"id": "petticoat", "colors": {"0": "walnut_brown"}},
			"accessories.waist": {"id": "apron", "colors": {"preset": "margaretha"}},
			"accessories.neck": {"id": "kerchief_womens"}, "legs.over": {"id": "stockings", "colors": {"0": "stroud_blue"}},
			"feet": {"id": "shoes_buckled"}, "head": {"id": "cap_linen"}}],
	["Settler, winter", {"vest": {"id": "stays_laced", "colors": {"0": "madder_red", "3": "linen_unbleached"}},
			"legs.lower": {"id": "petticoat", "colors": {"0": "walnut_brown"}},
			"accessories.waist": {"id": "apron", "colors": {"preset": "margaretha"}},
			"accessories.neck": {"id": "kerchief_womens"}, "outer": {"id": "jacket_womens"},
			"accessories.wrap": {"id": "cloak_hooded"}, "legs.over": {"id": "stockings", "colors": {"0": "stroud_blue"}},
			"feet": {"id": "shoes_buckled"}, "head": {"id": "cap_linen"}}],
	["British regular", {"shirt": {"id": "shirt_tucked"},
			"legs.lower": {"id": "breeches", "colors": {"0": "madder_red", "1": "madder_red"}},
			"vest": {"id": "waistcoat_skirted", "colors": {"preset": "22nd_foot"}},
			"outer": {"id": "coat_regimental_1751", "colors": {"preset": "22nd_foot"}},
			"head": {"id": "cocked_hat", "colors": {"preset": "british_private"}}, "accessories.neck": {"id": "stock_linen"},
			"accessories.waist": {"id": "belt_cartridge", "colors": {"preset": "british"}}, "legs.over": {"id": "stockings"},
			"feet": {"id": "shoes_buckled"}}],
	["French marine, garrison", {"legs.lower": {"id": "breeches", "colors": {"0": "stroud_blue", "1": "stroud_blue"}},
			"vest": {"id": "veste_sleeved", "colors": {"preset": "marine"}},
			"outer": {"id": "coat_skirted", "colors": {"preset": "marine_justaucorps"}},
			"accessories.neck": {"id": "neckerchief", "colors": {"preset": "cravat"}},
			"accessories.waist": {"id": "belt_cartridge", "colors": {"preset": "marine"}},
			"legs.over": {"id": "stockings", "colors": {"0": "royal_blue", "1": "logwood_black"}},
			"feet": {"id": "shoes_buckled", "colors": {"preset": "marine"}},
			"head": {"id": "cocked_hat", "colors": {"preset": "marine"}}}],
	["Sky crew gunner", {"shirt": {"id": "shirt_check", "colors": {"preset": "deckhand"}},
			"legs.lower": {"id": "slops", "colors": {"preset": "deckhand"}},
			"feet": {"id": "sea_boots", "colors": {"preset": "black"}},
			"outer": {"id": "sea_jacket", "colors": {"preset": "gunner"}},
			"accessories.neck": {"id": "glim", "colors": {"preset": "open"}}, "head": {"id": "tar_hat"}}],
]
## The fighters' dress one click away (NpcFactions.outfit_of: the faction's garments and colours): [name, faction].
const FACTION_PRESETS := [
	["Valley militiaman", "militia"], ["Watchman", "city_guard"], ["French marine, campaign", "french_marine"],
	["Canadian militiaman", "canadian_militia"], ["Sky crew deckhand", "sky_crew"],
]

var _get_look: Callable
var _changed: Callable
var _box: VBoxContainer
var _rows := {}
var _built_type := ""


static func create(get_look: Callable, changed: Callable) -> OutfitTab:
	var t := OutfitTab.new()
	t.name = "Outfit"
	t.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	t._get_look = get_look
	t._changed = changed
	t._box = VBoxContainer.new()
	t._box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(t._box)
	t._build()
	return t


## The outfits one click away for a body of `sex`: [name, outfit] (PRESETS, then FACTION_PRESETS), those whose garments the
## body type is offered (PlayerOutfit.offered).
static func presets(sex: float) -> Array:
	var list := []
	for p: Array in PRESETS:
		list.append([String(p[0]), p[1]])
	for p: Array in FACTION_PRESETS:
		if not NpcFactions.get_faction(String(p[1])).is_empty():
			list.append([String(p[0]), NpcFactions.outfit_of(String(p[1]), sex)])
	var offer := {}
	return list.filter(func(p: Array) -> bool:
		for slot: String in (p[1] as Dictionary):
			var v: Variant = p[1][slot]
			var id := String((v as Dictionary).get("id", "")) if v is Dictionary else String(v)
			if id == "" or id == "-" or not PlayerOutfit.usable(id):
				continue
			if not offer.has(slot):
				offer[slot] = PlayerOutfit.offered(slot, sex)
			if not id in (offer[slot] as Array):
				return false
		return true)


func _outfit() -> Dictionary:
	var lk: Dictionary = _get_look.call()
	if not lk.get("outfit") is Dictionary:
		lk["outfit"] = {}
	return lk.outfit


func _sex() -> float:
	var lk: Dictionary = _get_look.call()
	return float(lk.get("sex", 0.0))


func _build() -> void:
	for c in _box.get_children():
		c.queue_free()
	_rows.clear()
	var sex := _sex()
	_built_type = PlayerOutfit.body_type(sex)
	var l := Label.new()
	l.text = "What is worn. Basic is the plain dress of a shirt and breeches, or a shift and a petticoat."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	var pf := HFlowContainer.new()
	_box.add_child(pf)
	for p: Array in presets(sex):
		var b := Button.new()
		b.text = String(p[0])
		var o: Dictionary = p[1]
		b.pressed.connect(func() -> void:
			var lk: Dictionary = _get_look.call()
			lk["outfit"] = PlayerOutfit.validate(o.duplicate(true))
			refresh()
			_changed.call())
		pf.add_child(b)
	for slot: String in PlayerOutfit.SLOTS:
		var ids := PlayerOutfit.offered(slot, sex)
		if ids.size() < 3:
			continue        # (the basic piece and "none" only: nothing to choose in this build yet)
		var head := HBoxContainer.new()
		_box.add_child(head)
		var name_l := Label.new()
		name_l.text = String(PlayerOutfit.SLOT_NAMES.get(slot, slot))
		name_l.custom_minimum_size = Vector2(110, 0)
		head.add_child(name_l)
		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var in_set := "\n"                  # (no set yet: a separator with the set's name before its first garment)
		for i in ids.size():
			var id := String(ids[i])
			var e := PlayerOutfit.entry(id)
			if id != "" and id != "-" and String(e.get("set", "")) != in_set:
				in_set = String(e.get("set", ""))
				opt.add_separator(PlayerOutfit.set_label(in_set))
				opt.set_item_tooltip(opt.item_count - 1, PlayerOutfit.set_tip(in_set))
			elif id == "-" and in_set != "\n":
				opt.add_separator()
			var nm := PlayerOutfit.item_name(slot, id, sex)
			if String(e.get("evidence", "")) == "C":
				nm += "  (artistic licence)"
			opt.add_item(nm, i)
			var at := opt.item_count - 1
			opt.set_item_metadata(at, id)
			var tip := String(e.get("description", ""))
			if e.get("licence_note") is String:
				tip += "\n" + String(e.licence_note)
			opt.set_item_tooltip(at, tip)
		opt.item_selected.connect(func(i: int) -> void:
			var id := String(opt.get_item_metadata(i))
			var o := _outfit()
			if id == "":
				o.erase(slot)
			else:
				o[slot] = {"id": id, "colors": {}}
			_refresh_colors(slot)
			_changed.call())
		head.add_child(opt)
		var colors := HFlowContainer.new()
		_box.add_child(colors)
		var note := Label.new()
		note.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(note)
		_box.add_child(HSeparator.new())
		_rows[slot] = {"opt": opt, "colors": colors, "note": note}
	refresh()


## Shows the look's outfit (after a preset, Default or a new look); rebuilt when the body type changed.
func refresh() -> void:
	if PlayerOutfit.body_type(_sex()) != _built_type:
		_build()
		return
	var o := _outfit()
	for slot: String in _rows:
		var v = o.get(slot, {})
		var id := String(v.get("id", "")) if v is Dictionary else ""
		var opt: OptionButton = _rows[slot].opt
		for i in opt.item_count:
			var md: Variant = opt.get_item_metadata(i)       # (null on a set's separator)
			if md is String and String(md) == id:
				opt.select(i)
		_refresh_colors(slot)


## The garment shown in a slot: the look's, or the basic piece.
func _shown_id(slot: String) -> String:
	var v = _outfit().get(slot, {})
	var id := String(v.get("id", "")) if v is Dictionary else ""
	if id == "":
		var b := PlayerOutfit.basic(_sex())
		return String(b[slot].id) if b.has(slot) else ""
	return id


func _refresh_colors(slot: String) -> void:
	var row: Dictionary = _rows[slot]
	var box: HFlowContainer = row.colors
	for c in box.get_children():
		c.queue_free()
	var id := _shown_id(slot)
	var e := PlayerOutfit.entry(id) if id != "" and id != "-" else {}
	var ln := String(e.licence_note) if e.get("licence_note") is String else ""
	(row.note as Label).text = ln if ln.is_empty() or ln.begins_with("Artistic licence") else "Artistic licence: " + ln
	(row.note as Label).visible = (row.note as Label).text != ""
	if e.is_empty():
		return
	for ch: Array in PlayerOutfit.color_choices(id):
		var key := String(ch[0])
		var lab := Label.new()
		lab.text = String(ch[3]) + ":"
		box.add_child(lab)
		var zd := {}
		for z: Dictionary in e.get("zones", []):
			if str(int(z.get("zone", -1))) == key or (key == "bands" and not ClothMaterials.hem_bands(z).is_empty()):
				zd = z
		for tok in ch[1]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(34, 24)
			b.tooltip_text = String(tok).replace("fur_", "").replace("_", " ")
			var sb := StyleBoxFlat.new()
			sb.bg_color = ClothMaterials.token_color(zd, String(tok))
			b.add_theme_stylebox_override("normal", sb)
			var t := String(tok)
			b.pressed.connect(func() -> void:
				var o := _outfit()
				if not o.get(slot) is Dictionary:
					o[slot] = {"id": "", "colors": {}}
				var d: Dictionary = o[slot]
				if not d.get("colors") is Dictionary:
					d["colors"] = {}
				d.colors[key] = t
				if key == "bands" and not d.colors.has("bands_rows"):
					d.colors["bands_rows"] = 2
				_changed.call())
			box.add_child(b)
