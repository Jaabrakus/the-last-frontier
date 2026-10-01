class_name GearTab
extends RefCounted
## Her character sheet's Gear tab (user 2026-10-01: "the npc needs the same char sheet for clothing rigs and etc equipment or a inventory
## as well i can drag and drop gear on"): what she wears in each body slot (ClothesSlots, as the player's Clothes tab), the rope belt and
## sling she has on, and what she carries; beside it what the player carries that can go to her. A chip (a garment or a rope piece) is
## dragged from one list to another: onto a slot to put it on her, onto her pack to hand it over, onto the player's list to take it
## back (what is worn comes off first). A click on a chip puts it on or takes it off. Weapons and tools are the household's: they go in
## the chests and racks (the Tasks tab), and she borrows them.

const SIDE_W := 285.0

var s: HouseholdScreen
var sc: SpouseCore
var player: FrontierPlayer
var bridge: SurvivalBridge
var _note: Label


static func build(screen: HouseholdScreen) -> GearTab:
	var g := GearTab.new()
	g.s = screen
	g.sc = screen._sc()
	g.player = screen.house.player
	g.bridge = screen.house.bridge
	g._build()
	return g


# ---------------------------------------------------------------- what is where
## Garments the player carries that are not worn (core items with a clothing class).
func _yours_cloth() -> Array[String]:
	var out: Array[String] = []
	for z: String in ClothesSlots.zone_ids():
		for id: String in ClothesSlots.owned(bridge.core, z):
			if ClothesSlots.worn_in(bridge.core, z) != id and not out.has(id):
				out.append(id)
	return out


func _hers_cloth() -> Array[String]:
	var out: Array[String] = []
	for z: String in ClothesSlots.zone_ids():
		for id: String in ClothesSlots.owned(sc.core, z):
			if ClothesSlots.worn_in(sc.core, z) != id and not out.has(id):
				out.append(id)
	return out


func _yours_rope() -> Dictionary:
	var inv := InventoryState.from_player(player)
	var out := {}
	for k: String in InventoryState.GEAR_KINDS:
		if inv.pack_count(k) > 0:
			out[k] = inv.pack_count(k)
	return out


# ---------------------------------------------------------------- moves
## Moves one chip {what: "cloth" | "rope", id} between the player ("you") and her ("her"); `wear` puts it on her afterwards.
func move(chip: Dictionary, to: String, wear := false) -> bool:
	var id := String(chip.id)
	var kind := String(chip.what)
	var from := String(chip.src)
	if kind == "cloth":
		var from_core: SurvivalCore = bridge.core if from == "you" else sc.core
		var to_core: SurvivalCore = bridge.core if to == "you" else sc.core
		if from != to:
			var zone := ClothesSlots.zone_of(from_core, id)
			if from == "you":
				if ClothesSlots.worn_in(bridge.core, zone) == id:
					ClothesSlots.take_off(bridge, zone)
			else:
				if ClothesSlots.worn_in(sc.core, zone) == id:
					ClothesSlots.take_off_worker(sc, zone)
			if SurvivalInventory.remove(from_core, id, 1.0).is_empty():
				return false
			SurvivalInventory.add(to_core, id, 1.0)
		if to == "her" and wear:
			ClothesSlots.wear_worker(sc, id)
		_dress()
		return true
	if kind == "rope":
		if from != to:
			if from == "you":
				var inv := InventoryState.from_player(player)
				if inv.take(id, 1) < 1:
					return false
				player.inventory_pack = inv.pack.duplicate(true)
				sc.rope_bag[id] = int(sc.rope_bag.get(id, 0)) + 1
			else:
				if sc.rope_worn.has(id):
					sc.rope_worn.erase(id)
				elif int(sc.rope_bag.get(id, 0)) < 1:
					return false
				else:
					sc.rope_bag[id] = int(sc.rope_bag[id]) - 1
				var inv2 := InventoryState.from_player(player)
				inv2.add(id, 1)
				player.inventory_pack = inv2.pack.duplicate(true)
		if to == "her" and wear:
			_wear_rope(id)
		_dress()
		return true
	return false


## The full customizer (face, skin, hair, people) on her look; on Apply her body is dressed again. In a start with nothing the
## clothes she has on stay what she wears (nothing she does not own is put on her by the customizer).
func customize() -> void:
	var tree := s.get_tree()
	CustomizerOverlay.edit(sc.look, func(result: Dictionary) -> void:
		if not result.is_empty():
			sc.look = AppearanceStore.validate(result)
			if sc.bare:
				ClothesSlots.sync_worker(sc)
			var b := s.house.body_of(sc)
			if b != null:
				b.redress()
			s._show("gear"), tree)


func _wear_rope(id: String) -> void:
	if sc.rope_worn.has(id) or int(sc.rope_bag.get(id, 0)) < 1:
		return
	sc.rope_bag[id] = int(sc.rope_bag[id]) - 1
	sc.rope_worn.append(id)


func _take_off_rope(id: String) -> void:
	if sc.rope_worn.has(id):
		sc.rope_worn.erase(id)
		sc.rope_bag[id] = int(sc.rope_bag.get(id, 0)) + 1


## Her body and her belt rig follow what she has on.
func _dress() -> void:
	ClothesSlots.sync_worker(sc, s.house.body_of(sc))
	var b := s.house.body_of(sc)
	if b != null:
		var wg := WorkerGear.of(b)
		if wg != null:
			wg.refresh(true)


func toggle(chip: Dictionary) -> void:
	var id := String(chip.id)
	if String(chip.what) == "cloth":
		var zone := ClothesSlots.zone_of(sc.core, id)
		if ClothesSlots.worn_in(sc.core, zone) == id:
			ClothesSlots.take_off_worker(sc, zone)
		else:
			ClothesSlots.wear_worker(sc, id)
	else:
		if sc.rope_worn.has(id):
			_take_off_rope(id)
		else:
			_wear_rope(id)
	_dress()


# ---------------------------------------------------------------- the tab
func _build() -> void:
	if bridge == null or bridge.core == null:
		s._wrapped("There is nothing to carry yet.", 15, HouseholdScreen.DIM)
		return
	var cust := s._button("Customize %s's look…" % sc.name, 240)
	cust.pressed.connect(customize)
	s._content.add_child(cust)
	s._wrapped("Drag a garment or a rope piece between the lists, or onto a slot. Click one on her to put it on or take it off. Tools and arms go in the chests and racks: she borrows them.", 14, HouseholdScreen.DIM)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	s._content.add_child(cols)
	# her side: the slots and her pack
	var her := VBoxContainer.new()
	her.custom_minimum_size = Vector2(SIDE_W + 40, 0)
	her.add_theme_constant_override("separation", 6)
	cols.add_child(her)
	her.add_child(s._label("%s wears" % sc.name, 17, HouseholdScreen.HEAD))
	for z: Dictionary in ClothesSlots.ZONES:
		her.add_child(_slot_row(String(z.id), String(z.name)))
	her.add_child(s._label("Rope gear on", 15, HouseholdScreen.DIM))
	var rope_on := _zone("her", "wear_rope")
	for k: String in sc.rope_worn:
		rope_on.add_child(_chip({"what": "rope", "id": k, "src": "her"}, true))
	her.add_child(rope_on)
	her.add_child(s._label("%s carries" % sc.name, 15, HouseholdScreen.DIM))
	var pack := _zone("her", "pack")
	for id: String in _hers_cloth():
		pack.add_child(_chip({"what": "cloth", "id": id, "src": "her"}, false))
	for k: String in sc.rope_bag:
		for i in int(sc.rope_bag[k]):
			pack.add_child(_chip({"what": "rope", "id": k, "src": "her"}, false))
	her.add_child(pack)
	# the player's side
	var you := VBoxContainer.new()
	you.custom_minimum_size = Vector2(SIDE_W, 0)
	you.add_theme_constant_override("separation", 6)
	cols.add_child(you)
	you.add_child(s._label("You carry", 17, HouseholdScreen.HEAD))
	var mine := _zone("you", "pack")
	mine.custom_minimum_size = Vector2(SIDE_W, 140)
	for id: String in _yours_cloth():
		mine.add_child(_chip({"what": "cloth", "id": id, "src": "you"}, false))
	var rope := _yours_rope()
	for k: String in rope:
		for i in int(rope[k]):
			mine.add_child(_chip({"what": "rope", "id": k, "src": "you"}, false))
	you.add_child(mine)
	_note = s._label("", 14, HouseholdScreen.TEXT)
	s._content.add_child(_note)


func _slot_row(zone: String, nm: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := s._label(nm, 15, HouseholdScreen.TEXT)
	l.custom_minimum_size = Vector2(62, 0)
	row.add_child(l)
	var z := _zone("her", "slot", zone)
	z.custom_minimum_size = Vector2(SIDE_W - 60, 34)
	var worn := ClothesSlots.worn_in(sc.core, zone)
	if worn != "":
		z.add_child(_chip({"what": "cloth", "id": worn, "src": "her"}, true))
	else:
		z.add_child(s._label("nothing", 14, HouseholdScreen.DIM))
	row.add_child(z)
	return row


func _zone(owner_side: String, kind: String, slot := "") -> GearDrop:
	var z := GearDrop.new()
	z.tab = self
	z.side = owner_side
	z.kind = kind
	z.slot = slot
	return z


func _chip(chip: Dictionary, worn: bool) -> Control:
	var c := GearChip.new()
	c.tab = self
	c.chip = chip
	var id := String(chip.id)
	var nm: String
	if String(chip.what) == "cloth":
		nm = ClothesSlots.name_of(bridge.core, id)
	else:
		nm = InventoryState.name_of(id)
	c.text = nm
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 15)
	c.custom_minimum_size = Vector2(0, 30)
	c.modulate = HouseholdScreen.LIT if worn else Color.WHITE
	if String(chip.src) == "her":
		c.pressed.connect(func() -> void:
			toggle(chip)
			s._show("gear"))
	return c


func say(t: String) -> void:
	if _note:
		_note.text = t


## A button that is dragged.
class GearChip extends Button:
	var tab: GearTab
	var chip := {}

	func _get_drag_data(_at: Vector2) -> Variant:
		var p := Button.new()
		p.text = text
		p.add_theme_font_size_override("font_size", 15)
		set_drag_preview(p)
		return chip


## Where chips are dropped: a body slot or her pack ("her"), the player's list ("you").
class GearDrop extends HFlowContainer:
	var tab: GearTab
	var side := ""
	var kind := ""
	var slot := ""

	func _init() -> void:
		add_theme_constant_override("h_separation", 6)
		add_theme_constant_override("v_separation", 6)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		if not (d is Dictionary) or not (d as Dictionary).has("what"):
			return false
		var c := d as Dictionary
		if kind == "slot":
			return String(c.what) == "cloth" and ClothesSlots.zone_of(tab.sc.core if String(c.src) == "her" else tab.bridge.core, String(c.id)) == slot
		if kind == "wear_rope":
			return String(c.what) == "rope"
		return true

	func _drop_data(_at: Vector2, d: Variant) -> void:
		var c := d as Dictionary
		var wear := kind == "slot" or kind == "wear_rope"
		if side == "her" and not wear and String(c.src) == "her":
			# dropped on her own pack: it comes off
			if String(c.what) == "cloth":
				var z := ClothesSlots.zone_of(tab.sc.core, String(c.id))
				if ClothesSlots.worn_in(tab.sc.core, z) == String(c.id):
					ClothesSlots.take_off_worker(tab.sc, z)
			else:
				tab._take_off_rope(String(c.id))
			tab._dress()
		elif not tab.move(c, side, wear):
			tab.say("That could not be moved.")
			return
		tab.s._show("gear")
