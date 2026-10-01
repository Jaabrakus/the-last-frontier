class_name ClothesPanel
extends PanelContainer
## The character screen's Clothes tab (user 2026-10-01: "allow the players to add clothes slots in the tab, and ... rope to make sling
## rig to carry items as the starting"): a row for each body slot (ClothesSlots: head, body, legs, feet, hands, wrap) with the
## garments carried to choose from, and the rope gear (the belt and the sling: pack kinds made from bark cord, InventoryState.GEAR_KINDS)
## to put on or take off. Choosing a garment puts it on (warmth and, in a start with nothing, the look); "nothing" takes it off.

var screen: InventoryScreen
var _rows := {}              ## zone -> OptionButton
var _gear_rows := {}         ## rope kind -> Button
var _note: Label
var _fill := false


static func make(s: InventoryScreen) -> ClothesPanel:
	var c := ClothesPanel.new()
	c.screen = s
	c._build()
	return c


func _bridge() -> SurvivalBridge:
	return SurvivalBridge.find(screen.player.get_tree()) if screen != null and screen.player != null else null


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "Clothes"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	for z: Dictionary in ClothesSlots.ZONES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.text = String(z.name)
		l.custom_minimum_size = Vector2(110, 0)
		l.add_theme_font_size_override("font_size", 18)
		row.add_child(l)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(330, 34)
		var zid := String(z.id)
		ob.item_selected.connect(func(i: int) -> void: _chosen(zid, i))
		row.add_child(ob)
		box.add_child(row)
		_rows[zid] = ob
	var sep := HSeparator.new()
	box.add_child(sep)
	var g := Label.new()
	g.text = "Carry gear (made from bark cord at the knapping stone)"
	g.add_theme_font_size_override("font_size", 18)
	box.add_child(g)
	for kind: String in InventoryState.GEAR_KINDS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(450, 34)
		var k := kind
		b.pressed.connect(func() -> void: _toggle_gear(k))
		box.add_child(b)
		_gear_rows[kind] = b
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 16)
	_note.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	box.add_child(_note)


## The rows and buttons from what is carried and worn now.
func refresh() -> void:
	var br := _bridge()
	_fill = true
	for zid: String in _rows:
		var ob := _rows[zid] as OptionButton
		ob.clear()
		ob.add_item("— nothing —")
		ob.set_item_metadata(0, "")
		if br == null or br.core == null:
			ob.disabled = true
			continue
		ob.disabled = false
		var worn := ClothesSlots.worn_in(br.core, zid)
		var sel := 0
		var list := ClothesSlots.owned(br.core, zid)
		if worn != "" and not list.has(worn):
			list.append(worn)
		for id: String in list:
			ob.add_item(ClothesSlots.name_of(br.core, id))
			ob.set_item_metadata(ob.item_count - 1, id)
			if id == worn:
				sel = ob.item_count - 1
		ob.select(sel)
	for kind: String in _gear_rows:
		var b := _gear_rows[kind] as Button
		var nm := InventoryState.name_of(kind)
		if screen.inv.gear_worn(kind):
			b.text = "%s: on  (take it off)" % nm
			b.disabled = false
		elif screen.inv.pack_count(kind) > 0:
			b.text = "Put on the %s" % nm.to_lower()
			b.disabled = false
		else:
			b.text = "No %s (bark cord, two or three lengths)" % nm.to_lower()
			b.disabled = true
	_fill = false


func _chosen(zone: String, i: int) -> void:
	if _fill:
		return
	var br := _bridge()
	if br == null or br.core == null:
		return
	var ob := _rows[zone] as OptionButton
	var id := String(ob.get_item_metadata(i))
	if id == "":
		ClothesSlots.take_off(br, zone)
		_say("%s: nothing." % ClothesSlots.zone_name(zone))
	else:
		ClothesSlots.wear(br, id)
		_say("%s on." % ClothesSlots.name_of(br.core, id))
	refresh()


func _toggle_gear(kind: String) -> void:
	var inv := screen.inv
	if inv.gear_worn(kind):
		inv.unwear_gear(kind)
		_say("The %s is off, and what hung on it is in the pack." % InventoryState.name_of(kind).to_lower())
	elif inv.wear_gear(kind):
		_say("The %s is on." % InventoryState.name_of(kind).to_lower())
	screen._refresh()
	refresh()


func _say(t: String) -> void:
	if _note:
		_note.text = t
