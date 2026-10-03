extends SceneTree
## The bags (PlayerBags, scripts/inventory/bags.gd; the owner 2026-10-03: "can we do the inventory similar to world of warcraft
## with the bags and etc?", then "WoW-style bags ... i just need you to do these"): the core, no windows yet, on the real level
## with the real player, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/inventory/test_bags.gd -- survival=on
##
##   data       bags.json: seven bags, the haversack 16 slots 4 wide; stack sizes (a log 1, flint 50, the rest 20); the
##              specialty rules (a hunting pouch takes flint, not venison; a game bag venison, not stone or a bag); names,
##              ItemInfo rows, a model for every bag's icon
##   start      a new game: the haversack and a linen satchel, laid out once the hotbar's kit is placed: every thing the
##              pack holds in a slot, none loose, the speed as ever; what is on the hotbar takes no room (the musket), the
##              felling axe taken off the bar takes a slot and gives it back on the bar again; a spare garment carried takes
##              one (the spare moccasins)
##   layout     a new kind to the first free slot; more of it tops its stack up, past a stack a new slot (flint 50 + 10);
##              a moved stack keeps its slot; a kind used up takes from its smallest stack, its slot emptied and claimed;
##              back again it goes to that slot; a claim never keeps a slot from a new thing
##   specialty  a game bag put on: a new game kind goes into it first, stone never (can_hold's reason), a move of stone
##              into it refused, venison moved in; split (into the game bag first) and swap (refused across the rule)
##   full       logs past every free slot ride loose: 4 % slower each, from 4 loose no sprint (the bridge's speed
##              multiplied), "Your bags are full." once per filling; place() swaps a loose log with a stack; room made
##              takes the loose in again, the speed comes back; filled again it is said again; a pickup (a fallen
##              fighter's things) when full still comes into the pack, loose
##   equip      unequip refused while a bag holds things; equip refused for a thing not a bag or a bag not had; an empty
##              bag comes off into a slot; a bag onto an empty one swaps them (the old one where the new one lay); all four
##              sockets taken: refused
##   save       the player part keeps the sockets, the slots and the loose (through JSON); a save from before the bags
##              loads with the haversack and a linen satchel and an automatic layout
##   captivity  the captors take the pack: the bags empty (their slots claimed), the worn bags stay in their sockets, none
##              loose; given back, everything goes back to the slot it was in
##   got        the workbench offers the five bags; a game bag made from rawhide and a cord; the blanket roll wants a wool
##              blanket in the kit not worn, then makes one (the blanket gone from the kit); a knapsack bought (the core's
##              trade_committed) comes into the pack; the traders' data sell it; fallen fighters sometimes leave bags
##   bar        the bag bar reads the bags: the pack's free slots and tooltip, a socket's bag and its free slots
##   bare       a start with nothing (start_over): the haversack alone
## Ends with "BAGS TEST OK (<n> checks)" or "BAGS TEST FAILED <f>/<n>: [...]".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var g: PlayerBags
var b: SurvivalBridge
var hb: Hotbar
var notices := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## How many of `kind` the pack holds (every entry).
func count(kind: String) -> int:
	return Campfire._pack_count(p, kind)


## As the pack's writers do: InventoryState, then the pack written back.
func add(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(p)
	inv.add(kind, n)
	p.inventory_pack = inv.pack.duplicate(true)
	g.sync()


func take(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(p)
	inv.take(kind, n)
	p.inventory_pack = inv.pack.duplicate(true)
	g.sync()


func set_count(kind: String, n: int) -> void:
	var out := []
	for e: Dictionary in p.inventory_pack:
		if String(e.get("kind", "")) != kind:
			out.append(e)
	if n > 0:
		out.append({"kind": kind, "count": n, "state": {}})
	p.inventory_pack = out
	g.sync()


## Where `kind` lies: [[b, i, count], ...].
func where(kind: String) -> Array:
	var out := []
	for bi in g.bag_count():
		for i in g.bag_size(bi):
			var e := g.slot(bi, i)
			if String(e.get("kind", "")) == kind:
				out.append([bi, i, int(e.count)])
	return out


## The sockets as "linen_satchel,,," (socket 1 first).
func socks() -> String:
	return ",".join(g.sockets)


## Every slot's kind and count, the loose and the sockets: the layout as a string.
func layout() -> String:
	return str(g.sockets) + str(g.grid) + str(g.loose)


func laid_total() -> int:
	var n := 0
	for bi in g.bag_count():
		for i in g.bag_size(bi):
			n += int(g.slot(bi, i).get("count", 0))
	for e: Dictionary in g.loose:
		n += int(e.count)
	return n


func contents_total() -> int:
	var n := 0
	for e: Dictionary in PlayerBags.contents_of(p):
		n += int(e.count)
	return n


func first_free(bi: int) -> int:
	for i in g.bag_size(bi):
		if g.slot(bi, i).is_empty():
			return i
	return -1


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(150)
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	b = SurvivalBridge.find(self)
	check(p != null and b != null, "the level has the player and the survival bridge (survival=on)")
	if p == null or b == null:
		_end()
		return
	p.ignore_mouse_capture = true
	# (a new game opens the character creator, which holds the game: closed, the hotbar's kit is placed after KIT_S)
	for cc in root.find_children("*", "CharacterCreator", true, false):
		if cc.has_method("close"):
			cc.close()
	await frames(int(Hotbar.KIT_S * Engine.physics_ticks_per_second) + 20)
	g = PlayerBags.find(p)
	hb = Hotbar.find(p)
	check(g != null and p.bags == g and hb != null and hb.kit_placed, "the player has bags (PlayerBags) and the hotbar's kit is placed")
	if g == null:
		_end()
		return
	var it := p.interactor
	if it != null:
		it.noticed.connect(func(text: String, _s: float) -> void:
			if text == PlayerBags.FULL_TEXT:
				notices += 1)
	_data()
	_start()
	_layout()
	_specialty()
	await _full()
	_equip()
	await _save()
	await _captivity()
	await _got()
	await _bar()
	_bare()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("BAGS TEST OK (%d checks)" % checks)
	else:
		print("BAGS TEST FAILED %d/%d: %s" % [fails.size(), checks, str(fails)])
	quit(0 if fails.is_empty() else 1)


# --- data ----------------------------------------------------------------------------------------------------

func _data() -> void:
	var kinds := PlayerBags.bag_kinds()
	check(kinds.size() == 7 and PlayerBags.slots_of("haversack") == 16 and PlayerBags.slots_of("linen_satchel") == 8
			and PlayerBags.slots_of("game_bag") == 16 and PlayerBags.slots_of("simples_bag") == 14 and g.bag_wide(0) == 4,
			"seven bags; the haversack 16 slots, 4 wide; satchel 8, game bag 16, simples bag 14 (%s)" % str(kinds))
	check(PlayerBags.stack_of("log") == 1 and PlayerBags.stack_of("flint") == 50 and PlayerBags.stack_of("venison") == 20
			and PlayerBags.stack_of("bison_robe") == 1 and PlayerBags.stack_of("knapsack") == 1 and PlayerBags.stack_of("cloth:item.cloth.moccasins") == 1,
			"stacks: a log 1, flint 50, venison 20, a buffalo robe 1, a bag 1, a garment 1")
	check(PlayerBags.fits("hunting_pouch", "flint") and PlayerBags.fits("hunting_pouch", "bar_lead") and not PlayerBags.fits("hunting_pouch", "venison")
			and PlayerBags.fits("game_bag", "venison") and PlayerBags.fits("game_bag", "wolf_pelt") and not PlayerBags.fits("game_bag", "stone")
			and not PlayerBags.fits("game_bag", "knapsack") and PlayerBags.fits("simples_bag", "seed_corn") and PlayerBags.fits("simples_bag", "willow_bark_tea")
			and not PlayerBags.fits("simples_bag", "log") and PlayerBags.fits("knapsack", "log") and PlayerBags.fits("haversack", "game_bag"),
			"specialty: a hunting pouch takes flint and lead, not venison; a game bag venison and pelts, not stone or a bag; a simples bag seed and teas, not a log; the general bags anything")
	var names_ok := true
	for k: String in kinds + ["haversack"]:
		names_ok = names_ok and InventoryState.NAMES.has(k) and BagModels.has(k)
	check(names_ok, "every bag has a name (InventoryState.NAMES) and a model for its icon (BagModels)")
	var meshes := true
	for k: String in kinds + ["haversack"]:
		var m := BagModels.build(k)
		meshes = meshes and m.find_children("*", "MeshInstance3D", true, false).size() >= 3
		m.free()
	check(meshes, "every bag's model is built (BagModels: ItemIcons draws the icon from it)")
	var info := ItemInfo.of("game_bag", p)
	var rows := str(info.rows)
	check(String(info.name) == "Game Bag" and rows.contains("16 slots") and rows.contains("only game") and rows.contains("bag sockets")
			and String(info.tag) == "Bag", "ItemInfo: a game bag's slots, what it holds, where it is worn (%s)" % rows)
	check(str(ItemInfo.of("knapsack", p).rows).contains("12 slots") and str(ItemInfo.of("knapsack", p).rows).contains("anything"),
			"ItemInfo: a knapsack 12 slots for anything")


# --- the start -----------------------------------------------------------------------------------------------

func _start() -> void:
	g.sync()
	check(socks() == "linen_satchel,,," and g.bag_kind(0) == "haversack" and g.bag_size(0) == 16 and g.bag_size(1) == 8
			and g.slots_total() == 24, "a new game: the haversack and a linen satchel in socket 1 (%s)" % socks())
	var used := 0
	for bi in g.bag_count():
		used += g.used_slots(bi)
	check(laid_total() == contents_total() and g.loose.is_empty() and is_equal_approx(g.speed_mult(), 1.0) and g.sprint_ok(),
			"everything the pack holds is laid in the bags, nothing loose, the speed as ever (%d of 24 slots used)" % used)
	print("    the start's bags: %d of %d slots used: %s" % [used, g.slots_total(), str(g.grid[0]) + str(g.grid[1])])
	check(where("musket").is_empty() and where("bow").is_empty() and where("felling_axe").is_empty(),
			"what is on the hotbar takes no room (the musket, the bow, the felling axe)")
	var ax := hb.slot_of(Hotbar.TOOL, "felling_axe")
	if ax >= 0:
		hb.clear(ax)
		g.sync()
		check(where("felling_axe").size() == 1, "the felling axe taken off the bar: in the pack, a slot")
		hb.assign(ax, Hotbar.make(Hotbar.TOOL, "felling_axe"))
		g.sync()
		check(where("felling_axe").is_empty(), "back on the bar: its slot given back")
	var c := b.core
	var spare := SurvivalInventory.count_usable(c, "item.cloth.moccasins") - float(c.state.worn.count("item.cloth.moccasins"))
	if spare >= 1.0:
		check(where("cloth:item.cloth.moccasins").size() == int(spare), "a spare garment carried takes a slot (the moccasins not worn)")
		var nm := g.kind_name("cloth:item.cloth.moccasins")
		check(nm == ClothesSlots.name_of(c, "item.cloth.moccasins") and not nm.begins_with("Cloth"), "named by the core: '%s'" % nm)


# --- the layout ----------------------------------------------------------------------------------------------

func _layout() -> void:
	# a known start: the pack down to the weapons' own things and the tools (the rest put away), the bags laid afresh
	var keep := []
	for e: Dictionary in p.inventory_pack:
		var k := String(e.get("kind", ""))
		if InventoryState._derived(k) or not Hotbar.entry_for_kind(p, k).is_empty():
			keep.append(e)
	p.inventory_pack = keep
	g.reset(["linen_satchel"])
	g.sync()
	var f0 := first_free(0)
	check(f0 >= 0 and f0 < 10 and g.used_slots(1) == 0, "laid afresh: the haversack's first %d slots used, the satchel empty" % f0)
	add("flint", 60)
	var fl := where("flint")
	check(fl.size() == 2 and fl[0] == [0, f0, 50] and int(fl[1][0]) == 0 and int(fl[1][2]) == 10,
			"60 flint: a stack of 50 in the haversack's first free slot, 10 in the next (%s)" % str(fl))
	add("flint", 5)
	fl = where("flint")
	check(fl.size() == 2 and int(fl[1][2]) == 15, "5 more flint top the small stack up (%s)" % str(fl))
	var small_at: int = fl[1][1]
	add("venison", 3)
	var v := where("venison")
	check(v.size() == 1 and int(v[0][0]) == 0, "venison: a new kind in the first free slot (%s)" % str(v))
	var last := g.bag_size(0) - 1
	if not g.slot(0, last).is_empty():
		take(String(g.slot(0, last).kind), int(g.slot(0, last).count))
	var mv := g.move(int(v[0][0]), int(v[0][1]), 0, last)
	check(bool(mv.ok) and where("venison") == [[0, last, 3]], "venison moved to the haversack's last slot")
	var was_v: int = v[0][1]
	add("jerky", 2)
	check(where("venison") == [[0, last, 3]] and where("jerky").size() == 1 and int(where("jerky")[0][1]) <= was_v,
			"something new takes a free slot; the moved venison keeps its slot (%s, %s)" % [str(where("jerky")), str(where("venison"))])
	take("flint", 1)
	fl = where("flint")
	check(fl.size() == 2 and int(fl[0][2]) == 50 and int(fl[1][2]) == 14, "a flint used: from the smallest stack (%s)" % str(fl))
	take("flint", 14)
	check(where("flint") == [[0, f0, 50]] and g.claim(0, small_at) == "flint", "used up: its slot empty and claimed for flint")
	add("flint", 3)
	fl = where("flint")
	check(fl.size() == 2 and fl[1] == [0, small_at, 3], "3 more flint (the stack full): back to the slot they left (%s)" % str(fl))
	take("flint", 3)
	add("acorns", 4)
	check(where("acorns") == [[0, small_at, 4]] and g.claim(0, small_at) == "",
			"a claim keeps no slot from a new thing: acorns in flint's old slot (%s)" % str(where("acorns")))


# --- specialty bags ------------------------------------------------------------------------------------------

func _specialty() -> void:
	add("game_bag", 1)
	check(where("game_bag").size() == 1, "a game bag in the pack takes a slot")
	var r := g.equip("game_bag")
	check(bool(r.ok) and int(r.socket) == 1 and g.sockets[1] == "game_bag" and g.bag_size(2) == 16 and count("game_bag") == 0
			and where("game_bag").is_empty(), "equipped: the game bag in socket 2, 16 slots, out of the pack (%s)" % str(r))
	add("venison", 5)
	check(where("venison").size() == 1 and int(where("venison")[0][2]) == 8 and int(where("venison")[0][0]) == 0,
			"more venison tops its stack up where it is")
	add("deer_hide", 2)
	check(where("deer_hide") == [[2, 0, 2]], "a new game kind goes into the game bag first (%s)" % str(where("deer_hide")))
	add("stone", 2)
	check(where("stone").size() == 1 and int(where("stone")[0][0]) != 2, "stone never goes in the game bag (%s)" % str(where("stone")))
	var ch := g.can_hold(2, "stone")
	check(not bool(ch.ok) and String(ch.reason).contains("holds only game"), "can_hold: '%s'" % ch.reason)
	var s0: Array = where("stone")[0]
	var m := g.move(int(s0[0]), int(s0[1]), 2, 5)
	check(not bool(m.ok) and where("stone")[0] == s0, "stone moved onto the game bag: refused, it stays (%s)" % m.reason)
	var v0: Array = where("venison")[0]
	m = g.move(int(v0[0]), int(v0[1]), 2, 3)
	check(bool(m.ok) and where("venison") == [[2, 3, 8]], "venison moved into the game bag")
	var sp := g.split(2, 3, 3)
	var vs := where("venison")
	check(bool(sp.ok) and vs.size() == 2 and int(vs[0][2]) + int(vs[1][2]) == 8 and int(vs[0][0]) == 2 and int(vs[1][0]) == 2,
			"split 3 off the venison: into the game bag's first free slot (%s)" % str(vs))
	var sw := g.swap(int(s0[0]), int(s0[1]), 2, 3)
	check(not bool(sw.ok), "swap stone with venison in the game bag: refused (%s)" % sw.reason)
	var j0: Array = where("jerky")[0]
	sw = g.swap(int(s0[0]), int(s0[1]), int(j0[0]), int(j0[1]))
	check(bool(sw.ok) and where("stone")[0].slice(0, 2) == j0.slice(0, 2) and where("jerky")[0].slice(0, 2) == s0.slice(0, 2),
			"swap stone and jerky in the haversack")


# --- full bags -----------------------------------------------------------------------------------------------

func _full() -> void:
	set_count("log", 0)
	var room := g.free_for("log")
	check(g.free_for("log") < g.free_total(), "a log fits the general bags only (%d of %d free slots)" % [room, g.free_total()])
	var said := notices
	add("log", room + 5)
	check(g.loose_slots() == 5 and where("log").size() == room and count("log") == room + 5,
			"%d logs: %d in the bags, 5 loose (all in the pack)" % [room + 5, room])
	check(is_equal_approx(g.speed_mult(), 0.8) and not g.sprint_ok(), "5 loose: 20%% slower, no sprint (x%.2f)" % g.speed_mult())
	check(notices == said + 1, "\"Your bags are full.\" said once (%d)" % (notices - said))
	add("log", 1)
	check(g.loose_slots() == 6 and notices == said + 1, "a 6th loose: not said again")
	await process_frame
	await process_frame
	var core_mult := float(b.core.get_modifiers().get("move_speed_mult", 1.0))
	check(absf(p.survival_speed_mult - core_mult * g.speed_mult()) < 0.01 and not p.sprint_allowed,
			"the bridge's speed has the bags' in (x%.2f = %.2f x %.2f), no sprint" % [p.survival_speed_mult, core_mult, g.speed_mult()])
	var hud: HudClassicMap = current_scene.find_child("HudClassicMap", true, false) as HudClassicMap
	if hud != null and hud.chat != null:
		check(hud.chat.last_text().contains(PlayerBags.FULL_TEXT) or str(hud.chat.lines).contains(PlayerBags.FULL_TEXT),
				"the chat log has the line")
	# a loose log put onto the stone's slot: they change places
	var s0: Array = where("stone")[0]
	var pl := g.place(0, int(s0[0]), int(s0[1]))
	check(bool(pl.ok) and where("stone").is_empty() and String(g.slot(int(s0[0]), int(s0[1])).kind) == "log"
			and String(g.loose[0].kind) == "stone", "place: a loose log onto the stone's slot, the stone rides loose in its place")
	pl = g.place(0)
	check(not bool(pl.ok) and g.loose_slots() == 6, "the stone put away: no room for it ('%s')" % pl.reason)
	take("log", 7)
	check(g.loose.is_empty() and where("stone").size() == 1 and is_equal_approx(g.speed_mult(), 1.0) and g.sprint_ok(),
			"7 logs dropped: the loose logs first, the stone into a freed slot, nothing loose, the speed back")
	await process_frame
	await process_frame
	check(p.sprint_allowed == bool(b.core.get_modifiers().get("sprint_allowed", true)), "the sprint back")
	add("log", g.free_for("log") + 1)
	check(g.loose_slots() == 1 and notices == said + 2 and g.sprint_ok() and is_equal_approx(g.speed_mult(), 0.96),
			"filled again: said again; 1 loose: 4%% slower, the sprint kept")
	# a pickup when full: a fallen fighter's things
	set_count("hazelnuts", 0)
	var l := NpcLoot.new()
	l.items = [{"kind": "hazelnuts", "count": 5}]
	current_scene.add_child(l)
	l.interact(p)
	g.sync()
	var lz := g.loose.filter(func(e: Dictionary) -> bool: return String(e.kind) == "hazelnuts")
	check(count("hazelnuts") == 5 and lz.size() == 1 and int(lz[0].count) == 5 and g.loose_slots() == 2,
			"a pickup when full: into the pack all the same, riding loose")
	set_count("hazelnuts", 0)
	set_count("log", 0)
	check(g.loose.is_empty(), "the logs and the nuts gone: nothing loose")


# --- equip and unequip ---------------------------------------------------------------------------------------

func _equip() -> void:
	var r := g.unequip(1)
	check(not bool(r.ok) and String(r.reason).begins_with("Empty the game bag"), "unequip a bag with things in it: refused ('%s')" % r.reason)
	r = g.equip("stone")
	check(not bool(r.ok) and String(r.reason).contains("not a bag"), "equip stone: '%s'" % r.reason)
	set_count("knapsack", 0)
	r = g.equip("knapsack")
	check(not bool(r.ok) and String(r.reason).contains("no knapsack"), "equip a knapsack not had: '%s'" % r.reason)
	set_count("venison", 0)
	set_count("deer_hide", 0)
	check(g.used_slots(2) == 0, "the game bag emptied")
	r = g.unequip(1)
	var gb := where("game_bag")
	check(bool(r.ok) and g.sockets[1] == "" and g.bag_size(2) == 0 and count("game_bag") == 1 and gb.size() == 1,
			"the empty game bag off: into the pack, a slot (%s)" % str(gb))
	r = g.equip("game_bag", 1, int(gb[0][0]), int(gb[0][1]))
	check(bool(r.ok) and g.sockets[1] == "game_bag", "on again from its slot")
	add("knapsack", 1)
	var kn: Array = where("knapsack")[0]
	r = g.equip("knapsack", 1, int(kn[0]), int(kn[1]))
	check(bool(r.ok) and g.sockets[1] == "knapsack" and g.bag_size(2) == 12 and count("game_bag") == 1 and count("knapsack") == 0
			and where("game_bag") == [[kn[0], kn[1], 1]], "a knapsack onto the empty game bag: they swap, the game bag where the knapsack lay")
	add("portmanteau", 1)
	add("simples_bag", 1)
	check(bool(g.equip("portmanteau").ok) and bool(g.equip("game_bag").ok) and socks() == "linen_satchel,knapsack,portmanteau,game_bag",
			"four sockets filled (%s)" % socks())
	r = g.equip("simples_bag")
	check(not bool(r.ok) and String(r.reason).begins_with("Every bag socket"), "a fifth bag: '%s'" % r.reason)
	var j0: Array = where("jerky")[0]
	check(bool(g.move(int(j0[0]), int(j0[1]), 1, 0).ok), "the jerky moved into the satchel")
	r = g.equip("simples_bag", 0)
	check(not bool(r.ok) and String(r.reason).begins_with("Empty the linen satchel"), "onto the satchel with things in it: '%s'" % r.reason)
	add("flint", 10)
	check(g.sockets.has("game_bag") and where("flint").all(func(w: Array) -> bool: return g.bag_kind(int(w[0])) != "game_bag"),
			"flint never in the game bag")


# --- the save ------------------------------------------------------------------------------------------------

func _save() -> void:
	add("log", g.free_for("log") + 2)
	await frames(2)
	var before := layout()
	check(g.loose_slots() == 2, "two logs loose before the save")
	var d: Dictionary = JSON.parse_string(JSON.stringify(SaveParts.plain(SaveParts.save_player(current_scene))))
	check(d.has("bags") and (d.bags as Dictionary).has("grid"), "the player part has the bags")
	g.swap_sockets(1, 2)
	set_count("log", 0)
	var v: Array = where("flint")[0]
	g.move(int(v[0]), int(v[1]), 0, g.bag_size(0) - 1)
	check(layout() != before, "changed after the save")
	SaveParts.load_player(current_scene, d)
	await frames(4)
	g.sync()
	check(layout() == before, "loaded: the sockets, the slots and the loose as they were")
	var old := d.duplicate(true)
	old.erase("bags")
	SaveParts.load_player(current_scene, old)
	await frames(4)
	g.sync()
	check(socks() == "linen_satchel,,," and laid_total() == contents_total(),
			"a save from before the bags: the haversack and a linen satchel, everything laid out (%d loose)" % g.loose_slots())
	SaveParts.load_player(current_scene, d)
	await frames(4)
	g.sync()
	set_count("log", 0)
	check(g.loose.is_empty() and g.sockets[1] == "knapsack", "the save again, the logs dropped")


# --- captivity -----------------------------------------------------------------------------------------------

func _captivity() -> void:
	var before := {}
	for bi in g.bag_count():
		for i in g.bag_size(bi):
			if not g.slot(bi, i).is_empty():
				before["%d:%d" % [bi, i]] = String(g.slot(bi, i).kind)
	var sockets_before := socks()
	var c := Captivity.install(current_scene)
	check(c.begin(p, null, {"take": ["pack"], "notice": ""}), "taken captive: the captors take the pack")
	await frames(3)
	g.sync()
	var left := 0
	var claimed := 0
	for k: String in before:
		var at := k.split(":")
		var e := g.slot(int(at[0]), int(at[1]))
		if not e.is_empty():
			left += 1
		elif g.claim(int(at[0]), int(at[1])) == before[k]:
			claimed += 1
	check(socks() == sockets_before and g.loose.is_empty(), "the worn bags stay in their sockets; nothing loose (%s)" % socks())
	print("    after the strip: %d slots still hold something (the weapons' own, the torches), %d emptied and claimed" % [left, claimed])
	check(claimed > 0 and claimed + left == before.size(), "the pack's things gone: their slots empty and claimed (%d)" % claimed)
	c.end()
	await frames(3)
	g.sync()
	var same := 0
	for k: String in before:
		var at := k.split(":")
		if String(g.slot(int(at[0]), int(at[1])).get("kind", "")) == before[k]:
			same += 1
	check(same == before.size() and g.loose.is_empty(), "given back: every stack in the slot it was in (%d of %d)" % [same, before.size()])


# --- how bags are got ----------------------------------------------------------------------------------------

func _got() -> void:
	var st := CampStation.new()
	st.kind = "workbench"
	current_scene.add_child(st)
	st.global_position = p.global_position + p.global_basis.z * -1.2
	var ids := st.menu_rows(p).map(func(r: Dictionary) -> String: return String(r.id))
	check(ids.has("game_bag") and ids.has("hunting_pouch") and ids.has("simples_bag") and ids.has("knapsack") and ids.has("blanket_roll"),
			"the workbench offers the five bags")
	set_count("flint_knife", 1)
	set_count("rawhide", 1)
	set_count("cordage", 2)
	set_count("game_bag", 0)
	var row := {}
	for r: Dictionary in st.menu_rows(p):
		if String(r.id) == "game_bag":
			row = r
	check(bool(row.get("ok", false)) and String(row.get("detail", "")).contains("16 slots"), "the game bag's row: '%s'" % row.get("detail", ""))
	var ok := st.make(p, "game_bag")
	await _wait_work()
	check(ok and count("game_bag") == 1 and count("rawhide") == 0 and count("cordage") == 1, "a game bag made from rawhide and a cord")
	var core := b.core
	SurvivalInventory.remove(core, "item.trade.blanket", SurvivalInventory.count(core, "item.trade.blanket"))
	for r: Dictionary in st.menu_rows(p):
		if String(r.id) == "blanket_roll":
			row = r
	check(not bool(row.ok) and String(row.detail).contains("wool blanket"), "the blanket roll without a blanket: '%s'" % row.detail)
	SurvivalInventory.add(core, "item.trade.blanket", 1.0)
	set_count("blanket_roll", 0)
	ok = st.make(p, "blanket_roll")
	await _wait_work()
	check(ok and count("blanket_roll") == 1 and SurvivalInventory.count(core, "item.trade.blanket") < 0.001 and count("cordage") == 0,
			"a blanket roll: the kit's wool blanket and a cord")
	st.queue_free()
	# bought: the knapsack out of the core's kit into the pack when a trade is done
	set_count("knapsack", 0)
	SurvivalInventory.add(core, "item.bag.knapsack", 1.0)
	core._on_trade_committed("tr.test", {})
	check(count("knapsack") == 1 and SurvivalInventory.count(core, "item.bag.knapsack") < 0.001, "a knapsack bought comes into the pack")
	var eco: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/survival/economy.json"))
	var sells := {}
	for m: Dictionary in eco.markets:
		sells[String(m.id)] = m.sells
	check((sells["mkt.fort_sutler"] as Array).has("item.bag.knapsack") and (sells["mkt.visiting_trader"] as Array).has("item.bag.portmanteau")
			and SurvivalTrade.tradeable(core, "item.bag.knapsack"), "the sutler sells the knapsack, the visiting trader the portmanteau")
	# a fallen fighter's things
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 0
	var pouch := 0
	for i in 400:
		n += PlayerBags.loot_for("french_marine", rng).size()
		for e: Dictionary in PlayerBags.loot_for("canadian_militia", rng):
			if String(e.kind) == "hunting_pouch":
				pouch += 1
	check(n > 60 and n < 140 and pouch > 80 and pouch < 160 and PlayerBags.loot_for("sky_crew", rng).is_empty(),
			"fallen fighters: a marine's knapsack about one in four (%d/400), a Canadian's hunting pouch (%d/400), none for others" % [n, pouch])


func _wait_work(limit := 60.0) -> void:
	var t0 := Time.get_ticks_msec()
	await frames(4)
	while (b.work.working or p.kneeling != null) and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await process_frame
	await frames(4)


# --- the bag bar ---------------------------------------------------------------------------------------------

func _bar() -> void:
	var bar := ClassicBagBar.new()
	root.add_child(bar)
	await process_frame
	g.sync()
	bar.refresh(p)
	var sock1: ClassicMicroMenu.MicroButton = null
	var sock4: ClassicMicroMenu.MicroButton = null
	for btn: ClassicMicroMenu.MicroButton in bar.buttons:
		if btn.id == "bag_1":
			sock1 = btn
		if btn.id == "bag_4":
			sock4 = btn
	check(bar.pack.count == str(g.free_total()) and bar.pack.tooltip_text.begins_with("Pack  (%s)" % BagWindows.key_label()) and bar.pack.tooltip_text.contains("Haversack"),
			"the bag bar's pack: the free slots (%s) and the haversack in its tooltip" % bar.pack.count)
	check(sock1 != null and sock1.tooltip_text.begins_with("Linen Satchel") and sock1.count == str(g.free_slots(1)) and not sock1.later,
			"bag 1 (beside the pack): the linen satchel and its free slots ('%s')" % (sock1.tooltip_text.replace("\n", " / ") if sock1 else ""))
	check(sock4 != null and sock4.tooltip_text.begins_with(g.bag_name(4)) and sock4.tooltip_text.contains("only game"),
			"bag 4: the game bag, only game ('%s')" % (sock4.tooltip_text.replace("\n", " / ") if sock4 else ""))
	add("log", g.free_for("log") + 3)
	bar.refresh(p)
	check(bar.pack.count == "+3" and bar.pack.tooltip_text.contains("3 things loose"), "full: '+3' on the pack, the loose in its tooltip")
	set_count("log", 0)
	bar.queue_free()


# --- a start with nothing ------------------------------------------------------------------------------------

func _bare() -> void:
	g.start_over()
	g.sync()
	check(socks() == ",,," and g.slots_total() == 16 and laid_total() == contents_total(),
			"a start with nothing: the haversack alone (%d loose)" % g.loose_slots())
