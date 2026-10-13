class_name AdvancementLoadout
extends RefCounted
## One loadout of the Character Advancement window: an element's class (its style) and the nodes worn, with the ring's
## rules (artifacts/ui_audit/advancement/plan.md section 3; data/sway/skill_tree.json ring). Pure logic: it reads
## AdvancementData and nothing of the game, except with_live_context(), which reads the gates and the control scheme.
## Phase A: a loadout is saved and shown; no match reads it yet.
##
##   why_not(id)        why `id` cannot be worn now ("" = it can, or it is worn already). The checks, in this order, are
##                      the web mockup's whyNot (artifacts/skill_tree_page/template_wow.html) and then the plan's two more:
##                        held          never worn until the owner says yes
##                        excludes      not with a worn node that pulls the same number the other way (either side's list)
##                        requires      a node it needs is not worn
##                        (world mode stops here: the open world has no budget)
##                        world_only    world-only kinds and ring-illegal number swaps
##                        budget        10 points
##                        kind_cap      one skill set, one new skill, one passive, one technique per loadout
##                        twist         one twist per move-mode
##                        move_points   at most 4 points per move-mode, counting only nodes with a mode (passives, sets
##                                      and synergies are capped by their kind)
##                        scheme        First moves only / Direction reach each key's first move only: tap-twice nodes grey
##                        gates         before the first ring win everything; before the Full lessons the twists,
##                                      techniques, new skills and skill sets (advancement.json switches)
##   why_not_code(id)   the same check's code (the names above; "unknown" for an id not in this element's tree)
##   wear(id)           worn when why_not is "" (returns why_not); take_off(id) takes it off and every node that required
##                      it (returns the ids taken off, it first)
##   valid(gates, exempt)  "" or the first reason the picks break the rules (each pick re-worn in order, requires first); the
##                      newcomer gates count when `gates`, except for the picks in `exempt` (what is already saved)
##   ordered(ids)       `ids` with every pick after the picks it requires (the order they can be worn in)
##   diff(saved)        {worn, taken_off, style}: what this (pending) loadout changes against the saved one
##   code() / from_code TB1-<e|w|f|a>-<style index>-<base36 bitset over the element's node order in skill_tree.json>

## The element ("earth"), its class's style ("hung_gar") and the nodes worn, in the order they were worn.
var element := ""
var style := ""
var picks: Array = []
## "ring" (10 points and every ring limit) or "world" (the open world: no budget; Phase C).
var mode := "ring"
## The control scheme the loadout is checked under ("" = none: no greying; KitWords.scheme_id's ids).
var scheme := ""
## The newcomer gates ({} = open; AdvancementData.gate_state's shape).
var gates := {}


func _init(el := "", style_id := "", ids: Array = []) -> void:
	element = el
	style = style_id if style_id != "" else AdvancementData.canon_style(el)
	for id: Variant in ids:
		if not String(id) in picks:
			picks.append(String(id))


## Classic: no picks (every new player's loadout).
static func classic(el: String, style_id := "") -> AdvancementLoadout:
	return AdvancementLoadout.new(el, style_id)


## A premade build (a starter loadout of skill_tree.json); null for an unknown id.
static func from_starter(el: String, starter_id: String, style_id := "") -> AdvancementLoadout:
	var s := AdvancementData.starter(starter_id)
	if s.is_empty() or not starter_id.begins_with(el + "."):
		return null
	return AdvancementLoadout.new(el, style_id, s.get("nodes", []))


## A copy (picks, style, mode, scheme and gates).
func copy() -> AdvancementLoadout:
	var c := AdvancementLoadout.new(element, style, picks)
	c.mode = mode
	c.scheme = scheme
	c.gates = gates.duplicate()
	return c


## This loadout checked as the game stands now: the gates (AdvancementData.gate_state) and the control scheme
## (KitWords.scheme_id). Returns itself.
func with_live_context() -> AdvancementLoadout:
	gates = AdvancementData.gate_state(element)
	scheme = AdvancementData.scheme_now()
	return self


func has(id: String) -> bool:
	return id in picks


func is_empty() -> bool:
	return picks.is_empty()


## Points spent (every pick's cost).
func cost() -> int:
	var t := 0
	for id: String in picks:
		t += AdvancementData.cost(id)
	return t


## Points left of the budget.
func left() -> int:
	return AdvancementData.budget() - cost()


## Points spent on one tree's nodes ("left" or "right").
func spent(side: String) -> int:
	var t := 0
	for id: String in picks:
		if String(AdvancementData.node(id).get("side", "")) == side:
			t += AdvancementData.cost(id)
	return t


## {kinds: {skill_set, new_skill, passive, mastery: count}, per: {move/mode: points}, twists: {move/mode: count}}.
func tally() -> Dictionary:
	var kinds := {"skill_set": 0, "new_skill": 0, "passive": 0, "mastery": 0}
	var per := {}
	var twists := {}
	for id: String in picks:
		var n := AdvancementData.node(id)
		if n.is_empty():
			continue
		var k := String(n.kind)
		if kinds.has(k):
			kinds[k] += 1
		if not bool(n.on_mode):
			continue
		var mm := String(n.move_mode)
		per[mm] = int(per.get(mm, 0)) + int(n.cost)
		if k == "variation":
			twists[mm] = int(twists.get(mm, 0)) + 1
	return {"kinds": kinds, "per": per, "twists": twists}


## Why `id` cannot be worn now ("" = it can, or it is worn already). See the class doc for the checks and their order.
func why_not(id: String) -> String:
	return String(_check(id)[1])


func why_not_code(id: String) -> String:
	return String(_check(id)[0])


func can_wear(id: String) -> bool:
	return not has(id) and _check(id)[0] == ""


## True when only the points stop `id` (every other rule lets it be worn): the window draws it within reach.
func short_of_points(id: String) -> bool:
	return not has(id) and _check(id)[0] == "budget" and _check(id, true)[0] == ""


## [code, text] of the first check `id` fails (["", ""] when none). `ignore_budget` skips the points check.
func _check(id: String, ignore_budget := false) -> Array:
	var n := AdvancementData.node(id)
	if n.is_empty() or String(n.el) != element:
		return ["unknown", AdvancementData.word("reasons.unknown")]
	if has(id):
		return ["", ""]
	if bool(n.held):
		return ["held", AdvancementData.word("reasons.held")]
	var clash: Array = []
	for x: String in n.excludes:
		if has(x) and not x in clash:
			clash.append(x)
	for p: String in picks:
		if id in (AdvancementData.node(p).get("excludes", []) as Array) and not p in clash:
			clash.append(p)
	if not clash.is_empty():
		return ["excludes", AdvancementData.word("reasons.excludes") % _names_text(clash)]
	var miss: Array = []
	for r: String in n.requires:
		if not has(r):
			miss.append(r)
	if not miss.is_empty():
		return ["requires", AdvancementData.word("reasons.requires") % _names_text(miss)]
	if mode == "world":
		return ["", ""]
	if bool(n.world_only):
		return ["world_only", AdvancementData.word("reasons.world_only")]
	var c := int(n.cost)
	if cost() + c > AdvancementData.budget() and not ignore_budget:
		return ["budget", AdvancementData.word("reasons.budget") % [c, left()]]
	var k := tally()
	var kind := String(n.kind)
	if AdvancementData.KIND_CAPS.has(kind):
		var cap := AdvancementData.limit(String(AdvancementData.KIND_CAPS[kind]), 1)
		if int(k.kinds.get(kind, 0)) >= cap:
			return ["kind_cap", AdvancementData.word("reasons.kind_cap") % [cap, String(n.kind_word).to_lower()]]
	if bool(n.on_mode):
		var mm := String(n.move_mode)
		if kind == "variation" and int(k.twists.get(mm, 0)) >= AdvancementData.limit("variations_per_move_mode", 1):
			return ["twist", AdvancementData.word("reasons.twist") % String(n.move_label)]
		var most := AdvancementData.limit("points_per_move_mode", 4)
		if int(k.per.get(mm, 0)) + c > most:
			return ["move_points", AdvancementData.word("reasons.move_points") % [most, String(n.move_label)]]
	if scheme != "" and scheme in (AdvancementData.switch("first_only_schemes", []) as Array) and bool(n.tap_twice):
		return ["scheme", AdvancementData.word("reasons.scheme")]
	if not gates.is_empty():
		if bool(gates.get("first_win", false)) and not bool(gates.get("won", true)):
			return ["gate_first_win", AdvancementData.word("reasons.gate_first_win")]
		var full := int(gates.get("full_left", 0))
		if bool(gates.get("full_lessons", false)) and full > 0 and kind in (AdvancementData.switch("full_lessons_kinds", []) as Array):
			return ["gate_full", AdvancementData.word("reasons.gate_full") % full]
	return ["", ""]


## Wears `id` when nothing stops it; returns why_not (so "" = worn).
func wear(id: String) -> String:
	var r := _check(id)
	if has(id):
		return ""
	if String(r[0]) != "":
		return String(r[1])
	picks.append(id)
	return ""


## Takes `id` off, and every worn node that requires it (on and on: a set's twists and its new skill with the set root).
## Returns the ids taken off, `id` first ([] when it was not worn).
func take_off(id: String) -> Array:
	if not has(id):
		return []
	var drop: Array = [id]
	var grew := true
	while grew:
		grew = false
		for p: String in picks:
			if p in drop:
				continue
			for r: String in AdvancementData.node(p).get("requires", []):
				if r in drop:
					drop.append(p)
					grew = true
					break
	var keep: Array = []
	for p: String in picks:
		if not p in drop:
			keep.append(p)
	picks = keep
	return drop


## Every pick taken off (Classic).
func clear() -> void:
	picks = []


## `ids` in an order they can be worn in: a node's requires first, the rest in the given order.
static func ordered(ids: Array) -> Array:
	var todo: Array = ids.duplicate()
	var out: Array = []
	while not todo.is_empty():
		var next := ""
		for id: String in todo:
			var ready := true
			for r: String in AdvancementData.node(id).get("requires", []):
				if r in todo:
					ready = false
					break
			if ready:
				next = id
				break
		if next == "":
			next = String(todo[0])
		out.append(next)
		todo.erase(next)
	return out


## "" when the picks keep every rule, else the first broken one ("Avalanche: Boulder already has a twist"). The class's
## style must be one of the element's and pickable. Each pick is worn again into an empty copy, a node's requires first;
## the gates count only when `with_gates` (a saved loadout stays valid whatever the gates), and then not for the picks in
## `exempt` (the ones already saved: the gates keep out what is NEW, never what the player already has).
func valid(with_gates := false, exempt: Array = []) -> String:
	if not AdvancementData.style_fits(element, style) or not AdvancementData.pickable(style):
		return AdvancementData.word("reasons.style")
	var seen: Array = []
	for id: String in picks:
		if id in seen:
			return AdvancementData.word("reasons.duplicate") % AdvancementData.name_of(id)
		seen.append(id)
	var t := AdvancementLoadout.new(element, style)
	t.mode = mode
	t.scheme = scheme
	var old_ids: Array = []
	var new_ids: Array = []
	for id: String in ordered(picks):
		if id in exempt:
			old_ids.append(id)
		else:
			new_ids.append(id)
	for phase in 2:
		t.gates = gates.duplicate() if with_gates and phase == 1 else {}
		for id: String in (old_ids if phase == 0 else new_ids):
			var why := t.wear(id)
			if why != "":
				return AdvancementData.word("reasons.invalid_pick") % [AdvancementData.name_of(id), why]
	return ""


## The picks of `ids` the newcomer gates (this loadout's `gates`) let through: {kept: ids in an order they can be worn,
## held_back: ids a gate (or a held-back pick they need) keeps out, reason: the first gate's words, error: the first
## broken rule's words ("" when none)}. A pick that breaks a rule other than a gate stops the read with `error`.
func through_gates(ids: Array) -> Dictionary:
	var t := AdvancementLoadout.new(element, style)
	t.mode = mode
	t.scheme = scheme
	t.gates = gates.duplicate()
	var kept: Array = []
	var back: Array = []
	var reason := ""
	var reason_code := ""
	for id: String in ordered(ids):
		var code := t.why_not_code(id)
		if code == "":
			t.picks.append(id)
			kept.append(id)
		elif code.begins_with("gate_") or code == "requires":
			back.append(id)
			if reason == "" and code.begins_with("gate_"):
				reason = t.why_not(id)
				reason_code = code
		else:
			return {"kept": kept, "held_back": back, "reason": reason, "reason_code": reason_code, "error": AdvancementData.word("reasons.invalid_pick") % [AdvancementData.name_of(id), t.why_not(id)]}
	return {"kept": kept, "held_back": back, "reason": reason, "reason_code": reason_code, "error": ""}


## What this (pending) loadout changes against `saved`: {worn: ids here and not there, taken_off: ids there and not here,
## style: true when the class differs}.
func diff(saved: AdvancementLoadout) -> Dictionary:
	var on: Array = []
	var off: Array = []
	for id: String in picks:
		if saved == null or not saved.has(id):
			on.append(id)
	if saved != null:
		for id: String in saved.picks:
			if not has(id):
				off.append(id)
	return {"worn": on, "taken_off": off, "style": saved == null or saved.style != style}


## The same class and the same nodes (in any order).
func same_as(other: AdvancementLoadout) -> bool:
	if other == null or other.element != element or other.style != style or other.picks.size() != picks.size():
		return false
	for id: String in picks:
		if not other.has(id):
			return false
	return true


## The worn nodes' names, in worn order.
func names() -> Array:
	var out: Array = []
	for id: String in picks:
		out.append(AdvancementData.name_of(id))
	return out


## The toast lines for what `saved` did not have: twists, techniques, new skills and skill sets newly worn, in worn order:
## [{id, kind, text}] ("New twist worn: Avalanche").
func toasts(saved: AdvancementLoadout) -> Array:
	var out: Array = []
	for id: String in diff(saved).worn:
		var n := AdvancementData.node(id)
		var lines := AdvancementData.words("toasts")
		if lines.has(String(n.get("kind", ""))):
			out.append({"id": id, "kind": String(n.kind), "text": String(lines[n.kind]) % String(n.name)})
	return out


static func _names_text(ids: Array) -> String:
	var ns: Array = []
	for id: String in ids:
		ns.append(AdvancementData.name_of(id))
	return AdvancementData.word("status.list_sep", ", ").join(PackedStringArray(ns))


# --- loadout codes -------------------------------------------------------------------------------------------------------

const CODE_HEAD := "TB1"
const B36 := "0123456789abcdefghijklmnopqrstuvwxyz"


## The loadout as a short code to copy: TB1-<e|w|f|a>-<style index>-<base36 bitset over the element's node order>.
func code() -> String:
	var ids := AdvancementData.node_ids(element)
	var bits := 0
	for i in ids.size():
		if has(String(ids[i])):
			bits |= 1 << i
	return "%s-%s-%d-%s" % [CODE_HEAD, String(AdvancementData.LETTERS.get(element, "?")),
			maxi(0, AdvancementData.style_ids(element).find(style)), _to36(bits)]


## A loadout read from a code (null when it is no code of this tree: the window then says so). Not checked against the
## rules: call valid() on it.
static func from_code(text: String) -> AdvancementLoadout:
	var parts := text.strip_edges().to_lower().split("-")
	if parts.size() != 4 or parts[0] != CODE_HEAD.to_lower():
		return null
	var el := ""
	for e: String in AdvancementData.LETTERS:
		if String(AdvancementData.LETTERS[e]) == parts[1]:
			el = e
	if el == "" or not parts[2].is_valid_int():
		return null
	var styles := AdvancementData.style_ids(el)
	var si := parts[2].to_int()
	if si < 0 or si >= styles.size():
		return null
	var bits := _from36(parts[3])
	var ids := AdvancementData.node_ids(el)
	if bits < 0 or ids.size() < 63 and bits >= (1 << ids.size()):
		return null
	var picks_read: Array = []
	for i in ids.size():
		if bits & (1 << i):
			picks_read.append(String(ids[i]))
	return AdvancementLoadout.new(el, String(styles[si]), picks_read)


static func _to36(v: int) -> String:
	if v == 0:
		return "0"
	var s := ""
	while v > 0:
		s = B36[v % 36] + s
		v /= 36
	return s


## -1 for anything that is not base 36 (or would not fit 62 bits).
static func _from36(s: String) -> int:
	if s == "" or s.length() > 12:
		return -1
	var v := 0
	for ch in s:
		var d := B36.find(ch)
		if d < 0:
			return -1
		v = v * 36 + d
	return v
