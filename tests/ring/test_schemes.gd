extends SceneTree
## The control schemes (MatchSetup.scheme / set_scheme, data/bending/schemes.json; SwayCaster's scheme_pick and
## _switch_lock, Hotbar's ready_skill / step_skill, RadialWheel, BendStrip, the menus, F1 and HowTo; the owner, 2026-10-05:
## "still difficult for a human to switch spells, there's a lot of things going on" -> all three as options), in Tidebreak's
## ring (scenes/ring.tscn, earth against earth, the foe held), the test's own settings file (GameSettings.path):
##   keys       the default with nothing kept: the strip's five key columns as ever; F1 as ever
##   direction  forward / back / side (SwayCaster.dir_override, and the real keys once) cast each element's attack,
##              defence and dodge at their own variation (earth spike, catch, burrow-step; water whip, bubble, water skate;
##              fire punch, parry, hop; air ball, shield, sidestep); none held: the readied key's move at its own
##              variation; the key's variation never touched; a direction taken while a lock runs moves the lock to its
##              move (lock_switched) and that is what is cast; the strip's four columns (W, S, A D, the key) and its line;
##              F1's line
##   radial     Tab (the action bend_wheel) opens the wheel of ten moves; no lock while it is open; pointing at Earth Grip and
##              scrolling steps its form; letting go readies it on key 2 at that form; RMB casts it; a left click picks too
##   simple     the bar's four moves: key 1 again and key 5 do nothing, the wheel steps the four; a key left on its other
##              skill is turned back as the scheme comes in; the distance band picks the form at the release (near: boulder,
##              far: spike), the real foe's distance too; the strip's four columns with their two forms
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
## Each element's direction moves as the owner asked them ([move, variation]).
const DIR_WANT := {
	"earth": {"forward": ["stone_form", "spike"], "back": ["stone_catch", "catch"], "side": ["earth_skate", "burrow"]},
	"water": {"forward": ["water_whip", "whip"], "back": ["water_shield", "bubble"], "side": ["flow", "water_skate"]},
	"fire": {"forward": ["fire_blast", "punch"], "back": ["fire_parry", "parry"], "side": ["footwork", "hop"]},
	"air": {"forward": ["air_blast", "ball"], "back": ["air_shield", "shield"], "side": ["evade", "sidestep"]},
}

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
	c.set_mode("stone_form", "disc")
	await _ticks(4)
	# the strip
	var strip := hud.bend_strip
	var cols := [strip.column(0), strip.column(1), strip.column(2), strip.column(3), strip.column(4)]
	_expect(String(cols[0].head) == "W" and String(cols[0].id) == "stone_form" and String(cols[0].sub) == "spike"
			and String(cols[1].head) == "S" and String(cols[1].id) == "stone_catch" and String(cols[2].head) == "A D"
			and String(cols[2].id) == "earth_skate" and String(cols[2].sub) == "burrow-step" and String(cols[3].id) == "stone_form"
			and bool(cols[3].readied) and bool(cols[4].hidden) and not (strip._cols[4].box as Control).visible,
			"the strip: W Stone Form (spike), S Catch, A D Earth Skate (burrow-step), the key's move lit (%s)" % [cols.map(
			func(cl: Dictionary) -> String: return "%s:%s" % [cl.head, cl.id])])
	_expect(strip.help_line().contains("W attack") and (strip._help as Label).text.contains("W attack"),
			"the strip's line says how (%s)" % strip.help_line())
	_expect(hud.help_text().contains("Let go of RMB holding W: attack"), "F1 says it")
	# none: the key's move at its own variation
	c.dir_override = ""
	await _home_player()
	var got := await _rmb_cast()
	_expect(got == ["stone_form", "disc"], "no direction: the key's Stone Form (disc) (%s)" % [got])
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
	_expect(c.readied_spell == "stone_form" and c.base_mode_of("stone_form") == "disc",
			"the key's own variation untouched by the direction casts (%s)" % c.base_mode_of("stone_form"))
	# the real keys: S held at the release
	await _home_player()
	Input.action_press(&"move_back")
	await _ticks(3)
	_expect(c.held_dir() == "back" and bool(hud.bend_strip.column(1).readied), "S held: back, its column lit")
	got = await _rmb_cast()
	Input.action_release(&"move_back")
	_expect(got == ["stone_catch", "catch"], "S held (the key itself): Catch cast (%s)" % [got])
	await _secs(0.4)
	# a direction taken while the lock runs: the lock moves to its move
	await _home_player()
	c.dir_override = ""
	casts.clear()
	switched.clear()
	Input.action_press(&"aim")
	var on := await _until(func() -> bool: return c.state == SwayCaster.State.LOCKING, 1.0)
	_expect(on < INF and c.move == "stone_form" and c.mode_of("stone_form") == "disc", "the lock begins on the key's move (disc)")
	await _ticks(6)
	c.dir_override = "back"
	var sw := await _until(func() -> bool: return c.move == "stone_catch", 0.5)
	_expect(sw < INF and switched.has("stone_catch") and c.state != SwayCaster.State.IDLE,
			"S taken mid-lock: the lock moved to Catch (%s)" % [switched])
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	Input.action_release(&"aim")
	await _until(func() -> bool: return not casts.is_empty(), 1.0)
	_expect(not casts.is_empty() and casts[0] == ["stone_catch", "catch"], "let go: Catch is what is cast (%s)" % [casts])
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
	_expect(t < INF and w.items.size() == 10 and String(w.items[3].id) == "earth_grip" and String(w.items[9].id) == "patch",
			"Tab held: the wheel of ten (%d)" % w.items.size())
	Input.action_press(&"aim")
	await _ticks(6)
	_expect(c.state == SwayCaster.State.IDLE, "no lock while it is open")
	Input.action_release(&"aim")
	# the mouse toward Earth Grip (a motion event), the wheel steps its form
	var mm := InputEventMouseMotion.new()
	mm.relative = w.dir_of(3) * 120.0
	Input.parse_input_event(mm)
	await _ticks(2)
	_expect(w.sel == 3, "the mouse moved toward Earth Grip picks it (%d)" % w.sel)
	var was := c.base_mode_of("earth_grip")
	var nxt := w.step_form(1)
	_expect(nxt != "" and nxt != was and c.base_mode_of("earth_grip") == nxt, "the wheel steps its form (%s -> %s)" % [was, nxt])
	Input.action_release(RadialWheel.ACTION)
	await _ticks(3)
	_expect(not w.is_open and c.readied_spell == "earth_grip" and p.hotbar.slot_of(Hotbar.SPELL, "earth_grip") == 1
			and p.hotbar.spell == "earth_grip", "let go: Earth Grip readied on key 2 (%s)" % c.readied_spell)
	await _home_player()
	var got := await _rmb_cast()
	_expect(got == ["earth_grip", nxt], "RMB casts it at that form (%s)" % [got])
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


# ---------------------------------------------------------------- simple
func _simple() -> void:
	MatchSetup.set_scheme("keys")
	await _ticks(2)
	var bar := p.hotbar
	bar.take(0)
	await _ticks(2)
	if c.readied_spell != "rock_jab":
		bar.select(0)                            # (the keys scheme: key 1 again, its other skill)
		await _ticks(2)
	_expect(c.readied_spell == "rock_jab", "keys: key 1 again readies Rock Jab")
	MatchSetup.set_scheme("simple")
	await _ticks(3)
	_expect(c.scheme() == "simple" and bar.entry(0).get("id", "") == "stone_form" and c.readied_spell == "stone_form",
			"simple: key 1 turned back to Stone Form, readied (%s)" % c.readied_spell)
	bar.select(0)
	await _ticks(2)
	_expect(c.readied_spell == "stone_form" and bar.entry(0).get("id", "") == "stone_form", "key 1 again: nothing")
	bar.select(4)
	await _ticks(2)
	_expect(c.readied_spell == "stone_form", "key 5: nothing (four moves)")
	await _action(&"weapon_next")
	_expect(c.readied_spell == "earth_wall", "the wheel: the next move, Earth Wall (%s)" % c.readied_spell)
	await _action(&"weapon_prev")
	await _action(&"weapon_prev")
	_expect(c.readied_spell == "earth_shove", "and back round: Earth Shove (%s)" % c.readied_spell)
	await _action(&"weapon_next")
	_expect(c.readied_spell == "stone_form", "and on to Stone Form")
	var strip := hud.bend_strip
	await _ticks(3)
	_expect(String(strip.column(0).sub) == "boulder / spike" and bool(strip.column(4).hidden)
			and (strip.column(0).modes as Array).is_empty() and strip.ready_line().begins_with("1 · Stone Form · near boulder · far spike"),
			"the strip: four columns, their two forms, no pips (%s; %s)" % [strip.column(0).sub, strip.ready_line()])
	_expect(hud.help_text().contains("how near the opponent is picks the form"), "F1 says it")
	# the band picks the form at the release
	for pair: Array in [[3.0, "cannonball"], [20.0, "spike"]]:
		c.dist_override = pair[0]
		await _home_player()
		var got := await _rmb_cast()
		_expect(got == ["stone_form", pair[1]], "the opponent %.0f m away: Stone Form (%s) (%s)" % [pair[0], pair[1], got])
		await _secs(0.3)
	c.dist_override = null
	var d := c.foe_distance()
	var want := MatchSetup.simple_mode("earth", "stone_form", d)
	await _home_player()
	var got2 := await _rmb_cast()
	_expect(d < INF and got2 == ["stone_form", want], "the real foe %.1f m away: %s (%s)" % [d, want, got2])
	_expect(c.base_mode_of("stone_form") == "disc", "the key's variation untouched (%s)" % c.base_mode_of("stone_form"))


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
	c.dir_override = "back"
	await _home_player()
	var got := await _rmb_cast()
	_expect(got == ["stone_catch", "catch"], "switched mid-match to direction: back casts Catch (%s)" % [got])
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
		var four := MatchSetup.simple_skills(el)
		ok = ok and four.size() == 4
		for i in four.size():
			var e: Dictionary = four[i]
			ok = ok and String(e.id) == String(Bending.keys(el)[i][0]) and String(e.near) in SwayCaster.modes_of(String(e.id)) \
					and String(e.far) in SwayCaster.modes_of(String(e.id)) and String(e.near) != String(e.far)
	_expect(ok, "the data: every element's directions as asked, its simple four the first skills of 1-4, two real forms each")


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
	_expect(hud.help_text().contains("Let go of RMB holding W: attack") and hud.quick_help.text.contains("W attack"),
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
