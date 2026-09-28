class_name Remedies
extends RefCounted
## The alchemy table's remedies (CampStation; user 2026-09-27: "Alchemy"): an herbalist's work of the time from the herbs
## the player forages (ForageField: plantain, wintergreen, ginseng), made at the table and used from the pack
## (InventoryScreen: right-click, as the plantain poultice):
##   plantain salve    3 plantain worked into a salve: heals more than a raw poultice (the same Poultice node, ForageUse)
##   wintergreen tea   2 wintergreen steeped (a lit campfire near the table): warms (the core's warmth need) and eases
##                     aches (a little healing)
##   ginseng tonic     a root sliced and steeped: hours more of WELL RESTED (SurvivalBridge; the day's healing rest
##                     longer if that is the boost it lengthens, not a new one)
## From the plants for the remedies (user 2026-09-27: "we will need more plants and herbs for these new things"), each
## a cure for a lasting harm (LastingConditions, LastingChill), none touching the aim or the speed:
##   willow bark tea   2 willow bark steeped (a fire): the ague's fever down (half a day of its cure) and the pain of
##                     wounds dulled for WILLOW_NUMB_H (their head, arm and leg costs set aside; they still must knit)
##   slippery elm gruel  2 elm bark boiled (a fire): the flux settled (half a day of its cure) and the gut soothed for
##                     GRUEL_GUT_H (a meal nourishes in full through the flux or a stomach wound)
##   elderberry syrup  4 elderberries cooked down (a fire): chilled to the bone half a day nearer mended; a little
##                     warmth and ease otherwise
## Well rested, the healing is stronger (SurvivalBridge.heal_item_mult_in), as the poultice's.

const RECIPES := {
	"plantain_salve": {"inputs": {"plantain": 3}, "seconds": 5.0, "fire": false, "verb": "Working plantain into a salve",
			"detail": "3 plantain: heals 40 over half a minute (a raw poultice heals 15)"},
	"wintergreen_tea": {"inputs": {"wintergreen": 2}, "seconds": 6.0, "fire": true, "verb": "Steeping wintergreen",
			"detail": "2 wintergreen, steeped over a lit campfire beside the table: warms you through, eases aches"},
	"ginseng_tonic": {"inputs": {"ginseng": 1}, "seconds": 5.0, "fire": false, "verb": "Slicing and steeping ginseng root",
			"detail": "1 ginseng root: four hours more of well rested"},
	"willow_bark_tea": {"inputs": {"willow_bark": 2}, "seconds": 6.0, "fire": true, "verb": "Steeping willow bark",
			"detail": "2 willow bark, steeped over a lit campfire: brings a fever down, dulls the pain of wounds for six hours"},
	"slippery_elm_gruel": {"inputs": {"elm_bark": 2}, "seconds": 7.0, "fire": true, "verb": "Boiling slippery elm into a gruel",
			"detail": "2 slippery elm bark, boiled over a lit campfire: settles the flux, a sore gut keeps its food for half a day"},
	"elderberry_syrup": {"inputs": {"elderberries": 4}, "seconds": 7.0, "fire": true, "verb": "Cooking elderberries down",
			"detail": "4 elderberries, cooked over a lit campfire: drives a deep chill out of the bones"},
	# the smoking mixture (Vices; smoked in the pipe, Y): `n` pipefuls
	"kinnikinnick": {"inputs": {"bearberry": 2, "dogwood_bark": 1}, "n": 3, "seconds": 5.0, "fire": false,
			"verb": "Drying and rubbing leaves and bark", "detail": "2 bearberry leaves and a red-osier bark: 3 pipefuls, no habit"},
	"kinnikinnick_mix": {"inputs": {"bearberry": 2, "dogwood_bark": 1, "tobacco": 1}, "n": 3, "seconds": 5.0, "fire": false,
			"verb": "Rubbing leaves and bark with tobacco", "detail": "bearberry, red-osier bark and a tobacco: 3 pipefuls, a light habit"},
}
const USE := {
	"plantain_salve": {"heal": 40.0, "over_s": 30.0},
	"wintergreen_tea": {"heal": 10.0, "over_s": 12.0, "warmth": 35.0},
	"ginseng_tonic": {"rested_h": 4.0},
	"willow_bark_tea": {"heal": 6.0, "over_s": 12.0},
	"slippery_elm_gruel": {"gut_h": LastingConditions.GRUEL_GUT_H},
	"elderberry_syrup": {"heal": 8.0, "over_s": 12.0, "warmth": 15.0, "chill_min": 12.0 * 60.0},
}


static func can_use(kind: String) -> bool:
	return USE.has(kind)


## Uses one `kind` from `inv` (the pack screen's copy) on `p`. The line to show ("" when it is not a remedy).
static func use(p: Node, kind: String, inv: InventoryState) -> String:
	var u: Dictionary = USE.get(kind, {})
	if u.is_empty() or p == null:
		return ""
	if inv.pack_count(kind) <= 0:
		return "No %s in the pack." % InventoryState.name_of(kind).to_lower()
	var b := SurvivalBridge.find(p.get_tree())
	var hurt := float(p.get("health")) < float(p.get("max_health")) - 0.5
	var lines: PackedStringArray = []
	match kind:
		"plantain_salve":
			# a bleeding wound (PlayerWounds): the salve stanches it at once
			var w: Variant = p.get("wounds")
			var bleeding: bool = w is PlayerWounds and (w as PlayerWounds).bleeding()
			if not hurt and not bleeding:
				return "You have no wound to dress."
			if p.get_node_or_null("Poultice") != null and not bleeding:
				return "A poultice is on the wound already."
			if w is PlayerWounds:
				# on the wound whether it still bleeds or not: a dressed wound does not fester (LastingConditions)
				(w as PlayerWounds).dress(2.0)
			if bleeding:
				lines.append("The salve stops the bleeding")
			if p.get_node_or_null("Poultice") == null:
				_heal(p, float(u.heal), float(u.over_s))
				lines.append(("and it will heal well over the next %d seconds" if bleeding else "The salve on the wound: it will heal well over the next %d seconds") % int(u.over_s))
		"wintergreen_tea":
			if b and b.lasting:
				b.lasting.remedy("wintergreen_tea")      # it shortens the ague (LastingConditions)
			if b and b.core:
				var n := b.core.state.needs
				n["warmth"] = minf(float(n.get("warmth", 100.0)) + float(u.warmth), 100.0)
				b.core.invalidate_modifiers()
				b.needs_changed.emit()
			lines.append("The hot tea warms you through")
			if hurt and p.get_node_or_null("Poultice") == null:
				_heal(p, float(u.heal), float(u.over_s))
				lines.append("and eases the aches")
		"ginseng_tonic":
			if b == null or b.core == null:
				return "Nothing comes of it now."
			var fl := b.core.state.flags
			var now := b.core.state.minutes
			var healing := b.is_healing_rest()
			fl["well_rested_until"] = maxf(float(fl.get("well_rested_until", -1.0)), now) + float(u.rested_h) * 60.0
			# no more than the stomach allows (SurvivalBridge.rest_cap_h: hunger caps the boost)
			fl["well_rested_until"] = minf(float(fl["well_rested_until"]), now + b.rest_cap_h() * 60.0)
			# the day's healing rest runs on with it; a nap's boost it lengthens heals no more (healing once a day)
			if healing:
				fl["heal_rest_until"] = fl["well_rested_until"]
			b.needs_changed.emit()
			lines.append("The tonic steadies you: well rested for %d hours more (%s)" % [roundi(b.rested_hours_left()),
					"you heal and learn faster" if b.is_healing_rest() else "you learn faster"])
		"willow_bark_tea":
			var fever := b != null and b.lasting != null and b.lasting.is_on("ague")
			if b and b.lasting:
				b.lasting.remedy("willow_bark_tea")
			lines.append("The bitter tea %s dulls the pain of your wounds for %d hours" % [
					"brings the fever down and" if fever else "", roundi(LastingConditions.WILLOW_NUMB_H)])
			if hurt and p.get_node_or_null("Poultice") == null:
				_heal(p, float(u.heal), float(u.over_s))
		"slippery_elm_gruel":
			var flux := b != null and b.lasting != null and b.lasting.is_on("flux")
			if b and b.lasting:
				b.lasting.remedy("slippery_elm_gruel")
			lines.append("The slick gruel %s your gut keeps its food for %d hours" % [
					"settles the flux, and" if flux else "sits easy:", roundi(LastingConditions.GRUEL_GUT_H)])
		"elderberry_syrup":
			var chilled := b != null and b.chill != null and b.chill.is_on()
			if chilled:
				var cs := b.chill.state()
				cs["recover"] = float(cs.get("recover", 0.0)) + float(u.chill_min)
			if b and b.core:
				var n := b.core.state.needs
				n["warmth"] = minf(float(n.get("warmth", 100.0)) + float(u.warmth), 100.0)
				b.core.invalidate_modifiers()
				b.needs_changed.emit()
			lines.append("The thick syrup %s" % ("drives the chill out of your bones: half a day nearer mended" if chilled else "warms you a little"))
			if hurt and p.get_node_or_null("Poultice") == null:
				_heal(p, float(u.heal), float(u.over_s))
	inv.take(kind, 1)
	return " ".join(lines).replace("  ", " ") + "."


## The Poultice node (ForageUse): `amount` healed over `seconds`, more when well rested.
static func _heal(p: Node, amount: float, seconds: float) -> void:
	var k := SurvivalBridge.heal_item_mult_in(p.get_tree())
	var pu := ForageUse.new()
	pu.name = "Poultice"
	pu.player = p
	pu.left = amount * k
	pu.rate = pu.left / maxf(seconds, 0.1)
	p.add_child(pu)
