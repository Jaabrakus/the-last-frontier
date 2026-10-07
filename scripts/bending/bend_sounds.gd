class_name BendSounds
extends RefCounted
## Tidebreak's own sounds (improvement round 1, 2026-10-05; the arena used to borrow the frontier game's: a musket shot
## for lightning, an arrow for wind): every element's casts and hits, the ring's moments and the crowd, synthesized by
## tools/sfx/bend/bend_sfx.py (numpy; nothing recorded or downloaded) into audio/sfx/bend/<id>_NN.wav, 3-4 variants each,
## each family set to one loudness and held under -1 dBFS there. This owns the table (TABLE) and plays it.
##   bend(kind, what, at, db)   BendLooks.sound's (the bending's calls): `what` "cast" or "hit" of a kind (stone, ice,
##                              water, fire, air, lightning, steam). A cast is told by the move being cast (BendEffects'
##                              current cast: its spec's do, zone, kind; cast_id), a hit by its kind (hit_id) with two
##                              readings of the place: a stone held right there was just caught (stone_catch); water
##                              thrown up at the ring's pool is something falling in (ringout_splash)
##   event(name, at, db)        a moment by name (EVENTS: catch, crumble, rise, mend, knock, ringout, count, gong, bell,
##                              match, cheer, roar, groan, ooh, ...); at Vector3.INF it is not placed (the ring's calls)
##   play(id, at, db, pitch)    one id at a point (Vector3.INF: not placed)
##   loop_player(id, parent)    a looping 3D player of an id, not started (the crowd's murmur: RingDressing)
##   warm()                     every id's files loaded (RingLevel's build, behind the loading screen)
## Each play picks a variant at random (never the one before), with the id's pitch and level jitter (TABLE rp, rv) from
## this class's own dice (rng: the game's dice never move for a sound). 3D: inverse-distance falloff from `unit` m
## (the ring's deck is 34 m long: across it a cast falls about 14 dB), heard to `maxd` m, dulled a little with distance.
## Voices: a pool of MAX_VOICES under the scene, at most `cap` of one id at once (its oldest cut), and the same id again
## within SAME_S s and SAME_M m of one just started is dropped (a stream of bolts; the lightning's two calls).
## Buses: Sfx's (World for the elements: its open-air reverb; Ambience for the stands; SFX for the ring's moments), so the
## settings' volumes hold. Headless: ids resolve and are counted (played, recent) but no voice is made unless
## voices_headless (the tests).
## ROUND 4 (READ): shots in flight (the owner's FEEL list: "readable incoming attacks WITHOUT any target cue"; the genre
## times its guards from a shot's sound). Every shot carries a looping voice of its kind (FLIGHTS: stone_whirr, ice_whistle,
## water_rush, fire_flight, air_flight; the Kick's floor wave floor_run; lightning stays instant), synthesized by
## tools/sfx/bend/flight.py:
##   flight(kind, node, db)   a voice following `node` (a BendBolt: its launch; a Gust lift's stone in flight, a bot's spike:
##                            the pool's own watch, so a Spike and a caught stone thrown back whirr too), or null
##   flight_end(node_or_p)    let go: a FLIGHT_OUT_S fade where it ended (a BendBolt's end: its hit, the world, its range)
## The pool: FLIGHT_POOL 3D voices of their own, at most FLIGHT_MAX playing, the ones nearest the listener kept (the rest
## wait silent and take a voice when one is free or they come nearer); doppler tracked on the physics step on these voices
## only (every other sound as before); a steep level curve (each flight row's unit and maxd, FLIGHT_MAX_DB over it), so a
## shot within 6 m is clearly louder; a FLIGHT_IN_S fade in. The listener's own shots (the player whose camera hears)
## play OWN_DB under, so the incoming read leads. Arenas only (a RingArena or a DuelMode in the scene: arena_on): the open
## world's shots stay silent in flight as before.

const DIR := "res://audio/sfx/bend/"
const MAX_VARIANTS := 8
const MAX_VOICES := 24
const MAX_2D := 4
const SAME_S := 0.06
const SAME_M := 2.5
const DIST_CUT_HZ := 6500.0
const DIST_CUT_DB := -10.0

## id -> vol (dB), unit (m: full level within), maxd (m: silent past), bus, rp (pitch jitter: x rp^(-1..1)), rv (level
## jitter: +-rv/2 dB), cap (voices of it at once).
const TABLE := {
	&"earth_cast_rumble": {"vol": 0.0, "unit": 6.0, "maxd": 90.0, "bus": "World", "rp": 1.06, "rv": 2.0, "cap": 3},
	&"earth_cast_crack": {"vol": 0.0, "unit": 6.0, "maxd": 90.0, "bus": "World", "rp": 1.07, "rv": 2.0, "cap": 4},
	&"earth_grind": {"vol": -1.0, "unit": 5.0, "maxd": 70.0, "bus": "World", "rp": 1.06, "rv": 2.0, "cap": 2},
	&"earth_hit": {"vol": 0.0, "unit": 8.0, "maxd": 110.0, "bus": "World", "rp": 1.08, "rv": 2.5, "cap": 4},
	&"earth_rise": {"vol": 0.0, "unit": 8.0, "maxd": 110.0, "bus": "World", "rp": 1.05, "rv": 2.0, "cap": 3},
	&"earth_crumble": {"vol": 0.0, "unit": 8.0, "maxd": 110.0, "bus": "World", "rp": 1.06, "rv": 2.0, "cap": 3},
	&"stone_catch": {"vol": 1.0, "unit": 6.0, "maxd": 90.0, "bus": "World", "rp": 1.05, "rv": 1.5, "cap": 2},
	&"water_cast_rush": {"vol": 0.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.07, "rv": 2.0, "cap": 4},
	&"water_slosh": {"vol": 0.0, "unit": 5.0, "maxd": 70.0, "bus": "World", "rp": 1.07, "rv": 2.0, "cap": 3},
	&"water_hit": {"vol": 0.0, "unit": 7.0, "maxd": 90.0, "bus": "World", "rp": 1.08, "rv": 2.5, "cap": 4},
	&"ice_freeze": {"vol": 0.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.06, "rv": 2.0, "cap": 3},
	&"ice_cast": {"vol": 0.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.07, "rv": 2.0, "cap": 4},
	&"ice_hit": {"vol": 0.0, "unit": 7.0, "maxd": 90.0, "bus": "World", "rp": 1.08, "rv": 2.5, "cap": 4},
	&"fire_whoomph": {"vol": 0.0, "unit": 6.0, "maxd": 90.0, "bus": "World", "rp": 1.08, "rv": 2.0, "cap": 4},
	&"fire_roar": {"vol": 0.0, "unit": 7.0, "maxd": 100.0, "bus": "World", "rp": 1.05, "rv": 2.0, "cap": 3},
	&"fire_crackle": {"vol": 0.0, "unit": 5.0, "maxd": 60.0, "bus": "World", "rp": 1.08, "rv": 2.0, "cap": 2},
	&"fire_hit": {"vol": 0.0, "unit": 7.0, "maxd": 100.0, "bus": "World", "rp": 1.08, "rv": 2.5, "cap": 4},
	&"fire_sizzle": {"vol": 0.0, "unit": 5.0, "maxd": 60.0, "bus": "World", "rp": 1.08, "rv": 2.0, "cap": 2},
	&"air_whoosh": {"vol": 0.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.1, "rv": 2.0, "cap": 4},
	&"air_gust": {"vol": 0.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.07, "rv": 2.0, "cap": 3},
	&"air_swirl": {"vol": 0.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.06, "rv": 2.0, "cap": 2},
	&"air_hit": {"vol": 0.0, "unit": 7.0, "maxd": 90.0, "bus": "World", "rp": 1.08, "rv": 2.5, "cap": 4},
	&"lightning_crack": {"vol": 1.0, "unit": 10.0, "maxd": 160.0, "bus": "World", "rp": 1.05, "rv": 1.5, "cap": 2},
	&"lightning_charge": {"vol": -2.0, "unit": 5.0, "maxd": 60.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 2},
	&"steam_hiss": {"vol": 0.0, "unit": 7.0, "maxd": 90.0, "bus": "World", "rp": 1.08, "rv": 2.0, "cap": 3},
	&"mend": {"vol": 0.0, "unit": 6.0, "maxd": 70.0, "bus": "World", "rp": 1.05, "rv": 1.5, "cap": 2},
	&"heal": {"vol": 0.0, "unit": 5.0, "maxd": 50.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 2},
	&"knock_thud": {"vol": 0.0, "unit": 7.0, "maxd": 90.0, "bus": "World", "rp": 1.08, "rv": 2.0, "cap": 3},
	&"ringout_splash": {"vol": 2.0, "unit": 12.0, "maxd": 160.0, "bus": "World", "rp": 1.06, "rv": 1.5, "cap": 3},
	&"count_tick": {"vol": -4.0, "unit": 30.0, "maxd": 0.0, "bus": "SFX", "rp": 1.0, "rv": 0.0, "cap": 2},
	&"round_gong": {"vol": -2.0, "unit": 30.0, "maxd": 0.0, "bus": "SFX", "rp": 1.02, "rv": 0.5, "cap": 1},
	&"round_bell": {"vol": -3.0, "unit": 30.0, "maxd": 0.0, "bus": "SFX", "rp": 1.01, "rv": 0.5, "cap": 1},
	&"match_gong": {"vol": -1.0, "unit": 30.0, "maxd": 0.0, "bus": "SFX", "rp": 1.01, "rv": 0.5, "cap": 1},
	&"crowd_murmur": {"vol": -6.0, "unit": 14.0, "maxd": 200.0, "bus": "Ambience", "rp": 1.0, "rv": 0.0, "cap": 4},
	&"crowd_cheer": {"vol": -1.0, "unit": 18.0, "maxd": 200.0, "bus": "Ambience", "rp": 1.04, "rv": 2.0, "cap": 4},
	&"crowd_roar": {"vol": 0.0, "unit": 18.0, "maxd": 200.0, "bus": "Ambience", "rp": 1.03, "rv": 1.5, "cap": 2},
	&"crowd_groan": {"vol": -1.0, "unit": 18.0, "maxd": 200.0, "bus": "Ambience", "rp": 1.04, "rv": 1.5, "cap": 2},
	&"crowd_ooh": {"vol": -1.0, "unit": 18.0, "maxd": 200.0, "bus": "Ambience", "rp": 1.04, "rv": 1.5, "cap": 2},
	# round 2 (CORE): each guard's perfect and late (earth's late is stone_catch's thock), the grow's second click, the
	# sputter on the hands, Carried wind's whistle
	&"guard_earth_clean": {"vol": 1.0, "unit": 7.0, "maxd": 100.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 2},
	&"guard_water_clean": {"vol": 0.0, "unit": 7.0, "maxd": 90.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 2},
	&"guard_water_late": {"vol": -1.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.06, "rv": 1.5, "cap": 2},
	&"guard_fire_clean": {"vol": 1.0, "unit": 7.0, "maxd": 100.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 2},
	&"guard_fire_late": {"vol": -1.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.06, "rv": 1.5, "cap": 2},
	&"guard_air_clean": {"vol": 0.0, "unit": 7.0, "maxd": 90.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 2},
	&"guard_air_late": {"vol": -1.0, "unit": 6.0, "maxd": 80.0, "bus": "World", "rp": 1.06, "rv": 1.5, "cap": 2},
	&"lock_grow": {"vol": -2.0, "unit": 4.0, "maxd": 50.0, "bus": "World", "rp": 1.03, "rv": 1.0, "cap": 2},
	&"lock_sputter": {"vol": -4.0, "unit": 4.0, "maxd": 50.0, "bus": "World", "rp": 1.06, "rv": 1.5, "cap": 2},
	&"carried_whistle": {"vol": -3.0, "unit": 5.0, "maxd": 50.0, "bus": "World", "rp": 1.05, "rv": 1.5, "cap": 2},
	# round 4 (READ): the shots' voices in flight (loops; flight(): FLIGHT_MAX at once in all, cap unused). unit 4 m and
	# FLIGHT_MAX_DB: a shot at 2 m is about 15 dB over one at 12 m (level_db)
	&"stone_whirr": {"vol": 0.0, "unit": 4.0, "maxd": 60.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 6, "loop": true},
	&"ice_whistle": {"vol": 0.0, "unit": 4.0, "maxd": 60.0, "bus": "World", "rp": 1.03, "rv": 1.0, "cap": 6, "loop": true},
	&"water_rush": {"vol": 0.0, "unit": 4.0, "maxd": 60.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 6, "loop": true},
	&"fire_flight": {"vol": 0.0, "unit": 4.0, "maxd": 60.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 6, "loop": true},
	&"air_flight": {"vol": 0.0, "unit": 4.0, "maxd": 60.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 6, "loop": true},
	&"floor_run": {"vol": 0.0, "unit": 4.0, "maxd": 50.0, "bus": "World", "rp": 1.04, "rv": 1.0, "cap": 6, "loop": true},
}

## Round 4 (READ): a shot's voice in flight by its kind ("floor": the Kick's floor wave). Lightning has none (instant).
const FLIGHTS := {"stone": &"stone_whirr", "ice": &"ice_whistle", "water": &"water_rush", "fire": &"fire_flight",
		"air": &"air_flight", "floor": &"floor_run"}
## The flight pool: voices of its own, at most FLIGHT_MAX playing (the nearest to the listener kept), the level's cap over
## the inverse-distance curve (dB), the fades (s), the listener's own shots under the rest (dB).
const FLIGHT_POOL := 8
const FLIGHT_MAX := 6
const FLIGHT_MAX_DB := 6.0
const FLIGHT_IN_S := 0.04
const FLIGHT_OUT_S := 0.08
const OWN_DB := -6.0

## Moments by name (event()).
const EVENTS := {
	"catch": &"stone_catch", "crumble": &"earth_crumble", "rise": &"earth_rise", "ice_rise": &"ice_freeze",
	"mend": &"mend", "heal": &"heal", "knock": &"knock_thud", "ringout": &"ringout_splash", "steam": &"steam_hiss",
	"charge": &"lightning_charge", "lightning": &"lightning_crack", "melt": &"fire_sizzle", "burn": &"fire_crackle",
	"count": &"count_tick", "gong": &"round_gong", "bell": &"round_bell", "match": &"match_gong",
	"murmur": &"crowd_murmur", "cheer": &"crowd_cheer", "roar": &"crowd_roar", "groan": &"crowd_groan", "ooh": &"crowd_ooh",
	"grow": &"lock_grow", "sputter": &"lock_sputter", "carried": &"carried_whistle",
	"guard_earth_clean": &"guard_earth_clean", "guard_water_clean": &"guard_water_clean", "guard_water_late": &"guard_water_late",
	"guard_fire_clean": &"guard_fire_clean", "guard_fire_late": &"guard_fire_late", "guard_air_clean": &"guard_air_clean",
	"guard_air_late": &"guard_air_late",
}

## A hit's sound by kind (hit_id reads the place for a catch and the pool).
const HITS := {
	"stone": &"earth_hit", "ice": &"ice_hit", "water": &"water_hit", "fire": &"fire_hit", "air": &"air_hit",
	"lightning": &"lightning_crack", "steam": &"steam_hiss",
}

## A zone's cast by its zone (a zone's spec has no kind: BendEffects hands "stone" for all of them).
const ZONE_CASTS := {
	"catch": &"earth_cast_rumble", "deflect": &"earth_cast_crack",
	"spray": &"water_cast_rush", "water_wall": &"water_cast_rush", "bubble": &"water_slosh", "redirect": &"water_slosh",
	"absorb": &"water_slosh", "ice_patch": &"ice_freeze",
	"smoke": &"fire_whoomph", "fire_wall": &"fire_roar", "burn": &"fire_crackle", "parry": &"fire_whoomph",
	"cushion": &"air_gust", "vacuum": &"air_gust", "dust": &"air_gust", "spin": &"air_swirl", "air_shield": &"air_swirl",
	"tornado": &"air_swirl", "return": &"air_swirl", "wind_wall": &"air_gust", "wind_guard": &"air_swirl",
}

## Casts told apart by the move and mode where the rules by kind and do would miss ("move/mode").
const CAST_BY_MOVE := {
	"earth_shove/pull": &"earth_grind", "fire_blast/fireball": &"fire_roar", "fire_jets/hover": &"fire_roar",
	"footwork/ignite_step": &"fire_crackle", "wind_run/air_scooter": &"air_swirl", "flow/geyser": &"water_cast_rush",
	"wave/push": &"water_cast_rush", "fire_kick/kick": &"fire_roar", "wave/spout": &"water_cast_rush", "air_gust/gust": &"air_gust",
	"air_gust/pull": &"air_gust", "air_wall/wall": &"air_gust",
}

## Each element's cast when nothing else tells (a zone not in ZONE_CASTS).
const ELEMENT_CASTS := {"earth": &"earth_cast_rumble", "water": &"water_slosh", "fire": &"fire_whoomph",
		"air": &"air_gust"}

## This class's own dice (variants, pitch and level jitter): the game's global dice never move for a sound.
static var rng := _seeded()
## Plays asked for that resolved to a sound (headless too), and the last few ids (the tests).
static var played := 0
static var recent: Array[StringName] = []
## Make voices headless too (the tests of the pool).
static var voices_headless := false

static var _streams := {}          ## id -> Array[AudioStream] ([] = none on disk)
static var _on_disk := {}          ## id -> its first variant's file exists (has())
static var _last := {}             ## id -> the variant played last
static var _warned := {}
static var _runner: _Voices
## Round 4: each flight id's looping streams (made once from its files), and the flights started (headless too; the tests).
static var _loops := {}
static var flights_started := 0
static var flight_recent: Array[StringName] = []


static func _seeded() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1750
	return r


# ---------------------------------------------------------------- what plays
## BendLooks.sound's: a cast or a hit of `kind` at `at`, `db` over the id's level.
static func bend(kind: String, what: String, at: Vector3, db := 0.0) -> void:
	var id := &""
	if what == "cast":
		id = _current_cast(kind)
	elif what == "hit":
		id = hit_id(kind, at)
	if id != &"":
		play(id, at, db)


## A moment by name (EVENTS) at `at` (Vector3.INF: not placed).
static func event(name: String, at := Vector3.INF, db := 0.0, pitch := 1.0) -> void:
	var id: StringName = EVENTS.get(name, &"")
	if id != &"":
		play(id, at, db, pitch)


# ---------------------------------------------------------------- in flight (round 4, READ)
## A shot's voice in flight: `kind`'s (FLIGHTS) following `node` (a BendBolt, a GustLift, a bot's spike Flight: where it
## is read each physics step), `db` over its level (the listener's own shots OWN_DB more, read each step: a shot sent back
## at him is his no more). The voice it has now, or null (out of an arena, no such kind, headless, waiting for a voice: it
## takes one once it is among the FLIGHT_MAX nearest). One flight a node.
static func flight(kind: String, node: Node, db := 0.0) -> AudioStreamPlayer3D:
	var id: StringName = FLIGHTS.get(kind, &"")
	if id == &"" or node == null or not is_instance_valid(node) or not node.is_inside_tree() or not has(id):
		return null
	if not arena_on(node.get_tree()):
		return null                               # (the open world's shots stay silent in flight: the gate)
	flights_started += 1
	flight_recent.append(id)
	if flight_recent.size() > 16:
		flight_recent.remove_at(0)
	if DisplayServer.get_name() == "headless" and not voices_headless:
		return null
	var r := _get_runner()
	if r == null or not r.is_inside_tree():
		return null
	return r.flight_start(id, node, db)


## Lets go of the flight of `what` (its node, or the voice flight() gave): the voice fades over FLIGHT_OUT_S where it is
## and is free again. Nothing when there is none.
static func flight_end(what: Object) -> void:
	if what == null or not is_instance_valid(_runner):
		return
	_runner.flight_stop(what)


## The flight kind of BendBolt `b`: its kind, the floor wave's "floor"; "" none (lightning; a reach with no blow, the
## Grab's: no shot).
static func flight_kind(b: BendBolt) -> String:
	if b == null:
		return ""
	if b.floor_wave:
		return "floor"
	if b.damage <= 0.0 and b.knock_mps <= 0.0:
		return ""
	return b.kind if FLIGHTS.has(b.kind) else ""


## A ring or a duel is under way in `tree` (shots sound in flight only there).
static func arena_on(tree: SceneTree) -> bool:
	if tree == null:
		return false
	return RingArena.find(tree) != null or DuelMode.find(tree) != null


## The level (dB) of flight id `id` heard `d` m away: Godot's inverse distance from its unit, capped at FLIGHT_MAX_DB,
## silent past its maxd (-80) (AudioStreamPlayer3D's own formula, with the voice's volume).
static func level_db(id: StringName, d: float, db := 0.0) -> float:
	var c: Dictionary = TABLE.get(id, {})
	var maxd := float(c.get("maxd", 0.0))
	if maxd > 0.0 and d > maxd:
		return -80.0
	var att := linear_to_db(1.0 / (d / float(c.get("unit", 6.0)) + 0.00001)) + float(c.get("vol", 0.0)) + db
	return minf(att, FLIGHT_MAX_DB)


## Where the listener is in `vp` (its AudioListener3D when one is current, else its camera; INF none).
static func listener_pos(vp: Viewport) -> Vector3:
	if vp == null:
		return Vector3.INF
	var l := vp.get_audio_listener_3d()
	if l != null:
		return l.global_position
	var cam := vp.get_camera_3d()
	return cam.global_position if cam != null else Vector3.INF


## The flight voices that have a shot now (fading ones not counted), and every one still sounding (the tests).
static func flight_voices() -> int:
	return _runner.flight_count(false) if is_instance_valid(_runner) else 0


static func flight_sounding() -> int:
	return _runner.flight_count(true) if is_instance_valid(_runner) else 0


## The voice of `node`'s flight now (null: none, or waiting).
static func flight_voice_of(node: Object) -> AudioStreamPlayer3D:
	return _runner.voice_of(node) if is_instance_valid(_runner) else null


## A loop of `id` (variant `n`): its file's stream with its loop set over the whole of it (made once).
static func loop_stream(id: StringName, n: int) -> AudioStream:
	if not _loops.has(id):
		var out := []
		for s: AudioStream in streams(id):
			if s is AudioStreamWAV:
				var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(round(w.get_length() * w.mix_rate))
				out.append(w)
			else:
				out.append(s)
		_loops[id] = out
	var list: Array = _loops[id]
	return list[n % list.size()] if not list.is_empty() else null


## The listener's own shot: `node`'s shooter is the player whose camera hears.
static func own_shot(node: Node, vp: Viewport) -> bool:
	var by: Variant = null
	if node is BendBolt:
		by = (node as BendBolt).caster
	elif node is GustLift:
		by = (node as GustLift).by()
	elif node != null and &"shooter" in node:
		by = node.get(&"shooter")
	if not (by is FrontierPlayer) or not is_instance_valid(by) or vp == null:
		return false
	return (by as FrontierPlayer).camera != null and (by as FrontierPlayer).camera == vp.get_camera_3d()


## The cast BendEffects is making now (its _cur: set just before it calls BendLooks.sound(kind, "cast")): its move's
## spec for the mode, when the record is that cast's; else the kind's own.
static func _current_cast(kind: String) -> StringName:
	var cur: Dictionary = BendEffects._cur
	var move := String(cur.get("move", ""))
	var mode := String(cur.get("mode", ""))
	var sv: Variant = (SwayMoves.move(move).get("bend", {}) as Dictionary).get(mode) if move != "" else null
	var spec: Dictionary = sv if sv is Dictionary else {}
	if String(spec.get("do", "")) != String(cur.get("do", "")):
		spec = {}
	return cast_id(kind, spec, move, mode)


## The sound of casting `mode` of `move` (its bend spec `spec`; `kind` the spec's kind as BendEffects hands it).
static func cast_id(kind: String, spec: Dictionary, move := "", mode := "") -> StringName:
	if spec.has("as") and move != "":
		spec = BendEffects.resolved(move, spec)    # (round 3: a hidden mode standing for another sounds as that one)
		kind = String(spec.get("kind", kind))
	var d := String(spec.get("do", ""))
	var key := "%s/%s" % [move, mode]
	if CAST_BY_MOVE.has(key):
		return CAST_BY_MOVE[key]
	if d == "lightning" or (kind == "lightning" and d != "buff"):
		return &"lightning_crack"
	if d == "buff" and kind == "lightning":
		return &"lightning_charge"
	if d == "heal":
		return &"heal" if Bending.element_of(move) == "water" else &"mend"
	if d == "zone":
		var z := String(spec.get("zone", ""))
		if ZONE_CASTS.has(z):
			return ZONE_CASTS[z]
		return ELEMENT_CASTS.get(Bending.element_of(move), &"earth_cast_rumble")
	match String(spec.get("kind", kind)):
		"stone":
			if d in ["column", "shell", "ramp", "kick_up"]:
				return &"earth_rise"
			if d == "dash":
				return &"earth_grind"
			if d in ["throw", "shove", "bolt"]:
				return &"earth_cast_crack"
			return &"earth_cast_rumble"
		"ice":
			return &"ice_freeze" if d in ["status_at", "freeze_water", "ice_wall"] else &"ice_cast"
		"water":
			return &"water_cast_rush" if d in ["bolt", "dash", "throw"] else &"water_slosh"
		"fire":
			if d == "melt":
				return &"fire_sizzle"
			if d == "ring" or (d == "cone" and float(spec.get("range_m", 0.0)) >= 4.5):
				return &"fire_roar"
			return &"fire_whoomph"
		"air":
			if d == "ring" or d == "buff":
				return &"air_gust"
			return &"air_whoosh"
	return ELEMENT_CASTS.get(Bending.element_of(move), &"earth_cast_rumble")


## The sound of a hit of `kind` at `at`: a stone held right there was just caught; water thrown up at the ring's pool is
## something falling in.
static func hit_id(kind: String, at := Vector3.INF) -> StringName:
	if kind == "stone" and at != Vector3.INF and _held_stone_at(at):
		return &"stone_catch"
	if kind == "water" and at != Vector3.INF and _at_pool(at):
		return &"ringout_splash"
	return HITS.get(kind, &"")


## A stone held by a catch (BendZone: meta bend_held_by) lying at `at`: the catch's own burst point.
static func _held_stone_at(at: Vector3) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for s: Node in tree.get_nodes_in_group(FormStone.GROUP):
		if s is Node3D and s.has_meta(&"bend_held_by") and (s as Node3D).global_position.distance_to(at) < 0.25:
			return true
	return false


## `at` on the surface of a ring's pool (RingWater: just under it is its water).
static func _at_pool(at: Vector3) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for w: Node in tree.get_nodes_in_group(TorchState.WATER_GROUP):
		if w is RingWater and (w as RingWater).is_under_water(at + Vector3.DOWN * 0.3):
			return true
	return false


# ---------------------------------------------------------------- the files
## Whether `id` has at least one file (checked on disk once an id: nothing is loaded; every play asks).
static func has(id: StringName) -> bool:
	if not _on_disk.has(id):
		_on_disk[id] = ResourceLoader.exists(path_of(id, 1))
	return bool(_on_disk[id])


## Every id's files loaded now (the ring's build calls it behind the loading screen: a sound's first play in a fight
## would read its files from disk on that frame).
static func warm() -> void:
	for id: StringName in TABLE:
		streams(id)
		if bool((TABLE[id] as Dictionary).get("loop", false)):
			loop_stream(id, 0)                     # (round 4: the flight loops made here too, not on a shot's first frame)


## The file of variant `n` (1-based) of `id`.
static func path_of(id: StringName, n: int) -> String:
	return "%s%s_%02d.wav" % [DIR, id, n]


## How many variants `id` has on disk.
static func count(id: StringName) -> int:
	var n := 0
	while n < MAX_VARIANTS and ResourceLoader.exists(path_of(id, n + 1)):
		n += 1
	return n


## The loaded variants of `id` (loaded once).
static func streams(id: StringName) -> Array:
	if _streams.has(id):
		return _streams[id]
	var out := []
	for i in count(id):
		var s := load(path_of(id, i + 1)) as AudioStream
		if s != null:
			out.append(s)
	if out.is_empty() and not _warned.has(id):
		_warned[id] = true
		push_warning("BendSounds: no files for '%s' (python3 tools/sfx/bend/bend_sfx.py, then a Godot import)" % id)
	_streams[id] = out
	return out


static func _pick(id: StringName) -> AudioStream:
	var list := streams(id)
	if list.is_empty():
		return null
	var n := list.size()
	var i := rng.randi() % n
	if n > 1 and i == int(_last.get(id, -1)):
		i = (i + 1 + rng.randi() % (n - 1)) % n
	_last[id] = i
	return list[i]


# ---------------------------------------------------------------- playing
## `id` at `at` (Vector3.INF: not placed), `db` over its level, `pitch` times its jitter. The voice, or null (headless,
## dropped as a repeat, no file, out of the tree).
static func play(id: StringName, at := Vector3.INF, db := 0.0, pitch := 1.0) -> Node:
	if not TABLE.has(id):
		if not _warned.has(id):
			_warned[id] = true
			push_warning("BendSounds: '%s' is not in the table" % id)
		return null
	if not has(id):
		return null
	if bool((TABLE[id] as Dictionary).get("loop", false)):
		if not _warned.has(id):
			_warned[id] = true
			push_warning("BendSounds: '%s' is a flight loop (flight(), not play())" % id)
		return null
	played += 1
	recent.append(id)
	if recent.size() > 16:
		recent.remove_at(0)
	if DisplayServer.get_name() == "headless" and not voices_headless:
		return null
	var r := _get_runner()
	if r == null or not r.is_inside_tree():
		return null
	var placed := at != Vector3.INF
	if placed and r.repeated(id, at):
		return null
	var s := _pick(id)
	if s == null:
		return null
	var c: Dictionary = TABLE[id]
	var p: Node
	if placed:
		p = r.voice_3d(id, int(c.get("cap", 3)))
	else:
		p = r.voice_2d()
	p.set(&"stream", s)
	p.set(&"bus", _bus(String(c.get("bus", "SFX"))))
	if placed:
		_setup_3d(p as AudioStreamPlayer3D, c, at)
	var rv := float(c.get("rv", 0.0))
	var rp := float(c.get("rp", 1.0))
	p.set(&"volume_db", float(c.get("vol", 0.0)) + db + rng.randf_range(-0.5, 0.5) * rv)
	p.set(&"pitch_scale", maxf(pitch * pow(rp, rng.randf_range(-1.0, 1.0)), 0.05))
	p.call(&"play")
	return p


## A looping 3D player of `id` (variant `variant`, its loop set over the whole file), added to `parent`, not started; null
## when there is no file.
static func loop_player(id: StringName, parent: Node, variant := 0) -> AudioStreamPlayer3D:
	var list := streams(id)
	if list.is_empty() or parent == null:
		return null
	var s := (list[variant % list.size()] as AudioStream)
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
		s = w
	var c: Dictionary = TABLE.get(id, {})
	var p := AudioStreamPlayer3D.new()
	p.name = "Sound_" + String(id)
	p.stream = s
	p.bus = _bus(String(c.get("bus", "SFX")))
	parent.add_child(p)
	_setup_3d(p, c, Vector3.INF)
	p.volume_db = float(c.get("vol", 0.0))
	return p


static func _setup_3d(p: AudioStreamPlayer3D, c: Dictionary, at: Vector3) -> void:
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = float(c.get("unit", 6.0))
	p.max_distance = float(c.get("maxd", 0.0))
	p.max_db = FLIGHT_MAX_DB if bool(c.get("loop", false)) else 3.0
	p.panning_strength = 1.0
	p.attenuation_filter_cutoff_hz = DIST_CUT_HZ
	p.attenuation_filter_db = DIST_CUT_DB
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	if at != Vector3.INF:
		p.global_position = at


static func _bus(b: String) -> StringName:
	Sfx.setup_buses()
	return StringName(b) if AudioServer.get_bus_index(StringName(b)) != -1 else &"Master"


## The voices playing now (the tests).
static func playing() -> int:
	if not is_instance_valid(_runner):
		return 0
	var n := 0
	for p in _runner.voices3:
		n += 1 if p.playing else 0
	for p in _runner.voices2:
		n += 1 if p.playing else 0
	return n


static func _get_runner() -> _Voices:
	if is_instance_valid(_runner):
		return _runner
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	_runner = _Voices.new()
	_runner.name = "BendSoundVoices"
	if host.is_node_ready() and host != tree.root:
		host.add_child(_runner)
	else:
		host.add_child.call_deferred(_runner)
	return _runner


## The pool: 3D voices (MAX_VOICES, at most a cap of one id at once), a few 2D ones, and what started lately (repeats).
class _Voices extends Node:
	var voices3: Array[AudioStreamPlayer3D] = []
	var voices2: Array[AudioStreamPlayer] = []
	var _serial := 0
	var _started: Array = []          ## [id, at, msec]

	## The same id started within SAME_S s and SAME_M m of `at`: drop this one. Else noted.
	func repeated(id: StringName, at: Vector3) -> bool:
		var now := Time.get_ticks_msec()
		var keep: Array = []
		var hit := false
		for e: Array in _started:
			if now - int(e[2]) > int(SAME_S * 1000.0):
				continue
			keep.append(e)
			if e[0] == id and (e[1] as Vector3).distance_to(at) < SAME_M:
				hit = true
		_started = keep
		if not hit:
			_started.append([id, at, now])
		return hit

	func voice_3d(id: StringName, cap: int) -> AudioStreamPlayer3D:
		var same: Array[AudioStreamPlayer3D] = []
		var free: AudioStreamPlayer3D = null
		var oldest: AudioStreamPlayer3D = null
		for p in voices3:
			if not p.playing:
				if free == null:
					free = p
				continue
			if StringName(p.get_meta(&"id", &"")) == id:
				same.append(p)
			if oldest == null or int(p.get_meta(&"serial")) < int(oldest.get_meta(&"serial")):
				oldest = p
		var v: AudioStreamPlayer3D = free
		if cap > 0 and same.size() >= cap:
			same.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get_meta(&"serial")) < int(b.get_meta(&"serial")))
			v = same[0]
		elif v == null and voices3.size() < MAX_VOICES:
			v = AudioStreamPlayer3D.new()
			add_child(v)
			voices3.append(v)
		elif v == null:
			v = oldest
		if v.playing:
			v.stop()
		_serial += 1
		v.set_meta(&"serial", _serial)
		v.set_meta(&"id", id)
		return v

	func voice_2d() -> AudioStreamPlayer:
		var oldest: AudioStreamPlayer = null
		for p in voices2:
			if not p.playing:
				return _mark(p) as AudioStreamPlayer
			if oldest == null or int(p.get_meta(&"serial")) < int(oldest.get_meta(&"serial")):
				oldest = p
		if voices2.size() < MAX_2D or oldest == null:
			var v := AudioStreamPlayer.new()
			add_child(v)
			voices2.append(v)
			return _mark(v) as AudioStreamPlayer
		oldest.stop()
		return _mark(oldest) as AudioStreamPlayer

	func _mark(p: Node) -> Node:
		_serial += 1
		p.set_meta(&"serial", _serial)
		return p

	# ------------------------------------------------------------ round 4: the flights
	## The shots in flight: {node, id, db, voice (null: waiting), out}; their voices (FLIGHT_POOL at most), each with metas
	## gain (0..1), fade (1 in, 0 held, -1 out), base_db.
	var flights: Array[Dictionary] = []
	var fvoices: Array[AudioStreamPlayer3D] = []
	var _flight_of := {}              ## node instance id -> its flight

	func _ready() -> void:
		process_physics_priority = 100        # (after the shots have moved this step)

	func flight_start(id: StringName, node: Node, db: float) -> AudioStreamPlayer3D:
		var nid := node.get_instance_id()
		if _flight_of.has(nid):
			return (_flight_of[nid] as Dictionary).get("voice")
		var e := {"node": node, "nid": nid, "id": id, "db": db, "voice": null, "out": false, "at": _pos(node)}
		flights.append(e)
		_flight_of[nid] = e
		_rank()
		return e.voice

	func flight_stop(what: Object) -> void:
		for e: Dictionary in flights:
			if e.out:
				continue
			if e.voice == what or (is_instance_valid(e.node) and e.node == what) or int(e.nid) == what.get_instance_id():
				_end_flight(e)
				return

	func voice_of(what: Object) -> AudioStreamPlayer3D:
		var e: Variant = _flight_of.get(what.get_instance_id()) if what != null else null
		return (e as Dictionary).get("voice") if e is Dictionary else null

	func flight_count(fading: bool) -> int:
		var n := 0
		for v in fvoices:
			if v.playing and (fading or int(v.get_meta(&"fade", 0)) >= 0):
				n += 1
		return n

	func _end_flight(e: Dictionary) -> void:
		e.out = true
		_flight_of.erase(e.nid)
		if e.voice != null:
			_let_go(e.voice)
			e.voice = null

	func _let_go(v: AudioStreamPlayer3D) -> void:
		v.set_meta(&"fade", -1)
		v.set_meta(&"node", null)

	func _physics_process(dt: float) -> void:
		if flights.is_empty() and not _sounding() and not _watching():
			return
		_watch()
		var keep: Array[Dictionary] = []
		for e: Dictionary in flights:
			if not e.out and not _flying(e.node):
				_end_flight(e)
			if not e.out:
				e.at = _pos(e.node)
				keep.append(e)
		flights = keep
		_rank()
		_fade(dt)

	## Each flight's place to the listener: the FLIGHT_MAX nearest have voices, the rest wait (their voices let go).
	func _rank() -> void:
		var lp := BendSounds.listener_pos(get_viewport())
		var order := flights.filter(func(e: Dictionary) -> bool: return not e.out)
		if lp.is_finite():
			order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return (a.at as Vector3).distance_squared_to(lp) < (b.at as Vector3).distance_squared_to(lp))
		for i in order.size():
			var e: Dictionary = order[i]
			if i < FLIGHT_MAX and e.voice == null:
				e.voice = _give(e)
			elif i >= FLIGHT_MAX and e.voice != null:
				_let_go(e.voice)
				e.voice = null

	func _give(e: Dictionary) -> AudioStreamPlayer3D:
		var v: AudioStreamPlayer3D = null
		var quiet: AudioStreamPlayer3D = null
		for p in fvoices:
			if not p.playing:
				v = p
				break
			if int(p.get_meta(&"fade", 0)) < 0 and (quiet == null or float(p.get_meta(&"gain", 0.0)) < float(quiet.get_meta(&"gain", 0.0))):
				quiet = p
		if v == null and fvoices.size() < FLIGHT_POOL:
			v = AudioStreamPlayer3D.new()
			v.name = "Flight%d" % fvoices.size()
			# (round 4's merge: a shot's voice holds with the tree, even while the Splash Cam keeps this pool running for its own
			# sounds: a stone frozen in flight under the replay does not whirr on)
			v.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(v)
			fvoices.append(v)
		if v == null:
			v = quiet
		if v == null:
			return null
		if v.playing:
			v.stop()
		var c: Dictionary = TABLE[e.id]
		var s := BendSounds.loop_stream(e.id, BendSounds.rng.randi())
		if s == null:
			return null
		v.stream = s
		v.bus = BendSounds._bus(String(c.get("bus", "World")))
		v.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		BendSounds._setup_3d(v, c, e.at)
		# (tracking from here: switched on at its new place, so the step from its last shot is no speed)
		v.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		var rv := float(c.get("rv", 0.0))
		v.set_meta(&"base_db", float(c.get("vol", 0.0)) + float(e.db) + BendSounds.rng.randf_range(-0.5, 0.5) * rv)
		v.set_meta(&"gain", 0.0)
		v.set_meta(&"fade", 1)
		v.set_meta(&"node", e.node)
		v.set_meta(&"id", e.id)
		v.pitch_scale = maxf(pow(float(c.get("rp", 1.0)), BendSounds.rng.randf_range(-1.0, 1.0)), 0.05)
		v.volume_db = -80.0
		v.play(BendSounds.rng.randf() * maxf(s.get_length() - 0.05, 0.0))
		return v

	## The voices' fades, places and levels (each physics step).
	func _fade(dt: float) -> void:
		var vp := get_viewport()
		for v in fvoices:
			if not v.playing:
				continue
			var f := int(v.get_meta(&"fade", 0))
			var g := float(v.get_meta(&"gain", 0.0))
			if f > 0:
				g = minf(g + dt / FLIGHT_IN_S, 1.0)
				if g >= 1.0:
					v.set_meta(&"fade", 0)
			elif f < 0:
				g = maxf(g - dt / FLIGHT_OUT_S, 0.0)
				if g <= 0.0:
					v.stop()
					v.set_meta(&"gain", 0.0)
					continue
			v.set_meta(&"gain", g)
			var n: Variant = v.get_meta(&"node", null)
			var own := false
			if n is Node and is_instance_valid(n):
				v.global_position = _pos(n)
				own = BendSounds.own_shot(n, vp)
			v.set_meta(&"own", own)
			v.volume_db = float(v.get_meta(&"base_db", 0.0)) + (OWN_DB if own else 0.0) + linear_to_db(maxf(g, 0.0001))

	func _sounding() -> bool:
		for v in fvoices:
			if v.playing:
				return true
		return false

	## Whether the pool watches the Gust lifts and the bots' spikes (an arena only).
	func _watching() -> bool:
		return BendSounds.arena_on(get_tree())

	## The stones not launched as a BendBolt: a Gust lift's stone in flight (the Spike, the Boulder, a caught stone thrown
	## back), a bot's spike: each its whirr while it flies (a caught stone held has none: it is no lift in flight).
	func _watch() -> void:
		if not _watching():
			return
		for n in get_tree().get_nodes_in_group(GustLift.GROUP):
			var l := n as GustLift
			if l != null and l.phase == GustLift.Phase.FLIGHT and not _flight_of.has(l.get_instance_id()) \
					and l.stone != null and is_instance_valid(l.stone):
				BendSounds.flight("stone", l)
		for n in get_tree().get_nodes_in_group(NpcBending.FLIGHT_GROUP):
			var st: Variant = n.get(&"stone")
			if st is Node3D and is_instance_valid(st) and not _flight_of.has(n.get_instance_id()):
				BendSounds.flight("stone", n)

	## Still in flight: a bolt not spent, a lift still flying, a bot's spike with its stone.
	func _flying(n: Variant) -> bool:
		if not (n is Node) or not is_instance_valid(n) or not (n as Node).is_inside_tree() or (n as Node).is_queued_for_deletion():
			return false
		if n is BendBolt:
			return not (n as BendBolt).spent
		if n is GustLift:
			var l := n as GustLift
			return l.phase == GustLift.Phase.FLIGHT and l.stone != null and is_instance_valid(l.stone)
		var st: Variant = (n as Node).get(&"stone")
		if st != null:
			return st is Node3D and is_instance_valid(st)
		return true

	## Where a flight is now: a lift's or a spike's stone, else the node itself.
	func _pos(n: Variant) -> Vector3:
		if n is GustLift and (n as GustLift).stone != null and is_instance_valid((n as GustLift).stone):
			return (n as GustLift).stone.global_position
		if n is Node and not (n is Node3D):
			var st: Variant = (n as Node).get(&"stone")
			if st is Node3D and is_instance_valid(st):
				return (st as Node3D).global_position
		if n is Node3D:
			return (n as Node3D).global_position
		return Vector3.ZERO
