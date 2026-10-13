extends RefCounted
## Round 3 BOTS' stand-ins for the parts the other round-3 tasks build (PERCENT's RingRules, MOVE's RingMoves and
## RingPredict), so the bots', Practice's and the lessons' tests run before those merge. Each is a subclass or an object of
## the contract's shape (smash_r3 spec §14.3); none is used by the game. preload("res://tests/npc/r3_standins.gd").
##   FakeRules    a RingRules with rule_set "stock" whose per-body answers the test sets (f_pct, stun_for, f_string, ...);
##                install_rules() makes it RingRules.current() (the gate on) without a ring, uninstall() takes it back
##   FakeMoves    a RingMoves on a body driven by NpcRingMind's stand-in mover from the pad's intent each step (drive): its
##                airborne, off_deck, on_ledge, jumps_left, dodge_ready, rise_ready; sim_state() for the planner; a teeter on
##                the deck (it never walks off), the go() goal turned into pad.move (MOVE's NpcFighter does it)
##   FakePredict  flight / would_ko / ko_pct by a small ballistic model (gravity 20, the carry's decay 8, the water 6 m down,
##                the curtain 10 m out) over a few of the spec's classes (§2.3)


class FakeRules:
	extends RingRules
	var f_pct := {}
	var f_stun := {}
	var f_escape := {}
	var f_string := {}
	var f_stale := {}
	var f_steer := {}
	var f_fresh := {}
	var f_safe := {}
	var f_heal := true
	var resets: Array = []

	func _init() -> void:
		rule_set = "stock"

	static func _id(b: Node) -> int:
		return b.get_instance_id() if b != null and is_instance_valid(b) else 0

	func pct_of(b: Node) -> float:
		return float(f_pct.get(_id(b), 0.0))

	func stocks_of(_b: Node) -> int:
		return 3

	func safe_until(b: Node) -> float:
		return float(f_safe.get(_id(b), -INF))

	## b in hitstun for `s` s from now.
	func stun_for(b: Node, s: float) -> void:
		f_stun[_id(b)] = BendStatus.now() + s

	func hitstun_left(b: Node) -> float:
		return maxf(float(f_stun.get(_id(b), -INF)) - BendStatus.now(), 0.0)

	func stunned(b: Node) -> bool:
		return hitstun_left(b) > 0.0

	func can_escape(b: Node) -> bool:
		return bool(f_escape.get(_id(b), false))

	func string_hits(b: Node) -> int:
		return int(f_string.get(_id(b), 0))

	func stale_count(a: Node, tag: String) -> int:
		return int(f_stale.get("%d/%s" % [_id(a), tag], 0))

	func last_steer_deg(b: Node) -> float:
		return float(f_steer.get(_id(b), 0.0))

	func fresh_pct(b: Node) -> float:
		return float(f_fresh.get(_id(b), 0.0))

	func heal_allowed(_b: Node) -> bool:
		return f_heal

	func reset_pct(b: Node, to := 0.0) -> void:
		resets.append([_id(b), to])
		f_pct[_id(b)] = to
		pct_changed.emit(b as Node3D, to, 0.0)


static func install_rules() -> FakeRules:
	var r := FakeRules.new()
	RingRules._current = r
	return r


static func uninstall(r: FakeRules) -> void:
	if RingRules._current == r:
		RingRules._current = null
	if r != null and is_instance_valid(r):
		r.free()


## MOVE's RingMoves stood in by NpcRingMind's stand-in mover (drive each step from the pad's intent).
class FakeMoves:
	extends RingMoves
	var s := {}
	var geo := {}
	var on_deck := false
	var hanging := false
	var out := false
	var grabs := 0
	var refused := 0
	var run_mps := 5.0

	## Put on `b` (a body over or on the deck of arena `a`) with world state `st` (NpcRingMind.body_state's keys).
	static func put(b: Node3D, a: RingArena, st: Dictionary) -> FakeMoves:
		var old := RingMoves.of(b)
		if old != null:
			b.remove_child(old)
			old.free()
		var m := FakeMoves.new()
		m.name = RingMoves.NODE_NAME
		m.body = b as CharacterBody3D
		m.geo = NpcRingMind.geo_of(a)
		m.s = NpcRingMind.standin_state(st, m.geo)
		b.add_child(m)
		m._sync()
		return m

	func _sync() -> void:
		jumps_left = int(s.get("jumps", 0))
		dodge_ready = bool(s.get("dodge", false))
		rise_ready = bool(s.get("rise", false)) and int(s.get("jumps", 0)) <= 0 and not on_deck
		var xf: Transform3D = geo.xf
		var pw: Vector3 = Vector3(s.p) + Vector3.UP * (float(geo.top) - xf.origin.y)
		body.global_position = xf * pw

	func airborne() -> bool:
		return not on_deck and not hanging

	func off_deck() -> bool:
		return not on_deck and (NpcRingMind._standin_off(Vector3(s.p), float(geo.hl), float(geo.hw)) or hanging)

	func on_ledge() -> bool:
		return hanging

	func helpless() -> bool:
		return bool(s.get("helpless", false))

	## The first grab's safety left (a test sets safe_left).
	var safe_left := 0.0

	func ledge_safe_left() -> float:
		return safe_left

	func sim_state() -> Dictionary:
		var b: Basis = (geo.xf as Transform3D).basis
		return {"vel": b * Vector3(s.v), "carry": b * Vector3(s.c), "jumps_left": int(s.jumps), "dodge_ready": bool(s.dodge),
				"rise_ready": bool(s.rise), "helpless": bool(s.helpless), "grabs_left": int(s.grabs_left)}

	## One step from `intent` (world): on the deck a walk with a teeter (never off it) and a jump; in the air the stand-in.
	func drive(intent: Dictionary, dt: float) -> void:
		if out:
			return
		var inv: Basis = (geo.xf as Transform3D).basis.inverse()
		var li := intent.duplicate()
		li.move = inv * Vector3(intent.get("move", Vector3.ZERO))
		li.dodge_dir = inv * Vector3(intent.get("dodge_dir", Vector3.ZERO))
		li.aim = inv * Vector3(intent.get("aim", Vector3.ZERO))
		if on_deck:
			var p: Vector3 = s.p
			var mv: Vector3 = li.move
			mv.y = 0.0
			p += mv.normalized() * run_mps * dt if mv.length_squared() > 1e-4 else Vector3.ZERO
			p.x = clampf(p.x, -float(geo.hl) + 0.3, float(geo.hl) - 0.3)
			p.z = clampf(p.z, -float(geo.hw) + 0.3, float(geo.hw) - 0.3)
			p.y = 0.0
			s.p = p
			if bool(li.get("jump", false)):
				on_deck = false
				s.v = mv.normalized() * run_mps + Vector3.UP * float(NpcRingMind.standin_nums().get("jump_v", 8.94))
				s.jumps = 1
				s.dodge = true
				s.rise = true
				s.helpless = false
				s.last_jump_t = s.t
				s.how = ""
				s.p = p + Vector3.UP * 0.01
			_sync()
			return
		if hanging:
			_sync()
			return
		NpcRingMind.standin_step(s, li, dt, geo)
		refused = int(s.get("refused", 0))
		match String(s.how):
			"deck":
				on_deck = true
				s.how = ""
				s.v = Vector3.ZERO
				s.c = Vector3.ZERO
				s.grabs_left = 3
			"grab":
				hanging = true
				grabs += 1
				moved.emit("grab")
			"water":
				out = true
		_sync()


## RingPredict stood in: a small ballistic model of a launch from the deck (spec §2.2's physics, no recovery).
class FakePredict:
	extends RefCounted
	var a: RingArena
	## A few classes (spec §2.3): [d, base, growth, angle].
	const CLASSES := {
		"stone_form/spike": [14, 5.8, 12.2, 30], "water_whip/whip": [10, 4.6, 11.6, 25], "fire_blast/punch": [11, 4.0, 10.3, 25],
		"air_blast/slice": [6, 3.4, 14.5, 25], "stone_form/cannonball": [22, 8.0, 12.1, 35], "ice/spear": [16, 5.2, 12.2, 25],
		"fire_arc/lightning": [25, 6.9, 12.1, 30], "air_blast/ball": [7, 8.0, 18.7, 35], "earth_shove/push": [12, 6.9, 12.6, 30],
		"wave/push": [9, 8.0, 13.5, 30], "fire_kick/kick": [12, 5.8, 12.7, 40], "air_gust/gust": [5, 7.5, 16.5, 30],
	}

	func _init(arena: RingArena) -> void:
		a = arena

	## The launch speed of `tag` at the target's % after the hit (no range, no weight).
	func launch(tag: String, pct_before: float) -> float:
		var c: Array = CLASSES.get(tag, [])
		if c.is_empty():
			return 0.0
		var d := float(c[0])
		return float(c[1]) + float(c[2]) * (pct_before + d) / 100.0 * (0.5 + d / 20.0)

	func flight(v: Vector3, _hitstun_s: float, from: Vector3, _el: String) -> Dictionary:
		var p := from
		var vel := v
		vel.y = minf(vel.y, 16.0)
		var flat := Vector3(vel.x, 0.0, vel.z)
		var t := 0.0
		var lip_y := a.lip_y()
		while t < 6.0:
			var sp := flat.length()
			if sp > 0.0:
				flat = flat * maxf(sp - 8.0 / 60.0, 0.0) / sp
			vel.y -= 20.0 / 60.0
			p += (flat + Vector3.UP * vel.y) / 60.0
			t += 1.0 / 60.0
			var lip := a.nearest_lip(p)
			var off := float(lip.out_m) > 0.0
			if not off and p.y <= lip_y and vel.y < 0.0:
				return {"lands": "deck", "travel_m": NpcRingMind.flat_d(from, p), "t": t}
			# (out past the curtain at any height; down at the water inside it, his recovery (11-17 m of reach) brings him
			# back to the edge)
			if float(lip.out_m) > 10.0:
				return {"lands": "water", "travel_m": NpcRingMind.flat_d(from, p), "t": t}
			if p.y < lip_y - 6.0:
				return {"lands": "edge", "travel_m": NpcRingMind.flat_d(from, p), "t": t}
		return {"lands": "deck", "travel_m": NpcRingMind.flat_d(from, p), "t": t}

	func would_ko(tag: String, target: Node, from: Vector3, dir: Vector3, _range_m := 0.0, _air := false) -> bool:
		var r := RingRules.current()
		var c: Array = CLASSES.get(tag, [])
		if c.is_empty() or target == null:
			return false
		var v := launch(tag, r.pct_of(target) if r != null else 0.0)
		var ang := deg_to_rad(float(c[3]))
		var vel := dir * v * cos(ang) + Vector3.UP * v * sin(ang)
		return String(flight(vel, 0.0, (target as Node3D).global_position, "water").lands) == "water"

	func ko_pct(tag: String, target: Node, from: Vector3, dir: Vector3, _range_m := 0.0, _air := false) -> float:
		var c: Array = CLASSES.get(tag, [])
		if c.is_empty() or target == null:
			return INF
		var lo := 0.0
		var hi := 300.0
		var ang := deg_to_rad(float(c[3]))
		var kills := func(p: float) -> bool:
			var v := launch(tag, p)
			var vel := dir * v * cos(ang) + Vector3.UP * v * sin(ang)
			return String(flight(vel, 0.0, (target as Node3D).global_position, "water").lands) == "water"
		if not bool(kills.call(hi)):
			return INF
		for i in 20:
			var mid := (lo + hi) * 0.5
			if bool(kills.call(mid)):
				hi = mid
			else:
				lo = mid
		return hi
