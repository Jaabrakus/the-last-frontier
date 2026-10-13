extends SceneTree
## Earth's thrown stones in the ring (the owner, 2026-10-10: "the boulders and rocks they need to explode" -> shatter on
## impact; "similar to rock throws for boulder and spike" -> Spike and Boulder grow when held), in a practice ring (earth
## against an earth dummy that stands):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_stone_shatter.gd -- mode=ring practice=stand element=earth foe=earth
##   grow        a raised Spike grown (FormEffects.grow_raised): its size x stone_form.grow.spike.scale, its flight the grown
##               hurl's (slower), marked grown; a Boulder the same with its own scale
##   the deck    a Spike thrown at the deck bursts there: its stone gone within the flight, none left lying (FormStone group)
##   a fighter   a Boulder thrown at the dummy strikes it (the hit counted) and bursts on it: gone, not rolling on
##   the tags    a grown cast's hit tag ends ".grown" and rules.json has its class (a bigger launch than the plain one)
##   SwayCaster  grows("stone_form") is true for both modes (the ▲ on the bar)
## Last line "STONE SHATTER PASSED" or "STONE SHATTER FAILED".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var mode: RingMode


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("STONE SHATTER PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("STONE SHATTER FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(p != null and mode != null and mode.foe != null, "a practice ring with an earth dummy")
	if p == null or mode == null or mode.foe == null:
		return _end()
	await _frames(90)
	var sc := SwayCaster.of(p)
	_expect(sc != null and sc.grows("stone_form") and _grows("cannonball"), "SwayCaster.grows: Spike (%s) and Boulder grow when held"
			% sc.mode_of("stone_form") if sc != null else "no caster")
	await _grow_check("spike")
	await _grow_check("cannonball")
	await _deck_burst()
	await _fighter_burst()
	var c1: Dictionary = RingRules.class_of("stone_form/spike.grown")
	var c0: Dictionary = RingRules.class_of("stone_form/spike")
	var b1: Dictionary = RingRules.class_of("stone_form/cannonball.grown")
	var b0: Dictionary = RingRules.class_of("stone_form/cannonball")
	_expect(not c1.is_empty() and not b1.is_empty() and float(c1.d) > float(c0.d) and float(b1.d) > float(b0.d)
			and float(c1.base) > float(c0.base) and float(b1.base) > float(b0.base),
			"the grown classes: Spike d %.1f > %.1f, Boulder d %.1f > %.1f (bigger launches)" % [float(c1.get("d", 0)), float(c0.get("d", 0)),
			float(b1.get("d", 0)), float(b0.get("d", 0))])
	_end()


func _grows(md: String) -> bool:
	var g: Variant = SwayMoves.move("stone_form").get("grow", {})
	return g is Dictionary and (g as Dictionary).get(md) is Dictionary


## A stone of `md` raised before the player and grown at once.
func _grow_check(md: String) -> void:
	var th := FormEffects.raise_stone(p, "stone_form", md) as FormEffects.Throw
	await _frames(20)
	if th == null or th.stone == null:
		_expect(false, "%s raised" % md)
		return
	var r0 := th.stone.radius
	var mps0: float = float((th.lift._hurl_d().get("mps", [0.0]) as Array)[-1])
	FormEffects.grow_raised(th, "stone_form", md, true)
	var g: Dictionary = (SwayMoves.move("stone_form").grow as Dictionary)[md]
	var mps1: float = float((th.lift._hurl_d().get("mps", [0.0]) as Array)[-1])
	_expect(absf(th.stone.radius - r0 * float(g.scale)) < 0.01 and th.stone.has_meta(FormEffects.GROWN_META)
			and absf(th.stone.mesh_instance.scale.x - float(g.scale)) < 0.01 and mps1 < mps0,
			"%s grown: radius %.2f -> %.2f (x%.2f), its look scaled, its flight %.0f -> %.0f m/s" % [md, r0, th.stone.radius,
			float(g.scale), mps0, mps1])
	FormEffects.drop_raised(th)
	await _frames(5)
	_clear_stones()


func _stones() -> Array:
	var out: Array = []
	for n in get_nodes_in_group(FormStone.GROUP):
		if n is FormStone and is_instance_valid(n) and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _clear_stones() -> void:
	for s in _stones():
		(s as Node).queue_free()


## A Spike hurled at the deck a few metres ahead: it bursts, nothing lies.
func _deck_burst() -> void:
	await _frames(5)
	_clear_stones()
	await _frames(2)
	var th := FormEffects.raise_stone(p, "stone_form", "spike") as FormEffects.Throw
	if th == null:
		_expect(false, "a Spike raised")
		return
	var st := th.stone
	var fwd := -p.global_basis.z
	th.fixed = p.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * 6.0 + Vector3.DOWN * 0.5
	await _frames(20)
	var landed := [false]
	th.lift.landed.connect(func(_at: Vector3) -> void: landed[0] = true)
	th.waiting = false
	for i in 120:
		await physics_frame
		if landed[0]:
			break
	await _frames(3)
	var gone := not is_instance_valid(st) or st.is_queued_for_deletion()
	_expect(landed[0] and gone, "a Spike at the deck bursts: landed %s, its stone gone %s (none left lying)" % [landed[0], gone])


## A Boulder hurled at the dummy: it strikes and bursts on it.
func _fighter_burst() -> void:
	var foe := mode.foe
	var away := (p.global_position - foe.global_position) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	var at := foe.global_position + away * 9.0
	at.y = p.global_position.y
	RingLevel.place(p, Transform3D(Basis.looking_at(-away, Vector3.UP), at))
	await _frames(10)
	var th := FormEffects.raise_stone(p, "stone_form", "cannonball") as FormEffects.Throw
	if th == null:
		_expect(false, "a Boulder raised")
		return
	var st := th.stone
	th.fixed = foe.global_position + Vector3.UP * 1.1
	await _frames(40)
	var struck := [0]
	var landed := [false]
	th.lift.struck.connect(func(_w: Node, _d: float) -> void: struck[0] += 1)
	th.lift.landed.connect(func(_at: Vector3) -> void: landed[0] = true)
	th.waiting = false
	for i in 120:
		await physics_frame
		if landed[0]:
			break
	await _frames(3)
	var gone := not is_instance_valid(st) or st.is_queued_for_deletion()
	_expect(struck[0] >= 1 and landed[0] and gone, "a Boulder at the dummy strikes it (%d) and bursts on it: its stone gone %s" % [struck[0], gone])
