extends SceneTree
## A weapon's own gear goes with it (the user, 2026-10-03, with a screenshot of the player's back: "also when i unequip the
## weapons the musket sling is there and the arrow quiver is there still"; SlingRig.kit_follows, SlingRig.Entry.away), on
## the real level, headless, with its saves:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/loadout/test_kit_follows.gd -- survival=on save=on
##
##   carried    the start's kit on the hotbar, hands free: the musket on the back with its sling, the bow, the quiver with
##              its arrows and its strap, the powder horn
##   musket     the musket's slot given a spell (the user's case): the musket and its sling gone from the back; the bow and
##              the quiver stay; the horn stays (the pistol is still on the bar: the horn is the guns')
##   bow        the bow off the bar too: its quiver goes with it, arrows and strap
##   no gun     every weapon off the bar: no horn and no horn ties either; nothing left on the body, nothing floating (no
##              strap whose item is gone, nothing left in the back stack)
##   back       the musket and the bow on the bar again: both back with the musket's sling, the quiver with its arrows and
##              strap, the horn
##   put down   the bow put down in the world (FrontierPlayer.set_carried): its quiver goes too, the musket stays on the back
##              (hands free: a rig made again then put the loadout's in_hand musket in the empty hand, unseen); taken
##              again, both back
##   Tab        closed hands free, the musket stays on the back; the figure of the inventory screen: no musket, no sling and
##              no quiver while they are off the bar
##   save       the musket and the bow off the bar, 17 arrows, saved to the quick slot (SaveGame.TEST_DIR in -s runs, removed
##              at the end) and loaded (the level rebuilt): still off, no sling and no quiver; put back on the bar, both back
##              and the quiver shows its 17 arrows
## Ends with "KIT FOLLOWS TEST PASSED (<n> checks)" or "KIT FOLLOWS TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var hb: Hotbar
var sg: SaveGame


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


func _grab() -> void:
	p = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	hb = p.hotbar if p else null
	sg = SaveGame.find(self)
	if p:
		p.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()


# --- what the body shows ------------------------------------------------------------------------------------------

## Whether something of the item shows on the body: an entry not away whose copy and a unit of it are visible.
static func _shows(rig: SlingRig, id: String) -> bool:
	for e: SlingRig.Entry in rig.entries_of(id):
		if e.away or not is_instance_valid(e.holder) or not e.holder.is_visible_in_tree():
			continue
		for u in e.units:
			if (u as Node3D).is_visible_in_tree():
				return true
	return false


## The item's own straps (its sling, thong, strap or ties): Vector2i(shown, made).
static func _straps(rig: SlingRig, id: String) -> Vector2i:
	var n := Vector2i.ZERO
	for s: Dictionary in rig.straps:
		var o: SlingRig.Entry = s.owner
		if o != null and o.item_id == id:
			n.y += 1
			if (s.node as Node3D).visible:
				n.x += 1
	return n


## Arrows drawn in the quiver (0 when it does not show).
static func _arrows(rig: SlingRig) -> int:
	if not _shows(rig, "quiver"):
		return 0
	for e: SlingRig.Entry in rig.entries_of("quiver"):
		for mmi in e.root.find_children("*", "MultiMeshInstance3D", true, false):
			var mm := (mmi as MultiMeshInstance3D).multimesh
			if mm and (mmi as Node3D).is_visible_in_tree():
				return mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
	return 0


## What is left on the body of things that are gone: a strap shown whose item does not show, a copy shown of an item
## away, a point in the back stack whose item does not show.
static func _left_behind(rig: SlingRig) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in rig.straps:
		var o: SlingRig.Entry = s.owner
		if o != null and (s.node as Node3D).visible and not _shows(rig, o.item_id):
			out.append("strap %s (%s)" % [s.id, o.item_id])
	for e: SlingRig.Entry in rig.entries:
		if e.away and is_instance_valid(e.holder) and e.holder.is_visible_in_tree():
			out.append("copy of %s" % e.item_id)
	for pt: String in rig.layer_stack:
		var e := rig.entry_at(pt)
		if e == null or not _shows(rig, e.item_id):
			out.append("back stack %s" % pt)
	return out


func _state(rig: SlingRig) -> String:
	var parts := PackedStringArray()
	for id: String in ["musket", "bow", "quiver", "pistol_1", "tomahawk", "powder_horn"]:
		if not rig.entries_of(id).is_empty():
			parts.append("%s %s" % [id, "on" if _shows(rig, id) else "off"])
	for id: String in ["musket", "quiver", "powder_horn"]:
		var s := _straps(rig, id)
		parts.append("%s straps %d/%d" % [id, s.x, s.y])
	parts.append("arrows %d" % _arrows(rig))
	parts.append("stack %s" % str(rig.layer_stack))
	return ", ".join(parts)


# --- the bar ------------------------------------------------------------------------------------------------------

## The weapon `key` off the hotbar: its slot given the spell `spell` when the player has it (the user's case: spells on the
## bar), else emptied.
func _off_bar(key: String, spell := "") -> void:
	var at := hb.slot_of(Hotbar.WEAPON, key)
	if at < 0:
		return
	var sp := Hotbar.make(Hotbar.SPELL, spell)
	if spell != "" and hb.has_thing(sp) and hb.slot_of(Hotbar.SPELL, spell) < 0:
		hb.assign(at, sp)
	else:
		hb.clear(at)


## The weapon `key` back on the hotbar in slot `at` (what is there goes off the bar).
func _on_bar(key: String, at: int) -> void:
	hb.assign(at, Hotbar.make(Hotbar.WEAPON, key))


## A few rig updates (the rig updates on the skeleton's, every other frame when idle) and the bar's sync.
func _settle() -> void:
	await _physics(8)
	await _frames(2)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	await _physics(90)
	_grab()
	_expect(p != null and hb != null and sg != null, "the level has the player, its hotbar and its saves (save=on)")
	if p == null or hb == null or sg == null:
		_end()
		return
	await _physics(int(Hotbar.KIT_S * Engine.physics_ticks_per_second) + 10)
	await _carried()
	await _musket_off()
	await _bow_off()
	await _no_gun()
	await _back()
	await _put_down()
	await _tab()
	await _save_load()
	_end()


func _carried() -> void:
	for i in 80:
		if p.hands_free and not p.is_switching():
			break
		if not p.hands_free and not p.is_switching():
			hb.hands_free()
		await _physics(5)
	var rig: SlingRig = p.gear
	for i in 60:
		if rig.mode_of("musket") == SlingRig.Mode.STOWED and not rig.is_busy():
			break
		await _physics(5)
	await _settle()
	_expect(rig != null and rig.kit_follows, "the player's rig: the weapons' kit follows them (kit_follows)")
	_expect(hb.slot_of(Hotbar.WEAPON, "musket") >= 0 and hb.slot_of(Hotbar.WEAPON, "bow") >= 0 and hb.slot_of(Hotbar.WEAPON, "pistol") >= 0,
			"the start's kit on the bar: the musket, the bow, the pistol")
	_expect(p.hands_free and _shows(rig, "musket") and _straps(rig, "musket").x > 0, "carried, hands free: the musket on the back with its sling (%s)" % _state(rig))
	var bow := p.weapons.bow as Bow
	_expect(_shows(rig, "bow") and _shows(rig, "quiver") and _straps(rig, "quiver").x > 0 and _arrows(rig) == bow.quiver and bow.quiver > 0,
			"the bow, the quiver with its strap and its %d arrows (%s)" % [bow.quiver, _state(rig)])
	_expect(_shows(rig, "powder_horn"), "the powder horn (%s)" % _state(rig))
	_expect(_left_behind(rig).is_empty(), "nothing left behind (%s)" % str(_left_behind(rig)))


func _musket_off() -> void:
	_off_bar("musket", "gust")
	await _settle()
	var rig: SlingRig = p.gear
	_expect(hb.slot_of(Hotbar.WEAPON, "musket") < 0 and not p.is_usable("musket"), "the musket off the hotbar (a spell in its slot)")
	_expect(not _shows(rig, "musket") and _straps(rig, "musket").x == 0 and _straps(rig, "musket").y > 0,
			"musket not carried: no musket and no sling on the back (%s)" % _state(rig))
	_expect(_shows(rig, "bow") and _shows(rig, "quiver") and _straps(rig, "quiver").x > 0, "the bow and the quiver stay (%s)" % _state(rig))
	_expect(_shows(rig, "powder_horn"), "the horn stays: the pistol is still on the bar (%s)" % _state(rig))
	_expect(not rig.layer_stack.has("long_A"), "the musket has left the back stack: nothing rests on it (%s)" % str(rig.layer_stack))
	_expect(_left_behind(rig).is_empty(), "nothing left behind (%s)" % str(_left_behind(rig)))


func _bow_off() -> void:
	_off_bar("bow", "pillar")
	await _settle()
	var rig: SlingRig = p.gear
	_expect(not p.is_usable("bow"), "the bow off the hotbar")
	_expect(not _shows(rig, "bow") and not _shows(rig, "quiver") and _straps(rig, "quiver").x == 0 and _arrows(rig) == 0,
			"bow not carried: no quiver, no arrows, no quiver strap (%s)" % _state(rig))
	_expect(not rig.layer_stack.has("quiver") and not rig.layer_stack.has("long_B"), "and nothing of them in the back stack (%s)" % str(rig.layer_stack))
	_expect(_shows(rig, "powder_horn"), "the horn stays with the pistol (%s)" % _state(rig))
	_expect(_left_behind(rig).is_empty(), "nothing left behind (%s)" % str(_left_behind(rig)))


func _no_gun() -> void:
	for key: String in p.weapons:
		_off_bar(key)
	await _settle()
	var rig: SlingRig = p.gear
	var any := false
	for key: String in p.weapons:
		any = any or p.is_usable(key)
	_expect(not any, "every weapon off the hotbar")
	var shown: Array[String] = []
	for e: SlingRig.Entry in rig.entries:
		if _shows(rig, e.item_id):
			shown.append(e.item_id)
	_expect(shown.is_empty(), "nothing of them on the body, no horn either (%s)" % str(shown))
	var straps_on := 0
	for s: Dictionary in rig.straps:
		straps_on += 1 if (s.node as Node3D).visible else 0
	_expect(straps_on == 0 and _straps(rig, "powder_horn").x == 0, "no sling, strap or horn tie left (%d shown; %s)" % [straps_on, _state(rig)])
	_expect(rig.layer_stack.is_empty() and _left_behind(rig).is_empty(), "nothing floating, nothing in the back stack (%s, %s)" % [str(rig.layer_stack), str(_left_behind(rig))])


func _back() -> void:
	_on_bar("musket", 0)
	_on_bar("bow", 1)
	_on_bar("pistol", 2)
	await _settle()
	var rig: SlingRig = p.gear
	var bow := p.weapons.bow as Bow
	_expect(p.is_usable("musket") and p.is_usable("bow"), "the musket and the bow on the bar again")
	_expect(_shows(rig, "musket") and _straps(rig, "musket").x > 0, "the musket back on the back with its sling (%s)" % _state(rig))
	_expect(_shows(rig, "bow") and _shows(rig, "quiver") and _straps(rig, "quiver").x > 0 and _arrows(rig) == bow.quiver,
			"the bow back, the quiver with its strap and its %d arrows (%s)" % [bow.quiver, _state(rig)])
	_expect(_shows(rig, "powder_horn"), "the horn back with the guns (%s)" % _state(rig))
	_expect(rig.layer_stack.has("long_A") and rig.layer_stack.has("long_B") and rig.layer_stack.has("quiver"),
			"all three in the back stack again (%s)" % str(rig.layer_stack))
	_expect(_left_behind(rig).is_empty(), "nothing left behind (%s)" % str(_left_behind(rig)))


func _put_down() -> void:
	p.set_carried("bow", false)
	await _settle()
	var rig: SlingRig = p.gear
	_expect(not p.is_carried("bow") and rig.loadout.first_of_kind("bow").is_empty() and not rig.loadout.first_of_kind("quiver").is_empty(),
			"the bow put down: off the body's loadout, the quiver still worn")
	_expect(not _shows(rig, "quiver") and _straps(rig, "quiver").x == 0, "and its quiver goes with it (%s)" % _state(rig))
	_expect(_shows(rig, "musket") and _straps(rig, "musket").x > 0, "the musket stays with its sling (%s)" % _state(rig))
	_expect(_left_behind(rig).is_empty(), "nothing left behind (%s)" % str(_left_behind(rig)))
	p.set_carried("bow", true)
	await _settle()
	rig = p.gear
	_expect(p.is_usable("bow") and _shows(rig, "bow") and _shows(rig, "quiver") and _straps(rig, "quiver").x > 0 and _arrows(rig) > 0,
			"taken again: the bow back in its slot, the quiver with its arrows (%s)" % _state(rig))


func _tab() -> void:
	# closed with the hands free and the musket on the bar: the body's rig made again (apply_loadout) keeps it on the back
	var scr := InventoryScreen.open_for(p)
	await _frames(4)
	scr.close()
	await _settle()
	var rig: SlingRig = p.gear
	_expect(p.hands_free and _shows(rig, "musket") and _straps(rig, "musket").x > 0,
			"the Tab screen closed, hands free: the musket still on the back with its sling (%s)" % _state(rig))
	_off_bar("musket", "gust")
	_off_bar("bow", "pillar")
	await _settle()
	scr = InventoryScreen.open_for(p)
	await _frames(4)
	var fig: SlingRig = scr._rig
	_expect(fig != null and fig.kit_follows, "the Tab figure's rig follows the weapons too")
	if fig != null:
		_expect(not _shows(fig, "musket") and _straps(fig, "musket").x == 0 and not _shows(fig, "bow"),
				"the figure: no musket, no sling, no bow while off the bar (%s)" % _state(fig))
		_expect(not _shows(fig, "quiver") and _straps(fig, "quiver").x == 0, "the figure: no quiver either (%s)" % _state(fig))
		_expect(_shows(fig, "powder_horn") == _shows(p.gear, "powder_horn"), "the figure's horn as the body's (the pistol on the bar)")
		_expect(_left_behind(fig).is_empty(), "the figure: nothing left behind (%s)" % str(_left_behind(fig)))
	scr.close()
	await _physics(10)


func _save_load() -> void:
	# the state of the user's save: the long guns off the bar, spells on it; the bow's arrows down to 17
	var bow := p.weapons.bow as Bow
	bow.quiver = 17
	await _settle()
	var rig: SlingRig = p.gear
	_expect(not p.is_usable("musket") and not p.is_usable("bow") and not _shows(rig, "musket") and not _shows(rig, "quiver"),
			"before the save: the musket and the bow off the bar, not on the body (%s)" % _state(rig))
	_expect(sg.save_game("quick") == OK and SaveGame.dir() == SaveGame.TEST_DIR, "saved to the quick slot in the test folder (%s)" % SaveGame.dir())
	var doc := SaveGame.read_slot("quick")
	var lo: Dictionary = doc.get("parts", {}).get("player", {}).get("loadout", {})
	var kinds: Array = (lo.get("items", []) as Array).map(func(it: Dictionary) -> String: return String(it.kind))
	_expect(kinds.has("musket") and kinds.has("bow") and kinds.has("quiver") and Array(lo.get("gear", [])).has("horn_strap"),
			"the save's loadout is as it was: the musket, the bow and the quiver still worn, the horn strap (%s)" % str(kinds))
	# change it, then load: the save's state comes back
	_on_bar("musket", 0)
	await _settle()
	var old := sg
	_expect(sg.load_slot("quick"), "load_slot starts the load")
	for i in 60 * 12:
		await process_frame
		var s2 := SaveGame.find(self)
		if s2 != null and s2 != old and not s2.loading and s2.level != null and s2.level.is_inside_tree():
			await _frames(12)
			break
	_grab()
	await _physics(30)
	_expect(p != null and hb != null and sg != null and sg != old and not sg.loading, "a new level with the save applied")
	if p == null or hb == null:
		return
	rig = p.gear
	_expect(not p.is_usable("musket") and not p.is_usable("bow"), "loaded: the musket and the bow still off the bar")
	_expect(not _shows(rig, "musket") and _straps(rig, "musket").x == 0, "loaded: no musket and no sling on the back (%s)" % _state(rig))
	_expect(not _shows(rig, "bow") and not _shows(rig, "quiver") and _straps(rig, "quiver").x == 0, "loaded: no bow, no quiver (%s)" % _state(rig))
	_expect(_left_behind(rig).is_empty(), "loaded: nothing left behind (%s)" % str(_left_behind(rig)))
	_on_bar("musket", 0)
	_on_bar("bow", 1)
	await _settle()
	rig = p.gear
	var b2 := p.weapons.bow as Bow
	_expect(_shows(rig, "musket") and _straps(rig, "musket").x > 0, "put back on the bar: the musket with its sling (%s)" % _state(rig))
	_expect(_shows(rig, "quiver") and _straps(rig, "quiver").x > 0 and b2.quiver == 17 and _arrows(rig) == 17,
			"and the quiver with its 17 arrows (%s; the bow holds %d)" % [_state(rig), b2.quiver])
	_expect(_left_behind(rig).is_empty(), "nothing left behind (%s)" % str(_left_behind(rig)))


func _end() -> void:
	# the test's save (the quick slot in SaveGame.TEST_DIR, never the player's) goes with it
	if SaveGame.dir() == SaveGame.TEST_DIR and FileAccess.file_exists(SaveGame.TEST_DIR + "quick.json"):
		DirAccess.remove_absolute(SaveGame.TEST_DIR + "quick.json")
	if fails.is_empty():
		print("KIT FOLLOWS TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("KIT FOLLOWS TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("   - ", f)
		quit(1)
