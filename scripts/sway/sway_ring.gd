class_name SwayRing
extends Control
## The Sway's lock ring round the crosshair (SwayCaster; docs/main_story.md 11.4), GripRing's look made thin and centred:
## a dark under-ring and a thin ring in the move's art colour filling clockwise from the top. Its shape is the art's for
## colour-blind players (SwayMoves.ring_shape): Breath "open" (a gap at the top), Light "dotted", Ember "notched",
## Weight "doubled"; "ground" four ticks only (its lock the circle on the ground). Every bending element's art (earth, form,
## tide, gale, ember) is "notched" since 2026-10-12, the owner: "all bending spells need that circle on the crosshair like the
## fire ones". In the 0.15 s grace (the aim off the target) it flickers and waits; full, it closes with a flash
## (the click) and a thin inner arc counts the second left to let go. An ended lock fades: a cast swells out, a break
## or a fizzle greys away. A hold (Gust on a stone or a sail): the ring stays whole, an inner arc shows the stone's draw (or the
## sail's mote running down), and the strain reddens and shakes it. With the aim held and a spell readied (SwayCaster.readied)
## the empty track shows faintly, and the
## belt's motes as dots under it (also for a moment after they change; red when a lock wants more than are left). The self
## pillar's lock while running: a small beat ring inside it on each foot plant (pulse: the boost's moment, FormEffects).
## With free use (SwayCaster.free_use; the user, 2026-10-03: "lets make the spells free use right now") the belt is hidden
## (nothing is spent: dots that never change would only be noise, and could never say the belt is out) and a sail's hold
## shows its wind whole (no mote's time running down).
## No text.
## The new ring's meters (BendCombo; the owner, 2026-10-12: "the combo meter on the cursor like a gauge that fills up with each
## succefull action", "and also on when the e parry is on its on the cursor gauge", "and it drains"): two brackets just
## outside the lock ring, each filling from the bottom up. Left, gold: the combo, a tick a stack, swelling as one is gained and
## draining as BendCombo's level does. Right: the guard's gauge while a guard of his stands, or while it is broken (pale;
## orange under back_at; the track red while broken). Each fades in and out (METER_IN_S, METER_OUT_S).
## A tracking meter (SwayCaster.track_on; the owner, 2026-10-12: "the casting and look meter are the same"): the one ring is
## the lock too. The lock on a foe is bright, from the top (it drains back with the crosshair off him); the rest of the fill
## dim; at TRACK_SHARE bright it is locked: it whitens and pulses (let go, it goes under him).

const RADIUS := 21.0
const WIDTH := 2.5
const GAP := 0.42               ## the open ring's gap at the top (rad)
const DOTS := 24
const NOTCHES := 4
const BELT_Y := 34.0
const BELT_STEP := 9.0
const BELT_R := 2.6
const FLASH_S := 0.28
const END_S := 0.35
const BELT_SHOW_S := 2.5
const PULSE_S := 0.16
const METER_R := 31.0
const METER_SPAN := 1.9            ## each bracket's arc (rad)
const METER_W := 3.0
const METER_IN_S := 0.12
const METER_OUT_S := 0.45
const COMBO_COL := Color(1.0, 0.8, 0.35)
const GAUGE_COL := Color(0.86, 0.93, 1.0)
const GAUGE_LOW_COL := Color(0.98, 0.62, 0.22)
const BROKEN_COL := Color(0.95, 0.25, 0.18)

var caster: SwayCaster
var _t := 0.0
var _alpha := 0.0
var _flash := 0.0
var _end := {}                  ## an ended lock fading: {kind, f, art, t}
var _belt_t := 0.0
var _art := "breath"
var _pulse := 0.0
var _combo_a := 0.0
var _combo_v := 0.0
var _combo_pop := 0.0
var _gauge_a := 0.0
var _gauge_v := 1.0
var _broken := false
var _locked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## A lock begins (the ring comes up at once).
func begin() -> void:
	_end = {}
	_alpha = maxf(_alpha, 0.6)


## Full: the click's flash.
func click() -> void:
	_flash = 1.0


## A foot plant while the self pillar locks (the beat to let go on): a small ring inside it, gone in PULSE_S.
func pulse() -> void:
	_pulse = 1.0


## The lock ended: "cast", "break" or "fizzle".
func end(kind: String) -> void:
	if caster == null:
		return
	_end = {"kind": kind, "f": caster.fill, "art": caster.art(), "t": 0.0}
	if kind == "cast":
		show_belt()


func show_belt() -> void:
	_belt_t = BELT_SHOW_S


func _process(dt: float) -> void:
	if caster == null:
		return
	_t += dt
	var on := caster.state != SwayCaster.State.IDLE
	if on:
		_art = caster.art()
	elif caster.readied and caster.lock_spell() != "":
		_art = String(SwayMoves.move(caster.lock_spell()).get("art", _art))     # (the hotbar's spell readied: its art's track)
	_alpha = move_toward(_alpha, 1.0 if on else 0.0, dt * (8.0 if on else 3.0))
	_flash = maxf(_flash - dt / FLASH_S, 0.0)
	_pulse = maxf(_pulse - dt / PULSE_S, 0.0)
	_belt_t = maxf(_belt_t - dt, 0.0)
	_meters_tick(dt)
	var lk := on and caster._tracks(caster.move) and caster.track_locked()
	if lk and not _locked:
		pulse()                                   # (a tracking meter's lock taken)
	_locked = lk
	if not _end.is_empty():
		_end.t = float(_end.t) + dt
		if float(_end.t) >= END_S:
			_end = {}
	queue_redraw()


func _draw() -> void:
	if caster == null:
		return
	var c := get_viewport_rect().size * 0.5
	var col := SwayMoves.art_color(_art)
	var shape := SwayMoves.ring_shape(_art)
	var on := caster.state != SwayCaster.State.IDLE
	if on:
		var a := _alpha
		if caster.off_t > 0.0:
			a *= 0.3 + 0.7 * absf(sin(_t * 38.0))     # (the grace: it flickers)
		var full := caster.state == SwayCaster.State.FULL
		var holding := caster.state == SwayCaster.State.HOLDING
		var bright := col.lerp(Color.WHITE, 0.35) if full or holding else col
		if BendCombo.follow_on(caster.player) and not BendCombo.knockup(caster.move, caster.mode_of(caster.move)):
			bright = bright.lerp(Color.WHITE, 0.45)   # (a knock-up's follow-up: this lock fills faster, the ring glows)
		var strain := caster.hold.strain if holding and caster.hold != null and is_instance_valid(caster.hold) else 0.0
		if strain > 0.0:
			bright = bright.lerp(Color(1.0, 0.45, 0.25), strain)       # (the strain: it reddens and shakes)
		var wob := (0.6 * sin(_t * 9.0) if full else 0.0) + (strain * 2.2 * sin(_t * 41.0) if holding else 0.0)
		_ring(c, RADIUS, 1.0, Color(0, 0, 0, 0.35 * a), shape, WIDTH + 2.0)
		_ring(c, RADIUS, 1.0, Color(col.r, col.g, col.b, 0.22 * a), shape, WIDTH)
		if caster._tracks(caster.move):
			# (the one meter is the lock: dim what filled off any foe, bright what filled on one; locked, it whitens)
			var dim := col.lerp(Color(0.5, 0.5, 0.5), 0.55)
			_ring(c, RADIUS + wob, caster.fill, Color(dim.r, dim.g, dim.b, 0.8 * a), shape, WIDTH)
			var lit := bright.lerp(Color.WHITE, 0.5) if caster.track_locked() else bright
			_ring(c, RADIUS + wob, minf(caster.track_on, caster.fill), Color(lit.r, lit.g, lit.b, 0.95 * a), shape, WIDTH + (0.8 if caster.track_locked() else 0.0))
		else:
			_ring(c, RADIUS + wob, caster.fill, Color(bright.r, bright.g, bright.b, 0.95 * a), shape, WIDTH)
		if full:
			# the second left to let go: a thin inner arc running down
			var rw := caster.release_window()          # (0: no limit, Gust's: the arc stays whole)
			var left := 1.0 if rw <= 0.0 else clampf(1.0 - caster.full_t / rw, 0.0, 1.0)
			draw_arc(c, RADIUS - 5.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(bright.r, bright.g, bright.b, 0.5 * a), 1.2, true)
		elif holding:
			# a hold: a stone's draw filling (a bowstring's: GustLift), or the sail's wind (a mote's time running down)
			var k := 1.0
			if caster.hold != null and is_instance_valid(caster.hold):
				k = caster.hold.draw
			else:
				var drain := maxf(float((SwayMoves.move(caster.move).get("sail", {}) as Dictionary).get("drain_s", 2.0)), 0.1)
				k = 1.0 if SwayCaster.free_use() else 1.0 - clampf(fmod(caster.hold_t, drain) / drain, 0.0, 1.0)
			draw_arc(c, RADIUS - 5.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(bright.r, bright.g, bright.b, 0.75 * a), 1.8, true)
	elif caster.readied:
		_ring(c, RADIUS, 1.0, Color(0, 0, 0, 0.2), shape, WIDTH + 1.0)
		_ring(c, RADIUS, 1.0, Color(col.r, col.g, col.b, 0.16), shape, WIDTH * 0.7)
	if _pulse > 0.0 and on:
		var pc := SwayMoves.art_color(_art).lerp(Color.WHITE, 0.5)
		draw_arc(c, RADIUS - 8.0 + 3.0 * (1.0 - _pulse), 0.0, TAU, 32, Color(pc.r, pc.g, pc.b, 0.85 * _pulse), 2.0, true)
	if _flash > 0.0:
		var r := RADIUS + 12.0 * (1.0 - _flash)
		draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.7 * _flash), 1.5, true)
	if not _end.is_empty():
		var k := float(_end.t) / END_S
		var ec := SwayMoves.art_color(String(_end.art))
		var es := SwayMoves.ring_shape(String(_end.art))
		match String(_end.kind):
			"cast":
				_ring(c, RADIUS + 16.0 * k, 1.0, Color(ec.r, ec.g, ec.b, 0.9 * (1.0 - k)), es, WIDTH * (1.0 - 0.6 * k))
			_:
				var g := Color(0.62, 0.62, 0.62, 0.7 * (1.0 - k))
				_ring(c, RADIUS, float(_end.f), g, es, WIDTH)
	_draw_meters(c)
	_draw_way(c)
	if (caster.readied or on or _belt_t > 0.0) and not SwayCaster.free_use():     # (free use: no belt)
		var ba := 1.0 if (caster.readied or on) else clampf(_belt_t / 0.5, 0.0, 1.0)
		var short := caster.hint == "motes"
		var n := caster.belt_max
		var x0 := c.x - (n - 1) * BELT_STEP * 0.5
		for i in n:
			var p := Vector2(x0 + i * BELT_STEP, c.y + BELT_Y)
			var have := i < caster.motes
			var mc := Color(1.0, 0.86, 0.55) if have else (Color(0.95, 0.35, 0.3) if short else Color(0.85, 0.85, 0.85))
			draw_circle(p, BELT_R + 1.2, Color(0, 0, 0, 0.4 * ba))
			if have:
				draw_circle(p, BELT_R, Color(mc.r, mc.g, mc.b, 0.95 * ba))
			else:
				draw_arc(p, BELT_R - 0.4, 0.0, TAU, 12, Color(mc.r, mc.g, mc.b, 0.75 * ba), 1.0, true)


# ---------------------------------------------------------------- the meters (BendCombo)
func _meters_tick(dt: float) -> void:
	var body: Node = caster.player if caster != null else null
	var on := BendCombo.on() and body != null and is_instance_valid(body)
	var lv := BendCombo.level(body) if on else 0.0
	if lv > _combo_v + 0.5:
		_combo_pop = 1.0                       # (a stack gained: it swells)
	_combo_v = lv
	_combo_pop = maxf(_combo_pop - dt / 0.25, 0.0)
	_combo_a = move_toward(_combo_a, 1.0 if lv > 0.01 else 0.0, dt / (METER_IN_S if lv > 0.01 else METER_OUT_S))
	_broken = on and BendCombo.broken(body)
	_gauge_v = BendCombo.gauge(body) if on else 1.0
	var show := on and (caster.guard_up() or _broken)
	_gauge_a = move_toward(_gauge_a, 1.0 if show else 0.0, dt / (METER_IN_S if show else METER_OUT_S))


func _draw_meters(c: Vector2) -> void:
	if _combo_a > 0.005:
		var mx := maxf(float(RingRules.stock_block("combo").get("max", 5)), 1.0)
		var r := METER_R + 2.5 * _combo_pop
		var col := COMBO_COL.lerp(Color.WHITE, 0.5 * _combo_pop)
		_bracket(c, r, PI, clampf(_combo_v / mx, 0.0, 1.0), Color(col.r, col.g, col.b, 0.95 * _combo_a), Color(0, 0, 0, 0.4 * _combo_a))
		for i in range(1, int(mx)):
			var a := PI - METER_SPAN * 0.5 + METER_SPAN * float(i) / mx
			var dv := Vector2(cos(a), sin(a))
			draw_line(c + dv * (r - METER_W), c + dv * (r + METER_W), Color(0, 0, 0, 0.55 * _combo_a), 1.2, true)
	if _gauge_a > 0.005:
		var g := clampf(_gauge_v, 0.0, 1.0)
		var back_at := float(RingRules.stock_block("guard_gauge").get("back_at", 0.4))
		var col := BROKEN_COL if _broken else (GAUGE_LOW_COL if g < back_at else GAUGE_COL)
		var track := Color(BROKEN_COL.r * 0.5, BROKEN_COL.g * 0.5, BROKEN_COL.b * 0.5, 0.7 * _gauge_a) if _broken else Color(0, 0, 0, 0.4 * _gauge_a)
		_bracket(c, METER_R, 0.0, g, Color(col.r, col.g, col.b, 0.95 * _gauge_a), track)


## A bracket round `c` centred on angle `mid` (PI the left, 0 the right): its track whole, `f` of it filled from the bottom up.
func _bracket(c: Vector2, r: float, mid: float, f: float, col: Color, track: Color) -> void:
	var lo := mid + METER_SPAN * 0.5 if mid == 0.0 else mid - METER_SPAN * 0.5     # (the bottom end: screen y down)
	var way := -1.0 if mid == 0.0 else 1.0
	draw_arc(c, r, lo, lo + way * METER_SPAN, 32, track, METER_W + 2.0, true)
	if f > 0.0:
		draw_arc(c, r, lo, lo + way * METER_SPAN * f, 32, col, METER_W, true)


## The readied move's way (BendVariants: the Column's, the Geyser's), a small arrow under the ring while it is readied or
## locking: up, up and to the right or left, or a bar with an arrow out of it (from a wall; a ripple, from the water). No arrow
## for a move with none.
func _draw_way(c: Vector2) -> void:
	var body: Node = caster.player
	var m := caster.lock_spell() if caster.state != SwayCaster.State.IDLE else (caster.readied_spell if caster.readied else "")
	if m == "" or body == null:
		return
	var v := BendVariants.of(body, m, caster.mode_of(m))
	if v == "":
		return
	var o := c + Vector2(0.0, RADIUS + 13.0)
	var col := Color(SwayMoves.art_color(_art), 0.9)
	var sh := Color(0, 0, 0, 0.5)
	var d := Vector2.UP
	match v:
		"right":
			d = Vector2(0.7, -0.7)
		"left":
			d = Vector2(-0.7, -0.7)
		"wall", "water":
			d = Vector2.RIGHT
	var tail := o - d * 6.0
	var tip := o + d * 6.0
	if v == "wall":
		draw_line(tail + Vector2(-1.5, -6.0), tail + Vector2(-1.5, 6.0), sh, 4.0, true)
		draw_line(tail + Vector2(-1.5, -6.0), tail + Vector2(-1.5, 6.0), col, 2.0, true)
	elif v == "water":
		var wave := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			wave.append(tail + Vector2(-2.0 + 1.6 * sin(t * TAU * 1.5), -6.0 + 12.0 * t))
		draw_polyline(wave, sh, 4.0, true)
		draw_polyline(wave, col, 2.0, true)
	for w: Array in [[sh, 3.6], [col, 1.8]]:
		draw_line(tail, tip, w[0], w[1], true)
		draw_line(tip, tip - d.rotated(0.6) * 4.5, w[0], w[1], true)
		draw_line(tip, tip - d.rotated(-0.6) * 4.5, w[0], w[1], true)


## The meters now, for tests: {combo (level), combo_a, gauge, gauge_a, broken}.
func meters() -> Dictionary:
	return {"combo": _combo_v, "combo_a": _combo_a, "gauge": _gauge_v, "gauge_a": _gauge_a, "broken": _broken}


## The ring of `shape` at `r`, `f` (0..1) of it from the top, clockwise.
func _ring(c: Vector2, r: float, f: float, col: Color, shape: String, w: float) -> void:
	if f <= 0.0 or col.a <= 0.005:
		return
	match shape:
		"ground":
			# (Form: the lock is the circle drawn on the ground at the target, FormCircle; here only four small ticks round the
			# crosshair that close in as it fills)
			for i in 4:
				var a := -PI * 0.5 + TAU * float(i) / 4.0 + PI * 0.25
				var dv := Vector2(cos(a), sin(a))
				var rr := lerpf(r, r * 0.55, f)
				draw_line(c + dv * rr, c + dv * (rr + 4.0), col, w * 0.7, true)
		"dotted":
			var lit := int(ceil(f * DOTS - 0.001))
			for i in lit:
				var a := -PI * 0.5 + TAU * (float(i) + 0.5) / DOTS
				draw_circle(c + Vector2(cos(a), sin(a)) * r, w * 0.6, col)
		"notched":
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * f, 48, col, w, true)
			for i in NOTCHES:
				var fa := float(i) / NOTCHES
				if fa <= f:
					var a := -PI * 0.5 + TAU * fa
					var dv := Vector2(cos(a), sin(a))
					draw_line(c + dv * (r + w), c + dv * (r + w + 3.5), col, w * 0.7, true)
		"doubled":
			draw_arc(c, r - 2.0, -PI * 0.5, -PI * 0.5 + TAU * f, 48, col, w * 0.6, true)
			draw_arc(c, r + 2.0, -PI * 0.5, -PI * 0.5 + TAU * f, 48, col, w * 0.6, true)
		_:
			# open (Breath): a gap at the top, the fill from its right edge round to its left
			var start := -PI * 0.5 + GAP * 0.5
			draw_arc(c, r, start, start + (TAU - GAP) * f, 48, col, w, true)
