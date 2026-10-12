extends SceneTree
## F swaps keys 1 and 2 (Hotbar.swap_keys, the action bend_swap; the owner, 2026-10-11: "the F should toggle between 1 and
## 2"), in Tidebreak's ring (scenes/ring.tscn, MatchSetup.incoming, earth), the foe held:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_swap_keys.gd
##   the swap     F with key 1's move readied: key 2's first move readied (Shove); F again: key 1's (Spike); key 1 tapped
##                twice and F: key 2's first move, as a press of 2 would
##   neither      key 4 readied: F readies key 1's
##   mid-lock     a lock of key 1's move under the aim: F ends it as a press of 2 does, key 2's move readied
##   the words    F1's keys line says F swaps 1 and 2
## The last line "SWAP KEYS PASSED (<n> checks)" or "SWAP KEYS FAILED (<f> of <n>)".

const LIMIT_S := 120.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var c: SwayCaster


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("SWAP KEYS FAILED (watchdog)")
		quit(2))
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


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


## Action `a` pressed and let go (through Input: the player's _unhandled_input hears it as a key's).
func _action(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await _ticks(3)


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
	var laid := await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 8.0)
	var rm := RingMode.find(self)
	var fight := await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
	_expect(laid and fight, "earth's keys laid, the fight on")
	if rm.foe != null:
		rm.foe.held = true
	var hb := p.hotbar
	var el := "earth"
	var key := func() -> int: return Bending.key_of(el, hb.spell) if hb.spell != "" else -1
	# ---- the swap
	await _action(&"weapon_1")
	await _ticks(20)
	_expect(key.call() == 0, "key 1 readied (%s)" % hb.spell)
	await _action(&"bend_swap")
	_expect(key.call() == 1 and hb.spell == String(Bending.first_of(Bending.keys(el)[1]).id),
			"F: key 2's first move readied (%s)" % hb.spell)
	await _ticks(20)
	await _action(&"bend_swap")
	_expect(key.call() == 0 and hb.spell == String(Bending.first_of(Bending.keys(el)[0]).id) and c.mode_of(hb.spell) == String(Bending.first_of(Bending.keys(el)[0]).mode),
			"F again: key 1's first move (%s %s)" % [hb.spell, c.mode_of(hb.spell)])
	await _ticks(20)
	await _action(&"weapon_1")
	await _action(&"weapon_1")
	var other := c.mode_of(hb.spell)
	await _ticks(20)
	await _action(&"bend_swap")
	_expect(key.call() == 1, "key 1 tapped twice (%s) and F: key 2's move, as a press of 2 (%s)" % [other, hb.spell])
	# ---- neither readied
	await _ticks(20)
	await _action(&"weapon_4")
	await _ticks(20)
	var four := int(key.call())
	await _action(&"bend_swap")
	_expect(four == 3 and key.call() == 0, "key 4 readied (%d) and F: key 1's move (%s)" % [four, hb.spell])
	# ---- mid-lock
	await _ticks(20)
	c.held_override = true
	var locking := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE and Bending.key_of(el, c.move) == 0, 2.0)
	await _action(&"bend_swap")
	var why := c.last_break                       # (read before the aim is let go: a new lock of key 2's runs on while held)
	c.held_override = false
	await _ticks(3)
	_expect(locking and why == "switch" and key.call() == 1,
			"a lock of key 1's move: F ends it (%s) and readies key 2's (%s)" % [why, hb.spell])
	# ---- the words
	var help := KitWords.help_line("keys")
	_expect(help.contains("swaps 1 and 2") and help.contains("F"), "the keys help line says it: '%s'" % help)
	_end()


func _end() -> void:
	if c != null:
		c.held_override = null
	if fails.is_empty() and checks > 0:
		print("SWAP KEYS PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("SWAP KEYS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
