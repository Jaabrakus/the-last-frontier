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
const HUSH_S := 30.0                ## after a fight or the lament: no place's piece this long (the quiet after a battle)

enum Mode { QUIET, EXPLORE, FIGHT, UPPER, LAMENT, MENU, STORY }

var player: Node3D
## The level's AmbienceBed (its band() picks the explore piece); found by name when not set.
var ambience: Node
var mode := Mode.QUIET
var cue := ""                       ## the cue playing ("" none)
## Seconds with no giant minding the player before the fight fades (tests shorten it).
var calm_s := 6.0
## The sun's band to use instead of the ambience's ("" theirs; tests).
var band_override := ""
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


## The Music bus (idempotent): -> Master.
static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, &"Master")


## The main menu's music: the main theme, again after a rest. Returns the node (a child of `host`).
static func play_menu(host: Node) -> MusicDirector:
	var d := MusicDirector.new()
	d.name = "MenuMusic"
	d.mode = Mode.MENU
	host.add_child(d)
	d.play(&"main_theme", 0.0, 2.5)
	return d


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
		play(&"main_theme", 0.0, 2.5)


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
			if want == "upper" and mode == Mode.FIGHT:
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
	if upper:
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
	var tw := create_tween()
	tw.tween_property(p, "volume_db", SILENT_DB, maxf(secs, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)


## Where the current cue is (s into its file): the stream's own position once it is mixing, else our clock (folded
## into its loop).
func position() -> float:
	if _cur == null:
		return 0.0
	var pos := _cur.get_playback_position()
	if pos > 0.0:
		return pos + AudioServer.get_time_since_last_mix()
	var c: Dictionary = M.CUES.get(cue, {})
	var t := _from + (Time.get_ticks_usec() - _started_usec) / 1e6
	var ls := float(c.get("loop_start", -1.0))
	var ln := float(c.get("length", 0.0))
	if ls >= 0.0 and ln > ls and t >= ln:
		t = ls + fmod(t - ls, ln - ls)
	return t


func _bar_s(id: String) -> float:
	var c: Dictionary = M.CUES[id]
	return 60.0 / float(c.bpm) * int(c.beats)


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
