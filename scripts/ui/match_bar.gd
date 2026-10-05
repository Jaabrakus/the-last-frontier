class_name MatchBar
extends VBoxContainer
## The arena's match bar, top centre (Tidebreak; FrontierHUD.set_arena): what the match says, read off the match node (the
## first in group &"ring_match", through get() and has_method(): its round, score, phase, round_left_s(), side_of(body),
## confined_of(body), and its signals knocked_back, rang_out, round_over, match_over), never a mark of anyone's body:
##   ROUND 2   2:31             the round and the time left in it (a fixed width: the clock's figures never move it)
##   You ● ○  ·  ○ ○ Tide       the score, a pip a round to win, the other side by the name its competitors go by
##   ~ 3 2 1 | 1 2 3 ~          the deck's zones, your half on the left: the zone you are held to marked (your own, the
##                              rule's, not where you stand), the ground each side has lost dimmed (a side's zone from
##                              confined_of: the rule's state, it changes only as a side is pushed back)
##   the event line             1.5 s on a knock back ("Pushed back to zone 2"), a fall into the water, a round's end
## Hidden while there is no match node. The owner's rule (no target cues of any kind): nothing here follows, points at or is
## drawn over the opponent; tests/ring/test_ring_hud.gd moves a bot 10 m and finds nothing on the HUD moving with it.
##   lines() -> {round, time, score, zones, event}; match_node()

const GROUP := &"ring_match"
const EVENT_S := 1.5
const ZONE_W := 26.0
const ZONE_H := 18.0
const WATER_W := 30.0
const MID_W := 14.0

var player: FrontierPlayer

var _round: Label
var _time: Label
var _score: Label
var _zones: Control
var _event: Label
var _event_t := 0.0
var _hooked: Node = null
var _mine := 1
var _theirs := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	_round = FrontierHUD.hud_label(20, FrontierHUD.INK)
	_round.name = "Round"
	_round.custom_minimum_size = Vector2(110, 0)
	_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_round)
	_time = FrontierHUD.hud_label(20, FrontierHUD.GOLD)
	_time.name = "Time"
	_time.custom_minimum_size = Vector2(70, 0)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(_time)
	_score = FrontierHUD.hud_label(17, FrontierHUD.TEXT)
	_score.name = "Score"
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.custom_minimum_size = Vector2(260, 0)
	add_child(_score)
	_zones = Control.new()
	_zones.name = "Zones"
	_zones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zones.custom_minimum_size = Vector2(WATER_W * 2.0 + ZONE_W * 6.0 + MID_W + 10.0, ZONE_H + 6.0)
	_zones.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_zones.draw.connect(_draw_zones)
	add_child(_zones)
	_event = FrontierHUD.hud_label(18, FrontierHUD.INK)
	_event.name = "Event"
	_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event.custom_minimum_size = Vector2(320, 0)
	add_child(_event)
	visible = false


## The match node (the first in group &"ring_match"; null none).
func match_node() -> Node:
	if not is_inside_tree():
		return null
	var ns := get_tree().get_nodes_in_group(GROUP)
	return ns[0] if not ns.is_empty() else null


func _process(dt: float) -> void:
	var m := match_node()
	var hud_on := get_parent() != null and (get_parent() as CanvasItem).is_visible_in_tree()
	if m == null or player == null or not is_instance_valid(player):
		if visible:
			visible = false
		return
	if not visible and hud_on:
		visible = true
	if m != _hooked:
		_hook(m)
	_event_t = maxf(_event_t - dt, 0.0)
	_event.modulate.a = clampf(_event_t / 0.4, 0.0, 1.0)
	var l := lines()
	_round.text = String(l.round)
	_time.text = String(l.time)
	_score.text = String(l.score)
	var z: Array = l.zones
	if int(z[0]) != _mine or int(z[1]) != _theirs:
		_mine = int(z[0])
		_theirs = int(z[1])
		_zones.queue_redraw()


## What it says now: {round: "ROUND 2", time: "2:31", score: "You ● ○  ·  ○ ○ Tide", zones: [your zone, theirs], event}.
func lines() -> Dictionary:
	var m := match_node()
	var out := {"round": "", "time": "", "score": "", "zones": [1, 1], "event": _event.text if _event_t > 0.0 else ""}
	if m == null:
		return out
	out.round = "ROUND %d" % maxi(int(_num(m.get(&"round"), 1)), 1)
	var left := float(m.call(&"round_left_s")) if m.has_method(&"round_left_s") else 0.0
	var s := maxi(ceili(left), 0)
	out.time = "%d:%02d" % [s / 60, s % 60]
	var phase := String(m.get(&"phase")) if m.get(&"phase") != null else ""
	if phase == "COUNTDOWN":
		out.time = "ready"
	var side := _side_of(m, player)
	var sc: Variant = m.get(&"score")
	var mine := 0
	var theirs := 0
	if sc is Vector2i:
		mine = (sc as Vector2i)[side]
		theirs = (sc as Vector2i)[1 - side]
	var to_win := int(_num(m.get(&"rounds_to_win"), MatchSetup.rounds_to_win))
	out.score = "You %s  ·  %s %s" % [_pips(mine, to_win), _pips(theirs, to_win, true), _their_name(m, side)]
	out.zones = [_zone_of(m, player), _their_zone(m, side)]
	return out


static func _num(v: Variant, def: float) -> float:
	return float(v) if v is int or v is float else def


## "● ○" (won first; `rev` for the other side, so the rounds fill from the middle).
static func _pips(won: int, to_win: int, rev := false) -> String:
	var ps := PackedStringArray()
	for i in maxi(to_win, 1):
		ps.append("●" if i < won else "○")
	if rev:
		ps.reverse()
	return " ".join(ps)


## The match's side of `body` (0 or 1; 0 when it cannot say).
static func _side_of(m: Node, body: Node) -> int:
	if m == null or body == null or not m.has_method(&"side_of"):
		return 0
	return clampi(int(m.call(&"side_of", body)), 0, 1)


static func _zone_of(m: Node, body: Node) -> int:
	if m == null or body == null or not m.has_method(&"confined_of"):
		return 1
	return clampi(int(m.call(&"confined_of", body)), 1, 3)


## The other side's competitors (the bodies the match counts on the other side; a rule's question, no position read).
func _theirs_list(m: Node, side: int) -> Array:
	var out: Array = []
	if m == null or not m.has_method(&"side_of"):
		return out
	for n in get_tree().get_nodes_in_group(NpcFighter.GROUP):
		if n != player and is_instance_valid(n) and int(m.call(&"side_of", n)) == 1 - side:
			out.append(n)
	return out


## The ground the other side holds: the zone its furthest-pushed competitor is held to.
func _their_zone(m: Node, side: int) -> int:
	var z := 1
	for n in _theirs_list(m, side):
		z = maxi(z, _zone_of(m, n))
	return z


## The other side by the name its competitors go by (Stone, Tide, Ember, Gale): its fighter's element, else the setup's.
func _their_name(m: Node, side: int) -> String:
	for n in _theirs_list(m, side):
		var el: Variant = n.get(&"element")
		if el is String and String(el) in Bending.ELEMENTS:
			return MatchSetup.competitor(String(el))
	var f := String(MatchSetup.foes[0]) if not MatchSetup.foes.is_empty() else ""
	return MatchSetup.competitor(f) if f in Bending.ELEMENTS else "Rival"


# ---------------------------------------------------------------- the match's moments
func _hook(m: Node) -> void:
	_hooked = m
	if m.has_signal(&"knocked_back"):
		m.connect(&"knocked_back", _on_knocked_back)
	if m.has_signal(&"rang_out"):
		m.connect(&"rang_out", _on_rang_out)
	if m.has_signal(&"round_over"):
		m.connect(&"round_over", _on_round_over)
	if m.has_signal(&"match_over"):
		m.connect(&"match_over", _on_match_over)
	if m.has_signal(&"phase_changed"):
		m.connect(&"phase_changed", func(_p: Variant) -> void: _zones.queue_redraw())


## The event line for EVENT_S.
func say(text: String) -> void:
	_event.text = text
	_event_t = EVENT_S


func _who(n: Variant) -> String:
	if n == player:
		return "You"
	var el: Variant = n.get(&"element") if n is Object and is_instance_valid(n) else null
	return MatchSetup.competitor(String(el)) if el is String and String(el) in Bending.ELEMENTS else "Rival"


func _on_knocked_back(who: Variant, _from_zone: Variant, to_zone: Variant) -> void:
	say("%s pushed back to zone %d" % [_who(who), int(_num(to_zone, 1))] if who != player else "Pushed back to zone %d" % int(_num(to_zone, 1)))
	_zones.queue_redraw()


func _on_rang_out(who: Variant, _by: Variant) -> void:
	say("Into the water" if who == player else "%s into the water" % _who(who))


func _on_round_over(result: Variant, _why: Variant) -> void:
	var r := String(result) if result is String or result is StringName else ""
	match r:
		"player", "you", "win", "a":
			say("Round to you")
		"draw":
			say("Round drawn")
		_:
			say("Round to the other side" if r != "" else "Round over")


func _on_match_over(winner: Variant) -> void:
	var mine := false
	if winner is Node:
		mine = winner == player
	elif winner is int:
		mine = int(winner) == _side_of(match_node(), player)
	elif winner is String or winner is StringName:
		mine = String(winner) in ["player", "you", "a"]
	say("The match is yours" if mine else "The match goes to the other side")


# ---------------------------------------------------------------- the zones
## Water at each end, your half (3 2 1) on the left, the centre strip, theirs (1 2 3) on the right; a lost zone dimmed, the
## zone you are held to ringed in gold.
func _draw_zones() -> void:
	var font := FrontierHUD.serif()
	var x := 5.0
	var y := 3.0
	var water := Color(0.36, 0.6, 0.86, 0.75)
	_zones.draw_rect(Rect2(Vector2(x, y + 4.0), Vector2(WATER_W - 4.0, ZONE_H - 8.0)), water)
	x += WATER_W
	for half in 2:
		var held := _mine if half == 0 else _theirs
		for j in 3:
			var k := 3 - j if half == 0 else j + 1
			var r := Rect2(Vector2(x, y), Vector2(ZONE_W - 3.0, ZONE_H))
			var lost := k < held
			var col := FrontierHUD.TEXT if not lost else Color(FrontierHUD.DIM.r, FrontierHUD.DIM.g, FrontierHUD.DIM.b, 0.35)
			_zones.draw_rect(r, Color(0.02, 0.015, 0.01, 0.35 if not lost else 0.15))
			var s := str(k)
			var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_zones.draw_string(font, Vector2(r.get_center().x - tw * 0.5, r.end.y - 4.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
			if half == 0 and k == held:
				_zones.draw_rect(r.grow(1.0), FrontierHUD.GOLD, false, 1.5)
			x += ZONE_W
		if half == 0:
			_zones.draw_line(Vector2(x + MID_W * 0.5 - 1.5, y), Vector2(x + MID_W * 0.5 - 1.5, y + ZONE_H), FrontierHUD.INK, 1.5)
			x += MID_W
	_zones.draw_rect(Rect2(Vector2(x + 1.0, y + 4.0), Vector2(WATER_W - 4.0, ZONE_H - 8.0)), water)
