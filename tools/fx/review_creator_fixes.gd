extends SceneTree
## Review probe (read-only, headless, writes nothing): the creator-bug-fix hunks of 2026-10-09 that no test covers.
## It reads the copy of the owner's look kept in artifacts/ui_audit/creator/owner_look_copy.json (never the real
## user://appearance/current.json), drives CreatorOptions / CharacterCreator the way the creator's own _ready does, and
## never calls close(true), save_current or mark_offered.
##
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_creator_fixes.gd

const TUB := "res://artifacts/ui_audit/creator/owner_look_copy.json"
var _fails := 0


func ok(cond: bool, msg: String) -> void:
	print("%s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	await _run()
	print("REVIEW PROBE %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)


func _run() -> void:
	var tub := AppearanceStore.load_file(TUB)
	print("tubber: people=%s preset=%s face_variant=%s sex=%s name=%s" % [tub.get("people"), tub.get("preset"),
			tub.get("face_variant"), tub.get("sex"), tub.get("name")])
	print("path used by this run: ", AppearanceStore.current_path())
	ok(AppearanceStore.current_path().begins_with("user://appearance_test/"), "a script run keeps its look under appearance_test")
	# --- the creator's _ready on Tubber, by hand ---
	var look := tub.duplicate(true)
	var pp := CreatorOptions.preset_people(look)
	print("preset_people -> '%s'" % pp)
	ok(pp != "", "Tubber's face preset belongs to another listed people")
	if pp != "":
		look["people"] = pp
	var kept := CreatorOptions.keep_own_face(look)
	var fo := CreatorOptions.options("face", look)
	var cur := CreatorOptions.current("face", look, fo)
	print("face row: n=%d current=%d own_face_kept=%s ids=%s" % [fo.size(), cur, kept, fo.map(func(o: Dictionary) -> String: return String(o.id))])
	ok(cur >= 0, "the Face row holds Tubber's face (index %d)" % cur)
	# stepping away and back keeps it
	var face0 := (look.face as Dictionary).duplicate()
	var l2 := look.duplicate(true)
	CreatorOptions.step("face", l2, 1)
	ok(str(l2.face) != str(face0), "one step moves off the face")
	CreatorOptions.step("face", l2, -1)
	var maxdiff := 0.0
	for k in face0:
		maxdiff = maxf(maxdiff, absf(float(face0[k]) - float((l2.face as Dictionary).get(k, 0.0))))
	ok(CreatorOptions._same_face(l2.face, face0), "one step back returns to the face (largest slider difference %.4f)" % maxdiff)
	# Accept's save pipeline: what validate() leaves of the creator's look (own_face dropped, nothing else lost)
	var v := AppearanceStore.validate(look)
	ok(not v.has(CreatorOptions.OWN_FACE), "validate drops own_face")
	var diff := []
	for k in tub:
		if str(tub[k]) != str(v.get(k)):
			diff.append(k)
	for k in v:
		if not tub.has(k):
			diff.append("+" + String(k))
	print("keys that differ between the owner's look and what Accept would save: ", diff)
	# --- a fine-tuned face: it stays one of the choices ("Your face") ---
	var ft := tub.duplicate(true)
	ft["people"] = pp if pp != "" else String(ft.get("people", ""))
	(ft.face as Dictionary)["face_breadth"] = 0.1
	var kept2 := CreatorOptions.keep_own_face(ft)
	var fo2 := CreatorOptions.options("face", ft)
	ok(kept2 and String(fo2[-1].id) == CreatorOptions.OWN_FACE_ID and CreatorOptions.current("face", ft, fo2) == fo2.size() - 1,
			"a fine-tuned face becomes 'Your face', last, and is the current one (n=%d)" % fo2.size())
	var back := ft.duplicate(true)
	CreatorOptions.step("face", back, 1)
	CreatorOptions.step("face", back, -1)
	ok(str(back.face) == str(ft.face) and String(back.get("preset", "")) == String(ft.get("preset", "")), "step away and back returns to Your face")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen_own := false
	for i in 40:
		var r := CreatorOptions.randomized(ft, rng)
		seen_own = seen_own or str(r.face) == str(ft.face)
	ok(not seen_own, "R never lands on Your face")
	# a people change and back keeps the own face in the row
	var other := CreatorOptions.with_people(ft, "english")
	ok(other.has(CreatorOptions.OWN_FACE), "own_face survives a change of people (KEEP)")
	var home := CreatorOptions.with_people(other, String(ft.people))
	var fo3 := CreatorOptions.options("face", home)
	ok(String(fo3[-1].id) == CreatorOptions.OWN_FACE_ID, "and is in its own people's row again")
	# the other body type: no own face offered there
	var bt2 := CreatorOptions.with_body_type(ft, 2)
	var fo4 := CreatorOptions.options("face", bt2)
	ok(String(fo4[-1].id) != CreatorOptions.OWN_FACE_ID, "body type 2 lists no 'Your face' of body type 1")
	var bt1 := CreatorOptions.with_body_type(bt2, 1)
	ok(String((CreatorOptions.options("face", bt1))[-1].id) == CreatorOptions.OWN_FACE_ID, "back to body type 1 lists it again")
	# --- with_body_type keeps skin / eyes / hair colour / face index ---
	var base := CreatorOptions.with_people({"sex": 1.0}, "chinese" if CharacterPeoples.is_listed("chinese") else CharacterPeoples.default_people())
	base = CreatorOptions.with_body_type(base, 1)
	var skins := CreatorOptions.options("skin", base)
	CreatorOptions.select("skin", base, skins.size() - 3, skins)
	var eyes := CreatorOptions.options("eyes", base)
	CreatorOptions.select("eyes", base, eyes.size() - 1, eyes)
	var hcs := CreatorOptions.options("hair_color", base)
	CreatorOptions.select("hair_color", base, hcs.size() - 1, hcs)
	var faces := CreatorOptions.options("face", base)
	CreatorOptions.select("face", base, 3, faces)
	var w := CreatorOptions.with_body_type(base, 2)
	ok(is_equal_approx(float(w.melanin), float(base.melanin)) and String(w.undertone) == String(base.undertone),
			"body type change keeps the skin (%.3f %s -> %.3f %s)" % [base.melanin, base.undertone, w.melanin, w.undertone])
	ok(String(w.iris) == String(base.iris), "keeps the eyes (%s -> %s)" % [base.iris, w.iris])
	ok(String((w.hair as Dictionary).get("color", "")) == String((base.hair as Dictionary).get("color", "")),
			"keeps the hair colour (%s -> %s)" % [(base.hair as Dictionary).get("color"), (w.hair as Dictionary).get("color")])
	ok(CreatorOptions.current("face", w) == 3, "keeps the face's place (Face 4: now %d)" % CreatorOptions.current("face", w))
	var wb := CreatorOptions.with_body_type(w, 1)
	ok(is_equal_approx(float(wb.melanin), float(base.melanin)) and String(wb.iris) == String(base.iris), "and back again")
	# --- the default look's eyebrows are a row choice ---
	var dl := AppearanceStore.default_look()
	ok(CreatorOptions.current("eyebrows", dl) >= 0, "the default look's Eyebrows row reads a choice (%d)" % CreatorOptions.current("eyebrows", dl))
	var vd := AppearanceStore.validate({"sex": 1.0, "brows": {"thickness": 0.9, "arch": 0.0, "density": 0.5}})
	print("validate of a look with its own brows: eyebrows id = '%s' row index %d" % [vd.get("eyebrows", "<none>"), CreatorOptions.current("eyebrows", vd)])
	# --- first-run flag (reads only) ---
	print("was_offered (test dir): ", AppearanceStore.was_offered(), "  offered_path: ", AppearanceStore.offered_path())
	# --- the creator itself, headless, on Tubber at two window sizes ---
	var prev := root.size
	# (a headless script run starts with a 64x64 window: the first size set needs a few frames to take)
	root.size = Vector2i(1600, 900)
	await frames(10)
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1366, 768)]:
		root.size = size
		await frames(3)
		var c := CharacterCreator.new()
		c.look = tub.duplicate(true)
		root.add_child(c)
		await frames(4)
		var view := Rect2(Vector2.ZERO, Vector2(root.size))
		print("root.size %s visible rect %s" % [root.size, root.get_visible_rect()])
		print("--- window %s: people=%s face row '%s %s'" % [size, c.look.get("people"), (c._row_ui.face.value as Label).text, (c._row_ui.face.count as Label).text])
		ok(String(c.look.get("people", "")) == pp and (c._row_ui.face.value as Label).text.begins_with("Face 1") or cur >= 0, "opens on the face's people with the face selected")
		var hint := c._root.find_child("Hint", true, false) as Control
		var back_b := c._root.find_child("Back", true, false) as Control
		var dice := c._root.find_child("Randomize", true, false) as Control
		var accept := c._root.find_child("Accept", true, false) as Control
		var lp := c._left_panel as Control
		print("hint ", hint.get_global_rect(), " back ", back_b.get_global_rect(), " dice ", dice.get_global_rect(), " accept ", accept.get_global_rect(), " left ", lp.get_global_rect())
		ok(view.encloses(hint.get_global_rect()) and not hint.get_global_rect().intersects(back_b.get_global_rect())
				and not hint.get_global_rect().intersects(dice.get_global_rect()), "%s: the hint strip is on screen and clear of Back and the dice" % size)
		ok(not dice.get_global_rect().intersects(accept.get_global_rect()) and view.encloses(dice.get_global_rect()), "%s: the dice clear Accept" % size)
		print("hint strip right edge %.1f vs left panel right edge %.1f" % [hint.get_global_rect().end.x, lp.get_global_rect().end.x])
		# the clothing view
		# the pickers, headless (the face picker keeps its words without a renderer)
		for prow in ["face", "skin", "hair_style", "eyes"]:
			c._open_picker(prow)
			await frames(2)
			var grid_btns := c._picker.find_children("*", "Button", true, false)
			var cur_i := CreatorOptions.current(prow, c.look)
			print("picker %s: %d buttons, current %d, visible %s" % [prow, grid_btns.size(), cur_i, c._picker.visible])
			ok(grid_btns.size() == CreatorOptions.options(prow, c.look).size(), "%s picker lists every choice" % prow)
			c._picker.hide()
		c._show_clothing(true)
		await frames(4)
		var rp := c._right_panel as Control
		print("clothing: right panel ", rp.get_global_rect(), " title '%s' toggle '%s'" % [c._right_title.text, c._clothing_button.text])
		ok(view.encloses(rp.get_global_rect()), "%s: the Clothing panel is inside the window" % size)
		ok(rp.get_global_rect().position.x >= lp.get_global_rect().end.x, "%s: and clear of the people panel (left %.0f, panel starts %.0f)" % [size, lp.get_global_rect().end.x, rp.get_global_rect().position.x])
		c._show_clothing(false)
		await frames(3)
		ok(c._right_title.text == "Appearance" and c._clothing_button.text == "Clothing", "%s: back to look restores the titles" % size)
		var rp2 := c._right_panel as Control
		ok(view.encloses(rp2.get_global_rect()), "%s: Appearance panel inside the window after the round trip" % size)
		c.close(false)
		await frames(2)
	root.size = prev
	# --- tattoo row view and the sash (stage state only) ---
	var tl := tub.duplicate(true)
	var c2 := CharacterCreator.new()
	c2.look = tl
	root.add_child(c2)
	await frames(3)
	c2._set_focus(Tattoos.ROW)
	await frames(3)
	print("tattoo row: tattoos=%d newest place '%s' hide_slots=%s reveal=%s frame=%s focus=%s" % [Tattoos.list(c2.look).size(),
			c2._newest_tattoo_place(), c2.stage.hide_slots, c2.stage.reveal, c2.stage.frame_name, c2.stage._focus.keys()])
	var arm_place := String(Tattoos.view_of(c2._newest_tattoo_place()).get("frame", ""))
	ok((arm_place in ["arms", "hands"]) == (c2.stage.hide_slots == CharacterCreator.ARM_VIEW_CLEAR), "the sash is hidden exactly when the newest tattoo is on an arm or hand (frame '%s')" % arm_place)
	c2._set_focus("face")
	await frames(3)
	ok(c2.stage.hide_slots.is_empty(), "off the Tattoos row the sash is back")
	# a look with no tattoos: the row frames the bust and does not throw
	c2.look["tattoos"] = []
	c2._set_focus(Tattoos.ROW)
	await frames(3)
	ok(c2.stage.frame_name == "bust" and c2.stage.hide_slots.is_empty(), "no tattoo: the Tattoos row frames the bust (%s)" % c2.stage.frame_name)
	c2.close(false)
	await frames(2)
	await _overlay_check()
	# --- FaceThumbs' stage, headless: its _ready and the dressing loop of render() without the textures ---
	var FT := load("res://scripts/customizer/face_thumbs.gd")
	ok(not FT.available(), "FaceThumbs.available() is false headless (the picker keeps its words)")
	var thumbs: SubViewport = FT.new()
	root.add_child(thumbs)
	await frames(3)
	ok(thumbs.stage != null and thumbs.stage.frame_name == "portrait" and thumbs.stage.side_shift == 0.0, "FaceThumbs' stage is built on the portrait framing, centred")
	var t0 := Time.get_ticks_msec()
	var opts := CreatorOptions.options("face", look)
	var tbase := look.duplicate(true)
	for k: String in FT.FACE_KEYS:
		tbase.erase(k)
	thumbs.stage.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in opts.size():
		var lk := tbase.duplicate(true)
		lk["face"] = (opts[i].face as Dictionary).duplicate()
		thumbs.stage.show_look(lk)
		var bl := thumbs.stage.find_child("FaceBlink", true, false) as FaceBlink
		if bl and bl.body:
			bl.set_blink(0.0)
		await frames(1)
	print("FaceThumbs: %d show_look in %d ms (headless)" % [opts.size(), Time.get_ticks_msec() - t0])
	thumbs.queue_free()
	await frames(2)
	# --- garment_chest on the garments the ring and the creator dress ---
	var GC := load("res://scripts/customizer/garment_chest.gd")
	var n_changed := 0
	var n_seen := 0
	var cat := PlayerOutfit.catalog()
	for id: String in cat:
		var e: Dictionary = cat[id]
		if not (e.get("occupies_regions", []) as Array).any(func(r: String) -> bool: return r in PlayerOutfit.CHEST):
			continue
		var sc := PlayerOutfit.scene_of(String(e.get("glb", "")))
		if sc == null:
			continue
		var inst := sc.instantiate()
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			n_seen += 1
			var sm: Mesh = GC.smoothed(mi.mesh)
			if sm != mi.mesh:
				n_changed += 1
				ok(sm.get_surface_count() == mi.mesh.get_surface_count() and sm.get_aabb().size.distance_to(mi.mesh.get_aabb().size) < 0.05,
						"%s: smoothed mesh keeps its surfaces and size" % id)
				var om := mi.mesh as ArrayMesh
				var nm := sm as ArrayMesh
				var same := om.get_blend_shape_count() == nm.get_blend_shape_count() and om.blend_shape_mode == nm.blend_shape_mode
				var maxd := 0.0
				var lost := []
				for s in om.get_surface_count():
					var a0 := om.surface_get_arrays(s)
					var a1 := nm.surface_get_arrays(s)
					same = same and om.surface_get_material(s) == nm.surface_get_material(s)
					for k in a0.size():
						if (a0[k] == null) != (a1[k] == null):
							lost.append("surface %d array %d" % [s, k])
						elif a0[k] != null and a0[k].size() != a1[k].size():
							lost.append("surface %d array %d size %d -> %d" % [s, k, a0[k].size(), a1[k].size()])
					var p0: PackedVector3Array = a0[Mesh.ARRAY_VERTEX]
					var p1: PackedVector3Array = a1[Mesh.ARRAY_VERTEX]
					if p0.size() == p1.size():
						for q in p0.size():
							maxd = maxf(maxd, p0[q].distance_to(p1[q]))
					same = same and om.surface_get_format(s) & Mesh.ARRAY_FORMAT_BONES == nm.surface_get_format(s) & Mesh.ARRAY_FORMAT_BONES
				ok(same and lost.is_empty() and maxd < 0.02, "%s: skin weights, UVs, material, blend shapes kept; the largest move %.4f m %s" % [id, maxd, lost])
				ok(GC.smoothed(mi.mesh) == sm, "%s: smoothed() is cached (same mesh on a second call)" % id)
		inst.free()
	print("garment_chest: %d chest-region meshes seen, %d smoothed" % [n_seen, n_changed])
	for shp in ["", "sex", "breast_large", "breast_small"]:
		print("apexes under '%s': %s" % [shp, GC.apexes(shp)])
	GC._done.clear()
	var t1 := Time.get_ticks_msec()
	var n_v := 0
	for id: String in cat:
		var e2: Dictionary = cat[id]
		if not (e2.get("occupies_regions", []) as Array).any(func(r: String) -> bool: return r in PlayerOutfit.CHEST):
			continue
		var sc2 := PlayerOutfit.scene_of(String(e2.get("glb", "")))
		if sc2 == null:
			continue
		var inst2 := sc2.instantiate()
		for mi2: MeshInstance3D in inst2.find_children("*", "MeshInstance3D", true, false):
			if mi2.mesh != null:
				var t2 := Time.get_ticks_msec()
				GC.smoothed(mi2.mesh)
				var vcount := 0
				for ss in mi2.mesh.get_surface_count():
					vcount += (mi2.mesh.surface_get_arrays(ss)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				n_v += vcount
				print("  smooth %s: %d vertices, %d blend shapes, %d ms" % [id, vcount, (mi2.mesh as ArrayMesh).get_blend_shape_count(), Time.get_ticks_msec() - t2])
		inst2.free()
	print("garment_chest: all chest garments first-time: %d ms, %d vertices" % [Time.get_ticks_msec() - t1, n_v])
	# the male body in the same garments: does smoothing add a bump where there is no hollow?
	var m_body_sex := 0


## The Fine-tune overlay at two window sizes: its margin and whether the slider label column holds the longest label.
func _overlay_check() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = size
		await frames(3)
		var o := CustomizerOverlay.edit(AppearanceStore.load_file(TUB), func(_r: Dictionary) -> void: pass, self)
		await frames(4)
		var longest := 0.0
		var wide := []
		var rows := 0
		for l: Label in o.find_children("*", "Label", true, false):
			if int(l.custom_minimum_size.x) == CustomizerOverlay.SLIDER_LABEL_W:
				rows += 1
				var w := l.get_minimum_size().x
				longest = maxf(longest, w)
				if w > CustomizerOverlay.SLIDER_LABEL_W + 0.5:
					wide.append("%s (%.0f)" % [l.text, w])
		var view := Rect2(Vector2.ZERO, Vector2(root.size))
		var tabs := o.find_children("*", "TabContainer", true, false)[0] as Control
		var title := o.find_children("*", "Label", true, false)[0] as Control
		print("overlay %s: %d slider rows, longest label %.0f px of %d; title at %s; tabs rect %s; wide labels %s" % [size, rows, longest,
				CustomizerOverlay.SLIDER_LABEL_W, title.get_global_rect().position, tabs.get_global_rect(), wide])
		ok(view.encloses(tabs.get_global_rect()) and title.get_global_rect().position.x >= CustomizerOverlay.MARGIN - 0.5 and wide.is_empty(),
				"%s: the Fine-tune screen keeps its margin, fits the window, and no slider label is wider than its column" % size)
		o.close(false)
		await frames(2)
