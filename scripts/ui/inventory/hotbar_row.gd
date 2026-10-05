class_name HotbarRow
extends HBoxContainer
## The hotbar's row at the bottom of the inventory screen's Gear tab (Hotbar; user 2026-10-02: the minecraft approach):
## its nine slots, numbered, with what is in each. Drag a slot onto another to swap them; drag an item from the pack or a
## spell from the Spells list onto one to put it there (the one there goes off the bar); drag a slot onto the pack, or
## right-click it, to take it off the bar. Pointing at an item or a spell anywhere on the screen and pressing 1-9 puts it
## in that slot (InventoryScreen.hotbar_key). Nothing comes onto the bar by itself: the player puts it there.

const CELL := 64

var screen: InventoryScreen
var cells: Array[HotbarCell] = []


static func make(s: InventoryScreen) -> HotbarRow:
	var r := HotbarRow.new()
	r.name = "HotbarRow"
	r.screen = s
	r.add_theme_constant_override("separation", 6)
	var title := InventoryScreen._label("Hotbar", 24, Color(0.93, 0.8, 0.52))
	title.custom_minimum_size = Vector2(110, 0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(title)
	for i in Hotbar.SLOTS:
		var c := HotbarCell.new()
		c.row = r
		c.slot = i
		r.add_child(c)
		r.cells.append(c)
	var hint := InventoryScreen._label("Drag from the pack or the spells onto a slot,\nor point and press 1-9; right-click takes off.", 14,
			Color(0.66, 0.61, 0.52))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(hint)
	return r


func hotbar() -> Hotbar:
	return Hotbar.find(screen.player) if screen else null


func refresh() -> void:
	var hb := hotbar()
	visible = hb != null
	if hb == null:
		return
	var sel := hb.selected()
	for c in cells:
		c.show_slot(hb, sel)


## A hotbar slot in the row.
class HotbarCell extends PanelContainer:
	var row: HotbarRow
	var slot := 0
	var kind := ""                    ## the inventory's kind of what is in it ("" empty or a spell)
	var _sb: StyleBoxFlat
	var _icon: TextureRect
	var _num: Label
	var _cap: Label
	var _on := false
	var _spell := false
	var _mode := ""                   ## a spell's mode: its mark in the cell's corner (FrontierHUD.draw_mode_mark), as the HUD's strip
	var _mark: Control

	func _draw() -> void:
		if _spell and _icon and _icon.texture == null:
			FrontierHUD.draw_spell_circle(self, Rect2(Vector2(10, 6), size - Vector2(20, 22)))    # (its name under it)

	func _ready() -> void:
		custom_minimum_size = Vector2(HotbarRow.CELL, HotbarRow.CELL)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_sb = StyleBoxFlat.new()
		_sb.set_corner_radius_all(4)
		_sb.set_border_width_all(2)
		add_theme_stylebox_override("panel", _sb)
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_icon = TextureRect.new()
		_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon.offset_left = 4
		_icon.offset_top = 4
		_icon.offset_right = -4
		_icon.offset_bottom = -4
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_icon)
		_num = InventoryScreen._label(str(slot + 1), 15, Color(0.93, 0.8, 0.52))
		_num.position = Vector2(4, 0)
		_num.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_num.add_theme_constant_override("outline_size", 4)
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_num)
		_cap = InventoryScreen._label("", 11, Color(0.82, 0.74, 0.6))
		_cap.position = Vector2(4, HotbarRow.CELL - 20)
		_cap.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_cap.add_theme_constant_override("outline_size", 3)
		_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_cap)
		_mark = Control.new()
		_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark.draw.connect(func() -> void:
			if _mode != "":
				FrontierHUD.draw_mode_mark(_mark, Rect2(Vector2(_mark.size.x - 19, 1), Vector2(17, 17)), _mode))
		box.add_child(_mark)

	func show_slot(hb: Hotbar, sel: int) -> void:
		if _sb == null:
			return
		var e := hb.entry(slot)
		kind = hb.pack_kind(slot)
		var ik := hb.icon_kind(slot)
		_icon.texture = null
		var was := _spell
		_spell = ik.begins_with("spell:")
		if _spell:
			_icon.texture = FrontierHUD.spell_texture(ik.trim_prefix("spell:"), get_tree())    # (else its circle is drawn)
		elif ik != "":
			_icon.texture = row.screen.icons.get_icon(ik)
		if was != _spell or _spell:
			queue_redraw()
		var c := SwayCaster.of(row.screen.player) if _spell else null
		var md := c.base_mode_of(String(e.id)) if c != null else ""
		if md != _mode:
			_mode = md
			_mark.queue_redraw()
		_cap.text = hb.label(slot) if not e.is_empty() and (_icon.texture == null) else ""
		_cap.clip_text = true
		_cap.size = Vector2(HotbarRow.CELL - 8, 18)
		_on = slot == sel
		_sb.bg_color = Color(0.24, 0.2, 0.14) if not e.is_empty() else Color(0.12, 0.11, 0.09)
		_sb.border_color = Color(0.95, 0.78, 0.42) if _on else (Color(0.62, 0.5, 0.3) if not e.is_empty() else Color(0.3, 0.25, 0.18))
		var nm := c.spell_label(String(e.id)) if c != null else hb.label(slot)
		tooltip_text = ("%d: %s" % [slot + 1, nm]) if not e.is_empty() else "%d: empty" % (slot + 1)

	func _notification(what: int) -> void:
		if row == null or row.screen == null:
			return
		if what == NOTIFICATION_MOUSE_ENTER:
			row.screen.hovered_slot = slot
			if kind != "":
				row.screen.hover(kind)
			elif _spell:
				row.screen.hover("spell:" + String(row.hotbar().entry(slot).get("id", "")) if row.hotbar() else "")
		elif what == NOTIFICATION_MOUSE_EXIT:
			if row.screen.hovered_slot == slot:
				row.screen.hovered_slot = -1
			row.screen.hover("")

	func _get_drag_data(_at: Vector2) -> Variant:
		var hb := row.hotbar()
		if hb == null or not hb.filled(slot):
			return null
		var t := TextureRect.new()
		t.texture = _icon.texture
		t.size = Vector2(56, 56)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		set_drag_preview(t if t.texture else InventoryScreen._label(hb.label(slot), 16, Color(1, 0.9, 0.6)))
		return {"from": "hotbar", "slot": slot}

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		if not (d is Dictionary):
			return false
		var from := String((d as Dictionary).get("from", ""))
		if from == "hotbar":
			return true
		var e := row.screen.drag_entry(d)
		return not e.is_empty() and row.hotbar() != null and row.hotbar().has_thing(e)

	func _drop_data(_at: Vector2, d: Variant) -> void:
		var hb := row.hotbar()
		if hb == null:
			return
		if String(d.get("from", "")) == "hotbar":
			hb.swap(int(d.slot), slot)
			row.screen.say("Slots %d and %d swapped." % [int(d.slot) + 1, slot + 1])
		elif String(d.get("from", "")) == "spell":
			var id := String(d.get("id", ""))
			row.screen.hotbar_put_entry(Hotbar.make(Hotbar.SPELL, id), slot, Hotbar.spell_label(id))
		else:
			row.screen.hotbar_put(row.screen.drag_kind(d), slot)
		row.refresh()

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			row.screen.hotbar_off(slot)
