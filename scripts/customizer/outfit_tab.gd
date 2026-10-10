class_name OutfitTab
extends ScrollContainer
## The customizer's Outfit tab (CustomizerOverlay, the character creator's Clothing button): what the character wears
## (PlayerOutfit), one row per slot (shirt, breeches or skirt, coat, shoes, hat ...) with every garment this build has
## (for both body types: anyone may wear anything, the owner 2026-10-03; a garment cut for the other body type says so in
## its tooltip) and their colours (the costume bible's palette). A slot left on "Basic" wears the basic dress of
## the body type (a shirt and breeches, a shift and a petticoat); "None" takes it off. Items of evidence grade C say so
## ("Artistic licence") and name the documented forms. A slot's garments are listed set by set under the catalog's set
## names (Colonial, Drift sky crews). A garment's cloth can take a pattern (2026-10-03: "add patterns"): a check, stripes,
## a plaid of a sett, ticking, a calico print or a herringbone, on any garment (its catalog's documented ones say so), in
## the colours picked under it (the zone's own colour is the pattern's first; ClothMaterials.pattern_spec). Each group
## of choices (a zone's colours, the patterns, a plaid's setts, each of the pattern's colours) has its own line, its
## label in a column on the left and its buttons beside it.
##
##   tabs.add_child(OutfitTab.create(look_getter, changed_callback))

## Outfits one click away: [name, the look's "outfit" dictionary], shown for a body type when each of their garments was
## cut for it (PlayerOutfit.cut_for, their catalog tags: a petticoat for women, breeches for men; every garment is still
## offered to both in the slot rows). Colours may name a garment's catalog colour preset
## ({"preset": ...}: PlayerOutfit.resolve_colors). (The period outfits went with their garments, 2026-10-06.)
const PRESETS := [
	["Basic dress", {}],
	["Working dress", {"shirt": {"id": "shirt_tucked", "colors": {"0": "tow", "1": "tow"}},
			"legs.lower": {"id": "breeches", "colors": {"0": "buckskin_pale", "1": "buckskin_pale"}},
			"accessories.waist": {"id": "sash_worsted"}}],
	["Working dress", {"shirt": {"id": "shift_linen"}, "legs.lower": {"id": "petticoat", "colors": {"0": "walnut_brown"}}}],
]
## The fighters' dress one click away (NpcFactions.outfit_of: the faction's garments and colours): [name, faction].
const FACTION_PRESETS := [
	["Valley militiaman", "militia"], ["Watchman", "city_guard"], ["French marine, campaign", "french_marine"],
	["Canadian militiaman", "canadian_militia"], ["Sky crew deckhand", "sky_crew"],
]

## Colours a pattern's other colours may take beside the zone's own palette: the common dyes and linens of the time.
const DYES := ["linen_white", "linen_unbleached", "tow", "check_blue", "indigo_mid", "stroud_blue", "madder_red",
		"stroud_red", "deep_green", "full_green", "yellow", "butternut", "walnut_brown", "drab", "slate_grey", "logwood_black"]

## The label column of the colours' lines (px; a longer label wraps).
const LINE_LABEL_W := 118

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


## The outfits one click away for a body of `sex`: [name, outfit] (PRESETS, then FACTION_PRESETS), those whose garments
## were cut for the body type (PlayerOutfit.cut_for) and are offered in their slots (PlayerOutfit.offered).
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
			if not id in (offer[slot] as Array) or not PlayerOutfit.cut_for(id, sex):
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
		# (as wide as the column, not as the longest garment's name: that pushed the creator's Clothing panel off the
		# screen's right edge; a longer name ends in an ellipsis, whole in the list)
		opt.fit_to_longest_item = false
		opt.clip_text = true
		opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
			if id != "" and id != "-" and not PlayerOutfit.cut_for(id, sex):
				tip += "\nCut for %s; anyone may wear it." % ("men" if sex < 0.5 else "women")
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
		var colors := VBoxContainer.new()
		colors.add_theme_constant_override("separation", 2)
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


## A line of the colours box (each group of choices on its own line): its label in a column of its own, the buttons
## flowing beside it (a second row of swatches stays in their column, under the first); returns the buttons' flow.
static func _line(box: VBoxContainer, title: String) -> HFlowContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	box.add_child(line)
	var lab := Label.new()
	lab.text = title
	lab.custom_minimum_size = Vector2(LINE_LABEL_W, 0)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(lab)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	line.add_child(flow)
	return flow


func _refresh_colors(slot: String) -> void:
	var row: Dictionary = _rows[slot]
	var box: VBoxContainer = row.colors
	for c in box.get_children():
		c.queue_free()      # (not removed here: a swatch's own press rebuilds the box)
	var id := _shown_id(slot)
	var e := PlayerOutfit.entry(id) if id != "" and id != "-" else {}
	var ln := String(e.licence_note) if e.get("licence_note") is String else ""
	(row.note as Label).text = ln if ln.is_empty() or ln.begins_with("Artistic licence") else "Artistic licence: " + ln
	(row.note as Label).visible = (row.note as Label).text != ""
	if e.is_empty():
		return
	for ch: Array in PlayerOutfit.color_choices(id):
		var key := String(ch[0])
		var line := _line(box, String(ch[3]) + ":")
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
				var before := _pattern_state(slot)
				var o := _outfit()
				if not o.get(slot) is Dictionary:
					o[slot] = {"id": "", "colors": {}}
				var d: Dictionary = o[slot]
				if not d.get("colors") is Dictionary:
					d["colors"] = {}
				d.colors[key] = t
				if key == "bands" and not d.colors.has("bands_rows"):
					d.colors["bands_rows"] = 2
				_keep_pattern(before, d.colors, key, t)
				_changed.call())
			line.add_child(b)
	_add_pattern_rows(slot, box)


## The pattern zone of the garment shown in `slot` and what it shows: {id, pz, zd, tok, colors (resolved), spec} ({} when
## nothing is worn there).
func _pattern_state(slot: String) -> Dictionary:
	var id := _shown_id(slot)
	var e := PlayerOutfit.entry(id) if id != "" and id != "-" else {}
	if e.is_empty():
		return {}
	var v: Variant = _outfit().get(slot, {})
	var raw: Dictionary = (v as Dictionary).colors if v is Dictionary and (v as Dictionary).get("colors") is Dictionary else {}
	var cols := PlayerOutfit.resolve_colors(id, raw)
	var pz := ClothMaterials.pattern_zone(e, cols)
	var zd := {}
	for z: Dictionary in e.get("zones", []):
		if int(z.get("zone", -1)) == pz:
			zd = z
	if zd.is_empty():
		return {}
	var tok := str(cols.get(str(pz), zd.get("default", "")))
	return {"id": id, "pz": pz, "zd": zd, "tok": tok, "colors": cols,
			"spec": ClothMaterials.pattern_spec(zd, tok, cols, pz, pz)}


## The look's colours of `slot` (made when it has none).
func _slot_colors(slot: String) -> Dictionary:
	var o := _outfit()
	if not o.get(slot) is Dictionary:
		o[slot] = {"id": "", "colors": {}}
	var d: Dictionary = o[slot]
	if not d.get("colors") is Dictionary:
		d["colors"] = {}
	return d.colors


## A colour picked for the pattern zone while it showed a pattern (`before`): the pattern stays, in the new colour (the
## look now chooses it: a check shirt picked red is a red check, not a plain red shirt).
func _keep_pattern(before: Dictionary, colors: Dictionary, key: String, tok: String) -> void:
	if before.is_empty() or (before.spec as Dictionary).is_empty() or key != str(int(before.pz)):
		return
	var name := str(before.spec.name)
	if not colors.has("pattern"):
		colors["pattern"] = name
	if colors.get(name) is Array and not (colors[name] as Array).is_empty():
		colors[name][0] = tok


## The pattern row under a garment's colours: its patterns (any of ClothMaterials.PATTERNS; the catalog's documented
## ones say so), a plaid's setts, and the pattern's other colours.
func _add_pattern_rows(slot: String, box: VBoxContainer) -> void:
	var st := _pattern_state(slot)
	if st.is_empty() or not ClothMaterials.patternable(st.zd):
		return
	var spec: Dictionary = st.spec
	var cur := str(spec.get("name", "none"))
	var documented := ClothMaterials.zone_patterns(st.zd)
	var line := _line(box, "Pattern:")
	for pn: String in ClothMaterials.PATTERNS:
		var b := Button.new()
		b.text = String(ClothMaterials.PATTERN_LABELS.get(pn, pn))
		b.toggle_mode = true
		b.button_pressed = pn == cur
		b.tooltip_text = "Documented for this garment" if pn in documented and pn != "none" else ""
		b.pressed.connect(func() -> void:
			_slot_colors(slot)["pattern"] = pn
			_refresh_colors(slot)
			_changed.call())
		line.add_child(b)
	if spec.is_empty():
		return
	if cur == "plaid":
		line = _line(box, "Sett:")
		# the sett the plaid shows: the look's, else the garment's own (the catalog's), else the default
		var shown := ClothMaterials.sett_name(st.zd, st.colors)
		var setts := ClothMaterials.setts()
		for sn: String in setts:
			if not setts[sn] is Dictionary or not (setts[sn] as Dictionary).has("sett"):
				continue
			var b := Button.new()
			b.text = String(setts[sn].get("label", sn))
			b.tooltip_text = String(setts[sn].get("note", ""))
			b.toggle_mode = true
			b.button_pressed = shown == sn
			b.pressed.connect(func() -> void:
				var c := _slot_colors(slot)
				c["pattern"] = "plaid"
				c["sett"] = sn
				c.erase("plaid")
				_refresh_colors(slot)
				_changed.call())
			line.add_child(b)
	var cols: Array = spec.colors
	var pal: Array = []
	for t: Variant in (st.zd.get("palette", []) as Array) + cols + DYES:
		if not str(t) in pal:
			pal.append(str(t))
	for i in range(0 if cur == "plaid" else 1, mini(cols.size(), 4)):
		line = _line(box, "%s %d:" % [String(ClothMaterials.PATTERN_LABELS.get(cur, cur)), i + 1])
		for tok: String in pal:
			var b := Button.new()
			b.custom_minimum_size = Vector2(26, 22)
			b.tooltip_text = tok.replace("_", " ")
			var sb := StyleBoxFlat.new()
			sb.bg_color = ClothMaterials.token_color(st.zd, tok)
			if tok == str(cols[i]):
				sb.set_border_width_all(2)
				sb.border_color = Color(0.95, 0.8, 0.5)
			b.add_theme_stylebox_override("normal", sb)
			var at := i
			b.pressed.connect(func() -> void:
				var c := _slot_colors(slot)
				var now: Dictionary = _pattern_state(slot).get("spec", {})
				var list: Array = (now.get("colors", cols) as Array).duplicate()
				if at < list.size():
					list[at] = tok
				c["pattern"] = cur
				c[cur] = list
				_refresh_colors(slot)
				_changed.call())
			line.add_child(b)
