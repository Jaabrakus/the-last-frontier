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
## Round 3's SEAMS moved the practice into RingPractice (scripts/ring/ring_practice.gd, `practice_ctl`): this keeps one-line
## calls into it (reset, arm, step, set_way, paint, on_out, on_winded, key) and the old names as forwarders (dummy,
## slow_throws, throw_override, hint, tally_label, practice_line(), cycle_dummy(), reset_positions(), throw_every_s(), pword,
## _pnum, _pmove, dummy_guard), so RingLessons and the tests read it where they always did.
## TEAMS (the 3 v 3 groundwork): in RingRules' team_mode a competitor rung out sits the round out (a bot held), and a whole
## side out in one round is a knockout: the round its, and the match over at once (why "knockout").
## TEAM FORMATS (the owner, 2026-10-10: 2v2 and 4v4; docs/tidebreak/team_formats_and_arenas.md): team_n() fighters a side
## (RingArena.format's; a practice 1v1's). MatchSetup.lineup draws the sides' elements at each restart (foe_elements[0] the
## foe's, mate_elements the player's team-mates'); the other bots (extras) are made as the foe is (_make_bot), at their slots of
## their side's end, kept across games when they can stand (_keep_bot, _ready_bot), held through every countdown and let go at
## the go. THE TEAM COACH (_coach, FIGHT in team mode): every coach.every_s each bot is handed the nearest opponent still in
## play, counted coach.spread_m farther for each of its side already on him (no side all piling on one), a better one by
## coach.keep_m before it switches; a bot whose target is away (in the water, on the way back) is handed another at once.
## ROUND 3, THE % MATCH (RingRules.stock_on(): rules.json rule_set "stock", the default; smash_r3 spec v2 §7; PERCENT's). A
## "round" is a GAME: 3 lives each (team: 2), an 8:00 clock (stock.time_s; round_s= still sets it for a run), one game
## (stock.games) or best of 3 (MatchSetup.games(): to_win 2, ends swapped, RoundScreen between games only):
##   the set-up   every competitor gets MOVE's RingMoves (RingMoves.install), BendKnock.gravity_override is stock.gravity (20)
##                while the stock ring stands (put back after), each caster's lock_started ends its spawn safety
##                (RingRules.note_lock_started), key 1 readied at the countdown and after every respawn
##                (SwayCaster.ready_default)
##   a fall       RingRules.ko: a 1.4 s centre line ("Into the water: the Tide  ·  2 left", "Last one"), the body hidden and
##                out of reach for respawn.out_wait_s (its collision layer off, kept at its spout so the camera stays
##                valid), its locks and stones dropped (SwayCaster.drop_all); then the spout (RingSpout) on its end's s 12 m
##                line at the grate farther from the nearest foe, respawn.spout_up_m up, MOVE's RingMoves.ride_spout holding
##                him there (left_spout), safe until respawn.safe_after_s after he leaves it or a lock of his starts. No
##                respawn after the last life: his side out -> the game to the other (why "falls"); the final fall's word
##                "Over" over_s, then the screens
##   the clock    at 0:00 more lives wins (why "time"); level: sudden death (everyone at sudden.pct with one life, "Next one
##                in the water loses."), the next fall wins (why "sudden"), a draw after sudden.draw_s
##   the look     on a launch of 18 m/s or more a bigger burst at the hit point (hud.json launch_wake, default false: a 0.5 s
##                wake of the hitter's matter behind the body instead); hud.json respawn_drip (default false)
##   the contract the HUD's PercentBar reads lives_of(b), pct_of(b), ko_line(), sudden_left_s(), event_line(), falls (a line
##                per fall: {at_s, who, by, pct, tag, team, left})
## Practice under stock: no lives and no clock: a fall puts both back (RingPractice.on_out), the % to 0.

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
## The team formats' fighters' own names (data/ring/names.json).
const NAMES_PATH := "res://data/ring/names.json"
## The meta a team format's fighter carries its own name in (name_of).
const NAME_META := &"ring_name"

var level: Node3D
var ring: RingArena
var rules: RingRules
var menu: Node
var player: FrontierPlayer
var foe: NpcFighter
var squad: NpcSquad
## The team formats' other bots: [{bot: NpcFighter, squad: NpcSquad, team: 0 | 1, slot: the side's spawn slot (the player and
## the foe hold slot 0), element}], kept across games as the foe is.
var extras: Array[Dictionary] = []
## This match's elements beyond the player's (MatchSetup.lineup at each restart): the other side's (foe_elements[0] the foe's)
## and the player's team-mates'.
var foe_elements: Array = []
var mate_elements: Array = []
var _coach_t := 0.0
## This match's draw of names (team formats: slot k of team t is named _names[t * 4 + k]).
var _names: Array = []
## The % each fighter dealt this match (instance id -> %; RingRules.pct_dealt), for roster().
var _pct_by := {}
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
## A practice (no rounds, no timer) against a dummy (RingPractice runs it), and its way ("stand" | "block" | "throw").
var practice := false
## The practice: the dummy, its way and its lines (RingPractice; made with the mode).
var practice_ctl: RingPractice
var dummy: String:
	get:
		return practice_ctl.dummy
	set(v):
		practice_ctl.dummy = v
## The dummy's throws slowed (the lessons' guard drill and jump, RingLessons; the owner, 2026-10-05: a beginner beating a fast
## throw): a throw every slow_every_s, its shots flying at slow_speed of their own speed on the same path (data/ring/lessons.json).
var slow_throws: bool:
	get:
		return practice_ctl.slow_throws
	set(v):
		practice_ctl.slow_throws = v
## The dummy's throw instead of its element's strike ("id/mode"; "": screens.json practice.throw; the lessons' jump: fire's Kick).
var throw_override: String:
	get:
		return practice_ctl.throw_override
	set(v):
		practice_ctl.throw_override = v
var round_screen: Node
var match_screen: Node
## The practice's lines (RingPractice's).
var hint: Label:
	get:
		return practice_ctl.hint
var tally_label: Label:
	get:
		return practice_ctl.tally_label
var hint_back: ColorRect:
	get:
		return practice_ctl.hint_back
var _knockout := false
var _guard_took := {}
var _caster_hooked: SwayCaster
## Round 3 (stock): the falls of the match: {game, at_s (into the game), who, by, pct, tag, team, left}; the respawns
## pending ([{body, t}]); the spouts standing; the KO line and its time left; sudden death's start (phase_t), the gravity put
## back after; the bodies' collision layers while hidden.
var falls: Array = []
var _respawns: Array = []
var _spouts := {}
var _ko_line := ""
var _ko_t := 0.0
var _sudden_at := -1.0
var _prev_gravity := 0.0
var _gravity_set := false
var _hidden := {}
var _held_before := {}
var _hooked_casters := {}
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


func _init() -> void:
	practice_ctl = RingPractice.new(self)


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
	if stock():
		_prev_gravity = BendKnock.gravity_override
		BendKnock.gravity_override = RingRules.stock_num("gravity", 20.0)
		_gravity_set = true
		rules.ko.connect(_on_ko)
		rules.pct_dealt.connect(func(by: Node, _b: Node3D, d: float) -> void:
			if by != null and is_instance_valid(by):
				_pct_by[by.get_instance_id()] = float(_pct_by.get(by.get_instance_id(), 0.0)) + d)
		rules.launched.connect(_on_launched)
		rules.hit_safe.connect(_on_hit_safe)
	_build_ui()
	RingPractice.ensure_keys()
	rules.winded.connect(_on_winded)
	menu = RingMenu.install(level if level != null else self, self)
	var parent: Node = level if level != null else self
	round_screen = RoundScreen.install(parent, self)
	match_screen = MatchScreen.install(parent, self)
	# (round 4 VIRAL: the Splash Cam, the highlights, the callouts, photo mode and the clashes; each runs only under stock rules)
	RingReplay.install(self)
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


func _exit_tree() -> void:
	if _gravity_set:
		BendKnock.gravity_override = _prev_gravity
		_gravity_set = false


## The % match (the installed rules' rule set is "stock").
func stock() -> bool:
	return rules != null and rules.rule_set == "stock"


# ---------------------------------------------------------------- the match
## The match from its start with MatchSetup's choices: the score nil, round 1, the player's side at end 0.
func restart() -> void:
	element = MatchSetup.element if MatchSetup.element in Bending.ELEMENTS else "earth"
	var lu := MatchSetup.lineup(_rng, team_n())
	foe_elements = lu["foes"]
	mate_elements = lu["mates"]
	foe_element = String(foe_elements[0])
	_names = _draw_names()
	difficulty = MatchSetup.difficulty
	practice = MatchSetup.practice()
	practice_ctl.reset()
	history = []
	_knockout = false
	to_win = maxi(MatchSetup.rounds_to_win, 1)
	round_s = MatchSetup.round_s if MatchSetup.round_s > 0.0 else RingRules.num("round_s", 180.0)
	if stock():
		# (a game: 3 lives on the 8:00 clock; one game, or best of 3 from the menu: to_win 2)
		to_win = 2 if games() >= 3 else 1
		round_s = _arg_num("round_s", RingRules.stock_num("time_s", 480.0))
		falls = []
		_pct_by = {}
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
		# (the loadout worn for this element, read from the Advancement save at every match start: its fighting style and its
		# live node numbers on the player's body; Classic and every bot read the element's own: BendLoadout)
		BendLoadout.wear_player(player, element)
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
		rules.add(player, 0)
	if keep:
		_ready_foe()
	else:
		_spawn_foe()
	if foe != null:
		rules.add(foe, 1)
	_team_bots()
	rules.reset_round()
	rules.soft_walls = not practice
	if stock():
		_stock_game()
	_new_tally()
	_to("COUNTDOWN")


## The foe of this round (team 1) at the other end: a bot of its element, no gun, held through the countdown.
func _spawn_foe() -> void:
	var r := _make_bot(1, int(RingRules.num("bot_slot", 0.0)), foe_element, _seed + round * 17)
	squad = r.get("squad") as NpcSquad
	foe = r.get("bot") as NpcFighter


## A bot of side `team` at spawn slot `slot` of its end, of element `el`, its dice from `dice_seed`: no gun, the match's
## difficulty, never fleeing or dying, held through the countdown, ring aware. {bot, squad, team, slot, element}; {} none.
func _make_bot(team: int, slot: int, el: String, dice_seed: int) -> Dictionary:
	var xf := ring.spawn(_end(team), slot)
	var faction: String = FACTIONS[team]
	if NpcFactions.get_faction(faction).is_empty():
		if team == 0:
			return {}
		faction = FALLBACK_FACTION
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "ring", "tactics": "bend", "element": el,
			"weapon": "", "sidearm": "", "skill": difficulty, "seed": dice_seed, "y": ring.deck_y()}
	var sq := NpcSquad.spawn(level if level != null else get_parent(), faction, 1, xf.origin, opts)
	var b: NpcFighter = sq.members[0] if sq != null and not sq.members.is_empty() else null
	if b == null:
		return {"squad": sq}
	b.flees = false
	b.calm_s = INF
	b.held = true
	b.no_death = true
	if &"element" in b:
		b.set(&"element", el)
	Bending.of(b).element = el
	_name_bot(b, team, slot, el)
	_ring_aware(b)
	return {"bot": b, "squad": sq, "team": team, "slot": slot, "element": el}


## Bot `b` at slot `slot` of side `team` named: a team format's own name from this match's draw (name_of), else its
## element's competitor name (the Tide).
func _name_bot(b: NpcFighter, team: int, slot: int, el: String) -> void:
	var i := team * 4 + slot
	if team_n() > 1 and i < _names.size():
		b.label = String(_names[i])
		b.set_meta(NAME_META, b.label)
	else:
		b.label = MatchSetup.competitor(el)
		if b.has_meta(NAME_META):
			b.remove_meta(NAME_META)


## Every fighter of the match now, side by side (the match screen's roster in a team format): [{body, name ("You" the
## player's), element, team, mine, falls_dealt (falls of the other side he is credited with), falls_taken, self_falls, pct_dealt,
## mvp (his side's best: falls dealt, then % dealt; none without either)}], team 0 first, the player first on his side.
func roster() -> Array:
	var out: Array = []
	if rules == null:
		return out
	for t in 2:
		var side: Array = []
		for b in rules.sides[t]:
			if not (b is Node3D) or not is_instance_valid(b):
				continue
			var e := {"body": b, "name": "You" if b == player else (name_of(b) if name_of(b) != "" else MatchSetup.competitor(_element_of(b))),
					"element": _element_of(b), "team": t, "mine": b == player, "falls_dealt": 0, "falls_taken": 0, "self_falls": 0,
					"pct_dealt": roundi(float(_pct_by.get((b as Node).get_instance_id(), 0.0))), "mvp": false}
			for f: Dictionary in falls:
				if f.get("who") == b:
					e.falls_taken = int(e.falls_taken) + 1
					if bool(f.get("self", false)) or f.get("by") == b:
						e.self_falls = int(e.self_falls) + 1
				elif f.get("by") == b and int(f.get("team", -1)) != t:
					e.falls_dealt = int(e.falls_dealt) + 1
			if b == player:
				side.push_front(e)
			else:
				side.append(e)
		var best := -1
		for i in side.size():
			var k := int(side[i].falls_dealt) * 100000 + int(side[i].pct_dealt)
			if k > 0 and (best < 0 or k > int(side[best].falls_dealt) * 100000 + int(side[best].pct_dealt)):
				best = i
		if best >= 0:
			side[best].mvp = true
		out.append_array(side)
	return out


## A team format's fighter's own name ("" none: a 1v1's fighters go by their element's competitor name, the player by "you").
static func name_of(b: Variant) -> String:
	return String((b as Node).get_meta(NAME_META, "")) if b is Node and is_instance_valid(b) else ""


## The match's names: names.json's list shuffled by the match's seed (none twice).
func _draw_names() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH)) if FileAccess.file_exists(NAMES_PATH) else null
	var pool: Array = ((d as Dictionary).get("names", []) as Array).duplicate() if d is Dictionary else []
	var r := RandomNumberGenerator.new()
	r.seed = _seed * 31 + 5
	for i in range(pool.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool


## The deck end side `team` holds this game.
func _end(team: int) -> int:
	return player_end if team == 0 else 1 - player_end


## The fighters a side: the ring's format's (RingArena.format: 1, 2 or 4), a practice 1.
func team_n() -> int:
	return 1 if MatchSetup.practice() else MatchSetup.team_size(RingArena.format)


## The team formats' other bots for this game (none in a 1v1 or a practice): each side's slots past the first (the player's and
## the foe's), last game's bot kept when it can stand, else a new one; on the rules' books. Bots no slot wants are let go.
func _team_bots() -> void:
	var n := team_n()
	var want: Array[Dictionary] = []
	for t in 2:
		for slot in range(1, n):
			var el := String(mate_elements[slot - 1] if t == 0 else foe_elements[slot])
			var dice := _seed + round * 17 + 101 * (t + 1) + 7 * slot
			var rec := {}
			for e: Dictionary in extras:
				if int(e.get("team", -1)) == t and int(e.get("slot", -1)) == slot:
					rec = e
			if not rec.is_empty() and _keep_bot(rec.get("bot") as NpcFighter, rec.get("squad") as NpcSquad, el):
				_ready_bot(rec.get("bot") as NpcFighter, rec.get("squad") as NpcSquad, t, slot, el, dice)
			else:
				if not rec.is_empty():
					_drop_squad(rec.get("squad") as NpcSquad)
				rec = _make_bot(t, slot, el, dice)
			if rec.get("bot") == null:
				_drop_squad(rec.get("squad") as NpcSquad)
				continue
			want.append(rec)
			rules.add(rec["bot"] as NpcFighter, t)
	for e: Dictionary in extras:
		var kept := false
		for w: Dictionary in want:
			kept = kept or w.get("squad") == e.get("squad")
		if not kept:
			_drop_squad(e.get("squad") as NpcSquad)
	extras = want


## The bots of both sides (the foe first, then the team formats' others).
func bots() -> Array[NpcFighter]:
	var out: Array[NpcFighter] = []
	if foe != null and is_instance_valid(foe):
		out.append(foe)
	for e: Dictionary in extras:
		var b := e.get("bot") as NpcFighter
		if b != null and is_instance_valid(b):
			out.append(b)
	return out


## The bot's ring awareness, its bending's own reading: where it may stand, how far an open end lies along a way.
func _ring_aware(b: NpcFighter) -> void:
	var bend: Variant = b.brain.bending if b.brain != null else null
	if bend is Object and bend != null:
		var o := bend as Object
		if &"bounds_fn" in o:
			o.set(&"bounds_fn", rules.bounds_fn_for(b))
		if &"edge_fn" in o:
			o.set(&"edge_fn", rules.edge_along)


## Whether last round's bot can stand for this one: there, alive and not down, no wound, broken bone or limp of its own (a
## bend's slow is not its own: make_whole ends it), of the element and difficulty the match asks for now (a rematch may ask
## for another), with its bending mind (tactics "bend").
func _keep_foe() -> bool:
	return _keep_bot(foe, squad, foe_element)


## _keep_foe's test for bot `b` of squad `sq`, asked to play element `el`.
func _keep_bot(b: NpcFighter, sq: NpcSquad, el: String) -> bool:
	if b == null or not is_instance_valid(b) or not b.is_inside_tree() or sq == null or not is_instance_valid(sq):
		return false
	if b.is_dead() or b.down or b.left_field or b.arm_broken != "" or b.pool > 0.0 or b.mortal_left > 0.0:
		return false
	var own_limp := float(b.get_meta(&"bend_limp", b.limp))
	if own_limp < 1.0:
		return false
	return b.element == el and b.skill_preset == difficulty and b.brain != null \
			and b.brain.bending != null


## Last round's bot at this round's end as a new one would stand there (_spawn_foe): made whole (make_whole: no knock, root,
## slow or anchor), its health and water full, its feet and hands free, held through the countdown, its home the new spot,
## its own dice seeded as a new bot's of this round would be; and a new mind (NpcBrain: the target, the lock, the bending's
## books, its catches answered and its cools, all as at a spawn; the old one's lock let go and its held zones ended first).
func _ready_foe() -> void:
	_ready_bot(foe, squad, 1, int(RingRules.num("bot_slot", 0.0)), foe_element, _seed + round * 17)


## _ready_foe's making ready of bot `b` (squad `sq`) at slot `slot` of side `team`'s end, element `el`, its dice from `dice_seed`.
func _ready_bot(b: NpcFighter, sq: NpcSquad, team: int, slot: int, el: String, dice_seed: int) -> void:
	var xf := ring.spawn(_end(team), slot)
	make_whole(b)
	if b.has_meta(&"bend_limp"):
		b.limp = float(b.get_meta(&"bend_limp"))
		b.remove_meta(&"bend_limp")
	b.feet_held = false
	b.health = b.health_max
	b.held = true
	b.action = ""
	b.face_lock = Vector3.INF
	b.hits_taken = 0
	b.killed_by = null
	var dice := RandomNumberGenerator.new()
	dice.seed = dice_seed                    # (_make_bot's squad seed: its first draw is a new fighter's own seed)
	b.rng_seed = dice.randi() | 1
	b.rng.seed = b.rng_seed
	b.home = Vector3(xf.origin.x, ring.deck_y(), xf.origin.z)
	sq.origin = xf.origin
	RingLevel.place(b, xf)
	b.halt()
	if b.brain.bending != null:
		b.brain.bending.on_exit()
	b.brain = NpcBrain.new(b)
	var bd := Bending.of(b)
	bd.element = el
	_name_bot(b, team, slot, el)
	_ring_aware(b)


func _drop_foe() -> void:
	_drop_squad(squad)
	squad = null
	foe = null


func _drop_squad(sq: NpcSquad) -> void:
	if sq != null and is_instance_valid(sq):
		if sq.get_parent() != null:
			sq.get_parent().remove_child(sq)    # (out at once: the interactor and the senses forget him)
		sq.queue_free()


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
	_ko_t = maxf(_ko_t - dt, 0.0)
	if stock():
		_stock_respawns(dt)
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
			if rules.team_mode() and not practice:
				_coach(dt)
			if practice:
				practice_ctl.step(dt)
			elif stock():
				_stock_clock()
			elif foe == null or not is_instance_valid(foe):
				_end_round(0, "winded")
			elif round_left_s() <= 0.0:
				_time_out()
		"OVER":
			var wait := RingRules.num("pause_s", 6.0)
			if stock() and decided():
				wait = RingRules.stock_num("over_s", 2.2)
			if phase_t >= wait or _skip:
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
		foe.held = practice                  # (the dummy is held at its end; its casts are begun by RingPractice.step)
		if foe.brain != null and player != null:
			foe.brain.told(player, player.global_position)
	for b in bots():
		if b != foe:
			b.held = false
	_coach_t = 0.0
	if rules.team_mode() and not practice:
		_coach(0.0)
	rules.live = true
	practice_ctl.arm()
	if stock():
		for b in competitors():
			_ready_key1(b)
	_sting("go")
	if not practice:
		_music(true)
	_to("FIGHT")


## THE TEAM COACH (team formats, FIGHT): each bot is handed the nearest opponent still in play, counted spread_m farther for
## each of its side already on him (a side does not all pile on one); every every_s it looks again and switches only for one
## better by keep_m; a bot whose target is out of play (in the water, on the way back, out of the round) is handed another at
## once. rules.json coach.
func _coach(dt: float) -> void:
	_coach_t -= dt
	var again := _coach_t <= 0.0
	if again:
		_coach_t = _coach_num("every_s", 1.5)
	var spread := _coach_num("spread_m", 6.0)
	var keep := _coach_num("keep_m", 3.0)
	for t in 2:
		var mine: Array[NpcFighter] = []
		for b in rules.sides[t]:
			if b is NpcFighter and is_instance_valid(b) and (b as NpcFighter).brain != null:
				mine.append(b as NpcFighter)
		var on := {}
		for b in mine:
			var cur := b.brain.target
			if _fair_target(cur, t):
				on[cur.get_instance_id()] = int(on.get(cur.get_instance_id(), 0)) + 1
		for b in mine:
			if b.held or not in_play(b):
				continue
			var cur := b.brain.target
			var cur_ok := _fair_target(cur, t)
			if cur_ok and not again:
				continue
			var best: Node3D = null
			var best_d := INF
			var cur_d := INF
			for o in rules.sides[1 - t]:
				if not _fair_target(o, t):
					continue
				var n := int(on.get((o as Node3D).get_instance_id(), 0)) - (1 if o == cur else 0)
				var d := b.global_position.distance_to((o as Node3D).global_position) + spread * float(n)
				if o == cur:
					cur_d = d
				if d < best_d:
					best_d = d
					best = o as Node3D
			if best == null or best == cur or (cur_ok and best_d > cur_d - keep):
				continue
			if cur_ok:
				on[cur.get_instance_id()] = int(on.get(cur.get_instance_id(), 1)) - 1
			on[best.get_instance_id()] = int(on.get(best.get_instance_id(), 0)) + 1
			b.brain.focus(best)


## `b` can be fought now: a competitor able to fight, not out of the round (the zones) nor away (the % ring's water, a
## respawn, no lives left).
func in_play(b: Variant) -> bool:
	# (a side's list can still hold a fighter freed since — a team format's bot made again: `is` on it is a script error;
	# RingSpectate walks those lists after the player's last life)
	if not is_instance_valid(b) or not (b is Node3D) or not NpcSenses.can_fight(b) or rules.team_of(b as Node) < 0:
		return false
	return not rules.is_out(b as Node) and not (stock() and rules.is_away(b as Node))


## `o` a target for side `t`'s bots: in play, of the other side.
func _fair_target(o: Variant, t: int) -> bool:
	return o != null and is_instance_valid(o) and in_play(o) and rules.team_of(o as Node) == 1 - t


static func _coach_num(key: String, def: float) -> float:
	var c: Variant = RingRules.data().get("coach", {})
	return float((c as Dictionary).get(key, def)) if c is Dictionary else def


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
	if why in ["ringout", "winded", "knockout", "falls", "sudden"]:
		ringouts += 1
	_respawns.clear()
	_close_tally()
	_count_catches()
	history.append({"round": round, "winner": team, "result": last_result, "why": why,
			"at_s": maxf(round_s - _left_at_end, 0.0), "tally": round_tally.duplicate(true),
			"pct_tally": rules.tally.duplicate(true) if stock() else [{}, {}],
			"lives": [rules.team_stocks(0), rules.team_stocks(1)] if stock() else [0, 0]})
	for b in bots():
		b.held = true
	if player != null and is_instance_valid(player):
		player.drag_speed_cap = INF
	_music(false)
	_sting("ringout" if why in ["ringout", "falls", "sudden"] else "over")
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
	if not stock() and rules.team_mode() and who is NpcFighter and is_instance_valid(who):
		(who as NpcFighter).held = true      # (out: he sits the round out)
	rang_out.emit(who, by)


func _on_side_out(side: int) -> void:
	if practice:
		practice_ctl.on_out()
		return
	if stock():
		_end_round(1 - side, "sudden" if rules.sudden else "falls")
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
	practice_ctl.on_winded(who)


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
		if practice_ctl.key(e):
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
## The centre words (round 4, HUD: hud.json centre): the banner (the countdown, the fall's line, "Over") centre_px at
## banner_at of the height (44 px at 30%: clear of the plates, the clock and the event line at 1280x720, 1440x900 and
## 1920x1080), the sub line under it, the top line under the plates. One ink outline, as the strip's.
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "RingText"
	ui.layer = 15
	add_child(ui)
	var cc: Variant = PercentBar.hud_cfg().get("centre", {})
	var cfg: Dictionary = cc if cc is Dictionary else {}
	var at := float(cfg.get("banner_at", 0.3))
	var bh := float(cfg.get("banner_h", 56.0))
	banner = _label(int(cfg.get("banner_px", 44)), MenuUI.INK)
	banner.anchor_top = at
	banner.anchor_bottom = at
	banner.offset_top = -bh * 0.5
	banner.offset_bottom = bh * 0.5
	ui.add_child(banner)
	var sp := float(cfg.get("sub_px", 22.0))
	sub = _label(int(sp), MenuUI.DIM)
	sub.anchor_top = at
	sub.anchor_bottom = at
	sub.offset_top = bh * 0.5 + float(cfg.get("sub_gap", 2.0))
	sub.offset_bottom = sub.offset_top + sp + 10.0
	ui.add_child(sub)
	var tp := float(cfg.get("top_px", 17.0))
	top = _label(int(tp), MenuUI.DIM)
	top.anchor_top = 0.0
	top.anchor_bottom = 0.0
	top.offset_top = float(cfg.get("top_y", 112.0))
	top.offset_bottom = top.offset_top + tp + 8.0
	ui.add_child(top)
	for l: Label in [banner, sub, top]:
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 0.88))
		l.add_theme_constant_override("outline_size", int(BendStrip.snum("ink_px", 5.0)))
	practice_ctl.build_ui(ui)             # (practice: what the dummy does and the keys, under the HUD's match bar; the tally)


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
			elif stock():
				var head := words("game") % round if to_win > 1 else ""
				b = head if phase_t < RingRules.num("round_show_s", 0.8) and head != "" else str(maxi(ceili(cd - phase_t), 1))
				s = score_text() if to_win > 1 else ""
			else:
				b = words("round") % round if phase_t < RingRules.num("round_show_s", 0.8) else str(maxi(ceili(cd - phase_t), 1))
				s = words("sub_countdown") % [score_text(), MatchSetup.rounds_label(to_win), difficulty]
		"FIGHT":
			if practice:
				b = pword("banner") if phase_t < RingRules.num("go_show_s", 1.2) else (_note if _note_t > 0.0 else "")
			elif stock() and ko_line() != "":
				b = ko_line()
			else:
				b = words("go") if phase_t < RingRules.num("go_show_s", 1.2) else (_note if _note_t > 0.0 else "")
		"OVER":
			if stock() and decided():
				b = "" if RingMoment.busy() or RingReplay.holding() else words("over")      # (round 4 IMPACT: the word waits for the last fall's slow beat)
			elif round_screen == null or not is_instance_valid(round_screen):
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
	practice_ctl.paint()
	# (the HUD's strip shows the round, the time and the score once it has one: set_arena)
	var hud_has := player != null and is_instance_valid(player) and player.hud != null and player.hud.has_method(&"set_arena")
	top.text = "" if hud_has or phase == "DONE" else words("top") % [MatchSetup.sport(), round, floori(round_left_s() / 60.0),
			floori(fmod(round_left_s(), 60.0)), score_text()]


## The round's result in words.
func result_line() -> String:
	var foe_n := foe_name()
	if last_why in ["falls", "time", "sudden"] and last_result != "draw":
		var key := ("win_" if last_result == "win" else "loss_") + last_why
		return words(key) % foe_n if words(key).contains("%s") else words(key)
	if last_why == "sudden_draw":
		return words("sudden_draw")
	match last_why:
		"ringout", "winded", "territory", "health", "knockout":
			if last_result == "win":
				return words("win_" + last_why) % foe_n if words("win_" + last_why).contains("%s") else words("win_" + last_why)
			return words("loss_" + last_why) % foe_n if words("loss_" + last_why).contains("%s") else words("loss_" + last_why)
	return words("draw")


# ---------------------------------------------------------------- the tally (the screens')
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


# ---------------------------------------------------------------- practice (RingPractice's; the old names forward)
## data/ring/screens.json practice's number `key`.
static func _pnum(key: String, def: float) -> float:
	return RingPractice.pnum(key, def)


## A practice word (screens.json practice.words).
static func pword(key: String) -> String:
	return RingPractice.pword(key)


## The countdown's length: the rules' (3 s), a practice's short one.
func countdown_s() -> float:
	return _pnum("countdown_s", 1.0) if practice else RingRules.num("countdown_s", 3.0)


func practice_line() -> String:
	return practice_ctl.practice_line()


func cycle_dummy() -> void:
	practice_ctl.cycle_dummy()


func reset_positions() -> void:
	practice_ctl.reset_positions()


func throw_every_s() -> float:
	return practice_ctl.throw_every_s()


func _pmove(what: String) -> String:
	return practice_ctl.pmove(what)


static func dummy_guard(bend: Object) -> Dictionary:
	return RingPractice.dummy_guard(bend)


# ---------------------------------------------------------------- round 3: the % match (stock)
## The games in a match (1, or 3: best of 3): the user arg games=, else MatchSetup.games() (BOTS' Esc menu), else
## rules.json stock.games.
func games() -> int:
	var g := int(_arg_num("games", 0.0))
	if g <= 0:
		g = maxi(MatchSetup.games(), int(RingRules.stock_num("games", 1.0)))
	return 3 if g >= 3 else 1


## A number user arg `key`= (def without one).
static func _arg_num(key: String, def: float) -> float:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with(key + "=") and kv.get_slice("=", 1).is_valid_float():
			return float(kv.get_slice("=", 1))
	return def


## Every competitor the rules count (both sides).
func competitors() -> Array:
	var out: Array = []
	if rules == null:
		return out
	for t in 2:
		for b in rules.sides[t]:
			if b is Node3D and is_instance_valid(b):
				out.append(b)
	return out


## `b` a competitor of `team` mid-match (3v3's more bots, tests): on the rules' books, with its RingMoves and its caster's
## hooks (stock).
func join(b: Node3D, team: int) -> void:
	rules.add(b, team)
	if stock():
		_equip(b)
		if rules.falls.is_empty():
			rules.reset_lives()              # (a side grown before the first fall: every one at team.stocks)


## A game's start (stock): every competitor with its RingMoves and its hooks, shown and solid, lives full, % 0, key 1 readied.
func _stock_game() -> void:
	rules.lives_on = not practice
	var sp := get_node_or_null(RingSpectate.NODE_NAME) as RingSpectate
	if sp != null:
		sp.stop()                            # (a new game: your own camera again)
	for b in competitors():
		_equip(b)
		_hide(b, false)
	_held_before.clear()
	_respawns.clear()
	for s in _spouts.values():
		if is_instance_valid(s):
			(s as RingSpout).queue_free()
	_spouts.clear()
	_ko_line = ""
	_ko_t = 0.0
	_sudden_at = -1.0
	rules.reset_game()
	for b in competitors():
		_ready_key1(b)


## `b` made ready for the % ring: MOVE's RingMoves on it, its caster's lock starts ending its spawn safety.
func _equip(b: Node3D) -> void:
	RingMoves.install(b)
	if b == player:
		RingAssist.install(b)                # (round 4 SIMPLE: the Basic controls' helpers; idle under Full)
	var sc := SwayCaster.of(b)
	if sc != null and not _hooked_casters.has(sc.get_instance_id()):
		_hooked_casters[sc.get_instance_id()] = true
		sc.lock_started.connect(func(_m: String, _t: Node3D) -> void:
			if rules != null and is_instance_valid(b):
				rules.note_lock_started(b))


## `b`'s key 1 readied (SwayCaster.ready_default: at the countdown, after a respawn).
func _ready_key1(b: Node3D) -> void:
	var sc := SwayCaster.of(b)
	if sc != null:
		sc.ready_default()


## The clock (stock): at 0:00 more lives wins; level, sudden death; in sudden death a draw after sudden.draw_s.
func _stock_clock() -> void:
	if rules.sudden:
		if phase_t - _sudden_at >= RingRules.sub_num("sudden", "draw_s", 60.0):
			_end_round(-1, "sudden_draw")
		return
	if round_left_s() > 0.0:
		return
	var a := rules.team_stocks(0)
	var b := rules.team_stocks(1)
	if a != b:
		_end_round(0 if a > b else 1, "time")
		return
	# (level at the bell: sudden death; everyone back on the deck first)
	for p: Dictionary in _respawns:
		_do_respawn(p.body as Node3D)
	_respawns.clear()
	rules.start_sudden()
	_sudden_at = phase_t
	_note = words("sudden")
	_note_t = 2.5


## Seconds of sudden death left (0 when not in it).
func sudden_left_s() -> float:
	if rules == null or not rules.sudden:
		return 0.0
	return maxf(RingRules.sub_num("sudden", "draw_s", 60.0) - (phase_t - _sudden_at), 0.0)


## b's lives left (stock; 0 none).
func lives_of(b: Node) -> int:
	return rules.stocks_of(b) if rules != null and stock() else 0


## b's % now (stock).
func pct_of(b: Node) -> float:
	return rules.pct_of(b) if rules != null and stock() else 0.0


## The fall's centre line now ("" none).
func ko_line() -> String:
	return _ko_line if _ko_t > 0.0 else ""


## The match's % tally for team `t` (stock; the match screen's, spec §10.6): the games' RingRules tallies summed (the longest
## string and the highest % survived the best of them), the catches its guards took.
func stock_tally(t: int) -> Dictionary:
	var out := {}
	for h: Dictionary in history:
		var pt: Dictionary = (h.get("pct_tally", [{}, {}]) as Array)[t]
		for k: String in pt:
			if k in ["string_hits", "string_pct", "best_pct"]:
				continue
			out[k] = float(out.get(k, 0.0)) + float(pt[k])
		if int(pt.get("string_hits", 0)) > int(out.get("string_hits", 0)) or (int(pt.get("string_hits", 0)) == int(out.get("string_hits", 0))
				and float(pt.get("string_pct", 0.0)) > float(out.get("string_pct", 0.0))):
			out["string_hits"] = int(pt.get("string_hits", 0))
			out["string_pct"] = float(pt.get("string_pct", 0.0))
		out["best_pct"] = maxf(float(out.get("best_pct", 0.0)), float(pt.get("best_pct", 0.0)))
		out["catches"] = float(out.get("catches", 0.0)) + float(((h.tally as Array)[t] as Dictionary).get("catches", 0))
	return out


## RingRules.ko: a life gone (stock). The line, the fall's record, the body hidden and its respawn set (lives left), its
## locks and stones dropped; Practice: both put back (RingPractice through side_out).
func _on_ko(b: Node3D, by: Node, pct: float, tag: String, left: int) -> void:
	var t := rules.team_of(b)
	var at_s := maxf(round_s - round_left_s(), 0.0)
	falls.append({"game": round, "at_s": at_s, "who": b, "by": by, "pct": pct, "tag": tag, "team": t, "left": left,
			"self": by == null})
	var sc := SwayCaster.of(b)
	if sc != null:
		sc.drop_all()
	if ring != null and ring.water != null and ring.is_out(b.global_position) and not ring.water.holds(b):
		ring.water.curtain_splash(b.global_position, (b as CharacterBody3D).velocity.length() if b is CharacterBody3D else 8.0)
	if practice:
		return
	var who := words("ko_you") if b == player else (name_of(b) if name_of(b) != "" else words("ko_the") % MatchSetup.competitor(_element_of(b)))
	_ko_line = words("ko_line") % [who, words("ko_last") if left == 1 else (words("ko_left") % left)] if left > 0 else ""
	if b == player and left <= 0 and team_n() > 1:
		RingSpectate.start(self)             # (your last life gone in a team format: watch your team play on)
	_ko_t = RingRules.stock_num("ko_line_s", 1.4) if left > 0 else 0.0
	if left <= 0:
		_hide(b, true)
		return
	_hide(b, true)
	_respawns.append({"body": b, "t": RingRules.sub_num("respawn", "out_wait_s", 1.6)})


func _element_of(b: Node) -> String:
	var el := BendPoses.element_of(b)
	if el == "" and b is NpcFighter:
		el = String((b as NpcFighter).get(&"element"))
	return el if el in Bending.ELEMENTS else "earth"


## The respawns pending: each at its time, in game time.
func _stock_respawns(dt: float) -> void:
	if _respawns.is_empty():
		return
	var due: Array = []
	for p: Dictionary in _respawns:
		p["t"] = float(p.t) - dt
		if float(p.t) <= 0.0:
			due.append(p)
	for p: Dictionary in due:
		_respawns.erase(p)
		if phase == "FIGHT" and is_instance_valid(p.body):
			_do_respawn(p.body as Node3D)


## `b` hidden out of play (its collision layer off, still, held, kept at its end's spout so the camera stays valid) or
## shown again.
func _hide(b: Node3D, on: bool) -> void:
	if b == null or not is_instance_valid(b):
		return
	var id := b.get_instance_id()
	if on:
		if not _hidden.has(id) and b is CollisionObject3D:
			_hidden[id] = (b as CollisionObject3D).collision_layer
			(b as CollisionObject3D).collision_layer = 0
		b.visible = false
		var e := rules.end_of(b)
		if e >= 0 and ring != null:
			var at := ring.spout_at(e, 0)
			b.global_position = at + Vector3.UP * 0.1
			if b is CharacterBody3D:
				(b as CharacterBody3D).velocity = Vector3.ZERO
		if b == player:
			player.drag_speed_cap = 0.0
			_hold_casts(true)
		elif b is NpcFighter:
			if not _held_before.has(id):
				_held_before[id] = (b as NpcFighter).held       # (a held one, Practice's dummy, stays held after)
			(b as NpcFighter).held = true
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
		return
	if _hidden.has(id) and b is CollisionObject3D:
		(b as CollisionObject3D).collision_layer = int(_hidden[id])
	_hidden.erase(id)
	b.visible = true


## `b` back on the spout (spec §7.2): the grate on his end's s 12 m line farther from the nearest foe, spout_up_m up, facing
## the deck's middle; MOVE's ride_spout holds him there (left_spout ends it), else he stands on the grate; safe until
## safe_after_s after he leaves it or any lock of his starts.
func _do_respawn(b: Node3D) -> void:
	if b == null or not is_instance_valid(b) or rules.is_gone(b):
		return
	var e := rules.end_of(b)
	var slots := mini(ring.spout_count(), maxi(team_n(), 2)) if rules.team_mode() else 2
	var best := ring.spout_at(e, 0)
	var best_d := -INF
	for k in slots:
		var p := ring.spout_at(e, k)
		var near := INF
		for o in rules.sides[1 - rules.team_of(b)]:
			if is_instance_valid(o) and not rules.is_away(o):
				near = minf(near, (o as Node3D).global_position.distance_to(p))
		if near > best_d + 0.01:
			best_d = near
			best = p
	_hide(b, false)
	var up := RingRules.sub_num("respawn", "spout_up_m", 3.0)
	var face := ring.center() - best
	face.y = 0.0
	var xf := Transform3D(Basis.looking_at(face.normalized() if face.length() > 0.1 else -ring.axis(), Vector3.UP), best + Vector3.UP * up)
	RingLevel.place(b, xf)
	if b == player:
		player.drag_speed_cap = INF
		_hold_casts(false)
	elif b is NpcFighter:
		(b as NpcFighter).held = bool(_held_before.get(b.get_instance_id(), false))
	_held_before.erase(b.get_instance_id())
	var rm := RingMoves.of(b)
	var hold := RingRules.sub_num("respawn", "spout_s", 3.0)
	if rm != null:
		rm.ride_spout(b.global_position, hold)
	var held := rm != null and rm.on_spout()
	if not held:
		RingLevel.place(b, Transform3D(xf.basis, best))         # (nothing holds him up: he stands on the grate)
	var sp := RingSpout.raise(level if level != null else self, best, b, hold if held else 0.6)
	_spouts[b.get_instance_id()] = sp
	if held:
		rm.left_spout.connect(func() -> void:
			if rules != null and is_instance_valid(b):
				rules.left_spout(b)
			if is_instance_valid(sp):
				sp.sink(), CONNECT_ONE_SHOT)
	rules.respawn(b, held)
	_ready_key1(b)
	if bool(PercentBar.hud_cfg().get("respawn_drip", false)):
		RingSpout.drip(b, float(PercentBar.hud_cfg().get("drip_s", 1.5)))


## RingRules.launched (stock): a bigger burst at the hit point at launch_wake.mps or more (hud.json launch_wake false), or
## the wake of the hitter's matter behind the body for wake_s (launch_wake true).
func _on_launched(b: Node3D, v: Vector3, _hs: float, by: Node, _tag: String) -> void:
	var cfg := PercentBar.hud_cfg()
	if v.length() < float(cfg.get("wake_mps", 18.0)) or b == null or not is_instance_valid(b):
		return
	var kind := _element_of(by) if by != null and is_instance_valid(by) else "air"
	var mat := {"earth": "stone", "water": "water", "fire": "fire", "air": "air"}.get(kind, "air") as String
	if bool(cfg.get("launch_wake", false)):
		var g := BendLooks.trail(b, mat, 0.3)
		if g != null:
			g.position = Vector3(0.0, 1.0, 0.0)
			get_tree().create_timer(float(cfg.get("wake_s", 0.5)), false).timeout.connect(func() -> void:
				if is_instance_valid(g):
					BendLooks.stop_trail(g))
	else:
		BendLooks.burst(b.global_position + Vector3.UP * 1.0, mat, int(cfg.get("burst_n", 40)), v.normalized(), 70.0,
				float(cfg.get("burst_mps", 7.0)), 0.4)


## RingRules.hit_safe: the hiss and the splash-through at the hit point (an effect of the hit, never a mark on him).
func _on_hit_safe(b: Node3D, by: Node, point: Vector3) -> void:
	var d := Vector3.FORWARD
	if by is Node3D and is_instance_valid(by):
		d = b.global_position - (by as Node3D).global_position
	RingSpout.safe_hit(point, d)
