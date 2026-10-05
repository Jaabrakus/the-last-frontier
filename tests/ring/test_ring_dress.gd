extends SceneTree
## The ring's look wired into the match, and the walls cap (wave 3's integration; the owner, 2026-10-05: the dressed arena
## "looks nice", walls are spammable: cap them as data), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_dress.gd -- mode=ring element=earth foe=water light=golden
##   setup    MatchSetup takes light=golden (an unknown light leaves it); save/load keeps it
##   look     the level stands dressed (RingLevel.dressing, RingDressing.find_in) in the setup's light, RingLook on the same
##            preset; the loading hold is let go once the effects' warm-up is done (headless: at once)
##   sides    each round the dressing's sides follow the ends: round 1 the player's element at end 0, round 2 (the ends
##            swapped) at end 1
##   cap      rules.json max_walls 2: the player's third earth wall crumbles his oldest ("capped"), an ice wall counts with
##            them (the next oldest goes), the foe's walls are his own count (the player's stand)
## The last line: "RING DRESS TEST PASSED" or "RING DRESS TEST FAILED".

const LIMIT_S := 150.0

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var capped: Array[FormRaised] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("RING DRESS TEST FAILED (watchdog)")
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	GameSettings.path = "user://test_ring_dress.cfg"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	_expect(lvl != null and lvl.ring != null, "the ring's level loads")
	if lvl == null:
		return _end()
	# --- setup
	_expect(MatchSetup.light == "golden", "MatchSetup took light=golden (%s)" % MatchSetup.light)
	MatchSetup.parse(PackedStringArray(["light=dusk"]))
	_expect(MatchSetup.light == "golden", "an unknown light leaves it")
	MatchSetup.save()
	MatchSetup.light = "noon"
	MatchSetup.load()
	_expect(MatchSetup.light == "golden", "save / load keep the light")
	# --- look
	_expect(lvl.dressing != null and RingDressing.find_in(lvl) == lvl.dressing, "the ring stands dressed (RingDressing)")
	_expect(lvl.dressing != null and lvl.dressing.mood == "golden", "the dressing in the setup's light (%s)"
			% (lvl.dressing.mood if lvl.dressing else "none"))
	_expect(lvl.look != null and lvl.look.preset == "golden", "RingLook on the setup's light")
	_expect(not bool(lvl.get_meta(&"loading_hold", true)), "the loading hold let go after the warm-up")
	# --- sides
	var m := RingMode.find(self)
	_expect(m != null, "the match is on (mode=ring)")
	if m == null:
		return _end()
	await _ticks(5)
	_expect(m.player_end == 0 and lvl.dressing.side_elements == ["earth", "water"],
			"round 1: the player's earth at end 0, water at end 1 (%s)" % [lvl.dressing.side_elements])
	m.next_round()
	await _ticks(2)
	_expect(m.player_end == 1 and lvl.dressing.side_elements == ["water", "earth"],
			"round 2, the ends swapped: water at end 0, earth at end 1 (%s)" % [lvl.dressing.side_elements])
	m.score = Vector2i(1, 0)
	m.next_round()
	await _ticks(2)
	_expect(lvl.dressing.side_elements == ["earth", "water"], "round 3: back again")
	# --- the walls cap
	_expect(int(RingRules.num("max_walls", 0.0)) == 2 and FormRaised.wall_cap(self) == 2, "rules.json max_walls 2 in the ring")
	var p := lvl.player
	RingLevel.place(p, Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), Vector3(-6.0, 0.0, 0.0)))
	await _ticks(10)
	var d := SwayMoves.move("earth_wall")
	var walls: Array[FormRaised] = []
	for z: float in [-3.0, 0.0]:
		var w := FormEffects.earth_wall(p, Vector3(-3.0, 0.0, z), d)
		_watch(w)
		walls.append(w)
		await _ticks(3)
	_expect(walls[0] != null and walls[1] != null and capped.is_empty(), "two walls stand, none capped")
	var w3 := FormEffects.earth_wall(p, Vector3(-3.0, 0.0, 3.0), d)
	_watch(w3)
	await _ticks(2)
	_expect(capped.size() == 1 and capped[0] == walls[0], "the third wall crumbles the oldest (%d capped)" % capped.size())
	_expect(walls[1].state != FormRaised.State.CRUMBLING and w3 != null and w3.state != FormRaised.State.CRUMBLING,
			"the other two stand")
	var iw := BendEffects.ice_wall(p, Vector3.RIGHT)
	_watch(iw)
	await _ticks(2)
	_expect(iw != null and iw.has_meta(&"bend_ice") and capped.size() == 2 and capped[1] == walls[1],
			"an ice wall counts with them: the next oldest goes (%d capped)" % capped.size())
	# the foe's own count
	var foe := m.foe
	_expect(foe != null, "the foe stands")
	if foe != null:
		for z: float in [-2.0, 2.0]:
			var fw := FormEffects.earth_wall(foe, foe.global_position + Vector3(-3.0, 0.0, z), d)
			_watch(fw)
			await _ticks(2)
		_expect(capped.size() == 2, "the foe's two walls cap none of the player's (%d capped)" % capped.size())
	_end()


func _watch(w: FormRaised) -> void:
	if w != null:
		w.crumbled.connect(func(r: FormRaised, why: String) -> void:
			if why == "capped":
				capped.append(r))


func _end() -> void:
	print("%d checks, %d failed" % [checks, fails.size()])
	print("RING DRESS TEST " + ("PASSED" if fails.is_empty() else "FAILED"))
	quit(0 if fails.is_empty() else 1)
