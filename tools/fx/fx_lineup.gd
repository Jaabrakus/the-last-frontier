extends SceneTree
## Old against new for one element's moves (the Spellbreak effects, SbFx; the owner judges by eye): a Practice against a
## standing dummy of the same element (MatchSetup practice, dummy "stand"), the player and the dummy set 8 m apart on the
## deck, a fixed side camera, and every move/mode of the element cast by the player (BendCast.cast: the same path as a
## bot's, BendEffects / FormEffects; a lock's charge and grow shown by the player's SwayCaster before the release) twice:
## with the switch off (today's look: SbFx.force_on false) and on (SbFx.force_on true and this element forced on,
## SbFx.force_elements, whatever config.json's switches say: the side-by-side the owner picks from before an element goes
## back on). Each row's label says whether the bridge really played that run (SbFx.on). Frames at fixed moments: charge (the lock, or just before
## the release), release (+0.05 s), flight (+0.22 s), impact (the first projectile's end +0.05 s, else +0.45 s; the same
## frame in both runs) and after (+1.1 s).
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/fx/fx_lineup.gd -- el=fire [out=<dir>]
##         [only=fire_blast/punch,fire_wall/wall] [shipped=1]     (the wrapper adds --disable-vsync --max-fps 60, never pins the window)
## shipped=1: the "new" run plays config.json's own switches (nothing forced: what ships, a single move's roles in moves_on
## among them) instead of the whole element forced on.
## Writes <out>/<move>_<old|new>_<phase>.png and <out>/sheet_<n>.png (per move an old row above a new row, the phases across);
## default out: artifacts/fx_integration/lineup/<el>/. Windowed only (it draws). The stage (the Practice, the placing, the
## crosshair, the stills and the sheet) is tools/fx/fx_stage.gd, shared with tools/fx/lightning_shots.gd.

const FxStage := preload("res://tools/fx/fx_stage.gd")

const PHASES := ["charge", "release", "flight", "impact", "after"]
const CELL := Vector2i(448, 252)
const ROWS_PER_SHEET := 12
const LIMIT_S := 900.0

var el := "fire"
var out := ""
var only: Array = []
var shipped := false
var new_run := false                    ## (the run under way: the frames' names, old or new)
var st: FxStage
var rows: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		match kv.get_slice("=", 0):
			"el":
				el = kv.get_slice("=", 1)
			"out":
				out = kv.get_slice("=", 1)
			"only":
				only = Array(kv.get_slice("=", 1).split(",", false))
			"shipped":
				shipped = kv.get_slice("=", 1) in ["1", "on", "true"]
	if out == "":
		out = ProjectSettings.globalize_path("res://").path_join("artifacts/fx_integration/lineup").path_join(el)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("FX LINEUP FAILED (watchdog)")
		quit(2))
	st = FxStage.new(self)
	st.start(el)
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("FX LINEUP FAILED: no practice fight (phase %s)" % [st.mode.phase if st.mode != null else "-"])
		quit(1)
		return
	st.cam = st.side_camera(52.0, 5.4, 1.8, 1.0)
	st.cam.name = "FxLineupCam"
	st.cam.make_current()
	await st.frames(30)
	await st.calibrate_pitch()
	var shots := _shots()
	print("FX LINEUP %s: %d shots" % [el, shots.size()])
	for s: Dictionary in shots:
		var frames := {}
		var imgs := {}
		var live := {}
		for sw in [false, true]:
			new_run = sw
			SbFx.force_on = sw
			SbFx.force_elements = {el: sw}
			if sw and shipped:
				SbFx.force_on = null                  # (as it ships: config.json's switches, moves_on with them)
				SbFx.force_elements = {}
			live["new" if sw else "old"] = SbFx.on(el) or (sw and shipped and SbFx.any_on())   # (shipped: a single move's roles count)
			var got: Array = await _shot(s, frames)
			imgs["new" if sw else "old"] = got
			SbFx.force_on = null
			SbFx.force_elements = {}
		rows.append({"label": String(s.label), "old": imgs.old, "new": imgs.new, "live": live})
	await _sheets()
	print("FX LINEUP DONE %s -> %s" % [el, out])
	quit(0)


## The element's moves and modes: its jab (and the jab's air hit), each key's moves and modes (a grow move twice: tapped
## and grown; key 2's air Slam), its guard.
func _shots() -> Array:
	var outl: Array = []
	var jb := Bending.jab(el)
	if not jb.is_empty():
		outl.append({"id": String(jb.id), "mode": String(jb.mode)})
		if (SwayMoves.move(String(jb.id)).get("bend", {}) as Dictionary).has("air_hit"):
			outl.append({"id": String(jb.id), "mode": "air_hit", "air": true})
	for key: Array in Bending.keys(el):
		for id: String in key:
			var d := SwayMoves.move(id)
			var bd: Dictionary = d.get("bend", {}) if d.get("bend") is Dictionary else {}
			var modes: Variant = d.get("modes")
			if not (modes is Array):
				continue                          # (Mend: a worn wall of one's own to mend)
			for mo: String in modes:
				outl.append({"id": id, "mode": mo})
				var sp: Variant = bd.get(mo)
				if sp is Dictionary and (sp as Dictionary).get("grow") is Dictionary:
					outl.append({"id": id, "mode": mo, "grown": true})
			if bd.has("slam") and not "slam" in (modes as Array):
				outl.append({"id": id, "mode": "slam", "air": true})
	var g := Bending.guard(el)
	if not g.is_empty():
		outl.append({"id": String(g.id), "mode": String(g.mode), "guard": true})
	var keep: Array = []
	for s: Dictionary in outl:
		s["label"] = "%s/%s%s" % [s.id, s.mode, ".grown" if bool(s.get("grown", false)) else ""]
		if only.is_empty() or String(s.label) in only or String(s.id) in only:
			keep.append(s)
	return keep


## One run of shot `s` (frames: the frame numbers of each phase, taken by the first run and kept by the second). Its images.
func _shot(s: Dictionary, frames: Dictionary) -> Array:
	await st.reset()
	st.hide_ui()
	st.aiming = true
	await st.frames(3)
	var imgs: Array = []
	var id := String(s.id)
	var mo := String(s.mode)
	var grown := bool(s.get("grown", false))
	var sp: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(mo, {}) if SwayMoves.move(id).get("bend") is Dictionary else {}
	var locks := grown or String(sp.get("do", "")) == "lightning" or id == "ice" or id == "stone_form"
	var t0 := st.frame
	if locks and st.sway != null:
		st.sway.move = id
		st.sway._pin_id = id
		st.sway._pin_mode = mo
		st.sway._pin_on = true
		st.sway._began()
		if id == "stone_form":
			FormEffects.raise_stone(st.bc, id, mo)
		await st.frames(22)
		if grown:
			st.sway.grown = true
			BendLooks.grow_click(st.sway)
		await st.frames(16)
	else:
		await st.frames(4)
	imgs.append(_snap(id, mo, grown, "charge"))
	if locks and st.sway != null:
		st.sway._end_charge()
		st.sway.move = ""
		st.sway._pin_on = false
	if bool(s.get("air", false)):
		st.p.velocity = Vector3(0.0, 7.0, 0.0)
		await st.frames(16)
	var bolts_before := get_nodes_in_group(BendBolt.GROUP).size() + get_nodes_in_group(GustLift.GROUP).size()
	st.bc.grown = grown
	BendCast.cast(st.bc, id, mo)
	st.bc.grown = false
	var rel := st.frame
	var plan := {"release": 3, "flight": 13, "after": 66}
	var impact_at := int(frames.get("impact", -1))
	var seen := false
	var n_rel := -1
	while st.frame - rel < 70:
		await process_frame
		st.keep()
		var k := st.frame - rel
		var nb := get_nodes_in_group(BendBolt.GROUP).size() + get_nodes_in_group(GustLift.GROUP).size()
		if nb > bolts_before:
			seen = true
		if impact_at < 0 and seen and nb <= bolts_before and n_rel < 0:
			n_rel = k + 3
		if impact_at < 0 and n_rel < 0 and not seen and k >= 12:
			n_rel = 27                             # (nothing thrown: the impact column at +0.45 s)
		for ph: String in ["release", "flight"]:
			if k == int(plan[ph]):
				imgs.append(_snap(id, mo, grown, ph))
		var imp := impact_at if impact_at >= 0 else n_rel
		if imp >= 0 and k == imp:
			imgs.append(_snap(id, mo, grown, "impact"))
			frames["impact"] = imp
			impact_at = imp
		if k == int(plan.after):
			if imgs.size() < 4:
				imgs.append(_snap(id, mo, grown, "impact"))
				frames["impact"] = k
			imgs.append(_snap(id, mo, grown, "after"))
			break
	while imgs.size() < PHASES.size():
		imgs.append(_snap(id, mo, grown, "after"))
	st.aiming = false
	print("  shot %s%s %s: %d frames from the lock, impact +%d" % [id + "/" + mo, ".grown" if grown else "",
			"new" if new_run else "old", rel - t0, int(frames.get("impact", -1))])
	return imgs


func _snap(id: String, mo: String, grown: bool, ph: String) -> Image:
	var name := "%s_%s%s_%s_%s.png" % [id, mo, "_grown" if grown else "", "new" if new_run else "old", ph]
	var img := st.snap(out.path_join(name))
	var small := img.duplicate() as Image
	small.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return small


## The contact sheets: per move its old row above its new row, the phases across, ROWS_PER_SHEET rows a sheet.
func _sheets() -> void:
	var per := ROWS_PER_SHEET / 2
	var n := 0
	for i in range(0, rows.size(), per):
		var cells: Array = []
		var labels: Array = []
		var colours: Array = []
		for r: Dictionary in rows.slice(i, i + per):
			for which in ["old", "new"]:
				# (the label from what the bridge really did that run: a row claiming Spellbreak that drew today's look
				# cannot happen again)
				var lv := bool((r.get("live", {}) as Dictionary).get(which, which == "new"))
				var tag := ("AS SHIPPED" if shipped else "NEW (Spellbreak)") if lv else ("OLD (switch off)" if which == "old" else "NEW? (bridge off!)")
				if which == "old" and lv:
					tag = "OLD? (bridge on!)"
				labels.append("%s\n%s" % [r.label, tag])
				colours.append(Color(0.85, 0.85, 0.85) if not lv else Color(1.0, 0.75, 0.4))
				cells.append(r[which])
		n += 1
		await st.sheet(cells, labels, PHASES, CELL, out.path_join("sheet_%d.png" % n), colours, 210, 22)
