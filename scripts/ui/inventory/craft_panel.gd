class_name CraftPanel
extends PanelContainer
## The character screen's Craft tab: what the hands make with no table or station (HandCraft): each recipe a row with what it needs
## and a Make button, grey with the reason when the pack is short. Making closes the screen and the work is done in the world.

var screen: InventoryScreen
var _list: VBoxContainer
var _note: Label


static func make(s: InventoryScreen) -> CraftPanel:
	var c := CraftPanel.new()
	c.screen = s
	c._build()
	return c


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
	v.add_child(InventoryScreen._label("Craft by hand", 24, Color(0.93, 0.8, 0.52)))
	v.add_child(InventoryScreen._label("What needs no table: made from what you carry, kneeling where you stand.", 16, Color(0.9, 0.85, 0.75)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_note = InventoryScreen._label("", 16, Color(0.9, 0.85, 0.75))
	v.add_child(_note)


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if screen == null or screen.player == null or SurvivalBridge.find(screen.player.get_tree()) == null:
		_list.add_child(InventoryScreen._label("Nothing can be made without the survival rules.", 16, Color(0.66, 0.61, 0.52)))
		return
	for r: Dictionary in HandCraft.rows(screen.player):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ok := bool(r.ok)
		col.add_child(InventoryScreen._label(String(r.text), 19, Color(0.96, 0.9, 0.76) if ok else Color(0.66, 0.61, 0.52)))
		var d := InventoryScreen._label(String(r.detail), 15, Color(0.8, 0.76, 0.66) if ok else Color(0.9, 0.6, 0.45))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(540, 0)
		col.add_child(d)
		row.add_child(col)
		var b := Button.new()
		b.text = "Make"
		b.custom_minimum_size = Vector2(100, 36)
		b.disabled = not ok
		var id := String(r.id)
		b.pressed.connect(func() -> void: _make(id))
		row.add_child(b)
		_list.add_child(row)


func _make(id: String) -> void:
	var p := screen.player
	screen.close()
	HandCraft.make(p, id)
