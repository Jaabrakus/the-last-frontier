class_name ClothesSlots
extends RefCounted
## What a character wears, slot by slot (user 2026-10-01: "when we turn bare on ... we need to allow the players to add clothes slots
## in the tab"): the survival core's worn garments (SurvivalInventory.wear / take_off: the warmth) in eight body slots, the Clothes tab
## of the character screen (ClothesPanel) over them. Each garment is a core item with a clothing class (items.json clothing_classes:
## its insulation by body zone and the customizer garments it is drawn as); its slot is where the first of those garments goes
## (PlayerOutfit catalog "slot"): a shirt, a frock on the body; breeches, leggings on the legs; moccasins the feet; a cap the head;
## mitts the hands; a robe, a matchcoat the wrap.
## A start with nothing wears what it makes: its look is dressed from the worn garments (sync_look), so it is as naked as it is
## clothed. A normal start keeps the look the creator chose, and a garment put on or taken off in the Tab screen changes that
## slot of it (_look_slot).

## (2026-10-03: the shoulder and arms slots of PlayerOutfit, a harness or bandolier and bracers or arm bands, have their
## places on the figure too; in the panel's order: the first half down the left of the figure, the rest down the right.)
const ZONES := [
	{"id": "head", "name": "Head", "slots": ["head"]},
	{"id": "shoulder", "name": "Shoulders", "slots": ["accessories.shoulder"]},
	{"id": "body", "name": "Body", "slots": ["shirt", "vest", "outer"]},
	{"id": "legs", "name": "Legs", "slots": ["legs.lower", "legs.over"]},
	{"id": "arms", "name": "Arms", "slots": ["accessories.arms"]},
	{"id": "hands", "name": "Hands", "slots": ["accessories.hands"]},
	{"id": "feet", "name": "Feet", "slots": ["feet"]},
	{"id": "wrap", "name": "Wrap", "slots": ["accessories.wrap"]},
]
const ZONE_OF_INS := {"torso": "body", "legs": "legs", "feet": "feet", "hands": "hands", "head": "head"}
## Garments worn over the rest, in the wrap slot, whatever their warmth zone.
const WRAPS := ["clothing.fur_robe", "clothing.matchcoat"]


static func zone_ids() -> Array:
	return ZONES.map(func(z: Dictionary) -> String: return String(z.id))


static func zone_name(zone: String) -> String:
	for z: Dictionary in ZONES:
		if String(z.id) == zone:
			return String(z.name)
	return zone


static func _class_of(core: SurvivalCore, item_id: String) -> Dictionary:
	var cls := String(core.data.item(item_id).get("clothing", ""))
	return core.data.clothing.get(cls, {}) as Dictionary


## The customizer garment a core clothing item is drawn as: its own name when the class has it, else the class's first this build has.
static func garment_of(core: SurvivalCore, item_id: String) -> String:
	var c := _class_of(core, item_id)
	var gl: Array = c.get("garments", [])
	var own := item_id.trim_prefix("item.cloth.")
	if gl.has(own) and PlayerOutfit.usable(own):
		return own
	for g in gl:
		if PlayerOutfit.usable(String(g)):
			return String(g)
	return ""


## The slot zone of a clothing item ("" when it is not a garment).
static func zone_of(core: SurvivalCore, item_id: String) -> String:
	var c := _class_of(core, item_id)
	if c.is_empty():
		return ""
	if WRAPS.has(String(c.id)):
		return "wrap"
	var g := garment_of(core, item_id)
	if g != "":
		var slot := String(PlayerOutfit.entry(g).get("slot", ""))
		for z: Dictionary in ZONES:
			if (z.slots as Array).has(slot):
				return String(z.id)
	# (no garment this build draws: by the warmth zone with the most insulation)
	var best := ""
	var bv := -1.0
	for k: String in (c.get("ins", {}) as Dictionary):
		if float(c.ins[k]) > bv and ZONE_OF_INS.has(k):
			bv = float(c.ins[k])
			best = String(ZONE_OF_INS[k])
	return best


## The garments carried that go in `zone` (core items with a clothing class, one or more in the pack).
static func owned(core: SurvivalCore, zone: String) -> Array[String]:
	var out: Array[String] = []
	for st in SurvivalInventory._stacks(core):
		var id := String(st.id)
		var it := core.data.item(id)
		if it.get("clothing", null) == null or String(it.get("cat", "")) != "clothing":
			continue
		if SurvivalInventory.count_usable(core, id) < 1.0 - 0.0001:
			continue
		if zone_of(core, id) == zone and not out.has(id):
			out.append(id)
	return out


## The garment worn in `zone` ("" none).
static func worn_in(core: SurvivalCore, zone: String) -> String:
	for w in core.state.worn:
		if zone_of(core, String(w)) == zone:
			return String(w)
	return ""


static func name_of(core: SurvivalCore, item_id: String) -> String:
	return String(core.data.item(item_id).get("name", item_id))


## Puts a garment on (what is in its slot comes off), and the look follows. True when it is on.
static func wear(bridge: SurvivalBridge, item_id: String) -> bool:
	var core := bridge.core
	var zone := zone_of(core, item_id)
	if zone == "":
		return false
	var there := worn_in(core, zone)
	if there == item_id:
		return true
	if there != "":
		SurvivalInventory.take_off(core, there)
	var ok := SurvivalInventory.wear(core, item_id)
	sync_look(bridge)
	if there != "":
		_look_slot(bridge, there, false)
	if ok:
		_look_slot(bridge, item_id, true)
	return ok


## Takes off what is in `zone`. True when something came off.
static func take_off(bridge: SurvivalBridge, zone: String) -> bool:
	var there := worn_in(bridge.core, zone)
	if there == "":
		return false
	var ok := SurvivalInventory.take_off(bridge.core, there)
	sync_look(bridge)
	if ok:
		_look_slot(bridge, there, false)
	return ok


## A normal start: the garment put on (or taken off) in the Tab screen is drawn too (user 2026-10-03: "dragging a garment onto
## your character in Tab changes your warmth but not your look ... fix this"): its customizer garment goes into the look's slot
## (the colours kept when it is the same garment), and taken off the slot goes back to the basic dress. The look is saved as the
## creator's would be. A start with nothing is dressed from what is worn by sync_look instead.
static func _look_slot(bridge: SurvivalBridge, item_id: String, on: bool) -> void:
	if bridge == null or bridge.core == null or bridge.is_bare():
		return
	var p := bridge.player
	if p == null or not is_instance_valid(p) or p.get("appearance") == null:
		return
	var ap := p.get("appearance") as PlayerAppearance
	if ap == null or ap.body == null:
		return
	var g := garment_of(bridge.core, item_id)
	var slot := String(PlayerOutfit.entry(g).get("slot", "")) if g != "" else ""
	if slot == "":
		return
	var look := ap.look.duplicate(true)
	var outfit: Dictionary = (look.get("outfit", {}) as Dictionary).duplicate(true) if look.get("outfit") is Dictionary else {}
	var cur: Dictionary = outfit.get(slot, {}) if outfit.get(slot) is Dictionary else {}
	if on:
		outfit[slot] = {"id": g, "colors": (cur.get("colors", {}) as Dictionary).duplicate() if String(cur.get("id", "")) == g else {}}
	elif String(cur.get("id", "")) == g:
		outfit.erase(slot)
	else:
		return
	look["outfit"] = outfit
	ap.apply(look)
	AppearanceStore.save_current(ap.look)


## The outfit a start with nothing wears now: nothing in any slot the zones cover, then each worn garment in its own. {} if the
## look would be unchanged by it (a normal start).
static func outfit_of(core: SurvivalCore, base: Dictionary) -> Dictionary:
	var outfit := base.duplicate(true)
	for z: Dictionary in ZONES:
		for slot: String in z.slots:
			outfit[slot] = {"id": "-"}
	for w in core.state.worn:
		var g := garment_of(core, String(w))
		if g == "":
			continue
		var slot := String(PlayerOutfit.entry(g).get("slot", ""))
		if slot != "":
			outfit[slot] = {"id": g, "colors": {}}
	return outfit


## A start with nothing: the player's look is dressed from what is worn (nothing: naked). A normal start is left as the creator made it.
## The look's own clothes are kept aside (`outfit_kept`) while a start with nothing strips it, so the character's saved look (the creator
## saves it) never stays naked: a normal start puts them back (user 2026-10-01: "the clothes are stripped still when i have start with
## nothing off").
static func sync_look(bridge: SurvivalBridge) -> void:
	if bridge == null or bridge.core == null:
		return
	var p := bridge.player
	if p == null or not is_instance_valid(p) or p.get("appearance") == null:
		return
	var ap := p.get("appearance") as PlayerAppearance
	if ap == null or ap.body == null:
		return
	var look := ap.look.duplicate(true)
	var outfit: Dictionary = look.get("outfit", {}) if look.get("outfit") is Dictionary else {}
	if not bridge.is_bare():
		var back := restored(look)
		if back.hash() != look.hash():
			ap.apply(back)
			AppearanceStore.save_current(ap.look)
		return
	if not look.has("outfit_kept"):
		look["outfit_kept"] = outfit.duplicate(true)
	look["outfit"] = outfit_of(bridge.core, outfit)
	ap.apply(look)


## `look` with its own clothes again: what a start with nothing kept aside, or (a look stripped before that was kept) the zones'
## slots that are all "nothing" taken off so the basic dress shows.
static func restored(look: Dictionary) -> Dictionary:
	var out := look.duplicate(true)
	if out.has("outfit_kept"):
		out["outfit"] = (out.outfit_kept as Dictionary).duplicate(true) if out.outfit_kept is Dictionary else {}
		out.erase("outfit_kept")
		return out
	var outfit: Dictionary = (out.get("outfit", {}) as Dictionary).duplicate(true) if out.get("outfit") is Dictionary else {}
	var all_off := true
	for z: Dictionary in ZONES:
		for slot: String in z.slots:
			# (a slot the stripped look does not have counts as off: it was stripped before that slot was a zone's)
			if outfit.has(slot) and String((outfit.get(slot, {}) as Dictionary).get("id", "")) != "-":
				all_off = false
	if all_off:
		for z: Dictionary in ZONES:
			for slot: String in z.slots:
				outfit.erase(slot)
		out["outfit"] = outfit
	return out


## The same for a worker (the Gear tab of her sheet): a garment on in its slot over what was there, and her look dressed to what she wears.
static func wear_worker(sc: SpouseCore, item_id: String) -> bool:
	var zone := zone_of(sc.core, item_id)
	if zone == "":
		return false
	var there := worn_in(sc.core, zone)
	if there == item_id:
		return true
	if there != "":
		SurvivalInventory.take_off(sc.core, there)
	var ok := SurvivalInventory.wear(sc.core, item_id)
	sync_worker(sc)
	return ok


static func take_off_worker(sc: SpouseCore, zone: String) -> bool:
	var there := worn_in(sc.core, zone)
	if there == "":
		return false
	var ok := SurvivalInventory.take_off(sc.core, there)
	sync_worker(sc)
	return ok


## Her look's outfit follows what she wears (the slots the zones cover), and her body is dressed again.
static func sync_worker(sc: SpouseCore, body: Node = null) -> void:
	if not sc.bare:
		return      # (a normal start: she keeps the clothes her look has; only a start with nothing dresses her from what she wears)
	sc.look["outfit"] = outfit_of(sc.core, sc.look.get("outfit", {}) if sc.look.get("outfit") is Dictionary else {})
	if body != null and is_instance_valid(body) and body.has_method(&"redress"):
		body.call(&"redress")
