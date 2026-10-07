class_name RingMusic
extends Node
## The ring's score follows the match (round 4 SHOW; the owner's FEEL list: "Tidebreak's own music"). MusicDirector makes it
## (its child) while a RingMode stands; it reads RingRules.current() and RingMode's signals, never a position, and every
## number in data/ring/music.json:
##   the level  each scan_s, MusicDirector.set_ring_level (it lands on the next bar line, steps down at most once in 8 bars):
##              stock   0 at the start; 1 when any competitor is at pct1 % or more, the clock reads clock1_s or less, or
##                      falls1 falls have happened this game; 2 when anyone on his last life is at last_pct % or more, in
##                      sudden death, or the clock at clock2_s or less
##              classic 1 with a side confined to zone1 or deeper, or left1_s left; 2 with a side in its last zone, or
##                      left2_s left
##   stingers   (MusicDirector.ring_sting: the loop ducked under each, never two within sting_gap_s, the bigger wins)
##              ko_dealt / ko_taken on RingRules.ko by the fallen one's side (the player's side's fall is taken, a self-fall
##              too; the other side's is dealt), last_life when a side's last life starts (its respawn into it),
##              sudden_death when it starts, game_won / game_lost at a game's end (RingMode.round_over), match_won /
##              match_lost at the deciding game's end or at RingMode.match_over (once a match), the countdown's bed under
##              the count (its end on the go)
##   Practice   the score started here (RingMode asks for none in Practice): the base at practice_base_db, its level held,
##              no stingers
##   the end    RingMode's restart (a COUNTDOWN with the score playing) and its leaving stop the score
## The stands follow the same moments through RingDressing (RingLevel._follow), not through here.

var md: MusicDirector
var mode: RingMode
var rules: RingRules
var level := 0
var _scan := 0.0
var _bed_done := false
var _sudden := false
var _match_stung := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if mode == null or not is_instance_valid(mode):
		queue_free()
		return
	rules = mode.rules
	mode.phase_changed.connect(_on_phase)
	mode.round_over.connect(_on_round_over)
	mode.match_over.connect(_on_match_over)
	mode.tree_exiting.connect(_on_mode_gone)
	if rules != null:
		rules.ko.connect(_on_ko)
		rules.respawned.connect(_on_respawned)
	_on_phase(mode.phase)


func _process(dt: float) -> void:
	if mode == null or not is_instance_valid(mode):
		queue_free()
		return
	if mode.phase == "COUNTDOWN":
		_countdown_bed()
	_scan -= dt
	if _scan > 0.0:
		return
	_scan = MusicDirector.ring_num("scan_s", 0.25)
	if mode.phase != "FIGHT":
		return
	if mode.practice:
		if not md.ring_playing():
			md.start_ring(true)
		return
	if rules != null and rules.sudden and not _sudden:
		_sudden = true
		md.ring_sting("sudden_death")
	level = compute_level()
	md.set_ring_level(level)


## The level the match is at now (see the header).
func compute_level() -> int:
	if rules == null or not is_instance_valid(rules):
		return 0
	if mode.stock():
		return _stock_level()
	return _classic_level()


func _stock_level() -> int:
	var lv: Dictionary = _levels("stock")
	var left := mode.round_left_s()
	if rules.sudden or left <= float(lv.get("clock2_s", 30.0)):
		return 2
	var one := left <= float(lv.get("clock1_s", 120.0)) or rules.falls.size() >= int(lv.get("falls1", 2))
	for b: Node3D in mode.competitors():
		if rules.is_gone(b):
			continue
		var p := rules.pct_of(b)
		if rules.lives_on and rules.stocks_of(b) == 1 and p >= float(lv.get("last_pct", 80.0)):
			return 2
		if p >= float(lv.get("pct1", 60.0)):
			one = true
	return 1 if one else 0


func _classic_level() -> int:
	var lv: Dictionary = _levels("classic")
	var left := mode.round_left_s()
	var deep := 0
	for b: Node3D in mode.competitors():
		deep = maxi(deep, rules.confined_of(b))
	if deep >= rules.zones() or left <= float(lv.get("left2_s", 30.0)):
		return 2
	if deep >= int(lv.get("zone1", 2)) or left <= float(lv.get("left1_s", 60.0)):
		return 1
	return 0


static func _levels(rs: String) -> Dictionary:
	var l: Variant = MusicDirector.ring_data().get("levels", {})
	var d: Variant = (l as Dictionary).get(rs, {}) if l is Dictionary else {}
	return d if d is Dictionary else {}


# ---------------------------------------------------------------- the moments
func _on_phase(ph: String) -> void:
	match ph:
		"COUNTDOWN":
			_bed_done = false
			_sudden = false
			if mode.round <= 1 and mode.rounds_played == 0:
				_match_stung = false
			if md.ring_playing():
				md.play_story("")            # (a restart mid-game: the score stops; the go starts it again)
		"FIGHT":
			if mode.practice and not md.ring_playing():
				md.start_ring(true)


## The countdown's bed (not in Practice): played so it ends as the count does, on the go.
func _countdown_bed() -> void:
	if _bed_done or mode.practice:
		return
	var st: Dictionary = (MusicDirector.ring_data().get("stings", {}) as Dictionary).get("countdown", {})
	var lead := float(st.get("hold_s", 2.5))
	if mode.phase_t >= mode.countdown_s() - lead and mode.phase_t > 0.0:
		_bed_done = true
		md.ring_sting("countdown")


func _on_ko(b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
	if mode.practice or rules == null:
		return
	md.ring_sting("ko_taken" if rules.team_of(b) == 0 else "ko_dealt")


func _on_respawned(b: Node3D) -> void:
	if mode.practice or rules == null or not rules.lives_on:
		return
	if rules.stocks_of(b) == 1:
		md.ring_sting("last_life")


func _on_round_over(result: String, _why: String) -> void:
	if mode.practice:
		return
	if mode.decided():
		_match_stung = true
		md.ring_sting("match_won" if mode.score.x > mode.score.y else "match_lost")
	elif result != "draw":
		md.ring_sting("game_won" if result == "win" else "game_lost")


func _on_match_over(winner: int) -> void:
	if mode.practice or _match_stung:
		return
	_match_stung = true
	if winner >= 0:
		md.ring_sting("match_won" if winner == 0 else "match_lost")


func _on_mode_gone() -> void:
	if md != null and is_instance_valid(md) and md.ring_playing():
		md.play_story("")
	queue_free()
