extends SceneTree
## Critic's probe (read-only on game files): the Character Advancement window's flows, tried the way a player (and a
## careless one) would. Prints "ok" / "BAD" lines and a FINDINGS list; nothing is asserted to a pass (the point is to look).
## Headless, its own save file. Never opens the character creator.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/ui_audit/critique_flows.gd

const OWN := "user://advancement_critique_flows.json"
const SHOW_WORDS := ["avatar", "bender", "bending", "bend ", "spellbreak", "azeroth", "warcraft", "blizzard", " wow", "ascension", "aang", "korra"]
var findings: Array[String] = []
var checks := 0
var bad := 0


func _initialize() -> void:
	create_timer(170.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		quit(2))
	_run.call_deferred()


func ok(c: bool, what: String, extra := "") -> void:
	checks += 1
	if c:
		print("  ok   ", what)
	else:
		bad += 1
		print("  BAD  ", what, "  ", extra)
		findings.append(what + " " + extra)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	AdvancementStore.path = OWN
	if FileAccess.file_exists(OWN):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN))
	AdvancementStore.reload_file()


func _open(el: String) -> AdvancementWindow:
	var w := AdvancementWindow.open(root, el)
	w.wear_seconds = 0.0
	return w


func _dirty_text(s: String) -> String:
	# raw ids, design-note language, show words or placeholder leftovers in a player string
	var low := s.to_lower()
	for b in SHOW_WORDS:
		if low.contains(b):
			return "show/third-party word '%s'" % b.strip_edges()
	if RegEx.create_from_string("\\b[a-z]+_[a-z_]+\\b").search(s) != null:
		return "raw id with an underscore"
	for t in ["question ", "held for review", "yours to rule", "todo", "tbd", "placeholder", "owner", "draft"]:
		if low.contains(t):
			return "design-note phrase '%s'" % t
	return ""


func _run() -> void:
	AdvancementData.reload_data()
	AdvancementLayout.reload_data()
	_fresh()
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}

	# ---- 1. every node of every element: held / world-only / text hygiene ---------------------------------------------------
	print("== node hygiene")
	var dirty: Array = []
	for el: String in AdvancementData.ELEMENTS:
		var w := _open(el)
		await _frames(2)
		var held_ok := true
		var held_n := 0
		var wo_in_ring := 0
		var shown := {}
		for n: AdvancementNode in w.all_nodes():
			for id: String in n.ids:
				shown[id] = true
		for id: String in AdvancementData.node_ids(el):
			var nd: Dictionary = AdvancementData.node(id)
			if bool(nd.held):
				held_n += 1
				if w.work.can_wear(id) or w.work.why_not_code(id) != "held":
					held_ok = false
			if bool(nd.world_only) and shown.has(id):
				wo_in_ring += 1
			# text on the tip of every node
			for f: String in ["name", "effect", "plus", "minus", "help", "answer"]:
				var s := String(nd.get(f, ""))
				if s != "":
					var d := _dirty_text(s)
					if d != "":
						dirty.append("%s.%s [%s]: %s" % [id, f, d, s.substr(0, 90)])
		ok(held_ok, "%s: every held node refuses with code 'held' (%d held)" % [el, held_n])
		ok(wo_in_ring == 0, "%s: no world-only node is placed in the ring window" % el, "n=%d" % wo_in_ring)
		w.free()
		await process_frame
	print("  dirty player strings in the node data: ", dirty.size())
	for d in dirty.slice(0, 25):
		print("     ", d)
	if dirty.size() > 0:
		findings.append("%d node strings carry design-note or raw-id language, e.g. %s" % [dirty.size(), dirty[0]])

	# ---- 2. budget and caps: wear greedily until each limit message shows --------------------------------------------------
	print("== limits")
	for el: String in AdvancementData.ELEMENTS:
		var w := _open(el)
		await _frames(2)
		w.reset_classic()
		var codes := {}
		var msgs := {}
		for pass_i in 2:
			for id: String in AdvancementData.node_ids(el):
				var code := w.work.why_not_code(id)
				if code != "" and code != "unknown":
					codes[code] = int(codes.get(code, 0)) + 1
					msgs[code] = w.work.why_not(id)
				if code == "":
					w.wear_id(id)
		print("  %s: worn %d, cost %d of %d, codes seen %s" % [el, w.work.picks.size(), w.work.cost(), AdvancementData.budget(), str(codes)])
		for c in msgs:
			var d := _dirty_text(String(msgs[c]))
			ok(d == "", "%s: reason '%s' reads clean" % [el, c], "%s -> %s" % [d, msgs[c]])
			print("       [%s] %s" % [c, msgs[c]])
		ok(w.work.cost() <= AdvancementData.budget(), "%s: never over budget (%d)" % [el, w.work.cost()])
		ok(w.work.valid(true) == "", "%s: a greedy full build is a valid loadout" % el, w.work.valid(true))
		w.free()
		await process_frame

	# ---- 3. excludes both ways ---------------------------------------------------------------------------------------------
	print("== excludes")
	var el := "earth"
	var w := _open(el)
	await _frames(2)
	w.reset_classic()
	var pair := ["", ""]
	for id: String in AdvancementData.node_ids(el):
		var ex: Array = AdvancementData.node(id).excludes
		if not ex.is_empty() and not bool(AdvancementData.node(id).held) and not bool(AdvancementData.node(String(ex[0])).held):
			pair = [id, String(ex[0])]
			break
	if pair[0] != "":
		print("  pair ", pair)
		# wear what the first needs
		for r: String in AdvancementData.node(pair[0]).requires:
			w.wear_id(r)
		var why1 := w.wear_id(pair[0])
		var why2 := w.wear_id(pair[1])
		ok(why1 == "" or why1 != "", "first of the pair: '%s'" % why1)
		ok(why2 != "" or why1 != "", "second refused or first refused: '%s' / '%s'" % [why1, why2])
	else:
		print("  no excluding pair among ring-wearable nodes")
	w.free()
	await process_frame

	# ---- 4. save / undo / reset / slots ------------------------------------------------------------------------------------
	print("== save undo reset slots")
	w = _open("water")
	await _frames(2)
	ok(not w.is_pending(), "fresh slot is not pending")
	ok(w.save() == "", "Save with nothing pending is harmless")
	var starters := AdvancementData.starters("water")
	w.apply_premade(String(starters[0].id))
	ok(w.is_pending(), "premade makes a pending change")
	var n_before := w.work.picks.size()
	ok(w.save() == "", "Save the premade")
	ok(not w.is_pending(), "saved is not pending")
	w.reset_classic()
	ok(w.is_pending() and w.work.picks.is_empty(), "Reset is a pending Classic, not yet saved")
	w.undo()
	ok(w.work.picks.size() == n_before, "Undo brings the saved picks back")
	w.switch_slot(1)
	ok(w.work.picks.is_empty(), "slot 2 is empty")
	w.rename_slot(1, "A very long name that keeps going on and on and on past any sensible plate width")
	w.rename_slot(1, "   ")
	w.rename_slot(1, "<b>bold</b> [color=red]x[/color]")
	w.rename_slot(1, "Quake 🔥")
	print("  slot 2 name after renames: ", AdvancementStore.slot_name("water", 1))
	w.keep_slot(1, true)
	w.switch_slot(0)
	w.wear_slot(1)
	await _frames(3)
	ok(AdvancementStore.worn_index("water") in [0, 1], "wear an empty kept slot is handled (worn=%d)" % AdvancementStore.worn_index("water"))
	w.wear_slot(-1)
	await _frames(3)
	ok(AdvancementStore.worn_index("water") == -1, "Classic can be worn again")
	w.free()
	await process_frame

	# ---- 5. premade builds before the first win -------------------------------------------------------------------------
	print("== newcomer gates")
	AdvancementData.gates_override = {"won": false, "full_left": 0, "first_win": true, "full_lessons": false}
	w = _open("earth")
	await _frames(2)
	var items: Array = w._premade_items()
	for it in items:
		print("   premade item: ", str(it).substr(0, 160))
	w.apply_premade(String(AdvancementData.starters("earth")[0].id))
	var res := w.save()
	print("  save of a premade before the first win -> '", res, "'  pending=", w.is_pending(), " picks=", w.work.picks.size())
	ok(res != "" or w.work.picks.is_empty(), "before the first win a premade cannot be saved with gated picks")
	w.free()
	await process_frame
	AdvancementData.gates_override = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
	w = _open("earth")
	await _frames(2)
	var refused := 0
	for id: String in AdvancementData.node_ids("earth"):
		if w.work.why_not_code(id) == "gate_full":
			refused += 1
	print("  with 4 full lessons left, nodes refused by the gate: ", refused)
	w.free()
	await process_frame
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}

	# ---- 6. class change ----------------------------------------------------------------------------------------------------
	print("== class change")
	for e2: String in AdvancementData.ELEMENTS:
		w = _open(e2)
		await _frames(2)
		var rows: Array = []
		for sid: String in AdvancementData.style_ids(e2):
			var st: Dictionary = AdvancementData.style(sid)
			rows.append("%s:%s%s" % [sid, AdvancementData.style_state_word(sid), "*" if AdvancementData.pickable(sid) else ""])
		print("  %s styles: %s" % [e2, ", ".join(PackedStringArray(rows))])
		for sid: String in AdvancementData.style_ids(e2):
			if not AdvancementData.pickable(sid):
				w.pick_class(sid)
				ok(w.work.style != sid, "%s: unpickable class '%s' is not taken" % [e2, sid])
		w.free()
		await process_frame

	# ---- 7. search and codes with hostile text ---------------------------------------------------------------------------
	print("== search and codes")
	w = _open("earth")
	await _frames(2)
	for q in ["wall", "WALL", "", "   ", "(", "[", "\\", ".*", "wal l", "ü", "🔥", "a".repeat(400), "%s", "\n"]:
		w.set_search(q)
		await process_frame
	ok(true, "hostile search strings did not crash")
	w.set_search("")
	var code_a := ""
	w.apply_premade(String(AdvancementData.starters("earth")[0].id))
	w.copy_code()
	code_a = w.work.code()
	print("  code: ", code_a)
	for junk in ["", "garbage", "TB1", "TB1-", code_a.substr(0, code_a.length() - 3), code_a + "zzzz", "TB1-0-0-0", "<script>"]:
		var r := w.apply_code(junk)
		ok(true, "apply_code('%s') -> '%s'" % [junk.substr(0, 24), r])
	var w2 := _open("fire")
	ok(w2 == w, "open() twice under one parent returns the one already open")
	var cross := w.apply_code(AdvancementLoadout.new("water", "", []).code())
	print("  another element's code -> '", cross, "'")
	w.free()
	await process_frame

	# ---- 8. keys: arrows, Enter, Delete, Esc ----------------------------------------------------------------------------------
	print("== keyboard")
	w = _open("air")
	await _frames(3)
	w.reset_classic()
	root.gui_release_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	root.push_input(key)
	await _frames(2)
	var fo := root.gui_get_focus_owner()
	ok(fo is AdvancementNode, "first arrow key focuses a node", str(fo))
	var steps := 0
	var seen := {}
	for dir in [KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN]:
		var k := InputEventKey.new()
		k.keycode = dir
		k.pressed = true
		root.push_input(k)
		await process_frame
		var f2 := root.gui_get_focus_owner()
		if f2 != null:
			seen[f2.get_instance_id()] = true
		steps += 1
	ok(seen.size() >= 4, "arrows walk across at least 4 different nodes (%d)" % seen.size())
	var tip_up := w.tip_visible()
	ok(tip_up, "focus shows the tip (a keyboard player sees the same text)")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	root.push_input(esc)
	await _frames(3)
	ok(not is_instance_valid(w) or w.is_queued_for_deletion() or not w.is_inside_tree() or true, "Esc handled")
	if is_instance_valid(w) and not w.is_queued_for_deletion():
		ok(not w.tip_visible() or w.prompt_open() or true, "Esc state: tip=%s prompt=%s" % [w.tip_visible(), w.prompt_open()])
		w.free()
	await process_frame

	# ---- 9. a paused game ---------------------------------------------------------------------------------------------------
	print("== paused game")
	paused = true
	w = _open("earth")
	await _frames(3)
	w.reset_classic()
	var first: AdvancementNode = null
	for n: AdvancementNode in w.all_nodes():
		if n.state == "available" and String(n.item.type) == "node" and not n.is_choice():
			first = n
			break
	if first != null:
		w.wear_id(first.ids[0])
		ok(w.work.has(first.ids[0]), "a pick works while the tree is paused")
		var why := w.save()
		print("  save while paused -> '", why, "' status: ", w.status_text())
	w.free()
	paused = false
	await process_frame

	# ---- 10. the ribbon against what the game does -------------------------------------------------------------------------
	print("== ribbon vs live")
	var ribbon := AdvancementData.word("ribbon", "")
	print("  ribbon words: '%s'" % ribbon)
	var live_on := false
	var txt := FileAccess.get_file_as_string("res://data/bending/loadout_apply.json")
	var js: Variant = JSON.parse_string(txt)
	if js is Dictionary:
		live_on = bool((js as Dictionary).get("enabled", false))
		print("  data/bending/loadout_apply.json enabled=", live_on)
	ok(not (live_on and ribbon.to_lower().contains("not worn in matches")), "the on-screen ribbon does not claim matches are unchanged while BendLoadout applies worn loadouts",
			"ribbon='%s' loadout_apply.enabled=%s" % [ribbon, live_on])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN))
	print("---- %d checks, %d bad" % [checks, bad])
	for f in findings:
		print("FINDING: ", f)
	print("CRITIQUE FLOWS DONE")
	quit(0)
