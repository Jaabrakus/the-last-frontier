class_name InventoryState
extends RefCounted
## What the player owns and where it is (graph_analysis/inventory/inventory_design.md, first cut; user
## 2026-09-25: "create a Char inventory system with drag and drop with gear"): the worn Loadout (items at
## their points on the body: the back slings, the quiver, the belt and sash hooks, the tomahawk frog) and
## the PACK, everything else owned. Everything stays usable in play (user: "right now all unlocked"); what is
## worn is what shows on the body (FrontierPlayer.apply_loadout()).
##
##   var inv := InventoryState.from_player(player)
##   inv.can_wear("spear_pair", "long_B")          # {ok, reason, loadout (the trial)}
##   inv.wear("spear_pair", "long_B")              # the pack's spear pair onto the back
##   inv.unwear("musket")                          # the musket into the pack
##
## Item kinds are the loadout kinds (data/loadout/loadout_items.json); the pack holds {kind, count, state}.

const NAMES := {"musket": "Flintlock Musket", "over_under": "Over-and-Under", "bow": "Longbow", "quiver": "Quiver",
		"spear_pair": "Throwing Spears", "tomahawk": "Tomahawk", "atlatl": "Atlatl", "dart_bundle": "Atlatl Darts",
		"pistol": "Flintlock Pistol", "powder_horn": "Powder Horn", "torch": "Pine-knot Torch",
		# gathering (data/gathering/gathering.json): the tools and what they gather
		"felling_axe": "Felling Axe", "mattock": "Mattock", "log": "Log", "firewood": "Firewood", "branches": "Branches",
		"pole": "Pole", "stone": "Stone", "flint": "Flint", "bone": "Deer Leg Bone",
		# climbing gear (loadout_items.json climbing_stakes_* / climbing_claws_*): the knapping stone and the forge
		"climbing_stakes_wood": "Fire-hardened Climbing Stakes", "climbing_stakes_bone": "Bone Climbing Stakes",
		"climbing_stakes_stone": "Flint-pointed Climbing Stakes", "climbing_stakes_iron": "Iron Climbing Spikes",
		"climbing_claws_wood": "Hardwood Ashiko", "climbing_claws_bone": "Bone Ashiko", "climbing_claws_stone": "Flint-toothed Ashiko",
		"climbing_claws_iron": "Iron Ashiko",
		# wildlife (scripts/wildlife, WildlifeSpecies yields): what skinning gives
		"skinning_knife": "Skinning Knife", "fire_steel": "Flint and Steel", "venison": "Venison", "deer_hide": "Deer Hide", "antler": "Antler", "wolf_pelt": "Wolf Pelt", "fox_pelt": "Fox Pelt",
		"bison_robe": "Buffalo Robe", "tallow": "Tallow", "tongue": "Buffalo Tongue",
		# forage (data/forage/forage.json): what the plants give
		"blackberries": "Blackberries", "strawberries": "Wild Strawberries", "plantain": "Plantain Leaves",
		"wintergreen": "Wintergreen", "ginseng": "Ginseng Root", "acorns": "Acorns", "hazelnuts": "Hazelnuts",
		"willow_bark": "Willow Bark", "yarrow": "Yarrow", "elm_bark": "Slippery Elm Bark", "elderberries": "Elderberries",
		"hemp_tops": "Hemp Tops", "bearberry": "Bearberry Leaves", "dogwood_bark": "Red-osier Bark",
		"jimsonweed": "Jimsonweed", "crabapples": "Crabapples",
		# the woods' own materials (ForageField: arrowwood, pine pitch, turkey scratchings)
		"shoots": "Straight Shoots", "pine_pitch": "Pine Pitch", "feathers": "Turkey Feathers",
		# farming (data/farming/farming.json): the hoe, the digging stick, seed and the crops
		"hoe": "Hoe", "digging_stick": "Digging Stick", "farm_hoe": "Hoe", "farm_stick": "Digging Stick", "seed_corn": "Seed Corn", "seed_beans": "Bean Seed",
		"seed_squash": "Squash Seed", "seed_tobacco": "Tobacco Seed", "seed_flax": "Flaxseed", "corn": "Ear of Corn",
		"roast_corn": "Roasted Corn", "charred_corn": "Charred Corn", "beans": "Beans", "bean_pot": "Boiled Beans",
		"scorched_beans": "Scorched Beans", "squash": "Squash", "roast_squash": "Roasted Squash",
		"charred_squash": "Charred Squash", "tobacco_leaves": "Tobacco Leaves", "flax": "Flax",
		# provisions (data/survival/game_items.json): the kit's food
		"jerky": "Jerky", "cornmeal": "Cornmeal",
		# cooked on a campfire (CampCooking)
		"johnnycake": "Johnnycake", "burnt_johnnycake": "Burnt Johnnycake", "roast_venison": "Roast Venison",
		"charred_venison": "Charred Venison", "roast_fish": "Roast Fish", "charred_fish": "Charred Fish",
		# fish (scripts/fishing, FishCatch): by the pound, each species its own
		"brook_trout": "Brook Trout", "salmon": "Atlantic Salmon", "sucker": "White Sucker", "perch": "Yellow Perch",
		"pike": "Northern Pike", "eel": "American Eel", "bullhead": "Brown Bullhead", "sturgeon": "Lake Sturgeon",
		"pickerel": "Chain Pickerel",
		# the tanning frame and the alchemy table (CampStation, Remedies)
		"brains": "Brains", "buckskin": "Buckskin", "rawhide": "Rawhide", "plantain_salve": "Plantain Salve",
		"wintergreen_tea": "Wintergreen Tea", "ginseng_tonic": "Ginseng Tonic", "willow_bark_tea": "Willow Bark Tea",
		"slippery_elm_gruel": "Slippery Elm Gruel", "elderberry_syrup": "Elderberry Syrup",
		# drink and tobacco (Vices): rum by the gill, tobacco by the pipeful, the pipe to smoke it
		"rum": "Rum", "tobacco": "Tobacco", "clay_pipe": "Clay Pipe",
		# the rest of the time's vices (Vices)
		"whiskey": "Whiskey", "cider": "Hard Cider", "sweet_cider": "Sweet Cider", "laudanum": "Laudanum", "snuff": "Snuff",
		"chew": "Chewing Tobacco", "kinnikinnick": "Kinnikinnick", "kinnikinnick_mix": "Kinnikinnick with Tobacco",
		# the workbench and the stretching hoop
		"sinew": "Sinew", "dried_wolf_pelt": "Dried Wolf Pelt", "dried_fox_pelt": "Dried Fox Pelt",
		"marten_pelt": "Marten Pelt", "mink_pelt": "Mink Pelt", "fisher_pelt": "Fisher Pelt", "raccoon_pelt": "Raccoon Pelt",
		"dried_marten_pelt": "Dried Marten Pelt", "dried_mink_pelt": "Dried Mink Pelt", "dried_fisher_pelt": "Dried Fisher Pelt",
		"dried_raccoon_pelt": "Dried Raccoon Pelt", "small_game": "Small Game", "roast_small_game": "Roast Small Game",
		"charred_small_game": "Charred Small Game",
		# the trapper's and the shot-maker's gear (GearModels; the workbench and the fire make some)
		"cordage": "Cordage", "rope_belt": "Rope Belt", "rope_sling": "Rope Sling", "stake_set": "Deadfall Stakes", "steel_trap": "Steel Trap", "bar_lead": "Bar Lead",
		"bullet_mould": "Bullet Mould", "hooks_line": "Hooks and Line", "fishing_rod": "Fishing Rod",
		"fish_spear": "Fish Spear",
		# the knapping stone's tools (the start with nothing)
		"flint_knife": "Flint Knife", "stone_axe": "Stone Axe", "bow_drill": "Bow Drill", "bone_awl": "Bone Awl",
		# the canoe's parts (TreeHarvest, the boat stand)
		"canoe_stake": "Building Stake", "birch_bark_sheet": "Birch Bark Sheet", "wattap": "Wattap", "canoe_strip": "Split Strip",
		"canoe_rib": "Canoe Rib",
		# the forge's (bog iron from the hollows, clay from the banks, charcoal from the mound)
		"bog_iron": "Bog Iron Ore", "clay": "Clay", "charcoal": "Charcoal", "bar_iron": "Bar Iron",
		# a gun's parts (the forge's barrel and lock, the workbench's stock; assembled at the workbench)
		"gun_barrel": "Musket Barrel", "pistol_barrel": "Pistol Barrel", "gunlock": "Gunlock", "gunstock": "Gunstock"}
const POINT_NAMES := {"long_A": "Back sling (outer)", "long_B": "Back sling (inner)", "quiver": "Quiver strap",
		"R_hip": "Right hip", "L_hip": "Left hip", "back": "Tomahawk frog", "back_2": "Second tomahawk",
		"back_right": "Back of the belt", "chest_R": "Chest (right)", "chest_L": "Chest (left)", "horn": "Horn strap",
		"tool_loop": "Pack tool loop"}
## Weapon keys of FrontierPlayer.weapons -> the loadout kind that carries them.
const KIND_OF_KEY := {"musket": "musket", "over_under": "over_under", "bow": "bow", "pistol": "pistol",
		"spear": "spear_pair", "tomahawk": "tomahawk", "atlatl": "atlatl"}
## Torches ride in the pack only (PlayerTorch keeps them: one stack, the count of torches not in the hand).
const TORCH := "torch"
## Carry gear made from rope (user 2026-10-01: a start with nothing makes its sling rig from tree-bark rope): the pack kind and
## the loadout gear it is when worn (carry_gear.json): a tied belt (hip and back points), a sling (the back slings: the long
## weapons, the quiver strap, the tool loop).
const GEAR_KINDS := {"rope_belt": "belt_tied_behind", "rope_sling": "back_slings"}

var data: LoadoutData
var worn: Loadout
var pack: Array[Dictionary] = []     ## [{kind, count, state}]


static func from_player(p: Node) -> InventoryState:
	var inv := InventoryState.new()
	inv.data = LoadoutData.get_default()
	var lo: Loadout = p.get("loadout")
	inv.worn = lo.copy() if lo else Loadout.from_preset(inv.data.default_preset())
	# everything the player owns, less what is worn, is in the pack
	var owned := {}
	var ws: Dictionary = p.get("weapons")
	for key in ws:
		var k := String(KIND_OF_KEY.get(key, ""))
		if k == "":
			continue
		# a weapon put down in the world or on a rack is not with the player, so not in the pack
		if p.has_method("is_carried") and not bool(p.call("is_carried", String(key))):
			continue
		var w: Weapon = ws[key]
		var n := 1
		if w is Throwable and k != "atlatl":
			n = maxi((w as Throwable).max_count, 1)
		owned[k] = int(owned.get(k, 0)) + n
		if k == "bow":
			owned["quiver"] = 1
		if k == "atlatl":
			owned["dart_bundle"] = int(owned.get("dart_bundle", 0)) + 5
	# The weapons' part of the pack is worked out fresh every time (hotfix 2026-09-26, user: "when we equip things
	# from our pack like a musket to back we should be able to equip that": a pack saved at the last close still
	# listed a musket put down since, which then went on the back without being carried and could not be drawn).
	# The saved pack keeps each item's state, and every other item (not one of the weapons' kinds) as it was.
	var saved := {}
	var pack_list: Array = p.get("inventory_pack") if p.get("inventory_pack") != null else []
	for e: Dictionary in pack_list:
		var ek := String(e.get("kind", ""))
		if ek == TORCH:
			continue   # the torches come from the player's PlayerTorch (_torches_from)
		if _derived(ek):
			saved[ek] = e.get("state", {})
		else:
			inv.pack.append(e.duplicate(true))
	for k in owned:
		var left := int(owned[k])
		for it: Dictionary in inv.worn.items:
			if String(it.kind) == k:
				left -= int(it.get("count", 1))
		if left > 0:
			inv.pack.append({"kind": k, "count": left, "state": (saved.get(k, {}) as Dictionary).duplicate(true)})
	inv._torches_from(p)
	return inv


func _torches_from(p: Node) -> void:
	var t: Variant = p.get("torch")
	if t is PlayerTorch and (t as PlayerTorch).count() > 0:
		pack.append({"kind": TORCH, "count": (t as PlayerTorch).count(), "state": {}})


## Pack kinds that come from the player's weapons (worked out by from_player()).
static func _derived(kind: String) -> bool:
	return KIND_OF_KEY.values().has(kind) or kind in ["quiver", "dart_bundle"]


static func name_of(kind: String) -> String:
	return String(NAMES.get(kind, kind.capitalize()))


static func point_name(p: String) -> String:
	return String(POINT_NAMES.get(p, p))


## The body points the worn gear offers, in display order.
func points() -> Array:
	var gp := LoadoutRules.gear_points(worn.gear, worn.shoulder_ew_sash, data)
	var out: Array = []
	for p in ["long_A", "long_B", "quiver", "back", "back_2", "R_hip", "L_hip", "back_right", "chest_R", "chest_L", "tool_loop"]:
		if (gp.points as Dictionary).has(p):
			out.append(p)
	return out


## Kinds allowed at point `p` by the worn gear.
func kinds_at(p: String) -> Array:
	var gp := LoadoutRules.gear_points(worn.gear, worn.shoulder_ew_sash, data)
	return (gp.points as Dictionary).get(p, [])


func item_at(p: String) -> Dictionary:
	for it: Dictionary in worn.items:
		if (it.points as Array).has(p):
			return it
	return {}


## The body point one `kind` from the pack goes to when it is dropped on the figure or double-clicked: the first
## free point that takes it, else the first that takes it (what is there goes to the pack); "" when none can.
func best_point(kind: String) -> String:
	var fallback := ""
	for p in points():
		if not kinds_at(p).has(kind) or not bool(can_wear(kind, p).ok):
			continue
		if item_at(p).is_empty():
			return p
		if fallback == "":
			fallback = p
	return fallback


func pack_count(kind: String) -> int:
	for e in pack:
		if String(e.kind) == kind:
			return int(e.count)
	return 0


## Puts `n` of `kind` into the pack (every item stacks; gathering).
func add(kind: String, n: int) -> void:
	if n > 0:
		_to_pack(kind, n)


## Takes up to `n` of `kind` out of the pack; returns how many were there to take.
func take(kind: String, n: int) -> int:
	var got := mini(pack_count(kind), maxi(n, 0))
	if got > 0:
		_from_pack(kind, got)
	return got


## Would one `kind` from the pack worn at `p` be legal? {ok, reason, loadout}: the trial loadout (the item
## already at `p` goes back to the pack). "needs" (the bow's quiver, the atlatl's darts) only warns.
func can_wear(kind: String, p: String) -> Dictionary:
	if not kinds_at(p).has(kind):
		return {"ok": false, "reason": "%s does not go on the %s" % [name_of(kind), point_name(p).to_lower()]}
	var lo := worn.copy()
	var there := item_at(p)
	if not there.is_empty():
		_take_point(lo, there, p)
	var same := lo.first_of_kind(kind) if kind in ["tomahawk", "spear_pair", "dart_bundle"] else {}
	if kind == "tomahawk" and not same.is_empty():
		var pts: Array = (same.points as Array).duplicate()
		if not pts.has(p):
			pts.append(p)
		same.points = pts
		same.count = pts.size()
	else:
		lo.add_item(kind, [p], _unit_count(kind), _stack_state(kind))
	var errs := LoadoutRules.validate(lo, data)
	var hard: Array = []
	var soft: Array = []
	for e: String in errs:
		(soft if e.contains(" needs ") else hard).append(e)
	if not hard.is_empty():
		return {"ok": false, "reason": _plain(String(hard[0])), "loadout": lo}
	return {"ok": true, "reason": _plain(String(soft[0])) if not soft.is_empty() else "", "loadout": lo}


## Wears one `kind` from the pack at `p` (what was there goes to the pack). True when done.
func wear(kind: String, p: String) -> bool:
	if pack_count(kind) <= 0:
		return false
	var r := can_wear(kind, p)
	if not bool(r.ok):
		return false
	var there := item_at(p)
	if not there.is_empty():
		_to_pack(String(there.kind), 1 if String(there.kind) == "tomahawk" else int(there.get("count", 1)), there.get("state", {}))
	_from_pack(kind, _unit_count(kind))
	worn = r.loadout
	return true


## Takes the worn item at point `p` off the body into the pack.
func unwear_point(p: String) -> void:
	var it := item_at(p)
	if it.is_empty():
		return
	_to_pack(String(it.kind), 1 if String(it.kind) == "tomahawk" else int(it.get("count", 1)), it.get("state", {}))
	_take_point(worn, it, p)


func _take_point(lo: Loadout, it: Dictionary, p: String) -> void:
	if String(it.kind) == "tomahawk" and (it.points as Array).size() > 1:
		var live := lo.item(String(it.id))
		var pts: Array = (live.points as Array).duplicate()
		pts.erase(p)
		live.points = pts
		live.count = pts.size()
		return
	lo.remove_item(String(it.id))


func _unit_count(kind: String) -> int:
	# thrown weapons go on as the whole bundle in the pack (up to the carry maximum)
	if kind in ["spear_pair", "dart_bundle"]:
		return clampi(pack_count(kind), 1, data.count_max(kind))
	return 1


## A pack stack's state (a made thing's standard: StationPractice), copied for the body when it is worn.
func _stack_state(kind: String) -> Dictionary:
	for e in pack:
		if String(e.kind) == kind:
			return (e.get("state", {}) as Dictionary).duplicate(true)
	return {}


func _to_pack(kind: String, n: int, state: Variant = {}) -> void:
	var st := StationPractice.of_state(state)
	for e in pack:
		if String(e.kind) == kind:
			e.count = int(e.count) + n
			StationPractice.stamp(pack, kind, st)
			return
	pack.append({"kind": kind, "count": n, "state": (state as Dictionary).duplicate(true) if state is Dictionary else {}})


func _from_pack(kind: String, n: int) -> void:
	for i in pack.size():
		if String(pack[i].kind) == kind:
			pack[i].count = int(pack[i].count) - n
			if int(pack[i].count) <= 0:
				pack.remove_at(i)
			return


static func _plain(e: String) -> String:
	for k in NAMES:
		e = e.replace(String(k), String(NAMES[k]).to_lower())
	return e.replace("_", " ")

# --- rope gear ----------------------------------------------------------------------------------------------------------

## Whether the rope gear `kind` (a GEAR_KINDS key) is worn now.
func gear_worn(kind: String) -> bool:
	var gid := String(GEAR_KINDS.get(kind, ""))
	return gid != "" and worn.gear.has(gid)


## Puts on the rope gear `kind` from the pack. True when done.
func wear_gear(kind: String) -> bool:
	var gid := String(GEAR_KINDS.get(kind, ""))
	if gid == "" or gear_worn(kind) or pack_count(kind) <= 0:
		return false
	_from_pack(kind, 1)
	var g := Array(worn.gear)
	g.append(gid)
	worn.gear = PackedStringArray(g)
	return true


## Takes the rope gear `kind` off into the pack, and what hung on its points with it (a knife on a belt, a musket on a sling).
func unwear_gear(kind: String) -> bool:
	var gid := String(GEAR_KINDS.get(kind, ""))
	if gid == "" or not gear_worn(kind):
		return false
	worn.gear = PackedStringArray(Array(worn.gear).filter(func(x: String) -> bool: return x != gid))
	_to_pack(kind, 1)
	var gp := LoadoutRules.gear_points(worn.gear, worn.shoulder_ew_sash, data)
	for it: Dictionary in worn.items.duplicate():
		var supported := true
		for p in (it.points as Array):
			if not (gp.points as Dictionary).has(p):
				supported = false
		if not supported:
			_to_pack(String(it.kind), int(it.get("count", 1)), it.get("state", {}))
			worn.remove_item(String(it.id))
	return true
