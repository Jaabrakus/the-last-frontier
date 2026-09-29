class_name BareStart
extends RefCounted
## A start with nothing (user 2026-09-28: "can the game start with the user bare and naked no tools can they obtain or
## make all the tools and weapons now"): the new character owns nothing at all, not even the clothes. The kit's
## everything goes: the survival core's kit and worn clothes and its coin, the pack, every weapon (put down, their
## arrows and throwing stock gone), the worn loadout, the torches. What is handed out again each session (the
## felling axe and mattock, the skinning knife, flint and steel) is not, while the core's flag `bare_start` stands
## (SurvivalBridge.is_bare(); a save keeps it). From the ground: sticks, stones, chert, poles, bark (ForageField),
## then the knapping stone's tools (CampStation.STONE) and what they make.


## The loadout gear that is kit, not a place to carry things: the powder horn on its strap, the shot pouch on its strap,
## the pistol sling. A start with nothing wears none of it (the belt and the back slings are only where things ride).
const KIT_GEAR := ["horn_strap", "shot_pouch_strap", "pistol_sling"]


static func apply(b: SurvivalBridge) -> void:
	var core := b.core
	core.state.inventory = []
	core.state.worn = []
	core.state.flags["bare_start"] = true
	SurvivalEconomy._add_money(core, -float(SurvivalEconomy.money(core)))
	core._on_inventory_changed()
	var p := b.player
	if p == null or not is_instance_valid(p):
		return
	# every weapon put down and emptied
	for key: String in p.weapons.keys():
		var w: Variant = p.weapons[key]
		if w is Bow:
			(w as Bow).quiver = 0
		elif w is Throwable:
			(w as Throwable).count = 0
		elif w is Firearm:
			(w as Firearm).reserve = 0
			(w as Firearm).loaded = false
			(w as Firearm).state = Firearm.State.EMPTY
			if w is OverUnderMusket:
				(w as OverUnderMusket).barrels.load_in = [false, false]
		p.set_carried(key, false)
	# the worn loadout empty, the pack empty, no torches
	var lo: Loadout = p.loadout
	if lo:
		for it: Dictionary in lo.items.duplicate():
			lo.remove_item(String(it.id))
		# (and the kit's gear: the starting loadout's horn strap had left a powder horn on the back of a character who
		# owns nothing, the user 2026-09-29)
		lo.gear = PackedStringArray(Array(lo.gear).filter(func(g: String) -> bool: return not g in KIT_GEAR))
	p.apply_loadout(lo, [])
	if p.gather:
		p.gather._ensure_owned()            # (the axe that rode the pack's loop is gone: it re-reads the loadout)
		p.gather._refresh_models()
	if p.torch:
		p.torch.pack.clear()
		p.torch.changed.emit()
