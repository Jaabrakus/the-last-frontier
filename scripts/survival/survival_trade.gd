class_name SurvivalTrade
extends RefCounted
## The one trade specification (survival_gdd.md 11.4-11.6; redesign_economy.md 6.2 and 6.8): a versioned trade session
## between two parties that both confirm and the authority commits atomically. The same code serves NPC barter now and
## player-to-player trade later: in single-player the core is the authority, in co-op the host, online the server.
##
##   open(a, b) -> set_lines(tr, party, lines) -> [the NPC evaluates and confirms or counter-offers] -> confirm(tr, party,
##   version) -> commit (all removals, then all additions, obligations, ledger, standing and trust, trade_committed)
##
## Parties: "pl.<n>" (players: the local one is SurvivalState.player_id; guest players for tests and co-op later live in
## SurvivalState.players with their own inventory and coin) and NPC individual ids ("npc.fort.sutler").
## Lines: {kind: "item", uid or item_id, qty} | {kind: "coin", pence} | {kind: "service", service: "labour" | "lesson" |
## "loan", terms, due} | {kind: "promise", owes: {item_id: qty} or {pence: n}, due}.
## Offered goods and coin are held in escrow while the session is open (nobody can eat, wear, craft with or offer them
## elsewhere); a cancel returns them. Valuations are pure functions of world and player state computed on the authority
## (no random draws); a client sees cues, and numbers only from Adept Trade or with the ledger toggle.
## Every record (sessions, the item ledger, obligations, NPC stock, want quotas, patience) is WORLD state; trust is the
## player's (SurvivalState.players[pid].trust).
##
## Session lifecycle (fix round 1): the authority cancels an open session (escrow returned) when a party is no longer
## present (moved away, asleep, senseless, dead, or an NPC's schedule block ends), when the game day turns, and after
## SESSION_IDLE_MIN game minutes without an edit; check_sessions() runs after every simulation step and every context
## change. A save cancels open sessions too, except a persistent-world save that keeps them with their escrow
## (SurvivalSave.to_document keep_trades). A garment being worn is never escrowed: take it off first.

const LINE_KINDS := ["item", "coin", "service", "promise"]
## Line services live now; "guide" is an M4 service (GDD 11.6) and is refused until it has a value and a fulfilment.
const SERVICES := ["labour", "lesson", "loan"]
const LEDGER_CAP := 200
## A promise is worth less than goods in hand [D].
const PROMISE_VALUE_FRAC := 0.8
## Labour valued in rv per game hour when the data does not say (economy.json reference_value.services) [D].
const LABOUR_D_PER_H := 7.0
## A lesson ask's labour is due within this many game days [D].
const LABOUR_DUE_DAYS := 3.0
## An agreed lesson not yet given stays open this long, so it can be resumed at the next meeting [D].
const LESSON_DUE_DAYS := 3.0
## An open trade window left without an edit this long is closed by the authority [D].
const SESSION_IDLE_MIN := 120.0
## First refusal on prime pelts (the trader's lesson ask): kept by bringing him a pelt within this many game days [D].
const FIRST_REFUSAL_DAYS := 12.0
## A favour asked for a lesson is this many game hours of the mentor's chores [D].
const FAVOUR_HOURS := 2.0


static func _t(core: SurvivalCore) -> Dictionary:
	var w := core.state.world
	if not w.has("trade"):
		w["trade"] = {}
	var t: Dictionary = w.trade
	for k in ["sessions", "patience", "wants", "npc_stock", "restock"]:
		if not t.has(k):
			t[k] = {}
	if not t.has("ledger"):
		t["ledger"] = []
	return t


static func _obs(core: SurvivalCore) -> Dictionary:
	var w := core.state.world
	if not w.has("obligations"):
		w["obligations"] = {}
	return w.obligations


static func _next_id(core: SurvivalCore, prefix: String) -> String:
	var w := core.state.world
	if not w.has("ids"):
		w["ids"] = {}
	var n := int(SurvivalUtil.num(w.ids.get(prefix), 1.0))
	w.ids[prefix] = n + 1
	return "%s.%d" % [prefix, n]


static func barter_cfg(core: SurvivalCore) -> Dictionary:
	return core.data.section("economy", "barter")


# ---------------------------------------------------------------- parties
static func is_player(party: String) -> bool:
	return party.begins_with("pl.")


static func is_local(core: SurvivalCore, party: String) -> bool:
	return party == core.state.player_id


## A guest player record (co-op later; tests now): its own inventory, coin, location and trust.
static func add_guest_player(core: SurvivalCore, pid: String, opts: Dictionary = {}) -> Dictionary:
	var rec := {"id": pid, "guest": true, "inventory": [], "money_d": int(SurvivalUtil.num(opts.get("money_d"), 0.0)),
			"location": str(opts.get("location", core.state.context.get("location", ""))), "trust": {}, "knowledge": {},
			"learning": {}, "habits": [], "counters": {}, "wear": {}}
	core.state.players[pid] = rec
	for pair in SurvivalUtil.arr(opts.get("items")):
		SurvivalInventory.add_to(core, rec.inventory, str(pair[0]), SurvivalUtil.num(pair[1], 1.0), SurvivalUtil.dict(pair[2]) if pair.size() > 2 else {})
	return rec


static func _stacks_of_party(core: SurvivalCore, party: String) -> Array:
	if is_local(core, party):
		return core.state.inventory
	return SurvivalUtil.arr(SurvivalUtil.dict(core.state.players.get(party)).get("inventory"))


static func money_of(core: SurvivalCore, party: String) -> int:
	if is_local(core, party):
		return SurvivalEconomy.money(core)
	return int(SurvivalUtil.num(SurvivalUtil.dict(core.state.players.get(party)).get("money_d"), 0.0))


static func _add_money(core: SurvivalCore, party: String, d: float) -> void:
	if is_local(core, party):
		SurvivalEconomy._add_money(core, d)
	elif core.state.players.has(party):
		core.state.players[party]["money_d"] = int(round(SurvivalUtil.num(core.state.players[party].get("money_d"), 0.0) + d))


## The trade behaviour of an NPC: its archetype's trade_behaviours row with the individual's `trade` overrides.
static func behaviour(core: SurvivalCore, npc: String) -> Dictionary:
	var arch := SurvivalNpcs.archetype_of(core, npc)
	var tb := SurvivalUtil.dict(core.data.trade_behaviours.get(str(arch.get("trade_behaviour", "")))).duplicate(true)
	var ov := SurvivalUtil.dict(SurvivalUtil.dict(core.data.individuals.get(npc)).get("trade"))
	for k in ov.keys():
		tb[k] = ov[k]
	return tb


static func market_of(core: SurvivalCore, npc: String) -> String:
	return str(SurvivalNpcs.archetype_of(core, npc).get("market", ""))


static func faction_of(core: SurvivalCore, npc: String) -> String:
	var m := market_of(core, npc)
	if m != "":
		return str(core.data.market(m).get("faction", ""))
	return str(SurvivalNpcs.archetype_of(core, npc).get("faction", "faction.none"))


static func trades(core: SurvivalCore, npc: String) -> bool:
	var tb := behaviour(core, npc)
	if tb.is_empty() or str(tb.get("value_out", "")) == "none":
		return false
	return not (typeof(tb.get("trades")) == TYPE_BOOL and not bool(tb.trades))


## Is a party here, awake and able to trade now? An NPC must be at the player's location on its schedule (and its market
## open, within its hours); a player must be alive and awake (a guest at the same location).
static func partner_present(core: SurvivalCore, party: String) -> bool:
	if is_player(party):
		if is_local(core, party):
			return not core.is_dead() and not core.state.asleep and not core.is_passed_out()
		var g := SurvivalUtil.dict(core.state.players.get(party))
		return not g.is_empty() and str(g.get("location", "")) == str(core.state.context.get("location", ""))
	if core.data.individuals.get(party) == null:
		return false
	var w := SurvivalNpcs.where(core, party)
	if not bool(w.present) or str(w.activity) == "sleep" or str(w.location) != str(core.state.context.get("location", "")):
		return false
	var m := market_of(core, party)
	if m != "" and not core.data.market(m).is_empty():
		if not SurvivalEconomy.is_open(core, m):
			return false
		var hrs := SurvivalUtil.arr(core.data.market(m).get("hours"))
		if hrs.size() == 2:
			var h := SurvivalClock.hour(core)
			if h < SurvivalUtil.num(hrs[0]) or h >= SurvivalUtil.num(hrs[1]):
				return false
	return true


## Game minutes a party will stay available here from now (an NPC by its schedule and its market's hours; a player
## indefinitely): a lesson or a timed trade must fit inside it.
static func present_minutes(core: SurvivalCore, party: String) -> float:
	if not partner_present(core, party):
		return 0.0
	if is_player(party):
		return 1.0e9
	var mins := SurvivalNpcs.minutes_until_leaves(core, party, str(core.state.context.get("location", "")))
	var m := market_of(core, party)
	if m != "" and not core.data.market(m).is_empty():
		var hrs := SurvivalUtil.arr(core.data.market(m).get("hours"))
		if hrs.size() == 2:
			mins = minf(mins, (SurvivalUtil.num(hrs[1]) - SurvivalClock.hour(core)) * 60.0)
	return maxf(0.0, mins)


## Partners present at some time today (the local cap compares what another partner offers that day).
static func present_today(core: SurvivalCore, npc: String) -> bool:
	var m := market_of(core, npc)
	if m != "" and not core.data.market(m).is_empty():
		return SurvivalEconomy.is_open(core, m)
	return SurvivalNpcs.present_today(core, npc)


static func partners(core: SurvivalCore) -> Array:
	var out := []
	for id in SurvivalUtil.sorted_ids(core.data.individuals):
		if trades(core, str(id)):
			out.append(str(id))
	return out


static func partners_here(core: SurvivalCore) -> Array:
	var out := []
	for id in partners(core):
		if partner_present(core, str(id)):
			out.append(id)
	return out


# ---------------------------------------------------------------- NPC stock and want quotas (world state)
static func npc_stock(core: SurvivalCore, npc: String) -> Dictionary:
	var m := market_of(core, npc)
	if m != "" and not core.data.market(m).is_empty():
		var st := SurvivalUtil.dict(core.state.economy.get("stock"))
		if not st.has(m):
			SurvivalEconomy.restock(core, m)
		return core.state.economy.stock[m]
	var t := _t(core)
	if not t.npc_stock.has(npc):
		t.npc_stock[npc] = SurvivalUtil.dict(behaviour(core, npc).get("stock_per_month")).duplicate()
	return t.npc_stock[npc]


static func _stock_add(core: SurvivalCore, npc: String, item: String, qty: float) -> void:
	var st := npc_stock(core, npc)
	st[item] = maxf(0.0, SurvivalUtil.num(st.get(item), 0.0) + qty)


## The partner's period for want quotas: one visit for a visiting partner, one game month for a resident one.
static func period_key(core: SurvivalCore, npc: String) -> String:
	var m := market_of(core, npc)
	var op = core.data.market(m).get("open") if m != "" else null
	if typeof(op) == TYPE_ARRAY:
		for ev in op:
			if SurvivalClock.event_active(core, str(ev)):
				return "%s|%d" % [str(ev), SurvivalClock.year(core)]
	return "%d|%s" % [SurvivalClock.year(core), SurvivalClock.month_id(core)]


static func _taken(core: SurvivalCore, npc: String, item: String) -> float:
	var w := SurvivalUtil.dict(SurvivalUtil.dict(_t(core).wants.get(npc)).get(period_key(core, npc)))
	return SurvivalUtil.num(w.get(item), 0.0)


static func _record_taken(core: SurvivalCore, npc: String, item: String, qty: float) -> void:
	var t := _t(core)
	if not t.wants.has(npc):
		t.wants[npc] = {}
	var pk := period_key(core, npc)
	# Keep only the current period's quotas.
	for k in t.wants[npc].keys():
		if str(k) != pk:
			t.wants[npc].erase(k)
	if not t.wants[npc].has(pk):
		t.wants[npc][pk] = {}
	t.wants[npc][pk][item] = SurvivalUtil.num(t.wants[npc][pk].get(item), 0.0) + qty


static func _matches(core: SurvivalCore, row: Dictionary, item: String) -> bool:
	if SurvivalUtil.arr(row.get("items")).has(item):
		return true
	return SurvivalUtil.arr(row.get("cats")).has(core.data.item_cat(item))


static func _in_months(core: SurvivalCore, row: Dictionary) -> bool:
	var ms := SurvivalUtil.arr(row.get("months"))
	return ms.is_empty() or ms.has(SurvivalClock.month_id(core))


## The first wants row for an item this month, or {}.
static func want_row(core: SurvivalCore, npc: String, item: String) -> Dictionary:
	for row in SurvivalUtil.arr(behaviour(core, npc).get("wants")):
		if _matches(core, row, item) and _in_months(core, row):
			return row
	return {}


## The want tier now: the row's tier, stepping down one tier for each quota met this period ("need falls as it is met").
static func want_tier(core: SurvivalCore, npc: String, item: String) -> String:
	var row := want_row(core, npc, item)
	if row.is_empty():
		return "no_use"
	var tier := str(row.get("tier", "uses"))
	if tier == "resells":
		return tier
	var order := SurvivalUtil.arr(barter_cfg(core).get("want_order"))
	var q := SurvivalUtil.num(row.get("quota"), 0.0)
	if q > 0.0:
		var steps := int(floorf(_taken(core, npc, item) / q + 0.0001))
		tier = str(order[maxi(0, order.find(tier) - steps)])
	return tier


static func keep_row(core: SurvivalCore, npc: String, item: String) -> Dictionary:
	var tb := behaviour(core, npc)
	if SurvivalUtil.arr(tb.get("never_offers")).has(item):
		return {}
	for row in SurvivalUtil.arr(tb.get("keeps")):
		if not _in_months(core, row):
			continue
		if _matches(core, row, item):
			return row
		var fm := str(row.get("from_market", ""))
		if fm != "" and SurvivalUtil.arr(core.data.market(fm).get("sells")).has(item) and not SurvivalUtil.dict(row).has("items"):
			return row
	return {}


# ---------------------------------------------------------------- valuation (authority only; no draws)
static func rv(core: SurvivalCore, item: String) -> float:
	return SurvivalUtil.num(core.data.good(item).get("cash_retail_d"), 0.0)


static func _tier_mult(core: SurvivalCore, tiers_key: String, tier: String) -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(barter_cfg(core).get(tiers_key)).get(tier), 1.0)


## Quality of a stack for an NPC: pelts and skins by grade, prime, condition and handling; other goods by their standard
## (meta.quality) and any value multiplier; spoiled goods at half.
static func stack_q(core: SurvivalCore, st: Dictionary) -> float:
	var cat := core.data.item_cat(str(st.get("id", "")))
	var m := SurvivalUtil.dict(st.get("meta"))
	if cat == "pelt" or cat == "skin":
		return SurvivalEconomy.stack_value_factor(core, st)
	var q := SurvivalUtil.num(m.get("quality"), 1.0) * SurvivalUtil.num(m.get("value_mult"), 1.0)
	if bool(m.get("spoiled", false)) or bool(m.get("tainted", false)):
		q *= 0.5
	return q


## What one unit of an NPC's offer costs before its terms, in pence; -1 when it does not offer the good (not kept, never
## offered, out of season or out of stock). This is also the base price the local cap compares.
static func unit_out(core: SurvivalCore, npc: String, item: String, need_stock: bool = true) -> float:
	var row := keep_row(core, npc, item)
	if row.is_empty():
		return -1.0
	if need_stock and SurvivalUtil.num(npc_stock(core, npc).get(item), 0.0) <= 0.0001:
		return -1.0
	var tb := behaviour(core, npc)
	var r := rv(core, item)
	match str(tb.get("value_out", "rv_k")):
		"tariff":
			var b := SurvivalUtil.dict(core.data.good(item).get("barter"))
			if b.is_empty():
				return -1.0
			return SurvivalUtil.num(b.get("beaver"), 0.0) * SurvivalEconomy.beaver_d(core)
		"cash_price":
			var m := market_of(core, npc)
			if not SurvivalEconomy.sold_now(core, m, item):
				return -1.0
			var k := _tier_mult(core, "keep_tiers", str(row.get("tier", "enough")))
			var p := r * SurvivalUtil.num(core.data.market(m).get("markup"), 1.0) * SurvivalEconomy.season_mult(core, item) \
					* SurvivalEconomy.scarcity(core, m, item) * k
			return _clamp_out(core, p, r)
		_:
			var k2 := _tier_mult(core, "keep_tiers", str(row.get("tier", "enough")))
			return _clamp_out(core, r * k2 * SurvivalUtil.num(tb.get("markup"), 1.0), r)


static func _clamp_out(core: SurvivalCore, p: float, r: float) -> float:
	var c := SurvivalUtil.pair(barter_cfg(core).get("value_out_clamp"), 1.0)
	return clampf(p, c.x * r, c.y * r) if r > 0.0 else p


## The local cap on a buyer's want: 0.7 x the lowest base price at which any other partner present today offers the
## good, as a multiple of its rv (INF when nobody else offers it).
static func local_cap(core: SurvivalCore, buyer: String, item: String) -> float:
	var r := rv(core, item)
	if r <= 0.0:
		return INF
	var lc := SurvivalUtil.dict(barter_cfg(core).get("local_cap"))
	var best := INF
	for p in partners(core):
		if str(p) == buyer or not present_today(core, str(p)):
			continue
		var u := unit_out(core, str(p), item)
		if u > 0.0:
			best = minf(best, u)
	if best == INF:
		return INF
	return SurvivalUtil.num(lc.get("mult"), 0.7) * best / r


## What an NPC gives for one unit of a player's stack, in pence: {v, tier, reason}.
static func unit_in(core: SurvivalCore, npc: String, st: Dictionary) -> Dictionary:
	var item := str(st.get("id", ""))
	var tier := want_tier(core, npc, item)
	var row := want_row(core, npc, item)
	var out := {"v": 0.0, "tier": tier, "reason": str(row.get("reason", ""))}
	if bool(SurvivalUtil.dict(st.get("meta")).get("curing", false)) or not tradeable(core, item):
		out.tier = "no_use"
		return out
	if tier == "no_use":
		return out
	if tier == "resells":
		if str(row.get("channel", "")) == "meat_channel":
			var m := market_of(core, npc)
			var su := SurvivalEconomy.sell_unit(core, m, st)
			out.v = float(su.unit_d) if bool(su.get("ok", false)) else 0.0
			out["meat_channel"] = true
		else:
			var su2 := SurvivalEconomy.sell_unit(core, "mkt.visiting_trader", st)
			out.v = float(su2.unit_d) if bool(su2.get("ok", false)) and str(su2.layer) == "barter" else 0.0
		return out
	var r := rv(core, item)
	var W := _tier_mult(core, "want_tiers", tier)
	var cap := local_cap(core, npc, item)
	if cap < W:
		out["capped"] = true
		W = cap
	var c := SurvivalUtil.pair(barter_cfg(core).get("value_in_clamp"), 1.0)
	out.v = clampf(r * W, c.x * r, c.y * r) * stack_q(core, st) if W > 0.0 else 0.0
	return out


## The NPC's terms: the multiplier on what it gives (its margin, the standing tier, the player's Trade, drink), and the
## haggled terms of a session (at most 0.10 below).
static func terms(core: SurvivalCore, npc: String, haggle_down: float = 0.0) -> float:
	var tb := behaviour(core, npc)
	var t := 1.0
	match str(tb.get("value_out", "rv_k")):
		"cash_price":
			t = 1.0 + SurvivalEconomy.spread_eff(core, market_of(core, npc))
		"tariff":
			t = 1.0 + SurvivalUtil.num(SurvivalSkills.flag(core, "trade", "tariff_spread_add", 0.0), 0.0)
		_:
			var ta := SurvivalUtil.num(SurvivalUtil.dict(barter_cfg(core).get("tier_adj")).get(SurvivalEconomy.standing_tier(core, faction_of(core, npc))), 0.0)
			var disc := SurvivalUtil.num(barter_cfg(core).get("trade_skill_discount_at_100"), 0.1) * SurvivalSkills.level(core, "trade") / 100.0
			t = (1.0 + SurvivalUtil.num(tb.get("margin"), 0.1) + ta - disc) * SurvivalUtil.num(core.get_modifiers().get("trade_price_mult"), 1.0)
	var room := SurvivalUtil.num(SurvivalUtil.dict(barter_cfg(core).get("haggle")).get("opening_add"), 0.10)
	# The terms floor keeps any same-day round trip between two partners under the price paid (T11, economy.json barter).
	return maxf(SurvivalUtil.num(barter_cfg(core).get("terms_floor"), 0.9), maxf(t - room, t - maxf(0.0, haggle_down)))


static func tradeable(core: SurvivalCore, item: String) -> bool:
	var it := core.data.item(item)
	if it.is_empty():
		return false
	return not (it.has("tradeable") and not bool(it.tradeable))


# ---------------------------------------------------------------- lines
static func _line_rv(core: SurvivalCore, line: Dictionary) -> float:
	match str(line.get("kind", "")):
		"item":
			return rv(core, str(line.get("item_id", ""))) * SurvivalUtil.num(line.get("qty"), 0.0)
		"coin":
			return SurvivalUtil.num(line.get("pence"), 0.0)
		"service":
			if str(line.get("service", "")) == "labour":
				return LABOUR_D_PER_H * SurvivalUtil.num(SurvivalUtil.dict(line.get("terms")).get("hours"), 0.0)
		"promise":
			var owes := SurvivalUtil.dict(line.get("owes"))
			if owes.has("pence"):
				return SurvivalUtil.num(owes.pence, 0.0)
			var t := 0.0
			for it in owes.keys():
				t += rv(core, str(it)) * SurvivalUtil.num(owes[it], 0.0)
			return t
	return 0.0


## Value to the NPC of what the other party gives it (pence).
static func value_in(core: SurvivalCore, npc: String, lines: Array) -> Dictionary:
	var total := 0.0
	var cues := []
	var tb := behaviour(core, npc)
	var accepts := SurvivalUtil.arr(tb.get("accepts"))
	for line in lines:
		var v := 0.0
		var cue := {"tier": "fair", "reason": ""}
		match str(line.get("kind", "")):
			"item":
				for st in SurvivalUtil.arr(line.get("_stacks")):
					var u := unit_in(core, npc, st)
					v += float(u.v) * float(st.qty)
					cue = {"tier": str(u.tier), "reason": str(u.reason), "capped": bool(u.get("capped", false))}
			"coin":
				v = SurvivalUtil.num(line.get("pence"), 0.0)
			"service":
				if str(line.get("service", "")) == "labour" and (accepts.is_empty() or accepts.has("labour")):
					v = LABOUR_D_PER_H * SurvivalUtil.num(SurvivalUtil.dict(line.get("terms")).get("hours"), 0.0)
			"promise":
				var need := SurvivalUtil.num(tb.get("credit_trust_min"), 5.0)
				if trust(core, npc) >= need - 0.0001 and (accepts.is_empty() or accepts.has("promise")):
					v = _line_rv(core, line) * PROMISE_VALUE_FRAC
				else:
					cue = {"tier": "no_use", "reason": "they do not know you well enough for a promise"}
		total += v
		cues.append(cue)
	return {"total": total, "cues": cues}


## What the NPC's own lines cost it (pence, before its terms): its goods at unit_out, coin at its coin premium.
static func value_out(core: SurvivalCore, npc: String, lines: Array) -> float:
	var total := 0.0
	var tb := behaviour(core, npc)
	for line in lines:
		match str(line.get("kind", "")):
			"item":
				var u := unit_out(core, npc, str(line.get("item_id", "")), false)
				total += maxf(0.0, u) * SurvivalUtil.num(line.get("qty"), 0.0)
			"coin":
				total += SurvivalUtil.num(line.get("pence"), 0.0) * SurvivalUtil.num(tb.get("coin_premium"), 1.0)
	return total


# ---------------------------------------------------------------- sessions
static func session(core: SurvivalCore, tr_id: String) -> Dictionary:
	return SurvivalUtil.dict(_t(core).sessions.get(tr_id))


static func _in_open_session(core: SurvivalCore, party: String) -> String:
	for id in SurvivalUtil.sorted_ids(_t(core).sessions):
		var s: Dictionary = _t(core).sessions[id]
		if str(s.state) == "open" and SurvivalUtil.arr(s.parties).has(party):
			return str(id)
	return ""


static func _patience(core: SurvivalCore, npc: String) -> int:
	var p := SurvivalUtil.dict(_t(core).patience.get(npc))
	if int(SurvivalUtil.num(p.get("day"), -1.0)) != SurvivalClock.abs_day(core):
		return int(SurvivalUtil.num(behaviour(core, npc).get("patience"), 3.0))
	return int(SurvivalUtil.num(p.get("left"), 0.0))


static func _spend_patience(core: SurvivalCore, npc: String, n: int = 1) -> int:
	var left := maxi(0, _patience(core, npc) - n)
	_t(core).patience[npc] = {"day": SurvivalClock.abs_day(core), "left": left}
	return left


## Open a trade window between two parties. Returns {ok, tr, reason}.
static func open(core: SurvivalCore, a: String, b: String, opts: Dictionary = {}) -> Dictionary:
	if a == b:
		return {"ok": false, "reason": "a party cannot trade with itself"}
	var npc := b if not is_player(b) else (a if not is_player(a) else "")
	# The v4 records an NPC values a trade by (trust, Trade, standing) are still read from the local player (P0-3 is
	# partial), so a guest trades with NPCs only once the co-op split gives every player their own.
	if npc != "":
		var pl := a if npc == b else b
		if is_player(pl) and not is_local(core, pl):
			return {"ok": false, "reason": "a guest player trades with people here once co-op arrives"}
	for p in [a, b]:
		if not partner_present(core, p):
			return {"ok": false, "reason": "%s %s not here" % [_title(core, p), _be(core, p)]}
		if not is_player(p) and not trades(core, p):
			return {"ok": false, "reason": "%s does not trade" % _title(core, p)}
		if not is_player(p) and _patience(core, p) <= 0:
			return {"ok": false, "reason": "%s will not deal with you again today" % _title(core, p)}
		var other := _in_open_session(core, p)
		if other != "":
			return {"ok": false, "reason": "%s %s already trading (%s)" % [_title(core, p), _be(core, p), other]}
	var id := _next_id(core, "tr")
	_t(core).sessions[id] = {"id": id, "version": 0, "parties": [a, b], "lines": {a: [], b: []}, "confirmed": {a: -1, b: -1},
			"state": "open", "where": str(core.state.context.get("location", "")), "opened_w": core.state.minutes,
			"edited_w": core.state.minutes, "opened_day": SurvivalClock.abs_day(core),
			"escrow": {a: {"stacks": [], "coin": 0, "stock": {}}, b: {"stacks": [], "coin": 0, "stock": {}}}, "npc": npc,
			"haggle": {"presses": 0, "down": 0.0}, "lesson": bool(opts.get("lesson", false)), "edited_real_s": -1.0}
	return {"ok": true, "tr": id}


static func _title(core: SurvivalCore, party: String) -> String:
	return "you" if is_local(core, party) else (party if is_player(party) else core.npc_title(party))


## "is" or "are" for a party's title ("you are", "the sutler is").
static func _be(core: SurvivalCore, party: String) -> String:
	return "are" if is_local(core, party) else "is"


## The authority's own real clock (seconds), accumulated by SurvivalCore.update even while paused: the confirm lock
## between players is measured on it, never on a client's clock.
static func authority_real_s(core: SurvivalCore) -> float:
	return SurvivalUtil.num(core.state.world.get("real_s"), 0.0)


## The authority's lifecycle rules for open sessions (see the header): a party gone, a new day, or an idle window.
## Called after every simulation step and every context change. Returns the ids cancelled.
static func check_sessions(core: SurvivalCore) -> Array:
	var out := []
	var t := SurvivalUtil.dict(core.state.world.get("trade"))
	var ss := SurvivalUtil.dict(t.get("sessions"))
	if ss.is_empty():
		return out
	for id in SurvivalUtil.sorted_ids(ss):
		var s: Dictionary = ss[id]
		if str(s.get("state", "")) != "open":
			continue
		var why := ""
		if core.is_dead():
			why = "a party died"
		elif int(SurvivalUtil.num(s.get("opened_day"), SurvivalClock.abs_day(core))) != SurvivalClock.abs_day(core):
			why = "the day is over"
		elif core.state.minutes - SurvivalUtil.num(s.get("edited_w", s.get("opened_w")), core.state.minutes) > SESSION_IDLE_MIN:
			why = "the window was left open too long"
		else:
			for p in s.parties:
				if not partner_present(core, str(p)):
					why = "%s %s no longer here" % [_title(core, str(p)), _be(core, str(p))]
					break
		if why != "":
			cancel(core, str(id), why)
			out.append(str(id))
	return out


## Replace one party's lines. Offered goods and coin move into escrow; the version is bumped and both confirmations
## cleared. With an NPC in the session, the NPC then evaluates the deal as it stands (whichever side was edited) and
## confirms the new version or counter-offers. Players edit only their own lines; the player proposes an NPC partner's
## side too (SurvivalCore.trade_request), since an NPC has no client. The edit is stamped on the authority's real clock
## (the 2-second confirm lock between players); a client's clock is never trusted.
static func set_lines(core: SurvivalCore, tr_id: String, party: String, lines: Array, _opts: Dictionary = {}) -> Dictionary:
	var s := session(core, tr_id)
	if s.is_empty() or str(s.state) != "open":
		return {"ok": false, "reason": "no open trade"}
	if not SurvivalUtil.arr(s.parties).has(party):
		return {"ok": false, "reason": "not a party to this trade"}
	_release(core, s, party)
	var clean := []
	for line0 in lines:
		var line: Dictionary = SurvivalUtil.dict(line0).duplicate(true)
		line.erase("_stacks")
		var chk := _check_line(core, s, party, line)
		if not bool(chk.ok):
			_escrow_lines(core, s, party, s.lines[party])
			return {"ok": false, "reason": str(chk.reason)}
		clean.append(line)
	var esc := _escrow_lines(core, s, party, clean)
	if not bool(esc.ok):
		_escrow_lines(core, s, party, s.lines[party])
		return esc
	s.lines[party] = clean
	s["version"] = int(s.version) + 1
	for p in s.parties:
		s.confirmed[p] = -1
	s["edited_real_s"] = authority_real_s(core)
	s["edited_w"] = core.state.minutes
	var out := {"ok": true, "version": int(s.version)}
	var npc := str(s.get("npc", ""))
	if npc != "":
		var ev := evaluate(core, tr_id)
		out["evaluation"] = ev
		if bool(ev.ok):
			s.confirmed[npc] = int(s.version)
	return out


static func _check_line(core: SurvivalCore, s: Dictionary, party: String, line: Dictionary) -> Dictionary:
	var kind := str(line.get("kind", ""))
	if not LINE_KINDS.has(kind):
		return {"ok": false, "reason": "unknown line kind %s" % kind}
	match kind:
		"item":
			var item := str(line.get("item_id", ""))
			var qty := SurvivalUtil.num(line.get("qty"), 0.0)
			if line.has("uid") and is_player(party):
				# The authority trusts the stack a uid names, never the client's label for it.
				var st := SurvivalInventory.find_uid_in(_stacks_of_party(core, party), str(line.uid))
				if st.is_empty():
					return {"ok": false, "reason": "that stack is not carried"}
				if item != "" and item != str(st.id):
					return {"ok": false, "reason": "the line does not match the stack it names"}
				item = str(st.id)
				line["item_id"] = item
				if not SurvivalInventory.usable(st):
					return {"ok": false, "reason": "%s is still curing" % core.data.item_name(item)}
				if float(st.qty) < qty - 0.0001:
					return {"ok": false, "reason": "not enough %s in that stack" % core.data.item_name(item).to_lower()}
			if item == "" or core.data.item(item).is_empty():
				return {"ok": false, "reason": "unknown item"}
			if not tradeable(core, item):
				return {"ok": false, "reason": "%s cannot be traded" % core.data.item_name(item)}
			if qty <= 0.0:
				return {"ok": false, "reason": "nothing offered"}
			if not is_player(party) and unit_out(core, party, item) < 0.0:
				return {"ok": false, "reason": "%s has no %s to spare" % [_title(core, party), core.data.item_name(item).to_lower()]}
			# A garment being worn stays on: the player takes it off first (escrow never strips the body).
			if is_local(core, party):
				var worn_n := core.state.worn.count(item)
				if worn_n > 0 and SurvivalInventory.count(core, item) - qty < float(worn_n) - 0.0001:
					return {"ok": false, "reason": "you are wearing the %s: take it off first" % core.data.item_name(item).to_lower()}
		"coin":
			if int(SurvivalUtil.num(line.get("pence"), 0.0)) <= 0:
				return {"ok": false, "reason": "no coin offered"}
		"service":
			if not SERVICES.has(str(line.get("service", ""))):
				return {"ok": false, "reason": "unknown service"}
			if str(line.service) == "lesson" and not bool(s.get("lesson", false)):
				return {"ok": false, "reason": "lessons are agreed through the lesson dialog"}
			if str(line.service) == "labour" and SurvivalUtil.num(SurvivalUtil.dict(line.get("terms")).get("hours"), 0.0) <= 0.0:
				return {"ok": false, "reason": "no hours of labour offered"}
		"promise":
			if core.data.action("social.ask_teach").is_empty():
				return {"ok": false, "reason": "promises arrive with M2b"}
	return {"ok": true}


## Move a party's offered goods and coin into the session's escrow. Player stacks by uid (or item id, best first);
## NPC goods from its stock. Returns {ok, reason}.
static func _escrow_lines(core: SurvivalCore, s: Dictionary, party: String, lines: Array) -> Dictionary:
	var esc: Dictionary = s.escrow[party]
	for line in lines:
		match str(line.get("kind", "")):
			"item":
				var item := str(line.item_id)
				var qty := SurvivalUtil.num(line.qty, 0.0)
				if is_player(party):
					var stacks := _stacks_of_party(core, party)
					var one := SurvivalInventory.find_uid_in(stacks, str(line.uid)) if line.has("uid") else {}
					var have := SurvivalInventory.count_usable_in(core, stacks, item) if not line.has("uid") else \
							(SurvivalUtil.num(one.get("qty"), 0.0) if str(one.get("id", "")) == item and SurvivalInventory.usable(one) else 0.0)
					if have < qty - 0.0001:
						_release(core, s, party)
						return {"ok": false, "reason": "not enough %s" % core.data.item_name(item).to_lower()}
					var parts := SurvivalInventory.take_for_trade(core, stacks, item, qty, str(line.get("uid", "")), is_local(core, party))
					# The line is what was really escrowed: its item and quantity come from the parts taken.
					var got := 0.0
					for pt in parts:
						got += float(pt.qty)
						if str(pt.id) != item:
							esc.stacks.append_array(parts)
							_release(core, s, party)
							return {"ok": false, "reason": "the line does not match the stack it names"}
					line["qty"] = got
					line["_stacks"] = parts
					esc.stacks.append_array(parts)
				else:
					var st := npc_stock(core, party)
					if SurvivalUtil.num(st.get(item), 0.0) < qty - 0.0001:
						_release(core, s, party)
						return {"ok": false, "reason": "%s has only %s %s" % [_title(core, party), SurvivalEconomy._qty_s(SurvivalUtil.num(st.get(item), 0.0)), core.data.item_name(item).to_lower()]}
					st[item] = SurvivalUtil.num(st.get(item), 0.0) - qty
					esc.stock[item] = SurvivalUtil.num(esc.stock.get(item), 0.0) + qty
					line["_stacks"] = [{"id": item, "qty": qty, "meta": {}}]
			"coin":
				var pence := int(SurvivalUtil.num(line.pence, 0.0))
				if is_player(party):
					if money_of(core, party) < pence:
						_release(core, s, party)
						return {"ok": false, "reason": "not enough coin"}
					_add_money(core, party, -pence)
				esc["coin"] = int(esc.coin) + pence
	return {"ok": true}


## Return a party's escrow (goods to its pack or stock, coin to its purse).
static func _release(core: SurvivalCore, s: Dictionary, party: String) -> void:
	var esc: Dictionary = s.escrow[party]
	if is_player(party):
		var stacks := _stacks_of_party(core, party)
		for st in esc.stacks:
			SurvivalInventory.add_to(core, stacks, str(st.id), float(st.qty), SurvivalUtil.dict(st.get("meta")), str(st.get("uid", "")), is_local(core, party))
		if int(esc.coin) > 0:
			_add_money(core, party, float(esc.coin))
	else:
		for it in SurvivalUtil.dict(esc.stock).keys():
			_stock_add(core, party, str(it), float(esc.stock[it]))
	s.escrow[party] = {"stacks": [], "coin": 0, "stock": {}}
	for line in SurvivalUtil.arr(s.lines.get(party)):
		line.erase("_stacks")


## The NPC's view of the deal (authority side): {ok, value_in, value_out, required, ratio, cue, line_cues, counter}.
static func evaluate(core: SurvivalCore, tr_id: String) -> Dictionary:
	var s := session(core, tr_id)
	var npc := str(s.get("npc", ""))
	if npc == "":
		return {"ok": false, "reason": "no NPC party"}
	var other := ""
	for p in s.parties:
		if str(p) != npc:
			other = str(p)
	if bool(s.get("lesson", false)):
		return {"ok": true, "value_in": 0.0, "value_out": 0.0, "required": 0.0, "ratio": 1.0, "cue": "fair", "line_cues": []}
	var vi := value_in(core, npc, s.lines[other])
	var vo := value_out(core, npc, s.lines[npc])
	var tm := terms(core, npc, float(s.haggle.down))
	var req := vo * tm
	var ratio := float(vi.total) / maxf(0.01, req) if req > 0.0 else (INF if float(vi.total) > 0.0 else 0.0)
	var ok := (req > 0.0 and float(vi.total) >= req - 0.01) or (req <= 0.0 and float(vi.total) > 0.0)
	var out := {"ok": ok, "value_in": float(vi.total), "value_out": vo, "terms": tm, "required": req, "ratio": ratio,
			"cue": deal_cue(core, ratio), "line_cues": _line_cues(core, vi.cues)}
	if not ok:
		out["counter"] = counter_offer(core, s, npc, float(vi.total), tm)
	return out


static func deal_cue(core: SurvivalCore, ratio: float) -> String:
	var dc := SurvivalUtil.dict(SurvivalUtil.dict(barter_cfg(core).get("cues")).get("deal"))
	if ratio < SurvivalUtil.num(dc.get("insulting"), 0.8):
		return "insulting"
	if ratio < SurvivalUtil.num(dc.get("short"), 1.0):
		return "short"
	if ratio < SurvivalUtil.num(dc.get("good"), 1.1):
		return "good"
	if ratio < SurvivalUtil.num(dc.get("fair"), 1.35):
		return "fair"
	return "generous"


static func _line_cues(core: SurvivalCore, cues: Array) -> Array:
	var out := []
	for c in cues:
		var t := str(c.get("tier", "fair"))
		var word := "fair"
		match t:
			"short_of", "wants":
				word = "reluctant" if bool(c.get("capped", false)) else "eager"
			"uses", "resells":
				word = "reluctant" if bool(c.get("capped", false)) else "fair"
			"no_use":
				word = "will not take it"
		out.append({"cue": word, "reason": str(c.get("reason", ""))})
	return out


## A counter-offer: the most of its largest line the NPC would give for what is offered, or what more it wants.
static func counter_offer(core: SurvivalCore, s: Dictionary, npc: String, vin: float, tm: float) -> Dictionary:
	var lines: Array = s.lines[npc]
	var best := -1
	var best_v := 0.0
	for i in lines.size():
		var v := value_out(core, npc, [lines[i]])
		if v > best_v:
			best_v = v
			best = i
	if best < 0:
		return {"kind": "add", "text": "offer something they want"}
	var others := value_out(core, npc, lines) - best_v
	var line: Dictionary = lines[best]
	var unit := best_v / maxf(0.0001, SurvivalUtil.num(line.get("qty", line.get("pence", 1.0)), 1.0))
	var can := floorf(maxf(0.0, (vin / maxf(0.01, tm) - others)) / maxf(0.0001, unit))
	if can >= 1.0:
		return {"kind": "reduce", "line": best, "qty": can,
				"text": "I can give %s, not %s" % [SurvivalEconomy._qty_s(can), SurvivalEconomy._qty_s(SurvivalUtil.num(line.get("qty", line.get("pence", 0.0)), 0.0))]}
	return {"kind": "add", "pence": ceilf(best_v * tm - vin), "text": "add something more"}


## A party confirms the current version. Both confirming the same version commits the trade. Only a party may confirm.
## Between two players the confirm stays locked for confirm_lock_real_s after an edit, on the authority's real clock.
static func _in_ledger(core: SurvivalCore, tr_id: String) -> bool:
	for e in SurvivalUtil.arr(_t(core).get("ledger")):
		if str(e.get("tr", "")) == tr_id:
			return true
	return false


static func confirm(core: SurvivalCore, tr_id: String, party: String, version: int, _opts: Dictionary = {}) -> Dictionary:
	var s := session(core, tr_id)
	if s.is_empty():
		if _in_ledger(core, tr_id):
			return {"ok": true, "committed": true, "already": true, "tr": tr_id}
		return {"ok": false, "reason": "no such trade"}
	if str(s.state) == "committed":
		return {"ok": true, "committed": true, "already": true}
	if str(s.state) != "open":
		return {"ok": false, "reason": "the trade is %s" % str(s.state)}
	if not SurvivalUtil.arr(s.parties).has(party):
		return {"ok": false, "reason": "not a party to this trade"}
	if version != int(s.version):
		return {"ok": false, "reason": "the offer changed: look again before confirming"}
	var both_players := is_player(str(s.parties[0])) and is_player(str(s.parties[1]))
	var lock := SurvivalUtil.num(SurvivalUtil.dict(barter_cfg(core).get("commit")).get("confirm_lock_real_s"), 2.0)
	if both_players and SurvivalUtil.num(s.get("edited_real_s"), -1.0) >= 0.0 \
			and authority_real_s(core) - float(s.edited_real_s) < lock - 0.000001:
		return {"ok": false, "reason": "wait a moment: the offer just changed"}
	s.confirmed[party] = version
	# An NPC in the session answers the version the player confirms (it has no client to confirm with).
	var npc := str(s.get("npc", ""))
	if npc != "" and npc != party and int(s.confirmed[npc]) != version:
		var ev := evaluate(core, tr_id)
		if bool(ev.ok):
			s.confirmed[npc] = version
		else:
			return {"ok": true, "committed": false, "reason": "%s will not take it as it stands" % _title(core, npc),
					"counter": str(SurvivalUtil.dict(ev.get("counter")).get("text", ""))}
	for p in s.parties:
		if int(s.confirmed[p]) != version:
			return {"ok": true, "committed": false, "reason": "waiting for %s to confirm" % _title(core, str(p))}
	return commit(core, tr_id)


## A party's load after the trade (kg). Offered goods sit in escrow, out of the pack, while the window is open: the load
## after is what the party carries now plus what it receives.
static func _load_after(core: SurvivalCore, s: Dictionary, receiver: String, giver: String) -> float:
	return _load_now(core, receiver) + _lines_kg(core, SurvivalUtil.arr(s.lines.get(giver)))


## What a party carries now (a local player's pack weight, worn clothes included; escrowed goods excluded).
static func _load_now(core: SurvivalCore, party: String) -> float:
	var kg := 0.0
	if is_local(core, party):
		kg = SurvivalInventory.weight_kg(core)
	else:
		for st in _stacks_of_party(core, party):
			kg += SurvivalUtil.num(core.data.item(str(st.id)).get("kg"), 0.0) * float(st.qty)
	return kg


static func _lines_kg(core: SurvivalCore, lines: Array) -> float:
	var kg := 0.0
	for line in lines:
		if str(line.get("kind", "")) == "item":
			kg += SurvivalUtil.num(core.data.item(str(line.item_id)).get("kg"), 0.0) * SurvivalUtil.num(line.qty, 0.0)
	return kg


## The carry rule (the one overflow rule, GDD 11.5): a trade may not leave a player over load.max_kg carrying more than
## before the window opened (now plus what it offered). A trade that lightens an overloaded pack is always allowed:
## gathering and butchering may overload a player, and the load stages slow them until they cache or leave some.
static func _carry_refused(core: SurvivalCore, s: Dictionary, receiver: String, giver: String, maxkg: float) -> bool:
	var before := _load_now(core, receiver) + _lines_kg(core, SurvivalUtil.arr(s.lines.get(receiver)))
	var after := _load_after(core, s, receiver, giver)
	return after > maxkg + 0.001 and after > before + 0.001


## Commit on the authority: re-check everything, then apply every removal and addition in one step, write obligations
## and the ledger, change standing and trust, and emit trade_committed. Idempotent.
static func commit(core: SurvivalCore, tr_id: String) -> Dictionary:
	var s := session(core, tr_id)
	if s.is_empty():
		# Idempotent: a commit repeated after the session was pruned finds the trade in the ledger and changes nothing.
		if _in_ledger(core, tr_id):
			return {"ok": true, "committed": true, "already": true, "tr": tr_id}
		return {"ok": false, "reason": "no such trade"}
	if str(s.state) == "committed":
		return {"ok": true, "committed": true, "already": true}
	if str(s.state) != "open":
		return {"ok": false, "reason": "the trade is %s" % str(s.state)}
	var a := str(s.parties[0])
	var b := str(s.parties[1])
	if int(s.confirmed[a]) != int(s.version) or int(s.confirmed[b]) != int(s.version):
		return {"ok": false, "reason": "both sides must confirm the same offer"}
	for p in [a, b]:
		if not partner_present(core, p):
			return _reopen(core, s, "%s is no longer here" % _title(core, p))
	var npc := str(s.get("npc", ""))
	if npc != "" and not bool(s.get("lesson", false)):
		var ev := evaluate(core, tr_id)
		if not bool(ev.ok):
			return _reopen(core, s, "%s will not take it as it stands" % _title(core, npc))
	var maxkg := SurvivalUtil.num(core.data.section("needs", "load").get("max_kg"), 60.0)
	for pair in [[a, b], [b, a]]:
		if is_player(str(pair[0])) and _carry_refused(core, s, str(pair[0]), str(pair[1]), maxkg):
			return _reopen(core, s, "%s cannot carry it all (over %d kg)" % [_title(core, str(pair[0])), int(maxkg)])
	# Apply: every escrowed good and coin goes to the other party; services and promises become obligations. No module
	# signal leaves the authority until the whole apply has succeeded: they are queued and emitted after trade_committed.
	core.defer_signals(true)
	var rv_moved := {a: 0.0, b: 0.0}
	var new_obs := []
	for pair in [[a, b], [b, a]]:
		var giver := str(pair[0])
		var taker := str(pair[1])
		var esc: Dictionary = s.escrow[giver]
		for st in esc.stacks:
			_give(core, taker, str(st.id), float(st.qty), SurvivalUtil.dict(st.get("meta")), str(st.get("uid", "")))
			rv_moved[giver] = float(rv_moved[giver]) + rv(core, str(st.id)) * float(st.qty)
		for it in SurvivalUtil.dict(esc.stock).keys():
			_give(core, taker, str(it), float(esc.stock[it]), {}, "")
			rv_moved[giver] = float(rv_moved[giver]) + rv(core, str(it)) * float(esc.stock[it])
		if int(esc.coin) > 0:
			if is_player(taker):
				_add_money(core, taker, float(esc.coin))
			rv_moved[giver] = float(rv_moved[giver]) + float(esc.coin)
			if is_local(core, giver):
				core.state.stats["coin_spent"] = SurvivalUtil.num(core.state.stats.get("coin_spent"), 0.0) + float(esc.coin)
		for line in SurvivalUtil.arr(s.lines.get(giver)):
			var k := str(line.get("kind", ""))
			if k == "service" or k == "promise":
				new_obs.append(add_obligation(core, giver, taker, k if k == "promise" else str(line.service), line, tr_id))
				rv_moved[giver] = float(rv_moved[giver]) + _line_rv(core, line)
		s.escrow[giver] = {"stacks": [], "coin": 0, "stock": {}}
	s["state"] = "committed"
	s["committed_w"] = core.state.minutes
	var entry := {"tr": tr_id, "t": core.state.minutes, "date": SurvivalClock.date_string(core), "parties": [a, b],
			"lines": {a: _plain_lines(s.lines[a]), b: _plain_lines(s.lines[b])}, "rv": rv_moved.duplicate()}
	var led: Array = _t(core).ledger
	led.append(entry)
	while led.size() > LEDGER_CAP:
		led.remove_at(0)
	if npc != "":
		_after_npc_trade(core, s, npc, a if npc == b else b, float(rv_moved[a]) + float(rv_moved[b]))
	var summary := _summary(core, s)
	core.log_line("traded with %s: %s" % [_title(core, npc if npc != "" else (b if is_local(core, a) else a)), summary], "trade")
	core.state.stats["trades"] = int(SurvivalUtil.num(core.state.stats.get("trades"), 0.0)) + 1
	_prune(core)
	core._on_trade_committed(tr_id, entry)
	core.defer_signals(false)
	return {"ok": true, "committed": true, "tr": tr_id, "obligations": new_obs, "summary": summary}


static func _plain_lines(lines: Array) -> Array:
	var out := []
	for l in lines:
		var c: Dictionary = SurvivalUtil.dict(l).duplicate(true)
		c.erase("_stacks")
		out.append(c)
	return out


static func _give(core: SurvivalCore, taker: String, item: String, qty: float, meta: Dictionary, uid: String) -> void:
	if is_player(taker):
		SurvivalInventory.add_to(core, _stacks_of_party(core, taker), item, qty, meta, uid, is_local(core, taker))
	else:
		_stock_add(core, taker, item, qty)


static func _reopen(core: SurvivalCore, s: Dictionary, reason: String) -> Dictionary:
	for p in s.parties:
		s.confirmed[p] = -1
	return {"ok": false, "reason": reason}


static func _summary(core: SurvivalCore, s: Dictionary) -> String:
	var parts := PackedStringArray()
	for p in s.parties:
		var bits := PackedStringArray()
		for l in SurvivalUtil.arr(s.lines[p]):
			match str(l.get("kind", "")):
				"item":
					bits.append("%s %s" % [SurvivalEconomy._qty_s(SurvivalUtil.num(l.qty, 0.0)), core.data.item_name(str(l.item_id)).to_lower()])
				"coin":
					bits.append(SurvivalUtil.lsd(SurvivalUtil.num(l.pence, 0.0)))
				"service":
					bits.append("%s (%s)" % [str(l.service), str(SurvivalUtil.dict(l.get("terms")).get("what", SurvivalUtil.dict(l.get("terms")).get("job", "")))])
				"promise":
					bits.append("a promise")
		parts.append("%s gave %s" % [_title(core, str(p)), ", ".join(bits) if not bits.is_empty() else "nothing"])
	return "; ".join(parts)


## After a committed NPC trade: want quotas, market stock bookkeeping, fair-trade standing (60 d of rv or more a visit)
## and trust, and Trade experience from the rv the player gave (goods, coin, labour: one scale with sales,
## SurvivalEconomy.sell). A lesson's ask counts toward Trade too (a service traded), but not toward standing.
static func _after_npc_trade(core: SurvivalCore, s: Dictionary, npc: String, player: String, rv_total: float) -> void:
	var gave_pelt := false
	for line in SurvivalUtil.arr(s.lines.get(player)):
		if str(line.get("kind", "")) == "item":
			_record_taken(core, npc, str(line.item_id), SurvivalUtil.num(line.qty, 0.0))
			var row := want_row(core, npc, str(line.item_id))
			if str(row.get("channel", "")) == "meat_channel":
				SurvivalEconomy._record_meat(core, str(line.item_id), SurvivalUtil.num(line.qty, 0.0))
			if core.data.item_cat(str(line.item_id)) == "pelt":
				gave_pelt = true
	if not is_local(core, player):
		return
	var mine := 0.0
	for line in SurvivalUtil.arr(s.lines.get(player)):
		mine += _line_rv(core, line)
	SurvivalSkills.record_trade(core, mine, false, npc)
	if bool(s.get("lesson", false)):
		return
	var m := market_of(core, npc)
	SurvivalEconomy.record_visit_trade(core, m if m != "" else npc, faction_of(core, npc), rv_total)
	var ts := SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("trust")))
	if rv_total >= 60.0:
		add_trust(core, npc, SurvivalUtil.num(SurvivalUtil.dict(ts.get("sources")).get("fair_trade"), 0.5), "fair_trade")
	core.state.stats["barter_rv"] = SurvivalUtil.num(core.state.stats.get("barter_rv"), 0.0) + rv_total
	# First refusal (the trader's lesson ask) is kept by bringing him pelts before anyone else.
	if gave_pelt:
		for ob in obligations_of(core, player, true):
			if str(ob.kind) == "first_refusal" and str(ob.to) == npc:
				_close(core, ob, "kept")


static func cancel(core: SurvivalCore, tr_id: String, reason: String = "cancelled") -> Dictionary:
	var s := session(core, tr_id)
	if s.is_empty() or str(s.state) != "open":
		return {"ok": false, "reason": "no open trade"}
	for p in s.parties:
		_release(core, s, str(p))
	s["state"] = "cancelled"
	s["cancel_reason"] = reason
	_prune(core)
	return {"ok": true}


## Open sessions are cancelled (escrow returned) when a single-player or co-op save is written. A persistent world keeps
## them with their escrow instead (SurvivalSave.to_document keep_trades): the session records hold everything needed.
static func cancel_all(core: SurvivalCore, reason: String = "the game was saved") -> void:
	for id in SurvivalUtil.sorted_ids(_t(core).sessions):
		if str(_t(core).sessions[id].get("state", "")) == "open":
			cancel(core, str(id), reason)


## Finished sessions are dropped from the world (the ledger keeps the committed ones).
static func _prune(core: SurvivalCore) -> void:
	var ss: Dictionary = _t(core).sessions
	for id in ss.keys():
		if str(ss[id].get("state", "")) != "open":
			ss.erase(id)


# ---------------------------------------------------------------- haggling (M2b)
## trade.haggle's effect: a press moves the partner's ask toward its floor (0.05, 0.08 on an excellent); a failure costs
## patience; an offer more than 20% below the floor is an insult (patience and trust). At 0 patience the window closes.
static func haggle(core: SurvivalCore, tr_id: String, outcome: String) -> Dictionary:
	var s := session(core, tr_id)
	var npc := str(s.get("npc", ""))
	if s.is_empty() or npc == "":
		return {"ok": false, "reason": "no open trade with a partner"}
	var hc := SurvivalUtil.dict(barter_cfg(core).get("haggle"))
	var step := SurvivalUtil.num(SurvivalUtil.dict(hc.get("step")).get(outcome), 0.0)
	var res := {"ok": true, "outcome": outcome, "step": step}
	s.haggle["presses"] = int(s.haggle.presses) + 1
	if step > 0.0:
		s.haggle["down"] = minf(SurvivalUtil.num(hc.get("opening_add"), 0.10), float(s.haggle.down) + step)
	elif outcome == "failure" or outcome == "mishap":
		res["patience"] = _spend_patience(core, npc)
	var ev := evaluate(core, tr_id)
	if float(ev.required) > 0.0 and float(ev.ratio) < 1.0 - SurvivalUtil.num(hc.get("insult_below_floor"), 0.2):
		res["insult"] = true
		res["patience"] = _spend_patience(core, npc)
		add_trust(core, npc, SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("trust")).get("penalties"))).get("insult"), -1.0), "insult")
	if _patience(core, npc) <= 0:
		cancel(core, tr_id, "%s has had enough for today" % _title(core, npc))
		res["closed"] = true
		return res
	s["version"] = int(s.version) + 1
	for p in s.parties:
		s.confirmed[p] = -1
	if bool(ev.ok) or bool(evaluate(core, tr_id).ok):
		s.confirmed[npc] = int(s.version)
	res["evaluation"] = evaluate(core, tr_id)
	return res


## How many presses the haggle check is at (its D is 30 + 10 per earlier press) and whether the deal is big enough.
static func haggle_presses(core: SurvivalCore, tr_id: String) -> int:
	return int(SurvivalUtil.num(SurvivalUtil.dict(session(core, tr_id).get("haggle")).get("presses"), 0.0))


static func haggle_allowed(core: SurvivalCore, tr_id: String) -> Dictionary:
	var s := session(core, tr_id)
	if s.is_empty() or str(s.get("state", "")) != "open" or str(s.get("npc", "")) == "":
		return {"ok": false, "reason": "no open trade with a partner"}
	var rvd := 0.0
	for p in s.parties:
		for l in SurvivalUtil.arr(s.lines[p]):
			rvd += _line_rv(core, l)
	var mn := SurvivalUtil.num(SurvivalUtil.dict(barter_cfg(core).get("haggle")).get("no_haggle_under_rv_d"), 60.0)
	if rvd < mn:
		return {"ok": false, "reason": "too small a deal to haggle over"}
	return {"ok": true}


# ---------------------------------------------------------------- one-step trades (single-player menus, the harness)
## Barter in one step: open, set both sides' lines, let the NPC evaluate, confirm and commit. give / take: [[item_id, qty]]
## or [["coin", pence]]. Returns {ok, reason, evaluation, tr}.
static func barter(core: SurvivalCore, npc: String, give: Array, take: Array) -> Dictionary:
	var me := core.state.player_id
	var o := open(core, me, npc)
	if not bool(o.ok):
		return o
	var tr := str(o.tr)
	var r1 := set_lines(core, tr, npc, _to_lines(take))
	if not bool(r1.ok):
		cancel(core, tr, str(r1.reason))
		return r1
	var r2 := set_lines(core, tr, me, _to_lines(give))
	if not bool(r2.ok):
		cancel(core, tr, str(r2.reason))
		return r2
	var ev := SurvivalUtil.dict(r2.get("evaluation"))
	if not bool(ev.get("ok", false)):
		cancel(core, tr, "declined")
		return {"ok": false, "reason": "%s will not take it: %s" % [_title(core, npc), str(SurvivalUtil.dict(ev.get("counter")).get("text", ""))], "evaluation": ev}
	var c := confirm(core, tr, me, int(session(core, tr).version))
	if not bool(c.get("committed", false)):
		cancel(core, tr, str(c.get("reason", "")))
		return {"ok": false, "reason": str(c.get("reason", "not committed")), "evaluation": ev}
	return {"ok": true, "tr": tr, "evaluation": ev, "obligations": c.get("obligations", [])}


static func _to_lines(pairs: Array) -> Array:
	var out := []
	for p in pairs:
		var pr: Array = p
		if str(pr[0]) == "coin":
			out.append({"kind": "coin", "pence": int(SurvivalUtil.num(pr[1], 0.0))})
		elif str(pr[0]) == "labour":
			out.append({"kind": "service", "service": "labour", "terms": {"hours": SurvivalUtil.num(pr[1], 1.0), "job": str(pr[2]) if pr.size() > 2 else ""},
					"due": {"days": LABOUR_DUE_DAYS}})
		else:
			out.append({"kind": "item", "item_id": str(pr[0]), "qty": SurvivalUtil.num(pr[1], 1.0)})
	return out


## How much of `take_item` an NPC gives for `give_qty` of `give_item` at its current terms (0 when it will not deal).
## Authority-side arithmetic for the harness and tests; the player's window shows cues instead.
static func quote_units(core: SurvivalCore, npc: String, give_item: String, give_qty: float, take_item: String) -> float:
	var u_out := unit_out(core, npc, take_item)
	if u_out <= 0.0:
		return 0.0
	var st := {"id": give_item, "qty": give_qty, "meta": {}}
	var best := SurvivalInventory.best_stack(core, give_item)
	if not best.is_empty():
		st.meta = SurvivalUtil.dict(best.get("meta"))
	var vi := float(unit_in(core, npc, st).v) * give_qty
	var n := floorf(vi / (u_out * terms(core, npc)) + 0.0001)
	return minf(n, SurvivalUtil.num(npc_stock(core, npc).get(take_item), 0.0))


# ---------------------------------------------------------------- lessons as trades (M2b)
## A lesson agreed with a mentor: the learner's ask (goods, coin, labour owed, or friendship with no line) against the
## mentor's lesson (a service line), committed like any trade. Returns {ok, tr, lesson_ob, labour_ob}.
static func lesson_trade(core: SurvivalCore, npc: String, what: String, ask: Dictionary) -> Dictionary:
	var me := core.state.player_id
	var o := open(core, me, npc, {"lesson": true})
	if not bool(o.ok):
		return o
	var tr := str(o.tr)
	var mine := []
	if ask.has("goods"):
		for it in SurvivalUtil.dict(ask.goods).keys():
			mine.append({"kind": "item", "item_id": str(it), "qty": SurvivalUtil.num(ask.goods[it], 1.0)})
	elif ask.has("coin"):
		mine.append({"kind": "coin", "pence": int(SurvivalUtil.num(ask.coin, 0.0))})
	elif ask.has("labour"):
		var lb := SurvivalUtil.dict(ask.labour)
		mine.append({"kind": "service", "service": "labour", "terms": {"hours": SurvivalUtil.num(lb.get("hours"), 2.0), "job": str(lb.get("job", ""))},
				"due": {"days": LABOUR_DUE_DAYS}})
	elif ask.has("favour"):
		# A favour is a couple of hours of the mentor's chores, owed like labour.
		mine.append({"kind": "service", "service": "labour", "terms": {"hours": FAVOUR_HOURS, "job": "a favour"},
				"due": {"days": LABOUR_DUE_DAYS}})
	# The lesson is owed for LESSON_DUE_DAYS: cut short (the mentor gone), it resumes at the next meeting; never given,
	# the trade is void and the ask comes back (void_unfulfilled_lesson).
	var r1 := set_lines(core, tr, npc, [{"kind": "service", "service": "lesson", "terms": {"what": what}, "due": {"days": LESSON_DUE_DAYS}}])
	if not bool(r1.ok):
		cancel(core, tr, str(r1.reason))
		return r1
	var r2 := set_lines(core, tr, me, mine)
	if not bool(r2.ok):
		cancel(core, tr, str(r2.reason))
		return r2
	session(core, tr).confirmed[npc] = int(session(core, tr).version)
	var c := confirm(core, tr, me, int(session(core, tr).version))
	if not bool(c.get("committed", false)):
		cancel(core, tr, str(c.get("reason", "")))
		return {"ok": false, "reason": str(c.get("reason", "the lesson could not be agreed"))}
	var out := {"ok": true, "tr": tr, "lesson_ob": "", "labour_ob": ""}
	for ob_id in SurvivalUtil.arr(c.get("obligations")):
		var ob := obligation(core, str(ob_id))
		if str(ob.kind) == "lesson":
			out.lesson_ob = str(ob_id)
		elif str(ob.kind) == "labour":
			out.labour_ob = str(ob_id)
	if ask.has("first_refusal"):
		# First refusal on prime pelts: bring this partner pelts before anyone else within FIRST_REFUSAL_DAYS.
		out["first_refusal_ob"] = add_obligation(core, me, npc, "first_refusal",
				{"terms": {"what": "first refusal on prime pelts"}, "due": {"days": FIRST_REFUSAL_DAYS}}, tr)
	return out


# ---------------------------------------------------------------- obligations (world state, keyed by both parties)
static func obligation(core: SurvivalCore, ob_id: String) -> Dictionary:
	return SurvivalUtil.dict(_obs(core).get(ob_id))


static func add_obligation(core: SurvivalCore, from: String, to: String, kind: String, line: Dictionary, tr_id: String = "") -> String:
	var id := _next_id(core, "ob")
	var due := SurvivalUtil.dict(line.get("due"))
	var due_min := core.state.minutes + SurvivalUtil.num(due.get("days"), 3.0) * SurvivalClock.MIN_PER_DAY
	if due.has("day_id"):
		due_min = SurvivalClock.minutes_at(core, str(due.day_id), SurvivalClock.year(core) + (1 if SurvivalClock.day_index_of(core, str(due.day_id)) < SurvivalClock.day_of_year(core) else 0), 23.99)
	var what := {}
	match kind:
		"labour":
			what = {"hours": SurvivalUtil.num(SurvivalUtil.dict(line.get("terms")).get("hours"), 1.0), "job": str(SurvivalUtil.dict(line.get("terms")).get("job", ""))}
		"lesson":
			what = {"what": str(SurvivalUtil.dict(line.get("terms")).get("what", ""))}
		"loan":
			what = SurvivalUtil.dict(line.get("terms")).duplicate(true)
		"promise":
			what = {"owes": SurvivalUtil.dict(line.get("owes")).duplicate(true)}
		_:
			what = SurvivalUtil.dict(line.get("terms")).duplicate(true)
	_obs(core)[id] = {"id": id, "from": from, "to": to, "kind": kind, "what": what, "due_min": due_min,
			"due_played_days": SurvivalUtil.num(due.get("days"), 3.0), "status": "open", "tr": tr_id, "progress": 0.0,
			"created": core.state.minutes}
	core._on_obligation_changed(id, "open")
	return id


## Every obligation naming a party (the ledger page is a view of these).
static func obligations_of(core: SurvivalCore, party: String, only_open: bool = false) -> Array:
	var out := []
	for id in SurvivalUtil.sorted_ids(_obs(core)):
		var ob: Dictionary = _obs(core)[id]
		if (str(ob.from) == party or str(ob.to) == party) and (not only_open or str(ob.status) == "open"):
			out.append(ob)
	return out


static func _close(core: SurvivalCore, ob: Dictionary, status: String) -> void:
	if str(ob.status) != "open":
		return
	ob["status"] = status
	ob["closed"] = core.state.minutes
	var debtor := str(ob.from)
	var creditor := str(ob.to)
	var npc := creditor if not is_player(creditor) else (debtor if not is_player(debtor) else "")
	var src := SurvivalUtil.dict(core.data.section("npcs", "standing"))
	var trust_cfg := SurvivalUtil.dict(src.get("trust"))
	if is_local(core, debtor) and npc != "" and status != "void":
		var fac := faction_of(core, npc)
		if status == "kept":
			if str(ob.kind) == "labour":
				SurvivalEconomy.add_standing(core, fac, SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(src.get("sources")).get("labour_given")).get("value"), 0.5) \
						* SurvivalUtil.num(SurvivalUtil.dict(ob.what).get("hours"), 1.0), "labour_given")
				add_trust(core, npc, SurvivalUtil.num(SurvivalUtil.dict(trust_cfg.get("sources")).get("labour_kept"), 1.0), "labour_kept")
				SurvivalSkills.record_labour_kept(core)
			elif str(ob.kind) in ["promise", "loan", "first_refusal"]:
				SurvivalEconomy.add_standing(core, fac, SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(src.get("sources")).get("obligation_kept")).get("value"), 3.0), "obligation_kept")
				add_trust(core, npc, SurvivalUtil.num(SurvivalUtil.dict(trust_cfg.get("sources")).get("promise_kept"), 1.0), "promise_kept")
				SurvivalSkills.record_promise_kept(core)
		elif status == "broken":
			SurvivalEconomy.add_standing(core, fac, SurvivalUtil.num(SurvivalUtil.dict(src.get("penalties")).get("missed_obligation"), -5.0))
			var key := "labour_broken" if str(ob.kind) == "labour" else "promise_broken"
			add_trust(core, npc, SurvivalUtil.num(SurvivalUtil.dict(trust_cfg.get("penalties")).get(key), -2.0), key)
		core.state.stats["obligations_" + status] = int(SurvivalUtil.num(core.state.stats.get("obligations_" + status), 0.0)) + 1
	core.log_line("%s %s: %s" % [str(ob.kind).capitalize().replace("_", " "), status, _ob_text(core, ob)], "duty")
	core._on_obligation_changed(str(ob.id), status)


static func _ob_text(core: SurvivalCore, ob: Dictionary) -> String:
	var w := SurvivalUtil.dict(ob.what)
	match str(ob.kind):
		"labour":
			return "%s game hours for %s" % [SurvivalEconomy._qty_s(SurvivalUtil.num(w.get("hours"), 0.0)), _title(core, str(ob.to))]
		"lesson":
			return "%s's lesson" % _title(core, str(ob.from))
		"promise":
			return "owed to %s" % _title(core, str(ob.to))
		"first_refusal":
			return "first refusal on prime pelts to %s" % _title(core, str(ob.to))
	return str(ob.kind)


## Where labour owed is worked: the job's place (livelihoods.json jobs[].where), else the creditor's place of work or
## home when it is a POI, else a guest player's location; "" when nothing names one.
static func labour_place(core: SurvivalCore, ob: Dictionary) -> String:
	var job := SurvivalUtil.dict(core.data.jobs.get(str(SurvivalUtil.dict(ob.get("what")).get("job", ""))))
	if str(job.get("where", "")) != "":
		return str(job.where)
	var cred := str(ob.get("to", ""))
	if is_player(cred):
		return str(SurvivalUtil.dict(core.state.players.get(cred)).get("location", ""))
	var ind := SurvivalUtil.dict(core.data.individuals.get(cred))
	for k in ["work", "home"]:
		var loc := str(ind.get(k, ""))
		if loc.begins_with("poi."):
			return loc
	return ""


## Work off labour owed (the debtor is the local player), at the place the work is done, awake and not busy with another
## job: time passes at heavy work, at most what is still owed. The obligation is kept only when every hour owed has been
## worked. Returns {ok, reason, worked_min, done}.
static func work_off(core: SurvivalCore, ob_id: String, minutes: float) -> Dictionary:
	var ob := obligation(core, ob_id)
	if ob.is_empty() or str(ob.status) != "open" or str(ob.kind) != "labour":
		return {"ok": false, "reason": "no labour owed"}
	if not is_local(core, str(ob.from)):
		return {"ok": false, "reason": "not your labour"}
	if minutes <= 0.0:
		return {"ok": false, "reason": "no time given to the work"}
	if SurvivalJobs.is_running(core):
		return {"ok": false, "reason": "busy with %s" % str(SurvivalJobs.current(core).get("action", ""))}
	if core.is_dead() or core.state.asleep or core.is_passed_out():
		return {"ok": false, "reason": "not able to work now"}
	var place := labour_place(core, ob)
	if place != "" and str(core.state.context.get("location", "")) != place:
		return {"ok": false, "reason": "the work is done at %s" % core.npc_title(place)}
	var total := SurvivalUtil.num(SurvivalUtil.dict(ob.what).get("hours"), 0.0) * 60.0
	var left := total - SurvivalUtil.num(ob.get("progress"), 0.0)
	if left <= 0.01:
		_close(core, ob, "kept")
		return {"ok": true, "worked_min": 0.0, "done": true}
	var m := minf(minutes, left)
	var act := core.state.activity
	core.set_activity("heavy_work")
	var done := core.advance(m)
	core.set_activity(act)
	ob["progress"] = SurvivalUtil.num(ob.get("progress"), 0.0) + done
	var finished := SurvivalUtil.num(ob.progress, 0.0) >= total - 0.01
	if finished:
		_close(core, ob, "kept")
	return {"ok": true, "worked_min": done, "done": finished}


## Deliver a promise (goods or coin owed) to its creditor, who must be here. Returns {ok, reason}.
static func deliver(core: SurvivalCore, ob_id: String) -> Dictionary:
	var ob := obligation(core, ob_id)
	if ob.is_empty() or str(ob.status) != "open" or str(ob.kind) != "promise":
		return {"ok": false, "reason": "no promise owed"}
	var to := str(ob.to)
	if not partner_present(core, to):
		return {"ok": false, "reason": "%s %s not here" % [_title(core, to), _be(core, to)]}
	var owes := SurvivalUtil.dict(SurvivalUtil.dict(ob.what).get("owes"))
	if owes.has("pence"):
		var pence := SurvivalUtil.num(owes.pence, 0.0)
		if money_of(core, str(ob.from)) < int(pence):
			return {"ok": false, "reason": "not enough coin"}
		# Coin paid out by the local player is coin spent (T1's measure), like any other payment.
		if is_local(core, str(ob.from)):
			SurvivalEconomy._spend_money(core, pence)
		else:
			_add_money(core, str(ob.from), -pence)
		if is_player(to):
			_add_money(core, to, pence)
	else:
		for it in owes.keys():
			if SurvivalInventory.count_usable_in(core, _stacks_of_party(core, str(ob.from)), str(it)) < SurvivalUtil.num(owes[it], 0.0) - 0.0001:
				return {"ok": false, "reason": "not enough %s" % core.data.item_name(str(it)).to_lower()}
		for it in owes.keys():
			var parts := SurvivalInventory.take_for_trade(core, _stacks_of_party(core, str(ob.from)), str(it), SurvivalUtil.num(owes[it], 0.0), "", is_local(core, str(ob.from)))
			for st in parts:
				_give(core, to, str(st.id), float(st.qty), SurvivalUtil.dict(st.get("meta")), "")
	_close(core, ob, "kept")
	return {"ok": true}


## The lesson job finished: the mentor's lesson obligation is kept.
static func lesson_given(core: SurvivalCore, ob_id: String) -> void:
	var ob := obligation(core, ob_id)
	if not ob.is_empty():
		_close(core, ob, "kept")


## A lesson agreed and never given (the mentor was gone each time): the trade is void. The learner's labour or favour
## owed for it is void (no trust lost), and goods and coin given for it come back from the mentor.
static func void_unfulfilled_lesson(core: SurvivalCore, ob: Dictionary) -> void:
	if str(ob.get("status", "")) != "open" or str(ob.get("kind", "")) != "lesson":
		return
	var tr := str(ob.get("tr", ""))
	var npc := str(ob.from)
	var learner := str(ob.to)
	_close(core, ob, "void")
	for other in obligations_of(core, learner, true):
		if str(other.get("tr", "")) == tr and str(other.id) != str(ob.id):
			_close(core, other, "void")
	for e in SurvivalUtil.arr(_t(core).get("ledger")):
		if str(e.get("tr", "")) != tr:
			continue
		for line in SurvivalUtil.arr(SurvivalUtil.dict(e.get("lines")).get(learner)):
			match str(line.get("kind", "")):
				"item":
					var it := str(line.get("item_id", ""))
					var q := SurvivalUtil.num(line.get("qty"), 0.0)
					_stock_add(core, npc, it, -q)
					_give(core, learner, it, q, {}, "")
				"coin":
					_add_money(core, learner, SurvivalUtil.num(line.get("pence"), 0.0))
		e["void"] = true
	core.log_line("%s could not give the lesson: the agreement is void and your side of it comes back" % _title(core, npc).capitalize(), "duty")


## A promise to keep, made at creation (start.promise, M2b).
static func add_start_promise(core: SurvivalCore, promise: Dictionary) -> String:
	var line := {"owes": SurvivalUtil.dict(promise.get("goods")).duplicate(), "due": {"day_id": str(promise.get("due_day", "feb_late"))}}
	return add_obligation(core, core.state.player_id, str(promise.get("to", "")), "promise", line, "start")


## A new game day (at the midnight day boundary): obligations past due are broken (a lesson never given is void
## instead); open trade windows close; the soldiers' issue and the old hunter's stock come monthly.
static func on_day_started(core: SurvivalCore) -> void:
	# Lessons first: a lesson never given voids the labour or goods asked for it before that labour could count as broken.
	for pass_i in 2:
		for id in SurvivalUtil.sorted_ids(_obs(core)):
			var ob: Dictionary = _obs(core)[id]
			var due_at := SurvivalUtil.num(ob.get("due_min"), -1.0)
			if str(ob.status) != "open" or str(ob.kind) == "credit" or due_at < 0.0 or core.state.minutes <= due_at:
				continue
			if pass_i == 0 and str(ob.kind) == "lesson":
				void_unfulfilled_lesson(core, ob)
			elif pass_i == 1:
				_close(core, ob, "broken")
	var t := _t(core)
	var month := "%d|%s" % [SurvivalClock.year(core), SurvivalClock.month_id(core)]
	for npc in partners(core):
		if market_of(core, str(npc)) == "" and str(t.restock.get(npc, "")) != month:
			t.restock[npc] = month
			var st := npc_stock(core, str(npc))
			for it in SurvivalUtil.dict(behaviour(core, str(npc)).get("stock_per_month")).keys():
				st[it] = maxf(SurvivalUtil.num(st.get(it), 0.0), SurvivalUtil.num(behaviour(core, str(npc)).stock_per_month[it], 0.0))


## Credit books are obligations too (kind credit), kept in step with the accounts the credit year keeps.
static func sync_credit(core: SurvivalCore, creditor: String, balance_d: float, due_event: String) -> void:
	var found := {}
	for ob in obligations_of(core, core.state.player_id, true):
		if str(ob.kind) == "credit" and str(ob.to) == creditor:
			found = ob
	if balance_d > 0.5:
		if found.is_empty():
			var id := _next_id(core, "ob")
			_obs(core)[id] = {"id": id, "from": core.state.player_id, "to": creditor, "kind": "credit",
					"what": {"balance_d": balance_d, "due_event": due_event}, "due_min": -1.0, "status": "open", "tr": "",
					"progress": 0.0, "created": core.state.minutes}
			core._on_obligation_changed(id, "open")
		else:
			found.what["balance_d"] = balance_d
	elif not found.is_empty():
		found.what["balance_d"] = 0.0


## The settlement graded a book: the credit obligation is kept (paid in full) or broken (unpaid); part paid rolls over.
static func grade_credit(core: SurvivalCore, creditor: String, grade: String) -> void:
	for ob in obligations_of(core, core.state.player_id, true):
		if str(ob.kind) == "credit" and str(ob.to) == creditor:
			if grade == "paid_in_full":
				ob["status"] = "kept"
				core._on_obligation_changed(str(ob.id), "kept")
			elif grade == "unpaid":
				ob["status"] = "broken"
				core._on_obligation_changed(str(ob.id), "broken")


# ---------------------------------------------------------------- trust (per player, per individual)
## A player's trust with an individual (pid: the player record; the local player by default).
static func trust(core: SurvivalCore, npc: String, pid: String = "") -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(_player_rec(core, pid).get("trust")).get(npc), 0.0)


static func _player_rec(core: SurvivalCore, pid: String) -> Dictionary:
	if pid == "" or pid == core.state.player_id:
		return core.player()
	return SurvivalUtil.dict(core.state.players.get(pid))


static func add_trust(core: SurvivalCore, npc: String, delta: float, source: String = "", pid: String = "") -> float:
	var p := _player_rec(core, pid)
	if p.is_empty():
		return 0.0
	if not p.has("trust"):
		p["trust"] = {}
	var cfg := SurvivalUtil.dict(core.data.section("npcs", "standing").get("trust"))
	var d := delta
	if source == "fair_trade" and d > 0.0:
		if not p.has("trust_log"):
			p["trust_log"] = {}
		var key := "%s|%d|%s" % [npc, SurvivalClock.year(core), SurvivalClock.month_id(core)]
		var used := SurvivalUtil.num(p.trust_log.get(key), 0.0)
		d = minf(d, maxf(0.0, SurvivalUtil.num(cfg.get("cap_fair_trade_per_game_month"), 1.0) - used))
		p.trust_log[key] = used + d
	var r := SurvivalUtil.pair(cfg.get("range"), 10.0)
	var old := trust(core, npc, pid)
	var nv := clampf(old + d, minf(r.x, r.y), maxf(r.x, r.y))
	p.trust[npc] = nv
	if absf(nv - old) > 0.0001 and (pid == "" or pid == core.state.player_id):
		core._on_trust_changed(npc, nv)
	return nv - old


# ---------------------------------------------------------------- what a client may see
## The window's view for one party: its own and the other side's lines, a cue per line and for the deal, each player's
## load after the trade; numbers (value to the partner and the floor) only from Adept Trade or with the ledger toggle.
## It costs about 0.3 ms (it evaluates the deal): a UI refreshes it on trade and inventory events, never every frame.
static func view(core: SurvivalCore, tr_id: String, party: String) -> Dictionary:
	var s := session(core, tr_id)
	if s.is_empty():
		return {}
	var out := {"tr": tr_id, "version": int(s.version), "parties": s.parties.duplicate(), "state": str(s.state),
			"lines": {}, "confirmed": s.confirmed.duplicate()}
	for p in s.parties:
		out.lines[p] = _plain_lines(s.lines[p])
	# Each player's load after the trade (GDD 11.2 and 11.5), and the carry limit the commit applies.
	var loads := {}
	for p in s.parties:
		if is_player(str(p)):
			var other: String = str(s.parties[1]) if str(p) == str(s.parties[0]) else str(s.parties[0])
			loads[p] = snappedf(_load_after(core, s, str(p), other), 0.1)
	out["load_after_kg"] = loads
	out["max_kg"] = SurvivalUtil.num(core.data.section("needs", "load").get("max_kg"), 60.0)
	var npc := str(s.get("npc", ""))
	if npc != "" and is_player(party):
		var ev := evaluate(core, tr_id)
		out["cue"] = str(ev.get("cue", ""))
		out["line_cues"] = SurvivalUtil.arr(ev.get("line_cues"))
		var cues := SurvivalUtil.dict(barter_cfg(core).get("cues"))
		var rev := SurvivalUtil.dict(cues.get("reveal"))
		var t := SurvivalSkills.level(core, "trade")
		out["bar"] = t >= SurvivalSkills.tier_min(core, str(rev.get("bar_from", "apprentice")))
		out["wants_shown"] = t >= SurvivalSkills.tier_min(core, str(rev.get("wants_from", "journeyman")))
		if t >= SurvivalSkills.tier_min(core, str(rev.get("numbers_from", "adept"))):
			out["numbers"] = {"value_to_them": float(ev.get("value_in", 0.0)), "their_floor": float(ev.get("required", 0.0))}
		elif bool(core.setting("ledger_toggle", false)):
			var rvs := 0.0
			for l in SurvivalUtil.arr(s.lines[party]):
				rvs += _line_rv(core, l)
			out["numbers"] = {"rv_of_your_lines": rvs}
		if not ev.get("counter", {}).is_empty():
			out["counter"] = str(SurvivalUtil.dict(ev.get("counter")).get("text", ""))
	return out


## "What are you short of?" (the trade.needs topic): the partner's wants this month with a reason, and what it keeps.
static func needs_panel(core: SurvivalCore, npc: String) -> Dictionary:
	var wants := []
	for row in SurvivalUtil.arr(behaviour(core, npc).get("wants")):
		if not _in_months(core, row):
			continue
		for it in SurvivalUtil.arr(row.get("items")):
			wants.append({"item": str(it), "tier": want_tier(core, npc, str(it)), "reason": str(row.get("reason", ""))})
		for c in SurvivalUtil.arr(row.get("cats")):
			wants.append({"cat": str(c), "tier": str(row.get("tier", "")), "reason": str(row.get("reason", ""))})
	var keeps := []
	for it in npc_stock(core, npc).keys():
		if unit_out(core, npc, str(it)) > 0.0:
			keeps.append({"item": str(it), "qty": SurvivalUtil.num(npc_stock(core, npc)[it], 0.0)})
	return {"wants": wants, "keeps": keeps}
