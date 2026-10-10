extends SceneTree
## Critic's probe 2 (read-only on game files): what the player can actually read. For each element, the tooltip lines of every
## node placed in the window are scanned for raw ids, design notes and engine units; the held-and-world-only nodes that are placed
## are listed; the full-lessons and first-win gates are tried through wear_id and apply_code; the longest tooltip is measured.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/ui_audit/critique_details.gd

const OWN := "user://advancement_critique_details.json"
var re_id := RegEx.create_from_string("\\b[a-z]+(?:_[a-z]+)+\\b")
var re_dev := RegEx.create_from_string("(?i)(question \\d|held for|yours to rule|dormant|\\bdeg\\b|the owner|round \\d|2026-|draft|\\bTODO\\b|soak|meta|spec\\b|\\bfrom \\d)")


func _initialize() -> void:
	create_timer(170.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		quit(2))
	_run.call_deferred()


func _run() -> void:
	AdvancementStore.path = OWN
	if FileAccess.file_exists(OWN):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN))
	AdvancementStore.reload_file()
	AdvancementData.reload_data()
	AdvancementLayout.reload_data()
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
	var total_lines := 0
	var dev_hits := 0
	var id_hits := 0
	var longest := 0
	var longest_name := ""
	var per_el_dev := {}
	for el: String in AdvancementData.ELEMENTS:
		var w := AdvancementWindow.open(root, el)
		await process_frame
		await process_frame
		var seen := {}
		for n: AdvancementNode in w.all_nodes():
			if String(n.item.type) == "root":
				continue
			for id: String in n.ids:
				var nd: Dictionary = AdvancementData.node(id)
				if bool(nd.held) and bool(nd.world_only):
					print("  held+world-only is placed: %s (%s) state=%s" % [id, nd.name, n.state])
				var st := "held" if bool(nd.held) else "available"
				var lines: Array = AdvancementTip.node_lines(id, st, w.work)
				var chars := 0
				for l: Dictionary in lines:
					var t := String(l.text)
					chars += t.length()
					total_lines += 1
					var m := re_id.search(t)
					if m != null:
						id_hits += 1
						print("  RAW ID  %-34s '%s' in: %s" % [id, m.get_string(), t.substr(0, 110)])
					var m2 := re_dev.search(t)
					if m2 != null:
						dev_hits += 1
						per_el_dev[el] = int(per_el_dev.get(el, 0)) + 1
						print("  DEVNOTE %-34s '%s' in: %s" % [id, m2.get_string(), t.substr(0, 110)])
				if chars > longest:
					longest = chars
					longest_name = id
		print("-- %s done" % el)
		w.free()
		await process_frame
	print("tooltip lines scanned %d, raw-id hits %d, dev-note hits %d, longest tip %d chars (%s)" % [total_lines, id_hits, dev_hits, longest, longest_name])

	# the gates through the controls a player has
	print("== gates")
	AdvancementData.gates_override = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
	var w := AdvancementWindow.open(root, "earth")
	await process_frame
	await process_frame
	print("  work.gates = ", w.work.gates)
	var by := {}
	for id: String in AdvancementData.node_ids("earth"):
		var c := w.work.why_not_code(id)
		by[c] = int(by.get(c, 0)) + 1
	print("  why_not_code over all earth nodes (4 full lessons left): ", by)
	print("  full_lessons_kinds = ", AdvancementData.switch("full_lessons_kinds", []))
	w.free()
	await process_frame

	AdvancementData.gates_override = {"won": false, "full_left": 0, "first_win": true, "full_lessons": false}
	w = AdvancementWindow.open(root, "earth")
	await process_frame
	await process_frame
	var by2 := {}
	for id: String in AdvancementData.node_ids("earth"):
		var c2 := w.work.why_not_code(id)
		by2[c2] = int(by2.get(c2, 0)) + 1
	print("  before the first win, why_not_code over all earth nodes: ", by2)
	# paste a code carrying picks before the first win, then save
	var donor := AdvancementLoadout.from_starter("earth", String(AdvancementData.starters("earth")[0].id), "")
	var code := donor.code()
	var r := w.apply_code(code)
	print("  paste a full build's code before the first win -> '%s' pending=%s picks=%d" % [r, w.is_pending(), w.work.picks.size()])
	var sv := w.save()
	print("  then Save -> '%s' (saved picks %d)" % [sv, AdvancementStore.slot("earth", 0).picks.size()])
	w.free()
	await process_frame
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}

	# the ribbon, the title strip, text lengths
	print("== names")
	var longest_name_px := 0
	for el2: String in AdvancementData.ELEMENTS:
		for sid: String in AdvancementData.style_ids(el2):
			print("  title %s/%s -> '%s' / '%s'" % [el2, sid, AdvancementData.title(el2, "left", sid), AdvancementData.title(el2, "right", sid)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN))
	print("CRITIQUE DETAILS DONE")
	quit(0)
