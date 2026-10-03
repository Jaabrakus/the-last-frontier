extends SceneTree
## A garment put on in the Tab screen is drawn in a normal start too (user 2026-10-03: "dragging a garment onto your character in
## Tab changes your warmth but not your look ... fix this"): ClothesSlots.wear puts its customizer garment in the look's slot and
## take_off gives the slot back to the basic dress.
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_tab_wear_look.gd -- survival=on

var _fails := 0
var _checks := 0


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 240:
		await physics_frame
	var b := SurvivalBridge.find(self)
	var p: FrontierPlayer = current_scene.get_node("Player")
	_expect(b != null and b.core != null and not b.is_bare(), "a normal start with the survival rules")
	# a core garment drawn as a cloth2 garment this build dresses
	var item := ""
	var garment := ""
	for id: String in b.core.data.items.keys():
		var g := ClothesSlots.garment_of(b.core, id)
		if g != "" and PlayerOutfit.usable(g) and ClothesSlots.zone_of(b.core, id) != "" and not (g in ["shirt_linen", "shift_linen", "breeches", "petticoat"]):
			item = id
			garment = g
			break
	_expect(item != "", "a core garment drawn as a new cloth2 garment (%s -> %s)" % [item, garment])
	if item == "":
		_end()
		return
	var slot := String(PlayerOutfit.entry(garment).get("slot", ""))
	SurvivalInventory.add(b.core, item, 1.0)
	var ok := ClothesSlots.wear(b, item)
	await process_frame
	var look: Dictionary = p.appearance.look
	_expect(ok, "it goes on (%s)" % item)
	_expect(String(((look.get("outfit", {}) as Dictionary).get(slot, {}) as Dictionary).get("id", "")) == garment,
			"the look's %s slot is %s now" % [slot, garment])
	var gone := ClothesSlots.take_off(b, ClothesSlots.zone_of(b.core, item))
	await process_frame
	look = p.appearance.look
	_expect(gone and not (look.get("outfit", {}) as Dictionary).has(slot), "taken off: the slot goes back to the basic dress")
	_end()


func _end() -> void:
	print("TAB WEAR LOOK TEST %s (%d checks)" % ["PASSED" if _fails == 0 else "FAILED (%d of %d)" % [_fails, _checks], _checks])
	quit()
