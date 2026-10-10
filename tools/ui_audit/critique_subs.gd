extends SceneTree
## Critique probe (VISUAL): the sub-screens the broadcast_shots tool does not take (Credits, Controls from the lobby, Class & talents
## row focused, Your look's offer is never opened) in the menu's own scene inside a SubViewport of `px`, with the text dump's floor.
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/critique_subs.gd -- out=DIR [tag=_720 px=1280x720]
## Never the character creator (MainMenu.creator_hook is a stand-in and the offer is marked as made); GameSettings has its own cfg.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const HOWTO := "user://how_to.cfg"
const OWN_CFG := "user://critique_subs.cfg"

var out := ""
var tag := ""
var part := "subs"
var px := Vector2i(1600, 900)
var vp: SubViewport
var m: MainMenu
var n := 0


class StubCreator extends Node:
	signal closed(accepted: bool)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"out": out = v
			"part": part = v
			"tag": tag = v
			"px": px = Vector2i(int(v.get_slice("x", 0)), int(v.get_slice("x", 1)))
	if not CaptureKit.begin(self, "critique_subs", out, true):
		return
	auto_accept_quit = false
	CaptureKit.keep([HOWTO])
	BroadcastUI.hover_focus = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	MatchSetup.set_controls("full")
	MainMenu.launch_hook = Callable()
	MainMenu._look_offered = true
	MainMenu.creator_hook = func(_first: bool) -> Object: return StubCreator.new()
	var look := AppearanceStore.default_look()
	look["name"] = "Rowan"
	FighterWorld.look_override = AppearanceStore.validate(look)
	_run.call_deferred()


func _end() -> void:
	FighterWorld.look_override = {}
	MainMenu.creator_hook = Callable()
	BroadcastUI.hover_focus = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	print("CRITIQUE SUBS DONE shots=%d" % n)
	quit(0)


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
		RenderingServer.force_draw(false)
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s%s.png" % [out, name, tag])
	var items := CaptureKit.text_dump(vp, Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var small := 9999.0
	for it: Dictionary in items:
		small = minf(small, float(it.screen_px))
	n += 1
	var off := 0
	for it: Dictionary in items:
		if bool(it.offscreen):
			off += 1
	print("shot %s%s smallest %.1f px, %d texts, %d partly outside" % [name, tag, small, items.size(), off])


## The lobby and the setup in windows of other shapes (a phone-like tall one, 4:3, 5:4, ultrawide, a small 16:9): the shots, the type floor and any
## text outside the window, per size.
func _aspects() -> void:
	MatchSetup.element = "earth"
	MatchSetup.save()
	for sz: Vector2i in [Vector2i(1024, 768), Vector2i(1280, 1024), Vector2i(2560, 1080), Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(800, 600)]:
		if vp != null:
			vp.queue_free()
			await process_frame
		px = sz
		tag = "_%dx%d" % [sz.x, sz.y]
		vp = SubViewport.new()
		vp.size = sz
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var scene := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		vp.add_child(scene)
		m = scene as MainMenu
		await CaptureKit.until(self, func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
		await CaptureKit.secs(self, 1.0)
		await _shot("aspect_main")
		m._open_match()
		await CaptureKit.until(self, func() -> bool: return m._element_rows.size() == 4 and (m._element_rows["fire"] as Control).find_child("CardView", true, false) != null, 25.0)
		await CaptureKit.secs(self, 0.8)
		await _shot("aspect_match")
	_end()


func _run() -> void:
	for i in 4:
		await process_frame
	if part == "aspects":
		await _aspects()
		return
	MatchSetup.element = "water"
	MatchSetup.save()
	vp = SubViewport.new()
	vp.size = px
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	vp.add_child(scene)
	m = scene as MainMenu
	await CaptureKit.until(self, func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
	await CaptureKit.secs(self, 1.0)
	m._open_credits()
	await CaptureKit.secs(self, 0.6)
	await _shot("sub_credits")
	m._close_panel()
	await CaptureKit.secs(self, 0.3)
	m._open_match()
	await CaptureKit.until(self, func() -> bool: return m._element_rows.size() == 4 and (m._element_rows["fire"] as Control).find_child("CardView", true, false) != null, 25.0)
	await CaptureKit.secs(self, 0.6)
	var ctl := m._panel.find_child("Controls", true, false) as Button
	if ctl != null:
		ctl.pressed.emit()
		await CaptureKit.secs(self, 0.8)
		await _shot("sub_controls")
	m._close_panel()
	await CaptureKit.secs(self, 0.3)
	m._open_practice()
	await CaptureKit.secs(self, 0.6)
	await _shot("sub_practice_water")
	_end()
