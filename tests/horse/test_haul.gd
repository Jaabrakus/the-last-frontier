extends SceneTree
## Headless tests of log skidding and leading a horse (scripts/horse/horse_haul.gd, skid_load.gd, log_pile.gd,
## horse_lead.gd; data/horse/haul.json):
##   data   the pull -> speed cap table, what one horse can start, bole weights, the pile's stacking
##   sim    on flat ground: a bole on the chain follows the horse (chain length kept, on the ground), caps its
##          speed by its weight (a heavier load goes slower), cuts the corner and swings on a turn and tracks
##          straight again after, rides over a stump, slides round a standing trunk without going into it,
##          is caught when pulled square into two trunks (the horse stops, then it is worked free), lies
##          loose and still when unhitched, is bucked shorter by the axe, is chained again by its other end;
##          a bundle of logs is laid down as a pile
##   lead   on flat ground with trunks about: the horse follows a leader walking and running (a trot), comes
##          up on him and stops when he stops (without running into him), goes round the trunks in its way,
##          and stands on "Stay"
##   level  in the Frontier level with the real E: lead the horse, fell a tree, hitch it at the butt (the
##          crown's firewood and branches in the pack), mount and ride with the log behind, unhitch from the
##          saddle with a tap (still mounted), get off with a hold; a bundle from the pack at the horse's
##          hitch, unhitched on foot into a pile, the pile taken back into the pack
##   carcass on flat ground: a shot deer (WildAnimal) is taken once its death clip has played out, roped by the
##          neck without moving it, dragged head first behind a trotting horse (on its rope, lying on the ground
##          as it fell, the animal on the rope's end), swings on a turn and comes back in line, is let go where
##          it stopped and can be skinned again, hitched again; a carcass cleaned up under the rope frees the
##          horse; one fully dressed is not taken; the weights
##   carcass_level  in the level with the real E (pass wildlife=on for the spawner's own deer and its clean-up
##          rule; without it a deer is made): the view picks Hitch at the neck and Skin at the body, E ropes it,
##          ride with it, a tap in the saddle lets it go, the spawner keeps it while on the rope and after the
##          haul; at the end of the haul it is skinned with the knife (FieldDressing, wildlife=on), not taken
##          while under the knife, and taken again skinned (to be butchered elsewhere)
##
##   Godot --headless --path . -s tests/horse/test_haul.gd -- [only=data,sim,lead,level,carcass,carcass_level] [wildlife=on]
##
## The horse, the harness and the logs are the project's own. The animals are Quaternius's CC0 stand-in models
## (assets/wildlife/quaternius/SOURCE.md).

var failures := PackedStringArray()
var checks := 0
var only := ""
var report := {}
var world: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	if _on("data"):
		_test_data()
	if _on("sim"):
		await _test_sim()
	if _on("lead"):
		await _test_lead()
	if _on("level"):
		await _test_level()
	if _on("carcass"):
		await _test_carcass()
	if _on("carcass_level"):
		await _test_carcass_level()
	print("REPORT ", JSON.stringify(report))
	if failures.is_empty():
		print("HAUL TEST PASSED (%d checks)" % checks)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("HAUL TEST FAILED (%d of %d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _on(part: String) -> bool:
	return only == "" or part in only.split(",")


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


# --- Data -------------------------------------------------------------------------------------------------

func _test_data() -> void:
	var d := HorseHaul.data()
	_check(not d.is_empty() and d.has("mu_axial") and d.has("horse_kg"), "haul.json reads")
	var last := INF
	var mono := true
	for i in 40:
		var c := HorseHaul.cap_for_pull(float(i) * 0.05)
		mono = mono and c <= last + 1e-6
		last = c
	_check(mono, "the speed cap falls as the pull grows")
	_check(HorseHaul.cap_for_pull(0.1) >= 3.0, "a light load leaves the trot (%.2f)" % HorseHaul.cap_for_pull(0.1))
	_check(absf(HorseHaul.cap_for_pull(float(d.pull_walk_frac)) - float(d.cap_walk_mps)) < 1e-3, "at pull_walk_frac the walk")
	_check(absf(HorseHaul.cap_for_pull(float(d.pull_max_frac)) - float(d.cap_crawl_mps)) < 1e-3, "at pull_max_frac a crawl")
	_check(HorseHaul.cap_for_pull(float(d.stall_frac) + 0.05) == 0.0, "past stall_frac the horse stops")
	# a median white pine near the spawn (radius 0.31 m, 5 logs = 12 m of bole) against a big oak
	var pine := SkidLoad.bole_mass({"radius": 0.31, "species": "white_pine"}, 12.0, d)
	var oak := SkidLoad.bole_mass({"radius": 0.35, "species": "oak"}, 9.6, d)
	report["pine_12m_kg"] = roundi(pine)
	report["oak_9.6m_kg"] = roundi(oak)
	_check(pine > 1000.0 and pine < 2000.0, "a 12 m pine bole weighs %.0f kg" % pine)
	_check(HorseHaul.can_start(pine), "one horse starts a whole 12 m pine bole")
	_check(not HorseHaul.can_start(oak), "but not a 9.6 m oak bole (%.0f kg): buck it shorter" % oak)
	_check(HorseHaul.can_start(SkidLoad.bole_mass({"radius": 0.35, "species": "oak"}, 2.4, d)), "a 2.4 m oak butt log it does")
	for n in range(1, 8):
		var offs := SkidLoad.pile_offsets(n, 0.15)
		var ok := offs.size() == n
		for a in offs.size():
			for b in range(a + 1, offs.size()):
				ok = ok and offs[a].distance_to(offs[b]) > 0.29
			ok = ok and offs[a].y >= 0.0
		_check(ok, "a pile of %d logs: %d logs, none in another (%s)" % [n, offs.size(), offs])


# --- A flat test world -----------------------------------------------------------------------------------

func _flat_world() -> Horse:
	if world:
		world.queue_free()
		await process_frame
	world = Node3D.new()
	world.name = "HaulWorld"
	root.add_child(world)
	var ground := StaticBody3D.new()
	ground.add_to_group(&"terrain")
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(600, 1, 600)
	gs.shape = gb
	gs.position = Vector3(0, -0.5, 0)
	ground.add_child(gs)
	world.add_child(ground)
	var h := Horse.new()
	h.name = "Horse"
	world.add_child(h)
	HorseMount.attach_to(h)
	await _frames(4)
	return h


func _trunk(at: Vector3, r := 0.3, group := &"trees") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.add_to_group(group)
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = 12.0
	cs.shape = c
	cs.position = Vector3(0, 6.0, 0)
	b.add_child(cs)
	b.position = at
	world.add_child(b)
	return b


## A felled tree lying down along `dir` from its butt at `butt` (radius r, logs x 2.4 m of bole).
func _felled(butt: Vector3, dir: Vector3, r: float, logs: int, species := "white_pine") -> FelledTree:
	var cfg := GatherData.get_default().felling
	var d := {"i": 7, "pos": butt, "height": float(logs) * 2.4 * 2.0, "radius": r, "species": species, "name": species.replace("_", " "),
			"crown_bottom": float(logs) * 2.4, "crown_radius": 3.0, "kind": 0, "variant": 0, "scale": 1.0, "yaw": 0.0}
	var ft := FelledTree.create(d, dir, cfg, false)
	ft.theta = PI * 0.5
	ft.hinge = butt + Vector3.UP * r
	ft.state = FelledTree.State.DOWN
	ft.logs_total = logs
	ft.logs_left = logs
	world.add_child(ft)
	return ft


## Distance from point p to segment ab.
static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Sim -------------------------------------------------------------------------------------------------

func _test_sim() -> void:
	var h := await _flat_world()
	var haul := h.get_node_or_null("Haul") as HorseHaul
	var lead := h.get_node_or_null("Lead") as HorseLead
	_check(haul != null and lead != null, "HorseMount.attach_to gives the horse a Haul and a Lead")
	if haul == null:
		return
	# the horse faces -Z; the log lies behind it along +Z, butt by the hitch
	var hp := h.get_hitch_point()
	var ft := _felled(Vector3(hp.x, 0.0, hp.z + 2.2), Vector3.BACK, 0.22, 3)
	await _frames(2)
	var kg := haul.mass_of(ft)
	var s := haul.hitch_tree(ft, 0, null)
	_check(s != null and haul.load == s and s.hitched, "a felled tree (%.0f kg) is chained by the butt" % kg)
	await _frames(2)
	_check(not is_instance_valid(ft) or ft.is_queued_for_deletion(), "the felled tree is replaced by the load")
	if s == null:
		return
	_check(absf(s.length - 7.2) < 0.01 and s.bundle == 0, "the bole is its 3 logs long (%.2f m)" % s.length)
	_check(not s.is_down(), "a load on the chain does not take the axe")
	h.set_cruise_gait(Horse.Gait.TROT)
	h.drive(1.0, 0.0)
	var max_over := 0.0
	var max_float := 0.0
	var min_sink := INF
	var speeds := []
	for i in 120 * 7:
		await physics_frame
		var over := s.front.distance_to(h.get_hitch_point()) - s.chain_len
		max_over = maxf(max_over, over)
		max_float = maxf(max_float, maxf(s.front.y - s.r_front, s.back.y - s.r_back))
		min_sink = minf(min_sink, minf(s.front.y - s.r_front, s.back.y - s.r_back))
		if i > 120 * 3:
			speeds.append(h.speed)
	var v_med: float = speeds[speeds.size() / 2]
	var cap_now := HorseHaul.cap_for_pull(s.pull_kgf / float(HorseHaul.data().horse_kg))
	report["light"] = {"kg": roundi(s.mass_kg), "pull_kgf": roundi(s.pull_kgf), "speed": snappedf(v_med, 0.01), "cap": snappedf(cap_now, 0.01),
			"chain_over": snappedf(max_over, 0.001), "float": snappedf(max_float, 0.001), "sink": snappedf(min_sink, 0.001)}
	_check(max_over < 0.05, "the chain holds its length (at most %.3f m over)" % max_over)
	_check(max_float < 0.06 and min_sink > -0.03, "the log lies on the ground (%.3f .. %.3f m)" % [min_sink, max_float])
	var mu := float(HorseHaul.data().mu_axial)
	_check(absf(s.pull_kgf - s.mass_kg * mu) < s.mass_kg * mu * 0.15, "the pull is its weight x mu along (%.0f vs %.0f kgf)" % [s.pull_kgf, s.mass_kg * mu])
	_check(v_med <= cap_now + 0.06, "the horse keeps to the load's cap (%.2f <= %.2f m/s)" % [v_med, cap_now])
	_check(h.global_position.z < -8.0, "the horse got going with it (z %.1f)" % h.global_position.z)
	var d_axis := s.axis()
	_check(d_axis.dot(Vector3.BACK) > 0.99, "it trails straight behind (%.3f)" % d_axis.dot(Vector3.BACK))
	# a turn: the tail cuts the corner, swinging out of line with the horse, and comes back in line after
	h.drive(1.0, 0.6)
	var max_ang := 0.0
	for i in 120 * 3:
		await physics_frame
		var hf := _flat(h.global_basis.z).normalized()          # the horse's back direction
		max_ang = maxf(max_ang, rad_to_deg(hf.angle_to(_flat(s.axis()).normalized())))
	h.drive(1.0, 0.0)
	for i in 120 * 12:
		await physics_frame
		if OS.get_environment("HAUL_DEBUG") != "" and i % 60 == 0:
			print("dbg t=%.1f v=%.2f cap=%.2f jam=%.2f str=%.3f pull=%.0f ang=%.1f hp=%s f=%s b=%s obs=%d" % [i / 120.0, h.speed, haul.cap, haul.jam_t, s.stretch, s.pull_kgf,
					rad_to_deg(_flat(h.global_basis.z).normalized().angle_to(_flat(s.axis()).normalized())), h.get_hitch_point(), s.front, s.back, s.obstacle_hits])
	var after := rad_to_deg(_flat(h.global_basis.z).normalized().angle_to(_flat(s.axis()).normalized()))
	report["turn"] = {"max_angle_deg": snappedf(max_ang, 0.1), "after_deg": snappedf(after, 0.1)}
	_check(max_ang > 20.0, "on a turn the log swings out of the horse's line (%.0f deg)" % max_ang)
	_check(after < max_ang * 0.4, "and tracks back in line after (%.1f deg)" % after)
	# a heavier bole goes slower
	haul.unhitch()
	h.drive(0.0, 0.0)
	await _frames(120)
	var loose := s
	_check(not loose.hitched and loose.is_down(), "unhitched: the bole lies loose and takes the axe")
	await _frames(240)
	var rest0 := loose.front
	await _frames(30)
	_check(loose.front.distance_to(rest0) < 0.002, "and lies still (%.4f m)" % loose.front.distance_to(rest0))
	var L0 := loose.length
	var m0 := loose.mass_kg
	var cuts := 0
	while loose.logs_left == 3 and cuts < 50:
		loose.buck(1.0)
		cuts += 1
	_check(absf(loose.length - (L0 - 2.4)) < 0.01 and loose.mass_kg < m0, "bucking a log off shortens it (%.1f -> %.1f m)" % [L0, loose.length])
	var far := loose.back
	var near := loose.front
	# chained by the other end: turn the horse round so its hitch is by the far end
	h.global_position = far + (far - near).normalized() * 3.6
	h.global_position.y = 0.0
	h.look_at(h.global_position + (far - near).normalized(), Vector3.UP)
	await _frames(3)
	var s2 := haul.hitch_tree(loose, 1, null)
	_check(s2 == loose and loose.front.distance_to(far) < 0.01, "a loose bole is chained again by its other end")
	haul.unhitch()
	await _frames(2)
	# heavy vs light: same horse, a heavy hemlock
	h.global_position = Vector3(40, 0, 0)
	h.rotation = Vector3.ZERO
	await _frames(3)
	hp = h.get_hitch_point()
	var heavy_ft := _felled(Vector3(hp.x, 0.0, hp.z + 2.2), Vector3.BACK, 0.3, 4, "hemlock")
	await _frames(2)
	var heavy := haul.hitch_tree(heavy_ft, 0, null)
	_check(heavy != null, "a 9.6 m hemlock bole (%.0f kg) can be chained" % (heavy.mass_kg if heavy else 0.0))
	if heavy:
		h.drive(1.0, 0.0)
		var hs := []
		for i in 120 * 6:
			await physics_frame
			if i > 120 * 3:
				hs.append(h.speed)
		var hv: float = hs[hs.size() / 2]
		report["heavy"] = {"kg": roundi(heavy.mass_kg), "pull_kgf": roundi(heavy.pull_kgf), "speed": snappedf(hv, 0.01)}
		_check(hv < v_med - 0.3 and hv > 0.3, "the heavier load goes slower (%.2f vs %.2f m/s)" % [hv, v_med])
		_check(h.gait == Horse.Gait.WALK, "at a walk (gait %d)" % h.gait)
		haul.unhitch()
	# a stump in the path: the log rides up over it and down again
	h.drive(0.0, 0.0)
	await _frames(60)
	h.global_position = Vector3(-40, 0, 0)
	h.rotation = Vector3.ZERO
	h.speed = 0.0
	await _frames(3)
	hp = h.get_hitch_point()
	var bump_ft := _felled(Vector3(hp.x, 0.0, hp.z + 2.2), Vector3.BACK, 0.2, 2)
	await _frames(2)
	var bl := haul.hitch_tree(bump_ft, 0, null)
	var stump := StaticBody3D.new()
	stump.add_to_group(FrontierVegetation.LOW_GROUP)
	var scs := CollisionShape3D.new()
	var sc := CylinderShape3D.new()
	sc.radius = 0.28
	sc.height = 0.6
	scs.shape = sc
	stump.add_child(scs)
	stump.position = Vector3(-40, 0.0, -5.0)       # top 0.3 m over the ground, on the log's path
	world.add_child(stump)
	h.drive(1.0, 0.0)
	var top := 0.0
	var stuck := true
	for i in 120 * 9:
		await physics_frame
		if bl:
			top = maxf(top, maxf(bl.front.y - bl.r_front, bl.back.y - bl.r_back))
			if bl.back.z < -6.0:
				stuck = false
	report["stump_lift"] = snappedf(top, 0.01)
	_check(top > 0.1 and top < 0.5, "over a 0.3 m stump the log lifts (%.2f m)" % top)
	_check(not stuck, "and comes on over it")
	if bl:
		_check(bl.back.y - bl.r_back < 0.06, "and lies on the ground again past it (%.3f)" % (bl.back.y - bl.r_back))
		haul.unhitch()
	# a standing trunk the tail swings into on a turn: it slides round, never into it
	h.drive(0.0, 0.0)
	await _frames(60)
	h.global_position = Vector3(0, 0, 60)
	h.rotation = Vector3.ZERO
	h.speed = 0.0
	await _frames(3)
	hp = h.get_hitch_point()
	var tt_ft := _felled(Vector3(hp.x, 0.0, hp.z + 2.2), Vector3.BACK, 0.2, 3)
	await _frames(2)
	var tl := haul.hitch_tree(tt_ft, 0, null)
	var tree := _trunk(Vector3(-2.2, 0.0, 60 - 2.0), 0.35)   # left of the path, where the tail swings on a left turn
	h.drive(1.0, 0.0)
	await _frames(120)
	h.drive(1.0, 1.0)
	var min_gap := INF
	var hits := 0
	for i in 120 * 6:
		await physics_frame
		if tl:
			min_gap = minf(min_gap, _seg_dist(Vector3(tree.position.x, tl.front.y, tree.position.z), tl.front, tl.back) - 0.35 - (tl.r_front + tl.r_back) * 0.5)
			hits += tl.obstacle_hits
	report["trunk"] = {"min_gap": snappedf(min_gap, 0.001), "contact_ticks": hits}
	_check(min_gap > -0.05, "round a standing trunk the log never goes into it (gap %.3f m)" % min_gap)
	_check(hits > 0, "it did touch the trunk (%d contact ticks)" % hits)
	if tl:
		haul.unhitch()
	tree.queue_free()
	# caught: a log across the pull with a trunk in front of each end
	h.drive(0.0, 0.0)
	await _frames(60)
	h.global_position = Vector3(0, 0, -60)
	h.rotation = Vector3.ZERO
	h.speed = 0.0
	await _frames(3)
	hp = h.get_hitch_point()
	# a rock face square between the hitch and the log's end: pulled straight into it, end on
	var jam_ft := _felled(Vector3(hp.x, 0.0, hp.z + 2.2), Vector3.BACK, 0.2, 2)
	var t1 := StaticBody3D.new()
	t1.add_to_group(&"rocks")
	var rcs := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(1.6, 1.2, 0.5)
	rcs.shape = rb
	rcs.position = Vector3(0, 0.6, 0)
	t1.add_child(rcs)
	t1.position = Vector3(hp.x, 0.0, hp.z + 1.4)
	world.add_child(t1)
	await _frames(2)
	var jl := haul.hitch_tree(jam_ft, 0, null)
	h.drive(1.0, 0.0)
	var jammed := false
	var stopped := false
	var freed := false
	for i in 120 * 12:
		await physics_frame
		if OS.get_environment("HAUL_DEBUG") != "" and i % 30 == 0 and jl:
			print("jam t=%.2f hpos=%s v=%.2f cap=%.2f jam=%.2f str=%.3f free=%.2f f=%s b=%s obs=%d" % [i / 120.0, h.global_position, h.speed, haul.cap, haul.jam_t, jl.stretch, jl._free_t, jl.front, jl.back, jl.obstacle_hits])
		if haul.jam_t > 0.0:
			jammed = true
		if jammed and h.speed < 0.05:
			stopped = true
		if stopped and jl and jl._free_t > 0.0:
			freed = true
	report["jam"] = {"jammed": jammed, "stopped": stopped, "freed": freed}
	_check(jammed and stopped, "pulled square into a rock face the log is caught and the horse stops")
	_check(freed, "after a while it is worked free")
	_check(jl != null and jl.back.z < t1.position.z, "and comes on past the rock (its far end at z %.1f, the rock at %.1f)" % [jl.back.z if jl else 0.0, t1.position.z])
	if jl:
		haul.unhitch()
	t1.queue_free()
	# a bundle: chained behind, dragged, laid down as a pile
	h.drive(0.0, 0.0)
	await _frames(60)
	h.global_position = Vector3(60, 0, 0)
	h.rotation = Vector3.ZERO
	h.speed = 0.0
	await _frames(3)
	var b := SkidLoad.make_bundle(5, h.get_hitch_point() + Vector3(0, -0.4, 2.0), Vector3.BACK, HorseHaul.data(), false)
	world.add_child(b)
	haul._attach(b)
	_check(b.bundle == 5 and b.mass_kg > 300.0 and not b.is_down(), "a bundle of 5 logs (%.0f kg) on the chain, not for the axe" % b.mass_kg)
	h.drive(1.0, 0.0)
	await _frames(120 * 4)
	_check(h.global_position.z < -3.0 and b.front.distance_to(h.get_hitch_point()) < b.chain_len + 0.06, "the horse drags the bundle")
	h.drive(0.0, 0.0)
	await _frames(120 * 2)
	var pile := haul.unhitch()
	await _frames(2)
	_check(pile is LogPile and (pile as LogPile).count == 5 and pile.is_in_group(PlacedWeapon.GROUP), "unhitched, the bundle is a pile of 5 logs to take")
	_check(h.haul_speed_cap == INF, "nothing on the chain: no cap")


# --- Lead ------------------------------------------------------------------------------------------------

func _test_lead() -> void:
	var h := await _flat_world()
	var lead := h.get_node("Lead") as HorseLead
	var leader := CharacterBody3D.new()
	leader.name = "Leader"
	world.add_child(leader)
	leader.global_position = h.global_position + Vector3(0, 0, -3.2)    # in front of its head
	await _frames(2)
	lead.start(leader)
	_check(lead.leading and lead.interact_prompt(leader) == "Stay", "leading: the prompt is Stay")
	# walk off along -Z at 1.5 m/s for 8 s
	var v := Vector3(0, 0, -1.5)
	var max_gap := 0.0
	var min_gap := INF
	var trotted := false
	for i in 120 * 8:
		leader.velocity = v
		leader.global_position += v / 120.0
		await physics_frame
		if i > 240:
			var gap := _flat(lead.bit_point() - leader.global_position).length()
			max_gap = maxf(max_gap, gap)
	_check(max_gap < 4.5, "at a walk it keeps up (head at most %.1f m from him)" % max_gap)
	# run at 3.6 m/s for 6 s along -X (a turn too)
	v = Vector3(-3.6, 0, 0)
	max_gap = 0.0
	for i in 120 * 6:
		leader.velocity = v
		leader.global_position += v / 120.0
		await physics_frame
		if h.gait == Horse.Gait.TROT:
			trotted = true
		if i > 240:
			max_gap = maxf(max_gap, _flat(lead.bit_point() - leader.global_position).length())
	report["lead_run_gap"] = snappedf(max_gap, 0.1)
	_check(trotted, "he runs: it trots")
	_check(max_gap < 7.0, "and keeps within %.1f m" % max_gap)
	# he stops: it comes up and stops, not into him
	v = Vector3.ZERO
	leader.velocity = v
	var t_stop := -1.0
	min_gap = INF
	for i in 120 * 6:
		await physics_frame
		min_gap = minf(min_gap, _flat(h.global_position - leader.global_position).length())
		if t_stop < 0.0 and h.speed < 0.05 and i > 30:
			t_stop = i / 120.0
	var end_gap := _flat(lead.bit_point() - leader.global_position).length()
	report["lead_stop"] = {"t": snappedf(t_stop, 0.01), "head_gap": snappedf(end_gap, 0.01), "closest_body": snappedf(min_gap, 0.01)}
	_check(t_stop > 0.0 and t_stop < 5.0, "he stops: it stops (%.1f s)" % t_stop)
	_check(end_gap < 3.2 and min_gap > 0.9, "up with him (head %.1f m) and not into him (body %.1f m)" % [end_gap, min_gap])
	# trunks in the way: he walks on past a row of them; it goes round and comes up
	var base := leader.global_position
	var dir := Vector3(-1, 0, 0)
	var trunks: Array[Vector3] = []
	for k in 3:
		var at := base + dir * (4.0 + 3.5 * k) + Vector3(0, 0, (k % 2) * 0.8 - 0.4)
		_trunk(at, 0.35)
		trunks.append(at)
	var min_trunk := INF
	var inside := 0
	for i in 120 * 12:
		var target := base + dir * 16.0
		var to := target - leader.global_position
		to.y = 0
		var lv := to.normalized() * 1.5 if to.length() > 0.1 else Vector3.ZERO
		# he walks straight through the row (the test leader has no collider)
		leader.velocity = lv
		leader.global_position += lv / 120.0
		await physics_frame
		for t in trunks:
			var dd := _flat(h.global_position - t).length()
			min_trunk = minf(min_trunk, dd)
			if dd < 0.35 + 0.25:
				inside += 1
	var final_gap := _flat(lead.bit_point() - leader.global_position).length()
	report["lead_trees"] = {"closest_trunk": snappedf(min_trunk, 0.01), "final_head_gap": snappedf(final_gap, 0.1)}
	_check(inside == 0, "round the trunks, not through them (closest %.2f m)" % min_trunk)
	_check(final_gap < 4.0, "and up with him past them (head %.1f m)" % final_gap)
	# Stay: it stands while he walks off
	lead.interact(leader)
	_check(not lead.leading and lead.interact_prompt(leader) == "Lead horse", "E again: Stay (the prompt is Lead horse)")
	var p0 := h.global_position
	for i in 120 * 4:
		leader.velocity = Vector3(0, 0, 2.0)
		leader.global_position += Vector3(0, 0, 2.0) / 120.0
		await physics_frame
	_check(_flat(h.global_position - p0).length() < 1.0 and h.speed < 0.05, "it stays (moved %.2f m)" % _flat(h.global_position - p0).length())


# --- Level -----------------------------------------------------------------------------------------------

var player: FrontierPlayer
var it: PlayerInteractor


func _tap_e(frames := 4) -> void:
	Input.action_press(&"interact")
	await _frames(frames)
	Input.action_release(&"interact")
	await _frames(3)


func _face(at: Vector3) -> void:
	var d := at - player.global_position
	d.y = 0.0
	d = d.normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-12.0)


func _put_player(at: Vector3, look_at: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	_face(look_at)


func _test_level() -> void:
	if world:
		world.queue_free()
		world = null
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	_check(player != null, "level loads with a player")
	if player == null:
		return
	player.ignore_mouse_capture = true
	await _frames(40)
	it = player.interactor
	var hs := current_scene.find_children("*", "Horse", true, false)
	_check(not hs.is_empty(), "the level has its horse")
	if hs.is_empty():
		return
	var h := hs[0] as Horse
	var lead := h.get_node_or_null("Lead") as HorseLead
	var haul := h.get_node_or_null("Haul") as HorseHaul
	_check(lead != null and haul != null, "the level's horse has its lead and hitch")
	if lead == null or haul == null:
		return
	# E at its head: Lead horse
	var fwd := -h.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	_put_player(lead.bit_point() + fwd * 1.1, lead.bit_point())
	await _frames(6)
	_check(it.target == lead and it._label.text.ends_with("Lead horse"), "at its head the prompt is Lead horse (%s)" % it._label.text)
	await _tap_e()
	_check(lead.leading and lead.leader == player, "a tap of E takes the lead")
	_face(player.global_position * 2.0 - h.global_position)
	var h0 := h.global_position
	# walk away from it (the camera faces away from the horse: W walks off)
	Input.action_press(&"move_forward")
	await _frames(120 * 3)
	Input.action_release(&"move_forward")
	await _frames(120 * 4)
	report["level_lead_moved"] = snappedf(_flat(h.global_position - h0).length(), 0.1)
	_check(_flat(h.global_position - h0).length() > 2.0, "it follows the player (moved %.1f m)" % _flat(h.global_position - h0).length())
	_check(h.speed < 0.1, "and stops when the player stops")
	# fell a tree near: a small one with a trunk collider, off the fort
	var gt := player.gather
	var vh := VegHarvest.find(self)
	var best := -1
	var best_d := INF
	for i in vh.lay.tree_pos.size():
		if int(vh.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or vh.lay.tree_collider[i] == 0:
			continue
		var p: Vector3 = vh.lay.tree_pos[i]
		if absf(p.x) < 24.0 and absf(p.z) < 24.0:
			continue
		var d := vh.describe("tree", "tree", i)
		if d.is_empty() or float(d.radius) > 0.3:
			continue
		var dist := _flat(p - player.global_position).length()
		if dist < best_d:
			best_d = dist
			best = i
	_check(best >= 0, "a tree to fell")
	if best < 0:
		return
	var desc := vh.describe("tree", "tree", best)
	var felled := [null]
	gt.felled.connect(func(ft: FelledTree) -> void: felled[0] = ft)
	_put_player(desc.pos + Vector3(1.2, 0, 0.4), desc.pos)
	await _frames(3)
	gt._fell(desc)
	var ft: FelledTree = felled[0]
	_check(ft != null, "the tree comes down")
	if ft == null:
		return
	for i in 120 * 10:
		await physics_frame
		if ft.is_down():
			break
	_check(ft.is_down(), "and lies down")
	# too heavy? buck logs off first (the axe's own call)
	while not HorseHaul.can_start(haul.mass_of(ft)) and ft.logs_left > 1:
		ft.buck(ft.cut_work)
	report["level_tree"] = {"species": ft.species_name(), "logs": ft.logs_left, "kg": roundi(haul.mass_of(ft))}
	# the horse's hindquarters by the butt, facing away from the tree
	var away := -_flat(ft.axis()).normalized()
	lead.stop()
	var hpos := ft.hinge + away * (Horse.HITCH_BACK + 2.2)
	hpos.y = FrontierTerrain.height_at(hpos.x, hpos.z)
	h.global_position = hpos
	h.look_at(hpos + away, Vector3.UP)
	h.speed = 0.0
	await _frames(20)
	var butt := ft.hinge
	_put_player(butt - _flat(ft.axis()).normalized() * 0.2 + _flat(ft.axis()).cross(Vector3.UP).normalized() * 1.3, butt)
	await _frames(8)
	_check(it.target == haul and it._label.text.contains("Hitch the"), "at the butt with the horse by it: %s" % it._label.text)
	var inv0 := InventoryState.from_player(player)
	var fw0 := inv0.pack_count("firewood")
	var br0 := inv0.pack_count("branches")
	await _tap_e()
	var s := haul.load
	_check(s != null and s.hitched and s.bundle == 0, "a tap of E chains the bole")
	await _frames(2)
	_check(not is_instance_valid(ft), "the felled tree is limbed into the bole")
	var inv1 := InventoryState.from_player(player)
	_check(inv1.pack_count("firewood") > fw0 and inv1.pack_count("branches") > br0, "its crown's firewood and branches are in the pack")
	if s == null:
		return
	# mount with E and ride on with it
	var mp := h.get_mount_point(Horse.LEFT).origin
	_put_player(mp + (mp - h.global_position).normalized() * 0.4, h.get_saddle_transform().origin)
	await _frames(6)
	await _tap_e()
	await _frames(120)
	_check(player.riding == h, "E at the saddle mounts")
	player.yaw = h.rotation.y
	var p0 := h.global_position
	Input.action_press(&"move_forward")
	var over := 0.0
	var vmax := 0.0
	var usec := 0
	for i in 120 * 6:
		await physics_frame
		over = maxf(over, s.front.distance_to(h.get_hitch_point()) - s.chain_len)
		usec += s.sim_usec
		if i > 240:
			vmax = maxf(vmax, h.speed - haul.cap)
	report["level_sim_usec_avg"] = usec / (120 * 6)
	_check(usec / (120 * 6) < 1000, "a load costs %d us a tick in the forest" % (usec / (120 * 6)))
	Input.action_release(&"move_forward")
	report["level_ride"] = {"moved": snappedf(_flat(h.global_position - p0).length(), 0.1), "chain_over": snappedf(over, 0.01),
			"speed_over_cap": snappedf(vmax, 0.01), "cap": snappedf(haul.cap, 0.01), "pull_kgf": roundi(s.pull_kgf)}
	_check(_flat(h.global_position - p0).length() > 1.5, "riding, the horse drags the log (%.1f m)" % _flat(h.global_position - p0).length())
	_check(over < 0.3, "on its chain (at most %.2f m over)" % over)
	_check(vmax < 0.1, "at the load's pace")
	await _frames(120 * 3)
	_check(it.target == haul and it._label.text.contains("Unhitch"), "stopped in the saddle: %s" % it._label.text)
	await _tap_e()
	_check(haul.load == null and not s.hitched and player.riding == h, "a tap unhitches it and the rider stays up")
	Input.action_press(&"interact")
	await _frames(80)
	Input.action_release(&"interact")
	await _frames(20)
	_check(player.riding == null, "holding E gets off")
	# a bundle from the pack at the hitch
	var g := player.gather
	g.give("log", 4)
	await _frames(2)
	var logs0 := InventoryState.from_player(player).pack_count("log")
	var hp := h.get_hitch_point()
	_put_player(hp + h.global_basis.z * 1.4, hp)
	await _frames(8)
	if OS.get_environment("HAUL_DEBUG") != "":
		print("pack offer ", haul._offer, " target ", it.target, " riding ", player.riding, " logs ", logs0, " hp ", hp, " p ", player.global_position)
	_check(it.target != null and it.target.get_parent() == haul and it._label.text.contains("from the pack"), "at the hitch with logs in the pack: %s" % it._label.text)
	await _tap_e()
	var b := haul.load
	_check(b != null and b.bundle == mini(logs0, 6), "a tap chains a bundle of %d" % (b.bundle if b else 0))
	_check(InventoryState.from_player(player).pack_count("log") == logs0 - (b.bundle if b else 0), "taken from the pack")
	await _frames(120)
	if b:
		_put_player(b.chain_point() + h.global_basis.x * 1.2, b.chain_point())
		await _frames(8)
		_check(it.target == haul and it._label.text.contains("Unhitch"), "at the bundle on foot: %s" % it._label.text)
		await _tap_e()
		await _frames(3)
		var piles := current_scene.find_children("LogPile*", "LogPile", true, false)
		_check(piles.size() == 1, "unhitched on foot it is laid down as a pile")
		if piles.size() == 1:
			var pile := piles[0] as LogPile
			_put_player(pile.interact_point() + h.global_basis.x * 1.4, pile.interact_point())
			await _frames(8)
			_check(it.target == pile and it._label.text.contains("Take"), "at the pile: %s" % it._label.text)
			await _tap_e()
			await _frames(3)
			_check(InventoryState.from_player(player).pack_count("log") == logs0, "E takes the logs back into the pack")


# --- Carcasses -------------------------------------------------------------------------------------------

## A dead animal lying at `at` with its head toward `head_dir` (no spawner: its death clip is its clock).
func _dead(species: String, parent: Node, at: Vector3, head_dir: Vector3) -> WildAnimal:
	var a := WildAnimal.new()
	a.setup(species, null, null, 11)
	a.name = "Dead_%s" % species
	parent.add_child(a)
	a.global_position = at
	a.rotation.y = atan2(-head_dir.x, -head_dir.z)
	a._yaw = a.rotation.y
	await _frames(2)
	a.apply_hit(9999.0, a.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	return a


func _test_carcass() -> void:
	var h := await _flat_world()
	var haul := h.get_node("Haul") as HorseHaul
	var d := HorseHaul.data()
	var hp := h.get_hitch_point()
	var deer := await _dead("deer", world, Vector3(hp.x, 0.0, hp.z + 2.6), Vector3.FORWARD)
	_check(deer.is_dead() and CarcassLoad.is_carcass(deer), "a shot deer is a carcass")
	_check(not CarcassLoad.haulable(deer), "it is not taken while its death clip plays")
	await _frames(int(1.6 * 120))
	_check(CarcassLoad.haulable(deer), "it is taken once it lies still")
	var root0 := deer.global_position
	var s := haul.hitch_carcass(deer)
	_check(s != null and haul.load == s and s.hitched, "the horse takes it on a rope")
	if s == null:
		return
	_check(s.load_name() == "deer" and absf(s.mass_kg - float(d.carcass.kg.deer)) < 0.01, "a deer of %.0f kg" % s.mass_kg)
	_check(deer.get_meta(&"on_chain", false) and not deer.is_in_group(PlacedWeapon.GROUP), "on the rope it is no interactable (no Skin on a load)")
	_check(haul.hitch_carcass(deer) == null, "one load at a time")
	_check(not s.is_down() and not s.is_in_group(FelledTree.GROUP), "not wood: the axe has nothing to buck")
	await _frames(2)
	_check(deer.global_position.distance_to(root0) < 0.03, "roping it does not move it (%.3f m)" % deer.global_position.distance_to(root0))
	_check(CarcassLoad.neck_point(deer).distance_to(s.front) < 0.03, "the rope's end is at its neck")
	h.set_cruise_gait(Horse.Gait.TROT)
	h.drive(1.0, 0.0)
	var max_over := 0.0
	var max_float := 0.0
	var min_sink := INF
	var max_off := 0.0
	var min_up := 1.0
	var speeds := []
	for i in 120 * 7:
		await physics_frame
		max_over = maxf(max_over, s.front.distance_to(h.get_hitch_point()) - s.chain_len)
		max_float = maxf(max_float, maxf(s.front.y - s.r_front, s.back.y - s.r_back))
		min_sink = minf(min_sink, minf(s.front.y - s.r_front, s.back.y - s.r_back))
		max_off = maxf(max_off, CarcassLoad.neck_point(deer).distance_to(s.front))
		min_up = minf(min_up, deer.global_basis.y.dot(Vector3.UP))
		if i > 120 * 3:
			speeds.append(h.speed)
	var v_med: float = speeds[speeds.size() / 2]
	var mu := float(d.carcass.mu_axial)
	report["carcass"] = {"kg": roundi(s.mass_kg), "pull_kgf": snappedf(s.pull_kgf, 0.1), "speed": snappedf(v_med, 0.01), "cap": snappedf(haul.cap, 0.01),
			"rope_over": snappedf(max_over, 0.001), "float": snappedf(max_float, 0.001), "sink": snappedf(min_sink, 0.001),
			"neck_off": snappedf(max_off, 0.001), "min_up": snappedf(min_up, 0.001), "length": snappedf(s.length, 0.01)}
	_check(max_over < 0.05, "the rope holds its length (at most %.3f m over)" % max_over)
	_check(max_float < 0.06 and min_sink > -0.03, "it drags on the ground (%.3f .. %.3f m)" % [min_sink, max_float])
	_check(max_off < 0.03, "the animal rides on the rope's end (neck at most %.3f m off it)" % max_off)
	_check(min_up > 0.97, "on the level it lies as it fell (up %.3f)" % min_up)
	_check(absf(s.pull_kgf - s.mass_kg * mu) < s.mass_kg * mu * 0.15, "the pull is its weight x mu (%.1f vs %.1f kgf)" % [s.pull_kgf, s.mass_kg * mu])
	_check(haul.cap >= float(d.cap_trot_mps) - 0.01 and v_med > 2.5, "a deer is light: the horse trots on with it (%.2f m/s)" % v_med)
	_check(s.axis().dot(Vector3.BACK) > 0.99, "head first, straight behind (%.3f)" % s.axis().dot(Vector3.BACK))
	_check(h.global_position.z < -8.0, "the horse got going with it (z %.1f)" % h.global_position.z)
	h.drive(1.0, 0.6)
	var max_ang := 0.0
	for i in 120 * 3:
		await physics_frame
		max_ang = maxf(max_ang, rad_to_deg(_flat(h.global_basis.z).normalized().angle_to(_flat(s.axis()).normalized())))
	h.drive(1.0, 0.0)
	await _frames(120 * 8)
	var after := rad_to_deg(_flat(h.global_basis.z).normalized().angle_to(_flat(s.axis()).normalized()))
	report["carcass_turn"] = {"max_angle_deg": snappedf(max_ang, 0.1), "after_deg": snappedf(after, 0.1)}
	_check(max_ang > 15.0, "on a turn it swings out of the horse's line (%.0f deg)" % max_ang)
	_check(after < max_ang * 0.5, "and comes back in line (%.1f deg)" % after)
	h.drive(0.0, 0.0)
	await _frames(120 * 2)
	var left := haul.unhitch()
	_check(left == deer and haul.load == null and haul.cap == INF, "let go: the horse is free")
	await _frames(3)
	_check(not is_instance_valid(s), "the rope comes off")
	_check(deer.is_in_group(PlacedWeapon.GROUP) and not deer.has_meta(&"on_chain") and deer.has_meta(&"hauled_at"), "it is an interactable again")
	_check(deer.interact_prompt(null) == "Skin the deer", "to be skinned where it lies ('%s')" % deer.interact_prompt(null))
	var rest := deer.global_position
	await _frames(120)
	_check(deer.global_position.distance_to(rest) < 0.002, "it lies where it stopped")
	var s2 := haul.hitch_carcass(deer)
	_check(s2 != null and deer.global_position.distance_to(rest) < 0.03, "roped again where it lies")
	deer.queue_free()
	await _frames(4)
	_check(haul.load == null and haul.cap == INF and not is_instance_valid(s2), "a carcass cleaned up from under the rope frees the horse")
	var fox := await _dead("fox", world, h.get_hitch_point() + Vector3(0.0, -0.6, 2.0), Vector3.FORWARD)
	await _frames(int(1.6 * 120))
	_check(CarcassLoad.haulable(fox) and absf(CarcassLoad.mass_of_animal(fox, d) - float(d.carcass.kg.fox)) < 0.01, "a fox too (%.0f kg)" % CarcassLoad.mass_of_animal(fox, d))
	fox.remove_from_group(PlacedWeapon.GROUP)          # as the last step of field dressing does (WildAnimal.finish_dress)
	_check(not CarcassLoad.haulable(fox), "a carcass dressed to the bone is not taken")
	for sp in ["deer", "stag", "wolf", "fox"]:
		_check(HorseHaul.can_start(float(d.carcass.kg[sp])), "one horse drags a %s" % sp)


func _test_carcass_level() -> void:
	if world:
		world.queue_free()
		world = null
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	_check(player != null, "level loads with a player")
	if player == null:
		return
	player.ignore_mouse_capture = true
	await _frames(60)
	it = player.interactor
	var hs := current_scene.find_children("*", "Horse", true, false)
	if hs.is_empty():
		_check(false, "the level has its horse")
		return
	var h := hs[0] as Horse
	var haul := h.get_node("Haul") as HorseHaul
	var w := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	report["carcass_level_wildlife"] = w != null
	var deer: WildAnimal = null
	var back := _flat(h.global_basis.z).normalized()
	var at := h.get_hitch_point() + back * 2.6
	at.y = FrontierTerrain.height_at(at.x, at.z)
	if w:
		# the wolves far off; a deer of the spawner's own brought behind the horse and shot
		for a in w.animals():
			if a.species == "wolf":
				a.global_position = Vector3(285.0, FrontierTerrain.height_at(285.0, 285.0), 285.0)
				a.awareness = 0.0
			elif a.species == "deer" and deer == null and not a.is_dead():
				deer = a
		_check(deer != null, "a deer from the spawner")
		if deer == null:
			return
		deer.global_position = at
		deer.rotation.y = atan2(back.x, back.z)          # head toward the horse
		deer._yaw = deer.rotation.y
		deer.set_active(true)
		await _frames(2)
		deer.apply_hit(9999.0, deer.global_position + Vector3.UP * 0.6, Vector3.RIGHT, player, "vitals")
	else:
		deer = await _dead("deer", current_scene, at, -back)
	_check(deer.is_dead(), "the deer is down behind the horse")
	await _frames(int(1.7 * 120))
	var neck := CarcassLoad.neck_point(deer)
	var side := back.cross(Vector3.UP).normalized()
	# the view picks: at its body Skin (the animal's own E), at its neck Hitch (the horse's)
	_put_player(deer.interact_point() + side * 1.5, deer.interact_point())
	await _frames(8)
	_check(it.target == deer and it._label.text.ends_with("Skin the deer"), "looking at its body: %s" % it._label.text)
	_put_player(neck + side * 1.3 - back * 0.2, neck)
	await _frames(8)
	_check(it.target == haul and it._label.text.ends_with("Hitch the deer to the horse"), "looking at its neck: %s" % it._label.text)
	await _tap_e()
	var s := haul.load as CarcassLoad
	_check(s != null and s.animal == deer, "a tap of E ropes it")
	if s == null:
		return
	# mount with E and ride on with it
	var mp := h.get_mount_point(Horse.LEFT).origin
	_put_player(mp + (mp - h.global_position).normalized() * 0.4, h.get_saddle_transform().origin)
	await _frames(6)
	await _tap_e()
	await _frames(120)
	_check(player.riding == h, "E at the saddle mounts")
	player.yaw = h.rotation.y
	var p0 := deer.global_position
	if w:
		deer.set_meta("died_at", w.now - WildlifeSpawner.CARCASS_S - 10.0)       # long dead: kept while on the rope
	Input.action_press(&"move_forward")
	var over := 0.0
	for i in 120 * 5:
		await physics_frame
		if is_instance_valid(s) and s.hitched:
			over = maxf(over, s.front.distance_to(h.get_hitch_point()) - s.chain_len)
	Input.action_release(&"move_forward")
	_check(is_instance_valid(deer), "the spawner leaves a carcass on the rope alone")
	if not is_instance_valid(deer):
		return
	var moved := _flat(deer.global_position - p0).length()
	report["carcass_level_ride"] = {"moved": snappedf(moved, 0.1), "rope_over": snappedf(over, 0.01), "cap": snappedf(haul.cap, 0.01)}
	_check(moved > 3.0, "riding, the horse drags the deer (%.1f m)" % moved)
	_check(over < 0.3, "on its rope (at most %.2f m over)" % over)
	await _frames(120 * 3)
	_check(it.target == haul and it._label.text.contains("Unhitch the deer"), "stopped in the saddle: %s" % it._label.text)
	await _tap_e()
	_check(haul.load == null and player.riding == h, "a tap lets it go and the rider stays up")
	await _frames(120)
	_check(is_instance_valid(deer), "the spawner keeps it after the haul (its clock starts over)")
	Input.action_press(&"interact")
	await _frames(80)
	Input.action_release(&"interact")
	await _frames(40)
	_check(player.riding == null, "holding E gets off")
	if not is_instance_valid(deer):
		return
	var hide0 := InventoryState.from_player(player).pack_count("deer_hide")
	_put_player(deer.interact_point() + side * 1.5, deer.interact_point())
	await _frames(8)
	_check(it.target == deer and it._label.text.contains("Skin the deer"), "at the end of the haul: %s" % it._label.text)
	if w == null:
		return                          # the knife work is the spawner's (FieldDressing)
	await _tap_e()
	await _frames(30)
	_check(w.dressing.working and w.dressing.carcass == deer, "E: the knife work starts")
	_check(not CarcassLoad.haulable(deer), "a carcass under the knife is not taken")
	for i in 120 * 20:
		await physics_frame
		if deer.dress_step >= 1 and not w.dressing.working:
			break
	_check(deer.dress_step == 1 and InventoryState.from_player(player).pack_count("deer_hide") == hide0 + 1, "skinned there: +1 deer hide")
	await _frames(20)
	_check(CarcassLoad.haulable(deer), "a skinned carcass can be hauled on to be butchered")
