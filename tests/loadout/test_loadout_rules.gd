extends SceneTree
## Loadout rules (scripts/loadout/loadout.gd, loadout_rules.gd, loadout_keys.gd, loadout_arsenal.gd):
##
##   Godot --headless --path . -s tests/loadout/test_loadout_rules.gd        (about 1 s; run under a time limit)
##
## Exit 0 and "LOADOUT RULES TEST OK" when every check passes.
## Pins (source/graph_analysis/loadout/loadout_design.md 1 and 3):
##   - every preset loads, validates, carries at most two long weapons; the default keeps today's weapons
##   - never more than two long weapons: the slot rule for every pair, a third long item is refused (swap)
##   - the pistol count follows the worn gear (the design's table of maxima) and the other carried items
##     (effective capacity); a pistol beyond it is refused with the swap the design names
##   - multiple pistols are separate FlintlockPistol instances with their own loaded state; key 3 draws
##     the next loaded one (binding table 3.1)
##   - gear rules: exclusive points, blocks (back load x long_B and quiver), requires (back_2), needs
##   - save round trip; customizer accessories -> loadout gear

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_test_presets()
	_test_long_slots()
	_test_capacity()
	_test_can_carry()
	_test_validate()
	_test_pistol_instances()
	_test_keys()
	_test_save_and_gear()
	if _fails.is_empty():
		print("LOADOUT RULES TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL ", f)
		print("LOADOUT RULES TEST FAILED (%d of %d checks)" % [_fails.size(), _checks])
		quit(1)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)


func _gear(ids: Array) -> PackedStringArray:
	return PackedStringArray(ids)


func _test_presets() -> void:
	var d := LoadoutData.get_default()
	_check(d.preset_ids().size() >= 8, "eight presets")
	for pid in d.preset_ids():
		var lo := Loadout.from_preset(String(pid))
		var errs := LoadoutRules.validate(lo)
		_check(errs.is_empty(), "preset %s valid: %s" % [pid, errs])
		_check(lo.long_items().size() <= 2, "preset %s: at most two long weapons" % pid)
		_check(lo.in_hand == "" or lo.has_item(lo.in_hand), "preset %s: in_hand carried" % pid)
		# pistol ids follow the draw order
		var ps := lo.pistols()
		for i in ps.size():
			_check(ps[i] == "pistol_%d" % (i + 1), "preset %s: pistol ids in draw order (%s)" % [pid, ps])
		if not ps.is_empty():
			_check(lo.point_of(ps[0]) == "R_hip" or not LoadoutRules.gear_points(lo.gear).points.has("R_hip"),
					"preset %s: the first pistol is the right-hip belt pistol" % pid)
		var cap := LoadoutRules.pistol_capacity(lo.gear, lo.shoulder_ew_sash)
		_check(ps.size() <= int(cap.max), "preset %s: pistols within the gear's capacity" % pid)
	var dflt := Loadout.from_preset(d.default_preset())
	_check(dflt.has_kind("musket") and dflt.has_kind("bow") and dflt.has_kind("pistol"), "default keeps bow, musket, pistol")
	_check(dflt.in_hand == "musket", "default starts with the musket in hand (player.gd switch_weapon(\"musket\"))")
	_check(dflt.point_of("pistol_1") == "R_hip", "default: first pistol on the belt at the right hip")
	_check(dflt.point_of("musket") == "long_A" and dflt.point_of("bow") == "long_B" and dflt.point_of("quiver") == "quiver",
			"default: musket long_A, bow long_B over the quiver")


func _test_long_slots() -> void:
	var exp := {
		"musket+bow": {"musket#1": "long_A", "bow#1": "long_B"},
		"musket+spear_pair": {"musket#1": "long_A", "spear_pair#1": "long_B"},
		"musket+dart_bundle": {"musket#1": "long_A", "dart_bundle#1": "long_B"},
		"bow+spear_pair": {"spear_pair#1": "long_A", "bow#1": "long_B"},
		"bow+dart_bundle": {"dart_bundle#1": "long_A", "bow#1": "long_B"},
		"spear_pair+dart_bundle": {"spear_pair#1": "long_A", "dart_bundle#1": "long_B"},
		"musket+over_under": {"musket#1": "long_A", "over_under#1": "long_B"},
		"bow": {"bow#1": "long_B"},
		"musket": {"musket#1": "long_A"},
	}
	for k: String in exp:
		var kinds: Array = k.split("+")
		var r := LoadoutRules.assign_long_slots(kinds)
		_check(r.ok and r.slots == exp[k], "long slots %s -> %s (got %s)" % [k, exp[k], r.slots])
		kinds.reverse()
		var r2 := LoadoutRules.assign_long_slots(kinds)
		_check(r2.slots == exp[k], "long slots independent of order: %s" % k)
	for trio in [["musket", "bow", "spear_pair"], ["musket", "over_under", "bow"], ["spear_pair", "dart_bundle", "bow"]]:
		_check(not LoadoutRules.assign_long_slots(trio).ok, "three long weapons refused: %s" % [trio])
	_check(not LoadoutRules.assign_long_slots(["bow"], ["long_B"]).ok, "bow needs long_B (a back load blocks it)")


func _test_capacity() -> void:
	var table := [
		[["legacy_baked_belt"], false, 2],
		[["belt_tied_behind"], false, 2],
		[["military_waist_belt"], false, 2],
		[["sash_fingerwoven"], false, 2],
		[["ew_sash"], false, 2],
		[["sash_fingerwoven", "ew_sash"], true, 3],
		[["br_belts_cartridge"], false, 2],
		[["pistol_sling"], false, 2],
		[["legacy_baked_belt", "pistol_sling"], false, 4],
		[["sash_fingerwoven", "pistol_sling"], false, 4],
		[["horn_strap", "shot_pouch_strap"], false, 0],
	]
	for row: Array in table:
		var cap := LoadoutRules.pistol_capacity(_gear(row[0]), bool(row[1]))
		_check(int(cap.max) == int(row[2]), "pistol capacity %s%s = %d (got %d, %s)" % [row[0], " (ew_sash as baldric)" if row[1] else "", row[2], cap.max, cap.points])
	# the first pistol point of every belt is the right hip
	for g in ["legacy_baked_belt", "belt_tied_behind", "military_waist_belt", "sash_fingerwoven"]:
		_check(String(LoadoutRules.pistol_capacity(_gear([g])).points[0]) == "R_hip", "%s: first pistol point R_hip" % g)
	_check(not LoadoutRules.pistol_capacity(_gear(["br_belts_cartridge"])).points.has("R_hip"), "cross belts block R_hip (cartridge box)")
	# effective capacity after the other items (design 1.4)
	var eff := [
		[["legacy_baked_belt"], {"L_hip": "saber"}, 1],
		[["legacy_baked_belt"], {"L_hip": "knife"}, 1],
		[["sash_fingerwoven"], {"back": "tomahawk"}, 1],
		[["sash_fingerwoven"], {"back": "atlatl"}, 1],
		[["legacy_baked_belt", "pistol_sling"], {"L_hip": "saber"}, 3],
		[["sash_fingerwoven", "pistol_sling"], {"back": "tomahawk"}, 3],
		[["legacy_baked_belt"], {"R_hip": "pistol", "L_hip": "pistol"}, 2],
	]
	for row: Array in eff:
		var e := LoadoutRules.effective_pistol_capacity(_gear(row[0]), row[1])
		_check(int(e.max) == int(row[2]), "effective capacity %s with %s = %d (got %d)" % [row[0], row[1], row[2], e.max])


func _test_can_carry() -> void:
	# a third long weapon is refused and the occupant of its preferred slot is offered
	var mb := Loadout.from_preset("musket_bow")
	var r := LoadoutRules.can_carry(mb, "spear_pair")
	_check(not r.ok and r.action == "swap" and (r.swap as Array).has("musket"), "third long weapon refused with a swap (%s)" % r)
	var r2 := LoadoutRules.can_carry(Loadout.from_preset("ranger_1758"), "bow")
	_check(r2.ok and r2.point == "long_B", "ranger + bow: slung on long_B (%s)" % r2)
	var r3 := LoadoutRules.can_carry(Loadout.from_preset("ranger_1758"), "spear_pair")
	_check(r3.ok and r3.point == "long_B", "ranger + spears: long_B (%s)" % r3)
	# pistols follow the gear
	var brace := Loadout.from_preset("brace_of_pistols")
	var rp := LoadoutRules.can_carry(brace, "pistol")
	_check(not rp.ok and (rp.swap as Array) == ["pistol_2"], "belt full (2): third pistol refused, swap the last in draw order (%s)" % rp)
	brace.set_state("pistol_1", "loaded", false)
	var rp2 := LoadoutRules.can_carry(brace, "pistol")
	_check((rp2.swap as Array) == ["pistol_1"], "swap offers the first EMPTY pistol (%s)" % rp2)
	var ranger := Loadout.from_preset("ranger_1758")
	var rp3 := LoadoutRules.can_carry(ranger, "pistol")
	_check(rp3.ok and rp3.point == "L_hip", "ranger: second pistol on the left hip (%s)" % rp3)
	var slung := Loadout.from_preset("ranger_1758")
	slung.gear.append("pistol_sling")
	var added := 0
	while LoadoutRules.can_carry(slung, "pistol").ok and added < 6:
		var rr := LoadoutRules.can_carry(slung, "pistol")
		slung.add_item("pistol", [rr.point], 1, {"loaded": true})
		added += 1
	_check(slung.pistols().size() == 4 and LoadoutRules.validate(slung).is_empty(), "belt + pistol sling carries four pistols (%s)" % [slung.occupancy()])
	_check(slung.point_of("pistol_2") == "chest_R" and slung.point_of("pistol_3") == "L_hip", "pistol ids renumbered in draw order (%s)" % [slung.occupancy()])
	# tomahawks: a second one stacks on the first unless a quiver is worn
	var rt := LoadoutRules.can_carry(Loadout.from_preset("ranger_1758"), "tomahawk")
	_check(rt.ok and rt.action == "count" and rt.point == "back_2", "ranger: second tomahawk stacks at back_2 (%s)" % rt)
	var rt2 := LoadoutRules.can_carry(Loadout.from_preset("musket_bow"), "tomahawk")
	_check(not rt2.ok, "musket_bow: no second tomahawk with a quiver (%s)" % rt2)
	var rs := LoadoutRules.can_carry(Loadout.from_preset("musket_spears"), "spear_pair")
	_check(not rs.ok, "spear pair already full (2)")
	var one := Loadout.from_preset("musket_spears")
	one.set_count("spear_pair", 1)
	var rs2 := LoadoutRules.can_carry(one, "spear_pair")
	_check(rs2.ok and rs2.action == "count", "a thrown spear picked up again adds to the pair (%s)" % rs2)
	# a back load blocks long_B and the quiver: no slung bow
	var pack := Loadout.from_preset("ranger_1758")
	pack.gear.append("back_load")
	var rb := LoadoutRules.can_carry(pack, "bow")
	_check(not rb.ok, "back load: the bow cannot be slung (%s)" % rb)


func _test_validate() -> void:
	var lo := Loadout.from_preset("musket_bow")
	lo.add_item("spear_pair", ["long_A"], 2, {})
	var errs := LoadoutRules.validate(lo)
	_check(_any(errs, "long weapons"), "validate: three long weapons (%s)" % [errs])
	var lo2 := Loadout.from_preset("brace_of_pistols")
	lo2.add_item("pistol", ["back_right"], 1, {"loaded": true})
	_check(_any(LoadoutRules.validate(lo2), "not provided") and _any(LoadoutRules.validate(lo2), "capacity"), "validate: pistol beyond the belt's points")
	var lo3 := Loadout.from_preset("sash_brace")
	lo3.add_item("tomahawk", ["back"], 1, {})
	_check(_any(LoadoutRules.validate(lo3), "exclude"), "validate: sash back_right excludes back (%s)" % [LoadoutRules.validate(lo3)])
	var lo4 := Loadout.from_preset("ranger_1758")
	lo4.remove_item("tomahawk")
	lo4.add_item("tomahawk", ["back_2"], 1, {})
	_check(_any(LoadoutRules.validate(lo4), "requires"), "validate: back_2 needs a tomahawk at back")
	var lo5 := Loadout.from_preset("musket_bow")
	lo5.remove_item("quiver")
	_check(_any(LoadoutRules.validate(lo5), "needs quiver"), "validate: the bow needs its quiver")
	var lo6 := Loadout.from_preset("bow_darts")
	lo6.remove_item("atlatl")
	_check(_any(LoadoutRules.validate(lo6), "needs atlatl"), "validate: darts need the atlatl")
	var lo7 := Loadout.from_preset("musket_bow")
	lo7.item("tomahawk").points.append("back_2")
	lo7.item("tomahawk").count = 2
	_check(_any(LoadoutRules.validate(lo7), "exclude"), "validate: back_2 x quiver")
	var lo8 := Loadout.from_preset("ranger_1758")
	lo8.add_item("pistol", ["long_B"], 1, {})
	_check(_any(LoadoutRules.validate(lo8), "not allowed"), "validate: a pistol is not a long-slot item")


func _any(errs: Array[String], sub: String) -> bool:
	for e in errs:
		if sub in e:
			return true
	return false


func _test_pistol_instances() -> void:
	var lo := Loadout.from_preset("two_braces")
	var ws := LoadoutArsenal.create_weapons(lo)
	var ps := lo.pistols()
	_check(ps.size() == 4, "two braces: four pistols")
	var seen := {}
	for id in ps:
		_check(ws.has(id) and ws[id] is FlintlockPistol, "%s is a FlintlockPistol" % id)
		seen[(ws[id] as Object).get_instance_id()] = true
	_check(seen.size() == 4, "four separate pistol instances")
	# fire pistol_1: only it is empty
	(ws["pistol_1"] as Firearm).loaded = false
	(ws["pistol_1"] as Firearm).state = Firearm.State.EMPTY
	var st := LoadoutArsenal.states(ws)
	_check(not bool(st.pistol_1.loaded) and bool(st.pistol_2.loaded) and bool(st.pistol_3.loaded) and bool(st.pistol_4.loaded),
			"separate loaded states after one shot (%s)" % st)
	LoadoutArsenal.write_states(lo, ws)
	_check(not bool(lo.state_of("pistol_1").loaded) and bool(lo.state_of("pistol_2").loaded), "loaded states saved per pistol")
	# a reload stage belongs to its pistol
	(ws["pistol_3"] as Firearm).set("_stage", 2)
	(ws["pistol_3"] as Firearm).loaded = false
	LoadoutArsenal.write_states(lo, ws)
	_check(int(lo.state_of("pistol_3").stage) == 2 and int(lo.state_of("pistol_2").get("stage", 0)) == 0, "reload stages kept per pistol")
	var ws2 := LoadoutArsenal.create_weapons(lo)
	_check(not (ws2["pistol_1"] as Firearm).loaded and (ws2["pistol_2"] as Firearm).loaded and int((ws2["pistol_3"] as Firearm).get("_stage")) == 2,
			"states restored per pistol")
	# other kinds
	var mb := LoadoutArsenal.create_weapons(Loadout.from_preset("musket_spears"))
	_check(mb.get("musket") is Musket and mb.get("spear_pair") is Throwable and mb.get("tomahawk") is Throwable, "musket and throwables built")
	_check(int((mb["spear_pair"] as Throwable).count) == 2 and int((mb["tomahawk"] as Throwable).count) == 2, "throwable counts from the loadout")
	LoadoutArsenal.free_all(ws)
	LoadoutArsenal.free_all(ws2)
	LoadoutArsenal.free_all(mb)


func _test_keys() -> void:
	var lo := Loadout.from_preset("two_braces")
	var loaded := {"pistol_1": {"loaded": true}, "pistol_2": {"loaded": true}, "pistol_3": {"loaded": true}, "pistol_4": {"loaded": true}}
	var r := LoadoutKeys.resolve(&"weapon_3", lo, "pistol_1", loaded)
	_check(r.do == "none", "key 3 with a loaded pistol in hand: nothing (%s)" % r)
	var st := loaded.duplicate(true)
	st.pistol_1.loaded = false
	r = LoadoutKeys.resolve(&"weapon_3", lo, "pistol_1", st)
	_check(r.do == "switch" and r.target == "pistol_2", "key 3 with an empty pistol: the next loaded one (%s)" % r)
	st.pistol_2.loaded = false
	r = LoadoutKeys.resolve(&"weapon_3", lo, "pistol_2", st)
	_check(r.target == "pistol_3", "key 3 cycles in draw order (%s)" % r)
	st.pistol_3.loaded = false
	st.pistol_4.loaded = false
	r = LoadoutKeys.resolve(&"weapon_3", lo, "pistol_4", st)
	_check(r.do == "none", "no other loaded pistol: nothing, R reloads (%s)" % r)
	r = LoadoutKeys.resolve(&"weapon_3", lo, "musket", {"pistol_1": {"loaded": false}, "pistol_2": {"loaded": true}})
	_check(r.do == "switch" and r.target == "pistol_2", "key 3 from the musket: the first LOADED pistol (%s)" % r)
	r = LoadoutKeys.resolve(&"weapon_3", lo, "", {"pistol_1": {"loaded": false, "stage": 1}, "pistol_2": {"loaded": false, "stage": 3},
			"pistol_3": {"loaded": false}, "pistol_4": {"loaded": false}})
	_check(r.do == "draw" and r.target == "pistol_2", "none loaded: the one with the most reload progress (%s)" % r)
	var mb := Loadout.from_preset("musket_bow")
	_check(LoadoutKeys.resolve(&"weapon_2", mb, "musket").do == "none", "key 2 with the only long gun in hand: nothing")
	_check(LoadoutKeys.resolve(&"weapon_1", mb, "musket").target == "bow", "key 1: holster the musket, draw the bow")
	_check(LoadoutKeys.resolve(&"weapon_1", mb, "bow").do == "none", "same key never puts the weapon away")
	_check(LoadoutKeys.resolve(&"weapon_4", mb, "musket").do == "none", "key 4 without spears: nothing")
	_check(LoadoutKeys.resolve(&"sling_all", mb, "musket").do == "sling_all", "X: hands free")
	_check(LoadoutKeys.resolve(&"sling_all", mb, "").do == "none", "X with hands free: nothing")
	_check(LoadoutKeys.resolve(&"weapon_next", mb, "bow").target == "musket", "wheel: bow -> musket")
	_check(LoadoutKeys.resolve(&"weapon_next", mb, "pistol_1").target == "tomahawk", "wheel: pistols -> tomahawk")
	_check(LoadoutKeys.resolve(&"weapon_prev", mb, "bow").target == "tomahawk", "wheel back wraps to the last category")
	var ranger := Loadout.from_preset("ranger_1758")
	_check(LoadoutKeys.resolve(&"weapon_1", ranger, "musket").do == "none", "ranger has no bow: key 1 does nothing")


func _test_save_and_gear() -> void:
	for pid in LoadoutData.get_default().preset_ids():
		var lo := Loadout.from_preset(String(pid))
		lo.set_state(lo.pistols()[0] if not lo.pistols().is_empty() else "musket", "loaded", false)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(lo.to_dict()))
		var back := Loadout.from_dict(saved)
		var again: Dictionary = JSON.parse_string(JSON.stringify(back.to_dict()))
		_check(JSON.stringify(again) == JSON.stringify(saved) and back.pistols() == lo.pistols() and back.in_hand == lo.in_hand
				and back.items.size() == lo.items.size(), "save round trip %s" % pid)
	var g := LoadoutRules.gear_from_appearance({"accessories.waist": "sash_fingerwoven", "accessories.shoulder": ["pistol_sling", "horn_and_pouch"]}, false)
	var gear: PackedStringArray = g.gear
	_check(gear.has("sash_fingerwoven") and gear.has("pistol_sling") and gear.has("horn_strap") and gear.has("shot_pouch_strap"),
			"customizer accessories -> loadout gear (%s)" % gear)
	_check(int(LoadoutRules.pistol_capacity(gear).max) == 4, "sash + pistol sling from the customizer: four pistols")
	var g2 := LoadoutRules.gear_from_appearance({}, true)
	_check((g2.gear as PackedStringArray).has("legacy_baked_belt"), "no waist accessory on the legacy body: the baked belt")
	var g3 := LoadoutRules.gear_from_appearance({"accessories.waist": "sash_fingerwoven", "accessories.shoulder": ["ew_sash"]}, false)
	_check(bool(g3.shoulder_ew_sash) and int(LoadoutRules.pistol_capacity(g3.gear, true).max) == 3, "ew_sash as a baldric adds the left hip")
