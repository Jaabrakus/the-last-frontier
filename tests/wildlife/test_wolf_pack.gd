extends SceneTree
## A wolf pack against a player (user 2026-09-27: "wolfs will attack hindlegs and etc but there goal is to either get us
## weak so we have to heal and recoup"; "bleeding on humans should also leave trails as well for other people to find"),
## on the real level with its wildlife, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_wolf_pack.gd -- wildlife=on
##
##   trail     a bleeding player walking leaves drops of blood (every metre or so); none once it stops
##   scent     a fresh drop of his blood gives a wolf near it his scent
##   legs      a pack set on a player standing still, before him: the one he faces holds off, the bites come from
##             behind, on the legs
##   worn      weak, the pack draws off (well away, no bites) and shadows him; whole again, it comes on
##   alpha     the pack has an alpha (the strongest, larger); shot and hurt badly, the pack is routed: every wolf runs
##             and none bites; the rout over, another wolf is the alpha; the new alpha killed, routed again
## Ends with "WOLF PACK TEST PASSED (<n> checks)" or "WOLF PACK TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var w: WildlifeSpawner
var p: FrontierPlayer
var wolves: Array = []
var bites: Array = []            ## [region, side]


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
	await _secs(1.0)
	wolves = w.animals().filter(func(a: WildAnimal) -> bool: return a.species == "wolf" and not a.is_dead())
	_expect(wolves.size() >= 3, "a wolf pack (%d)" % wolves.size())
	p.wounds.struck.connect(func(region: String, side: String, _kind: String, _dmg: float) -> void: bites.append([region, side]))
	await _trail()
	await _scent()
	if wolves.size() >= 2:
		await _legs()
		await _worn()
		await _alpha()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("WOLF PACK TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("WOLF PACK TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _place(at: Vector3) -> void:
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO


## The wolves far off and calm.
func _park() -> void:
	var i := 0
	for a: WildAnimal in wolves:
		var q := Vector3(-150.0 - i * 3.0, 0.0, 150.0)
		a.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
		a.awareness = 0.0
		a.set_active(false)
		i += 1


func _trail() -> void:
	_park()
	var trail := PlayerBloodTrail.install(p)
	var n0 := w.player_blood.size()
	var start := Vector3(100.0, 0.0, 100.0)
	p.wounds.pool = 25.0
	for i in 60:
		_place(start + Vector3(0.25 * i, 0.0, 0.0))
		await _fr(6)
	var made := w.player_blood.size() - n0
	_expect(made >= 8 and made <= 20, "trail: bleeding, 15 m walked: %d drops of blood left" % made)
	var last: Vector3 = w.player_blood.back().pos if not w.player_blood.is_empty() else Vector3.INF
	_expect(last.distance_to(p.global_position) < 3.0, "trail: the drops follow him")
	p.wounds.pool = 0.0
	var n1 := w.player_blood.size()
	for i in 20:
		_place(start + Vector3(15.0 + 0.25 * i, 0.0, 0.0))
		await _fr(6)
	_expect(w.player_blood.size() == n1, "trail: the bleeding stopped, no more drops")
	p.health = p.max_health


func _scent() -> void:
	var a: WildAnimal = wolves[0]
	_place(Vector3(100.0, 0.0, 100.0))
	var drop := Vector3(40.0, 0.0, 160.0)
	a.global_position = Vector3(drop.x + 12.0, FrontierTerrain.height_at(drop.x + 12.0, drop.z) + 0.02, drop.z)
	a.set_active(true)
	var saved := w.player_blood.duplicate()
	w.player_blood.clear()
	var plain := a._sense_player(p, 0.1)
	w.player_blood.append({"pos": drop, "t": w.now})
	var with_blood := a._sense_player(p, 0.1)
	w.player_blood = saved
	_expect(with_blood > plain + 0.2, "scent: a fresh drop of his blood 12 m off gives the wolf his scent (%.2f, %.2f without)" %
			[with_blood, plain])
	_park()


## The pack before him (in his view), he standing still: the bites come from behind, on the legs.
func _legs() -> void:
	var spot := Vector3(90.0, 0.0, 90.0)
	_place(spot)
	p.health = p.max_health
	p.wounds.clear()
	var fwd := WildAnimal._player_fwd(p)
	var i := 0
	for a: WildAnimal in wolves:
		var q := spot + fwd * (15.0 + i * 1.5) + fwd.cross(Vector3.UP) * (i - 1) * 2.5
		a.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
		a.set_active(true)
		a.awareness = 1.0
		a.threat_pos = spot
		a.hunger = maxf(a.hunger, 0.5)     # (hungry: a fed wolf hunts no one, WildAnimal.FED)
		i += 1
	if wolves[0].group:
		(wolves[0].group as WildGroup).shadowing = false
	bites.clear()
	var faced_bit := false
	var t := 0.0
	while bites.size() < 4 and t < 60.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		p.velocity = Vector3.ZERO
		# (kept whole: this part is about where they bite)
		if p.health < p.max_health * 0.7:
			p.health = p.max_health
			p.wounds.pool = 0.0
		for a: WildAnimal in wolves:
			if a.state == WildAnimal.State.ATTACK and a._faced_by(p) and a.global_position.distance_to(p.global_position) < 2.5:
				faced_bit = true
	var back := bites.filter(func(b: Array) -> bool: return String(b[1]) == "back").size()
	var legs := bites.filter(func(b: Array) -> bool: return String(b[0]) in ["l_leg", "r_leg", "l_foot", "r_foot"]).size()
	_expect(bites.size() >= 3, "legs: the pack comes on and bites (%d bites in %.0f s)" % [bites.size(), t])
	_expect(not faced_bit, "legs: none bites where he looks")
	_expect(bites.size() > 0 and back >= int(ceil(bites.size() * 0.75)), "legs: the bites come from behind (%d of %d)" % [back, bites.size()])
	_expect(bites.size() > 0 and legs >= int(ceil(bites.size() * 0.75)), "legs: on the legs (%d of %d: %s)" % [legs, bites.size(), str(bites)])


## The alpha: hurt badly, the pack runs; a new one after the rout; the new one killed, it runs again.
func _alpha() -> void:
	var g: WildGroup = (wolves[0] as WildAnimal).group
	if g == null:
		_expect(false, "alpha: the wolves are a pack")
		return
	g.is_routed(w.now)
	var al := g.alpha
	var others := wolves.filter(func(a: WildAnimal) -> bool: return a != al and not a.is_dead())
	_expect(al != null and al._visual.scale.x > (others[0] as WildAnimal)._visual.scale.x * 1.05,
			"alpha: the pack has an alpha, larger than the rest")
	p.health = p.max_health
	p.wounds.pool = 0.0
	for a: WildAnimal in wolves:
		a.awareness = 1.0
	await _secs(3.0)
	# shot: hurt under 60%
	al.apply_hit(float(al.data.health) * 0.5, al.global_position + Vector3.UP * 0.6, Vector3.FORWARD, p, "body")
	_expect(g.alpha == null and g.is_routed(w.now), "alpha: shot and hurt badly, it falls; the pack is routed")
	bites.clear()
	var d0 := 0.0
	for a: WildAnimal in others:
		d0 += a.global_position.distance_to(p.global_position)
	var fled := 0
	for k in 10 * 60:
		await physics_frame
		p.velocity = Vector3.ZERO
		p.health = p.max_health
	var d1 := 0.0
	for a: WildAnimal in others:
		d1 += a.global_position.distance_to(p.global_position)
		if a.state == WildAnimal.State.FLEE or a.global_position.distance_to(p.global_position) > 30.0:
			fled += 1
	_expect(bites.is_empty() and fled == others.size() and d1 > d0,
			"alpha: routed, every wolf runs (%d of %d, %.0f m to %.0f m off in all) and none bites" % [fled, others.size(), d0, d1])
	# the rout over: a new alpha, not the one that fell
	g.routed_until = w.now
	await _fr(30)
	g.is_routed(w.now)
	var na := g.alpha
	_expect(na != null and na != al and not na.is_dead() and na._visual.scale.x > (al._visual.scale.x if is_instance_valid(al) else 0.0),
			"alpha: the rout over, another wolf is the alpha (%s)" % (na.name if na else "none"))
	# the new alpha killed: routed again
	if na:
		na.apply_hit(9999.0, na.global_position + Vector3.UP * 0.6, Vector3.FORWARD, p, "vitals")
		_expect(na.is_dead() and g.is_routed(w.now), "alpha: the new alpha killed, the pack is routed again")


## Weak: the pack draws off and shadows; whole again: it comes on.
func _worn() -> void:
	p.health = p.max_health * 0.3
	p.wounds.pool = 0.0
	for a: WildAnimal in wolves:
		a.awareness = 1.0
	await _secs(6.0)
	var near := INF
	bites.clear()
	for k in 15 * 60:
		await physics_frame
		p.velocity = Vector3.ZERO
		p.health = p.max_health * 0.3
		for a: WildAnimal in wolves:
			a.awareness = maxf(a.awareness, 0.8)
			near = minf(near, a.global_position.distance_to(p.global_position))
	var g: WildGroup = (wolves[0] as WildAnimal).group
	_expect(g != null and g.shadowing, "worn: weak, the pack shadows him")
	_expect(bites.is_empty() and near > 12.0, "worn: it draws off (none nearer than %.0f m, %d bites in 15 s)" % [near, bites.size()])
	p.health = p.max_health
	p.wounds.pool = 0.0
	var came := false
	for k in 40 * 60:
		await physics_frame
		p.velocity = Vector3.ZERO
		for a: WildAnimal in wolves:
			a.awareness = maxf(a.awareness, 0.8)
		if not bites.is_empty():
			came = true
			break
	_expect(g != null and not g.shadowing and came, "worn: whole again, it comes on (a bite)")
