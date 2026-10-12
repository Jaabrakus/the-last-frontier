extends SceneTree
## The movement spells on Shift + a direction, no sprint in the ring (the owner, 2026-10-11: "those movement spells we keep it as
## shift and then hit a direction button it would be easier then hiting 3 right and then we can use 3 for a different move";
## picked: no sprint in the ring). Tidebreak's ring (scenes/ring.tscn, MatchSetup.incoming, fire against water, the foe
## held), the player's controls driven (PlayerControls.set_held, as a duel AI's):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_shift_moves.gd -- [rules=stock|zones]
##   the chord    Shift held, then a direction (W too: no sprint breaks it): key 3's movement spell (the crosshair on the foe too) (SwayCaster.last_key3 "dash"); a direction held, then
##                Shift: the same; Shift + W tapped and let go before the move goes: still forward (PlayerBendCaster.latch_move);
##                Shift alone, a direction alone, Shift + Space, the guard held + Shift + a direction: never key 3; in the air
##                Shift + a direction: the air dodge (last_key3 "dodge")
##   no sprint    Shift and W held 2 s: the run's speed (movement.json physics.run), never the old sprint's
##   the words    the strip's key 3 shows Shift; F1 says Shift + a direction dashes
## The last line "SHIFT MOVES PASSED (<n> checks)" or "SHIFT MOVES FAILED (<f> of <n>)".

const LIMIT_S := 150.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var c: SwayCaster
var ctl: PlayerControls
var rules := "stock"


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("SHIFT MOVES FAILED (watchdog)")
		quit(2))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("rules=") and a.substr(6) in ["stock", "zones"]:
			rules = a.substr(6)
	MatchSetup.set_match()
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	RingRules.rule_set_override = rules
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if fails.is_empty() and checks > 0:
		print("SHIFT MOVES PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("SHIFT MOVES FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


## Every key let go, the player landed and still on the deck again, the caster idle (the next case from rest: Fire's step
## carries him through the air a good second).
func _rest() -> void:
	ctl.release_all()
	await _ticks(20)
	await _until(_settled, 5.0)
	await _ticks(10)
	c.last_key3 = ""


## Both mid-deck again, the fight on and casting let back (a case's dash may carry him out: a new round's countdown holds
## casts, RingMode._hold_casts).
func _mid() -> void:
	var rm := RingMode.find(self)
	await _until(func() -> bool: return rm.phase == "FIGHT" and c.enabled, 10.0)
	var ar := RingArena.find(self)
	for e: Array in [[p, -3.0], [rm.foe, 3.0]]:
		var b: CharacterBody3D = e[0]
		if b != null:
			b.global_position = ar.center() + ar.axis() * float(e[1]) + Vector3.UP * 0.05
			b.velocity = Vector3.ZERO
	await _ticks(20)
	await _until(_settled, 5.0)


func _settled() -> bool:
	var rm := RingMoves.of(p)
	return not c.airborne() and p.is_on_floor() and c.state == SwayCaster.State.IDLE and (rm == null or rm.mode == "") \
			and Vector2(p.velocity.x, p.velocity.z).length() < 0.2


## Keys pressed in turn, `gap` physics frames apart (each held from its press), then held `hold` frames; key 3's word after.
func _press(keys: Array, gap := 2, hold := 4) -> String:
	await physics_frame
	for k: StringName in keys:
		ctl.set_held(k, true)
		await _ticks(gap)
	await _ticks(hold)
	return c.last_key3


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	var laid := await _until(func() -> bool: return p.arena_element == "fire" and p.hotbar.spell != "", 8.0)
	var rm := RingMode.find(self)
	var fight := await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
	_expect(laid and fight and RingRules.stock_on() and rm.rules.rule_set == rules,
			"fire's keys laid, the fight on, the new ring (%s)" % rm.rules.rule_set)
	if rm.foe != null:
		rm.foe.held = true
	ctl = PlayerControls.new(false)
	p.controls = ctl
	await _rest()
	# (the crosshair on the foe's chest, as in a fight: key 3's move still goes, by the keys held; the move reel, 2026-10-12)
	var foe := RingMode.find(self).foe
	var ar := RingArena.find(self)
	for e: Array in [[p, -3.0], [foe, 3.0]]:                 # (both mid-deck again: the cases above walked him to an edge)
		var b: CharacterBody3D = e[0]
		b.global_position = ar.center() + ar.axis() * float(e[1]) + Vector3.UP * 0.05
		b.velocity = Vector3.ZERO
	await _ticks(20)
	var pitch_sign := 1.0
	p.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-p.camera.global_basis.z).y > 0.0 else -1.0
	var aim := func() -> void:
		var d := (foe.global_position + Vector3.UP * 1.1 - p.camera.global_position).normalized()
		p.yaw = atan2(-d.x, -d.z)
		p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign
	for i in 12:
		aim.call()
		await physics_frame
	var x0 := p.global_position
	var on_foe: bool = c._query().get("node") == foe
	# (the crosshair kept on him through the press, as a player's mouse stays on his foe)
	ctl.set_held(&"sprint", true)
	for i in 2:
		aim.call()
		await physics_frame
	ctl.set_held(&"move_left", true)
	for i in 4:
		aim.call()
		await physics_frame
	var said_foe := c.last_key3
	var going := c.state != SwayCaster.State.IDLE or not c._dash.is_empty()
	await _ticks(30)
	var moved := Vector2(p.global_position.x - x0.x, p.global_position.z - x0.z).length()
	_expect(on_foe and said_foe == "dash" and going,
			"the crosshair on the foe, Shift + A: key 3's move still goes (on him %s, %s, %.1f m)" % [on_foe, said_foe, moved])
	await _rest()
	# ---- the chord, both orders
	_expect(await _press([&"sprint", &"move_left"]) == "dash", "Shift, then A: key 3's movement spell (%s)" % c.last_key3)
	await _rest()
	var lb0 := c.last_break
	_expect(await _press([&"sprint", &"move_forward"], 2, 8) == "dash" and c.last_break != "sprint",
			"Shift, then W: key 3's movement spell, never broken as a sprint (%s, last break %s)" % [c.last_key3, c.last_break])
	c.last_break = lb0
	await _rest()
	_expect(await _press([&"move_right", &"sprint"], 6) == "dash", "D held, then Shift: key 3's movement spell (%s)" % c.last_key3)
	await _rest()
	# ---- a tap: Shift + W let go before the move goes still goes forward (the way pressed is kept; the move reel's Skate)
	await _mid()
	var fw := BendCaster.of(p).facing()
	var t0 := p.global_position
	await physics_frame
	ctl.set_held(&"sprint", true)
	await _ticks(2)
	ctl.set_held(&"move_forward", true)
	await _ticks(2)
	ctl.release_all()
	var tapped := c.last_key3
	await _ticks(40)
	var ahead := (p.global_position - t0).dot(fw)
	_expect(tapped == "dash" and ahead > 1.0, "Shift + W tapped and let go: forward, the way pressed (%s, %.1f m ahead)" % [tapped, ahead])
	await _rest()

	# ---- never key 3
	_expect(await _press([&"sprint"], 2, 20) == "", "Shift alone: nothing (%s)" % c.last_key3)
	await _rest()
	_expect(await _press([&"move_forward"], 2, 20) == "", "W alone: nothing (%s)" % c.last_key3)
	await _rest()
	_expect(await _press([&"sprint", &"jump"], 1, 6) == "", "Shift + Space: no movement spell (%s)" % c.last_key3)
	await _rest()
	_expect(await _press([InputSetup.GUARD_ACTION, &"sprint", &"move_back"], 3, 6) == "",
			"the guard held + Shift + S: the guard's own Roll, not key 3 (%s)" % c.last_key3)
	await _rest()
	# ---- in the air: the air dodge
	ctl.set_held(&"jump", true)
	await _ticks(10)
	ctl.set_held(&"jump", false)
	var air := RingMoves.of(p) != null and RingMoves.of(p).airborne()
	var said := await _press([&"sprint", &"move_left"], 2, 3)
	_expect(air and said == "dodge", "in the air, Shift + A: the air dodge (airborne %s, %s)" % [air, said])
	await _rest()
	# ---- no sprint: Shift and W held 2 s (the dash it fires first is over by the end)
	await _press([&"move_forward", &"sprint"], 4, 0)
	await _ticks(120)
	var v := Vector2(p.velocity.x, p.velocity.z).length()
	var run := float((RingMoves.data().get("physics", {}) as Dictionary).get("run", 5.0))
	_expect(v <= run + 0.15, "Shift + W held: the run's %.2f m/s, no sprint (%.2f)" % [run, v])
	await _rest()
	# ---- the words
	var strip: Variant = p.hud.get(&"bend_strip") if p.hud != null else null
	var col: Dictionary = (strip as BendStrip).column(2) if strip is BendStrip else {}
	_expect(String(col.get("head", "")).begins_with(KitWords.key(&"sprint")), "the strip's key 3 reads Shift (%s)" % col.get("head", ""))
	var help := String(p.hud.call(&"help_text")) if p.hud != null else ""
	_expect(help.contains("Shift + a direction dash") and not help.contains("Shift sprint"), "F1: Shift + a direction dashes")
	_end()
