extends SceneTree
## Stills of earth's thrown stones (the owner, 2026-10-10: Spike and Boulder grow when held; they shatter on impact): a practice
## ring, earth against a standing earth dummy, from the player's own camera (every CanvasLayer hidden). Windowed (a normal
## window, never on top):
##   Godot --path . --resolution 1600x900 -s tools/ring/stone_shots.gd -- out=<dir>
## Writes <dir>/stone_<moment>.png: boulder_plain (raised, as it was), boulder_grown (held on: swelled), boulder_burst_0/1 (on
## the dummy), spike_burst (a grown Spike on the deck). Ends with STONE SHOTS DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://stone_shots.cfg"

var out := "user://stone_shots"
var p: FrontierPlayer
var mode: RingMode


func _initialize() -> void:
	var a := CaptureKit.args({"out": out})
	out = String(a["out"])
	CaptureKit.window()
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth"
	MatchSetup.light = "noon"
	MatchSetup.set_practice("earth", "stand")
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 4:
		await process_frame
	var lvl := current_scene as RingLevel
	var loaded: bool = lvl != null and await CaptureKit.wait_loaded(self, lvl)
	mode = RingMode.find(self)
	p = lvl.player if lvl != null else null
	if not loaded or mode == null or mode.foe == null or p == null:
		print("STONE SHOTS FAILED: no practice")
		return _quit(1)
	await CaptureKit.secs(self, 2.0)
	var foe := mode.foe
	var away := (p.global_position - foe.global_position) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	var at := foe.global_position + away * 8.0
	at.y = p.global_position.y
	RingLevel.place(p, Transform3D(Basis.looking_at(-away, Vector3.UP), at))
	p.yaw = atan2(away.x, away.z)
	await CaptureKit.secs(self, 0.6)
	var th := FormEffects.raise_stone(p, "stone_form", "cannonball") as FormEffects.Throw
	await CaptureKit.secs(self, 0.7)
	await _shot("boulder_plain")
	FormEffects.grow_raised(th, "stone_form", "cannonball")
	await CaptureKit.secs(self, 0.5)
	await _shot("boulder_grown")
	th.fixed = foe.global_position + Vector3.UP * 1.1
	var landed := [false]
	th.lift.landed.connect(func(_a: Vector3) -> void: landed[0] = true)
	th.waiting = false
	await CaptureKit.until(self, func() -> bool: return landed[0], 4.0)
	await CaptureKit.frames(self, 3)
	await _shot("boulder_burst_0")
	await CaptureKit.secs(self, 0.18)
	await _shot("boulder_burst_1")
	await CaptureKit.secs(self, 1.5)
	var th2 := FormEffects.raise_stone(p, "stone_form", "spike") as FormEffects.Throw
	await CaptureKit.secs(self, 0.7)
	FormEffects.grow_raised(th2, "stone_form", "spike")
	await CaptureKit.secs(self, 0.4)
	th2.fixed = p.global_position - away * 5.0 + Vector3.DOWN * 0.3
	var landed2 := [false]
	th2.lift.landed.connect(func(_a: Vector3) -> void: landed2[0] = true)
	th2.waiting = false
	await CaptureKit.until(self, func() -> bool: return landed2[0], 4.0)
	await CaptureKit.frames(self, 4)
	await _shot("spike_burst")
	print("STONE SHOTS DONE")
	_quit(0)


func _shot(moment: String) -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	await CaptureKit.drawn(self)
	var img := root.get_texture().get_image()
	print("  shot ", CaptureKit.save(img, out, "stone_" + moment))


func _quit(code: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(code)
