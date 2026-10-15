extends SceneTree
## The game on a controller (PadInput; the owner, 2026-10-15: "make it controller friendly as well add controller support"),
## in the ring (a practice, earth, the standing dummy 5 m off, the hold style), the player's controls this machine's own
## (Input) and the pad's presses, sticks and triggers fed in as a pad sends them (Input.parse_input_event):
##   bound      the pad's buttons, sticks and triggers on the game's actions; the keys and the mouse kept beside them
##   device     a pad's press makes it the device, a key gives it back; the words then name its buttons (LT, RT, LB, X, Y)
##              and the strip's heads and jab chip follow; the aim help Strong unless chosen
##   keys       X readies key 1, Y key 2, RB the next skill
##   sticks     the left stick moves him (its lean, not all or nothing), the right turns the view
##   triggers   LT held: the readied skill aims while it fills, let go: it casts; RT held and let go: the jab
##   buttons    LB stands the guard; A jumps; B with the stick dashes
##   menu       B never opens the Esc menu; Start opens it and the D-pad walks its rows; nothing focused, the D-pad
##              focuses a button (PadInput._focus_first); Start closes it
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_pad_controls.gd
## The last line "PAD CONTROLS PASSED (<n> checks)" or "PAD CONTROLS FAILED (<f> of <n>)".

const OWN_CFG := "user://test_pad_controls.cfg"
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
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("PAD CONTROLS FAILED (watchdog)")
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


## A pad's button down or up, as a pad sends it.
func _btn(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)


## A pad's stick or trigger at `v`.
func _axis(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


## A pad's button pressed (down `s` s, then up).
func _tap(b: JoyButton, s := 0.08) -> void:
	_btn(b, true)
	await _secs(s)
	_btn(b, false)
	await _ticks(3)


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await _ticks(1)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _ticks(2)


func _has_pad(a: StringName) -> bool:
	for e in InputMap.action_get_events(a):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return true
	return false


func _has_other(a: StringName) -> bool:
	for e in InputMap.action_get_events(a):
		if e is InputEventKey or e is InputEventMouseButton:
			return true
	return false


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
		print("PAD CONTROLS FAILED (no ring)")
		quit(1)
		return
	p = mode.player
	root.size = Vector2i(1280, 720)
	await _ticks(2)
	p.ignore_mouse_capture = false
	c = SwayCaster.of(p)
	c.cast_released.connect(func(m: String, md: String) -> void: released.append([m, md, BendStatus.now()]))
	await _secs(0.5)

	# ---- bound: every action a pad's and still the keys' and the mouse's
	var acts: Array[StringName] = [&"jump", &"sprint", &"aim", &"fire", &"bend_guard", &"weapon_1", &"weapon_2", &"weapon_3",
			&"weapon_4", &"weapon_5", &"bend_swap", &"move_forward", &"move_left", &"look_left", &"look_up", &"bend_quick_bind"]
	var unbound: Array = []
	for a in acts:
		if not _has_pad(a) or (not String(a).begins_with("look") and not _has_other(a)):
			unbound.append(a)
	_expect(unbound.is_empty(), "the pad's buttons on the game's actions, the keys and the mouse kept (%s)" % [unbound])

	# ---- the device: a pad's press makes it; a key gives it back; the words follow
	await _key(KEY_K)
	var was := PadInput.active
	await _tap(JOY_BUTTON_RIGHT_STICK)
	var pad_on := PadInput.active
	_expect(not was and pad_on, "a key: the keyboard's; a pad's press: the pad's (%s, %s)" % [was, pad_on])
	var words := [KitWords.key(&"aim"), KitWords.key(&"fire"), KitWords.key(KitWords.GUARD_ACTION), KitWords.slot_key(0),
			KitWords.slot_key(1), KitWords.key(Hotbar.SWAP_ACTION)]
	_expect(words == ["LT", "RT", "LB", "X", "Y", "RB"], "the words name the pad's buttons (%s)" % [words])
	await _secs(0.3)
	var strip: BendStrip = null
	for n in root.find_children("*", "BendStrip", true, false):
		strip = n as BendStrip
	var col0 := strip.column(0) if strip != null else {}
	var jab_chip := strip.chip("jab") if strip != null else {}
	_expect(String(col0.get("head", "")).begins_with("X") and String(jab_chip.get("head", "")).begins_with("RT")
			and strip.help_line().contains("LT"),
			"the strip: key 1's head '%s', the jab's '%s', its help '%s'" % [col0.get("head", ""), jab_chip.get("head", ""),
			strip.help_line() if strip != null else "-"])
	_expect(MatchSetup.aim_help() == "strong", "the aim help Strong with a pad, none chosen (%s)" % MatchSetup.aim_help())

	# ---- keys: X key 1, Y key 2, RB the next
	await _tap(JOY_BUTTON_Y)
	var k2 := p.hotbar.readied_key()
	await _tap(JOY_BUTTON_X)
	var k1 := p.hotbar.readied_key()
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	var kn := p.hotbar.readied_key()
	await _tap(JOY_BUTTON_X)
	_expect(k2 == 1 and k1 == 0 and kn == 1, "Y readies key 2 (%d), X key 1 (%d), RB the next (%d)" % [k2 + 1, k1 + 1, kn + 1])

	# ---- sticks
	var at0 := p.global_position
	_axis(JOY_AXIS_LEFT_Y, -0.5)
	await _ticks(4)
	var half := p.controls.move_vector()
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _secs(0.6)
	var full := p.controls.move_vector()
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _secs(0.3)
	var went := (p.global_position - at0) * Vector3(1, 0, 1)
	_expect(half.length() > 0.2 and half.length() < 0.8 and full.length() > 0.95 and went.length() > 1.0,
			"the left stick moves him: half a lean %.2f, all of it %.2f, %.1f m gone" % [half.length(), full.length(), went.length()])
	var yaw0 := p.yaw
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _secs(0.5)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _ticks(3)
	var turned := rad_to_deg(absf(wrapf(p.yaw - yaw0, -PI, PI)))
	_expect(turned > 40.0, "the right stick turns the view: %.0f deg in half a second" % turned)
	var pitch0 := p.pitch
	_axis(JOY_AXIS_RIGHT_Y, -0.6)
	await _secs(0.3)
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await _ticks(3)
	_expect(absf(p.pitch - pitch0) > deg_to_rad(3.0), "and up and down (%.1f deg)" % rad_to_deg(absf(p.pitch - pitch0)))

	# ---- triggers: LT the readied skill, held and let go; RT the jab
	await _stage(5.0)
	p.hotbar.ready_move(0, "stone_form", "spike")
	await _ticks(3)
	released = []
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var locking := await _until(func() -> bool: return c.state == SwayCaster.State.LOCKING and c.lock_src == SwayCaster.SRC_AIM, 1.0)
	await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], 3.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	_expect(locking and not released.is_empty() and String(released[0][0]) == "stone_form",
			"LT held: the Spike aims while it fills; let go: it casts (%s)" % [released])
	await _idle()
	released = []
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], 2.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	var jab := Bending.jab("earth")
	_expect(not released.is_empty() and String(released[0][0]) == String(jab.id), "RT held and let go: the jab (%s)" % [released])

	# ---- buttons: LB the guard, A the jump, B with the stick the dash
	await _idle()
	await _secs(0.4)
	_btn(JOY_BUTTON_LEFT_SHOULDER, true)
	var guard := await _until(func() -> bool: return c.guard_up(), 1.0)
	_btn(JOY_BUTTON_LEFT_SHOULDER, false)
	await _secs(0.8)
	_expect(guard, "LB stands the guard")
	await _until(func() -> bool: return p.is_on_floor() and c.state == SwayCaster.State.IDLE, 2.0)
	await _secs(0.5)
	var y0 := p.global_position.y
	_btn(JOY_BUTTON_A, true)
	var rose := await _until(func() -> bool: return p.global_position.y > y0 + 0.4, 1.0)
	_btn(JOY_BUTTON_A, false)
	_expect(rose, "A jumps")
	await _until(func() -> bool: return p.is_on_floor(), 2.0)
	await _secs(0.6)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _ticks(3)
	_btn(JOY_BUTTON_B, true)
	var dashed := await _until(func() -> bool: return c.lock_src == SwayCaster.SRC_DASH and c.state != SwayCaster.State.IDLE, 1.0)
	_btn(JOY_BUTTON_B, false)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_expect(dashed, "B with the stick held: the dash (key 3's movement spell)")
	await _idle()
	await _secs(0.8)

	# ---- the menu: B never opens it, Start does, the D-pad walks it, Start closes it
	var menu := mode.menu as RingMenu
	await _tap(JOY_BUTTON_B)
	var b_opened := menu.is_open()
	_btn(JOY_BUTTON_START, true)
	await process_frame
	_btn(JOY_BUTTON_START, false)
	await _until(func() -> bool: return menu.is_open(), 1.0)
	for i in 6:
		await process_frame
	var f0 := root.gui_get_focus_owner()
	_btn(JOY_BUTTON_DPAD_DOWN, true)
	await process_frame
	_btn(JOY_BUTTON_DPAD_DOWN, false)
	for i in 3:
		await process_frame
	var f1 := root.gui_get_focus_owner()
	var opened := menu.is_open()
	root.gui_release_focus()
	_btn(JOY_BUTTON_DPAD_DOWN, true)
	await process_frame
	_btn(JOY_BUTTON_DPAD_DOWN, false)
	for i in 3:
		await process_frame
	var refocused := root.gui_get_focus_owner()
	_btn(JOY_BUTTON_START, true)
	await process_frame
	_btn(JOY_BUTTON_START, false)
	await _until(func() -> bool: return not menu.is_open(), 1.0)
	_expect(not b_opened and opened and f0 != null and f1 != null and f0 != f1 and not menu.is_open(),
			"B: no menu (%s); Start opens it (%s), the D-pad walks its rows (%s to %s), Start closes it (%s)" % [b_opened, opened,
			f0.name if f0 != null else "-", f1.name if f1 != null else "-", not menu.is_open()])
	_expect(refocused is BaseButton, "nothing focused on the menu: the D-pad focuses a button (%s)" % [
			refocused.name if refocused != null else "-"])

	if fails.is_empty():
		print("PAD CONTROLS PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("PAD CONTROLS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


## Both fighters `d` m apart on the deck's long axis, the player facing the dummy.
func _stage(d: float) -> void:
	await _idle()
	var g := RingMoves.arena_geo(mode.ring)
	var xf: Transform3D = g.xf
	var y := mode.ring.deck_y()
	var ax := (xf.basis.x * Vector3(1, 0, 1)).normalized()
	var mid := Vector3(xf.origin.x, y, xf.origin.z)
	RingLevel.place(mode.foe, Transform3D(Basis.looking_at(-ax, Vector3.UP), mid + ax * d * 0.5))
	RingLevel.place(p, Transform3D(Basis.looking_at(ax, Vector3.UP), mid - ax * d * 0.5))
	var want := (NpcSenses.chest_of(mode.foe) - p.camera.global_position).normalized()
	p.yaw = atan2(-want.x, -want.z)
	p.pitch = 0.0
	await _until(func() -> bool: return p.is_on_floor() and mode.foe.is_on_floor(), 2.0)
	await _ticks(20)
