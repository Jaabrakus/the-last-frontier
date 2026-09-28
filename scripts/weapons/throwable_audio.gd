class_name ThrowableAudio
extends Node
## Placeholder sounds for the thrown weapons, made from sounds the project already has,
## until the dedicated ones exist (design doc, checklist 4.5: spear_release, tomahawk_whirr,
## atlatl_flick, thrown_pickup, ...). Like WeaponAudio it only listens: each Throwable's
## `sfx`, `action_started` and `action_cancelled`; it never changes weapon or player state.
## Flight whooshes and impacts are played by ThrownProjectile itself.
##
## A throw is not a gunshot: no shot, no echo tail, and the birds are not startled.
## WeaponAudio treats every non-bow weapon in player.weapons as a gun (_on_fired) and
## starts the bow creak on an sfx "draw", so when the throwables join the roster it must
## skip them (`if w is Throwable: continue` in its _ready loop) and leave them to this node.
##
## Added to the player by ThrowableKit.install; `watch(w)` connects one weapon.

## Every cue played: [id, gain_db, pitch, delay] per weapon key and event.
const CUES := {
	"windup": [["cloth_move", -6.0, 1.0, 0.0]],
	"cancel": [["cloth_move", -10.0, 0.9, 0.0]],
	"release": [["cloth_move", -2.0, 1.2, 0.0]],
	"release_atlatl": [["cloth_move", -2.0, 1.2, 0.0], ["arrow_rest", 2.0, 0.7, 0.0]],   # Dart leaving the hook.
	"empty": [["quiver_empty", -4.0, 0.85, 0.0]],
	"pickup": [["gear_jostle", -2.0, 0.9, 0.0]],
	"equip": [["gear_jostle", -4.0, 1.0, 0.0]],
	"draw_spear": [["quiver_draw", -2.0, 0.8, 0.0]],                                      # Over the shoulder.
	"draw_tomahawk": [["gear_jostle", -2.0, 1.1, 0.0]],                                   # From the belt.
	"draw_atlatl": [["quiver_draw", -3.0, 0.9, 0.0], ["nock_click", 0.0, 0.7, 0.7]],      # Fit the dart to the hook.
}
const EMPTY_COOLDOWN := 0.5

## Each event as its cues are played (tests, debug): the CUES key and the weapon key.
signal cue(event: StringName, key: String)

var player: FrontierPlayer

var _key_of := {}
var _empty_cd := 0.0


func _physics_process(delta: float) -> void:
	_empty_cd -= delta


## Connects the sounds of `w` (key "spear", "tomahawk", "atlatl", ...).
func watch(w: Throwable, key: String) -> void:
	if _key_of.has(w):
		return
	_key_of[w] = key
	w.sfx.connect(_on_sfx.bind(w))
	w.action_started.connect(_on_action.bind(w))
	w.action_cancelled.connect(_on_cancelled.bind(w))


func _kind(w: Throwable) -> String:
	if w is ThrowableAtlatl:
		return "atlatl"
	if w is ThrowableTomahawk:
		return "tomahawk"
	return "spear"


func _on_sfx(id: StringName, at: Vector3, w: Throwable) -> void:
	match String(id):
		"windup", "cancel", "pickup":
			_play(w, String(id), at)
		"release":
			_play(w, "release_atlatl" if w is ThrowableAtlatl else "release", at)
		"empty":
			if _empty_cd <= 0.0:
				_empty_cd = EMPTY_COOLDOWN
				_play(w, "empty", at)
		"draw":
			_play(w, "draw_" + _kind(w), at, w.draw_time)


func _on_action(action: String, _duration: float, w: Throwable) -> void:
	if action == "equip":
		if player and player.weapons.values().has(w) and player.get_node_or_null("WeaponAudio") != null:
			# In the roster the switch sounds are WeaponAudio's (<key>_holster, then <key>_equip), as
			# for the other weapons (throwables_design.md 4.5): no second equip sound here.
			cue.emit(&"equip_switch", String(_key_of.get(w, "")))
			return
		_play(w, "equip", w.model.global_position if w.model and w.model.is_inside_tree() else Vector3.INF)


## Put away mid-draw: drop the pending hook click.
func _on_cancelled(w: Throwable) -> void:
	Sfx.cancel(_tag(w), 0.05)


func _tag(w: Throwable) -> String:
	return "throw_" + String(_key_of.get(w, "?"))


## Plays the cue list `event`; delays are fractions of `span` seconds when given.
func _play(w: Throwable, event: String, at: Vector3, span := 1.0) -> void:
	var key: String = _key_of.get(w, "")
	var follow: Node3D = w.model if w.model and w.model.is_inside_tree() else null
	if at == Vector3.INF:
		at = follow.global_position if follow else (player.global_position + Vector3.UP if player else Vector3.ZERO)
	for c: Array in CUES.get(event, []):
		var opts := {"tag": _tag(w)}
		if follow and event != "pickup":
			opts["follow"] = follow
		var delay := float(c[3]) * span
		if delay > 0.0:
			opts["delay"] = delay
		Sfx.play_3d(StringName(c[0]), at, float(c[1]), float(c[2]), opts)
	cue.emit(StringName(event), key)
