extends SceneTree
## Round 3 BOTS' review images for the owner's eye (smash_r3 spec §11; the % ring's Practice and lessons, a hard bot keeping a
## recovering player off), the ring at noon at 1280 x 720, the gate on by the tests' stand-in RingRules (tests/npc/
## r3_standins.gd: the %, the hits and the hang are PERCENT's and MOVE's, stood in until they merge). Windowed (it draws):
##   Godot --path . --resolution 1280x720 -s tools/ring/r3_bots_shots.gd -- out=<dir>
## Writes <dir>/r3_bots_practice_panel.png (the counter white on a true 3-string, the readout with "steered"),
## r3_bots_practice_panel_free.png (grey: the dummy was free), r3_bots_lesson_<card>.png (the nine cards, String for earth and
## for water, and the stock guard card) and r3_bots_edge_trap.png (a hard fire bot at the lip with its lock filled, the player
## hanging below: one frame). Ends with R3 BOTS SHOTS DONE.

const Standins := preload("res://tests/npc/r3_standins.gd")
const OWN_CFG := "user://r3_bots_shots.cfg"

var out := ""
var lvl: RingLevel
var p: FrontierPlayer
var mode: RingMode
var rules: Standins.FakeRules


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup._aim_help = "strong"
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.light = "noon"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	for i in 3:
		RenderingServer.force_draw(true)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join(name + ".png"))
	print("  wrote %s.png" % name)


func _run() -> void:
	await _frames(20)
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	p = lvl.player
	p.ignore_mouse_capture = true
	for i in 300:
		if mode.phase == "FIGHT":
			break
		await physics_frame
	await _frames(30)
	mode.rules.live = false
	rules = Standins.install_rules()
	NpcRingMind.predict_override = Standins.FakePredict.new(lvl.ring)
	await _panel()
	await _cards()
	await _edge_trap()
	NpcRingMind.predict_override = null
	Standins.uninstall(rules)
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	print("R3 BOTS SHOTS DONE")
	quit(0)


## Practice's panel: a true 3-string white with its readout, then grey once the dummy is free.
func _panel() -> void:
	var ring := lvl.ring
	var foe := mode.foe
	var e := 1 - mode.player_end
	foe.global_position = ring.to_global(Vector3(RingArena.side_sign(e) * 6.0, ring.top() + 0.05, 0.0))
	p.global_position = ring.to_global(Vector3(RingArena.side_sign(e) * -2.0, ring.top() + 0.05, 0.0))
	var to := NpcRingMind.flat_dir(p.global_position, foe.global_position)
	p.yaw = atan2(-to.x, -to.z)
	p.rotation.y = p.yaw
	var ctl := mode.practice_ctl
	MatchSetup.foe_pct = 30.0
	ctl._apply_pct()
	await _frames(10)
	var fid := foe.get_instance_id()
	rules.f_steer[fid] = 12.0
	for n in [1, 2, 3]:
		rules.f_string[fid] = n
		rules.stun_for(foe, 0.6)
		rules.launched.emit(foe, to * 6.0 + Vector3.UP * 3.0, 0.55, p, "rock_jab/pebbles" if n < 3 else "jab/pop")
		rules.pct_changed.emit(foe, 30.0 + 5.0 * n, 5.0 if n < 3 else 3.0)
		await _frames(8)
	rules.launched.emit(foe, to * 9.2 + Vector3.UP * 5.0, 0.55, p, "stone_form/spike")
	rules.pct_changed.emit(foe, 57.0, 14.0)
	await _frames(20)
	await _shot("r3_bots_practice_panel")
	rules.f_stun.erase(fid)
	for i in 30:
		await physics_frame
	await _shot("r3_bots_practice_panel_free")
	MatchSetup.foe_pct = -1.0


## The cards (LessonCard over the practice): the nine and the stock guard card.
func _cards() -> void:
	_clear_panel()
	RingLessons._ensure_keys()
	var rl := RingLessons.new()
	rl.scheme = "keys"
	rl.element = "earth"
	var card := LessonCard.install(root)
	await _frames(2)
	var all: Array = RingLessons.data().get("lessons", [])
	var want := ["pct", "out", "jumps", "dodge", "back", "edge", "string", "steer", "keep_off"]
	var total := want.size() + 1
	var n := 0
	for l: Dictionary in all:
		if String(l.id) == "guard":
			rl.element = "water"
			card.show_lesson(1, total, String(l.title), String(RingLessons.by_of(l, "keys").line), RingLessons.word("skip"))
			await _frames(30)
			await _shot("r3_bots_lesson_guard_stock")
			rl.element = "earth"
	for id: String in want:
		for l: Dictionary in all:
			if String(l.id) != id:
				continue
			n += 1
			card.show_lesson(n + 1, total, String(l.title), rl.line_spec(l), RingLessons.word("skip"))
			await _frames(30)
			await _shot("r3_bots_lesson_" + id + ("_earth" if id == "string" else ""))
			if id == "string":
				rl.element = "water"
				card.show_lesson(n + 1, total, String(l.title), rl.line_spec(l), RingLessons.word("skip"))
				await _frames(30)
				await _shot("r3_bots_lesson_string_water")
				rl.element = "earth"
	card.hide_card()
	await _frames(20)
	card.queue_free()
	rl.free()


## Practice's numbers off the screen (the cards and the edge on their own).
func _clear_panel() -> void:
	var ctl := mode.practice_ctl
	ctl.counter = {"hits": 0, "pct": 0.0, "free": false, "until": -INF, "at": -INF}
	ctl.best = {"hits": 0, "pct": 0.0}
	ctl.readout = ""


## A hard fire bot keeping the player off: he hangs below its end's lip (a first grab's safety left), it stands back from the
## lip with its lock filled and held for his safety's end.
func _edge_trap() -> void:
	_clear_panel()
	var ring := lvl.ring
	var e := 1 - mode.player_end
	var sg := RingArena.side_sign(e)
	if mode.foe != null:
		mode.foe.held = true
		mode.foe.global_position = ring.global_position + Vector3(0.0, 40.0, 70.0)
	var lip := ring.to_global(Vector3(sg * ring.half_l(), ring.top(), 0.0))
	var out := (ring.axis() * sg).normalized()
	var at := lip - out * 2.5 + ring.global_basis.z.normalized() * 1.8
	at.y = ring.deck_y()
	var sq := NpcSquad.spawn(current_scene, "ring_team_b", 1, at, {"element": "fire", "tactics": "bend", "weapon": "",
			"sidearm": "", "skill": "hard", "seed": 1750, "y": ring.deck_y(), "face": lip})
	var f: NpcFighter = sq.members[0]
	f.no_death = true
	f.flees = false
	f.calm_s = INF
	var b := f.brain.bending
	b.bounds_fn = mode.rules.bounds_fn_for(f)
	b.edge_fn = mode.rules.edge_along
	b._grace_until = 0.0
	f.brain.told(p, p.global_position)
	f.brain.target = p
	# (the player hanging: his feet 2 m under the lip, 0.35 m out, facing the deck; a stand-in RingMoves says so)
	var hang := lip + out * 0.35 + Vector3.DOWN * 2.0
	p.set_physics_process(false)
	p.global_position = hang
	p.yaw = atan2(out.x, out.z)
	p.rotation.y = p.yaw
	p.pitch = -0.12
	var fm := Standins.FakeMoves.put(p, ring, {"pos": hang, "element": "earth"})
	fm.hanging = true
	fm.safe_left = 30.0
	p.global_position = hang
	for i in 150:
		b.mind()._edge_roll["on"] = true          # (this frame is the 0.85 that keeps him off)
		await physics_frame
		p.global_position = hang
		if b.casting != "" and b.fill >= 1.0:
			break
	await _frames(10)
	await _shot("r3_bots_edge_trap")
	print("  (edge trap: the bot in %s, casting '%s' at %.2f full, %.1f m from the lip)" % [NpcRingMind.STATE_NAMES[b.mind().state],
			b.casting, b.fill, NpcRingMind.flat_d(f.global_position, lip)])
