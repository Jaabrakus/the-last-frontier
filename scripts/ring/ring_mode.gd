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
##   never dies   0 health in the ring is winded (RingRules): pushed back a zone, health to 40%; no fall hurts
##   the screen   plain text only on its own layer (the round, the countdown, the result, the score); the full strip is
##                the HUD's (FrontierHUD.set_arena). Nothing is drawn on or over the opponent
##   sound        a fight cue if MusicDirector has one (rules.json fight_cues), stings from the existing sounds
## THE CONTRACT (group &"ring_match"; the HUD and the bots read it, through get() / has_method()):
##   round (int, from 1), score (Vector2i: x the player's side, y the other), phase ("COUNTDOWN" | "FIGHT" | "OVER" |
##   "DONE"), round_left_s(), side_of(body) -> 0 the player's side, 1 the other, -1 none; confined_of(body) -> 1..3 (0
##   none); end_of(body) -> the deck end it holds (RingArena side)
##   signals phase_changed(phase), knocked_back(who, from_zone, to_zone), rang_out(who, by), round_over(result, why) with
##   result "win" | "loss" | "draw" as the player's side sees it and why "ringout" | "winded" | "territory" | "health" |
##   "time", match_over(winner): 0 the player's side, 1 the other, -1 a drawn match
##   restart(), next_round(), stats, ringouts, self_outs, rounds_played, foe, rules, last_result, last_why, last_by

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
	menu = RingMenu.install(level if level != null else self, self)
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
		stats[t] = {"knock_backs": 0, "hits": 0, "rounds": 0, "catches": 0}
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
	_spawn_foe()
	if foe != null:
		rules.add(foe, 1)
	rules.reset_round()
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
	# (ring awareness, the bot's own reading: where it may stand, how far an open end lies along a way)
	var bend: Variant = foe.brain.bending if foe.brain != null else null
	if bend is Object and bend != null:
		var o := bend as Object
		if &"bounds_fn" in o:
			o.set(&"bounds_fn", rules.bounds_fn_for(foe))
		if &"edge_fn" in o:
			o.set(&"edge_fn", rules.edge_along)


func _drop_foe() -> void:
	if squad != null and is_instance_valid(squad):
		if squad.get_parent() != null:
			squad.get_parent().remove_child(squad)  # (out at once: the interactor and the senses forget him)
		squad.queue_free()
	squad = null
	foe = null


## `b` whole for a round: alive and full, back on its feet, no knock, no root, slow or anchor, no lock held.
func make_whole(b: Node3D) -> void:
	for key: StringName in [&"bend_root", &"bend_slow", &"bend_anchor", &"bend_redirect_lightning", &"bend_brace"]:
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
			var n := ceili(RingRules.num("countdown_s", 3.0) - phase_t)
			if n != _count_said and phase_t >= RingRules.num("round_show_s", 0.8) and n > 0:
				_count_said = n
				_sting("count")
			if phase_t >= RingRules.num("countdown_s", 3.0):
				_fight()
		"FIGHT":
			if foe == null or not is_instance_valid(foe):
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
		foe.held = false
		if foe.brain != null and player != null:
			foe.brain.told(player, player.global_position)
	rules.live = true
	_sting("go")
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
	if why in ["ringout", "winded"]:
		ringouts += 1
	_count_catches()
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
	return score.x >= to_win or score.y >= to_win or round >= int(RingRules.num("max_rounds", 7.0))


func _done() -> void:
	winner = 0 if score.x > score.y else (1 if score.y > score.x else -1)
	_sting("match")
	_to("DONE")
	match_over.emit(winner)


func _on_knocked_back(who: Node3D, from_zone: int, to_zone: int) -> void:
	var t := rules.team_of(who)
	if t >= 0:
		stats[1 - t]["knock_backs"] = int(stats[1 - t].get("knock_backs", 0)) + 1
	if who == player:
		_note = words("pushed") % to_zone
		_note_t = 1.6
	knocked_back.emit(who, from_zone, to_zone)


func _on_rang_out(who: Node3D, by: Node) -> void:
	last_by = by
	if by == null or not is_instance_valid(by) or by == who:
		self_outs += 1
	rang_out.emit(who, by)


func _on_side_out(side: int) -> void:
	var why := String(rules.last_out.get("why", "ringout"))
	_end_round(1 - side, why)


func _count_catches() -> void:
	stats[0]["hits"] = rules.knocks.x + int(stats[0].get("hits", 0))
	stats[1]["hits"] = rules.knocks.y + int(stats[1].get("hits", 0))
	# (the bot's own count, NpcBending.catches; a new bot each round, so the match's is the sum of the rounds')
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
	if phase != "OVER" or not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	if (e as InputEventKey).physical_keycode == KEY_SPACE:
		_skip = true


# ---------------------------------------------------------------- sound
func _sting(key: String) -> void:
	var s: Variant = (RingRules.data().get("stings", {}) as Dictionary).get(key)
	if not (s is Array) or (s as Array).size() < 3 or not Sfx.has(StringName(String(s[0]))):
		return
	Sfx.play_2d(StringName(String(s[0])), float(s[1]), float(s[2]))


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
			var cd := RingRules.num("countdown_s", 3.0)
			b = words("round") % round if phase_t < RingRules.num("round_show_s", 0.8) else str(maxi(ceili(cd - phase_t), 1))
			s = words("sub_countdown") % [score_text(), MatchSetup.rounds_label(to_win), difficulty]
		"FIGHT":
			b = words("go") if phase_t < RingRules.num("go_show_s", 1.2) else (_note if _note_t > 0.0 else "")
		"OVER":
			b = result_line()
			s = score_text()
			if not decided():
				s += "  ·  " + words("next") % ceili(maxf(RingRules.num("pause_s", 6.0) - phase_t, 0.0))
		"DONE":
			b = words("match_win") if winner == 0 else (words("match_draw") if winner < 0 else words("match_loss") % foe_name())
			s = score_text() + "  ·  " + words("done_hint")
	banner.text = b
	sub.text = s
	# (the HUD's strip shows the round, the time and the score once it has one: set_arena)
	var hud_has := player != null and is_instance_valid(player) and player.hud != null and player.hud.has_method(&"set_arena")
	top.text = "" if hud_has or phase == "DONE" else words("top") % [MatchSetup.sport(), round, floori(round_left_s() / 60.0),
			floori(fmod(round_left_s(), 60.0)), score_text()]


## The round's result in words.
func result_line() -> String:
	var foe_n := foe_name()
	match last_why:
		"ringout", "winded", "territory", "health":
			if last_result == "win":
				return words("win_" + last_why) % foe_n if words("win_" + last_why).contains("%s") else words("win_" + last_why)
			return words("loss_" + last_why) % foe_n if words("loss_" + last_why).contains("%s") else words("loss_" + last_why)
	return words("draw")
