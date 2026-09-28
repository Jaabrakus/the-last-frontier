extends SceneTree
## Player against player (user 2026-09-27: "if we had multiplayer and players duel it should work?", "can you use ai to
## check these"), headless on the real level: this machine's player (the keyboard: Input) and a second FrontierPlayer
## on the map (is_local false, driven through its PlayerControls, not the keyboard), both with the felling axe, 1.1 m
## apart, face to face; the same melee on both (AxeMelee), nothing stood in for:
##   second   the second player has no camera of its own in use, no HUD, no E prompts; this machine's keys (the D
##            with LMB) neither move it nor swing it
##   counter  both D at once, then both A: stopped short, both bounce back, no harm
##   first    this player's D a moment ahead of the other's A: it lands on a player's body as flesh (cut in, on
##            through: not bounced off it as wood), the other hurt, flinching, its A broken off, bleeding (BloodFx: the
##            wound's mark on it, the splash on the ground); the other way round the same for this one
##   parry    the other's stab, this one's parry a moment after: stopped, no harm; the other's W (the overhand chop),
##            this one's high block (S, the haft held up across) a moment after: the same
##   stab     this one's stab into the other: in to the spine
##   free     both played by MeleeDuelAI (reacting to each other's attacks with the counter, attacking when left
##            alone, feinting now and then) for DUEL_S: attacks made, counters, blows landed both ways, neither left
##            stuck in a swing at the end
##   Godot --headless --path . -s tests/melee/test_duel.gd
## "DUEL TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.

const SPOT := Vector3(6.0, 0.0, 8.0)
const DUEL_S := 30.0

var p: FrontierPlayer
var q: FrontierPlayer
var failures := PackedStringArray()
var checks := 0


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	p = current_scene.get_node_or_null("Player")
	if p == null:
		print("DUEL TEST FAILED (no player)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	q = FrontierPlayer.new()
	q.name = "Player2"
	q.is_local = false
	q.controls = PlayerControls.new(false)
	q.demo_horse = false
	q.demo_wheelbarrow = false
	current_scene.add_child(q)
	await _fr(240)
	p.gather.take_out("felling_axe")
	q.gather.take_out("felling_axe")
	for i in 300:
		await physics_frame
		if p.gather.phase == GatherTools.Phase.READY and q.gather.phase == GatherTools.Phase.READY:
			break
	_expect(p.gather.phase == GatherTools.Phase.READY and q.gather.phase == GatherTools.Phase.READY,
			"both draw the felling axe (%d, %d)" % [p.gather.phase, q.gather.phase])
	await _second()
	await _counters()
	await _first()
	await _parry_and_stab()
	await _free()
	if failures.is_empty():
		print("DUEL TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("DUEL TEST FAILED (%d of %d)" % [failures.size(), checks])
		quit(1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


## Both back in place, face to face, whole, rested.
func _home() -> void:
	for who: FrontierPlayer in [p, q]:
		who.velocity = Vector3.ZERO
		who.pitch = 0.0
		who.health = who.max_health
		who.grip.stamina = who.grip.stamina_max
	p.global_position = SPOT + Vector3(0, 0.05, 0)
	p.yaw = 0.0
	var at := SPOT + Vector3(0.0, 0.0, -1.1)
	q.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.05, at.z)
	q.yaw = PI
	q.controls.release_all()
	await _fr(40)
	p.gather.melee.last_contact = {}
	q.gather.melee.last_contact = {}


func _second() -> void:
	await _home()
	_expect(p.camera.current and not q.camera.current, "second: this machine's view stays its player's")
	_expect(q.hud == null and q.interactor == null and q.equip_wheel == null
			and q.find_children("GripHUD", "CanvasLayer", true, false).is_empty(),
			"second: no HUD, E prompts, wheel or stamina ring of its own")
	var at := q.global_position
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("move_right")
	Input.action_release("fire")
	await _fr(30)
	_expect(String(p.gather._swing.get("dir", "")) == "D", "second: the keys swing this machine's player (%s)" % p.gather._swing.get("dir", "-"))
	_expect(q.gather._swing.is_empty() and q.global_position.distance_to(at) < 0.05,
			"second: and not the other (swing %s, moved %.2f m)" % [q.gather._swing.get("dir", "-"), q.global_position.distance_to(at)])
	await _settle()


## One exchange: this player's attack (Input) and the other's (its controls), the other `lead` ticks after (before,
## negative). {"p_hurt", "q_hurt", "p_cut", "q_cut" (their attack broken off by a blow)}.
func _exchange(keys_p: Array, keys_q: Array, lead: int) -> Dictionary:
	await _home()
	var out := {"p_hurt": 0, "q_hurt": 0, "p_cut": false, "q_cut": false}
	var hp := func(_l: Vector2, _a: float, _h: bool) -> void: out.p_hurt = int(out.p_hurt) + 1
	var hq := func(_l: Vector2, _a: float, _h: bool) -> void: out.q_hurt = int(out.q_hurt) + 1
	var cp := func(_d: String) -> void: out.p_cut = true
	var cq := func(_d: String) -> void: out.q_cut = true
	p.hurt.connect(hp)
	q.hurt.connect(hq)
	p.gather.melee.interrupted.connect(cp)
	q.gather.melee.interrupted.connect(cq)
	var t_p := 0 if lead >= 0 else -lead
	var t_q := lead if lead >= 0 else 0
	for tick in 500:
		if tick == t_p and not keys_p.is_empty():
			for k: String in keys_p:
				Input.action_press(k)
			Input.action_press("fire")
		if tick == t_p + 2:
			for k: String in keys_p:
				Input.action_release(k)
			Input.action_release("fire")
		if tick == t_q and not keys_q.is_empty():
			for k: String in keys_q:
				q.controls.set_held(StringName(k), true)
			q.controls.set_held(&"fire", true)
		if tick == t_q + 2:
			q.controls.release_all()
		await physics_frame
		_watch_marks()
		if tick > maxi(t_p, t_q) + 10 and _still():
			break
	p.hurt.disconnect(hp)
	q.hurt.disconnect(hq)
	p.gather.melee.interrupted.disconnect(cp)
	q.gather.melee.interrupted.disconnect(cq)
	return out


## Every wound's mark on either, every frame of an exchange from the one it is made: the size it is meant to be
## (world scale 1) and on its body (the red cloud, user 2026-09-27: "theres still that big red cloud of blood?": a
## mark made before its holder was on its bone, blown up by the skeleton's scale, for its first frames).
var mark_worst := ""


func _watch_marks() -> void:
	for who: FrontierPlayer in [p, q]:
		for m in who.skeleton.get_meta(&"wound_marks", []):
			if not is_instance_valid(m):
				continue
			var g: Transform3D = (m as Node3D).global_transform
			var sc := g.basis.get_scale()
			var off := g.origin.distance_to(who.global_position + Vector3(0, 1.0, 0))
			if (absf(sc.x - 1.0) > 0.1 or absf(sc.y - 1.0) > 0.1 or off > 0.9) and mark_worst == "":
				mark_worst = "scale %s, %.2f m from its body's middle" % [sc.snappedf(0.01), off]


func _still() -> bool:
	for who: FrontierPlayer in [p, q]:
		if who.gather.phase != GatherTools.Phase.READY or not who.gather._swing.is_empty() or who.gather.melee.flinching():
			return false
	return true


func _settle() -> void:
	for i in 300:
		await physics_frame
		if _still():
			return


func _counters() -> void:
	var r := await _exchange(["move_right"], ["move_right"], 0)
	var blocked := p.gather.melee.last_contact.has("blocked") or q.gather.melee.last_contact.has("blocked")
	_expect(blocked and int(r.p_hurt) == 0 and int(r.q_hurt) == 0, "counter: D against D, blocked, no harm (%s / %s, hurt %d / %d)" % [
			_met(p.gather.melee.last_contact), _met(q.gather.melee.last_contact), r.p_hurt, r.q_hurt])
	r = await _exchange(["move_left"], ["move_left"], 0)
	blocked = p.gather.melee.last_contact.has("blocked") or q.gather.melee.last_contact.has("blocked")
	_expect(blocked and int(r.p_hurt) == 0 and int(r.q_hurt) == 0, "counter: A against A, blocked, no harm (%s / %s, hurt %d / %d)" % [
			_met(p.gather.melee.last_contact), _met(q.gather.melee.last_contact), r.p_hurt, r.q_hurt])


func _first() -> void:
	var hq := 0.0
	var r := await _exchange(["move_right"], ["move_left"], 12)
	var lc := p.gather.melee.last_contact
	_expect(String(lc.get("surface", "")) == "flesh" and bool(lc.get("through", false)),
			"first: this one's D meets the other player as flesh and goes on through (%s)" % _met(lc))
	_expect(int(r.q_hurt) > 0 and bool(r.q_cut) and int(r.p_hurt) == 0,
			"first: the other hurt, its A broken off, this one unhurt (hurt %d / %d, cut %s)" % [r.p_hurt, r.q_hurt, r.q_cut])
	var marks: Array = q.skeleton.get_meta(&"wound_marks", [])
	_expect(not marks.is_empty(), "blood: the wound's mark on the one struck (%d)" % marks.size())
	var worst := ""
	for m in marks:
		if is_instance_valid(m):
			var g: Transform3D = (m as Node3D).global_transform
			var sc := g.basis.get_scale()
			var off := g.origin.distance_to(q.global_position + Vector3(0, 1.0, 0))
			if absf(sc.x - 1.0) > 0.1 or absf(sc.y - 1.0) > 0.1 or off > 0.9:
				worst = "scale %s, %.2f m from its middle" % [sc.snappedf(0.01), off]
	_expect(worst == "" and mark_worst == "", "blood: the mark stays a mark on its body, not blown up round it, from its first frame (%s%s)" % [worst, mark_worst])
	_expect(BloodFx._ground.size() > 0, "blood: splashed on the ground (%d drops)" % BloodFx._ground.size())
	r = await _exchange(["move_left"], ["move_right"], -12)
	lc = q.gather.melee.last_contact
	_expect(String(lc.get("surface", "")) == "flesh" and int(r.p_hurt) > 0 and bool(r.p_cut) and int(r.q_hurt) == 0,
			"first: the other way round, the same (%s; hurt %d / %d, cut %s)" % [_met(lc), r.p_hurt, r.q_hurt, r.p_cut])


func _parry_and_stab() -> void:
	var r := await _exchange(["move_left", "move_right"], ["move_forward", "move_right"], -3)
	_expect(q.gather.melee.last_contact.has("blocked") and int(r.p_hurt) == 0,
			"parry: the other's stab stopped by this one's parry (%s, hurt %d)" % [_met(q.gather.melee.last_contact), r.p_hurt])
	# the other's W (the overhand chop), this one's high block (S) a moment after
	r = await _exchange(["move_back"], ["move_forward"], -20)
	_expect(q.gather.melee.last_contact.has("blocked") and int(r.p_hurt) == 0,
			"high block: the other's W stopped by this one's S, the haft held up across (%s, hurt %d)" % [_met(q.gather.melee.last_contact), r.p_hurt])
	r = await _exchange(["move_forward", "move_right"], [], 0)
	var lc := p.gather.melee.last_contact
	var core := bool(lc.get("core", false))
	_expect(int(r.q_hurt) > 0, "stab: this one's stab lands on the other (%s)" % _met(lc))
	_expect(core or String(lc.get("surface", "")) == "flesh", "stab: into the body, in to the spine (%s)" % _met(lc))


func _free() -> void:
	await _home()
	for who: FrontierPlayer in [p, q]:
		who.max_health = 1.0e6
		who.health = 1.0e6
	p.controls = PlayerControls.new(false)
	var ai_p := MeleeDuelAI.attach(p, q, 11)
	var ai_q := MeleeDuelAI.attach(q, p, 23)
	var hits := {"p": 0, "q": 0}
	var blocks := [0]
	var hp := func(_l: Vector2, _a: float, _h: bool) -> void: hits.p += 1
	var hq := func(_l: Vector2, _a: float, _h: bool) -> void: hits.q += 1
	var bl := func(surface: String, _pt: Vector3) -> void:
		if surface == "weapon":
			blocks[0] += 1
	p.hurt.connect(hp)
	q.hurt.connect(hq)
	p.gather.melee.contacted.connect(bl)
	q.gather.melee.contacted.connect(bl)
	var stamina_low := 1.0e9
	var ticks := int(DUEL_S * Engine.physics_ticks_per_second)
	for i in ticks:
		await physics_frame
		stamina_low = minf(stamina_low, minf(p.grip.stamina, q.grip.stamina))
		# (they drift in the fight: kept within reach of each other)
		if i % 240 == 0:
			var mid := (p.global_position + q.global_position) * 0.5
			var d := (q.global_position - p.global_position)
			d.y = 0.0
			if d.length() > 1.6 or d.length() < 0.7:
				p.global_position = SPOT + Vector3(0, 0.05, 0)
				var at := SPOT + Vector3(0.0, 0.0, -1.1)
				q.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.05, at.z)
	ai_p.enabled = false
	ai_q.enabled = false
	p.controls.release_all()
	q.controls.release_all()
	await _settle()
	p.hurt.disconnect(hp)
	q.hurt.disconnect(hq)
	print("DUEL free %.0f s: attacks %d / %d, feints %d / %d, saw %d / %d, countered %d / %d, blows landed on p %d, on q %d, blocks %d, stamina low %.0f" % [
			DUEL_S, ai_p.attacks, ai_q.attacks, ai_p.feints, ai_q.feints, ai_p.seen, ai_q.seen, ai_p.countered, ai_q.countered,
			hits.p, hits.q, blocks[0], stamina_low])
	_expect(ai_p.attacks >= 8 and ai_q.attacks >= 8, "free: both attack through the fight (%d / %d)" % [ai_p.attacks, ai_q.attacks])
	_expect(ai_p.seen > 0 and ai_q.seen > 0, "free: each sees the other's attacks begin (%d / %d)" % [ai_p.seen, ai_q.seen])
	_expect(int(hits.p) > 0 and int(hits.q) > 0, "free: blows land both ways (%d / %d)" % [hits.p, hits.q])
	_expect(blocks[0] > 0, "free: some are blocked (%d)" % blocks[0])
	_expect(stamina_low < 90.0, "free: stamina spent in the fight (low %.0f)" % stamina_low)
	_expect(_still(), "free: neither left stuck in a swing or a flinch")
	p.controls = PlayerControls.new()


static func _met(c: Dictionary) -> String:
	if c.is_empty():
		return "nothing"
	return String(c.get("surface", "-")) + (" through" if c.get("through", false) else "") + (" core" if c.get("core", false) else "") \
			+ (" blocked" if c.has("blocked") else "") + (" glancing" if c.has("glance") else "")
