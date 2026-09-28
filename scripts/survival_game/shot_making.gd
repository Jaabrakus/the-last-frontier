class_name ShotMaking
extends RefCounted
## Casting balls at the fire (user 2026-09-28, "making your gear": "bullets cast from bar lead"; the rules' rcp.cast_balls):
## at a lit campfire, with the bullet mould and a pound of bar lead from the pack, the lead is melted in the ladle and
## poured, BALLS_PER_LB balls, and each is rolled up into a paper cartridge with its charge of powder from the kit
## (item.ammo.powder by the pound, POWDER_PER_CARTRIDGE lb each: the rules' forty charges a pound) and goes to the
## musket's cartridges (or, without a musket, the first firearm carried). CASTING_S seconds knelt at the fire
## (StationWork: moving stops it and the lead comes back). The campfire offers it on its hold-E list (Campfire).

const BALLS_PER_LB := 16
const POWDER_PER_CARTRIDGE := 1.0 / 40.0
const CASTING_S := 12.0
const LEAD := "bar_lead"
const MOULD := "bullet_mould"
const POWDER := "item.ammo.powder"


## Why casting cannot be done at `fire` now ("" when it can).
static func why_not(fire: Node, player: Node) -> String:
	var b := SurvivalBridge.find(fire.get_tree()) if fire and fire.is_inside_tree() else null
	if b == null or b.core == null:
		return "needs the survival rules"
	if not bool(fire.get("state").lit):
		return "needs the fire lit"
	if Campfire._pack_count(player, MOULD) <= 0:
		return "needs a bullet mould"
	if Campfire._pack_count(player, LEAD) <= 0:
		return "needs bar lead"
	if SurvivalInventory.count(b.core, POWDER) < POWDER_PER_CARTRIDGE * BALLS_PER_LB - 0.0001:
		return "needs powder for the cartridges"
	if _gun(player) == null:
		return "needs a firearm to load"
	return ""


## The hold-E row at `fire` ({} when there is no mould or lead to show it for).
static func row(fire: Node, player: Node) -> Dictionary:
	if Campfire._pack_count(player, MOULD) <= 0 or Campfire._pack_count(player, LEAD) <= 0:
		return {}
	var b := SurvivalBridge.find(fire.get_tree())
	var powder := SurvivalInventory.count(b.core, POWDER) if b and b.core else 0.0
	return {"id": "cast", "text": "Cast %d balls and roll cartridges (%d bar lead, %.1f lb powder)" % [BALLS_PER_LB,
			Campfire._pack_count(player, LEAD), powder]}


## Starts the casting at `fire`. False when it cannot (why_not).
static func cast(fire: Node3D, player: Node) -> bool:
	if why_not(fire, player) != "":
		return false
	var b := SurvivalBridge.find(fire.get_tree())
	if b.work.working:
		return false
	var inv := InventoryState.from_player(player)
	inv.take(LEAD, 1)
	player.set("inventory_pack", inv.pack.duplicate(true))
	var powder := POWDER_PER_CARTRIDGE * BALLS_PER_LB
	SurvivalInventory.remove(b.core, POWDER, powder)
	var ok := b.work.begin(fire.global_position, "low", "Casting balls and rolling cartridges", CASTING_S, "", func(done: bool) -> void:
		if done:
			var g := _gun(player)
			if g:
				g.reserve += BALLS_PER_LB
			_note(player, "+%d cartridges (%d in all)" % [BALLS_PER_LB, g.reserve if g else 0])
		else:
			var inv2 := InventoryState.from_player(player)
			inv2.add(LEAD, 1)
			player.set("inventory_pack", inv2.pack.duplicate(true))
			SurvivalInventory.add(b.core, POWDER, powder))
	if not ok:
		var inv3 := InventoryState.from_player(player)
		inv3.add(LEAD, 1)
		player.set("inventory_pack", inv3.pack.duplicate(true))
		SurvivalInventory.add(b.core, POWDER, powder)
	return ok


## The firearm the cartridges go to: the musket, else the first one carried.
static func _gun(player: Node) -> Firearm:
	var ws: Variant = player.get("weapons")
	if not ws is Dictionary:
		return null
	if (ws as Dictionary).get("musket") is Firearm:
		return ws.musket
	for w in (ws as Dictionary).values():
		if w is Firearm:
			return w
	return null


static func _note(player: Node, text: String) -> void:
	var h: Variant = player.get("hud")
	if h != null and is_instance_valid(h) and (h as Node).has_method("toast"):
		(h as Node).call("toast", text, "bar_lead")
