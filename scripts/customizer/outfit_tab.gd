class_name OutfitTab
extends ScrollContainer
## The customizer's Outfit tab (CustomizerOverlay, the character creator's Clothing button): what the character wears
## (PlayerOutfit), one row per slot (shirt, breeches or skirt, coat, shoes, hat ...) with the garments this build has
## for the body type and their colours (the costume bible's palette). A slot left on "Basic" wears the basic dress of
## the body type (a shirt and breeches, a shift and a petticoat); "None" takes it off. Items of evidence grade C say so
## ("Artistic licence") and name the documented forms.
##
##   tabs.add_child(OutfitTab.create(look_getter, changed_callback))

## Outfits one click away: name -> the look's "outfit" dictionary.
const PRESETS := [
	["Basic dress", {}],
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
	for p: Array in PRESETS:
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
		for i in ids.size():
			var id := String(ids[i])
			var e := PlayerOutfit.entry(id)
			var nm := PlayerOutfit.item_name(slot, id, sex)
			if String(e.get("evidence", "")) == "C":
				nm += "  (artistic licence)"
			opt.add_item(nm, i)
			opt.set_item_metadata(i, id)
			var tip := String(e.get("description", ""))
			if e.get("licence_note") is String:
				tip += "\n" + String(e.licence_note)
			opt.set_item_tooltip(i, tip)
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
			if String(opt.get_item_metadata(i)) == id:
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
