extends SceneTree
## Stills of a team format's ring (the owner, 2026-10-10: 2v2 and 4v4 on decks "big enough"; docs/tidebreak/team_formats_and_arenas.md):
## the dressed ring at the format's size with every fighter of both sides, at the countdown (all at their spawns) and a few
## seconds into the fight (the bots under the team coach; the player stands in his slot). Every CanvasLayer hidden.
## Windowed (it draws; a normal window, never on top):
##   Godot --path . -s tools/ring/team_format_shots.gd -- format=4v4 out=<dir> [light=golden] [fight_s=7]
## Writes <dir>/team_<format>_<view>_<moment>.png (1600 x 900): views "above" (the whole deck from over the stands) and
## "corner"; moments "countdown" and "fight". Ends with TEAM SHOTS DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1600
const H := 900
const OWN_CFG := "user://team_format_shots.cfg"

var out := "user://team_format_shots"
var fmt := "4v4"
var fight_s := 7.0


func _initialize() -> void:
	var a := CaptureKit.args({"format": "4v4", "out": out, "light": "golden", "fight_s": "7"})
	fmt = String(a["format"]) if String(a["format"]) in MatchSetup.FORMATS else "4v4"
	out = String(a["out"])
	fight_s = float(a["fight_s"])
	CaptureKit.window()
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.set_match()
	MatchSetup.format = fmt
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.mates = []
	MatchSetup.light = String(a["light"])
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _views(ring: RingArena) -> Dictionary:
	var hl := ring.half_l()
	var hw := ring.half_w()
	return {
		"above": [Vector3(0.0, 14.0 + hl * 0.55, hw + 8.0 + hl * 0.75), Vector3(0.0, 0.0, -1.0), 50.0],
		"corner": [Vector3(-hl - 6.0, 7.5, hw + 7.0), Vector3(hl * 0.15, 0.5, 0.0), 55.0],
	}


func _run() -> void:
	for i in 4:
		await process_frame
	var lvl := current_scene as RingLevel
	var loaded: bool = lvl != null and await CaptureKit.wait_loaded(self, lvl)
	if not loaded:
		print("TEAM SHOTS FAILED: no ring")
		return _quit(1)
	var mode := RingMode.find(self)
	if mode == null:
		print("TEAM SHOTS FAILED: no match")
		return _quit(1)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
	await CaptureKit.frames(self, 30)
	_hide_layers()
	# the countdown: everyone at the spawns
	await CaptureKit.until(self, func() -> bool: return mode.phase == "COUNTDOWN" and mode.phase_t > 0.5, 20.0)
	mode.phase_t = -60.0                       # (held in the countdown while the stills are taken)
	await _shots(view, lvl.ring, "countdown")
	mode.phase_t = mode.countdown_s()
	await CaptureKit.until(self, func() -> bool: return mode.phase == "FIGHT" and mode.phase_t >= fight_s, fight_s + 20.0)
	get_tree_paused(true)
	await _shots(view, lvl.ring, "fight")
	get_tree_paused(false)
	print("TEAM SHOTS on deck: %d a side (%d, %d)" % [MatchSetup.team_size(fmt), (mode.rules.sides[0] as Array).size(),
			(mode.rules.sides[1] as Array).size()])
	print("TEAM SHOTS DONE")
	_quit(0)


func get_tree_paused(on: bool) -> void:
	paused = on


func _shots(view: Variant, ring: RingArena, moment: String) -> void:
	var vs := _views(ring)
	for v: String in vs:
		var spec: Array = vs[v]
		var from: Vector3 = ring.to_global(spec[0])
		var at: Vector3 = ring.to_global(spec[1])
		view.camera.fov = float(spec[2])
		view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
		_hide_layers()
		await CaptureKit.frames(self, 20)
		for i in 8:
			RenderingServer.force_draw(false)
			await process_frame
		var img: Image = view.get_texture().get_image()
		print("  still ", CaptureKit.save(img, out, "team_%s_%s_%s" % [fmt, v, moment]))


func _hide_layers() -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false


func _quit(code: int) -> void:
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(code)
