extends SceneTree
## The hotbar (Hotbar, scripts/ui/hotbar.gd; user 2026-10-02: "instead of equipment rigs for slot items we take the
## minecraft approach ... if nothing is equipped then nothing shows in the toolbar"; the owner the same day: "pickups
## shouldnt auto fill") on the real level, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_hotbar.gd -- survival=on
##
##   keys       weapon_1..weapon_9 bound to 1-9; 7 and 8 no longer on the tool and fishing buttons
##   start      a new game's kit is placed once: the musket, the bow, the pistol, the felling axe, the saber first, then
##              the rest the start owns in the old order; once placed, a slot emptied stays empty (nothing refills it); a
##              weapon kept off the bar is not drawn and not on the body, nor the axe on the pack's loop
##   empty      a start with nothing (BareStart): an empty bar, nothing at all on the HUD
##   no fill    a musket picked up goes to the pack, not onto the bar: not drawable, key 1 draws nothing; dragged onto
##              slot 1 key 1 draws it. A tool given goes to the pack: not taken out (the remapped tool button and E pass
##              it by); put in slot 2 its key takes it out, its key again puts it away; the HUD shows only 1 and 2
##   lost       the musket put down: slot 1 empties; picked up again it goes back to slot 1 (not a new thing)
##   Tab        the inventory screen's row: an item pointed at and a number puts it there (moving it); a slot dropped on
##              another swaps; an item dragged from the pack onto a slot moves it; a slot dropped on the pack takes it
##              off (not drawable), pointed at and a number puts it back
##   wheel      the mouse wheel steps over the empty slots, round again
##   save       the player part keeps the slots (through JSON, as SaveGame writes); a save from before the bar gets the kit
##   spell      a spell granted is not put on the bar; dragged from the Spells list onto slot 9 its key readies it
##              (SwayCaster.ready_spell, spell_selected), the hands free, the HUD's line names it; its key again puts it
##              down
##   bar only   spells are readied only from the bar (the real caster): a grant readies nothing, a spell off the bar cannot
##              be readied (ready_spell false); on it the caster's ready is the bar's selected slot; a weapon taken from the
##              bar puts it down, the caster's too; taken off the bar it is put down and cannot be readied again
## Ends with "HOTBAR TEST PASSED (<n> checks)" or "HOTBAR TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var hb: Hotbar
var hud: FrontierHUD
var spells: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	root.push_input(e)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	root.push_input(r)


func _wheel(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	root.push_input(e)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	root.push_input(r)


func _is(i: int, kind: String, id: String) -> bool:
	var e := hb.entry(i)
	return String(e.get("kind", "")) == kind and String(e.get("id", "")) == id


func _layout() -> String:
	var parts := PackedStringArray()
	for i in Hotbar.SLOTS:
		var e := hb.entry(i)
		parts.append("%d:%s" % [i + 1, "-" if e.is_empty() else String(e.id)])
	return " ".join(parts)


## The HUD strip's visible slots: [[number, kind, active]].
func _strip() -> Array:
	var out := []
	for box: Array in hud._slot_boxes:
		var ov: Control = box[0]
		if ov.visible:
			out.append([(box[2] as Label).text, str((box[1] as TextureRect).get_meta(&"kind", "")), bool(ov.get_meta(&"active", false))])
	return out


func _has_action_key(action: StringName, key: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ((ev as InputEventKey).physical_keycode == key or (ev as InputEventKey).keycode == key):
			return true
	return false


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	await _physics(90)
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	var b := SurvivalBridge.find(self)
	_expect(p != null and b != null, "the level has the player and the survival bridge")
	if p == null or b == null:
		_end()
		return
	p.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	await _physics(10)
	hb = p.hotbar
	hud = p.hud
	_expect(hb != null and hb == Hotbar.of(p) and hud != null, "the player has its hotbar (Hotbar.of) and the HUD")
	if hb == null or hud == null:
		_end()
		return
	hb.spell_selected.connect(func(id: String) -> void: spells.append(id))
	await _keys()
	await _start_kit()
	await _empty(b)
	await _no_fill()
	await _lost()
	await _tab()
	await _wheel_steps()
	await _save_load()
	await _spell()
	await _spell_rule()
	_end()


func _keys() -> void:
	var bound := true
	for i in range(1, 10):
		bound = bound and _has_action_key(StringName("weapon_%d" % i), KEY_0 + i)
	_expect(bound, "weapon_1..weapon_9 are on the keys 1-9")
	_expect(not _has_action_key(&"tool_cycle", KEY_7) and not _has_action_key(&"fish_gear", KEY_8),
			"7 and 8 are the hotbar's only (not the tool or the fishing button)")


func _start_kit() -> void:
	await _physics(int(Hotbar.KIT_S * Engine.physics_ticks_per_second) + 10)
	_expect(hb.kit_placed, "the start's kit is placed (after KIT_S)")
	# what the start owns: the five first, in the owner's order, then the rest in the old order
	var have := hb._candidates()
	var want: Array[String] = []
	for pair: Array in Hotbar.START_ORDER:
		for e: Dictionary in have:
			if String(e.kind) == String(pair[0]) and String(e.id) == String(pair[1]):
				want.append(Hotbar.key_of(e))
	for e: Dictionary in have:
		if not want.has(Hotbar.key_of(e)):
			want.append(Hotbar.key_of(e))
	var got: Array[String] = []
	for i in Hotbar.SLOTS:
		if hb.filled(i):
			got.append(Hotbar.key_of(hb.entry(i)))
	_expect(got == want.slice(0, Hotbar.SLOTS), "a new game: the kit in order (%s)" % _layout())
	_expect(_is(0, "weapon", "musket") and _is(1, "weapon", "bow") and _is(2, "weapon", "pistol") and _is(3, "tool", "felling_axe"),
			"1 musket, 2 bow, 3 pistol, 4 felling axe (%s)" % _layout())
	if hb.has_thing(Hotbar.make("tool", "saber")):
		_expect(_is(4, "tool", "saber"), "5 the saber (%s)" % _layout())
	# placed once: an emptied slot stays empty
	var mattock := hb.slot_of("tool", "mattock")
	if mattock >= 0:
		hb.clear(mattock)
		await _physics(30)
		_expect(not hb.filled(mattock) and hb.slot_of("tool", "mattock") < 0, "the mattock taken off: nothing puts it back (%s)" % _layout())
		_expect(not Hotbar.allows_tool_of(p, "mattock"), "and off the bar it is not taken out")
		hb.assign(mattock, Hotbar.make("tool", "mattock"))
	# a weapon kept off the bar: not drawn, not on the body
	var rig: SlingRig = p.gear
	var bow_id := rig.item_for_key("bow") if rig else ""
	var bow_at := hb.slot_of("weapon", "bow")
	hb.clear(bow_at)
	await _physics(4)
	_expect(not p.is_usable("bow") and hb.slot_of("weapon", "bow") < 0, "the bow off the bar cannot be drawn")
	if bow_id != "":
		_expect(rig._absent.has(bow_id), "and its copy on the body is hidden (%s)" % bow_id)
	p.switch_weapon("bow")
	await _physics(2)
	_expect(p.weapon_key != "bow", "switch_weapon refuses it (%s in the hands)" % p.weapon_key)
	hb.assign(bow_at, Hotbar.make("weapon", "bow"))
	await _physics(4)
	_expect(p.is_usable("bow") and _is(bow_at, "weapon", "bow"), "put back in its slot: usable again")
	if bow_id != "":
		_expect(not rig._absent.has(bow_id), "and on the body again")
	var g := p.gather
	if g.on_loop != "" and g._socket_back != null:
		var at := hb.slot_of("tool", g.on_loop)
		hb.clear(at)
		await _physics(4)
		_expect(not g._socket_back.visible, "the %s on the pack's loop is hidden while off the bar" % g.on_loop)
		hb.assign(at, Hotbar.make("tool", g.on_loop))
		await _physics(4)
		_expect(g._socket_back.visible, "and shows again when put back")


func _empty(b: SurvivalBridge) -> void:
	BareStart.apply(b)
	await _physics(12)
	await _frames(3)
	_expect(hb.is_empty() and hb.away.is_empty(), "a start with nothing: the hotbar is empty, no slot kept (%s)" % _layout())
	_expect(_strip().is_empty() and not hud._slots_box.visible, "and the HUD shows nothing at all bottom right (%s)" % str(_strip()))


func _no_fill() -> void:
	p.set_carried("musket", true)
	await _physics(6)
	await _frames(2)
	var inv := InventoryState.from_player(p)
	var with_me := inv.pack_count("musket") > 0 or not inv.worn.first_of_kind("musket").is_empty()
	_expect(hb.is_empty() and with_me, "a musket picked up goes to the pack, not onto the bar (%s)" % _layout())
	_expect(not p.is_usable("musket"), "off the bar it cannot be drawn")
	_key(KEY_1)
	await _physics(30)
	_expect(p.hands_free or p.weapon_key != "musket" or not p.weapon.active, "key 1 (an empty slot) draws nothing")
	_expect(hb.assign(0, Hotbar.make("weapon", "musket")) and _is(0, "weapon", "musket"), "dragged onto slot 1 (%s)" % _layout())
	await _frames(2)
	_expect(str(_strip()) == str([["1", "musket", false]]), "the HUD shows just it, numbered 1 (%s)" % str(_strip()))
	_key(KEY_1)
	await _physics(120)
	await _frames(2)
	_expect(p.weapon_key == "musket" and not p.hands_free and p.weapon != null and p.weapon.active,
			"key 1 draws it (%s, hands free %s)" % [p.weapon_key, p.hands_free])
	_expect(hb.selected() == 0 and str(_strip()) == str([["1", "musket", true]]), "its slot bright with the gold rule (%s)" % str(_strip()))
	p.gather.give("felling_axe", 1)
	await _physics(6)
	_expect(hb.slot_of("tool", "felling_axe") < 0 and p.gather.owns("felling_axe"), "a tool given goes to the pack, not the bar (%s)" % _layout())
	_expect(not Hotbar.allows_tool_of(p, "felling_axe"), "off the bar: E at a tree and the tool button pass it by")
	p.gather.tools_cycle()
	await _physics(10)
	_expect(p.gather.tool == "", "the tool button takes nothing out (%s)" % p.gather.tool)
	hb.assign(1, Hotbar.make("tool", "felling_axe"))
	_expect(_is(1, "tool", "felling_axe"), "dragged onto slot 2 (%s)" % _layout())
	_key(KEY_2)
	await _physics(200)
	_expect(p.gather.in_hand() == "felling_axe" and hb.selected() == 1, "key 2 takes it out (%s, selected %d)" % [p.gather.in_hand(), hb.selected()])
	_key(KEY_2)
	await _physics(120)
	_expect(p.gather.in_hand() == "" and p.hands_free and hb.selected() == -1,
			"key 2 again: put away, hands free (%s, selected %d)" % [p.gather.in_hand(), hb.selected()])
	await _frames(2)
	_expect(str(_strip()) == str([["1", "musket", false], ["2", "felling_axe", false]]), "the HUD: 1 and 2, neither bright (%s)" % str(_strip()))


func _lost() -> void:
	p.set_carried("musket", false)
	await _physics(6)
	_expect(not hb.filled(0) and hb.away.has("weapon:musket"), "the musket put down: slot 1 empties, kept for it (%s)" % _layout())
	p.set_carried("musket", true)
	await _physics(6)
	_expect(_is(0, "weapon", "musket"), "picked up again: back in slot 1 (%s)" % _layout())


func _tab() -> void:
	var scr := InventoryScreen.open_for(p)
	await _frames(4)
	_expect(scr._hotbar_row != null and scr._hotbar_row.visible and scr._hotbar_row.cells.size() == 9,
			"the inventory screen has the hotbar row, nine slots")
	_expect(scr._hotbar_row.cells[0].kind == "musket" and scr._hotbar_row.cells[1].kind == "felling_axe",
			"the row shows the musket and the axe in 1 and 2")
	scr.hover("musket")
	_key(KEY_5)
	_expect(_is(4, "weapon", "musket") and hb.entry(0).is_empty(), "the musket pointed at and 5: moved to slot 5 (%s)" % _layout())
	scr.hover("")
	scr._hotbar_row.cells[2]._drop_data(Vector2.ZERO, {"from": "hotbar", "slot": 4})
	_expect(_is(2, "weapon", "musket") and hb.entry(4).is_empty(), "slot 5 dropped on slot 3: moved (%s)" % _layout())
	scr._hotbar_row.cells[3]._drop_data(Vector2.ZERO, {"from": "hotbar", "slot": 1})
	scr._hotbar_row.cells[3]._drop_data(Vector2.ZERO, {"from": "hotbar", "slot": 2})
	_expect(_is(3, "weapon", "musket") and _is(2, "tool", "felling_axe"), "slot 3 dropped on slot 4 (the axe there): swapped (%s)" % _layout())
	scr._hotbar_row.cells[2]._drop_data(Vector2.ZERO, {"from": "hotbar", "slot": 3})
	var pk := {"from": "pack", "kind": "felling_axe"}
	_expect(scr._hotbar_row.cells[6]._can_drop_data(Vector2.ZERO, pk), "the axe dragged from the pack may drop on slot 7")
	scr._hotbar_row.cells[6]._drop_data(Vector2.ZERO, pk)
	_expect(_is(6, "tool", "felling_axe") and hb.slot_of("tool", "felling_axe") == 6, "dropped there: the axe in slot 7 (%s)" % _layout())
	_expect(not scr._hotbar_row.cells[0]._can_drop_data(Vector2.ZERO, {"from": "pack", "kind": "venison"}),
			"venison does not go on the hotbar")
	scr._list_drop(Vector2.ZERO, {"from": "hotbar", "slot": hb.slot_of("weapon", "musket")})
	_expect(hb.slot_of("weapon", "musket") < 0 and not p.is_usable("musket"), "the musket's slot dropped on the pack: off the bar, not drawable")
	await _frames(2)
	var listed := scr.pack_rows().any(func(e: Dictionary) -> bool: return String(e.kind) == "musket")
	_expect(listed, "and the pack lists it")
	scr.hover("musket")
	_key(KEY_3)
	scr.hover("")
	_expect(_is(2, "weapon", "musket") and p.is_usable("musket"), "pointed at and 3: back on the bar, drawable (%s)" % _layout())
	scr.close()
	await _physics(30)


func _wheel_steps() -> void:
	_key(KEY_3)
	await _physics(120)
	_expect(p.weapon_key == "musket" and not p.hands_free and hb.selected() == 2, "key 3: the musket drawn (selected %d)" % hb.selected())
	_wheel(&"weapon_next")
	_expect(hb.cursor == 6 and p.gather.tool == "felling_axe", "the wheel steps over 4-6 to the axe in 7 (cursor %d, %s)" % [hb.cursor, p.gather.tool])
	await _physics(200)
	_expect(p.gather.in_hand() == "felling_axe", "the axe out (%s)" % p.gather.in_hand())
	_wheel(&"weapon_next")
	_expect(hb.cursor == 2, "again: over 8, 9, 1 and 2, round to the musket in 3 (cursor %d)" % hb.cursor)
	await _physics(160)
	_expect(p.weapon_key == "musket" and not p.hands_free and p.gather.in_hand() == "", "the musket in the hands again (%s, hands free %s, tool %s)"
			% [p.weapon_key, p.hands_free, p.gather.in_hand()])
	_wheel(&"weapon_prev")
	_expect(hb.cursor == 6, "back the other way: the axe again (cursor %d)" % hb.cursor)
	await _physics(200)


func _save_load() -> void:
	var d: Dictionary = JSON.parse_string(JSON.stringify(SaveParts.plain(SaveParts.save_player(current_scene))))
	_expect(d.has("hotbar") and (d.hotbar.slots as Array).size() == 9 and bool(d.hotbar.get("kit", false)),
			"the player part has the hotbar's nine slots")
	hb.clear(2)
	hb.clear(6)
	hb.assign(0, Hotbar.make("weapon", "musket"))
	_expect(_is(0, "weapon", "musket") and hb.entry(6).is_empty(), "the bar changed (%s)" % _layout())
	SaveParts.load_player(current_scene, d)
	await _physics(10)
	_expect(_is(2, "weapon", "musket") and _is(6, "tool", "felling_axe") and hb.entry(0).is_empty(), "loaded: as saved, 3 and 7 (%s)" % _layout())
	_expect(hb.kit_placed, "a loaded bar is the player's: no kit laid over it")
	# a save from before the bar: its kit, from what it has
	var old := d.duplicate(true)
	old.erase("hotbar")
	SaveParts.load_player(current_scene, old)
	await _physics(int(Hotbar.KIT_S * Engine.physics_ticks_per_second) + 10)
	_expect(hb.kit_placed and _is(0, "weapon", "musket") and _is(1, "tool", "felling_axe"),
			"a save from before the bar: the kit from what it has, the musket then the axe (%s)" % _layout())
	SaveParts.load_player(current_scene, d)
	await _physics(10)


func _spell() -> void:
	# a stand-in caster with ready_spell, when the level has none
	var stub: Node = null
	var real := p.get_node_or_null("SwayCaster")
	if real == null:
		var gs := GDScript.new()
		gs.source_code = "extends Node\nvar got: Array = []\nfunc ready_spell(id: String) -> void:\n\tgot.append(id)\n"
		gs.reload()
		stub = Node.new()
		stub.set_script(gs)
		stub.name = "SwayCaster"
		p.add_child(stub)
	elif real.has_method(&"grant"):
		real.call(&"grant", "gust")
		await _physics(6)
		_expect(hb.slot_of("spell", "gust") < 0, "a spell granted is not put on the bar (%s)" % _layout())
	var scr := InventoryScreen.open_for(p)
	await _frames(4)
	var row := {"from": "spell", "id": "gust"}
	_expect(scr._hotbar_row.cells[8]._can_drop_data(Vector2.ZERO, row), "the spell dragged from the Spells list may drop on slot 9")
	scr._hotbar_row.cells[8]._drop_data(Vector2.ZERO, row)
	_expect(_is(8, "spell", "gust"), "dropped there: gust in slot 9 (%s)" % _layout())
	scr.close()
	await _physics(4)
	await _frames(2)
	var strip := _strip()
	_expect(strip.size() == 3 and strip[2][0] == "9" and String(strip[2][1]) == "spell:gust", "the HUD: 3, 7 and the spell in 9 (%s)" % str(strip))
	spells.clear()
	_key(KEY_9)
	_expect(str(spells) == str(["gust"]) and hb.spell == "gust" and hb.selected() == 8, "key 9 readies it: spell_selected(gust) (%s)" % str(spells))
	if stub != null:
		_expect(str(stub.get("got")) == str(["gust"]), "and the caster's ready_spell(gust) (%s)" % str(stub.get("got")))
	elif real.has_method(&"ready_spell"):
		_expect(String(real.get("readied_spell")) == "gust", "and the caster's spell readied (%s)" % str(real.get("readied_spell")))
	await _physics(120)
	await _frames(2)
	_expect(p.hands_free and p.gather.in_hand() == "" and hb.spell == "gust", "the hands free for it, still readied (hands free %s)" % p.hands_free)
	_expect(hud._ammo.visible and hud._ammo.text.begins_with("Gust"), "the HUD's line names it (%s)" % hud._ammo.text)
	_key(KEY_9)
	_expect(str(spells) == str(["gust", ""]) and hb.spell == "" and hb.selected() == -1, "key 9 again puts it down (%s)" % str(spells))
	if stub != null:
		_expect(str(stub.get("got")) == str(["gust", ""]), "the caster told too")
		stub.free()


func _spell_rule() -> void:
	hb.clear(8)                                 # (the stand-in's Gust off the bar)
	var c := SwayCaster.install(p)
	c.grant("gust")
	await _physics(4)
	_expect(c.readied_spell == "" and not c.ready_spell("gust") and c.readied_spell == "",
			"bar only: the grant readies nothing, and Gust off the bar cannot be readied (%s)" % _layout())
	hb.assign(8, Hotbar.make(Hotbar.SPELL, "gust"))
	await _physics(2)
	var ok := c.ready_spell("gust")
	await _physics(2)
	_expect(ok and c.readied_spell == "gust" and hb.spell == "gust" and hb.selected() == 8,
			"bar only: on slot 9 it is readied, and the bar follows the caster (selected %d)" % hb.selected())
	_key(KEY_3)
	await _physics(4)
	_expect(c.readied_spell == "" and hb.spell == "" and not p.has_meta(SwayCaster.SPELL_META),
			"bar only: a weapon taken from the bar (key 3) puts the spell down, the caster's too")
	for i in 60:
		await _physics(5)
		if not p.is_switching():
			break
	hb.hands_free()
	for i in 60:
		await _physics(5)
		if p.hands_free and not p.is_switching():
			break
	_key(KEY_9)
	await _physics(4)
	_expect(c.readied_spell == "gust" and hb.selected() == 8, "bar only: key 9 readies it again")
	hb.clear(8)
	await _physics(4)
	_expect(c.readied_spell == "" and hb.spell == "" and not c.ready_spell("gust"),
			"bar only: taken off the bar it is put down and cannot be readied again")


func _end() -> void:
	if fails.is_empty():
		print("HOTBAR TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("HOTBAR TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("   - ", f)
		quit(1)
