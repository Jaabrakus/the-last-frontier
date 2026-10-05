class_name DuelMode
extends Node
## THE DUEL (test): the player against one soldier who fights well (the user, 2026-10-04: "lets build a test game where it is
## 1v1 npc can find cover aim and etc"). Started from the main menu's "Duel (test): 1 v 1" row (incoming) or the user arg
## mode=duel (the tests): the main level as ever (the terrain, the walk grid, NpcCover, the anatomy hits, the HUD) with the
## story off and no survival needs (no SurvivalBridge: no hunger, cold or the core's clock; no household, no saves, no wild
## animals: FrontierLevel), the clock held by day (HOUR, clear weather), and the arena staged on the open land (DuelArena).
##   the kit      the player's own (the musket, the pistol, the bow, the thrown weapons; the Sway's spells free to use as
##                they are now), loaded and full again each round (WeaponState as it was at the duel's start)
##   the foe      a French marine of the troupes de la marine (FACTION: hostile to the player) with his musket and its butt
##                (the fighters carry no pistol yet), fighting from cover (NpcFighter.tactics "cover": NpcSkirmish), aiming by
##                the difficulty (NpcFighter.SKILLS: easy, normal, hard), never running from his wounds (he falls back and
##                fights on: flees off) nor giving up the fight (calm_s never), his covers kept to the arena (bounds); told
##                at the start where the player stands (a duel: each knows where the other begins), then only what he sees
##                and hears
##   a round      COUNTDOWN (COUNTDOWN_S: both held at their spawns, "Round 2", 3, 2, 1, "Fight"), FIGHT until one falls
##                (dead; for the marine also out of the fight: down, yielding, running with his arm broken) or ROUND_S runs
##                out (a draw), OVER: the banner with the result and the score, PAUSE_S to look (M, or E at him: InspectView on
##                the fallen marine; the pause waits while the view is open, the game paused under it), then the next round
##                with the sides swapped (player_side), the arena put back (DuelArena.rebuild, clear_dropped), both whole at
##                their spawns; first to TO_WIN wins the duel (DONE: the banner stays; Esc for the menu)
##   Esc          DuelMenu: resume, restart the duel, the difficulty (easy / normal / hard: the marine's aim, at once),
##                settings, the main menu, quit
## Text only on the screen (the round, the countdown, the result and the score, a small line at the top): no cue of where
## the marine is (the owner's rule: no markers on enemies).
##   DuelMode.requested() / take_request()   the level asks; DuelMode.find(tree); DuelMode.install(level, player)
##   restart(), set_difficulty(d), phase, round, score (x the player's, y the marine's), npc, arena, last_result

signal round_over(result: String, score: Vector2i)
signal duel_over(result: String)

enum Phase { COUNTDOWN, FIGHT, OVER, DONE }
const PHASES := ["COUNTDOWN", "FIGHT", "OVER", "DONE"]
const NODE_NAME := "DuelMode"
const COUNTDOWN_S := 3.0
const ROUND_S := 150.0
const PAUSE_S := 7.0
const FIGHT_SHOW_S := 1.2
const TO_WIN := 3
const FACTION := "french_marine"
## What the foe is called on the screen (a bender: no gun).
const FOE_LABEL := "Earthbender"
## How the foe fights: "bend" (NpcBending, the duel as it is played) or "cover" (the marine with his musket, fighting from
## cover: NpcSkirmish; kept for its own test, tests/npc/test_duel.gd).
static var foe_tactics := "bend"
const DIFFICULTIES := ["easy", "normal", "hard"]
## The hour the sky is held at (local solar time: the sun high, the light full).
const HOUR := 10.5
## The duel's hotbar (the user, 2026-10-04: "we need to make the spells in the hotbar for the 1v1"; "remove the guns in 1v1
## its just spells"; "users ... are one of the four elements"): the chosen element's keys (Bending.bar: the first skill of
## 1-4, Mend on 5; the same key again switches a key to its other skill), the first readied (the hands free) at each
## round's start; the weapons and tools in the pack (off the bar: not drawn, not shown on the body). Laid once the bar has
## placed the start's kit (Hotbar.KIT_S) and the element is chosen.
static func bar_now() -> Array:
	var out: Array = []
	for id in Bending.bar(element):
		out.append(["spell", String(id)])
	return out


## The player's element (Bending.ELEMENTS): chosen at the duel's start (choosing: keys 1-4), or the user arg element=...;
## kept from one duel to the next in a run; the Esc menu changes it (a new duel).
static var element := "earth"

## Set by the main menu's row for the level it loads (taken once: take_request).
static var incoming := false
## The marine's aim (NpcFighter.SKILLS); kept from one duel to the next in a run.
static var difficulty := "normal"

var level: Node3D
var player: FrontierPlayer
var arena: DuelArena
var npc: NpcFighter
var squad: NpcSquad
var menu: DuelMenu
var phase := Phase.COUNTDOWN
var phase_t := 0.0
var round := 0
var score := Vector2i.ZERO
## The spawn the player starts this round at (0 side A, 1 side B); the marine the other.
var player_side := 0
## The last round's result: "player", "npc", "draw"; and why ("dead", "down", "yields", "runs", "time", "fell").
var last_result := ""
var last_why := ""
var ui: CanvasLayer
var banner: Label
var sub: Label
var top: Label
var _kit := {}
var _fight_shown := 0.0
var _seed := 7000
var _bar_laid := false
## The element still to be chosen (the duel's start; the countdown waits). Not in -s tool and test runs (they pass
## element=, or keep the run's).
var choosing := not SaveGame._is_script_run()


## Whether this level is a duel (the main menu's row, or the user arg mode=duel).
static func requested() -> bool:
	if incoming:
		return true
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--") == "mode=duel":
			return true
	return false


## The level asks once at its start (the menu's request is taken: the next game from the menu is a game again).
static func take_request() -> bool:
	var on := requested()
	incoming = false
	return on


static func find(tree: SceneTree) -> DuelMode:
	var scene := tree.current_scene if tree else null
	return scene.get_node_or_null(NODE_NAME) as DuelMode if scene else null


static func install(lvl: Node3D, p: FrontierPlayer) -> DuelMode:
	var d := DuelMode.new()
	d.name = NODE_NAME
	d.level = lvl
	d.player = p
	lvl.add_child(d)
	return d


func _ready() -> void:
	process_physics_priority = 20            # (after the fighters and the player have moved: their deaths are this frame's)
	_hold_the_sky()
	arena = DuelArena.make(level)
	_build_ui()
	menu = DuelMenu.install(level, self)
	InspectView.ensure_hotkey(get_tree())
	get_tree().create_timer(Hotbar.KIT_S + 0.3, false).timeout.connect(lay_bar)
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("element=") and a.get_slice("=", 1) in Bending.ELEMENTS:
			element = a.get_slice("=", 1)
			choosing = false
	# (the player's kit as he starts: each round gives it back)
	for k: String in player.weapons:
		_kit[k] = WeaponState.capture(player.weapons[k])
	restart.call_deferred()


## The duel's bar laid out (bar_now): each slot what it names (when the player has it), the rest emptied, the first spell
## readied.
func lay_bar() -> void:
	var bar := Hotbar.of(player) if player != null and is_instance_valid(player) else null
	if bar == null:
		return
	var bar_l := bar_now()
	for i in Hotbar.SLOTS:
		var e := Hotbar.make(String(bar_l[i][0]), String(bar_l[i][1])) if i < bar_l.size() else {}
		if not e.is_empty() and bar.has_thing(e):
			bar.assign(i, e)
		else:
			bar.clear(i)
	_bar_laid = true
	_ready_first()


## The bar's first spell readied, the hands free (each round's start: the respawn may have put a weapon back in them).
func _ready_first() -> void:
	var bar := Hotbar.of(player) if player != null and is_instance_valid(player) else null
	if bar != null and _bar_laid and bar.filled(0) and bar.selected() != 0:
		bar.take(0)


## The sky held by day: HOUR, the clock stopped, clear weather (no rig clock headless: NpcSenses reads full daylight).
func _hold_the_sky() -> void:
	var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig == null or rig.clock_driver == null:
		return
	var clock: WorldClock = rig.clock_driver.clock
	if clock != null:
		clock.running = false
		clock.set_time(HOUR)
	if rig.clock_driver.has_method(&"force_weather"):
		rig.clock_driver.force_weather("clear")


## The duel from its start: the score nil, round 1, the player on side A.
func restart() -> void:
	score = Vector2i.ZERO
	round = 0
	player_side = 1                          # (next_round swaps it: side A first)
	last_result = ""
	last_why = ""
	next_round()


## The marine's aim from now (easy, normal, hard): the one in the field at once, and the next rounds'.
func set_difficulty(d: String) -> void:
	if not d in DIFFICULTIES:
		return
	difficulty = d
	if npc != null and is_instance_valid(npc):
		npc.apply_skill(d)
	_paint()


## The next round: the sides swapped, the arena put back, both whole at their spawns, the countdown.
func next_round() -> void:
	round += 1
	player_side = 1 - player_side
	_seed += 1
	if squad != null and is_instance_valid(squad):
		squad.get_parent().remove_child(squad)  # (out at once: the interactor forgets him, NpcSenses.forget)
		squad.queue_free()
	squad = null
	npc = null
	arena.clear_dropped()
	arena.rebuild()
	_place_player(arena.spawn(player_side))
	_ready_first.call_deferred()
	var xf := arena.spawn(1 - player_side)
	# (a bender, no gun: the user, 2026-10-04, "remove the guns in 1v1 its just spells"; NpcBending)
	var bend := foe_tactics == "bend"
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "duel", "tactics": foe_tactics, "skill": difficulty, "seed": _seed}
	if bend:
		opts["weapon"] = ""
		opts["sidearm"] = ""
	squad = NpcSquad.spawn(level, FACTION, 1, xf.origin, opts)
	npc = squad.members[0] if not squad.members.is_empty() else null
	if npc != null:
		npc.flees = false
		npc.calm_s = INF
		npc.held = true
		if bend:
			npc.label = FOE_LABEL
		if npc.brain != null and npc.brain.skirmish != null:
			npc.brain.skirmish.bounds = arena.bounds()
	_to(Phase.COUNTDOWN)


func _place_player(xf: Transform3D) -> void:
	if InspectView.current != null and is_instance_valid(InspectView.current):
		InspectView.current.close()
	player.respawn()
	player.global_position = xf.origin + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	var f := -xf.basis.z
	player.yaw = atan2(-f.x, -f.z)
	player.rotation.y = player.yaw
	player.pitch = 0.0
	player.set_crouched(false)
	_refill()
	player.drag_speed_cap = 0.0              # (held at the spawn through the countdown)


## The player's kit loaded and full again (as at the duel's start), every weapon of it carried.
func _refill() -> void:
	for k: String in _kit:
		var w: Weapon = player.weapons.get(k)
		if w == null:
			continue
		if w is Firearm and (w as Firearm).state == Firearm.State.RELOADING:
			(w as Firearm)._interrupt_reload()
		WeaponState.apply(w, _kit[k])
		if w is Firearm:
			(w as Firearm)._stage = 0
		if not player.is_carried(k):
			player.set_carried(k, true, false)


func _to(p: Phase) -> void:
	phase = p
	phase_t = 0.0
	_paint()


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	phase_t += dt
	match phase:
		Phase.COUNTDOWN:
			if choosing:
				phase_t = 0.0                      # (the countdown waits for the element)
			elif phase_t >= COUNTDOWN_S:
				_fight()
		Phase.FIGHT:
			_fight_shown = maxf(_fight_shown - dt, 0.0)
			_watch()
		Phase.OVER:
			if phase_t >= PAUSE_S:
				if score.x >= TO_WIN or score.y >= TO_WIN:
					_to(Phase.DONE)
					duel_over.emit("player" if score.x >= TO_WIN else "npc")
				else:
					next_round()
	_paint()


func _fight() -> void:
	player.drag_speed_cap = INF
	if npc != null and is_instance_valid(npc):
		npc.held = false
		# (a duel: he knows where the player begins; from here on only what he sees and hears)
		npc.brain.told(player, arena.spawn(player_side).origin)
	_fight_shown = FIGHT_SHOW_S
	_to(Phase.FIGHT)


## The round's end, when it comes: one of them fallen, or the time out.
func _watch() -> void:
	if player.is_dead:
		_end_round("npc", "fell")
	elif npc == null or not is_instance_valid(npc) or npc.is_dead():
		_end_round("player", "dead")
	elif npc.down:
		_end_round("player", "down")
	elif npc.surrendered():
		_end_round("player", "yields")
	elif npc.brain != null and (npc.brain.state == NpcBrain.State.FLEE or npc.brain.routed()):
		_end_round("player", "runs")
	elif phase_t >= ROUND_S:
		_end_round("draw", "time")


func _end_round(result: String, why: String) -> void:
	last_result = result
	last_why = why
	if result == "player":
		score.x += 1
	elif result == "npc":
		score.y += 1
	if npc != null and is_instance_valid(npc) and not npc.is_dead():
		npc.held = true
	player.drag_speed_cap = INF
	_to(Phase.OVER)
	round_over.emit(result, score)


## The element chosen at the duel's start (keys 1-4), before the hotbar takes the keys.
func _input(e: InputEvent) -> void:
	if not choosing or not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	var k := (e as InputEventKey).physical_keycode
	if k >= KEY_1 and k <= KEY_4:
		choose(Bending.ELEMENTS[k - KEY_1])
		get_viewport().set_input_as_handled()


## The player's element `el`: his bar laid for it, the countdown begins.
func choose(el: String) -> void:
	if not el in Bending.ELEMENTS:
		return
	element = el
	choosing = false
	if _bar_laid:
		lay_bar()
	phase_t = 0.0
	_paint()


## M in the pause after the round: the fallen marine's body opened (InspectView), wherever the player stands.
func _unhandled_input(e: InputEvent) -> void:
	if phase != Phase.OVER or not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	var hit := e.is_action_pressed(&"inspect") if InputMap.has_action(&"inspect") else (e as InputEventKey).physical_keycode == KEY_M
	if hit and can_inspect():
		get_viewport().set_input_as_handled()
		InspectView.open_on(npc)


## Whether the fallen marine can be looked into now.
func can_inspect() -> bool:
	return npc != null and is_instance_valid(npc) and npc.is_dead() and (InspectView.current == null or not is_instance_valid(InspectView.current)) \
			and InspectView.can_inspect(npc)


# ---------------------------------------------------------------- the words on the screen
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "DuelText"
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
	return l


## The marine's name on the screen ("French marine").
func foe_name() -> String:
	return npc.label if npc != null and is_instance_valid(npc) else FOE_LABEL


func score_text() -> String:
	return "You %d  :  %d %s" % [score.x, score.y, foe_name()]


func _paint() -> void:
	if banner == null:
		return
	var b := ""
	var s := ""
	match phase:
		Phase.COUNTDOWN:
			if choosing:
				b = "Choose your element"
				s = "1  Earth     2  Water     3  Fire     4  Air"
				banner.text = b
				sub.text = s
				top.text = ""
				return
			b = "Round %d" % round if phase_t < 0.8 else str(ceili(COUNTDOWN_S - phase_t))
			s = "%s  ·  first to %d  ·  %s" % [score_text(), TO_WIN, difficulty]
		Phase.FIGHT:
			b = "Fight" if _fight_shown > 0.0 else ""
		Phase.OVER:
			b = result_line()
			s = score_text()
			if can_inspect():
				s += "  ·  M: inspect the body"
			s += "  ·  next round in %d" % ceili(maxf(PAUSE_S - phase_t, 0.0))
			if score.x >= TO_WIN or score.y >= TO_WIN:
				s = score_text() + ("  ·  M: inspect the body" if can_inspect() else "")
		Phase.DONE:
			b = "You win the duel" if score.x >= TO_WIN else "The %s wins the duel" % foe_name()
			s = score_text() + "  ·  Esc: restart the duel, the difficulty, the main menu"
	banner.text = b
	sub.text = s
	var left := ROUND_S - phase_t if phase == Phase.FIGHT else ROUND_S
	top.text = "Duel  ·  round %d  ·  %s  ·  %d:%02d  ·  %s" % [round, score_text(), floori(left / 60.0), floori(fmod(left, 60.0)), difficulty] \
			if phase != Phase.DONE else ""


## The round's result in words.
func result_line() -> String:
	var foe := foe_name()
	match last_result:
		"player":
			match last_why:
				"down":
					return "The %s is down: your round" % foe
				"yields":
					return "The %s yields: your round" % foe
				"runs":
					return "The %s runs: your round" % foe
			return "The %s is dead: your round" % foe
		"npc":
			return "You fell: the %s's round" % foe
		"draw":
			return "Time: a draw"
	return ""
