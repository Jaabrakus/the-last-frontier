extends SceneTree
## The touch layer under the tap style (TouchControls; the owner, 2026-10-13: drag aims, hold grows, the tag changes the
## skill, "for touch it should be hold and release right?"; 2026-10-14: "only hold and release cast"). In the ring (fire, a
## practice, the standing dummy), the layer made by hand and forced up (force_up), its touches fed straight in:
##   tap        key 1 tapped (down, up two frames on): nothing cast, no cooldown, the caster idle, the Punch readied
##   firm       key 1 held 0.2 s (inside TAP_S, past the Punch's 0.15 s wind-up: its ring full) and let go: it casts; its
##              cooldown runs
##   short      Lightning on key 1 held 0.3 s (past TAP_S, inside its 0.5 s wind-up) and let go: it casts as the wind-up ends
##   hold       key 1 held still past its wind-up: it grows (the Fireball); let go: it casts
##   drag       key 1 held and the finger dragged past DRAG_PX: the view turns; let go away from it: it casts
##   back       dragged out and back onto key 1, let go there: called off, nothing cast, no cooldown
##   tag        key 1's tag names its other skill (Lightning); tapped: key 1 is Lightning, nothing cast
##   jab        the jab held 1.5 s: volley after volley (the tap style's held jab)
##   words      the strip's help line in the thumbs' words (never "(no key)": the mouse's buttons are off), no Q line; the
##              tag's word whole (its type made to fit, not cut)
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_touch_cast.gd
## The last line "TOUCH CAST PASSED (<n> checks)" or "TOUCH CAST FAILED (<f> of <n>)".

const OWN_CFG := "user://test_touch_cast.cfg"
var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var t: TouchControls
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
		print("TOUCH CAST FAILED (watchdog)")
		quit(2))
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, seconds: float) -> bool:
	for i in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _key_b(k: int) -> Dictionary:
	for b: Dictionary in t._buttons():
		if b.has("key") and int(b.key) == k:
			return b
	return {}


func _jab_b() -> Dictionary:
	for b: Dictionary in t._buttons():
		if String(b.id) == "jab":
			return b
	return {}


## `s` seconds of physics frames (the project's physics_ticks_per_second).
func _secs(s: float) -> void:
	await _ticks(int(ceil(s * Engine.physics_ticks_per_second)))


func _ready_for_next() -> void:
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE and c.cooldown_left("fire_blast", "punch") <= 0.0, 4.0)
	await _ticks(5)


func _run() -> void:
	for i in 1800:
		await process_frame
		mode = RingMode.find(self)
		if mode != null and mode.foe != null and mode.phase == "FIGHT" and not current_scene.get_meta("loading_hold", false):
			break
	if mode == null:
		print("TOUCH CAST FAILED (no ring)")
		quit(1)
		return
	p = mode.player
	root.size = Vector2i(1280, 720)
	await _ticks(2)
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	c.cast_released.connect(func(m: String, md: String) -> void: released.append([m, md, BendStatus.now()]))
	t = TouchControls.new()
	t.name = "TouchControls"
	t.player = p
	t.force_up = true
	p.add_child(t)
	await _ticks(3)
	_expect(t._active and TouchControls.up(p), "the touch layer is up (forced)")
	p.hotbar.ready_move(0, "fire_blast", "punch")
	await _ticks(3)
	var k1 := _key_b(0)
	var at: Vector2 = k1.at
	var drag := t._pad.size.y * TouchControls.DRAG_PX * 4.0

	# ---- tap: nothing cast (only a hold and let go casts)
	released = []
	var col1 := t._key_column(1)
	p.hotbar.ready_move(1, String(col1.get("id", "")), String(col1.get("mode", "")))   # (key 2 first: the tap readies key 1)
	await _ticks(3)
	var before := bool(t._key_column(0).get("readied", false))
	t._down(0, at)
	await _ticks(2)
	t._up(0, at)
	await _ticks(60)
	var col0 := t._key_column(0)
	_expect(released.is_empty() and c.state == SwayCaster.State.IDLE and is_zero_approx(c.cooldown_left("fire_blast", "punch"))
			and not before and bool(col0.get("readied", false)) and String(col0.get("id", "")) == "fire_blast",
			"a tap on key 1: nothing cast (%d), no cooldown (%.2f s), the caster idle (%s), the Punch readied (%s, was %s)" % [
			released.size(), c.cooldown_left("fire_blast", "punch"), SwayCaster.State.keys()[c.state], col0.get("readied", false),
			before])

	# ---- a firm press: inside TAP_S but past the Punch's wind-up (its ring full): it casts
	await _ready_for_next()
	released = []
	t._down(0, at)
	await _secs(0.2)
	var was_full := c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING]
	t._up(0, at)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	_expect(was_full and not released.is_empty() and String(released[0][0]) == "fire_blast",
			"key 1 held 0.2 s, its ring full (%s), let go: the Punch casts (%s)" % [was_full,
			released[0] if not released.is_empty() else "-"])
	_expect(c.cooldown_left("fire_blast", "punch") > 0.5, "its cooldown runs (%.2f s)" % c.cooldown_left("fire_blast", "punch"))

	# ---- held past a tap, let go before its wind-up is full (Lightning's 0.5 s): it runs on and casts
	await _ready_for_next()
	p.hotbar.ready_move(0, "fire_arc", "lightning")
	await _ticks(3)
	released = []
	t._down(0, at)
	await _secs(0.3)
	var mid := c.state == SwayCaster.State.LOCKING and c.move == "fire_arc"
	t._up(0, at)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	_expect(mid and not released.is_empty() and String(released[0][0]) == "fire_arc",
			"Lightning held 0.3 s, let go mid wind-up (%s): it casts as the wind-up ends (%s)" % [mid,
			released[0] if not released.is_empty() else "-"])
	p.hotbar.ready_move(0, "fire_blast", "punch")
	await _ticks(3)

	# ---- hold and let go
	await _ready_for_next()
	released = []
	t._down(0, at)
	var grew := await _until(func() -> bool: return c.grown, 3.0)
	await _ticks(3)
	t._up(0, at)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	_expect(grew and not released.is_empty() and String(released[0][0]) == "fire_blast",
			"key 1 held still grows it (%s: the Fireball) and its let go casts it" % grew)

	# ---- drag aims, let go away casts
	await _ready_for_next()
	released = []
	var yaw0 := p.yaw
	t._down(0, at)
	await _ticks(2)
	t._drag(0, at + Vector2(-drag, 0.0), Vector2(-drag, 0.0))
	await _ticks(2)
	var turned := absf(wrapf(p.yaw - yaw0, -PI, PI))
	t._up(0, at + Vector2(-drag, 0.0))
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	_expect(turned > 0.01 and not released.is_empty(), "a drag from key 1 turns the view (%.1f deg) and its let go casts" % rad_to_deg(turned))

	# ---- dragged back onto it: called off
	await _ready_for_next()
	released = []
	t._down(0, at)
	await _ticks(2)
	t._drag(0, at + Vector2(-drag, 0.0), Vector2(-drag, 0.0))
	await _ticks(2)
	t._drag(0, at, Vector2(drag, 0.0))
	await _ticks(2)
	t._up(0, at)
	await _ticks(40)
	_expect(released.is_empty() and c.state == SwayCaster.State.IDLE and is_zero_approx(c.cooldown_left("fire_blast", "punch")),
			"dragged back onto key 1 and let go there: called off, nothing cast, no cooldown (%d)" % released.size())

	# ---- the tag
	var tag := t._tag(_key_b(0))
	_expect(not tag.is_empty() and String((tag.other as Dictionary).id) == "fire_arc",
			"key 1's tag names its other skill (%s)" % (String((tag.other as Dictionary).id) if not tag.is_empty() else "-"))
	if not tag.is_empty():
		released = []
		t._down(1, tag.at)
		await _ticks(2)
		t._up(1, tag.at)
		await _ticks(8)
		var col := t._key_column(0)
		_expect(String(col.get("id", "")) == "fire_arc" and released.is_empty(),
				"tapped: key 1 is Lightning now, nothing cast (%s, %d)" % [col.get("id", ""), released.size()])
		p.hotbar.ready_move(0, "fire_blast", "punch")
		await _ticks(3)

	# ---- the jab held fires again and again
	await _ready_for_next()
	released = []
	var jb := _jab_b()
	t._down(2, jb.at)
	await _secs(1.5)
	t._up(2, jb.at)
	await _ticks(30)
	var jabs := released.filter(func(r: Array) -> bool: return String(r[0]) == "fire_jab").size()
	_expect(jabs >= 3, "the jab held 1.5 s fires volley after volley (%d)" % jabs)

	# ---- the strip's words on touch, the tag's word
	var strip: BendStrip = null
	for n in root.find_children("*", "BendStrip", true, false):
		strip = n as BendStrip
	var hl := strip.help_line() if strip != null else "-"
	var want := String(KitWords.words().get("help_strip_touch", "?"))
	strip._paint_hint()
	_expect(strip != null and hl == want and not hl.contains("(no key)") and strip._hint.text == "",
			"the strip on touch: '%s', no Q line ('%s')" % [hl, strip._hint.text if strip != null else "-"])
	p.hotbar.ready_move(0, "fire_blast", "punch")
	await _ticks(3)
	var tg := t._tag(_key_b(0))
	var whole := String((tg.get("other", {}) as Dictionary).get("label", "")).split(" ")[0] if not tg.is_empty() else ""
	_expect(not tg.is_empty() and String(tg.label) == whole and whole.length() > 6,
			"the tag's word whole: '%s' (%s)" % [tg.get("label", "-"), whole])

	if fails.is_empty():
		print("TOUCH CAST PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("TOUCH CAST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
