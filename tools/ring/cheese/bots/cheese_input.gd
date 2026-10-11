extends "res://tools/ring/highlight_input.gd"
## Cheese hunt, lens "bots": the film player's own hands (tools/ring/highlight_input.gd, expert model: ordinary key and mouse
## inputs through the player's PlayerControls, nothing of the game written) with a strategy on top. No damage, launch, %
## or result is written here: every effect comes from the keys.
##   expert   the baseline: highlight_input as it is (the nearest enemy in play is "the foe" in a team format)
##   idle     stands, camera on the foe, presses nothing on the deck (recovers like the expert when thrown)
##   perch    team formats: up the nearest Ruins perch by its stairs, stays on top, fights from there with the expert's
##            hands (no walking at the foe); back up the stairs when knocked down
##   hop      the expert, plus Space at every landing (always in the air)
##   crouch   holds C on the deck (ducked, still), camera on the foe, no attack
##   jab      walks in and only clicks LMB (the jab string) in reach

var strat := "expert"
## The enemy fought now (nearest in play in a team format; mode.foe in 1v1).
var cur: Node3D = null
## perch: the waypoints (world) of the climb, the index reached, the perch's own centre.
var _route: Array = []
var _route_i := 0
var perch_top_s := 0.0          ## seconds on the perch's top (books)
var _hop_cd := 0.0
## Seconds of FIGHT this driver has played (the switch's clock).
var fight_t := 0.0


func pick_enemy() -> Node3D:
	if mode.team_n() <= 1:
		return mode.foe if mode.foe != null and is_instance_valid(mode.foe) else null
	var best: Node3D = null
	var bd := INF
	for b in mode.rules.sides[1]:
		if not (b is Node3D) or not is_instance_valid(b) or not mode.in_play(b):
			continue
		var d := (b as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = b as Node3D
	return best


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
	cur = pick_enemy()
	if rm == null or cur == null or (_rules != null and _rules.is_away(player)):
		_let_go()
		return
	_books(rm)
	fight_t += dt
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_hold(&"crouch", false)
		_thrown(rm)
		return
	var st := strat
	if strat.contains(">"):
		# ("a>b@t": strategy a for the first t s of the fight, then b; the film's before and after in one take)
		var at := float(strat.get_slice("@", 1))
		var ab := strat.get_slice("@", 0)
		st = ab.get_slice(">", 0) if fight_t < at else ab.get_slice(">", 1)
	match st:
		"idle":
			_hold(&"jump", false)
			_mouse(cur, dt)
			for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				_hold(a, false)
		"crouch":
			_hold(&"jump", false)
			_mouse(cur, dt)
			for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				_hold(a, false)
			_hold(&"crouch", true)
		"perch":
			_hold(&"jump", false)
			_perch(dt)
		"hop":
			_mouse(cur, dt)
			_feet(cur)
			_hands(cur)
			_guard(cur)
			_hop_cd -= dt
			var air := rm.airborne()
			if not air and player.is_on_floor() and _hop_cd <= 0.0 and not player.controls.pressed(&"aim"):
				_tap(&"jump", 0.05)
				_hop_cd = 0.15
			elif not _taps.has(&"jump"):
				_hold(&"jump", false)
		"hopidle":
			# (Space at every landing, nothing else: the camera on him)
			_mouse(cur, dt)
			for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				_hold(a, false)
			if not rm.airborne() and player.is_on_floor() and not _taps.has(&"jump"):
				_tap(&"jump", 0.05)
		"hop1":
			# (Space at every landing; key 1's moves only (its double tap now and then), the jab when he is close, E as the
			# expert taps it; the feet keep the expert's distance)
			_mouse(cur, dt)
			_feet(cur)
			_hands1(cur)
			_guard(cur)
			if not rm.airborne() and player.is_on_floor() and not _taps.has(&"jump"):
				_tap(&"jump", 0.05)
		"slamhop":
			_mouse(cur, dt)
			_slamhop(dt, rm)
			_guard(cur)
		"run", "runhop":
			_mouse(cur, dt)
			_run(dt, st == "runhop", rm)
			_guard(cur)
		"hide", "hidecol":
			_hold(&"jump", false)
			_hide(dt, st == "hidecol")
		"jab":
			_hold(&"jump", false)
			_mouse(cur, dt)
			var d := _flat_d(cur)
			_hold(&"move_forward", d > 2.0)
			for a: StringName in [&"move_back", &"move_left", &"move_right"]:
				_hold(a, false)
			if d <= 3.2 and _t >= _next_click:
				_next_click = _t + rng.randf_range(0.18, 0.28)
				_tap(&"fire", 0.05)
				clicks += 1
		_:
			_hold(&"jump", false)
			_mouse(cur, dt)
			_feet(cur)
			_hands(cur)
			_guard(cur)


# ---------------------------------------------------------------- perch
## The nearest perch: its rect, height, its stairs' rect and way up; the climb's foot (a step out from the stairs' low end),
## head (on the perch past the stairs' top) and middle (deck-local 2D).
var _pc := {}


func _pick_perch() -> void:
	var ring := mode.ring
	var bd := INF
	# (the perch on its own half: the one on its team's flank, by the side of the deck its end holds)
	var own := signf(ring.to_local(ring.spawn(mode.player_end).origin).x)
	for pc: Dictionary in ring.pieces():
		if String(pc.get("kind", "")) != "perch":
			continue
		var r: Rect2 = pc.rect
		var c := ring.to_global(Vector3(r.get_center().x, ring.top(), r.get_center().y))
		var d := c.distance_to(player.global_position) + (0.0 if signf(r.get_center().x) == own else 100.0)
		if d < bd:
			bd = d
			_pc = pc
	if _pc.is_empty():
		return
	var rp: Dictionary = _pc.get("ramp", {})
	var rr: Rect2 = rp.rect
	var cz := rr.get_center().y
	var cx := rr.get_center().x
	var foot := Vector2.ZERO
	var head := Vector2.ZERO
	match String(rp.get("up", "+x")):
		"+x":
			foot = Vector2(rr.position.x - 1.2, cz)
			head = Vector2(rr.end.x + 0.8, cz)
		"-x":
			foot = Vector2(rr.end.x + 1.2, cz)
			head = Vector2(rr.position.x - 0.8, cz)
		"+z":
			foot = Vector2(cx, rr.position.y - 1.2)
			head = Vector2(cx, rr.end.y + 0.8)
		_:
			foot = Vector2(cx, rr.end.y + 1.2)
			head = Vector2(cx, rr.position.y - 0.8)
	_pc["foot"] = foot
	_pc["head"] = head
	_pc["mid"] = (_pc.rect as Rect2).get_center()
	set_meta(&"perch_rect", _pc.rect)
	set_meta(&"perch_h", float(_pc.h))


func _loc2(p: Vector3) -> Vector2:
	var l := mode.ring.to_local(p)
	return Vector2(l.x, l.z)


func _to_world(v: Vector2) -> Vector3:
	return mode.ring.to_global(Vector3(v.x, mode.ring.top(), v.y))


func on_perch() -> bool:
	if _pc.is_empty():
		return false
	var l := mode.ring.to_local(player.global_position)
	return (_pc.rect as Rect2).grow(0.1).has_point(Vector2(l.x, l.z)) and l.y > mode.ring.top() + float(_pc.h) - 0.5


func _on_ramp() -> bool:
	var rr: Rect2 = (_pc.ramp as Dictionary).rect
	return rr.grow(0.15).has_point(_loc2(player.global_position)) and mode.ring.to_local(player.global_position).y > mode.ring.top() + 0.15


## The obstacles for walking on the deck: every piece's footprint and its stairs', grown.
func _blocks(grow := 0.55) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pc: Dictionary in mode.ring.pieces():
		out.append((pc.rect as Rect2).grow(grow))
		var rp: Variant = pc.get("ramp")
		if rp is Dictionary:
			out.append(((rp as Dictionary).rect as Rect2).grow(grow))
	return out


static func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


func _clear(a: Vector2, b: Vector2, blocks: Array[Rect2]) -> bool:
	for r in blocks:
		if _seg_hits(a, b, r):
			return false
	return true


## The next deck point toward `goal` round the pieces (a visibility graph over the grown footprints' corners).
func _next_toward(from: Vector2, goal: Vector2) -> Vector2:
	var blocks := _blocks()
	if _clear(from, goal, blocks):
		return goal
	var nodes: Array[Vector2] = [from, goal]
	var big := _blocks(0.85)
	for r in big:
		for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var inside := false
			for q in blocks:
				if q.has_point(c):
					inside = true
					break
			if not inside:
				nodes.append(c)
	var n := nodes.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var done: Array[bool] = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		done.append(false)
	dist[0] = 0.0
	for _k in n:
		var u := -1
		var bu := INF
		for i in n:
			if not done[i] and dist[i] < bu:
				bu = dist[i]
				u = i
		if u < 0 or u == 1:
			break
		done[u] = true
		for v in n:
			if done[v] or v == u:
				continue
			if not _clear(nodes[u], nodes[v], blocks):
				continue
			var nd := dist[u] + nodes[u].distance_to(nodes[v])
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if prev[1] < 0:
		return goal
	var at := 1
	while prev[at] != 0 and prev[at] >= 0:
		at = prev[at]
	return nodes[at]


func _walk_to(g: Vector2, dt: float) -> void:
	var to := _to_world(g) - player.global_position
	to.y = 0.0
	var want_yaw := atan2(-to.x, -to.z)
	var k := 1.0 - exp(-12.0 * dt)
	player.yaw += wrapf(want_yaw - player.yaw, -PI, PI) * k
	player.pitch = lerpf(player.pitch, -0.15, k)
	if to.length_squared() > 1e-4:
		_hold_world(to.normalized())


func _perch(dt: float) -> void:
	if _pc.is_empty():
		_pick_perch()
		if _pc.is_empty():
			return
	if on_perch():
		perch_top_s += dt
		# (on top: the camera on the nearest enemy and the expert's hands; the feet only keep it near the middle)
		_mouse(cur, dt)
		var to := _to_world(_pc.mid as Vector2) - player.global_position
		to.y = 0.0
		if to.length() > 0.8 and not player.controls.pressed(&"aim"):
			_hold_world(to.normalized())
		else:
			for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				_hold(a, false)
		_hands(cur)
		_guard(cur)
		return
	var here := _loc2(player.global_position)
	_guard(cur)
	if _on_ramp():
		_walk_to(_pc.head as Vector2, dt)
		return
	var foot: Vector2 = _pc.foot
	if here.distance_to(foot) < 0.6:
		_walk_to(_pc.head as Vector2, dt)
		return
	_walk_to(_next_toward(here, foot), dt)


# ---------------------------------------------------------------- run (keep away, Shift held)
## Away from the nearest enemy, kept off the lips: the way from him, the lips within edge_m pushing it back in, along the
## lip the side that opens the gap; Shift held (sprint), E as the expert taps it; runhop: Space at each landing too.
var run_edge_m := 3.5
var run_s := 0.0


func _run(dt: float, hop: bool, rm: RingMoves) -> void:
	run_s += dt
	var ring := mode.ring
	var p := _loc2(player.global_position)
	var foes: Array = []
	for b in mode.rules.sides[1]:
		if b is Node3D and is_instance_valid(b) and mode.in_play(b):
			foes.append(_loc2((b as Node3D).global_position))
	if foes.is_empty():
		return
	var away := Vector2.ZERO
	for f: Vector2 in foes:
		var d := p - f
		var l := maxf(d.length(), 0.3)
		away += d / l / l * 4.0
	if away.length() < 1e-3:
		away = Vector2(1, 0)
	var hl := ring.half_l()
	var hw := ring.half_w()
	var push := Vector2.ZERO
	var e := run_edge_m
	if p.x > hl - e:
		push.x -= (p.x - (hl - e)) / e
	if p.x < -hl + e:
		push.x += (-hl + e - p.x) / e
	if p.y > hw - e:
		push.y -= (p.y - (hw - e)) / e
	if p.y < -hw + e:
		push.y += (-hw + e - p.y) / e
	var want := away.normalized()
	if push.length() > 0.0:
		# (an edge near: its outward part taken off, the push in added, and along it the way that opens the gap)
		var n := -push.normalized()
		var outward := want.dot(n)
		if outward > 0.0:
			want -= n * outward
		var tan := Vector2(-n.y, n.x)
		var f0: Vector2 = foes[0]
		var s := 1.0 if (p + tan - f0).length() > (p - tan - f0).length() else -1.0
		want += tan * s * 0.8 + push * 2.0
	if want.length() < 1e-3:
		want = Vector2(-p.x, -p.y)
	want = want.normalized()
	var w := ring.global_basis * Vector3(want.x, 0.0, want.y)
	w.y = 0.0
	_hold_world(w.normalized())
	_hold(&"sprint", true)
	if hop:
		if not rm.airborne() and player.is_on_floor() and not _taps.has(&"jump"):
			_tap(&"jump", 0.05)
	else:
		_hold(&"jump", false)


# ---------------------------------------------------------------- hide (behind a Ruins wall, ducked)
## The wall piece whose far face (from the enemies in play) is nearest: the spot hide_off_m off that face, at its middle;
## walked to round the pieces, then C held there (ducked, still). hidecol: from there, the element's up-from-under move
## (earth's Column, water's Spout: key 2 tapped twice) at the nearest enemy when the lock is free, else nothing.
var hide_off_m := 0.55
var hide_s := 0.0
var _hide_spot := Vector2.INF
var _hide_t := 0.0
var _col_at := 0.0


func _enemy_centroid() -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for b in mode.rules.sides[1]:
		if b is Node3D and is_instance_valid(b) and mode.in_play(b):
			c += _loc2((b as Node3D).global_position)
			n += 1
	return c / float(n) if n > 0 else Vector2.ZERO


func _pick_hide() -> void:
	var e := _enemy_centroid()
	var here := _loc2(player.global_position)
	var best := Vector2.INF
	var bd := INF
	for pc: Dictionary in mode.ring.pieces():
		if String(pc.get("kind", "")) not in ["wall", "pillar"]:
			continue
		var r: Rect2 = pc.rect
		var ctr := r.get_center()
		var away := ctr - e
		var spot := Vector2.ZERO
		# (the face whose outward normal points most away from the enemies)
		if absf(away.x) * r.size.y >= absf(away.y) * r.size.x:
			spot = Vector2(r.end.x + hide_off_m if away.x > 0.0 else r.position.x - hide_off_m, ctr.y)
		else:
			spot = Vector2(ctr.x, r.end.y + hide_off_m if away.y > 0.0 else r.position.y - hide_off_m)
		var d := here.distance_to(spot) + 0.5 * spot.distance_to(Vector2.ZERO) * 0.0
		if d < bd:
			bd = d
			best = spot
	_hide_spot = best


func at_hide() -> bool:
	return _hide_spot != Vector2.INF and _loc2(player.global_position).distance_to(_hide_spot) < 0.45


func _hide(dt: float, col: bool) -> void:
	_hide_t -= dt
	if _hide_spot == Vector2.INF or _hide_t <= 0.0:
		_hide_t = 2.0
		_pick_hide()
	if _hide_spot == Vector2.INF:
		return
	var here := _loc2(player.global_position)
	if here.distance_to(_hide_spot) > 0.45:
		_hold(&"crouch", false)
		_walk_to(_next_toward(here, _hide_spot), dt)
		_guard(cur)
		return
	hide_s += dt
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		_hold(a, false)
	_mouse(cur, dt)
	if not col:
		_hold(&"crouch", true)
		return
	# (hidecol: ducked between casts; the Column / Spout aimed at the nearest enemy when free: key 2, key 2 again 0.1 s
	# later (the double tap), then the right button clicked)
	if _k2_at > 0.0:
		_hold(&"crouch", false)
		if _t >= _k2_at:
			_k2_at = -1.0
			_key(&"weapon_2")
			_tap(&"aim", 0.08)
			casts += 1
		return
	var caster := SwayCaster.of(player)
	var busy := caster != null and caster.state != SwayCaster.State.IDLE
	if busy or player.controls.pressed(&"aim"):
		_hold(&"crouch", false)
		return
	_hold(&"crouch", true)
	if _t >= _col_at and _flat_d(cur) < 18.0:
		_col_at = _t + 2.2
		_hold(&"crouch", false)
		_key(&"weapon_2")
		_k2_at = _t + 0.10


var _k2_at := -1.0


## hop1's hands: the expert's rhythm with key 1 only (a key-1 move works in the air as on the deck; key 2's first move would
## be the Slam there): the jab within 3.8 m half the time, else key 1 (its other move every third cast), clicked.
func _hands1(foe: Node3D) -> void:
	if _second_at > 0.0:
		if _t >= _second_at:
			_second_at = -1.0
			_key(&"weapon_1")
			_tap(&"aim", 0.08)
		return
	if _t < _attack_at:
		return
	var caster := SwayCaster.of(player)
	if caster == null or caster.state != SwayCaster.State.IDLE or player.controls.pressed(&"aim"):
		return
	attack_n += 1
	if _flat_d(foe) < 3.8 and attack_n % 2 == 0:
		_tap(&"fire", 0.06)
		clicks += 1
		_attack_at = _t + 0.45
		return
	_key(&"weapon_1")
	if attack_n % 3 == 0:
		_second_at = _t + 0.10
	else:
		_tap(&"aim", 0.08)
	casts += 1
	_attack_at = _t + 1.0


# ---------------------------------------------------------------- slamhop (the Slam, again and again)
## Walks in to Slam reach; Space; at slam_at_s into the jump key 2 and a click (key 2's first move begun in the air is the
## Slam: its column comes down before him); drifts at him meanwhile; lands; again. Nothing else but E as the expert taps it.
var slam_at_s := 0.2
var slams := 0
var _sh_phase := "walk"
var _sh_t := 0.0


func _slamhop(dt: float, rm: RingMoves) -> void:
	_sh_t += dt
	var d := _flat_d(cur)
	var to := cur.global_position - player.global_position
	to.y = 0.0
	match _sh_phase:
		"walk":
			_hold(&"jump", false)
			if to.length() > 0.01:
				_hold_world(to.normalized())
			if d < 2.6 and player.is_on_floor() and not rm.airborne():
				var caster := SwayCaster.of(player)
				if caster == null or caster.state == SwayCaster.State.IDLE:
					_tap(&"jump", 0.05)
					_sh_phase = "up"
					_sh_t = 0.0
		"up":
			if to.length() > 0.01 and d > 1.0:
				_hold_world(to.normalized())
			else:
				for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
					_hold(a, false)
			if _sh_t >= slam_at_s and rm.airborne():
				_key(&"weapon_2")
				_tap(&"aim", 0.06)
				casts += 1
				slams += 1
				_sh_phase = "down"
				_sh_t = 0.0
			elif _sh_t > 0.6:
				_sh_phase = "walk"
		"down":
			for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				_hold(a, false)
			if (player.is_on_floor() and not rm.airborne() and _sh_t > 0.3) or _sh_t > 1.5:
				_sh_phase = "walk"
				_sh_t = 0.0
