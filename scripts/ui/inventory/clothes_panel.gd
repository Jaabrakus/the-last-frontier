class_name ClothesPanel
extends PanelContainer
## The character screen's Clothes tab, laid out as the Gear tab's equipment (user 2026-10-01: "it should be the same as the equipment
## tab we just drag it on to the character"): the body's slots in a column each side of the character (head, shoulders, body, legs;
## arms, hands, feet, wrap; the rope belt and the rope sling), the character itself (the Gear tab's own figure, shown here too), and a list of what is
## carried to drag from. A garment is dragged onto its slot or onto the character to put it on (what was there comes off); a worn one
## dragged onto the list, or right-clicked, comes off. A double-click on a carried one puts it on. Warmth always follows; in a start
## with nothing so does the look (ClothesSlots).

const CELL_W := 150.0
const CELL_H := 74.0

var screen: InventoryScreen
var _slot_cells := {}        ## zone -> Cell
var _gear_rows := {}         ## rope kind -> Cell
var _list: VBoxContainer
var _doll: TextureRect
var _note: Label


static func make(s: InventoryScreen) -> ClothesPanel:
	var c := ClothesPanel.new()
	c.screen = s
	c._build()
	return c


func _bridge() -> SurvivalBridge:
	return SurvivalBridge.find(screen.player.get_tree()) if screen != null and screen.player != null else null


func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.08, 0.7)
	sb.border_color = Color(0.5, 0.4, 0.26, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(InventoryScreen._label("Clothes", 24, Color(0.93, 0.8, 0.52)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var zones: Array = ClothesSlots.ZONES
	var half := ceili(zones.size() / 2.0)       # (the first half of the slots down the left of the figure, the rest down the right)
	row.add_child(_column(zones.slice(0, half).map(func(z: Dictionary) -> Array: return ["zone", String(z.id), String(z.name)])
			+ [["gear", "rope_belt", "Belt"]]))
	_doll = TextureRect.new()
	_doll.custom_minimum_size = Vector2(240, 444)
	_doll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_doll.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_doll.set_drag_forwarding(Callable(), _doll_can_drop, _doll_drop)
	row.add_child(_doll)
	row.add_child(_column(zones.slice(half).map(func(z: Dictionary) -> Array: return ["zone", String(z.id), String(z.name)])
			+ [["gear", "rope_sling", "Sling"]]))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	side.add_child(InventoryScreen._label("Carried", 20, Color(0.93, 0.8, 0.52)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_list.set_drag_forwarding(Callable(), _list_can_drop, _list_drop)
	scroll.add_child(_list)
	_note = InventoryScreen._label("Drag a garment onto its slot or onto the character. Right-click a slot to take it off.", 16, Color(0.9, 0.85, 0.75))
	v.add_child(_note)


func _column(specs: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	for sp: Array in specs:
		var c := Cell.new()
		c.panel = self
		c.kind = String(sp[0])
		c.key = String(sp[1])
		c.title = String(sp[2])
		c.custom_minimum_size = Vector2(CELL_W, CELL_H)
		col.add_child(c)
		if c.kind == "zone":
			_slot_cells[c.key] = c
		else:
			_gear_rows[c.key] = c
	return col


## The rows and cells from what is carried and worn now.
func refresh() -> void:
	var br := _bridge()
	if br != null and br.core != null:
		for zid: String in _slot_cells:
			var worn := ClothesSlots.worn_in(br.core, zid)
			(_slot_cells[zid] as Cell).set_content(ClothesSlots.name_of(br.core, worn) if worn != "" else "", worn != "")
	for kind: String in _gear_rows:
		var on := screen.inv.gear_worn(kind)
		var c := _gear_rows[kind] as Cell
		c.set_content(InventoryState.name_of(kind) if on else "", on)
		c.disabled = not on and screen.inv.pack_count(kind) <= 0
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if br != null and br.core != null:
		for z: String in ClothesSlots.zone_ids():
			for id: String in ClothesSlots.owned(br.core, z):
				if ClothesSlots.worn_in(br.core, z) != id:
					_list.add_child(_row({"from": "cloth", "id": id}, ClothesSlots.name_of(br.core, id)))
	for kind: String in InventoryState.GEAR_KINDS:
		if screen.inv.pack_count(kind) > 0:
			_list.add_child(_row({"from": "rope", "id": kind}, InventoryState.name_of(kind)))
	if _list.get_child_count() == 0:
		_list.add_child(InventoryScreen._label("Nothing to put on. Cloth is sewn at a workbench; bark cord makes a belt and a sling.", 15, Color(0.66, 0.61, 0.52)))
	if _doll != null and screen._view != null:
		_doll.texture = screen._view.get_texture()


func _row(payload: Dictionary, text: String) -> Control:
	var c := Cell.new()
	c.panel = self
	c.kind = "row"
	c.payload = payload
	c.title = text
	c.custom_minimum_size = Vector2(0, 34)
	return c


# ---------------------------------------------------------------- putting on and taking off
func wear_cloth(id: String) -> bool:
	var br := _bridge()
	if br == null or br.core == null:
		return false
	var ok := ClothesSlots.wear(br, id)
	if ok:
		_say("%s on." % ClothesSlots.name_of(br.core, id))
	_after()
	return ok


func take_off_zone(zone: String) -> bool:
	var br := _bridge()
	if br == null or br.core == null:
		return false
	var there := ClothesSlots.worn_in(br.core, zone)
	var ok := ClothesSlots.take_off(br, zone)
	if ok:
		_say("%s off." % ClothesSlots.name_of(br.core, there))
	_after()
	return ok


func _toggle_gear(kind: String) -> void:
	var inv := screen.inv
	if inv.gear_worn(kind):
		inv.unwear_gear(kind)
		_say("The %s is off, and what hung on it is in the pack." % InventoryState.name_of(kind).to_lower())
	elif inv.wear_gear(kind):
		_say("The %s is on." % InventoryState.name_of(kind).to_lower())
	screen._refresh()
	_after()


func _wear_payload(d: Dictionary) -> void:
	if String(d.from) == "cloth":
		wear_cloth(String(d.id))
	elif String(d.from) == "rope" and not screen.inv.gear_worn(String(d.id)):
		_toggle_gear(String(d.id))


## The doll is shown again in what she wears now (the figure of the Gear tab, drawn the same way).
func _after() -> void:
	var app: Variant = screen.player.get("appearance") if screen.player else null
	if screen._body != null and app is PlayerAppearance:
		PlayerAppearance.dress(screen._body, (app as PlayerAppearance).look)
	refresh()


func _say(t: String) -> void:
	if _note:
		_note.text = t


func _doll_can_drop(_at: Vector2, d: Variant) -> bool:
	return d is Dictionary and (String(d.get("from", "")) == "cloth" or String(d.get("from", "")) == "rope")


func _doll_drop(_at: Vector2, d: Variant) -> void:
	_wear_payload(d as Dictionary)


func _list_can_drop(_at: Vector2, d: Variant) -> bool:
	return d is Dictionary and (String(d.get("from", "")) == "worn_cloth" or String(d.get("from", "")) == "worn_rope")


func _list_drop(_at: Vector2, d: Variant) -> void:
	var p := d as Dictionary
	if String(p.from) == "worn_cloth":
		take_off_zone(String(p.zone))
	else:
		_toggle_gear(String(p.id))


## A slot, a rope cell or a carried row: dragged out when it holds something, dropped on when it is a slot.
class Cell extends Button:
	var panel: ClothesPanel
	var kind := ""                ## "zone", "gear" or "row"
	var key := ""
	var title := ""
	var payload := {}
	var content := ""
	var filled := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_theme_font_size_override("font_size", 16)
		clip_text = true

	func set_content(text: String, on: bool) -> void:
		content = text
		filled = on
		self.text = "%s\n%s" % [title, text if on else "—"]
		modulate = Color(1.0, 0.92, 0.6) if on else Color(0.8, 0.8, 0.8)

	func _ready() -> void:
		if kind == "row":
			text = title

	func _get_drag_data(_at: Vector2) -> Variant:
		var d: Dictionary = {}
		if kind == "row":
			d = payload
		elif filled and kind == "zone":
			d = {"from": "worn_cloth", "zone": key}
		elif filled and kind == "gear":
			d = {"from": "worn_rope", "id": key}
		if d.is_empty():
			return null
		var pv := Button.new()
		pv.text = content if content != "" else title
		pv.add_theme_font_size_override("font_size", 16)
		set_drag_preview(pv)
		return d

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		if not (d is Dictionary):
			return false
		var f := String((d as Dictionary).get("from", ""))
		if kind == "zone" and f == "cloth":
			var br := panel._bridge()
			return br != null and ClothesSlots.zone_of(br.core, String(d.id)) == key
		if kind == "gear" and f == "rope":
			return String(d.id) == key
		return false

	func _drop_data(_at: Vector2, d: Variant) -> void:
		panel._wear_payload(d as Dictionary)

	func _gui_input(e: InputEvent) -> void:
		if not (e is InputEventMouseButton) or not (e as InputEventMouseButton).pressed:
			return
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and filled:
			if kind == "zone":
				panel.take_off_zone(key)
			elif kind == "gear":
				panel._toggle_gear(key)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			if kind == "row":
				panel._wear_payload(payload)
			elif kind == "gear" and not filled and not disabled:
				panel._toggle_gear(key)
