class_name StoreLedger
extends RefCounted
## LEDGER: a store's memory of what went in and out (user 2026-09-29: "the memory of the supply system should be in the
## storage so the storage has a ledger of who takes what ... the player or npc just has a task: I need this, I take
## this"). A storage chest (StorageChest.ledger) and a household store without chests (HouseholdStock.ledger) each keep
## one: entries {t: game minute, who, kind, n (in +, out -), why}, the last KEEP. Who: "you" for the player's hand (the
## chest screen), a worker's name for the household's; why: the work it was for. A run of the same entry within a game
## minute is one line (a pack moved across one by one).
##   StoreLedger.add(ledger, tree, who, kind, n, why)   -> the ledger, trimmed
##   StoreLedger.line(e, now)                           -> "Mercy took 2 venison (Cooking), an hour ago"
##   StoreLedger.recent(ledgers, n)                     -> the last n entries of several, newest first

const KEEP := 120
const WHO_HOUSE := "the household"


static func now(tree: SceneTree) -> float:
	var b := SurvivalBridge.find(tree) if tree != null else null
	return b.core.state.minutes if b != null and b.core != null else -1.0


static func add(ledger: Array, tree: SceneTree, who: String, kind: String, n: int, why: String) -> Array:
	if n == 0 or kind == "":
		return ledger
	var w := who if who != "" else WHO_HOUSE
	var t := now(tree)
	if not ledger.is_empty():
		var last: Dictionary = ledger[ledger.size() - 1]
		if String(last.who) == w and String(last.kind) == kind and String(last.why) == why and signi(int(last.n)) == signi(n) \
				and absf(float(last.t) - t) < 1.0:
			last.n = int(last.n) + n
			return ledger
	ledger.append({"t": t, "who": w, "kind": kind, "n": n, "why": why})
	if ledger.size() > KEEP:
		return ledger.slice(ledger.size() - KEEP)
	return ledger


## The ledger as saved (a copy; entries with their fields only).
static func to_save(ledger: Array) -> Array:
	return ledger.duplicate(true)


static func from_save(a: Variant) -> Array:
	var out := []
	if a is Array:
		for e: Variant in a:
			if e is Dictionary and (e as Dictionary).has("kind") and int((e as Dictionary).get("n", 0)) != 0:
				out.append({"t": float(e.get("t", -1.0)), "who": String(e.get("who", WHO_HOUSE)), "kind": String(e.kind),
						"n": int(e.n), "why": String(e.get("why", ""))})
	return out


## The last `n` entries of several ledgers together, newest first.
static func recent(ledgers: Array, n: int) -> Array:
	var all := []
	for l: Variant in ledgers:
		if l is Array:
			all.append_array(l)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) > float(b.t))
	return all.slice(0, mini(n, all.size()))


## An entry as a line: "Mercy took 2 venison (Cooking), an hour ago"; "you put in 6 ears of corn".
static func line(e: Dictionary, t_now := -1.0) -> String:
	var n := int(e.n)
	var who := String(e.who)
	var verb := ("put in" if n > 0 else "took") if who != "you" else ("put in" if n > 0 else "took out")
	var why := String(e.get("why", ""))
	var s := "%s %s %s" % [who.left(1).to_upper() + who.substr(1), verb, count_words(String(e.kind), n)]
	if why != "":
		s += " (%s)" % why
	if t_now >= 0.0 and float(e.t) >= 0.0:
		s += ", " + ago(t_now - float(e.t))
	return s


## Entries (newest first) as lines, the ones made together (the same who, why and way, within a game minute) as one:
## "Mercy put in 5 ears of corn, 4 beans, 3 squash (the harvest), just now". At most `most` lines.
static func lines(entries: Array, t_now := -1.0, most := 6) -> Array:
	var out := []
	var i := 0
	while i < entries.size() and out.size() < most:
		var e: Dictionary = entries[i]
		var parts := [count_words(String(e.kind), int(e.n))]
		var j := i + 1
		while j < entries.size():
			var f: Dictionary = entries[j]
			if String(f.who) != String(e.who) or String(f.get("why", "")) != String(e.get("why", "")) \
					or signi(int(f.n)) != signi(int(e.n)) or absf(float(f.t) - float(e.t)) >= 1.0:
				break
			parts.append(count_words(String(f.kind), int(f.n)))
			j += 1
		var s := line(e, t_now)
		if parts.size() > 1:
			var first := count_words(String(e.kind), int(e.n))
			s = s.replace(first, ", ".join(parts))
		out.append(s)
		i = j
	return out


## `n` of `kind` in words: "5 ears of corn", "1 seed corn", "4 beans" (the pack's name, lower case, "ear of" made plural).
static func count_words(kind: String, n: int) -> String:
	var nm := InventoryState.name_of(kind).to_lower()
	if absi(n) != 1 and nm.begins_with("ear of "):
		nm = "ears of " + nm.substr(7)
	return "%d %s" % [absi(n), nm]


## "just now", "20 minutes ago", "3 hours ago", "2 days ago" (game time).
static func ago(m: float) -> String:
	if m < 2.0:
		return "just now"
	if m < 60.0:
		return "%d minutes ago" % roundi(m)
	if m < 1440.0:
		var h := roundi(m / 60.0)
		return "an hour ago" if h == 1 else "%d hours ago" % h
	var d := roundi(m / 1440.0)
	return "a day ago" if d == 1 else "%d days ago" % d
