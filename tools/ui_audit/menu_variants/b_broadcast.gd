extends SceneTree
## Menu style B, "Arena broadcast" (a mock for the owner's lineup of four menu styles; nothing in the game changes): the
## Tidebreak league as a TV sports broadcast. Bold condensed type with big numerals, element-coloured plates, lower-third
## panels and a results board; the main menu is a lobby where your fighter, in the element's ring dress, stands on the deck
## beside the menu.
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 \
##       -s tools/ui_audit/menu_variants/b_broadcast.gd -- part=render|ui|all|probe [out=DIR]
##   render   the ring staged and taken (b_broadcast/stage.gd) into DIR/renders/
##   ui       the screens built over those renders and saved: DIR/main.png, match.png, pause.png, end.png,
##            main_720.png, pause_720.png (and main_<element>.png for the other three elements)
## Every word is the game's own where it has one (MatchSetup, KitWords, data/ring/*.json read at run time); the new
## Fighter area's words follow docs/skill_tree_design.md. GameSettings goes to its own cfg (deleted at the end) and
## user://how_to.cfg is put back byte for byte.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const Stage := preload("res://tools/ui_audit/ring_stage.gd")
const Screens := preload("res://tools/ui_audit/menu_variants/b_broadcast/screens.gd")
const OUT := "res://artifacts/ui_audit/menu_variants/b_broadcast"
const OWN_CFG := "user://b_broadcast_mock.cfg"
const HOWTO := "user://how_to.cfg"
const LIMIT_S := 600.0
## Each element's lobby opponent (the dressing's banners show both ends' elements).
const FOE_OF := {"fire": "water", "earth": "air", "water": "fire", "air": "earth"}

var out := OUT
var part := "all"
var els: Array = ["fire", "earth", "water", "air"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		match kv.get_slice("=", 0):
			"out": out = kv.get_slice("=", 1)
			"part": part = kv.get_slice("=", 1)
			"els": els = Array(kv.get_slice("=", 1).split(","))
	out = ProjectSettings.globalize_path(out)      # (OUT is a res:// path; a clone or a worktree writes under its own artifacts)
	if not CaptureKit.begin(self, "b_broadcast"):
		return
	auto_accept_quit = false                  # (stray close requests reach these tool windows: the run goes on)
	DisplayServer.window_set_title("Menu style B: arena broadcast (mock)")
	CaptureKit.keep([HOWTO])
	seed(1750)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup._aim_help = "strong"
	RingRules.rule_set_override = "stock"
	InputSetup.ensure()
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("BROADCAST watchdog")
		_end(2))
	_run.call_deferred()


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		print("BROADCAST a close request at %d ms: the run goes on" % Time.get_ticks_msec())


func _end(code := 0) -> void:
	paused = false
	Engine.time_scale = 1.0
	RingRules.rule_set_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	print("BROADCAST DONE code=%d" % code)
	quit(code)


func _run() -> void:
	await process_frame
	match part:
		"probe":
			await _probe()
		"render":
			await _render()
		"ui":
			await _ui()
		"all":
			await _render()
			await _ui()
	_end(0)


# ---------------------------------------------------------------- renders
func _probe() -> void:
	var st := Stage.new(self, out.path_join("probe"))
	if not await st.load_ring("fire", "water"):
		print("BROADCAST: no ring")
		return
	var w := st.deck_way()
	st.place(st.player, st.at(-1.0), -w)
	st.place(st.foe, st.at(9.0, 3.0), -w)
	await st._frames(30)
	st._views(Vector2i(800, 450))
	st.freeze()
	var P := st.at(-1.0)
	await st.shot("a_front_gate", Vector2i(800, 450), st.at(-4.6, -0.9, 1.15), st.at(-1.0, 1.2, 1.0), 40.0, 4.5)
	await st.shot("b_front_gate_wide", Vector2i(800, 450), st.at(-5.2, -1.4, 1.0), st.at(-1.0, 1.6, 1.05), 46.0, 5.0)
	await st.shot("c_back_end", Vector2i(800, 450), st.at(3.0, 0.8, 1.3), st.at(-1.0, -1.0, 1.0), 40.0, 4.5)
	await st.shot("d_side", Vector2i(800, 450), st.at(-1.6, -4.2, 1.2), st.at(-0.4, 0.0, 1.0), 40.0, 4.5)
	await st.shot("e_deck_high", Vector2i(800, 450), st.at(-10.0, 6.0, 7.5), st.at(1.0, 0.0, 0.5), 58.0)
	await st.shot("f_behind", Vector2i(800, 450), st.at(-6.5, 0.65, 2.25), st.at(5.0, 0.0, 1.1), 62.0)
	print("BROADCAST probe at ", P)
	st.thaw()


## Per element: the lobby (your fighter on the deck at the right third, your own end's gate and banners behind, soft)
## and the cut-out; for fire also the three ring frames (a match under way, its end, the deck wide).
func _render() -> void:
	var st := Stage.new(self, out.path_join("renders"))
	for el: String in els:
		if not await st.load_ring(el, String(FOE_OF[el])):
			print("BROADCAST: no ring for ", el)
			continue
		var w := st.deck_way()
		var side := (st.ring.global_basis * Vector3(0.0, 0.0, 1.0)).normalized()
		# the lobby: the camera on +X looking back at your end; you face it, turned a little toward the menu (+Z)
		var me := st.at(-1.0)
		var cam := st.at(3.4, 0.0, 1.0)
		var to_cam := (cam - me).normalized()
		st.place(st.player, me, to_cam.rotated(Vector3.UP, deg_to_rad(-24.0)))
		st.place(st.foe, st.at(12.0, 5.0), -w)
		st.foe.visible = false
		await st._frames(40)
		st._views(Vector2i(1600, 900))
		st.freeze()
		await st.cutout("lobby_" + el, Vector2i(3200, 1800), cam, st.at(-1.0, 0.78, 1.0), 30.0, 6.2, true)
		# the cut-out for the cards and the scoreboard: in front, a little to the side, the whole body
		var cc := me + to_cam.rotated(Vector3.UP, deg_to_rad(-10.0)) * 3.6 + Vector3.UP * 0.95
		await st.cutout("card_" + el, Vector2i(720, 1080), cc, me + Vector3.UP * 0.9, 33.0)
		if el == "fire":
			st.thaw()
			st.foe.visible = true
			st.place(st.player, st.at(-3.0), w)
			st.place(st.foe, st.at(4.0, 0.6), -w)
			await st._frames(40)
			st.freeze()
			await st.shot("frame_pause", Vector2i(1600, 900), st.at(-6.5, 0.65, 2.25), st.at(5.0, 0.0, 1.1), 62.0)
			await st.shot("frame_setup", Vector2i(1600, 900), st.at(-10.0, 6.0, 7.5), st.at(1.0, 0.0, 0.5), 58.0)
			st.thaw()
			st.place(st.foe, st.at(40.0, 40.0), -w)
			st.place(st.player, st.at(2.0, -1.0), -w)
			await st._frames(30)
			st.freeze()
			await st.shot("frame_end", Vector2i(1600, 900), st.at(13.0, -6.5, 8.0), st.at(-2.0, 0.5, 0.0), 58.0)
		st.thaw()
		st.release()
		print("BROADCAST side ", side)


# ---------------------------------------------------------------- the screens
## The kept setup the screens show: fire against water, normal, Lives, best of 3, noon.
func _setup() -> void:
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "normal"
	MatchSetup.rules_choice = "stock"
	MatchSetup.games_n = 3
	MatchSetup.rounds_to_win = 2
	MatchSetup.light = "noon"
	MatchSetup.format = "1v1"


## A screen built by `build` (a Callable of the layout Control) at `px`, saved as `name`.png: laid out at 1600 x 900 and
## scaled to the window, as the game's own menu fits itself (MainMenu._fit_menu_layout).
func _take(name: String, px: Vector2i, build: Callable) -> void:
	var vp := SubViewport.new()
	vp.size = px
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var base := Control.new()
	vp.add_child(base)
	base.position = Vector2.ZERO
	base.size = Vector2(px)
	var bg := ColorRect.new()
	bg.color = Color("060c17")
	bg.size = Vector2(px)
	base.add_child(bg)
	var s := minf(px.x / 1600.0, px.y / 900.0)
	var lay := Control.new()
	lay.name = "Layout"
	base.add_child(lay)
	lay.position = Vector2.ZERO
	lay.scale = Vector2(s, s)
	lay.size = Vector2(px) / s
	lay.clip_contents = true
	build.call(lay)
	for i in 6:
		await process_frame
		RenderingServer.force_draw(false)
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join(name + ".png"))
	print("BROADCAST SCREEN %s %dx%d" % [name, img.get_width(), img.get_height()])
	vp.queue_free()
	await process_frame


func _ui() -> void:
	_setup()
	var sc := Screens.new(out.path_join("renders"))
	var big := Vector2i(1600, 900)
	var small := Vector2i(1280, 720)
	await _take("main", big, func(l: Control) -> void: sc.main_menu(l, "fire"))
	await _take("match", big, func(l: Control) -> void: sc.match_setup(l, "fire", "water"))
	await _take("pause", big, func(l: Control) -> void: sc.pause(l, "fire", "water"))
	await _take("end", big, func(l: Control) -> void: sc.end_screen(l, "fire", "water"))
	await _take("main_720", small, func(l: Control) -> void: sc.main_menu(l, "fire"))
	await _take("pause_720", small, func(l: Control) -> void: sc.pause(l, "fire", "water"))
	for e: String in ["earth", "water", "air"]:
		if FileAccess.file_exists(out.path_join("renders/lobby_%s.png" % e)):
			MatchSetup.element = e
			await _take("main_" + e, big, func(l: Control) -> void: sc.main_menu(l, e))
	MatchSetup.element = "fire"
