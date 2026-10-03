class_name BagGrid
extends Control
## One bag's window (the owner 2026-10-03, "WoW-style bags"): a small classic window in the HUD's leather and brass
## (ClassicSkin): the title bar with the bag's picture in a brass ring at its corner, its name and its free slots, a close
## button; under it the bag's slots (BagSlot) 4 wide. `bag` LOOSE: the Loose strip, red-edged, the slow-down at its foot.
## The HUD's windows (BagWindows) stack these up from the bag bar; the character screen (InventoryScreen) lists them in
## one scrolling column, bigger and without the close button.
##   host            the slots' and the window's host (BagWindows, InventoryScreen): see BagSlot; and here
##                   grid_close(grid), grid_drag(grid) -> Variant (the title picture dragged: the bag taken off),
##                   grid_drop_check(grid, d) -> {ok, reason}, grid_drop(grid, d) (dropped on the title: into this bag)
##   refresh(bags)   the slots and the size from the bags (PlayerBags) now
## Read by the tests: bag, slots, close_rect, icon_rect.

const LOOSE := BagSlot.LOOSE
const GAP := 4.0
const PAD := 8.0
const TITLE_H := 28.0
const FOOT_H := 18.0
const RING_R := 15.0

var host: Object
var bag := 0
var slot_px := BagUI.SLOT_HUD
var closable := true
## Makes a slot (the character screen's: its PackCell).
var make_slot: Callable
var slots: Array[BagSlot] = []
var title := ""
var free_text := ""
var foot := ""
var icon: Texture2D
var holds := ""
var close_rect := Rect2()
var icon_rect := Rect2()
var drop_state := ""
var _close_hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func cols() -> int:
	return 4


## The window's size for `n` slots.
func size_for(n: int) -> Vector2:
	var c := cols()
	var rows := maxi(ceili(float(n) / float(c)), 1)
	var w := PAD * 2.0 + slot_px * c + GAP * (c - 1)
	var h := TITLE_H + 4.0 + slot_px * rows + GAP * (rows - 1) + PAD + (FOOT_H if foot != "" else 0.0)
	return Vector2(w, h)


## The slots and the title from `bags` (PlayerBags) now; `icons` gives the pictures.
func refresh(bags: PlayerBags, icons: Callable) -> void:
	var entries: Array = []
	if bag == LOOSE:
		for e: Dictionary in bags.loose:
			entries.append(e)
		title = "Loose"
		icon = null
		holds = ""
		free_text = ""
		var lc := bags.loose_slots()
		var slow := roundi((1.0 - bags.speed_mult()) * 100.0)
		foot = ("%d %% slower%s" % [slow, ", no sprint" if not bags.sprint_ok() else ""]) if lc > 0 else ""
	else:
		for i in bags.bag_size(bag):
			entries.append(bags.slot(bag, i))
		var k := bags.bag_kind(bag)
		title = bags.bag_name(bag)
		icon = icons.call(k) if icons.is_valid() and k != "" else null
		holds = bags.bag_holds(bag) if PlayerBags.is_specialty(k) else ""
		free_text = "%d free" % bags.free_slots(bag)
		foot = ""
	while slots.size() < entries.size():
		var s: BagSlot = make_slot.call() if make_slot.is_valid() else BagSlot.new()
		s.host = host
		s.bag = bag
		s.index = slots.size()
		s.size = Vector2(slot_px, slot_px)
		add_child(s)
		slots.append(s)
	while slots.size() > entries.size():
		var s: BagSlot = slots.pop_back()
		remove_child(s)
		s.queue_free()
	var c := cols()
	for i in slots.size():
		var s := slots[i]
		s.bag = bag
		s.index = i
		s.position = Vector2(PAD + float(i % c) * (slot_px + GAP), TITLE_H + 4.0 + float(i / c) * (slot_px + GAP))
		s.size = Vector2(slot_px, slot_px)
		var e: Dictionary = entries[i]
		var k2 := String(e.get("kind", ""))
		s.show_stack(e, icons.call(k2) if icons.is_valid() and k2 != "" else null, holds)
	var sz := size_for(entries.size())
	custom_minimum_size = sz
	size = sz
	close_rect = Rect2(Vector2(sz.x - 24.0, 6.0), Vector2(17, 17)) if closable else Rect2()
	icon_rect = Rect2(Vector2(PAD - 2.0, 1.0), Vector2(RING_R, RING_R) * 2.0) if bag != LOOSE else Rect2()
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	ClassicSkin.panel(self, r)
	if bag == LOOSE:
		draw_rect(r.grow(-3.0), Color(BagUI.BAD.r, BagUI.BAD.g, BagUI.BAD.b, 0.55), false, 1.5)
	# the title bar: a darker band under the brass rule, the bag's picture in a ring at its corner
	var band := Rect2(Vector2(4, 4), Vector2(size.x - 8.0, TITLE_H - 6.0))
	draw_rect(band, Color(0, 0, 0, 0.28))
	draw_line(Vector2(band.position.x, band.end.y + 0.5), Vector2(band.end.x, band.end.y + 0.5), Color(ClassicSkin.BRASS.r, ClassicSkin.BRASS.g, ClassicSkin.BRASS.b, 0.55), 1.0)
	var tx := PAD + 4.0
	if icon_rect.size.x > 0.0:
		var c := icon_rect.get_center()
		draw_circle(c, RING_R - 1.0, Color(0.6, 0.51, 0.37))
		draw_texture_rect(ClassicSkin.grain(), Rect2(c - Vector2(RING_R, RING_R) * 0.7, Vector2(RING_R, RING_R) * 1.4), true, Color(1, 1, 1, 0.3))
		if icon != null:
			ClassicSkin.fit_texture(self, icon, Rect2(c - Vector2(RING_R, RING_R), Vector2(RING_R, RING_R) * 2.0), 3.0)
		else:
			ClassicMicroMenu.draw_glyph(self, "pack" if bag == 0 else "bag", c, RING_R * 0.55, ClassicSkin.INK)
		ClassicSkin.ring(self, c, RING_R, 2.6)
		if drop_state != "":
			draw_arc(c, RING_R + 2.0, 0.0, TAU, 32, BagUI.GOOD if drop_state == "ok" else BagUI.BAD, 2.0, true)
		tx = icon_rect.end.x + 6.0
	var tc := ClassicSkin.GOLD if bag != LOOSE else BagUI.BAD.lerp(ClassicSkin.INK, 0.25)
	var right := close_rect.position.x - 6.0 if closable else size.x - PAD
	var fw := 0.0
	if free_text != "":
		fw = ClassicSkin.font().get_string_size(free_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		ClassicSkin.text_right(self, Vector2(right, 19.0), free_text, 12, ClassicSkin.DIM)
	ClassicSkin.text(self, Vector2(tx, 19.0), title, 15, tc, maxf(right - fw - 6.0 - tx, 20.0))
	if closable:
		var cr := close_rect
		ClassicSkin.socket(self, cr)
		var col := ClassicSkin.BRASS_HI if _close_hover else ClassicSkin.BRASS
		var m := cr.grow(-4.5)
		draw_line(m.position, m.end, col, 2.0, true)
		draw_line(Vector2(m.end.x, m.position.y), Vector2(m.position.x, m.end.y), col, 2.0, true)
	if foot != "":
		ClassicSkin.text_right(self, Vector2(size.x - PAD, size.y - 7.0), foot, 12, BagUI.BAD.lerp(ClassicSkin.INK, 0.3))


func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm != null:
		var on := closable and close_rect.has_point(mm.position)
		if on != _close_hover:
			_close_hover = on
			queue_redraw()
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not mb.pressed and closable and close_rect.has_point(mb.position) and host != null:
			host.call(&"grid_close", self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _close_hover:
		_close_hover = false
		queue_redraw()
	elif (what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT) and drop_state != "":
		drop_state = ""
		queue_redraw()


## The title's picture dragged: the bag (a socket's) taken off when dropped in a slot.
func _get_drag_data(at: Vector2) -> Variant:
	if host == null or bag < 1 or not icon_rect.grow(3.0).has_point(at):
		return null
	var d: Variant = host.call(&"grid_drag", self)
	if d == null or (d is Dictionary and (d as Dictionary).is_empty()):
		return null
	set_drag_preview(BagSlot.drag_preview(icon, "", 40.0))
	return d


func _can_drop_data(_at: Vector2, d: Variant) -> bool:
	if host == null or bag == LOOSE or not (d is Dictionary):
		return false
	var v: Dictionary = host.call(&"grid_drop_check", self, d)
	var st := "ok" if bool(v.ok) else "no"
	if st != drop_state:
		drop_state = st
		queue_redraw()
	return true


func _drop_data(_at: Vector2, d: Variant) -> void:
	drop_state = ""
	queue_redraw()
	if host != null:
		host.call(&"grid_drop", self, d)
