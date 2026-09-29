class_name WeaponAudio
extends Node
## Sounds of the player's weapons. Listens to each weapon's signals (fired, action_started,
## action_cancelled and the `sfx` hook in firearm.gd / bow.gd), so the weapon scripts only
## announce what happens:
##
##   firing   lock (flint on frizzen) at the pan, pan flash 27 ms later, then on `fired` the
##            shot at the muzzle plus a baked echo tail (palisade version inside the fort),
##            and the birds are startled. Bow: release twang scaled by draw, no startle.
##   reload   each stage (action_started "reload_*") plays its cue list; times scale with
##            the stage length. An interrupted stage drops its cues and fades its Foley; a
##            resumed stage starts its list again.
##   bow      draw, a creak loop while drawn (strains with fatigue), let-down, nock / grab
##            timelines, empty-quiver pat.
##   switch   <previous>_holster, then <new>_equip 80 ms later (a faster second switch drops
##            the unheard equip and its holster).
##
##   thrown   (Throwable: spear, tomahawk, atlatl) no shot, no echo tail, no bird scare: on `fired`
##            (the object leaving the hand) only a low swing whoosh at the hand; every other throw
##            cue is ThrowableAudio's (its `sfx` hook is not voiced here). The switch sounds
##            <key>_equip / <key>_holster play like the other weapons', from placeholder ids
##            (THROWN_SWITCH) until the manifest has their own (THROW).
##
## Added to the player by frontier_level.gd; it never changes weapon or player state.

const PAN_DELAY := 0.027          ## Lock -> pan flash (flintlock manifest delay_after_lock_s).
const DRY_COOLDOWN := 0.35
const QUIVER_COOLDOWN := 0.6
const FORT_HALF := 16.0           ## Inside the stockade the shot gets the palisade tail.
const EQUIP_DELAY := 0.08         ## <previous>_holster -> <new>_equip.

## Reload cue lists per weapon key and stage: [nominal stage seconds, [[id, t, gain_db, pitch], ...]].
const RELOAD := {
	"musket": [
		[1.3, [["cock_half", 0.05], ["frizzen_open", 0.32], ["cartridge_draw", 0.50], ["cartridge_bite", 0.95]]],
		[1.6, [["powder_pour_pan", 0.15], ["frizzen_close", 0.85], ["musket_handle", 1.20]]],
		# (the rod's first tugs start in the pouring step: MusketReload's animation draws it from 1.1 s into it)
		[1.8, [["powder_pour_barrel", 0.20], ["ball_seat", 1.25], ["ramrod_draw", 1.41]]],
		[2.2, [["ramrod_draw", 0.08], ["ram_stroke", 0.80], ["ram_stroke", 1.25], ["ram_stroke", 1.70, 2.0, 0.97]]],
		[1.3, [["ramrod_return", 0.05], ["musket_handle", 0.78], ["cock_full", 1.05]]],
	],
	"pistol": [
		[0.8, [["cock_half", 0.05, 0.0, 1.15], ["frizzen_open", 0.40, 0.0, 1.15]]],
		[1.2, [["cartridge_bite", 0.0, 0.0, 1.05], ["powder_pour_barrel_pistol", 0.22], ["ball_seat", 0.60, 0.0, 1.1],
				["ram_stroke_pistol", 0.78], ["ram_stroke_pistol", 0.98, 1.0]]],
		[0.9, [["powder_pour_pan", 0.03], ["frizzen_close", 0.52, 0.0, 1.15], ["cock_full", 0.72, 0.0, 1.15]]],
	],
}
## Bow timelines (same format). Nocking from the bow hand skips the reach to the quiver.
const NOCK := [0.75, [["quiver_draw", 0.02], ["arrow_rest", 0.35], ["nock_click", 0.55]]]
const HAND_NOCK := [0.35, [["arrow_rest", 0.03], ["nock_click", 0.22]]]
const GRAB := [1.1, [["quiver_draw", 0.05], ["quiver_draw", 0.42, -3.0, 1.04], ["arrow_rest", 0.92, -2.0]]]

## Where a sound comes from (default: the weapon model).
const ANCHOR := {
	"cartridge_draw": "hip", "cartridge_bite": "head", "powder_pour_pan": "pan",
	"ram_stroke": "muzzle", "ram_stroke_pistol": "muzzle",
	"musket_equip": "chest", "musket_holster": "chest", "pistol_equip": "hip", "pistol_holster": "hip",
	"bow_holster": "chest", "quiver_draw": "back", "quiver_empty": "back",
}
const ANCHOR_HEIGHT := {"hip": 0.9, "chest": 1.2, "back": 1.4, "head": 1.5}
## Thrown weapons' switch sounds until the manifest has them: id -> [placeholder id, pitch, gain_db]
## (the spear and the dart bundle come off the back, the tomahawk off the belt).
const THROWN_SWITCH := {
	"spear_equip": ["quiver_draw", 0.8, -2.0], "spear_holster": ["quiver_draw", 0.72, -4.0],
	"tomahawk_equip": ["gear_jostle", 1.1, -2.0], "tomahawk_holster": ["gear_jostle", 0.95, -4.0],
	"atlatl_equip": ["gear_jostle", 1.0, -2.0], "atlatl_holster": ["gear_jostle", 0.9, -4.0],
}
## The thrown weapons' swing whoosh on release: [id, pitch, gain_db].
const THROWN_RELEASE := ["arrow_whoosh", 0.55, -10.0]
## A new ram stroke cuts the previous one.
const VOICE_LIMIT := {"ram_stroke": ["ram", 1], "ram_stroke_pistol": ["ram", 1]}

var player: FrontierPlayer

var _key_of := {}                 ## Weapon -> "bow" / "musket" / "pistol"
var _current := ""                ## Weapon key the last equip sound was played for.
var _dry_cd := 0.0
var _quiver_cd := 0.0
var _draw_voice: AudioStreamPlayer3D   ## Pooled: only ours while its serial matches.
var _draw_serial := -1
var _creak: AudioStreamPlayer3D
var _creak_on := false
var _creak_env := 0.0             ## 0..1 fade envelope.
var _creak_db := -30.0            ## Smoothed level.
var _creak_next := 0


func _ready() -> void:
	if player == null:
		player = get_parent() as FrontierPlayer
	if player == null:
		return
	if player.camera:
		player.camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
	_current = player.weapon_key       # The first equip happens before this node exists.
	for key: String in player.weapons:
		var w: Weapon = player.weapons[key]
		_key_of[w] = key
		w.fired.connect(_on_fired.bind(w))
		w.action_started.connect(_on_action.bind(w))
		w.action_cancelled.connect(_on_cancelled.bind(w))
		if w.has_signal(&"sfx"):
			w.connect(&"sfx", _on_sfx.bind(w))


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_dry_cd -= delta
	_quiver_cd -= delta
	var bow := player.weapon as Bow
	if bow and bow.active and bow.quiver <= 0 and _quiver_cd <= 0.0 and _fire_enabled() \
			and Input.is_action_just_pressed("fire"):
		_quiver_cd = QUIVER_COOLDOWN
		_cue(bow, "quiver_empty", 0.0, 0.0, 1.0, "bow")


func _process(delta: float) -> void:
	_update_creak(delta)


# --- Signal handlers -----------------------------------------------------------------------

func _on_fired(w: Weapon) -> void:
	var key: String = _key_of.get(w, "")
	if w is Throwable:
		# A throw is not a gunshot: no shot, no echo tail, the birds stay (ThrowableAudio has the rest).
		var at := w.model.global_position if w.model and w.model.is_inside_tree() else player.global_position + Vector3.UP * 1.5
		Sfx.play_3d(StringName(THROWN_RELEASE[0]), at, float(THROWN_RELEASE[2]), float(THROWN_RELEASE[1]), {"tag": key})
		return
	if w is Bow:
		var bow := w as Bow
		_fade_draw(0.03)
		_stop_creak()
		var pos := bow.model.global_position if bow.model else player.global_position
		Sfx.play_3d(&"bow_release", pos, linear_to_db(lerpf(0.45, 1.0, bow.charge)),
				0.93 + 0.10 * bow.charge, {"follow": bow.model})
		return
	if w.muzzle:
		Sfx.play_3d(StringName(key + "_shot"), w.muzzle.global_position)
	var p := player.global_position
	var inside := absf(p.x) < FORT_HALF and absf(p.z) < FORT_HALF
	Sfx.play_2d(StringName(key + ("_tail_fort" if inside else "_tail")))
	get_tree().call_group(&"ambience", &"scare")


func _on_sfx(id: StringName, at: Vector3, w: Weapon) -> void:
	if w is Throwable:
		return    # ThrowableAudio voices the throw cycle (its "draw" is not the bow's draw and creak)
	var key: String = _key_of.get(w, "")
	var pistol := key == "pistol"
	match String(id):
		"lock":
			Sfx.play_3d(StringName(key + "_lock"), at)
			Sfx.play_3d(&"pan_flash", at, -2.0 if pistol else 0.0, 1.08 if pistol else 1.0, {"delay": PAN_DELAY})
		"dry":
			if _dry_cd <= 0.0:
				_dry_cd = DRY_COOLDOWN
				Sfx.play_3d(&"dry_fire", at, 0.0, 1.15 if pistol else 0.95)
		"draw":
			_fade_draw(0.02)
			_draw_voice = Sfx.play_3d(&"bow_draw", at, 0.0, 1.0, {"follow": w.model, "tag": key})
			_draw_serial = int(_draw_voice.get_meta(&"serial", -1)) if _draw_voice else -1
			_start_creak(w)
		"let_down":
			_fade_draw(0.03)
			_stop_creak()
			Sfx.play_3d(&"bow_let_down", at, 0.0, 1.0, {"follow": w.model, "tag": key})


func _on_action(action: String, duration: float, w: Weapon) -> void:
	var key: String = _key_of.get(w, "")
	if action == "equip":
		_on_equip(w, key)
	elif action.begins_with("reload") and w is Firearm:
		var stages: Array = RELOAD.get(key, [])
		var stage: int = (w as Firearm)._stage
		if stage >= 0 and stage < stages.size():
			_timeline(w, key, stages[stage], duration)
	elif action == "nock":
		var bow := w as Bow
		_timeline(w, key, HAND_NOCK if bow and duration < bow.nock_time * 0.8 else NOCK, duration)
	elif action == "grab":
		_timeline(w, key, GRAB, duration)


## Reload interrupted (sprint, jump) or weapon put away: drop pending cues, fade its Foley.
func _on_cancelled(w: Weapon) -> void:
	Sfx.cancel(_key_of.get(w, ""), 0.06)
	if w is Bow:
		_fade_draw(0.04)
		_stop_creak()


func _on_equip(w: Weapon, key: String) -> void:
	if key == _current:
		return
	# Switching again within EQUIP_DELAY (mouse wheel): the last weapon's equip has not been
	# heard yet, so drop it and skip its holster instead of playing them in reverse order.
	var unheard := Sfx.drop_pending("equip_next")
	var prev: Weapon = player.weapons.get(_current)
	if prev and not unheard:
		_cue(prev, _current + "_holster", 0.0, 0.0, 1.0, "equip")
	_cue(w, key + "_equip", EQUIP_DELAY, 0.0, 1.0, "equip_next")
	_current = key


# --- Cues --------------------------------------------------------------------------------------

func _timeline(w: Weapon, key: String, entry: Array, duration: float) -> void:
	var scale := duration / float(entry[0]) if float(entry[0]) > 0.0 and duration > 0.0 else 1.0
	for c: Array in entry[1]:
		_cue(w, c[0], float(c[1]) * scale, float(c[2]) if c.size() > 2 else 0.0,
				float(c[3]) if c.size() > 3 else 1.0, key)


func _cue(w: Weapon, id: String, delay: float, gain_db: float, pitch: float, tag: String) -> void:
	if THROWN_SWITCH.has(id) and Sfx.config(StringName(id)).is_empty():
		var sub: Array = THROWN_SWITCH[id]
		id = String(sub[0])
		pitch *= float(sub[1])
		gain_db += float(sub[2])
	var a := _anchor(w, id)
	var opts := {"tag": tag, "follow": a[0], "offset": a[1]}
	if delay > 0.0:
		opts["delay"] = delay
	if VOICE_LIMIT.has(id):
		opts["group"] = VOICE_LIMIT[id][0]
		opts["max"] = VOICE_LIMIT[id][1]
	Sfx.play_3d(StringName(id), (a[0] as Node3D).global_position + (a[1] as Vector3), gain_db, pitch, opts)


## [node to follow, world offset] for a sound.
func _anchor(w: Weapon, id: String) -> Array:
	var where: String = ANCHOR.get(id, "model")
	if ANCHOR_HEIGHT.has(where):
		return [player, Vector3.UP * float(ANCHOR_HEIGHT[where])]
	if where == "muzzle" and w.muzzle:
		return [w.muzzle, Vector3.ZERO]
	if where == "pan" and w.model and w is Firearm:
		return [w.model, pan_point(w as Firearm) - w.model.global_position]
	if w.model:
		return [w.model, Vector3.ZERO]
	return [player, Vector3.UP]


## The flintlock's pan, as Firearm._pull_trigger finds it.
static func pan_point(f: Firearm) -> Vector3:
	var pan := f.model.get_node_or_null("Pan") as Node3D if f.model else null
	if pan:
		return pan.global_position
	return f.muzzle.global_position + f.muzzle.global_basis.z * f.pan_distance + Vector3.UP * 0.03


func _fire_enabled() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.ignore_mouse_capture


# --- Bow draw and creak loop -------------------------------------------------------------------

func _fade_draw(fade: float) -> void:
	if is_instance_valid(_draw_voice) and _draw_voice.playing \
			and int(_draw_voice.get_meta(&"serial", -2)) == _draw_serial:
		Sfx.stop(_draw_voice, fade)
	_draw_voice = null
	_draw_serial = -1


## Starts the tension creak. bow_draw already carries some creak, so the loop stays low while
## drawing and comes up at full draw.
func _start_creak(w: Weapon) -> void:
	if _creak == null or not is_instance_valid(_creak):
		_creak = Sfx.make_player_3d(&"bow_creak_loop", w.model if w.model else player)
		if _creak == null:
			return
	var loops := Sfx.variants(&"bow_creak_loop")
	if loops.is_empty():
		return
	_creak.stream = loops[_creak_next % loops.size()]       # Alternate the takes.
	_creak_next += 1
	_creak_on = true
	_creak_env = 0.0
	_creak_db = -30.0
	_creak.volume_db = -60.0
	_creak.play(randf() * maxf(_creak.stream.get_length() - 0.1, 0.0))


func _stop_creak() -> void:
	_creak_on = false


func _update_creak(delta: float) -> void:
	if _creak == null or not is_instance_valid(_creak) or not _creak.playing:
		return
	var bow := player.weapons.get("bow") as Bow if player else null
	if _creak_on and (bow == null or not bow.active or not bow.is_drawn()):
		_creak_on = false             # Unequip resets the draw without a signal.
	if _creak_on:
		var target := -18.0
		var pitch := 1.04
		if bow.state == Bow.State.DRAWING:
			target = lerpf(-30.0, -20.0, bow.charge)
			pitch = 0.92 + 0.12 * bow.charge
		else:
			# Holding: strains louder with fatigue, jitters with the tremble.
			var f := bow.fatigue()
			var tremble := bow.tremble_offset() / deg_to_rad(0.9)
			target = -18.0 + 6.0 * f + 3.0 * tremble.length()
			pitch = 1.04 + 0.03 * f * clampf(tremble.x, -1.0, 1.0)
		_creak_db = move_toward(_creak_db, target, 60.0 * delta)
		_creak.pitch_scale = pitch
		_creak_env = move_toward(_creak_env, 1.0, delta / 0.025)
	else:
		_creak_env = move_toward(_creak_env, 0.0, delta / 0.04)
		if _creak_env <= 0.0:
			_creak.stop()
			return
	_creak.volume_db = _creak_db + linear_to_db(maxf(_creak_env, 0.001))
