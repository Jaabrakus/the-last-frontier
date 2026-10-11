extends SceneTree
## The Basic control set (round 4 SIMPLE; MatchSetup.controls "basic", data/bending/schemes.json "basic", RingAssist's
## blocks) in a % ring match (rules stock; water against a water bot held still at its end), the player's keys driven through
## his own PlayerControls (set_held) and the number keys as key events (the hotbar reads them so):
##   Basic keys    LMB: the jab cast; 1 readies the strike, tapped twice its partner, right-click casts it; 2 the push,
##                 right-click casts it; E held: the guard up; Space: the full jump (2 m), again in the air the double
##                 jump; 3 on the deck: the dash cast
##   Full-only     under Basic nothing: C (no crouch on the deck, no fast fall after the apex), E + a fresh direction (no
##                 roll), E + C (no duck), 3 in the air (no dodge, the dodge kept), the short hop (a cast let go, then Space:
##                 the full jump; Space, then a cast let go: not capped), 4 and 5 before the first win (nothing readied; after
##                 RingAssist.note_win: 4 readies the wall), the edge's E, click and C (no roll in, no attack, no let go)
##   Full          the same inputs do what round 3 made them do: the crouch, the fast fall, the roll, the duck, the air
##                 dodge, the short hop (0.8 m) both orders, 4 the wall, E on the edge rolls in
## Watchdog LIMIT_S; seed(1750); MatchSetup._aim_help pinned; GameSettings.path its own. Last line "BASIC SCHEME PASSED" or
## "BASIC SCHEME FAILED"; exit 0 only on a pass.
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_basic_scheme.gd

const NAME := "BASIC SCHEME"
const LIMIT_S := 300.0
const OWN_CFG := "user://basic_scheme_test.cfg"
const EL := "water"

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var rm: RingMoves
var a: RingAssist
var mode: RingMode
var ring: RingArena
var foe: NpcFighter
var c: SwayCaster
var moved: Array = []
var casts: Array = []
var released: Array = []
var _foe_at := Vector3.INF
var _jump_on_release := false


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "light"
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("basic")
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = EL
	MatchSetup.foes = [EL]
	MatchSetup.difficulty = "easy"
	RingRules.rule_set_override = "stock"
	physics_frame.connect(_hold_foe)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d: %s)" % [NAME, fails.size(), checks, "; ".join(fails)])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _hold_foe() -> void:
	if foe != null and is_instance_valid(foe):
		foe.held = true
		if _foe_at == Vector3.INF:
			_foe_at = foe.global_position
		foe.global_position = _foe_at
		foe.velocity = Vector3.ZERO
	if _jump_on_release and not released.is_empty() and p != null:
		_jump_on_release = false
		p.controls.set_held(&"jump", true)


func _run() -> void:
	for i in 600:
		await physics_frame
		mode = RingMode.find(self)
		p = mode.player if mode != null else null
		if p != null and p.arena_element != "" and mode.rules != null and SwayCaster.of(p) != null and mode.foe != null:
			break
	_expect(p != null and RingRules.stock_on(), "the % ring and its player")
	if p == null:
		return _end()
	await _until(func() -> bool: return mode.phase == "FIGHT", 8.0)
	foe = mode.foe
	ring = mode.ring
	c = SwayCaster.of(p)
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	a = RingAssist.install(p)
	rm = RingMoves.of(p)
	await _ticks(2)
	rm.moved.connect(func(k: String) -> void: moved.append(k))
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append(m))
	c.cast_released.connect(func(m: String, _md: String) -> void: released.append(m))
	_expect(MatchSetup.basic() and MatchSetup.scheme() == "keys" and a.active(), "Basic on: the keys scheme's routing, the helper active")
	await _basic_keys()
	await _basic_blocks()
	MatchSetup.set_controls("full")
	_expect(not MatchSetup.basic() and not a.active(), "Full set: the helper idle")
	await _full_keys()
	_end()


# ---------------------------------------------------------------- the keys
func _key(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await _ticks(2)


func _tap(action: StringName, s := 0.08) -> void:
	p.controls.set_held(action, true)
	await _secs(s)
	p.controls.set_held(action, false)


## A cast's button held until its lock is full, then let go (the owner, 2026-10-10: casts are held, no click and forget).
func _hold_cast(action: StringName, limit := 3.0) -> void:
	p.controls.set_held(action, true)
	await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], limit)
	p.controls.set_held(action, false)


func _reset() -> void:
	p.controls.release_all()
	var g := RingMoves.arena_geo(ring)
	var xf: Transform3D = g.xf
	p.global_position = xf * Vector3(-float(g.hl) + 8.0, float(g.top) + 0.05, 0.0)
	p.yaw = atan2(-1.0, 0.0)
	p.rotation.y = p.yaw
	p.pitch = 0.0
	p.velocity = Vector3.ZERO
	var kn := BendKnock.peek(p)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
	rm.placed()
	await _secs(0.5)
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE and p.is_on_floor(), 3.0)
	moved.clear()
	casts.clear()
	released.clear()


func _apex_of_jump() -> float:
	var y0 := p.global_position.y
	var top := y0
	for i in 70:
		await physics_frame
		top = maxf(top, p.global_position.y)
	p.controls.set_held(&"jump", false)
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
	return top - y0


func _basic_keys() -> void:
	await _reset()
	var jab := String(KitWords.jab(EL).get("id", ""))
	await _hold_cast(&"fire")
	await _until(func() -> bool: return casts.has(jab), 2.0)
	_expect(casts.has(jab), "LMB: the jab (%s) cast (%s)" % [jab, casts])
	# 1: the strike, tapped twice its partner; right-click casts it
	await _reset()
	var k1 := KitWords.key_moves(EL, 0)
	await _key(&"weapon_1")
	var first := c.readied_spell == String(k1[0].id) and c.base_mode_of(c.readied_spell) == String(k1[0].mode)
	await _key(&"weapon_1")
	var other := k1.size() > 1 and c.readied_spell == String(k1[1].id) and c.base_mode_of(c.readied_spell) == String(k1[1].mode)
	await _key(&"weapon_1")
	await _secs(0.4)
	await _hold_cast(&"aim")
	await _until(func() -> bool: return not casts.is_empty(), 3.0)
	_expect(first and other and casts.has(String(k1[0].id)), "1 readies %s, twice %s; right-click casts it (%s)" % [k1[0], k1[1] if k1.size() > 1 else "-", casts])
	# 2: the push, right-click casts it
	await _reset()
	var k2 := KitWords.key_moves(EL, 1)
	await _key(&"weapon_2")
	var two := c.readied_spell == String(k2[0].id)
	await _hold_cast(&"aim")
	await _until(func() -> bool: return not casts.is_empty(), 3.0)
	_expect(two and casts.has(String(k2[0].id)), "2 readies %s; right-click casts it (%s)" % [k2[0].id, casts])
	# E: the guard
	await _reset()
	p.controls.set_held(InputSetup.GUARD_ACTION, true)
	var up := await _until(func() -> bool: return c.guard_up(), 1.5)
	p.controls.set_held(InputSetup.GUARD_ACTION, false)
	_expect(up < INF, "E held: the guard up (%.2f s)" % up)
	# Space: the full jump, again in the air the double jump
	await _reset()
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	p.controls.set_held(&"jump", false)
	await _secs(0.25)
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	p.controls.set_held(&"jump", false)
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 3.0)
	_expect(moved.has("jump") and moved.has("double_jump"), "Space jumps, Space again in the air the double jump (%s)" % [moved])
	await _reset()
	p.controls.set_held(&"jump", true)
	var h := await _apex_of_jump()
	_expect(absf(h - RingMoves.num("jump", "apex_m", 2.0)) < 0.25, "Space: the full jump (%.2f m)" % h)
	# 3 on the deck: the dash
	await _reset()
	var k3 := KitWords.key_moves(EL, 2)
	p.controls.set_held(&"move_left", true)
	await _key(&"weapon_3")
	await _until(func() -> bool: return not casts.is_empty(), 2.0)
	p.controls.set_held(&"move_left", false)
	_expect(casts.has(String(k3[0].id)), "3 on the deck: the dash (%s) cast (%s)" % [k3[0].id, casts])


func _basic_blocks() -> void:
	# C on the deck: no crouch
	await _reset()
	p.controls.set_held(&"crouch", true)
	await _secs(0.3)
	var crouch := bool(rm.get(&"_crouch"))
	p.controls.set_held(&"crouch", false)
	_expect(not crouch, "Basic: C on the deck does not crouch")
	# C after the apex: no fast fall
	await _reset()
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	p.controls.set_held(&"jump", false)
	await _secs(0.55)
	p.controls.set_held(&"crouch", true)
	await _ticks(3)
	var ff := bool(rm.get(&"_ff"))
	p.controls.set_held(&"crouch", false)
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
	_expect(not ff, "Basic: C after the apex is no fast fall")
	# E + a fresh direction: no roll; E + C: no duck
	await _reset()
	p.controls.set_held(InputSetup.GUARD_ACTION, true)
	await _ticks(2)
	p.controls.set_held(&"move_left", true)
	await _secs(0.5)
	p.controls.set_held(&"move_left", false)
	p.controls.set_held(InputSetup.GUARD_ACTION, false)
	await _reset()
	p.controls.set_held(InputSetup.GUARD_ACTION, true)
	await _ticks(2)
	p.controls.set_held(&"crouch", true)
	await _secs(0.4)
	p.controls.set_held(&"crouch", false)
	p.controls.set_held(InputSetup.GUARD_ACTION, false)
	_expect(not moved.has("roll") and not moved.has("duck"), "Basic: E + a direction no roll, E + C no duck (%s)" % [moved])
	# 3 in the air: no dodge
	await _reset()
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	p.controls.set_held(&"jump", false)
	await _secs(0.15)
	await _key(&"weapon_3")
	await _secs(0.3)
	var dodged := moved.has("dodge")
	var kept := rm.dodge_ready
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
	_expect(not dodged and kept, "Basic: 3 in the air is no dodge (the dodge kept: %s)" % kept)
	# the short hop: a cast let go, then Space at once: the full jump
	await _reset()
	await _key(&"weapon_1")
	_jump_on_release = true
	await _hold_cast(&"aim")
	await _until(func() -> bool: return not released.is_empty(), 3.0)
	await _ticks(1)
	var h1 := await _apex_of_jump()
	_expect(h1 > RingMoves.num("jump", "apex_m", 2.0) - 0.3, "Basic: a cast let go, Space at once: the full jump (%.2f m), no short hop" % h1)
	# Space, then a cast let go within the hop's window: not capped
	var h2 := await _space_then_release()
	_expect(h2 > RingMoves.num("jump", "apex_m", 2.0) - 0.3, "Basic: Space, a cast let go just after: the full jump (%.2f m)" % h2)
	# 4 and 5 before the first win: nothing readied; after it, 4 the wall
	await _reset()
	await _key(&"weapon_1")
	var before := c.readied_spell
	await _key(&"weapon_4")
	var r4 := c.readied_spell
	await _key(&"weapon_5")
	var r5 := c.readied_spell
	var locked := RingAssist.key_locked(p, 4) and RingAssist.key_locked(p, 5) and not RingAssist.key_locked(p, 3)
	_expect(r4 == before and r5 == before and locked, "Basic: 4 and 5 do nothing before the first win (readied %s, %s; locked for the strip %s)" % [r4, r5, locked])
	RingAssist.note_win()
	var k4 := KitWords.key_moves(EL, 3)
	await _key(&"weapon_4")
	_expect(RingAssist.won_once() and c.readied_spell == String(k4[0].id) and not RingAssist.key_locked(p, 4), "after the first win 4 readies %s (%s)" % [k4[0].id, c.readied_spell])
	await _key(&"weapon_1")
	# the edge: E, a click and C do nothing there
	await _hang()
	if rm.on_ledge():
		p.controls.set_held(&"crouch", true)
		await _secs(0.2)
		p.controls.set_held(InputSetup.GUARD_ACTION, true)
		await _ticks(3)
		p.controls.set_held(&"fire", true)
		await _ticks(3)
		p.controls.set_held(&"fire", false)
		await _secs(0.5)
		var still := rm.on_ledge()
		p.controls.set_held(InputSetup.GUARD_ACTION, false)
		p.controls.set_held(&"crouch", false)
		await _until(func() -> bool: return moved.has("climb"), 1.0)
		_expect(still and not moved.has("ledge_roll") and not moved.has("ledge_attack") and moved.has("climb"),
				"Basic: on the edge C, E and a click do nothing (still hanging %s, %s); let go, it climbs" % [still, moved])
	else:
		_expect(false, "Basic: he grabs the edge")
	await _secs(0.8)


func _space_then_release() -> float:
	await _reset()
	await _key(&"weapon_1")
	p.controls.set_held(&"aim", true)
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL or c.state == SwayCaster.State.HOLDING, 3.0)
	p.controls.set_held(&"jump", true)
	await _ticks(1)
	p.controls.set_held(&"aim", false)
	return await _apex_of_jump()


## Hanging on the -X end's lip (dropped into the grab box).
func _hang() -> void:
	await _reset()
	var g := RingMoves.arena_geo(ring)
	var xf: Transform3D = g.xf
	var lip: Vector3 = xf * Vector3(-float(g.hl), float(g.top), 0.0)
	var n: Vector3 = (xf.basis * Vector3(-1.0, 0.0, 0.0)).normalized()
	p.global_position = lip + n * 0.45 - Vector3.UP * 1.55
	p.yaw = atan2(n.x, n.z)
	p.velocity = Vector3.ZERO
	rm.placed()
	moved.clear()
	await _until(func() -> bool: return rm.on_ledge(), 2.0)
	await _secs(0.17)


func _full_keys() -> void:
	await _reset()
	p.controls.set_held(&"crouch", true)
	await _secs(0.3)
	var crouch := bool(rm.get(&"_crouch"))
	p.controls.set_held(&"crouch", false)
	await _reset()
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	p.controls.set_held(&"jump", false)
	await _secs(0.55)
	p.controls.set_held(&"crouch", true)
	await _ticks(3)
	var ff := bool(rm.get(&"_ff"))
	p.controls.set_held(&"crouch", false)
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
	_expect(crouch and ff, "Full: C crouches on the deck (%s), fast falls after the apex (%s)" % [crouch, ff])
	await _reset()
	p.controls.set_held(InputSetup.GUARD_ACTION, true)
	await _ticks(2)
	p.controls.set_held(&"move_left", true)
	await _secs(0.6)
	p.controls.set_held(&"move_left", false)
	p.controls.set_held(InputSetup.GUARD_ACTION, false)
	var rolled := moved.has("roll")
	await _reset()
	p.controls.set_held(InputSetup.GUARD_ACTION, true)
	await _ticks(2)
	p.controls.set_held(&"crouch", true)
	await _secs(0.4)
	p.controls.set_held(&"crouch", false)
	p.controls.set_held(InputSetup.GUARD_ACTION, false)
	_expect(rolled and moved.has("duck"), "Full: E + a direction rolls (%s), E + C ducks (%s)" % [rolled, moved])
	await _reset()
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	p.controls.set_held(&"jump", false)
	await _secs(0.15)
	await _key(&"weapon_3")
	await _secs(0.3)
	var dodged := moved.has("dodge")
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
	_expect(dodged, "Full: 3 in the air dodges")
	await _reset()
	await _key(&"weapon_1")
	_jump_on_release = true
	await _hold_cast(&"aim")
	await _until(func() -> bool: return not released.is_empty(), 3.0)
	await _ticks(1)
	var h1 := await _apex_of_jump()
	var h2 := await _space_then_release()
	var hop := RingMoves.num("jump", "short_apex_m", 0.8)
	_expect(absf(h1 - hop) < 0.25 and absf(h2 - hop) < 0.35, "Full: the short hop both ways (%.2f m, %.2f m; %.1f m)" % [h1, h2, hop])
	await _reset()
	var k4 := KitWords.key_moves(EL, 3)
	await _key(&"weapon_4")
	_expect(c.readied_spell == String(k4[0].id), "Full: 4 readies %s" % k4[0].id)
	await _key(&"weapon_1")
	await _hang()
	p.controls.set_held(InputSetup.GUARD_ACTION, true)
	await _ticks(3)
	p.controls.set_held(InputSetup.GUARD_ACTION, false)
	await _until(func() -> bool: return moved.has("ledge_roll"), 1.0)
	_expect(moved.has("ledge_roll"), "Full: E on the edge rolls in (%s)" % [moved])
	await _secs(1.0)
