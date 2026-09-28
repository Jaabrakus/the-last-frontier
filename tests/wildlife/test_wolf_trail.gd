extends SceneTree
## Wolves on blood trails (user 2026-09-27: "wolves shouldnt steal if deer life is abundent if food sources are scares
## then it hunts and tracks", "also wolves will protect the kill try to hunt me"; WildPlanner), on the real level with its
## wildlife, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_wolf_trail.gd -- wildlife=on
##
##   plenty    the land full of deer: a hungry pack by the fresh blood of a deer he wounded takes up no trail, never picks
##             it to hunt, nor goes for it dead
##   track     short of deer: a pack that crosses the blood of a deer he wounded follows it, the leader along the drops,
##             till it is up with the deer (HUNT) or finds it dead (EAT)
##   dead      the deer bled out: the pack follows the trail to it and it is their kill (EAT)
##   wait      hungry, he at his kill: they wait off it, well away, and eat it once he goes
##   starving  he at his kill: they take it and come for him
##   fed       once they have eaten, he in plain sight off the kill: none comes for him
##   taken     starving, he butchered it and went off with the meat: they come after him; hungry, the kill gone on a
##             rope: they give it up
## Ends with "WOLF TRAIL TEST PASSED (<n> checks)" or "WOLF TRAIL TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var w: WildlifeSpawner
var p: FrontierPlayer
var g: WildGroup
var bites := 0
var _used: Array = []
## The land's hunger for the part running (held: the ecology's day ticks would move it).
var _h := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame
		_hold()


func _secs(s: float) -> void:
	await _fr(int(s * Engine.physics_ticks_per_second))


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
	w._restock_t = 1e9                  # (the bodies kept as they are: the parts set the land's numbers by hand)
	await _secs(1.0)
	var wolves := w.animals().filter(func(a: WildAnimal) -> bool: return a.species == "wolf" and not a.is_dead())
	g = (wolves[0] as WildAnimal).group if not wolves.is_empty() else null
	_expect(g != null and g.alive().size() >= 2, "a wolf pack (%d)" % (g.alive().size() if g else 0))
	if g == null:
		_end()
		return
	for a: WildAnimal in wolves:
		if a.group != g:
			_away(a)
	p.wounds.struck.connect(func(_r: String, _s: String, _k: String, _d: float) -> void: bites += 1)
	await _plenty()
	await _track(35.0, "track")
	await _track(30.0, "dead")
	await _wait()
	await _starving()
	await _taken()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("WOLF TRAIL TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("WOLF TRAIL TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


# --- The setting ---------------------------------------------------------------------------------

## Every frame: the land's hunger held, the player whole.
func _hold() -> void:
	if w == null:
		return
	w.ecology.pop.wolf = 5.0
	w.ecology.pop.bison = 0.0
	w.ecology.pop.deer = WildlifeEcology.PER_WOLF * 5.0 * (1.0 - _h)
	if p.health < p.max_health * 0.8:
		p.health = p.max_health
		p.wounds.pool = 0.0


func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.02, at.z)


func _away(a: WildAnimal) -> void:
	a.global_position = _ground(Vector3(-200.0, 0.0, 200.0 + randf() * 20.0))
	a.set_active(false)


## The player in the fort (the wolves never come for him there).
func _in_fort() -> void:
	p.global_position = _ground(Vector3(0.0, 0.0, 8.0)) + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO


func _put_player(at: Vector3) -> void:
	p.global_position = _ground(at) + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO


## The pack at `at`, calm, its members as hungry as `need`, no plan.
func _pack_at(at: Vector3, need: float) -> void:
	var i := 0
	for a: WildAnimal in g.alive():
		a.global_position = _ground(at + Vector3(float(i % 3) * 1.8, 0.0, floorf(i / 3.0) * 1.8))
		a.set_active(true)
		a.awareness = 0.0
		a.hunger = need
		a.health = float(a.data.health)
		a._enter(WildAnimal.State.IDLE, 1.0)
		i += 1
	g.activity = WildGroup.Activity.BED
	g.activity_since = w.now
	g.dest_set = false
	g.prey = null
	g.carcass = null
	g.trail_of = null
	g.trail_wait = -1.0
	g.after_player_until = -1e9
	g.trails_left.clear()
	g.shadowing = false
	g.losses = 0
	g.routed_until = -1e9


## The pack parked far off.
func _pack_off() -> void:
	for a: WildAnimal in g.alive():
		_away(a)
	g.activity = WildGroup.Activity.BED
	g.carcass = null
	g.prey = null
	g.trail_of = null
	g.after_player_until = -1e9


## A deer not used yet, at `at`, calm.
func _deer(at: Vector3) -> WildAnimal:
	for a in w.animals():
		if a.species == "deer" and not a.is_dead() and not (a in _used):
			_used.append(a)
			a.global_position = _ground(at)
			a.set_active(true)
			a.awareness = 0.0
			a._enter(WildAnimal.State.IDLE, 2.0)
			return a
	return null


## The player's shot into `d` (from where he stands).
## The player's shot into `d` (from where he stands): through its middle (a gut wound: it lives on minutes), or
## through the lungs (`lungs`: it runs on seconds and drops).
func _shoot(d: WildAnimal, dmg: float, lungs := false) -> void:
	var dir := d.global_position - p.global_position
	dir.y = 0.0
	var at := _lungs_of(d) if lungs else d.global_position + Vector3.UP * 0.6
	d.apply_hit(dmg, at, dir.normalized(), p, "body")


## The middle of `d`'s lungs (WildlifeSpecies.LUNGS in its body capsule): a shot through there is a lung shot.
func _lungs_of(d: WildAnimal) -> Vector3:
	var sb: StaticBody3D = d._zones[0]
	var cap := d._body_capsule()
	var axis := sb.global_basis.y.normalized()
	var hb := d._skel.find_bone(String((d.data.head as Array)[1]))
	if (d._skel.global_transform * d._skel.get_bone_global_pose(hb).origin - sb.global_position).dot(axis) < 0.0:
		axis = -axis
	var up := (Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
	var o: Array = WildlifeSpecies.LUNGS
	return sb.global_position + axis * cap.height * 0.5 * float(o[0]) + up * cap.radius * float(o[1])


func _near_trail(d: WildAnimal, at: Vector3) -> float:
	var best := INF
	for b: Dictionary in w.animal_blood:
		if b.who == d:
			best = minf(best, (b.pos as Vector3).distance_to(at))
	return best


# --- The parts -----------------------------------------------------------------------------------

func _plenty() -> void:
	_h = 0.0
	_in_fort()
	w.animal_blood.clear()
	var spot := Vector3(100.0, 0.0, 100.0)
	var d := _deer(spot)
	_expect(d != null, "plenty: a deer")
	if d == null:
		return
	_shoot(d, 30.0)
	await _secs(2.0)
	_pack_at(spot + Vector3(-12.0, 0.0, -6.0), 0.6)
	var tracked := false
	var hunted := false
	for k in int(10.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		tracked = tracked or g.trail_of == d or g.activity == WildGroup.Activity.TRACK
		hunted = hunted or g.prey == d
	_expect(w.ecology.wolf_hunger() < 0.05, "plenty: the land full of deer (wolf hunger %.2f)" % w.ecology.wolf_hunger())
	_expect(not tracked, "plenty: the pack by his wounded deer's fresh blood takes up no trail")
	_expect(not hunted and w.pick_prey(d.global_position, 350.0) != d, "plenty: nor picks his wounded deer to hunt")
	d.apply_hit(999.0, d.global_position + Vector3.UP * 0.6, Vector3.FORWARD, p, "body")
	_expect(d.is_dead() and w.nearest_carcass(d.global_position, 300.0, "wolf") != d,
			"plenty: nor goes for it dead (killed by %s)" % d.killed_by)
	_pack_off()


## A deer he wounded (through the middle, a gut wound: it lives on; "dead": through the lungs, it bleeds out soon): the
## pack crosses its blood and follows it.
func _track(dmg: float, part: String) -> void:
	_h = 0.55
	_in_fort()
	w.animal_blood.clear()
	var spot := Vector3(110.0, 0.0, 90.0) if part == "track" else Vector3(90.0, 0.0, 120.0)
	var d := _deer(spot)
	_expect(d != null, part + ": a deer")
	if d == null:
		return
	_shoot(d, dmg, part == "dead")
	await _secs(3.0)
	var start := d.global_position
	_pack_at(spot + (spot - p.global_position).normalized() * -10.0, 0.45)
	var took := false
	for k in int(4.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		if g.activity == WildGroup.Activity.TRACK and g.trail_of == d:
			took = true
			break
	_expect(took, "%s: short of deer (hunger %.2f), the pack crosses his wounded deer's blood and takes up its trail" %
			[part, w.ecology.wolf_hunger()])
	var off := 0.0
	var n := 0
	var t := 0.0
	var lead_start := g.leader().global_position
	while t < 150.0:
		await physics_frame
		_hold()
		t += 1.0 / Engine.physics_ticks_per_second
		if g.activity == WildGroup.Activity.TRACK and int(t * 10.0) % 10 == 0:
			off += _near_trail(d, g.leader().global_position)
			n += 1
		if (g.activity == WildGroup.Activity.HUNT and g.prey == d) or (g.activity == WildGroup.Activity.EAT and g.carcass == d):
			break
	var went := g.leader().global_position.distance_to(lead_start)
	_expect(n > 0 and off / n < 10.0 and went > 20.0,
			"%s: the leader keeps to the drops (%.1f m off them on average, %.0f m along; the deer %.0f m off 3 s after the shot)" %
			[part, off / maxf(n, 1.0), went, start.distance_to(spot)])
	if part == "track":
		_expect((g.activity == WildGroup.Activity.HUNT and g.prey == d) or (g.activity == WildGroup.Activity.EAT and g.carcass == d),
				"track: up with it, they hunt it (%s, deer %s, %.0f s)" % [WildGroup.Activity.keys()[g.activity],
				"dead" if d.is_dead() else "alive", t])
	else:
		_expect(d.is_dead() and d.killed_by == "player", "dead: the deer bled out, his kill (%s)" % d.killed_by)
		_expect(g.activity == WildGroup.Activity.EAT and g.carcass == d,
				"dead: the pack follows the trail to it and it is their kill (%s, %.0f s)" % [WildGroup.Activity.keys()[g.activity], t])
	_pack_off()


## Hungry, he at his kill: they wait off it; he goes, they eat it.
func _wait() -> void:
	_h = 0.55
	w.animal_blood.clear()
	var spot := Vector3(80.0, 0.0, 80.0)
	var d := _deer(spot)
	if d == null:
		_expect(false, "wait: a deer")
		return
	_put_player(spot + Vector3(2.0, 0.0, 0.0))
	_shoot(d, 999.0)
	_pack_at(spot + Vector3(-22.0, 0.0, 8.0), 0.45)
	var waited := false
	var nearest := INF
	for k in int(15.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		p.velocity = Vector3.ZERO
		# (their own notice of him held off: this part is the plan's wait; a pack that sees him hunts him as ever)
		for a: WildAnimal in g.alive():
			a.awareness = 0.0
		waited = waited or (g.activity == WildGroup.Activity.TRACK and g.trail_wait >= 0.0)
		if k > int(8.0 * Engine.physics_ticks_per_second):
			nearest = minf(nearest, g.leader().global_position.distance_to(d.global_position))
	_expect(waited and g.carcass != d, "wait: hungry, he at his kill, they do not take it: they wait")
	_expect(nearest > 20.0, "wait: well away from it (the leader %.0f m off at the nearest)" % nearest)
	_in_fort()
	var ate := false
	for k in int(15.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		if g.activity == WildGroup.Activity.EAT and g.carcass == d:
			ate = true
			break
	_expect(ate, "wait: he gone, they take it (EAT)")
	_pack_off()


## Starving, he at his kill: they take it and come for him.
func _starving() -> void:
	_h = 0.9
	w.animal_blood.clear()
	var spot := Vector3(70.0, 0.0, 110.0)
	var d := _deer(spot)
	if d == null:
		_expect(false, "starving: a deer")
		return
	_put_player(spot + Vector3(2.0, 0.0, 0.0))
	_shoot(d, 999.0)
	_pack_at(spot + Vector3(-22.0, 0.0, 8.0), 0.45)
	bites = 0
	var took := false
	var came := false
	for k in int(30.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		p.velocity = Vector3.ZERO
		took = took or (g.carcass == d and g.after_player_until > w.now)
		for a: WildAnimal in g.alive():
			if a.state in [WildAnimal.State.CHASE, WildAnimal.State.ATTACK] and a.global_position.distance_to(p.global_position) < 12.0:
				came = true
		if came and bites > 0:
			break
	_expect(took, "starving: he at his kill, they take it (hunger %.2f)" % w.ecology.wolf_hunger())
	_expect(came or bites > 0, "starving: and come for him (%d bites)" % bites)
	# fed on it (user 2026-09-28: "why did it go after the player after it just ate"): he stands off the kill, in plain
	# sight, and they want nothing more of him
	_put_player(d.global_position + Vector3(0.0, 0.0, 35.0))
	bites = 0
	var near := INF
	var hunting := 0
	for k in int(12.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		p.velocity = Vector3.ZERO
		for a: WildAnimal in g.alive():
			a.hunger = minf(a.hunger, 0.1)
			a.awareness = 1.0
			a.threat_pos = p.global_position
			if k > int(3.0 * Engine.physics_ticks_per_second):
				near = minf(near, a.global_position.distance_to(p.global_position))
				if a.state in [WildAnimal.State.STALK, WildAnimal.State.CHASE, WildAnimal.State.ATTACK]:
					hunting += 1
	_expect(g.after_player_until < w.now and bites == 0 and hunting == 0 and near > 15.0,
			"fed: they have eaten; he in plain sight off the kill, none comes for him (nearest %.0f m, %d bites)" % [near, bites])
	_pack_off()
	_in_fort()


## His meat gone with him: starving, they come after him; hungry, a kill gone on a rope, they give it up.
func _taken() -> void:
	_h = 0.9
	w.animal_blood.clear()
	var spot := Vector3(120.0, 0.0, 60.0)
	var d := _deer(spot)
	if d == null:
		_expect(false, "taken: a deer")
		return
	_put_player(spot + Vector3(4.0, 0.0, 0.0))
	_shoot(d, 999.0)
	d.dress_step = 2                     # butchered: the meat in his pack, the remains left
	d.meat_left = WildAnimal.REMAINS_MEAT
	_put_player(spot + Vector3(45.0, 0.0, 0.0))
	_pack_at(spot + Vector3(-20.0, 0.0, 6.0), 0.45)
	var after := false
	var near := INF
	for k in int(30.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		p.velocity = Vector3.ZERO
		after = after or g.after_player_until > w.now
		for a: WildAnimal in g.alive():
			near = minf(near, a.global_position.distance_to(p.global_position))
		if after and near < 10.0:
			break
	_expect(after and near < 10.0, "taken: starving, he went off with its meat: they come after him (%.0f m)" % near)
	_pack_off()
	_in_fort()
	# hungry, the kill gone on a rope (his horse's): given up
	_h = 0.55
	w.animal_blood.clear()
	var spot2 := Vector3(60.0, 0.0, 140.0)
	var d2 := _deer(spot2)
	if d2 == null:
		_expect(false, "taken: a second deer")
		return
	_shoot(d2, 999.0)
	d2.set_meta(&"on_chain", true)
	d2.global_position = _ground(spot2 + Vector3(60.0, 0.0, 0.0))
	_pack_at(spot2 + Vector3(-15.0, 0.0, 5.0), 0.45)
	var tracked := false
	for k in int(8.0 * Engine.physics_ticks_per_second):
		await physics_frame
		_hold()
		tracked = tracked or g.trail_of == d2
	_expect(tracked and g.trail_of == null and g.carcass != d2 and g.after_player_until < w.now
			and g.trails_left.has(d2.get_instance_id()),
			"taken: hungry, the kill gone on a rope, they give it up (%s)" % WildGroup.Activity.keys()[g.activity])
	d2.remove_meta(&"on_chain")
	_pack_off()
