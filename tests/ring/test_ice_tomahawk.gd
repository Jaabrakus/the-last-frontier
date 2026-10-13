extends SceneTree
## The Ice Tomahawk on water's key 3 (the owner, 2026-10-12: "then we can have icy tomahawk?", "is a Aoe spell? that puts water
## on the ground", picked: a water puddle, chop plus splash), headless, in a 1v1 % ring (water against a held fire bot):
##   the data     water's key 3 (Bending.key3) is the Ice Tomahawk, the other elements' none; our own sidearm throw (each hand)
##                with the floating tomahawk held; its chop and its splash counted (ice_axe/axe, ice_axe/axe.splash)
##   the keys     3 readies it (the hotbar's spell and the caster's); the strip's 3 shows it, a Throw; Shift + a direction still
##                water's movement spell (SwayCaster.last_key3 "dash"), the tomahawk kept on 3
##   the float    its lock floats an ice tomahawk (BendFloatAxe) over the throwing hand
##   the throw    a spinning ice tomahawk (its body turning in flight) from where it floated; on the foe the chop, he alone hit
##                (the splash spares the one it chopped); on the deck by him the splash, pushing him away from where it landed;
##                each leaves a puddle of the caster's where it landed (BendZone puddle)
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ice_tomahawk.gd
## Ends with "ICE TOMAHAWK PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "ICE TOMAHAWK"
const LIMIT_S := 180.0
const ID := "ice_axe"
const MODE := "axe"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var foe: NpcFighter
var mode: RingMode
var sc: SwayCaster
var pc: BendCaster
var home := Vector3.ZERO


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(2026)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	BendLooks.build_headless = false
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
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


func _spec() -> Dictionary:
	return ((SwayMoves.move(ID).get("bend", {}) as Dictionary).get(MODE, {}) as Dictionary).duplicate(true)


## Both on the deck's middle line `d` m apart, still, the player facing the foe.
func _face_off(d := 8.0) -> void:
	var way := Vector3(0, 0, 1)
	foe.global_position = home + way * d * 0.5
	player.global_position = home - way * d * 0.5
	for b: CharacterBody3D in [player, foe]:
		b.velocity = Vector3.ZERO
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
			kn.stun_t = 0.0
	player.yaw = atan2(-way.x, -way.z)
	player.pitch = 0.0
	RingRules.current().reset_pct(foe, 0.0)
	await _ticks(3)


func _puddles() -> Dictionary:
	var out := {}
	for z in get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "puddle" and not bz.is_queued_for_deletion():
			out[bz.get_instance_id()] = bz
	return out


func _new_puddle(before: Dictionary) -> BendZone:
	for z: BendZone in _puddles().values():
		if not before.has(z.get_instance_id()) and z.owner_node == player:
			return z
	return null


## The player's aim at `point` (BendEffects.aim's, the crosshair there; no float to throw from).
func _aim_at(point: Vector3) -> Dictionary:
	player.remove_meta(BendLooks.FLOAT_META)
	var flat := point - player.global_position
	flat.y = 0.0
	flat = flat.normalized()
	var from := pc.launch_point(flat)
	return {"from": from, "dir": (point - from).normalized(), "flat": flat, "point": point, "target": null}


## The tomahawk thrown at `point` as the game's cast throws it (its hit info: BendEffects.apply's, BendR3.cur).
func _throw(point: Vector3) -> BendBolt:
	var spec := _spec()
	var info := BendR3.info_for(pc, ID, MODE, false, spec)
	spec["_info"] = info
	var keep := BendR3.cur
	BendR3.cur = info
	var b := BendThrow.one(pc, _aim_at(point), spec)
	BendR3.cur = keep
	return b


func _hits_on(who: Node, tag: String) -> Array:
	return BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == who and String(e.tag) == tag)


func _run() -> void:
	BendLooks.build_headless = true
	# ---------------------------------------------------------------- the data (no scene)
	var k3 := Bending.key3("water")
	_expect(k3.size() == 1 and String(Bending.first_of(k3).get("id", "")) == ID and String(Bending.first_of(k3).get("mode", "")) == MODE,
			"water's key 3 is the Ice Tomahawk (%s)" % str(k3))
	var others := []
	for el: String in ["earth", "fire", "air"]:
		if not Bending.key3(el).is_empty():
			others.append(el)
	_expect(others.is_empty(), "the other elements have no key-3 move of their own yet (%s)" % str(others))
	var pk := BendPoses.pick(ID, MODE, "water")
	_expect(String(pk.clip) == "own-bend-throw-sidearm" and String(BendPoses._as_pose(pk.get("alt", "")).get("clip", "")) == "own-bend-throw-sidearm-l"
			and String(pk.get("held", "")) == "ice_axe", "our own sidearm throw, each hand, the tomahawk held (%s)" % pk.clip)
	var spec := _spec()
	var sp: Dictionary = spec.get("splash", {})
	_expect(String(spec.get("shape", "")) == "tomahawk" and String(spec.get("flight", "")) == "spinning" and bool(spec.get("float_from", false))
			and float(sp.get("radius_m", 0.0)) > 1.0 and sp.get("puddle") is Dictionary,
			"a spinning ice tomahawk thrown from its float, a %.1f m splash and a puddle" % float(sp.get("radius_m", 0.0)))
	_expect(not RingRules.class_of("ice_axe/axe").is_empty() and not RingRules.class_of("ice_axe/axe.splash").is_empty(),
			"its chop and its splash counted in the ring's %")

	# ---------------------------------------------------------------- the ring
	MatchSetup.format = "1v1"
	MatchSetup.incoming = true
	MatchSetup.element = "water"
	MatchSetup.foes = ["fire"]
	MatchSetup.mates = []
	MatchSetup.round_s = 600.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(mode != null and player != null and mode.foe != null and RingRules.stock_on(), "a 1v1 % ring: the player (water) and a fire bot")
	if mode == null or player == null or mode.foe == null:
		return _end()
	foe = mode.foe as NpcFighter
	player.ignore_mouse_capture = true
	RingRules.current().stale_off = true
	sc = SwayCaster.of(player)
	pc = BendCaster.of(player)
	var laid := await _until(func() -> bool: return player.arena_element == "water" and player.hotbar.spell != "", 8.0)
	await _until(func() -> bool: return mode.phase == "FIGHT" and sc.enabled, 10.0)
	_expect(laid and mode.phase == "FIGHT", "water's keys laid, the fight on")
	foe.held = true
	await _secs(0.5)
	home = foe.global_position
	home.y = player.global_position.y

	# ---- the keys
	player.hotbar.select(2)
	await _ticks(3)
	_expect(player.hotbar.spell == ID and player.hotbar._caster_spell() == ID,
			"3 readies the Ice Tomahawk (the hotbar's %s, the caster's %s)" % [player.hotbar.spell, player.hotbar._caster_spell()])
	var strip: Variant = player.hud.get(&"bend_strip") if player.hud != null else null
	var col: Dictionary = (strip as BendStrip).column(2) if strip is BendStrip else {}
	_expect(String(col.get("id", "")) == ID and String(col.get("head", "")).begins_with("3") and String(col.get("head", "")).ends_with("Throw"),
			"the strip's 3: the tomahawk, a Throw (%s, %s)" % [col.get("head", ""), col.get("label", "")])
	await _face_off(6.0)
	await _until(func() -> bool: return sc.state == SwayCaster.State.IDLE and player.is_on_floor(), 3.0)
	var ctl := PlayerControls.new(false)
	var was: PlayerControls = player.controls
	player.controls = ctl
	sc.last_key3 = ""
	var x0 := player.global_position
	ctl.set_held(&"sprint", true)
	await _ticks(2)
	ctl.set_held(&"move_left", true)
	await _ticks(4)
	var said := sc.last_key3
	await _ticks(30)
	ctl.release_all()
	var moved := Vector2(player.global_position.x - x0.x, player.global_position.z - x0.z).length()
	_expect(said == "dash" and moved > 1.0, "Shift + A: still water's movement spell (%s, %.1f m)" % [said, moved])
	_expect(player.hotbar.spell == ID, "the tomahawk still on 3 after it (%s)" % player.hotbar.spell)
	player.controls = was
	await _secs(1.0)

	# ---- the float
	sc._pin_id = ID
	sc._pin_mode = MODE
	sc._pinning = true
	sc._lock_looks(ID)
	var ax: Node3D = sc.charge as Node3D
	_expect(ax != null and ax.name.begins_with("BendFloatAxe"), "its lock floats an ice tomahawk (%s)" % (ax.name if ax != null else "none"))
	if ax != null:
		for i in 30:
			ax.set(&"level", clampf(float(i + 1) / 20.0, 0.0, 1.0))
			await process_frame
		var hb := String(sc.pose.pick.get("hand", "r_palm")) if sc.pose != null else "r_palm"
		var sk := player.skeleton
		var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(hb)).origin
		_expect(ax.visible and ax.global_position.y > hand.y + 0.1 and ax.global_position.y < hand.y + 0.6,
				"over the throwing hand (%.2f m above it)" % (ax.global_position.y - hand.y))
	sc._end_charge()
	sc._pinning = false
	await _ticks(10)

	# ---- the throw: on the foe, the chop
	await _face_off(8.0)
	BendR3.hits_log.clear()
	var before := _puddles()
	var bolt := _throw(foe.global_position + Vector3.UP * 1.1)
	_expect(bolt != null and bolt.shape == "tomahawk" and bolt.kind == "ice" and bolt.flight == "spinning" and not bolt.splash.is_empty(),
			"a spinning ice tomahawk thrown")
	if bolt != null and bolt.spin != null:
		var b0 := bolt.spin.basis
		await _ticks(3)
		_expect(is_instance_valid(bolt) and not bolt.spin.basis.is_equal_approx(b0), "it turns end over end in flight")
	await _secs(1.0)
	var chop := _hits_on(foe, "ice_axe/axe")
	var spl := _hits_on(foe, "ice_axe/axe.splash")
	var pct := RingRules.current().pct_of(foe)
	_expect(chop.size() == 1 and spl.is_empty() and pct > 5.0, "on him: the chop, he alone (%d chop, %d splash, +%.1f%%)" % [chop.size(), spl.size(), pct])
	var pd := _new_puddle(before)
	_expect(pd != null and Vector2(pd.global_position.x - foe.global_position.x, pd.global_position.z - foe.global_position.z).length() < 2.5,
			"a puddle of his where it landed")
	if pd != null:
		pd.end()

	# ---- the throw: on the deck by him, the splash
	await _face_off(8.0)
	BendR3.hits_log.clear()
	before = _puddles()
	var ground := foe.global_position - Vector3(0, 0, 1) * 1.0 + Vector3(0.6, 0.0, 0.0)
	var land := FormEffects.ground_at(foe, ground)
	var f0 := foe.global_position
	_throw(land)
	await _secs(1.0)
	chop = _hits_on(foe, "ice_axe/axe")
	spl = _hits_on(foe, "ice_axe/axe.splash")
	pct = RingRules.current().pct_of(foe)
	var away := Vector2(foe.global_position.x - land.x, foe.global_position.z - land.z).length() - Vector2(f0.x - land.x, f0.z - land.z).length()
	_expect(chop.is_empty() and spl.size() == 1 and pct > 1.0, "by him: the splash (%d chop, %d splash, +%.1f%%)" % [chop.size(), spl.size(), pct])
	_expect(away > 0.2, "it pushes him away from where it landed (%.2f m further)" % away)
	pd = _new_puddle(before)
	_expect(pd != null and Vector2(pd.global_position.x - land.x, pd.global_position.z - land.z).length() < 1.5, "a puddle of his there too")
	_end()
