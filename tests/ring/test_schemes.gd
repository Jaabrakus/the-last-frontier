extends SceneTree
## The control schemes (MatchSetup.scheme / set_scheme, data/bending/schemes.json; SwayCaster's scheme_pick and
## _switch_lock, Hotbar's ready_skill / step_skill, RadialWheel, BendStrip, the menus, F1 and HowTo; the owner, 2026-10-05:
## "still difficult for a human to switch spells, there's a lot of things going on" -> all three as options), in Tidebreak's
## ring (scenes/ring.tscn, earth against earth, the foe held), the test's own settings file (GameSettings.path):
##   keys       the default with nothing kept: the strip's five key columns, each its key's first move; F1 as ever
##   direction  (round 2: spec 6) forward / side (SwayCaster.dir_override, and the real keys once) cast key 1's first move
##              and key 3's (earth Spike, Burrow; water Lash, Skate; fire Punch, Step; air Slice, Slip), back picks the
##              wall (the pick; its cast is the walls' own); none held: the readied key's move at its own variation; the
##              key's variation never touched; the direction is sampled at the press: one taken while the lock runs changes
##              nothing (no lock_switched); the strip's and F1's lines are schemes.json's
##   radial     Tab (the action bend_wheel) opens the wheel of the element's moves; no lock while it is open; pointing at
##              Shove and letting go readies it on key 2; RMB casts it; a left click picks too
##   first_moves (replaces simple) the bar's first moves only: key 3 again does not ready its other move (Lift), key 1
##              again leaves Spike; no distance band: the cast is the first variation near or far
##   switching  the ring's Esc menu steps the scheme mid-match (its row says so), the match goes on under it; the main
##              menu's row is the one tests/ring/test_match_setup.gd and test_main_menu cover (here: its words)
##   kept       set_scheme writes GameSettings' match section of the test's own file; read back after reload_scheme
##   words      no show word in schemes.json, the how-to topics, the strip or the menus' lines
##   bots       the foe has no SwayCaster (bots never follow a scheme)
##   mode=duel  the duel (scenes/main.tscn): the direction scheme casts forward's move; under the radial scheme Tab opens the
##              wheel and not the character screen; the duel's Esc menu steps the scheme
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_schemes.gd [-- mode=duel]
## The last line "SCHEMES TEST PASSED" or "SCHEMES TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "SCHEMES TEST"
const LIMIT_S := 300.0
const OWN_CFG := "user://schemes_test.cfg"
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?"]
## Each element's direction moves (round 2's skills, spec 6: W key 1's first move, S its wall, A/D key 3's first: [move,
## variation]).
const DIR_WANT := {
	"earth": {"forward": ["stone_form", "spike"], "back": ["earth_wall", "wall"], "side": ["earth_skate", "burrow"]},
	"water": {"forward": ["water_whip", "whip"], "back": ["water_shield", "ice_wall"], "side": ["flow", "skate"]},
	"fire": {"forward": ["fire_blast", "punch"], "back": ["fire_wall", "wall"], "side": ["footwork", "step"]},
	"air": {"forward": ["air_blast", "slice"], "back": ["air_wall", "wall"], "side": ["evade", "slip"]},
}
## The directions whose move is cast through by the player here (a wall's lock needs the deck at its place: the walls are the
## data's own check, _words).
const DIR_CAST := ["forward", "side"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var hud: FrontierHUD
## Each cast: [move, its variation as cast].
var casts: Array = []
var switched: Array = []
var _foe_at := Vector3.INF
var _home := Vector3.INF
var duel_mode := false
var duel: DuelMode


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup.reload_scheme()
	SwayCaster.free_override = true
	InputSetup.ensure()
	for a in OS.get_cmdline_user_args():
		if a == "mode=duel":
			duel_mode = true
	if duel_mode:
		DuelMode.incoming = true
		DuelMode.element = "earth"
		change_scene_to_file("res://scenes/main.tscn")
		_run_duel.call_deferred()
		return
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"]
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _action(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await _ticks(3)


func _key_down(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


## The foe held where it stands (no cast, no knock on the player), and the player kept off the edge between casts.
func _hold_foe() -> void:
	var foe: NpcFighter = null
	if duel != null:
		foe = duel.npc
	else:
		var rm := RingMode.find(self)
		foe = rm.foe if rm != null else null
	if foe == null or not is_instance_valid(foe):
		return
	foe.held = true
	if _foe_at == Vector3.INF:
		_foe_at = foe.global_position
	foe.global_position = _foe_at
	foe.velocity = Vector3.ZERO


func _home_player() -> void:
	if _home == Vector3.INF or p == null:
		return
	p.global_position = _home
	p.velocity = Vector3.ZERO
	await _ticks(4)


## One RMB cast: held until the lock is full, let go; returns the cast ([move, variation]; [] none).
func _rmb_cast(limit := 3.0) -> Array:
	casts.clear()
	Input.action_press(&"aim")
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit)
	Input.action_release(&"aim")
	var t := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.5)
	if full == INF or t == INF:
		await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 1.0)
		return []
	return casts[0]


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	p.pitch = -0.15
	physics_frame.connect(_hold_foe)
	c = SwayCaster.of(p)
	hud = p.hud
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append([m, c.mode_of(m)]))
	c.lock_switched.connect(func(m: String, _t: Node3D) -> void: switched.append(m))
	var laid := await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 4.0)
	_expect(laid < INF and c != null, "the arena player, earth laid, a move readied")
	var rm := RingMode.find(self)
	if rm != null:
		var up := await _until(func() -> bool: return rm.phase == "FIGHT", 8.0)
		_expect(up < INF, "the round is on (%s)" % rm.phase)
		await _secs(0.3)
	# (casts are made from a third of the way to the held foe: the dashes keep off the edge)
	_home = p.global_position.lerp(_foe_at, 0.35) if _foe_at != Vector3.INF else p.global_position
	await _keys()
	await _direction()
	_info(rm, "direction")
	await _radial()
	_info(rm, "radial")
	await _simple()
	_info(rm, "simple")
	await _switching(rm)
	_kept()
	_words()
	var foe: Node = rm.foe if rm != null else null
	_expect(foe != null and SwayCaster.of(foe) == null and MatchSetup.scheme() != "keys",
			"bots: the foe has no SwayCaster, whatever the player's scheme (%s)" % MatchSetup.scheme())
	_end()


func _info(rm: RingMode, after: String) -> void:
	if rm != null:
		print("  info after %s: phase %s, round %d, %s, player at %s" % [after, rm.phase, rm.round, rm.score_text(), p.global_position])


func _end() -> void:
	Input.action_release(&"fire")
	Input.action_release(&"aim")
	Input.action_release(RadialWheel.ACTION)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	MatchSetup.reload_scheme()
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


# ---------------------------------------------------------------- keys: the default
func _keys() -> void:
	_expect(MatchSetup.scheme() == "keys" and c.scheme() == "keys" and p.hotbar.scheme() == "keys",
			"nothing kept: the keys scheme (%s)" % MatchSetup.scheme())
	await _ticks(3)
	var strip := hud.bend_strip
	var ok := true
	for i in 5:
		var col := strip.column(i)
		ok = ok and not bool(col.hidden) and String(col.head) == str(i + 1) and String(col.id) == String(Bending.keys("earth")[i][0])
	_expect(ok and (strip._cols[0].key as Label).text == "1", "the strip's five key columns as ever")
	_expect(not hud.help_text().contains(MatchSetup.scheme_text("f1", "direction")), "F1 as ever")


# ---------------------------------------------------------------- direction
func _direction() -> void:
	_expect(MatchSetup.set_scheme("direction") and c.scheme() == "direction", "the direction scheme set")
	var bar := p.hotbar
	bar.take(0)
	await _ticks(2)
	if c.readied_spell != "stone_form":
		bar.select(0)
		await _ticks(2)
	c.set_mode("stone_form", "cannonball")
	await _ticks(4)
	# the strip's and F1's lines: schemes.json's
	var strip := hud.bend_strip
	var line := MatchSetup.scheme_text("strip", "direction")
	_expect(line != "" and strip.help_line().contains(line.get_slice(" · ", 0)), "the strip's line says how (%s)" % strip.help_line())
	_expect(hud.help_text().contains(MatchSetup.scheme_text("f1", "direction")), "F1 says it")
	# none: the key's move at its own variation
	c.dir_override = ""
	await _home_player()
	var got := await _rmb_cast()
	_expect(got == ["stone_form", "cannonball"], "no direction: the key's Boulder (%s)" % [got])
	# each element's three
	for el: String in ["earth", "water", "fire", "air"]:
		if el != p.arena_element:
			MatchSetup.element = el
			var t := await _until(func() -> bool: return p.arena_element == el and p.hotbar.spell != "", 4.0)
			_expect(t < INF, "%s laid" % el)
			await _secs(0.3)
		for dir: String in ["forward", "back", "side"]:
			c.dir_override = dir
			await _home_player()
			var want: Array = DIR_WANT[el][dir]
			_expect(c.scheme_pick() == {"id": want[0], "mode": want[1]}, "%s %s: the pick is %s (%s)" % [el, dir, want, c.scheme_pick()])
			if not dir in DIR_CAST:
				continue
			got = await _rmb_cast()
			_expect(got == want, "%s %s: cast %s (%s)" % [el, dir, want, got])
			await _secs(0.4)
	c.dir_override = null
	MatchSetup.element = "earth"
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 4.0)
	await _secs(0.3)
	bar.take(0)
	await _ticks(2)
	if c.readied_spell != "stone_form":
		bar.select(0)
		await _ticks(2)
	_expect(c.readied_spell == "stone_form" and c.base_mode_of("stone_form") == "cannonball",
			"the key's own variation untouched by the direction casts (%s)" % c.base_mode_of("stone_form"))
	# the real keys: A held at the press
	await _home_player()
	Input.action_press(&"move_left")
	await _ticks(3)
	_expect(c.held_dir() == "side", "A held: side")
	got = await _rmb_cast()
	Input.action_release(&"move_left")
	_expect(got == ["earth_skate", "burrow"], "A held (the key itself): Burrow cast (%s)" % [got])
	await _secs(0.4)
	# a direction taken while the lock runs changes nothing: sampled at the press (spec 6)
	await _home_player()
	c.dir_override = ""
	casts.clear()
	switched.clear()
	Input.action_press(&"aim")
	var on := await _until(func() -> bool: return c.state == SwayCaster.State.LOCKING, 1.0)
	_expect(on < INF and c.move == "stone_form" and c.mode_of("stone_form") == "cannonball", "the lock begins on the key's move (Boulder)")
	await _ticks(6)
	c.dir_override = "forward"
	await _ticks(12)
	_expect(c.move == "stone_form" and switched.is_empty() and c.state != SwayCaster.State.IDLE,
			"W taken mid-lock: the lock stays the Boulder's (%s, switched %s)" % [c.move, switched])
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"aim")
	await _until(func() -> bool: return not casts.is_empty(), 1.0)
	_expect(not casts.is_empty() and casts[0] == ["stone_form", "cannonball"], "let go: the Boulder is what is cast (%s)" % [casts])
	c.dir_override = null
	await _secs(0.5)


# ---------------------------------------------------------------- radial
func _radial() -> void:
	MatchSetup.set_scheme("radial")
	await _ticks(3)
	var w := c.radial
	_expect(w != null and w.can_open() and InputMap.has_action(RadialWheel.ACTION)
			and SwayCaster.key_name(RadialWheel.ACTION) == "Tab", "the radial scheme: the wheel on Tab")
	var strip := hud.bend_strip
	_expect(bool(strip.column(0).hidden) and not (strip._cols[0].box as Control).visible and strip.ready_line() != ""
			and strip.help_line().contains("hold Tab: the wheel"), "the strip: no key columns, the ready line and the wheel's line")
	Input.action_press(RadialWheel.ACTION)
	var t := await _until(func() -> bool: return w.is_open, 0.5)
	var ids: Array = w.items.map(func(it: Dictionary) -> String: return String(it.id))
	var shove := ids.find("earth_shove")
	_expect(t < INF and shove >= 0 and "patch" in ids and not "earth_grip" in ids and not "rock_jab" in ids,
			"Tab held: the wheel of earth's moves, none cut (%s)" % [ids])
	Input.action_press(&"aim")
	await _ticks(6)
	_expect(c.state == SwayCaster.State.IDLE, "no lock while it is open")
	Input.action_release(&"aim")
	# the mouse toward Shove (a motion event)
	var mm := InputEventMouseMotion.new()
	mm.relative = w.dir_of(maxi(shove, 0)) * 120.0
	Input.parse_input_event(mm)
	await _ticks(2)
	_expect(w.sel == shove, "the mouse moved toward Shove picks it (%d)" % w.sel)
	var md := c.base_mode_of("earth_shove")
	Input.action_release(RadialWheel.ACTION)
	await _ticks(3)
	_expect(not w.is_open and c.readied_spell == "earth_shove" and p.hotbar.slot_of(Hotbar.SPELL, "earth_shove") == 1
			and p.hotbar.spell == "earth_shove", "let go: Shove readied on key 2 (%s)" % c.readied_spell)
	await _home_player()
	var got := await _rmb_cast()
	_expect(got == ["earth_shove", md], "RMB casts it (%s)" % [got])
	# a left click picks too (and starts no quick lock)
	w.open()
	w.pick_toward(w.dir_of(0) * 120.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.action_press(&"fire")
	await _ticks(4)
	_expect(not w.is_open and c.readied_spell == "stone_form" and c.state == SwayCaster.State.IDLE,
			"a left click picks Stone Form, no quick lock from it (%s, %s)" % [c.readied_spell, c.state])
	Input.action_release(&"fire")
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await _ticks(4)


# ---------------------------------------------------------------- first moves only (it replaces simple)
func _simple() -> void:
	MatchSetup.set_scheme("keys")
	await _ticks(2)
	var bar := p.hotbar
	bar.select(2)
	await _ticks(2)
	bar.select(2)                                # (the keys scheme: key 3 tapped twice, its other move)
	await _ticks(2)
	_expect(c.readied_spell == "pillar", "keys: key 3 tapped twice readies Lift (%s)" % c.readied_spell)
	await _ticks(30)
	MatchSetup.set_scheme("first_moves")
	await _ticks(3)
	_expect(c.scheme() == "first_moves" and MatchSetup.scheme_label() == "First moves only", "the first-moves scheme set (%s)" % c.scheme())
	bar.select(2)
	await _ticks(2)
	bar.select(2)
	await _ticks(2)
	_expect(c.readied_spell == "earth_skate" and bar.entry(2).get("id", "") == "earth_skate",
			"first moves: key 3 tapped twice stays on Burrow (%s)" % c.readied_spell)
	await _ticks(30)
	bar.select(0)
	await _ticks(2)
	bar.select(0)
	await _ticks(2)
	_expect(c.readied_spell == "stone_form" and c.base_mode_of("stone_form") == "spike",
			"first moves: key 1, tapped once or twice, is Spike (%s)" % c.base_mode_of("stone_form"))
	_expect(hud.help_text().contains(MatchSetup.scheme_text("f1", "first_moves")), "F1 says it")
	# no distance band: near or far, the first variation
	for d: float in [3.0, 20.0]:
		c.dist_override = d
		await _home_player()
		var got := await _rmb_cast()
		_expect(got == ["stone_form", "spike"], "the opponent %.0f m away: Spike (%s)" % [d, got])
		await _secs(0.3)
	c.dist_override = null


# ---------------------------------------------------------------- switching mid-match, kept, words
func _switching(rm: RingMode) -> void:
	var m := rm.menu if rm != null else null
	_expect(m != null, "the ring's Esc menu")
	if m == null:
		return
	MatchSetup.set_scheme("keys")
	var phase := rm.phase
	m.open()
	await process_frame
	var before := MatchSetup.scheme()
	m.cycle_scheme()
	var row := m._scheme.find_child("Text", true, false) as Label
	_expect(MatchSetup.scheme() == MatchSetup.next_scheme(before) and MatchSetup.scheme() != before and row.text == MatchSetup.scheme_row() and m._note.text.contains(MatchSetup.scheme_label()),
			"the Esc menu steps the scheme: %s -> %s (\"%s\")" % [before, MatchSetup.scheme(), row.text])
	m._controls()
	var texts: Array = []
	for l in m._panel.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	_expect(" ".join(PackedStringArray(texts)).contains(MatchSetup.scheme_label()), "its Controls panel follows the scheme")
	m.close()
	await _ticks(3)
	_expect(c.scheme() == MatchSetup.scheme() and rm.phase == phase, "the match goes on under it (%s, %s)" % [phase, rm.phase])
	# direction mid-match from the menu: casts at once
	MatchSetup.set_scheme("direction")
	c.dir_override = "forward"
	await _home_player()
	var got := await _rmb_cast()
	_expect(got == ["stone_form", "spike"], "switched mid-match to direction: forward casts Spike (%s)" % [got])
	c.dir_override = null


func _kept() -> void:
	MatchSetup.set_scheme("radial")
	MatchSetup.reload_scheme()
	var cf := ConfigFile.new()
	cf.load(OWN_CFG)
	_expect(MatchSetup.scheme() == "radial" and String(cf.get_value(MatchSetup.SECTION, MatchSetup.SCHEME_KEY, "")) == "radial"
			and GameSettings.file() == OWN_CFG, "kept: radial read back from the test's own settings file")
	_expect(not MatchSetup.set_scheme("nope") and MatchSetup.scheme() == "radial", "an unknown scheme is not taken")


func _words() -> void:
	var re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))
	var texts: Array[String] = [FileAccess.get_file_as_string(MatchSetup.SCHEMES_PATH)]
	for id: String in HowTo.ARENA_TOPICS:
		texts.append(String(HowTo.TOPICS[id].title))
		for s in HowTo.TOPICS[id].steps:
			texts.append(String(s))
	for s: String in MatchSetup.SCHEMES:
		texts.append(MatchSetup.scheme_keys_head("earth", s))
		for el: String in Bending.ELEMENTS:
			for l in MatchSetup.scheme_key_lines(el, s):
				texts.append(String(l))
	for l in hud.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var bad: Array = []
	for t in texts:
		for mt in re.search_all(t):
			bad.append(mt.get_string())
	_expect(bad.is_empty(), "no show word in the schemes' words, the topics, the menus' lines or the HUD (%d texts%s)"
			% [texts.size(), "" if bad.is_empty() else ": %s" % [bad]])
	var ok := true
	for el: String in Bending.ELEMENTS:
		for dir: String in MatchSetup.DIRS:
			ok = ok and MatchSetup.direction_move(el, dir) == {"id": DIR_WANT[el][dir][0], "mode": DIR_WANT[el][dir][1]}
		var four := MatchSetup.first_moves(el)
		ok = ok and four.size() == 4
		for i in four.size():
			var e: Dictionary = four[i]
			ok = ok and String(e.id) == String(Bending.keys(el)[i][0]) and String(e.mode) == String(SwayCaster.modes_of(String(e.id))[0])
	_expect(ok, "the data: every element's directions as asked, its four first moves the first of keys 1-4 at their first variation")


# ---------------------------------------------------------------- the duel
func _run_duel() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	_expect(p != null and duel != null, "the duel and its player")
	if p == null or duel == null:
		return _end()
	p.ignore_mouse_capture = true
	p.pitch = -0.15
	physics_frame.connect(_hold_foe)
	hud = p.hud
	await _secs(Hotbar.KIT_S + 1.0)
	await _until(func() -> bool: return duel.phase == DuelMode.Phase.FIGHT, 8.0)
	await _secs(0.3)
	c = SwayCaster.of(p)
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append([m, c.mode_of(m)]))
	_home = p.global_position
	MatchSetup.set_scheme("direction")
	c.dir_override = "forward"
	var got := await _rmb_cast()
	_expect(got == ["stone_form", "spike"], "the duel, direction: forward casts Stone Form (spike) (%s)" % [got])
	c.dir_override = null
	_expect(hud.help_text().contains(MatchSetup.scheme_text("f1", "direction"))
			and hud.quick_help.text.contains(MatchSetup.scheme_text("strip", "direction").get_slice(" · ", 0)),
			"the duel's F1 and its LMB row's line say the scheme")
	# radial: Tab is the wheel's, not the character screen's
	MatchSetup.set_scheme("radial")
	await _ticks(2)
	_key_down(KEY_TAB, true)
	await _ticks(3)
	_expect(c.radial.is_open and (p.get("_inv_screen") == null or not is_instance_valid(p.get("_inv_screen"))),
			"the duel, radial: Tab opens the wheel, not the character screen")
	_key_down(KEY_TAB, false)
	await _ticks(3)
	_expect(not c.radial.is_open, "Tab let go: shut (key held %s, inventory held %s)" % [Input.is_action_pressed(RadialWheel.ACTION),
			Input.is_action_pressed(&"inventory")])
	MatchSetup.set_scheme("keys")
	await _ticks(2)
	_key_down(KEY_TAB, true)
	await _ticks(3)
	var inv: Variant = p.get("_inv_screen")
	_expect(not c.radial.is_open and inv != null and is_instance_valid(inv), "the keys scheme: Tab is the character screen's again")
	_key_down(KEY_TAB, false)
	await _ticks(3)
	if inv != null and is_instance_valid(inv):
		(inv as InventoryScreen).close()
	paused = false
	await _ticks(3)
	var m := current_scene.get_node_or_null("DuelMenu") as DuelMenu
	_expect(m != null, "the duel's Esc menu")
	if m != null:
		m.open()
		await process_frame
		m.cycle_scheme()
		var row := m._scheme.find_child("Text", true, false) as Label
		_expect(MatchSetup.scheme() == "direction" and row.text == MatchSetup.scheme_row(),
				"the duel's Esc menu steps the scheme: keys -> direction (\"%s\")" % row.text)
		m.close()
	_end()
