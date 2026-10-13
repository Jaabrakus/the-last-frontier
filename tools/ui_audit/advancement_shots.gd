extends SceneTree
## Look-check stills of the Character Advancement window (scripts/ui/advancement), standalone: no main menu, a stand-in dark
## background, its own save file (user://advancement_shots.json, deleted first) and the newcomer gates open. Windowed, so
## wrap it in the lock wrapper:
##
##   GODOT_TIMEOUT=300 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/advancement_shots.gd -- \
##       out=<abs dir> [only=name,name] [el=earth]
##
## Writes adv_<earth|water|fire|air>.png (each with a premade build saved and worn), adv_tip.png, adv_pending.png,
## adv_slots.png, adv_class.png, adv_held.png, adv_search.png, adv_choice.png, adv_gate.png, adv_gate_first.png, adv_toast.png,
## adv_open.png (a fresh Classic slot with four nodes worn), adv_drop.png and adv_drop_loadout.png (the premade and the loadout
## drops open), adv_prompt.png (the unsaved-changes prompt), adv_wear.png (the wear animation under way), adv_tip_full.png (the
## long tip), adv_class_air.png (Air's five classes, Capoeira's card), adv_status.png (a premade build under a shut gate: some
## picks held back, the long status line in the bar), adv_720.png and adv_720_tip.png (1280x720). Never opens the character
## creator. Ends with ADVANCEMENT SHOTS DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const SAVE := "user://advancement_shots.json"

var out := ""
var only: Array = []
var _bg: ColorRect
var _w: AdvancementWindow
var _el_only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("out="):
			out = kv.get_slice("=", 1)
		elif kv.begins_with("only="):
			only = kv.get_slice("=", 1).split(",")
		elif kv.begins_with("el="):
			_el_only = kv.get_slice("=", 1)
	if out == "":
		out = ProjectSettings.globalize_path("res://artifacts/ui_audit/advancement/shots")
	if not CaptureKit.begin(self, "advancement_shots", "", false, true):
		return
	_run.call_deferred()


func _frames(n: int) -> void:
	await CaptureKit.frames(self, n)


## `keep_tip`: the tooltip shown is the point of the shot (else a tip the real pointer raised is put away first).
func _shot(name: String, keep_tip := false) -> void:
	await _frames(8)
	if not keep_tip and _w != null and is_instance_valid(_w):
		_w._hide_tip()
		await process_frame
	RenderingServer.force_draw()
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("  shot ", name, " ", img.get_size())


func _want(name: String) -> bool:
	return only.is_empty() or name in only


func _stand_in() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.09, 0.1, 0.13)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_bg)
	var l := Label.new()
	l.text = "stand-in for the menu behind the window"
	l.position = Vector2(30, 868)
	l.modulate = Color(1, 1, 1, 0.35)
	_bg.add_child(l)


func _open(el: String) -> AdvancementWindow:
	if _w != null and is_instance_valid(_w):
		_w.free()
	_w = AdvancementWindow.open(root, el)
	return _w


## Save the element's first premade into slot 1, a second into slot 2, and wear slot 1.
func _fill(el: String) -> void:
	var w := _open(el)
	var starters := AdvancementData.starters(el)
	if el == "fire":
		w.pick_class("boxing")      # the one animated style: Boxing
	w.apply_premade(String(starters[0].id))
	w.save()
	w.switch_slot(1)
	w.apply_premade(String(starters[1].id))
	w.save()
	w.switch_slot(0)
	w.wear_seconds = 0.0
	w.wear_slot(0)
	await _frames(2)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	AdvancementStore.path = SAVE
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	AdvancementStore.reload_file()
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
	_stand_in()
	await _frames(4)
	var els: Array = AdvancementData.ELEMENTS if _el_only == "" else [_el_only]
	for el: String in els:
		await _fill(el)
		var w := _open(el)
		await _frames(6)
		if _want("adv_" + el):
			await _shot("adv_" + el)
		if el == els[0]:
			await _extras(w, el)
	if _want("adv_class_air"):
		var wa := _open("air")
		await _frames(4)
		wa.open_picker()
		await _frames(6)
		await _shot("adv_class_air")
		wa.close_picker()
	if _want("adv_status"):
		AdvancementData.gates_override = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
		var ws := _open("earth")
		await _frames(4)
		ws.apply_premade(String(AdvancementData.starters("earth")[0].id))
		await _shot("adv_status")
		AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
	if _want("adv_720"):
		var w := _open(els[0])
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _frames(20)
		await _shot("adv_720")
		var tipn := _find_node(w, "variation")
		if tipn != null:
			tipn.tip.emit(tipn, true)
			await _shot("adv_720_tip", true)
		DisplayServer.window_set_size(Vector2i(1600, 900))
		await _frames(10)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("ADVANCEMENT SHOTS DONE")
	quit(0)


func _find_node(w: AdvancementWindow, kind: String) -> AdvancementNode:
	for n: AdvancementNode in w.all_nodes():
		if String(n.item.type) == "node" and n.kind == kind:
			return n
	return null


func _find_available(w: AdvancementWindow) -> AdvancementNode:
	for n: AdvancementNode in w.all_nodes():
		if n.state == "available" and not n.is_choice() and String(n.item.type) == "node":
			return n
	return null


func _extras(w: AdvancementWindow, el: String) -> void:
	# a tooltip on a worn twist
	if _want("adv_tip"):
		var n := _find_node(w, "variation")
		if n != null:
			n.tip.emit(n, true)
			await _shot("adv_tip", true)
			if _want("adv_tip_full"):
				w._expand_tip()
				await _shot("adv_tip_full", true)
			n.tip.emit(n, false)
	# a choice popped
	if _want("adv_choice"):
		for n: AdvancementNode in w.all_nodes():
			if n.is_choice():
				var t: AdvancementTree = w.tree(String(AdvancementData.node(n.first_id()).get("side", "left")))
				t.open_pop(n, true)
				await _frames(3)
				var pn: AdvancementNode = t._pop_nodes[0]
				pn.tip.emit(pn, true)
				await _shot("adv_choice", true)
				t.close_pop()
				w._hide_tip()
				break
	# a held node
	if _want("adv_held"):
		for n: AdvancementNode in w.all_nodes():
			if n.state == "held":
				n.tip.emit(n, true)
				await _shot("adv_held", true)
				n.tip.emit(n, false)
				break
	# pending changes: take a worn pick off and wear another
	if _want("adv_pending") or _want("adv_toast"):
		var worn: Array = w.work.picks.duplicate()
		if not worn.is_empty():
			w.take_off_id(String(worn[worn.size() - 1]))
		var avail := _find_available(w)
		if avail != null:
			w.wear_id(avail.first_id())
		await _shot("adv_pending")
		w.undo()
	if _want("adv_toast"):
		w.switch_slot(2)
		w.apply_premade(String(AdvancementData.starters(el)[2].id))
		w.save()
		await _shot("adv_toast")
		w.switch_slot(0)
	if _want("adv_open"):
		w.switch_slot(2)
		w.reset_classic()
		w.save()
		var n := 0
		for nd: AdvancementNode in w.all_nodes():
			if nd.state == "available" and not nd.is_choice() and String(nd.item.type) == "node" and n < 4:
				w.wear_id(nd.first_id())
				n += 1
		await _shot("adv_open")
		w.undo()
		w.switch_slot(0)
	if _want("adv_drop"):
		w.premade_drop().open()
		await _shot("adv_drop")
		w.premade_drop().close()
		w.loadout_drop().open()
		await _shot("adv_drop_loadout")
		w.loadout_drop().close()
	if _want("adv_prompt"):
		if not w.work.picks.is_empty():
			w.take_off_id(String(w.work.picks[w.work.picks.size() - 1]))
			w.request_close()
			await _shot("adv_prompt")
			w._close_prompt()
			w.undo()
	if _want("adv_wear"):
		w.wear_seconds = 1.6
		w.wear_slot(1)
		await _frames(40)
		await _shot("adv_wear")
		await _frames(120)
		w.wear_seconds = 0.0
		w.wear_slot(0)
	if _want("adv_search"):
		w.set_search("wall")
		await _shot("adv_search")
		w.set_search("")
	if _want("adv_slots"):
		w.set_slots_open(true)
		await _frames(12)
		await _shot("adv_slots")
		w.set_slots_open(false)
	if _want("adv_class"):
		w.open_picker()
		await _frames(6)
		await _shot("adv_class")
		w.close_picker()
	if _want("adv_gate"):
		AdvancementData.gates_override = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
		_open(el)
		await _frames(6)
		await _shot("adv_gate")
		AdvancementData.gates_override = {"won": false, "full_left": 4, "first_win": true, "full_lessons": true}
		_open(el)
		await _frames(6)
		await _shot("adv_gate_first")
		AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
		_open(el)
		await _frames(4)
