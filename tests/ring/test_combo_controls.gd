extends SceneTree
## The combo rules on the ring (BendCombo; the owner, 2026-10-15: "we can click a button and trigger combos faster", the combo
## window; then, after playing the jab string, "to easy to spam", "people can just get close to the user", "chains are good if
## you land and attack", picked: a hit worth its cast time, no repeats in a chain, a full meter's finisher, the rusher
## answered). In the ring (a practice, earth, the standing fire dummy 4 m off, the crosshair kept on his chest, the hold
## style), the player's buttons through PlayerControls and the caster's quick_override:
##   jab        a 0.1 s click of the jab button: called off (no jab click: held to cast as every skill); held: it casts, and
##              landing it fills combo.jab_worth and opens the window
##   link       the Spike clicked inside the window: a link (link_share of its cast time), cast on the click; landing it fills
##              its worth (its cast time over stack_s)
##   repeat     the Spike again in the same chain: no link (a click called off), held it casts, landing it fills half its
##              worth (combo.repeat_k; the owner, 2026-10-15: two Spikes "doesnt stack", picked "repeats add half") and opens
##              the window
##   finisher   a full combo: the Spike's hit launches as the Pop does (the Pop's set launch, its own tag) and the combo is
##              spent; the jab at full is the Pop (its pose, its tag)
##   rusher     the fire dummy's jab taken on the beat by the player's guard from 4 m: the dummy knocked back, the player's
##              window open
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_combo_controls.gd
## The last line "COMBO CONTROLS PASSED (<n> checks)" or "COMBO CONTROLS FAILED (<f> of <n>)".

const OWN_CFG := "user://test_combo_controls.cfg"
var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var checks := 0
var fails: Array[String] = []
var released: Array = []
## The ring's launches by the player on the dummy ([sv, stun, tag, at]).
var hits: Array = []
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


## Both fighters `d` m apart on the deck's long axis, whole, at 0%, both combos empty, no stone of his loose or in his hand.
func _stage(d: float) -> void:
	aiming = false
	await _idle()
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
	for st in FormStone.loose_of(p):
		if is_instance_valid(st):
			st.queue_free()
	var held := BendZone.held_stone(p)
	if held != null and is_instance_valid(held):
		held.queue_free()
	aiming = true
	await _until(func() -> bool: return p.is_on_floor() and mode.foe.is_on_floor(), 2.0)
	await _ticks(30)
	BendCombo.reset(p)
	BendCombo.reset(mode.foe)


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


## The jab held to cast: down until its lock is full, then let go.
func _jab_held() -> void:
	c.quick_override = true
	await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], 2.0)
	await _ticks(2)
	c.quick_override = false


## A click of the aim button (down 0.1 s).
func _aim_click() -> void:
	p.controls.set_held(&"aim", true)
	await _secs(0.1)
	p.controls.set_held(&"aim", false)


## The readied skill held to cast: the aim button down until its lock is full, then let go.
func _aim_held() -> void:
	p.controls.set_held(&"aim", true)
	await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], 3.0)
	await _ticks(2)
	p.controls.set_held(&"aim", false)


func _idle() -> void:
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 4.0)
	await _ticks(3)


## Waits for the player's next hit on the dummy (the ring's launch of it): the hit ([sv, stun, tag, at]) or [] none.
func _next_hit(seconds := 2.0) -> Array:
	var n := hits.size()
	await _until(func() -> bool: return hits.size() > n, seconds)
	return hits[n] if hits.size() > n else []


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
	mode.rules.launched.connect(func(n: Node, sv: Vector3, stun: float, by: Node, tag: String) -> void:
		if n == mode.foe and by == p:
			hits.append([sv, stun, tag, BendStatus.now()]))
	physics_frame.connect(_aim)
	var jab := Bending.jab("earth")
	var jab_w := BendCombo.worth({"jab": true})
	var spike_w := BendCombo.worth({"move": "stone_form", "mode": "spike"})
	_expect(BendCombo.on() and BendCombo.finishers() and jab_w < 0.5 and spike_w > 1.5,
			"the combo rules on, finishers on; a jab worth %.2f, the Spike %.2f" % [jab_w, spike_w])
	await _stage(4.0)
	await _secs(1.0)

	# ---- the jab: a click called off, held it casts; landing it fills a sliver and opens the window
	released = []
	await _jab_click()
	await _secs(0.8)
	_expect(released.is_empty() and c.last_break == "let go",
			"a 0.1 s click of the jab: called off, nothing cast (%d, '%s')" % [released.size(), c.last_break])
	await _idle()
	await _jab_held()
	var h0 := await _next_hit()
	_expect(not h0.is_empty() and absf(BendCombo.level(p) - jab_w) < 0.05 and BendCombo.link_on(p),
			"the jab held casts; landing it fills %.2f (its worth %.2f) and opens the window (%s)" % [BendCombo.level(p), jab_w,
			BendCombo.link_on(p)])

	# ---- the Spike clicked inside it: a link, cast on the click; landing it fills its worth
	p.hotbar.ready_move(0, "stone_form", "spike")
	released = []
	var lv0 := BendCombo.level(p)
	await _aim_click()
	var linked := c._link
	var link_lock := c.lock_s
	var h1 := await _next_hit()
	var lv1 := BendCombo.level(p)
	_expect(linked and not h1.is_empty() and absf(lv1 - lv0 - spike_w) < 0.08,
			"the Spike clicked in the window: a link (%s, %.2f s), it lands and fills %.2f (its worth %.2f)" % [linked, link_lock,
			lv1 - lv0, spike_w])
	_expect(BendCombo.in_chain(p, "stone_form", "spike") and BendCombo.chain(p).size() == 2,
			"the chain: the jab and the Spike (%s)" % [BendCombo.chain(p)])

	# ---- the Spike again in the same chain: no link; it fills half its worth and opens the window
	await _idle()
	released = []
	await _aim_click()
	var again_link := c._link
	await _secs(0.6)
	_expect(not again_link and released.is_empty(), "the Spike again in the chain: no link, its click called off (%s, %d)" % [
			again_link, released.size()])
	await _idle()
	var nh := hits.size()
	var before := [BendCombo.level(p)]
	await _aim_held()
	await _until(func() -> bool:
		if hits.size() > nh:
			return true
		before[0] = BendCombo.level(p)
		return false, 2.0)
	var lv3 := BendCombo.level(p)
	var half := spike_w * float(RingRules.stock_block("combo").get("repeat_k", 0.5))
	_expect(hits.size() > nh and absf(lv3 - float(before[0]) - half) < 0.05 and BendCombo.link_on(p),
			"held, it casts and lands, filling %.2f (half its worth: %.2f) and opening the window (%s)" % [lv3 - float(before[0]), half,
			BendCombo.link_on(p)])

	# ---- the finisher: a full combo's next hit launches as the Pop does, the combo spent
	await _stage(4.0)
	await _secs(0.6)
	p.hotbar.ready_move(0, "stone_form", "spike")
	BendCombo.gain(p, 5.0)
	_expect(BendCombo.finisher_ready(p), "a full combo: the finisher ready (%.2f)" % BendCombo.level(p))
	await _aim_held()
	var h3 := await _next_hit()
	var pop_mps := float(BendR3.block("pop").get("set_mps", 9.0))
	var sv3: Vector3 = h3[0] if not h3.is_empty() else Vector3.ZERO
	_expect(not h3.is_empty() and String(h3[2]) == "stone_form/spike" and absf(sv3.length() - pop_mps) < 1.0 and sv3.y > pop_mps * 0.9
			and is_zero_approx(BendCombo.level(p)) and not BendCombo.link_on(p),
			"its Spike lands as the finisher: the Pop's launch (%.1f m/s, %.1f up), its own tag (%s), the combo spent (%.2f)" % [
			sv3.length(), sv3.y, String(h3[2]) if not h3.is_empty() else "-", BendCombo.level(p)])

	# ---- the jab at full: the Pop
	await _stage(4.0)
	await _secs(0.6)
	BendCombo.gain(p, 5.0)
	c.quick_override = true
	await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	var popped := c._form_mode == "pop"
	await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], 2.0)
	await _ticks(2)
	c.quick_override = false
	var h4 := await _next_hit()
	_expect(popped and not h4.is_empty() and String(h4[2]) == String(BendR3.block("pop").get("tag", "jab/pop"))
			and is_zero_approx(BendCombo.level(p)),
			"the jab at full: the Pop (its pose %s, its tag %s), the combo spent" % [popped, String(h4[2]) if not h4.is_empty() else "-"])

	# ---- the rusher answered: the dummy's jab taken on the beat from 4 m
	await _stage(4.0)
	await _secs(0.6)
	var fbc := BendCaster.of(mode.foe) as BodyBendCaster
	fbc.scatter_deg = 0.0
	fbc.lead = 0.0
	fbc.target = p
	var gspec: Dictionary = (SwayMoves.move("stone_catch").bend as Dictionary)["catch"]
	var z := BendZone.make(p, "catch", p.global_position, gspec, BendCaster.of(p).facing())
	var gap0 := (mode.foe.global_position - p.global_position).length()
	BendCast.cast(fbc, String(Bending.jab("fire").id), String(Bending.jab("fire").mode))
	var opened := await _until(func() -> bool: return BendCombo.link_on(p), 1.0)
	await _secs(0.5)
	var gap1 := (mode.foe.global_position - p.global_position).length()
	_expect(z.results.has("perfect") and opened and gap1 > gap0 + 1.0,
			"the dummy's jab guarded on the beat from %.1f m: the player's window open (%s), the dummy knocked back to %.1f m (%s)" % [
			gap0, opened, gap1, z.results])

	if fails.is_empty():
		print("COMBO CONTROLS PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("COMBO CONTROLS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
