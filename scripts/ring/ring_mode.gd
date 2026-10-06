class_name RingMode
extends Node
## A TIDEBREAK MATCH (the owner, 2026-10-04: the elemental ring sport is called Tidebreak; "1v1 first", the team structure
## kept for 3v3; "knockback wins": docs/bending_design.md): the rounds, the score, the text on the screen. Shaped like
## DuelMode (COUNTDOWN / FIGHT / OVER / DONE) but its own class: the duel and its test stay as they are. RingLevel puts it
## under the ring's level when a match is asked for (MatchSetup.take(): the main menu's Begin, or the user arg mode=ring);
## RingRules (its child) judges the deck, RingMenu is its Esc. Every number in data/ring/rules.json, every word on the
## screen in its "words".
##   the setup    MatchSetup: the player's element (Bending.of(player).element), the foe's (foes[0]; "any" drawn by lot
##                from the match's seed), the difficulty, to_win, round_s (user args round_s= and to_win= for soak
##                tests); read again at each restart (the Esc menu's choices land there)
##   the sides    team 0 the player's (his faction ring_team_a), team 1 the bot's (NpcSquad.spawn(level, "ring_team_b", 1,
##                ...) with tactics "bend", its element, no gun, the difficulty; "french_marine" when the ring factions
##                are missing). Both start mid zone 1 of their end; the ends swap each round (player_end)
##   a round      COUNTDOWN (countdown_s: both held at their spawns, "Round 2", 3, 2, 1, "Break!"), FIGHT until a
##                ring-out (at once: the round to the other side, credited to the last knocker) or the time-out (round_s:
##                the side holding more ground, then the higher health, else a draw), OVER (pause_s, Space: at once),
##                then the next round, the deck cleared (clear_dropped, rebuild), both made whole at their spawns. First to
##                to_win round wins takes the match (DONE; max_rounds rounds at most: the higher score, else a drawn match)
##   the bot      one bot the match long (improvement round 1, PERF: a new bot built each round froze the restart ~1 s): the
##                last round's made whole at its new end with a new mind (_keep_foe, _ready_foe); a new one only when it
##                cannot go on (hurt past whole, or the restart asks for another element or difficulty: _spawn_foe)
##   never dies   0 health in the ring is winded (RingRules): pushed back a zone, health to 40%; no fall hurts
##   the screen   plain text only on its own layer (the round, the countdown, the result, the score); the full strip is
##                the HUD's (FrontierHUD.set_arena). Nothing is drawn on or over the opponent
##   sound        a fight cue if MusicDirector has one (rules.json fight_cues), stings in the ring's own sounds (BendSounds:
##                the countdown's tick, the gong at the go, the bell at a round's end, the match's gong; rules.json stings)
## THE CONTRACT (group &"ring_match"; the HUD and the bots read it, through get() / has_method()):
##   round (int, from 1), score (Vector2i: x the player's side, y the other), phase ("COUNTDOWN" | "FIGHT" | "OVER" |
##   "DONE"), round_left_s(), side_of(body) -> 0 the player's side, 1 the other, -1 none; confined_of(body) -> 1..3 (0
##   none); end_of(body) -> the deck end it holds (RingArena side)
##   signals phase_changed(phase), knocked_back(who, from_zone, to_zone), rang_out(who, by), round_over(result, why) with
##   result "win" | "loss" | "draw" as the player's side sees it and why "ringout" | "winded" | "territory" | "health" |
##   "time", match_over(winner): 0 the player's side, 1 the other, -1 a drawn match
##   restart(), next_round(), stats, ringouts, self_outs, rounds_played, foe, rules, last_result, last_why, last_by
##   history (a line per round: {round, winner, result, why, at_s, tally}), round_tally ([team 0's, team 1's] this round:
##   {casts, catches, knock_backs, hits}), practice, dummy
## THE SCREENS (plan T13): RoundScreen over the ring through OVER (who took the round and why, the score, the round's tally:
## your casts, catches and knock-backs, the other side's), MatchScreen at DONE (the result, a line per round, the match's
## tally; Rematch, your element and the opponent for it, the main menu). Their words in data/ring/screens.json. While they
## stand, the banner here says nothing over them.
## PRACTICE (MatchSetup.kind "practice"; the user arg practice=stand|block|throw): a dummy of foes[0]'s element at the other
## end, held there (it never walks): "stand" never casts; "block" answers what comes at it with its element's guards (no
## dice: every time the lock fits the threat's time) and raises its cover when the player begins a lock (no more often than
## block_every_s); "throw" casts its throw at him every throw_every_s: its element's key 1 first move (MatchSetup.
## practice_move: earth a Spike to catch and send back, water a Lash to Turn, fire a Punch to Parry, air a Slice). No timer
## (the clock counts up), no rounds, no score; the soft walls off (walk anywhere); a fall into the water puts both back at
## their ends after reset_after_out_s, R (ring_reset) at once (reset_positions), B (ring_dummy) steps the dummy's way
## (cycle_dummy); 0 health is whole again. A line at the top says so, with the player's casts, catches and knock-backs.
## TEAMS (the 3 v 3 groundwork): in RingRules' team_mode a competitor rung out sits the round out (a bot held), and a whole
## side out in one round is a knockout: the round its, and the match over at once (why "knockout").

signal phase_changed(phase: String)
signal knocked_back(who: Node3D, from_zone: int, to_zone: int)
signal rang_out(who: Node3D, by: Node)
signal round_over(result: String, why: String)
signal match_over(winner: int)

const GROUP := &"ring_match"
const NODE_NAME := "RingMode"
const PHASES := ["COUNTDOWN", "FIGHT", "OVER", "DONE"]
## The sides' factions (data/npc/factions.json: mutually hostile, barks off), the player's first.
const FACTIONS := ["ring_team_a", "ring_team_b"]
const FALLBACK_FACTION := "french_marine"

var level: Node3D
var ring: RingArena
var rules: RingRules
var menu: Node
var player: FrontierPlayer
var foe: NpcFighter
var squad: NpcSquad
var phase := "COUNTDOWN"
var phase_t := 0.0
var round := 0
var score := Vector2i.ZERO
var round_s := 180.0
var to_win := 2
var element := "earth"
var foe_element := "earth"
var difficulty := "normal"
## The deck end (RingArena side) the player's side holds this round.
var player_end := 0
## The last round: "win" | "loss" | "draw" (the player's side's), why, the winning team (-1 a draw), who did it.
var last_result := ""
var last_why := ""
var last_winner := -1
var last_by: Node = null
## The match's winner once DONE (0 the player's side, 1 the other, -1 a draw).
var winner := -1
## Per team, the match so far: {knock_backs, hits, rounds}; and the bot's catches when its bending counts them.
var stats: Array = [{}, {}]
var rounds_played := 0
## Rounds ended by a ring-out (the water, or spent in the last zone), and those with no knocker to credit (or one's own).
var ringouts := 0
var self_outs := 0
var ui: CanvasLayer
var banner: Label
var sub: Label
var top: Label
var _left_at_end := 0.0
var _skip := false
var _seed := 7300
var _rng := RandomNumberGenerator.new()
var _count_said := -1
var _note := ""
var _note_t := 0.0
var _bar_laid := false
## A line per round of the match: {round, winner (-1 drawn), result, why, at_s (into the round), tally [team 0's, 1's]}.
var history: Array = []
## This round's (in practice: since the last reset) tally per team: {casts, catches, knock_backs, hits}.
var round_tally: Array = [{}, {}]
## A practice (no rounds, no timer) against a dummy, and its way ("stand" | "block" | "throw").
var practice := false
var dummy := "stand"
## The dummy's throws slowed (the lessons' guard drill and jump, RingLessons; the owner, 2026-10-05: a beginner beating a fast
## throw): a throw every slow_every_s, its shots flying at slow_speed of their own speed on the same path (data/ring/lessons.json).
var slow_throws := false
## The dummy's throw instead of its element's strike ("id/mode"; "": screens.json practice.throw; the lessons' jump: fire's Kick).
var throw_override := ""
var round_screen: Node
var match_screen: Node
var hint: Label
var tally_label: Label
var hint_back: ColorRect
var _knockout := false
var _guard_took := {}
var _reset_in := -1.0
var _live_in := 0.0
## After a practice's reset the deck is judged again this much later (s).
const RESET_GRACE_S := 0.12
var _dummy_next := 0.0
var _cover_next := 0.0
var _caster_hooked: SwayCaster
## Practice's lessons asked for (the main menu's Lessons row, RingLessons.ask; taken by RingLessons.install).
static var lessons_asked := false


## The match under `lvl` (the ring's level), for `p`, on `arena`: installed by RingLevel.
static func install(lvl: Node3D, p: FrontierPlayer, arena: RingArena) -> RingMode:
	var m := RingMode.new()
	m.name = NODE_NAME
	m.level = lvl
	m.player = p
	m.ring = arena
	if lvl.has_method(&"install_mode"):
		lvl.call(&"install_mode", m)
	else:
		lvl.add_child(m)
	return m


static func find(tree: SceneTree) -> RingMode:
	return tree.get_first_node_in_group(GROUP) as RingMode if tree != null else null


static func words(key: String) -> String:
	return String((RingRules.data().get("words", {}) as Dictionary).get(key, key))


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = 20            # (after the bodies and the rules: this frame's ring-out is this frame's)
	_seed = int(RingRules.num("seed", 7300))
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("seed=") and kv.get_slice("=", 1).is_valid_int():
			_seed = int(kv.get_slice("=", 1))
	_rng.seed = _seed
	if ring == null:
		ring = RingArena.find(get_tree())
	rules = RingRules.make(self, ring)
	rules.knocked_back.connect(_on_knocked_back)
	rules.rang_out.connect(_on_rang_out)
	rules.side_out.connect(_on_side_out)
	_build_ui()
	_ensure_keys()
	rules.winded.connect(_on_winded)
	menu = RingMenu.install(level if level != null else self, self)
	var parent: Node = level if level != null else self
	round_screen = RoundScreen.install(parent, self)
	match_screen = MatchScreen.install(parent, self)
	# (Practice's lessons and a first Quick match's key hints: each comes only when asked for, RingLessons / FirstHints)
	if MatchSetup.practice() and (lessons_asked or "lessons=on" in OS.get_cmdline_user_args()):
		RingLessons.install(self)
	elif MatchSetup.quick:
		FirstHints.install(self)
	if player != null:
		player.no_death = true
		if player.hud != null and player.hud.has_method(&"set_arena"):
			player.hud.call(&"set_arena", true)
	# (the element's bar: player.gd's own arena switch lays it when it has one; until then laid here, as the duel does)
	if player != null and player.get(&"arena") == null:
		get_tree().create_timer(Hotbar.KIT_S + 0.3, false).timeout.connect(lay_bar)
	restart.call_deferred()


# ---------------------------------------------------------------- the match
## The match from its start with MatchSetup's choices: the score nil, round 1, the player's side at end 0.
func restart() -> void:
	element = MatchSetup.element if MatchSetup.element in Bending.ELEMENTS else "earth"
	foe_element = String(MatchSetup.resolved([MatchSetup.foe()], _rng)[0])
	difficulty = MatchSetup.difficulty
	practice = MatchSetup.practice()
	dummy = MatchSetup.dummy if MatchSetup.dummy in MatchSetup.DUMMIES else "stand"
	history = []
	_knockout = false
	_reset_in = -1.0
	_live_in = 0.0
	to_win = maxi(MatchSetup.rounds_to_win, 1)
	round_s = MatchSetup.round_s if MatchSetup.round_s > 0.0 else RingRules.num("round_s", 180.0)
	score = Vector2i.ZERO
	round = 0
	winner = -1
	rounds_played = 0
	ringouts = 0
	self_outs = 0
	last_result = ""
	last_why = ""
	last_winner = -1
	last_by = null
	for t in 2:
		stats[t] = {"knock_backs": 0, "hits": 0, "rounds": 0, "catches": 0, "casts": 0}
	_hook_caster()
	if player != null:
		Bending.of(player).element = element
		if _bar_laid:
			lay_bar()
	next_round()


## The next round: the ends swapped, the deck cleared, both whole at their spawns, the countdown.
func next_round() -> void:
	round += 1
	player_end = (round - 1) % 2
	_skip = false
	_count_said = -1
	var keep := _keep_foe()
	if not keep:
		_drop_foe()
	if ring != null:
		ring.clear_dropped()
		ring.rebuild()
	rules.live = false
	rules.clear()
	rules.set_ends(player_end)
	if player != null and is_instance_valid(player):
		make_whole(player)
		RingLevel.place(player, ring.spawn(player_end))
		player.drag_speed_cap = 0.0          # (held at the spawn through the countdown: a root ending never frees it)
		_hold_casts(true)                    # (and no lock through it: the arena player's contract, SwayCaster.enabled)
		var bd := Bending.of(player)
		bd.element = element
		bd.water = bd.water_max
		rules.add(player, 0)
	if keep:
		_ready_foe()
	else:
		_spawn_foe()
	if foe != null:
		rules.add(foe, 1)
	rules.reset_round()
	rules.soft_walls = not practice
	_new_tally()
	_to("COUNTDOWN")


## The foe of this round (team 1) at the other end: a bot of its element, no gun, held through the countdown.
func _spawn_foe() -> void:
	var xf := ring.spawn(1 - player_end, int(RingRules.num("bot_slot", 0.0)))
	var faction: String = FACTIONS[1] if not NpcFactions.get_faction(FACTIONS[1]).is_empty() else FALLBACK_FACTION
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "ring", "tactics": "bend", "element": foe_element,
			"weapon": "", "sidearm": "", "skill": difficulty, "seed": _seed + round * 17, "y": ring.deck_y()}
	squad = NpcSquad.spawn(level if level != null else get_parent(), faction, 1, xf.origin, opts)
	foe = squad.members[0] if squad != null and not squad.members.is_empty() else null
	if foe == null:
		return
	foe.flees = false
	foe.calm_s = INF
	foe.held = true
	foe.no_death = true
	foe.label = MatchSetup.competitor(foe_element)
	if &"element" in foe:
		foe.set(&"element", foe_element)
	Bending.of(foe).element = foe_element
	_ring_aware()


## The bot's ring awareness, its bending's own reading: where it may stand, how far an open end lies along a way.
func _ring_aware() -> void:
	var bend: Variant = foe.brain.bending if foe.brain != null else null
	if bend is Object and bend != null:
		var o := bend as Object
		if &"bounds_fn" in o:
			o.set(&"bounds_fn", rules.bounds_fn_for(foe))
		if &"edge_fn" in o:
			o.set(&"edge_fn", rules.edge_along)


## Whether last round's bot can stand for this one: there, alive and not down, no wound, broken bone or limp of its own (a
## bend's slow is not its own: make_whole ends it), of the element and difficulty the match asks for now (a rematch may ask
## for another), with its bending mind (tactics "bend").
func _keep_foe() -> bool:
	if foe == null or not is_instance_valid(foe) or not foe.is_inside_tree() or squad == null or not is_instance_valid(squad):
		return false
	if foe.is_dead() or foe.down or foe.left_field or foe.arm_broken != "" or foe.pool > 0.0 or foe.mortal_left > 0.0:
		return false
	var own_limp := float(foe.get_meta(&"bend_limp", foe.limp))
	if own_limp < 1.0:
		return false
	return foe.element == foe_element and foe.skill_preset == difficulty and foe.brain != null \
			and foe.brain.bending != null


## Last round's bot at this round's end as a new one would stand there (_spawn_foe): made whole (make_whole: no knock, root,
## slow or anchor), its health and water full, its feet and hands free, held through the countdown, its home the new spot,
## its own dice seeded as a new bot's of this round would be; and a new mind (NpcBrain: the target, the lock, the bending's
## books, its catches answered and its cools, all as at a spawn; the old one's lock let go and its held zones ended first).
func _ready_foe() -> void:
	var xf := ring.spawn(1 - player_end, int(RingRules.num("bot_slot", 0.0)))
	make_whole(foe)
	if foe.has_meta(&"bend_limp"):
		foe.limp = float(foe.get_meta(&"bend_limp"))
		foe.remove_meta(&"bend_limp")
	foe.feet_held = false
	foe.health = foe.health_max
	foe.held = true
	foe.action = ""
	foe.face_lock = Vector3.INF
	foe.hits_taken = 0
	foe.killed_by = null
	var dice := RandomNumberGenerator.new()
	dice.seed = _seed + round * 17           # (_spawn_foe's squad seed: its first draw is a new fighter's own seed)
	foe.rng_seed = dice.randi() | 1
	foe.rng.seed = foe.rng_seed
	foe.home = Vector3(xf.origin.x, ring.deck_y(), xf.origin.z)
	squad.origin = xf.origin
	RingLevel.place(foe, xf)
	foe.halt()
	if foe.brain.bending != null:
		foe.brain.bending.on_exit()
	foe.brain = NpcBrain.new(foe)
	var bd := Bending.of(foe)
	bd.element = foe_element
	bd.water = bd.water_max
	_ring_aware()


func _drop_foe() -> void:
	if squad != null and is_instance_valid(squad):
		if squad.get_parent() != null:
			squad.get_parent().remove_child(squad)  # (out at once: the interactor and the senses forget him)
		squad.queue_free()
	squad = null
	foe = null


## `b` whole for a round: alive and full, back on its feet, no knock, no root, slow or anchor, no lock held.
func make_whole(b: Node3D) -> void:
	for key: StringName in [&"bend_root", &"bend_slow", &"bend_anchor", &"bend_redirect_lightning", &"bend_brace",
			&"bend_dazzle_until"]:                # (a flare's dazzle: the bot kept from last round is not still dazzled)
		if b.has_meta(key):
			b.remove_meta(key)
	var kn := BendKnock.peek(b)
	if kn != null:
		kn.reset()
		kn.last_knocker = null
		kn.last_knock_at = -INF
	if b is FrontierPlayer:
		var p := b as FrontierPlayer
		var rag := p.get_node_or_null(^"Ragdoll") as PlayerRagdoll
		if rag != null and rag.is_down():
			rag.recover_now()
		if InspectView.current != null and is_instance_valid(InspectView.current):
			InspectView.current.close()
		p.respawn()
		p.bend_speed_cap = INF
		p.fell_by = null
		p.set_crouched(false)
		var sc := SwayCaster.of(p)
		if sc != null and sc.is_locking() and sc.has_method(&"_end_on"):
			sc.call(&"_end_on", "round")


## The player's bar laid for his element (until player.gd lays it itself in the arena): the element's keys, the first
## readied, the weapons in the pack.
func lay_bar() -> void:
	var bar := Hotbar.of(player) if player != null and is_instance_valid(player) else null
	if bar == null:
		return
	var ids := Bending.bar(element)
	for i in Hotbar.SLOTS:
		var e := Hotbar.make("spell", String(ids[i])) if i < ids.size() else {}
		if not e.is_empty() and bar.has_thing(e):
			bar.assign(i, e)
		else:
			bar.clear(i)
	_bar_laid = true
	if bar.filled(0) and bar.selected() != 0:
		bar.take(0)


func _to(p: String) -> void:
	phase = p
	phase_t = 0.0
	phase_changed.emit(p)
	_paint()


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	phase_t += dt
	if phase == "COUNTDOWN" and LoadingScreen.covering():
		phase_t = 0.0                        # (the countdown begins as the loading screen goes)
	_note_t = maxf(_note_t - dt, 0.0)
	match phase:
		"COUNTDOWN":
			var cd := countdown_s()
			var n := ceili(cd - phase_t)
			if not practice and n != _count_said and phase_t >= RingRules.num("round_show_s", 0.8) and n > 0:
				_count_said = n
				_sting("count")
			if phase_t >= cd:
				_fight()
		"FIGHT":
			_count_guards()
			if practice:
				_practice_step(dt)
			elif foe == null or not is_instance_valid(foe):
				_end_round(0, "winded")
			elif round_left_s() <= 0.0:
				_time_out()
		"OVER":
			if phase_t >= RingRules.num("pause_s", 6.0) or _skip:
				_skip = false
				if decided():
					_done()
				else:
					next_round()
	_paint()


func _fight() -> void:
	if player != null and is_instance_valid(player):
		player.drag_speed_cap = INF
	_hold_casts(false)
	if foe != null and is_instance_valid(foe):
		foe.held = practice                  # (the dummy is held at its end; its casts are begun here: _practice_step)
		if foe.brain != null and player != null:
			foe.brain.told(player, player.global_position)
	rules.live = true
	_dummy_next = BendStatus.now() + _pnum("throw_every_s", 3.0) * 0.5
	_cover_next = 0.0
	_sting("go")
	if not practice:
		_music(true)
	_to("FIGHT")


## The time-out: more ground, then more health, else a draw.
func _time_out() -> void:
	var t := rules.territory()
	if t >= 0:
		_end_round(t, "territory")
		return
	var h0 := rules.health_frac(0)
	var h1 := rules.health_frac(1)
	if absf(h0 - h1) > 0.001:
		_end_round(0 if h0 > h1 else 1, "health")
	else:
		_end_round(-1, "time")


## The round to `team` (-1: drawn) for `why`.
func _end_round(team: int, why: String) -> void:
	if phase != "FIGHT":
		return
	_left_at_end = round_left_s()
	rules.live = false
	last_winner = team
	last_why = why
	last_result = "draw" if team < 0 else ("win" if team == 0 else "loss")
	if team == 0:
		score.x += 1
	elif team == 1:
		score.y += 1
	if team >= 0:
		stats[team]["rounds"] = int(stats[team].get("rounds", 0)) + 1
	rounds_played += 1
	if why in ["ringout", "winded", "knockout"]:
		ringouts += 1
	_close_tally()
	_count_catches()
	history.append({"round": round, "winner": team, "result": last_result, "why": why,
			"at_s": maxf(round_s - _left_at_end, 0.0), "tally": round_tally.duplicate(true)})
	if foe != null and is_instance_valid(foe):
		foe.held = true
	if player != null and is_instance_valid(player):
		player.drag_speed_cap = INF
	_music(false)
	_sting("ringout" if why == "ringout" else "over")
	_to("OVER")
	round_over.emit(last_result, why)


## The match is decided: a side at to_win, or max_rounds played.
func decided() -> bool:
	if practice:
		return false
	return _knockout or score.x >= to_win or score.y >= to_win or round >= int(RingRules.num("max_rounds", 7.0))


func _done() -> void:
	winner = 0 if score.x > score.y else (1 if score.y > score.x else -1)
	if player != null and is_instance_valid(player):
		player.drag_speed_cap = 0.0          # (the match screen stands: he waits for a rematch or the menu)
		_hold_casts(true)
	_sting("match")
	_to("DONE")
	match_over.emit(winner)


func _on_knocked_back(who: Node3D, from_zone: int, to_zone: int) -> void:
	var t := rules.team_of(who)
	if t >= 0:
		stats[1 - t]["knock_backs"] = int(stats[1 - t].get("knock_backs", 0)) + 1
		round_tally[1 - t]["knock_backs"] = int(round_tally[1 - t].get("knock_backs", 0)) + 1
	if who == player:
		_note = words("pushed") % to_zone
		_note_t = 1.6
	knocked_back.emit(who, from_zone, to_zone)


func _on_rang_out(who: Node3D, by: Node) -> void:
	last_by = by
	if by == null or not is_instance_valid(by) or by == who:
		self_outs += 1
	if rules.team_mode() and who is NpcFighter and is_instance_valid(who):
		(who as NpcFighter).held = true      # (out: he sits the round out)
	rang_out.emit(who, by)


func _on_side_out(side: int) -> void:
	if practice:
		_note = pword("out")
		_note_t = _pnum("reset_after_out_s", 1.6)
		_reset_in = _pnum("reset_after_out_s", 1.6)
		return
	var why := String(rules.last_out.get("why", "ringout"))
	if rules.team_mode():
		# (a whole side in the water in one round: a knockout, the match over at once)
		_knockout = true
		_end_round(1 - side, "knockout")
		_done()
		return
	_end_round(1 - side, why)


## Spent in the ring (RingRules' winded): in practice whole again at once.
func _on_winded(who: Node3D, _by: Node, _to_zone: int) -> void:
	if not practice or who == null or not is_instance_valid(who):
		return
	if who is FrontierPlayer:
		(who as FrontierPlayer).health = (who as FrontierPlayer).max_health
	elif who is NpcFighter:
		(who as NpcFighter).health = (who as NpcFighter).health_max


func _count_catches() -> void:
	stats[0]["hits"] = rules.knocks.x + int(stats[0].get("hits", 0))
	stats[1]["hits"] = rules.knocks.y + int(stats[1].get("hits", 0))
	# (the bot's own count, NpcBending.catches; a new mind each round, its books with it: the match's is the sum of the rounds')
	var bend: Variant = foe.brain.bending if foe != null and is_instance_valid(foe) and foe.brain != null else null
	if bend is Object and bend != null:
		var n: Variant = (bend as Object).get(&"catches")
		var c: Variant = (bend as Object).get(&"counters")
		if not (n is int) and c is Dictionary:
			n = (c as Dictionary).get("catches", 0)
		if n is int:
			stats[1]["catches"] = int(stats[1].get("catches", 0)) + int(n)


## The player's casting held (the countdown) or let go: SwayCaster.enabled, the arena player's contract (his bar stays laid,
## a lock under way ends "off").
func _hold_casts(on: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	var sc := SwayCaster.of(player)
	if sc != null:
		sc.enabled = not on


# ---------------------------------------------------------------- the contract
func round_left_s() -> float:
	if practice:
		return phase_t if phase == "FIGHT" else 0.0      # (no timer: the clock counts up)
	match phase:
		"FIGHT":
			return maxf(round_s - phase_t, 0.0)
		"OVER", "DONE":
			return _left_at_end
	return round_s


## 0 the player's side, 1 the other, -1 not a competitor.
func side_of(body: Node) -> int:
	return rules.team_of(body) if rules != null else -1


## The zone `body` is confined to this round (1..3; 0 not a competitor).
func confined_of(body: Node) -> int:
	return rules.confined_of(body) if rules != null else 0


## The deck end (RingArena side) `body` holds this round.
func end_of(body: Node) -> int:
	return rules.end_of(body) if rules != null else -1


# ---------------------------------------------------------------- input
## Space in the pause after a round: the next round at once.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	if practice and phase == "FIGHT":
		if e.is_action_pressed(RESET_ACTION):
			reset_positions()
			get_viewport().set_input_as_handled()
		elif e.is_action_pressed(DUMMY_ACTION):
			cycle_dummy()
			get_viewport().set_input_as_handled()
		return
	if phase != "OVER":
		return
	if (e as InputEventKey).physical_keycode == KEY_SPACE:
		_skip = true


# ---------------------------------------------------------------- sound
## The round's moment `key` (count, go, ringout, over, match): rules.json stings [id, gain dB, pitch], the ring's own sound
## (BendSounds: the countdown's tick, the gong at the go, the bell at a round's end, the match's gong; improvement round 2,
## the owner: no borrowed frontier sounds in the ring), else an existing Sfx id.
func _sting(key: String) -> void:
	var s: Variant = (RingRules.data().get("stings", {}) as Dictionary).get(key)
	if not (s is Array) or (s as Array).size() < 3:
		return
	var id := StringName(String(s[0]))
	if BendSounds.has(id):
		BendSounds.play(id, Vector3.INF, float(s[1]), float(s[2]))
	elif Sfx.has(id):
		Sfx.play_2d(id, float(s[1]), float(s[2]))


func _music(on: bool) -> void:
	var md := get_tree().get_first_node_in_group(MusicDirector.GROUP) as MusicDirector
	if md == null:
		return
	if not on:
		if md.mode == MusicDirector.Mode.STORY:
			md.play_story("")
		return
	for c: Variant in RingRules.data().get("fight_cues", []):
		if MusicDirector.M.CUES.has(String(c)):
			md.play_story(String(c))
			return


# ---------------------------------------------------------------- the words on the screen
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "RingText"
	ui.layer = 15
	add_child(ui)
	banner = _label(54, MenuUI.INK)
	banner.anchor_top = 0.22
	banner.anchor_bottom = 0.22
	ui.add_child(banner)
	sub = _label(22, MenuUI.DIM)
	sub.anchor_top = 0.22
	sub.anchor_bottom = 0.22
	sub.offset_top = 70.0
	sub.offset_bottom = 110.0
	ui.add_child(sub)
	top = _label(17, MenuUI.DIM)
	top.anchor_top = 0.0
	top.anchor_bottom = 0.0
	top.offset_top = 86.0
	top.offset_bottom = 110.0
	ui.add_child(top)
	# (practice: what the dummy does and the keys, under the HUD's match bar; the player's tally under it)
	hint_back = ColorRect.new()
	hint_back.name = "PracticeBack"
	hint_back.color = Color(0.02, 0.015, 0.01, 0.5)
	hint_back.anchor_left = 0.18
	hint_back.anchor_right = 0.82
	hint_back.offset_top = 110.0
	hint_back.offset_bottom = 158.0
	hint_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_back.visible = false
	ui.add_child(hint_back)
	hint = _label(16, MenuUI.INK)
	hint.name = "PracticeHint"
	hint.offset_top = 112.0
	hint.offset_bottom = 134.0
	hint.visible = false
	ui.add_child(hint)
	tally_label = _label(16, MenuUI.GOLD)
	tally_label.name = "PracticeTally"
	tally_label.offset_top = 134.0
	tally_label.offset_bottom = 156.0
	tally_label.visible = false
	ui.add_child(tally_label)


func _label(size: int, color: Color) -> Label:
	var l := MenuUI.label("", size, color)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = 0.0
	l.offset_bottom = 64.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The foe's name on the screen (the name its element's competitors go by: "Tide").
func foe_name() -> String:
	return MatchSetup.competitor(foe_element)


func score_text() -> String:
	return words("score") % [words("you"), score.x, score.y, foe_name()]


func time_text(s: float) -> String:
	return "%d:%02d" % [floori(s / 60.0), floori(fmod(s, 60.0))]


func _paint() -> void:
	if banner == null:
		return
	var b := ""
	var s := ""
	match phase:
		"COUNTDOWN":
			var cd := countdown_s()
			if practice:
				b = pword("banner")
			else:
				b = words("round") % round if phase_t < RingRules.num("round_show_s", 0.8) else str(maxi(ceili(cd - phase_t), 1))
				s = words("sub_countdown") % [score_text(), MatchSetup.rounds_label(to_win), difficulty]
		"FIGHT":
			if practice:
				b = pword("banner") if phase_t < RingRules.num("go_show_s", 1.2) else (_note if _note_t > 0.0 else "")
			else:
				b = words("go") if phase_t < RingRules.num("go_show_s", 1.2) else (_note if _note_t > 0.0 else "")
		"OVER":
			if round_screen == null or not is_instance_valid(round_screen):
				b = result_line()
				s = score_text()
				if not decided():
					s += "  ·  " + words("next") % ceili(maxf(RingRules.num("pause_s", 6.0) - phase_t, 0.0))
		"DONE":
			if match_screen == null or not is_instance_valid(match_screen):
				b = words("match_win") if winner == 0 else (words("match_draw") if winner < 0 else words("match_loss") % foe_name())
				s = score_text() + "  ·  " + words("done_hint")
	banner.text = b
	sub.text = s
	if hint != null:
		hint.visible = practice
		tally_label.visible = practice
		hint_back.visible = practice
		if practice:
			hint.text = practice_line()
			var mine: Dictionary = round_tally[0]
			tally_label.text = pword("tally") % [int(mine.get("casts", 0)), int(mine.get("catches", 0)), int(mine.get("knock_backs", 0))]
	# (the HUD's strip shows the round, the time and the score once it has one: set_arena)
	var hud_has := player != null and is_instance_valid(player) and player.hud != null and player.hud.has_method(&"set_arena")
	top.text = "" if hud_has or phase == "DONE" else words("top") % [MatchSetup.sport(), round, floori(round_left_s() / 60.0),
			floori(fmod(round_left_s(), 60.0)), score_text()]


## The round's result in words.
func result_line() -> String:
	var foe_n := foe_name()
	match last_why:
		"ringout", "winded", "territory", "health", "knockout":
			if last_result == "win":
				return words("win_" + last_why) % foe_n if words("win_" + last_why).contains("%s") else words("win_" + last_why)
			return words("loss_" + last_why) % foe_n if words("loss_" + last_why).contains("%s") else words("loss_" + last_why)
	return words("draw")


# ---------------------------------------------------------------- the tally (the screens')
const RESET_ACTION := &"ring_reset"
const DUMMY_ACTION := &"ring_dummy"
const RESET_KEY := KEY_R
const DUMMY_KEY := KEY_B


## The practice keys (R: reset positions, B: the dummy's way), made when missing (the player may rebind them).
static func _ensure_keys() -> void:
	for pair: Array in [[RESET_ACTION, RESET_KEY], [DUMMY_ACTION, DUMMY_KEY]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var k := InputEventKey.new()
		k.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], k)


func _new_tally() -> void:
	round_tally = [{"casts": 0, "catches": 0, "knock_backs": 0, "hits": 0}, {"casts": 0, "catches": 0, "knock_backs": 0, "hits": 0}]
	_guard_took.clear()
	var bend := _foe_bending()
	if bend != null:
		round_tally[1]["casts0"] = int(bend.get(&"casts"))
		round_tally[1]["catches0"] = int(bend.get(&"catches"))


## The player's casts counted as he casts (SwayCaster.cast: the keys' and the quick spell's alike), in a fight only.
func _hook_caster() -> void:
	var sc := SwayCaster.of(player) if player != null and is_instance_valid(player) else null
	if sc == null or sc == _caster_hooked:
		return
	_caster_hooked = sc
	sc.cast.connect(_on_player_cast)


func _on_player_cast(_m: String, _t: Node3D) -> void:
	if phase == "FIGHT":
		round_tally[0]["casts"] = int(round_tally[0].get("casts", 0)) + 1


## The player's catches: what his guards took (BendZone.took on a guard he owns: stones caught, bolts sent back or turned
## aside), counted as they take.
func _count_guards() -> void:
	if player == null or not is_instance_valid(player):
		return
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz == null or bz.owner_node != player or not (bz.kind in BendZone.GUARDS or bz.kind == "air_shield"):
			continue
		var id := bz.get_instance_id()
		var had := int(_guard_took.get(id, 0))
		if bz.took > had:
			round_tally[0]["catches"] = int(round_tally[0].get("catches", 0)) + bz.took - had
			_guard_took[id] = bz.took
	if _guard_took.size() > 64:
		_guard_took.clear()


## The round's tally closed: the knocks landed, the bot's casts and catches (its own counts), into the match's stats.
func _close_tally() -> void:
	round_tally[0]["hits"] = rules.knocks.x
	round_tally[1]["hits"] = rules.knocks.y
	var bend := _foe_bending()
	if bend != null:
		round_tally[1]["casts"] = int(bend.get(&"casts")) - int(round_tally[1].get("casts0", 0))
		round_tally[1]["catches"] = int(bend.get(&"catches")) - int(round_tally[1].get("catches0", 0))
	for t in 2:
		(round_tally[t] as Dictionary).erase("casts0")
		(round_tally[t] as Dictionary).erase("catches0")
		stats[t]["casts"] = int(stats[t].get("casts", 0)) + int(round_tally[t].get("casts", 0))
	stats[0]["catches"] = int(stats[0].get("catches", 0)) + int(round_tally[0].get("catches", 0))


## The match's tally for team `t`: {casts, catches, knock_backs, hits} summed over the rounds played.
func match_tally(t: int) -> Dictionary:
	var out := {"casts": 0, "catches": 0, "knock_backs": 0, "hits": 0}
	for h: Dictionary in history:
		var tl: Dictionary = (h.tally as Array)[t]
		for k: String in out:
			out[k] = int(out[k]) + int(tl.get(k, 0))
	return out


func _foe_bending() -> Object:
	if foe == null or not is_instance_valid(foe) or foe.brain == null:
		return null
	var b: Variant = foe.brain.bending
	return b as Object if b is Object and b != null else null


# ---------------------------------------------------------------- practice
## data/ring/screens.json practice's number `key`.
static func _pnum(key: String, def: float) -> float:
	return float((MatchSetup.screens().get("practice", {}) as Dictionary).get(key, def))


## A practice word (screens.json practice.words).
static func pword(key: String) -> String:
	return String((((MatchSetup.screens().get("practice", {}) as Dictionary).get("words", {})) as Dictionary).get(key, key))


## The countdown's length: the rules' (3 s), a practice's short one.
func countdown_s() -> float:
	return _pnum("countdown_s", 1.0) if practice else RingRules.num("countdown_s", 3.0)


## "Practice  ·  a Stone dummy that throws at you every few seconds  ·  R: reset positions ..."
func practice_line() -> String:
	return pword("hint") % [MatchSetup.competitor(foe_element), MatchSetup.dummy_line(dummy)]


## The dummy's next way in turn (stand, block, throw), at once.
func cycle_dummy() -> void:
	var ds := MatchSetup.DUMMIES
	dummy = String(ds[(ds.find(dummy) + 1) % ds.size()])
	MatchSetup.dummy = dummy
	_dummy_next = BendStatus.now() + _pnum("throw_every_s", 3.0) * 0.5
	_cover_next = 0.0
	_note = pword("way") % MatchSetup.dummy_line(dummy)
	_note_t = 1.8


## Both back at their ends, whole, the deck cleared (practice's R; after a fall into the water).
func reset_positions() -> void:
	_reset_in = -1.0
	if ring != null:
		ring.clear_dropped()
	if player != null and is_instance_valid(player):
		make_whole(player)
		RingLevel.place(player, ring.spawn(player_end))
		player.drag_speed_cap = INF
		_hold_casts(false)
	if foe == null or not is_instance_valid(foe) or foe.down or foe.is_dead():
		# (gone, or down for good: a new dummy, the books made again)
		_drop_foe()
		rules.clear()
		if player != null and is_instance_valid(player):
			rules.add(player, 0)
		_spawn_foe()
		if foe != null:
			rules.add(foe, 1)
	if foe != null and is_instance_valid(foe):
		make_whole(foe)
		foe.health = foe.health_max
		var bend := _foe_bending()
		if bend != null and bend.has_method(&"reset"):
			bend.call(&"reset")
		var xf := ring.spawn(1 - player_end, int(RingRules.num("bot_slot", 0.0)))
		RingLevel.place(foe, xf)
		foe.held = true
		if player != null and foe.brain != null:
			foe.brain.told(player, player.global_position)
	rules.reset_round()
	# (the deck judged again a moment later: the tank's Area3D still counts a body just lifted out of it until the physics
	# has stepped, so judging at once would put him straight back out)
	rules.live = false
	_live_in = RESET_GRACE_S
	_dummy_next = BendStatus.now() + _pnum("throw_every_s", 3.0) * 0.5
	_cover_next = 0.0
	if _note_t <= 0.0:
		_note = pword("reset")
		_note_t = 1.2


## The dummy each frame of a practice: held at its end facing the player; its lock let run while it casts; its way's cast
## begun (block: a guard against what comes, its cover when he locks; throw: its throw every throw_every_s).
func _practice_step(dt: float) -> void:
	if slow_throws and foe != null and is_instance_valid(foe):
		_slow_shots()                         # (each shot the frame it leaves, whatever the dummy is doing)
	if _live_in > 0.0:
		_live_in -= dt
		if _live_in <= 0.0:
			rules.live = true
	if _reset_in > 0.0:
		_reset_in -= dt
		if _reset_in <= 0.0:
			reset_positions()
		return
	if foe == null or not is_instance_valid(foe):
		reset_positions()
		return
	var bend := _foe_bending()
	if bend == null:
		return
	if String(bend.get(&"casting")) != "" or float(bend.get(&"_follow")) > 0.0:
		foe.held = false                     # (its lock fills and its cast clip plays: NpcBending.tick)
		return
	foe.held = true
	if player == null or not is_instance_valid(player):
		return
	foe.face_point(player.global_position)
	var bw := Bending.of(foe)
	if bw != null:
		bw.water = bw.water_max              # (a dummy never runs dry)
	var now := BendStatus.now()
	match dummy:
		"throw":
			if now >= _dummy_next:
				_dummy_next = now + throw_every_s()
				_dummy_cast(bend, throw_override if throw_override != "" else _pmove("throw"))
		"block":
			var g := dummy_guard(bend)
			if not g.is_empty():
				_dummy_cast(bend, "%s/%s" % [g.id, g.mode])
				return
			var sc := SwayCaster.of(player)
			if sc != null and sc.is_locking() and now >= _cover_next:
				_cover_next = now + _pnum("block_every_s", 2.5)
				_dummy_cast(bend, _pmove("cover"))


## The seconds between the dummy's throws: screens.json practice throw_every_s, slow_every_s while they are slowed.
func throw_every_s() -> float:
	return RingLessons.num("slow_every_s", 5.0) if slow_throws else _pnum("throw_every_s", 3.0)


## The dummy's shots slowed once each, as they leave (slow_throws): a bolt's speed by slow_speed and its gravity by its square
## (the same path, later); a thrown stone (GustLift) by slow_speed with its rise made good for its own gravity's longer fall.
func _slow_shots() -> void:
	var k := clampf(RingLessons.num("slow_speed", 0.6), 0.2, 1.0)
	for b in get_tree().get_nodes_in_group(BendBolt.GROUP):
		var bb := b as BendBolt
		if bb == null or bb.caster != foe or bb.has_meta(&"ring_slowed"):
			continue
		bb.set_meta(&"ring_slowed", true)
		bb.velocity *= k
		bb.gravity *= k * k
	for n in get_tree().get_nodes_in_group(GustLift.GROUP):
		var gl := n as GustLift
		if gl == null or gl.phase != GustLift.Phase.FLIGHT or gl.has_meta(&"ring_slowed") or gl.caster == null \
				or gl.caster.body != foe:
			continue
		gl.set_meta(&"ring_slowed", true)
		var v := gl.velocity
		var flat := Vector2(v.x, v.z).length()
		var g := float((gl.call(&"_hurl_d") as Dictionary).get("gravity", 6.0)) if gl.has_method(&"_hurl_d") else 6.0
		var d := Vector2(player.global_position.x - gl.stone.global_position.x, player.global_position.z
				- gl.stone.global_position.z).length() if player != null and is_instance_valid(gl.stone) else 0.0
		var t0 := d / maxf(flat, 0.1)
		var t1 := t0 / k
		# (the same drop at his distance: v1y * t1 - g t1² / 2 = v0y * t0 - g t0² / 2)
		var vy := (v.y * t0 - 0.5 * g * t0 * t0 + 0.5 * g * t1 * t1) / maxf(t1, 0.01) if t1 > 0.0 else v.y * k
		gl.velocity = Vector3(v.x * k, vy, v.z * k)


## The dummy's element's move for `what` ("throw" | "cover": screens.json practice), "id/mode".
func _pmove(what: String) -> String:
	return MatchSetup.practice_move(foe_element, what)


## The dummy's lock of "id/mode" begun (let go: its tick fills it and casts it, NpcBending's own way).
func _dummy_cast(bend: Object, key: String) -> bool:
	if key == "" or not key.contains("/"):
		return false
	foe.held = false
	bend.call(&"begin", key.get_slice("/", 0), key.get_slice("/", 1))
	return true


## A guard of the dummy's against what comes at it now ({id, mode, kind} or {}): its element's reaction whose lock fits the
## threat's time (NpcBending's own rule, without its chance: a practice dummy answers every time it can).
static func dummy_guard(bend: Object) -> Dictionary:
	var threats: Array = bend.call(&"_threats")
	if threats.is_empty():
		return {}
	var pn := String(bend.call(&"_preset_name"))
	var best := {}
	for th: Dictionary in threats:
		var tti := float(th.tti)
		for o: Dictionary in bend.get(&"options"):
			var h: Dictionary = o.hint
			if String(h.get("role", "")) != "reaction" or not String(th.kind) in (h.get("answers", []) as Array):
				continue
			if not bool(bend.call(&"castable", o)):
				continue
			var ls := NpcBending.lock_for(String(o.id), String(o.mode), pn, 0.0)
			var window := float(o.spec.get("window_s", o.spec.get("life_s", o.spec.get("s", 1.0))))
			if ls > tti or ls + window * 0.8 < tti:
				continue
			if best.is_empty() or ls < float(best.ls):
				best = {"id": o.id, "mode": o.mode, "kind": th.kind, "ls": ls}
	return best
