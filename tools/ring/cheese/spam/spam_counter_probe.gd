extends SceneTree
## Cheese hunt, lens "spam", THE COUNTER SIDE: the same real match (scenes/ring.tscn, Lives rules), but here the PLAYER is the one
## spammed and tries the obvious answers through his own inputs, while the real bot (its body, its NpcBendCaster, its lock times
## from NpcBending.lock_for, its aim scatter) is made to cast one move again the moment it is free: NpcBending.begin(id, mode)
## each frame its hands are idle, it is on the deck, not in hitstun and within reach (out of reach its own mind walks it in).
## Nothing is injected: no %, no launch, no stun, no position.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/cheese/spam/spam_counter_probe.gd -- \
##       element=air foe=fire difficulty=hard spam=fire_jab/embers reach=4 defense=shield seconds=60 matches=2 seed=700
## defense (the player's answer, his own keys only):
##   none     stands, touches nothing
##   shield   holds E (let go a frame each 2.4 s: the held guard stands 2.5 s at most)
##   guard    taps E on the beat: every bolt that flies at him seen, E tapped react_s later (0.12-0.2 s, none missed)
##   dash     key 3 (the dodge / dash) with A held, again whenever his hands are free
##   back     walks straight away from the bot (S held), jumping when free
##   jab      mashes his own jab (LMB) back at it
##   expert   tools/ring/highlight_input.gd fighting back as normal
## Lines: COUNTER_GAME {json} per match, COUNTER_SUMMARY {json}, then COUNTER PROBE DONE.

const Expert := preload("res://tools/ring/highlight_input.gd")
const Sim := preload("res://tools/ring/newcomer_sim.gd")
const OWN_CFG := "user://cheese_spam_counter.cfg"


## The player's answer to the spam: newcomer_sim's hands and recovery, its deck behaviour replaced by one defence.
class Defender:
	extends "res://tools/ring/newcomer_sim.gd"
	var defense := "none"
	var foe_ref: Node3D
	var _shield_t := 0.0
	var presses := 0

	func _feet(foe: Node3D) -> void:
		for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			_hold(a, false)
		match defense:
			"back":
				var g := RingMoves.arena_geo(mode.ring)
				var xf: Transform3D = g.xf
				var local: Vector3 = xf.affine_inverse() * player.global_position
				var away: Vector3 = local - xf.affine_inverse() * foe.global_position
				away.y = 0.0
				var nxt := local + away.normalized() * 1.5
				var ok := absf(nxt.x) < float(g.hl) - 1.4 and absf(nxt.z) < float(g.hw) - 1.2
				# (walking away along the deck; at an end, sideways along it)
				if ok:
					_hold_world(xf.basis * away.normalized())
				else:
					_hold_world(xf.basis * Vector3(0.0, 0.0, -signf(local.z) if absf(local.z) > 0.5 else 1.0))
			"dash":
				_hold(&"move_left", true)

	func _hands(foe: Node3D) -> void:
		var caster := SwayCaster.of(player)
		var free := caster != null and caster.state == SwayCaster.State.IDLE and not mode.rules.stunned(player)
		match defense:
			"shield":
				_shield_t += 1.0 / Engine.physics_ticks_per_second
				if _shield_t >= 2.4:
					_shield_t = 0.0
					player.controls.set_held(InputSetup.GUARD_ACTION, false)
				else:
					if not player.controls.pressed(InputSetup.GUARD_ACTION):
						presses += 1
					player.controls.set_held(InputSetup.GUARD_ACTION, true)
			"dash":
				if free:
					_key(&"weapon_3")
					presses += 1
			"back":
				if free and player.is_on_floor():
					_tap(&"jump", 0.05)
					presses += 1
			"jab":
				if free and not player.controls.pressed(&"fire"):
					_tap(&"fire", 0.06)
					presses += 1

	func _guard(foe: Node3D) -> void:
		if defense == "guard":
			super._guard(foe)


var args := {}
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var sim: Node
var matches := 2
var seed0 := 700
var seconds := 60.0
var spam_id := "fire_jab"
var spam_mode := "embers"
var reach := 4.0
var defense := "none"
var g := {}
var all_games: Array = []
var _hooked_rules: RingRules = null
var _fight_t := 0.0
var _spam_node: Node = null
var bot_begins := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.contains("="):
			args[kv.get_slice("=", 0)] = kv.get_slice("=", 1)
	matches = int(args.get("matches", "2"))
	seed0 = int(args.get("seed", "700"))
	seconds = float(args.get("seconds", "60"))
	var sp := String(args.get("spam", "fire_jab/embers"))
	spam_id = sp.get_slice("/", 0)
	spam_mode = sp.get_slice("/", 1)
	reach = float(args.get("reach", "4"))
	defense = String(args.get("defense", "none"))
	create_timer(float(args.get("watchdog_s", "2400")), true, false, true).timeout.connect(func() -> void:
		print("COUNTER PROBE WATCHDOG")
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = "light"
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.format = "1v1"
	MatchSetup.element = String(args.get("element", "air"))
	MatchSetup.foes = [String(args.get("foe", "fire"))]
	MatchSetup.difficulty = String(args.get("difficulty", "hard"))
	MatchSetup.games_n = 1
	MatchSetup.light = "noon"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	if mode == null or player == null:
		print("COUNTER PROBE no ring")
		quit(1)
		return
	player.ignore_mouse_capture = true
	for i in 1200:
		if mode.phase == "FIGHT" and not lvl.get_meta("loading_hold", false):
			break
		await physics_frame
	for gi in matches:
		await _play(gi)
	_summary()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	print("COUNTER PROBE DONE")
	quit(0)


func _play(gi: int) -> void:
	if is_instance_valid(sim):
		sim._let_go()
		sim.queue_free()
		sim = null
	mode._seed = seed0 + gi * 101
	mode.restart()
	while mode.phase != "FIGHT":
		await physics_frame
	player.controls = PlayerControls.new(false)
	if defense == "expert":
		sim = Expert.new()
	else:
		sim = Defender.new()
		sim.defense = defense
	sim.setup(player, mode, "expert", seed0 + gi * 101 + 7)
	sim.m = (sim.m as Dictionary).duplicate(true)
	if defense == "guard":
		sim.m["react"] = [0.12, 0.2]
		sim.m["miss_share"] = 0.0
	lvl.add_child(sim)
	if _hooked_rules != mode.rules:
		_hooked_rules = mode.rules
		mode.rules.launched.connect(_on_launched)
		mode.rules.ko.connect(_on_ko)
		mode.rules.pct_dealt.connect(_on_pct)
	g = {"game": gi, "seed": seed0 + gi * 101, "defense": defense, "spam": spam_id + "/" + spam_mode, "element": mode.element,
			"foe": mode.foe_element, "fight_s": 0.0, "pct_taken": 0.0, "pct_dealt": 0.0, "falls_taken": 0, "falls_dealt": 0,
			"hits_taken": 0, "hits_by": {}, "stun_s": 0.0, "in_play_s": 0.0, "free_windows": [], "my_casts": 0,
			"bot_begins": 0, "dist_sum": 0.0, "dist_n": 0, "longest_stun_s": 0.0}
	bot_begins = 0
	var free_from := -1.0
	var stun_from := -1.0
	_fight_t = 0.0
	var c := SwayCaster.of(player)
	var casts0 := [0]
	var cb := func(_m: String, _md: String) -> void: casts0[0] += 1
	if c != null:
		c.cast_released.connect(cb)
	while mode.phase != "DONE" and _fight_t < seconds:
		await physics_frame
		if mode.phase != "FIGHT":
			continue
		var dt := 1.0 / Engine.physics_ticks_per_second
		_fight_t += dt
		_bot_spam()
		var r := mode.rules
		if r.is_away(player) or (mode.foe != null and r.is_away(mode.foe)):
			free_from = -1.0
			if stun_from >= 0.0:
				g.longest_stun_s = maxf(float(g.longest_stun_s), _fight_t - stun_from)
			stun_from = -1.0
			continue
		g.in_play_s = float(g.in_play_s) + dt
		if mode.foe != null and is_instance_valid(mode.foe):
			var dv := mode.foe.global_position - player.global_position
			g.dist_sum = float(g.dist_sum) + Vector2(dv.x, dv.z).length()
			g.dist_n = int(g.dist_n) + 1
		if r.stunned(player):
			g.stun_s = float(g.stun_s) + dt
			if free_from >= 0.0:
				(g.free_windows as Array).append(_fight_t - free_from)
				free_from = -1.0
			if stun_from < 0.0:
				stun_from = _fight_t
		else:
			if stun_from >= 0.0:
				g.longest_stun_s = maxf(float(g.longest_stun_s), _fight_t - stun_from)
				stun_from = -1.0
			if free_from < 0.0:
				free_from = _fight_t
	if c != null and c.cast_released.is_connected(cb):
		c.cast_released.disconnect(cb)
	g.my_casts = casts0[0]
	g.bot_begins = bot_begins
	g.fight_s = snappedf(_fight_t, 0.01)
	var fw: Array = g.free_windows
	g["free_windows_n"] = fw.size()
	g["free_windows_ge_0_3"] = fw.filter(func(w: Variant) -> bool: return float(w) >= 0.3).size()
	g.free_windows = []
	g["stun_share"] = snappedf(float(g.stun_s) / maxf(float(g.in_play_s), 0.01), 0.001)
	g["pct_taken_per_s"] = snappedf(float(g.pct_taken) / maxf(float(g.fight_s), 0.01), 0.01)
	g["pct_dealt_per_s"] = snappedf(float(g.pct_dealt) / maxf(float(g.fight_s), 0.01), 0.01)
	g["mean_dist_m"] = snappedf(float(g.dist_sum) / maxf(float(g.dist_n), 1.0), 0.1)
	g["defender_presses"] = sim.get("presses") if sim.get("presses") != null else 0
	g["defender_guards"] = sim.guards
	g.erase("dist_sum")
	g.erase("dist_n")
	g["pct_taken"] = snappedf(float(g.pct_taken), 0.1)
	g["pct_dealt"] = snappedf(float(g.pct_dealt), 0.1)
	g["stun_s"] = snappedf(float(g.stun_s), 0.01)
	g["longest_stun_s"] = snappedf(float(g.longest_stun_s), 0.01)
	print("COUNTER_GAME " + JSON.stringify(g))
	all_games.append(g.duplicate(true))


## The bot's hands made to spam: begin() the move the moment it is free (no lock running, on the deck, not stunned, in reach).
func _bot_spam() -> void:
	var f := mode.foe
	if f == null or not is_instance_valid(f) or f.held or f.brain == null or f.brain.bending == null:
		return
	var b: NpcBending = f.brain.bending
	if b.casting != "" or mode.rules.is_away(f) or mode.rules.is_away(player) or mode.rules.stunned(f):
		return
	var rm := RingMoves.of(f)
	if rm != null and (rm.off_deck() or rm.airborne() or rm.on_ledge()):
		return
	if not f.is_on_floor():
		return
	var dv := player.global_position - f.global_position
	if Vector2(dv.x, dv.z).length() > reach:
		return
	if f.brain.target != player:
		return
	b.begin(spam_id, spam_mode)
	bot_begins += 1


func _on_launched(b: Node3D, _v: Vector3, _stun: float, by: Node, tag: String) -> void:
	if g.is_empty() or mode.phase != "FIGHT":
		return
	if b == player:
		g.hits_taken = int(g.hits_taken) + 1
		var hb: Dictionary = g.hits_by
		hb[tag] = int(hb.get(tag, 0)) + 1


func _on_ko(b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
	if g.is_empty():
		return
	if b == player:
		g.falls_taken = int(g.falls_taken) + 1
	elif b == mode.foe:
		g.falls_dealt = int(g.falls_dealt) + 1


func _on_pct(by: Node, b: Node3D, delta: float) -> void:
	if g.is_empty():
		return
	if b == player:
		g.pct_taken = float(g.pct_taken) + delta
	elif by == player:
		g.pct_dealt = float(g.pct_dealt) + delta


func _summary() -> void:
	var fight := 0.0
	var taken := 0.0
	var dealt := 0.0
	var stun := 0.0
	var play := 0.0
	var fw := 0
	var fw3 := 0
	var falls := 0
	var longest := 0.0
	for x: Dictionary in all_games:
		fight += float(x.fight_s)
		taken += float(x.pct_taken)
		dealt += float(x.pct_dealt)
		stun += float(x.stun_s)
		play += float(x.in_play_s)
		fw += int(x.free_windows_n)
		fw3 += int(x.free_windows_ge_0_3)
		falls += int(x.falls_taken)
		longest = maxf(longest, float(x.longest_stun_s))
	print("COUNTER_SUMMARY " + JSON.stringify({"defense": defense, "spam": spam_id + "/" + spam_mode, "element": args.get("element", ""),
			"foe": args.get("foe", ""), "matches": all_games.size(), "fight_s": snappedf(fight, 0.1),
			"pct_taken_per_s": snappedf(taken / maxf(fight, 0.01), 0.01), "pct_dealt_per_s": snappedf(dealt / maxf(fight, 0.01), 0.01),
			"stun_share": snappedf(stun / maxf(play, 0.01), 0.001), "free_windows": fw, "free_windows_ge_0_3": fw3,
			"falls_taken": falls, "longest_stun_s": snappedf(longest, 0.01)}))
