extends SceneTree
## The tap style (MatchSetup.cast_style "tap"; SwayCaster's tap layer, moves.json tap_cast; the owner, 2026-10-13: "we still
## have to click a number or highlight and ... click ... to launch it or hold it longer for its bigger cast"; 2026-10-14: "we
## need the cast times back", "meaning no more cooldowns"). In the ring (a practice, the standing dummy), fire, the readied
## skill on the right button through PlayerControls:
##   click      Punch readied, a click (down two frames) casts it once its own cast time is up (its lock, not the old short
##              wind-up); no cooldown after it (SwayCaster.tap_cooldowns off; cooldown_left 0, the strip's chip clear)
##   again      clicked again at once: it casts again after its cast time (nothing to wait out)
##   other      another skill (the Kick) clicked just after the Punch casts after its own cast time (no shared cooldown)
##   grow       Punch held on past its cast time by grow_after_s grows: the cast is the Fireball (grown)
##   hold       the hold style: a click let go before the lock is full is called off (nothing cast), the lock is its own
##   bots       NpcBending.lock_for gives a ring bot the Spike's own cast time
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_tap_cast.gd
## The last line "TAP CAST PASSED (<n> checks)" or "TAP CAST FAILED (<f> of <n>)".

const OWN_CFG := "user://test_tap_cast.cfg"
var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var checks := 0
var fails: Array[String] = []
var released: Array = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _initialize() -> void:
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._scheme = "keys"
	MatchSetup._aim_help = "light"
	MatchSetup._cast_style = "tap"
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = "fire"
	MatchSetup.foes = ["earth"]
	MatchSetup.difficulty = "normal"
	MatchSetup.light = "noon"
	MatchSetup.speed = 1.0
	MatchSetup.fresh = true
	MatchSetup.my_pct = -1.0
	MatchSetup.foe_pct = -1.0
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	BendCombo.enabled = false
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("TAP CAST FAILED (watchdog)")
		quit(2))
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, seconds: float) -> bool:
	for i in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _key(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _ticks(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await _ticks(4)


## A click of the right button (down two frames).
func _click() -> void:
	p.controls.set_held(&"aim", true)
	await _ticks(2)
	p.controls.set_held(&"aim", false)


func _ready_punch() -> void:
	p.hotbar.ready_move(0, "fire_blast", "punch")
	await _ticks(3)


func _run() -> void:
	for i in 1800:
		await process_frame
		mode = RingMode.find(self)
		if mode != null and mode.foe != null and mode.phase == "FIGHT" and not current_scene.get_meta("loading_hold", false):
			break
	if mode == null:
		print("TAP CAST FAILED (no ring)")
		quit(1)
		return
	p = mode.player
	root.size = Vector2i(1280, 720)
	await _ticks(2)
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	c = SwayCaster.of(p)
	c.cast_released.connect(func(m: String, md: String) -> void: released.append([m, md, BendStatus.now(), c.grown]))
	var lock := float(SwayMoves.move("fire_blast").get("lock_s", 0.35))
	var tv := SwayCaster.tap_of("fire_blast", "punch")
	_expect(c.tap_on() and not SwayCaster.tap_cooldowns(), "the tap style is on in the ring, its cooldowns off")
	await _secs(1.0)

	# ---- click: its own cast time, no cooldown
	await _ready_punch()
	released = []
	var t0 := BendStatus.now()
	await _click()
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	var took := float(released[0][2]) - t0 if not released.is_empty() else -1.0
	_expect(not released.is_empty() and String(released[0][0]) == "fire_blast" and took >= lock * 0.8 and took < lock + 0.25,
			"a click casts the Punch once its cast time is up (%.2f s; its cast time %.2f, the old short wind-up %.2f)" % [took,
			lock, float(tv[0]) if tv.size() >= 1 else -1.0])
	_expect(is_zero_approx(c.cooldown_left("fire_blast", "punch")), "no cooldown after it (%.2f s)" % c.cooldown_left("fire_blast", "punch"))
	await _ticks(12)
	var strip := _strip()
	var cd_shown := _strip_cd(strip, 0)
	_expect(strip != null and is_zero_approx(cd_shown), "the strip's key 1 shows no cooldown (%.2f)" % cd_shown)

	# ---- again at once: nothing to wait out
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	await _ready_punch()
	released = []
	var a0 := BendStatus.now()
	await _click()
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	var again := float(released[0][2]) - a0 if not released.is_empty() else -1.0
	_expect(not released.is_empty() and again < lock + 0.25, "clicked again at once, it casts again after its cast time (%.2f s)" % again)

	# ---- another skill just after: its own cast time, no shared cooldown
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	p.hotbar.ready_move(1, "fire_kick", "kick")
	await _ticks(2)
	released = []
	var k0 := BendStatus.now()
	await _click()
	await _until(func() -> bool: return not released.is_empty(), 2.0)
	var kick_lock := float((SwayMoves.move("fire_kick").get("mode_lock_s", {}) as Dictionary).get("kick", SwayMoves.move("fire_kick").get("lock_s", 0.6)))
	var kick_took := float(released[0][2]) - k0 if not released.is_empty() else -1.0
	_expect(not released.is_empty() and String(released[0][0]) == "fire_kick" and kick_took < kick_lock + 0.25,
			"the Kick right after casts after its own cast time (%.2f s; its cast time %.2f): no shared cooldown" % [kick_took, kick_lock])

	# ---- grow: Punch held on past its cast time grows into the Fireball
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 4.0)
	await _ready_punch()
	released = []
	var known := {}
	for n in get_nodes_in_group(BendBolt.GROUP):
		known[n.get_instance_id()] = true
	p.controls.set_held(&"aim", true)
	var grew := await _until(func() -> bool: return c.grown, 3.0)
	await _ticks(3)
	p.controls.set_held(&"aim", false)
	var ball: BendBolt = null
	for k in 90:
		await physics_frame
		for n in get_nodes_in_group(BendBolt.GROUP):
			var b := n as BendBolt
			if b != null and not known.has(b.get_instance_id()) and b.caster == p:
				ball = b
		if ball != null:
			break
	var grow_r := float((SwayMoves.move("fire_blast").bend.punch.grow as Dictionary).get("radius_m", 0.5))
	_expect(grew and not released.is_empty() and ball != null and ball.radius >= grow_r - 0.01,
			"held on past its cast time, the Punch grows: the Fireball flies (grown %s, its radius %.2f)" % [grew,
			ball.radius if ball != null else -1.0])

	# ---- bots: their own cast times
	var bot := mode.foe as NpcFighter
	var bl := NpcBending.lock_for("stone_form", "spike", "normal", 8.0, bot)
	var spike_lock := float(SwayMoves.move("stone_form").get("mode_lock_s", {}).get("spike", 1.1))
	_expect(bl >= spike_lock * 0.6, "a ring bot's Spike takes its own cast time (%.2f s; the Spike's %.2f)" % [bl, spike_lock])

	# ---- hold: a click let go before full is called off, the lock its own
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	MatchSetup._cast_style = "hold"
	await _ready_punch()
	released = []
	await _click()
	await _secs(0.8)
	_expect(released.is_empty() and not c.tap_on(), "the hold style: a click let go before full casts nothing (%d)" % released.size())
	p.controls.set_held(&"aim", true)
	var h0 := BendStatus.now()
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	var lock_took := BendStatus.now() - h0
	p.controls.set_held(&"aim", false)
	_expect(lock_took >= float(SwayMoves.move("fire_blast").get("lock_s", 0.35)) * 0.8,
			"the hold style's lock is the Punch's own (%.2f s)" % lock_took)
	MatchSetup._cast_style = "tap"

	if fails.is_empty():
		print("TAP CAST PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("TAP CAST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _strip() -> BendStrip:
	for n in root.find_children("*", "BendStrip", true, false):
		return n as BendStrip
	return null


func _strip_cd(s: BendStrip, i: int) -> float:
	if s == null or s._cols.size() <= i:
		return -1.0
	return float((s._cols[i] as Dictionary).get("cd", 0.0))
