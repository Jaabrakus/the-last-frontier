extends SceneTree
## Round 5 CLIPWIRE: every active % ring clip (animations_extra/Frontier_Bend.res) plays where the spec
## (smash_r3 §13) and rounds 3 and 4 mean it to, on the player AND on a bot, in a real stock-rules match (scenes/ring.tscn, the
## player against a bot of his element; one match per element). Each situation is brought about the way the game brings it
## about: the player's keys (PlayerControls driven by the test; his SwayCaster's held/quick/guard overrides for the clicks and
## E; key 3 through key3_press), the bot's pad (NpcPad) and its NpcBending.begin (the mind's own call), real knocks
## (BendKnock.knock with the % rules' launch) and the spout's ride (RingMoves.ride_spout, as a respawn). What shows is read
## off the bodies every frame: the player's SwayPose (its ring layer, its cast clip, its struck layer, its air legs; each on
## his ToolPose) and the bot's NpcBody (the clip its AnimationPlayer plays).
##   movement    the double jump, the fall, the fast fall, controlled flight after a Rise, the air dodge, the landings
##               (light: a cast's landing lag; heavy: after a Rise), the teeter, the spout's ride and its step-off
##   the edge    the grab, the hang, the climb, the roll in, the jump, the attack, the scramble (a Rise up the face)
##   the deck    the rolls (forward, back, right, left) and the duck (E, then a direction or C)
##   knocks      the tumble, the flinch, the spiked knock, the bounce, lying, the getups (stand, roll right and left,
##               attack), breaking the fall (standing, rolling right and left, on a wall)
##   per element the Rise, the air close hit and its twin, the Slam (fire's Axe Kick and its twin), the Pop's rising hand
##               and its twin, the held guard; fire's air High Kick (the flip kick) and its twin (the player only: no bot
##               casts it)
##   the struck  a held hit from the front, the back, the left and the right shows own-bend-hit-impact-<side> at its contact
##               frame through the whole hold (the player's struck layer at weight 1, the bot's clip at its hold_s), then
##               the tumble takes over
## Inactive compatibility mappings must still load; they are not claimed as played. The air legs are the player's only
## (a bot plays its casts whole). METRIC lines: clips_player_ok, clips_bot_ok,
## struck_hold_ok. Last line "CLIP SITUATIONS PASSED" or "CLIP SITUATIONS FAILED" (exit 0 only on a pass).
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_clip_situations.gd [-- els=earth,fire]

const NAME := "CLIP SITUATIONS"
const LIMIT_S := 900.0
const OWN_CFG := "user://clip_situations_test.cfg"
const ELEMENTS := ["earth", "water", "fire", "air"]
## Clips no bot plays: the air legs (the player's layer under an air cast), the air High Kick (no bot casts it).
const PLAYER_ONLY := ["own-bend-air-legs", "own-bend-fire-flip-kick", "own-bend-fire-flip-kick-l"]
## The compatibility mapping remains loaded, but a spent Rise now returns control instead of entering helplessness.
const INACTIVE_CLIPS := ["own-bend-helpless"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var c: SwayCaster
var foe: NpcFighter
var el := "earth"
## clip -> {"p": [situation...], "b": [situation...]} where it was seen.
var seen_in := {}
var _seen := {"p": {}, "b": {}}
var _taps: Array[StringName] = []
var _hover := {}
var _wall: StaticBody3D
var struck_ok := true
var _mute := false


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	# (the Pop armed by the jab string, its own rules: the combo's finishers replace it in the ring since 2026-10-15; off here)
	BendCombo.enabled = false
	SwayCaster.free_override = true
	BendImpact.enabled_override = true
	InputSetup.ensure()
	physics_frame.connect(_physics)
	process_frame.connect(_record)
	_run.call_deferred()


# ---------------------------------------------------------------- the frame: keys let go, hovers kept, what shows recorded
func _physics() -> void:
	if player != null and is_instance_valid(player) and player.controls != null:
		var keep: Array[StringName] = []
		for a in _taps:
			if int(player.controls._down_at.get(a, -1)) == Engine.get_physics_frames():
				keep.append(a)
			else:
				player.controls.set_held(a, false)
		_taps = keep
	for who: String in _hover:
		var b := _body(who)
		if b != null and is_instance_valid(b):
			b.global_position.y = float(_hover[who])
			(b as CharacterBody3D).velocity.y = 0.0
	if mode != null and is_instance_valid(mode) and mode.phase == "FIGHT":
		mode.phase_t = 0.0                           # (the clock kept from running out under the test)
	if _mute and foe != null and is_instance_valid(foe) and _bend().ring_mind != null:
		_bend().ring_mind._launch = {}               # (its own breaks and its own getting up kept off: the test's pad)
		_bend().ring_mind._lying_seen = INF
	_record()


func _record() -> void:
	if c != null and is_instance_valid(c) and c.pose != null:
		var sp := c.pose
		var lay: Array = sp._pose.layers if sp._pose != null and is_instance_valid(sp._pose) and sp._pose.active else []
		var on_body := {}
		for l: Dictionary in lay:
			if float(l.get("weight", 0.0)) > 0.0 and l.get("anim") != null:
				on_body[l.anim] = true
		for nm: StringName in [sp.ring_clip(), sp.current_clip(), sp.struck_clip()]:
			if String(nm) != "" and on_body.has(BendPoses.animation(String(nm))):
				_seen.p[String(nm)] = true
		if sp._al_anim != null and sp._al_w > 0.0 and on_body.has(sp._al_anim):
			_seen.p["own-bend-air-legs"] = true
	if foe != null and is_instance_valid(foe) and foe.body != null:
		var nb := foe.body.shown_clip()
		if nb != "":
			_seen.b[nb] = true


# ---------------------------------------------------------------- helpers
func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(round(s * Engine.physics_ticks_per_second)), 1))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _body(who: String) -> Node3D:
	return player if who == "p" else foe


func _rm(who: String) -> RingMoves:
	return RingMoves.of(_body(who))


func _bend() -> NpcBending:
	return foe.brain.bending as NpcBending


## World point at ring-local (x along the deck from its middle, z across; y over the deck's top).
func _at(x: float, z := 0.0, y := 0.0) -> Vector3:
	return ring.to_global(Vector3(x, ring.top() + y, z))


## The -X lip's x (ring local).
func _lip_x() -> float:
	return -ring.half_l()


## Ring-local +X as a world way (toward the deck from the -X lip).
func _deck_way() -> Vector3:
	return (ring.global_basis * Vector3(1.0, 0.0, 0.0)).normalized()


func _yaw_of(way: Vector3) -> float:
	return atan2(-way.x, -way.z)


## Nothing held or pressed, no hover, no knock, no lock; `who` put at ring-local `pos` facing `way` (still, its moves
## reset) and the other one parked far off at the other end, both whole; the % and lives back to the start. The bot's mind
## (NpcRingMind: its own edge choices on its pad) is held out when not `think` (the edge: the bot held, its pad the test's);
## its reeling and getting up are muted while _mute (its launch's rolls and its lying reaction cleared each frame).
func _reset(who: String, pos: Vector3, way := Vector3.ZERO, think := true) -> void:
	_hover.clear()
	player.controls.release_all()
	_taps.clear()
	c.held_override = false
	c.quick_override = false
	c.guard_override = false
	c._wait_release = false
	c.drop_all()
	foe.pad.clear()
	var bend := _bend()
	if bend.casting != "":
		bend._cancel()
	if bend.ring_mind != null:
		bend.ring_mind.shield = {}
	foe.action = ""
	foe.held = not think
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormStone.GROUP, GustLift.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	rules.reset_game()
	rules._stale.clear()
	mode._respawns.clear()
	if way == Vector3.ZERO:
		way = _deck_way()
	for w: String in ["p", "b"]:
		var b := _body(w)
		mode._hide(b, false)
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
			kn.stun_t = 0.0
			kn.lying_t = 0.0
		for k: StringName in [BendImpact.HOLD_META, BendImpact.OWE_META, BendImpact.RATE_META, BendImpact.STRUCK_META]:
			if b.has_meta(k):
				b.remove_meta(k)
		var at := pos if w == who else _at(ring.half_l() - 3.0, 4.0 if w == "b" else -4.0)
		var yaw := _yaw_of(way if w == who else -_deck_way())
		b.global_position = at
		(b as CharacterBody3D).velocity = Vector3.ZERO
		if b == player:
			player.yaw = yaw
			player.rotation.y = yaw
			player.pitch = -0.05
		else:
			foe.rotation.y = yaw
			foe.set(&"_face", yaw)
		var m := RingMoves.of(b)
		if m != null:
			m.placed()
	await _ticks(6)
	_seen = {"p": {}, "b": {}}


## A key of the player's this physics frame (let go the next).
func _ptap(action: StringName) -> void:
	player.controls.set_held(action, true)
	_taps.append(action)


## The player's move key whose way (his camera's yaw) is nearest world `way`.
func _key_for(way: Vector3) -> StringName:
	var yb := Basis(Vector3.UP, player.yaw)
	var best := &"move_forward"
	var bd := -INF
	for pair: Array in [[&"move_forward", Vector3.FORWARD], [&"move_back", Vector3.BACK], [&"move_left", Vector3.LEFT],
			[&"move_right", Vector3.RIGHT]]:
		var d := (yb * Vector3(pair[1])).dot(way)
		if d > bd:
			bd = d
			best = pair[0]
	return best


## A press of `what` by `who`: jump, down (C: the fast fall), guard (E), attack (a click), dodge (key 3 / the pad's dodge).
func _press(who: String, what: String) -> void:
	if who == "p":
		match what:
			"jump":
				_ptap(&"jump")
			"down":
				_ptap(&"crouch")
			"guard":
				_ptap(InputSetup.GUARD_ACTION)
			"attack":
				_ptap(&"fire")
			"dodge":
				c.key3_press()
	else:
		match what:
			"down":
				foe.pad.press("fast_fall")
			"attack":
				foe.pad.press("attack")
			_:
				foe.pad.press(what)


## `who` holding world way `way` (ZERO: let go); `fresh`: a fresh tap of it this frame (the roll's).
func _move(who: String, way: Vector3, fresh := false) -> void:
	if who == "p":
		for k: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			player.controls.set_held(k, false)
		if way != Vector3.ZERO:
			player.controls.set_held(_key_for(way), true)
	else:
		foe.pad.move = Vector3(way.x, 0.0, way.z).normalized() if way != Vector3.ZERO else Vector3.ZERO
		if fresh and way != Vector3.ZERO:
			foe.pad.press("roll")


## Waits up to `limit` s for `clip` on `who`; records it. True when seen.
func _wait(who: String, clip: String, limit: float, situation: String) -> bool:
	var t := await _until(func() -> bool: return (_seen[who] as Dictionary).has(clip), limit)
	var ok := t < INF
	if ok:
		_mark(who, clip, situation)
	return ok


func _mark(who: String, clip: String, situation: String) -> void:
	if not seen_in.has(clip):
		seen_in[clip] = {"p": [], "b": []}
	if not situation in (seen_in[clip][who] as Array):
		(seen_in[clip][who] as Array).append(situation)


## Every clip seen on `who` since the reset noted under `situation` (the sightings a situation brings with it).
func _note_all(who: String, situation: String) -> void:
	for nm: String in (_seen[who] as Dictionary):
		if nm.begins_with("own-bend-"):
			_mark(who, nm, situation)


func _who_name(who: String) -> String:
	return "the player" if who == "p" else "the bot"


# ---------------------------------------------------------------- the run
func _run() -> void:
	var els: Array = ELEMENTS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("els="):
			els = Array(a.trim_prefix("els=").split(","))
	for e: String in els:
		el = e
		var ok := await _scene(e)
		_expect(ok, "%s: the stock ring, its match, the player and a %s bot" % [e, e])
		if not ok:
			continue
		for who: String in ["p", "b"]:
			await _per_element(who)
			if e == els[0]:
				await _movement(who)
				await _edge(who)
				await _deck(who)
				await _knocks(who)
				await _struck(who)
	_verdict()
	_end()


func _scene(e: String) -> bool:
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = e
	MatchSetup.foes = [e]
	player = null
	foe = null
	c = null
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 12:
		await process_frame
	lvl = current_scene as RingLevel
	if lvl == null:
		return false
	ring = lvl.ring
	player = lvl.player
	mode = RingMode.find(self)
	if mode == null or player == null:
		return false
	rules = mode.rules
	player.ignore_mouse_capture = true
	player.controls = PlayerControls.new(false)
	c = SwayCaster.of(player)
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and mode.foe != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	foe = mode.foe if is_instance_valid(mode.foe) else null
	if foe == null:
		return false
	foe.held = false
	foe._think_t = 1e9                                 # (its mind never thinks: the test drives its pad and its casts)
	foe.brain.target = player
	await _until(func() -> bool: return player.arena_element == e and p_ready(), 4.0)
	await _ticks(25)
	return RingRules.stock_on() and foe.ring_moves != null and player.ring_moves != null


func p_ready() -> bool:
	return player.hotbar != null and player.hotbar.spell != ""


# ---------------------------------------------------------------- per element: the Rise, the air hit, the Slam, the Pop, the guard
func _per_element(who: String) -> void:
	var tag := "%s (%s)" % [el, _who_name(who)]
	# the Rise off the deck, then controlled flight with the Rise still spent
	await _reset(who, _at(_lip_x() - 4.0, 0.0, -0.5), _deck_way())
	_rm(who).jumps_left = 0
	var rise_started := _rm(who)._t
	_press(who, "jump")
	var rise := "own-bend-rise-" + el
	_expect(await _wait(who, rise, 1.5, "the Rise"), "%s: Space off the deck, jumps spent: the Rise plays %s" % [tag, rise])
	var ended := await _until(func() -> bool: return _rm(who)._rise_end_at >= rise_started, 2.0) < INF
	var controlled := ended and not _rm(who).helpless() and _rm(who).can_cast() and not _rm(who).rise_ready
	var fall := await _wait(who, "own-bend-fall", 0.8, "controlled fall after the Rise")
	_expect(controlled and fall and not (_seen[who] as Dictionary).has("own-bend-helpless"),
			"%s: after the Rise: control restored, Rise spent, ordinary fall (%s, %s)" % [tag, controlled, fall])
	_note_all(who, "the Rise")
	# the air close hit, then its twin
	var jb := Bending.jab(el)
	var hit := "own-bend-air-hit-" + el
	await _reset(who, _at(-6.0, 0.0, 2.0), Vector3.ZERO, true)
	_hover[who] = _at(-6.0, 0.0, 2.0).y
	await _ticks(3)
	if who == "p":
		c.quick_override = true
		var a := await _wait(who, hit, 0.6, "the air hit")
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
		c.quick_override = false
		await _ticks(3)
		c.quick_override = true
		var b := await _wait(who, hit + "-l", 0.6, "the air hit again")
		_expect(a and b, "%s: LMB in the air: the air hit %s, again at once its twin -l (%s, %s)" % [tag, hit, a, b])
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
		c.quick_override = false
		await _ticks(10)
		_note_all(who, "an air cast")
	else:
		var bend := _bend()
		bend.begin(String(jb.id), String(jb.mode))
		var a := await _wait(who, hit, 0.6, "the air hit")
		await _until(func() -> bool: return bend.casting == "", 2.5)
		await _ticks(3)
		bend.begin(String(jb.id), String(jb.mode))
		var b := await _wait(who, hit + "-l", 0.6, "the air hit again")
		_expect(a and b, "%s: its jab begun in the air: the air hit %s, the next its twin -l (mode %s; %s, %s)" % [tag, hit,
				bend.mode, a, b])
		await _until(func() -> bool: return bend.casting == "", 2.5)
	# the Slam (key 2's first move begun in the air)
	var slam := {"earth": "own-bend-earth-hammer", "water": "own-bend-water-downpour", "fire": "own-bend-fire-axe-kick",
			"air": "own-bend-air-down-gust"}[el] as String
	await _reset(who, _at(-6.0), Vector3.ZERO, true)
	if who == "p":
		player.hotbar.select(1)
		await _ticks(3)
	_hover[who] = _at(-6.0, 0.0, 2.5).y
	await _ticks(3)
	if who == "p":
		c.held_override = true
		var a := await _wait(who, slam, 0.6, "the Slam")
		var form := c.mode_of(c.move)
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
		c.held_override = false
		var b := true
		if el == "fire":
			await _ticks(3)
			c.held_override = true
			b = await _wait(who, slam + "-l", 0.6, "the Slam again")
			await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
			c.held_override = false
		_expect(a and b, "%s: key 2 begun in the air: the Slam (%s) plays %s%s (%s, %s)" % [tag, form, slam,
				", again its twin" if el == "fire" else "", a, b])
		await _ticks(10)
		_note_all(who, "an air cast")
	else:
		var bend := _bend()
		var k2 := Bending.first_of(Bending.keys(el)[1])
		bend.begin(String(k2.id), String(k2.mode))
		var a := await _wait(who, slam, 0.6, "the Slam")
		var md := bend.mode
		await _until(func() -> bool: return bend.casting == "", 3.0)
		var b := true
		if el == "fire":
			await _ticks(3)
			bend.begin(String(k2.id), String(k2.mode))
			b = await _wait(who, slam + "-l", 0.6, "the Slam again")
			await _until(func() -> bool: return bend.casting == "", 3.0)
		_expect(a and b, "%s: key 2's first move begun in the air: the Slam (%s) plays %s%s (%s, %s)" % [tag, md, slam,
				", the next its twin" if el == "fire" else "", a, b])
	# fire's air High Kick: the flip kick and its twin (the player's only)
	if el == "fire" and who == "p":
		await _reset(who, _at(-6.0), Vector3.ZERO, true)
		player.hotbar.select(1)
		await _ticks(2)
		player.hotbar.select(1)
		await _secs(0.35)
		_hover[who] = _at(-6.0, 0.0, 2.5).y
		await _ticks(3)
		c.held_override = true
		var a := await _wait(who, "own-bend-fire-flip-kick", 0.6, "the air High Kick")
		var form := c.mode_of(c.move)
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
		c.held_override = false
		await _ticks(3)
		c.held_override = true
		var b := await _wait(who, "own-bend-fire-flip-kick-l", 0.6, "the air High Kick again")
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
		c.held_override = false
		_expect(a and b, "%s: 2 twice in the air: the air High Kick (%s) plays the flip kick, again its twin (%s, %s)" % [tag,
				form, a, b])
	# the Pop's rising hand: a jab with the Pop armed (the jab string's third), then again
	await _reset(who, _at(-6.0), Vector3.ZERO, true)
	var bc := BendCaster.of(_body(who))
	bc.jab = {"hits": int(BendR3.block("pop").get("hits", 3)) - 1, "at": BendStatus.now(), "popped": false}
	if who == "p":
		c.quick_override = true
		var a := await _wait(who, "own-bend-jab-rise", 0.6, "the Pop")
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
		c.quick_override = false
		await _ticks(3)
		bc.jab = {"hits": int(BendR3.block("pop").get("hits", 3)) - 1, "at": BendStatus.now(), "popped": false}
		c.quick_override = true
		var b := await _wait(who, "own-bend-jab-rise-l", 0.6, "the Pop again")
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
		c.quick_override = false
		_expect(a and b, "%s: LMB with the Pop armed: the rising hand, again its twin (%s, %s)" % [tag, a, b])
	else:
		var bend := _bend()
		bend.begin(String(jb.id), String(jb.mode))
		var a := await _wait(who, "own-bend-jab-rise", 0.6, "the Pop")
		await _until(func() -> bool: return bend.casting == "", 2.5)
		bc.jab = {"hits": int(BendR3.block("pop").get("hits", 3)) - 1, "at": BendStatus.now(), "popped": false}
		await _ticks(3)
		bend.begin(String(jb.id), String(jb.mode))
		var b := await _wait(who, "own-bend-jab-rise-l", 0.6, "the Pop again")
		await _until(func() -> bool: return bend.casting == "", 2.5)
		_expect(a and b, "%s: its jab with the Pop armed: the rising hand, the next its twin (%s, %s)" % [tag, a, b])
	# the held guard: E held (the player), a shield raised and held (the bot)
	var gh := "own-bend-guard-hold-" + el
	await _reset(who, _at(-6.0), Vector3.ZERO, true)
	if who == "p":
		c.guard_override = true
		var a := await _wait(who, gh, 2.0, "the held guard")
		c.guard_override = false
		_expect(a, "%s: E held, the guard up: its held loop %s" % [tag, gh])
	else:
		var bend := _bend()
		var g := NpcBending.guard_of(el)
		bend.mind().raise_shield({"id": 4242, "kind": "bolt", "tti": 3.0})
		bend.begin(String(g[0]), String(g[1]))
		var a := await _wait(who, gh, 2.5, "the held guard")
		_expect(a, "%s: its guard raised as a shield and held: the held loop %s (shield %s)" % [tag, gh, bend.ring_mind.shield])
		if bend.ring_mind != null:
			bend.ring_mind.drop_shield()


# ---------------------------------------------------------------- movement
func _movement(who: String) -> void:
	var tag := _who_name(who)
	# the double jump
	await _reset(who, _at(-6.0))
	_press(who, "jump")
	await _secs(0.2)
	_press(who, "jump")
	_expect(await _wait(who, "own-bend-jump-double", 0.6, "the double jump"), "%s: Space, Space: own-bend-jump-double" % tag)
	await _secs(0.8)
	# the fall, the fast fall
	await _reset(who, _at(-6.0, 0.0, 6.0))
	_expect(await _wait(who, "own-bend-fall", 1.0, "the fall"), "%s: dropped from 6 m: own-bend-fall" % tag)
	_press(who, "down")
	_expect(await _wait(who, "own-bend-fall-fast", 0.6, "the fast fall"), "%s: C falling: own-bend-fall-fast" % tag)
	await _secs(0.6)
	# the air dodge
	await _reset(who, _at(-6.0))
	_press(who, "jump")
	await _secs(0.2)
	_press(who, "dodge")
	_expect(await _wait(who, "own-bend-air-dodge", 0.6, "the air dodge"), "%s: key 3 in the air: own-bend-air-dodge" % tag)
	await _secs(0.8)
	# the landings: a cast's landing lag; the recovery landing after a controlled Rise
	await _reset(who, _at(-6.0))
	_rm(who).land_lag(0.25)
	_expect(await _wait(who, "own-bend-land-light", 0.4, "the landing lag"), "%s: a cast's landing lag: own-bend-land-light" % tag)
	await _reset(who, _at(_lip_x() - 4.0, 0.0, -0.5), _deck_way())
	_rm(who).jumps_left = 0
	var rise_started := _rm(who)._t
	_press(who, "jump")
	await _until(func() -> bool: return _rm(who)._rise_end_at >= rise_started, 2.0)
	var b := _body(who)
	var to := _at(_lip_x() + 1.5, 0.0, 1.5)
	while b.global_position.distance_to(to) > 0.05:
		# Carry over the deck below teleport_m, preserving the pending recovery landing.
		b.global_position = b.global_position.move_toward(to, 2.0)
		(b as CharacterBody3D).velocity = Vector3.ZERO
		await physics_frame
	_expect(await _wait(who, "own-bend-land-heavy", 2.0, "landing after the Rise"), "%s: after the Rise, contact with the deck: own-bend-land-heavy" % tag)
	await _secs(0.5)
	# the teeter: run at the lip
	await _reset(who, _at(_lip_x() + 2.0), -_deck_way())
	_move(who, -_deck_way())
	var tt := await _wait(who, "own-bend-teeter", 1.5, "the teeter")
	_move(who, Vector3.ZERO)
	_expect(tt, "%s: run at the lip: own-bend-teeter" % tag)
	# the spout: its ride, then off it
	await _reset(who, _at(-6.0))
	_rm(who).ride_spout(_at(-6.0, 0.0, 3.0), 3.0)
	var ride := await _wait(who, "own-bend-spout-ride", 0.6, "the spout")
	await _secs(0.4)
	_move(who, _deck_way())
	var off := await _wait(who, "own-bend-spout-step-off", 0.6, "off the spout")
	_move(who, Vector3.ZERO)
	_expect(ride and off, "%s: on the spout its ride, a step off it the step-off (%s, %s)" % [tag, ride, off])
	await _secs(0.6)


# ---------------------------------------------------------------- the edge
## `who` dropped 0.5 m past the -X lip just over it, facing the deck: true when he hangs.
func _drop(who: String) -> bool:
	await _reset(who, _at(_lip_x() - 0.5, 0.0, 0.3), _deck_way(), false)
	return await _until(func() -> bool: return _rm(who).on_ledge(), 1.0) < INF


func _edge(who: String) -> void:
	var tag := _who_name(who)
	var hung := await _drop(who)
	var grab := await _wait(who, "own-bend-edge-grab", 0.3, "the grab")
	var hang := await _wait(who, "own-bend-edge-hang", 0.6, "the hang")
	_expect(hung and grab and hang, "%s: dropped at the lip: the grab, then the hang (%s, %s, %s)" % [tag, hung, grab, hang])
	await _secs(0.7)
	for opt: Array in [["climb", "own-bend-edge-climb"], ["roll", "own-bend-edge-roll"], ["jump", "own-bend-edge-jump"],
			["attack", "own-bend-edge-attack"]]:
		var ok := await _drop(who)
		await _secs(0.3)
		if who == "p":
			match String(opt[0]):
				"climb":
					_ptap(_key_for(_deck_way()))
				"roll":
					_press(who, "guard")
				"jump":
					_press(who, "jump")
				"attack":
					_press(who, "attack")
		else:
			foe.pad.ledge_option(String(opt[0]))
		var seen := await _wait(who, String(opt[1]), 1.0, "the edge's " + String(opt[0]))
		_expect(ok and seen, "%s: hanging, the %s: %s" % [tag, opt[0], opt[1]])
		await _secs(0.5)
	# the scramble: a Rise up the face from under the lip
	await _reset(who, _at(_lip_x() - 0.2, 0.0, -2.6), _deck_way(), false)
	_rm(who).jumps_left = 0
	_press(who, "jump")
	var sc := await _wait(who, "own-bend-edge-scramble", 1.0, "the scramble")
	_expect(sc, "%s: a Rise up the face under the lip: own-bend-edge-scramble (mode %s)" % [tag, _rm(who).mode])
	await _secs(0.4)


# ---------------------------------------------------------------- the deck: rolls and the duck
func _deck(who: String) -> void:
	var tag := _who_name(who)
	for r: Array in [["own-bend-roll-f", 0.0], ["own-bend-roll-b", 180.0], ["own-bend-roll-side", -90.0], ["own-bend-roll-side-l", 90.0]]:
		await _reset(who, _at(-6.0))
		var b := _body(who)
		var fwd := -b.global_basis.z
		fwd.y = 0.0
		var way := Basis(Vector3.UP, deg_to_rad(float(r[1]))) * fwd.normalized()
		_press(who, "guard")
		await _ticks(1)
		if who == "p":
			_ptap(_key_for(way))
		else:
			_move(who, way, true)
		var seen := await _wait(who, String(r[0]), 0.6, "the roll")
		_move(who, Vector3.ZERO)
		_expect(seen, "%s: E then a direction (%d deg): %s" % [tag, int(r[1]), r[0]])
		await _secs(0.7)
	await _reset(who, _at(-6.0))
	_press(who, "guard")
	await _ticks(1)
	_press(who, "down")
	_expect(await _wait(who, "own-bend-duck", 0.6, "the duck"), "%s: E then C: own-bend-duck" % tag)
	await _secs(0.6)


# ---------------------------------------------------------------- knocks: tumble, flinch, spiked, bounce, lying, getups, breaks
## A launch of `v` on `who` (the % rules' kind: SET, its hitstun, tumbling or not), by the other one.
func _knock(who: String, v: Vector3, tumble := true, hs := -1.0) -> void:
	var b := _body(who)
	var by := _body("b" if who == "p" else "p")
	var h := hs if hs > 0.0 else RingRules.hitstun_of(v.length())
	BendKnock.of(b).knock(v, by, {"_launch": {"v": v, "hitstun_s": h, "tumble": tumble}})


## Down on the deck from 2.5 m, spiked; E pressed as the deck comes (with a direction held when `way` is not ZERO).
func _spike_down(who: String, press: bool, way := Vector3.ZERO) -> void:
	await _reset(who, _at(-6.0, 0.0, 2.5))
	_knock(who, Vector3(0.0, -8.0, 0.0), true, 1.0)
	if not press:
		return
	var b := _body(who)
	await _until(func() -> bool: return not BendKnock.of(b).pending() and b.global_position.y - _at(0.0).y < 0.9, 1.5)
	if way != Vector3.ZERO:
		_move(who, way)
	_press(who, "guard")


func _knocks(who: String) -> void:
	var tag := _who_name(who)
	var b := _body(who)
	_mute = who == "b"
	# the tumble, the flinch
	await _reset(who, _at(-6.0))
	_knock(who, _deck_way() * 6.0 + Vector3.UP * 8.0)
	_expect(await _wait(who, "own-bend-tumble", 1.0, "a launch"), "%s: launched: own-bend-tumble" % tag)
	await _until(func() -> bool: return b.is_on_floor() and not BendKnock.of(b).is_launched(), 3.0)
	await _secs(1.5)
	await _reset(who, _at(-6.0))
	_knock(who, _deck_way() * 3.0, false, 0.3)
	_expect(await _wait(who, "own-bend-flinch", 0.5, "a light hit"), "%s: a light hit on the deck: own-bend-flinch" % tag)
	await _secs(0.6)
	# spiked, the bounce, lying, then each getup
	for g: Array in [["stand", "own-bend-getup"], ["roll", "own-bend-getup-roll"], ["roll_l", "own-bend-getup-roll-l"],
			["attack", "own-bend-getup-attack"]]:
		await _spike_down(who, false)
		var sp := await _wait(who, "own-bend-knock-spiked", 0.6, "spiked")
		var bo := await _wait(who, "own-bend-knock-bounce", 1.5, "the bounce")
		var lie := await _wait(who, "own-bend-lie", 1.5, "lying")
		await _secs(0.45)
		var right := b.global_basis.x
		right.y = 0.0
		right = right.normalized()
		match String(g[0]):
			"stand":
				_press(who, "jump")
			"roll", "roll_l":
				var way := right if String(g[0]) == "roll" else -right
				if who == "p":
					player.controls.set_held(InputSetup.GUARD_ACTION, true)
					_ptap(_key_for(way))
				else:
					foe.pad.hold("guard", true)
					_move(who, way)
			"attack":
				_press(who, "attack")
		var up := await _wait(who, String(g[1]), 0.8, "the getup " + String(g[0]))
		_move(who, Vector3.ZERO)
		if who == "p":
			player.controls.set_held(InputSetup.GUARD_ACTION, false)
		else:
			foe.pad.hold("guard", false)
		_expect(sp and bo and lie and up, "%s: spiked down, no E: spiked, the bounce, lying (%s, %s, %s); then %s: %s (%s)" % [
				tag, sp, bo, lie, g[0], g[1], up])
		await _secs(0.8)
	# breaking the fall: standing, rolling right and left
	for t: Array in [["", "own-bend-tech"], ["right", "own-bend-tech-roll"], ["left", "own-bend-tech-roll-l"]]:
		var right := b.global_basis.x
		right.y = 0.0
		right = right.normalized()
		var way := Vector3.ZERO if String(t[0]) == "" else (right if String(t[0]) == "right" else -right)
		await _spike_down(who, true, way)
		var ok := await _wait(who, String(t[1]), 1.0, "the fall broken")
		_move(who, Vector3.ZERO)
		_expect(ok, "%s: spiked down, E as the deck comes%s: %s" % [tag, (" holding " + String(t[0])) if t[0] != "" else "", t[1]])
		await _secs(0.8)
	# on a wall: a stone slab on the deck, flown into tumbling, E just before
	if _wall == null or not is_instance_valid(_wall):
		_wall = StaticBody3D.new()
		_wall.name = "ClipTestWall"
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.6, 4.0, 6.0)
		cs.shape = bx
		_wall.add_child(cs)
		current_scene.add_child(_wall)
	_wall.global_transform = Transform3D(ring.global_basis, _at(-2.0, 0.0, 2.0))
	await _reset(who, _at(-4.5, 0.0, 1.2), _deck_way())
	_knock(who, _deck_way() * 9.0 + Vector3.UP * 2.0, true, 1.0)
	await _until(func() -> bool: return not BendKnock.of(b).pending() and absf((b.global_position - _wall.global_position).dot(_deck_way())) < 1.1, 1.0)
	_press(who, "guard")
	if OS.get_cmdline_user_args().has("debug"):
		for i in 20:
			await physics_frame
			var kd := BendKnock.of(b)
			print("    DBG wall %s pos=%s v=%s tumble=%s launched=%s pend=%s kv=%s presses=%d floor=%s wall=%s mode=%s st=%s" % [who,
					b.global_position - _wall.global_position, (b as CharacterBody3D).velocity, kd.tumble, kd.is_launched(), kd.pending(),
					kd.kv, kd._presses.size(), (b as CharacterBody3D).is_on_floor(), (b as CharacterBody3D).is_on_wall(), _rm(who).mode,
					_rm(who).clip_state()])
	var tw := await _wait(who, "own-bend-tech-wall", 1.0, "the fall broken on a wall")
	_expect(tw, "%s: flown into a wall tumbling, E just before: own-bend-tech-wall" % tag)
	_wall.global_position += Vector3.UP * 200.0
	await _secs(0.8)
	_mute = false


# ---------------------------------------------------------------- the struck pose and the hit-stop
func _struck(who: String) -> void:
	var tag := _who_name(who)
	var b := _body(who)
	for side: String in ["front", "back", "left", "right"]:
		await _reset(who, _at(-6.0))
		var fwd := -b.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP)
		var push: Vector3 = {"front": -fwd, "back": fwd, "left": right, "right": -right}[side]
		var nm := "own-bend-hit-impact-" + side
		var anim := BendPoses.animation(nm)
		var hold_s := float(anim.get_meta(&"hold_s", 0.1)) if anim != null else -1.0
		_knock(who, push * 12.0 + Vector3.UP * 6.0)
		var held_n := 0
		var contact := true
		var shared_rate := true
		var given := BendImpact.struck_of(b)
		while BendImpact.held(b):
			await process_frame
			if not BendImpact.held(b):
				break
			held_n += 1
			var rate := BendImpact.pose_rate(b, 1.0 / 60.0)
			var debt := float(b.get_meta(BendImpact.OWE_META, 0.0))
			var other_rate := BendImpact.pose_rate(b, 1.0 / 60.0)
			shared_rate = shared_rate and rate == other_rate and is_equal_approx(debt, float(b.get_meta(BendImpact.OWE_META, 0.0)))
			if who == "p" and held_n == 1:
				continue                             # (his SwayPose takes the hit on its own first frame after this one)
			if who == "p":
				contact = contact and c.pose.struck_clip() == StringName(nm) and is_equal_approx(c.pose.struck_weight(), 1.0) \
						and absf(c.pose._s_t - hold_s) < 1e-4
			else:
				contact = contact and foe.body.shown_clip() == nm and absf(foe.body.ap.current_animation_position - hold_s) < 1e-3
		var seen := (_seen[who] as Dictionary).has(nm)
		if seen:
			_mark(who, nm, "struck from the " + side)
		var tum := await _wait(who, "own-bend-tumble", 0.6, "after the struck pose")
		var ok := seen and held_n >= 2 and contact and shared_rate and String(given.get("side", "")) == side and tum
		struck_ok = struck_ok and ok
		_expect(ok, "%s: hit from the %s: %s at its contact (%.2f s) through the hold (%d frames, held %s), then the tumble (%s)"
				% [tag, side, nm, hold_s, held_n, contact, tum])
		await _until(func() -> bool: return b.is_on_floor() and not BendKnock.of(b).is_launched(), 3.0)
		await _secs(1.2)


# ---------------------------------------------------------------- the verdict: every clip on both
func _all_clips() -> Array[String]:
	var out: Array[String] = []
	var clips: Dictionary = RingMoves.block("clips")
	for k: String in clips:
		if clips[k] is Dictionary and String((clips[k] as Dictionary).get("clip", "")) != "":
			out.append(String(clips[k].clip))
	for e: String in ELEMENTS:
		for nm: String in ["own-bend-air-hit-" + e, "own-bend-air-hit-%s-l" % e, "own-bend-guard-hold-" + e]:
			out.append(nm)
	for nm: String in ["own-bend-earth-hammer", "own-bend-water-downpour", "own-bend-fire-axe-kick", "own-bend-fire-axe-kick-l",
			"own-bend-air-down-gust", "own-bend-jab-rise", "own-bend-jab-rise-l", "own-bend-fire-flip-kick", "own-bend-fire-flip-kick-l"]:
		out.append(nm)
	return out


func _verdict() -> void:
	var all := _all_clips()
	var p_ok := true
	var b_ok := true
	var missing_lib: Array[String] = []
	var ran := true                                     # (every element run: no els= given)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("els="):
			ran = false
	print("  clip                              player                          bot")
	for nm: String in all:
		if BendPoses.animation(nm) == null:
			missing_lib.append(nm)
		var rec: Dictionary = seen_in.get(nm, {"p": [], "b": []})
		var pp: Array = rec.p
		var bb: Array = rec.b
		var b_na := nm in PLAYER_ONLY
		if nm in INACTIVE_CLIPS:
			print("  %-34s inactive compatibility mapping (not required or claimed as played)" % nm)
			continue
		print("  %-34s %-31s %s" % [nm, ", ".join(pp) if not pp.is_empty() else "-", "n/a" if b_na else (", ".join(bb) if not bb.is_empty() else "-")])
		if ran:
			p_ok = p_ok and not pp.is_empty()
			b_ok = b_ok and (b_na or not bb.is_empty())
	_expect(missing_lib.is_empty(), "every clip the ring names is in our own libraries (%d clips; missing %s)" % [all.size(), missing_lib])
	if ran:
		_expect(p_ok, "every one of the %d active clips played on the player in its situation" % (all.size() - INACTIVE_CLIPS.size()))
		_expect(b_ok, "every one played on a bot too (but %s, the player's only)" % [PLAYER_ONLY])
	print("METRIC clips_player_ok=%s" % p_ok)
	print("METRIC clips_bot_ok=%s" % b_ok)
	print("METRIC struck_hold_ok=%s" % struck_ok)
	print("METRIC clips_total=%d" % all.size())
	print("METRIC clips_active=%d" % (all.size() - INACTIVE_CLIPS.size()))


func _end() -> void:
	BendImpact.enabled_override = null
	SwayCaster.free_override = false
	RingRules.rule_set_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)
