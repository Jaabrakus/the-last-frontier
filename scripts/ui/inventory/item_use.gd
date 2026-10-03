class_name ItemUse
extends RefCounted
## What using a pack thing on the body does, and whether it can: the character screen's (InventoryScreen: the figure, a
## double-click, a right-click) and the bags' (BagWindows: a right-click in a bag; the owner 2026-10-03, "WoW-style bags":
## "right-click uses ... eat, apply, drink, smoke, wear"), one set of rules for both. Each works on an InventoryState `inv`:
## the Tab screen's copy of the pack, or for the bags a fresh one (InventoryState.from_player) written back after.
##   verdict(p, inv, kind)       {ok, reason}: what it would do ("Eat the jerky"), or why not (the survival code's own words)
##   use(p, inv, kind)           a right-click: food eaten, a herb or a remedy applied, laudanum, snuff or a quid taken, a
##                               drink or a pipe fill chosen. {done, ok, text, refresh}; done false: nothing to do here
##   on_body(p, inv, kind)       the figure's: rope gear put on, food eaten, a herb or a remedy applied, a vice taken, a
##                               gill drunk, a pipeful smoked, a bag put on (PlayerBags.equip), a weapon or a tool into the
##                               first free hotbar slot. {ok, text, gear (the worn rope gear changed)}. Not the torch: the
##                               callers have their own (the Tab screen lights it on closing, the bags at once)
## The words are the ones the Tab screen always said (its tests read them).

## The figure's word for a torch in the Tab screen (it is taken in hand when the screen closes).
const TORCH_ON_CLOSE := "A torch in your left hand, lit, when you close the pack"


static func bridge(p: Node) -> SurvivalBridge:
	return SurvivalBridge.find(p.get_tree()) if p != null and p.is_inside_tree() else null


static func vices(p: Node) -> Vices:
	var br := bridge(p)
	return br.vices if br else null


static func _yes(what: String) -> Dictionary:
	return {"ok": true, "reason": what}


static func _no(why: String) -> Dictionary:
	return {"ok": false, "reason": why}


## In the pack or worn.
static func owns(inv: InventoryState, kind: String) -> bool:
	if inv.pack_count(kind) > 0:
		return true
	for it: Dictionary in inv.worn.items:
		if String(it.kind) == kind:
			return true
	return false


## What `kind` from the pack would do on the body: {ok, reason}.
static func verdict(p: Node, inv: InventoryState, kind: String, torch_says := TORCH_ON_CLOSE) -> Dictionary:
	if kind == "":
		return _no("")
	var nm := InventoryState.name_of(kind)
	var e := Hotbar.entry_for_kind(p, kind)
	if inv.pack_count(kind) <= 0 and (e.is_empty() or not owns(inv, kind)):
		return _no("No %s in the pack" % nm.to_lower())
	if InventoryState.GEAR_KINDS.has(kind):
		return _no("The %s is on already" % nm.to_lower()) if inv.gear_worn(kind) else _yes("Put the %s on" % nm.to_lower())
	if kind == InventoryState.TORCH:
		return _yes(torch_says)
	if PlayerBags.is_bag(kind):
		var g := PlayerBags.find(p)
		var s := g.sockets.find("") if g != null else -1
		if g == null:
			return _no("Not now")
		return _yes("Put the %s on: bag %d" % [nm.to_lower(), s + 1]) if s >= 0 \
				else _no("Every bag socket has a bag: take one off first")
	var br := bridge(p)
	if br and br.can_eat(kind):
		var why := br.why_not(kind)
		return _no(why) if why != "" else _yes("Eat the %s" % nm.to_lower())
	if ForageUse.can_use(kind) or Remedies.can_use(kind):
		var why := dressing_refusal(p, kind)
		return _no(why) if why != "" else _yes("Use the %s" % nm.to_lower())
	var vc := vices(p)
	if Vices.can_use(kind):
		return _yes("Take the %s" % nm.to_lower()) if vc else _no("Not now")
	if Vices.DRINKS.has(kind) or Vices.FILLS.has(kind) or kind == "clay_pipe":
		var what := "drink" if Vices.DRINKS.has(kind) else "tobacco"
		var why := vc.why_not(what, inv) if vc else "."
		if why == ".":
			why = "Not now"
		return _no(why) if why != "" else _yes("Drink a gill of the %s" % nm.to_lower() if what == "drink" else "Smoke a pipeful")
	if not e.is_empty():
		return bar_verdict(p, e, nm)
	return _no("The %s cannot be worn or used" % nm.to_lower())


## Why a herb or a remedy would do nothing now ("" when it would): the dressing's own rules (ForageUse.use, Remedies.use:
## a wound to dress, not one under a poultice already; the tonic needs the survival rules).
static func dressing_refusal(p: Node, kind: String) -> String:
	if not (ForageUse.can_use(kind) or kind == "plantain_salve"):
		var br := bridge(p)
		return "Nothing comes of it now" if kind == "ginseng_tonic" and (br == null or br.core == null) else ""
	var hurt := float(p.get("health")) < float(p.get("max_health")) - 0.5
	var w: Variant = p.get("wounds")
	var bleeding: bool = w is PlayerWounds and (w as PlayerWounds).bleeding()
	if not hurt and not bleeding:
		return "You have no wound to dress"
	if p.get_node_or_null("Poultice") != null and not bleeding:
		return "A poultice is on the wound already"
	return ""


## Whether the hotbar entry `e` (`nm` its name) could go in the first free slot.
static func bar_verdict(p: Node, e: Dictionary, nm: String) -> Dictionary:
	var hb := Hotbar.find(p)
	if hb == null:
		return _no("No hotbar")
	var at := hb.slot_of(String(e.kind), String(e.id))
	if at >= 0:
		return _no("The %s is on the hotbar already: %d" % [nm.to_lower(), at + 1])
	if not hb.has_thing(e):
		return _no("You do not have the %s" % nm.to_lower())
	var free := hb.first_free()
	if free < 0:
		return _no("No free slot on the hotbar: drag it onto a slot to swap")
	return _yes("Onto the hotbar: %d" % (free + 1))


## A right-click's use: {done, ok, text, refresh}. done false: nothing here for it (a torch, a weapon: the caller's).
static func use(p: Node, inv: InventoryState, kind: String) -> Dictionary:
	var br := bridge(p)
	if br and br.can_eat(kind):
		# food: eaten from `inv` (SurvivalBridge.eat)
		var r := br.eat(kind, inv)
		return {"done": true, "ok": bool(r.ok), "text": String(r.text), "refresh": true}
	if ForageUse.can_use(kind):
		# a herb (plantain: a poultice on a wound; scripts/forage/forage_use.gd)
		return {"done": true, "ok": true, "text": ForageUse.use(p, kind, inv), "refresh": true}
	if Remedies.can_use(kind):
		# a remedy from the alchemy table (salve, tea, tonic; scripts/survival_game/remedies.gd)
		return {"done": true, "ok": true, "text": Remedies.use(p, kind, inv), "refresh": true}
	var vc: Vices = br.vices if br else null
	if vc and Vices.can_use(kind):
		# laudanum, snuff, a quid (Vices)
		return {"done": true, "ok": true, "text": vc.use_item(kind, inv), "refresh": true}
	if vc and Vices.can_choose(kind):
		# a drink or a pipe fill: the next gill (U) or pipeful (Y) is of it
		return {"done": true, "ok": true, "text": vc.choose(kind), "refresh": false}
	return {"done": false, "ok": false, "text": "", "refresh": false}


## A gill of `kind` drunk (Vices.take: the bottle open is finished first; it soaks in over the next hour). {ok, text}.
static func drink(p: Node, inv: InventoryState, kind: String) -> Dictionary:
	var vc := vices(p)
	if vc == null:
		return {"ok": false, "text": ""}
	vc.choose(kind)
	if vc.take("drink", 1.0, inv) <= 0.0:
		return {"ok": false, "text": vc.why_not("drink", inv)}
	return {"ok": true, "text": "You drink a gill of %s." % InventoryState.name_of(String(vc._st().get("flask_kind", kind))).to_lower()}


## A pipeful smoked (Vices.take): of `kind` when it is a fill, else of what the pipe is packed with next. {ok, text}.
static func smoke(p: Node, inv: InventoryState, kind: String) -> Dictionary:
	var vc := vices(p)
	if vc == null:
		return {"ok": false, "text": ""}
	if Vices.FILLS.has(kind):
		vc.choose(kind)
	if vc.take("tobacco", 1.0, inv) <= 0.0:
		return {"ok": false, "text": vc.why_not("tobacco", inv)}
	return {"ok": true, "text": "You smoke a pipeful of %s." % InventoryState.name_of(String(vc._st().get("bowl_kind", kind))).to_lower()}


## `kind` used on the body (the bags' right-click; the Tab screen's figure has its own steps round these): {ok, text, gear}.
static func on_body(p: Node, inv: InventoryState, kind: String) -> Dictionary:
	var v := verdict(p, inv, kind, "Take a torch in your left hand")
	if not bool(v.ok):
		return {"ok": false, "text": String(v.reason), "gear": false}
	var nm := InventoryState.name_of(kind)
	if InventoryState.GEAR_KINDS.has(kind):
		var ok := inv.wear_gear(kind)
		return {"ok": ok, "text": ("The %s is on." if ok else "The %s is on already.") % nm.to_lower(), "gear": ok}
	if PlayerBags.is_bag(kind):
		var r := PlayerBags.find(p).equip(kind)
		return {"ok": bool(r.ok), "text": ("The %s is on: bag %d." % [nm.to_lower(), int(r.socket) + 1]) if bool(r.ok) else String(r.reason),
				"gear": false}
	if Vices.DRINKS.has(kind):
		var d := drink(p, inv, kind)
		return {"ok": bool(d.ok), "text": String(d.text), "gear": false}
	if Vices.FILLS.has(kind) or kind == "clay_pipe":
		var s := smoke(p, inv, kind)
		return {"ok": bool(s.ok), "text": String(s.text), "gear": false}
	var u := use(p, inv, kind)
	if bool(u.done):
		return {"ok": bool(u.ok), "text": String(u.text), "gear": false}
	var e := Hotbar.entry_for_kind(p, kind)
	var hb := Hotbar.find(p)
	if not e.is_empty() and hb != null:
		var i := hb.add(e)
		return {"ok": i >= 0, "text": ("%s on the hotbar: %d." % [hb.label(i), i + 1]) if i >= 0
				else "No free slot on the hotbar: drag it onto a slot to swap.", "gear": false}
	return {"ok": false, "text": "The %s cannot be worn or used" % nm.to_lower(), "gear": false}
