extends SceneTree
## The baby, headless (no level): the needs sim (rates, crying, sleep, neglect never harms), feeding refilling hunger and costing the
## mother food without breaking her stomach/reserve, the hold state machine (one holder, handover, laying down, hands and reach
## rules, save round trip, old saves), the care plan, the model and its skin, the cradle piece's data and mesh, and (loading
## characters/Actor_B.tscn) the hold poses on a real skeleton: every pose on both arms puts the wrists on the baby within tolerance,
## no bone flips, the feet stay planted in a squat, the fade in and out.
##   Godot --headless --path . -s tests/companion/test_baby.gd
var fails := 0
var _ran_poses := false


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _child(id: String, born: float, sex := 0.0) -> Dictionary:
	return {"id": id, "name": "Hannah" if sex < 0.5 else "Thomas", "sex": sex, "born_at": born, "mother": "Ruth", "father": "player",
			"kind": "spouse", "seed": 5, "vigor": 1.0, "worker_id": -1}


func _initialize() -> void:
	InputSetup.ensure()
	var cfg := BabyCare.cfg()
	var nd: Dictionary = cfg.needs
	_expect(cfg.has("poses") and (cfg.poses as Dictionary).has_all(["cradle", "shoulder", "feed", "reach"]), "baby.json has the four poses")

	# ---- the needs
	var s := BabyCare.new_state()
	s.hunger = 0.0
	s.tired = 0.0
	s.soiled = 0.0
	s.upset = 0.0
	BabyCare.advance(s, 60.0, {"held": true, "stage": BabyCare.stage_row(1.0)})
	_expect(is_equal_approx(float(s.hunger), float(nd.hunger_per_h)), "an hour fills hunger by the data's rate (%.2f)" % float(s.hunger))
	_expect(is_equal_approx(float(s.tired), float(nd.tired_per_h)) and is_equal_approx(float(s.soiled), float(nd.soiled_per_h)), "tiredness and the wrappings fill too")
	_expect(BabyCare.mood(s) == "content" and not BabyCare.crying(s), "an hour on: content")
	for i in 8:
		BabyCare.advance(s, 30.0, {"held": false, "stage": BabyCare.stage_row(1.0)})
	_expect(BabyCare.crying(s) or bool(s.asleep), "left four hours: it cries (or sleeps): %s" % BabyCare.status_text(s))
	var neglected := BabyCare.new_state()
	neglected.hunger = 0.99
	neglected.soiled = 0.99
	neglected.tired = 0.99
	neglected.upset = 0.99
	neglected.asleep = false
	BabyCare.advance(neglected, 60.0 * 48.0, {"held": false, "stage": BabyCare.stage_row(1.0)})
	var bounded := true
	for k: String in ["hunger", "tired", "soiled", "upset"]:
		bounded = bounded and float(neglected[k]) >= 0.0 and float(neglected[k]) <= 1.0
	_expect(bounded and BabyCare.cry_level(neglected) <= 1.0 and not neglected.has("dead") and not neglected.has("health"),
			"two days of neglect: only crying, louder (level %.2f), all needs stay in 0..1, nothing to die of" % BabyCare.cry_level(neglected))
	var loud := BabyCare.new_state()
	loud.hunger = 0.7
	var louder := BabyCare.new_state()
	louder.hunger = 1.0
	_expect(BabyCare.cry_level(louder) > BabyCare.cry_level(loud) and BabyCare.crying(loud), "the hungrier, the louder")
	# feeding
	var f := BabyCare.new_state()
	f.hunger = 0.9
	BabyCare.feed(f)
	_expect(float(f.hunger) <= 0.0001 and int(f.fed) == 1, "a feed empties hunger (fed %d)" % int(f.fed))
	var w := BabyCare.new_state()
	w.soiled = 0.8
	BabyCare.change(w)
	_expect(float(w.soiled) == 0.0, "changing the wrappings")
	var u := BabyCare.new_state()
	u.upset = 0.9
	BabyCare.soothe(u)
	_expect(float(u.upset) < 0.9 - float(nd.soothe_relief) + 0.001, "rocking soothes (%.2f)" % float(u.upset))
	# sleep
	var sl := BabyCare.new_state()
	sl.hunger = 0.1
	sl.tired = 0.9
	BabyCare.advance(sl, 5.0, {"held": true, "settled": true, "stage": BabyCare.stage_row(1.0)})
	_expect(bool(sl.asleep) and BabyCare.mood(sl) == "asleep" and BabyCare.cry_level(sl) == 0.0, "a tired, fed baby sleeps")
	BabyCare.advance(sl, 60.0 * 6.0, {"held": true, "stage": BabyCare.stage_row(1.0)})
	_expect(not bool(sl.asleep) and float(sl.hunger) > 0.5, "it wakes when rested or hungry (hunger %.2f)" % float(sl.hunger))
	_expect(not BabyCare.stage_row(0.0).is_empty() and String(BabyCare.stage_row(0.0).id) == "newborn" and BabyCare.carried(_child("c", 0.0), 100.0)
			and not bool(BabyCare.stage_row(200.0).carried) and bool(BabyCare.stage_row(200.0).get("placeholder", false)), "stages: a newborn is carried; the sitting stage is a placeholder")

	# ---- nursing costs the mother food (through her core)
	var main := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	var mother := SpouseCore.create(main, AppearanceStore.default_look(), 11)
	var n := mother.core.state.needs
	n["stomach"] = 300.0
	n["reserve"] = 1000.0
	var st0 := float(n.stomach)
	var rs0 := float(n.reserve)
	var took := BabyCare.take_kcal(mother.core, 35.0)
	_expect(is_equal_approx(took, 35.0) and float(n.stomach) < st0 and float(n.reserve) == rs0, "a feed's 35 kcal come from her stomach first (%.0f)" % took)
	took = BabyCare.take_kcal(mother.core, 1000.0)
	_expect(float(n.stomach) >= 0.0 and float(n.reserve) >= 0.0 and took <= st0 + rs0, "an empty stomach is never below zero, the reserve gives the rest (stomach %.0f, reserve %.0f)" % [float(n.stomach), float(n.reserve)])
	n["stomach"] = 0.0
	n["reserve"] = 0.0
	_expect(BabyCare.take_kcal(mother.core, 500.0) == 0.0 and float(n.reserve) == 0.0 and float(n.stomach) == 0.0, "with nothing left, nothing is taken and nothing goes negative")
	n["stomach"] = 400.0
	n["reserve"] = 3000.0
	var burn := BabyCare.nursing_burn(mother.core, 60.0)
	_expect(burn > 0.0 and burn < 60.0, "nursing burns a share of her hourly burn (%.1f kcal an hour)" % burn)
	_expect(BabyCare.nursing_now(_child("c", 0.0), 1440.0 * 30.0) and not BabyCare.nursing_now(_child("c", 0.0), 1440.0 * 400.0), "nursing ends at weaning")

	# ---- who holds it
	var care := BabyCare.new()
	var fam := [_child("child.1", 0.0)]
	care.sync(fam)
	_expect(care.holder_of("child.1") == "spouse" and care.state("child.1").has("hunger"), "a new baby is in the wife's arms")
	_expect(not bool(care.can_take("child.1", "spouse").ok) and care.can_take("child.1", "spouse").reason == "held", "one holder: she already has it")
	_expect(care.can_take("child.1", "player", {"near": false}).reason == "far", "too far to hand over")
	_expect(care.can_take("child.1", "player", {"near": true, "hands": false}).reason == "hands", "the player needs both hands free")
	_expect(care.can_take("child.1", "player", {"near": true, "hands": true, "dead": true}).reason == "dead", "not when dead")
	var r := care.take("child.1", "player", {"near": true, "hands": true})
	_expect(bool(r.ok) and care.holder_of("child.1") == "player" and care.ids_held_by("spouse").is_empty() and care.ids_held_by("player").size() == 1,
			"handed over: the player holds it and she does not")
	var evs := care.pop_events()
	_expect(evs.size() == 1 and evs[0].do == "handover" and evs[0].from == "spouse" and evs[0].to == "player" and care.pop_events().is_empty(), "the handover is one event, drained once")
	_expect(bool(care.give_back("child.1", {"near": true}).ok) and care.holder_of("child.1") == "spouse", "give the baby back")
	care.pop_events()
	_expect(not bool(care.lay_down("child.1", "cradle", {"places": []}).ok) and care.holder_of("child.1") == "spouse", "no cradle: it stays in her arms")
	_expect(bool(care.lay_down("child.1", "cradle", {"places": ["cradle"]}).ok) and care.holder_of("child.1") == "cradle", "laid in the cradle")
	_expect(not bool(care.lay_down("child.1", "bed", {"places": ["bed"]}).ok), "a baby already lying down cannot be laid down again")
	r = care.take("child.1", "spouse", {"near": true})
	var ev: Dictionary = care.pop_events().back()
	_expect(bool(r.ok) and ev.do == "take" and ev.from == "cradle" and care.holder_of("child.1") == "spouse", "taken up from the cradle")
	care.take("child.1", "player", {"near": true, "hands": true})
	care.lay_down("child.1", "bed", {"places": ["bed"]})
	_expect(care.holder_of("child.1") == "bed", "the player lays it on a bed")
	# time and saving
	care.state("child.1")["hunger"] = 0.42
	care.state("child.1")["asleep"] = true
	var saved := care.to_dict()
	var back := BabyCare.new()
	back.load_dict(JSON.parse_string(JSON.stringify(saved)), fam)
	_expect(back.holder_of("child.1") == "bed" and is_equal_approx(float(back.state("child.1").hunger), 0.42) and bool(back.state("child.1").asleep),
			"the holder and the needs survive a save round trip (through JSON)")
	var old := BabyCare.new()
	old.load_dict(null, fam)
	_expect(old.holder_of("child.1") == "spouse" and old.states.size() == 1, "an old save without a baby part: defaults, the wife holding")
	old.load_dict({"states": {"child.1": {"hunger": 7, "tired": -3}}, "holders": {"child.1": "the moon", "child.9": "player"}}, fam)
	_expect(old.holder_of("child.1") == "spouse" and float(old.state("child.1").hunger) == 1.0 and float(old.state("child.1").tired) == 0.0 and not old.holders.has("child.9"),
			"a broken save is clamped, an unknown holder becomes the wife, strangers are dropped")
	var fam2 := [_child("child.1", 0.0), _child("child.2", 500.0, 1.0)]
	old.sync(fam2)
	_expect(old.states.size() == 2 and old.holder_of("child.2") == "spouse", "a second child gets its own state and the wife's arms")
	old.sync([fam2[1]])
	_expect(old.states.size() == 1 and not old.states.has("child.1"), "a child gone from the family is dropped")
	care.tick(60.0, fam, 100.0)
	_expect(float(care.state("child.1").hunger) > 0.42 or not bool(care.state("child.1").asleep), "tick lets time pass for the family")

	# ---- the care plan
	var hungry := BabyCare.new_state()
	hungry.hunger = 0.7
	var free := {"holder": "spouse", "can_feed": true, "free": true, "busy": false, "has_place": true}
	var steps := BabyCare.plan(hungry, free)
	var kinds := steps.map(func(x: Dictionary) -> String: return String(x.do))
	_expect(kinds == ["sit", "care", "stand", "burp"] and steps[1].what == "feed", "hungry: sit, feed, stand, burp over the shoulder (%s)" % str(kinds))
	var in_cradle := free.duplicate()
	in_cradle["holder"] = "cradle"
	kinds = BabyCare.plan(hungry, in_cradle).map(func(x: Dictionary) -> String: return String(x.do))
	_expect(kinds == ["walk", "take", "sit", "care", "stand", "burp"], "hungry in the cradle: she goes, takes it up, then feeds (%s)" % str(kinds))
	var wet := BabyCare.new_state()
	wet.soiled = 0.8
	var wp := BabyCare.plan(wet, free)
	_expect(wp.size() == 3 and wp[0].kind == "kneel" and wp[1].what == "change", "wet: kneel and change the wrappings")
	var fret := BabyCare.new_state()
	fret.upset = 0.9
	_expect(BabyCare.plan(fret, free)[0].do == "rock", "fretful and fed: she rocks it")
	var quiet := BabyCare.new_state()
	quiet.hunger = 0.1
	_expect(BabyCare.plan(quiet, free).is_empty(), "content: nothing to do")
	var asleep := BabyCare.new_state()
	asleep.asleep = true
	kinds = BabyCare.plan(asleep, free).map(func(x: Dictionary) -> String: return String(x.do))
	_expect(kinds == ["walk", "lay"], "asleep in her arms: she lays it in the cradle")
	var working := free.duplicate()
	working["busy"] = true
	working["free"] = false
	kinds = BabyCare.plan(quiet, working).map(func(x: Dictionary) -> String: return String(x.do))
	_expect(kinds == ["walk", "lay"], "going to work: the baby goes down first")
	var no_place := working.duplicate()
	no_place["has_place"] = false
	_expect(BabyCare.plan(quiet, no_place).is_empty(), "no cradle or bed: she keeps carrying it")
	var at_work_cradle := working.duplicate()
	at_work_cradle["holder"] = "cradle"
	_expect(BabyCare.plan(hungry, at_work_cradle).is_empty(), "at work she does not pick it up")
	var pl := free.duplicate()
	pl["holder"] = "player"
	_expect(BabyCare.plan(hungry, pl).is_empty(), "the player has it: she waits")
	var father := free.duplicate()
	father["can_feed"] = false
	kinds = BabyCare.plan(hungry, father).map(func(x: Dictionary) -> String: return String(x.do))
	_expect(not kinds.has("care") and kinds == ["rock"], "the husband cannot feed it: he rocks it (%s)" % str(kinds))
	_expect(BabyCare.line(["feed"]) != "" and BabyCare.line(["refuse", "hands"]) != "", "lines exist in baby.json")

	# ---- the bundle
	var lo := BabyModel.skin_color(0.0)
	var hi := BabyModel.skin_color(1.0)
	_expect(lo.get_luminance() > BabyModel.skin_color(0.5).get_luminance() and BabyModel.skin_color(0.5).get_luminance() > hi.get_luminance(),
			"the skin darkens with the parents' melanin")
	var bm := BabyModel.create(_child("child.1", 0.0), [0.1, 0.9])
	_expect(bm.get_child_count() >= 2 and bm.find_child("Shawl", false, false) != null and not (bm.find_child("Shawl", false, false) as Node3D).visible, "the model is built, the shawl hidden")
	var cried := [0]
	bm.cried.connect(func() -> void: cried[0] += 1)
	bm.set_state("crying", 0.7, false, true)
	bm.set_state("crying", 0.8, false, true)
	_expect(cried[0] == 1 and (bm.find_child("Shawl", false, false) as Node3D).visible, "crying emits the sound hook once; the shawl shows")
	bm.set_state("asleep", 0.0, true, false)
	_expect(not (bm.find_child("Shawl", false, false) as Node3D).visible, "asleep: shawl off")
	bm.free()

	# ---- the cradle piece
	var bd := BuildData.get_default()
	_expect(bd.group_of("cradle") == "Furniture" and not bd.cost("cradle").is_empty(), "the cradle is a Furniture piece with a cost (%s)" % BuildData.cost_text(bd.cost("cradle")))
	var mesh := BuildGeometry.mesh("cradle", 0, {})
	_expect(mesh != null and mesh.get_surface_count() > 0, "the cradle has a mesh")
	var boxes := BuildSnap.inner_local("cradle")
	_expect(not boxes.is_empty() and BuildSnap.FOOT.has("cradle"), "the cradle has an inner box and a footprint")

	print("---- poses (needs the character)")
	_ran_poses = false


func _process(_dt: float) -> bool:
	if _ran_poses:
		return false
	_ran_poses = true
	_poses()
	print("%d failed" % fails)
	quit(1 if fails > 0 else 0)
	return true


func _angle(a: Quaternion, b: Quaternion) -> float:
	return rad_to_deg(a.angle_to(b))


func _poses() -> void:
	var scene := load("res://characters/Actor_B.tscn") as PackedScene
	if scene == null:
		print("skip: Actor_B.tscn does not load")
		return
	var m := scene.instantiate()
	root.add_child(m)
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var h := BabyHold.attach(sk)
	_expect(h != null and h.hold != null and h.attachment.bone_name == "spined", "the hold attaches under the skeleton with its mount on the chest bone")
	_expect(BabyHold.attach(sk) == h, "attaching twice gives the same one")
	var base := {}
	for i in sk.get_bone_count():
		base[i] = sk.get_bone_pose_rotation(i)
	var arms := {"l": ["l_shoulder", "l_elbow"], "r": ["r_shoulder", "r_elbow"]}
	var pts := [Vector3(0.0, 0.55, 0.55), Vector3(0.15, 0.7, 0.5)]
	for side in [1.0, -1.0]:
		for pose in ["cradle", "shoulder", "feed", "reach"]:
			for pt in (pts if pose == "reach" else [Vector3.ZERO]):
				sk.reset_bone_poses()
				h.pose_name = pose
				h.side = side
				h._from = {}
				h._to = h._resolve(pose)
				h._pb = 1.0
				h._engaged = true
				h._w = 1.0
				h._rw = 1.0 if pose == "reach" else 0.0
				h.reach_point = sk.global_transform * pt
				h.alive_motion = false
				h.speed = 0.0
				h._process_modification()
				var l := h.last
				var near_e := (l.near_wrist as Transform3D).origin.distance_to(l.near)
				var far_e := (l.far_wrist as Transform3D).origin.distance_to(l.far)
				var tag := "%s %s side %d" % [pose, str(pt) if pose == "reach" else "", int(side)]
				_expect(near_e < 0.02 and far_e < 0.02, "%s: both wrists on the baby (%.3f, %.3f m)" % [tag, near_e, far_e])
				# the hands really are at the baby's underside: the wrist targets come from the baby's frame
				var baby: Transform3D = l.baby
				var bound_ok := true
				for k in ["near", "far"]:
					var t: Vector3 = l[k]
					bound_ok = bound_ok and t.distance_to(baby.origin) < 0.2
				_expect(bound_ok, "%s: the hands are within 20 cm of the baby's middle" % tag)
				# no flips: no bone turned more than its limit from the animation
				var worst := 0.0
				var worst_bone := ""
				for i in sk.get_bone_count():
					var d := _angle(base[i], sk.get_bone_pose_rotation(i))
					var lim := 200.0
					if d > worst and sk.get_bone_name(i) in ["spinea", "spineb", "spinec", "neck", "heada", "l_elbow", "r_elbow", "pelvis"]:
						worst = d
						worst_bone = sk.get_bone_name(i)
				_expect(worst < 150.0, "%s: no flips (largest turn %s %.0f degrees)" % [tag, worst_bone, worst])
				# the baby's mount is finite and near the chest
				var chest := sk.get_bone_global_pose(sk.find_bone("spined")).origin
				var mount := (l.baby as Transform3D).origin
				_expect(is_finite(mount.x) and (pose != "reach" and mount.distance_to(chest) < 0.5 or pose == "reach"), "%s: the baby sits at the chest" % tag)
				if pose == "reach":
					var ankle := sk.get_bone_global_pose(sk.find_bone("l_ankle")).origin.distance_to(sk.get_bone_global_rest(sk.find_bone("l_ankle")).origin)
					_expect(ankle < 0.01, "%s: the feet stay planted (%.3f m)" % [tag, ankle])
	# the cradle pose is a real cradle: forearm across the body, the near hand over the far side of the midline
	sk.reset_bone_poses()
	h.pose_name = "cradle"
	h.side = 1.0
	h._to = h._resolve("cradle")
	h._from = {}
	h._pb = 1.0
	h._engaged = true
	h._w = 1.0
	h._rw = 0.0
	h.alive_motion = false
	h._process_modification()
	_expect(((h.last.baby as Transform3D).origin.z > 0.1), "the baby is held in front of the chest")
	# walking sway and rocking move it a little, not a lot
	var still := (h.last.baby as Transform3D).origin
	h.alive_motion = true
	h.speed = 1.3
	h._phase = 0.25
	h._t = 3.0
	sk.reset_bone_poses()
	h._process_modification()
	var moved := (h.last.baby as Transform3D).origin.distance_to(still)
	_expect(moved > 0.0005 and moved < 0.06, "walking sway moves the baby a little (%.3f m)" % moved)
	h.rocking = true
	h._rock = 1.0
	h._t = 0.3
	sk.reset_bone_poses()
	h._process_modification()
	_expect((h.last.baby as Transform3D).origin.distance_to(still) < 0.08, "rocking stays gentle")
	# the fade in and out
	var h2 := BabyHold.attach(sk)
	h2._w = 0.0
	h2._engaged = false
	h2.influence = 0.0
	h2.active = false
	h2.engage("cradle", 1.0)
	_expect(h2.engaged() and h2.weight() == 0.0 and h2.active, "engage starts the fade")
	for i in 60:
		h2._process(0.02)
	_expect(is_equal_approx(h2.weight(), 1.0) and is_equal_approx(h2.influence, 1.0), "faded in after the blend time (influence %.2f)" % h2.influence)
	h2.release()
	for i in 60:
		h2._process(0.02)
	_expect(h2.weight() == 0.0 and not h2.active and h2.influence == 0.0, "faded out and switched off")
	h2.set_pose("shoulder")
	h2.engage("feed", -1.0)
	_expect(h2.pose_name == "feed" and h2.side == -1.0, "engage takes a pose and a side")
	m.queue_free()
