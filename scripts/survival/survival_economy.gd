class_name SurvivalEconomy
extends RefCounted
## Markets, prices, books and the optional credit year (economy.json), the GDD's EconomyService. Barter between two
## parties (goods, coin, labour, lessons, promises) is SurvivalTrade's; this module keeps the coin-and-book counter, the
## firewood contract, the credit year for players who open a book, and market stock (world state).
##
## Accounts are in whole pence of New York currency (8 s, 96 d, to the Spanish dollar). Every good has two layers: a
## cash price (valley retail; the sutler adds carriage) and a barter tariff in beaver (1 beaver = 1.5 bucks = 144 d).
##   cash buy   = cash_retail * markup * season(profile, month) * scarcity * (1 + spread_eff)
##   spread_eff = clamp(spread + tier_adj(standing) - 0.10 * Trade/100, 0.10, 0.6) * trade_price_mult (drink)
## The sutler's barter window uses the same price (SurvivalTrade.unit_out "cash_price" and terms), so coin buys the same
## at her counter and in the window.
##   barter     = beaver * 144 (x prime, grade and condition for furs)
## The trader pays in goods, book credit at barter value, or coin at 0.6 of it; the sutler buys furs any day for coin
## at 0.6 of their cash value and takes a little venison and jerky through the garrison's one meat channel.
## Income anywhere is compared in cash-equivalent pence (barter x the coin rate), as the design does.

const TRADER_ID := "npc.post.trader"
const SUTLER_ID := "npc.fort.sutler"
const COUNTY_ID := "county.militia"
## Split-wood armloads to a stacked cord at the fort woodpile [D: a Woodcraft-0 worker stacks about 4 cords a game day].
const ARMLOADS_PER_CORD := 8.0
const PRESETS := ["settler", "woodsman", "hard_winter", "ironman"]


static func _e(core: SurvivalCore) -> Dictionary:
	return core.state.economy


## A new character's purse, books and obligations. variant: a start variant row (backgrounds.json start_variants); the
## default, Clear, owes nothing. Credit is optional: the fall outfit stays on offer every Mid September.
static func init(core: SurvivalCore, bg: Dictionary, variant: Dictionary = {}) -> void:
	var e := _e(core)
	e["money_d"] = int(SurvivalUtil.num(bg.get("starting_money_d"), 0.0))
	e["accounts"] = {}
	e["stock"] = {}
	e["last_restock_day"] = {}
	e["standing"] = {}
	e["standing_log"] = {}
	e["meat_sold"] = {}
	e["visit_trade"] = {}
	e["contract"] = {"cords": 0, "armloads": 0.0, "open": false, "season_year": -1}
	e["obligations"] = []
	e["collection"] = {}
	e["income"] = {"coin_d": 0.0, "barter_d": 0.0, "ce_d": 0.0, "wages_d": 0.0}
	e["steel_cap"] = {}
	for f in SurvivalUtil.dict(bg.get("standing")).keys():
		e.standing[f] = SurvivalUtil.num(bg.standing[f], 0.0)
	# The trader's book: last season's balance and this season's outfit limit.
	_account(core, TRADER_ID, "barter")["outfit_limit_d"] = SurvivalUtil.num(SurvivalUtil.dict(bg.get("credit")).get("first_outfit_limit_barter_d"), 800.0)
	_account(core, SUTLER_ID, "cash")
	var debt := SurvivalUtil.dict(variant.get("debt"))
	if not debt.is_empty():
		var cred := str(debt.get("creditor", TRADER_ID))
		var layer := str(debt.get("layer", "barter"))
		var amt := SurvivalUtil.num(debt.get("amount_barter_d", debt.get("amount_d", 0.0)), 0.0)
		var acct := _account(core, cred, layer)
		acct["due_event"] = str(debt.get("due_event", "event.spring_trade"))
		_change_balance(core, cred, amt, "carried debt (%s)" % str(variant.get("name", "start")))
	if variant.has("sutler_limit_d"):
		e["sutler_limit_d"] = SurvivalUtil.num(variant.sutler_limit_d, 240.0)
	var ob := SurvivalUtil.dict(bg.get("obligation"))
	if not ob.is_empty():
		e.obligations.append({"kind": str(ob.get("kind", "")), "due_event": str(ob.get("due_event", "")),
				"miss_standing": SurvivalUtil.dict(ob.get("miss_standing")).duplicate(), "miss_fine_d": SurvivalUtil.num(ob.get("miss_fine_d"), 0.0),
				"status": "pending"})
	for mid in core.data.markets.keys():
		restock(core, str(mid))


static func money(core: SurvivalCore) -> int:
	return int(SurvivalUtil.num(_e(core).get("money_d"), 0.0))


static func _add_money(core: SurvivalCore, d: float) -> void:
	var e := _e(core)
	e["money_d"] = int(round(SurvivalUtil.num(e.get("money_d"), 0.0) + d))
	core._on_money_changed(int(e.money_d))


## Coin the player pays out (the self-sufficiency measure: T1's "coin spent 0"). Trade escrow counts at the commit.
static func _spend_money(core: SurvivalCore, d: float) -> void:
	_add_money(core, -d)
	core.state.stats["coin_spent"] = SurvivalUtil.num(core.state.stats.get("coin_spent"), 0.0) + d


static func _account(core: SurvivalCore, creditor: String, layer: String = "") -> Dictionary:
	var accts: Dictionary = _e(core).accounts
	if not accts.has(creditor):
		accts[creditor] = {"creditor": creditor, "layer": layer if layer != "" else "cash", "balance_d": 0.0,
				"due_event": "event.spring_trade", "history": [], "season_sales_d": 0.0, "outfit_charged_d": 0.0}
	return accts[creditor]


static func account(core: SurvivalCore, creditor: String) -> Dictionary:
	return SurvivalUtil.dict(SurvivalUtil.dict(_e(core).get("accounts")).get(creditor))


## What the player owes a creditor (negative: the creditor owes the player, e.g. book credit at the trader).
static func balance(core: SurvivalCore, creditor: String) -> float:
	return SurvivalUtil.num(account(core, creditor).get("balance_d"), 0.0)


static func total_debt(core: SurvivalCore) -> float:
	var t := 0.0
	for a in SurvivalUtil.dict(_e(core).get("accounts")).values():
		t += maxf(0.0, SurvivalUtil.num(a.get("balance_d"), 0.0))
	return t


static func _history(core: SurvivalCore, creditor: String, what: String, amount: float) -> void:
	var a := _account(core, creditor)
	var h: Array = a.history
	h.append({"t": core.state.minutes, "date": SurvivalClock.date_string(core), "what": what, "d": amount,
			"balance": SurvivalUtil.num(a.get("balance_d"), 0.0)})
	while h.size() > 60:
		h.remove_at(0)
	core._on_account_changed(creditor, SurvivalUtil.num(a.get("balance_d"), 0.0))


static func _change_balance(core: SurvivalCore, creditor: String, delta: float, what: String) -> void:
	var a := _account(core, creditor)
	a["balance_d"] = SurvivalUtil.num(a.get("balance_d"), 0.0) + delta
	_history(core, creditor, what, delta)
	# A book is a credit obligation too (SurvivalTrade), kept in step with the account.
	SurvivalTrade.sync_credit(core, creditor, SurvivalUtil.num(a.get("balance_d"), 0.0), str(a.get("due_event", "")))


## Income in both layers and in cash-equivalent pence (barter x the coin rate), also by kind of good (pelt, skin,
## meat_raw, wage, ...) for the livelihood ladder.
static func _income(core: SurvivalCore, coin: float, barter: float, kind: String = "") -> void:
	var inc: Dictionary = _e(core).income
	inc["coin_d"] = SurvivalUtil.num(inc.get("coin_d"), 0.0) + coin
	inc["barter_d"] = SurvivalUtil.num(inc.get("barter_d"), 0.0) + barter
	var ce := coin + barter * coin_rate(core)
	inc["ce_d"] = SurvivalUtil.num(inc.get("ce_d"), 0.0) + ce
	if kind != "":
		if not inc.has("by_cat"):
			inc["by_cat"] = {}
		inc.by_cat[kind] = SurvivalUtil.num(inc.by_cat.get(kind), 0.0) + ce


static func coin_rate(core: SurvivalCore) -> float:
	return SurvivalUtil.num(core.data.section("economy", "settlement").get("coin_rate"), 0.6)


static func beaver_d(core: SurvivalCore) -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("economy", "currency")).get("units")).get("beaver_d"), 144.0)


# ---------------------------------------------------------------- markets
static func creditor_for(core: SurvivalCore, mkt_id: String) -> String:
	var arch := str(core.data.market(mkt_id).get("npc", ""))
	for ind in core.data.individuals.values():
		if str(ind.get("archetype", "")) == arch:
			return str(ind.id)
	return mkt_id


static func is_open(core: SurvivalCore, mkt_id: String) -> bool:
	var m := core.data.market(mkt_id)
	if m.is_empty():
		return false
	var op = m.get("open")
	if typeof(op) == TYPE_STRING:
		return str(op) == "all_year"
	for ev in SurvivalUtil.arr(op):
		if SurvivalClock.event_active(core, str(ev)):
			return true
	return false


## Each market's standing faction and the player's standing with it.
static func standing(core: SurvivalCore, faction: String) -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(_e(core).get("standing")).get(faction), 0.0)


static func standing_tier(core: SurvivalCore, faction: String) -> String:
	var v := standing(core, faction)
	for t in SurvivalUtil.arr(core.data.section("npcs", "standing").get("tiers")):
		if v <= SurvivalUtil.num(t.get("max"), 100.0):
			return str(t.id)
	return "trusted"


## Add standing from a named source with its per-game-month cap and ceiling (npcs.json standing.sources).
static func add_standing(core: SurvivalCore, faction: String, value: float, source: String = "") -> float:
	var e := _e(core)
	var src := SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("sources")).get(source))
	var v := value
	if not src.is_empty() and src.has("cap_per_game_month"):
		var key := "%s|%s|%d|%s" % [faction, source, SurvivalClock.year(core), SurvivalClock.month_id(core)]
		var used := SurvivalUtil.num(SurvivalUtil.dict(e.standing_log).get(key), 0.0)
		v = clampf(value, 0.0, maxf(0.0, SurvivalUtil.num(src.cap_per_game_month) - used))
		e.standing_log[key] = used + v
	var cur := standing(core, faction)
	var nv := cur + v
	if src.has("ceiling") and v > 0.0:
		nv = minf(nv, maxf(cur, SurvivalUtil.num(src.ceiling)))
	var r := SurvivalUtil.pair(core.data.section("npcs", "standing").get("range"), 100.0)
	nv = clampf(nv, minf(r.x, r.y), maxf(r.x, r.y))
	e.standing[faction] = nv
	if absf(nv - cur) > 0.0001:
		core._on_standing_changed(faction, nv)
	return nv - cur


static func restock(core: SurvivalCore, mkt_id: String) -> void:
	var m := core.data.market(mkt_id)
	var st := {}
	var sbe := SurvivalUtil.dict(m.get("stock_by_event"))
	var ev_stock := {}
	for ev in sbe.keys():
		if SurvivalClock.event_active(core, str(ev)):
			ev_stock = SurvivalUtil.dict(sbe[ev])
	for it in SurvivalUtil.arr(m.get("sells")):
		st[it] = SurvivalUtil.num(ev_stock.get(it), 0.0) if not sbe.is_empty() else stock_target(core, mkt_id, str(it))
	_e(core).stock[mkt_id] = st
	_e(core).last_restock_day[mkt_id] = SurvivalClock.abs_day(core)


static func stock_target(core: SurvivalCore, mkt_id: String, item_id: String) -> float:
	var tgt := SurvivalUtil.dict(core.data.market(mkt_id).get("stock_target"))
	var v := SurvivalUtil.num(tgt.get(item_id, tgt.get("default", 10.0)), 10.0)
	# A paid-in-full settlement raises the trader's steel-trap cap for this hunter from 4 to 8 (economy.json credit.grading).
	if item_id == "item.trap.steel" and SurvivalUtil.num(SurvivalUtil.dict(_e(core).get("steel_cap")).get(mkt_id), 0.0) > 0.0:
		v = SurvivalUtil.num(_e(core).steel_cap[mkt_id], v)
	return v


static func stock_of(core: SurvivalCore, mkt_id: String, item_id: String) -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(_e(core).get("stock")).get(mkt_id)).get(item_id), 0.0)


static func season_mult(core: SurvivalCore, item_id: String) -> float:
	var prof := str(core.data.good(item_id).get("profile", "flat"))
	var pp := SurvivalUtil.dict(core.data.section("economy", "price_profiles").get(prof))
	return SurvivalUtil.num(pp.get(SurvivalClock.month_id(core)), 1.0)


static func scarcity(core: SurvivalCore, mkt_id: String, item_id: String) -> float:
	var tgt := stock_target(core, mkt_id, item_id)
	var st := stock_of(core, mkt_id, item_id)
	return clampf(sqrt(tgt / maxf(1.0, st)), 0.8, 1.6)


## The counter's margin: the market's spread, the standing tier's adjustment (economy.json barter.tier_adj), the
## player's Trade, and drink. The sutler's barter window uses the same terms.
static func spread_eff(core: SurvivalCore, mkt_id: String) -> float:
	var m := core.data.market(mkt_id)
	var trade := SurvivalSkills.level(core, "trade")
	var fac := str(m.get("faction", ""))
	var ta := SurvivalUtil.num(SurvivalUtil.dict(core.data.section("economy", "barter").get("tier_adj")).get(standing_tier(core, fac)), 0.0)
	var disc := SurvivalUtil.num(core.data.section("economy", "barter").get("trade_skill_discount_at_100"), 0.10)
	var s := clampf(SurvivalUtil.num(m.get("spread"), 0.2) + ta - disc * trade / 100.0, 0.10, 0.6)
	return s * SurvivalUtil.num(core.get_modifiers().get("trade_price_mult"), 1.0)


## Is the market selling this item this month? (the sutler sells out of winter clothing by November: sells_months)
static func sold_now(core: SurvivalCore, mkt_id: String, item_id: String) -> bool:
	var m := core.data.market(mkt_id)
	if not SurvivalUtil.arr(m.get("sells")).has(item_id):
		return false
	var sm := SurvivalUtil.arr(SurvivalUtil.dict(m.get("sells_months")).get(item_id))
	return sm.is_empty() or sm.has(SurvivalClock.month_id(core))


## Unit price to buy from a market in its own layer: {ok, unit_d, layer, reason}.
static func buy_unit(core: SurvivalCore, mkt_id: String, item_id: String) -> Dictionary:
	var m := core.data.market(mkt_id)
	var g := core.data.good(item_id)
	if m.is_empty() or g.is_empty() or not SurvivalUtil.arr(m.get("sells")).has(item_id):
		return {"ok": false, "reason": "not sold here"}
	if str(m.get("price_layer", "cash")) == "valuation":
		return {"ok": false, "reason": "they trade goods for goods in the trade window"}
	if not sold_now(core, mkt_id, item_id):
		return {"ok": false, "reason": "sold out until the river opens"}
	if str(m.get("price_layer", "cash")) == "barter":
		var b := SurvivalUtil.dict(g.get("barter"))
		if b.is_empty():
			return {"ok": false, "reason": "no tariff"}
		var disc := SurvivalUtil.num(SurvivalSkills.flag(core, "trade", "tariff_spread_add", 0.0), 0.0)
		return {"ok": true, "unit_d": SurvivalUtil.num(b.get("beaver"), 0.0) * beaver_d(core) * (1.0 + disc), "layer": "barter"}
	var unit := SurvivalUtil.num(g.get("cash_retail_d"), 0.0) * SurvivalUtil.num(m.get("markup"), 1.0) * season_mult(core, item_id) \
			* scarcity(core, mkt_id, item_id) * (1.0 + spread_eff(core, mkt_id))
	return {"ok": true, "unit_d": unit, "layer": "cash"}


## The value factor of a pelt or skin stack: prime (fur pelts only) x grade x condition x any value multiplier.
static func stack_value_factor(core: SurvivalCore, st: Dictionary) -> float:
	var m := SurvivalUtil.dict(st.get("meta"))
	var it := core.data.item(str(st.id))
	var f := SurvivalInventory.grade_factor(core, str(m.get("grade", "good")))
	if bool(m.get("slipped", false)):
		f *= SurvivalUtil.num(SurvivalUtil.dict(core.data.section("items", "pelt_rules").get("slipped")).get("extra_mult"), 0.3)
	var cats := SurvivalUtil.arr(core.data.section("items", "pelt_rules").get("prime_applies_to_cats"))
	if cats.has(str(it.get("cat", ""))):
		f *= SurvivalUtil.num(m.get("prime"), 1.0)
	f *= SurvivalUtil.num(m.get("condition"), 1.0) * SurvivalUtil.num(m.get("value_mult"), 1.0)
	if bool(m.get("green", false)):
		f *= 0.5
	return f


## The prime factor of a species' pelt in a month (seasons.json pelt_prime_by_species; fur pelts only).
static func prime_factor(core: SurvivalCore, species: String, month: String) -> float:
	var pb := core.data.section("seasons", "pelt_prime_by_species")
	var row := SurvivalUtil.dict(pb.get(species, pb.get("default", {})))
	return SurvivalUtil.num(row.get(month), 1.0)


## What a market pays for one unit of a stack: {ok, unit_d, layer, channel, reason}.
static func sell_unit(core: SurvivalCore, mkt_id: String, st: Dictionary) -> Dictionary:
	var m := core.data.market(mkt_id)
	var id := str(st.get("id", ""))
	var it := core.data.item(id)
	var g := core.data.good(id)
	var buys := SurvivalUtil.dict(m.get("buys"))
	var cat := str(it.get("cat", ""))
	var meat := SurvivalUtil.dict(buys.get("meat_channel"))
	if SurvivalUtil.arr(meat.get("items")).has(id):
		return {"ok": true, "unit_d": SurvivalUtil.num(SurvivalUtil.dict(meat.get("price_d")).get(id), 0.0), "layer": "cash", "channel": "meat"}
	var by_cat := SurvivalUtil.arr(buys.get("categories")).has(cat)
	var by_item := SurvivalUtil.arr(buys.get("items")).has(id)
	if not (by_cat or by_item) or g.is_empty():
		return {"ok": false, "reason": "not bought here"}
	if bool(SurvivalUtil.dict(st.get("meta")).get("green", false)):
		return {"ok": false, "reason": "dry it first"}
	var f := stack_value_factor(core, st)
	if str(m.get("price_layer", "cash")) == "barter":
		var b := SurvivalUtil.dict(g.get("barter"))
		var bonus := 1.0 + 0.08 * SurvivalSkills.level(core, "trade") / 100.0
		return {"ok": true, "unit_d": SurvivalUtil.num(b.get("beaver"), 0.0) * beaver_d(core) * f * bonus, "layer": "barter", "channel": "tariff"}
	var mult := SurvivalUtil.num(buys.get("pelt_cash_mult"), 0.6)
	return {"ok": true, "unit_d": SurvivalUtil.num(g.get("cash_retail_d"), 0.0) * mult * f, "layer": "cash", "channel": "pelts"}


## Meat-channel room left today in lb (the garrison's cap times the era's army-demand multiplier).
static func meat_room_lb(core: SurvivalCore, mkt_id: String, item_id: String) -> float:
	var meat := SurvivalUtil.dict(SurvivalUtil.dict(core.data.market(mkt_id).get("buys")).get("meat_channel"))
	var cap := SurvivalUtil.num(SurvivalUtil.dict(meat.get("caps_lb_per_game_day")).get(item_id), 0.0)
	cap *= SurvivalUtil.num(SurvivalUtil.dict(meat.get("cap_mult_by_era")).get(core.era_id()), 1.0)
	var ms := SurvivalUtil.dict(_e(core).get("meat_sold"))
	var sold := 0.0
	if int(SurvivalUtil.num(ms.get("day"), -1.0)) == SurvivalClock.abs_day(core):
		sold = SurvivalUtil.num(SurvivalUtil.dict(ms.get("lb")).get(item_id), 0.0)
	return maxf(0.0, cap - sold)


# ---------------------------------------------------------------- quotes and trades
static func quote_buy(core: SurvivalCore, mkt_id: String, item_id: String, qty: float) -> Dictionary:
	if not is_open(core, mkt_id):
		return {"ok": false, "reason": "closed"}
	var u := buy_unit(core, mkt_id, item_id)
	if not bool(u.ok):
		return u
	var avail := stock_of(core, mkt_id, item_id)
	if avail < qty - 0.0001:
		return {"ok": false, "reason": "only %d in stock" % int(avail), "unit_d": u.unit_d, "layer": u.layer}
	var total := float(round(float(u.unit_d) * qty))
	return {"ok": true, "unit_d": u.unit_d, "total_d": total, "layer": u.layer, "display": display(core, total, str(u.layer))}


## Buy. pay: "coin" (cash markets, or coin at the trader) or "book" (the trader's outfit book, the sutler's tally).
static func buy(core: SurvivalCore, mkt_id: String, item_id: String, qty: float, pay: String = "coin") -> Dictionary:
	var q := quote_buy(core, mkt_id, item_id, qty)
	if not bool(q.ok):
		return q
	var total := float(q.total_d)
	var cred := creditor_for(core, mkt_id)
	if pay == "coin":
		if money(core) < int(total):
			return {"ok": false, "reason": "not enough coin (%s)" % SurvivalUtil.lsd(total)}
		_spend_money(core, total)
	else:
		var why := _book_refusal(core, mkt_id, cred, total)
		if why != "":
			return {"ok": false, "reason": why}
		_change_balance(core, cred, total, "bought %s x%s" % [core.data.item_name(item_id), str(qty)])
		if cred == TRADER_ID:
			var a := _account(core, cred)
			a["outfit_charged_d"] = SurvivalUtil.num(a.get("outfit_charged_d"), 0.0) + total
	_e(core).stock[mkt_id][item_id] = stock_of(core, mkt_id, item_id) - qty
	SurvivalInventory.add(core, item_id, qty)
	_visit_trade(core, mkt_id, SurvivalTrade.rv(core, item_id) * qty)
	core.state.stats["bought_rv"] = SurvivalUtil.num(core.state.stats.get("bought_rv"), 0.0) + SurvivalTrade.rv(core, item_id) * qty
	core.log_line("bought %s x%s for %s" % [core.data.item_name(item_id), _qty_s(qty), display(core, total, str(q.layer))], "trade")
	return {"ok": true, "total_d": total, "layer": q.layer, "paid_with": pay}


static func _book_refusal(core: SurvivalCore, mkt_id: String, cred: String, total: float) -> String:
	var m := core.data.market(mkt_id)
	var cr := SurvivalUtil.dict(m.get("credit"))
	var a := _account(core, cred)
	if bool(a.get("no_credit", false)):
		return "no credit until the old account is settled"
	if cred == TRADER_ID:
		var lim := SurvivalUtil.num(a.get("outfit_limit_d"), 0.0) * SurvivalUtil.num(SurvivalSkills.flag(core, "trade", "credit_limit_mult", 1.0), 1.0)
		if SurvivalUtil.num(a.get("outfit_charged_d"), 0.0) + total > lim + 0.5:
			return "beyond this season's outfit (%s)" % display(core, lim, "barter")
		return ""
	var lim2 := SurvivalUtil.num(cr.get("limit_d"), 0.0)
	if str(m.get("type", "")) == "sutler" and _e(core).has("sutler_limit_d"):
		lim2 = SurvivalUtil.num(_e(core).sutler_limit_d, lim2)
	if lim2 <= 0.0:
		return "no credit here"
	if str(m.get("type", "")) == "sutler" and standing(core, str(m.get("faction", ""))) < 10.0:
		return "the sutler gives credit only to people the garrison knows"
	if SurvivalUtil.num(a.get("balance_d"), 0.0) + total > lim2 + 0.5:
		return "the tally is full (%s)" % SurvivalUtil.lsd(lim2)
	return ""


static func quote_sell(core: SurvivalCore, mkt_id: String, item_id: String, qty: float = -1.0) -> Dictionary:
	if not is_open(core, mkt_id):
		return {"ok": false, "reason": "closed"}
	var p := _sell_plan(core, mkt_id, item_id, qty)
	if not bool(p.ok):
		return p
	var total := float(p.total_d)
	var layer := str(p.layer)
	return {"ok": true, "qty": p.qty, "total_d": total, "layer": layer, "display": display(core, total, layer),
			"coin_if_taken_d": total * (coin_rate(core) if layer == "barter" else 1.0)}


## What a market takes of an item and what it pays: the best stacks it will buy first, skipping any it refuses (a green
## pelt must be dried first). {ok, reason, qty, total_d, layer, parts: [[stack, qty]]}; the parts are the inventory's
## own stacks, so a sale removes exactly what was priced.
static func _sell_plan(core: SurvivalCore, mkt_id: String, item_id: String, qty: float) -> Dictionary:
	var sts := SurvivalInventory.stacks_of(core, item_id)
	sts.sort_custom(func(a, b): return SurvivalInventory.stack_quality(a) > SurvivalInventory.stack_quality(b))
	var left := qty if qty >= 0.0 else SurvivalInventory.count(core, item_id)
	var total := 0.0
	var n := 0.0
	var layer := ""
	var reason := "none carried"
	var parts := []
	for st in sts:
		if left <= 0.0001:
			break
		var u := sell_unit(core, mkt_id, st)
		if not bool(u.ok):
			reason = str(u.reason)
			continue
		var take := minf(left, float(st.qty))
		if str(u.get("channel", "")) == "meat":
			take = minf(take, meat_room_lb(core, mkt_id, item_id) - n)
			if take <= 0.0:
				reason = "the mess has bought all it needs today"
				continue
		total += float(u.unit_d) * take
		n += take
		left -= take
		layer = str(u.layer)
		parts.append([st, take])
	if n <= 0.0:
		return {"ok": false, "reason": reason}
	return {"ok": true, "qty": n, "total_d": total, "layer": layer, "parts": parts}


## Sell. take: "coin" (at the trader: coin at the coin rate), "book" (credited to the account: pays debt first).
static func sell(core: SurvivalCore, mkt_id: String, item_id: String, qty: float = -1.0, take: String = "coin") -> Dictionary:
	if not is_open(core, mkt_id):
		return {"ok": false, "reason": "closed"}
	var q := _sell_plan(core, mkt_id, item_id, qty)
	if not bool(q.ok):
		return q
	var sold_qty := float(q.qty)
	var total := float(q.total_d)
	var layer := str(q.layer)
	# Remove exactly the stacks that were priced (never a green pelt the market refused).
	for part in q.parts:
		SurvivalInventory.remove_stack_qty(core, part[0], float(part[1]))
	var cred := creditor_for(core, mkt_id)
	var m := core.data.market(mkt_id)
	if SurvivalUtil.arr(SurvivalUtil.dict(SurvivalUtil.dict(m.get("buys")).get("meat_channel")).get("items")).has(item_id):
		_record_meat(core, item_id, sold_qty)
	# Collection on an unpaid book takes its share of fur sales first (economy.json credit.collection).
	var proceeds := total
	var collected := 0.0
	var cat := core.data.item_cat(item_id)
	if cat == "pelt" or cat == "skin":
		for c in SurvivalUtil.dict(_e(core).get("collection")).keys():
			var owed := balance(core, str(c))
			if owed <= 0.0:
				continue
			var share := 0.5 if str(_e(core).collection[c]) == "settler" else 1.0
			var val_in_layer := proceeds * share
			var take_d := minf(owed, val_in_layer)
			collected += take_d
			proceeds -= take_d
			_change_balance(core, str(c), -take_d, "collected from a fur sale")
	var coin := 0.0
	var barter_credit := 0.0
	if layer == "barter":
		if take == "coin":
			coin = proceeds * coin_rate(core)
		else:
			barter_credit = proceeds
			_change_balance(core, cred, -proceeds, "furs credited: %s x%s" % [core.data.item_name(item_id), _qty_s(sold_qty)])
		_income(core, coin, barter_credit + collected, cat)
		if cred == TRADER_ID:
			var a := _account(core, cred)
			a["season_sales_d"] = SurvivalUtil.num(a.get("season_sales_d"), 0.0) + total
	else:
		if take == "book" and balance(core, cred) > 0.0:
			var pay_d := minf(balance(core, cred), proceeds)
			_change_balance(core, cred, -pay_d, "paid in %s" % core.data.item_name(item_id))
			coin = proceeds - pay_d
		else:
			coin = proceeds
		_income(core, proceeds + collected, 0.0, cat)
	if coin > 0.0:
		_add_money(core, coin)
	_visit_trade(core, mkt_id, SurvivalTrade.rv(core, item_id) * sold_qty)
	core.state.stats["sold_rv"] = SurvivalUtil.num(core.state.stats.get("sold_rv"), 0.0) + SurvivalTrade.rv(core, item_id) * sold_qty
	# Trade grows on one scale with barter: the rv of the goods sold (not the pence received), capped per partner a day.
	SurvivalSkills.record_trade(core, SurvivalTrade.rv(core, item_id) * sold_qty, false, cred if cred != "" else mkt_id)
	core.log_line("sold %s x%s: %s" % [core.data.item_name(item_id), _qty_s(sold_qty), display(core, total, layer)], "trade")
	core.state.stats["sold_" + cat] = SurvivalUtil.num(core.state.stats.get("sold_" + cat), 0.0) + sold_qty
	return {"ok": true, "qty": sold_qty, "total_d": total, "layer": layer, "coin_d": coin, "book_d": barter_credit, "collected_d": collected}


static func _record_meat(core: SurvivalCore, item_id: String, lb: float) -> void:
	var e := _e(core)
	var ms := SurvivalUtil.dict(e.get("meat_sold"))
	if int(SurvivalUtil.num(ms.get("day"), -1.0)) != SurvivalClock.abs_day(core):
		ms = {"day": SurvivalClock.abs_day(core), "lb": {}}
	ms.lb[item_id] = SurvivalUtil.num(ms.lb.get(item_id), 0.0) + lb
	e["meat_sold"] = ms


## npcs.json standing.sources.fair_trade: +1 per visit with 60 d or more of rv traded, barter counting (3 a game month).
static func _visit_trade(core: SurvivalCore, mkt_id: String, amount_rv: float) -> void:
	record_visit_trade(core, mkt_id, str(core.data.market(mkt_id).get("faction", "")), amount_rv)


## A trade with a partner today (a market or an individual): the fair-trade standing source by rv.
static func record_visit_trade(core: SurvivalCore, key_id: String, faction: String, amount_rv: float) -> void:
	var e := _e(core)
	var key := "%s|%d" % [key_id, SurvivalClock.abs_day(core)]
	var before := SurvivalUtil.num(SurvivalUtil.dict(e.visit_trade).get(key), 0.0)
	var after := before + amount_rv
	e.visit_trade[key] = after
	var need := SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("sources")).get("fair_trade")).get("min_rv_d"), 60.0)
	if before < need and after >= need and faction != "":
		add_standing(core, faction, 1.0, "fair_trade")
	if e.visit_trade.size() > 40:
		var ks: Array = e.visit_trade.keys()
		for i in ks.size() - 40:
			e.visit_trade.erase(ks[i])


## Pay a creditor in coin (1 d of coin pays 1 d of either layer [D: the reverse of the coin rate is not specified]).
static func pay(core: SurvivalCore, creditor: String, amount_d: float) -> Dictionary:
	var owed := balance(core, creditor)
	var amt := minf(float(money(core)), minf(amount_d, maxf(0.0, owed)))
	if amt <= 0.0:
		return {"ok": false, "reason": "nothing owed" if owed <= 0.0 else "no coin"}
	_spend_money(core, amt)
	_change_balance(core, creditor, -amt, "paid in coin")
	return {"ok": true, "paid_d": amt, "balance_d": balance(core, creditor)}


## Take book credit as coin at the trader (coin at the coin rate x barter value): the book's credit becomes cash.
static func draw_book_credit(core: SurvivalCore, amount_barter_d: float) -> Dictionary:
	if not is_open(core, "mkt.visiting_trader"):
		return {"ok": false, "reason": "the trader is not here"}
	var credit := -balance(core, TRADER_ID)
	var amt := minf(amount_barter_d, credit)
	if amt <= 0.0:
		return {"ok": false, "reason": "no credit on the book"}
	_change_balance(core, TRADER_ID, amt, "book credit taken in coin")
	_add_money(core, amt * coin_rate(core))
	return {"ok": true, "coin_d": amt * coin_rate(core)}


# ---------------------------------------------------------------- the credit year
static func can_take_outfit(core: SurvivalCore) -> Dictionary:
	if not SurvivalClock.event_active(core, "event.fall_credit"):
		return {"ok": false, "reason": "the outfit is given at the fall credit (Mid September)"}
	var a := _account(core, TRADER_ID)
	if bool(a.get("no_credit", false)):
		return {"ok": false, "reason": "no outfit: last spring's book was not paid"}
	if int(SurvivalUtil.num(a.get("outfit_year"), -1.0)) == SurvivalClock.year(core):
		return {"ok": false, "reason": "the outfit is already taken this year"}
	return {"ok": true, "limit_d": SurvivalUtil.num(a.get("outfit_limit_d"), 0.0)}


## trade.take_credit: charge a basket to the trader's book up to the outfit limit. basket {item: qty}; empty basket =
## the design's typical basket (economy.json settlement.typical_basket) scaled to the limit.
static func take_outfit(core: SurvivalCore, basket: Dictionary = {}) -> Dictionary:
	var ok := can_take_outfit(core)
	if not bool(ok.ok):
		return ok
	var a := _account(core, TRADER_ID)
	a["outfit_charged_d"] = 0.0
	a["outfit_year"] = SurvivalClock.year(core)
	if basket.is_empty():
		basket = SurvivalUtil.dict(core.data.section("economy", "settlement").get("typical_basket")).duplicate()
	var bought := {}
	var total := 0.0
	for it in basket.keys():
		var want := int(SurvivalUtil.num(basket[it], 0.0))
		for i in want:
			var r := buy(core, "mkt.visiting_trader", str(it), 1.0, "book")
			if not bool(r.ok):
				break
			bought[it] = int(bought.get(it, 0)) + 1
			total += float(r.total_d)
	core.log_line("took the fall outfit on the book: %s" % display(core, total, "barter"), "trade")
	return {"ok": true, "bought": bought, "total_d": total, "limit_d": SurvivalUtil.num(a.get("outfit_limit_d"), 0.0)}


## Next outfit limit after a settlement: clamp(0.5 x season sales to the trader, 800, 3000) x the grade multiplier.
static func _next_limit(core: SurvivalCore, sales: float, mult: float) -> float:
	return clampf(0.5 * sales, 800.0, 3000.0) * mult


## Grade every book due at an event when its window closes (economy.json credit.grading).
static func grade_accounts(core: SurvivalCore, event_id: String) -> void:
	var gr := SurvivalUtil.dict(core.data.section("economy", "credit").get("grading"))
	for cred in SurvivalUtil.dict(_e(core).get("accounts")).keys():
		var a: Dictionary = _e(core).accounts[cred]
		if str(a.get("due_event", "")) != event_id:
			continue
		var due := SurvivalUtil.num(a.get("due_at_open"), SurvivalUtil.num(a.get("balance_d"), 0.0))
		var bal := SurvivalUtil.num(a.get("balance_d"), 0.0)
		# Credit is optional: the settlement grades only a book with a balance or an outfit charged this credit year.
		if due <= 0.5 and bal <= 0.5 and SurvivalUtil.num(a.get("outfit_charged_d"), 0.0) <= 0.0:
			a.erase("due_at_open")
			continue
		var grade := "paid_in_full"
		if due > 0.0 and bal > 0.5:
			grade = "part_paid" if (due - bal) >= 0.5 * due else "unpaid"
		var g := SurvivalUtil.dict(gr.get(grade))
		var fac := "faction.post" if str(cred) == TRADER_ID else "faction.garrison"
		var st = g.get("standing", 0.0)
		var sv := 0.0
		if typeof(st) == TYPE_ARRAY:
			var i := maxi(0, PRESETS.find(core.state.preset))
			sv = SurvivalUtil.num(st[mini(i, st.size() - 1)], 0.0)
		else:
			sv = SurvivalUtil.num(st, 0.0)
		var res := {"creditor": cred, "grade": grade, "owed_at_open": due, "balance": bal}
		if due > 0.0 or grade != "paid_in_full":
			a["standing_applied"] = sv
			if sv != 0.0:
				add_standing(core, fac, sv, "honour_debt" if sv > 0.0 else "")
		if str(cred) == TRADER_ID:
			var mult := SurvivalUtil.num(g.get("next_limit_mult"), 1.0)
			a["outfit_limit_d"] = _next_limit(core, SurvivalUtil.num(a.get("season_sales_d"), 0.0), mult) if mult > 0.0 else 0.0
			a["no_credit"] = mult <= 0.0
			if grade == "paid_in_full":
				_e(core).steel_cap["mkt.visiting_trader"] = 8.0
			res["next_limit_d"] = a.outfit_limit_d
			a["season_sales_d"] = 0.0
			a["outfit_charged_d"] = 0.0
		if grade == "unpaid":
			_e(core).collection[cred] = core.state.preset
		elif grade == "paid_in_full":
			_e(core).collection.erase(cred)
			if due > 0.0:
				SurvivalSkills.record_trade(core, 0.0, true)
		a["last_grade"] = grade
		a.erase("due_at_open")
		SurvivalTrade.grade_credit(core, str(cred), grade)
		core._on_settlement(str(cred), grade, res)
		core.log_line("settlement with %s: %s" % [core.npc_title(str(cred)), grade.replace("_", " ")], "trade")


## Obligations (the provincial's militia muster). kind "militia_muster": attend on the day, or supply it (women on the
## historical setting supply provisions worth 60 d: backgrounds.json obligation_rules.militia).
static func fulfil_obligation(core: SurvivalCore, kind: String) -> Dictionary:
	for ob in SurvivalUtil.arr(_e(core).get("obligations")):
		if str(ob.kind) != kind or str(ob.status) != "pending":
			continue
		if not SurvivalClock.event_active(core, str(ob.due_event)):
			return {"ok": false, "reason": "not today"}
		if str(core.setting("militia_role", "men")) == "women" and str(core.setting("service_setting", "historical")) == "historical":
			var cost := 60.0
			if not _pay_in_provisions(core, cost):
				if money(core) < int(cost):
					return {"ok": false, "reason": "the muster's provisions are worth %s" % SurvivalUtil.lsd(cost)}
				_spend_money(core, cost)
		ob["status"] = "kept"
		add_standing(core, "faction.colonial_authorities", SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("sources")).get("obligation_kept")).get("value"), 3.0))
		core.log_line("answered the district's muster", "duty")
		return {"ok": true}
	return {"ok": false, "reason": "no such obligation due"}


static func _close_obligations(core: SurvivalCore, event_id: String) -> void:
	for ob in SurvivalUtil.arr(_e(core).get("obligations")):
		if str(ob.due_event) != event_id or str(ob.status) != "pending":
			continue
		ob["status"] = "missed"
		for f in SurvivalUtil.dict(ob.get("miss_standing")).keys():
			add_standing(core, str(f), SurvivalUtil.num(ob.miss_standing[f], 0.0))
		var fine := SurvivalUtil.num(ob.get("miss_fine_d"), 0.0)
		if fine > 0.0:
			var acct := _account(core, COUNTY_ID, "cash")
			acct["due_event"] = "event.fall_credit"
			_change_balance(core, COUNTY_ID, fine, "militia fine: missed the muster")
		core.log_line("missed the district's muster: a fine of %s" % SurvivalUtil.lsd(fine), "duty")


## Pay a duty in provisions of the same rv (the muster's supply, the militia fine): meat and meal carried, best-kept
## first. Returns false (and takes nothing) when the pack does not hold enough.
static func _pay_in_provisions(core: SurvivalCore, rv_d: float) -> bool:
	var plan := []
	var left := rv_d
	for it in ["item.food.jerky", "item.food.salt_pork", "item.food.cornmeal", "item.food.flour", "item.food.venison_raw", "item.food.nuts"]:
		var r := SurvivalTrade.rv(core, it)
		if r <= 0.0 or left <= 0.0:
			continue
		var n := minf(SurvivalInventory.count_usable(core, it), ceilf(left / r))
		if n > 0.0:
			plan.append([it, n])
			left -= n * r
	if left > 0.0:
		return false
	for p in plan:
		SurvivalInventory.remove(core, str(p[0]), float(p[1]))
	return true


## A fine owed to the county (a missed muster) paid in coin or in provisions of the same value [D].
static func pay_fine(core: SurvivalCore, how: String = "coin") -> Dictionary:
	var owed := balance(core, COUNTY_ID)
	if owed <= 0.0:
		return {"ok": false, "reason": "no fine owed"}
	if how == "provisions":
		if not _pay_in_provisions(core, owed):
			return {"ok": false, "reason": "not enough provisions"}
		_change_balance(core, COUNTY_ID, -owed, "fine paid in provisions")
		return {"ok": true, "paid_d": owed}
	return pay(core, COUNTY_ID, owed)


# ---------------------------------------------------------------- the firewood contract
static func contract_open(core: SurvivalCore) -> bool:
	return SurvivalClock.gate_active(core, "firewood_contract") and int(SurvivalUtil.num(SurvivalUtil.dict(_e(core).get("contract")).get("cords"), 0.0)) < contract_cords(core)


static func contract_cords(core: SurvivalCore) -> int:
	var job := SurvivalUtil.dict(core.data.jobs.get("job.garrison_firewood"))
	var txt := str(job.get("openings", "40 cords"))
	var n := txt.get_slice(" ", 0).to_int()
	return n if n > 0 else 40


## Stack split wood at the fort woodpile for the garrison's firewood contract: 18 d a cord, paid per cord in coin or, in
## v4, in rations (4 lb flour and 1.5 lb salt pork a cord: economy.json wage.firewood_cord rations_per_cord).
static func deliver_firewood(core: SurvivalCore, armloads: float, pay_in: String = "coin") -> Dictionary:
	if not contract_open(core):
		return {"ok": false, "reason": "the lieutenant is not buying firewood now"}
	var have := SurvivalInventory.count(core, "item.fuel.split_wood")
	var n := minf(armloads, have)
	if n <= 0.0:
		return {"ok": false, "reason": "no split wood carried"}
	SurvivalInventory.remove(core, "item.fuel.split_wood", n)
	var c: Dictionary = _e(core).contract
	c["armloads"] = SurvivalUtil.num(c.get("armloads"), 0.0) + n
	var wage := SurvivalUtil.dict(core.data.wages.get("wage.firewood_cord"))
	var per := SurvivalUtil.num(wage.get("per_cord_d"), 18.0)
	var paid := 0.0
	var cords := 0
	# The lieutenant takes at most a day's cords from one man: 4, or 5 from Woodcraft 50 (wage.firewood_cord's rule, which v3
	# never enforced because Woodcraft hardly grew; under growth model v4 it does).
	var cap_day := _cords_per_day_cap(core)
	if int(SurvivalUtil.num(c.get("day"), -1.0)) != SurvivalClock.abs_day(core):
		c["day"] = SurvivalClock.abs_day(core)
		c["cords_today"] = 0
	while float(c.armloads) >= ARMLOADS_PER_CORD and int(SurvivalUtil.num(c.get("cords"), 0.0)) < contract_cords(core) \
			and int(SurvivalUtil.num(c.get("cords_today"), 0.0)) < cap_day:
		c["cords_today"] = int(SurvivalUtil.num(c.get("cords_today"), 0.0)) + 1
		c["armloads"] = float(c.armloads) - ARMLOADS_PER_CORD
		c["cords"] = int(SurvivalUtil.num(c.get("cords"), 0.0)) + 1
		cords += 1
		paid += per
		add_standing(core, "faction.garrison", SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("sources")).get("firewood_cord")).get("value"), 0.5), "firewood_cord")
	if paid > 0.0 and pay_in == "rations" and not SurvivalUtil.dict(wage.get("rations_per_cord")).is_empty():
		var rations := {}
		for it in SurvivalUtil.dict(wage.rations_per_cord).keys():
			var q := SurvivalUtil.num(wage.rations_per_cord[it], 0.0) * float(cords)
			SurvivalInventory.add(core, str(it), q)
			rations[it] = q
		core.log_line("stacked %d cord(s) at the woodpile: paid in rations" % cords, "trade")
		return {"ok": true, "cords": cords, "paid_d": 0.0, "rations": rations, "armloads_toward_next": c.armloads}
	if paid > 0.0:
		_add_money(core, paid)
		_income(core, paid, 0.0, "wage")
		var inc: Dictionary = _e(core).income
		inc["wages_d"] = SurvivalUtil.num(inc.get("wages_d"), 0.0) + paid
		core.log_line("stacked %d cord(s) at the woodpile: %s" % [cords, SurvivalUtil.lsd(paid)], "trade")
	return {"ok": true, "cords": cords, "paid_d": paid, "armloads_toward_next": c.armloads}


static func _cords_per_day_cap(core: SurvivalCore) -> int:
	var w := SurvivalUtil.dict(core.data.wages.get("wage.firewood_cord"))
	var cpd := SurvivalUtil.pair(w.get("cords_per_game_day"), 4.0)
	return int(cpd.x) + (int(cpd.y - cpd.x) if SurvivalSkills.level(core, "woodcraft") >= 50.0 else 0)


## Services such as lodging in the sutler's loft (economy.json services).
static func buy_service(core: SurvivalCore, service_id: String) -> Dictionary:
	var s := SurvivalUtil.dict(core.data.services.get(service_id))
	if s.is_empty():
		return {"ok": false, "reason": "unknown service"}
	var price := SurvivalUtil.num(s.get("price_d"), 0.0)
	if money(core) < int(price):
		return {"ok": false, "reason": "not enough coin"}
	_spend_money(core, price)
	return {"ok": true, "paid_d": price}


# ---------------------------------------------------------------- daily upkeep
static func on_day_started(core: SurvivalCore, doy: int) -> void:
	var e := _e(core)
	var today := SurvivalClock.abs_day(core)
	# The sutler restocks every 3 game days in open season, every 6 in deep snow; the soldiers' issue comes monthly.
	for mid in core.data.markets.keys():
		var m := core.data.market(str(mid))
		if str(m.get("type", "")) == "sutler":
			var every := 6 if SurvivalClock.gate_active(core, "deep_snow") else 3
			if today - int(SurvivalUtil.num(SurvivalUtil.dict(e.last_restock_day).get(mid), -99.0)) >= every:
				restock(core, str(mid))
		elif str(m.get("type", "")) == "soldiers" and SurvivalClock.phase(core) == 0:
			restock(core, str(mid))
	# Events that start or end today.
	for ev in core.data.events.keys():
		var first := SurvivalClock.day_index_of(core, SurvivalClock.event_first_day(core, str(ev)))
		var last := SurvivalClock.day_index_of(core, SurvivalClock.event_last_day(core, str(ev)))
		if first == doy:
			_event_started(core, str(ev))
		if last >= 0 and posmod(last + 1, SurvivalClock.days_per_year(core)) == doy:
			_event_ended(core, str(ev))
	# Overdue store tally: simple interest at 6% a year (a game year of 36 days) after its due window closes.
	for cred in SurvivalUtil.dict(e.accounts).keys():
		var a: Dictionary = e.accounts[cred]
		if str(a.get("last_grade", "")) in ["part_paid", "unpaid"] and SurvivalUtil.num(a.get("balance_d"), 0.0) > 0.0:
			var rate := _interest_rate(core, str(cred))
			if rate > 0.0:
				var add := SurvivalUtil.num(a.balance_d) * rate / float(SurvivalClock.days_per_year(core))
				a["interest_accrued"] = SurvivalUtil.num(a.get("interest_accrued"), 0.0) + add
				if float(a.interest_accrued) >= 1.0:
					var whole := floorf(float(a.interest_accrued))
					a["interest_accrued"] = float(a.interest_accrued) - whole
					_change_balance(core, str(cred), whole, "interest on an overdue tally")
	# Hard Winter and Ironman: 3 game days late, the creditor's man seizes carried furs.
	for cred in SurvivalUtil.dict(e.collection).keys():
		var preset := str(e.collection[cred])
		if (preset == "hard_winter" or preset == "ironman") and balance(core, str(cred)) > 0.0:
			var a2 := account(core, str(cred))
			var late := int(SurvivalUtil.num(a2.get("late_days"), 0.0)) + 1
			a2["late_days"] = late
			if late >= 3:
				_seize_furs(core, str(cred))


static func _interest_rate(core: SurvivalCore, cred: String) -> float:
	for mid in core.data.markets.keys():
		if creditor_for(core, str(mid)) == cred:
			return SurvivalUtil.num(SurvivalUtil.dict(core.data.market(str(mid)).get("credit")).get("overdue_interest_per_year"), 0.0)
	return 0.0


static func _seize_furs(core: SurvivalCore, cred: String) -> void:
	var taken := 0.0
	for st in core.state.inventory.duplicate():
		var cat := core.data.item_cat(str(st.id))
		if cat != "pelt" and cat != "skin":
			continue
		var b := SurvivalUtil.dict(core.data.good(str(st.id)).get("barter"))
		var val := SurvivalUtil.num(b.get("beaver"), 0.0) * beaver_d(core) * stack_value_factor(core, st) * float(st.qty)
		SurvivalInventory.remove_stack_qty(core, st, float(st.qty))
		taken += val
	if taken > 0.0:
		_change_balance(core, cred, -taken, "furs seized by the creditor's man")
		core.log_line("the creditor's man seized your furs", "loss")


static func _event_started(core: SurvivalCore, ev: String) -> void:
	match ev:
		"event.fall_credit", "event.trader_visit_winter", "event.trader_visit_late_winter", "event.spring_trade":
			restock(core, "mkt.visiting_trader")
	for mid in core.data.markets.keys():
		if SurvivalUtil.dict(core.data.market(str(mid)).get("stock_by_event")).has(ev):
			restock(core, str(mid))
	if ev == "event.spring_trade" or _is_due_event(core, ev):
		for a in SurvivalUtil.dict(_e(core).get("accounts")).values():
			if str(a.get("due_event", "")) == ev:
				a["due_at_open"] = SurvivalUtil.num(a.get("balance_d"), 0.0)
	if ev == "event.firewood_contract":
		_e(core).contract = {"cords": 0, "armloads": 0.0, "open": true, "season_year": SurvivalClock.year(core)}
	core._on_event(ev, true)


static func _is_due_event(core: SurvivalCore, ev: String) -> bool:
	for a in SurvivalUtil.dict(_e(core).get("accounts")).values():
		if str(a.get("due_event", "")) == ev:
			return true
	return false


static func _event_ended(core: SurvivalCore, ev: String) -> void:
	if _is_due_event(core, ev):
		grade_accounts(core, ev)
	_close_obligations(core, ev)
	core._on_event(ev, false)


# ---------------------------------------------------------------- display and advice
static func display(core: SurvivalCore, d: float, layer: String) -> String:
	if layer == "barter":
		return "%.2f beaver (%s)" % [d / beaver_d(core), SurvivalUtil.lsd(d)]
	return SurvivalUtil.lsd(d)


static func _qty_s(q: float) -> String:
	return str(int(q)) if is_equal_approx(q, roundf(q)) else "%.2f" % q


## Every account for the journal's ledger: [{creditor, title, layer, balance_d, due_event, due_in_days, grade}].
static func ledger(core: SurvivalCore) -> Array:
	var out := []
	for cred in SurvivalUtil.dict(_e(core).get("accounts")).keys():
		var a: Dictionary = _e(core).accounts[cred]
		var due := str(a.get("due_event", ""))
		out.append({"creditor": str(cred), "title": core.npc_title(str(cred)), "layer": str(a.get("layer", "cash")),
				"balance_d": SurvivalUtil.num(a.get("balance_d"), 0.0),
				"display": display(core, SurvivalUtil.num(a.get("balance_d"), 0.0), str(a.get("layer", "cash"))),
				"due_event": due, "due_in_days": SurvivalClock.days_until(core, SurvivalClock.event_first_day(core, due)),
				"outfit_limit_d": SurvivalUtil.num(a.get("outfit_limit_d"), 0.0), "grade": str(a.get("last_grade", "")),
				"collection": SurvivalUtil.dict(_e(core).get("collection")).has(cred)})
	return out


## The debt icon: from 3 game days before a due window opens (Mid March for the spring settlement) and while overdue.
static func debt_warning(core: SurvivalCore) -> bool:
	var warn_from := str(SurvivalUtil.dict(core.data.section("seasons", "almanac")).get("settlement_warning_from", "mar_mid"))
	for a in SurvivalUtil.dict(_e(core).get("accounts")).values():
		if SurvivalUtil.num(a.get("balance_d"), 0.0) <= 0.0:
			continue
		if SurvivalUtil.dict(_e(core).get("collection")).has(str(a.creditor)):
			return true
		var ev := str(a.get("due_event", ""))
		var first := SurvivalClock.event_first_day(core, ev)
		if first == "":
			continue
		if SurvivalClock.in_window(core, [warn_from, SurvivalClock.event_last_day(core, ev)]) and ev == "event.spring_trade":
			return true
		if SurvivalClock.days_until(core, first) <= 3:
			return true
	return false


## Where an item fetches the most right now, among open markets: {market, unit_d, layer, coin_equiv_d}.
static func best_offer(core: SurvivalCore, item_id: String) -> Dictionary:
	var best := {}
	var sts := SurvivalInventory.stacks_of(core, item_id)
	var probe: Dictionary = sts[0] if not sts.is_empty() else {"id": item_id, "qty": 1.0, "meta": {}}
	for mid in core.data.markets.keys():
		if not is_open(core, str(mid)):
			continue
		var u := sell_unit(core, str(mid), probe)
		if not bool(u.get("ok", false)):
			continue
		var ce := float(u.unit_d) * (coin_rate(core) if str(u.layer) == "barter" else 1.0)
		if best.is_empty() or ce > float(best.coin_equiv_d):
			best = {"market": str(mid), "unit_d": float(u.unit_d), "layer": str(u.layer), "coin_equiv_d": ce}
	return best
