extends SceneTree
## The Character Advancement WINDOW (scripts/ui/advancement/advancement_window.gd and its parts), headless, no level, through
## the controls the player uses (a node's click and right click, the dropdown's pick, the Save / Undo / Reset buttons, the
## tabs, Esc), on its own save file (user://advancement_window_test.json):
##   open       for each element: the window opens, is above the menus (layer >= 95), keeps working over a paused game
##              (PROCESS_MODE_ALWAYS), shows the mouse, places every node of both trees and the rail's traits; closes
##              cleanly (`closed` once, freed, the mouse mode back, no nodes left over)
##   picks      wear (Save glows, undo shows, Reset hides), take off, undo; a premade build; Save writes the slot and
##              raises the toasts; Reset makes Classic a pending change; a held node cannot be worn (and says why); a
##              choice swaps its options; the pop-out opens and closes; the real mouse's left and right click work
##   panels     the Loadouts panel (edit another slot, Wear with its bar, rename, the padlock keeping a slot), the class
##              picker (a ready class is picked as a pending change, Capoeira is not), the gates, Search dimming
##   keys       focus navigation reaches every node (left / right / up / down, and the Tab ring); Enter wears
##   esc        Esc steps back (a popped choice, the picker, the Loadouts panel, the prompt, then the window), asks before
##              closing with changes pending (Save / Discard / Keep editing), and is consumed (a node under it that
##              takes unhandled Esc, like the ring's menu, does not see it)
##   repairs    the critic's second pass: the newcomer gates hold for a pasted code, a premade build and Save (and keep out only
##              what is new); the short tip is short and the full one is the old one, both inside the painting and clear of the
##              bottom bar; the ribbon tells the truth about the live picks (a green dot and a line in the tip for each); the
##              lattice fills its zone evenly with its cross links; the status line stands clear of the trees; the class
##              picker's state lines stay inside their cards; a choice of held options reads held
##   look       at 1280x720 nothing is set under 14 px; no word on screen is one the show or another game owns
##   Godot --headless --path . -s tests/ui/test_advancement_window.gd
## The last line "ADVANCEMENT WINDOW TEST PASSED" or "... FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "ADVANCEMENT WINDOW TEST"
const LIMIT_S := 170.0
const OWN_FILE := "user://advancement_window_test.json"
const BANNED := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?",
		"republic city", "ba sing se", "omashu", "water whip", "air balls?", "air shields?", "spouts?",
		"redirect lightning", "bend\\w*", "spellbreak", "azeroth", "warcraft", "blizzard", "wow", "ascension"]
const OPEN := {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}

## A node under the window that, like the ring's menu, closes on an unhandled Esc.
class Probe extends Node:
	var hits := 0

	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed(&"ui_cancel"):
			hits += 1


var checks := 0
var fails: Array[String] = []
var _re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(BANNED)))


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ok   ", what)
	else:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _reset_store() -> void:
	AdvancementStore.path = OWN_FILE
	if FileAccess.file_exists(OWN_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_FILE))
	AdvancementStore.reload_file()


func _open(el: String) -> AdvancementWindow:
	var w := AdvancementWindow.open(root, el)
	w.wear_seconds = 0.0
	return w


func _free(w: AdvancementWindow) -> void:
	if is_instance_valid(w):
		w.free()


func _first_available(w: AdvancementWindow, single := true) -> AdvancementNode:
	for n: AdvancementNode in w.all_nodes():
		if n.state == "available" and String(n.item.type) == "node" and (not single or not n.is_choice()):
			return n
	return null


func _click(pos: Vector2, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button
	ev.pressed = true
	root.push_input(ev)
	var up := InputEventMouseButton.new()
	up.position = pos
	up.global_position = pos
	up.button_index = button
	up.pressed = false
	root.push_input(up)


## Esc as the window delivers it: _input first, then the GUI, then _unhandled_input (push_input runs all of them in 4.7).
func _esc() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	root.push_input(ev)


func _run() -> void:
	AdvancementData.reload_data()
	AdvancementLayout.reload_data()
	_reset_store()
	AdvancementData.gates_override = OPEN.duplicate()
	await _open_close()
	await _picks()
	await _held_and_choice()
	await _mouse()
	await _panels()
	await _picker()
	await _gates()
	await _search()
	await _keys()
	await _esc_steps()
	await _repairs()
	await _look()
	AdvancementData.gates_override = {}
	AdvancementStore.path = AdvancementStore.PATH
	AdvancementStore.reload_file()
	if FileAccess.file_exists(OWN_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_FILE))
	print("%d checks, %d failed" % [checks, fails.size()])
	for f in fails:
		print("  failed: ", f)
	print("%s %s" % [NAME, "PASSED" if fails.is_empty() else "FAILED"])
	quit(0 if fails.is_empty() else 1)


# --- open and close -------------------------------------------------------------------------------------------------------------

func _open_close() -> void:
	var orphans0 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for el: String in AdvancementData.ELEMENTS:
		var before_mode := Input.mouse_mode
		var w := _open(el)
		await frames(3)
		var closed := [0]
		w.closed.connect(func() -> void: closed[0] += 1)
		check(w.layer >= 95, "%s: the window is above the menus (layer %d)" % [el, w.layer])
		check(w.process_mode == Node.PROCESS_MODE_ALWAYS, "%s: it works over a paused game" % el)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "%s: the mouse is shown" % el)
		for side: String in ["left", "right"]:
			var plan := AdvancementLayout.place(el, side)
			check(w.tree(side).nodes.size() == (plan.items as Array).size() and not (plan.items as Array).is_empty(),
					"%s: the %s tree places all %d of its nodes" % [el, side, (plan.items as Array).size()])
		check(w.rail().nodes.size() == AdvancementData.rail(w.work.style, el).size(), "%s: the rail shows its traits" % el)
		check(not w.is_pending() and w.save_button().disabled, "%s: nothing pending, Save is off" % el)
		check(AdvancementWindow.open(root, el) == w, "%s: opening it again gives the one that is open" % el)
		w.close()
		w.close()
		await frames(2)
		check(not is_instance_valid(w) and closed[0] == 1, "%s: it closes once and is freed" % el)
		check(Input.mouse_mode == before_mode, "%s: the mouse mode comes back" % el)
	await frames(3)
	var orphans1 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	check(orphans1 <= orphans0 + 2, "four opens and closes leave no nodes behind (%d -> %d)" % [orphans0, orphans1])
	# over a paused game
	paused = true
	var p := _open("earth")
	await frames(3)
	check(p.can_process() and get_root().get_tree().paused, "over a paused game the window still runs")
	var starters := AdvancementData.starters("earth")
	p.apply_premade(String(starters[0].id))
	p.save()
	p.wear_slot(0)
	await frames(2)
	check(p.status_text() == AdvancementData.word("status.ring_restart"), "in the paused ring a worn loadout reads 'Worn from the next restart' (%s)" % p.status_text())
	_free(p)
	paused = false
	_reset_store()


# --- picks ----------------------------------------------------------------------------------------------------------------------

func _picks() -> void:
	var w := _open("earth")
	await frames(3)
	var starters := AdvancementData.starters("earth")
	check(w.reset_button().visible and not w.undo_button().visible, "nothing pending: Reset shows, undo does not")
	var n := _first_available(w)
	check(n != null, "an available node can be found")
	var id := n.first_id()
	n.pressed.emit()
	check(w.work.has(id) and w.is_pending() and n.state == "pending_on", "a click wears a node as a pending change (%s)" % n.state)
	check(not w.save_button().disabled and w.undo_button().visible and not w.reset_button().visible, "pending: Save is on, undo shows, Reset hides")
	check(not AdvancementStore.slot("earth", 0).has(id), "nothing is written before Save")
	n.take_off.emit(n)
	check(not w.work.has(id) and not w.is_pending() and n.state == "available", "a right click takes it off again, nothing pending")
	n.pressed.emit()
	w.undo_button().pressed.emit()
	check(not w.work.has(id) and not w.is_pending(), "undo goes back to the saved slot")
	# a premade build
	w.premade_drop().picked.emit(String(starters[0].id))
	check(w.work.cost() == 10 and w.is_pending() and not w.save_button().disabled, "a premade build fills the pending changes (%d points)" % w.work.cost())
	check(w.status_text().contains(String(starters[0].name)), "its line is in the status (%s)" % w.status_text())
	w.save_button().pressed.emit()
	await frames(2)
	var stored := AdvancementStore.slot("earth", 0)
	check(not w.is_pending() and stored.picks.size() == (starters[0].nodes as Array).size(), "Save writes the slot (%d picks)" % stored.picks.size())
	check(String(AdvancementStore.slot_info("earth", 0).name) == String(starters[0].name), "the slot takes the premade's name")
	check(w.status_text().begins_with(AdvancementData.word("status.saved")), "the status says Saved (%s)" % w.status_text())
	var toasts := w.toast_texts()
	var want := stored.toasts(AdvancementLoadout.classic("earth", stored.style))
	check(toasts.size() == mini(want.size(), 3) and not toasts.is_empty(), "a toast for each new twist, technique, new skill and set, at most 3 (%s)" % [toasts])
	var worn_nodes := 0
	for nd: AdvancementNode in w.all_nodes():
		if nd.state == "worn" and String(nd.item.type) != "root":
			worn_nodes += 1
	check(worn_nodes >= (starters[0].nodes as Array).size() - 3, "worn nodes are drawn worn (%d)" % worn_nodes)
	check(w.node_for_id(String(stored.picks[0])).state == "worn", "a saved pick reads worn")
	# take one off: pending off, then save
	var off_id := String(stored.picks[stored.picks.size() - 1])
	var off_node := w.node_for_id(off_id)
	off_node.take_off.emit(off_node)
	check(w.is_pending() and off_node.state == "pending_off", "a taken-off pick is a pending off (%s)" % off_node.state)
	w.save()
	check(not AdvancementStore.slot("earth", 0).has(off_id), "Save writes the take-off")
	# Reset makes Classic a pending change
	check(w.reset_button().visible, "after Save Reset shows again")
	w.reset_button().pressed.emit()
	check(w.work.is_empty() and w.is_pending() and not w.reset_button().visible, "Reset is a pending change to Classic")
	check(not AdvancementStore.slot("earth", 0).is_empty(), "and the slot is untouched until Save")
	w.save_button().pressed.emit()
	check(AdvancementStore.slot("earth", 0).is_empty() and not w.is_pending(), "Save keeps Classic")
	# a code round trip as a pending change
	w.apply_premade(String(starters[1].id))
	var code := w.work.code()
	w.undo()
	check(w.apply_code(code) == "" and w.work.code() == code and w.is_pending(), "a loadout code is read as a pending change")
	check(w.apply_code("nonsense") != "" and w.work.code() == code, "a bad code is refused")
	w.undo()
	_free(w)
	_reset_store()


# --- held and choice ------------------------------------------------------------------------------------------------------------

func _held_and_choice() -> void:
	var w := _open("earth")
	await frames(3)
	var held: AdvancementNode = null
	for n: AdvancementNode in w.all_nodes():
		if n.state == "held":
			held = n
			break
	check(held != null, "a held node is drawn (dashed, with '?')")
	if held != null:
		held.pressed.emit()
		check(not w.work.has(held.first_id()) and not w.is_pending(), "a held node cannot be worn")
		check(w.status_text() == AdvancementData.word("reasons.held") and not w.status_text().to_lower().contains("question"), "and says why in plain words (%s)" % w.status_text())
		var lines := AdvancementTip.node_lines(held.first_id(), "held", w.work)
		check(String(lines[lines.size() - 1].text) == w.work.why_not(held.first_id()), "its tooltip ends with the reason")
	# a choice: two options both wearable on an empty loadout
	var pair: Array = []
	var holder: AdvancementTree = null
	for t: AdvancementTree in [w.tree("left"), w.tree("right")]:
		for n: AdvancementNode in t.nodes:
			if n.is_choice() and pair.is_empty():
				var ok: Array = []
				for id: String in n.ids:
					if w.work.why_not(id) == "":
						ok.append(id)
				if ok.size() >= 2:
					pair = ok
					holder = t
	check(pair.size() >= 2, "a choice with two wearable options is there (%s)" % [pair])
	if pair.size() >= 2:
		var a := String(pair[0])
		var b := String(pair[1])
		w.wear_id(a)
		check(w.work.has(a), "an option of a choice is worn")
		w.wear_id(b)
		check(w.work.has(b) and not w.work.has(a), "the other option swaps with it")
		var cn := holder.node_for_id(a)
		check(cn.state == "pending_on", "the octagon reads pending on (%s)" % cn.state)
		cn.take_off.emit(cn)
		check(not w.work.has(b), "a right click on the octagon takes its worn option off")
		# the pop-out
		holder.open_pop(cn, true)
		await frames(2)
		check(holder.is_popped() and holder._pop_nodes.size() == cn.ids.size(), "the pop-out shows each option (%d)" % holder._pop_nodes.size())
		w.escape()
		check(not holder.is_popped() and is_instance_valid(w), "Esc closes the pop-out first, not the window")
		holder.open_pop(cn, true)
		await frames(2)
		var pn: AdvancementNode = holder._pop_nodes[0]
		var pid := pn.first_id()
		pn.pressed.emit()
		await frames(2)
		check(w.work.has(pid) and not holder.is_popped(), "choosing in the pop-out wears it and closes it")
	w.undo()
	_free(w)
	_reset_store()


# --- the real mouse ----------------------------------------------------------------------------------------------------------------

func _mouse() -> void:
	var w := _open("water")
	await frames(3)
	var n := _first_available(w)
	var id := n.first_id()
	var centre := n.get_global_rect().get_center()
	_click(centre, MOUSE_BUTTON_LEFT)
	await frames(2)
	check(w.work.has(id), "a real left click on a node wears it (%s)" % n.state)
	_click(centre, MOUSE_BUTTON_RIGHT)
	await frames(2)
	check(not w.work.has(id), "a real right click takes it off")
	# the Save button by the mouse
	_click(centre, MOUSE_BUTTON_LEFT)
	await frames(2)
	var sb := w.save_button().get_global_rect().get_center()
	_click(sb, MOUSE_BUTTON_LEFT)
	await frames(2)
	check(AdvancementStore.slot("water", 0).has(id), "a real click on Save Changes writes the slot")
	_free(w)
	_reset_store()


# --- panels ---------------------------------------------------------------------------------------------------------------------

func _panels() -> void:
	var w := _open("earth")
	await frames(3)
	var starters := AdvancementData.starters("earth")
	w.apply_premade(String(starters[0].id))
	w.save()
	w.tab_button("loadouts").pressed.emit()
	await frames(14)
	check(w.slots_open() and w.slots_panel().visible, "the Loadouts tab opens the panel")
	check(w.tab_button("loadouts").button_pressed and not w.tab_button("advancement").button_pressed, "and its tab reads pressed")
	w.tab_button("advancement").pressed.emit()
	check(not w.slots_open() and w.tab_button("advancement").button_pressed, "the Advancement tab closes it")
	var looked := [0]
	w.look_requested.connect(func() -> void: looked[0] += 1)
	w.tab_button("look").pressed.emit()
	check(looked[0] == 1 and is_instance_valid(w), "the Your look tab asks the menus to open the creator (look_requested), nothing more")
	w.set_slots_open(true)
	# edit slot 2, with a pending change in slot 1: the prompt asks first
	w.reset_classic()
	check(w.is_pending(), "a pending change in slot 1")
	w.slots_panel().edit_requested.emit(1)
	check(w.prompt_open() and w.slot_index == 0, "editing another slot with changes pending asks first")
	w.prompt_node().find_child("Ask_keep", true, false).pressed.emit()
	check(not w.prompt_open() and w.slot_index == 0 and w.is_pending(), "Keep editing stays")
	w.slots_panel().edit_requested.emit(1)
	w.prompt_node().find_child("Ask_discard", true, false).pressed.emit()
	await frames(2)
	check(not w.prompt_open() and w.slot_index == 1 and not w.is_pending(), "Discard goes on to slot 2 with nothing pending")
	w.apply_premade(String(starters[1].id))
	w.save()
	check(AdvancementStore.slot("earth", 1).picks.size() > 0, "slot 2 saves its own build")
	w.rename_slot(1, "My build")
	check(AdvancementStore.slot_name("earth", 1) == "My build", "a slot is renamed")
	# Wear
	w.wear_slot(1)
	await frames(2)
	check(AdvancementStore.worn_index("earth") == 1, "Wear wears the slot")
	check(w.status_text() == AdvancementData.word("status.worn_now"), "and says Worn (%s)" % w.status_text())
	w.wear_slot(-1)
	await frames(2)
	check(AdvancementStore.worn_index("earth") == -1, "Classic can be worn")
	# a slow Wear bar holds the inputs
	w.wear_seconds = 0.15
	w.wear_slot(0)
	check(w.busy, "the Wear bar holds the inputs while it fills")
	var n := _first_available(w)
	if n != null:
		var before := w.work.picks.size()
		n.pressed.emit()
		check(w.work.picks.size() == before, "a click during the bar does nothing")
	await create_timer(0.4).timeout
	check(not w.busy and AdvancementStore.worn_index("earth") == 0, "then the slot is worn")
	w.wear_seconds = 0.0
	# the padlock keeps a slot
	w.keep_slot(1, true)
	w.switch_slot(1)
	w.reset_classic()
	var before_nodes := AdvancementStore.slot("earth", 1).picks.duplicate()
	var why := w.save()
	check(why != "" and AdvancementStore.slot("earth", 1).picks == before_nodes, "a kept slot is not changed by Save (%s)" % why)
	w.undo()
	w.keep_slot(1, false)
	_free(w)
	_reset_store()


func _picker() -> void:
	var w := _open("fire")
	await frames(3)
	check(w.work.style == AdvancementData.canon_style("fire"), "fire opens in its own style")
	w.class_button().pressed.emit()
	await frames(3)
	check(w.picker_open(), "Change class opens the picker")
	var card := w.picker_node().find_child("Card_boxing", true, false)
	var cap := w.picker_node().find_child("Card_muay_thai", true, false)
	check(card != null and cap != null, "the picker holds the element's classes (Boxing, Muay Thai)")
	check((cap.find_child("PickButton", true, false) as Button).disabled, "a class that is only coming cannot be picked")
	check(not (card.find_child("PickButton", true, false) as Button).disabled, "Boxing, the animated style, can")
	(card.find_child("PickButton", true, false) as Button).pressed.emit()
	await frames(3)
	check(not w.picker_open() and w.work.style == "boxing" and w.is_pending(), "picking a class is a pending change")
	var title := w.find_child("TitleLeft", true, false) as Label
	check(title.text == "BOXING", "the left title takes the class (%s)" % title.text)
	check(w.rail().style_id == "boxing", "the rail takes the class's traits")
	w.pick_class("muay_thai")
	check(w.work.style == "boxing", "pick_class refuses a class that is not ready")
	w.save_button().pressed.emit()
	check(AdvancementStore.slot("fire", 0).style == "boxing" and not w.is_pending(), "Save writes the class")
	check(AdvancementStore.style_of("fire") == "boxing" or AdvancementStore.worn_index("fire") != 0, "the class is the worn one's when it is worn")
	w.pick_class(AdvancementData.canon_style("fire"))
	w.undo()
	check(w.work.style == "boxing" and title.text == "BOXING", "undo returns the class too")
	_free(w)
	_reset_store()


func _gates() -> void:
	AdvancementData.gates_override = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
	var w := _open("earth")
	await frames(3)
	var twist: AdvancementNode = null
	for n: AdvancementNode in w.all_nodes():
		if String(n.item.type) == "node" and n.kind == "variation":
			twist = n
			break
	check(twist != null and twist.state == "blocked", "with Full lessons left a twist is blocked (%s)" % [twist.state if twist != null else "-"])
	var why := w.work.why_not(twist.first_id())
	check(why.contains("4"), "with the lessons gate's reason (%s)" % why)
	twist.pressed.emit()
	check(not w.work.has(twist.first_id()) and w.status_text() == why, "and a click shows it")
	var enh: AdvancementNode = null
	for n: AdvancementNode in w.all_nodes():
		if String(n.item.type) == "node" and n.kind == "enhance" and n.state == "available":
			enh = n
	check(enh != null, "an enhance can still be worn")
	# the gate shown on every pick it holds, and on no other (the lattice mixes the rows: each such pick wears the padlock)
	var gated_kinds: Array = AdvancementData.switch("full_lessons_kinds", [])
	var wrong_marks: Array = []
	for n: AdvancementNode in w.all_nodes():
		if String(n.item.type) == "root" or n.state != "blocked":
			continue
		var all_gated := true
		for id: String in n.ids:
			if not String(AdvancementData.node(id).kind) in gated_kinds:
				all_gated = false
		if (n.gate_num == 4) != all_gated:
			wrong_marks.append("%s:%d" % [n.name, n.gate_num])
	check(wrong_marks.is_empty(), "every shut twist, technique, new skill and set wears the lessons gate's padlock with 4, nothing else does %s" % [wrong_marks])
	_free(w)
	AdvancementData.gates_override = {"won": false, "full_left": 4, "first_win": true, "full_lessons": true}
	w = _open("earth")
	await frames(3)
	var open_ct := 0
	for n: AdvancementNode in w.all_nodes():
		if n.state == "available":
			open_ct += 1
	check(open_ct == 0, "before the first win nothing can be worn (%d)" % open_ct)
	var unmarked := 0
	for n: AdvancementNode in w.all_nodes():
		if String(n.item.type) != "root" and n.state == "blocked" and n.gate_num != 1:
			unmarked += 1
	check(unmarked == 0, "and every shut pick wears the first-win gate's padlock with 1 (%d without)" % unmarked)
	var items: Array = w.premade_drop().items
	var all_dis := true
	for it: Dictionary in items:
		if String(it.id) != "classic" and not bool(it.get("disabled", false)):
			all_dis = false
	check(all_dis, "and the premade builds are listed, greyed, with the reason")
	_free(w)
	AdvancementData.gates_override = OPEN.duplicate()


func _search() -> void:
	var w := _open("earth")
	await frames(3)
	w.set_search("wall")
	var hits := w.search_matches()
	var dimmed := 0
	for n: AdvancementNode in w.all_nodes():
		if n.dim:
			dimmed += 1
	check(not hits.is_empty() and dimmed > 0 and dimmed + hits.size() <= w.all_nodes().size(), "Search lights the matches and dims the rest (%d lit, %d dim)" % [hits.size(), dimmed])
	check(is_equal_approx((hits[0] as AdvancementNode).modulate.a, 1.0) and (w.all_nodes().filter(func(x: AdvancementNode) -> bool: return x.dim)[0] as AdvancementNode).modulate.a < 0.5, "a non-match fades")
	w.search_box().text_submitted.emit("wall")
	await frames(2)
	check(hits.has(get_root().gui_get_focus_owner()), "Enter steps to a match")
	w.set_search("zzzzqq")
	check(w.search_matches().is_empty() and w.status_text() == AdvancementData.word("search.none"), "no match says so")
	w.set_search("")
	var any_dim := false
	for n: AdvancementNode in w.all_nodes():
		any_dim = any_dim or n.dim
	check(not any_dim, "clearing the search clears the dimming")
	_free(w)


# --- keys -----------------------------------------------------------------------------------------------------------------------

func _keys() -> void:
	for el: String in AdvancementData.ELEMENTS:
		var w := _open(el)
		await frames(3)
		var start: Control = w.tree("left").nodes[0]
		start.grab_focus()
		var seen := {start: true}
		var queue: Array = [start]
		while not queue.is_empty():
			var c: Control = queue.pop_back()
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				var nb := c.find_valid_focus_neighbor(side)
				if nb != null and not seen.has(nb):
					seen[nb] = true
					queue.append(nb)
		var missed := 0
		for n: AdvancementNode in w.all_nodes():
			if not seen.has(n):
				missed += 1
		check(missed == 0, "%s: arrow keys reach all %d nodes (%d missed)" % [el, w.all_nodes().size(), missed])
		var rail_missed := 0
		for n: AdvancementNode in w.rail().nodes:
			if not seen.has(n):
				rail_missed += 1
		check(rail_missed == 0, "%s: and the rail's traits" % el)
		# the Tab ring runs through every node of both trees
		var tab_seen := {}
		var c2: Control = start
		for i in w.all_nodes().size() + 40:
			tab_seen[c2] = true
			var nx := c2.find_next_valid_focus()
			if nx == null or nx == c2:
				break
			c2 = nx
		var tab_missed := 0
		for n: AdvancementNode in w.all_nodes():
			if not tab_seen.has(n):
				tab_missed += 1
		check(tab_missed == 0, "%s: Tab reaches every node (%d missed)" % [el, tab_missed])
		# Enter wears the focused node, Delete takes it off
		var n := _first_available(w)
		if n != null:
			n.grab_focus()
			var ev := InputEventAction.new()
			ev.action = &"ui_accept"
			ev.pressed = true
			root.push_input(ev)
			await frames(2)
			var ev2 := InputEventAction.new()
			ev2.action = &"ui_accept"
			ev2.pressed = false
			root.push_input(ev2)
			await frames(2)
			check(w.work.has(n.first_id()), "%s: Enter wears the focused node" % el)
			var k := InputEventKey.new()
			k.keycode = KEY_DELETE
			k.pressed = true
			n._on_gui_input(k)
			check(not w.work.has(n.first_id()), "%s: Delete takes it off" % el)
		_free(w)
		_reset_store()


# --- esc ------------------------------------------------------------------------------------------------------------------------

func _esc_steps() -> void:
	var probe := Probe.new()
	root.add_child(probe)
	var w := _open("earth")
	await frames(3)
	var closed := [0]
	w.closed.connect(func() -> void: closed[0] += 1)
	w.set_slots_open(true)
	await frames(3)
	_esc()
	await frames(2)
	check(is_instance_valid(w) and not w.slots_open() and closed[0] == 0, "Esc closes the Loadouts panel first")
	w.open_picker()
	await frames(2)
	_esc()
	await frames(2)
	check(not w.picker_open() and closed[0] == 0, "then the class picker")
	# changes pending: Esc asks, Esc again keeps editing, Discard closes
	var n := _first_available(w)
	n.pressed.emit()
	_esc()
	await frames(2)
	check(w.prompt_open() and closed[0] == 0, "with changes pending Esc asks Save / Discard / Keep editing")
	_esc()
	await frames(2)
	check(not w.prompt_open() and w.is_pending() and closed[0] == 0, "Esc on the prompt keeps editing")
	_esc()
	await frames(2)
	w.prompt_node().find_child("Ask_discard", true, false).pressed.emit()
	await frames(3)
	check(closed[0] == 1 and not is_instance_valid(w), "Discard closes the window")
	check(AdvancementStore.slot("earth", 0).is_empty(), "and nothing was saved")
	check(probe.hits == 0, "the Esc was consumed: nothing under the window saw it (%d)" % probe.hits)
	# Save from the prompt
	w = _open("earth")
	await frames(3)
	w.apply_premade(String(AdvancementData.starters("earth")[0].id))
	_esc()
	await frames(2)
	w.prompt_node().find_child("Ask_save", true, false).pressed.emit()
	await frames(3)
	check(not is_instance_valid(w) and not AdvancementStore.slot("earth", 0).is_empty(), "Save from the prompt writes the slot and closes")
	# a clean window closes on one Esc, and a probe (the ring's menu) sees an Esc once the window is gone
	w = _open("earth")
	await frames(3)
	_esc()
	await frames(3)
	check(not is_instance_valid(w) and probe.hits == 0, "one Esc closes a clean window, consumed")
	_esc()
	await frames(2)
	check(probe.hits == 1, "and with the window gone the Esc reaches what is under it (the probe works)")
	probe.free()
	_reset_store()


# --- look -----------------------------------------------------------------------------------------------------------------------

func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
		out.append((n as Button).tooltip_text)
	elif n is LineEdit:
		out.append((n as LineEdit).placeholder_text)
	for c in n.get_children():
		_texts(c, out)


func _small(n: Node, fit: float, out: Array) -> void:
	if n is Label or n is Button or n is LineEdit:
		var c := n as Control
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is LineEdit:
			txt = (n as LineEdit).placeholder_text
		if txt.strip_edges() != "":
			var px := float(c.get_theme_font_size("font_size"))
			if px * fit < 14.0:
				out.append("%s (%d px)" % [txt.left(30), int(px)])
	for ch in n.get_children():
		_small(ch, fit, out)


# --- the repairs -----------------------------------------------------------------------------------------------------------------

func _repairs() -> void:
	await _repair_gates()
	await _repair_tips()
	await _repair_live()
	await _repair_layout()
	await _repair_picker_and_held()


func _repair_gates() -> void:
	AdvancementStore.reload_file()
	_reset_store()
	var el := "earth"
	var starters := AdvancementData.starters(el)
	var donor := AdvancementLoadout.from_starter(el, String(starters[0].id), "")
	var code := donor.code()
	# before the first win: nothing of a code, a premade build or a set-by-hand pick gets in
	AdvancementData.gates_override = {"won": false, "full_left": 4, "first_win": true, "full_lessons": true}
	var w := _open(el)
	await frames(3)
	var r := w.apply_code(code)
	check(r != "" and not w.is_pending() and w.work.picks.is_empty(), "before the first win a pasted code is refused with the gate's words, nothing pending (%s)" % r)
	check(r == AdvancementData.word("reasons.gate_first_win") or r.contains(AdvancementData.word("reasons.gate_first_win")), "and the words are the gate's")
	w.apply_premade(String(starters[0].id))
	check(not w.is_pending() and w.work.picks.is_empty(), "a premade build chosen by script is refused as well")
	w.work.picks = donor.picks.duplicate()                # (a bypass of the window's own controls)
	var why := w.save()
	check(why != "" and AdvancementStore.slot(el, 0).picks.is_empty(), "and Save refuses picks that came in some other way (%s)" % why)
	_free(w)
	# after the first win, before the Full lessons: a code or a premade build brings in what is open and holds the rest back
	AdvancementData.gates_override = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
	w = _open(el)
	await frames(3)
	r = w.apply_code(code)
	var kinds_in: Array = []
	for id: String in w.work.picks:
		kinds_in.append(String(AdvancementData.node(id).kind))
	check(r == "" and not w.work.picks.is_empty() and w.work.picks.size() < donor.picks.size(), "with Full lessons left a pasted code brings in only what is open (%d of %d)" % [w.work.picks.size(), donor.picks.size()])
	check(not "variation" in kinds_in and not "mastery" in kinds_in, "no twist, no technique (%s)" % [kinds_in])
	check(w.status_text().contains("held back"), "and the status says some were held back (%s)" % w.status_text())
	check(w.save() == "" and AdvancementStore.slot(el, 0).picks.size() == w.work.picks.size(), "and that Save writes them")
	_free(w)
	# what is saved stays saved when a gate is up: a change to the slot keeps (and does not re-ask) the old picks
	AdvancementData.gates_override = OPEN.duplicate()
	AdvancementStore.reload_file()
	w = _open(el)
	await frames(3)
	w.apply_premade(String(starters[0].id))
	check(w.save() == "", "(setup) a full build saved with the gates open")
	_free(w)
	AdvancementData.gates_override = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
	w = _open(el)
	await frames(3)
	var n_saved := w.work.picks.size()
	var take := String(w.work.picks[0])
	w.take_off_id(take)
	check(w.save() == "" and AdvancementStore.slot(el, 0).picks.size() < n_saved, "with a gate up, taking a saved pick off still saves (the old twists are not asked again)")
	_free(w)
	AdvancementData.gates_override = OPEN.duplicate()
	_reset_store()


func _repair_tips() -> void:
	var worst_short := 0
	var worst_short_id := ""
	var worst_full := 0
	var outside: Array = []
	var cut := 0
	for el: String in AdvancementData.ELEMENTS:
		var w := _open(el)
		await frames(3)
		var bounds := w._tip_bounds()
		check(bounds.end.y <= AdvancementData.window_rect("bottom_bar").position.y, "%s: a tip may stand only above the bottom bar" % el)
		for n: AdvancementNode in w.all_nodes():
			if String(n.item.type) == "root":
				continue
			n.tip.emit(n, true)
			var tip: Control = w._tip
			var sr := Rect2(tip.position, tip.size)
			if int(tip.size.y) > worst_short:
				worst_short = int(tip.size.y)
				worst_short_id = String(n.name)
			if sr.position.y < bounds.position.y - 0.5 or sr.end.y > bounds.end.y + 0.5 or sr.position.x < bounds.position.x - 0.5 or sr.end.x > bounds.end.x + 0.5:
				outside.append("%s short" % n.name)
			w._expand_tip()
			sr = Rect2(tip.position, tip.size)
			worst_full = maxi(worst_full, int(tip.size.y))
			if sr.end.y > bounds.end.y + 0.5 or sr.position.y < bounds.position.y - 0.5:
				outside.append("%s full" % n.name)
			n.tip.emit(n, false)
			cut += 1
		_free(w)
	check(outside.is_empty(), "%d tips (short and full) of every element stay inside the painting, above the bar (%s)" % [cut, outside.slice(0, 5)])
	check(worst_short <= 250, "the short tip is at most 250 px tall at 1600x900 (the first one reached 490, the repair's 330): %d (%s)" % [worst_short, worst_short_id])
	check(worst_full > worst_short, "and the full one holds more (%d)" % worst_full)
	# one node, line by line
	var lo := AdvancementLoadout.new("earth")
	var short := AdvancementTip.node_lines("earth.catch.juggle", "worn", lo, false)
	var full := AdvancementTip.node_lines("earth.catch.juggle", "worn", lo, true)
	check(short.size() <= 8 and full.size() > short.size(), "Juggle's short tip is %d lines, its full one %d" % [short.size(), full.size()])
	var short_text := ""
	for l: Dictionary in short:
		short_text += String(l.text) + "\n"
	check(short_text.contains("Juggle") and short_text.contains("hold two stones") and short_text.contains(AdvancementData.word("tip.take_off")) and not short_text.contains("How he answers") and not short_text.contains("Rank"),
			"the short tip has the name, the effect, the numbers, the action; not the rank (on the plate) nor the answer")
	# one line of effect and one of numbers, whatever the node (each kept to one line by the tip itself)
	var multi: Array = []
	for el: String in AdvancementData.ELEMENTS:
		for nd: Dictionary in AdvancementData.nodes(el):
			var ls := AdvancementTip.node_lines(String(nd.id), "available", lo, false)
			var fx_lines := 0
			var num_lines := 0
			for l: Dictionary in ls:
				if l.get("col") == AdvancementData.color("effect"):
					fx_lines += 1
					if not bool(l.get("one", false)):
						multi.append(String(nd.id))
				if l.has("parts") and (String(l.text).begins_with("+ ") or String(l.text).begins_with("- ")):
					num_lines += 1
			if fx_lines > 1 or num_lines > 1 or ls.size() > 6:
				multi.append(String(nd.id))
	check(multi.is_empty(), "every short tip: one effect line, one numbers line, at most 6 lines %s" % [multi.slice(0, 5)])
	# Shift and a long stay make it full
	var w2 := _open("earth")
	await frames(3)
	var nn := _first_available(w2)
	nn.tip.emit(nn, true)
	check(not w2.tip_is_full(), "a tip starts short")
	var ev := InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = true
	root.push_input(ev)
	check(w2.tip_is_full(), "Shift makes it full")
	ev = InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = false
	root.push_input(ev)
	check(not w2.tip_is_full(), "and letting go makes it short again")
	await create_timer(AdvancementData.layout_num("tip_full_s", 0.6) + 0.35).timeout
	check(w2.tip_is_full(), "a stay of %.1f s grows it" % AdvancementData.layout_num("tip_full_s", 0.6))
	nn.tip.emit(nn, false)
	check(not w2.tip_is_full() and not w2.tip_visible(), "and leaving puts it away")
	_free(w2)


func _repair_live() -> void:
	var cfg := AdvancementData.apply_cfg()
	var live: Array = cfg.get("live", [])
	var w := _open("earth")
	await frames(3)
	var ribbon := AdvancementData.word("ribbon")
	check(not ribbon.to_lower().contains("not worn in matches yet"), "the ribbon no longer says nothing is worn in matches (%s)" % ribbon)
	check(ribbon.to_lower().contains("dot") and ribbon.to_lower().contains("preview"), "it names the green dot and the preview")
	_free(w)
	var marked := 0
	var tip_ok := true
	var stray: Array = []
	for el: String in AdvancementData.ELEMENTS:
		w = _open(el)
		await frames(3)
		for n: AdvancementNode in w.all_nodes():
			if String(n.item.type) == "root":
				continue
			var id := n.first_id()
			var shown := n.live
			if n.is_choice():
				continue
			if shown != AdvancementData.is_live(id):
				stray.append(id)
			if shown:
				marked += 1
				var txt := ""
				for l: Dictionary in AdvancementTip.node_lines(id, w.tree("left" if String(AdvancementData.node(id).side) == "left" else "right").state_of(id), w.work):
					txt += String(l.text) + "\n"
				tip_ok = tip_ok and txt.contains(AdvancementData.word("tip.live"))
		_free(w)
	var expect := 0
	for id: String in live:
		if AdvancementData.is_live(id):
			expect += 1
	check(stray.is_empty(), "a node wears the green dot exactly when loadout_apply.json makes it live (%s)" % [stray])
	check(marked >= expect - 2 and marked > 0, "%d of the %d live picks are on the windows' plain nodes" % [marked, expect])
	check(tip_ok, "each marked pick says 'Plays in matches' in its tip")
	check(AdvancementData.is_live_style("boxing") == bool(cfg.get("enabled", false)) and not AdvancementData.is_live_style("capoeira"), "Boxing plays in matches, Capoeira does not")
	check(not AdvancementData.is_live("earth.shove.split") and not AdvancementData.is_live("no.such.node"), "a held or unknown pick is never live")


func _repair_layout() -> void:
	var worst_gap := 0.0
	var worst_fill := 1.0
	var worst_density := 1.0
	var off_lattice: Array = []
	var no_decor: Array = []
	var bad: Array = []
	var fm: Array = AdvancementData.layout().get("fill_margin", [0, 0, 0])
	for el: String in AdvancementData.ELEMENTS:
		for side: String in AdvancementData.SIDES:
			var p := AdvancementLayout.place(el, side)
			var zone: Rect2 = p.zone
			var ys: Array = []
			var top := INF
			var bot := -INF
			for it: Dictionary in p.items:
				var pos: Vector2 = it.pos
				top = minf(top, pos.y - float(p.icon) / 2.0)
				bot = maxf(bot, pos.y + float(p.icon) / 2.0)
				var y := snappedf(pos.y, 0.5)
				if not y in ys:
					ys.append(y)
			ys.sort()
			var pitch_y := float(p.pitch.y)
			for i in range(1, ys.size()):
				var gap := (float(ys[i]) - float(ys[i - 1])) / pitch_y
				worst_gap = maxf(worst_gap, gap)
			var avail := zone.size.y - float(fm[1]) - float(fm[2])
			worst_fill = minf(worst_fill, (bot - top) / avail)
			# the diamond lattice (2026-10-10 repair of "sparse"): every slot on a lattice point (a whole column on a row of
			# one parity, a half on the other), and the points of the tree's box mostly in use
			var hx := float(p.pitch.x) * 0.5
			var x_min := INF
			var y_min := INF
			for it: Dictionary in p.items:
				x_min = minf(x_min, (it.pos as Vector2).x)
				y_min = minf(y_min, (it.pos as Vector2).y)
			var cells := {}
			var r_max := 0
			var q_max := 0
			for it: Dictionary in p.items:
				var q := roundi(((it.pos as Vector2).x - x_min) / hx)
				var r := roundi(((it.pos as Vector2).y - y_min) / pitch_y)
				cells["%d,%d" % [q, r]] = true
				r_max = maxi(r_max, r)
				q_max = maxi(q_max, q)
				if absf(((it.pos as Vector2).x - x_min) / hx - float(q)) > 0.02 or absf(((it.pos as Vector2).y - y_min) / pitch_y - float(r)) > 0.02:
					off_lattice.append("%s %s %s" % [el, side, it.key])
			var parity := -1
			for k: String in cells:
				var qr := k.split(",")
				var pp := (int(qr[0]) + int(qr[1])) % 2
				if parity == -1:
					parity = pp
				elif pp != parity:
					off_lattice.append("%s %s parity %s" % [el, side, k])
			var points := 0
			for r in r_max + 1:
				for q in q_max + 1:
					if (q + r) % 2 == parity:
						points += 1
			worst_density = minf(worst_density, float(cells.size()) / float(maxi(points, 1)))
			if top < float(fm[1]) - 0.5 or bot > zone.size.y - float(fm[2]) + 0.5:
				bad.append("%s %s %.0f..%.0f" % [el, side, top, bot])
			if side == "left" and (p.decor as Array).is_empty():
				no_decor.append(el)
			# a cross link joins two items one row apart, and is never one of the real links
			for d: Dictionary in p.decor:
				for l: Dictionary in p.links:
					if String(l.from) == String(d.from) and String(l.to) == String(d.to):
						bad.append("%s %s decor repeats a link" % [el, side])
	check(bad.is_empty(), "every tree sits inside its zone with the fill margin kept clear (%s)" % [bad])
	check(worst_gap <= 1.3, "no hole between two rows of a tree: the widest is %.2f row pitches (it was 1.6)" % worst_gap)
	check(worst_fill >= 0.6, "every tree fills at least 60%% of its zone's height (%.2f)" % worst_fill)
	check(off_lattice.is_empty(), "every slot of every tree is on its diamond lattice %s" % [off_lattice.slice(0, 5)])
	check(worst_density >= 0.62, "every tree is a dense lattice: at least 62%% of the points in its box hold a slot (%.2f)" % worst_density)
	check(no_decor.is_empty(), "every left tree has its cross links (%s)" % [no_decor])
	# the status line stands in the bar, clear of both trees' zones
	var w := _open("earth")
	await frames(3)
	var st := AdvancementData.window_rect("status")
	var clear := true
	for side: String in AdvancementData.SIDES:
		if AdvancementData.zone(side).intersects(st):
			clear = false
	check(clear and st.position.y >= AdvancementData.window_rect("bottom_bar").position.y, "the status line is in the bottom bar, clear of the trees")
	w.apply_premade(String(AdvancementData.starters("earth")[0].id))
	var wt := String(w.status_text())
	check(wt.length() > 10, "(a long status) %s" % wt)
	_free(w)


func _repair_picker_and_held() -> void:
	var w := _open("air")
	await frames(3)
	w.open_picker()
	await frames(4)
	var pk := w.picker_node()
	var inside := true
	var checked := 0
	var odd: Array = []
	for card in pk.find_children("Card_*", "Panel", true, false):
		var cr := Rect2(Vector2.ZERO, (card as Control).size)
		for c in card.get_children():
			if not c is Label:
				continue
			var lab := c as Label
			checked += 1
			if lab.position.x < -0.5 or lab.position.x + lab.size.x > cr.size.x + 0.5:
				inside = false
				odd.append("%s sticks out of %s" % [lab.text.left(24), card.name])
			# the text, wrapped to the label's width, must fit the label's height (a line cut off or run on is a fail)
			var f := lab.get_theme_font("font")
			var px := lab.get_theme_font_size("font_size")
			var need := f.get_multiline_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, lab.size.x if lab.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0, px, 2 if lab.autowrap_mode != TextServer.AUTOWRAP_OFF else -1)
			if need.x > lab.size.x + 1.0 and lab.autowrap_mode == TextServer.AUTOWRAP_OFF and not lab.clip_text:
				inside = false
				odd.append("%s runs on" % lab.text.left(24))
			if lab.autowrap_mode != TextServer.AUTOWRAP_OFF and need.y > lab.size.y + 2.0:
				inside = false
				odd.append("%s needs %d of %d px" % [lab.text.left(24), int(need.y), int(lab.size.y)])
	check(checked >= 10 and inside, "the class picker's labels stay inside their cards (%d read: %s)" % [checked, odd])
	var cap_text := ""
	for st: Dictionary in AdvancementData.styles("air"):
		if String(st.id) == "capoeira":
			cap_text = AdvancementData.style_state_word("capoeira")
	check(cap_text != "" and cap_text.length() <= 18, "Capoeira's state is a short line (%s)" % cap_text)
	w.close_picker()
	_free(w)
	# a choice whose options are all held or blocked reads held when one of them is held
	var found := 0
	var wrong: Array = []
	for el: String in AdvancementData.ELEMENTS:
		var w2 := _open(el)
		await frames(2)
		for t: AdvancementTree in [w2.tree("left"), w2.tree("right")]:
			for n: AdvancementNode in t.nodes:
				if not n.is_choice():
					continue
				var held_any := false
				var open_any := false
				for id: String in n.ids:
					var stt := t.state_of(id)
					held_any = held_any or stt == "held"
					open_any = open_any or stt in ["available", "worn", "pending_on", "pending_off"]
				if held_any and not open_any:
					found += 1
					if n.state != "held":
						wrong.append("%s %s" % [el, n.name])
		_free(w2)
	check(found > 0 and wrong.is_empty(), "a choice of held (and blocked) options reads held, dashed with '?' (%d, wrong: %s)" % [found, wrong])


func _look() -> void:
	var seen_words := 0
	var bad: Array = []
	var small: Array = []
	for el: String in AdvancementData.ELEMENTS:
		var w := _open(el)
		await frames(3)
		var starters := AdvancementData.starters(el)
		w.apply_premade(String(starters[0].id))
		w.save()
		w.set_slots_open(true)
		w.open_picker()
		await frames(8)
		var texts: Array = []
		_texts(w, texts)
		for n: AdvancementNode in w.all_nodes():
			var lines: Array
			if String(n.item.type) == "root":
				lines = AdvancementTip.root_lines(n.item, el)
			elif n.is_choice():
				var st := {}
				for id: String in n.ids:
					st[id] = "available"
				lines = AdvancementTip.choice_lines(n.ids, st, w.work)
			else:
				lines = AdvancementTip.node_lines(n.first_id(), n.state, w.work)
			for l: Dictionary in lines:
				texts.append(String(l.text))
		for tr: Dictionary in w.rail().traits:
			for l: Dictionary in AdvancementTip.trait_lines(tr):
				texts.append(String(l.text))
		for t: String in texts:
			if t.strip_edges() == "":
				continue
			seen_words += 1
			for m in _re.search_all(t):
				bad.append("%s: %s" % [t.left(40), m.get_string()])
		# at 1280x720 the stage is scaled by 0.8: nothing set under 14 px
		root.size = Vector2i(1280, 720)
		await frames(3)
		var fit := w.stage().scale.x
		if el == "earth":
			check(is_equal_approx(fit, 0.8), "at 1280x720 the window scales to 0.8 (%f)" % fit)
		_small(w, fit, small)
		root.size = Vector2i(1600, 900)
		await frames(2)
		_free(w)
		_reset_store()
	check(seen_words > 600, "the window's lines were read (%d)" % seen_words)
	check(bad.is_empty(), "no show word, no 'bend', no third-party name on screen (%s)" % [bad])
	check(small.is_empty(), "at 1280x720 no text is set under 14 px (%s)" % [small])
	check(AdvancementTheme.S_SMALL * 0.8 >= 14.0, "the smallest type size is 18 authored px (%d)" % AdvancementTheme.S_SMALL)
