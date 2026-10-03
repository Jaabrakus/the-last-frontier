class_name BagSlot
extends Control
## One slot of a bag window (BagGrid; the owner 2026-10-03, "WoW-style bags"): the stack in it drawn on its paper bed with
## its count bottom right in outlined white (BagUI.draw_slot), a drag source and a drop target. What a click, a drag or a
## drop does is its host's (`host`: the HUD's BagWindows or the character screen, InventoryScreen), asked through these:
##   slot_hover(slot, on)  slot_click(slot)  slot_shift_click(slot)  slot_right_click(slot)  slot_double_click(slot)
##   slot_drag(slot) -> Variant (the drag; null none)   slot_drop_check(slot, d) -> {ok, reason}   slot_drop(slot, d)
##   slot_icon(kind) -> Texture2D
## `bag` 0-4 (PlayerBags: 0 the haversack) and `index` its slot; `bag` LOOSE (-1): the Loose strip's stack `index`.
## A drop is always taken (so a refusal says its reason, in red, when it is let go); a drag over it lights the slot green
## when it would go, red when not.

const LOOSE := -1

var host: Object
var bag := 0
var index := 0
var kind := ""
var count := 0
## The bag's specialty ("shot", "game", "simples"; "" any): its empty slots tinted.
var holds := ""
var texture: Texture2D
## The character screen's picked thing: a gold rim.
var picked := false
## "", "ok" or "no": a drag over it now.
var drop_state := ""
var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## The stack it shows ({} empty) and its picture.
func show_stack(e: Dictionary, tex: Texture2D, spec := "") -> void:
	var k := String(e.get("kind", ""))
	var n := int(e.get("count", 0)) if k != "" else 0
	if k != kind or n != count or tex != texture or spec != holds:
		kind = k
		count = n
		texture = tex
		holds = spec
		queue_redraw()


func set_picked(on: bool) -> void:
	if on != picked:
		picked = on
		queue_redraw()


func _draw() -> void:
	var px := size.x
	BagUI.draw_slot(self, Rect2(Vector2.ZERO, size), kind, count, texture, holds, drop_state, _hover, picked, bag == LOOSE,
			13 if px >= 44.0 else 12)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hover = true
			queue_redraw()
			if host != null:
				host.call(&"slot_hover", self, true)
		NOTIFICATION_MOUSE_EXIT:
			_hover = false
			if drop_state != "":
				drop_state = ""
			queue_redraw()
			if host != null:
				host.call(&"slot_hover", self, false)
		NOTIFICATION_DRAG_END:
			if drop_state != "":
				drop_state = ""
				queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or host == null:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if mb.shift_pressed:
			host.call(&"slot_shift_click", self)
		elif mb.double_click:
			host.call(&"slot_double_click", self)
		else:
			host.call(&"slot_click", self)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		host.call(&"slot_right_click", self)


func _get_drag_data(_at: Vector2) -> Variant:
	if kind == "" or host == null:
		return null
	var d: Variant = host.call(&"slot_drag", self)
	if d == null or (d is Dictionary and (d as Dictionary).is_empty()):
		return null
	set_drag_preview(drag_preview(texture, kind, size.x))
	return d


## What follows the mouse in a drag: the picture (or the name).
static func drag_preview(tex: Texture2D, k: String, px := 40.0) -> Control:
	if tex == null:
		var l := Label.new()
		l.text = InventoryState.name_of(k.trim_prefix(BagUI.CLOTH).get_slice(".", 2) if k.begins_with(BagUI.CLOTH) else k)
		l.add_theme_color_override("font_color", ClassicSkin.INK)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		return l
	var t := TextureRect.new()
	t.texture = tex
	t.size = Vector2(px, px)
	t.position = -t.size * 0.5
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = Color(1, 1, 1, 0.85)
	var c := Control.new()
	c.add_child(t)
	return c


func _can_drop_data(_at: Vector2, d: Variant) -> bool:
	if host == null or not (d is Dictionary):
		return false
	var v: Dictionary = host.call(&"slot_drop_check", self, d)
	var st := "" if String(v.get("reason", "")) == "" and bool(v.ok) and _is_self(d) else ("ok" if bool(v.ok) else "no")
	if st != drop_state:
		drop_state = st
		queue_redraw()
	return true


func _drop_data(_at: Vector2, d: Variant) -> void:
	drop_state = ""
	queue_redraw()
	if host != null:
		host.call(&"slot_drop", self, d)


## Whether the drag is this slot's own stack.
func _is_self(d: Variant) -> bool:
	var dd := d as Dictionary
	if bag == LOOSE:
		return dd.has("loose") and int(dd.loose) == index
	return dd.has("bag") and int(dd.bag) == bag and int(dd.get("slot", -1)) == index
