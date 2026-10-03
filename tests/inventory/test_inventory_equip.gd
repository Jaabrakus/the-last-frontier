extends SceneTree
## Equipping from the pack (hotfix 2026-09-26, user: "when we equip things from our pack like a musket to back we
## should be able to equip that"): the pack lists what the player carries less what is worn, worked out fresh each
## time; a musket from the pack goes on the back (InventoryState) and can be drawn. The screen (the owner 2026-10-02: "no
## more rigs on the char slots"; Hotbar): the rig places on the figure are gone (their checks retired); a musket taken
## off the hotbar is in the pack list, and dropped on the figure, or double-clicked, it goes in the first free hotbar
## slot and can be drawn.
##
##   Godot --headless --path . -s tests/inventory/test_inventory_equip.gd
##   Godot --path . --resolution 1280x720 -s tests/inventory/test_inventory_equip.gd     (real mouse drag + double-click)
##
## "INVENTORY EQUIP TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _pack_has(inv: InventoryState, kind: String) -> bool:
	return inv.pack_count(kind) > 0


func _worn_kind(inv: InventoryState, p: String) -> String:
	var it := inv.item_at(p)
	return String(it.kind) if not it.is_empty() else ""


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	for i in 10:
		await physics_frame
	var p: FrontierPlayer = current_scene.get_node("Player")
	p.set("ignore_mouse_capture", true)

	# 1) off the back into the pack, and back on at its best spot; it can be drawn
	var inv := InventoryState.from_player(p)
	_check(_worn_kind(inv, "long_A") == "musket" and not _pack_has(inv, "musket"), "start: the musket on the back sling, not in the pack")
	inv.unwear_point("long_A")
	p.apply_loadout(inv.worn, inv.pack)
	inv = InventoryState.from_player(p)
	_check(_pack_has(inv, "musket") and _worn_kind(inv, "long_A") == "", "taken off: the musket is in the pack")
	_check(inv.best_point("musket") == "long_A", "its best spot is the free back sling (%s)" % inv.best_point("musket"))
	_check(inv.wear("musket", inv.best_point("musket")), "worn from the pack")
	p.apply_loadout(inv.worn, inv.pack)
	_check(p.loadout.first_of_kind("musket").size() > 0 and p.is_usable("musket"), "on the back and drawable")

	# 2) put down in the world: not in the pack; taken again: back on the body
	p.set_carried("musket", false)
	inv = InventoryState.from_player(p)
	_check(not _pack_has(inv, "musket") and _worn_kind(inv, "long_A") != "musket", "put down: neither worn nor in the pack")
	p.set_carried("musket", true)
	inv = InventoryState.from_player(p)
	_check(_worn_kind(inv, "long_A") == "musket" or _worn_kind(inv, "long_B") == "musket" or _pack_has(inv, "musket"), "taken again: with the player")
	_check(p.is_usable("musket"), "taken again: drawable")

	# 3) a stale saved pack does not list a weapon twice; other items in it are kept
	p.inventory_pack = [{"kind": "musket", "count": 1, "state": {}}, {"kind": "powder_horn", "count": 1, "state": {"charges": 3}}]
	inv = InventoryState.from_player(p)
	var worn_musket := _worn_kind(inv, "long_A") == "musket" or _worn_kind(inv, "long_B") == "musket"
	_check(not (worn_musket and _pack_has(inv, "musket")), "a stale pack entry for a worn musket is dropped")
	_check(inv.pack_count("powder_horn") == 1, "other pack items are kept (powder horn x%d)" % inv.pack_count("powder_horn"))
	p.inventory_pack = []

	# 4) the screen: the musket off the hotbar is in the pack list; dropped on the figure, or double-clicked, it goes on the
	# bar in the first free slot (the old rig places, a back sling spot to drop on, are gone: those checks are retired)
	var hb: Hotbar = p.hotbar
	var scr := InventoryScreen.open_for(p)
	await _frames(20)
	_check(not ("_slot_cells" in scr), "screen: no rig places on the figure")
	var at := hb.slot_of("weapon", "musket")
	scr.hotbar_off(at)
	_check(hb.slot_of("weapon", "musket") < 0 and _pack_cell(scr, "musket") != null, "screen: off the hotbar, the musket is in the pack list")
	if _headless():
		_check(scr.figure._can_drop_data(Vector2.ZERO, {"from": "pack", "kind": "musket"}), "screen: the figure accepts the musket")
		scr.figure._drop_data(Vector2.ZERO, {"from": "pack", "kind": "musket"})
		_check(hb.slot_of("weapon", "musket") == hb.first_free() or hb.slot_of("weapon", "musket") >= 0,
				"screen: dropped on the figure -> on the hotbar (%d)" % hb.slot_of("weapon", "musket"))
		scr.hotbar_off(hb.slot_of("weapon", "musket"))
		scr.use_on_body("musket")
		_check(hb.slot_of("weapon", "musket") >= 0, "screen: used on the body (a double-click) -> on the hotbar")
	else:
		await _frames(10)
		var cell := _pack_cell(scr, "musket")
		var drop: Control = scr.figure
		_check(cell != null and drop != null, "screen: the musket's pack row and the figure found")
		if cell and drop:
			var a := cell.get_global_rect().get_center()
			var b := drop.get_global_rect().get_center()
			await _drag(a, b)
			_check(hb.slot_of("weapon", "musket") >= 0, "screen: dragged onto the figure with the mouse -> on the hotbar")
			scr.hotbar_off(hb.slot_of("weapon", "musket"))
			await _frames(5)
			cell = _pack_cell(scr, "musket")
			await _double_click(cell.get_global_rect().get_center())
			_check(hb.slot_of("weapon", "musket") >= 0, "screen: double-clicked in the pack -> on the hotbar")
	scr.close()
	await _frames(5)
	_check(p.is_usable("musket") and p.loadout.first_of_kind("musket").size() > 0, "closed: the musket on the back and drawable")
	p.switch_weapon("musket")
	for i in 240:
		await physics_frame
	_check(p.weapon_key == "musket", "closed: the musket drawn with its key (%s)" % p.weapon_key)

	if _fails.is_empty():
		print("INVENTORY EQUIP TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("INVENTORY EQUIP TEST FAILED (%d of %d)" % [_fails.size(), _checks])
		quit(1)


func _pack_cell(scr: InventoryScreen, kind: String) -> Control:
	for c in scr.find_children("*", "", true, false):
		if c is InventoryScreen.PackCell and (c as InventoryScreen.PackCell).kind == kind:
			return c
	return null


func _mouse(pos: Vector2, pressed: bool, dbl := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.double_click = dbl
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e)


var _last := Vector2.ZERO


func _move(pos: Vector2, held: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.relative = pos - _last          # Godot starts a drag once the relative motion adds up past its threshold
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_last = pos
	root.push_input(m)


func _drag(a: Vector2, b: Vector2) -> void:
	_move(a, false)
	await _frames(2)
	_mouse(a, true)
	await _frames(2)
	for i in 12:
		_move(a.lerp(b, float(i + 1) / 12.0), true)
		await _frames(1)
	await _frames(2)
	_mouse(b, false)
	await _frames(4)


func _double_click(a: Vector2) -> void:
	_move(a, false)
	await _frames(2)
	_mouse(a, true)
	_mouse(a, false)
	await _frames(1)
	_mouse(a, true, true)
	_mouse(a, false)
	await _frames(4)
