extends SceneTree
## Checks the loadout design data (data/loadout/carry_gear.json, loadout_items.json,
## loadout_presets.json, design_fit_check.json; written by tools/loadout/build_loadout_data.py).
## Loads the Actor_B rig once to check the stowed transforms against the real bone rests; about 2 s.
##
##   Godot --headless --path . -s tests/loadout/test_loadout_data.gd
##
## Exit code 0 and "LOADOUT DATA TEST OK" when every check passes; 1 and the failures otherwise.
## Run it under a hard time limit like every Godot run.
##
## What it pins (Player_Animation_Project/graph_analysis/loadout/loadout_design.md):
##   - every stowed transform parses with str_to_var(), is orthonormal, matches its quaternion, and
##     bone rest * local reproduces the bind-space transform (so the runtime can use `local` directly)
##   - the first pistol sits on the belt at the right hip (user rule), carried by the pelvis
##   - long weapons ride spineb in long_A / long_B; at most two long weapons in every preset
##   - every preset obeys the gear rules: its points exist on the worn gear, the kinds are allowed there,
##     exclusive points are not both used, pistols <= the gear's pistol points (cap 4), needs are met
##   - the pistol capacity table of the design (belt 2, sash 2, belt + pistol sling 4, cross belts 2)
##   - every source-drawn point records its handover gap; the fit check covers every placement
##   - revision 3 (loadout_design.md changelog): the first pistol hangs at the side seam (the old horn's
##     place, 80-100 deg) with no pre-contact roll (pendulum <= 20 deg, settle and IK decay as clip phases);
##     hanging items yield; slung bow on long_B only, string outward; back loads exclude the quiver; the
##     effective pistol capacity after the other items; the key binding table; sling-all finishes on the stow
##     clips; presets carry a history grade; the review's studies are stored in design_fit_check.json

const CARRY := "res://data/loadout/carry_gear.json"
const ITEMS := "res://data/loadout/loadout_items.json"
const PRESETS := "res://data/loadout/loadout_presets.json"
const FIT := "res://data/loadout/design_fit_check.json"
const RIG := "res://characters/Actor_B.tscn"
const LONG_SLOTS := ["long_A", "long_B"]

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var carry := _load(CARRY)
	var items := _load(ITEMS)
	var presets := _load(PRESETS)
	var fit := _load(FIT)
	if not (carry.is_empty() or items.is_empty() or presets.is_empty() or fit.is_empty()):
		_test_transforms(carry)
		_test_slot_map(carry)
		_test_presets(carry, items, presets)
		_test_capacity(carry)
		_test_handover_and_fit(carry, fit)
		_test_revision3(carry, items, presets, fit)
	if _fails.is_empty():
		print("LOADOUT DATA TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL ", f)
		print("LOADOUT DATA TEST FAILED (%d of %d checks)" % [_fails.size(), _checks])
		quit(1)


func _load(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(d is Dictionary, "%s parses" % path)
	return d if d is Dictionary else {}


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)


func _test_transforms(carry: Dictionary) -> void:
	var scene := load(RIG) as PackedScene
	var inst := scene.instantiate()
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for key: String in carry.points:
		var e: Dictionary = carry.points[key]
		if not e.has("stow"):
			continue
		var st: Dictionary = e.stow
		var loc: Variant = str_to_var(String(st.local))
		_check(loc is Transform3D, "%s: stow.local parses" % key)
		if not (loc is Transform3D):
			continue
		var t: Transform3D = loc
		var b := t.basis
		_check(b.is_conformal() and absf(b.determinant() - 1.0) < 1e-3, "%s: stow basis is a rotation" % key)
		var q := Quaternion(float(st.q[0]), float(st.q[1]), float(st.q[2]), float(st.q[3]))
		var bq := Basis(q.normalized())
		var dq := maxf(maxf((bq.x - b.x).length(), (bq.y - b.y).length()), (bq.z - b.z).length())
		_check(dq < 1e-4, "%s: stow.q matches stow.local (%.6f)" % [key, dq])
		_check(t.origin.distance_to(Vector3(float(st.o[0]), float(st.o[1]), float(st.o[2]))) < 1e-4, "%s: stow.o matches" % key)
		var bi := sk.find_bone(String(st.bone))
		_check(bi >= 0, "%s: bone %s exists" % [key, st.bone])
		if bi < 0:
			continue
		var bind: Transform3D = str_to_var(String(st.bind))
		var got := sk.get_bone_global_rest(bi) * t
		_check(got.origin.distance_to(bind.origin) < 1e-3, "%s: rest(%s) * local = bind (origin %.4f m)" % [key, st.bone,
				got.origin.distance_to(bind.origin)])
		var db := maxf(maxf((got.basis.x - bind.basis.x).length(), (got.basis.y - bind.basis.y).length()),
				(got.basis.z - bind.basis.z).length())
		_check(db < 1e-3, "%s: rest * local = bind (rotation, %.6f)" % [key, db])
	inst.free()


func _test_slot_map(carry: Dictionary) -> void:
	var p: Dictionary = carry.points.get("R_hip.pistol", {})
	_check(not p.is_empty(), "R_hip.pistol exists (user rule: first pistol on the belt at the right hip)")
	if not p.is_empty():
		var o: Array = p.stow.bind_o
		_check(float(o[0]) < -0.1 and float(o[1]) > 0.85 and float(o[1]) < 1.0, "R_hip pistol at the right hip, belt height %s" % [o])
		_check(String(p.bone) == "pelvis", "R_hip pistol rides the pelvis")
	for key: String in carry.points:
		var e: Dictionary = carry.points[key]
		if String(e.point) in LONG_SLOTS or String(e.point) == "quiver":
			_check(String(e.bone) == "spineb", "%s rides spineb" % key)
		if e.has("stow") and String(e.point) in ["R_hip", "L_hip", "back", "back_right", "back_left"]:
			_check(String(e.bone) == "pelvis", "%s (belt) rides the pelvis" % key)


## The gear rules, as the runtime will apply them: points of the worn gear, minus blocked points.
func _gear_points(carry: Dictionary, gear_ids: Array) -> Dictionary:
	var pts := {}
	var blocked := {}
	var excl: Array = []
	for g: String in gear_ids:
		var d: Dictionary = carry.gear[g]
		if d.has("as_waist"):
			d = carry.gear[String(d.as_waist)]
		for pt: String in d.get("points", {}):
			var kinds: Array = pts.get(pt, [])
			for k in d.points[pt]:
				if not k in kinds:
					kinds.append(k)
			pts[pt] = kinds
		for b in d.get("blocks", []):
			blocked[b] = true
		excl.append_array(d.get("exclusive", []))
	for b: String in blocked:
		pts.erase(b)
	return {"points": pts, "exclusive": excl}


func _kind(v: Variant) -> String:
	return (String(v) if v is String else String(v.kind)).get_slice("@", 0)


func _test_presets(carry: Dictionary, items: Dictionary, presets: Dictionary) -> void:
	_check(presets.presets.has(presets.default), "default preset exists")
	var d: Dictionary = presets.presets.get(presets.default, {})
	_check(d.get("items", {}).get("R_hip", "") is String and d.items.R_hip == "pistol", "default preset: pistol at R_hip")
	for pid: String in presets.presets:
		var pr: Dictionary = presets.presets[pid]
		var gp := _gear_points(carry, pr.gear)
		var pts: Dictionary = gp.points
		var used: Dictionary = pr.items
		var longs := 0
		var pistols := 0
		for pt: String in used:
			var k := _kind(used[pt])
			_check(items.kinds.has(k), "%s: kind %s known" % [pid, k])
			_check(pts.has(pt), "%s: point %s provided by the gear" % [pid, pt])
			if pts.has(pt):
				_check(k in pts[pt], "%s: %s allowed at %s" % [pid, k, pt])
			if pt in LONG_SLOTS:
				longs += 1
			if k == "pistol":
				pistols += 1
			var kd: Dictionary = items.kinds.get(k, {})
			for need: String in kd.get("needs", []):
				var found := false
				for v in used.values():
					found = found or _kind(v) == need
				_check(found, "%s: %s needs %s" % [pid, k, need])
			if used[pt] is Dictionary and used[pt].has("count"):
				_check(int(used[pt].count) <= int(kd.get("count_max", 1)), "%s: %s count" % [pid, k])
		_check(longs <= 2, "%s: at most two long weapons" % pid)
		for pair: Array in gp.exclusive:
			_check(not (used.has(pair[0]) and used.has(pair[1])), "%s: %s and %s exclusive" % [pid, pair[0], pair[1]])
		var cap := 0
		for pt: String in pts:
			if "pistol" in pts[pt]:
				cap += 1
		_check(pistols <= mini(cap, int(carry.pistol_cap)), "%s: %d pistols within capacity %d" % [pid, pistols, cap])


func _test_capacity(carry: Dictionary) -> void:
	var want := {"legacy_baked_belt": 2, "belt_tied_behind": 2, "sash_fingerwoven": 2, "military_waist_belt": 2,
			"br_belts_cartridge": 2, "legacy_baked_belt+pistol_sling": 4, "sash_fingerwoven+pistol_sling": 4}
	for combo: String in want:
		var gp := _gear_points(carry, Array(combo.split("+")))
		var n := 0
		for pt: String in gp.points:
			if "pistol" in gp.points[pt]:
				n += 1
		_check(mini(n, int(carry.pistol_cap)) == int(want[combo]), "pistol capacity %s = %d (got %d)" % [combo, want[combo], n])


func _test_handover_and_fit(carry: Dictionary, fit: Dictionary) -> void:
	for key: String in carry.points:
		var e: Dictionary = carry.points[key]
		_check(fit.placements.has(key), "%s: fit check present" % key)
		if not (e.draw as Array).is_empty() and e.has("stow"):
			_check(e.has("handover"), "%s: handover recorded" % key)
			if e.has("handover"):
				_check(float(e.handover.max_gap_m) < 0.25, "%s: handover gap %.3f m < 0.25" % [key, e.handover.max_gap_m])
				_check(bool(e.handover.reach_ik) == (float(e.handover.max_gap_m) > 0.06), "%s: reach_ik flag" % key)
		for s: String in e.get("draw", []):
			_check(carry.draw_sets.has(s), "%s: draw set %s defined" % [key, s])


## LoadoutRules.effective_pistol_capacity (build_loadout_data.py): pistol points still usable after the other items.
func _effective(carry: Dictionary, gear_ids: Array, used: Dictionary) -> int:
	var gp := _gear_points(carry, gear_ids)
	var n := 0
	for p: String in ["R_hip", "back_right", "chest_R", "L_hip", "chest_L"]:
		if not gp.points.has(p) or not "pistol" in gp.points[p]:
			continue
		if used.has(p) and _kind(used[p]) != "pistol":
			continue
		var lost := false
		for pair: Array in gp.exclusive:
			lost = lost or (pair[0] == p and used.has(pair[1])) or (pair[1] == p and used.has(pair[0]))
		if not lost:
			n += 1
	return mini(n, int(carry.pistol_cap))


func _test_revision3(carry: Dictionary, items: Dictionary, presets: Dictionary, fit: Dictionary) -> void:
	# first pistol at the side seam, no pre-contact roll
	var p: Dictionary = carry.points.get("R_hip.pistol", {})
	if not p.is_empty():
		var ang := float(p.stow.angle_deg)
		_check(ang >= 80.0 and ang <= 100.0, "R_hip pistol at the side seam where the old horn sat (80-100 deg): %.1f" % ang)
		_check(not p.has("grab_pose"), "R_hip pistol: no pre-contact grab_pose roll")
		var ho: Dictionary = p.get("handoff", {})
		_check(float(ho.get("pre_contact", {}).get("max_deg", 99)) <= 20.0, "R_hip pistol: pre-contact pendulum <= 20 deg")
		var sp: Array = ho.get("in_hand_settle_phase", [0, 9])
		var ip: Array = ho.get("reach_ik_decay_phase", [0, 9])
		_check(float(sp[1]) > 0.0 and float(sp[1]) <= 0.5, "R_hip pistol: in-hand settle is a clip phase <= 0.5 (%s)" % [sp])
		_check(float(ip[1]) >= 0.3 and float(ip[1]) <= 0.4, "R_hip pistol: reach IK decays over 30-40 %% of the draw (%s)" % [ip])
		_check(float(p.handover.max_gap_m) < 0.10, "R_hip pistol within 10 cm of the source grab (%.3f)" % float(p.handover.max_gap_m))
		_check(float(p.yield_deg) > 0.0, "R_hip pistol yields to the limbs")
	for key: String in ["back.tomahawk", "back_2.tomahawk", "back.atlatl", "L_hip.pistol", "horn.powder_horn"]:
		if carry.points.has(key):
			_check(float(carry.points[key].get("yield_deg", 0.0)) > 0.0, "%s yields (hangs from a hook or strap)" % key)
	for key: String in ["chest_L.pistol", "chest_R.pistol"]:
		if carry.points.has(key):
			_check(float(carry.points[key].get("yield_deg", 0.0)) == 0.0, "%s does not yield (the solver would swing it into the head)" % key)
	# bow: long_B only, string outward, no string ribbon
	_check(Array(items.kinds.bow.slots) == ["long_B"], "bow slots = long_B only")
	_check(not carry.points.has("long_A.bow"), "no long_A.bow placement")
	_check(not "bow" in Array(carry.gear.back_slings.points.long_A), "long_A does not take the bow")
	if carry.points.has("long_B.bow"):
		var ids := []
		for c: Dictionary in carry.points["long_B.bow"].capsules_bind:
			ids.append(String(c.id))
		_check(ids.any(func(i: String) -> bool: return i.ends_with(":string")), "long_B.bow measured with its string capsule")
	# back load takes the quiver place too
	_check("quiver" in Array(carry.gear.back_load.blocks) and "long_B" in Array(carry.gear.back_load.blocks), "back_load blocks long_B and the quiver")
	var gp := _gear_points(carry, ["legacy_baked_belt", "back_slings", "back_load"])
	_check(not gp.points.has("quiver") and not gp.points.has("long_B"), "with a back load: no quiver, no long_B")
	# effective capacity (maxima are pinned in _test_capacity)
	_check(_effective(carry, ["sash_fingerwoven"], {"back": "tomahawk"}) == 1, "sash + back tomahawk: 1 usable pistol point")
	_check(_effective(carry, ["legacy_baked_belt"], {"L_hip": "saber"}) == 1, "belt + saber at L_hip: 1")
	_check(_effective(carry, ["legacy_baked_belt", "pistol_sling"], {"L_hip": "saber"}) == 3, "belt + sling + saber: 3")
	_check(_effective(carry, ["legacy_baked_belt", "pistol_sling"], {}) == 4, "belt + sling: 4")
	# keys: one binding table
	var keys: Dictionary = items.get("keys", {})
	_check(keys.get("bindings", {}).get("sling_all", "") == "KEY_X", "sling_all is X")
	for a in ["weapon_4", "weapon_5", "weapon_6"]:
		_check(keys.get("bindings", {}).has(a), "%s bound" % a)
	var rules: Array = keys.get("rules", [])
	var loaded := false
	var empty := false
	for r: Dictionary in rules:
		loaded = loaded or (r.input == "weapon_3" and String(r.state).contains("LOADED") and String(r.result).begins_with("nothing"))
		empty = empty or (r.input == "weapon_3" and String(r.state).contains("EMPTY") and String(r.result).contains("next loaded"))
		_check(not String(r.result).contains("hands free") or String(r.input).begins_with("sling_all"), "only X puts the weapons away (%s)" % r.input)
	_check(loaded and empty, "key 3: loaded pistol in hand = nothing, empty = next loaded")
	# sling-all finishes on the stow clips
	for ds in ["pistol_no_pack", "bow_left"]:
		var f: Dictionary = carry.draw_sets[ds].get("sling_all_finish", {})
		_check(String(f.get("stand", "")).contains("stow"), "%s: sling-all finish (stand) is the stow clip" % ds)
	# fidelity labels and the explicit musket path
	for key: String in carry.points:
		var e: Dictionary = carry.points[key]
		if not (e.draw as Array).is_empty():
			_check(String(e.get("draw_fidelity", "")) != "", "%s: draw fidelity labelled" % key)
	var mh: Dictionary = carry.points.get("long_A.musket", {}).get("handoff", {})
	_check(mh.has("lift_phase") and mh.has("join_phase") and float(mh.join_phase) < 0.5, "long_A musket: explicit path with clip phases")
	# presets: graded; the realistic ranger kit has no bow; the default keeps today's three weapons
	for pid: String in presets.presets:
		_check(presets.presets[pid].has("grade") or pid != presets.default, "%s: history grade" % pid)
	_check(presets.presets.has("ranger_1758"), "ranger_1758 preset exists")
	if presets.presets.has("ranger_1758"):
		var bows := 0
		for v in presets.presets.ranger_1758.items.values():
			bows += 1 if _kind(v) == "bow" else 0
		_check(bows == 0, "ranger_1758 carries no bow")
	# the review's studies are stored with the fit check
	var rev: Dictionary = fit.get("revision", {})
	for sec in ["r_hip", "l_hip", "horn", "bow", "musket_path", "draw_paths", "ride_prone", "traversal", "camera", "holster_finish", "yield"]:
		_check(rev.has(sec), "design_fit_check.json revision.%s present" % sec)
	_check(fit.has("design_candidates"), "design_fit_check.json keeps the dz_* candidates")
	if rev.has("bow"):
		_check(not bool(rev.bow.string_ribbon_rev1.passes), "rev 1 string ribbon fails the length test (so it is dropped)")
	if rev.has("r_hip"):
		var rows: Dictionary = rev.r_hip.candidates
		var two_anchor_straight := 0
		for cid: String in rows:
			if cid.begins_with("dz4_rhip_a"):
				two_anchor_straight += 1
		_check(two_anchor_straight >= 5, "two-anchor straight-down right-hip candidates measured (71-125 deg): %d" % two_anchor_straight)
