extends SceneTree
## Damage from what a shot goes through (Anatomy.effect; user 2026-09-30: "now the new damages should be based on those"), headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/fx/test_anatomy_damage.gd -- wildlife=on [ironman=on]
## (run both ways: injuries touch the movement speed only in Iron Man, GameSettings.iron_man)
##
##   player   heart: mortal (dead in MORTAL_HEART_S); the thigh: the femur broken, alive; a lung bleeds harder than a limb; the cord at
##            T10: alive, the legs gone (slow, thrown down); at T3: dead within seconds; the brain: dead at once (the fitted body,
##            BodyModel: each shot from the body's front, a ball of the damage's energy)
##   animal   the wound kind is what the channel went through: the heart, the lungs, the gut (intestines), the spine (a vertebra)
## Ends with "ANATOMY DAMAGE TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var an: Anatomy
var shooter := Node.new()


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


func _part(a: Anatomy, nm: String) -> Vector3:
	for d in a.parts:
		if d.name == nm:
			return (d.node as Node3D).global_position
	return Vector3.INF


## A ball (`damage`) from the front through the part `nm` (`off`: that far to the body's left of its middle, m): the shooter 0.3 m
## before it on the body's own front (the fitted body's axes).
func _shoot(nm: String, damage := 30.0, off := 0.0) -> void:
	var b := p.skeleton.global_transform.basis.orthonormalized()
	var front := (b * an.model.fwd).normalized()
	var left := (b * an.model.left).normalized()
	p.apply_hit(damage, _part(an, nm) + left * off + front * 0.3, -front, shooter, "body")
	var fx: Dictionary = an.last_shot.get("fx", {})
	print("   %s (%.0f): %s | mortal %.0f s, legs %s, dead %s, health %.0f, mortal_left %.1f" % [nm, damage, " · ".join(an.last_shot.get("lines", [])),
			float(fx.get("mortal_s", 0.0)), fx.get("legs", false), p.is_dead, p.health, p.wounds.mortal_left])


func _fresh() -> void:
	if PlayerRagdoll.of(p).is_down():
		PlayerRagdoll.of(p).recover_now()       # (a cord hit throws the body down: up again for the next shot)
	p.respawn()
	p.health = p.max_health
	p.wounds.clear()
	p.broken_leg = false
	p.maim_legs = false


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	current_scene.add_child(shooter)
	p = current_scene.get_node("Player") as FrontierPlayer
	await _fr(60)
	an = Anatomy.attach_to(p.skeleton)
	# the heart
	_shoot("Heart")
	_expect(not p.is_dead and p.wounds.mortal(), "a ball through the heart is mortal: still up, the clock running")
	_expect(p._maim_speed() <= 0.5 if GameSettings.iron_man() else p._maim_speed() == 1.0, "staggering only in iron man (speed x%.2f, iron man %s)" % [p._maim_speed(), GameSettings.iron_man()])
	await _fr(int(Anatomy.MORTAL_HEART_S * Engine.physics_ticks_per_second) + 30)
	_expect(p.is_dead, "and dead when it runs out")
	await _fr(60)
	_fresh()
	await _fr(120)
	# the thigh: a flesh wound
	_shoot("Left femur")
	_expect(not p.is_dead and p.health > 50.0, "through the thigh it is a wound (health %.0f)" % p.health)
	var arm_pool := p.wounds.pool
	_fresh()
	await _fr(60)
	_shoot("Left lung")
	_expect(not p.is_dead, "a lung: alive")
	_expect(p.wounds.pool > arm_pool * 1.3, "a lung bleeds harder than a limb (pool %.1f against %.1f)" % [p.wounds.pool, arm_pool])
	_fresh()
	await _fr(120)
	# the cord low: legs gone
	_shoot("T10 vertebra")
	print("   T10: hits ", an.last_hits.map(func(h): return h.name), " fx ", Anatomy.effect(an.last_hits, 30.0), " dead ", p.is_dead, " health ", p.health)
	await _fr(10)
	_expect(not p.is_dead and (p._maim_speed() < 0.2 if GameSettings.iron_man() else p._maim_speed() == 1.0), "the cord at T10: alive; the legs gone for good only in iron man (speed x%.2f)" % p._maim_speed())
	_expect(PlayerRagdoll.of(p).is_down(), "thrown down where they stood")
	PlayerRagdoll.of(p).recover_now()
	_fresh()
	await _fr(120)
	_shoot("T3 vertebra")
	_expect(not p.is_dead and p.wounds.mortal(), "the cord at T3 is mortal")
	await _fr(int(Anatomy.MORTAL_CORD_S * Engine.physics_ticks_per_second) + 30)
	_expect(p.is_dead, "the cord at T3 kills within seconds")
	_fresh()
	await _fr(120)
	# a musket ball (120) into the body no longer kills outright: it bleeds, each wound at the pace of what it went through
	_shoot("Left femur", 120.0)
	_expect(not p.is_dead and p.health > 40.0, "a musket ball through the thigh does not kill (%.0f health, the rest bleeds: pool %.0f)" % [p.health, p.wounds.pool])
	var flesh_drain := p.wounds.drain_mult
	_fresh()
	await _fr(60)
	# (off the middle: the fitted body has the aorta and the spine behind the gut there, and a ball would go on into them)
	_shoot("Intestines", 120.0, 0.06)
	var gut_drain := p.wounds.drain_mult
	_expect(not p.is_dead and p.wounds.pool > 0.0, "a ball through the gut: alive and bleeding")
	_fresh()
	await _fr(60)
	_shoot("Left lung", 120.0)
	var lung_drain := p.wounds.drain_mult
	_expect(not p.is_dead and lung_drain > flesh_drain and flesh_drain > gut_drain and lung_drain > gut_drain,
			"it bleeds at the pace of what it went through (lung %.1f, flesh %.1f, gut %.1f)" % [lung_drain, flesh_drain, gut_drain])
	_fresh()
	await _fr(120)
	# a heart wound treated and survived: stretched a long way by the dressings, and it holds
	_shoot("Heart")
	_expect(p.wounds.mortal(), "heart: mortal again")
	await _fr(2 * int(Engine.physics_ticks_per_second))
	p.wounds.dress(1.0)
	_expect(p.wounds.mortal_left > 25.0, "a poultice stretches the clock a long way (%.0f s)" % p.wounds.mortal_left)
	await _fr(int((Anatomy.MORTAL_HEART_S + 3.0) * Engine.physics_ticks_per_second))
	_expect(not p.is_dead, "alive past the untreated time (%.0f health)" % p.health)
	p.wounds.stanch(0.9)
	await _fr(int((PlayerWounds.STABLE_S) * Engine.physics_ticks_per_second))
	_expect(not p.is_dead and not p.wounds.mortal(), "treated and survived long enough: it holds (no longer mortal), alive with %.0f health" % p.health)
	_fresh()
	await _fr(120)
	# the cap
	_shoot("Heart")
	for i in 8:
		p.wounds.dress(1.0)
	_expect(p.wounds.mortal_left <= PlayerWounds.MORTAL_CAP + 0.01, "the clock has a cap (%.0f s)" % p.wounds.mortal_left)
	_fresh()
	await _fr(120)
	_shoot("Brain", 30.0)
	_expect(p.is_dead, "the brain: over at once")
	_fresh()
	await _fr(120)
	# animals
	var w := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	if w:
		var a: WildAnimal = null
		for x: WildAnimal in w.animals():
			if x.species == "deer" and not x.is_dead():
				a = x
				break
		if a:
			var sk: Skeleton3D = a.get("_skel")
			var dn := Anatomy.attach_to(sk)
			# (broadside, from its left: the musket's ball through the heart, the gut and the spine; a light arrow into the near lung,
			# which it stops in: the wound kind is the worst of what the round went through)
			var left := -a.global_basis.x
			for case in [["Heart", "heart", {"kind": "ball", "speed": 320.0}], ["Left lung", "lungs", {"kind": "arrow", "speed": 40.0}],
					["Intestines", "gut", {"kind": "ball", "speed": 320.0}], ["T8 vertebra", "spine", {"kind": "ball", "speed": 320.0}]]:
				a.health = 1000.0
				a.state = WildAnimal.State.IDLE
				var at := _part(dn, case[0])
				Hit.shot = case[2]
				a.apply_hit(5.0, at + left * 0.6, -left, p, "body")
				Hit.shot = {}
				_expect(a.last_wound == case[1] or (case[1] == "spine" and a.is_dead()), "deer: a %s through the %s is a %s wound (%s: %s)" % [
						case[2].kind, case[0], case[1], a.last_wound, Anatomy.report(dn.last_shot.get("lines", []))])
				if a.is_dead():
					break
	if fails.is_empty():
		print("ANATOMY DAMAGE TEST PASSED (%d checks)" % checks)
	else:
		print("ANATOMY DAMAGE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
