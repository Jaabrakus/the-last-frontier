extends SceneTree
## The arena player and the match HUD (Tidebreak's ring, scenes/ring.tscn; FrontierPlayer.arena, Hotbar.lay_spells,
## FrontierHUD.set_arena, BendStrip, MatchBar, SwayPose's knock layer; the owner, 2026-10-04: "remove the guns in 1v1 its just
## spells", no target cues of any kind):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_hud.gd [-- seed=<n>]
## MatchSetup.incoming is set before the scene loads, so it runs with or without the match (RingMode) in the scene.
##   arena     the player is the arena's: no musket, pistol, bow, spear, tomahawk or atlatl, no ThrowableKit, nothing on the
##             body, no equip wheel or building; `weapon` null every frame of the run (10 s and more)
##   the bar   the hotbar laid from the element's bar at once (the kit closed), its first key readied
##   strip     the HUD in arena mode (no compass), the BendStrip's five columns name the element's keys and their other
##             skills; key 2 twice: column 2's skill is its partner; the wheel moves the filled pip; the ready line as
##             docs/bending_design.md writes it ("2 · Earth Grip · trap (2/3)"); the aim dot shown
##   keys      6, 7, 8, 9, H, Tab, K, Q, T, B and Z leave the readied move, the hands and the open screens as they were
##   water     the element water: the strip's keys are water's, the water bar shows, the ready line says the water
##   match     the MatchBar reads the match node (a stub when there is none): its round and its time
##   no cues   a bot moved 10 m in 1 s: no CanvasItem anywhere moves or shows or hides with it (against the same second with
##             the bot still); bend_strip.gd and match_bar.gd read no position (no unproject_position, no global_position)
##   words     the arena's HUD lines, the strip, the bar and the arena's first-time help hold none of the show's words
##   body      a cast (the lock held, let go: cast), a walk forward, a jump; a 6 m/s knock plays the knocked slide and the
##             legs' pace leaves the carry out; a knock-up plays the airborne clip; a 16 m/s knock throws him down
##             (PlayerRagdoll) and he gets up and walks again
## The last line "RING HUD TEST PASSED" or "RING HUD TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "RING HUD TEST"
const LIMIT_S := 300.0
## The show's words (as tests/ring/test_player_words.gd holds them).
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?"]


class StubMatch extends Node:
	var round := 2
	var score := Vector2i(1, 0)
	var phase := "FIGHT"

	func round_left_s() -> float:
		return 100.0

	func side_of(_b: Node) -> int:
		return 0

	func confined_of(_b: Node) -> int:
		return 1


var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var hud: FrontierHUD
var opts_seed := 1750
var _armed_frames := 0
var _weapon_seen := false


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			opts_seed = int(a.get_slice("=", 1))
	seed(opts_seed)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
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


func _watch_weapon() -> void:
	if p != null and is_instance_valid(p):
		_armed_frames += 1
		if p.weapon != null:
			_weapon_seen = true


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	physics_frame.connect(_watch_weapon)
	c = SwayCaster.of(p)
	hud = p.hud
	await _arena()
	await _strip()
	await _keys()
	await _water()
	await _match()
	await _no_cues()
	_words()
	await _body()
	_expect(_armed_frames >= 10 * Engine.physics_ticks_per_second and not _weapon_seen,
			"no weapon in the hands any frame of the run (%d frames, %.0f s)" % [_armed_frames, float(_armed_frames) / Engine.physics_ticks_per_second])
	_end()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


# ---------------------------------------------------------------- the arena player
func _arena() -> void:
	_expect(p.arena, "the ring's player is the arena's")
	var keys := ["musket", "pistol", "bow", "spear", "tomahawk", "atlatl"]
	_expect(not keys.any(func(k: String) -> bool: return p.weapons.has(k)) and p.weapons.is_empty() and p.weapon == null,
			"no musket, pistol, bow, spear, tomahawk or atlatl (%s), none in the hands" % [p.weapons.keys()])
	_expect(p.find_children("*", "ThrowableKit", true, false).is_empty() and p.gear == null and p.equip_wheel == null
			and p.building == null, "no ThrowableKit, nothing slung on the body, no equip wheel, no building")
	var laid := await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 3.0)
	_expect(laid < INF and p.hotbar.kit_placed and p.hotbar.spells_only,
			"the bar laid from the element's at once, the kit closed (%.2f s)" % laid)
	var want := Bending.bar("earth")
	var have: Array = []
	for i in 5:
		have.append(String(p.hotbar.entry(i).get("id", "")))
	_expect(have == want and not p.hotbar.filled(5), "the bar: %s" % [have])
	_expect(p.hotbar.spell == String(want[0]) and c.readied_spell == String(want[0]), "its first key readied (%s)" % p.hotbar.spell)
	await _secs(Hotbar.KIT_S + 0.5)
	have.clear()
	for i in 5:
		have.append(String(p.hotbar.entry(i).get("id", "")))
	_expect(have == want, "the start kit never comes over it (%s at %.1f s)" % [have, Hotbar.KIT_S + 0.5])


# ---------------------------------------------------------------- the strip
func _strip() -> void:
	var strip := hud.bend_strip
	_expect(hud.arena and strip != null and strip.is_visible_in_tree() and hud.match_bar != null,
			"the HUD in arena mode: the strip shows")
	var compass := hud._root.get_node_or_null(^"Compass") as Control
	_expect(compass != null and not compass.visible and not hud._slots_box.visible and not hud._torch_row.visible,
			"no compass, no clock, no slot strip, no torch")
	if strip == null:
		return
	await _ticks(3)
	var ok := true
	var names: Array = []
	for i in 5:
		var pair: Array = Bending.keys("earth")[i]
		var col := strip.column(i)
		var ui: Dictionary = strip._cols[i]
		names.append((ui.name as Label).text)
		ok = ok and String(col.id) == String(pair[0]) and (ui.name as Label).text == Hotbar.spell_label(String(pair[0])) \
				and (ui.other as Label).text == "again: " + Hotbar.spell_label(String(pair[1]))
	_expect(ok, "five columns: the element's keys and their other skills (%s)" % [names])
	_expect(bool(strip.column(0).readied) and not bool(strip.column(1).readied), "the first column readied")
	await _action(&"weapon_2")
	_expect(String(strip.column(1).id) == "earth_wall" and bool(strip.column(1).readied), "2: Earth Wall readied")
	await _action(&"weapon_2")
	await _ticks(2)
	_expect(String(strip.column(1).id) == "earth_grip" and (strip._cols[1].name as Label).text == Hotbar.spell_label("earth_grip")
			and (strip._cols[1].other as Label).text == "again: " + Hotbar.spell_label("earth_wall"),
			"2 again: column 2 is its partner, Earth Grip (%s)" % (strip._cols[1].name as Label).text)
	var m0 := int(strip.column(1).mode_i)
	await _action(&"weapon_next")
	await _ticks(2)
	var m1 := int(strip.column(1).mode_i)
	_expect(m0 == 0 and m1 == 1, "the wheel moves the filled pip (%d -> %d)" % [m0, m1])
	var ms: Array = SwayCaster.modes_of("earth_grip")
	var want := "2 · %s · %s (2/%d)" % [Hotbar.spell_label("earth_grip"), SwayCaster.mode_label("earth_grip", String(ms[1])), ms.size()]
	_expect(strip.ready_line() == want and (strip._line as Label).text == want,
			"the ready line as the design writes it: \"%s\" (%s)" % [want, strip.ready_line()])
	_expect(hud.aim_dot_shown(), "the aim dot shows with a move readied and no weapon")


# ---------------------------------------------------------------- keys that do nothing here
func _keys() -> void:
	var spell := p.hotbar.spell
	var before := _screens()
	var acts: Array[StringName] = [&"weapon_6", &"weapon_7", &"weapon_8", &"weapon_9", &"hands_free", &"inventory", &"skills",
			&"equip_wheel", &"torch", &"build_mode", &"sleep"]
	var missing: Array = []
	for a in acts:
		if not InputMap.has_action(a):
			missing.append(String(a))
			continue
		await _action(a)
	await _ticks(10)
	_expect(p.hotbar.spell == spell and c.readied_spell == spell and p.weapon == null and p.hands_free,
			"6-9, H, Tab, K, Q, T, B, Z: the readied move and the hands as they were (%s)" % p.hotbar.spell)
	_expect(_screens() == before, "and no screen opened (%s -> %s)%s" % [before, _screens(),
			"" if missing.is_empty() else "; unbound here: %s" % [missing]])


## The screens open now (the character screen, the equip wheel, build mode, the torch out).
func _screens() -> Array:
	var out: Array = []
	out.append(root.find_children("*", "InventoryScreen", true, false).size())
	out.append(root.find_children("*", "EquipWheel", true, false).filter(func(w: Node) -> bool: return bool(w.get(&"is_open"))).size())
	out.append(1 if p.building != null and p.building.active else 0)
	out.append(1 if p.torch != null and p.torch.held != null else 0)
	return out


# ---------------------------------------------------------------- water
func _water() -> void:
	MatchSetup.element = "water"
	var t := await _until(func() -> bool: return p.arena_element == "water" and p.hotbar.spell == "water_whip", 2.0)
	await _ticks(3)
	var strip := hud.bend_strip
	_expect(t < INF and String(strip.column(0).id) == "water_whip" and String(strip.column(3).id) == "water_shield",
			"water: the bar and the strip are water's (%.2f s)" % t)
	_expect(hud._water_row.visible and hud._water_bar.value > 0.0, "the water bar shows (%.2f)" % hud._water_bar.value)
	_expect(strip.ready_line().begins_with("1 · Water Whip · ") and strip.ready_line().contains(" · water "),
			"the ready line says the water (%s)" % strip.ready_line())
	# the dress: the element's colour on the basic shirt, no coat, no hat, nothing at the neck or on the shoulders
	var app := p.appearance
	if app != null:
		var outfit: Dictionary = app.look.get("outfit", {})
		var shirt: Dictionary = outfit.get("shirt", {})
		var want_col := "#" + MatchSetup.color("water").to_html(false)
		var bare := ["outer", "head", "vest", "accessories.neck", "accessories.shoulder", "accessories.wrap"].all(
				func(s: String) -> bool: return app.body.part_meshes("outfit:" + s).is_empty())
		_expect(String((shirt.get("colors", {}) as Dictionary).get("0", "")) == want_col and bare
				and not app.body.part_meshes("outfit:shirt").is_empty() and not app.body.part_meshes("outfit:legs.lower").is_empty(),
				"dressed for the ring in the element's colour: the basic shirt %s, trousers, no coat, hat or gear (%s)" % [want_col,
				shirt])
	else:
		_expect(true, "no appearance on this body (use_appearance off): no dress to check")
	# LMB: nothing (no weapon to fire; the casts are RMB's)
	var sp := p.hotbar.spell
	var st := c.state
	await _action(&"fire")
	await _ticks(5)
	_expect(p.hotbar.spell == sp and c.state == st and p.weapon == null, "LMB does nothing in the arena")
	# the arena's first-time help: its own topics, the moves' first
	var how := p.get_node_or_null(^"HowTo") as HowTo
	if how != null:
		how.cfg_path = "user://how_to_ring_test.cfg"
		how.reset()
		how.enabled = true
		var up := await _until(func() -> bool: return how.current != "", 4.0)
		_expect(up < INF and how.current == "elements" and how._steps.size() == 4,
				"the arena's first-time help: the moves' panel first (%s)" % how.current)
		how.enabled = false
		how._panel.visible = false
		how.current = ""
		DirAccess.remove_absolute(ProjectSettings.globalize_path(how.cfg_path))


# ---------------------------------------------------------------- the match bar
func _match() -> void:
	var stub: StubMatch = null
	if get_nodes_in_group(MatchBar.GROUP).is_empty():
		stub = StubMatch.new()
		stub.name = "StubMatch"
		stub.add_to_group(MatchBar.GROUP)
		lvl.add_child(stub)
	await _ticks(3)
	var mb := hud.match_bar
	var m := mb.match_node()
	var l := mb.lines()
	var want_round := "ROUND %d" % int(m.get(&"round")) if m != null else ""
	_expect(mb.visible and String(l.round) == want_round and String(l.time) != "" and (mb._round as Label).text == want_round,
			"the match bar shows the match's round and time (%s, %s%s)" % [l.round, l.time, "; a stub" if stub != null else ""])
	if stub != null:
		_expect(String(l.time) == "1:40" and String(l.score).begins_with("You ● ○"), "the stub's time and score (%s; %s)" % [l.time, l.score])


# ---------------------------------------------------------------- no target cues
func _canvas_items() -> Dictionary:
	var out := {}
	for n in root.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		var at := Vector2.INF
		if ci is Control:
			at = (ci as Control).global_position
		elif ci is Node2D:
			at = (ci as Node2D).global_position
		out[ci.get_instance_id()] = [at, ci.is_visible_in_tree(), String(ci.get_path())]
	return out


static func _moved(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k: int in b:
		if not a.has(k):
			out[k] = "new " + String(b[k][2])
		elif Vector2(a[k][0]).distance_to(Vector2(b[k][0])) > 0.5 or bool(a[k][1]) != bool(b[k][1]):
			out[k] = String(b[k][2])
	return out


func _no_cues() -> void:
	var faction := "ring_team_b" if not NpcFactions.get_faction("ring_team_b").is_empty() else "french_marine"
	var at := lvl.ring.spawn(1).origin
	var sq := NpcSquad.spawn(lvl, faction, 1, at, {"element": "earth", "tactics": "bend", "weapon": "", "sidearm": "",
			"seed": opts_seed})
	var got := await _until(func() -> bool: return not sq.fighters().is_empty(), 4.0)
	var n: NpcFighter = sq.fighters()[0] if not sq.fighters().is_empty() else null
	_expect(got < INF and n != null, "a bot on the other side (%s)" % faction)
	if n == null:
		return
	n.held = true
	var still := n.global_position
	var hold := func() -> void:
		if is_instance_valid(n):
			n.global_position = still
			n.velocity = Vector3.ZERO
	physics_frame.connect(hold)
	await _secs(1.0)
	var a := _canvas_items()
	await _secs(1.0)
	var b := _canvas_items()
	physics_frame.disconnect(hold)
	var steady := _moved(a, b)          # (what changes by itself in a second: not the bot's doing)
	var t := 0.0
	var dir := Vector3(0.0, 0.0, 1.0)
	while t < 1.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if is_instance_valid(n):
			n.global_position = still + dir * 10.0 * clampf(t, 0.0, 1.0)
			n.velocity = Vector3.ZERO
	await _ticks(2)
	var moved := Vector2(n.global_position.x - still.x, n.global_position.z - still.z).length()
	var c2 := _canvas_items()
	var tracking: Array = []
	var changed := _moved(b, c2)
	for k: int in changed:
		if not steady.has(k):
			tracking.append(changed[k])
	_expect(moved >= 9.5 and tracking.is_empty(),
			"the bot moved %.1f m in 1 s: no CanvasItem moved, showed or hid with it (%d items; %s)" % [moved, c2.size(), tracking])
	for path: String in ["res://scripts/ui/bend_strip.gd", "res://scripts/ui/match_bar.gd"]:
		var src := FileAccess.get_file_as_string(path)
		var code := "\n".join(Array(src.split("\n")).filter(func(ln: String) -> bool: return not ln.strip_edges().begins_with("#")))
		_expect(not code.contains("unproject_position") and not code.contains("global_position") and not code.contains("NpcSenses")
				and not code.contains("global_transform"), "%s reads no body's position" % path.get_file())
	n.queue_free()


# ---------------------------------------------------------------- the words
func _words() -> void:
	var re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))
	var texts: Array[String] = [FrontierHUD.ARENA_HELP]
	for id: String in HowTo.ARENA_TOPICS:
		texts.append(String(HowTo.TOPICS[id].title))
		for s in HowTo.TOPICS[id].steps:
			texts.append(String(s))
	for path: String in ["res://scripts/ui/bend_strip.gd", "res://scripts/ui/match_bar.gd"]:
		var lit := RegEx.create_from_string("\"([^\"\\\\]|\\\\.)*\"")
		for ln in FileAccess.get_file_as_string(path).split("\n"):
			if ln.strip_edges().begins_with("#"):
				continue
			for mt in lit.search_all(ln):
				texts.append(mt.get_string())
	for l in hud.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var bad: Array = []
	for t in texts:
		for mt in re.search_all(t):
			bad.append(mt.get_string())
	_expect(bad.is_empty(), "the arena's HUD lines, the strip's, the bar's and the arena help hold none of the show's words (%d texts%s)"
			% [texts.size(), "" if bad.is_empty() else ": %s" % [bad]])


# ---------------------------------------------------------------- the body
func _body() -> void:
	p.pitch = -0.15
	await _secs(0.5)
	var casts: Array = []
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append(m))
	c.held_override = true
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL or not casts.is_empty(), 5.0)
	c.held_override = false
	await _until(func() -> bool: return not casts.is_empty(), 2.0)
	_expect(not casts.is_empty(), "a cast: the lock held (full in %.2f s), let go: %s" % [full, casts])
	await _secs(1.0)
	# a walk forward
	var p0 := p.global_position
	Input.action_press(&"move_forward")
	await _secs(1.0)
	Input.action_release(&"move_forward")
	await _secs(0.6)
	_expect(Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length() > 1.5,
			"he walks (%.2f m in 1 s)" % Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length())
	# a jump
	var y0 := p.global_position.y
	var top := y0
	Input.action_press(&"jump")
	await _ticks(2)
	Input.action_release(&"jump")
	for i in 60:
		await physics_frame
		top = maxf(top, p.global_position.y)
	_expect(top - y0 > 0.3, "he jumps (%.2f m)" % (top - y0))
	await _until(func() -> bool: return p.is_on_floor(), 2.0)
	await _secs(0.5)
	# a knock under the ragdoll's: the knocked slide, the carry not the legs' pace
	_face_centre()
	BendStatus.knock(p, Vector3(6.0, 0.0, 0.0) * _centre_sign(), null)
	await _ticks(4)
	var slide := c.pose.knock
	var carry := p.horizontal_speed()
	var pace := p.local_move.length()
	_expect(slide == "slide" and String(c.pose.knock_clip()) == "own-bend-knock-slide" and carry > 3.0 and pace < 1.0,
			"a 6 m/s knock: the knocked slide plays (%s), the legs' pace %.2f m/s while carried at %.1f" % [slide, pace, carry])
	await _until(func() -> bool: return c.pose.knock == "", 4.0)
	_expect(c.pose.knock == "", "and it ends")
	await _secs(0.5)
	BendStatus.knock(p, Vector3(0.0, 8.0, 0.0), null)
	var air := await _until(func() -> bool: return c.pose.knock == "air", 0.5)
	_expect(air < INF and p.is_launched(), "a knock-up: the airborne clip (%s)" % c.pose.knock_clip())
	await _until(func() -> bool: return not p.is_launched(), 4.0)
	await _until(func() -> bool: return c.pose.knock == "", 4.0)
	_expect(c.pose.knock == "" and not p.is_launched(), "landed, and the clip ends")
	await _secs(0.5)
	# 16 m/s: thrown down, and up again. (With the match in, RingRules is BendKnock.rules: it scales every knock and caps
	# its push at max_push_m, so no knock of a match reaches ragdoll_mps; the body's own way down and up is checked with
	# the ring's rules stood aside for this one knock, the ring's ragdoll_mps kept.)
	_face_centre()
	var rag := PlayerRagdoll.of(p)
	var ring_rules: Object = BendKnock.rules
	BendKnock.rules = null
	BendStatus.knock(p, Vector3(maxf(16.0, BendKnock.ragdoll_mps + 1.0), 1.0, 0.0) * Vector3(_centre_sign(), 1.0, 1.0), null)
	BendKnock.rules = ring_rules
	var down := await _until(func() -> bool: return rag.is_down(), 1.0)
	_expect(down < INF, "a 16 m/s knock throws him down (%.2f s)" % down)
	var up := await _until(func() -> bool: return not rag.is_down() and p.kneeling == null, 15.0)
	_expect(up < INF, "he gets up (%.1f s)" % up)
	await _secs(1.0)
	p0 = p.global_position
	Input.action_press(&"move_forward")
	await _secs(1.0)
	Input.action_release(&"move_forward")
	_expect(Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length() > 1.5 and not p.is_dead and p.weapon == null,
			"and walks again, no weapon (%.2f m)" % Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length())


## Toward the deck's centre from where he stands (+1 / -1 along x).
func _centre_sign() -> float:
	return 1.0 if p.global_position.x < lvl.ring.center().x else -1.0


func _face_centre() -> void:
	p.yaw = -PI / 2.0 if _centre_sign() > 0.0 else PI / 2.0
	p.rotation.y = p.yaw
