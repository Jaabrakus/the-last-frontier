class_name Hotbar
extends Node
## The hotbar (user 2026-10-02: "instead of equipment rigs for slot items we take the minecraft approach and just have
## rigs show up as in the tool bar ... if nothing is equipped then nothing shows in the toolbar"): nine slots, each empty
## or {kind: "weapon" | "tool" | "spell", id}. One per player (the local one): Hotbar.of(player).
##
##   fills        never by itself (the owner, 2026-10-02: "pickups shouldnt auto fill"): a weapon, a tool or a spell gained
##                goes to the pack (a spell to the Tab screen's Spells list) and the player drags it on. Only a new game's
##                starting kit is placed, once (START_ORDER: the musket, the bow, the pistol, the felling axe, the saber,
##                then the rest the start owns in the old order, while there is room): for KIT_S after the bar is made
##                (the start's things come in over the first frames) unless a save is loaded, the bar is touched or the
##                start is a start with nothing (start_over). A save keeps its bar; a save from before the bar had one gets
##                the kit from what it owns. Lost (put down, thrown, knocked out of the hands, the last of a kind thrown):
##                its slot empties and is kept for it; had again while that slot is still empty, it goes back there (the
##                musket put down and picked up again is not a new thing); something else put in that slot ends the claim
##   off the bar  a thing the player has but not on the bar is in the pack only: a weapon off the bar cannot be drawn
##                (FrontierPlayer.is_usable) and is not drawn on the body (SlingRig hides its copy; the tool on the pack's
##                loop is hidden too; the Tab figure matches, InventoryScreen); one in the hands when it is taken off is
##                put away; a tool off the bar is not taken out (GatherTools.take_out, nor by E at a target); the equip
##                wheel lists only the bar (EquipWheel)
##   keys         1-9 (the actions weapon_1..weapon_9: the old weapon keys, 7-9 added; 7 and 8 are taken from the tool
##                and fishing buttons, tool_cycle and fish_gear) take the slot's thing in hand: a weapon drawn
##                (switch_weapon), a tool taken out (GatherTools / FishingGear), a spell readied (SwayCaster.ready_spell
##                when it has it; spell_selected always). The slot in the hands pressed again, or an empty slot: hands
##                free. The mouse wheel steps through the filled slots only
##   spells       readied only from the bar (the owner's rule; SwayCaster.ready_spell refuses one off it): the bar follows
##                the caster's readied spell (`spell`), and a weapon or a tool taken from it, or the hands freed, puts the
##                caster's spell down whoever readied it
##   Tab          the inventory screen's hotbar row (HotbarRow): drag from the pack or the Spells list onto a slot (what was
##                there goes off the bar), between slots to swap, a slot onto the pack to empty it; an item pointed at and
##                1-9 puts it in that slot; dropped on the figure, a weapon, tool or spell goes in the first free slot
##   HUD          FrontierHUD's bottom-right strip shows only the filled slots with their numbers; nothing when empty
##   save         SaveParts' player part ("hotbar": save_of / load_of)
##   arena        Tidebreak's ring (FrontierPlayer.arena): lay_spells(ids) lays the element's keys at once, the start kit closed
##                (kit_placed) so it never comes over them; then only those keys (the same key again: its other skill) and the
##                wheel (the readied skill's variations) act; keys past them do nothing
##   schemes      with an element (the ring, the duel) the control scheme (MatchSetup.scheme(), data/bending/schemes.json)
##                shapes the keys: "keys" and "direction" as above; "radial" too, and its wheel readies any of the
##                element's skills (ready_skill: the key holding its pair turned to it); "first_moves" (a saved "simple"
##                too) four moves only (the first move of keys 1-4): the same key again and 5 do nothing, the wheel steps
##                the four (step_skill), and a key left on its other move is turned back as the scheme comes in
##                (_follow_scheme)
##   round 2      an element's keys have no memory (skills_r2 spec §2.2): a tap readies its key's FIRST move (Bending.first_of),
##                a second tap within double_tap_s its other (Bending.other_move: the mode flipped, or the partner), and
##                so does a wheel step from the readied one; first_moves ignores the second tap. While a lock of the aim
##                runs the key goes to the caster first (SwayCaster.key_tap: the same key switches the lock with its time
##                kept, another key ends it), the wheel too (SwayCaster.step_other)
##   round 3      in a stock-rules ring (RingRules.stock_on) key 3 acts at once and readies nothing, in every scheme
##                (SwayCaster.key3_press: the dash on the deck, the air dodge in the air)
##   F            keys 1 and 2 swapped (SWAP_ACTION; the owner, 2026-10-11: "the F should toggle between 1 and 2"): an element's
##                fighter's readied move goes to the other of the two keys, as that key's press would (swap_keys)

## Something on the bar changed (a slot filled, emptied, moved).
signal changed
## A spell slot taken in hand (`id`), or the readied spell put down (""). SwayCaster.ready_spell(id) is called too when
## the caster has it.
signal spell_selected(id: String)

const SLOTS := 9
const NODE_NAME := &"Hotbar"
const WEAPON := "weapon"
const TOOL := "tool"
const SPELL := "spell"
const KINDS := [WEAPON, TOOL, SPELL]
## Slot i's key action (i from 1): the old weapon keys.
const ACTION := "weapon_%d"
## F: keys 1 and 2 swapped for an element's fighter (swap_keys; InputSetup).
const SWAP_ACTION := &"bend_swap"
## The one-button cycles whose number keys the slots take ([action, key]); the actions stay, unbound, for remapping.
const TAKEN_KEYS := [[&"tool_cycle", KEY_7], [&"fish_gear", KEY_8]]
## What is had is looked at every SYNC_EVERY physics frames (and at every key).
const SYNC_EVERY := 3
## A new game's kit, first and in this order (the owner, 2026-10-02: "1 musket, 2 bow, 3 pistol, 4 felling axe, 5 saber or
## whatever the start owns, in that order"); the rest the start owns follows in the old order.
const START_ORDER := [[WEAPON, "musket"], [WEAPON, "bow"], [WEAPON, "pistol"], [TOOL, "felling_axe"], [TOOL, "saber"]]
## Seconds after the bar is made during which the start's things are laid out as the kit (they come in over the first
## frames: the tools a frame late, the thrown weapons when the level installs them).
const KIT_S := 1.5
## A thing gained after the start: a line telling where it went.
const PACK_NOTICE_S := 3.0

var player: FrontierPlayer
## SLOTS entries: {} or {kind, id}.
var slots: Array[Dictionary] = []
## The spell readied from the bar ("" none).
var spell := ""
## The slot last taken in hand (the wheel steps on from it when the hands are free).
var cursor := 0
## The start's kit is placed (or a save's bar loaded): nothing comes onto the bar by itself any more.
var kit_placed := false
## The arena's bar (lay_spells): only its spells' keys and the wheel act; nothing frees the hands.
var spells_only := false
## "kind:id" -> slot: a thing lost from the bar, its slot kept for it while it stays empty.
var away := {}
var _kit_t := 0.0
## "kind:id" -> true: what the player has that the bar has seen (a thing not in it is new: into the pack, said once).
var _known := {}
var _fresh := true                  ## _known is to be taken as it is next sync, with nothing said (after a load)
var _tick := 0
var _was_sel := -2
var _spell_free := false            ## the hands have been free since the spell was readied
var _scheme_was := ""               ## the control scheme the keys were last shaped for (_follow_scheme)
var _tap_key := -1                  ## an element's key tapped last (-1 none: a double tap's first) and when (BendStatus.now())
var _tap_at := -INF


## The player's hotbar, made on first call.
static func of(p: FrontierPlayer) -> Hotbar:
	var h := find(p)
	if h != null:
		return h
	h = Hotbar.new()
	h.name = NODE_NAME
	h.player = p
	p.add_child(h)
	return h


static func find(p: Node) -> Hotbar:
	return p.get_node_or_null(NodePath(String(NODE_NAME))) as Hotbar if p != null else null


## Whether the player may draw the weapon `key` as far as the bar goes: true with no bar, or the weapon on it (or coming
## back to the slot kept for it).
static func allows(p: Node, key: String) -> bool:
	var h: Hotbar = p.get("hotbar") as Hotbar if p != null else null
	return h == null or h.allows_weapon(key)


## The same for the tool `kind` (GatherTools: taken out only from the bar).
static func allows_tool_of(p: Node, kind: String) -> bool:
	var h: Hotbar = p.get("hotbar") as Hotbar if p != null and p.get("hotbar") is Hotbar else null
	return h == null or h.allows_tool(kind)


static func make(kind: String, id: String) -> Dictionary:
	return {"kind": kind, "id": id}


static func key_of(e: Dictionary) -> String:
	return "%s:%s" % [String(e.get("kind", "")), String(e.get("id", ""))] if not e.is_empty() else ""


## The bar's entry for a pack or worn item kind (the inventory's kinds: "musket", "spear_pair", "felling_axe",
## "stone_axe" for the felling axe it stands in for, "fishing_rod"); {} when it does not go on the bar.
static func entry_for_kind(p: Node, kind: String) -> Dictionary:
	var ws: Variant = p.get("weapons") if p != null else null
	for key: String in InventoryState.KIND_OF_KEY:
		if String(InventoryState.KIND_OF_KEY[key]) == kind and ws is Dictionary and (ws as Dictionary).has(key):
			return make(WEAPON, key)
	if kind in GatherTools.ORDER or kind in FishingGear.ORDER:
		return make(TOOL, kind)
	var st: Dictionary = GatherData.get_default().stone_tools.get(kind, {})
	if String(st.get("stands_for", "")) in GatherTools.ORDER:
		return make(TOOL, String(st.stands_for))
	return {}


## Number keys: weapon_1..weapon_9 (1-6 there already, InputSetup), and the 7 and the 8 taken off the tool and fishing
## buttons so a key does one thing. Safe to call again.
static func ensure_input() -> void:
	for i in range(1, SLOTS + 1):
		var a := StringName(ACTION % i)
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_0 + i
		InputMap.action_add_event(a, e)
	for pair: Array in TAKEN_KEYS:
		var a: StringName = pair[0]
		if not InputMap.has_action(a):
			InputMap.add_action(a)          # (made unbound now, so its own ensure_input does not bind the key later)
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and ((ev as InputEventKey).physical_keycode == pair[1] or (ev as InputEventKey).keycode == pair[1]):
				InputMap.action_erase_event(a, ev)


static func save_of(p: Node) -> Dictionary:
	var h := find(p)
	if h == null:
		return {}
	var out: Array = []
	for e: Dictionary in h.slots:
		out.append(e.duplicate())
	return {"slots": out, "cursor": h.cursor, "kit": true, "away": h.away.duplicate()}


## A save's bar: as it was (an older save of today's first cut, with its "known" list, too). A save from before the bar
## (no "hotbar" part, `d` empty) gets the start's kit from what it owns now.
static func load_of(p: Node, d: Dictionary) -> void:
	var h := find(p)
	if h == null:
		return
	h._drop_spell()                       # (a load readies nothing: the caster's spell put down with the bar's)
	if d.is_empty():
		h._open_kit()
		return
	h.kit_placed = true
	h.away.clear()
	var src: Array = d.get("slots", [])
	for i in SLOTS:
		var e: Variant = src[i] if i < src.size() else {}
		h.slots[i] = {}
		if e is Dictionary and String((e as Dictionary).get("kind", "")) in KINDS and String((e as Dictionary).get("id", "")) != "":
			h.slots[i] = make(String(e.kind), String(e.id))
	var aw: Variant = d.get("away", {})
	if aw is Dictionary:
		for k in aw:
			var at := int(aw[k])
			if at >= 0 and at < SLOTS and h.slots[at].is_empty():
				h.away[String(k)] = at
	h.cursor = clampi(int(d.get("cursor", 0)), 0, SLOTS - 1)
	h._known.clear()
	h._fresh = true
	h.changed.emit()


func _ready() -> void:
	if player == null:
		player = get_parent() as FrontierPlayer
	while slots.size() < SLOTS:
		slots.append({})
	ensure_input()
	sync()


func _physics_process(dt: float) -> void:
	_follow_caster()
	_follow_scheme()
	_shift_dir()
	if not kit_placed:
		_kit_t += dt
		if _kit_t >= KIT_S:
			_close_kit()
	_tick += 1
	if _tick % SYNC_EVERY == 0:
		sync()
	var s := selected()
	if s != _was_sel:
		_was_sel = s
		if s >= 0:
			cursor = s


# --- what is on it --------------------------------------------------------------------------------------------

func entry(i: int) -> Dictionary:
	return slots[i] if i >= 0 and i < slots.size() else {}


func filled(i: int) -> bool:
	return not entry(i).is_empty()


## No slot filled.
func is_empty() -> bool:
	for e: Dictionary in slots:
		if not e.is_empty():
			return false
	return true


func slot_of(kind: String, id: String) -> int:
	for i in slots.size():
		if String(slots[i].get("kind", "")) == kind and String(slots[i].get("id", "")) == id:
			return i
	return -1


func _slot_of_key(k: String) -> int:
	for i in slots.size():
		if key_of(slots[i]) == k:
			return i
	return -1


## The first empty slot (-1: the bar is full).
func first_free() -> int:
	for i in slots.size():
		if slots[i].is_empty():
			return i
	return -1


## The thing `k` lost from the bar comes back to its kept slot when had again (that slot still empty).
func _returning(k: String) -> bool:
	if not away.has(k):
		return false
	var at := int(away[k])
	return at >= 0 and at < slots.size() and slots[at].is_empty()


func allows_weapon(key: String) -> bool:
	var k := key_of(make(WEAPON, key))
	return _slot_of_key(k) >= 0 or _returning(k)


## A tool kind is taken out, and drawn on the body (the pack's loop), only while it is on the bar.
func allows_tool(kind: String) -> bool:
	var k := key_of(make(TOOL, kind))
	return _slot_of_key(k) >= 0 or _returning(k)


## Whether an item of the inventory's kind `pack_kind` is on the body as far as the bar goes: what does not go on the bar
## (a quiver, a horn, rope gear) always; a weapon or a tool only while it is on the bar (the Tab figure, as SlingRig).
func on_body(pack_kind: String) -> bool:
	var e := entry_for_kind(player, pack_kind)
	if e.is_empty():
		return true
	return allows_weapon(String(e.id)) if String(e.kind) == WEAPON else allows_tool(String(e.id))


## Whether the player has `e` now (a spell: one the caster has been granted; with no caster, any).
func has_thing(e: Dictionary) -> bool:
	match String(e.get("kind", "")):
		WEAPON:
			return _has_weapon(String(e.id))
		TOOL:
			return _has_tool(String(e.id))
		SPELL:
			return _has_spell(String(e.get("id", "")))
	return false


## The kind ItemIcons draws for slot i (the roster key for a weapon, as the strip always asked; a tool's stand-in when
## only that is had), "spell:<id>" for a spell, "" empty.
func icon_kind(i: int) -> String:
	var e := entry(i)
	if e.is_empty():
		return ""
	var id := String(e.id)
	match String(e.kind):
		SPELL:
			return "spell:" + id
		TOOL:
			var g := _gather()
			if g != null and id in GatherTools.ORDER and g.stand_in_only(id):
				return g.stand_in(id)
	return id


## The inventory's kind for slot i ("spear_pair" for the spears), "" for a spell or an empty slot.
func pack_kind(i: int) -> String:
	var e := entry(i)
	if e.is_empty() or String(e.kind) == SPELL:
		return ""
	if String(e.kind) == WEAPON:
		return String(InventoryState.KIND_OF_KEY.get(String(e.id), String(e.id)))
	return icon_kind(i)


func label(i: int) -> String:
	var e := entry(i)
	if e.is_empty():
		return ""
	if String(e.kind) == SPELL:
		return spell_label(String(e.id))
	return InventoryState.name_of(pack_kind(i))


## A spell's name (moves.json label).
static func spell_label(id: String) -> String:
	return String(SwayMoves.move(id).get("label", id.capitalize()))


# --- changing it (the player's: the Tab screen) ---------------------------------------------------------------

## Puts `e` in slot i: one already on the bar swaps places with what is there; what slot i held goes off the bar (into
## the pack). False when the player does not have it.
func assign(i: int, e: Dictionary) -> bool:
	if i < 0 or i >= SLOTS or not String(e.get("kind", "")) in KINDS or not has_thing(e):
		return false
	_close_kit()
	e = make(String(e.kind), String(e.id))
	var k := key_of(e)
	var at := _slot_of_key(k)
	if at == i:
		return true
	if at >= 0:
		swap(at, i)
		return true
	var was := slots[i]
	slots[i] = e
	_off_bar(was)
	_known[k] = true
	away.erase(k)
	_unclaim(i)
	changed.emit()
	return true


## Puts `e` in the first free slot (dropped on the Tab figure; a thing taken back onto the bar): its slot, or -1 (none
## free, or not had).
func add(e: Dictionary) -> int:
	var at := _slot_of_key(key_of(e))
	if at >= 0:
		return at
	var i := first_free()
	if i < 0 or not assign(i, e):
		return -1
	return i


func swap(i: int, j: int) -> void:
	if i == j or i < 0 or j < 0 or i >= SLOTS or j >= SLOTS:
		return
	_close_kit()
	var a := slots[i]
	slots[i] = slots[j]
	slots[j] = a
	for s in [i, j]:
		if not slots[s].is_empty():
			_unclaim(s)
	changed.emit()


## Empties slot i: its thing stays the player's, off the bar (in the pack).
func clear(i: int) -> void:
	if not filled(i):
		return
	_close_kit()
	var was := slots[i]
	slots[i] = {}
	_off_bar(was)
	changed.emit()


## `e` taken off the bar by the player: out of the hands if it is in them (a spell put down, a tool put back; a weapon is
## put away by _enforce).
func _off_bar(e: Dictionary) -> void:
	if e.is_empty() or slot_of(String(e.kind), String(e.id)) >= 0:
		return
	match String(e.kind):
		SPELL:
			if String(e.id) == spell:
				_drop_spell()
		TOOL:
			var g := _gather()
			if g != null and g.in_hand() == String(e.id):
				g.put_away()
			var fg := FishingGear.find(player) if player != null else null
			if fg != null and fg.gear == String(e.id):
				fg.put_away()
	if player != null and is_instance_valid(player):
		_enforce()


## The arena's bar (Tidebreak; FrontierPlayer.arena): slots 1.. hold the spells `ids` (an element's keys, Bending.bar), the
## rest empty; the start kit is closed at once (kit_placed: it never comes over it), nothing kept for anything lost, and from
## then on (`spells_only`) only the laid keys and the wheel do anything: a key past them, or the key in the hands again with
## no other skill, leaves the readied spell as it is (no hands free, no weapon to draw).
func lay_spells(ids: Array, only := true) -> void:
	kit_placed = true
	spells_only = only
	_kit_t = KIT_S
	away.clear()
	for i in slots.size():
		var id := String(ids[i]) if i < ids.size() else ""
		slots[i] = make(SPELL, id) if id != "" else {}
	_known.clear()
	_fresh = true
	if spell != "" and slot_of(SPELL, spell) < 0:
		_drop_spell()
	changed.emit()


## A start with nothing (BareStart): an empty bar, no slot kept for anything, the kit placed (there is none).
func start_over() -> void:
	_drop_spell()
	for i in slots.size():
		slots[i] = {}
	away.clear()
	_known.clear()
	_fresh = true
	kit_placed = true
	changed.emit()


## Follows what the player has: lost things come off (their slots kept for them), things had again go back to their kept
## slots; while the start's kit is being placed the bar is laid out from what is had. Nothing new comes onto it.
func sync() -> void:
	if player == null or not is_instance_valid(player):
		return
	var have := _candidates()
	if not kit_placed:
		_lay_kit(have)
		return
	var have_keys := {}
	for e: Dictionary in have:
		have_keys[key_of(e)] = true
	var dirty := false
	for i in slots.size():
		var e := slots[i]
		if e.is_empty():
			continue
		if String(e.kind) == SPELL:
			if not _has_spell(String(e.id)):
				if String(e.id) == spell:
					_drop_spell()
				slots[i] = {}
				dirty = true
			continue
		if not have_keys.has(key_of(e)):
			slots[i] = {}
			away[key_of(e)] = i
			dirty = true
	var new_names: Array[String] = []
	for e: Dictionary in have:
		var k := key_of(e)
		if _slot_of_key(k) >= 0:
			_known[k] = true
			continue
		if away.has(k):
			var at := int(away[k])
			away.erase(k)
			if at >= 0 and at < slots.size() and slots[at].is_empty():
				slots[at] = e
				_known[k] = true
				dirty = true
				continue
		if not _known.has(k) and not _fresh:
			new_names.append(_name_of(e))
		_known[k] = true
	for k: String in _known.keys():
		if not have_keys.has(k):
			_known.erase(k)
	_fresh = false
	if not new_names.is_empty() and player.interactor != null:
		player.interactor.notice("%s: in the pack (Tab: drag it onto the hotbar)" % ", ".join(new_names), PACK_NOTICE_S)
	_enforce()
	if dirty:
		changed.emit()


## The start's kit: what is had, START_ORDER first and then the old order, into slots 1-9 (the rest stays in the pack).
func _lay_kit(have: Array[Dictionary]) -> void:
	var order: Array[Dictionary] = []
	var placed := {}
	for pair: Array in START_ORDER:
		for e: Dictionary in have:
			if String(e.kind) == String(pair[0]) and String(e.id) == String(pair[1]):
				order.append(e)
				placed[key_of(e)] = true
	for e: Dictionary in have:
		if not placed.has(key_of(e)):
			order.append(e)
	var was := slots.duplicate(true)
	for i in SLOTS:
		slots[i] = order[i] if i < order.size() else {}
	_known.clear()
	for e: Dictionary in have:
		_known[key_of(e)] = true
	_enforce()
	if str(was) != str(slots):
		changed.emit()


func _open_kit() -> void:
	kit_placed = false
	_kit_t = 0.0
	away.clear()


func _close_kit() -> void:
	if kit_placed:
		return
	if player != null and is_instance_valid(player):
		_lay_kit(_candidates())
	kit_placed = true
	_fresh = true


## Slot i filled by the player: no lost thing comes back to it.
func _unclaim(i: int) -> void:
	for k: String in away.keys():
		if int(away[k]) == i:
			away.erase(k)


func _name_of(e: Dictionary) -> String:
	if String(e.kind) == WEAPON:
		return InventoryState.name_of(String(InventoryState.KIND_OF_KEY.get(String(e.id), String(e.id))))
	var g := _gather()
	if g != null and String(e.id) in GatherTools.ORDER and g.stand_in_only(String(e.id)):
		return InventoryState.name_of(g.stand_in(String(e.id)))
	return InventoryState.name_of(String(e.id))


# --- in the hands ---------------------------------------------------------------------------------------------

## The slot whose thing is in the hands (or being drawn), -1 none.
func selected() -> int:
	if player == null:
		return -1
	if spell != "":
		return slot_of(SPELL, spell)
	var g := _gather()
	if g != null and g.tool != "" and g.phase in [GatherTools.Phase.HOLSTER, GatherTools.Phase.DRAW_GRAB,
			GatherTools.Phase.DRAW_OUT, GatherTools.Phase.READY, GatherTools.Phase.SWING]:
		return slot_of(TOOL, g.tool)
	var fg := FishingGear.find(player)
	if fg != null and fg.gear != "":
		return slot_of(TOOL, fg.gear)
	if not player.hands_free and player.weapon != null and player.weapon_key != "":
		return slot_of(WEAPON, player.weapon_key)
	return -1


## Key i (0-based): its thing in the hands; the slot in the hands again, or an empty slot: hands free.
func select(i: int) -> void:
	if i < 0 or i >= SLOTS or player == null:
		return
	_follow_caster()
	sync()
	if i == 2 and RingRules.stock_on():
		# (round 3, spec §0: in the % ring 3 acts at once, a dash or the air dodge, and never readies a move: every scheme)
		var c3 := SwayCaster.of(player)
		if c3 != null and c3.key3_press():
			return
	var e := slots[i]
	if _element_keys():
		_key_tap(i)
		return
	if _first_only():
		# (the first-moves scheme: four moves; a key that is not one of them, or the key again, does nothing)
		if not e.is_empty() and String(e.get("kind", "")) == SPELL and _simple_has(String(e.id)) and i != selected():
			cursor = i
			_take(e)
		return
	# (a bending key pressed again: its other skill; the user, 2026-10-04, "toggle between the 1s"; only as an element's
	# fighter, a duel's or the ring's: in the open world a spell's key again puts it down, as the bar always did)
	if not e.is_empty() and i == selected() and String(e.get("kind", "")) == SPELL and Bending.partner_of(String(e.id)) != "" \
			and (spells_only or BendPoses.element_of(player) != ""):
		var other := make(SPELL, Bending.partner_of(String(e.id)))
		if has_thing(other) and assign(i, other):
			cursor = i
			_take(slots[i])
			return
	if spells_only and (e.is_empty() or i == selected() or String(e.get("kind", "")) != SPELL):
		return                              # (the arena's bar: an empty key, or the key in the hands with no other skill)
	if e.is_empty() or i == selected():
		if spell != "" and i == selected() and _keeps_weapon(spell):
			_drop_spell()                   # (an expert's spell put down: the weapon it kept stays in the hand)
			return
		hands_free()
		return
	cursor = i
	_take(e)


## Slot i's thing in the hands (the equip wheel's pick): as its key, but never a toggle (already in the hands: nothing).
func take(i: int) -> void:
	if i < 0 or i >= SLOTS or player == null or slots[i].is_empty() or i == selected():
		return
	cursor = i
	_take(slots[i])


## The wheel: the next (`dir` 1) or the one before (-1) of the filled slots, from the one in the hands (or the last).
func step(dir: int) -> void:
	if player == null:
		return
	sync()
	var cur := selected()
	var from := cur if cur >= 0 else cursor
	for n in range(1, SLOTS + 1):
		var j := posmod(from + dir * n, SLOTS)
		if slots[j].is_empty():
			continue
		if j == cur:
			return                  # (the only one, and it is in the hands)
		cursor = j
		_take(slots[j])
		return


## Nothing in the hands: a tool or the fishing gear put back, the weapon put away on the body, a readied spell put down.
func hands_free() -> void:
	_drop_spell()
	_tools_away()
	if not player.hands_free:
		player.toggle_hands_free()


## The new ring (RingRules.stock_on: Lives or Zones; the owner, 2026-10-11: "those movement spells we keep it as shift and then
## hit a direction button ... then we can use 3 for a different move"): Shift + a direction, in either order (the second press
## makes the pair), is key 3 (select(2): the element's movement spell on the deck, the air dodge in the air) toward the held
## keys (SwayCaster.held_world); the direction again within key3_min_s is key 3's second tap (its other move). Never with the
## guard held (the guard's Roll is E + a direction) nor with Space (Shift + Space drops off a ledge: RingMoves._drop_off).
func _shift_dir() -> void:
	if player == null or not player.arena or player.is_dead or not RingRules.stock_on():
		return
	var c := player.controls
	if c == null or not c.pressed(&"sprint") or c.pressed(InputSetup.GUARD_ACTION) or c.pressed(&"jump"):
		return
	var fresh := false
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		fresh = fresh or c.just_pressed(a)
	if fresh or (c.just_pressed(&"sprint") and c.move_vector().length() > 0.3):
		select(2)


## The player's key event (FrontierPlayer._unhandled_input): true when it was a slot key or the wheel.
func handle_input(event: InputEvent) -> bool:
	for i in SLOTS:
		var a := StringName(ACTION % (i + 1))
		if InputMap.has_action(a) and event.is_action_pressed(a):
			select(i)
			return true
	if InputMap.has_action(SWAP_ACTION) and event.is_action_pressed(SWAP_ACTION) and swap_keys():
		return true
	if InputMap.has_action(&"weapon_next") and event.is_action_pressed(&"weapon_next"):
		wheel(1)
		return true
	if InputMap.has_action(&"weapon_prev") and event.is_action_pressed(&"weapon_prev"):
		wheel(-1)
		return true
	return false


## Keys 1 and 2 swapped (F, SWAP_ACTION): an element's fighter's readied move goes to the other of keys 1 and 2, as a press of
## that key would ready it (its first move; a lock under way ended as another key's press ends it); key 1 when neither is
## readied. False when the bar is no element's (the open world's F is the cook key).
func swap_keys() -> bool:
	if player == null or not (_element_keys() or _first_only()):
		return false
	var k := Bending.key_of(_element(), spell) if spell != "" else -1
	select(1 if k == 0 else 0)
	return true


## The mouse wheel a step (`dir` 1 down, -1 up): first moves, the next of the four; an element's keys, the readied move's
## other (step_other); else the readied spell's next mode, or the next slot.
func wheel(dir: int) -> void:
	if _first_only():
		step_skill(dir)
	elif _element_keys():
		step_other()
	elif not _step_mode(dir) and not spells_only:
		step(dir)


# --- an element's keys (round 2: no memory) ---------------------------------------------------------------------

## Whether the keys are an element's (an element's fighter whose bar holds its keys: Bending.keys) and follow round 2's
## taps (not the first-moves scheme: _first_only).
func _element_keys() -> bool:
	if player == null or not is_instance_valid(player) or _first_only():
		return false
	var el := _element()
	return el != "" and not Bending.keys(el).is_empty() and (spells_only or BendPoses.element_of(player) != "")


## The first-moves scheme (a saved "simple" too): four moves, no second tap.
func _first_only() -> bool:
	return scheme() in ["first_moves", "simple"]


## Key i tapped (an element's: _element_keys). A lock of the aim running hears it first (SwayCaster.key_tap); else a tap
## readies the key's first move and a second tap within double_tap_s its other (spec §2.2), whatever was readied before.
func _key_tap(i: int) -> void:
	var ks := Bending.keys(_element())
	if i < 0 or i >= ks.size():
		return
	var key: Array = ks[i]
	var now := BendStatus.now()
	var c := SwayCaster.of(player)
	if c != null:
		var r := c.key_tap(i)
		if r in ["switch", "ignored"]:
			_tap_key = -1
			return
	var want := Bending.first_of(key)
	if i == _tap_key and now - _tap_at <= Bending.rule("double_tap_s", 0.3):
		var other := Bending.other_move(key, String(want.get("id", "")), String(want.get("mode", "")))
		if not other.is_empty():
			want = other
		_tap_key = -1                       # (a third tap is a first tap again)
	else:
		_tap_key = i
		_tap_at = now
	ready_move(i, String(want.get("id", "")), String(want.get("mode", "")))


## The readied move's key turned to its other move (a wheel step; spec §2.2): mid-lock the lock moves with it
## (SwayCaster.step_other), else it is readied. False when there is none.
func step_other() -> bool:
	var c := SwayCaster.of(player)
	if c != null and c.is_locking():
		return c.step_other()
	var el := _element()
	var k := Bending.key_of(el, spell)
	if k < 0 or c == null:
		return false
	var nxt := Bending.other_move(Bending.keys(el)[k] as Array, spell, c.base_mode_of(spell))
	if nxt.is_empty():
		return false
	return ready_move(k, String(nxt.id), String(nxt.mode))


## Key i turned to move `id` at `mode` and readied (its slot holds `id`; the caster's variation of it `mode`). True when it
## is the readied move now.
func ready_move(i: int, id: String, mode: String) -> bool:
	if id == "" or i < 0 or i >= SLOTS:
		return false
	var e := make(SPELL, id)
	if String(slots[i].get("id", "")) != id and not assign(i, e):
		return false
	var c := SwayCaster.of(player)
	if c != null and mode != "" and c.base_mode_of(id) != mode:
		c.set_mode(id, mode)
	if spell != id or _caster_spell() != id:
		cursor = i
		_take(slots[i])
	return spell == id


# --- the control schemes (an element's fighter) -----------------------------------------------------------------

## The control scheme the keys follow: MatchSetup's for an element's fighter (the ring, the duel), else "keys".
func scheme() -> String:
	if player == null or not is_instance_valid(player) or (not spells_only and BendPoses.element_of(player) == ""):
		return "keys"
	return MatchSetup.scheme()


func _element() -> String:
	var el := BendPoses.element_of(player) if player != null else ""
	if el == "":
		var b := player.get_node_or_null(NodePath(String(Bending.NODE_NAME))) as Bending if player != null else null
		el = b.element if b != null else ""
	return el


## Whether `id` is one of the first-moves scheme's four for the player's element (the first move of keys 1-4).
func _simple_has(id: String) -> bool:
	var ks := Bending.keys(_element())
	for i in mini(ks.size(), 4):
		if not (ks[i] as Array).is_empty() and String((ks[i] as Array)[0]) == id:
			return true
	return false


## Readies the element's skill `id` from its key (the move wheel's pick, RadialWheel): the key whose pair holds it turned to
## it (assign) and taken. True when it is the readied move now.
func ready_skill(id: String) -> bool:
	if player == null or id == "":
		return false
	sync()
	var at := slot_of(SPELL, id)
	if at < 0:
		var other := Bending.partner_of(id)
		at = slot_of(SPELL, other) if other != "" else -1
		if at < 0 or not assign(at, make(SPELL, id)):
			return false
	if selected() != at or spell != id:
		cursor = at
		_take(slots[at])
	return spell == id


## The simple scheme's wheel: the next (`dir` 1) or the one before (-1) of the four moves on the bar.
func step_skill(dir: int) -> void:
	var cur := selected()
	var from := cur if cur >= 0 else cursor
	for n in range(1, SLOTS + 1):
		var j := posmod(from + dir * n, SLOTS)
		var e := slots[j]
		if e.is_empty() or String(e.get("kind", "")) != SPELL or not _simple_has(String(e.id)):
			continue
		if j != cur:
			cursor = j
			_take(e)
		return


## As the simple scheme comes in: each key left on its other skill turned back to its first (the four), and a readied move
## that is not one of them put on the first of them. Looked at each physics frame (a scheme changed in a menu mid-match).
func _follow_scheme() -> void:
	var s := scheme()
	if s == _scheme_was:
		return
	_scheme_was = s
	if not _first_only():
		return
	var el := _element()
	if el == "":
		return
	for i in slots.size():
		var e := slots[i]
		if e.is_empty() or String(e.get("kind", "")) != SPELL or _simple_has(String(e.id)):
			continue
		var first := Bending.partner_of(String(e.id))
		if first != "" and _simple_has(first):
			var was := spell == String(e.id)
			assign(i, make(SPELL, first))
			if was:
				cursor = i
				_take(slots[i])
	if spell != "" and not _simple_has(spell):
		for i in slots.size():
			if _simple_has(String(slots[i].get("id", ""))) and String(slots[i].get("kind", "")) == SPELL:
				cursor = i
				_take(slots[i])
				break


## The wheel with a readied spell of several modes: its next mode (the user, 2026-10-04: "roll the wheel to change that
## spell"); false when there is none to step (the wheel steps the slots).
func _step_mode(dir: int) -> bool:
	var c := player.get_node_or_null("SwayCaster") if player != null else null
	if c == null or spell == "" or not c.has_method(&"step_mode"):
		return false
	return String(c.call(&"step_mode", dir)) != ""


func _take(e: Dictionary) -> void:
	var id := String(e.id)
	match String(e.kind):
		WEAPON:
			_drop_spell()
			_tools_away()
			player.switch_weapon(id)
		TOOL:
			_drop_spell()
			var fg := FishingGear.find(player)
			if id in FishingGear.ORDER:
				if fg != null:
					fg.take_out(id)
			else:
				if fg != null and fg.gear != "":
					fg.put_away()
				var g := _gather()
				if g != null:
					g.take_out(id)
		SPELL:
			# (an expert's spell keeps a pistol, a tomahawk or the saber in the right hand: SwayCaster.keeps_weapon)
			if not _keeps_weapon(id):
				_tools_away()
				if not player.hands_free:
					player.toggle_hands_free()
			spell = id
			_spell_free = player.hands_free
			_tell_spell(id)


func _tools_away() -> void:
	var g := _gather()
	if g != null and g.tool != "":
		g.put_away()
	var fg := FishingGear.find(player)
	if fg != null and fg.gear != "":
		fg.put_away()


## Whether readying spell `id` keeps what the right hand holds (the Sway v2's expert: SwayCaster.keeps_weapon).
func _keeps_weapon(id: String) -> bool:
	var c := player.get_node_or_null("SwayCaster") if player != null else null
	return c != null and c.has_method(&"keeps_weapon") and bool(c.call(&"keeps_weapon", id))


## The readied spell put down: the bar's and the caster's (one the caster readied itself is the bar's too: _follow_caster).
func _drop_spell() -> void:
	if spell == "" and _caster_spell() == "":
		return
	spell = ""
	_tell_spell("")


## The caster's readied spell ("" none, or no caster that says).
func _caster_spell() -> String:
	var c := player.get_node_or_null("SwayCaster") if player != null and is_instance_valid(player) else null
	var r: Variant = c.get("readied_spell") if c != null else null
	return String(r) if r is String else ""


## The bar follows the caster: a spell it readied (a direct call on a spell on the bar: a trainer, a test) is the bar's
## selected slot; one it put down (a weapon taken into the hands its tier does not keep) is put down here too. One the
## caster holds off the bar (it cannot: ready_spell refuses) is put down.
func _follow_caster() -> void:
	if player == null or not is_instance_valid(player):
		return
	var c := player.get_node_or_null("SwayCaster")
	var r: Variant = c.get("readied_spell") if c != null else null
	if not (r is String) or String(r) == spell:
		return
	var id := String(r)
	if id != "" and slot_of(SPELL, id) < 0:
		spell = ""
		_tell_spell("")
		return
	spell = id
	_spell_free = player.hands_free
	spell_selected.emit(id)


func _tell_spell(id: String) -> void:
	var c := player.get_node_or_null("SwayCaster")
	if c != null and c.has_method(&"ready_spell"):
		c.call(&"ready_spell", id)
	spell_selected.emit(id)


## Nothing off the bar is in the hands or on the body: a weapon taken off while drawn is put away, the tool on the
## pack's loop is hidden while it is off; a readied spell is put down when a weapon or a tool comes into the hands.
func _enforce() -> void:
	if player.is_dead:
		return
	if not player.hands_free and player.weapon != null and player.weapon_key != "" and not allows_weapon(player.weapon_key) \
			and not player.is_switching() and player.riding == null:
		player.toggle_hands_free()
	if spell != "":
		var g := _gather()
		var fg := FishingGear.find(player)
		if player.hands_free:
			_spell_free = true
		# (a weapon drawn after the hands were free for the spell: the equip wheel, H; a tool or the rod taken out; not one
		# an expert's spell keeps in the right hand: _keeps_weapon)
		var keeps := _keeps_weapon(spell)
		if slot_of(SPELL, spell) < 0 or (_spell_free and not player.hands_free and not keeps) \
				or (g != null and g.in_hand() != "" and not keeps) or (fg != null and fg.gear != ""):
			_drop_spell()
	var gt := _gather()
	if gt != null and gt._socket_back != null:
		gt._socket_back.visible = gt.on_loop == "" or allows_tool(gt.on_loop)


# --- what the player has ----------------------------------------------------------------------------------------

## What the player has that goes on the bar, in the old order.
func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in player.weapon_order:
		if _has_weapon(key):
			out.append(make(WEAPON, key))
	var g := _gather()
	if g != null and g.data != null:
		for t: String in GatherTools.ORDER:
			if g.data.is_tool(t) and g.owns(t):
				out.append(make(TOOL, t))
	if FishingGear.find(player) != null:
		for t: String in FishingGear.ORDER:
			if _in_pack(t):
				out.append(make(TOOL, t))
	return out


func _has_weapon(key: String) -> bool:
	if not player.weapons.has(key) or not player.is_carried(key):
		return false
	var w: Weapon = player.weapons[key]
	return not (w is Throwable and (w as Throwable).count <= 0)


func _has_tool(kind: String) -> bool:
	if kind in FishingGear.ORDER:
		return FishingGear.find(player) != null and _in_pack(kind)
	var g := _gather()
	return g != null and g.data != null and g.data.is_tool(kind) and g.owns(kind)


## A spell the player's caster has been granted (with no caster, or one that cannot say: any). With no caster but a save's
## Sway part waiting for one (SwayCaster.load_of's meta sway_save), the spells that save granted: a game saved under the
## Sway's free use (every spell known; the user, 2026-10-03: "lets make the spells free use right now") and loaded with
## the switch off has no caster in a plain game, and its spells on the bar would stay doing nothing.
func _has_spell(id: String) -> bool:
	if id == "":
		return false
	var c := player.get_node_or_null("SwayCaster") if player != null else null
	if c == null and player != null and player.has_meta(&"sway_save"):
		var sv: Variant = player.get_meta(&"sway_save")
		if sv is Dictionary and (sv as Dictionary).get("moves") is Array:
			return ((sv as Dictionary).moves as Array).has(id)
	if c == null or not c.has_method(&"has"):
		return true
	return bool(c.call(&"has", id))


func _in_pack(kind: String) -> bool:
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) == kind and int(e.get("count", 0)) > 0:
			return true
	return false


func _gather() -> GatherTools:
	var g: GatherTools = player.gather if player != null else null
	return g if g != null and is_instance_valid(g) else null
