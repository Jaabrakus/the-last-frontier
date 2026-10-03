class_name PlayerBags
extends Node
## WoW-style bags (the owner, 2026-10-03: "can we do the inventory similar to world of warcraft with the bags and etc?"
## (haversack, satchel and so on), then "WoW-style bags ... i just need you to do these"): a SLOT LAYOUT over the pack.
## The pack stays what it was (FrontierPlayer.inventory_pack, a flat list of {kind, count, state} some forty scripts
## write: pickups, forage, skinning, loot, cooking, the stations, captivity, death's pack drop, the horse, the spouse);
## this lays its stacks out in bag slots and follows it, so none of those writers changes. One per player (the local
## one): PlayerBags.of(player). Data: data/inventory/bags.json.
##
##   the bags     the HAVERSACK, always worn (the base pack: 16 slots, 4 wide as the classic backpack; bag 0), and FOUR
##                sockets on the bag bar (ClassicBagBar; bags 1-4) that take bag items: a linen satchel (8), a knapsack
##                (12), a blanket roll (10), a portmanteau (16, trade only), and the specialty bags that hold only their
##                own kinds, as the classic herb and ammunition bags do: the hunting pouch (12, shot and its makings), the
##                game bag (16, game), the simples bag (14: "simples", the period word for medicinal plants). None is a
##                medicine bag or a bundle (sacred objects of living Native traditions); the bow's worn quiver stays the
##                loadout piece it is (no quiver bag)
##   a slot       one stack of one kind, up to the kind's stack size (bags.json "stacks": 20, heavy things 1-5, small
##                things 50); a pack entry bigger than a stack fills several slots
##   what         what the Tab screen lists as the pack (InventoryScreen.pack_rows: the pack less what is on the hotbar,
##                and a weapon or a tool worn but kept off the bar: off the bar it is in the pack), and the garments
##                carried, not worn (the survival core's: ClothesSlots; kind "cloth:<item>"). What is on the hotbar and
##                the clothes worn take no room; a bag in a socket is not in the pack
##   where        a stack keeps its slot (the player's move, swap, split). Anything new goes: onto a stack of its kind
##                with room; back to a slot it left that is still empty (a claim: what captors took or death dropped
##                comes back as it lay; a claim never keeps the slot from anything else); else the first free slot that
##                may hold it: a fitting SPECIALTY bag first, then the haversack, then the other bags in socket order
##                (bag 1, beside the haversack on the bar, first, as the classic bags fill). A kind used up takes from
##                the loose first, then from its smallest stack (the later of equals)
##   full         what fits nowhere still comes in (no pickup path breaks) but rides LOOSE (`loose`, a stack a loose
##                slot, the Loose strip under the bags): each loose slot slows the player 4 % (at most 30 %), multiplied
##                into the speed the survival bridge feeds (FrontierPlayer.survival_speed_mult: SurvivalBridge._to_player;
##                without a bridge, set here); from 4 loose slots no sprint; "Your bags are full." once per filling (the
##                interactor's notice, which the classic HUD's chat log writes; `full`). Room made (a thing eaten, put in
##                a chest, a bag put on) takes the loose in again, the oldest first
##   bags         a bag not worn is a pack thing like any other (one a slot, never in a specialty bag). equip() puts one
##                from the pack in a socket (a bag already there must be empty: it comes off into the pack, where the new
##                one lay); unequip() takes off only an EMPTY bag, into a slot of the other bags (refused when none has
##                room). Made at the workbench (CampStation.BAGS), sold by the traders (the core's items, bags.json
##                "trade"), sometimes in a fallen fighter's things (bags.json "loot": NpcFighter)
##   new game     the haversack and a linen satchel in socket 1, laid out once the hotbar's kit is placed (the start's
##                things come in over the first frames: laid before, the musket would have left a hole); a start with
##                nothing (BareStart: start_over) the haversack alone
##   save         SaveParts' player part ("bags": save_of / load_of): the sockets, the slots, the claims, the loose. A
##                save from before the bags: the haversack and a linen satchel, laid out afresh
##   captivity, death  whatever they do to the pack, the layout follows: the things gone leave their slots empty and
##                claimed, so what is given back or taken up again from the dropped pack goes back where it lay. The
##                WORN bags stay on the body, empty: the captive keeps what they wear (Captivity's kit rule) as the dead
##                come back in what they wear (DeathRule); a bag carried in the pack goes with the pack
##
##   var bags := PlayerBags.of(player)
##   bags.sync()                              # follow the pack now (every SYNC_EVERY physics frames by itself)
##   bags.slot(0, 3)                          # {kind, count, state} or {}
##   bags.move(0, 3, 1, 0)                    # {ok, reason}
##   bags.equip("knapsack", 1)                # {ok, reason, socket}
## The whole API is listed under "--- the API" below.

## The layout changed (a stack moved, came, went; a bag put on or off).
signal changed
## The bags filled: something rides loose (once per filling).
signal full

const DATA_PATH := "res://data/inventory/bags.json"
const NODE_NAME := &"PlayerBags"
const HAVERSACK := "haversack"
## The bag sockets on the bar (bags 1-4; bag 0 is the haversack).
const SOCKETS := 4
const ANY := "any"
## A garment carried: "cloth:<core item>".
const CLOTH := "cloth:"
## The pack is looked at every SYNC_EVERY physics frames (and at every call of the API).
const SYNC_EVERY := 6
const FULL_TEXT := "Your bags are full."

static var _data := {}

var player: Node
## The bag kind in each socket ("" empty), socket 0 first (bag 1).
var sockets: Array[String] = []
## Bag b (0 the haversack, 1-4 the sockets) -> its slots: {} or {kind, count}.
var grid: Array = []
## Bag b -> its slots' claims: the kind that left an empty slot ("" none).
var claims: Array = []
## The stacks riding loose, oldest first: [{kind, count}].
var loose: Array[Dictionary] = []
## kind -> the pack's state of it (a made thing's standard), for slot().
var _states := {}
## kind -> how many the player has that take bag room (the last sync's).
var _want := {}
var _fresh := true                  ## the next sync lays everything out anew (a new game, a save from before the bags)
var _sig := ""
var _full_said := false
var _tick := 0
var _fed := false                   ## the survival bridge feeds the speed (looked at with each sync)


# --- the data ---------------------------------------------------------------------------------------------------

static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = d if d is Dictionary else {"haversack": {"name": "Haversack", "slots": 16, "holds": ANY}, "bags": {}}
	return _data


## Whether `kind` is a bag item (one that goes in a socket; the haversack is not one: it is always worn).
static func is_bag(kind: String) -> bool:
	return (data().get("bags", {}) as Dictionary).has(kind)


static func bag_kinds() -> Array:
	return (data().get("bags", {}) as Dictionary).keys()


## The bag `kind`'s row of bags.json ({name, slots, holds, text, got}); the haversack's for "haversack"; {} for none.
static func bag_def(kind: String) -> Dictionary:
	if kind == HAVERSACK:
		return data().get("haversack", {})
	return (data().get("bags", {}) as Dictionary).get(kind, {})


static func slots_of(kind: String) -> int:
	return int(bag_def(kind).get("slots", 0))


## "any", or the specialty: "shot", "game", "simples".
static func holds_of(kind: String) -> String:
	return String(bag_def(kind).get("holds", ANY))


static func is_specialty(kind: String) -> bool:
	return kind != "" and holds_of(kind) != ANY


## What a bag holds, in words ("anything"; "game: meat, fish, ...").
static func holds_text(kind: String) -> String:
	var h := holds_of(kind)
	if h == ANY:
		return "anything"
	return String(((data().get("holds", {}) as Dictionary).get(h, {}) as Dictionary).get("text", h))


## Whether a bag of `bag_kind` may hold `kind` (a specialty bag only its own kinds; a bag carried is never in one).
static func fits(bag_kind: String, kind: String) -> bool:
	if bag_kind == "" or bag_def(bag_kind).is_empty():
		return false
	var h := holds_of(bag_kind)
	if h == ANY:
		return true
	var kinds: Array = ((data().get("holds", {}) as Dictionary).get(h, {}) as Dictionary).get("kinds", [])
	return kinds.has(kind)


## How many of `kind` one slot holds.
static func stack_of(kind: String) -> int:
	if kind.begins_with(CLOTH) or is_bag(kind):
		return 1
	var st: Dictionary = data().get("stacks", {})
	return maxi(int((st.get("kinds", {}) as Dictionary).get(kind, st.get("default", 20))), 1)


static func name_of(kind: String) -> String:
	var d := bag_def(kind)
	if d.has("name"):
		return String(d.name)
	return InventoryState.name_of(kind)


static func _loose_rule(key: String, def: float) -> float:
	return float((data().get("loose", {}) as Dictionary).get(key, def))


## The sockets a new game starts with (`bare`: a start with nothing's).
static func start_sockets(bare := false) -> Array:
	return ((data().get("start", {}) as Dictionary).get("bare" if bare else "sockets", [])).duplicate()


## The core item a trader sells `kind` as ("" not sold): bags.json "trade".
static func trade_item(kind: String) -> String:
	var t: Variant = (data().get("trade", {}) as Dictionary).get(kind, "")
	return String(t) if t is String else ""


## The bags a fallen fighter of `faction` leaves: each of bags.json "loot"'s kinds for it, on its chance (`rng`, or the
## global one). [{kind, count}].
static func loot_for(faction: String, rng: RandomNumberGenerator = null) -> Array:
	var out := []
	var table: Variant = (data().get("loot", {}) as Dictionary).get(faction, {})
	if not (table is Dictionary):
		return out
	for k: String in table:
		if not is_bag(k):
			continue
		var roll := rng.randf() if rng != null else randf()
		if roll < float(table[k]):
			out.append({"kind": k, "count": 1})
	return out


# --- one per player ---------------------------------------------------------------------------------------------

## The player's bags, made on first call (a new game's: the haversack and the start's sockets).
static func of(p: Node) -> PlayerBags:
	var g := find(p)
	if g != null:
		return g
	g = PlayerBags.new()
	g.name = NODE_NAME
	g.player = p
	g.reset(start_sockets())
	p.add_child(g)
	return g


static func find(p: Node) -> PlayerBags:
	return p.get_node_or_null(NodePath(String(NODE_NAME))) as PlayerBags if p != null and is_instance_valid(p) else null


## The player's speed x this for the loose slots (1 with no bags).
static func speed_mult_of(p: Node) -> float:
	var g := find(p)
	return g.speed_mult() if g != null else 1.0


static func sprint_ok_of(p: Node) -> bool:
	var g := find(p)
	return g == null or g.sprint_ok()


static func save_of(p: Node) -> Dictionary:
	var g := find(p)
	if g == null:
		return {}
	var out_loose := []
	for e: Dictionary in g.loose:
		out_loose.append({"kind": String(e.kind), "count": int(e.count)})
	return {"sockets": Array(g.sockets), "grid": g.grid.duplicate(true), "claims": g.claims.duplicate(true), "loose": out_loose,
			"laid": not g._fresh}


## A save's bags as they were; a save from before the bags (`d` empty): the haversack and the start's satchel, laid
## out afresh. Called after the pack and the hotbar are loaded (SaveParts.load_player).
static func load_of(p: Node, d: Dictionary) -> void:
	var g := find(p)
	if g == null:
		return
	if d.is_empty():
		g.reset(start_sockets())
		return
	var s: Array[String] = []
	var src: Array = d.get("sockets", [])
	for i in SOCKETS:
		var k := String(src[i]) if i < src.size() and src[i] is String else ""
		s.append(k if is_bag(k) else "")
	g.sockets = s
	g.grid = []
	g.claims = []
	g._size_bags()
	var dg: Array = d.get("grid", [])
	var dc: Array = d.get("claims", [])
	for b in g.grid.size():
		var row: Array = dg[b] if b < dg.size() and dg[b] is Array else []
		var crow: Array = dc[b] if b < dc.size() and dc[b] is Array else []
		for i in (g.grid[b] as Array).size():
			var e: Variant = row[i] if i < row.size() else {}
			if e is Dictionary and String((e as Dictionary).get("kind", "")) != "" and int((e as Dictionary).get("count", 0)) > 0:
				g.grid[b][i] = {"kind": String(e.kind), "count": int(e.count)}
			var c: Variant = crow[i] if i < crow.size() else ""
			g.claims[b][i] = String(c) if c is String else ""
	g.loose.clear()
	for e: Variant in d.get("loose", []):
		if e is Dictionary and String((e as Dictionary).get("kind", "")) != "" and int((e as Dictionary).get("count", 0)) > 0:
			g.loose.append({"kind": String(e.kind), "count": int(e.count)})
	g._fresh = not bool(d.get("laid", true))
	g._sig = ""
	g._full_said = not g.loose.is_empty()          # (a load says nothing of bags already full)
	g.sync()
	g.changed.emit()


func _ready() -> void:
	if player == null:
		player = get_parent()
	if grid.is_empty():
		reset(start_sockets())


func _physics_process(_dt: float) -> void:
	_tick += 1
	if _tick % SYNC_EVERY == 0:
		sync()
		_fed = _bridge_feeds()
	if not _fed and player is FrontierPlayer:
		# (no survival bridge to feed the speed: the loose slots' slow-down and the sprint set here; nothing else writes them
		# then)
		var fp := player as FrontierPlayer
		fp.survival_speed_mult = speed_mult()
		fp.sprint_allowed = sprint_ok()


## Whether the survival bridge feeds this player's speed (and multiplies the bags' in: SurvivalBridge._to_player).
func _bridge_feeds() -> bool:
	if not is_inside_tree():
		return false
	var b := SurvivalBridge.find(get_tree())
	return b != null and b.core != null and b.player == player


# --- the API ----------------------------------------------------------------------------------------------------
#   bag_count() -> 5                       the haversack (0) and the four sockets (1-4)
#   bag_kind(b) / bag_name(b) / bag_size(b) / bag_holds(b) / bag_wide(b)
#   slot(b, i) -> {kind, count, state} or {}           claim(b, i) -> the kind that left it ("")
#   kind_name(kind)                        a slot's thing's name (a garment's by the core: "Moccasins")
#   free_slots(b) / used_slots(b) / free_total() / free_for(kind)
#   can_hold(b, kind) -> {ok, reason}                  may bag b hold `kind` (its socket empty, a specialty's kinds)
#   move(b, i, to_b, to_i) -> {ok, reason}             onto an empty slot, onto its kind (as many as fit), else swap
#   swap(b, i, to_b, to_i) -> {ok, reason}
#   split(b, i, n, to_b = -1, to_i = -1) -> {ok, reason, at: [b, i]}   n off into an empty slot (the first that holds it)
#   place(li, b = -1, i = -1) -> {ok, reason, at}      a loose stack put away (onto another kind: they change places)
#   take_out(b, i) / take_out_loose(li) -> {ok, reason, kind, count, state}   out of the pack (a chest, the ground: the
#                                          caller's); not a weapon's, the torches or a garment (they have their own ways)
#   loose (the stacks), loose_slots(), speed_mult(), sprint_ok()
#   equip(kind, socket = -1, from_b = -1, from_i = -1) -> {ok, reason, socket}
#   unequip(socket, to_b = -1, to_i = -1) -> {ok, reason, at}
#   swap_sockets(a, c)
#   sync() -> bool (changed)               signals changed, full

func bag_count() -> int:
	return 1 + SOCKETS


## Bag b's kind: "haversack", a socket's bag, "" an empty socket.
func bag_kind(b: int) -> String:
	if b == 0:
		return HAVERSACK
	return sockets[b - 1] if b >= 1 and b <= SOCKETS else ""


func bag_name(b: int) -> String:
	var k := bag_kind(b)
	return name_of(k) if k != "" else ""


func bag_size(b: int) -> int:
	return (grid[b] as Array).size() if b >= 0 and b < grid.size() else 0


func bag_holds(b: int) -> String:
	var k := bag_kind(b)
	return holds_of(k) if k != "" else ""


## Columns of bag b's window (the classic bags are all 4 wide; a bag's "wide" in the data).
func bag_wide(b: int) -> int:
	return int(bag_def(bag_kind(b)).get("wide", 4))


func slot(b: int, i: int) -> Dictionary:
	if not _valid(b, i):
		return {}
	var e: Dictionary = grid[b][i]
	if e.is_empty():
		return {}
	return {"kind": String(e.kind), "count": int(e.count), "state": (_states.get(String(e.kind), {}) as Dictionary).duplicate(true)}


## What a slot's thing is called: a bag's or a pack kind's name; a garment carried ("cloth:<item>") by the core's name for
## it ("Moccasins").
func kind_name(kind: String) -> String:
	if kind.begins_with(CLOTH):
		var id := kind.trim_prefix(CLOTH)
		var br := SurvivalBridge.find(get_tree()) if is_inside_tree() else null
		return ClothesSlots.name_of(br.core, id) if br != null and br.core != null else id.get_slice(".", 2).capitalize()
	return name_of(kind)


func claim(b: int, i: int) -> String:
	return String(claims[b][i]) if _valid(b, i) else ""


func used_slots(b: int) -> int:
	var n := 0
	if b >= 0 and b < grid.size():
		for e: Dictionary in grid[b]:
			if not e.is_empty():
				n += 1
	return n


func free_slots(b: int) -> int:
	return bag_size(b) - used_slots(b)


func free_total() -> int:
	var n := 0
	for b in grid.size():
		n += free_slots(b)
	return n


## Free slots that may hold `kind`.
func free_for(kind: String) -> int:
	var n := 0
	for b in grid.size():
		if fits(bag_kind(b), kind):
			n += free_slots(b)
	return n


func slots_total() -> int:
	var n := 0
	for b in grid.size():
		n += bag_size(b)
	return n


func loose_slots() -> int:
	return loose.size()


## The player's speed x this: LOOSE_SLOW a loose slot, at most the data's slow_max.
func speed_mult() -> float:
	if loose.is_empty():
		return 1.0
	return 1.0 - minf(_loose_rule("slow_each", 0.04) * float(loose.size()), _loose_rule("slow_max", 0.3))


func sprint_ok() -> bool:
	return loose.size() < int(_loose_rule("no_sprint_at", 4.0))


## May bag b hold `kind`: {ok, reason}.
func can_hold(b: int, kind: String) -> Dictionary:
	if b < 0 or b >= bag_count():
		return _no("There is no such bag")
	var bk := bag_kind(b)
	if bk == "":
		return _no("No bag in that socket")
	if fits(bk, kind):
		return _yes()
	if is_bag(kind):
		return _no("A bag does not go in the %s" % name_of(bk).to_lower())
	return _no("The %s holds only %s" % [name_of(bk).to_lower(), holds_text(bk)])


## Moves the stack at (b, i) to (to_b, to_i): onto an empty slot that may hold it; onto a stack of its kind, as many as
## fit (the rest stays); onto another kind, they change places (swap).
func move(b: int, i: int, to_b: int, to_i: int) -> Dictionary:
	sync()
	if not _valid(b, i) or not _valid(to_b, to_i):
		return _no("There is no such slot")
	var src: Dictionary = grid[b][i]
	if src.is_empty():
		return _no("Nothing there")
	if b == to_b and i == to_i:
		return _yes()
	var dst: Dictionary = grid[to_b][to_i]
	var k := String(src.kind)
	if dst.is_empty():
		var r := can_hold(to_b, k)
		if not bool(r.ok):
			return r
		grid[to_b][to_i] = src
		grid[b][i] = {}
		claims[to_b][to_i] = ""
		claims[b][i] = ""
		changed.emit()
		return _yes()
	if String(dst.kind) == k:
		var t := mini(stack_of(k) - int(dst.count), int(src.count))
		if t <= 0:
			return _yes()                 # (a full stack onto a full stack of its kind: nothing to do)
		dst.count = int(dst.count) + t
		src.count = int(src.count) - t
		if int(src.count) <= 0:
			grid[b][i] = {}
			claims[b][i] = ""
		changed.emit()
		return _yes()
	return swap(b, i, to_b, to_i)


## The stacks at (b, i) and (to_b, to_i) change places (each must suit the other's bag).
func swap(b: int, i: int, to_b: int, to_i: int) -> Dictionary:
	sync()
	if not _valid(b, i) or not _valid(to_b, to_i):
		return _no("There is no such slot")
	var a: Dictionary = grid[b][i]
	var c: Dictionary = grid[to_b][to_i]
	if not a.is_empty():
		var r := can_hold(to_b, String(a.kind))
		if not bool(r.ok):
			return r
	if not c.is_empty():
		var r2 := can_hold(b, String(c.kind))
		if not bool(r2.ok):
			return r2
	grid[b][i] = c
	grid[to_b][to_i] = a
	claims[b][i] = ""
	claims[to_b][to_i] = ""
	changed.emit()
	return _yes()


## `n` of the stack at (b, i) into their own slot: (to_b, to_i) when given (empty, or its kind with room), else the
## first empty slot that may hold them. {ok, reason, at: [b, i]}.
func split(b: int, i: int, n: int, to_b := -1, to_i := -1) -> Dictionary:
	sync()
	if not _valid(b, i):
		return _no("There is no such slot")
	var src: Dictionary = grid[b][i]
	if src.is_empty():
		return _no("Nothing there")
	var k := String(src.kind)
	if n < 1 or n >= int(src.count):
		return _no("Split off between 1 and %d" % (int(src.count) - 1))
	var at := [to_b, to_i]
	if to_b < 0:
		at = _first_empty(k)
		if int(at[0]) < 0:
			return _no("No free slot for it")
	elif not _valid(to_b, to_i) or (to_b == b and to_i == i):
		return _no("There is no such slot")
	var dst: Dictionary = grid[at[0]][at[1]]
	if dst.is_empty():
		var r := can_hold(int(at[0]), k)
		if not bool(r.ok):
			return r
		grid[at[0]][at[1]] = {"kind": k, "count": n}
		claims[at[0]][at[1]] = ""
	elif String(dst.kind) == k and int(dst.count) + n <= stack_of(k):
		dst.count = int(dst.count) + n
	else:
		return _no("That slot is taken")
	src.count = int(src.count) - n
	changed.emit()
	return {"ok": true, "reason": "", "at": at}


## Puts the loose stack `li` away: into (b, i) when given (empty; onto its kind as many as fit; onto another kind they
## change places: that stack rides loose), else the first slot that holds it (topping up its kind first).
## {ok, reason, at: [b, i]}.
func place(li: int, b := -1, i := -1) -> Dictionary:
	sync()
	if li < 0 or li >= loose.size():
		return _no("Nothing loose there")
	var e: Dictionary = loose[li]
	var k := String(e.kind)
	if b < 0:
		var left := _into_bags(k, int(e.count))
		if left == int(e.count):
			return _no("No room for it in your bags")
		if left <= 0:
			loose.remove_at(li)
		else:
			e.count = left
		_after()
		return {"ok": true, "reason": "", "at": []}
	if not _valid(b, i):
		return _no("There is no such slot")
	var r := can_hold(b, k)
	if not bool(r.ok):
		return r
	var dst: Dictionary = grid[b][i]
	if dst.is_empty():
		grid[b][i] = {"kind": k, "count": int(e.count)}
		claims[b][i] = ""
		loose.remove_at(li)
	elif String(dst.kind) == k:
		var t := mini(stack_of(k) - int(dst.count), int(e.count))
		if t <= 0:
			return _no("That stack is full")
		dst.count = int(dst.count) + t
		e.count = int(e.count) - t
		if int(e.count) <= 0:
			loose.remove_at(li)
	else:
		grid[b][i] = {"kind": k, "count": int(e.count)}
		claims[b][i] = ""
		loose[li] = {"kind": String(dst.kind), "count": int(dst.count)}
	_after()
	return {"ok": true, "reason": "", "at": [b, i]}


## Takes the stack at (b, i) out of the pack (into a chest, onto the ground: the caller's): {ok, reason, kind, count,
## state}. Not a weapon's (InventoryState works them out from the weapons carried: put one down with E), the torches
## (PlayerTorch keeps them) or a garment (the core's kit: the Clothes tab).
func take_out(b: int, i: int) -> Dictionary:
	sync()
	if not _valid(b, i) or (grid[b][i] as Dictionary).is_empty():
		return _no("Nothing there")
	var e: Dictionary = grid[b][i]
	var r := _take_from_pack(String(e.kind), int(e.count))
	if bool(r.ok):
		grid[b][i] = {}
		claims[b][i] = ""
		_after()
	return r


func take_out_loose(li: int) -> Dictionary:
	sync()
	if li < 0 or li >= loose.size():
		return _no("Nothing loose there")
	var e: Dictionary = loose[li]
	var r := _take_from_pack(String(e.kind), int(e.count))
	if bool(r.ok):
		loose.remove_at(li)
		_after()
	return r


func _take_from_pack(k: String, n: int) -> Dictionary:
	if InventoryState._derived(k) or k == InventoryState.TORCH or k.begins_with(CLOTH):
		return _no("%s is not taken out this way" % name_of(k.trim_prefix(CLOTH)))
	var inv := InventoryState.from_player(player)
	var st := (_states.get(k, {}) as Dictionary).duplicate(true)
	var got := inv.take(k, n)
	if got <= 0:
		return _no("You have no %s" % name_of(k).to_lower())
	player.set("inventory_pack", inv.pack.duplicate(true))
	_want[k] = maxi(int(_want.get(k, 0)) - got, 0)
	_sig = ""
	return {"ok": true, "reason": "", "kind": k, "count": got, "state": st}


## Puts the bag `kind` from the pack in `socket` (-1: the first empty one); from (from_b, from_i) when given (the slot it
## is dragged from). A bag already in the socket must be empty: it comes off into the pack, into the slot the new one
## left. {ok, reason, socket}.
func equip(kind: String, socket := -1, from_b := -1, from_i := -1) -> Dictionary:
	sync()
	if not is_bag(kind):
		return _no("%s is not a bag" % name_of(kind))
	if int(_want.get(kind, 0)) <= 0:
		return _no("You have no %s" % name_of(kind).to_lower())
	if from_b >= 0 and (not _valid(from_b, from_i) or String((grid[from_b][from_i] as Dictionary).get("kind", "")) != kind):
		return _no("There is no %s there" % name_of(kind).to_lower())
	if socket < 0:
		socket = sockets.find("")
		if socket < 0:
			return _no("Every bag socket has a bag: take one off first")
	if socket >= SOCKETS:
		return _no("There is no such socket")
	var old := sockets[socket]
	if old != "" and used_slots(socket + 1) > 0:
		return _no("Empty the %s first" % name_of(old).to_lower())
	# where the new bag lay: that slot (or its smallest stack's) gives it up
	var at := [from_b, from_i] if from_b >= 0 else _smallest(kind)
	if int(at[0]) >= 0:
		var e: Dictionary = grid[at[0]][at[1]]
		e.count = int(e.count) - 1
		if int(e.count) <= 0:
			grid[at[0]][at[1]] = {}
	else:
		var li := _loose_of(kind)
		if li >= 0:
			loose[li].count = int(loose[li].count) - 1
			if int(loose[li].count) <= 0:
				loose.remove_at(li)
	var inv := InventoryState.from_player(player)
	inv.take(kind, 1)
	if old != "":
		inv.add(old, 1)
	player.set("inventory_pack", inv.pack.duplicate(true))
	_want[kind] = int(_want.get(kind, 0)) - 1
	sockets[socket] = kind
	grid[socket + 1] = []
	claims[socket + 1] = []
	_size_bags()
	if old != "":
		# the old bag where the new one lay (that slot is free now), else wherever a bag may go
		if int(at[0]) >= 0 and (grid[at[0]][at[1]] as Dictionary).is_empty() and fits(bag_kind(int(at[0])), old):
			grid[at[0]][at[1]] = {"kind": old, "count": 1}
			claims[at[0]][at[1]] = ""
			_want[old] = int(_want.get(old, 0)) + 1
	_sig = ""
	sync()
	changed.emit()
	return {"ok": true, "reason": "", "socket": socket}


## Takes the bag in `socket` off into the pack, only when it is EMPTY: into (to_b, to_i) when given (an empty slot of
## another bag that may hold it), else the first such slot. Refused when the other bags have no room for it.
## {ok, reason, at: [b, i]}.
func unequip(socket: int, to_b := -1, to_i := -1) -> Dictionary:
	sync()
	if socket < 0 or socket >= SOCKETS or sockets[socket] == "":
		return _no("No bag there")
	var k := sockets[socket]
	var n := used_slots(socket + 1)
	if n > 0:
		return _no("Empty the %s first (%d slot%s in use)" % [name_of(k).to_lower(), n, "" if n == 1 else "s"])
	var at := [to_b, to_i]
	if to_b < 0:
		at = _first_empty(k, socket + 1)
		if int(at[0]) < 0:
			return _no("No room for the %s in your other bags" % name_of(k).to_lower())
	elif to_b == socket + 1 or not _valid(to_b, to_i) or not (grid[to_b][to_i] as Dictionary).is_empty() or not fits(bag_kind(to_b), k):
		return _no("The %s does not go there" % name_of(k).to_lower())
	sockets[socket] = ""
	grid[socket + 1] = []
	claims[socket + 1] = []
	grid[at[0]][at[1]] = {"kind": k, "count": 1}
	claims[at[0]][at[1]] = ""
	var inv := InventoryState.from_player(player)
	inv.add(k, 1)
	player.set("inventory_pack", inv.pack.duplicate(true))
	_want[k] = int(_want.get(k, 0)) + 1
	_sig = ""
	sync()
	changed.emit()
	return {"ok": true, "reason": "", "at": at}


## Two sockets' bags change places, their things with them.
func swap_sockets(a: int, c: int) -> void:
	if a < 0 or c < 0 or a >= SOCKETS or c >= SOCKETS or a == c:
		return
	var s := sockets[a]
	sockets[a] = sockets[c]
	sockets[c] = s
	var g: Variant = grid[a + 1]
	grid[a + 1] = grid[c + 1]
	grid[c + 1] = g
	var cl: Variant = claims[a + 1]
	claims[a + 1] = claims[c + 1]
	claims[c + 1] = cl
	changed.emit()


## The sockets set to `kinds` (socket 1 first), every slot empty, laid out afresh at the next sync (a new game; a save
## from before the bags).
func reset(kinds: Array) -> void:
	sockets.clear()
	for i in SOCKETS:
		var k := String(kinds[i]) if i < kinds.size() else ""
		sockets.append(k if is_bag(k) else "")
	grid = []
	claims = []
	_size_bags()
	loose.clear()
	_want.clear()
	_fresh = true
	_sig = ""
	_full_said = false
	changed.emit()


## A start with nothing (BareStart): the haversack alone.
func start_over() -> void:
	reset(start_sockets(true))


# --- following the pack -----------------------------------------------------------------------------------------

## What takes bag room: [{kind, count, state}], one a kind, in the pack's order (see the header's `what`).
static func contents_of(p: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if p == null or not is_instance_valid(p) or p.get("weapons") == null:
		return out
	var inv := InventoryState.from_player(p)
	var hb := Hotbar.find(p)
	var at := {}
	for e: Dictionary in inv.pack:
		var k := String(e.get("kind", ""))
		var n := int(e.get("count", 0))
		if k == "" or n <= 0 or (hb != null and _on_bar(p, hb, k)):
			continue
		if at.has(k):
			out[at[k]].count = int(out[at[k]].count) + n
		else:
			at[k] = out.size()
			out.append({"kind": k, "count": n, "state": (e.get("state", {}) as Dictionary).duplicate(true) if e.get("state", {}) is Dictionary else {}})
	if hb != null:
		# a weapon or a tool worn but kept off the bar is in the pack (InventoryScreen.pack_rows)
		for it: Dictionary in inv.worn.items:
			var k := String(it.kind)
			if at.has(k) or Hotbar.entry_for_kind(p, k).is_empty() or _on_bar(p, hb, k):
				continue
			at[k] = out.size()
			out.append({"kind": k, "count": 1 if k == "tomahawk" else int(it.get("count", 1)), "state": it.get("state", {})})
	# the garments carried, not worn (the core's kit; those the Tab screen's clothes list shows: ClothesSlots.owned)
	var tree: SceneTree = p.get_tree() if p.is_inside_tree() else null
	var br := SurvivalBridge.find(tree) if tree != null else null
	if br != null and br.core != null and br.player == p:
		var core := br.core
		var have := {}
		for st in SurvivalInventory._stacks(core):
			var id := String(st.id)
			if _garment(core, id) and SurvivalInventory.usable(st):
				have[id] = float(have.get(id, 0.0)) + float(st.qty)
		for w in core.state.worn:
			if have.has(String(w)):
				have[String(w)] = float(have[String(w)]) - 1.0
		for id: String in have:
			var n := floori(float(have[id]) + 0.0001)
			if n > 0:
				out.append({"kind": CLOTH + id, "count": n, "state": {}})
	return out


static var _garments := {}


## Whether the core item `id` is a garment with a clothes slot (ClothesSlots.owned's rule; kept, it is the data's).
static func _garment(core: SurvivalCore, id: String) -> bool:
	if not _garments.has(id):
		var it := core.data.item(id)
		_garments[id] = it.get("clothing", null) != null and String(it.get("cat", "")) == "clothing" and ClothesSlots.zone_of(core, id) != ""
	return bool(_garments[id])


## Whether the pack kind `k` is on the hotbar (its weapon, its tool, or the tool it stands in for: InventoryScreen._on_bar).
static func _on_bar(p: Node, hb: Hotbar, k: String) -> bool:
	var e := Hotbar.entry_for_kind(p, k)
	return not e.is_empty() and hb.slot_of(String(e.kind), String(e.id)) >= 0


## Follows the pack: what went leaves its slots (claimed), the loose goes in where there is room, what came is laid in.
## Nothing until the hotbar's start kit is placed (a new game). True when the layout changed.
func sync() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var hb := Hotbar.find(player)
	if hb != null and not hb.kit_placed:
		return false
	var rows := contents_of(player)
	var want := {}
	var order: Array[String] = []
	_states.clear()
	for e: Dictionary in rows:
		var k := String(e.kind)
		want[k] = int(e.count)
		order.append(k)
		_states[k] = e.get("state", {})
	_want = want
	var sig := str(want) + "|" + str(sockets)
	if sig == _sig and not _fresh:
		return false
	_sig = sig
	var before := str(grid) + str(loose)
	if _fresh:
		for b in grid.size():
			for i in (grid[b] as Array).size():
				grid[b][i] = {}
				claims[b][i] = ""
		loose.clear()
		_fresh = false
	_reconcile(want, order)
	var moved := before != str(grid) + str(loose)
	_after(moved)
	return moved


func _reconcile(want: Dictionary, order: Array[String]) -> void:
	# what went: from the loose first, then the smallest stacks
	var have := _laid()
	for k: String in have:
		var over := int(have[k]) - int(want.get(k, 0))
		if over > 0:
			_remove(k, over)
	# the loose in where there is room now, the oldest first
	var li := 0
	while li < loose.size():
		var e: Dictionary = loose[li]
		var left := _into_bags(String(e.kind), int(e.count))
		if left <= 0:
			loose.remove_at(li)
		else:
			e.count = left
			li += 1
	# what came: a kind with a claimed slot first (coming back), then the rest in the pack's order
	have = _laid()
	var claimed := {}
	for b in claims.size():
		for c: String in claims[b]:
			if c != "":
				claimed[c] = true
	for pass_i in 2:
		for k: String in order:
			var d := int(want[k]) - int(have.get(k, 0))
			if d <= 0 or claimed.has(k) != (pass_i == 0):
				continue
			var left2 := _into_bags(k, d)
			have[k] = int(want[k])
			_to_loose(k, left2)


## kind -> how many are laid (the slots and the loose).
func _laid() -> Dictionary:
	var out := {}
	for row: Array in grid:
		for e: Dictionary in row:
			if not e.is_empty():
				out[String(e.kind)] = int(out.get(String(e.kind), 0)) + int(e.count)
	for e: Dictionary in loose:
		out[String(e.kind)] = int(out.get(String(e.kind), 0)) + int(e.count)
	return out


## `n` of `k` gone: from the loose (the newest first), then the smallest stack (the later of equals); a slot emptied keeps
## a claim for its kind.
func _remove(k: String, n: int) -> void:
	for li in range(loose.size() - 1, -1, -1):
		if n <= 0:
			return
		if String(loose[li].kind) != k:
			continue
		var t := mini(n, int(loose[li].count))
		loose[li].count = int(loose[li].count) - t
		n -= t
		if int(loose[li].count) <= 0:
			loose.remove_at(li)
	while n > 0:
		var at := _smallest(k)
		if int(at[0]) < 0:
			return
		var e: Dictionary = grid[at[0]][at[1]]
		var t := mini(n, int(e.count))
		e.count = int(e.count) - t
		n -= t
		if int(e.count) <= 0:
			grid[at[0]][at[1]] = {}
			claims[at[0]][at[1]] = k


## The slot of `k`'s smallest stack (the later of equals), [-1, -1] none.
func _smallest(k: String) -> Array:
	var best := [-1, -1]
	var best_n := 1 << 30
	for b in grid.size():
		for i in (grid[b] as Array).size():
			var e: Dictionary = grid[b][i]
			if not e.is_empty() and String(e.kind) == k and int(e.count) <= best_n:
				best = [b, i]
				best_n = int(e.count)
	return best


func _loose_of(k: String) -> int:
	for li in range(loose.size() - 1, -1, -1):
		if String(loose[li].kind) == k:
			return li
	return -1


## The bags `k` goes in, in order: a fitting specialty bag, the haversack, the other bags (socket order).
func _bag_order(k: String) -> Array[int]:
	var out: Array[int] = []
	for b in range(1, bag_count()):
		if is_specialty(bag_kind(b)) and fits(bag_kind(b), k):
			out.append(b)
	out.append(0)
	for b in range(1, bag_count()):
		if bag_kind(b) != "" and not is_specialty(bag_kind(b)):
			out.append(b)
	return out


## The first empty slot that may hold `k` (not in bag `skip`), [-1, -1] none.
func _first_empty(k: String, skip := -1) -> Array:
	for b in _bag_order(k):
		if b == skip:
			continue
		for i in (grid[b] as Array).size():
			if (grid[b][i] as Dictionary).is_empty():
				return [b, i]
	return [-1, -1]


## Lays `n` of `k` into the bags: onto its stacks with room, its claimed slots, the first free slots (bag order). Returns
## how many found no room.
func _into_bags(k: String, n: int) -> int:
	var st := stack_of(k)
	var bags := _bag_order(k)
	for b in bags:
		for e: Dictionary in grid[b]:
			if n <= 0:
				return 0
			if not e.is_empty() and String(e.kind) == k and int(e.count) < st:
				var t := mini(n, st - int(e.count))
				e.count = int(e.count) + t
				n -= t
	for b in bags:
		for i in (grid[b] as Array).size():
			if n <= 0:
				return 0
			if String(claims[b][i]) == k and (grid[b][i] as Dictionary).is_empty():
				var t := mini(n, st)
				grid[b][i] = {"kind": k, "count": t}
				claims[b][i] = ""
				n -= t
	for b in bags:
		for i in (grid[b] as Array).size():
			if n <= 0:
				return 0
			if (grid[b][i] as Dictionary).is_empty():
				var t := mini(n, st)
				grid[b][i] = {"kind": k, "count": t}
				claims[b][i] = ""
				n -= t
	return maxi(n, 0)


## `n` of `k` ride loose: onto a loose stack of its kind with room, then new loose stacks.
func _to_loose(k: String, n: int) -> void:
	if n <= 0:
		return
	var st := stack_of(k)
	for e: Dictionary in loose:
		if String(e.kind) == k and int(e.count) < st:
			var t := mini(n, st - int(e.count))
			e.count = int(e.count) + t
			n -= t
			if n <= 0:
				return
	while n > 0:
		var t := mini(n, st)
		loose.append({"kind": k, "count": t})
		n -= t


## After a change: the signal, the "full" notice once per filling.
func _after(moved := true) -> void:
	if moved:
		changed.emit()
	if loose.is_empty():
		_full_said = false
	elif not _full_said:
		_full_said = true
		var it: Variant = player.get("interactor") if player != null else null
		if it is Object and (it as Object).has_method(&"notice"):
			(it as Object).call(&"notice", FULL_TEXT)
		full.emit()


## Each bag's rows at its size (a socket emptied: none; a bag bigger or smaller than its row: grown, or what no longer
## fits dropped, to be laid again).
func _size_bags() -> void:
	while grid.size() < bag_count():
		grid.append([])
	while claims.size() < bag_count():
		claims.append([])
	for b in bag_count():
		var k := bag_kind(b)
		var n := slots_of(k) if k != "" else 0
		var row: Array = grid[b]
		var crow: Array = claims[b]
		while row.size() < n:
			row.append({})
		while crow.size() < n:
			crow.append("")
		if row.size() > n:
			row.resize(n)
		if crow.size() > n:
			crow.resize(n)


func _valid(b: int, i: int) -> bool:
	return b >= 0 and b < grid.size() and i >= 0 and i < (grid[b] as Array).size()


static func _yes() -> Dictionary:
	return {"ok": true, "reason": ""}


static func _no(why: String) -> Dictionary:
	return {"ok": false, "reason": why}
