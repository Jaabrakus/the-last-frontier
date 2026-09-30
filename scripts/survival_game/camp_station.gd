class_name CampStation
extends Node3D
## What a built bed or crafting station does and holds (BuiltPiece.dress adds it; user 2026-09-27: "add in beds and other
## craftables in the build option ... leather and tanning stations ... Alchemy"). An E interactable (PlayerInteractor's
## hook, as the campfire), worked through the survival bridge (SurvivalBridge.find; without it only the look is there):
##   bough_bed, pole_bed   E: lie down in it and sleep (SurvivalSleep). While the player is in it CampLink gives the core
##                         its bedding (BEDDING: the core's bough bed, +2 C and a better sleep; the pole bed, +3 C and
##                         better still); with a lean-to's or a roof's shelter it is a full night's rest.
##   drying_rack           E: venison hung over the fire (a lit campfire within DRY_FIRE_M; the core's
##                         preserve.jerk_scaffold with rcp.jerky: 10 lb of raw venison a batch make 4 lb of jerky), then
##                         1-2 game days drying on the rack (the core's rack record, under the rack's own location tag,
##                         kept in its save); E takes the dry jerky down. The strips show on the rack, darker as they dry.
##   tanning_frame         E: a menu (StationMenu): a deer hide dressed into buckskin (rcp.dress_hide: brains or cornmeal
##                         worked in, smoked over a lit campfire within TAN_FIRE_M; a failure leaves rawhide), or scraped
##                         into rawhide (rcp.rawhide): the core's craft.dress_hide and its Hidecraft check; a bison's
##                         green robe dressed with the hair on (rcp.dress_robe: brains or cornmeal, worked soft, no
##                         smoking) into the rules' fur robe, put on as a wrap (the warmest by day, a bed by night).
##   alchemy_table         E: a menu of remedies from what you forage (Remedies): plantain salve, wintergreen tea,
##                         ginseng tonic, willow bark tea, slippery elm gruel, elderberry syrup (the teas, gruel and
##                         syrup with a lit fire near); a few seconds' work at the table.
##   workbench             E: a menu (user 2026-09-27: "a workbench for moccasins, arrows and spears"): moccasins
##                         (rcp.moccasins: a third of a buckskin and a sinew) and fur mitts (rcp.mitts_fur: a pelt and a
##                         sinew) into the kit the core wears out, mending the worn moccasins (a hide scrap from dressing
##                         hides and a sinew); arrows, a throwing spear and atlatl darts from branches, poles and flint
##                         (BENCH, straight into the bow's quiver and the throwables' counts); the trapper's and the
##                         angler's gear into the pack (GEAR; user 2026-09-28, "making your gear"): cordage twisted
##                         from sinew, a fishing rod (a pole and a line), a fish spear (a pole and barbs), deadfall
##                         stakes cut from branches.
##   stretching_hoop       E: a wolf or fox pelt laced in, fleshed (the core's fur.stretch: its grade up or down by the
##                         Hidecraft check), then 2-3 game days drying on the hoop (the core's record under the hoop's own
##                         tag, kept in its save); E takes the dried pelt down.
## The work is SurvivalBridge.work's (StationWork: kneeling, at the table or reaching up, a bar; moving stops it and the
## things put in come back). Pack and core items: data/survival/game_items.json ("items", "materials").

const KINDS := ["bough_bed", "pole_bed", "drying_rack", "tanning_frame", "alchemy_table", "workbench", "stretching_hoop", "work_stone",
		"charcoal_mound", "forge"]
const BEDS := ["bough_bed", "pole_bed"]
## The core's bedding for each bed (needs.json bedding_c, sleep_quality_terms).
const BEDDING := {"bough_bed": "bough_bed", "pole_bed": "pole_bed"}
const DRY_FIRE_M := 3.0
const TAN_FIRE_M := 5.0
const TABLE_FIRE_M := 5.0
const JERKY_LB := 10.0
## The workbench's own work (no core recipe): what it takes from the pack, the weapon it arms and how many, seconds.
const BENCH := {
	"arrows": {"text": "Arrows (6)", "inputs": {"shoots": 2, "flint": 1, "feathers": 1}, "or": {"shoots": "branches"}, "weapon": "bow",
			"n": 6, "seconds": 8.0, "verb": "Straightening shafts, knapping points and fletching",
			"detail": "2 straight shoots (or branches), a flint and turkey feathers: 6 fletched arrows into the quiver"},
	"spear": {"text": "Throwing spear", "inputs": {"pole": 1, "flint": 1}, "weapon": "spear", "n": 1, "seconds": 6.0,
			"verb": "Shaving a pole and hafting a point", "detail": "a pole and a flint point: a throwing spear"},
	"darts": {"text": "Atlatl darts (2)", "inputs": {"shoots": 2, "flint": 1, "feathers": 1}, "or": {"shoots": "branches"}, "weapon": "atlatl",
			"n": 2, "seconds": 7.0, "verb": "Cutting dart shafts, knapping points and fletching",
			"detail": "2 straight shoots (or branches), a flint and feathers: 2 darts for the atlatl"},
}
## Weapons made whole (the start with nothing; or a second one when yours is lost): at the workbench and the knapping
## stone. `knife`: a knife in the pack to shape it (the steel one or a flint one). Made, the weapon is the player's
## (FrontierPlayer.set_carried), empty: a bow's quiver and an atlatl's darts are made after (BENCH).
const ARMS := {
	"bow": {"text": "Self bow", "weapon": "bow", "inputs": {"pole": 1, "sinew": 1}, "or": {"sinew": "cordage"}, "knife": true,
			"seconds": 14.0, "verb": "Shaving a sapling stave to a bow and stringing it",
			"detail": "a pole (a straight sapling) and a bowstring (a sinew, or cordage): a self bow with its quiver"},
	"atlatl": {"text": "Atlatl", "weapon": "atlatl", "inputs": {"branches": 1, "antler": 1}, "or": {"antler": "cordage"}, "knife": true,
			"seconds": 10.0, "verb": "Carving a spear-thrower and setting its hook",
			"detail": "a branch and a hook (an antler tine, or a cord-lashed spur): a spear-thrower for darts"},
	"musket": {"text": "Flintlock musket", "weapon": "musket", "inputs": {"gun_barrel": 1, "gunlock": 1, "gunstock": 1}, "knife": true,
			"at": ["workbench"], "seconds": 20.0, "verb": "Inletting the stock, breeching the barrel and fitting the lock",
			"detail": "a musket barrel, a lock and a stock (the forge, the bench): a flintlock musket (powder and ball from the kit or the trader)"},
	"pistol": {"text": "Flintlock pistol", "weapon": "pistol", "inputs": {"pistol_barrel": 1, "gunlock": 1, "gunstock": 1}, "knife": true,
			"at": ["workbench"], "seconds": 16.0, "verb": "Shaping a pistol stock and fitting the barrel and lock",
			"detail": "a pistol barrel, a lock and a stock: a flintlock pistol"},
	"over_under": {"text": "Over-and-under", "weapon": "over_under", "inputs": {"gun_barrel": 2, "gunlock": 2, "gunstock": 1}, "knife": true,
			"at": ["workbench"], "seconds": 28.0, "verb": "Fitting two barrels on a turning breech, two locks, one stock",
			"detail": "two musket barrels, two locks and a stock: the turnover double gun"},
}
## The forge's work (a bloomery forge; the same shape as GEAR, `makes` the pack kind, `weapon` a thrown weapon armed):
## charcoal feeds every heat. Bog ore smelts to a bloom hammered into bar iron; bar iron is forged into the tools the
## kit had (the start with nothing makes them here) and a gun's barrel and lock.
const FORGE := {
	"bar_iron": {"text": "Smelt bar iron", "inputs": {"bog_iron": 3, "charcoal": 4}, "n": 1, "seconds": 22.0,
			"verb": "Charging the shaft with ore and charcoal, working the bellows, hammering the bloom",
			"detail": "3 bog ore and 4 charcoal: a bloom, hammered out into a bar of iron"},
	"felling_axe": {"text": "Felling axe", "inputs": {"bar_iron": 2, "charcoal": 2, "pole": 1}, "n": 1, "seconds": 20.0,
			"verb": "Drawing the head, punching the eye, steeling the bit, hanging it on a haft",
			"detail": "2 bar iron, 2 charcoal, a pole for the haft: a felling axe"},
	"mattock": {"text": "Mattock", "inputs": {"bar_iron": 2, "charcoal": 2, "pole": 1}, "n": 1, "seconds": 20.0,
			"verb": "Drawing the pick and the blade, punching the eye, hafting", "detail": "2 bar iron, 2 charcoal, a pole: a mattock"},
	"hoe": {"text": "Hoe", "inputs": {"bar_iron": 2, "charcoal": 2, "pole": 1}, "n": 1, "seconds": 18.0,
			"verb": "Drawing a broad blade, forging the neck and eye, hafting it",
			"detail": "2 bar iron, 2 charcoal, a pole: a planter's hoe (breaks ground for a bed, hoes out weeds)"},
	"skinning_knife": {"text": "Belt knife", "inputs": {"bar_iron": 1, "charcoal": 1, "branches": 1}, "n": 1, "seconds": 14.0,
			"verb": "Drawing a blade, hardening it, fitting a handle", "detail": "a bar of iron, charcoal, a branch for the handle: a belt knife"},
	"tomahawk": {"text": "Tomahawk", "weapon": "tomahawk", "inputs": {"bar_iron": 1, "charcoal": 1, "branches": 1}, "n": 1, "seconds": 14.0,
			"verb": "Wrapping the eye, welding the bit, fitting a haft", "detail": "a bar of iron, charcoal, a branch for the haft: a throwing tomahawk"},
	"fire_steel": {"text": "Flint and steel", "inputs": {"bar_iron": 1, "charcoal": 2}, "n": 1, "seconds": 10.0,
			"verb": "Case-hardening a striker in the charcoal", "detail": "a bar of iron hardened in 2 charcoal: a fire steel (strike it on a flint)"},
	"steel_trap": {"text": "Steel trap", "inputs": {"bar_iron": 2, "charcoal": 2}, "n": 1, "seconds": 18.0,
			"verb": "Forging jaws, a pan and a long spring, tempering the spring", "detail": "2 bar iron, 2 charcoal: a long-spring steel trap"},
	"bullet_mould": {"text": "Bullet mould", "inputs": {"bar_iron": 1, "charcoal": 1, "branches": 1}, "n": 1, "seconds": 14.0,
			"verb": "Forging the jaws, drilling the ball cavity, fitting handles", "detail": "a bar of iron, charcoal, a branch: a mould for musket balls"},
	"hooks_line": {"text": "Hooks and line", "inputs": {"bar_iron": 1, "charcoal": 1, "cordage": 1}, "n": 1, "seconds": 10.0,
			"verb": "Drawing wire, filing barbs, winding a line", "detail": "a bar of iron drawn to wire for hooks, charcoal, a cord: hooks and line"},
	"gun_barrel": {"text": "Musket barrel", "inputs": {"bar_iron": 4, "charcoal": 4}, "n": 1, "seconds": 30.0,
			"verb": "Welding a skelp round a mandrel, boring and breeching it", "detail": "4 bar iron, 4 charcoal: a smoothbore barrel"},
	"pistol_barrel": {"text": "Pistol barrel", "inputs": {"bar_iron": 2, "charcoal": 2}, "n": 1, "seconds": 20.0,
			"verb": "Welding a short skelp round a mandrel and boring it", "detail": "2 bar iron, 2 charcoal: a pistol barrel"},
	"climbing_stakes_iron": {"text": "Climbing spikes, iron", "inputs": {"bar_iron": 1, "charcoal": 1, "rawhide": 1}, "or": {"rawhide": "cordage"},
			"n": 1, "seconds": 14.0, "verb": "Drawing two square spikes, hardening the points, wrapping the grips",
			"detail": "a bar of iron, charcoal and a grip wrap: the best climbing spikes there are"},
	"gunlock": {"text": "Gunlock", "inputs": {"bar_iron": 2, "charcoal": 2}, "n": 1, "seconds": 26.0,
			"verb": "Forging the plate, cock, frizzen and springs, filing and fitting them",
			"detail": "2 bar iron, 2 charcoal: a flintlock (a flint goes in its cock)"},
}
## The charcoal mound: its game minutes charring, and what it gives.
const CHAR_MIN := 20.0 * 60.0
const CHAR_YIELD := 5
## The trapper's and the angler's gear, into the pack (as the vices' goods): what it takes (a kind in `or` stands in for
## one missing: the rod's line from cordage when the kit's hooks and line are gone, the spear's barbs from flint when
## there is no antler), how many it makes, seconds.
const GEAR := {
	"cordage": {"text": "Cordage (2)", "inputs": {"sinew": 1}, "n": 2, "seconds": 5.0, "verb": "Twisting sinew into cord",
			"detail": "a sinew: 2 lengths of cordage (a snare each, or a rod's line)"},
	"fishing_rod": {"text": "Fishing rod", "inputs": {"pole": 1, "hooks_line": 1}, "or": {"hooks_line": "cordage"}, "n": 1,
			"seconds": 8.0, "verb": "Shaving a pole and tying on the line",
			"detail": "a pole and a line (hooks and line, or cordage): an ash rod with its line, quill float and hook"},
	"fish_spear": {"text": "Fish spear", "inputs": {"pole": 1, "antler": 1}, "or": {"antler": "flint"}, "n": 1,
			"seconds": 8.0, "verb": "Shaving a pole and cutting barbs",
			"detail": "a pole and barbs (an antler, or a flint): a spear for the fish in the shallows"},
	"stake_set": {"text": "Deadfall stakes", "inputs": {"branches": 3}, "n": 1, "seconds": 6.0,
			"verb": "Cutting stakes, a trigger and a bait stick", "detail": "3 branches: the stakes and trigger of one deadfall"},
	# farming (FarmField): the crops worked up at the bench
	"cordage_flax": {"text": "Linen cord from flax (2)", "makes": "cordage", "inputs": {"flax": 2}, "n": 2, "seconds": 8.0,
			"verb": "Breaking and scutching the flax, twisting the fibre into cord",
			"detail": "2 flax: 2 lengths of cordage (a snare each, or a rod's line)"},
	"tobacco": {"text": "Twist of tobacco", "inputs": {"tobacco_leaves": 3}, "n": 1, "seconds": 8.0,
			"verb": "Hanging the leaves to cure and twisting them into a carrot",
			"detail": "3 tobacco leaves, cured and twisted: tobacco for the pipe"},
}
## The knapping stone's work (the start with nothing; same shape as GEAR; `makes` the pack kind when it is not the id): the
## first tools from the ground's own things: chert (fieldstones, nodules), sticks, poles, bark cord. A throwing spear is
## BENCH's "spear" (a pole and a chert point), offered here too.
const STONE := {
	"cordage_bark": {"text": "Cordage from bark (2)", "makes": "cordage", "inputs": {"elm_bark": 2}, "or": {"elm_bark": "dogwood_bark"}, "n": 2,
			"seconds": 6.0, "verb": "Stripping the inner bark and twisting it into cord",
			"detail": "2 bark (slippery elm, or red-osier): 2 lengths of cordage"},
	"flint_knife": {"text": "Flint knife", "inputs": {"flint": 1, "branches": 1, "cordage": 1}, "n": 1, "seconds": 9.0,
			"verb": "Knapping a blade and binding it into a split handle",
			"detail": "a flint, a branch and a cord: a knife that skins, butchers and cuts, as a belt knife does"},
	"stone_axe": {"text": "Stone axe", "inputs": {"flint": 2, "pole": 1, "cordage": 1}, "n": 1, "seconds": 12.0,
			"verb": "Knapping an axe head, splitting the haft and lashing it in",
			"detail": "2 flints, a pole and a cord: an axe that fells trees and cuts saplings, slowly (under half a steel axe's bite)"},
	"bow_drill": {"text": "Bow drill", "inputs": {"branches": 2, "cordage": 1}, "n": 1, "seconds": 8.0,
			"verb": "Cutting a bow, a spindle and a hearth board", "detail": "2 branches and a cord: fire from friction, without flint and steel"},
	"bone_awl": {"text": "Bone awl", "inputs": {"antler": 1}, "knife": true, "n": 1, "seconds": 8.0,
			"verb": "Cutting a tine and grinding it to a point on the stone",
			"detail": "an antler tine ground to a point: the awl to sew hides (moccasins, mitts, clothes)"},
	"torch": {"text": "Pine-knot torches (2)", "inputs": {"branches": 1, "pine_pitch": 1}, "n": 2, "seconds": 5.0,
			"verb": "Splitting sticks and working pitch into them", "detail": "a branch and pine pitch: 2 torches"},
	"digging_stick": {"text": "Digging stick", "inputs": {"pole": 1}, "knife": true, "n": 1, "seconds": 6.0,
			"verb": "Whittling a point and hardening it in the fire",
			"detail": "a pole whittled to a point and fire-hardened: breaks ground for a bed, slowly (half a hoe's bite)"},
	# climbing gear (user 2026-09-29): stakes carried on the belt or sash, ashiko copies strapped under the feet while
	# gripping (PlayerGrip). The ashiko copies are handed-down knowledge (know.ashiko: Old Pieter teaches it; the real
	# iron pair is the far-East stranger's, npc.wanderer.shinobi in the backlog).
	"climbing_stakes_wood": {"text": "Climbing stakes, fire-hardened", "inputs": {"branches": 2, "rawhide": 1}, "or": {"rawhide": "cordage"},
			"knife": true, "n": 1, "seconds": 9.0, "verb": "Whittling two hardwood points and hardening them in the coals",
			"detail": "2 branches and a grip wrap (rawhide, or cordage): a pair of stakes for the fists while you climb"},
	"climbing_stakes_bone": {"text": "Climbing stakes, bone", "inputs": {"bone": 2, "rawhide": 1}, "or": {"rawhide": "cordage"},
			"n": 1, "seconds": 11.0, "verb": "Splitting two leg bones and grinding them to points on the stone",
			"detail": "2 deer leg bones and a grip wrap: stakes that bite deeper than wood"},
	"climbing_stakes_stone": {"text": "Climbing stakes, flint-pointed", "inputs": {"flint": 2, "branches": 2, "sinew": 1}, "or": {"sinew": "cordage"},
			"n": 1, "seconds": 12.0, "verb": "Knapping two points and binding them into split hafts",
			"detail": "2 flints, 2 branches and a binding (sinew, or cordage): stakes that bite into bark and cracks"},
	"climbing_claws_wood": {"text": "Ashiko, hardwood", "inputs": {"branches": 2, "buckskin": 1}, "or": {"buckskin": "rawhide"},
			"knife": true, "needs_know": "know.ashiko", "n": 1, "seconds": 11.0,
			"verb": "Carving two soles with teeth at the toe, hardening them, cutting the straps",
			"detail": "2 branches and straps (buckskin, or rawhide): foot claws that ease hanging still"},
	"climbing_claws_bone": {"text": "Ashiko, bone", "inputs": {"bone": 2, "buckskin": 1}, "or": {"buckskin": "rawhide"},
			"needs_know": "know.ashiko", "n": 1, "seconds": 13.0, "verb": "Splitting bone into soles, grinding the teeth, cutting the straps",
			"detail": "2 deer leg bones and straps: foot claws that hold better than wood"},
	"climbing_claws_stone": {"text": "Ashiko, flint-toothed", "inputs": {"flint": 2, "branches": 1, "sinew": 1, "buckskin": 1},
			"or": {"sinew": "cordage", "buckskin": "rawhide"}, "needs_know": "know.ashiko", "n": 1, "seconds": 14.0,
			"verb": "Setting knapped teeth in two wooden soles and binding them",
			"detail": "2 flints, a branch, a binding and straps: foot claws that bite into rock"},
	"cornmeal": {"text": "Cornmeal", "inputs": {"corn": 4}, "n": 1, "seconds": 7.0,
			"verb": "Shelling the ears and pounding the corn on the stone",
			"detail": "4 ears of corn shelled and pounded: a pound of cornmeal (bake it into johnnycake on a fire)"},
}
## The knapping stone's things the workbench makes too.
const STONE_AT_BENCH := ["bone_awl", "torch", "digging_stick"]
## The workbench's gunstock (a log cut and carved; the forge makes the barrel and lock).
const BENCH_WOOD := {
	"gunstock": {"text": "Gunstock", "inputs": {"log": 1}, "knife": true, "n": 1, "seconds": 16.0,
			"verb": "Splitting a stock blank from the log and carving it", "detail": "a log (maple or walnut): a carved gunstock"},
}
## Clothes of skin and fur sewn at the workbench (the core's clothing.sew_mitts; an awl and a knife in the kit): the
## recipe, the row, what it takes of the pack.
const SKINS := {
	"rcp.hunting_frock": {"text": "Buckskin hunting frock", "buckskin": 1.0, "what": "frock",
			"detail": "a whole buckskin and a sinew: a fringed frock, worn (warmth on the body)"},
	"rcp.leggings_skin": {"text": "Breechcloth and leggings", "buckskin": 0.5, "what": "leggings",
			"detail": "half a buckskin and a sinew: a breechclout and leggings, worn (warmth on the legs)"},
	"rcp.fur_cap": {"text": "Fur cap", "pelt": true, "what": "cap",
			"detail": "a pelt and a sinew: a fur cap, worn (warmth on the head)"},
}
## Pelts a fur cap is cut from, the first the pack has.
const CAP_PELTS := ["dried_raccoon_pelt", "raccoon_pelt", "dried_fox_pelt", "fox_pelt", "dried_marten_pelt", "marten_pelt",
		"dried_fisher_pelt", "fisher_pelt", "dried_mink_pelt", "mink_pelt", "dried_wolf_pelt", "wolf_pelt"]
## Pelts the hoop takes (pack kind -> the dried one, the core's item).
const PELTS := {"wolf_pelt": ["dried_wolf_pelt", "item.pelt.wolf", "wolf"], "fox_pelt": ["dried_fox_pelt", "item.pelt.fox", "fox"],
		"marten_pelt": ["dried_marten_pelt", "item.pelt.marten", "marten"], "mink_pelt": ["dried_mink_pelt", "item.pelt.mink", "mink"],
		"fisher_pelt": ["dried_fisher_pelt", "item.pelt.fisher", "fisher"],
		"raccoon_pelt": ["dried_raccoon_pelt", "item.pelt.raccoon", "raccoon"]}
const MOCCASINS := "item.cloth.moccasins"
const FUR_ROBE := "item.cloth.fur_robe"

var kind := ""
var interact_reach := 2.6
## The last work's result {what, ok, text, got: {pack kind: units}} (tests).
var last := {}

var _bridge: SurvivalBridge
var _job := ""
var _job_what := ""
var _moved := {}        ## core item -> [pack kind, units, per unit, core count before]
var _saved_loc := ""
var _goods: Node3D
var _mound_fire: TorchFire
var _mound_state: TorchState
var _strips: Array[MeshInstance3D] = []
var _strip_mat: StandardMaterial3D
var _hide: MeshInstance3D
static var _mats := {}


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	add_to_group(&"camp_stations")
	_goods = Node3D.new()
	_goods.name = "Goods"
	add_child(_goods)
	_dress_goods()


func bridge() -> SurvivalBridge:
	if _bridge == null or not is_instance_valid(_bridge):
		_bridge = SurvivalBridge.find(get_tree())
	return _bridge


func piece() -> BuiltPiece:
	return get_parent() as BuiltPiece


# --- E -------------------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_transform * BuildSnap.center_local(kind)


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func highlight_targets() -> Array:
	var p := piece()
	return p.highlight_targets() if p else []


func interact_prompt(player: Node) -> String:
	if _build_mode_on():
		return ""
	var b := bridge()
	if b == null:
		return ""
	if b.work and b.work.working:
		return ""
	match kind:
		"bough_bed":
			return "Sleep on the bough bed"
		"pole_bed":
			return "Sleep in the pole bed"
		"drying_rack":
			return _rack_prompt(player)
		"tanning_frame":
			return "Work hides" + ("" if Campfire._pack_count(player, "deer_hide") > 0 else " (no deer hide in the pack)")
		"alchemy_table":
			return "Make remedies"
		"workbench":
			return "Work at the bench"
		"work_stone":
			return "Knap and work at the stone"
		"forge":
			return "Work at the forge"
		"charcoal_mound":
			return _mound_prompt(player)
		"stretching_hoop":
			return _hoop_prompt(player)
	return ""


## Hold E's list (PlayerInteractor): at the drying rack with jerky ready and venison enough for another batch, both
## taking it down and hanging more.
func interact_actions(player: Node) -> Array:
	var first := interact_prompt(player)
	if first == "":
		return []
	var out: Array = [{"id": "", "text": first}]
	if kind == "drying_rack" and ready_units() > 0:
		var need := _venison_units_for(JERKY_LB)
		if need > 0 and Campfire._pack_count(player, "venison") >= need and _fire_near(DRY_FIRE_M) != null:
			out.append({"id": "hang", "text": "Hang venison to dry (%d venison)" % need})
	return out


func interact_action(player: Node, id: String) -> void:
	if id == "hang":
		if not _build_mode_on() and bridge() != null:
			hang(player)
		return
	interact(player)


func interact(player: Node) -> void:
	if _build_mode_on() or bridge() == null:
		return
	match kind:
		"bough_bed", "pole_bed":
			sleep_in(player)
		"drying_rack":
			if ready_units() > 0:
				take_down(player)
			else:
				hang(player)
		"tanning_frame", "alchemy_table", "workbench", "work_stone", "forge":
			open_menu(player)
		"charcoal_mound":
			mound_work(player)
		"stretching_hoop":
			if hoop_ready() != "":
				take_down_pelt(player)
			else:
				stretch(player)


func _build_mode_on() -> bool:
	return is_instance_valid(BuildMode.current) and BuildMode.current.active


# --- Beds ----------------------------------------------------------------------------------------------------

## The player lies down in the bed and sleeps (SurvivalSleep). False when they cannot (the reason is told).
func sleep_in(player: Node) -> bool:
	var b := bridge()
	if b == null or b.sleeper == null or not (player is FrontierPlayer):
		return false
	var p := player as FrontierPlayer
	var top := 0.16 if kind == "bough_bed" else BuildGeometry.POLE_BED_H + 0.02
	p.global_position = global_transform * Vector3(0, top, 0.25)
	p.velocity = Vector3.ZERO
	p.rotation.y = global_rotation.y + PI
	if b.camp:
		b.camp.refresh()
	return b.sleeper.start()


## Whether `pos` (the player's feet) is in this bed.
func holds(pos: Vector3) -> bool:
	var l := global_transform.affine_inverse() * pos
	var hw := (BuildGeometry.BOUGH_W if kind == "bough_bed" else BuildGeometry.POLE_BED_W) * 0.5 + 0.15
	return absf(l.x) <= hw and absf(l.z) <= BuildGeometry.BED_L * 0.5 + 0.1 and l.y > -0.4 and l.y < 1.0


# --- The drying rack -------------------------------------------------------------------------------------------

## The rack's own location tag (its record in the core).
func tag() -> String:
	var p := piece()
	return "camp.%s.%d" % [kind, p.piece_id if p else get_instance_id()]


func rack_record() -> Dictionary:
	var b := bridge()
	return SurvivalCamp.rack_at(b.core, tag()) if b and b.core else {}


## Pounds hanging, and of those ready to come down.
func hanging_lb() -> float:
	var n := 0.0
	for h in SurvivalUtil.arr(rack_record().get("hanging")):
		n += float(h.get("qty", 0.0))
	return n


func ready_units() -> int:
	var b := bridge()
	if b == null:
		return 0
	var n := 0.0
	for h in SurvivalUtil.arr(rack_record().get("hanging")):
		if b.core.state.minutes >= float(h.get("ready_at", 0.0)):
			n += float(h.get("qty", 0.0))
	return floori(n + 0.0001)


## Game hours until the next strips are dry (0 when some are).
func hours_to_ready() -> float:
	var b := bridge()
	var best := INF
	for h in SurvivalUtil.arr(rack_record().get("hanging")):
		best = minf(best, float(h.get("ready_at", 0.0)) - b.core.state.minutes)
	return maxf(best, 0.0) / 60.0 if best != INF else 0.0


func _rack_prompt(player: Node) -> String:
	var rd := ready_units()
	if rd > 0:
		return "Take down %d jerky" % rd
	var need := _venison_units_for(JERKY_LB)
	var have := Campfire._pack_count(player, "venison")
	var line := ""
	if have >= need:
		line = "Hang venison to dry (%d venison)" % need
		if _fire_near(DRY_FIRE_M) == null:
			line += " (needs a lit campfire under or beside it)"
	else:
		line = "Hang venison to dry (needs %d venison)" % need
	if hanging_lb() > 0.0:
		line += "      Drying: %d lb, ready in %d hours" % [roundi(hanging_lb()), ceili(hours_to_ready())]
	return line


## Pack venison units that make up `lb` with what raw venison the core already has.
func _venison_units_for(lb: float) -> int:
	var b := bridge()
	var e: Dictionary = b.items.get("venison", {})
	var per := float(e.get("qty", 7.0))
	var has := SurvivalInventory.count(b.core, String(e.get("item", "item.food.venison_raw")))
	return maxi(ceili((lb - has) / per - 0.0001), 0)


## Venison on the rack over the fire: the core's jerk_scaffold job. False when it cannot start (told why).
func hang(player: Node) -> bool:
	var b := bridge()
	var f := _fire_near(DRY_FIRE_M)
	if f == null:
		b._notice("The meat must hang over a lit campfire: build the rack over one, or light the one beside it")
		return false
	var need := _venison_units_for(JERKY_LB)
	if Campfire._pack_count(player, "venison") < need:
		b._notice("Hang venison to dry: %d lb a batch, %d venison" % [int(JERKY_LB), need])
		return false
	return _start_recipe("preserve.jerk_scaffold", "rcp.jerky", {"venison": need}, "high", "Cutting strips and hanging them over the fire", f, tag(), "jerky")


## The dry jerky off the rack into the pack.
func take_down(player: Node) -> int:
	var b := bridge()
	var r := rack_record()
	if r.is_empty():
		return 0
	var keep := []
	var lb := 0.0
	var underdried := false
	for h in SurvivalUtil.arr(r.get("hanging")):
		if b.core.state.minutes >= float(h.get("ready_at", 0.0)):
			lb += float(h.get("qty", 0.0))
			underdried = underdried or String(h.get("id", "")).ends_with("underdried")
		else:
			keep.append(h)
	var units := floori(lb + 0.0001)
	if units <= 0:
		return 0
	r["hanging"] = keep
	if lb - units > 0.0001:
		SurvivalInventory.add(b.core, "item.food.jerky", lb - units)        # a part pound stays with the kit
	var inv := InventoryState.from_player(player)
	inv.add("jerky", units)
	player.set("inventory_pack", inv.pack.duplicate(true))
	b._notice("You take down %d jerky%s" % [units, " (not quite dry: eat it soon)" if underdried else ""])
	_dress_goods()
	return units


# --- Menus: the tanning frame and the alchemy table ------------------------------------------------------------------

## The station's menu rows: [{text, detail, ok, id}].
func menu_rows(player: Node) -> Array:
	var rows: Array = []
	if kind == "tanning_frame":
		var hides := Campfire._pack_count(player, "deer_hide")
		var agent := "brains" if Campfire._pack_count(player, "brains") > 0 else ("cornmeal" if Campfire._pack_count(player, "cornmeal") > 0 else "")
		var fire := _fire_near(TAN_FIRE_M) != null
		var why := ""
		if hides <= 0:
			why = "needs a deer hide"
		elif agent == "":
			why = "needs brains or cornmeal to work into the hide"
		elif not fire:
			why = "needs a lit campfire beside the frame to smoke it"
		rows.append({"id": "rcp.dress_hide", "text": "Dress a deer hide into buckskin",
				"detail": ("a deer hide and %s, smoked over the fire: soft buckskin (a day's cure)" % (agent if agent != "" else "brains or cornmeal")) if why == "" else why,
				"ok": why == "", "agent": agent})
		rows.append({"id": "rcp.rawhide", "text": "Scrape a deer hide into rawhide",
				"detail": "a deer hide, fleshed and scraped, dried hard on the frame: 2 rawhide for lacing" if hides > 0 else "needs a deer hide",
				"ok": hides > 0})
		var rwhy := ""
		if Campfire._pack_count(player, "bison_robe") <= 0:
			rwhy = "needs a buffalo robe (skinned from a bison)"
		elif agent == "":
			rwhy = "needs brains or cornmeal to work into the robe"
		rows.append({"id": "rcp.dress_robe", "text": "Dress a buffalo robe with the hair on",
				"detail": ("the green robe and %s, worked soft on the frame: a fur robe to wear and sleep under" % agent) if rwhy == "" else rwhy,
				"ok": rwhy == "", "agent": agent})
	elif kind == "alchemy_table":
		var fire := _fire_near(TABLE_FIRE_M) != null
		for id: String in Remedies.RECIPES:
			var r: Dictionary = Remedies.RECIPES[id]
			var why := ""
			for k: String in r.inputs:
				if Campfire._pack_count(player, k) < int(r.inputs[k]):
					why = "needs %d %s" % [int(r.inputs[k]), InventoryState.name_of(k).to_lower()]
			if why == "" and bool(r.fire) and not fire:
				why = "needs a lit campfire beside the table"
			rows.append({"id": id, "text": InventoryState.name_of(id), "detail": String(r.detail) if why == "" else why, "ok": why == ""})
	elif kind == "workbench":
		rows.append_array(_bench_rows(player))
	elif kind == "work_stone":
		rows.append_array(_stone_rows(player))
	elif kind == "forge":
		for id: String in FORGE:
			rows.append(_table_row(player, id, FORGE[id]))
	return rows


## The knapping stone's rows: its own work (STONE), the weapons made whole (ARMS), then what arms them (BENCH: arrows,
## darts, a chert-pointed throwing spear).
func _stone_rows(player: Node) -> Array:
	var rows: Array = []
	for id: String in STONE:
		rows.append(_table_row(player, id, STONE[id]))
	rows.append_array(_arms_rows(player))
	for id: String in BENCH:
		var r: Dictionary = BENCH[id]
		var why2 := _bench_why(player, r)
		rows.append({"id": id, "text": String(r.text), "ok": why2 == "", "detail": String(r.detail) if why2 == "" else why2})
	return rows


## A row of a STONE / GEAR table entry: made from the pack (with an `or` stand-in), a knife when it asks for one.
func _table_row(player: Node, id: String, g: Dictionary) -> Dictionary:
	var why := _gear_why(player, g) if _inputs_for(player, g).is_empty() else ""
	if why == "" and bool(g.get("knife", false)) and not _has_knife(player):
		why = "needs a knife (a flint knife: the knapping stone)"
	if not _knows(g):
		why = "you do not know how (Old Pieter, the old hunter, could teach you)"
	var st := StationPractice.standard_at(StationPractice.makes(_core(), id))
	if why == "" and st != "plain":
		return {"id": id, "text": "%s  (%s)" % [String(g.text), st], "ok": true, "detail": String(g.detail)}
	return {"id": id, "text": String(g.text), "ok": why == "", "detail": String(g.detail) if why == "" else why}


func _arms_rows(player: Node) -> Array:
	var rows: Array = []
	for id: String in ARMS:
		if ARMS[id].has("at") and not (kind in (ARMS[id].at as Array)):
			continue
		if not (player.get("weapons") as Dictionary).has(String(ARMS[id].weapon)):
			continue                          # (a weapon this character's roster does not have)
		var why := _arm_why(player, id)
		rows.append({"id": id, "text": String(ARMS[id].text), "ok": why == "", "detail": String(ARMS[id].detail) if why == "" else why})
	return rows


## Why ARMS `id` cannot be made now: already carrying one, a knife, its things ("" when it can).
func _arm_why(player: Node, id: String) -> String:
	var g: Dictionary = ARMS[id]
	var key := String(g.weapon)
	if player.has_method("is_carried") and bool(player.call("is_carried", key)):
		return "you carry one already"
	if not _has_knife(player):
		return "needs a knife (a flint knife: the knapping stone)"
	if _inputs_for(player, g).is_empty():
		return _gear_why(player, g)
	return ""


static func _has_knife(player: Node) -> bool:
	return Campfire._pack_count(player, "skinning_knife") > 0 or Campfire._pack_count(player, "flint_knife") > 0


## What table entry `g` takes from this pack now ({kind: units}: an `or` kind where the first is short); {} when it
## cannot be made.
static func _inputs_for(player: Node, g: Dictionary) -> Dictionary:
	var out := {}
	for k: String in g.inputs:
		var n := int(g.inputs[k])
		var alt := String((g.get("or", {}) as Dictionary).get(k, ""))
		if Campfire._pack_count(player, k) >= n:
			out[k] = n
		elif alt != "" and Campfire._pack_count(player, alt) >= n:
			out[alt] = n
		else:
			return {}
	return out


## A garment of skin or fur (SKINS) at the workbench: the buckskin or a pelt and a sinew into the core's kit, its
## clothing.sew_mitts job (the Hidecraft check; the kit's awl and knife). False, with everything given back, when it
## cannot start.
func _skin_make(player: Node, id: String) -> bool:
	var g: Dictionary = SKINS[id]
	if not _has_core_or_pack(player, "sinew", 1.0):
		return false
	var ins := {"sinew": _units_needed("sinew", 1.0)}
	if g.has("buckskin"):
		if not _has_core_or_pack(player, "buckskin", float(g.buckskin)):
			return false
		ins["buckskin"] = _units_needed("buckskin", float(g.buckskin))
	else:
		var pk := _cap_pelt(player)
		if pk == "":
			return false
		ins[pk] = 1
	return _start_recipe("clothing.sew_mitts", id, ins, "table", "Cutting and sewing a %s" % String(g.text).to_lower(), null, "", String(g.what))


## A weapon made whole (ARMS): its things taken, the work, then the weapon is the player's. False when it cannot start.
func _arm_make(player: Node, id: String) -> bool:
	if _arm_why(player, id) != "":
		return false
	var g: Dictionary = ARMS[id]
	var ins := _inputs_for(player, g)
	var inv := InventoryState.from_player(player)
	for k: String in ins:
		inv.take(k, int(ins[k]))
	player.set("inventory_pack", inv.pack.duplicate(true))
	var key := String(g.weapon)
	var ok := bridge().work.begin(global_position, "low" if kind == "work_stone" else "table", String(g.verb), float(g.seconds), "", func(done: bool) -> void:
		if done:
			player.call("set_carried", key, true, false)
			var then := {"bow": "make arrows for its quiver", "atlatl": "make darts for it"}.get(key, "load it with powder and ball") as String
			_result(id, true, "You make a %s: it is yours (%s)" % [String(g.text).to_lower(), then], {id: 1})
		else:
			var inv2 := InventoryState.from_player(player)
			for k2: String in ins:
				inv2.add(k2, int(ins[k2]))
			player.set("inventory_pack", inv2.pack.duplicate(true))
			_result(id, false, "", {}))
	if not ok:
		var inv3 := InventoryState.from_player(player)
		for k: String in ins:
			inv3.add(k, int(ins[k]))
		player.set("inventory_pack", inv3.pack.duplicate(true))
	return ok


## The workbench's clothes of skin and fur (SKINS): buckskin or a pelt, and a sinew (the pack's or the kit's).
func _skin_rows(player: Node) -> Array:
	var rows: Array = []
	var sinew := _has_core_or_pack(player, "sinew", 1.0)
	for id: String in SKINS:
		var g: Dictionary = SKINS[id]
		var why := ""
		if g.has("buckskin") and not _has_core_or_pack(player, "buckskin", float(g.buckskin)):
			why = "needs %s buckskin (the tanning frame dresses it)" % ("a whole" if float(g.buckskin) >= 1.0 else "half a")
		elif g.has("pelt") and _cap_pelt(player) == "":
			why = "needs a pelt (raccoon, fox, marten, fisher, mink or wolf)"
		elif not sinew:
			why = "needs a sinew (butcher a deer)"
		rows.append({"id": id, "text": String(g.text), "ok": why == "", "detail": String(g.detail) if why == "" else why})
	return rows


func _cap_pelt(player: Node) -> String:
	for k: String in CAP_PELTS:
		if Campfire._pack_count(player, k) > 0:
			return k
	return ""


## Why the STONE / GEAR row `g` cannot be made from this pack ("needs 2 flint or ..."), or "".
func _gear_why(player: Node, g: Dictionary) -> String:
	for k: String in g.inputs:
		var alt := String((g.get("or", {}) as Dictionary).get(k, ""))
		if Campfire._pack_count(player, k) < int(g.inputs[k]) and (alt == "" or Campfire._pack_count(player, alt) < int(g.inputs[k])):
			var why := "needs %d %s" % [int(g.inputs[k]), InventoryState.name_of(k).to_lower()]
			if alt != "":
				why += " or %s" % InventoryState.name_of(alt).to_lower()
			return why
	return ""


## Why BENCH row `r` cannot be made now: its things, a weapon to arm (a bow for arrows, an atlatl for darts; a throwing
## spear is itself a weapon and is picked up when made), room for more ("" when it can).
func _bench_why(player: Node, r: Dictionary) -> String:
	if _inputs_for(player, r).is_empty():
		for k: String in r.inputs:
			var alt := String((r.get("or", {}) as Dictionary).get(k, ""))
			if Campfire._pack_count(player, k) < int(r.inputs[k]) and (alt == "" or Campfire._pack_count(player, alt) < int(r.inputs[k])):
				var w := "needs %d %s" % [int(r.inputs[k]), BuildSnap._item_word(k, int(r.inputs[k]))]
				if alt != "":
					w += " or %s" % BuildSnap._item_word(alt, int(r.inputs[k]))
				return w
	var key := String(r.weapon)
	if key != "spear" and player.has_method("is_carried") and not bool(player.call("is_carried", key)):
		return "needs %s" % ("a bow" if key == "bow" else "an atlatl")
	var w: Variant = (player.get("weapons") as Dictionary).get(key) if player.get("weapons") is Dictionary else null
	if w is Throwable and (w as Throwable).count >= (w as Throwable).max_count:
		return "you carry all you can (%d)" % (w as Throwable).max_count
	return ""


## The workbench's rows: the kit's moccasins and mitts (the core's), then the arms (BENCH).
func _bench_rows(player: Node) -> Array:
	var rows: Array = []
	var core := bridge().core
	var pairs := int(round(SurvivalInventory.count(core, MOCCASINS)))
	var worn := SurvivalInventory.wear_of(core, MOCCASINS)
	var sinew := _has_core_or_pack(player, "sinew", 1.0)
	var why := ""
	if not _has_core_or_pack(player, "buckskin", 0.33):
		why = "needs buckskin (the tanning frame dresses it)"
	elif not sinew:
		why = "needs a sinew (butcher a deer)"
	rows.append({"id": "rcp.moccasins", "text": "Moccasins", "ok": why == "",
			"detail": ("a third of a buckskin and a sinew: a pair into your kit (%d pairs, the worn pair %d%% worn)" % [pairs, roundi(worn * 100.0)]) if why == "" else why})
	why = ""
	if not SurvivalInventory.needs_mending(core, [MOCCASINS]):
		why = "your moccasins are whole (%d%% worn)" % roundi(worn * 100.0)
	elif SurvivalInventory.count(core, "item.material.hide_scrap") < 1.0:
		why = "needs a hide scrap (left from dressing a hide)"
	elif not sinew:
		why = "needs a sinew (butcher a deer)"
	rows.append({"id": "clothing.repair_moccasins", "text": "Mend your moccasins", "ok": why == "",
			"detail": ("a hide scrap and a sinew: the worn pair (%d%% worn) patched" % roundi(worn * 100.0)) if why == "" else why})
	why = ""
	var fur := _mitt_skin(player)
	if fur == "":
		why = "needs a pelt or buckskin"
	elif not sinew:
		why = "needs a sinew (butcher a deer)"
	rows.append({"id": "rcp.mitts_fur", "text": "Fur mitts", "ok": why == "",
			"detail": ("a %s and a sinew: warm mitts into your kit (%d pairs)" % [InventoryState.name_of(fur).to_lower(), int(round(SurvivalInventory.count(core, "item.cloth.mitts")))]) if why == "" else why})
	rows.append_array(_skin_rows(player))
	for id: String in BENCH:
		var r: Dictionary = BENCH[id]
		why = _bench_why(player, r)
		rows.append({"id": id, "text": String(r.text), "ok": why == "", "detail": String(r.detail) if why == "" else why})
	rows.append_array(_arms_rows(player))
	# the trapper's and the angler's gear (GEAR)
	for id: String in GEAR:
		var g: Dictionary = GEAR[id]
		var ins := gear_inputs(player, id)
		why = ""
		if ins.is_empty():
			for k: String in g.inputs:
				var alt := String((g.get("or", {}) as Dictionary).get(k, ""))
				if Campfire._pack_count(player, k) < int(g.inputs[k]) and (alt == "" or Campfire._pack_count(player, alt) < int(g.inputs[k])):
					why = "needs %d %s" % [int(g.inputs[k]), InventoryState.name_of(k).to_lower()]
					if alt != "":
						why += " or %s" % InventoryState.name_of(alt).to_lower()
					break
		rows.append({"id": id, "text": String(g.text), "ok": why == "", "detail": String(g.detail) if why == "" else why})
	# the knapping stone's awl and torches, here too
	for id: String in STONE_AT_BENCH:
		rows.append(_table_row(player, id, STONE[id]))
	for id: String in BENCH_WOOD:
		rows.append(_table_row(player, id, BENCH_WOOD[id]))
	# the vices' stuff (Vices.BENCH): snuff, a quid, sweet cider
	for id: String in Vices.BENCH:
		var r: Dictionary = Vices.BENCH[id]
		why = ""
		for k: String in r.inputs:
			if Campfire._pack_count(player, k) < int(r.inputs[k]):
				why = "needs %d %s" % [int(r.inputs[k]), InventoryState.name_of(k).to_lower()]
		rows.append({"id": id, "text": InventoryState.name_of(id), "ok": why == "", "detail": String(r.detail) if why == "" else why})
	return rows


## Whether the core's kit and the pack between them hold `need` of `kind`'s core item.
func _has_core_or_pack(player: Node, kind: String, need: float) -> bool:
	var m := bridge().pack_item(kind)
	if m.is_empty():
		return false
	var have := SurvivalInventory.count(bridge().core, String(m.item)) + Campfire._pack_count(player, kind) * float(m.get("qty", 1.0))
	return have >= need - 0.001


## Pack units of `kind` to move so the core holds `need` of its item.
func _units_needed(kind: String, need: float) -> int:
	var m := bridge().pack_item(kind)
	var have := SurvivalInventory.count(bridge().core, String(m.item))
	return maxi(ceili((need - have) / float(m.get("qty", 1.0)) - 0.001), 0)


## The skin fur mitts are sewn from: a fox pelt before a wolf's, dried before green, else buckskin ("" when none).
func _mitt_skin(player: Node) -> String:
	for k in ["dried_fox_pelt", "fox_pelt", "dried_wolf_pelt", "wolf_pelt", "buckskin"]:
		if Campfire._pack_count(player, k) > 0:
			return k
	return ""


func open_menu(player: Node) -> void:
	var rows := menu_rows(player)
	if rows.is_empty():
		return
	var m := StationMenu.open(get_tree(), BuildData.get_default().name_of(kind), rows)
	var i: int = await m.picked
	if i >= 0 and i < rows.size():
		make(player, String(rows[i].id))


## Makes `id` (a tanning recipe or a remedy) at the station. False when it cannot start.
func make(player: Node, id: String) -> bool:
	var b := bridge()
	if b == null or b.work.working:
		return false
	match id:
		"rcp.dress_hide":
			var f := _fire_near(TAN_FIRE_M)
			var agent := "brains" if Campfire._pack_count(player, "brains") > 0 else "cornmeal"
			if f == null or Campfire._pack_count(player, "deer_hide") <= 0 or Campfire._pack_count(player, agent) <= 0:
				return false
			return _start_recipe("craft.dress_hide", id, {"deer_hide": 1, agent: 1}, "low", "Working the hide over the beam, then smoking it", f, "", "buckskin")
		"rcp.rawhide":
			if Campfire._pack_count(player, "deer_hide") <= 0:
				return false
			return _start_recipe("craft.dress_hide", id, {"deer_hide": 1}, "low", "Fleshing and scraping the hide", null, "", "rawhide")
		"rcp.dress_robe":
			var ra := "brains" if Campfire._pack_count(player, "brains") > 0 else "cornmeal"
			if Campfire._pack_count(player, "bison_robe") <= 0 or Campfire._pack_count(player, ra) <= 0:
				return false
			return _start_recipe("craft.dress_hide", id, {"bison_robe": 1, ra: 1}, "low", "Fleshing the robe, working brains into it and softening it by hand",
					null, "", "robe")
	match id:
		"rcp.moccasins":
			if not (_has_core_or_pack(player, "buckskin", 0.33) and _has_core_or_pack(player, "sinew", 1.0)):
				return false
			return _start_recipe("craft.moccasins", id, {"buckskin": _units_needed("buckskin", 0.33), "sinew": _units_needed("sinew", 1.0)},
					"table", "Cutting and sewing moccasins", null, "", "moccasins")
		"clothing.repair_moccasins":
			if not _has_core_or_pack(player, "sinew", 1.0):
				return false
			return _start_recipe("clothing.repair_moccasins", "", {"sinew": _units_needed("sinew", 1.0)}, "table", "Patching the worn moccasins",
					null, "", "mend")
		"rcp.mitts_fur":
			var fur := _mitt_skin(player)
			if fur == "" or not _has_core_or_pack(player, "sinew", 1.0):
				return false
			return _start_recipe("clothing.sew_mitts", id, {fur: 1, "sinew": _units_needed("sinew", 1.0)}, "table", "Cutting and sewing fur mitts",
					null, "", "mitts")
	if kind == "workbench" and SKINS.has(id):
		return _skin_make(player, id)
	if BENCH.has(id):
		return _bench_make(player, id)
	if ARMS.has(id):
		return _arm_make(player, id)
	if not _gear_def(id).is_empty():
		return _gear_make(player, id)
	if Remedies.RECIPES.has(id) or (kind == "workbench" and Vices.BENCH.has(id)):
		var r: Dictionary = Remedies.RECIPES[id] if Remedies.RECIPES.has(id) else Vices.BENCH[id]
		var made := int(r.get("n", 1))
		for k: String in r.inputs:
			if Campfire._pack_count(player, k) < int(r.inputs[k]):
				return false
		if bool(r.fire) and _fire_near(TABLE_FIRE_M) == null:
			return false
		var inv := InventoryState.from_player(player)
		for k: String in r.inputs:
			inv.take(k, int(r.inputs[k]))
		player.set("inventory_pack", inv.pack.duplicate(true))
		var ok := b.work.begin(global_position, "table", String(r.verb), float(r.seconds), "", func(done: bool) -> void:
			var inv2 := InventoryState.from_player(player)
			if done:
				inv2.add(id, made)
				if id == "sweet_cider" and b.vices:
					b.vices.pressed_cider(made)
				_result(id, true, "You make %s" % (("a " + InventoryState.name_of(id).to_lower()) if made == 1
						else "%d %s" % [made, InventoryState.name_of(id).to_lower()]), {id: made})
			else:
				for k2: String in r.inputs:
					inv2.add(k2, int(r.inputs[k2]))
				_result(id, false, "", {})
			player.set("inventory_pack", inv2.pack.duplicate(true)))
		if not ok:
			var inv3 := InventoryState.from_player(player)
			for k: String in r.inputs:
				inv3.add(k, int(r.inputs[k]))
			player.set("inventory_pack", inv3.pack.duplicate(true))
		return ok
	return false


## Arrows, a spear or darts at the workbench: the pack's branches, poles and flint, a few seconds, then into the weapon.
func _bench_make(player: Node, id: String) -> bool:
	var r: Dictionary = BENCH[id]
	if _bench_why(player, r) != "":
		return false
	var ins := _inputs_for(player, r)
	var weapons: Dictionary = player.get("weapons") if player.get("weapons") is Dictionary else {}
	var w: Variant = weapons.get(String(r.weapon))
	if w == null:
		return false
	var inv := InventoryState.from_player(player)
	for k: String in ins:
		inv.take(k, int(ins[k]))
	player.set("inventory_pack", inv.pack.duplicate(true))
	var ok := bridge().work.begin(global_position, "low" if kind == "work_stone" else "table", String(r.verb), float(r.seconds), "", func(done: bool) -> void:
		if done:
			var n := int(r.n)
			if w is Bow:
				(w as Bow).add_arrows(n)
			elif w is Throwable:
				n = (w as Throwable).add_items(n)
				# a spear made from nothing is the player's (put on the back where it fits)
				if player.has_method("is_carried") and not bool(player.call("is_carried", String(r.weapon))):
					player.call("set_carried", String(r.weapon), true, false)
			_result(id, true, "You make %s: %s" % [String(r.text).to_lower(), _arms_text(w)], {id: n})
		else:
			var inv2 := InventoryState.from_player(player)
			for k2: String in ins:
				inv2.add(k2, int(ins[k2]))
			player.set("inventory_pack", inv2.pack.duplicate(true))
			_result(id, false, "", {}))
	if not ok:
		var inv3 := InventoryState.from_player(player)
		for k: String in ins:
			inv3.add(k, int(ins[k]))
		player.set("inventory_pack", inv3.pack.duplicate(true))
	return ok


## What `id` of GEAR takes from this pack now ({kind: units}: an `or` kind where the first is missing); {} when it
## cannot be made.
func gear_inputs(player: Node, id: String) -> Dictionary:
	var g := _gear_def(id)
	if g.is_empty():
		return {}
	var out := {}
	for k: String in g.inputs:
		var n := int(g.inputs[k])
		var alt := String((g.get("or", {}) as Dictionary).get(k, ""))
		if Campfire._pack_count(player, k) >= n:
			out[k] = n
		elif alt != "" and Campfire._pack_count(player, alt) >= n:
			out[alt] = n
		else:
			return {}
	return out


## Cordage, a rod, a spear or deadfall stakes at the workbench: the pack's things, a few seconds, then into the pack.
## The GEAR / STONE entry `id` made here ({} when this station does not make it).
func _gear_def(id: String) -> Dictionary:
	if kind == "workbench" and GEAR.has(id):
		return GEAR[id]
	if kind == "workbench" and BENCH_WOOD.has(id):
		return BENCH_WOOD[id]
	if kind == "forge" and FORGE.has(id):
		return FORGE[id]
	if STONE.has(id) and (kind == "work_stone" or (kind == "workbench" and id in STONE_AT_BENCH)):
		return STONE[id]
	return {}


## Handed-down knowledge a station recipe needs (`needs_know`): heard of is enough to try (a make promotes it).
func _knows(g: Dictionary) -> bool:
	var kid := String(g.get("needs_know", ""))
	var core := _core()
	return kid == "" or core == null or SurvivalLearning.rank(SurvivalLearning.state_of(core, kid)) >= SurvivalLearning.rank("heard_of")


func _core() -> SurvivalCore:
	var b := bridge()
	return b.core if b else null


func _gear_make(player: Node, id: String) -> bool:
	var g := _gear_def(id)
	var ins := gear_inputs(player, id)
	if g.is_empty() or ins.is_empty() or (bool(g.get("knife", false)) and not _has_knife(player)) or not _knows(g):
		return false
	var inv := InventoryState.from_player(player)
	for k: String in ins:
		inv.take(k, int(ins[k]))
	player.set("inventory_pack", inv.pack.duplicate(true))
	var made := int(g.n)
	var makes := String(g.get("makes", id))
	var ok := bridge().work.begin(global_position, "low" if kind == "work_stone" else "table", String(g.verb), float(g.seconds), "", func(done: bool) -> void:
		var inv2 := InventoryState.from_player(player)
		if done and makes == InventoryState.TORCH:
			player.torch.add_torches(made)      # (torches ride in the pack through PlayerTorch)
		elif done and g.has("weapon"):
			# a thrown weapon forged: one more carried (it is the player's, if it was not)
			var w: Variant = (player.get("weapons") as Dictionary).get(String(g.weapon))
			if w is Throwable:
				(w as Throwable).add_items(made)
			if player.has_method("is_carried") and not bool(player.call("is_carried", String(g.weapon))):
				player.call("set_carried", String(g.weapon), true, false)
		elif done:
			inv2.add(makes, made)
		else:
			for k2: String in ins:
				inv2.add(k2, int(ins[k2]))
		# practice: the standard this make came out at (StationPractice), stamped on the pack's stack
		var st: String = StationPractice.note_make(_core(), id) if done else "plain"
		if done:
			StationPractice.stamp(inv2.pack, makes, st)
			var kid := String(g.get("needs_know", ""))
			if kid != "" and _core() and SurvivalLearning.state_of(_core(), kid) in ["heard_of", "seen"]:
				SurvivalLearning.record_result(_core(), kid, "success")
		player.set("inventory_pack", inv2.pack.duplicate(true))
		if done:
			bridge().sync_carried_tools()
			var nm := InventoryState.name_of(makes).to_lower()
			_result(id, true, "You make %s" % (StationPractice.named(st, nm) if made == 1 else "%d lengths of %s" % [made, nm]
					if makes == "cordage" else "%d %s" % [made, nm]), {makes: made})
		else:
			_result(id, false, "", {}))
	if not ok:
		var inv3 := InventoryState.from_player(player)
		for k: String in ins:
			inv3.add(k, int(ins[k]))
		player.set("inventory_pack", inv3.pack.duplicate(true))
	return ok


static func _arms_text(w: Variant) -> String:
	if w is Bow:
		return "%d arrows in the quiver" % (w as Bow).quiver
	if w is Throwable:
		return "%d of %d carried" % [(w as Throwable).count, (w as Throwable).max_count]
	return ""


# --- The charcoal mound --------------------------------------------------------------------------------------

## The core's record of this mound: {lit_at, ready_at} while it chars (kept in its save); {} not yet fired.
func mound_record() -> Dictionary:
	var core := bridge().core
	if not core.state.world.has("mounds"):
		core.state.world["mounds"] = {}
	var h: Dictionary = core.state.world.mounds
	if not h.has(tag()):
		h[tag()] = {}
	return h[tag()]


## "" laid and cold, "burning", "done".
func mound_state() -> String:
	var r := mound_record()
	if r.is_empty():
		return ""
	return "done" if bridge().core.state.minutes >= float(r.get("ready_at", 0.0)) else "burning"


func _mound_prompt(player: Node) -> String:
	match mound_state():
		"burning":
			var h := maxf(float(mound_record().ready_at) - bridge().core.state.minutes, 0.0) / 60.0
			return "The mound is charring: ready in %d hours" % ceili(h)
		"done":
			return "Break open the mound: %d charcoal" % CHAR_YIELD
	if Campfire._torch_lit(player) or Campfire._has_striker(player):
		return "Fire the charcoal mound"
	if Campfire._has_drill(player):
		return "Fire the charcoal mound with the bow drill"
	return "Fire the charcoal mound (needs a torch, flint and steel or a bow drill)"


## E at the mound: fire it (a lit torch or a striker at once; a bow drill takes a few seconds and may not catch), or
## when it is done break it open: the charcoal into the pack and the mound gone.
func mound_work(player: Node) -> bool:
	var b := bridge()
	if b == null or b.work.working:
		return false
	match mound_state():
		"burning":
			return false
		"done":
			var inv := InventoryState.from_player(player)
			inv.add("charcoal", CHAR_YIELD)
			player.set("inventory_pack", inv.pack.duplicate(true))
			(b.core.state.world.mounds as Dictionary).erase(tag())
			_result("charcoal", true, "You break open the mound: %d charcoal" % CHAR_YIELD, {"charcoal": CHAR_YIELD})
			var w := BuildWorld.of(get_tree(), false)
			if w and piece():
				w.remove_piece(piece())
			return true
	if Campfire._torch_lit(player) or Campfire._has_striker(player):
		_fire_mound()
		return true
	if Campfire._has_drill(player):
		return b.work.begin(global_position, "low", "Twirling the bow drill for a coal to fire the mound", Campfire.DRILL_S, "", func(done: bool) -> void:
			if not done:
				return
			var p := clampf(Campfire.DRILL_BASE + SurvivalSkills.level(b.core, "survival") * Campfire.DRILL_PER_LEVEL, 0.1, 0.95)
			if b.core.rng.randf() < p:
				SurvivalSkills.practice(b.core, "survival", 1.5)
				_fire_mound()
			else:
				SurvivalSkills.practice(b.core, "survival", 0.6)
				b._notice("Smoke, but no coal yet: twirl it again"))
	return false


func _fire_mound() -> void:
	var now := bridge().core.state.minutes
	var r := mound_record()
	r["lit_at"] = now
	r["ready_at"] = now + CHAR_MIN
	bridge()._notice("The mound is fired: it chars slowly under the earth, about %d hours" % roundi(CHAR_MIN / 60.0))
	_mound_look()


## Smoke from the chimney while it chars (a smudge hidden inside the dome), nothing when cold or done.
func _mound_look() -> void:
	if kind != "charcoal_mound" or bridge() == null:
		return
	var on := mound_state() == "burning"
	if _mound_fire == null and on:
		_mound_state = TorchState.new(1.0e6)
		_mound_fire = TorchFire.new()
		_mound_fire.name = "Charring"
		_mound_fire.fire_size = 0.5
		_mound_fire.amount_mult = 0.6
		_mound_fire.light_range = 0.1
		_mound_fire.energy = 0.0
		_mound_fire.state = _mound_state
		_mound_fire.position = Vector3(0, 0.25, 0)
		_mound_fire.smoke_offset = Vector3(0, BuildGeometry.MOUND_H - 0.2, 0)
		add_child(_mound_fire)
	if _mound_state:
		if on and not _mound_state.lit:
			_mound_state.light()
		elif not on and _mound_state.lit:
			_mound_state.snuff("burnt")


# --- The stretching hoop -------------------------------------------------------------------------------------

## The core's record of what is on this hoop: [{id, meta, pelt (pack kind), hung_at, ready_at}] (kept in its save).
func hoop_record() -> Array:
	var core := bridge().core
	if not core.state.world.has("hoops"):
		core.state.world["hoops"] = {}
	var h: Dictionary = core.state.world.hoops
	if not h.has(tag()):
		h[tag()] = []
	return h[tag()]


## The pack kind of a dried pelt ready to come off ("" when none is).
func hoop_ready() -> String:
	var b := bridge()
	if b == null:
		return ""
	for e: Dictionary in hoop_record():
		if b.core.state.minutes >= float(e.get("ready_at", 0.0)):
			return String(e.get("pelt", ""))
	return ""


func _hoop_prompt(player: Node) -> String:
	var rd := hoop_ready()
	if rd != "":
		return "Take down the %s" % InventoryState.name_of(PELTS[rd][0]).to_lower()
	var on := hoop_record()
	if not on.is_empty():
		var h := maxf(float(on[0].get("ready_at", 0.0)) - bridge().core.state.minutes, 0.0) / 60.0
		return "The %s dries on the hoop: ready in %d hours" % [InventoryState.name_of(String(on[0].pelt)).to_lower(), ceili(h)]
	for k: String in PELTS:
		var n := Campfire._pack_count(player, k)
		if n > 0:
			return "Stretch a %s on the hoop (%d in the pack)" % [InventoryState.name_of(k).to_lower(), n]
	return "Stretch a pelt (no green pelt in the pack)"


## A green pelt from the pack laced in and fleshed (the core's fur.stretch). False when it cannot start.
func stretch(player: Node) -> bool:
	if not hoop_record().is_empty() or bridge().work.working or SurvivalJobs.is_running(bridge().core):
		return false
	var pk := ""
	for k: String in PELTS:
		if Campfire._pack_count(player, k) > 0:
			pk = k
			break
	if pk == "":
		bridge()._notice("No wolf or fox pelt in the pack")
		return false
	var core := bridge().core
	var inv := InventoryState.from_player(player)
	inv.take(pk, 1)
	player.set("inventory_pack", inv.pack.duplicate(true))
	var item := String(PELTS[pk][1])
	_moved = {item: [pk, 1, 1.0, SurvivalInventory.count(core, item)]}
	SurvivalInventory.add(core, item, 1.0, {"green": true, "grade": "good", "species": String(PELTS[pk][2])})
	return _start_prepared("fur.stretch", {"item": item}, "table", "Lacing the pelt into the hoop and fleshing it", "pelt:" + pk)


## The dried pelt off the hoop into the pack.
func take_down_pelt(player: Node) -> String:
	var core := bridge().core
	var rec := hoop_record()
	for i in rec.size():
		var e: Dictionary = rec[i]
		if core.state.minutes < float(e.get("ready_at", 0.0)):
			continue
		rec.remove_at(i)
		var dried := String(PELTS[String(e.pelt)][0])
		var inv := InventoryState.from_player(player)
		inv.add(dried, 1)
		player.set("inventory_pack", inv.pack.duplicate(true))
		bridge()._notice("You take down the %s: %s" % [InventoryState.name_of(dried).to_lower(), _grade_words(String(SurvivalUtil.dict(e.get("meta")).get("grade", "good")))])
		_dress_goods()
		return dried
	return ""


## The core's pelt grades (SurvivalInventory.GRADE_ORDER) in words.
static func _grade_words(g: String) -> String:
	return {"prime_well_handled": "a prime pelt, well handled", "good": "a good pelt", "fair": "a fair pelt",
			"poor": "a poor pelt"}.get(g, "a %s pelt" % g.replace("_", " "))


# --- The core's recipe jobs ----------------------------------------------------------------------------------

## Puts `inputs` ({pack kind: units}) into the core and starts `action` with `recipe` at this station (the core's fire:
## `fire`; the core's location, for the rack, `loc`), the player working it (StationWork). False, with everything given
## back, when it cannot start.
func _start_recipe(action: String, recipe: String, inputs: Dictionary, height: String, text: String, fire: Campfire,
		loc: String, what: String) -> bool:
	var b := bridge()
	var core := b.core
	var player := b.player
	if b.work.working or SurvivalJobs.is_running(core):
		return false
	if fire and b.camp:
		b.camp.link_fire(fire)
		var d := Vector2(fire.global_position.x - player.global_position.x, fire.global_position.z - player.global_position.z).length()
		b.set_context({"fire_id": fire.fire_id, "fire_distance_m": d})
		b.camp.told = {}
	_moved = {}
	var inv := InventoryState.from_player(player)
	for k: String in inputs:
		var m := b.pack_item(k)
		if m.is_empty():
			continue
		var n := int(inputs[k])
		var item := String(m.item)
		inv.take(k, n)
		_moved[item] = [k, n, float(m.get("qty", 1.0)), SurvivalInventory.count(core, item)]
		SurvivalInventory.add(core, item, n * float(m.get("qty", 1.0)))
	player.inventory_pack = inv.pack.duplicate(true)
	if loc != "":
		_saved_loc = str(core.state.context.get("location", ""))
		b.set_context({"location": loc})
	return _start_prepared(action, {"recipe": recipe} if recipe != "" else {}, height, text, what)


## Starts `action` with `params` once its inputs are in the core (_moved), the player working it. False, with the inputs
## given back, when it cannot start.
func _start_prepared(action: String, params: Dictionary, height: String, text: String, what: String) -> bool:
	var b := bridge()
	var core := b.core
	var r := core.start_job(action, params)
	if not bool(r.get("ok", false)):
		_give_back()
		_restore_loc()
		var rs: Array = r.get("reasons", [])
		b._notice("You cannot do that now: %s" % (String(rs[0]) if not rs.is_empty() else String(r.get("reason", "not now"))))
		return false
	_job = action
	_job_what = what
	if not core.job_finished.is_connected(_on_finished):
		core.job_finished.connect(_on_finished)
	if not core.job_interrupted.is_connected(_on_interrupted):
		core.job_interrupted.connect(_on_interrupted)
	if not b.work.begin(global_position, height, text, 0.0, action, _on_work_end):
		core.cancel_job("moved")
		_job = ""
		_give_back()
		_restore_loc()
		return false
	return true


func _on_finished(res: Dictionary) -> void:
	if _job == "" or String(res.get("action", "")) != _job:
		return
	_job = ""
	var b := bridge()
	var core := b.core
	var got := {}
	var cr: Dictionary = res.get("recipe", {})
	var on_rack := cr.has("rack")
	if _job_what.begins_with("pelt:"):
		_pelt_stretched(res)
		return
	for item: String in SurvivalUtil.dict(res.get("gained")):
		if on_rack and item.begins_with("item.food.jerky"):
			continue                                 # it hangs on the rack
		var k := b.pack_kind_of(item)
		if k == "":
			continue                                 # (deer hair, a hide scrap: the kit keeps them)
		var per := float(b.pack_item(k).get("qty", 1.0))
		var have := SurvivalInventory.count(core, item)
		var units := floori(minf(float(res.gained[item]), have) / per + 0.0001)
		if units <= 0:
			continue
		SurvivalInventory.remove(core, item, units * per)
		got[k] = int(got.get(k, 0)) + units
	_give_back()
	_restore_loc()
	var inv := InventoryState.from_player(b.player)
	for k: String in got:
		inv.add(k, int(got[k]))
	b.player.inventory_pack = inv.pack.duplicate(true)
	var outcome := String(res.get("outcome", ""))
	var text := ""
	match _job_what:
		"jerky":
			if on_rack:
				var lb := 0.0
				for v: Variant in SurvivalUtil.dict(cr.get("made")).values():
					lb += float(v)
				text = "The strips hang over the smoke: %d lb of jerky in a day or two" % roundi(lb)
			else:
				text = "The meat spoils on the rack"
		"buckskin":
			text = "You dress the hide: %s" % _got_text(got) if not got.is_empty() else "The hide is spoilt in the working"
		"rawhide":
			text = "You scrape the hide: %s" % _got_text(got) if not got.is_empty() else "The hide tears through"
		"robe":
			if SurvivalUtil.dict(cr.get("made")).has(FUR_ROBE):
				var on := core.state.worn.has(FUR_ROBE) or SurvivalInventory.wear_if_slot_empty(core, FUR_ROBE)
				text = "The buffalo robe is dressed, the hair on: %s" % ("you wrap it round you" if on else "a fur robe in your kit")
				got = {FUR_ROBE: 1}
			else:
				text = ("The hair slips in the working: %s" % _got_text(got)) if not got.is_empty() else "The robe is spoilt in the working"
		"moccasins":
			var made := SurvivalUtil.dict(cr.get("made")).has(MOCCASINS)
			text = ("A new pair of moccasins in your kit (%d pairs)" % int(round(SurvivalInventory.count(core, MOCCASINS)))) if made else "The seams will not hold: Hidecraft comes with practice"
			got = {MOCCASINS: 1} if made else {}
		"mitts":
			var made2 := SurvivalUtil.dict(cr.get("made")).has("item.cloth.mitts")
			text = ("Fur mitts in your kit (%d pairs)" % int(round(SurvivalInventory.count(core, "item.cloth.mitts")))) if made2 else "The mitts come out wrong: Hidecraft comes with practice"
			got = {"item.cloth.mitts": 1} if made2 else {}
		"frock", "leggings", "cap":
			var item := {"frock": "item.cloth.hunting_frock", "leggings": "item.cloth.leggings_buckskin", "cap": "item.cloth.fur_cap"}[_job_what] as String
			if SurvivalUtil.dict(cr.get("made")).has(item):
				var on := core.state.worn.has(item) or SurvivalInventory.wear_if_slot_empty(core, item)
				var nm := {"frock": "buckskin hunting frock", "leggings": "breechcloth and a pair of buckskin leggings", "cap": "fur cap"}[_job_what] as String
				text = "You sew a %s%s" % [nm, ": you put it on" if on else " (in your kit)"]
				got = {item: 1}
			else:
				text = "The seams will not hold: Hidecraft comes with practice"
		"mend":
			var ok := outcome != "failure" and outcome != "mishap"
			text = ("You patch the moccasins: %d%% worn now" % roundi(SurvivalInventory.wear_of(core, MOCCASINS) * 100.0)) if ok else "The patch will not hold: the scrap is spent"
			got = {"mend": 1} if ok else {}
	if outcome == "failure" and _job_what == "buckskin" and got.has("rawhide"):
		text = "The hide went hard in the working: %s" % _got_text(got)
	_result(_job_what, not got.is_empty() or on_rack, text, got)
	_dress_goods()


## The pelt fleshed and laced: off the core's kit onto this hoop's record, drying for the time the core gave it.
func _pelt_stretched(res: Dictionary) -> void:
	var b := bridge()
	var core := b.core
	var pk := _job_what.trim_prefix("pelt:")
	var item := String(PELTS[pk][1])
	var meta := {}
	for st in core.state.inventory:
		var m := SurvivalUtil.dict(st.meta)
		if String(st.id) == item and bool(m.get("stretched", false)):
			meta = m.duplicate(true)
			SurvivalInventory.remove_stack_qty(core, st, 1.0)
			break
	_moved = {}
	if meta.is_empty():
		_result(_job_what, false, "The pelt tears in the lacing", {})
		return
	var need_min := float(meta.get("dry_need_h", 60.0)) * 60.0
	hoop_record().append({"id": item, "meta": meta, "pelt": pk, "hung_at": core.state.minutes, "ready_at": core.state.minutes + need_min})
	_result(_job_what, true, "The %s dries on the hoop: %s, in %d hours" % [InventoryState.name_of(pk).to_lower(), _grade_words(String(meta.get("grade", "good"))),
			roundi(need_min / 60.0)], {pk: 1})
	_dress_goods()


func _on_interrupted(job: Dictionary, reason: String) -> void:
	if _job == "" or String(job.get("action", "")) != _job:
		return
	# going from fed to peckish is the core's wake rule for any worse need: the work goes on where it was (as the sleeper)
	if reason.contains("peckish") and bool(bridge().core.start_job(_job, SurvivalUtil.dict(job.get("params"))).get("ok", false)):
		return
	_job = ""
	_give_back()
	_restore_loc()
	_result(_job_what, false, "You stop: %s" % reason, {})
	if bridge().work.working:
		bridge().work.stop("interrupted")


func _on_work_end(ok: bool) -> void:
	if ok or _job == "":
		return
	# stopped by the player: the core cancelled the job and keeps its progress; the things come back
	_job = ""
	_give_back()
	_restore_loc()
	_result(_job_what, false, "", {})


## What of the inputs is still in the core goes back to the pack (whole units; a part stays with the kit).
func _give_back() -> void:
	var b := bridge()
	var inv := InventoryState.from_player(b.player)
	for item: String in _moved:
		var m: Array = _moved[item]
		var left := SurvivalInventory.count(b.core, item) - float(m[3])
		var units := mini(floori(left / float(m[2]) + 0.0001), int(m[1]))
		if units > 0:
			SurvivalInventory.remove(b.core, item, units * float(m[2]))
			inv.add(String(m[0]), units)
	b.player.inventory_pack = inv.pack.duplicate(true)
	_moved = {}


func _restore_loc() -> void:
	if _saved_loc != "":
		bridge().set_context({"location": _saved_loc})
		_saved_loc = ""


func _result(what: String, ok: bool, text: String, got: Dictionary) -> void:
	last = {"what": what, "ok": ok, "text": text, "got": got}
	if text != "":
		bridge()._notice(text)


static func _got_text(got: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in got:
		parts.append("%d %s" % [int(got[k]), InventoryState.name_of(k).to_lower()])
	return ", ".join(parts)


## The lit campfire nearest the station within `m` m, or null.
func _fire_near(m: float) -> Campfire:
	var b := bridge()
	if b and b.camp:
		return b.camp.lit_fire_near(global_position, m)
	return null


# --- The goods: what lies on or hangs from it -------------------------------------------------------------------

func _process(_dt: float) -> void:
	if kind == "drying_rack" and Engine.get_process_frames() % 30 == 0:
		_dress_strips()
	elif kind == "stretching_hoop" and Engine.get_process_frames() % 30 == 0:
		_dress_hoop()
	elif kind == "charcoal_mound" and Engine.get_process_frames() % 30 == 0:
		_mound_look()


func _dress_goods() -> void:
	match kind:
		"pole_bed":
			if _goods.get_child_count() == 0:
				# a deer hide spread over the tick, hair up
				var hide := MeshInstance3D.new()
				hide.mesh = hide_mesh(0.85, 1.4, 7)
				hide.material_override = _mat("hide", Color(0.5, 0.36, 0.22), 0.95)
				hide.rotation = Vector3(-PI * 0.5, 0.04, 0.0)
				hide.position = Vector3(0, BuildGeometry.POLE_BED_H + 0.045, 0.15)
				_goods.add_child(hide)
				var roll := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.1
				c.bottom_radius = 0.1
				c.height = BuildGeometry.POLE_BED_W - 0.2
				roll.mesh = c
				roll.material_override = _mat("blanket", Color(0.55, 0.14, 0.1), 0.9)
				roll.rotation.z = PI * 0.5
				roll.position = Vector3(0, BuildGeometry.POLE_BED_H + 0.1, -BuildGeometry.BED_L * 0.5 + 0.25)
				_goods.add_child(roll)
		"tanning_frame":
			if _goods.get_child_count() == 0:
				# a scraped hide laced into the frame, the lacing to the bars
				_hide = MeshInstance3D.new()
				_hide.mesh = hide_mesh(1.05, 1.3, 11)
				_hide.material_override = _hide_mat("rawhide", Color(0.8, 0.68, 0.48))
				_hide.position = Vector3(0, BuildGeometry.TAN_H * 0.52, 0.03)
				_goods.add_child(_hide)
				for i in 6:
					var y := BuildGeometry.TAN_H * 0.52 + (i - 2.5) * 0.22
					for sx: float in [-1.0, 1.0]:
						var l := _box(Vector3(0.3, 0.012, 0.012), Vector3(sx * 0.66, y, 0.02), _mat("lacing", Color(0.6, 0.5, 0.35), 0.9))
						l.rotation.z = sx * 0.1
		"alchemy_table":
			if _goods.get_child_count() == 0:
				var top := BuildGeometry.TABLE_H
				_cyl(0.09, 0.07, 0.1, Vector3(-0.42, top + 0.05, 0.08), _mat("mortar", Color(0.5, 0.49, 0.46), 0.85))
				var pestle := _cyl(0.018, 0.022, 0.2, Vector3(-0.38, top + 0.14, 0.08), _mat("wood_dark", Color(0.38, 0.27, 0.18), 0.8))
				pestle.rotation.z = 0.5
				for i in 3:
					_cyl(0.06, 0.065, 0.13 + 0.03 * i, Vector3(-0.1 + 0.15 * i, top + 0.07 + 0.015 * i, -0.15), _mat("crock%d" % i,
							[Color(0.62, 0.5, 0.34), Color(0.45, 0.36, 0.26), Color(0.7, 0.62, 0.48)][i], 0.6))
				for i in 2:
					var bx := 0.42 + 0.1 * i
					_cyl(0.035, 0.04, 0.16, Vector3(bx, top + 0.08, -0.05 + 0.1 * i), _mat("glass", Color(0.24, 0.36, 0.22, 0.85), 0.15))
					_cyl(0.012, 0.014, 0.06, Vector3(bx, top + 0.19, -0.05 + 0.1 * i), _mat("glass", Color(0.24, 0.36, 0.22, 0.85), 0.15))
				# herbs hung to dry from the crossbar
				var hz := -BuildGeometry.TABLE_D * 0.5 + 0.04
				for i in 5:
					# a bundle hung stems up: the tied stems, the leaves spreading below them
					var x := -0.5 + 0.25 * i
					var col: Color = [Color(0.3, 0.42, 0.22), Color(0.46, 0.46, 0.28), Color(0.4, 0.34, 0.4)][i % 3]
					_cyl(0.008, 0.008, 0.08, Vector3(x, top + 0.66, hz), _mat("string", Color(0.55, 0.48, 0.36), 0.9))
					_cyl(0.018, 0.022, 0.07, Vector3(x, top + 0.6, hz), _mat("stems%d" % (i % 3), col.darkened(0.25), 0.95))
					var leaves := _cyl(0.025, 0.065 + 0.01 * (i % 2), 0.16, Vector3(x, top + 0.49, hz), _mat("herb%d" % (i % 3), col, 0.95))
					leaves.rotation.y = 0.5 * i
		"drying_rack":
			_dress_strips()
		"stretching_hoop":
			_dress_hoop()
		"workbench":
			if _goods.get_child_count() == 0:
				var top := BuildGeometry.BENCH_H
				var wood := _mat("wood_dark", Color(0.38, 0.27, 0.18), 0.8)
				var iron := _mat("iron", Color(0.24, 0.24, 0.25), 0.4)
				# a mallet, an awl and a knife laid out, a bundle of arrow shafts, a strip of buckskin
				var head := _cyl(0.045, 0.045, 0.16, Vector3(-0.55, top + 0.05, 0.08), wood)
				head.rotation.z = PI * 0.5
				var handle := _cyl(0.014, 0.016, 0.28, Vector3(-0.55, top + 0.02, 0.24), wood)
				handle.rotation.x = PI * 0.5
				var awl := _cyl(0.004, 0.004, 0.09, Vector3(-0.22, top + 0.02, 0.16), iron)
				awl.rotation.z = PI * 0.5
				var awl_h := _cyl(0.014, 0.012, 0.08, Vector3(-0.31, top + 0.02, 0.16), wood)
				awl_h.rotation.z = PI * 0.5
				_box(Vector3(0.16, 0.004, 0.03), Vector3(-0.08, top + 0.006, 0.2), iron)
				_box(Vector3(0.1, 0.02, 0.025), Vector3(0.05, top + 0.012, 0.2), wood)
				for i in 7:
					var sh := _cyl(0.005, 0.005, 0.72, Vector3(0.3 + 0.012 * i, top + 0.01 + 0.004 * (i % 3), -0.12 + 0.012 * i), _mat("shaft", Color(0.72, 0.6, 0.42), 0.8))
					sh.rotation.z = PI * 0.5
				var strip := MeshInstance3D.new()
				strip.mesh = hide_mesh(0.34, 0.42, 5)
				strip.material_override = _mat("buckskin", Color(0.8, 0.66, 0.46), 0.95)
				strip.rotation = Vector3(-PI * 0.5, 0.3, 0.0)
				strip.position = Vector3(0.52, top + 0.008, 0.12)
				_goods.add_child(strip)


## The pelt laced in the hoop while one dries (grey for a wolf's, red for a fox's, the small furs' own colours), with its
## lacing to the ring.
func _dress_hoop() -> void:
	var b := bridge()
	var on: Array = hoop_record() if b and b.core else []
	var want := "" if on.is_empty() else String(on[0].get("pelt", ""))
	if String(_goods.get_meta(&"pelt", "-")) == want:
		return
	_goods.set_meta(&"pelt", want)
	for c in _goods.get_children():
		c.queue_free()
	if want == "":
		return
	var pelt := MeshInstance3D.new()
	pelt.mesh = hide_mesh(0.62, 0.8, 13)
	var fur := Color(0.66, 0.62, 0.56) if want == "wolf_pelt" else Color(0.78, 0.42, 0.2)
	if GearModels.PELT_LOOK.has(want):
		fur = (GearModels.PELT_LOOK[want][0] as Color).lightened(0.15)
	pelt.material_override = _hide_mat("pelt_" + want, fur)
	pelt.position = Vector3(0, BuildGeometry.HOOP_Y, 0.012)
	_goods.add_child(pelt)
	for i in 10:
		var a := TAU * i / 10.0
		var l := _box(Vector3(0.012, 0.012, 0.012), Vector3.ZERO, _mat("lacing", Color(0.6, 0.5, 0.35), 0.9))
		var r0 := 0.3
		var r1 := BuildGeometry.HOOP_R - 0.02
		l.mesh.size = Vector3(r1 - r0, 0.008, 0.008)
		l.position = Vector3(cos(a) * (r0 + r1) * 0.5, BuildGeometry.HOOP_Y + sin(a) * (r0 + r1) * 0.5, 0.01)
		l.rotation.z = a


## Meat strips on the rack's sticks: as many as the pounds hanging, redder fresh, near black when dry.
func _dress_strips() -> void:
	var lb := hanging_lb() if bridge() else 0.0
	var n := clampi(ceili(lb * 3.0), 0, 36)
	if _strip_mat == null:
		_strip_mat = StandardMaterial3D.new()
		_strip_mat.roughness = 0.55
	var dry := 1.0 if lb <= 0.0 else clampf(1.0 - hours_to_ready() / 36.0, 0.0, 1.0)
	_strip_mat.albedo_color = Color(0.5, 0.14, 0.1).lerp(Color(0.2, 0.08, 0.06), dry)
	while _strips.size() < n:
		var i := _strips.size()
		var stick := i % 7
		var along := floori(float(i) / 7.0)
		var x := -BuildGeometry.DRY_W * 0.5 + 0.2 + (BuildGeometry.DRY_W - 0.4) * stick / 6.0
		var z := -BuildGeometry.DRY_D * 0.5 + 0.2 + along * 0.13
		var s := _box(Vector3(0.05, 0.28 + 0.06 * float((i * 7) % 3), 0.012), Vector3(x, BuildGeometry.DRY_H - 0.16, z), _strip_mat)
		s.rotation.y = 0.2 * float((i * 5) % 3 - 1)
		_strips.append(s)
	while _strips.size() > n:
		_strips.pop_back().queue_free()


## A hide's outline as a flat mesh in XY, `w` by `h`: a body, the four legs at the corners, the neck at the top; the
## edge a little ragged (`seed`). Both faces show.
static func hide_mesh(w: float, h: float, seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	# the outline, a quarter-turn at a time: neck, shoulder, foreleg, flank, hind leg, rump (mirrored right to left)
	var half: Array[Vector2] = [Vector2(0.0, 0.5), Vector2(0.1, 0.5), Vector2(0.14, 0.4), Vector2(0.36, 0.42), Vector2(0.5, 0.36),
			Vector2(0.4, 0.26), Vector2(0.36, 0.05), Vector2(0.38, -0.2), Vector2(0.5, -0.34), Vector2(0.44, -0.44),
			Vector2(0.26, -0.4), Vector2(0.12, -0.5), Vector2(0.0, -0.48)]
	var pts: Array[Vector2] = []
	for v in half:
		pts.append(Vector2(v.x * w, v.y * h) + Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012)))
	for i in range(half.size() - 2, 0, -1):
		var v := half[i]
		pts.append(Vector2(-v.x * w, v.y * h) + Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, side))
		for i in pts.size():
			var a := pts[i]
			var b2 := pts[(i + 1) % pts.size()]
			var tri := [Vector3.ZERO, Vector3(a.x, a.y, 0.0), Vector3(b2.x, b2.y, 0.0)]
			if side < 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for v: Vector3 in tri:
				st.set_uv(Vector2(v.x / w + 0.5, 0.5 - v.y / h))
				st.add_vertex(v + Vector3(0, 0, side * 0.004))
	return st.commit()


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_goods.add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	_goods.add_child(mi)
	return mi


## A hide's or pelt's: the light shows through it when the sun is behind (a stretched hide glows warm).
static func _hide_mat(key: String, c: Color) -> StandardMaterial3D:
	var m := _mat(key, c, 0.95)
	m.backlight_enabled = true
	m.backlight = Color(c.r * 0.55, c.g * 0.45, c.b * 0.35)
	return m


static func _mat(key: String, c: Color, rough: float) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]
