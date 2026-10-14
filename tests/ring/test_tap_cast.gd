extends SceneTree
## The tap style (MatchSetup.cast_style "tap"; SwayCaster's tap layer, moves.json tap_cast; the owner, 2026-10-13: "would we
## break the game if cast time is the cooldown ... after each click it does a mini refresh like how wow does", then "we still
## have to click a number or highlight and ... click ... to launch it or hold it longer for its bigger cast"). In the ring (a
## practice, the standing dummy), fire, the readied skill on the right button through PlayerControls:
##   click      Punch readied, a click (down two frames) casts it after its wind-up (tap_cast.moves fire_blast/punch's), not
##              its old lock; its cooldown starts (SwayCaster.cooldown_left), the strip's chip shows it (BendStrip cd)
##   cooling    a click inside its cooldown, far from its end, casts nothing; one within queue_s of its end is kept and casts
##              as the cooldown ends
##   shared     another skill (the Kick) clicked just after the Punch waits for the shared cooldown (gcd_s), then casts
##   grow       Punch held on past its wind-up by grow_after_s grows: the cast is the Fireball (grown)
##   hold       the hold style: a click let go before the lock is full is called off (nothing cast), the lock is its own
##   bots       NpcBending.lock_for gives a ring bot the tap wind-up, and its cool after a cast at least the tap cooldown
##   a fall     drop_all clears every cooldown
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
	var tv := SwayCaster.tap_of("fire_blast", "punch")
	var gcd := SwayCaster.tap_num("gcd_s", 0.4)
	var queue := SwayCaster.tap_num("queue_s", 0.3)
	_expect(c.tap_on() and tv.size() == 2, "the tap style is on in the ring (Punch's numbers %s)" % [tv])
	await _secs(1.0)

	# ---- click
	await _ready_punch()
	released = []
	var t0 := BendStatus.now()
	await _click()
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	var took := float(released[0][2]) - t0 if not released.is_empty() else -1.0
	_expect(not released.is_empty() and String(released[0][0]) == "fire_blast" and took > 0.0 and took < float(tv[0]) + 0.2,
			"a click casts the Punch after its wind-up (%.2f s; its wind-up %.2f, its old lock %.2f)" % [took, float(tv[0]),
			float(SwayMoves.move("fire_blast").get("lock_s", 0.0))])
	var left := c.cooldown_left("fire_blast", "punch")
	_expect(left > float(tv[1]) - 0.3 and left <= float(tv[1]) + 0.01, "its cooldown runs (%.2f s of %.2f)" % [left, float(tv[1])])
	await _ticks(12)
	var strip := _strip()
	var cd_shown := _strip_cd(strip, 0)
	_expect(strip != null and cd_shown > 0.0 and cd_shown <= 1.0, "the strip's key 1 shows its cooldown (%.2f of it left)" % cd_shown)

	# ---- cooling: a click far from its end casts nothing; one within queue_s of its end is kept
	released = []
	await _click()
	await _secs(0.3)
	_expect(released.is_empty(), "a click in its cooldown, far from its end, casts nothing (%d)" % released.size())
	await _until(func() -> bool: return c.cooldown_left("fire_blast", "punch") <= queue * 0.6, 3.0)
	released = []
	var due := BendStatus.now() + c.cooldown_left("fire_blast", "punch")
	await _click()
	await _until(func() -> bool: return not released.is_empty(), 2.0)
	_expect(not released.is_empty() and float(released[0][2]) >= due - 0.02 and float(released[0][2]) <= due + float(tv[0]) + 0.25,
			"a click within queue_s of its end is kept and casts as it ends (%.2f s after its end)" % [
			(float(released[0][2]) - due) if not released.is_empty() else -1.0])

	# ---- shared: the Kick clicked just after waits out the shared cooldown
	await _until(func() -> bool: return c.cooldown_left("fire_blast", "punch") <= 0.0, 3.0)
	await _ready_punch()
	released = []
	await _click()
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	var punch_at := float(released[0][2]) if not released.is_empty() else -1.0
	p.hotbar.ready_move(1, "fire_kick", "kick")
	await _ticks(2)
	released = []
	p.controls.set_held(&"aim", true)
	await _until(func() -> bool: return not released.is_empty() or c.state == SwayCaster.State.FULL, 2.0)
	p.controls.set_held(&"aim", false)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	var kick_at := float(released[0][2]) if not released.is_empty() else -1.0
	_expect(not released.is_empty() and String(released[0][0]) == "fire_kick" and kick_at - punch_at >= gcd - 0.02,
			"another skill right after waits for the shared cooldown (the Kick %.2f s after the Punch; shared %.2f)" % [kick_at - punch_at, gcd])

	# ---- grow: Punch held on past its wind-up grows into the Fireball
	await _until(func() -> bool: return c.cooldown_left("fire_blast", "punch") <= 0.0 and c.state == SwayCaster.State.IDLE, 4.0)
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
			"held on past its wind-up, the Punch grows: the Fireball flies (grown %s, its radius %.2f)" % [grew,
			ball.radius if ball != null else -1.0])

	# ---- bots: the tap wind-up and cooldown
	var bot := mode.foe as NpcFighter
	var bl := NpcBending.lock_for("stone_form", "spike", "normal", 8.0, bot)
	var st := SwayCaster.tap_of("stone_form", "spike")
	_expect(bl < float(SwayMoves.move("stone_form").get("mode_lock_s", {}).get("spike", 1.1)) * 0.6 and bl >= float(st[0]) * 0.5,
			"a ring bot's Spike locks for the tap wind-up (%.2f s; tap %.2f)" % [bl, float(st[0])])

	# ---- a fall clears every cooldown
	await _ready_punch()
	await _click()
	await _until(func() -> bool: return c.cooldown_left("fire_blast", "punch") > 0.0, 1.5)
	c.drop_all()
	_expect(is_zero_approx(c.cooldown_left("fire_blast", "punch")), "a fall clears every cooldown")

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
