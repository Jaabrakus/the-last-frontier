extends SceneTree
## What a worker can get over follows what she carries (Spouse.refresh_abilities, the tool pool's climb_stakes): a mini-vault's
## 1.0 m bare-handed, a mantle's 1.5 m with climbing stakes in hand; the planner then goes over a chest-high rock with the
## stakes and round it without (WalkGrid.routes: "over"). The stakes are in the start pool, and the outside jobs take them
## when free. Headless.
##   Godot --headless --fixed-fps 120 --path . -s tests/companion/test_walk_abilities.gd -- survival=on fort_plan=on
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 260:
		await physics_frame
	_expect(ToolPool.kinds().has("climb_stakes"), "climb_stakes is a pool kind")
	for job: String in ["hunt", "forage", "firewood"]:
		var n := ToolPool.needs_of(job)
		var found := false
		for g: Variant in n.optional:
			var kinds: Array = (g as Dictionary).get("any", []) if g is Dictionary else (g as Array)
			if "climb_stakes" in kinds:
				found = true
		_expect(found, "the %s job takes climbing stakes when they are free" % job)
	var h := Household.find(self)
	var w := h.add_worker(781, 1.0, ["woodcutting"])
	var hb := h.body_of(w)
	var tp := ToolPool.of(w)
	_expect(tp != null and tp.available("climb_stakes", -1) >= 2, "the start pool has climbing stakes (%d)" % (tp.available("climb_stakes", -1) if tp else -1))
	hb.refresh_abilities()
	_expect(is_equal_approx(float(hb.abilities.climb_m), 1.0), "bare-handed she gets over 1.0 m (%.2f)" % hb.abilities.climb_m)
	# a rock 1.2 m high across the way: over with the stakes, round without
	var g := WalkGrid.of(self)
	var base := Vector3(-30.0, 0.0, 34.0)
	base.y = FrontierTerrain.height_at(base.x, base.z)
	var rock := StaticBody3D.new()
	rock.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.2, 20.0)
	cs.shape = box
	cs.position.y = 0.6
	rock.add_child(cs)
	current_scene.add_child(rock)
	rock.global_position = base
	await physics_frame
	g.dirty(base, 16.0)
	var from := base + Vector3(-6.0, 0.0, 0.0)
	var to := base + Vector3(6.0, 0.0, 0.0)
	var r0 := g.routes(from, to, 0.3, hb.abilities)
	var kinds0 := []
	for r in r0:
		kinds0.append("%s %dm%s" % [r.kind, roundi(r.len), " over" if r.over else ""])
	_expect(not r0.is_empty() and not bool(r0[0].over), "a 1.2 m rock bare-handed: the best way is round it (%s)" % str(kinds0))
	# with the stakes in hand
	tp.held[w.worker_id] = {"climb_stakes": [{"wear": 0.0}]}
	hb.refresh_abilities()
	_expect(is_equal_approx(float(hb.abilities.climb_m), 1.5), "with the stakes she gets over 1.5 m (%.2f)" % hb.abilities.climb_m)
	var r1 := g.routes(from, to, 0.3, hb.abilities)
	var kinds1 := []
	for r in r1:
		kinds1.append("%s %dm%s" % [r.kind, roundi(r.len), " over" if r.over else ""])
	_expect(not r1.is_empty() and bool(r1[0].over) and float(r1[0].len) < 14.5, "with them the best way is over it (%s)" % str(kinds1))
	var around := false
	for r in r1:
		if r.kind == "around":
			around = true
	_expect(around, "and the way round is offered too")
	tp.held.erase(w.worker_id)
	hb.refresh_abilities()
	_expect(is_equal_approx(float(hb.abilities.climb_m), 1.0), "the stakes put back: 1.0 m again")
	print("WALK ABILITIES DONE: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
