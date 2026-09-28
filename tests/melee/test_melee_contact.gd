extends SceneTree
## Melee contact (user 2026-09-27: "we need a collision thing where it doesnt go thru the target", "if two weapons
## collide they both bounce back"), headless on the real level, the player driven by its input actions:
##   dummy    D at a straw dummy where its edge passes (1.05 m): the edge cuts in, slowed, to the core of the part it met
##            (its torso's post, user 2026-09-27 "i still want the crunch maybe go all the way to the spine"; or, the
##            edge coming from the side meeting the tip of an arm first, as it may, the arm's middle), the crunch, and
##            goes on through ("have the strike if hit go thru the body"): no hold, the swing plays out past it, the
##            dummy struck once; LMB during the follow-through begins the next at its chain time
##   block    D into a wooden post where its edge passes: it stops on the wood and bounces back; no damage
##   exchange against a sparring partner 1.1 m off, blocks only by counters (user 2026-09-27: "ad should only parry
##            thrusts and [the] users should only block by counters and thats it") and the first blow to land winning
##            ("if the other user hits the user [first] then a hit animation happens and it restarts the persons hit
##            swing"; "its more about timing and who can win the exchange"):
##              counter  the player's D and the partner's D at once (facing each other the side cuts are mirrored: the
##                       same cut meets it head on; "if the user does the same attacks it cancel out ... besides the up
##                       down and down up"): stopped short, both bounce back, no harm; the same for A and A
##              first    the partner's D a moment ahead of the player's A (not its counter): it lands, the player is
##                       hurt and flinches, their A broken off (it lands nothing), no attack begins in the flinch; the
##                       other way round (the player's D ahead of the partner's A) the partner is struck, flinches (the
##                       hit reaction), its A lost
##              guard    the player's D on the partner on guard: nothing blocks it, full damage
##              parry    the parry (A+D; our own sweep, "the thrust parry is weird") a moment after the partner's stab:
##                       the stab is stopped, no harm; against the partner's D: not a stab, so it lands; the parry turns
##                       a stab (block_power), nothing else
##   fairness (user 2026-09-27, the fairness pass):
##              stunlock the player struck first (the partner's D) and flinching has time to counter the partner's next
##                       D chained on at its chain time: it is stopped, no second blow lands
##              interrupt a graze (under AxeMelee.INTERRUPT_DAMAGE) does not break an attack off; a real blow does
##              stamina  an attack spends its cost, a feint (RMB) its own; too little and LMB begins nothing; none comes
##                       back for PlayerGrip.REST_S, then it does
##              stab     played slower (rate 0.8)
##              heads    a melee blow takes no head bonus (the partner's head, x2 for shots, takes it as the body)
##   Godot --headless --path . -s tests/melee/test_melee_contact.gd
## "MELEE CONTACT TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.

const SPOT := Vector3(6.0, 0.0, 8.0)

var p: FrontierPlayer
var g: GatherTools
var failures := PackedStringArray()
var checks := 0


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	p = current_scene.get_node_or_null("Player")
	if p == null:
		print("MELEE CONTACT TEST FAILED (no player)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	g = p.gather
	await _fr(240)
	g.take_out("felling_axe")
	for i in 240:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	_expect(g.phase == GatherTools.Phase.READY, "draw: the felling axe out")
	await _dummy()
	await _block()
	await _exchange()
	await _fairness()
	if failures.is_empty():
		print("MELEE CONTACT TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("MELEE CONTACT TEST FAILED (%d of %d)" % [failures.size(), checks])
		quit(1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _home() -> void:
	p.global_position = SPOT + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	p.grip.stamina = p.grip.stamina_max
	await _fr(20)


func _attack_d() -> void:
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("move_right")
	Input.action_release("fire")


func _edge() -> Vector3:
	var m := g._model_hand
	return m.global_transform * (g.melee._points(m).edge as Vector3)


## Plays the attack out (g.melee.last_contact cleared first), noting the swing's contact states, the u it first met
## something at and the most it reached after (held back: it bounced; on: it went through), whether it crunched at a
## core (and which part), and the deepest the edge went (depth(edge) > 0 in).
func _watch(depth: Callable, depth_arms := Callable()) -> Dictionary:
	var out := {"states": {}, "deepest": -INF, "deepest_arms": -INF, "u_max_after": -INF, "u_hit": INF, "core": false,
			"core_part": ""}
	var s0: Dictionary = g._swing
	for i in 200:
		await physics_frame
		var s: Dictionary = g._swing
		if s != s0:
			break
		if s.has("contact"):
			out.states[String(s.contact)] = true
		var lc: Dictionary = g.melee.last_contact
		if not lc.is_empty():
			if float(out.u_hit) == INF:
				out.u_hit = float(lc.get("u", s.u))     # (the moment it met it)
			out.u_max_after = maxf(float(out.u_max_after), float(s.u))
			if bool(lc.get("core", false)) and not bool(out.core):
				out.core = true
				out.core_part = String(lc.get("core_part", ""))
		out.deepest = maxf(float(out.deepest), float(depth.call(_edge())))
		if depth_arms.is_valid():
			out.deepest_arms = maxf(float(out.deepest_arms), float(depth_arms.call(_edge())))
		if g.phase == GatherTools.Phase.READY:
			break
	return out


func _dummy() -> void:
	await _home()
	var at := SPOT + Vector3(0.0, 0.0, -1.05)
	var d := TargetDummy.new()
	d.position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	current_scene.add_child(d)
	d.max_health = 1.0e6
	d.health = 1.0e6
	await _fr(10)
	var hp := d.health
	var axis := d.global_position
	g.melee.last_contact = {}
	g.melee.last_hits = []
	await _attack_d()
	# (how far the edge is in from the torso's side toward the post: radius 0.22 round it, 0.85..1.82 up to the head)
	var w := await _watch(func(e: Vector3) -> float:
		var y := e.y - axis.y
		if y < 0.85 or y > 1.82:
			return -1.0
		return 0.22 - Vector2(e.x - axis.x, e.z - axis.z).length(),
		func(e: Vector3) -> float:
			# (in from the arms' faces toward their middle line, across at 1.35 m)
			var q := d.to_local(e)
			if absf(q.x) > 0.525:
				return -1.0
			return 0.05 - Vector2(q.y - 1.35, q.z).length())
	var lc := g.melee.last_contact
	var arm := String(w.core_part) == "Arms"
	var deep := float(w.deepest_arms) if arm else float(w.deepest)
	_expect(String(lc.get("surface", "")) == "straw", "dummy: D cuts into the straw (met %s)" % lc.get("surface", "nothing"))
	_expect(bool(w.core), "dummy: the cut goes in to the core (the crunch)")
	_expect(d.health < hp and g.melee.last_hits.size() == 1, "dummy: struck, once (took %.0f in %d blows)" % [hp - d.health, g.melee.last_hits.size()])
	# (the torso: in toward the post, 0.22 in: the edge's path passes the post 7 to 15 cm off run to run, as the pose
	# it swings from sways, and a path passing off it crunches at its deepest (the core check above); well inside the
	# torso, then, not how deep exactly; an arm, 0.1 thick: into it, at its middle)
	_expect(deep > (0.0 if arm else 0.04), "dummy: the edge goes deep, toward the core of the %s (%.2f m in)" % [w.core_part, deep])
	_expect((w.states as Dictionary).is_empty(), "dummy: nothing holds it or runs it back (%s)" % str((w.states as Dictionary).keys()))
	_expect(float(w.u_max_after) > float(w.u_hit) + 0.3, "dummy: it goes on through, the swing playing out (u %.2f past %.2f)" % [w.u_max_after, w.u_hit])
	# LMB during the follow-through: the next attack begins at the swing's chain time
	await _fr(30)
	await _home()
	g.melee.last_contact = {}
	await _attack_d()
	var first: Dictionary = g._swing
	for i in 120:
		await physics_frame
		if not g.melee.last_contact.is_empty():
			break
	_expect(not g.melee.last_contact.is_empty(), "dummy: the second D meets it too")
	Input.action_press("move_left")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("fire")
	Input.action_release("move_left")
	var next := false
	for i in 120:
		await physics_frame
		if g._swing != first and String(g._swing.get("dir", "")) == "A":
			next = true
			break
	_expect(next, "dummy: LMB in the follow-through begins the next attack")
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	d.queue_free()
	await _fr(5)


func _block() -> void:
	await _home()
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 1.8, 0.2)
	cs.shape = box
	b.add_child(cs)
	b.set_meta(&"surface", "wood")
	current_scene.add_child(b)
	var c := SPOT + Vector3(0.0, 0.0, -1.05)
	b.global_position = Vector3(c.x, FrontierTerrain.height_at(c.x, c.z) + 0.9, c.z)
	await _fr(5)
	await _attack_d()
	var bc := b.global_position
	var w := await _watch(func(e: Vector3) -> float:
		# (inside the box: the least way out)
		var r := (e - bc).abs()
		return minf(minf(0.1 - r.x, 0.9 - r.y), 0.1 - r.z))
	var lc := g.melee.last_contact
	_expect(String(lc.get("surface", "")) == "wood", "block: D stops on the wood (met %s)" % lc.get("surface", "nothing"))
	_expect(float(w.deepest) < 0.02 + 0.05, "block: the edge stays out of the wood (%.2f m in)" % float(w.deepest))
	_expect((w.states as Dictionary).has("recoil") and float(w.u_max_after) <= float(w.u_hit) + 0.01, "block: it bounces back")
	b.queue_free()
	await _fr(5)


func _exchange() -> void:
	await _home()
	var sp := SparringPartner.new()
	current_scene.add_child(sp)
	var at := SPOT + Vector3(0.0, 0.0, -1.1)
	sp.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	await _fr(10)
	# counter: both bounce back, no harm
	var r := await _beat(sp, ["move_right"], "D", 0)
	_expect(bool(sp.last_contact.has("blocked")) or bool(g.melee.last_contact.has("blocked")),
			"counter: D met by D is blocked (player met %s, partner met %s)" % [_met(g.melee.last_contact), _met(sp.last_contact)])
	_expect((r.states as Dictionary).has("recoil"), "counter: the player's swing bounces back (%s)" % str((r.states as Dictionary).keys()))
	_expect(String(sp.last_contact.get("surface", "")) == "weapon", "counter: the partner's swing bounces back too (met %s)" % _met(sp.last_contact))
	_expect(float(r.took) == 0.0 and int(r.hits) == 0, "counter: no harm either way (partner took %.0f, player struck %d)" % [r.took, r.hits])
	var ra := await _beat(sp, ["move_left"], "A", 0)
	_expect((bool(sp.last_contact.has("blocked")) or bool(g.melee.last_contact.has("blocked"))) and float(ra.took) == 0.0
			and int(ra.hits) == 0, "counter: A met by A is blocked, no harm (player met %s, partner met %s)" % [_met(g.melee.last_contact), _met(sp.last_contact)])
	# the partner a moment ahead: its blow lands first
	r = await _beat(sp, ["move_left"], "D", -12)
	_expect(float(r.hurt) > 0.0, "first: the partner's D lands on the player first (player lost %.0f)" % float(r.hurt))
	_expect(bool(r.interrupted), "first: the player's A is broken off")
	_expect(float(r.took) == 0.0, "first: so it lands nothing (partner took %.0f; player met %s)" % [float(r.took), _met(g.melee.last_contact)])
	_expect(bool(r.flinch_blocked), "first: no attack begins in the flinch")
	# the player a moment ahead: the partner is struck, flinches, its A lost
	r = await _beat(sp, ["move_right"], "A", 12)
	_expect(float(r.took) > 0.0, "first: the player's D lands first (partner took %.0f)" % float(r.took))
	_expect(bool(r.partner_flinched), "first: the partner flinches (the hit reaction)")
	_expect(int(r.hits) == 0, "first: its A lost, the player not struck (%d blows)" % int(r.hits))
	# the guard blocks nothing
	r = await _beat(sp, ["move_right"], "", 0)
	_expect(float(r.took) > 0.0 and not g.melee.last_contact.has("glance") and not g.melee.last_contact.has("blocked"),
			"guard: the D on the partner's guard lands whole (took %.0f, met %s)" % [r.took, _met(g.melee.last_contact)])
	# the parry turns a stab, nothing else
	r = await _beat(sp, ["move_left", "move_right"], "STAB", -10)
	_expect(bool(sp.last_contact.has("blocked")) and int(r.hits) == 0,
			"parry: the partner's stab is stopped, no harm (partner met %s, player struck %d)" % [_met(sp.last_contact), r.hits])
	r = await _beat(sp, ["move_left", "move_right"], "D", -10)
	_expect(String(r.dir) == "AD", "parry: A+D is the parry (%s)" % r.dir)
	_expect(float(r.hurt) > 0.0 and not sp.last_contact.has("blocked"), "parry: the partner's D is not a stab: it lands (player lost %.0f, partner met %s)" % [r.hurt, _met(sp.last_contact)])
	await _home()
	Input.action_press("move_left")
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(4)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("fire")
	var pb_stab := g.melee.block_power("STAB", Vector3.ZERO, Vector3.FORWARD)
	var pb_d := g.melee.block_power("D", Vector3.ZERO, Vector3.FORWARD)
	_expect(String(g._swing.get("dir", "")) == "AD" and pb_stab >= AxeMelee.BLOCK_FULL and pb_d == 0.0,
			"parry: it blocks a stab whole (%.2f) and a cut not at all (%.2f)" % [pb_stab, pb_d])
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY and g._swing.is_empty():
			break
	sp.queue_free()


func _fairness() -> void:
	await _home()
	var sp := SparringPartner.new()
	current_scene.add_child(sp)
	var at := SPOT + Vector3(0.0, 0.0, -1.1)
	sp.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	await _fr(10)
	# stunlock: struck first, then the partner's next D chained on; the player counters it (D) as the flinch ends
	p.health = p.max_health
	var hits := [0]
	var on_hurt := func(_l: Vector2, _a: float, _h: bool) -> void: hits[0] += 1
	p.hurt.connect(on_hurt)
	sp.swing("D")
	var chained := false
	var countered := false
	var blocked := false
	for tick in 400:
		if tick == 12:
			Input.action_press("move_left")
			Input.action_press("fire")
		if tick == 14:
			Input.action_release("move_left")
			Input.action_release("fire")
		if not chained and hits[0] > 0 and sp.state == "swing" and sp.u >= float(sp._chain):
			sp.last_contact = {}
			sp.swing("D")
			chained = true
		if chained and not countered and not g.melee.flinching():
			countered = true
			Input.action_press("move_right")
			Input.action_press("fire")
			await physics_frame
			Input.action_release("move_right")
			Input.action_release("fire")
		await physics_frame
		blocked = blocked or chained and sp.last_contact.has("blocked")
		if countered and sp.state == "" and g.phase == GatherTools.Phase.READY and g._swing.is_empty():
			break
	p.hurt.disconnect(on_hurt)
	_expect(chained and countered, "stunlock: struck, the partner's next D chained on, the player free to answer (chained %s, answered %s)" % [chained, countered])
	_expect(blocked and hits[0] == 1, "stunlock: the counter stops the second blow (blocked %s, struck %d times)" % [blocked, hits[0]])
	# interrupt: a graze does not break a W off, a real blow does
	await _home()
	Input.action_press("move_forward")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("move_forward")
	Input.action_release("fire")
	await _fr(6)
	var w: Dictionary = g._swing
	p.apply_hit(AxeMelee.INTERRUPT_DAMAGE - 5.0, p.global_position + Vector3(0, 1, -0.3), Vector3(0, 0, 1), sp)
	await _fr(2)
	_expect(g._swing == w and not bool(w.get("cancel", false)) and not g.melee.flinching(), "interrupt: a graze does not break the W off")
	p.apply_hit(AxeMelee.INTERRUPT_DAMAGE + 5.0, p.global_position + Vector3(0, 1, -0.3), Vector3(0, 0, 1), sp)
	await _fr(2)
	_expect(bool(w.get("cancel", false)) and g.melee.flinching(), "interrupt: a real blow does")
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY and g._swing.is_empty() and not g.melee.flinching():
			break
	p.health = p.max_health
	# stamina: an attack and a feint spend it; too little, nothing begins; it comes back after the rest
	await _home()
	var st0 := p.grip.stamina
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("move_right")
	Input.action_release("fire")
	var st1 := p.grip.stamina
	_expect(absf(st0 - st1 - g.melee.cost("D")) < 0.01, "stamina: the D spends %.0f (%.1f -> %.1f)" % [g.melee.cost("D"), st0, st1])
	await _fr(10)
	Input.action_press("aim")
	await _fr(2)
	Input.action_release("aim")
	_expect(bool(g._swing.get("cancel", false)) and absf(st1 - p.grip.stamina - g.melee.cost("feint")) < 0.01,
			"stamina: the feint spends %.0f (now %.1f)" % [g.melee.cost("feint"), p.grip.stamina])
	for i in 60:
		await physics_frame
		if g.phase == GatherTools.Phase.READY and g._swing.is_empty():
			break
	p.grip.stamina = g.melee.cost("D") - 1.0
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("move_right")
	Input.action_release("fire")
	_expect(g._swing.is_empty(), "stamina: too little, LMB begins nothing (%s)" % g._swing.get("dir", "-"))
	var low := p.grip.stamina
	p.grip.spend(1.0)
	await _fr(int(PlayerGrip.REST_S * 60.0))
	_expect(p.grip.stamina <= low, "stamina: none back while resting after a spend (%.1f)" % p.grip.stamina)
	await _fr(int(PlayerGrip.REST_S * 120.0))
	_expect(p.grip.stamina > low + 5.0, "stamina: then it comes back (%.1f)" % p.grip.stamina)
	# the stab slower; no head bonus on the partner
	await _home()
	Input.action_press("move_forward")
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("fire")
	_expect(String(g._swing.get("dir", "")) == "STAB" and absf(float(g._swing.get("rate", 0.0)) - 0.8) < 0.01,
			"stab: played at 0.8 (%.2f)" % float(g._swing.get("rate", 0.0)))
	var t0 := sp.damage_taken
	Hit.deliver(sp._head, 10.0, sp._head.global_position, Vector3(0, 0, 1), p, false)
	var melee_head := sp.damage_taken - t0
	Hit.deliver(sp._head, 10.0, sp._head.global_position, Vector3(0, 0, 1), p)
	var shot_head := sp.damage_taken - t0 - melee_head
	_expect(Sfx.surface_of(p, p.global_position + Vector3(0, 1, 0), Vector3.BACK) == "flesh",
			"players: a player's body is flesh to a blow (duels: cut into and gone through, not bounced off as wood)")
	_expect(melee_head == 10.0 and shot_head == 20.0, "heads: a melee blow to the head as the body (%.0f), a shot doubled (%.0f)" % [melee_head, shot_head])
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY and g._swing.is_empty():
			break
	sp.queue_free()


## One exchange: the player's attack (the keys with LMB; none: on guard) and the partner's (`other`, "" none), the
## partner `lead` ticks after the player (before, negative); played out. {"states": the player's swing's contact states,
## "dir", "took": the partner's damage, "hurt": the player's health lost, "hits": the blows the player took (hurt;
## health alone would count a wound still bleeding), "interrupted", "flinch_blocked": LMB in the flinch began nothing,
## "partner_flinched"}.
func _beat(sp: SparringPartner, keys: Array, other: String, lead: int) -> Dictionary:
	await _home()
	p.health = p.max_health
	await _fr(40)
	g.melee.last_contact = {}
	sp.last_contact = {}
	var out := {"states": {}, "dir": "", "took": 0.0, "hurt": 0.0, "hits": 0, "interrupted": false,
			"flinch_blocked": false, "partner_flinched": false}
	var took0 := sp.damage_taken
	var hp0 := p.health
	var cut := func(_d: String) -> void: out.interrupted = true
	g.melee.interrupted.connect(cut)
	var hurt := func(_l: Vector2, _a: float, _h: bool) -> void: out.hits = int(out.hits) + 1
	p.hurt.connect(hurt)
	var t_me := 0 if lead >= 0 else -lead
	var t_sp := lead if lead >= 0 else 0
	var tried := false
	for tick in 600:
		if tick == t_me and not keys.is_empty():
			for k: String in keys:
				Input.action_press(k)
			Input.action_press("fire")
		if tick == t_me + 2:
			for k: String in keys:
				Input.action_release(k)
			Input.action_release("fire")
		if tick == t_sp and other != "":
			sp.swing(other)
		# struck: LMB again at once begins nothing (the flinch)
		if bool(out.interrupted) and not tried:
			tried = true
			Input.action_press("fire")
			await physics_frame
			Input.action_release("fire")
			out.flinch_blocked = g.melee.flinching() and (g._swing.is_empty() or bool(g._swing.get("cancel", false)))
		await physics_frame
		if not g._swing.is_empty():
			if String(out.dir) == "":
				out.dir = String(g._swing.get("dir", ""))
			if g._swing.has("contact"):
				(out.states as Dictionary)[String(g._swing.contact)] = true
		if sp.state == "flinch":
			out.partner_flinched = true
		if tick > maxi(t_me, t_sp) + 10 and g.phase == GatherTools.Phase.READY and g._swing.is_empty() and sp.state == "" \
				and not g.melee.flinching():
			break
	g.melee.interrupted.disconnect(cut)
	p.hurt.disconnect(hurt)
	out.took = sp.damage_taken - took0
	out.hurt = hp0 - p.health
	return out


static func _met(c: Dictionary) -> String:
	if c.is_empty():
		return "nothing"
	return String(c.get("surface", "-")) + (" glancing" if c.has("glance") else "") + (" blocked" if c.has("blocked") else "") \
			+ " (u %.2f%s)" % [float(c.get("u", -1.0)), (", " + String(c.line)) if c.has("line") else ""]
