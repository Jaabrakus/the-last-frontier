class_name LoadoutArsenal
extends RefCounted
## One weapon instance per carried item, for the later integration of player._build_weapons()
## (loadout_design.md 8.2): a FlintlockPistol PER PISTOL (pistol_1 .. pistol_4, numbered in draw order),
## each with its own `loaded` state and reload stage (the period reason for a brace: fire one, draw the
## next loaded one without reloading); the musket / over-under, the bow (its arrows from the quiver
## item), and the throwables through ThrowableKit.create(). Nothing here touches the player.
##
##   var weapons := LoadoutArsenal.create_weapons(loadout)        # {item id: Weapon}, not in the tree
##   LoadoutArsenal.read_states(loadout, weapons)                  # loadout item state -> weapons
##   LoadoutArsenal.write_states(loadout, weapons)                 # weapons -> loadout (save)
##   LoadoutKeys.resolve(&"weapon_3", loadout, "pistol_1", LoadoutArsenal.states(weapons))

## Weapon key the anim profile uses per kind (player_anim profiles: bow / musket / pistol; throwables).
const PROFILE := {"musket": "musket", "over_under": "musket", "bow": "bow", "pistol": "pistol",
		"spear_pair": "spear", "tomahawk": "tomahawk", "atlatl": "atlatl"}


static func create_weapons(lo: Loadout) -> Dictionary:
	var out := {}
	for it: Dictionary in lo.items:
		var w := create(String(it.kind))
		if w == null:
			continue
		w.name = String(it.id).to_pascal_case()
		w.set_meta("loadout_item", String(it.id))
		w.set_meta("anim_profile", String(PROFILE.get(String(it.kind), String(it.kind))))
		out[String(it.id)] = w
	read_states(lo, out)
	return out


## A fresh weapon for an item kind; null for kinds that are not weapons (quiver, dart bundle, horn).
static func create(kind: String) -> Weapon:
	match kind:
		"musket":
			return Musket.new()
		"over_under":
			var s: Script = load("res://scripts/weapons/over_under.gd") if ResourceLoader.exists("res://scripts/weapons/over_under.gd") else null
			if s and s.can_instantiate():
				var o: Variant = s.new()
				if o is Weapon:
					return o
			return Musket.new()
		"bow":
			return Bow.new()
		"pistol":
			return FlintlockPistol.new()
		"spear_pair":
			return ThrowableKit.create("spear")
		"tomahawk":
			return ThrowableKit.create("tomahawk")
		"atlatl":
			return ThrowableKit.create("atlatl")
	return null


## Loadout item state -> weapons (loaded state, reload stage, counts, arrows).
static func read_states(lo: Loadout, weapons: Dictionary) -> void:
	for id: String in weapons:
		var it := lo.item(id)
		var w: Weapon = weapons[id]
		if it.is_empty() or w == null:
			continue
		var st: Dictionary = it.get("state", {})
		if w is Firearm:
			var f := w as Firearm
			f.loaded = bool(st.get("loaded", true))
			f.set("_stage", int(st.get("stage", 0)))
			f.state = Firearm.State.READY if f.loaded else Firearm.State.EMPTY
		elif w is Bow:
			var q := lo.first_of_kind("quiver")
			if not q.is_empty():
				(w as Bow).quiver = int(q.get("state", {}).get("arrows", 24))
		elif w is Throwable:
			(w as Throwable).count = int(it.get("count", 1))


## Weapons -> loadout item state (for saving and for the HUD).
static func write_states(lo: Loadout, weapons: Dictionary) -> void:
	for id: String in weapons:
		var w: Weapon = weapons[id]
		if not lo.has_item(id) or w == null:
			continue
		if w is Firearm:
			lo.set_state(id, "loaded", (w as Firearm).loaded)
			lo.set_state(id, "stage", int((w as Firearm).get("_stage")))
		elif w is Throwable:
			lo.set_count(id, (w as Throwable).count)
		elif w is Bow:
			var q := lo.first_of_kind("quiver")
			if not q.is_empty():
				lo.set_state(String(q.id), "arrows", (w as Bow).quiver)


## {item id: {loaded, stage, stages}} for LoadoutKeys and the HUD pistol line.
static func states(weapons: Dictionary) -> Dictionary:
	var out := {}
	for id: String in weapons:
		var w: Weapon = weapons[id]
		if w is Firearm:
			var f := w as Firearm
			out[id] = {"loaded": f.loaded, "stage": int(f.get("_stage")), "stages": f.reload_stages.size()}
	return out


## Frees weapons that never entered the tree.
static func free_all(weapons: Dictionary) -> void:
	for id: String in weapons:
		var w: Weapon = weapons[id]
		if is_instance_valid(w) and not w.is_inside_tree():
			w.free()
