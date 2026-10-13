class_name RingHighlights
extends Node
## THE MATCH'S BEST PLAYS (round 4 VIRAL): the plays tracked from the match's events, scored by data, the best of each kind
## kept with a snapshot of the Splash Cam's buffer, and the cards' words for the match screen (HighlightCards). It also tells
## the callouts (Callouts) of the big moments as they happen. Every number and word in data/ring/highlights.json.
##   THE GATE   only while RingRules.stock_on() (installed under RingMode by RingReplay.install)
##   the plays  launch (the speed of a launch, more when it ends in a fall within ko_after_s), catch (an earth catch: the
##              time its guard had stood when the stone came, the less the closer), rally (catches back and forth, each within
##              rally_gap_s of the other side's), perfect (perfect guards in a row: a late guard or a hit ends it), recover (a
##              Rise or a double jump back to the edge or the deck from the deepest point under the deck's top), comeback (a
##              game won after being comeback_down lives behind), fast_ko (a fall dealt soonest after the faller came back
##              on), clash (two attacks meeting: BendClash)
##   scoring    score = base + per x value, mine_bonus for the player's side; the best of each kind kept; the top `cards`
##              of the kinds' bests hold a snapshot (RingReplay.snapshot: before_s before the play to after_s after it, taken
##              after_s after it), the others none (scores only rise, so a play out of the top never needs one)
##   moments    moment(kind, body, info): "splash" (a fall: body the one who sent him, else the faller), "caught" (an earth
##              catch within calls.caught.within_s), "perfect", "rise" (a recovery from the deepest third:
##              calls.rise.deep_third of the way from the deck's top to the water), "clash", "comeback", "last_life"
##              (sudden death, or every side on its last life; once a game)
## cards() -> [{kind, title, line, num, score, clip, mine}] the best first; plays() all the kinds' bests; reset() at a match's
## start (RingMode's restart: phase COUNTDOWN at round 1).

signal moment(kind: String, body: Node, info: Dictionary)

const NODE_NAME := "RingHighlights"
const GROUP := &"ring_highlights"
const DATA_PATH := "res://data/ring/highlights.json"

static var _data := {}

var mode: Node
var replay: RingReplay
var _rules: RingRules
## kind -> the best play {kind, score, value, who (Node), whom (Node), who_team, at (tick), clip, num, mine}
var _best := {}
## Snapshots due: [{play, due (tick)}]
var _due: Array = []
var _streak := {}
var _rally := {"n": 0, "team": -1, "at": -INF, "a": null, "b": null}
var _deep := {}
var _back_at := {}
var _launches := {}
var _deficit := [0, 0]
var _last_life_said := false
var _sudden_seen := false
var _hooked := {}


static func install(m: Node, r: RingReplay) -> RingHighlights:
	if m == null:
		return null
	var have := m.get_node_or_null(NODE_NAME) as RingHighlights
	if have != null:
		return have
	var h := RingHighlights.new()
	h.name = NODE_NAME
	h.mode = m
	h.replay = r
	m.add_child(h)
	return h


static func find(tree: SceneTree) -> RingHighlights:
	return tree.get_first_node_in_group(GROUP) as RingHighlights if tree != null else null


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = d if d is Dictionary else {}
	return _data


static func play_cfg(kind: String) -> Dictionary:
	var p: Variant = (data().get("plays", {}) as Dictionary).get(kind, {})
	return p if p is Dictionary else {}


static func num(key: String, def := 0.0) -> float:
	return float(data().get(key, def))


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = 31                # (after the recorder: a snapshot due this tick holds it)
	if mode != null and mode.has_signal(&"phase_changed"):
		mode.connect(&"phase_changed", _on_phase)
	if mode != null and mode.has_signal(&"round_over"):
		mode.connect(&"round_over", _on_round_over)


# ---------------------------------------------------------------- hooks
func _hook() -> void:
	var r := RingRules.current()
	if r == null:
		return
	if r != _rules:
		_rules = r
		r.launched.connect(_on_launched)
		r.ko.connect(_on_ko)
		r.respawned.connect(_on_respawned)
		r.pct_changed.connect(_on_pct)
	for t in 2:
		for b in r.sides[t]:
			if not (b is Node3D) or not is_instance_valid(b):
				continue
			var bc := BendCaster.of(b)
			if bc != null and not _hooked.has(bc.get_instance_id()):
				_hooked[bc.get_instance_id()] = true
				bc.guarded.connect(_on_guarded.bind(b))
			var rm := RingMoves.of(b)
			if rm != null and not _hooked.has(rm.get_instance_id()):
				_hooked[rm.get_instance_id()] = true
				rm.moved.connect(_on_moved.bind(b))
	var c := BendClash.find(get_tree())
	if c != null and not _hooked.has(c.get_instance_id()):
		_hooked[c.get_instance_id()] = true
		c.clashed.connect(_on_clash)
		if replay != null:
			c.clashed.connect(replay.on_clash)


func _physics_process(_dt: float) -> void:
	if not RingRules.stock_on():
		return
	_hook()
	_take_due(false)
	_track_depths()
	if _rules != null and _rules.sudden and not _sudden_seen:
		_sudden_seen = true
		_say_last_life()


## A match's start: every play forgotten.
func reset() -> void:
	_best.clear()
	_due.clear()
	_reset_game()


func _reset_game() -> void:
	_streak.clear()
	_rally = {"n": 0, "team": -1, "at": -INF, "a": null, "b": null}
	_deep.clear()
	_back_at.clear()
	_launches.clear()
	_deficit = [0, 0]
	_last_life_said = false
	_sudden_seen = false


func _on_phase(ph: String) -> void:
	if ph == "COUNTDOWN":
		if int(mode.get(&"round")) <= 1:
			reset()
		else:
			_reset_game()
	elif ph == "DONE":
		_take_due(true)


func _now() -> float:
	return BendStatus.now()


func _tick() -> int:
	return replay.next_tick() if replay != null else 0


func _team(b: Variant) -> int:
	return _rules.team_of(b as Node) if _rules != null and b is Node and is_instance_valid(b) else -1


func _player() -> Node:
	var p: Variant = mode.get(&"player") if mode != null else null
	return p as Node if p is Node and is_instance_valid(p) else null


## The player's side (0; -1 when he is not on the books: bots on both sides).
func my_team() -> int:
	return _team(_player())


# ---------------------------------------------------------------- the plays
func _on_launched(b: Node3D, v: Vector3, _hs: float, by: Node, _tag: String) -> void:
	if by == null or not is_instance_valid(by) or by == b:
		return
	var sp := v.length()
	_launches[b.get_instance_id()] = {"by": by, "v": sp, "at": _now(), "tick": _tick()}
	offer("launch", sp, by, b)


func _on_pct(b: Node3D, _p: float, delta: float) -> void:
	if delta > 0.0 and b != null:
		_streak.erase(b.get_instance_id())        # (a hit taken ends his perfect guards in a row)


func _on_guarded(result: String, what: String, b: Node3D) -> void:
	if not RingRules.stock_on() or not is_instance_valid(b):
		return
	var id := b.get_instance_id()
	if result == "perfect":
		_streak[id] = int(_streak.get(id, 0)) + 1
		offer("perfect", float(_streak[id]), b, null)
		moment.emit("perfect", b, {"n": int(_streak[id])})
	elif result == "late":
		_streak.erase(id)
	if what != "stone" or BendZone.held_stone(b) == null or result == "whiff":
		return
	# an earth catch: how long its guard had stood when the stone came
	var age := INF
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.owner_node == b and bz.kind == "catch":
			age = minf(age, bz.t)
	if age < INF:
		offer("catch", age, b, null)
		var within := float(_call("caught").get("within_s", 0.15))
		if age <= within + 1e-4:
			moment.emit("caught", b, {"t": age})
	# the rally: the other side's last catch within rally_gap_s carries it on
	var t := _team(b)
	var now := _now()
	if int(_rally.team) >= 0 and int(_rally.team) != t and now - float(_rally.at) <= num("rally_gap_s", 4.0):
		_rally.n = int(_rally.n) + 1
	else:
		_rally.n = 1
		_rally.a = null
	_rally.b = _rally.a
	_rally.a = b
	_rally.team = t
	_rally.at = now
	if int(_rally.n) >= 2:
		offer("rally", float(_rally.n), b, _rally.b as Node if _rally.b is Node and is_instance_valid(_rally.b) else null)


func _on_moved(kind: String, b: Node3D) -> void:
	if not is_instance_valid(b):
		return
	var id := b.get_instance_id()
	var d := _deep.get(id, {}) as Dictionary
	if kind in ["rise", "double_jump"] and not d.is_empty():
		d["used"] = true
		d["used_rise"] = bool(d.get("used_rise", false)) or kind == "rise"
	elif kind == "grab":
		_back(b)


## Each body's depth under the deck's top while it is off the deck; back on the deck (or a grab: _back) after a Rise or a
## double jump from deep enough, a recovery.
func _track_depths() -> void:
	if _rules == null or _rules.ring == null:
		return
	var top := _rules.ring.top()
	for t in 2:
		for b in _rules.sides[t]:
			if not (b is Node3D) or not is_instance_valid(b) or _rules.is_away(b):
				continue
			var body := b as Node3D
			var id := body.get_instance_id()
			var rm := RingMoves.of(body)
			var off := rm != null and rm.off_deck()
			var d := _deep.get(id, {}) as Dictionary
			if off:
				var depth := top - body.global_position.y
				if d.is_empty():
					d = {"deepest": 0.0, "used": false, "used_rise": false, "tick": _tick()}
					_deep[id] = d
				if depth > float(d.deepest):
					d["deepest"] = depth
					d["tick"] = _tick()
			elif not d.is_empty():
				_back(body)


func _back(b: Node3D) -> void:
	var id := b.get_instance_id()
	var d := _deep.get(id, {}) as Dictionary
	_deep.erase(id)
	if d.is_empty() or not bool(d.get("used", false)):
		return
	var depth := float(d.deepest)
	if depth < num("recover_min_m", 1.0):
		return
	offer("recover", depth, b, null, int(d.get("tick", _tick())))
	var r := _rules.ring
	var water_down := r.top() - (r.water.level_y if r.water != null else r.top() - 6.0)
	if bool(d.get("used_rise", false)) and depth >= float(_call("rise").get("deep_third", 0.6667)) * water_down:
		moment.emit("rise", b, {"depth": depth})


func _on_respawned(b: Node3D) -> void:
	_back_at[b.get_instance_id()] = _now()


func _on_ko(b: Node3D, by: Node, _pct: float, _tag: String, _left: int) -> void:
	var id := b.get_instance_id()
	_deep.erase(id)
	_streak.erase(id)
	var sender: Node = by if by != null and is_instance_valid(by) and by != b else null
	moment.emit("splash", sender if sender != null else b, {"faller": b})
	# the launch that put him in: its play gets the fall's bonus
	var l := _launches.get(id, {}) as Dictionary
	if not l.is_empty() and _now() - float(l.at) <= num("ko_after_s", 3.0) and is_instance_valid(l.by):
		offer("launch", float(l.v), l.by as Node, b, int(l.tick), num("ko_bonus", 18.0))
	if sender != null:
		var since := _now() - float(_back_at.get(id, _game_start()))
		offer("fast_ko", since, sender, b)
	# lives: the deficits (comebacks) and the last life
	if _rules != null:
		var a := _rules.team_stocks(0)
		var c := _rules.team_stocks(1)
		_deficit[0] = maxi(int(_deficit[0]), c - a)
		_deficit[1] = maxi(int(_deficit[1]), a - c)
		var all_last := true
		for t in 2:
			for o in _rules.sides[t]:
				if is_instance_valid(o) and not _rules.is_gone(o) and _rules.stocks_of(o) != 1:
					all_last = false
		if all_last and a > 0 and c > 0:
			_say_last_life()


func _game_start() -> float:
	var pt: Variant = mode.get(&"phase_t") if mode != null else null
	return _now() - float(pt) if pt != null and String(mode.get(&"phase")) == "FIGHT" else _now()


func _say_last_life() -> void:
	if _last_life_said:
		return
	_last_life_said = true
	moment.emit("last_life", null, {})


func _on_round_over(_result: String, _why: String) -> void:
	if not RingRules.stock_on():
		return
	var w := int(mode.get(&"last_winner"))
	if w < 0 or w > 1:
		return
	var down := int(_deficit[w])
	if down >= int(num("comeback_down", 2.0)):
		var who: Node = null
		for b in _rules.sides[w]:
			if is_instance_valid(b):
				who = b
				break
		offer("comeback", float(down), who, null)
		moment.emit("comeback", who, {"down": down})


func _on_clash(at: Vector3, ka: String, kb: String, _way: Vector3, by_a: Node, by_b: Node) -> void:
	var who := by_a if by_a != null else by_b
	var mine := my_team()
	if by_b != null and _team(by_b) == mine and mine >= 0:
		who = by_b
	var k := data().get("kinds", {}) as Dictionary
	var text := String(k.get("meets", "%s meets %s")) % [String(k.get(ka, ka.capitalize())), String(k.get(kb, kb.capitalize()))]
	offer("clash", 1.0, who, by_b if who == by_a else by_a, -1, 0.0, text)
	moment.emit("clash", who, {"at": at, "a": ka, "b": kb})


func _call(kind: String) -> Dictionary:
	var c: Variant = (Callouts.data().get("calls", {}) as Dictionary).get(kind, {})
	return c if c is Dictionary else {}


## A play of `kind` worth `value`, made by `who` (on `whom`), at tick `at` (-1: now): kept when it beats the kind's best;
## its snapshot taken when it makes the top `cards`. `bonus` added to its score; `text` its number's words (a clash's).
func offer(kind: String, value: float, who: Node, whom: Node, at := -1, bonus := 0.0, text := "") -> bool:
	if not RingRules.stock_on():
		return false
	var cfg := play_cfg(kind)
	if cfg.is_empty():
		return false
	if cfg.has("min") and value < float(cfg.min) - 1e-6:
		return false
	if cfg.has("max") and value > float(cfg.max) + 1e-6:
		return false
	var mine := who != null and is_instance_valid(who) and _team(who) == my_team() and my_team() >= 0
	var score := float(cfg.get("base", 0.0)) + float(cfg.get("per", 0.0)) * value + bonus + (num("mine_bonus", 6.0) if mine else 0.0)
	var have := _best.get(kind, {}) as Dictionary
	if not have.is_empty() and float(have.score) >= score:
		return false
	var p := {"kind": kind, "score": score, "value": value, "who": who if who != null and is_instance_valid(who) else null,
			"whom": whom if whom != null and is_instance_valid(whom) else null, "who_team": _team(who), "mine": mine,
			"at": at if at >= 0 else _tick(), "clip": null, "text": text,
			"who_name": _name_of(who, true), "whom_name": _name_of(whom, false)}
	_best[kind] = p
	_refresh_snapshots()
	return true


## The top `cards` plays hold a snapshot (due after_s after the play); the others let theirs go.
func _refresh_snapshots() -> void:
	var top := _top()
	for k in _best:
		var p := _best[k] as Dictionary
		if p in top:
			if p.clip == null and not _is_due(p):
				_due.append({"play": p, "due": int(p.at) + int(round(RingReplay.sub("highlight", "after_s", 1.0) * _tps()))})
		else:
			p["clip"] = null
	var keep: Array = []
	for d: Dictionary in _due:
		if d.play in top and _best.get(String((d.play as Dictionary).kind)) == d.play:
			keep.append(d)
	_due = keep


func _is_due(p: Dictionary) -> bool:
	for d: Dictionary in _due:
		if d.play == p:
			return true
	return false


func _tps() -> int:
	return replay.tps if replay != null else Engine.physics_ticks_per_second


## The snapshots due now (all of them: `all`, the match over) copied out of the buffer.
func _take_due(all: bool) -> void:
	if _due.is_empty() or replay == null:
		return
	var now := replay.newest_tick()
	var left: Array = []
	for d: Dictionary in _due:
		if not all and int(d.due) > now:
			left.append(d)
			continue
		var p := d.play as Dictionary
		var at := int(p.at)
		var c := replay.snapshot(at - int(round(RingReplay.sub("highlight", "before_s", 3.0) * _tps())), int(d.due))
		if c != null:
			c.faller = replay.slot_index(p.whom) if p.whom != null else replay.slot_index(p.who)
			c.thrower = replay.slot_index(p.who) if p.whom != null else -1
			c.hit_t = at - c.t0 if at >= c.t0 else -1
			c.why = String(p.kind)
			if c.faller < 0:
				c.faller = 0
		p["clip"] = c
	_due = left


## The kinds' bests, the best first, at most `cards` (one per kind).
func _top() -> Array:
	var list: Array = _best.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	return list.slice(0, int(num("cards", 3.0)))


func plays() -> Array:
	return _best.values()


## The cards for the match screen: the best `cards` plays, each {kind, title, line, num, score, clip, mine}.
func cards() -> Array:
	_take_due(true)
	var out: Array = []
	for p: Dictionary in _top():
		var cfg := play_cfg(String(p.kind))
		var line := String(cfg.get("line", "")).format({"who": String(p.who_name), "whom": String(p.whom_name)})
		var nf := String(cfg.get("num", "%s"))
		var n := String(p.text) if String(p.text) != "" else (nf % (int(round(float(p.value))) if nf.contains("%d") else float(p.value)))
		out.append({"kind": p.kind, "title": String(cfg.get("title", p.kind)), "line": line, "num": n, "score": p.score,
				"clip": p.clip, "mine": p.mine})
	return out


## "You" / "The Tide" (`cap`), "you" / "the Tide".
func _name_of(b: Variant, cap: bool) -> String:
	var key := "who" if cap else "whom"
	var w := data().get(key, {}) as Dictionary
	if not (b is Node) or not is_instance_valid(b):
		return String(w.get("them", "%s")) % "Tide"
	if b == _player():
		return String(w.get("you", "You"))
	if RingMode.name_of(b) != "":
		return RingMode.name_of(b)             # (a team format's own name, no article: "Linh")
	var el := RingReplay._element_of(b as Node)
	return String(w.get("them", "%s")) % MatchSetup.competitor(el)
