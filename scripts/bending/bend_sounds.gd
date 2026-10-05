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
}

## Moments by name (event()).
const EVENTS := {
	"catch": &"stone_catch", "crumble": &"earth_crumble", "rise": &"earth_rise", "ice_rise": &"ice_freeze",
	"mend": &"mend", "heal": &"heal", "knock": &"knock_thud", "ringout": &"ringout_splash", "steam": &"steam_hiss",
	"charge": &"lightning_charge", "lightning": &"lightning_crack", "melt": &"fire_sizzle", "burn": &"fire_crackle",
	"count": &"count_tick", "gong": &"round_gong", "bell": &"round_bell", "match": &"match_gong",
	"murmur": &"crowd_murmur", "cheer": &"crowd_cheer", "roar": &"crowd_roar", "groan": &"crowd_groan", "ooh": &"crowd_ooh",
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
	"tornado": &"air_swirl", "return": &"air_swirl",
}

## Casts told apart by the move and mode where the rules by kind and do would miss ("move/mode").
const CAST_BY_MOVE := {
	"earth_shove/pull": &"earth_grind", "fire_blast/fireball": &"fire_roar", "fire_jets/hover": &"fire_roar",
	"footwork/ignite_step": &"fire_crackle", "wind_run/air_scooter": &"air_swirl", "flow/geyser": &"water_cast_rush",
	"wave/push": &"water_cast_rush",
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
	p.max_db = 3.0
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
