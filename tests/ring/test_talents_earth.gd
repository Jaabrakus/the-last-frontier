extends SceneTree
## Earth's talents (pass 1; the owner, 2026-10-11: "we need to make sure all the talents work and they work in game right") in a
## real % ring match (earth against an earth bot), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_talents_earth.gd
## Each talent worn by one fighter alone, played through the game's own code (its casts, hits, zones and walls), and the same
## worn by nobody (Classic): what the node text says for the wearer, nothing for anyone else:
##   Thick Wall        an Earth Wall raised and shot down: 5 hits and 2.5 m wide (Classic 4 hits, 3 m); live in the json
## Last line "TALENTS EARTH PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "TALENTS EARTH"
const LIMIT_S := 600.0
## A water bolt that wears an earth wall one hit (BendBolt.WEAR) and counts (FormRaised.hit_min 10).
const SHOT := {"kind": "water", "mps": 30.0, "damage": 20.0, "knock_mps": 0.0, "up_mps": 0.0, "radius_m": 0.15, "range_m": 20.0}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var bot: NpcFighter
var mode: RingMode
var rules: RingRules
var pc: BendCaster
var sc: SwayCaster


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1760)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	for b: Node in [player, bot]:
		if b != null and is_instance_valid(b):
			BendLoadout.clear(b)
	BendLoadout.config_override = {}
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


## Game seconds of physics frames.
func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _near(a: float, b: float, tol := 0.03) -> bool:
	return absf(a - b) <= tol


## `body` wears `id` alone as an earth caster ("" nothing: Classic).
func _wear(body: Node, id: String) -> void:
	BendLoadout.clear(body)
	if id != "":
		var ov := BendLoadout.wear(body, [id], "", "earth")
		if not (ov.ids as Array).has(id):
			_expect(false, "%s worn (refused: %s)" % [id, str(ov.refused)])


func _run() -> void:
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"]
	MatchSetup.round_s = 900.0
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
	_expect(mode != null and player != null and mode.foe != null and RingRules.stock_on(), "the % ring with a match and an earth bot")
	if mode == null or player == null or mode.foe == null:
		return _end()
	bot = mode.foe
	rules = RingRules.current()
	rules.stale_off = true
	pc = BendCaster.of(player)
	sc = SwayCaster.of(player)
	await _secs(4.5)                                 # (past the countdown and the start's safety)
	bot.held = true                                  # (the bot stands where it is: every hit below on a still body)
	await _secs(0.25)
	await _thick_wall()
	_end()


# ---------------------------------------------------------------- Thick Wall
## An Earth Wall raised by the player (FormEffects.earth_wall, the builder the cast calls) and shot by the bot's water bolts
## until it crumbles: how many shots it takes, how wide it stood.
func _wall_shots(id: String) -> Array:
	_wear(player, id)
	var way := (bot.global_position - player.global_position)
	way.y = 0.0
	way = way.normalized()
	var at := player.global_position + way * 3.0
	var r := FormEffects.earth_wall(pc, at, SwayMoves.move("earth_wall"), "earth")
	if r == null:
		return [-1, -1.0, -1]
	await _secs(1.0)                                 # (risen)
	var hits_max := r.hits_max
	var width := r.size.x
	var shots := 0
	var mid := r.global_position + Vector3.UP * 1.0
	while is_instance_valid(r) and r.state != FormRaised.State.CRUMBLING and shots < 10:
		BendBolt.launch(bot, mid + way * 6.0, -way, SHOT)
		shots += 1
		await _secs(0.4)
	var down := not is_instance_valid(r) or r.state == FormRaised.State.CRUMBLING
	await _secs(1.6)
	return [shots if down else -1, width, hits_max]


func _thick_wall() -> void:
	_expect(BendLoadout.why_not("earth.wall.thick") == "", "Thick Wall is live in the json (%s)" % BendLoadout.why_not("earth.wall.thick"))
	var c := await _wall_shots("")
	var t := await _wall_shots("earth.wall.thick")
	_expect(int(c[0]) == 4 and int(t[0]) == 5, "Thick Wall: the wearer's wall falls to the 5th shot (Classic the 4th: %d, %d)" % [t[0], c[0]])
	_expect(_near(float(c[1]), 3.0) and _near(float(t[1]), 2.5), "Thick Wall: it stands 2.5 m wide (Classic 3 m: %.2f, %.2f)" % [t[1], c[1]])
	# the bot's walls are its own numbers while the player wears it
	_wear(player, "earth.wall.thick")
	var bw := BendLoadout.wall_numbers(bot, "wall", SwayMoves.move("earth_wall").wall, "earth")
	_expect(int(bw.hits) == 4 and _near(float(bw.width_m), 3.0), "Thick Wall: a wall the bot raises meanwhile is Classic's (%d hits, %.1f m)" % [bw.hits, bw.width_m])
	_wear(player, "")
