extends SceneTree
## The Geyser has a way, as the Column (BendVariants; the owner, 2026-10-12: "do the same for geyser allow water from the side
## of the ring or the vents to shoot and attac ksomeone side ways"), in a 1v1 Lives ring, water against a held bot, the
## crosshair on its chest:
##   the pick   the Geyser readied: the wheel steps up > throw right > throw left > from the water > up; key 2 held and A: throw
##              left, D: throw right, S: from the water, W: up; the strip's name says it ("Geyser · from the water")
##   the casts  up: thrown up (wave/spout); throw right: to the caster's right, low (wave/spout.lean); throw left: to his left;
##              from the water, the bot 2.5 m in from a grate: a jet out of the grate throws him away from it, near flat
##              (wave/spout.side); the bot 1.5 m in from the deck's long lip, every grate farther: the jet out of the tank
##              under the lip throws him in across the deck
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_spout_way.gd
## The last line "SPOUT WAY PASSED (<n> checks)" or "SPOUT WAY FAILED (<f> of <n>)".

const LIMIT_S := 160.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var foe: NpcFighter
var rm: RingMode
var pc: BendCaster
var c: SwayCaster
var home := Vector3.ZERO
var way := Vector3(0, 0, 1)
var pitch_sign := 1.0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("SPOUT WAY FAILED (watchdog)")
		quit(2))
	MatchSetup.set_match()
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "water"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 600.0
	MatchSetup.set_controls("full")
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if fails.is_empty() and checks > 0:
		print("SPOUT WAY PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("SPOUT WAY FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _aim() -> void:
	if foe == null or not is_instance_valid(foe) or p == null or p.camera == null:
		return
	var d := (NpcSenses.chest_of(foe) - p.camera.global_position).normalized()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


## The bot at `at`, the player 5 m off along the deck (toward the middle), both still, the bot at 30%.
func _place(at: Vector3) -> void:
	for z in get_nodes_in_group(BendZone.GROUP):
		(z as BendZone).end("test")
	var ar := rm.ring
	var back := -ar.axis() if (at - ar.center()).dot(ar.axis()) > 0.0 else ar.axis()
	foe.global_position = at
	p.global_position = at + back * 5.0
	for b: CharacterBody3D in [p, foe]:
		b.velocity = Vector3.ZERO
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	RingRules.current().reset_pct(foe, 30.0)
	await _ticks(15)


## The Geyser cast at the bot (the game's own cast); {tag, moved (the bot's flat move 0.7 s on), rose}.
func _geyser() -> Dictionary:
	var f0 := foe.global_position
	BendR3.hits_log.clear()
	BendEffects.apply(pc, "wave", "spout", (SwayMoves.move("wave").bend as Dictionary).spout)
	var got := await _until(func() -> bool: return not BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == foe).is_empty(), 2.0)
	var top := foe.global_position.y
	for i in 42:
		await physics_frame
		top = maxf(top, foe.global_position.y)
	var mine := BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == foe)
	var e: Dictionary = mine[-1] if got else {}
	var mv := foe.global_position - f0
	return {"tag": String(e.get("tag", "")), "moved": Vector3(mv.x, 0.0, mv.z), "rose": top - f0.y}


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	rm = RingMode.find(self)
	foe = rm.foe as NpcFighter if rm != null else null
	_expect(p != null and foe != null, "the ring, the player and the bot")
	if p == null or foe == null:
		return _end()
	p.ignore_mouse_capture = true
	pc = BendCaster.of(p)
	c = SwayCaster.of(p)
	await _until(func() -> bool: return rm.phase == "FIGHT" and p.hotbar.spell != "", 12.0)
	foe.held = true
	RingRules.current().stale_off = true
	await _secs(3.5)
	home = foe.global_position
	home.y = p.global_position.y
	p.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-p.camera.global_basis.z).y > 0.0 else -1.0
	physics_frame.connect(_aim)
	var hb := p.hotbar
	var ar := rm.ring
	# ---- the pick
	hb.ready_move(1, "wave", "spout")
	await _ticks(3)
	BendVariants.set_to(p, "wave", "spout", "up")
	var seen: Array = []
	for i in 4:
		hb.wheel(1)
		seen.append(BendVariants.of(p, "wave", "spout"))
	_expect(hb.spell == "wave" and c.mode_of("wave") == "spout" and seen == ["right", "left", "water", "up"],
			"the wheel steps the Geyser's way: %s" % str(seen))
	var ctl := PlayerControls.new(false)
	var was: PlayerControls = p.controls
	p.controls = ctl
	var held: Array = []
	for a: StringName in [&"move_left", &"move_right", &"move_back", &"move_forward"]:
		ctl.set_held(&"weapon_2", true)
		await _ticks(2)
		ctl.set_held(a, true)
		await _ticks(2)
		held.append(BendVariants.of(p, "wave", "spout"))
		ctl.release_all()
		await _ticks(2)
	p.controls = was
	_expect(held == ["left", "right", "water", "up"], "key 2 held and A, D, S, W: %s" % str(held))
	BendVariants.set_to(p, "wave", "spout", "water")
	hb.ready_move(1, "wave", "spout")
	var strip: Variant = p.hud.get(&"bend_strip") if p.hud != null else null
	var col: Dictionary = (strip as BendStrip).column(1) if strip is BendStrip else {}
	_expect(String(col.get("label", "")).contains("from the water"), "the strip says it ('%s')" % col.get("label", ""))
	# ---- the casts: up, right, left, the bot in the deck's middle line
	var mid := ar.center()
	mid.y = home.y
	var spot := mid + ar.axis() * 4.5
	var right := Vector3.ZERO
	var res := {}
	for v: String in ["up", "right", "left"]:
		await _place(spot)
		var fw := spot - p.global_position
		fw.y = 0.0
		right = fw.normalized().cross(Vector3.UP).normalized()      # (the player faces the bot: his right)
		BendVariants.set_to(p, "wave", "spout", v)
		res[v] = await _geyser()
	var up_r: Dictionary = res.up
	var r_r: Dictionary = res.right
	var l_r: Dictionary = res.left
	_expect(String(up_r.tag) == "wave/spout" and float(up_r.rose) > 1.0 and Vector3(up_r.moved).length() < 1.0,
			"up: thrown up (%s, rose %.1f m, moved %.1f m)" % [up_r.tag, up_r.rose, Vector3(up_r.moved).length()])
	_expect(String(r_r.tag) == "wave/spout.lean" and Vector3(r_r.moved).dot(right) > 1.0,
			"throw right: thrown to his right (%s, %.1f m right)" % [r_r.tag, Vector3(r_r.moved).dot(right)])
	_expect(String(l_r.tag) == "wave/spout.lean" and Vector3(l_r.moved).dot(right) < -1.0,
			"throw left: thrown to his left (%s, %.1f m right)" % [l_r.tag, Vector3(l_r.moved).dot(right)])
	# ---- from the water: a grate (the bot 2.5 m in from it, toward the deck's middle line)
	BendVariants.set_to(p, "wave", "spout", "water")
	var grates := ar.pools()
	_expect(not grates.is_empty(), "the ring has grates (%d)" % grates.size())
	if grates.is_empty():
		return _end()
	var g: Node3D = grates[0]
	var gp := g.global_position
	var lat := ar.axis().cross(Vector3.UP).normalized()
	var inward := -lat if (gp - ar.center()).dot(lat) > 0.0 else lat
	var at_g := Vector3(gp.x, home.y, gp.z) + inward * 2.5
	await _place(at_g)
	var gr: Dictionary = await _geyser()
	var away_g := Vector3(at_g.x - gp.x, 0.0, at_g.z - gp.z).normalized()
	_expect(String(gr.tag) == "wave/spout.side" and Vector3(gr.moved).dot(away_g) > 1.5 and float(gr.rose) < 1.6,
			"from a grate 2.5 m off: thrown away from it, near flat (%s, %.1f m away, rose %.1f m)" % [gr.tag, Vector3(gr.moved).dot(away_g), gr.rose])
	# ---- from the water: the deck's long lip (the bot 1.5 m in from it, where every grate is farther)
	var at_l := Vector3.INF
	var lip_n := Vector3.ZERO
	for i in 41:
		var along := -10.0 + 0.5 * i
		var cand := mid + ar.axis() * along - inward * (ar.half_w() - 1.5)
		var lip := ar.nearest_lip(cand)
		var near_g := INF
		for gg: Node3D in grates:
			near_g = minf(near_g, Vector2(gg.global_position.x - cand.x, gg.global_position.z - cand.z).length())
		if near_g > 2.4 and Vector2((lip.point as Vector3).x - cand.x, (lip.point as Vector3).z - cand.z).length() < 1.6:
			at_l = cand
			lip_n = lip.normal
			break
	_expect(at_l != Vector3.INF, "a spot 1.5 m in from the long lip, every grate farther (over 2.4 m)")
	if at_l == Vector3.INF:
		return _end()
	await _place(at_l)
	var lr: Dictionary = await _geyser()
	_expect(String(lr.tag) == "wave/spout.side" and Vector3(lr.moved).dot(-lip_n) > 1.5 and float(lr.rose) < 1.6,
			"from the lip: out of the tank, thrown in across the deck (%s, %.1f m in, rose %.1f m)" % [lr.tag, Vector3(lr.moved).dot(-lip_n), lr.rose])
	_end()
