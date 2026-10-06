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
##   key(e) -> bool   R and B (true: it took the key)

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


func _init(m: RingMode = null) -> void:
	mode = m


## data/ring/screens.json practice's number `key`.
static func pnum(key: String, def: float) -> float:
	return float((MatchSetup.screens().get("practice", {}) as Dictionary).get(key, def))


## A practice word (screens.json practice.words).
static func pword(key: String) -> String:
	return String((((MatchSetup.screens().get("practice", {}) as Dictionary).get("words", {})) as Dictionary).get(key, key))


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


## A restart's: the dummy's way from MatchSetup, no reset waiting.
func reset() -> void:
	dummy = MatchSetup.dummy if MatchSetup.dummy in MatchSetup.DUMMIES else "stand"
	_reset_in = -1.0
	_live_in = 0.0


## The fight's go: the dummy's first throw half a throw_every_s away, its cover ready.
func arm() -> void:
	_dummy_next = BendStatus.now() + pnum("throw_every_s", 3.0) * 0.5
	_cover_next = 0.0


## The hint and tally lines shown in a practice (hidden in a match).
func paint() -> void:
	if hint == null:
		return
	var on := mode.practice
	hint.visible = on
	tally_label.visible = on
	hint_back.visible = on
	if on:
		hint.text = practice_line()
		var mine: Dictionary = mode.round_tally[0]
		tally_label.text = pword("tally") % [int(mine.get("casts", 0)), int(mine.get("catches", 0)), int(mine.get("knock_backs", 0))]


## "Practice  ·  a Stone dummy that throws at you every few seconds  ·  R: reset positions ..."
func practice_line() -> String:
	return pword("hint") % [MatchSetup.competitor(mode.foe_element), MatchSetup.dummy_line(dummy)]


## R and B in a practice's fight (true: taken).
func key(e: InputEvent) -> bool:
	if e.is_action_pressed(RESET_ACTION):
		reset_positions()
		return true
	if e.is_action_pressed(DUMMY_ACTION):
		cycle_dummy()
		return true
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


## The dummy's next way in turn (stand, block, throw), at once.
func cycle_dummy() -> void:
	var ds := MatchSetup.DUMMIES
	set_way(String(ds[(ds.find(dummy) + 1) % ds.size()]))


## The dummy's way `way` ("stand" | "block" | "throw"), at once: kept for the next practice, said on the banner.
func set_way(way: String) -> void:
	dummy = way if way in MatchSetup.DUMMIES else "stand"
	MatchSetup.dummy = dummy
	arm()
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
