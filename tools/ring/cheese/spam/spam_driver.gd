extends "res://tools/ring/highlight_input.gd"
## Cheese hunt, lens "spam": the player's hands for one spammed move (or the film's expert as the baseline), through the
## player's own inputs only (PlayerControls.set_held for the mouse buttons, E and the move keys; the number keys as
## InputEventAction events, as the hotbar reads them; the camera's yaw and pitch for the mouse). Nothing of the game is
## written: no %, no launch, no lock, no position.
##   strat "expert"  tools/ring/highlight_input.gd unchanged (the baseline: varied attacks, reactive guards, finishers)
##   any other       one move cast again the moment the hands are free (the caster IDLE), from a distance band [lo, hi]
##                   (walk in when farther, back off when nearer, never walk off the deck); recovery as the expert's
## Strategy table: STRATS (key "1" | "2" | "lmb", second: tap the key twice, hold: the right button held (0.08 a click,
## 1.65 grows a move that grows), lo/hi the band (m), reach: no cast past it (m)).

const STRATS := {
	"punch": {"key": "1", "second": false, "hold": 0.08, "lo": 5.0, "hi": 9.0, "reach": 26.0},
	"fireball": {"key": "1", "second": false, "hold": 1.65, "lo": 6.0, "hi": 10.0, "reach": 30.0},
	"lightning": {"key": "1", "second": true, "hold": 2.6, "lo": 9.0, "hi": 16.0, "reach": 40.0},
	"kick": {"key": "2", "second": false, "hold": 0.08, "lo": 4.0, "hi": 9.0, "reach": 15.0},
	"kick_grown": {"key": "2", "second": false, "hold": 1.65, "lo": 5.0, "hi": 11.0, "reach": 20.0},
	"high_kick": {"key": "2", "second": true, "hold": 0.08, "lo": 4.0, "hi": 9.0, "reach": 20.0},
	"embers": {"key": "lmb", "second": false, "hold": 0.06, "lo": 1.5, "hi": 3.0, "reach": 9.0},
	"slice": {"key": "1", "second": false, "hold": 0.08, "lo": 6.0, "hi": 11.0, "reach": 30.0},
	"ball": {"key": "1", "second": true, "hold": 0.08, "lo": 5.0, "hi": 10.0, "reach": 26.0},
	"gust": {"key": "2", "second": false, "hold": 0.08, "lo": 4.0, "hi": 8.0, "reach": 13.0},
	"gust_grown": {"key": "2", "second": false, "hold": 1.65, "lo": 5.0, "hi": 10.0, "reach": 16.0},
	"pull": {"key": "2", "second": true, "hold": 0.08, "lo": 4.0, "hi": 9.0, "reach": 13.0},
	"palm": {"key": "lmb", "second": false, "hold": 0.06, "lo": 1.2, "hi": 2.4, "reach": 3.3},
	"whip": {"key": "1", "second": false, "hold": 0.08, "lo": 5.0, "hi": 10.0, "reach": 15.0},
	"spear": {"key": "1", "second": true, "hold": 0.08, "lo": 6.0, "hi": 11.0, "reach": 30.0},
	"wave": {"key": "2", "second": false, "hold": 0.08, "lo": 3.0, "hi": 6.5, "reach": 8.5},
	"wave_grown": {"key": "2", "second": false, "hold": 1.65, "lo": 4.0, "hi": 9.0, "reach": 11.5},
	"geyser": {"key": "2", "second": true, "hold": 0.08, "lo": 4.0, "hi": 9.0, "reach": 15.0},
	"splash": {"key": "lmb", "second": false, "hold": 0.06, "lo": 1.5, "hi": 3.0, "reach": 9.0},
	"spike": {"key": "1", "second": false, "hold": 0.08, "lo": 6.0, "hi": 11.0, "reach": 20.0},
	"spike_grown": {"key": "1", "second": false, "hold": 1.65, "lo": 6.0, "hi": 11.0, "reach": 20.0},
	"boulder": {"key": "1", "second": true, "hold": 0.08, "lo": 5.0, "hi": 10.0, "reach": 17.0},
	"boulder_grown": {"key": "1", "second": true, "hold": 1.65, "lo": 5.0, "hi": 10.0, "reach": 17.0},
	"shove": {"key": "2", "second": false, "hold": 0.08, "lo": 3.0, "hi": 7.0, "reach": 18.0},
	"shove_grown": {"key": "2", "second": false, "hold": 1.65, "lo": 3.0, "hi": 8.0, "reach": 18.0},
	"column": {"key": "2", "second": true, "hold": 0.08, "lo": 4.0, "hi": 9.0, "reach": 18.0},
	"pebbles": {"key": "lmb", "second": false, "hold": 0.06, "lo": 1.5, "hi": 3.5, "reach": 9.0},
}

var strat := "expert"
var cfg := {}
var main_cfg := {}
## The finisher: once the foe's % reaches fin_pct the hands switch to this strat's move (and back after his fall).
var fin_cfg := {}
var fin_pct := INF
var fin_casts := 0
var guard_on := false
## What the spam did: presses of the cast, readying taps, frames the hands were free and nothing went (out of reach).
var spam := {"presses": 0, "readies": 0, "idle_out_of_reach": 0, "fin_presses": 0}
var _want := {}
var _want_of := {}


func configure(s: String, opts: Dictionary) -> void:
	strat = s
	if STRATS.has(s):
		cfg = (STRATS[s] as Dictionary).duplicate()
	for k in ["lo", "hi", "reach", "hold"]:
		if opts.has(k):
			cfg[k] = float(opts[k])
	main_cfg = cfg
	var f := String(opts.get("fin", ""))
	if STRATS.has(f):
		fin_cfg = (STRATS[f] as Dictionary).duplicate()
		fin_pct = float(opts.get("fin_pct", "120"))
		# (the finisher thrown from where the spam stands: its band is the spam's, unless fin_lo / fin_hi say)
		fin_cfg["lo"] = float(opts.get("fin_lo", str(cfg.get("lo", 2.0))))
		fin_cfg["hi"] = float(opts.get("fin_hi", str(cfg.get("hi", 4.0))))
	guard_on = String(opts.get("guard", "0")) == "1"


func _ready() -> void:
	super._ready()


## The move the hands are on now: the finisher's once the foe's % is at fin_pct, else the spammed one.
func _pick_cfg(foe: Node3D) -> void:
	if fin_cfg.is_empty() or main_cfg.is_empty():
		return
	var want := fin_cfg if mode.rules.pct_of(foe) >= fin_pct else main_cfg
	if want != cfg:
		cfg = want
		_want = {}


func _wanted() -> Dictionary:
	if not _want.is_empty():
		return _want
	var el := String(player.arena_element)
	var ks := Bending.keys(el)
	var k := int(String(cfg.get("key", "1"))) - 1
	if k < 0 or k >= ks.size():
		return {}
	var first := Bending.first_of(ks[k] as Array)
	_want = first
	if bool(cfg.get("second", false)):
		_want = Bending.other_move(ks[k] as Array, String(first.id), String(first.mode))
	return _want


func _feet(foe: Node3D) -> void:
	if strat == "expert" or cfg.is_empty():
		super._feet(foe)
		return
	_pick_cfg(foe)
	var d := _flat_d(foe)
	var foe_moves := RingMoves.of(foe)
	var away := foe_moves != null and foe_moves.off_deck()
	var g := RingMoves.arena_geo(mode.ring)
	var xf: Transform3D = g.xf
	var local: Vector3 = xf.affine_inverse() * player.global_position
	var to_foe: Vector3 = xf.affine_inverse() * foe.global_position - local
	to_foe.y = 0.0
	var dir := to_foe.normalized() if to_foe.length() > 0.01 else Vector3.ZERO
	# (stepping toward or away from him, would it take us within a margin of a lip?)
	var ahead := local + dir * 1.2
	var behind := local - dir * 1.2
	var hl := float(g.hl) - 1.4
	var hw := float(g.hw) - 1.2
	var fwd_ok := absf(ahead.x) < hl and absf(ahead.z) < hw
	var back_ok := absf(behind.x) < hl and absf(behind.z) < hw
	var lo := float(cfg.get("lo", 4.0))
	var hi := float(cfg.get("hi", 9.0))
	_hold(&"move_forward", not away and fwd_ok and d > hi)
	_hold(&"move_back", d < lo and back_ok)
	_hold(&"move_left", false)
	_hold(&"move_right", false)


func _hands(foe: Node3D) -> void:
	if strat == "expert" or cfg.is_empty():
		super._hands(foe)
		return
	if _second_at <= 0.0:
		_pick_cfg(foe)
	var key := String(cfg.get("key", "1"))
	if cfg == fin_cfg and _second_at <= 0.0 and SwayCaster.of(player) != null \
			and SwayCaster.of(player).state == SwayCaster.State.IDLE and not player.controls.pressed(&"aim") \
			and not player.controls.pressed(&"fire"):
		spam.fin_presses = int(spam.fin_presses) + 1
	var caster := SwayCaster.of(player)
	if caster == null:
		return
	if _second_at > 0.0:
		if _t >= _second_at:
			_second_at = -1.0
			_key(StringName("weapon_" + key))
			_tap(&"aim", float(cfg.get("hold", 0.08)))
			spam.presses = int(spam.presses) + 1
		return
	if caster.state != SwayCaster.State.IDLE or player.controls.pressed(&"aim") or player.controls.pressed(&"fire"):
		return
	if _flat_d(foe) > float(cfg.get("reach", 20.0)):
		spam.idle_out_of_reach = int(spam.idle_out_of_reach) + 1
		return
	if key == "lmb":
		_tap(&"fire", float(cfg.get("hold", 0.06)))
		clicks += 1
		spam.presses = int(spam.presses) + 1
		return
	var w := _wanted()
	if w.is_empty():
		return
	var ready_now := caster.readied_spell == String(w.id) and caster.base_mode_of(String(w.id)) == String(w.mode)
	if ready_now:
		_tap(&"aim", float(cfg.get("hold", 0.08)))
		spam.presses = int(spam.presses) + 1
	elif bool(cfg.get("second", false)):
		_key(StringName("weapon_" + key))
		_second_at = _t + 0.10
		spam.readies = int(spam.readies) + 1
		return
	else:
		_key(StringName("weapon_" + key))
		_tap(&"aim", float(cfg.get("hold", 0.08)))
		spam.readies = int(spam.readies) + 1
		spam.presses = int(spam.presses) + 1
	casts += 1


func _guard(foe: Node3D) -> void:
	if strat == "expert" or cfg.is_empty():
		super._guard(foe)
		return
	if guard_on and not player.controls.pressed(&"aim") and _second_at <= 0.0:
		super._guard(foe)
