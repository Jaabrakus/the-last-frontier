extends SceneTree
## The combo controls on the ring's combo rules (BendCombo.link_on, jab_clicks; the owner, 2026-10-15: "we can click a button
## and trigger combos faster", picked both: the combo window and jab strings by clicks). In the ring (a practice, earth, the
## standing dummy 4 m off, the crosshair kept on his chest, the hold style), the player's buttons through PlayerControls and
## the caster's quick_override:
##   jab click   a 0.1 s click of the jab button casts the jab (its lock runs on; before 2026-10-15 a click was called off)
##   window      the jab landing opens the combo window (BendCombo.link_on)
##   link        the Spike clicked inside it: a link (a third of its cast time: its lock against the Spike's held one), cast
##               on the click; the window spent
##   lapsed      the Spike clicked after the window: called off, nothing cast (hold to cast outside a combo)
##   hold        the Spike held: its own cast time, cast as ever
##   string      three jab clicks, each as soon as the last has left the hand, landing: the third is the Pop
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_combo_controls.gd
## The last line "COMBO CONTROLS PASSED (<n> checks)" or "COMBO CONTROLS FAILED (<f> of <n>)".

const OWN_CFG := "user://test_combo_controls.cfg"
var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var checks := 0
var fails: Array[String] = []
var released: Array = []
var aiming := false


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
	MatchSetup._cast_style = "hold"
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.difficulty = "normal"
	MatchSetup.light = "noon"
	MatchSetup.speed = 1.0
	MatchSetup.fresh = true
	MatchSetup.my_pct = -1.0
	MatchSetup.foe_pct = -1.0
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	BendCombo.enabled = true
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("COMBO CONTROLS FAILED (watchdog)")
		quit(2))
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(ceil(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, seconds: float) -> bool:
	for i in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _stage(d: float) -> void:
	aiming = false
	var g := RingMoves.arena_geo(mode.ring)
	var xf: Transform3D = g.xf
	var y := mode.ring.deck_y()
	var ax := (xf.basis.x * Vector3(1, 0, 1)).normalized()
	var mid := Vector3(xf.origin.x, y, xf.origin.z)
	RingLevel.place(mode.foe, Transform3D(Basis.looking_at(-ax, Vector3.UP), mid + ax * d * 0.5))
	RingLevel.place(p, Transform3D(Basis.looking_at(ax, Vector3.UP), mid - ax * d * 0.5))
	mode.rules.reset_pct(mode.foe, 0.0)
	mode.make_whole(mode.foe)
	mode.make_whole(p)
	BendCombo.reset(p)
	aiming = true
	await _until(func() -> bool: return p.is_on_floor() and mode.foe.is_on_floor(), 2.0)
	await _ticks(30)


func _aim() -> void:
	if aiming and p != null and is_instance_valid(mode.foe):
		var cam := p.camera
		var want := (NpcSenses.chest_of(mode.foe) - cam.global_position).normalized()
		var fwd := -cam.global_basis.z
		var dy := wrapf(atan2(-want.x, -want.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
		var dp := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(fwd.y, -1.0, 1.0))
		p.yaw += dy
		p.pitch = clampf(p.pitch + dp, -deg_to_rad(p.pitch_limit_deg), deg_to_rad(p.pitch_limit_deg))


## A click of the jab button (down 0.1 s).
func _jab_click() -> void:
	c.quick_override = true
	await _secs(0.1)
	c.quick_override = false


## A click of the aim button (down 0.1 s).
func _aim_click() -> void:
	p.controls.set_held(&"aim", true)
	await _secs(0.1)
	p.controls.set_held(&"aim", false)


func _idle() -> void:
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 4.0)
	await _ticks(3)


func _run() -> void:
	for i in 1800:
		await process_frame
		mode = RingMode.find(self)
		if mode != null and mode.foe != null and mode.phase == "FIGHT" and not current_scene.get_meta("loading_hold", false):
			break
	if mode == null:
		print("COMBO CONTROLS FAILED (no ring)")
		quit(1)
		return
	p = mode.player
	root.size = Vector2i(1280, 720)
	await _ticks(2)
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	c = SwayCaster.of(p)
	c.cast_released.connect(func(m: String, md: String) -> void: released.append([m, md, BendStatus.now()]))
	physics_frame.connect(_aim)
	var jab := Bending.jab("earth")
	var bc := BendCaster.of(p)
	_expect(BendCombo.on() and BendCombo.jab_clicks() and String(jab.get("id", "")) != "", "the combo rules are on, the jab clicks (%s)" % [jab])
	await _stage(4.0)

	# ---- the jab string: three clicks that land, the third the Pop
	await _secs(1.0)
	# (clicked as a player strings them: the next click as soon as the last jab has left the hand, not after it lands, so each
	# lands while the one before still holds him; RingRules' string ends when he recovers, and the jab string with it)
	var n_hits: Array = []
	released = []
	for k in 3:
		var casts := released.size()
		await _jab_click()
		await _until(func() -> bool: return released.size() > casts, 1.5)
		n_hits.append(int(bc.jab.get("hits", 0)))
	await _until(func() -> bool: return bool(bc.jab.get("popped", false)), 1.5)
	var popped := bool(bc.jab.get("popped", false))
	_expect(popped and released.size() >= 3, "three jab clicks that land: the third is the Pop (%d jabs, hits as each left %s)" % [
			released.size(), n_hits])

	# (the Pop's stone out of his hand, the string and its window lapsed, before the window's checks)
	await _idle()
	var held := BendZone.held_stone(p)
	if held != null and is_instance_valid(held):
		held.queue_free()
	await _stage(4.0)
	await _secs(1.2)

	# ---- a jab on a click, its hit opens the window
	released = []
	var hits0 := int(bc.jab.get("hits", 0))
	await _jab_click()
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	_expect(not released.is_empty() and String(released[0][0]) == String(jab.id),
			"a 0.1 s click of the jab button casts the jab (%s; last break '%s')" % [released, c.last_break])
	var landed := await _until(func() -> bool: return BendCombo.link_on(p), 1.5)
	_expect(landed, "the jab landing opens the combo window (hits %d -> %d)" % [hits0, int(bc.jab.get("hits", 0))])

	# ---- the Spike clicked inside the window: a link, cast on the click
	p.hotbar.ready_move(0, "stone_form", "spike")
	released = []
	var t0 := BendStatus.now()
	await _aim_click()
	var linked := c._link
	var link_lock := c.lock_s
	_expect(linked and not BendCombo.link_on(p), "the Spike clicked inside it is a link, the window spent (link %s)" % linked)
	await _until(func() -> bool: return not released.is_empty(), 2.0)
	var took := (float(released[0][2]) - t0) if not released.is_empty() else -1.0
	_expect(not released.is_empty() and String(released[0][0]) == "stone_form", "the link casts on the click (%.2f s)" % took)

	# ---- after the window: a click calls it off
	await _idle()
	await _secs(1.2)
	released = []
	await _aim_click()
	await _secs(0.8)
	_expect(released.is_empty() and c.last_break == "let go",
			"the Spike clicked after the window: called off, nothing cast (%d, '%s')" % [released.size(), c.last_break])

	# ---- held: its own cast time
	await _idle()
	await _secs(0.6)
	p.controls.set_held(&"aim", true)
	await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	var held_lock := c.lock_s
	await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], 3.0)
	released = []
	p.controls.set_held(&"aim", false)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	_expect(not released.is_empty() and held_lock > 0.0 and absf(link_lock / held_lock - BendCombo.link_share()) < 0.03,
			"held, the Spike takes its own cast time (%.2f s); the link took %.2f of it (%.2f s)" % [held_lock,
			link_lock / maxf(held_lock, 0.001), link_lock])

	if fails.is_empty():
		print("COMBO CONTROLS PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("COMBO CONTROLS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
