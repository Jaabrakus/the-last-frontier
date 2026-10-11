extends "res://tools/ring/highlight_input.gd"
## Cheese hunt, lens "team" (2v2 / 4v4 only): the film's expert player (tools/ring/highlight_input.gd: ordinary key and
## mouse actions through his PlayerControls and the game's own input events; nothing of the fighters is written) with a
## team format's target pick (the nearest opponent in play, not the first foe only) and a WAY:
##   deck        the expert as he is (the baseline: normal good play), at the nearest opponent in play
##   focus       the same, but always on his own team-mate's target when it has one (the player + a bot on one foe)
##   perch       up his own end's perch (its stairs) and stays on it: aims at the nearest opponent in play, casts as the
##               expert does, guards (E) what flies at him; knocked down, he walks back up
##   perch_idle  the same perch, no attack at all: only the guard (pure stalling: keep the lives, wait for the bell)
##   hide        his own end's far corner on the deck (not the perch side), guard only
## Books (read by team_probe.gd): perch_s (seconds on the perch top), climbs (times he reached it), knocked_off.

var way := "deck"
var perch := {}            ## the perch piece he uses ({} none)
var perch_s := 0.0
var climbs := 0
var knocked_off := 0
var on_top := false
var target: Node3D = null
var _was_top := false


func _physics_process(dt: float) -> void:
	_t += dt
	if player == null or not is_instance_valid(player) or mode == null or not is_instance_valid(mode):
		return
	_hook()
	_untap()
	if mode.phase != "FIGHT":
		_let_go()
		_launch = {}
		return
	var rm := RingMoves.of(player)
	var foe := _pick()
	target = foe
	on_top = _on_perch_top()
	if on_top:
		perch_s += dt
	if on_top and not _was_top:
		climbs += 1
	if _was_top and not on_top:
		knocked_off += 1
	_was_top = on_top
	if rm == null or (_rules != null and _rules.is_away(player)):
		_let_go()
		return
	_books(rm)
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_thrown(rm)
		return
	_hold(&"jump", false)
	match way:
		"perch", "perch_idle":
			_perch_step(foe, dt)
		"hide":
			_hide_step(foe, dt)
		_:
			if foe == null:
				_let_go()
				return
			_mouse(foe, dt)
			_feet(foe)
			_hands(foe)
			_guard(foe)


## The opponent he fights: the nearest one in play (focus: his team-mate's target when that one is in play).
func _pick() -> Node3D:
	var rules := mode.rules
	if rules == null:
		return null
	if way == "focus":
		for b in rules.sides[0]:
			if b is NpcFighter and is_instance_valid(b) and (b as NpcFighter).brain != null and mode.in_play(b):
				var tg: Variant = (b as NpcFighter).brain.target
				if tg is Node3D and is_instance_valid(tg) and mode.in_play(tg) and rules.team_of(tg as Node) == 1:
					return tg as Node3D
	var best: Node3D = null
	var bd := INF
	for o in rules.sides[1]:
		if o is Node3D and is_instance_valid(o) and mode.in_play(o):
			var d := player.global_position.distance_to((o as Node3D).global_position)
			if d < bd:
				bd = d
				best = o as Node3D
	return best


# ---------------------------------------------------------------- the perch
## His own end's perch piece (kind "perch" on his half of the deck).
static func own_perch(ring: RingArena, end: int) -> Dictionary:
	var sg := RingArena.side_sign(end)
	for pc: Dictionary in ring.pieces():
		if String(pc.kind) == "perch" and signf((pc.rect as Rect2).get_center().x) == sg:
			return pc
	return {}


func _on_perch_top() -> bool:
	if perch.is_empty():
		return false
	var ring := mode.ring
	var l := ring.to_local(player.global_position)
	return (perch.rect as Rect2).grow(0.1).has_point(Vector2(l.x, l.z)) and l.y > ring.top() + float(perch.h) - 0.5


## The way up: the stairs' foot (1.5 m out past its low end), then the perch's middle.
func _foot_and_top() -> Array:
	var rp: Dictionary = perch.ramp
	var r: Rect2 = rp.rect
	var c := r.get_center()
	var foot := c
	match String(rp.up):
		"+x":
			foot = Vector2(r.position.x - 1.5, c.y)
		"-x":
			foot = Vector2(r.end.x + 1.5, c.y)
		"+z":
			foot = Vector2(c.x, r.position.y - 1.5)
		_:
			foot = Vector2(c.x, r.end.y + 1.5)
	return [foot, (perch.rect as Rect2).get_center()]


func _perch_step(foe: Node3D, dt: float) -> void:
	var ring := mode.ring
	if perch.is_empty():
		perch = own_perch(ring, mode.player_end)
	if foe != null:
		_mouse(foe, dt)
	if perch.is_empty():
		_walk_to(Vector2.ZERO, 0.0)
		return
	var l := ring.to_local(player.global_position)
	var p := Vector2(l.x, l.z)
	var ft: Array = _foot_and_top()
	var foot: Vector2 = ft[0]
	var top: Vector2 = ft[1]
	if on_top:
		_walk_to(top, 0.8)
		if foe != null:
			if way == "perch":
				_hands(foe)
			_guard(foe)
		return
	if _corridor().has_point(p) or p.distance_to(foot) < 1.0:
		_walk_to(top, 0.3)
	else:
		_walk_to(_detour(p, foot), 0.3)
	if foe != null:
		_guard(foe)


## A corner to go round the perch and its stairs when the straight way to `goal` runs through them (beside them at deck
## level: out to the nearest open side first).
func _detour(p: Vector2, goal: Vector2) -> Vector2:
	var un := (perch.rect as Rect2).merge((perch.ramp as Dictionary).rect as Rect2)
	var u := un.grow(1.0)
	var inner := un.grow(0.6)
	var hw := mode.ring.half_w() - 0.8
	var hl := mode.ring.half_l() - 0.8
	if inner.has_point(p) and not _corridor().has_point(p):
		var outs := [Vector2(u.position.x, p.y), Vector2(u.end.x, p.y), Vector2(p.x, u.position.y), Vector2(p.x, u.end.y)]
		var bo := goal
		var bdo := INF
		for o: Vector2 in outs:
			if (o.y != p.y and absf(o.y) > hw) or (o.x != p.x and absf(o.x) > hl):
				continue
			if p.distance_to(o) < bdo:
				bdo = p.distance_to(o)
				bo = o
		return bo
	if not _seg_hits(p, goal, inner):
		return goal
	var corners := [u.position, Vector2(u.end.x, u.position.y), u.end, Vector2(u.position.x, u.end.y)]
	var best := goal
	var bd := INF
	for c: Vector2 in corners:
		if absf(c.y) > hw or absf(c.x) > hl or p.distance_to(c) < 0.6:
			continue
		if _seg_hits(p, c, inner):
			continue
		var d := p.distance_to(c) + c.distance_to(goal)
		if d < bd:
			bd = d
			best = c
	return best


## The stairs' footprint with a 2 m apron before its low end: in it he walks straight up to the top.
func _corridor() -> Rect2:
	var rp: Dictionary = perch.ramp
	var r: Rect2 = rp.rect
	match String(rp.up):
		"+x":
			return Rect2(r.position.x - 2.0, r.position.y, r.size.x + 2.0, r.size.y)
		"-x":
			return Rect2(r.position.x, r.position.y, r.size.x + 2.0, r.size.y)
		"+z":
			return Rect2(r.position.x, r.position.y - 2.0, r.size.x, r.size.y + 2.0)
	return Rect2(r.position.x, r.position.y, r.size.x, r.size.y + 2.0)


static func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	for i in 21:
		if r.has_point(a.lerp(b, float(i) / 20.0)):
			return true
	return false


## WASD held toward local deck point `goal` (his camera stays where _mouse put it: he strafes); nothing within `stop_m`.
func _walk_to(goal: Vector2, stop_m: float) -> void:
	var ring := mode.ring
	var l := ring.to_local(player.global_position)
	var d := goal - Vector2(l.x, l.z)
	if d.length() <= stop_m:
		_hold_world(Vector3.ZERO)
		return
	var w := ring.global_basis * Vector3(d.x, 0.0, d.y)
	w.y = 0.0
	_hold_world(w.normalized())


# ---------------------------------------------------------------- the hide
func _hide_step(foe: Node3D, dt: float) -> void:
	var ring := mode.ring
	if foe != null:
		_mouse(foe, dt)
		_guard(foe)
	var sg := RingArena.side_sign(mode.player_end)
	var own := own_perch(ring, mode.player_end)
	var zs := -1.0
	if not own.is_empty():
		zs = -signf((own.rect as Rect2).get_center().y)      # (the corner away from his own perch)
	_walk_to(Vector2(sg * (ring.half_l() - 3.0), zs * (ring.half_w() - 3.0)), 0.6)
