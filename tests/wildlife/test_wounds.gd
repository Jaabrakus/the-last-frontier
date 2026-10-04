extends SceneTree
## Wounds on game (user 2026-09-28: heart, lungs, gut, leg, graze; WildlifeSpecies.WOUNDS, WildAnimal.wound_at), on the
## real level with its wildlife, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_wounds.gd -- wildlife=on
##
##   where     a shot from the side through the heart, the lungs, the gut, the shoulder, the haunch, the spine at the withers,
##             over the back and at the head makes that wound: each traced through the deer's fitted body (Anatomy; the user
##             2026-10-03, hits worked out in the body), the worst of what it crossed the wound (WildAnimal.wound_at)
##   (the wounds below are shot through it too: at its heart, its near lung (an arrow, stopping in it), its gut, its near femur,
##   and just over its back for the graze)
##   heart     it drops within seconds, not far off; big drops close together
##   lungs     it runs on a while and drops; its drops are the lungs' froth
##   gut       it lives on minutes, the bleeding not stopping; unpushed it lies up; sparse wide dark drops
##   leg       it limps while the wound bleeds hard, the wound clots and stops; it lives
##   graze     a few drops, soon stopped; it heals
##   mend      (user 2026-09-28: "the weakest one heals"): fed, it mends faster than starving; a weak wolf leaves the
##             chase to the pack, and at the kill it feeds first, mending
## Ends with "WOUNDS TEST PASSED (<n> checks)" or "WOUNDS TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var w: WildlifeSpawner
var p: FrontierPlayer
var _used: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	w = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	p = current_scene.get_node("Player") as FrontierPlayer
	_expect(w != null, "the level has its wildlife (wildlife=on)")
	if w == null:
		_end()
		return
	p.ignore_mouse_capture = true
	w._restock_t = 1e9
	p.global_position = Vector3(0.0, FrontierTerrain.height_at(0.0, 8.0) + 0.1, 8.0)     # in the fort, out of it
	await _secs(1.0)
	for a in w.animals():
		if a.species == "wolf":
			a.global_position = Vector3(-200.0, FrontierTerrain.height_at(-200.0, 200.0), 200.0)
			a.set_active(false)
	await _where()
	await _heart()
	await _lungs()
	await _gut()
	await _leg()
	await _graze()
	await _mend()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("WOUNDS TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("WOUNDS TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


## A deer not used yet at `at`, calm; the player 90 m off it, out of its sight (an animal further than
## WildlifeSpawner.ACTIVE_D from him sleeps, its wounds with it).
func _deer(at: Vector3) -> WildAnimal:
	var pp := at + Vector3(-90.0, 0.0, 0.0)
	p.global_position = Vector3(pp.x, FrontierTerrain.height_at(pp.x, pp.z) + 0.1, pp.z)
	p.velocity = Vector3.ZERO
	for a in w.animals():
		if a.species == "deer" and not a.is_dead() and not (a in _used):
			_used.append(a)
			a.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.02, at.z)
			a.rotation.y = 0.0
			a.set_active(true)
			a.awareness = 0.0
			a.health = float(a.data.health)
			a._enter(WildAnimal.State.IDLE, 5.0)
			return a
	return null


## The body's frame: [centre, toward the head, up, capsule radius, half-length].
func _frame(a: WildAnimal) -> Array:
	var sb: StaticBody3D = a._zones[0]
	var cap := a._body_capsule()
	var c := sb.global_position
	var axis := sb.global_basis.y.normalized()
	var hb := a._skel.find_bone(String((a.data.head as Array)[1]))
	if (a._skel.global_transform * a._skel.get_bone_global_pose(hb).origin - c).dot(axis) < 0.0:
		axis = -axis
	var up := (Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
	return [c, axis, up, cap.radius, cap.height * 0.5]


## A shot from the side at `at` (horizontal, across the body): [point, direction, part] where it meets the hit zones,
## or [] on a miss.
func _side_shot(a: WildAnimal, at: Vector3) -> Array:
	var f := _frame(a)
	var side := (f[1] as Vector3).cross(Vector3.UP).normalized()
	var q := PhysicsRayQueryParameters3D.create(at + side * 3.0, at - side * 3.0, WildAnimal.HIT_LAYER)
	var r := a.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return []
	return [r.position, -side, String((r.collider as Node).get_meta("hit_part", "body"))]


func _organ(a: WildAnimal, o: Array) -> Vector3:
	var f := _frame(a)
	return (f[0] as Vector3) + (f[1] as Vector3) * float(f[4]) * float(o[0]) + (f[2] as Vector3) * float(f[3]) * float(o[1])


## Where a side shot through `at` wounds `a`, "miss" when it misses.
func _wound_through(a: WildAnimal, at: Vector3) -> String:
	var s := _side_shot(a, at)
	return "miss" if s.is_empty() else a.wound_at(s[0], s[1], s[2])


## `a` shot from the side through `at` for `dmg` (by the player, from the fort's side); `shot`: what struck (Hit.deliver's).
func _hit(a: WildAnimal, at: Vector3, dmg: float, shot := {}) -> String:
	var s := _side_shot(a, at)
	if s.is_empty():
		return "miss"
	Hit.deliver(_zone_of(a, String(s[2])), dmg, s[0], s[1], p, true, shot)
	return a.last_wound


## Where the deer's fitted body has `nm` now (Anatomy), the one of two nearer the side the shots come from (_side_shot's).
func _fitted(a: WildAnimal, names: Array) -> Vector3:
	var sk := a.inspect_skeleton()
	var an := Anatomy.attach_to(sk)
	if an == null:
		return Vector3.INF
	var side := ((_frame(a)[1] as Vector3).cross(Vector3.UP)).normalized()
	var ov := BodyModel.overrides(sk)
	var best := Vector3.INF
	var best_d := -INF
	for nm: String in names:
		var i := an.model.find(nm)
		if i < 0:
			continue
		var at := an.model.shape_world(sk, i, ov, {}).origin
		if at.dot(side) > best_d:
			best_d = at.dot(side)
			best = at
	return best


## Just over the middle of the deer's back (its barrel's top there, 1.5 cm above the skin): a line there meets none of its body
## (nothing stands above the back to get in its way, as the legs do under the belly) and only grazes it.
func _over_back(a: WildAnimal) -> Vector3:
	var sk := a.inspect_skeleton()
	var an := Anatomy.attach_to(sk)
	var m := an.model
	var ov := BodyModel.overrides(sk)
	var top := Vector3.INF
	var c := _frame(a)[0] as Vector3
	var best := INF
	for i in m.shapes.size():
		if String(m.shapes[i].name) != "Barrel":
			continue
		var w := m.shape_world(sk, i, ov, {})
		var d := w.origin.distance_to(c)
		if d < best:
			best = d
			var sz := m.shapes[i].s as Vector3
			var y0 := w * Vector3(0.0, 0.0, -sz.z)
			var y1 := w * Vector3(0.0, 0.0, sz.z)
			top = (y0 if y0.y > y1.y else y1) + Vector3.UP * 0.015
	return top


func _zone_of(a: WildAnimal, part: String) -> Node:
	for z in a._zones:
		if String(z.get_meta("hit_part", "")) == part:
			return z
	return a


func _where() -> void:
	var a := _deer(Vector3(120.0, 0.0, 60.0))
	if a == null:
		_expect(false, "where: a deer")
		return
	await _secs(0.3)
	a.set_physics_process(false)
	a._update_zones()
	for i in 3:
		await physics_frame              # (the zones where they were put, for the space's queries)
	# each a side shot traced through its fitted body (Anatomy.add_wound: the record only, no harm done) and the wound it makes
	# (wound_at: the worst of what the round went through); the lung and the shoulder with an arrow, which stops there
	var side := ((_frame(a)[1] as Vector3).cross(Vector3.UP)).normalized()
	var an := Anatomy.attach_to(a.inspect_skeleton())
	var arrow := {"kind": "arrow", "speed": 45.0}
	var cases := [["heart", _fitted(a, ["Heart"]), {}], ["lungs", _fitted(a, ["Left lung", "Right lung"]), arrow],
			["gut", _fitted(a, ["Intestines"]), {}], ["leg (shoulder)", _fitted(a, ["Left humerus", "Right humerus"]), arrow],
			["leg (haunch)", _fitted(a, ["Left femur", "Right femur"]), {}], ["graze", _over_back(a), {}],
			["spine", _fitted(a, ["T8 vertebra"]), {}], ["head", _fitted(a, ["Brain"]), {}]]
	for c: Array in cases:
		var at: Vector3 = c[1]
		an.add_wound(at + side * 0.6, -side, 30.0, -1.0, c[2])
		var got := a.wound_at(at + side * 0.6, -side, "body")
		var want := String(c[0]).split(" ")[0]
		_expect(got == want, "where: a side shot at the %s makes a %s wound (%s: %s)" % [c[0], want, got, Anatomy.report(an.last_shot.get("lines", []))])
	a.set_physics_process(true)


## Shot at `organ`-ish place, watched till it dies or `max_s`: [seconds, metres from where it was hit, drops laid].
func _watch(a: WildAnimal, max_s: float) -> Array:
	var start := a.global_position
	var n0 := _drops_of(a)
	var t := 0.0
	var far := 0.0
	while t < max_s and not a.is_dead():
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		far = maxf(far, a.global_position.distance_to(start))
	return [t, far, _drops_of(a) - n0]


func _drops_of(a: WildAnimal) -> int:
	var n := 0
	for b: Dictionary in w.animal_blood:
		if b.who == a:
			n += 1
	return n


## The mean size of the newest `n` drops on the ground.
func _mean_size(n: int) -> float:
	var s := 0.0
	var k := 0
	for i in range(w._drops.size() - 1, maxi(w._drops.size() - 1 - n, -1), -1):
		var d: Decal = w._drops[i]
		if is_instance_valid(d):
			s += d.size.x
			k += 1
	return s / maxf(k, 1.0)


func _heart() -> void:
	var a := _deer(Vector3(100.0, 0.0, 100.0))
	if a == null:
		_expect(false, "heart: a deer")
		return
	await _secs(0.3)
	var kind := _hit(a, _fitted(a, ["Heart"]), 30.0)
	var r := await _watch(a, 20.0)
	_expect(kind == "heart" and a.is_dead() and float(r[0]) < 8.0 and float(r[1]) < 80.0,
			"heart: it drops within seconds, not far off (%s: dead %s after %.1f s, %.0f m on)" % [kind, str(a.is_dead()), r[0], r[1]])
	var per_m := float(r[2]) / maxf(float(r[1]), 1.0)
	var size := _mean_size(maxi(int(r[2]) - 3, 1))
	_expect(size > 0.35 and per_m > 1.0, "heart: big drops close together (%.2f m wide, %.1f a metre)" % [size, per_m])
	set_meta("heart_size", size)


func _lungs() -> void:
	var a := _deer(Vector3(60.0, 0.0, 130.0))
	if a == null:
		_expect(false, "lungs: a deer")
		return
	await _secs(0.3)
	# (an arrow: it stops in the near lung; a ball would go on into the heart or the aorta behind it)
	var kind := _hit(a, _fitted(a, ["Left lung", "Right lung"]), 30.0, {"kind": "arrow", "speed": 45.0})
	var look := a.wound_look()
	var r := await _watch(a, 60.0)
	_expect(kind == "lungs" and a.is_dead() and float(r[0]) > 4.0 and float(r[0]) < 45.0,
			"lungs: it runs on a while and drops (%s: dead %s after %.1f s, %.0f m on)" % [kind, str(a.is_dead()), r[0], r[1]])
	var last: Decal = w._drops.back()
	_expect(look == "froth" and last.texture_albedo == w._blood_texture("froth"), "lungs: its drops are the lungs' froth (%s)" % look)


func _gut() -> void:
	var a := _deer(Vector3(130.0, 0.0, 130.0))
	if a == null:
		_expect(false, "gut: a deer")
		return
	await _secs(0.3)
	var kind := _hit(a, _fitted(a, ["Intestines"]), 30.0)
	var rate0 := a.bleed_rate()
	var r := await _watch(a, 45.0)
	var per_m := float(r[2]) / maxf(float(r[1]), 1.0)
	_expect(kind == "gut" and not a.is_dead() and absf(a.bleed_rate() - rate0) < 0.001 and rate0 > 0.0
			and a.health / rate0 < 600.0,
			"gut: alive after 45 s, bleeding on unstopped, minutes to live (%s: %.2f a s, %.0f health)" % [kind, rate0, a.health])
	_expect(a.state == WildAnimal.State.REST, "gut: unpushed, it lies up (%s)" % WildAnimal.State.keys()[a.state])
	var size := _mean_size(3)
	_expect(per_m < 0.6 and a.wound_look() == "gut" and size > 0.12,
			"gut: few drops (%.2f a metre), wide dark smears (%s, %.2f m wide)" % [per_m, a.wound_look(), size])


func _leg() -> void:
	var a := _deer(Vector3(40.0, 0.0, 150.0))
	if a == null:
		_expect(false, "leg: a deer")
		return
	await _secs(0.3)
	var kind := _hit(a, _fitted(a, ["Left femur", "Right femur"]), 30.0)
	var lame0 := a.lame()
	var rate0 := a.bleed_rate()
	await _secs(150.0)
	_expect(kind == "leg" and lame0 and not a.lame(), "leg: it limps while the wound bleeds hard, not once it has clotted (%s)" % kind)
	_expect(not a.is_dead() and a.bleed_rate() == 0.0 and rate0 > 0.5,
			"leg: the wound clots and stops, it lives (%.2f a s at first, %.2f now, %.0f health)" % [rate0, a.bleed_rate(), a.health])


func _graze() -> void:
	var a := _deer(Vector3(150.0, 0.0, 40.0))
	if a == null:
		_expect(false, "graze: a deer")
		return
	await _secs(0.3)
	# (just over its back: the line meets none of its body, and grazes the skin it passes; dealt to its trunk's zone as a hit
	# with no round, which lands on the flesh nearest it)
	var side := ((_frame(a)[1] as Vector3).cross(Vector3.UP)).normalized()
	var at := _over_back(a)
	Hit.deliver(_zone_of(a, "body"), 30.0, at + side * 0.3, -side, p)
	var kind := a.last_wound
	var h0 := a.health
	await _secs(40.0)
	var h1 := a.health
	await _secs(10.0)
	_expect(kind == "graze" and h0 > float(a.data.health) - 20.0 and a.bleed_rate() == 0.0,
			"graze: a light wound, soon stopped (%s: %.0f health after the hit, %.2f a s now)" % [kind, h0, a.bleed_rate()])
	_expect(a.health > h1 and not a.is_dead(), "graze: it heals (%.1f -> %.1f)" % [h1, a.health])


func _mend() -> void:
	# fed against starving, the same wound healed over
	var fed := _deer(Vector3(170.0, 0.0, 90.0))
	var starving := _deer(Vector3(175.0, 0.0, 95.0))
	if fed == null or starving == null:
		_expect(false, "mend: two deer")
		return
	var h := float(fed.data.health) * 0.5
	for k in int(20.0 * Engine.physics_ticks_per_second):
		await physics_frame
		if k == 0:
			fed.health = h
			starving.health = h
		fed.hunger = 0.05
		starving.hunger = 0.95
		fed.awareness = 0.0
		starving.awareness = 0.0
	_expect(fed.health - h > 3.0 * (starving.health - h) and fed.health > h,
			"mend: fed, it mends faster than starving (+%.1f, starving +%.1f in 20 s)" % [fed.health - h, starving.health - h])
	# the pack after a deer, one wolf weak
	var wolves := w.animals().filter(func(a: WildAnimal) -> bool: return a.species == "wolf" and not a.is_dead())
	var g: WildGroup = (wolves[0] as WildAnimal).group if not wolves.is_empty() else null
	if g == null or g.alive().size() < 3:
		_expect(false, "mend: a wolf pack of three or more")
		return
	var spot := Vector3(60.0, 0.0, 60.0)
	var prey := _deer(spot)
	var pp := spot + Vector3(-150.0, 0.0, 0.0)
	p.global_position = Vector3(pp.x, FrontierTerrain.height_at(pp.x, pp.z) + 0.1, pp.z)
	var members := g.alive()
	var weak: WildAnimal = members[members.size() - 1]
	var i := 0
	for a: WildAnimal in members:
		var q := spot + Vector3(-35.0, 0.0, float(i) * 2.5)
		a.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
		a.set_active(true)
		a.awareness = 0.0
		a.hunger = 0.7
		a.health = float(a.data.health)
		a._enter(WildAnimal.State.IDLE, 1.0)
		i += 1
	weak.health = float(weak.data.health) * 0.4
	g.routed_until = -1e9
	g.losses = 0
	g.prey = prey
	g.carcass = null
	g.activity = WildGroup.Activity.HUNT
	g.activity_since = w.now
	g.hunt_since = w.now
	var weak_chased := false
	var others_chased := false
	for k in int(25.0 * Engine.physics_ticks_per_second):
		await physics_frame
		weak.health = minf(weak.health, float(weak.data.health) * 0.4)
		for a: WildAnimal in g.alive():
			if a.state in [WildAnimal.State.CHASE, WildAnimal.State.ATTACK]:
				if a == weak:
					weak_chased = true
				else:
					others_chased = true
		if prey.is_dead():
			break
	_expect(others_chased and not weak_chased, "mend: the pack runs the deer down, the weak wolf leaves the chase to it")
	# at the kill: the weak one feeds first, and mends
	if not prey.is_dead():
		prey.apply_hit(9999.0, prey.global_position + Vector3.UP * 0.6, Vector3.RIGHT, members[0], "vitals")
	i = 0
	for a: WildAnimal in g.alive():
		var q := prey.global_position + Vector3(cos(float(i) * 1.9), 0.0, sin(float(i) * 1.9)) * 1.4
		a.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
		a.hunger = 0.7
		a.awareness = 0.0
		a._enter(WildAnimal.State.EAT, 30.0)
		i += 1
	g.carcass = prey
	g.prey = null
	g.activity = WildGroup.Activity.EAT
	g.activity_since = w.now
	var h0 := weak.health
	for k in int(12.0 * Engine.physics_ticks_per_second):
		await physics_frame
	var others := 0.0
	var n := 0
	for a: WildAnimal in g.alive():
		if a != weak:
			others += a.hunger
			n += 1
	_expect(weak.hunger < others / maxf(n, 1.0), "mend: at the kill the weak wolf feeds first (hunger %.2f, the rest %.2f)" %
			[weak.hunger, others / maxf(n, 1.0)])
	_expect(weak.health > h0, "mend: and mends as it feeds (%.1f -> %.1f)" % [h0, weak.health])
