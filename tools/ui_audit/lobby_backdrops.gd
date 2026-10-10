extends SceneTree
## The lobby's backdrop plates (the broadcast menus, 2026-10-10): the ring's own scene (scenes/ring.tscn) at noon with nobody
## on the deck, taken from the lobby camera (FighterWorld.LOBBY_CAM, LOBBY_AT, LOBBY_FOV: where the live fighter's own camera
## stands, so the fighter drawn over the plate stands on its deck), with the far blur of a long lens. One plate per element:
## your own end's gate and banners behind. Written to assets/ui/menu/lobby_<element>.jpg (1920 x 1080, drawn from a
## 3840 x 2160 render) and the sun's direction in the camera's frame printed, so the live fighter's light follows it.
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/lobby_backdrops.gd -- [els=fire,earth,water,air] [out=res://assets/ui/menu]
##         [look=classic|soft]
## look=soft: the ring under the Look setting's Soft (SoftWorld: the study's light and colours), written to lobby_soft_<element>.jpg
## (the main menu shows those in Soft: MainMenu.lobby_plate).
## Needs a window (the ring is drawn); not headless. The ring is drawn off-window through the mock's Stage (a SubViewport, as
## tools/ring/palette_shots.gd does), so a window behind another one still renders. Read-only on the game; GameSettings
## goes to the tool's own cfg; the player's user://how_to.cfg is kept and given back (CaptureKit.keep: on disk, so a run the
## timeout killed is healed by the next run).

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const Stage := preload("res://tools/ui_audit/ring_stage.gd")
const OWN_CFG := "user://lobby_backdrops.cfg"
const LIMIT_S := 500.0
## Each element's lobby opponent (the dressing's banners show both ends' elements).
const FOE_OF := {"fire": "water", "earth": "air", "water": "fire", "air": "earth"}

var els: Array = ["fire", "earth", "water", "air"]
var out := "res://assets/ui/menu"
var look := "classic"
const HOWTO := "user://how_to.cfg"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		match kv.get_slice("=", 0):
			"els": els = Array(kv.get_slice("=", 1).split(",", false))
			"out": out = kv.get_slice("=", 1)
			"look": look = kv.get_slice("=", 1)
	if not CaptureKit.begin(self, "lobby_backdrops"):
		return
	auto_accept_quit = false
	CaptureKit.keep([HOWTO])
	seed(1750)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup._aim_help = "strong"
	SoftLook.override = SoftLook.SOFT if look == "soft" else SoftLook.CLASSIC
	RingRules.rule_set_override = "stock"
	InputSetup.ensure()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("LOBBY BACKDROPS watchdog")
		_end(2))
	_run.call_deferred()


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		print("LOBBY BACKDROPS a close request at %d ms: the run goes on" % Time.get_ticks_msec())


func _end(code := 0) -> void:
	paused = false
	Engine.time_scale = 1.0
	RingRules.rule_set_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	print("LOBBY BACKDROPS DONE code=%d" % code)
	quit(code)


func _run() -> void:
	await process_frame
	var st := Stage.new(self, ProjectSettings.globalize_path("user://lobby_backdrops_work"))
	for el: String in els:
		if not await st.load_ring(el, String(FOE_OF[el])):
			print("LOBBY BACKDROPS: no ring for ", el)
			continue
		# nobody on the deck: the player and the bot hidden
		st.player.visible = false
		st.foe.visible = false
		var me := st.at(-1.0)
		st.place(st.foe, st.at(12.0, 5.0), -st.deck_way())
		await st._frames(30)
		st._views(Vector2i(3840, 2160))
		st.freeze()
		# the lobby camera, as FighterWorld has it relative to the fighter's feet (ring axes: x along the deck, z across, y up)
		var cam := st.at(-1.0 + FighterWorld.LOBBY_CAM.x, FighterWorld.LOBBY_CAM.z, FighterWorld.LOBBY_CAM.y)
		var aim := st.at(-1.0 + FighterWorld.LOBBY_AT.x, FighterWorld.LOBBY_AT.z, FighterWorld.LOBBY_AT.y)
		var img := await st.shot("", Vector2i(3840, 2160), cam, aim, FighterWorld.LOBBY_FOV, 6.2)
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(out.path_join(("lobby_soft_%s.jpg" if look == "soft" else "lobby_%s.jpg") % el))
		img.save_jpg(path, 0.92)
		print("LOBBY BACKDROPS wrote ", path)
		# the sun in the lobby's frame (ring axes), where it travels, so FighterWorld's sun can follow it
		var rig := st.lvl.environment_rig
		var sun: Light3D = rig.get_sun() if rig != null else null
		if sun != null:
			var fwd := st.ring.global_basis.inverse() * (-sun.global_basis.z)
			print("LOBBY BACKDROPS sun travels (ring axes) ", fwd, " energy ", sun.light_energy, " color ", sun.light_color)
		var env := rig.get_environment() if rig != null else null
		if env != null:
			print("LOBBY BACKDROPS env exposure ", env.tonemap_exposure, " ambient ", env.ambient_light_color, " sky contrib ",
					env.ambient_light_sky_contribution, " energy ", env.ambient_light_energy)
		print("LOBBY BACKDROPS figure spot ", me)
		st.thaw()
		st.release()
	_end(0)
