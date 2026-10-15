class_name RingPractice
extends RefCounted
## A Tidebreak PRACTICE (MatchSetup.kind "practice"; the user arg practice=stand|block|throw), moved out of RingMode by round
## 3's SEAMS so the practice is BOTS' own file (smash_r3 spec §11.1, §14.3) and RingMode keeps one-line calls into it. Its
## RingMode (`mode`) still runs the match; this runs the dummy and the practice's lines. Behaviour as it was in RingMode:
## a dummy of foes[0]'s element at the other end, held there (it never walks): "stand" never casts; "block" answers what
## comes at it with its element's guards (no dice: every time the lock fits the threat's time) and raises its cover when the
## player begins a lock (no more often than block_every_s); "throw" casts its throw at him every throw_every_s: its element's
## key 1 first move (MatchSetup.practice_move: earth a Spike to catch and send back, water a Lash to Turn, fire a Punch to
## Parry, air a Slice). No timer (the clock counts up), no rounds, no score; the soft walls off (walk anywhere); a fall into
## the water puts both back at their ends after reset_after_out_s, R (ring_reset) at once (reset_positions), B (ring_dummy)
## steps the dummy's way (cycle_dummy); 0 health is whole again. A line at the top says so, with the player's casts, catches
## and knock-backs. Every number and word in data/ring/screens.json "practice" (data/ring/practice.json: round 3's rows).
##   reset()          a restart's: the dummy's way from MatchSetup, no reset waiting
##   arm()            the fight's go: the dummy's first throw half a throw_every_s away, its cover ready
##   step(dt)         each FIGHT frame (RingMode._physics_process)
##   set_way(way)     the dummy's way now ("stand" | "block" | "throw"), said on the banner
##   paint()          the hint and tally lines (RingMode._paint)
##   on_out()         the player's side in the water: said, both back at their ends a moment later
##   on_winded(who)   0 health in practice: whole again at once
##   key(e) -> bool   R and B (true: mark the key handled, R only, as RingMode always did)
## ROUND 3, the % ring (smash_r3 spec §11.1; only while RingRules.stock_on(): the classic ring's practice above is unchanged).
## The Practice rows (MatchSetup's, the Esc menu's Practice panel and the main menu's; data/ring/practice.json):
##   its % and yours   0 / 30 / 60 / 90 / 120 / 150 / 200 / grows: set at the go, by R and after every fall
##                     (RingRules.reset_pct; grows: left as the match would)
##   the dummy's way   B steps practice.json ways: stand, walk (side to side), jump (a hop, a double jump every other), block
##                     (its guard on the beat: today's), guard_held (up again and again), guard_after (up as its hitstun
##                     ends), recover (R and every fall put it off an open end, 3-7 m out and 0-1.5 m under the lip; it
##                     comes back at the match's difficulty), throw (today's), fight (the bot at its difficulty);
##                     NpcBending.set_practice_way tells the bot
##   its steering      none / in / out / random (NpcRingMind.steer_way)
##   Throw me off      R puts you off an end instead: your recovery drill
##   speed             1, 1/2, 1/4 (Engine.time_scale, put back each frame of the practice: a pause or a fall keeps it)
##   fresh moves       on: RingRules' stale moves off (stale_off)
## No lives and no clock (PERCENT's RingMode in a practice). On the panel (PracticePanel): the string counter (32 px, top
## centre: "3 hits · 41%", white while every hit landed inside the dummy's hitstun (RingRules.string_hits, hitstun_left: the
## 0.6 s escape counted), grey "free" once it was free, held counter_hold_s; the best kept), the readout after each hit
## ("Launch 9.2 m · reeling 0.55 s · steered 12° · from here, out at 124%": RingPredict.flight and ko_pct, the rules'
## last_steer_deg; numbers only, nothing drawn on the dummy) and the notes line ("Hop and let go at once: a low hop.").

const RESET_ACTION := &"ring_reset"
const DUMMY_ACTION := &"ring_dummy"
const RESET_KEY := KEY_R
const DUMMY_KEY := KEY_B
## After a practice's reset the deck is judged again this much later (s).
const RESET_GRACE_S := 0.12

## The RingMode this practice runs in.
var mode: RingMode
## The dummy's way ("stand" | "block" | "throw").
var dummy := "stand"
## The dummy's throws slowed (the lessons' guard drill and jump, RingLessons; the owner, 2026-10-05: a beginner beating a fast
## throw is no lesson): a throw each slow_every_s, each shot slowed by slow_speed as it leaves.
var slow_throws := false
## The dummy's throw instead of its element's strike ("id/mode"; "": screens.json practice.throw; the lessons' jump: fire's Kick).
var throw_override := ""
## What the dummy does and the keys, under the HUD's match bar; the player's tally under it (made by build_ui).
var hint: Label
var tally_label: Label
var hint_back: ColorRect

var _reset_in := -1.0
var _live_in := 0.0
var _dummy_next := 0.0
var _cover_next := 0.0
## Round 3 (the % ring): the panel (counter, readout, notes), the counter now and the best, the readout's line.
var panel: PracticePanel
## How far the practice's lines and panel stand lower than their 110 px top: under the plates where they reach past it
## (_lay_lines).
var _dy := 0.0
var counter := {"hits": 0, "pct": 0.0, "free": false, "until": -INF, "at": -INF}
var best := {"hits": 0, "pct": 0.0}
var readout := ""
## Counted (tests): readouts written, the last one's numbers ({launch_m, reeling_s, steered_deg, out_at}).
var readouts := 0
var last_read := {}
var _rules_seen: RingRules = null
var _pending: Array = []
var _hit_at := -INF
var _guard_after_done := -INF
var _walk_side := 1.0
var _jumps := 0
var _pct_in := -1.0
## Engine.time_scale set by a practice (put back to 1 when a match follows).
static var _speed_set := false


func _init(m: RingMode = null) -> void:
	mode = m


## data/ring/screens.json practice's number `key`.
static func pnum(key: String, def: float) -> float:
	return float((MatchSetup.screens().get("practice", {}) as Dictionary).get(key, def))


## A practice word (screens.json practice.words).
static func pword(key: String) -> String:
	return KitWords.keyed(String((((MatchSetup.screens().get("practice", {}) as Dictionary).get("words", {})) as Dictionary).get(key, key)))


## The practice keys (R: reset positions, B: the dummy's way), made when missing (the player may rebind them).
static func ensure_keys() -> void:
	for pair: Array in [[RESET_ACTION, RESET_KEY], [DUMMY_ACTION, DUMMY_KEY]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var k := InputEventKey.new()
		k.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], k)


## The hint and tally lines on RingMode's text layer `ui` (hidden until a practice paints them).
func build_ui(ui: CanvasLayer) -> void:
	hint_back = ColorRect.new()
	hint_back.name = "PracticeBack"
	hint_back.color = Color(0.02, 0.015, 0.01, 0.5)
	hint_back.anchor_left = 0.18
	hint_back.anchor_right = 0.82
	hint_back.offset_top = 110.0
	hint_back.offset_bottom = 158.0
	hint_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_back.visible = false
	ui.add_child(hint_back)
	hint = mode._label(16, MenuUI.INK)
	hint.name = "PracticeHint"
	hint.offset_top = 112.0
	hint.offset_bottom = 134.0
	hint.visible = false
	ui.add_child(hint)
	tally_label = mode._label(16, MenuUI.GOLD)
	tally_label.name = "PracticeTally"
	tally_label.offset_top = 134.0
	tally_label.offset_bottom = 156.0
	tally_label.visible = false
	ui.add_child(tally_label)
	panel = PracticePanel.new()
	panel.name = "PracticePanel"
	panel.visible = false
	ui.add_child(panel)


## A restart's: the dummy's way from MatchSetup, no reset waiting.
func reset() -> void:
	dummy = MatchSetup.dummy if MatchSetup.dummy in MatchSetup.dummy_ways() else "stand"
	_reset_in = -1.0
	_live_in = 0.0
	counter = {"hits": 0, "pct": 0.0, "free": false, "until": -INF, "at": -INF}
	readout = ""
	if _speed_set and (mode == null or not MatchSetup.practice()):
		Engine.time_scale = 1.0                   # (a match after a slowed practice: its own speed again)
		_speed_set = false


## The fight's go: the dummy's first throw half a throw_every_s away, its cover ready; in the % ring the rows applied (the
## %, the dummy's way and steering, the speed, fresh moves).
func arm() -> void:
	_dummy_next = BendStatus.now() + pnum("throw_every_s", 3.0) * 0.5
	_cover_next = 0.0
	if stock() and mode != null and mode.practice:
		_apply_rows()
	if stock() and mode != null and mode.is_inside_tree():
		RingLessons.ensure_hints(mode)          # (round 3: the one hint queue over a match or a practice without the cards)


## The hint and tally lines shown in a practice (hidden in a match).
func paint() -> void:
	if hint == null:
		return
	var on := mode.practice
	hint.visible = on
	tally_label.visible = on
	hint_back.visible = on
	if panel != null:
		panel.visible = on and stock()
		if panel.visible:
			panel.paint(counter_text(), counter_white(), best_text(), readout, MatchSetup.pword("notes"))
	if on:
		_lay_lines()
		hint.text = practice_line()
		var mine: Dictionary = mode.round_tally[0]
		tally_label.text = pword("tally") % [int(mine.get("casts", 0)), int(mine.get("catches", 0)), int(mine.get("knock_backs", 0))]


## The practice's band, its lines and the panel under the plates (the UI audit, 2026-10-09: at 1600 x 900 the band ran over
## the bottom of both plates): as at 1280 x 720 where the plates end above 110 px, lower by as much as they reach past it
## (PercentBar.top_plates_bottom, the key hints' gap under them).
func _lay_lines() -> void:
	if hint_back == null or not hint_back.is_inside_tree():
		return
	var vh := hint_back.get_viewport_rect().size.y
	var under := PercentBar.top_plates_bottom(vh) if RingRules.pct_on() else -1.0
	var dy := maxf(under + PercentBar.cnum("hints_gap", 12.0) * vh / 720.0 - 112.0, 0.0) if under >= 0.0 else 0.0
	if is_equal_approx(dy, _dy):
		return
	_dy = dy
	hint_back.offset_top = 110.0 + dy
	hint_back.offset_bottom = 158.0 + dy
	hint.offset_top = 112.0 + dy
	hint.offset_bottom = 134.0 + dy
	tally_label.offset_top = 134.0 + dy
	tally_label.offset_bottom = 156.0 + dy
	if panel != null:
		panel.offset_top = dy
		panel.offset_bottom = dy


## "Practice  ·  a Stone dummy that throws at you every few seconds  ·  R: reset positions ..."
func practice_line() -> String:
	if stock():
		return MatchSetup.pword("hint") % [MatchSetup.competitor(mode.foe_element), MatchSetup.dummy_line(dummy)]
	return pword("hint") % [MatchSetup.competitor(mode.foe_element), MatchSetup.dummy_line(dummy)]


## R and B in a practice's fight (true: mark the key handled; R only, as RingMode always did: B steps the dummy's way and
## lets the key go on).
func key(e: InputEvent) -> bool:
	if e.is_action_pressed(RESET_ACTION):
		reset_positions()
		return true
	if e.is_action_pressed(DUMMY_ACTION):
		cycle_dummy()
	return false


## The player's side in the water: said, both back at their ends reset_after_out_s later.
func on_out() -> void:
	mode._note = pword("out")
	mode._note_t = pnum("reset_after_out_s", 1.6)
	_reset_in = pnum("reset_after_out_s", 1.6)


## Spent in the ring (RingRules' winded): whole again at once.
func on_winded(who: Node3D) -> void:
	if who is FrontierPlayer:
		(who as FrontierPlayer).health = (who as FrontierPlayer).max_health
	elif who is NpcFighter:
		(who as NpcFighter).health = (who as NpcFighter).health_max


## The dummy's next way in turn (stand, block, throw; the % ring's practice.json ways), at once.
func cycle_dummy() -> void:
	var ds := ways()
	set_way(String(ds[(ds.find(dummy) + 1) % ds.size()]))


## The ways B steps now: the % ring's (practice.json) or the classic ring's.
func ways() -> Array:
	return MatchSetup.STOCK_DUMMIES if stock() else MatchSetup.DUMMIES


## The dummy's way `way` ("stand" | "block" | "throw"; the % ring's ways too), at once: kept for the next practice, said on
## the banner, told to the bot (NpcBending.set_practice_way).
func set_way(way: String) -> void:
	dummy = way if way in ways() else "stand"
	MatchSetup.dummy = dummy
	arm()
	if stock():
		_tell_way()
		if dummy == "recover" and mode != null and mode.foe != null and is_instance_valid(mode.foe):
			place_off(mode.foe)
		mode._note = MatchSetup.pword("way_said") % MatchSetup.dummy_line(dummy)
	else:
		mode._note = pword("way") % MatchSetup.dummy_line(dummy)
	mode._note_t = 1.8


## Both back at their ends, whole, the deck cleared (practice's R; after a fall into the water).
func reset_positions() -> void:
	_reset_in = -1.0
	var ring := mode.ring
	var rules := mode.rules
	var player := mode.player
	if ring != null:
		ring.clear_dropped()
	if player != null and is_instance_valid(player):
		mode.make_whole(player)
		RingLevel.place(player, ring.spawn(mode.player_end))
		player.drag_speed_cap = INF
		mode._hold_casts(false)
	var foe := mode.foe
	if foe == null or not is_instance_valid(foe) or foe.down or foe.is_dead():
		# (gone, or down for good: a new dummy, the books made again)
		mode._drop_foe()
		rules.clear()
		if player != null and is_instance_valid(player):
			rules.add(player, 0)
		mode._spawn_foe()
		foe = mode.foe
		if foe != null:
			rules.add(foe, 1)
	if foe != null and is_instance_valid(foe):
		mode.make_whole(foe)
		foe.health = foe.health_max
		var bend := mode._foe_bending()
		if bend != null and bend.has_method(&"reset"):
			bend.call(&"reset")
		var xf := ring.spawn(1 - mode.player_end, int(RingRules.num("bot_slot", 0.0)))
		RingLevel.place(foe, xf)
		foe.held = true
		if player != null and foe.brain != null:
			foe.brain.told(player, player.global_position)
	rules.reset_round()
	if stock():
		# (round 3: both at the rows' %; the recover drill's dummy and Throw me off's player off an end)
		_apply_pct()
		if dummy == "recover" and foe != null and is_instance_valid(foe):
			place_off(foe)
		if MatchSetup.throw_me and player != null and is_instance_valid(player):
			place_off(player)
	# (the deck judged again a moment later: the tank's Area3D still counts a body just lifted out of it until the physics
	# has stepped, so judging at once would put him straight back out)
	rules.live = false
	_live_in = RESET_GRACE_S
	arm()
	if mode._note_t <= 0.0:
		mode._note = pword("reset")
		mode._note_t = 1.2


## The dummy each frame of a practice: held at its end facing the player; its lock let run while it casts; its way's cast
## begun (block: a guard against what comes, its cover when he locks; throw: its throw every throw_every_s).
func step(dt: float) -> void:
	var foe := mode.foe
	var player := mode.player
	if stock():
		_stock_step(dt)
		if _stock_owns():
			return
	if slow_throws and foe != null and is_instance_valid(foe):
		_slow_shots()                         # (each shot the frame it leaves, whatever the dummy is doing)
	if _live_in > 0.0:
		_live_in -= dt
		if _live_in <= 0.0:
			mode.rules.live = true
	if _reset_in > 0.0:
		_reset_in -= dt
		if _reset_in <= 0.0:
			reset_positions()
		return
	if foe == null or not is_instance_valid(foe):
		reset_positions()
		return
	var bend := mode._foe_bending()
	if bend == null:
		return
	if String(bend.get(&"casting")) != "" or float(bend.get(&"_follow")) > 0.0:
		foe.held = false                     # (its lock fills and its cast clip plays: NpcBending.tick)
		return
	foe.held = true
	if player == null or not is_instance_valid(player):
		return
	foe.face_point(player.global_position)
	var now := BendStatus.now()
	match dummy:
		"throw":
			if now >= _dummy_next:
				_dummy_next = now + throw_every_s()
				_dummy_cast(bend, throw_override if throw_override != "" else pmove("throw"))
		"block":
			var g := dummy_guard(bend)
			if not g.is_empty():
				_dummy_cast(bend, "%s/%s" % [g.id, g.mode])
				return
			var sc := SwayCaster.of(player)
			if sc != null and sc.is_locking() and now >= _cover_next:
				_cover_next = now + pnum("block_every_s", 2.5)
				_dummy_cast(bend, pmove("cover"))


## The seconds between the dummy's throws: screens.json practice throw_every_s, slow_every_s while they are slowed.
func throw_every_s() -> float:
	return RingLessons.num("slow_every_s", 5.0) if slow_throws else pnum("throw_every_s", 3.0)


## The dummy's shots slowed once each, as they leave (slow_throws): a bolt's speed by slow_speed and its gravity by its square
## (the same path, later); a thrown stone (GustLift) by slow_speed with its rise made good for its own gravity's longer fall.
func _slow_shots() -> void:
	var foe := mode.foe
	var player := mode.player
	var tree := mode.get_tree()
	var k := clampf(RingLessons.num("slow_speed", 0.6), 0.2, 1.0)
	for b in tree.get_nodes_in_group(BendBolt.GROUP):
		var bb := b as BendBolt
		if bb == null or bb.caster != foe or bb.has_meta(&"ring_slowed"):
			continue
		bb.set_meta(&"ring_slowed", true)
		bb.velocity *= k
		bb.gravity *= k * k
	for n in tree.get_nodes_in_group(NpcBending.FLIGHT_GROUP):
		# (the earth dummy's spike flies as NpcBending's Flight: slowed the same way, the catch drill's stones too)
		var fl := n as NpcBending.Flight
		if fl == null or fl.shooter != foe or fl.has_meta(&"ring_slowed"):
			continue
		fl.set_meta(&"ring_slowed", true)
		fl.velocity *= k
		fl.gravity *= k * k
	for n in tree.get_nodes_in_group(GustLift.GROUP):
		var gl := n as GustLift
		if gl == null or gl.phase != GustLift.Phase.FLIGHT or gl.has_meta(&"ring_slowed") or gl.caster == null \
				or gl.caster.body != foe:
			continue
		gl.set_meta(&"ring_slowed", true)
		var v := gl.velocity
		var flat := Vector2(v.x, v.z).length()
		var g := float((gl.call(&"_hurl_d") as Dictionary).get("gravity", 6.0)) if gl.has_method(&"_hurl_d") else 6.0
		var d := Vector2(player.global_position.x - gl.stone.global_position.x, player.global_position.z
				- gl.stone.global_position.z).length() if player != null and is_instance_valid(gl.stone) else 0.0
		var t0 := d / maxf(flat, 0.1)
		var t1 := t0 / k
		# (the same drop at his distance: v1y * t1 - g t1² / 2 = v0y * t0 - g t0² / 2)
		var vy := (v.y * t0 - 0.5 * g * t0 * t0 + 0.5 * g * t1 * t1) / maxf(t1, 0.01) if t1 > 0.0 else v.y * k
		gl.velocity = Vector3(v.x * k, vy, v.z * k)


# ---------------------------------------------------------------- round 3: the % ring's practice
## THE GATE: a stock-rules ring.
static func stock() -> bool:
	return RingRules.stock_on()


## data/ring/practice.json's number `key`.
static func snum(key: String, def: float) -> float:
	return float(MatchSetup.practice_data().get(key, def))


static func srange(key: String, def: Vector2) -> Vector2:
	var v: Variant = MatchSetup.practice_data().get(key)
	return Vector2(float(v[0]), float(v[1])) if v is Array and (v as Array).size() >= 2 else def


## Whether the way now is the % ring's own (stand and its moving ways; block and throw stay today's code).
func _stock_owns() -> bool:
	return not dummy in ["block", "throw"]


## The rows applied: both % (reset_pct), the bot told its way and steering, the speed, fresh moves.
func _apply_rows() -> void:
	_listen()
	_apply_pct()
	_tell_way()
	Engine.time_scale = MatchSetup.speed
	_speed_set = MatchSetup.speed != 1.0
	var r := RingRules.current()
	if r != null:
		r.set(&"stale_off", MatchSetup.fresh)   # (PERCENT's: every move fresh while on)


## Both sides' % put to the rows' values (a row on "grows" left alone).
func _apply_pct() -> void:
	var r := RingRules.current()
	if r == null or mode == null:
		return
	var pc := MatchSetup.practice_pct()
	if pc.has("foe") and mode.foe != null and is_instance_valid(mode.foe):
		r.reset_pct(mode.foe, float(pc.foe))
	if pc.has("player") and mode.player != null and is_instance_valid(mode.player):
		r.reset_pct(mode.player, float(pc.player))


## The bot told its way (NpcBending.set_practice_way) and its steering (NpcRingMind.steer_way).
func _tell_way() -> void:
	var bend := mode._foe_bending() if mode != null else null
	if bend == null:
		return
	if bend.has_method(&"set_practice_way"):
		bend.call(&"set_practice_way", dummy)
	var nb := bend as NpcBending
	if nb != null:
		nb.mind().steer_way = MatchSetup.steer
	if mode.foe != null and is_instance_valid(mode.foe):
		mode.foe.held = dummy == "stand"


## The rules' signals heard once per RingRules: the counter and the readout, the % back after a fall.
func _listen() -> void:
	var r := RingRules.current()
	if r == null or r == _rules_seen:
		return
	_rules_seen = r
	r.launched.connect(_on_launched)
	r.pct_changed.connect(_on_pct)
	r.respawned.connect(_on_respawned)


## A hit on the dummy by the player: the counter (the rules' string_hits) and the readout pending.
func _on_launched(b: Node3D, v: Vector3, hitstun_s: float, by: Node, tag: String) -> void:
	if mode == null or not mode.practice or b != mode.foe or by != mode.player:
		return
	note_hit(RingRules.current().string_hits(b) if RingRules.current() != null else 1)
	_hit_at = BendStatus.now()
	var from := (by as Node3D).global_position if by is Node3D else Vector3.ZERO
	_pending.append({"at": BendStatus.now(), "v": v, "s": hitstun_s, "tag": tag, "from": from, "pos": b.global_position})


## The counter told of a hit whose string on the dummy now has `n` hits (1: a new one; a free gap shown grey before it).
func note_hit(n: int) -> void:
	if n <= 1 or bool(counter.free) or int(counter.hits) == 0:
		counter = {"hits": 1, "pct": 0.0, "free": false, "until": INF, "at": BendStatus.now()}
	else:
		counter.hits = n
		counter.at = BendStatus.now()
		counter.until = INF


func _on_pct(b: Node3D, _pct: float, delta: float) -> void:
	if mode != null and b == mode.foe and delta > 0.0 and int(counter.hits) > 0 and not bool(counter.free):
		counter.pct = float(counter.pct) + delta


## A fall in practice: that side back at its row's %, the recover drill's dummy off an end again.
func _on_respawned(b: Node3D) -> void:
	if mode == null or not mode.practice:
		return
	var r := RingRules.current()
	var pc := MatchSetup.practice_pct()
	if b == mode.foe:
		if pc.has("foe") and r != null:
			r.reset_pct(b, float(pc.foe))
		if dummy == "recover":
			place_off(b)
	elif b == mode.player and pc.has("player") and r != null:
		r.reset_pct(b, float(pc.player))


## "3 hits · 41%", "1 hit · 5%", "free" after it ("" none).
func counter_text() -> String:
	var n := int(counter.hits)
	if n <= 0 or BendStatus.now() > float(counter.until):
		return ""
	var t := MatchSetup.pword("counter_one") % roundi(float(counter.pct)) if n == 1 else MatchSetup.pword("counter") % [n, roundi(float(counter.pct))]
	return t + ("  ·  " + MatchSetup.pword("counter_free") if bool(counter.free) else "")


## White while every hit landed inside the dummy's hitstun, grey once it was free.
func counter_white() -> bool:
	return not bool(counter.free)


func best_text() -> String:
	return MatchSetup.pword("best") % [int(best.hits), roundi(float(best.pct))] if int(best.hits) >= 2 else ""


## Each FIGHT frame of a % ring practice: the speed kept, the counter's free moment, the readouts due, the dummy's way.
func _stock_step(dt: float) -> void:
	_listen()
	if not mode.get_tree().paused and absf(Engine.time_scale - MatchSetup.speed) > 1e-4 and Engine.time_scale > 0.0:
		Engine.time_scale = MatchSetup.speed   # (a fall's moment or a pause put it back: Practice's speed again)
		_speed_set = MatchSetup.speed != 1.0
	var r := RingRules.current()
	var foe := mode.foe
	var now := BendStatus.now()
	if int(counter.hits) > 0 and not bool(counter.free) and foe != null and is_instance_valid(foe) \
			and (r == null or r.hitstun_left(foe) <= 0.0) and now - float(counter.at) > dt * 1.5:
		counter.free = true
		counter.until = now + snum("counter_hold_s", 2.0)
		if int(counter.hits) > int(best.hits) or (int(counter.hits) == int(best.hits) and float(counter.pct) > float(best.pct)):
			best = {"hits": int(counter.hits), "pct": float(counter.pct)}
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		if now - float(p.at) >= snum("readout_after_s", 0.15):
			_pending.remove_at(i)
			_read(p)
	if foe == null or not is_instance_valid(foe) or _reset_in > 0.0:
		return
	_dummy_step(dt)


## The readout of hit `p`: "Launch 9.2 m · reeling 0.55 s · steered 12° · from here, out at 124%".
func _read(p: Dictionary) -> void:
	var r := RingRules.current()
	var foe := mode.foe
	if foe == null or not is_instance_valid(foe):
		return
	var el := NpcRingMind.element_of(foe)
	var v: Vector3 = p.v
	var fl := flight_of(v, float(p.s), Vector3(p.pos), el)
	var steer := r.last_steer_deg(foe) if r != null else 0.0
	var from: Vector3 = p.from
	var dir := NpcRingMind.flat_dir(from, Vector3(p.pos))
	var out := ko_pct_of(String(p.tag), foe, from, dir, NpcRingMind.flat_d(from, Vector3(p.pos)), false)
	var tail := MatchSetup.pword("stays") if out == INF or out > 999.0 else MatchSetup.pword("out_at") % roundi(out)
	readout = MatchSetup.pword("readout") % [float(fl.get("travel_m", 0.0)), float(p.s), roundi(absf(steer)), tail]
	readouts += 1
	last_read = {"launch_m": float(fl.get("travel_m", 0.0)), "reeling_s": float(p.s), "steered_deg": steer, "out_at": out}


## RingPredict.flight (or the tests' stand-in, NpcRingMind.predict_override).
static func flight_of(v: Vector3, s: float, from: Vector3, el: String) -> Dictionary:
	var po := NpcRingMind.predict_override
	if po != null and po.has_method(&"flight"):
		return po.call(&"flight", v, s, from, el)
	return RingPredict.flight(v, s, from, el)


## RingPredict.ko_pct (or the tests' stand-in).
static func ko_pct_of(tag: String, t: Node, from: Vector3, dir: Vector3, range_m: float, air: bool) -> float:
	var po := NpcRingMind.predict_override
	if po != null and po.has_method(&"ko_pct"):
		return float(po.call(&"ko_pct", tag, t, from, dir, range_m, air))
	return RingPredict.ko_pct(tag, t, from, dir, range_m, air)


## The dummy's way each frame (stand, walk, jump, guard_held, guard_after, recover, fight; block and throw are today's).
func _dummy_step(_dt: float) -> void:
	var foe := mode.foe
	var player := mode.player
	var bend := mode._foe_bending() as NpcBending
	if bend == null:
		return
	var now := BendStatus.now()
	match dummy:
		"stand":
			foe.held = String(bend.casting) == ""
			if player != null and is_instance_valid(player):
				foe.face_point(player.global_position)
		"walk":
			foe.held = false
			var a := mode.ring
			if a != null and foe.arrived():
				_walk_side = -_walk_side
			var c := a.spawn(1 - mode.player_end).origin if a != null else foe.global_position
			foe.go(c + Vector3(0.0, 0.0, _walk_side * snum("walk_m", 4.0)), NpcFighter.WALK_SPEED * 2.0, 0.3, true)
		"jump":
			foe.held = false
			if now >= _dummy_next:
				_dummy_next = now + snum("jump_every_s", 1.5)
				_jumps += 1
				bend.pad().press("jump")
				if _jumps % 2 == 0:
					_dummy_next_double = now + 0.3
			if _dummy_next_double > 0.0 and now >= _dummy_next_double:
				_dummy_next_double = -1.0
				bend.pad().press("jump")
		"guard_held":
			foe.held = String(bend.casting) == ""
			if String(bend.casting) == "" and not _guard_up(foe) and now >= _cover_next:
				_cover_next = now + 0.1
				_dummy_guard_now(bend)
		"guard_after":
			foe.held = String(bend.casting) == ""
			var r := RingRules.current()
			if _hit_at > _guard_after_done and (r == null or r.hitstun_left(foe) <= 0.0):
				_guard_after_done = now
				_dummy_guard_now(bend)
		"recover", "fight":
			foe.held = false


var _dummy_next_double := -1.0


## The dummy's guard (E) begun now.
func _dummy_guard_now(bend: NpcBending) -> void:
	var g := NpcBending.guard_of(bend.element)
	if g.size() >= 2:
		_dummy_cast(bend, "%s/%s" % [g[0], g[1]])


## A guard zone of `b`'s own stands now.
func _guard_up(b: Node3D) -> bool:
	for z in mode.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.owner_node == b and BendZone.R2_GUARDS.has(bz.kind) and not bz.is_queued_for_deletion():
			return true
	return false


## `b` put off a random open end of the deck: recover_out_m out, recover_below_m under the lip, facing the deck (the
## recover drill, Throw me off).
func place_off(b: Node3D) -> void:
	var a := mode.ring if mode != null else null
	if a == null or b == null or not is_instance_valid(b):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([b.get_instance_id(), Engine.get_physics_frames()])
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var out := srange("recover_out_m", Vector2(3.0, 7.0))
	var below := srange("recover_below_m", Vector2(0.0, 1.5))
	place_at(b, side, rng.randf_range(out.x, out.y), rng.randf_range(below.x, below.y),
			rng.randf_range(-a.half_w() + 1.0, a.half_w() - 1.0))


## `b` put `out_m` past the deck's end on side `side_sign` (-1, +1: local x), `below_m` under the lip (its head that much
## under the lip's grab height: feet below_m + 1 m under the lip), `along` m along the end (local z), facing the deck, still.
func place_at(b: Node3D, side_sign: float, out_m: float, below_m: float, along: float) -> void:
	var a := mode.ring if mode != null else null
	if a == null or b == null or not is_instance_valid(b):
		return
	var p := a.to_global(Vector3(side_sign * (a.half_l() + out_m), 0.0, along))
	p.y = a.lip_y() - below_m - 1.0
	var fd := NpcRingMind.flat_dir(p, a.global_position)
	var face := Basis.looking_at(fd if fd != Vector3.ZERO else Vector3.FORWARD, Vector3.UP)
	RingLevel.place(b, Transform3D(face, p - Vector3.UP * 0.1))
	var kn := BendKnock.peek(b)
	if kn != null:
		kn.reset()
	if b is NpcFighter:
		(b as NpcFighter).held = false


## The dummy's element's move for `what` ("throw" | "cover": screens.json practice), "id/mode".
func pmove(what: String) -> String:
	return MatchSetup.practice_move(mode.foe_element, what)


## The dummy's lock of "id/mode" begun (let go: its tick fills it and casts it, NpcBending's own way).
func _dummy_cast(bend: Object, key_s: String) -> bool:
	if key_s == "" or not key_s.contains("/"):
		return false
	mode.foe.held = false
	bend.call(&"begin", key_s.get_slice("/", 0), key_s.get_slice("/", 1))
	return true


## A guard of the dummy's against what comes at it now ({id, mode, kind} or {}): its element's reaction whose lock fits the
## threat's time (NpcBending's own rule, without its chance: a practice dummy answers every time it can).
static func dummy_guard(bend: Object) -> Dictionary:
	var threats: Array = bend.call(&"_threats")
	if threats.is_empty():
		return {}
	var pn := String(bend.call(&"_preset_name"))
	var best := {}
	for th: Dictionary in threats:
		var tti := float(th.tti)
		for o: Dictionary in bend.get(&"options"):
			var h: Dictionary = o.hint
			if String(h.get("role", "")) != "reaction" or not String(th.kind) in (h.get("answers", []) as Array):
				continue
			if not bool(bend.call(&"castable", o)):
				continue
			var ls := NpcBending.lock_for(String(o.id), String(o.mode), pn, 0.0)
			var window := float(o.spec.get("window_s", o.spec.get("life_s", o.spec.get("s", 1.0))))
			if ls > tti or ls + window * 0.8 < tti:
				continue
			if best.is_empty() or ls < float(best.ls):
				best = {"id": o.id, "mode": o.mode, "kind": th.kind, "ls": ls}
	return best
