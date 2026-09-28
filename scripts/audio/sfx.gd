class_name Sfx
extends RefCounted
## Sound-effect player: a static API, no autoload.
##
##   Sfx.setup(level)                               buses, voice pool under `level`, preload
##   Sfx.play_3d(&"musket_shot", pos)               one-shot at a point
##   Sfx.play_2d(&"musket_tail")                    non-positional one-shot
##   Sfx.attach(&"arrow_whoosh", node)              one-shot riding on a moving node
##   Sfx.impact(kind, collider, point, normal, speed)   projectile hit, sound by surface
##
## Every id has 1-4 variant WAVs; each play picks one at random (never the same twice in a
## row) with a little random pitch and volume. The variants and each id's bus, volume and 3D
## attenuation come from sfx_manifest.gd, which tools/sfx/gen_manifest.py generates. The
## `gain_db` and `pitch` arguments are relative to those defaults. Missing files are skipped
## with one warning per id, so the game runs with no audio on disk.
##
## 3D voices come from a pool of AudioStreamPlayer3D nodes under the level (the oldest voice
## is cut when all are busy). Sounds within NEAR_FILTER_M of the listener play unfiltered; a
## high-shelf cut fades in with distance, so far shots and hits arrive muffled.
##
## play_3d / play_2d options (`opts`):
##   delay: float      seconds before playing (cue timelines). Without it, ids flagged
##                     "travel" (impacts, targets) wait for the sound to reach the listener.
##   tag: String       label for cancel(tag): drops pending plays, fades playing voices
##   follow: Node3D    keep the voice at follow.global_position + offset while it plays
##   offset: Vector3   world-space offset from `follow`
##   group: String, max: int   voice limit for a group (its oldest voice is cut)
##   from: float       start position in seconds

const _M := preload("res://scripts/audio/sfx_manifest.gd")

const MAX_3D := 48
const MAX_2D := 12
const SPEED_OF_SOUND := 343.0
const MAX_TRAVEL_DELAY := 0.4
const NEAR_FILTER_M := 8.0       ## No distance filtering this close to the listener...
const FAR_FILTER_M := 48.0       ## ...full filter depth from here on.
const FLYBY_RADIUS := 3.0

static var _runner: _Runner
static var _cache := {}          ## id -> [[AudioStream, gain_db], ...] ([] = missing)
static var _last := {}           ## id -> last variant index
static var _warned := {}


# --- Setup -------------------------------------------------------------------------------

## Builds the buses, puts the voice pool under `host` (the level) and loads every sound.
## Safe to call more than once.
static func setup(host: Node = null) -> void:
	setup_buses()
	_ensure_runner(host)
	for id: String in _M.FILES:
		_streams(id)


## Bus layout, built in code because project.godot has none. Idempotent.
##   Master    hard limiter at -0.3 dB (stacked shots)
##   SFX       -> Master, group fader
##   Ambience  -> Master -4 dB, ducked by the Weapons bus (sidechain compressor)
##   Weapons   -> SFX, gentle glue compressor (lock, pan and shot layers)
##   Tails     -> SFX -3 dB, 45 Hz highpass (baked stereo echo tails)
##   Foley     -> SFX -2 dB, 70 Hz highpass + a touch of small-room air
##   World     -> SFX, outdoor reverb for impacts and targets
static func setup_buses() -> void:
	if AudioServer.get_bus_index(&"SFX") != -1:
		return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.3
	limiter.release = 0.1
	AudioServer.add_bus_effect(0, limiter)
	_add_bus("SFX", "Master", 0.0, [])

	# A shot at full scale ducks wind and birds by about 7 dB; they swell back over ~1 s.
	var duck := AudioEffectCompressor.new()
	duck.threshold = -14.0
	duck.ratio = 2.2
	duck.attack_us = 2000.0
	duck.release_ms = 900.0
	duck.sidechain = &"Weapons"
	_add_bus("Ambience", "Master", -4.0, [duck])

	# Slow enough attack to let the crack through; the Master limiter catches the rest.
	var glue := AudioEffectCompressor.new()
	glue.threshold = -8.0
	glue.ratio = 2.0
	glue.attack_us = 3000.0
	glue.release_ms = 150.0
	_add_bus("Weapons", "SFX", 0.0, [glue])

	var hp45 := AudioEffectHighPassFilter.new()
	hp45.cutoff_hz = 45.0
	_add_bus("Tails", "SFX", -3.0, [hp45])

	var hp70 := AudioEffectHighPassFilter.new()
	hp70.cutoff_hz = 70.0
	var air := AudioEffectReverb.new()
	air.room_size = 0.2
	air.damping = 0.8
	air.spread = 0.6
	air.hipass = 0.3
	air.predelay_msec = 10.0
	air.dry = 1.0
	air.wet = 0.05
	_add_bus("Foley", "SFX", -2.0, [hp70, air])

	var outdoor := AudioEffectReverb.new()
	outdoor.room_size = 0.5
	outdoor.damping = 0.65
	outdoor.spread = 0.9
	outdoor.hipass = 0.2
	outdoor.predelay_msec = 35.0
	outdoor.predelay_feedback = 0.25
	outdoor.dry = 1.0
	outdoor.wet = 0.12
	_add_bus("World", "SFX", 0.0, [outdoor])


static func _add_bus(bus_name: String, send: String, volume_db: float, effects: Array) -> void:
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, send)
	AudioServer.set_bus_volume_db(i, volume_db)
	for e: AudioEffect in effects:
		AudioServer.add_bus_effect(i, e)


# --- Playback ----------------------------------------------------------------------------

## One-shot at `pos`. Returns the voice, or null when delayed, missing or out of the tree.
static func play_3d(id: StringName, pos: Vector3, gain_db := 0.0, pitch := 1.0, opts := {}) -> AudioStreamPlayer3D:
	var key := String(id)
	var r := _get_runner()
	if r == null:
		return null
	var c := config(key)
	var delay := float(opts.get("delay", -1.0))
	if delay < 0.0 and bool(c.get("travel", false)):
		delay = travel_delay(pos)
	if delay > 0.0:
		var o: Dictionary = opts.duplicate()
		o["delay"] = 0.0
		r.later(delay, String(opts.get("tag", "")), func() -> void: play_3d(key, pos, gain_db, pitch, o))
		return null
	var pick := _pick(key)
	if pick.is_empty():
		return null
	var p := r.voice_3d(String(opts.get("group", "")), int(opts.get("max", 0)))
	var fv: Variant = opts.get("follow")
	var follow: Node3D = fv as Node3D if is_instance_valid(fv) else null
	var offset: Vector3 = opts.get("offset", Vector3.ZERO)
	if follow and follow.is_inside_tree():
		pos = follow.global_position + offset
		p.set_meta(&"follow", follow)
		p.set_meta(&"offset", offset)
	p.set_meta(&"tag", String(opts.get("tag", "")))
	p.set_meta(&"group", String(opts.get("group", "")))
	p.stream = pick[0]
	_setup_3d(p, c, pos)
	_randomize(p, c, gain_db + float(pick[1]), pitch)
	p.global_position = pos
	p.play(float(opts.get("from", 0.0)))
	return p


## Non-positional one-shot (echo tails, UI-like sounds).
static func play_2d(id: StringName, gain_db := 0.0, pitch := 1.0, opts := {}) -> AudioStreamPlayer:
	var key := String(id)
	var r := _get_runner()
	if r == null:
		return null
	var delay := float(opts.get("delay", 0.0))
	if delay > 0.0:
		var o: Dictionary = opts.duplicate()
		o.erase("delay")
		r.later(delay, String(opts.get("tag", "")), func() -> void: play_2d(key, gain_db, pitch, o))
		return null
	var pick := _pick(key)
	if pick.is_empty():
		return null
	var c := config(key)
	var p := r.voice_2d()
	p.set_meta(&"tag", String(opts.get("tag", "")))
	p.stream = pick[0]
	p.bus = _bus_name(c)
	_randomize(p, c, gain_db + float(pick[1]), pitch)
	p.play(float(opts.get("from", 0.0)))
	return p


## One-shot parented to a moving node (it follows the node and frees itself when done).
## Doppler is tracked per physics step. Stop it early with Sfx.stop(voice).
static func attach(id: StringName, node: Node3D, gain_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var key := String(id)
	if node == null or not node.is_inside_tree():
		return null
	var pick := _pick(key)
	if pick.is_empty():
		return null
	var c := config(key)
	var p := AudioStreamPlayer3D.new()
	p.name = "Sfx_" + key
	p.stream = pick[0]
	p.set_meta(&"owned", true)
	node.add_child(p)
	_setup_3d(p, c, node.global_position)
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	_randomize(p, c, gain_db + float(pick[1]), pitch)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Stops a voice, fading over `fade` seconds. Voices made by attach() are freed.
static func stop(voice: Variant, fade := 0.04) -> void:
	if not is_instance_valid(voice) or not voice is Node:
		return
	var p := voice as Node
	var owned := bool(p.get_meta(&"owned", false))
	if fade <= 0.0 or not p.is_inside_tree():
		p.call(&"stop")
		if owned:
			p.queue_free()
		return
	_kill_tween(p)
	var t := p.create_tween()
	t.tween_property(p, "volume_db", -60.0, fade)
	t.tween_callback(Callable(p, &"stop"))
	if owned:
		t.tween_callback(p.queue_free)
	p.set_meta(&"tween", t)


## Drops pending plays with `tag` and fades its playing voices (interrupted reloads).
static func cancel(tag: String, fade := 0.06) -> void:
	if tag == "" or not is_instance_valid(_runner):
		return
	_runner.drop(tag)
	for p in _runner.voices3:
		if p.playing and String(p.get_meta(&"tag", "")) == tag:
			stop(p, fade)
	for p in _runner.voices2:
		if p.playing and String(p.get_meta(&"tag", "")) == tag:
			stop(p, fade)


## Drops pending (not yet started) plays with `tag`, leaving playing voices alone. True if
## any were still waiting.
static func drop_pending(tag: String) -> bool:
	if tag == "" or not is_instance_valid(_runner):
		return false
	return _runner.drop(tag) > 0


## Projectile hit: plays arrow_hit_<surface> or ball_hit_<surface> at the point, louder for
## faster hits. Like every impact and target sound it is delayed by the sound's travel time
## (manifest "travel"), so a hit and the dummy's reaction layered on it stay together.
static func impact(kind: Projectile.Kind, collider: Object, point: Vector3, normal: Vector3, speed: float) -> void:
	var id := ("arrow_hit_" if kind == Projectile.Kind.ARROW else "ball_hit_") + surface_of(collider, point, normal)
	var c := config(id)
	var gain := linear_to_db(clampf(speed / float(c.get("sref", 62.0)), float(c.get("smin", 0.25)), 1.0))
	play_3d(id, point, gain)


## Close pass of a ball (someone else's shot): plays ball_whizz at the closest point of the
## step segment when it passes within FLYBY_RADIUS of the listener. True if it played.
static func flyby(from: Vector3, to: Vector3) -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var ear := cam.global_position
	var seg := to - from
	var t := clampf((ear - from).dot(seg) / maxf(seg.length_squared(), 1e-6), 0.0, 1.0)
	var closest := from + seg * t
	if closest.distance_to(ear) > FLYBY_RADIUS:
		return false
	play_3d(&"ball_whizz", closest)
	return true


## Surface name for sound selection: wood, straw, dirt, grass or stone.
##   1. meta "surface" on the collider
##   2. meta hit_part "post" -> wood, "head" -> straw
##   3. inside a TargetDummy -> straw
##   4. level ground (normal up, y < 0.05): dirt on the fort floor and range lane, else grass
##   5. sphere shapes (rocks) and the 0.9 x 1.6 x 0.9 chimney -> stone; 1.6 x 0.9 x 0.9 hay bales
##      -> straw
##   6. anything else (palisade, buildings, crates, barrels, trees) -> wood
static func surface_of(collider: Object, point: Vector3, normal: Vector3) -> String:
	var node := collider as Node
	if node == null:
		return "wood"
	if node.has_meta(&"surface"):
		return String(node.get_meta(&"surface"))
	var part := String(node.get_meta(&"hit_part", ""))
	if part == "post":
		return "wood"
	if part == "head":
		return "straw"
	var n := node
	while n:
		if n is TargetDummy:
			return "straw"
		n = n.get_parent()
	if normal.y > 0.7 and point.y < 0.05:
		return "dirt" if is_dirt(point) else "grass"
	for child in node.get_children():
		var cs := child as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is SphereShape3D:
			return "stone"
		if cs.shape is BoxShape3D:
			var s: Vector3 = (cs.shape as BoxShape3D).size
			if _near(s, Vector3(0.9, 1.6, 0.9)):
				return "stone"
			if _near(s, Vector3(1.6, 0.9, 0.9)):
				return "straw"
		break
	return "wood"


## Packed dirt: the fort floor and the range lane (frontier_level.gd).
static func is_dirt(p: Vector3) -> bool:
	return (absf(p.x) < 16.0 and absf(p.z) < 16.0) or (absf(p.x) < 5.0 and p.z < -20.0 and p.z > -160.0)


## Seconds a sound from `pos` takes to reach the listener (0 within 10 m, at most 0.4 s).
static func travel_delay(pos: Vector3) -> float:
	var cam := _camera()
	if cam == null:
		return 0.0
	var d := cam.global_position.distance_to(pos)
	return 0.0 if d < 10.0 else minf(d / SPEED_OF_SOUND, MAX_TRAVEL_DELAY)


# --- Streams -----------------------------------------------------------------------------

## True if the id has at least one loadable file.
static func has(id: StringName) -> bool:
	return not _streams(String(id)).is_empty()


## Playback defaults for an id (bus, vol, rp, rv, unit, maxd, maxdb, cut, fdb, loop, ...).
static func config(id: StringName) -> Dictionary:
	return _M.DEFAULTS.get(String(id), {})


## The loaded variant streams of an id (looping ids come back with looping enabled).
static func variants(id: StringName) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for e: Array in _streams(String(id)):
		out.append(e[0])
	return out


## A dedicated (not pooled) 3D player for a looping sound, configured from the manifest and
## added to `parent`. Not started. Null if the sound is missing.
static func make_player_3d(id: StringName, parent: Node, variant := 0) -> AudioStreamPlayer3D:
	var key := String(id)
	var list := _streams(key)
	if list.is_empty() or parent == null:
		return null
	var c := config(key)
	var p := AudioStreamPlayer3D.new()
	p.name = "Sfx_" + key
	p.stream = list[variant % list.size()][0]
	parent.add_child(p)
	_setup_3d(p, c, p.global_position if p.is_inside_tree() else Vector3.ZERO)
	p.volume_db = float(c.get("vol", 0.0))
	return p


## A dedicated 2D player for a looping bed. Not started. Null if the sound is missing.
static func make_player_2d(id: StringName, parent: Node, variant := 0) -> AudioStreamPlayer:
	var key := String(id)
	var list := _streams(key)
	if list.is_empty() or parent == null:
		return null
	var c := config(key)
	var p := AudioStreamPlayer.new()
	p.name = "Sfx_" + key
	p.stream = list[variant % list.size()][0]
	p.bus = _bus_name(c)
	p.volume_db = float(c.get("vol", 0.0))
	parent.add_child(p)
	return p


static func _streams(key: String) -> Array:
	if _cache.has(key):
		return _cache[key]
	var out := []
	var paths: Array = _M.FILES.get(key, [])
	var gains: Array = _M.FILE_GAIN.get(key, [])
	var loop := bool(config(key).get("loop", false))
	for i in paths.size():
		var path: String = paths[i]
		if not ResourceLoader.exists(path):
			continue
		var s := load(path) as AudioStream
		if s == null:
			continue
		if loop and s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(round(w.get_length() * w.mix_rate))
		out.append([s, float(gains[i]) if i < gains.size() else 0.0])
	if out.is_empty() and not _warned.has(key):
		_warned[key] = true
		push_warning("Sfx: no playable files for '%s' (run tools/sfx/gen_manifest.py and a Godot import)" % key)
	_cache[key] = out
	return out


## Random variant, never the same one twice in a row: [stream, gain_db] or [].
static func _pick(key: String) -> Array:
	var list := _streams(key)
	if list.is_empty():
		return []
	var n := list.size()
	var i := randi() % n
	if n > 1 and i == int(_last.get(key, -1)):
		i = (i + 1 + randi() % (n - 1)) % n
	_last[key] = i
	return list[i]


static func _setup_3d(p: AudioStreamPlayer3D, c: Dictionary, pos: Vector3) -> void:
	p.bus = _bus_name(c)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = float(c.get("unit", 3.0))
	p.max_distance = float(c.get("maxd", 0.0))
	p.max_db = float(c.get("maxdb", 3.0))
	p.panning_strength = 1.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	# High-shelf cut that deepens with distance; off near the listener.
	var cam := _camera()
	var d := cam.global_position.distance_to(pos) if cam else 0.0
	var depth := clampf((d - NEAR_FILTER_M) / (FAR_FILTER_M - NEAR_FILTER_M), 0.0, 1.0)
	if bool(c.get("loop", false)):
		depth = 1.0     # Loops outlive the listener position they started at.
	p.attenuation_filter_cutoff_hz = float(c.get("cut", 5000.0))
	p.attenuation_filter_db = float(c.get("fdb", -24.0)) * depth


static func _randomize(p: Node, c: Dictionary, gain_db: float, pitch: float) -> void:
	var rp := float(c.get("rp", 1.0))
	var rv := float(c.get("rv", 0.0))
	p.set(&"volume_db", float(c.get("vol", 0.0)) + gain_db + randf_range(-0.5, 0.5) * rv)
	p.set(&"pitch_scale", maxf(pitch * pow(rp, randf_range(-1.0, 1.0)), 0.05))


static func _bus_name(c: Dictionary) -> StringName:
	var b := StringName(c.get("bus", "SFX"))
	return b if AudioServer.get_bus_index(b) != -1 else &"Master"


static func _near(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) <= 0.05 and absf(a.y - b.y) <= 0.05 and absf(a.z - b.z) <= 0.05


static func _kill_tween(p: Node) -> void:
	if p.has_meta(&"tween"):
		var t := p.get_meta(&"tween") as Tween
		if t and t.is_valid():
			t.kill()
		p.remove_meta(&"tween")


static func _camera() -> Camera3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_viewport().get_camera_3d()


static func _ensure_runner(host: Node) -> void:
	if is_instance_valid(_runner):
		return
	setup_buses()
	var tree := Engine.get_main_loop() as SceneTree
	if host == null and tree:
		host = tree.current_scene
	_runner = _Runner.new()
	_runner.name = "SfxVoices"
	if host and host.is_inside_tree():
		host.add_child(_runner)
		host.tree_exited.connect(func() -> void: _silence(host), CONNECT_ONE_SHOT)
	elif tree:
		tree.root.add_child.call_deferred(_runner)


## The level is leaving the tree (scene change or quit): stop its sounds and give the mixer a
## moment to release them. The AudioServer frees a stopped playback only after two mix
## steps, so quitting mid-sound would otherwise leak playbacks ("resources still in use").
static func _silence(host: Node) -> void:
	if not is_instance_valid(host):
		return
	var stopped := 0
	for p in host.find_children("*", "AudioStreamPlayer3D", true, false) \
			+ host.find_children("*", "AudioStreamPlayer", true, false):
		if p.call(&"has_stream_playback"):      # Leaving the tree paused it; stop for real.
			p.call(&"stop")
			stopped += 1
	if stopped > 0:
		OS.delay_msec(80)


static func _get_runner() -> _Runner:
	if not is_instance_valid(_runner):
		_ensure_runner(null)
	return _runner if is_instance_valid(_runner) and _runner.is_inside_tree() else null


## Holds the voice pools, the delayed-play queue and moves voices that follow a node.
class _Runner extends Node:
	var voices3: Array[AudioStreamPlayer3D] = []
	var voices2: Array[AudioStreamPlayer] = []
	var _pending: Array = []         ## [seconds_left, tag, Callable]
	var _serial := 0

	func later(delay: float, tag: String, fn: Callable) -> void:
		_pending.append([delay, tag, fn])

	## Removes pending plays with `tag`; returns how many there were.
	func drop(tag: String) -> int:
		var n := _pending.size()
		_pending = _pending.filter(func(e: Array) -> bool: return e[1] != tag)
		return n - _pending.size()

	func voice_3d(group: String, max_voices: int) -> AudioStreamPlayer3D:
		if group != "" and max_voices > 0:
			var in_group: Array[AudioStreamPlayer3D] = []
			for p in voices3:
				if p.playing and String(p.get_meta(&"group", "")) == group:
					in_group.append(p)
			if in_group.size() >= max_voices:
				in_group.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get_meta(&"serial")) < int(b.get_meta(&"serial")))
				return _reuse(in_group[0]) as AudioStreamPlayer3D
		var oldest: AudioStreamPlayer3D = null
		for p in voices3:
			if not p.playing:
				return _reuse(p) as AudioStreamPlayer3D
			if oldest == null or int(p.get_meta(&"serial")) < int(oldest.get_meta(&"serial")):
				oldest = p
		if voices3.size() < MAX_3D or oldest == null:
			var v := AudioStreamPlayer3D.new()
			add_child(v)
			voices3.append(v)
			return _reuse(v) as AudioStreamPlayer3D
		return _reuse(oldest) as AudioStreamPlayer3D

	func voice_2d() -> AudioStreamPlayer:
		var oldest: AudioStreamPlayer = null
		for p in voices2:
			if not p.playing:
				return _reuse(p) as AudioStreamPlayer
			if oldest == null or int(p.get_meta(&"serial")) < int(oldest.get_meta(&"serial")):
				oldest = p
		if voices2.size() < MAX_2D or oldest == null:
			var v := AudioStreamPlayer.new()
			add_child(v)
			voices2.append(v)
			return _reuse(v) as AudioStreamPlayer
		return _reuse(oldest) as AudioStreamPlayer

	func _reuse(p: Node) -> Node:
		Sfx._kill_tween(p)
		if p.get(&"playing"):
			p.call(&"stop")
		for m: StringName in [&"follow", &"offset", &"tag", &"group"]:
			if p.has_meta(m):
				p.remove_meta(m)
		_serial += 1
		p.set_meta(&"serial", _serial)
		return p

	func _process(delta: float) -> void:
		if not _pending.is_empty():
			var due: Array = []
			var keep: Array = []
			for e: Array in _pending:
				e[0] -= delta
				if e[0] <= 0.0:
					due.append(e)
				else:
					keep.append(e)
			_pending = keep
			for e: Array in due:
				(e[2] as Callable).call()
		for p in voices3:
			if p.playing and p.has_meta(&"follow"):
				var f: Variant = p.get_meta(&"follow")
				if is_instance_valid(f) and (f as Node3D).is_inside_tree():
					p.global_position = (f as Node3D).global_position + (p.get_meta(&"offset", Vector3.ZERO) as Vector3)
