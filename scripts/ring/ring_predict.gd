class_name RingPredict
## Where a launch takes a body in Tidebreak's % ring (round 3, smash_r3 spec §2.2, §9.3, §14.3; MOVE's file): pure static, a
## GDScript mirror of smash_r3/lead_model.py v2 (gravity 20, the water 6 m under the lip, the carry's decay 8 in the air,
## hitstun 0.045 s per m/s clamped 0.12-1.2, the 0.6 s escape, the double jump keeping half the carry, the air dodge, each
## element's Rise with the Pillar's 20 degree lean and the Jet's +20 floor, the scramble, the grab box, the deck's face, the
## water and the tank's curtain at any height), read along the launch's flat way from where it starts. The bots read it to
## finish, Practice to say "out at", the tests check it against the model (movement.json's numbers; the model's policy:
## the moves spent in the order a good player spends them).
##   flight(v, hitstun_s, from, element) -> {lands: "deck" | "edge" | "water", travel_m, t}
##   would_ko(tag, target, from, dir, range_m, air) -> bool    a hit of `tag` on `target` now would take a life
##   ko_pct(tag, target, from, dir, range_m, air) -> float     the % at which it would (a search 0-300 over RingRules.launch_v)
##   ko_speed(angle_deg, lip_m, element) / reach(element)      the model's two tables (the tests)
## The class of a tag is RingRules.class_of(tag) (PERCENT's); classes_override fills it for a tag while that is empty.

const DT := 1.0 / 240.0
## The model's Jet aim (above the +20 floor) and its numbers kept with it.
const JET_AIM_DEG := 45.0
## Tags' classes for the KO read while RingRules.class_of has none (the tests; {tag: {d, base, growth, angle, set}}).
static var classes_override := {}
## The deck when there is no RingArena: ring.json's rectangle at the origin, the water 6 m down, the curtain 10 m out.
static var geo_override := {}


## The hitstun of a launch at `v` m/s (spec §3.1).
static func hitstun(v: float) -> float:
	return clampf(_k("hitstun_k", 0.045) * v, _k("hitstun_min", 0.12), _k("hitstun_max", 1.2))


## rules.json stock's number `key` (PERCENT's), else the spec's default.
static func _k(key: String, def: float) -> float:
	return RingRules.stock_num(key, def)


## The 1-D model (lead_model.py v2's survives): a body `lip_m` m inside the lip (negative: already past it), launched straight
## out at `kv` flat and `vy` up with `stun` s of hitstun, `tank_m` from the lip to the curtain (INF: none), `recover` false:
## no input; `honest` false: the model's own deck test, which counts any touch of the deck's face above the water as a
## landing (it lifts air's reach from 14.7 to 17.3 m; the KO speeds are the same either way), true: only the deck's top, the
## grab box and the scramble save him, as in the engine. {lands, travel_m, t}.
static func run1d(kv: float, vy: float, stun: float, lip_m: float, el: String, tank_m: float, recover := true,
		honest := true) -> Dictionary:
	var g := RingMoves.gravity()
	var water := -6.0
	var gd := _geo()
	if not gd.is_empty():
		water = float(gd.water_y) - RingMoves._lip_y(gd)
	var decel := _k("decel_air", RingMoves.num("physics", "carry_decel_air", 8.0))
	var esc := RingMoves.num("hitstun", "escape_s", 0.6)
	var dr := RingMoves.drift_of(el)
	var drift := dr.x
	var acc := dr.y
	var dj_h := RingMoves.el_num("double_jump", "m", el, 1.6)
	var keep := RingMoves.num("double_jump", "carry_keep", 0.5)
	var fall := RingMoves.el_num("physics", "max_fall", el, 11.0)
	var rr := RingMoves.rise_of(el)
	var kind := String(rr.get("kind", "up"))
	var startup := float(rr.get("startup_s", 0.1))
	var h := float(rr.get("m", 4.0))
	var dur := float(rr.get("s", 0.5))
	var extra := float(rr.get("drift", 1.0))
	var lean := deg_to_rad(float(rr.get("lean_deg", 20.0)))
	var jet := deg_to_rad(maxf(JET_AIM_DEG, float(rr.get("pitch_floor_deg", 20.0))))
	var glide := float(rr.get("glide_mps", 3.0))
	var dodge_m := RingMoves.num("air_dodge", "m", 3.2)
	var dodge_s := RingMoves.num("air_dodge", "s", 0.22)
	var head_m := RingMoves.num("edge", "head_m", 1.6)
	var box_in := RingMoves.num("edge", "box_in_m", 0.3)
	var box_out := RingMoves.num("edge", "box_out_m", 0.9)
	var box_lo := RingMoves.num("edge", "box_low_m", -0.5)
	var box_hi := RingMoves.num("edge", "box_high_m", 0.6)
	var grab_vy := RingMoves.num("edge", "grab_vy", 1.0)
	var rise_grab := RingMoves.num("edge", "rise_grab_after_s", 0.2)
	var scr_m := RingMoves.num("rise", "scramble_m", 2.0)
	var scr_after := RingMoves.num("rise", "scramble_after_s", 0.1)
	var hd := RingMoves.num("rise", "helpless_drift", 0.6)
	var x := 0.0
	var y := 0.0
	var own := 0.0
	var free_at := esc if stun > esc else stun
	var t := 0.0
	var dj := false
	var dodge := false
	var rise := false
	var rise_t := -1.0
	var rise_end := -1.0
	var dodge_t := -1.0
	var helpless := false
	var left := vy > 0.0
	var dl := lip_m
	while t < 10.0:
		t += DT
		var ctl := recover and t >= free_at
		var over := x > dl
		var grav := g
		if ctl and dodge_t < 0.0 and rise_t < 0.0:
			if not dj and vy < 0.0 and x > dl - 1.0 and y < 0.5:
				vy = sqrt(2.0 * g * dj_h)
				own = -drift
				kv *= keep
				dj = true
			elif dj and not dodge and over and vy < 0.0 and x - dl > 2.0:
				dodge = true
				dodge_t = 0.0
			elif dj and not rise and over and vy < 0.0 and y < -0.5:
				rise = true
				rise_t = 0.0
		if dodge_t >= 0.0:
			dodge_t += DT
			grav = 0.0
			vy = 0.0
			own = -dodge_m / dodge_s
			if dodge_t >= dodge_s:
				dodge_t = -1.0
				own = 0.0
		if rise_t >= 0.0:
			rise_t += DT
			if rise_t < startup:
				if kind == "jet" or kind == "pillar":
					vy = 0.0
					grav = 0.0
				if kind == "jet":
					own = 0.0
			elif rise_t < startup + dur:
				grav = 0.0
				var sp := h / dur
				if kind == "jet":
					vy = sp * sin(jet)
					own = -sp * cos(jet)
				elif kind == "pillar":
					vy = sp * cos(lean)
					own = -sp * sin(lean)
				else:
					vy = sp
					own = maxf(own - acc * DT, -drift * extra)
			else:
				rise_t = -1.0
				rise_end = t
				helpless = true
				vy = float(rr.get("end_vy", 3.0)) if kind == "pillar" else minf(vy, float(rr.get("end_vy", 2.0)))
				if kind == "pillar":
					own = maxf(own, -drift * extra)
		if ctl and dodge_t < 0.0 and rise_t < 0.0:
			var lim := drift * (hd if helpless else 1.0)
			own = maxf(own - acc * DT, -lim)
		kv = maxf(kv - decel * DT, 0.0)
		x += (kv + own) * DT
		vy -= grav * DT
		if kind == "updraft" and helpless:
			vy = maxf(vy, -glide)
		if t >= stun:
			vy = maxf(vy, -fall)
		y += vy * DT
		if y > 0.05:
			left = true
		var head := y + head_m
		if y < 0.0 and x > dl - 0.5 and x < dl and kv + own < 0.0 and not (y > -0.05):
			x = dl
			var rising := rise_t >= 0.0 or (rise_end >= 0.0 and t - rise_end <= scr_after)
			if rising and head >= box_lo - scr_m:
				return {"lands": "edge", "travel_m": x, "t": t}
		if x > dl + tank_m:
			return {"lands": "water", "travel_m": x, "t": t}
		var out := x - dl
		if ctl and dodge_t < 0.0 and out >= -box_in and out <= box_out and head >= box_lo and head <= box_hi and vy <= grab_vy \
				and (rise_t < 0.0 or rise_t > startup + rise_grab):
			return {"lands": "edge", "travel_m": x, "t": t}
		if x <= dl and y <= 0.0 and (not honest or y > -0.05) and vy < 0.0 and (left or t > 0.05):
			return {"lands": "deck", "travel_m": x, "t": t}
		if y < water and (x > dl or (honest and x >= dl - 0.01)):
			return {"lands": "water", "travel_m": x, "t": t}
	return {"lands": "deck", "travel_m": x, "t": t}


## The deck (RingArena's, else geo_override, else ring.json's rectangle at the origin with the stock water and curtain).
static func _geo() -> Dictionary:
	if not geo_override.is_empty():
		return geo_override
	if not RingMoves.geo_override.is_empty():
		return RingMoves.geo_override
	var tree := Engine.get_main_loop() as SceneTree
	var a := RingArena.find(tree) if tree != null else null
	if a != null:
		return RingMoves.arena_geo(a)
	return RingMoves.box_geo(Vector3.ZERO, 6.0, 10.0)


## Along the flat way `dir` from `from`: the metres to the deck's lip (negative: already past it) and from the lip to the
## curtain's plane.
static func _ray(from: Vector3, dir: Vector3) -> Vector2:
	var g := _geo()
	var xf: Transform3D = g.xf
	var l := xf.affine_inverse() * from
	var d := xf.basis.inverse() * Vector3(dir.x, 0.0, dir.z)
	d.y = 0.0
	if d.length() < 1e-4:
		return Vector2(INF, INF)
	d = d.normalized()
	var hl := float(g.hl)
	var hw := float(g.hw)
	var tank := float(g.get("tank", 10.0))
	var to_lip := _exit(Vector2(l.x, l.z), Vector2(d.x, d.z), Vector2(hl, hw))
	var to_curtain := _exit(Vector2(l.x, l.z), Vector2(d.x, d.z), Vector2(hl + tank, hw + tank))
	return Vector2(to_lip, to_curtain - to_lip)


## How far along `d` (unit) from `p` the rectangle |x| <= h.x, |z| <= h.y is left (negative: already outside it, how far
## back along -d it was last in; a point outside that never enters: the distance past its nearest side).
static func _exit(p: Vector2, d: Vector2, h: Vector2) -> float:
	var tx := INF
	var tz := INF
	if absf(d.x) > 1e-6:
		tx = ((h.x if d.x > 0.0 else -h.x) - p.x) / d.x
	if absf(d.y) > 1e-6:
		tz = ((h.y if d.y > 0.0 else -h.y) - p.y) / d.y
	return minf(tx, tz)


## Where a body launched at `v` from `from` with `hitstun_s` of hitstun comes down (`element`: its recovery):
## {lands: "deck" | "edge" | "water", travel_m (flat, along the launch), t}.
static func flight(v: Vector3, hitstun_s: float, from: Vector3, element: String) -> Dictionary:
	var flat := Vector3(v.x, 0.0, v.z)
	if flat.length() < 1e-3:
		return {"lands": "deck", "travel_m": 0.0, "t": 0.0}
	var r := _ray(from, flat)
	if r.x == INF:
		return {"lands": "deck", "travel_m": 0.0, "t": 0.0}
	var el := element if element in RingMoves.ELEMENTS else "water"
	return run1d(flat.length(), minf(v.y, _k("vy_cap", 16.0)), hitstun_s, r.x, el, r.y)


## The launch a hit of `tag` on `target` would give at `pct_after` (after the hit): its velocity, or ZERO with no class.
static func _launch(cls: Dictionary, pct_after: float, el: String, dir: Vector3, range_m: float, air: bool) -> Vector3:
	var d := float(cls.get("d", 0.0))
	var v := RingRules.launch_v(cls, pct_after, d, _weight(el), range_m, air)
	var a := deg_to_rad(float(cls.get("angle", 30.0)))
	var f := Vector3(dir.x, 0.0, dir.z)
	f = f.normalized() if f.length() > 1e-4 else Vector3.FORWARD
	return f * v * cos(a) + Vector3.UP * minf(v * sin(a), _k("vy_cap", 16.0))


static func _weight(el: String) -> float:
	var w := RingRules.weight_of(el)
	if is_equal_approx(w, 1.0):
		var ws: Variant = RingRules.stock_block("weights").get(el, null)
		if ws != null:
			var wt := float(ws)
			return 2.0 / (1.0 + wt)
	return w


static func _class(tag: String) -> Dictionary:
	var c := RingRules.class_of(tag)
	if c.is_empty() and classes_override.has(tag):
		c = (classes_override[tag] as Dictionary).duplicate()
	if not c.is_empty() and not c.has("tag"):
		c["tag"] = tag
	return c


static func _element_of(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return "water"
	var e: Variant = target.get(&"arena_element") if target is FrontierPlayer else target.get(&"element")
	var s := String(e) if e is String or e is StringName else ""
	return s if s in RingMoves.ELEMENTS else "water"


static func _pct_of(target: Node) -> float:
	var r := RingRules.current()
	return r.pct_of(target) if r != null else 0.0


## Whether a hit of `tag` on `target` at his % now (+ the hit's d), going `dir`, from `from` (his place: the launch starts
## there), `range_m` from where it was cast, `air` released airborne, would put him in the water.
static func would_ko(tag: String, target: Node, from: Vector3, dir: Vector3, range_m := 0.0, air := false) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var cls := _class(tag)
	if cls.is_empty() or bool(cls.get("set", false)):
		return false
	var el := _element_of(target)
	var v := _launch(cls, _pct_of(target) + float(cls.get("d", 0.0)), el, dir, range_m, air)
	return String(flight(v, hitstun(v.length()), from, el).lands) == "water"


## The % (after the hit) at which a hit of `tag` on `target` from `from` going `dir` would put him in the water (a binary
## search 0-300 over RingRules.launch_v; INF: never by 300).
static func ko_pct(tag: String, target: Node, from: Vector3, dir: Vector3, range_m := 0.0, air := false) -> float:
	if target == null or not is_instance_valid(target):
		return INF
	return ko_pct_el(tag, _element_of(target), from, dir, range_m, air)


## ko_pct for a body of `el` (no node needed).
static func ko_pct_el(tag: String, el: String, from: Vector3, dir: Vector3, range_m := 0.0, air := false) -> float:
	var cls := _class(tag)
	if cls.is_empty() or bool(cls.get("set", false)):
		return INF
	var out := func(p: float) -> bool:
		var v := _launch(cls, p, el, dir, range_m, air)
		return String(flight(v, hitstun(v.length()), from, el).lands) == "water"
	if not bool(out.call(300.0)):
		return INF
	if bool(out.call(0.0)):
		return 0.0
	var lo := 0.0
	var hi := 300.0
	for i in 30:
		var mid := (lo + hi) * 0.5
		if bool(out.call(mid)):
			hi = mid
		else:
			lo = mid
	return hi


## The model's KO speed (m/s) at `angle_deg` from `lip_m` inside the lip, for `el` (lead_model's ko_speed; `honest`: see
## run1d).
static func ko_speed(angle_deg: float, lip_m: float, el := "water", recover := true, tank_m := 10.0, honest := false) -> float:
	var a := deg_to_rad(angle_deg)
	var survive := func(v: float) -> bool:
		var r := run1d(v * cos(a), minf(v * sin(a), _k("vy_cap", 16.0)), hitstun(v), lip_m, el, tank_m, recover, honest)
		return String(r.lands) != "water"
	var lo := 1.0
	var hi := 120.0
	if bool(survive.call(hi)):
		return INF
	for i in 36:
		var mid := (lo + hi) * 0.5
		if bool(survive.call(mid)):
			lo = mid
		else:
			hi = mid
	return hi


## The model's recovery reach (m past the lip, at rest at deck height, free at once, no curtain): lead_model's reach
## (`honest`: see run1d; the spec's 11.3 / 11.8 / 15.8 / 17.4 m are the model's own).
static func reach(el: String, honest := false) -> float:
	var lo := 0.0
	var hi := 30.0
	for i in 30:
		var mid := (lo + hi) * 0.5
		var r := run1d(0.001, 0.0, 0.0, -mid, el, INF, true, honest)
		if String(r.lands) != "water":
			lo = mid
		else:
			hi = mid
	return lo
