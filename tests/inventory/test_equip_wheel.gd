extends SceneTree
## The equip wheel (hold Q; user 2026-09-26): its slots (only the hotbar's, the owner 2026-10-02: "lists only hotbar
## entries"; then bare hands), picking by direction, taking a tool, a weapon and bare hands; a weapon taken off the bar
## leaves the wheel; the game at full speed throughout; no pick = no change. (The torch is T's: not on the wheel now.)
##
##   Godot --headless --path . -s tests/inventory/test_equip_wheel.gd
## "EQUIP WHEEL TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _pick(w: EquipWheel, id: String) -> bool:
	var i := -1
	for k in w.slots.size():
		if String(w.slots[k].id) == id:
			i = k
	if i < 0:
		return false
	var a := i * TAU / w.slots.size()
	w.pick_toward(Vector2(sin(a), -cos(a)) * 120.0)
	return w.sel == i


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	await _wait(90)
	var p: FrontierPlayer = current_scene.get_node("Player")
	p.set("ignore_mouse_capture", true)
	var w := p.equip_wheel
	_check(w != null, "the player has an equip wheel")
	w.open()
	_check(w.is_open and is_equal_approx(Engine.time_scale, 1.0), "open: the game runs on at full speed (%.2f)" % Engine.time_scale)
	var ids := []
	for s: Dictionary in w.slots:
		ids.append(String(s.id))
	var hb: Hotbar = p.hotbar
	var want := []
	for i in Hotbar.SLOTS:
		var e := hb.entry(i)
		if not e.is_empty():
			want.append({"weapon": "w:", "tool": "t:", "spell": "s:"}[String(e.kind)] + String(e.id))
	want.append("hands")
	_check(ids == want and ids.has("w:musket") and ids.has("t:felling_axe") and not ids.has("torch"),
			"slots: the hotbar's in order, then bare hands (%s)" % str(ids))
	w.close(false)
	var at := hb.slot_of("weapon", "bow")
	hb.clear(at)
	w.open()
	ids = []
	for s: Dictionary in w.slots:
		ids.append(String(s.id))
	_check(not ids.has("w:bow"), "the bow taken off the bar: not on the wheel (%s)" % str(ids))
	w.close(false)
	hb.assign(at, Hotbar.make("weapon", "bow"))
	w.open()
	w.pick_toward(Vector2(3, 2))
	_check(w.sel == -1, "a small mouse move picks nothing")
	w.close(true)
	_check(not w.is_open and is_equal_approx(Engine.time_scale, 1.0), "closed: still full speed")
	await _wait(30)
	var before := p.weapon_key
	_check(p.weapon_key == before and p.gather.in_hand() == "", "letting go with nothing picked changes nothing")
	# a tool
	w.open()
	_check(_pick(w, "t:felling_axe"), "the felling axe picked by direction")
	w.close(true)
	await _wait(200)
	_check(p.gather.in_hand() == "felling_axe", "taken: the felling axe in the hands (%s)" % p.gather.in_hand())
	# a weapon (the tool goes away)
	w.open()
	_check(_pick(w, "w:pistol"), "the pistol picked")
	w.close(true)
	await _wait(300)
	_check(p.weapon_key == "pistol" and not p.hands_free and p.gather.in_hand() == "", "taken: the pistol out, the tool away (%s, hands free %s)" % [p.weapon_key, p.hands_free])
	# a left click takes the pick, the pistol in the hand does not fire with it
	var pis: Weapon = p.weapons.pistol
	var st0 := str(pis.get("state"))
	var loaded0 := str(pis.get("loaded"))
	w.open()
	_check(_pick(w, "w:musket"), "the musket picked")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.action_press(&"fire")
	await _wait(6)
	_check(not w.is_open, "a left click closes the wheel")
	_check(str(pis.get("loaded")) == loaded0, "the click did not fire the pistol (loaded %s -> %s)" % [loaded0, str(pis.get("loaded"))])
	Input.action_release(&"fire")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(300)
	_check(p.weapon_key == "musket" and not p.hands_free, "taken by the click: the musket out (%s)" % p.weapon_key)
	# bare hands
	w.open()
	_check(_pick(w, "hands"), "bare hands picked")
	w.close(true)
	await _wait(200)
	_check(p.hands_free, "taken: the hands free")
	if _fails.is_empty():
		print("EQUIP WHEEL TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("EQUIP WHEEL TEST FAILED (%d of %d)" % [_fails.size(), _checks])
		quit(1)
