extends SceneTree
## The fitted body a shot is worked out in, and the inspect view onto it (the user, 2026-10-03: hit detection and damage off "a
## perfect skeleton mesh", the viewer the window onto it), headless, in the real level:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/fx/test_inspect_view.gd -- survival=on
##
##   model    a marine's body: the bones (C1-L5, the ribs, the sternum, the clavicles and scapulae, humerus, radius, ulna, the hand,
##            the pelvis and sacrum, femur, kneecap, tibia, fibula, the foot, the skull and jaw), the brain and brainstem, the cord,
##            the organs, and the vessels on their bones (the carotid on the neck's, the femoral on the thigh's ...); a deer's
##   thigh    a musket ball (the game's Projectile into Hit.deliver) through a marine's left femur from the front: fractured,
##            through and through; told to run he limps (no more than his limp x the walk) where an unhurt marine runs
##   chest    a light ball (105 m/s) from the front-left: the left lung, stopped short of the heart; the full charge on the same
##            line (320 m/s): the lung and the heart, mortal: he falls within MORTAL_HEART_S
##   neck     through the left carotid into the cord at C2-C3: the artery cut, the cord badly injured: dead at once
##   record   a marine shot twice (the right femur through and through, a weak ball lodged in the left femur): two shots, the
##            latest flagged, an exit and a stop; both legs broken: down, alive, out of the fight; a ball in the head kills him
##   same     the same line traced twice gives the same record, the same hits the same outcome
##   cost     ms a hit (the path, the labels, the outcome) and the fitted body's build
##   inspect  dead, he offers "Inspect the body (M)" as his tap; the tap opens the view: the game paused, the world's own 3D off,
##            the survival clock still; its shapes, dots (in, out, stopped, the cord), paths (green the latest, white the earlier),
##            the struck bones tinted; LEFT DRAG turns it, the WHEEL brings it closer, RIGHT DRAG and W move it, R resets it, M
##            closes it (the game on, the mouse back); M on the highlighted body (the hotkey) opens it again, Esc closes
##   living   with InspectView.debug_living (dev, tests: inspect_living=on) a living marine offers the row too and the view opens
##            on him; off again, it is not offered
##   deer     an arrow into a deer's near lung (it stops: a lungs wound), a musket ball through its heart (a heart wound: dead, a
##            ragdoll); at rest it offers the inspect row; the view opens on the ragdoll
## Ends with "INSPECT VIEW TEST PASSED (<n> checks)" or "INSPECT VIEW TEST FAILED (<f> of <n>)".

const LANE_X := -1.25
var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
## A nobody's shots (the men hurt by them do not turn on the player).
var shooter: Node3D
var costs := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _ground(x: float, z: float) -> Vector3:
	var h := FrontierTerrain.height_at(x, z)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 3.0, z), Vector3(x, h - 3.0, z), 1, [player.get_rid()])
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3(x, h, z)


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += dt
	return INF


## A marine standing at (x, z), still (his mind put by: he takes no orders of his own while the test shoots him).
func _marine(x: float, z: float, seed_v: int) -> NpcFighter:
	var at := _ground(x, z)
	var sq := NpcSquad.spawn(current_scene, "french_marine", 1, at, {"seed": seed_v, "face": at + Vector3(0, 0, 10)})
	await _until(func() -> bool: return not sq.members.is_empty(), 2.0)
	var f: NpcFighter = sq.members[0]
	f._think_t = 1.0e9
	await _ticks(30)
	return f


## The body's axes now (world): x its left, y its up, z its front (the fitted body's, turned with its chest).
static func _axes(sk: Skeleton3D, m: BodyModel) -> Basis:
	var cb := m.chest_bone
	var rot := sk.get_bone_global_pose(cb).basis.orthonormalized() * sk.get_bone_global_rest(cb).basis.orthonormalized().inverse()
	var b := sk.global_transform.basis.orthonormalized()
	var up := (b * (rot * m.up)).normalized()
	var fwd := (b * (rot * m.fwd)).normalized()
	var left := up.cross(fwd).normalized()
	return Basis(left, up, left.cross(up).normalized())


func _at(m: BodyModel, sk: Skeleton3D, nm: String, nth := 0) -> Vector3:
	var k := 0
	for i in m.shapes.size():
		if String(m.shapes[i].name) == nm:
			if k == nth:
				return m.shape_world(sk, i).origin
			k += 1
	return Vector3.INF


## Holds a fighter's pose still (his clips not stepped) while a shot is aimed and lands: the line worked out from his pose is the
## one the round meets (a flinch moves a thigh a few cm a frame).
func _hold(f: NpcFighter, on: bool) -> void:
	if f.body != null:
		f.body.animate = not on


## A round as the game launches one (Projectile: stepped by rays, into Hit.deliver), from `from` along `dir`, straight (no drop:
## the test's lines are known ones).
func _fire(from: Vector3, dir: Vector3, speed := 320.0, kind := Projectile.Kind.BALL, damage := 120.0) -> void:
	var d := dir.normalized()
	var p := Projectile.new()
	p.kind = kind
	p.velocity = d * speed
	p.gravity = 0.0
	p.drag = 0.0
	p.damage = damage
	p.shooter = shooter
	p.exclude = [player.get_rid()]
	current_scene.add_child(p)
	p.global_position = from
	p.look_at(from + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	await _ticks(int(ceil(2.5 / speed * Engine.physics_ticks_per_second)) + 3)


func _lines(an: Anatomy) -> String:
	return " · ".join(an.last_shot.get("lines", []))


func _has(an: Anatomy, start: String) -> bool:
	for l: String in an.last_shot.get("lines", []):
		if l.begins_with(start):
			return true
	return false


func _run() -> void:
	for i in 25:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(player != null, "the level has the player")
	if player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	for i in 60:
		await process_frame
	NpcSenses.daylight_override = 1.0
	shooter = Node3D.new()
	shooter.name = "TestShooter"
	current_scene.add_child(shooter)
	player.global_position = _ground(12.0, 10.0) + Vector3.UP * 0.1
	await _model()
	await _thigh()
	await _chest()
	await _neck()
	await _record_and_inspect()
	await _living()
	await _deer()
	print("COST: the fitted body built in %.1f ms (a person), %.1f ms (a deer), once a kind; a hit %.3f ms (the path %.3f ms) over %d hits" % [
			float(costs.get("build_human", 0.0)), float(costs.get("build_deer", 0.0)), float(costs.get("hit_ms", 0.0)),
			float(costs.get("trace_ms", 0.0)), int(costs.get("n", 0))])
	_end()


# ---------------------------------------------------------------- the fitted body
func _model() -> void:
	var f := await _marine(LANE_X, -60.0, 51)
	var sk := f.body.sk
	var an := Anatomy.attach_to(sk)
	_expect(an != null and an.model != null and an.model.human, "a marine has a fitted body (%d shapes)" % (an.model.shapes.size() if an else 0))
	if an == null:
		return
	var m := an.model
	costs["build_human"] = m.build_ms
	var missing := []
	var want := ["Skull", "Jaw", "Brain", "Brainstem", "Spinal cord", "Sternum", "Sacrum", "Pelvis", "Heart", "Left lung", "Right lung", "Liver",
			"Stomach", "Spleen", "Left kidney", "Intestines"]
	for i in range(1, 8):
		want.append("C%d vertebra" % i)
	for i in range(1, 13):
		want.append("T%d vertebra" % i)
		want.append("Left rib %d" % i)
		want.append("Right rib %d" % i)
	for i in range(1, 6):
		want.append("L%d vertebra" % i)
	for sd in ["Left ", "Right "]:
		for b in ["clavicle", "scapula", "humerus", "radius", "ulna", "hand", "femur", "kneecap", "tibia", "fibula", "foot"]:
			want.append(sd + b)
	for nm: String in want:
		if m.find(nm) < 0:
			missing.append(nm)
	_expect(missing.is_empty(), "every bone, the brain and brainstem, the cord, the organs (%d structures; missing %s)" % [want.size(), missing])
	# the vessels on their bones
	var on := {"Aorta": ["spined", "spinec", "spineb", "spinea", "pelvis"], "Inferior vena cava": ["spined", "spinec", "spineb", "spinea", "pelvis"],
			"Superior vena cava": ["spined"], "Left carotid artery": ["spined", "neck", "heada"], "Right carotid artery": ["spined", "neck", "heada"],
			"Left jugular vein": ["neck", "heada"], "Left subclavian artery": ["spined", "l_clavicle"], "Left subclavian vein": ["l_clavicle"],
			"Left brachial artery": ["l_shoulder"], "Left brachial vein": ["l_shoulder"], "Left radial artery": ["l_elbow"],
			"Left ulnar artery": ["l_elbow"], "Left iliac artery": ["pelvis"], "Left iliac vein": ["pelvis"], "Left femoral artery": ["l_upper_leg"],
			"Left femoral vein": ["l_upper_leg"], "Left popliteal artery": ["l_knee"], "Right femoral artery": ["r_upper_leg"]}
	var bad := []
	for nm: String in on:
		var n := 0
		for s: Dictionary in m.shapes:
			if String(s.name) == nm:
				n += 1
				if String(s.kind) != "vessel" or not (on[nm] as Array).has(sk.get_bone_name(int(s.bone))):
					bad.append("%s on %s" % [nm, sk.get_bone_name(int(s.bone))])
		if n == 0:
			bad.append(nm + " missing")
	var arteries := m.shapes.filter(func(s: Dictionary) -> bool: return String(s.kind) == "vessel" and String(s.get("vessel", "")) == "artery").size()
	var veins := m.shapes.filter(func(s: Dictionary) -> bool: return String(s.kind) == "vessel" and String(s.get("vessel", "")) == "vein").size()
	_expect(bad.is_empty(), "the vessels ride their bones: the carotids and jugulars the neck's, the aorta and the cava the spine's, the femorals the thighs' (%d artery and %d vein pieces) %s" % [arteries, veins, bad])
	f.get_parent().queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- a ball through the thigh: the femur, a limp
func _thigh() -> void:
	var f := await _marine(LANE_X + 4.0, -62.0, 52)
	var ok := await _marine(LANE_X - 4.0, -62.0, 53)
	var sk := f.body.sk
	var an := Anatomy.attach_to(sk)
	var m := an.model
	_hold(f, true)
	var ax := _axes(sk, m)
	var femur := _at(m, sk, "Left femur")
	await _fire(femur + ax.z * 2.0, -ax.z)
	_hold(f, false)
	print("   thigh: ", _lines(an))
	_expect(f.hits_taken == 1 and _has(an, "Left femur, fractured") and Vector3(an.last_shot.rec.exit) != Vector3.INF,
			"a musket ball through the left thigh: the femur fractured, through and through (%s)" % _lines(an))
	_expect(f.limp <= 0.5 and not f.down and not f.is_dead(), "he limps (x%.2f of the walk), on his feet" % f.limp)
	await _secs(1.0)
	var speeds := []
	for g: NpcFighter in [f, ok]:
		g.go(g.global_position + ax.z * 10.0, NpcFighter.RUN_SPEED, 0.5, true)
	var top := [0.0, 0.0]
	for i in int(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		top[0] = maxf(top[0], Vector2(f.velocity.x, f.velocity.z).length())
		top[1] = maxf(top[1], Vector2(ok.velocity.x, ok.velocity.z).length())
	_expect(top[0] <= NpcFighter.WALK_SPEED * f.limp + 0.05 and top[1] > NpcFighter.WALK_SPEED + 0.5,
			"told to run, the wounded man limps at %.2f m/s at most; the unhurt one runs at %.2f m/s" % [top[0], top[1]])
	f.get_parent().queue_free()
	ok.get_parent().queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- the chest: a light charge stops in the lung, a full one reaches the heart
## The line into the chest from the front-left (the angle off his front) that a light ball takes into the left lung and stops in,
## and the full charge on into the heart, on his pose now (his musket's arms may be in the way of some): [direction, heart].
func _chest_line(f: NpcFighter, an: Anatomy) -> Array:
	var sk := f.body.sk
	var m := an.model
	var ax := _axes(sk, m)
	var heart := _at(m, sk, "Heart")
	var light := BodyModel.round_of({"kind": "ball", "speed": 105.0}, 120.0)
	var full := BodyModel.round_of({"kind": "ball", "speed": 320.0}, 120.0)
	for deg: float in [55.0, 45.0, 65.0, 35.0, 75.0, 90.0, 25.0, 100.0]:
		for lift: float in [0.0, 0.03, -0.03]:
			var a := deg_to_rad(deg)
			var d := -(ax.z * cos(a) + ax.x * sin(a)).normalized()
			var at := heart + ax.y * lift
			var r1 := m.trace(sk, at - d * 0.6, d, light)
			var r2 := m.trace(sk, at - d * 0.6, d, full)
			var n1 := (r1.crossed as Array).filter(func(r: Dictionary) -> bool: return String(r.kind) != "flesh").map(func(r: Dictionary) -> String: return String(r.name))
			var n2 := (r2.crossed as Array).map(func(r: Dictionary) -> String: return String(r.name))
			if n1.has("Left lung") and not n1.has("Heart") and Vector3(r1.stop) != Vector3.INF and n2.has("Heart") and n2.has("Left lung"):
				return [d, at, deg]
	return []


func _chest() -> void:
	var f := await _marine(LANE_X + 4.0, -66.0, 54)
	var an := Anatomy.attach_to(f.body.sk)
	_hold(f, true)
	var line := _chest_line(f, an)
	_expect(not line.is_empty(), "a line into his chest from the front-left (%s deg)" % (str(line[2]) if not line.is_empty() else "none"))
	if line.is_empty():
		f.get_parent().queue_free()
		return
	var d: Vector3 = line[0]
	await _fire(Vector3(line[1]) - d * 2.0, d, 105.0)
	_hold(f, false)
	print("   chest 105 m/s: %s" % _lines(an))
	_expect(_has(an, "Left lung, punctured") and not _has(an, "Heart") and Vector3(an.last_shot.rec.stop) != Vector3.INF and not f.is_dead(),
			"a light ball (105 m/s) from the front-left: the left lung, stopped short of the heart; alive (%s)" % _lines(an))
	_expect(f.limp <= 0.9 and f.pool > 0.0, "the lung: short of breath (no running: x%.2f) and bleeding (%.0f to lose)" % [f.limp, f.pool])
	# the cost a hit: the path, the labels, the outcome (on a second marine's body: its record grows by these)
	var g := await _marine(LANE_X - 4.0, -66.0, 55)
	var gan := Anatomy.attach_to(g.body.sk)
	var gax := _axes(g.body.sk, gan.model)
	var gheart := _at(gan.model, g.body.sk, "Heart")
	var t0 := Time.get_ticks_usec()
	var us := 0
	var n := 60
	for i in n:
		gan.add_wound(gheart + gax.z * 0.4 + gax.y * (float(i % 6) - 2.5) * 0.02, -gax.z, 120.0, -1.0, {"kind": "ball", "speed": 320.0})
		us += int(gan.last_shot.rec.us)
	costs["hit_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	costs["trace_ms"] = float(us) / 1000.0 / float(n)
	costs["n"] = n
	_expect(float(costs.hit_ms) < 3.0, "a hit costs %.3f ms (its path through the body %.3f ms)" % [float(costs.hit_ms), float(costs.trace_ms)])
	g.get_parent().queue_free()
	# the full charge on the same line (from his pose now)
	await _secs(1.0)
	_hold(f, true)
	line = _chest_line(f, an)
	if line.is_empty():
		line = [d, _at(an.model, f.body.sk, "Heart"), 0.0]
	d = line[0]
	await _fire(Vector3(line[1]) - d * 2.0, d, 320.0)
	_hold(f, false)
	print("   chest 320 m/s: %s" % _lines(an))
	var mortal := float((an.last_shot.fx as Dictionary).mortal_s)
	_expect(_has(an, "Left lung, punctured") and _has(an, "Heart, punctured") and mortal > 0.0 and (f.mortal_left > 0.0 or f.is_dead()),
			"the full charge on the same line: the lung and the heart, mortal (%.0f s; %s) (%s)" % [mortal, "dead already of both wounds" if f.is_dead() else "on his feet", _lines(an)])
	var t := await _until(func() -> bool: return f.is_dead(), Anatomy.MORTAL_HEART_S + 1.5)
	_expect(t <= Anatomy.MORTAL_HEART_S + 0.5, "and down within the heart's seconds (%.1f s)" % t)
	f.get_parent().queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- the neck: a carotid and the cord
func _neck() -> void:
	var f := await _marine(LANE_X, -70.0, 56)
	var sk := f.body.sk
	var an := Anatomy.attach_to(sk)
	var m := an.model
	_hold(f, true)
	var ax := _axes(sk, m)
	var cord := Vector3.INF
	for i in m.shapes.size():
		if String(m.shapes[i].kind) == "cord" and int(m.shapes[i].lvl) == 3:
			cord = m.shape_world(sk, i).origin
	var car := _at(m, sk, "Left carotid artery", 2)
	car += ax.y * (cord - car).dot(ax.y)
	var d := (cord - car).normalized()
	await _fire(car - d * 2.0, d)
	_hold(f, false)
	var fx: Dictionary = an.last_shot.fx
	print("   neck: ", _lines(an))
	_expect(_has(an, "Left carotid artery, cut") and _has(an, "Spinal cord, badly injured at C"),
			"into the neck through the left carotid: the artery cut, the cord at %s badly injured (%s)" % [Anatomy.level_tag(int(fx.cord_lvl)), _lines(an)])
	_expect(f.is_dead() and bool(fx.lethal) and int(fx.cord_lvl) <= 4, "the cord high in the neck: dead at once")
	f.get_parent().queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- two shots, the record, the view
func _record_and_inspect() -> void:
	var f := await _marine(LANE_X, -74.0, 57)
	var sk := f.body.sk
	var an := Anatomy.attach_to(sk)
	var m := an.model
	_hold(f, true)
	var ax := _axes(sk, m)
	await _fire(_at(m, sk, "Right femur") + ax.z * 2.0, -ax.z, 320.0)
	_hold(f, false)
	await _secs(1.5)
	_hold(f, true)
	ax = _axes(sk, m)
	await _fire(_at(m, sk, "Left femur") + ax.z * 2.0, -ax.z, 150.0)
	_hold(f, false)
	var s1: Dictionary = an.shots[0] if an.shots.size() > 0 else {}
	var s2: Dictionary = an.shots[1] if an.shots.size() > 1 else {}
	print("   shot 1: ", " · ".join(s1.get("lines", [])), "\n   shot 2: ", " · ".join(s2.get("lines", [])))
	_expect(an.shots.size() == 2 and bool(s2.latest) and not bool(s1.latest), "the record: two shots, the latest flagged")
	_expect(not s1.is_empty() and Vector3(s1.rec.entry) != Vector3.INF and Vector3(s1.rec.exit) != Vector3.INF and Vector3(s1.rec.stop) == Vector3.INF,
			"shot 1: the right femur, in and out (an entry and an exit)")
	_expect(not s2.is_empty() and Vector3(s2.rec.exit) == Vector3.INF and Vector3(s2.rec.stop) != Vector3.INF and String(s2.rec.stopped_in) == "Left femur",
			"shot 2, a weak ball (150 m/s): stopped in the left femur (an entry and a stop, no exit)")
	_expect(f.down and not f.is_dead() and f.surrendered() and not NpcSenses.can_fight(f),
			"both legs broken: down for good, alive, out of the fight")
	# the same line twice: the same record, the same outcome
	var from := _at(m, sk, "Heart") + ax.z * 0.6
	var rnd := BodyModel.round_of({"kind": "ball", "speed": 320.0}, 120.0)
	var r1 := m.trace(sk, from, -ax.z, rnd)
	var r2 := m.trace(sk, from, -ax.z, rnd)
	var sig := func(r: Dictionary) -> String:
		var parts := []
		for row: Dictionary in r.crossed:
			parts.append("%s|%s|%.4f|%.3f" % [row.name, row.res, float(row.t0), float(row.e_in)])
		return "%s %s %s %s" % [r.entry, r.exit, r.stop, ",".join(parts)]
	var h := an._hits_of(r1, "")
	_expect(sig.call(r1) == sig.call(r2) and str(Anatomy.effect(h, 120.0)) == str(Anatomy.effect(an._hits_of(r2, ""), 120.0)) and not (r1.crossed as Array).is_empty(),
			"the same line traced twice: the same path, the same outcome (%d structures)" % (r1.crossed as Array).size())
	# a ball in the head: dead
	await _secs(1.5)
	_hold(f, true)
	var brain := _at(m, sk, "Brain")
	await _fire(brain + Vector3.UP * 1.5, Vector3.DOWN)
	_hold(f, false)
	print("   head: ", _lines(an))
	_expect(f.is_dead() and _has(an, "Brain, punctured"), "a ball down into his head: the brain, dead")
	await _secs(2.5)
	# the view
	_expect(f.interact_prompt(player) == InspectView.ROW and (f.interact_actions(player)[0] as Dictionary).text == InspectView.ROW and InspectView.can_inspect(f),
			"dead, he offers \"%s\" as his tap" % InspectView.ROW)
	var b := SurvivalBridge.find(self)
	var minutes := b.core.state.minutes if b != null and b.core != null else -1.0
	var mouse_before := Input.mouse_mode
	f.interact(player)
	var v := InspectView.current
	_expect(v != null and paused and root.disable_3d, "the tap opens the view: the game paused under it, the world's own 3D off")
	if v == null:
		return
	print("   drawn: ", v.counts)
	var c := v.counts
	_expect(int(c.shapes) > 300 and int(c.dot_in) >= 3 and int(c.dot_out) >= 1 and int(c.dot_stop) >= 1 and int(c.green) >= 1 and int(c.white) >= 2 and int(c.tinted) >= 2,
			"it draws the body (%d shapes), the holes in (%d red), out (%d blue), the stop (%d purple), the latest path green (%d), the earlier white (%d), the broken bones tinted (%d)" % [
			int(c.shapes), int(c.dot_in), int(c.dot_out), int(c.dot_stop), int(c.green), int(c.white), int(c.tinted)])
	await _ticks(90)
	var minutes2 := b.core.state.minutes if b != null and b.core != null else -1.0
	_expect(b != null and is_equal_approx(minutes, minutes2) and paused, "the survival clock stands still while it is open (%.2f -> %.2f min)" % [minutes, minutes2])
	# the skin's outline: his own skin meshes with their blend shapes as he wears them (a man's build), on a bare skeleton that
	# holds his bones where they are drawn
	var ol := v.outline
	var n_mesh := 0
	var n_set := 0
	var same := true
	if ol != null:
		for mi: MeshInstance3D in ol.find_children("*", "MeshInstance3D", false, false):
			n_mesh += 1
			var src: MeshInstance3D = null
			for s: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
				if s.mesh == mi.mesh:
					src = s
			same = same and src != null and mi.skin == src.skin and mi.get_node_or_null(mi.skeleton) == ol     # (skinned on it)
			if src != null:
				for i in src.get_blend_shape_count():
					same = same and is_equal_approx(mi.get_blend_shape_value(i), src.get_blend_shape_value(i))
					n_set += 1 if absf(src.get_blend_shape_value(i)) > 0.01 else 0
	var wb := sk.find_bone("l_wrist")
	var off := -1.0
	if ol != null and wb >= 0:
		var drawn := sk.global_transform * BodyModel.pose(sk, wb, BodyModel.overrides(sk), {}).origin
		off = (ol.global_transform * ol.get_bone_global_pose(wb).origin).distance_to(drawn)
	_expect(ol != null and n_mesh == v.model.skin_names.size() and same and n_set >= 1 and off >= 0.0 and off < 0.01,
			"the skin's outline: his %d skin meshes, their %d blend shapes set as he wears them, his left wrist where it lies (%.3f m off; %.1f ms)" % [
			n_mesh, n_set, off, float(v.counts.get("outline_ms", -1.0))])
	# the controls
	_expect(v.side() == "FRONT", "it opens on his front (VIEWING %s)" % v.side())
	await _mouse_button(MOUSE_BUTTON_LEFT, true)
	await _motion(Vector2(-260, 0), MOUSE_BUTTON_MASK_LEFT)
	await _mouse_button(MOUSE_BUTTON_LEFT, false)
	_expect(v.side() != "FRONT" and absf(v.yaw) > 0.5, "LEFT DRAG turns round him (VIEWING %s, %.0f deg)" % [v.side(), rad_to_deg(v.yaw)])
	var d0 := v.dist
	await _mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	_expect(v.dist < d0, "the WHEEL brings it closer (%.2f -> %.2f m)" % [d0, v.dist])
	var p0 := v.pan
	await _mouse_button(MOUSE_BUTTON_RIGHT, true)
	await _motion(Vector2(120, -60), MOUSE_BUTTON_MASK_RIGHT)
	await _mouse_button(MOUSE_BUTTON_RIGHT, false)
	var p1 := v.pan
	await _key(KEY_W, true)
	for i in 20:
		await process_frame
	await _key(KEY_W, false)
	_expect(p1.distance_to(p0) > 0.01 and v.pan.distance_to(p1) > 0.01, "RIGHT DRAG and W move it (%.2f m, then %.2f m)" % [p1.distance_to(p0), v.pan.distance_to(p1)])
	await _key(KEY_R, true)
	await _key(KEY_R, false)
	_expect(v.side() == "FRONT" and v.pan == Vector3.ZERO, "R resets it")
	var was_mouse := v.was_mouse
	await _key(KEY_M, true)
	await _key(KEY_M, false)
	_expect(InspectView.current == null and not paused and not root.disable_3d and Input.mouse_mode == was_mouse,
			"M closes it: the game goes on, its 3D back, the mouse as the game had it (%d -> %d)" % [mouse_before, Input.mouse_mode])
	# the hotkey: M on the highlighted body
	await _ticks(2)
	var it := player.interactor
	it._set_target(f)
	var hk := InspectView._hotkey
	_expect(hk != null and is_instance_valid(hk), "the first body down made the M listener")
	if hk != null and is_instance_valid(hk):
		var e := InputEventKey.new()
		e.physical_keycode = KEY_M
		e.keycode = KEY_M
		e.pressed = true
		hk._unhandled_input(e)
	_expect(InspectView.current != null, "M on the highlighted dead body opens it")
	await _key(KEY_ESCAPE, true)
	await _key(KEY_ESCAPE, false)
	_expect(InspectView.current == null and not paused, "Esc closes it")
	it._set_target(null)
	f.get_parent().queue_free()
	await _ticks(3)


func _mouse_button(btn: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = down
	e.position = Vector2(500, 400)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame


func _motion(rel: Vector2, mask: MouseButtonMask) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.position = Vector2(500, 400) + rel
	e.button_mask = mask
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame


func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame


# ---------------------------------------------------------------- the debug toggle: a look inside the living
func _living() -> void:
	var f := await _marine(LANE_X, -78.0, 58)
	var plain := f.interact_actions(player).any(func(x: Dictionary) -> bool: return String(x.text) == InspectView.ROW)
	InspectView.debug_living = true
	var acts := f.interact_actions(player)
	var offered := acts.any(func(x: Dictionary) -> bool: return String(x.text) == InspectView.ROW)
	_expect(not plain and offered and InspectView.can_inspect(f), "the debug toggle offers \"%s\" on a living marine (off: %s, on: %s)" % [InspectView.ROW, plain, offered])
	for x: Dictionary in acts:
		if String(x.text) == InspectView.ROW:
			if String(x.id) == "":
				f.interact(player)
			else:
				f.interact_action(player, String(x.id))
	var v := InspectView.current
	_expect(v != null and not f.is_dead() and paused, "and the view opens on him alive")
	if v != null:
		v.close()
	InspectView.debug_living = false
	_expect(not InspectView.can_inspect(f) and not paused, "off again: not offered on the living, the game on")
	f.get_parent().queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- a deer
func _deer() -> void:
	var a := WildAnimal.new()
	a.species = "deer"
	current_scene.add_child(a)
	a.global_position = _ground(LANE_X + 8.0, -40.0)
	a.rotation.y = 0.3
	await _ticks(20)
	a.set_physics_process(false)          # (it stands for the shots, its clips held: the lines are worked out from where it is)
	a.set_process(false)
	var sk: Skeleton3D = a.get("_skel")
	var an := Anatomy.attach_to(sk)
	_expect(an != null and not an.model.human, "a deer has a fitted body (%d shapes)" % (an.model.shapes.size() if an else 0))
	if an == null:
		return
	costs["build_deer"] = an.model.build_ms
	var m := an.model
	var ax := _axes(sk, m)
	var lung := _at(m, sk, "Left lung")
	await _fire(lung + ax.x * 2.0, -ax.x, 40.0, Projectile.Kind.ARROW, 30.0)
	print("   deer, the arrow: %s (%s)" % [_lines(an), a.last_wound])
	_expect(a.last_wound == "lungs" and _has(an, "Left lung, punctured") and Vector3(an.last_shot.rec.stop) != Vector3.INF,
			"an arrow (40 m/s) into its near lung: it stops there, a lungs wound (%s)" % _lines(an))
	ax = _axes(sk, m)
	var heart := _at(m, sk, "Heart")
	await _fire(heart + ax.x * 2.0, -ax.x, 320.0)
	print("   deer, the ball: %s (%s)" % [_lines(an), a.last_wound])
	_expect(_has(an, "Heart, punctured") and a.last_wound == "heart", "a musket ball through its heart: a heart wound (%s)" % a.last_wound)
	a.set_physics_process(true)
	a.set_process(true)
	_expect(a.is_dead(), "and it is dead")
	var rag: Variant = a.get("_rag")
	var t := await _until(func() -> bool:
		var r: Variant = a.get("_rag")
		return r == null or (r as BoneRagdoll).frozen, 9.0)
	await _secs(1.2)
	var acts := a.interact_actions(player)
	var has_row := acts.any(func(x: Dictionary) -> bool: return String(x.text) == InspectView.ROW and String(x.id) == "inspect")
	_expect(rag != null and t < 9.0 and has_row and String((acts[0] as Dictionary).id) == "", "fallen as a ragdoll and at rest (%.1f s): its tap still the knife's, the hold list has \"%s\"" % [t, InspectView.ROW])
	a.interact_action(player, "inspect")
	var v := InspectView.current
	_expect(v != null, "the view opens on the ragdoll")
	if v != null:
		print("   drawn: ", v.counts, " viewing ", v.side())
		_expect(int(v.counts.dot_in) >= 2 and int(v.counts.dot_stop) >= 1 and int(v.counts.dot_out) >= 1 and int(v.counts.green) >= 1 and int(v.counts.white) >= 1,
				"its two shots drawn: the arrow's stop, the ball's way out")
		await _key(KEY_ESCAPE, true)
		await _key(KEY_ESCAPE, false)
		_expect(InspectView.current == null and not paused, "Esc closes it")
	a.queue_free()
	await _ticks(3)


func _end() -> void:
	if InspectView.current != null:
		InspectView.current.close()
	if fails.is_empty():
		print("INSPECT VIEW TEST PASSED (%d checks)" % checks)
	else:
		print("INSPECT VIEW TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("   failed: ", f)
	quit(0 if fails.is_empty() else 1)
