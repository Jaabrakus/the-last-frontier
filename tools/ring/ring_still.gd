extends SceneTree
## The ring's own loading still (improvement round 2, the owner: the ring's loading screen showed the open world's painting and
## its lore; LoadingScreen.ring_entry, data/ring/screens.json "loading"): the dressed ring (RingDressing, RingLook) with its two
## competitors in their ring dress at their ends (a practice: the dummy stands), from a few cameras at the chosen light.
## Windowed (it draws):
##   Godot --path . -s tools/ring/ring_still.gd -- out=<dir> [light=golden] [player=earth] [foe=fire] [pick=<view>]
## Writes <dir>/ring_still_<view>.png (1920 x 1080) for each view and, with pick=<view>, that one to
## res://assets/ui/loading/ring_still.jpg (the game's still). Ends with RING STILL DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1920
const H := 1080
## [from, at, fov] per view (the ring's own space: x along the deck, the player's end at -x).
const VIEWS := {
	"stand": [Vector3(-3.0, 6.2, 17.5), Vector3(0.5, 0.6, -1.0), 50.0],
	"corner": [Vector3(-24.0, 9.0, 16.0), Vector3(1.0, 0.0, 0.0), 52.0],
	"behind": [Vector3(-16.5, 2.6, 3.4), Vector3(8.0, 1.2, -0.8), 58.0],
	"low": [Vector3(-9.0, 1.1, 8.5), Vector3(3.0, 1.6, -1.0), 60.0],
}
const GAME_STILL := "res://assets/ui/loading/ring_still.jpg"


func _initialize() -> void:
	var out := "user://ring_still"
	var light := "golden"
	var el := "earth"
	var foe_el := "fire"
	var pick := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("light="):
			light = a.substr(6)
		elif a.begins_with("player="):
			el = a.substr(7)
		elif a.begins_with("foe="):
			foe_el = a.substr(4)
		elif a.begins_with("pick="):
			pick = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = el
	MatchSetup.light = light
	MatchSetup.set_practice(foe_el, "stand")
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred(out, pick)


func _run(out: String, pick: String) -> void:
	for i in 4:
		await process_frame
	var lvl := current_scene as RingLevel
	if lvl == null:
		print("RING STILL FAILED: no ring")
		quit(1)
		return
	# (the level builds a part a frame behind its loading metas; then the effects warm)
	var t := 0
	while t < 1200 and (float(lvl.get_meta(&"loading_progress", 1.0)) < 1.0 or bool(lvl.get_meta(&"loading_hold", false))):
		await process_frame
		t += 1
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
	var p := lvl.player
	if p != null and p.hud != null:
		p.hud.visible = false
	for i in 120:
		await process_frame
	var ring := lvl.ring
	for v: String in VIEWS:
		var spec: Array = VIEWS[v]
		var from: Vector3 = ring.to_global(spec[0]) if ring != null else spec[0]
		var at: Vector3 = ring.to_global(spec[1]) if ring != null else spec[1]
		view.camera.fov = float(spec[2])
		view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
		for i in 60:
			await process_frame
		# (a window the Mac stops drawing, covered or on another Space, leaves the view stale: drawn by force)
		for i in 8:
			RenderingServer.force_draw(false)
			await process_frame
		var img: Image = view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(out.path_join("ring_still_%s.png" % v))
		print("  still ", v)
		if v == pick:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GAME_STILL.get_base_dir()))
			img.save_jpg(ProjectSettings.globalize_path(GAME_STILL), 0.88)
			print("  the game's still: ", v)
	print("RING STILL DONE")
	quit(0)
