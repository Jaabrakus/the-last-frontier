class_name MusicDirector
extends Node
## The music (user 2026-10-03, of Shadow of the Colossus's soundtrack: "can we build a soundtrack like this"): the cues
## in audio/music/ (tools/music/: VSCO 2 CE's recorded orchestra and a synthesized choir, our own themes), each one's
## tempo and loop from music_manifest.gd. Like that game it leaves the land mostly quiet and scores the giants:
##   explore   now and then a piece (the first FIRST_S after the level starts, then GAP_S after the last ended; never
##             over a fight), by where the player is and the sun (AmbienceBed.band()):
##               night (user 2026-10-03: Fullmetal Alchemist's soundtrack "would be great for the night time music"):
##                 night_waltz, lullaby, night_elegy by turns
##               at home (Household.home, or the story's homestead) at dusk or night: night_waltz ("Hearth", the
##                 family theme), the lullaby by a sleeping baby (BABY_R)
##               a place (user 2026-10-03: "location scenes require new music"): the fort (loc_fort), the farms and
##                 the mill (loc_farms), the ford (loc_river), the wreck's pines (loc_wreck) by StoryLayer's places
##                 (the farms, ford and wreck only while the story's layer stands); else the square's kind
##                 (WorldSquares: the woods loc_woods, cliffs loc_cliffs, the lake loc_river, the marsh loc_marsh,
##                 open land explore_day)
##               else the hour's: explore_day; at dusk explore_dusk or explore_night
##             Coming into a place (or home at dusk or night) after AWAY_S away plays its piece SETTLE_S in, if it has
##             not played for PLACE_GAP_S, and not within HUSH_S of a fight or the lament ending
##   creator   the character creator open (user 2026-10-03: "make music for each race when on char creation"): the chosen
##             people's theme (people_<id>, tools/music/cues/peoples.py), looped, crossed to the next as the choice changes;
##             the creator closing fades it (found by its script among the root's children: no hook in its code)
## (Since the 2026-10-06 cleanup, owner answers O1/O2, loc_fort, loc_wreck, story_wonder, giant_upper_hand and giant_lament
## are not rendered (their cue sources stay in tools/music/cues): a place, a knee down or a death that would play one
## falls through: the place's square, the battle going on, the fight fading out. Of the peoples' themes only the
## Vietnamese, Thai and Malay ones are rendered.)
##   story     a mission's "music" effect (StoryEffects; MusicDirector.story(tree, cue)): story_wonder, story_sorrow,
##             story_home; once, over anything but a giant's fight
##   fight     a giant (group "giants": StandInGiant) within ENGAGE_R turns on the player (its MammothTemper threatening,
##             charging, swinging or stomping): giant_battle, its two bars of rearing and then its loop
##   upper     one of its knees buckled near the player, or the player on it: giant_upper_hand, crossed in on the next
##             bar line (both 144 BPM); back to the battle's loop the same way when it is up and no one is on it
##   lament    it dies with the player near (LAMENT_R) or fighting it: the fight fades and giant_lament plays once
##   calm      no giant minding the player for calm_s: the fight fades out over FADE_OUT_S
## The main menu plays the main theme (play_menu()), again MENU_GAP_S after it ends. Its own bus, "Music" (-> Master),
## the Settings' Music slider (GameSettings); the players keep going through the pause menu.
## RING MODE (round 4 SHOW; the owner's FEEL list: "Tidebreak's own music"; data/ring/music.json): the ring's own score,
## tools/music/cues/ring_fight.py, three stems of one length and loop (base, drive, peak) in one AudioStreamSynchronized:
##   play_story("ring_fight")   (RingMode._music at each game's go) starts it: the go (ring_fight, the score's own first
##                              downbeat) struck once, the stems from their top, the base heard, drive and peak silent;
##                              mode STORY, cue "ring_fight", so RingMode._music(false) -> play_story("") ends it as before
##   set_ring_level(0..2)       the layers: 0 the base, 1 + drive, 2 + peak. A change lands on the next bar line; it never
##                              steps down more than once in down_every_bars bars
##   ring_sting(id)             a stinger (music.json stings) over the score, the loop ducked duck_db and brought back over
##                              a beat after it; never two within sting_gap_s (a bigger rank wins a collision)
##   start_ring(practice)       also Practice's own start (RingMode asks for no music there): the base at practice_base_db,
##                              its level held at practice_level, no stingers
##   RingMusic                  made here (a child) while a RingMode stands: it reads RingRules.current() and RingMode's
##                              signals and sets the level and the stingers (scripts/ring/ring_music.gd)
## giant_battle (music.json "never") never plays while a ring match stands: the ring's fight is its own
## (tests/ring/test_ring_music.gd pins it).

const M := preload("res://scripts/audio/music_manifest.gd")
const BUS := &"Music"
const LEVEL_DB := -4.0              ## the cues' level on the bus (under the world's sound)
const SILENT_DB := -50.0
const ENGAGE_R := 45.0
const LAMENT_R := 70.0
const FADE_OUT_S := 4.0
const XFADE_S := 0.35               ## a bar-line crossing: the new cue in, the old out over a beat or so
const FIRST_S := Vector2(60.0, 120.0)
const GAP_S := Vector2(300.0, 540.0)
const MENU_GAP_S := 25.0
const SCAN_S := 0.25
const FIGHT_MOODS := ["threat", "charge", "swing", "stomp"]
const GROUP := &"music_director"
## The hour's pieces, by AmbienceBed.band().
const POOLS := {"day": ["explore_day"], "dusk": ["explore_dusk", "explore_night"],
		"night": ["night_waltz", "lullaby", "night_elegy"]}
## Named places: [StoryLayer place names, radius m, cue, only while the story's layer stands].
const PLACES := [
	[["flatts_fort"], 75.0, "loc_fort", false],
	[["rauch_farm", "farm_brenner", "farm_wendel", "farm_ott", "flatts_farms", "mill"], 55.0, "loc_farms", true],
	[["ford", "lesson_ice"], 55.0, "loc_river", true],
	[["wreck", "pine_grove"], 70.0, "loc_wreck", true],
]
## The world's squares by kind (WorldSquares.type_id).
const SQUARES := {"deep_woods": "loc_woods", "old_woods": "loc_woods", "woods_ridge": "loc_woods",
		"cliffs": "loc_cliffs", "lake": "loc_river", "marsh": "loc_marsh", "open_land": "explore_day",
		"field_land": "explore_day"}
const HOME_R := 30.0
const BABY_R := 20.0
const SETTLE_S := 8.0
const AWAY_S := 180.0
const PLACE_GAP_S := 600.0
const CREATOR_SCRIPT := "res://scripts/customizer/character_creator.gd"
const PEOPLE_XFADE_S := 1.2
const HUSH_S := 30.0                ## after a fight or the lament: no place's piece this long (the quiet after a battle)

enum Mode { QUIET, EXPLORE, FIGHT, UPPER, LAMENT, MENU, STORY, CREATOR }

const RING_DATA := "res://data/ring/music.json"
const RING_CUE := "ring_fight"

var player: Node3D
## The level's AmbienceBed (its band() picks the explore piece); found by name when not set.
var ambience: Node
var mode := Mode.QUIET
var cue := ""                       ## the cue playing ("" none)
## Seconds with no giant minding the player before the fight fades (tests shorten it).
var calm_s := 6.0
## The sun's band to use instead of the ambience's ("" theirs; tests).
var band_override := ""
## The character creator's script (tests point it at a stand-in's).
var creator_script := CREATOR_SCRIPT
var _creator_scan := 0.0
## Where the player is: "home", a place's cue, a square's cue, or "".
var where := ""
var _where_t := 0.0
var _arrived_fresh := false        ## came into `where` after AWAY_S away
var _seen := {}                    ## place -> _clock when last there
var _played := {}                  ## cue -> _clock when last started
var _clock := 0.0
var _last_piece := ""
var _hush_until := 0.0
var _cur: AudioStreamPlayer
var _explore_in := 0.0
var _calm := 0.0
var _scan := 0.0
var _pending := ""                  ## the cue to cross to on the next bar line
var _pending_bar := -1
var _started_usec := 0              ## when `cue` started (its own clock, for a stream not yet mixed)
var _from := 0.0                    ## where in the file it started
var _menu_wait := -1.0
var _hooked := {}                   ## giants whose `died` is connected (instance id -> true)
## The ring's score (RING MODE): the level heard, Practice's, its RingMusic; its player (the stems in one
## AudioStreamSynchronized), the level asked for, the bars it has played (its loops counted), its last step down, the duck.
var ring_level := 0
var ring_practice := false
var ring_music: RingMusic
## The stingers played and every cue started, in order (the tests read them).
var ring_stings: Array[String] = []
var started: Array[String] = []
var _ring: AudioStreamPlayer                ## the ring's player while its score plays (null when stopped)
var _ring_sync: AudioStreamSynchronized
var _ring_player: AudioStreamPlayer         ## the ring's player, kept for the ring's stay
var _ring_fade: Tween
var _ring_want := 0
var _ring_bar := -1
var _ring_loops := 0
var _ring_last_pos := 0.0
var _ring_down_bar := -1000000
var _ring_tw: Array[Tween] = [null, null, null]
var _duck: Tween
var _sting_at := -1e9
var _sting_rank := -1
var _sting_player: AudioStreamPlayer
var _ring_held := {}                ## path -> the stream read on a worker thread (null until then)
static var _ring_data := {}


## The Music bus (idempotent): -> Master.
static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, &"Master")


## The main menu's music: Tidebreak's lobby (tidebreak_lobby, 2026-10-13: the lobby is the arena's front door, its music the
## ring score's, "avatar inspired") when it is rendered, else the main theme; again after a rest. Returns the node (a child of
## `host`).
static func play_menu(host: Node) -> MusicDirector:
	var d := MusicDirector.new()
	d.name = "MenuMusic"
	d.mode = Mode.MENU
	host.add_child(d)
	d.play(menu_cue(), 0.0, 2.5)
	return d


static func menu_cue() -> StringName:
	return &"tidebreak_lobby" if M.CUES.has("tidebreak_lobby") else &"main_theme"


## A mission's music (StoryEffects' "music"): `id` once ("" fades what plays); not over a giant's fight.
static func story(tree: SceneTree, id: String) -> void:
	var d := tree.get_first_node_in_group(GROUP) as MusicDirector if tree else null
	if d == null:
		return
	d.play_story(id)


func play_story(id: String) -> void:
	if mode in [Mode.FIGHT, Mode.UPPER, Mode.LAMENT, Mode.MENU]:
		return
	_pending = ""
	if id == "":
		fade_out(3.0)
		mode = Mode.QUIET
		_explore_in = randf_range(GAP_S.x, GAP_S.y)
		return
	if id == RING_CUE and has_ring_score():
		start_ring(false)
		return
	mode = Mode.STORY
	play(StringName(id), 0.0, 2.0, 3.0)


func _ready() -> void:
	ensure_bus()
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_explore_in = randf_range(FIRST_S.x, FIRST_S.y)


func _process(dt: float) -> void:
	if mode == Mode.MENU:
		_menu(dt)
		return
	_creator_scan -= dt
	if _creator_scan <= 0.0:
		_creator_scan = SCAN_S
		_creator_music()
		_ring_watch()
		_ring_hold()
	if _ring != null:
		_ring_bars()
	if mode == Mode.CREATOR:
		return
	_scan -= dt
	if _scan <= 0.0:
		_scan = SCAN_S
		_think(SCAN_S)
	if _pending != "":
		_cross_on_bar()
	if mode in [Mode.EXPLORE, Mode.LAMENT, Mode.STORY] and (_cur == null or not _cur.playing):
		if mode == Mode.LAMENT:
			_hush_until = _clock + HUSH_S
		mode = Mode.QUIET
		cue = ""
		_explore_in = randf_range(GAP_S.x, GAP_S.y)


func _menu(dt: float) -> void:
	if _cur != null and _cur.playing:
		return
	if _menu_wait < 0.0:
		_menu_wait = MENU_GAP_S
	_menu_wait -= dt
	if _menu_wait <= 0.0:
		_menu_wait = -1.0
		play(menu_cue(), 0.0, 2.5)


## What the giants want, and where the player is, every SCAN_S.
func _think(dt: float) -> void:
	_clock += dt
	_track_where(dt)
	var want := _giants()
	match mode:
		Mode.QUIET, Mode.EXPLORE, Mode.STORY:
			if want == "fight":
				_go_fight(false)
			elif want == "upper":
				_go_fight(true)
			elif mode == Mode.QUIET and player != null:
				_explore_in -= dt
				if _arrived_fresh and _where_t >= SETTLE_S and _clock >= _hush_until:
					_arrived_fresh = false
					var pp := _place_piece()
					if pp != "" and _clock - float(_played.get(pp, -1e9)) >= PLACE_GAP_S:
						_start_piece(pp)
						return
				if _explore_in <= 0.0:
					_start_piece(pick())
		Mode.FIGHT, Mode.UPPER:
			if want == "":
				_calm += dt
				if _calm >= calm_s:
					fade_out(FADE_OUT_S)
					mode = Mode.QUIET
					_hush_until = _clock + HUSH_S
					_pending = ""
					_explore_in = randf_range(GAP_S.x, GAP_S.y)
				return
			_calm = 0.0
			if want == "upper" and mode == Mode.FIGHT and M.CUES.has("giant_upper_hand"):
				mode = Mode.UPPER
				_cross(&"giant_upper_hand")
			elif want == "fight" and mode == Mode.UPPER:
				mode = Mode.FIGHT
				_cross(&"giant_battle")
		Mode.LAMENT:
			pass


func _start_piece(piece: String) -> void:
	mode = Mode.EXPLORE
	_last_piece = piece
	play(StringName(piece), 0.0, 3.0)


## The character creator: its people's theme while it is open (see the header).
func _creator_music() -> void:
	var c := _creator()
	if c == null:
		if mode == Mode.CREATOR:
			fade_out(2.0)
			mode = Mode.QUIET
			_hush_until = _clock + HUSH_S
			_explore_in = maxf(_explore_in, 20.0)
		return
	var look: Variant = c.get("look")
	var want := "people_" + (String((look as Dictionary).get("people", "")) if look is Dictionary else "")
	if mode != Mode.CREATOR:
		_pending = ""
		mode = Mode.CREATOR
	if M.CUES.has(want) and cue != want:
		play(StringName(want), 0.0, PEOPLE_XFADE_S, PEOPLE_XFADE_S)


func _creator() -> Node:
	for n in get_tree().root.get_children():
		var sc := n.get_script() as Script
		if sc != null and sc.resource_path == creator_script:
			return n
	return null


## The piece for now: by where the player is and the sun (see the header).
func pick() -> String:
	var band := _band()
	var home := where == "home"
	if home and band in ["dusk", "night"]:
		return "lullaby" if band == "night" and _baby_asleep_near() else "night_waltz"
	if band == "night":
		var pool: Array = POOLS.night.filter(func(c: String) -> bool: return c != _last_piece)
		return String(pool[randi() % pool.size()])
	if where != "" and not home and _clock - float(_played.get(where, -1e9)) >= PLACE_GAP_S:
		return where
	var p: Array = POOLS.get(band, POOLS.day)
	var fresh: Array = p.filter(func(c: String) -> bool: return c != _last_piece)
	return String((fresh if not fresh.is_empty() else p)[randi() % (fresh if not fresh.is_empty() else p).size()])


## The piece the place itself has now ("" none: no place, or night away from home, or home by day).
func _place_piece() -> String:
	var band := _band()
	if where == "home":
		return pick() if band in ["dusk", "night"] else ""
	if where == "" or band == "night":
		return ""
	return where


## Where the player is (`where`), how long, and whether they came there from away.
func _track_where(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var w := locate(player.global_position)
	if w != where:
		_arrived_fresh = w != "" and _clock - float(_seen.get(w, -1e9)) >= AWAY_S
		where = w
		_where_t = 0.0
	else:
		_where_t += dt
	if where != "":
		_seen[where] = _clock


## "home", a place's cue, a square's cue, or "" at `pos`.
func locate(pos: Vector3) -> String:
	var hp := _home_pos()
	if hp != Vector3.INF and _flat(pos, hp) < HOME_R:
		return "home"
	var layered := StoryLayer.active_id() != ""
	for e: Array in PLACES:
		if bool(e[3]) and not layered:
			continue
		if not M.CUES.has(String(e[2])):
			continue               # (a place whose piece is not rendered: loc_fort, loc_wreck since 2026-10-06)
		for nm: String in e[0]:
			var p := StoryLayer.place(nm)
			if p != Vector3.INF and _flat(pos, p) < float(e[1]):
				return String(e[2])
	return String(SQUARES.get(WorldSquares.type_id(WorldSquares.square_at(pos)), ""))


## The household's home (its first worker's place), else the story's homestead while its layer stands; INF none.
func _home_pos() -> Vector3:
	var h := get_tree().get_first_node_in_group(&"household")
	if h != null and h.get("sc") != null:
		var at: Variant = h.get("home")
		if at is Vector3 and at != Vector3.ZERO:
			return at
	if StoryLayer.active_id() != "":
		return StoryLayer.place("homestead")
	return Vector3.INF


func _baby_asleep_near() -> bool:
	var h := get_tree().get_first_node_in_group(&"household")
	var b: Object = h.get("baby") if h != null else null
	if b == null or not b.has_method("state") or player == null:
		return false
	var st: Variant = b.call("state")
	if not (st is Dictionary) or not bool((st as Dictionary).get("asleep", false)):
		return false
	var at: Variant = b.call("baby_world") if b.has_method("baby_world") else Vector3.ZERO
	return at is Vector3 and at != Vector3.ZERO and _flat(player.global_position, at) < BABY_R


## "" (no giant minds the player), "fight" or "upper".
func _giants() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	var out := ""
	for g in get_tree().get_nodes_in_group(&"giants"):
		if not is_instance_valid(g) or String(g.get("dead_side")) != "":
			continue
		var id := g.get_instance_id()
		if not _hooked.has(id) and g.has_signal(&"died"):
			_hooked[id] = true
			g.connect(&"died", _on_giant_died.bind(g))
		var d := _flat(player.global_position, g.call("where"))
		if bool(g.call("carries", player)) or (String(g.get("down_leg")) != "" and d < ENGAGE_R):
			return "upper"
		var t := g.get_node_or_null(^"Temper")
		if t != null and d < ENGAGE_R and String(t.get("mood")) in FIGHT_MOODS:
			out = "fight"
	return out


func _go_fight(upper: bool) -> void:
	_calm = 0.0
	_pending = ""
	if upper and M.CUES.has("giant_upper_hand"):
		mode = Mode.UPPER
		play(&"giant_upper_hand", 0.0, 1.0)
	else:
		mode = Mode.FIGHT
		play(&"giant_battle", 0.0, 0.4)


func _on_giant_died(g: Node) -> void:
	if not is_instance_valid(g) or player == null or not is_instance_valid(player):
		return
	var near := _flat(player.global_position, g.call("where")) < LAMENT_R
	if mode in [Mode.FIGHT, Mode.UPPER] or near:
		_pending = ""
		if not M.CUES.has("giant_lament"):
			# (the lament not rendered since 2026-10-06: the fight fades out instead)
			fade_out(FADE_OUT_S)
			mode = Mode.QUIET
			_hush_until = _clock + HUSH_S
			_explore_in = randf_range(GAP_S.x, GAP_S.y)
			return
		mode = Mode.LAMENT
		play(&"giant_lament", 0.0, 2.0, 2.5)


## The cue to cross to on the current cue's next bar line (at once with nothing playing).
func _cross(to: StringName) -> void:
	if _cur == null or not _cur.playing or not M.CUES.has(cue):
		play(to, _loop_start(String(to)), XFADE_S)
		return
	_pending = String(to)
	_pending_bar = int(floor(position() / _bar_s(cue)))


func _cross_on_bar() -> void:
	var bar := _bar_s(cue)
	var pos := position()
	var now := int(floor(pos / bar))
	if now == _pending_bar:
		return
	# into the new cue's loop, as far past its start as we are past the bar line
	var late := fmod(pos, bar)
	var to := _pending
	_pending = ""
	play(StringName(to), _loop_start(to) + late, XFADE_S, XFADE_S * 2.0)


## Plays cue `id` from `from` (s), fading in over `fade_in`; what was playing fades out over `fade_old` (fade_in if <0).
func play(id: StringName, from: float = 0.0, fade_in: float = 1.0, fade_old: float = -1.0) -> void:
	var c: Dictionary = M.CUES.get(String(id), {})
	if c.is_empty():
		return
	if ring_on() and String(id) in (ring_data().get("never", []) as Array):
		return                               # (the giants' fight never in the ring)
	started.append(String(id))
	var stream := load(String(c.path)) as AudioStream
	if stream == null:
		push_warning("MusicDirector: no %s" % c.path)
		return
	_loop(stream, c)
	fade_out(fade_in if fade_old < 0.0 else fade_old)
	var p := AudioStreamPlayer.new()
	p.name = "Cue_%s" % id
	p.bus = BUS
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = stream
	p.volume_db = SILENT_DB if fade_in > 0.0 else LEVEL_DB
	add_child(p)
	p.play(from)
	if fade_in > 0.0:
		create_tween().tween_property(p, "volume_db", LEVEL_DB, fade_in).set_trans(Tween.TRANS_SINE)
	_cur = p
	cue = String(id)
	_played[cue] = _clock
	_from = from
	_started_usec = Time.get_ticks_usec()


## Fades out what is playing over `secs`, then frees it.
func fade_out(secs: float) -> void:
	if _cur == null or not is_instance_valid(_cur):
		_cur = null
		return
	var p := _cur
	_cur = null
	cue = ""
	var keep := p == _ring_player
	if p == _ring:
		_ring_stop()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", SILENT_DB, maxf(secs, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# (the ring's player is kept and stopped, not freed: freeing a synchronized stream's player as it mixed stalled the
	# frame for seconds now and then, tests/perf/test_ring_hitches.gd)
	tw.tween_callback(p.stop if keep else p.queue_free)
	if keep:
		_ring_fade = tw


## Where the current cue is (s into its file): the stream's own position once it is mixing, else our clock (folded
## into its loop).
func position() -> float:
	if _cur == null:
		return 0.0
	var pos := _cur.get_playback_position()
	if pos > 0.0:
		return pos + AudioServer.get_time_since_last_mix()
	var c: Dictionary = M.CUES.get(String(ring_data().stems[0]) if _ring != null and _cur == _ring else cue, {})
	var t := _from + (Time.get_ticks_usec() - _started_usec) / 1e6
	var ls := float(c.get("loop_start", -1.0))
	var ln := float(c.get("length", 0.0))
	if ls >= 0.0 and ln > ls and t >= ln:
		t = ls + fmod(t - ls, ln - ls)
	return t


func _bar_s(id: String) -> float:
	var c: Dictionary = M.CUES[id]
	return 60.0 / float(c.bpm) * int(c.beats)


# ---------------------------------------------------------------- the ring's score (RING MODE; see the header)
static func ring_data() -> Dictionary:
	if _ring_data.is_empty():
		var f := FileAccess.open(RING_DATA, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_ring_data = d if d is Dictionary else {"stems": []}
	return _ring_data


static func ring_num(key: String, def := 0.0) -> float:
	return float(ring_data().get(key, def))


## The manifest has the ring's three stems and its go.
static func has_ring_score() -> bool:
	var stems: Array = ring_data().get("stems", [])
	if stems.size() != 3 or not M.CUES.has(RING_CUE):
		return false
	for s: Variant in stems:
		if not M.CUES.has(String(s)):
			return false
	return true


## A ring match stands (its RingMusic made) or the ring's score plays.
func ring_on() -> bool:
	return _ring != null or (ring_music != null and is_instance_valid(ring_music))


## The ring's score is playing now.
func ring_playing() -> bool:
	return _ring != null and is_instance_valid(_ring) and _ring == _cur


## The ring's score from its top: the stems in step, the base heard (in Practice at practice_base_db, its level held at
## practice_level), the go struck once (not in Practice).
func start_ring(practice := false) -> void:
	if not has_ring_score():
		return
	_pending = ""
	if ring_playing():
		_cur = null
		_ring_stop()
	fade_out(1.0)
	# (one player and one synchronized stream for the ring's whole stay: made once, stopped and started again)
	if _ring_player == null or not is_instance_valid(_ring_player):
		var stems: Array = ring_data().stems
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = 3
		for i in 3:
			var c: Dictionary = M.CUES[String(stems[i])]
			var w := load(String(c.path)) as AudioStream
			_loop(w, c)
			sync.set_sync_stream(i, w)
		_ring_player = AudioStreamPlayer.new()
		_ring_player.name = "Cue_ring_fight"
		_ring_player.bus = BUS
		_ring_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_ring_player.stream = sync
		add_child(_ring_player)
	if _ring_fade != null and _ring_fade.is_valid():
		_ring_fade.kill()
	var p := _ring_player
	var sync := p.stream as AudioStreamSynchronized
	for i in 3:
		sync.set_sync_stream_volume(i, 0.0 if i == 0 else SILENT_DB)
	ring_practice = practice
	ring_level = 0
	_ring_want = int(ring_num("practice_level", 0.0)) if practice else 0
	_ring_bar = -1
	_ring_loops = 0
	_ring_last_pos = 0.0
	_ring_down_bar = -1000000
	p.volume_db = _ring_db()
	p.play(0.0)
	_ring = p
	_ring_sync = sync
	_cur = p
	cue = RING_CUE
	mode = Mode.STORY
	_from = 0.0
	_started_usec = Time.get_ticks_usec()
	_played[cue] = _clock
	started.append(RING_CUE)
	if not practice:
		_one_shot(RING_CUE, ring_num("go_db", 0.0))
	_apply_level(true)


## The ring's player's level: LEVEL_DB, Practice's practice_base_db under it.
func _ring_db() -> float:
	return LEVEL_DB + (ring_num("practice_base_db", -6.0) if ring_practice else 0.0)


## The layers to `n` (0..2) from the next bar line (Practice: held at practice_level).
func set_ring_level(n: int) -> void:
	if ring_practice:
		n = int(ring_num("practice_level", 0.0))
	_ring_want = clampi(n, 0, 2)


## The level asked for (it lands on the next bar line).
func ring_level_wanted() -> int:
	return _ring_want


## The bars the score has played (its loops counted), each frame: on a new bar line the level asked for lands (up at once;
## down one step, at most once in down_every_bars bars).
func _ring_bars() -> void:
	if not ring_playing():
		return
	var c: Dictionary = M.CUES[String(ring_data().stems[0])]
	var pos := position()
	if pos + 1.0 < _ring_last_pos:
		_ring_loops += 1                     # (round its loop)
	_ring_last_pos = pos
	var per_loop := int(round(float(c.length) / _bar_s(RING_CUE)))
	var bar := _ring_loops * per_loop + int(floor(pos / _bar_s(RING_CUE)))
	if bar == _ring_bar:
		return
	_ring_bar = bar
	if _ring_want > ring_level:
		ring_level = _ring_want
		_apply_level(false)
	elif _ring_want < ring_level and bar - _ring_down_bar >= int(ring_num("down_every_bars", 8.0)):
		ring_level -= 1
		_ring_down_bar = bar
		_apply_level(false)


## The bars played since the score began (-1 not playing).
func ring_bar() -> int:
	return _ring_bar if ring_playing() else -1


## The beats since the score began (its loops counted; -1 not playing): the crowd's clap keeps to it.
func ring_beat() -> float:
	if not ring_playing():
		return -1.0
	var c: Dictionary = M.CUES[String(ring_data().stems[0])]
	return (_ring_loops * float(c.length) + position()) * float(c.bpm) / 60.0


## The tempo of the ring's score (BPM; its manifest row).
static func ring_bpm() -> float:
	return float((M.CUES.get(RING_CUE, {}) as Dictionary).get("bpm", 132.0))


## The stems' volumes to the level: each one in quickly at the bar line (layer_in_s), out over layer_out_beats.
func _apply_level(instant: bool) -> void:
	if _ring_sync == null:
		return
	var beat := 60.0 / ring_bpm()
	for i in 3:
		var to := 0.0 if i <= ring_level else SILENT_DB
		if _ring_tw[i] != null and _ring_tw[i].is_valid():
			_ring_tw[i].kill()
		var from := _ring_sync.get_sync_stream_volume(i)
		if instant or is_equal_approx(from, to):
			_ring_sync.set_sync_stream_volume(i, to)
			continue
		var secs := ring_num("layer_in_s", 0.06) if to > from else beat * ring_num("layer_out_beats", 1.0)
		var sync := _ring_sync
		var k := i
		_ring_tw[i] = create_tween()
		_ring_tw[i].tween_method(func(db: float) -> void: sync.set_sync_stream_volume(k, db), from, to, secs)


## Each stem's volume now (dB; the tests read the layers).
func ring_stem_db(i: int) -> float:
	return _ring_sync.get_sync_stream_volume(i) if _ring_sync != null else SILENT_DB


## A stinger (music.json stings `id`) over the ring's score: the loop ducked duck_db at once and brought back over a beat
## once the stinger's hold_s is up. Never two within sting_gap_s: a bigger rank cuts the last one short, a smaller or equal
## one is dropped. None in Practice (practice_stings). Returns whether it played.
func ring_sting(id: String) -> bool:
	var st: Dictionary = (ring_data().get("stings", {}) as Dictionary).get(id, {})
	if st.is_empty() or not M.CUES.has(String(st.get("cue", ""))):
		return false
	if ring_practice and ring_playing() and not bool(ring_data().get("practice_stings", false)):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var rank := int(st.get("rank", 0))
	if now - _sting_at < ring_num("sting_gap_s", 1.5):
		if rank <= _sting_rank:
			return false
		if _sting_player != null and is_instance_valid(_sting_player):
			var old := _sting_player
			var tw := old.create_tween()
			tw.tween_property(old, "volume_db", SILENT_DB, 0.12)
			tw.tween_callback(old.queue_free)
	_sting_at = now
	_sting_rank = rank
	_sting_player = _one_shot(String(st.cue), float(st.get("db", 0.0)))
	ring_stings.append(id)
	if ring_playing():
		var beat := 60.0 / ring_bpm()
		if _duck != null and _duck.is_valid():
			_duck.kill()
		var base := _ring_db()
		_duck = create_tween()
		_duck.tween_property(_ring, "volume_db", base + ring_num("duck_db", -9.0), ring_num("duck_in_s", 0.05))
		_duck.tween_interval(maxf(float(st.get("hold_s", 2.0)) - beat, 0.0))
		_duck.tween_property(_ring, "volume_db", base, beat * ring_num("duck_back_beats", 1.0)).set_trans(Tween.TRANS_SINE)
	return true


## The loop's duck now (dB under its own level; 0 none).
func ring_duck_db() -> float:
	return _ring.volume_db - _ring_db() if ring_playing() else 0.0


## A cue once over whatever plays (not the current cue): the go, the stingers. Frees itself when done.
func _one_shot(id: String, db: float) -> AudioStreamPlayer:
	var c: Dictionary = M.CUES.get(id, {})
	var s := load(String(c.get("path", ""))) as AudioStream if not c.is_empty() else null
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.name = "Sting_%s" % id
	p.bus = BUS
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = s
	p.volume_db = LEVEL_DB + db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	started.append(id)
	return p


## The ring's score let go (fade_out fades and frees its player).
func _ring_stop() -> void:
	_ring = null
	_ring_sync = null
	ring_level = 0
	_ring_bar = -1
	for i in 3:
		if _ring_tw[i] != null and _ring_tw[i].is_valid():
			_ring_tw[i].kill()
	if _duck != null and _duck.is_valid():
		_duck.kill()


## A ring match standing (group ring_match: RingMode): its RingMusic made, as a child (it frees itself when the match goes).
func _ring_watch() -> void:
	if ring_music != null and not is_instance_valid(ring_music):
		ring_music = null
	if ring_music != null or not is_inside_tree() or not has_ring_score():
		return
	var m := get_tree().get_first_node_in_group(&"ring_match") as RingMode
	if m == null or m.rules == null:
		return
	ring_music = RingMusic.new()
	ring_music.name = "RingMusic"
	ring_music.md = self
	ring_music.mode = m
	add_child(ring_music)
	# (the stems, the go and the stingers read on worker threads now and held, so the go reads nothing from disk)
	var ids: Array = (ring_data().stems as Array) + [RING_CUE]
	for st: Variant in (ring_data().get("stings", {}) as Dictionary).values():
		if st is Dictionary:
			ids.append(String((st as Dictionary).get("cue", "")))
	for id: Variant in ids:
		var path := String((M.CUES.get(String(id), {}) as Dictionary).get("path", ""))
		if path != "" and not _ring_held.has(path):
			_ring_held[path] = null
			ResourceLoader.load_threaded_request(path)


## The ring's files asked for on the worker threads, held once read.
func _ring_hold() -> void:
	for path: String in _ring_held:
		if _ring_held[path] == null and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			_ring_held[path] = ResourceLoader.load_threaded_get(path)


func _loop_start(id: String) -> float:
	return maxf(float(M.CUES[id].loop_start), 0.0)


## A looped cue's WAV loops from its loop start to its end (the file's own smpl chunk says the same).
static func _loop(stream: AudioStream, c: Dictionary) -> void:
	var w := stream as AudioStreamWAV
	if w == null or float(c.loop_start) < 0.0:
		return
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = int(round(float(c.loop_start) * w.mix_rate))
	w.loop_end = int(round(float(c.length) * w.mix_rate))


func _band() -> String:
	if band_override != "":
		return band_override
	if ambience == null or not is_instance_valid(ambience):
		ambience = get_parent().get_node_or_null(^"AmbienceBed") if get_parent() else null
	return String(ambience.call("band")) if ambience != null and ambience.has_method("band") else "day"


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
