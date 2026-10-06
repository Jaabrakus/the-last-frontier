class_name NpcPad
extends RefCounted
## A bot's virtual pad in Tidebreak's % ring (round 3, smash_r3 spec §9.1, §14.3; MOVE's file): the bot's mind presses and
## holds keys here, and its body moves through the same RingMoves.pre(intent, dt) as the player's keys, so a bot never writes
## its own velocity in the ring (NpcFighter hands intent() to its RingMoves each physics frame). A press lasts one physics
## frame.
##   press(key)       a key pressed this frame, read once by intent(): jump, jump_short, dodge, fast_fall, guard, ledge
##                    (the climb), attack (a click: the edge's and the getup's attacks), cast (a cast key: off the spout),
##                    roll (the guard's roll along `move`)
##   hold(key, on)    a key held: jump, down, guard, sprint
##   ledge_option(k)  the edge option to take this frame by name: "climb", "roll", "jump", "attack", "drop"
##   move, di         the wanted flat direction (world, |move| <= 1: a share of the run) and the steer (world, flat)
##   dodge_dir, aim   the dodge's way when one is pressed (ZERO: in place); the Rise's way (the Jet's; ZERO: toward the lip)
##   intent()         this frame's intent: {move, jump, jump_short, jump_held, dodge, dodge_dir, fast_fall, down_held,
##                    guard_held, guard_pressed, ledge, di}, plus sprint, attack, cast, fresh_dir and aim when they are set;
##                    the presses are used up by reading it

## The keys intent() always returns.
const KEYS := ["move", "jump", "jump_short", "jump_held", "dodge", "dodge_dir", "fast_fall", "down_held", "guard_held",
		"guard_pressed", "ledge", "di"]

## The wanted flat direction (world).
var move := Vector3.ZERO
## The steer in hitstun (world, flat).
var di := Vector3.ZERO
## The dodge's direction when one is pressed (ZERO: in place).
var dodge_dir := Vector3.ZERO
## The Rise's way (the Jet's aim; ZERO: toward the nearest lip).
var aim := Vector3.ZERO

var _pressed := {}
var _held := {}
var _ledge := ""


## `key` pressed this frame (read once by intent()).
func press(key: String) -> void:
	_pressed[key] = true


## `key` held (on) or let go.
func hold(key: String, on: bool) -> void:
	if on:
		_held[key] = true
	else:
		_held.erase(key)


## The edge option `kind` this frame ("climb", "roll", "jump", "attack", "drop").
func ledge_option(kind: String) -> void:
	_ledge = kind


## Everything let go (a respawn, the countdown).
func clear() -> void:
	_pressed.clear()
	_held.clear()
	_ledge = ""
	move = Vector3.ZERO
	di = Vector3.ZERO
	dodge_dir = Vector3.ZERO
	aim = Vector3.ZERO


## This frame's intent (the presses used up).
func intent() -> Dictionary:
	var ledge: Variant = _ledge if _ledge != "" else bool(_pressed.get("ledge", false))
	var out := {
		"move": move,
		"jump": bool(_pressed.get("jump", false)),
		"jump_short": bool(_pressed.get("jump_short", false)),
		"jump_held": bool(_held.get("jump", false)),
		"dodge": bool(_pressed.get("dodge", false)),
		"dodge_dir": dodge_dir,
		"fast_fall": bool(_pressed.get("fast_fall", false)),
		"down_held": bool(_held.get("down", false)),
		"guard_held": bool(_held.get("guard", false)),
		"guard_pressed": bool(_pressed.get("guard", false)),
		"ledge": ledge,
		"di": di,
	}
	if _held.has("sprint"):
		out["sprint"] = true
	if _pressed.has("attack"):
		out["attack"] = true
	if _pressed.has("cast"):
		out["cast"] = true
	if _pressed.has("roll"):
		out["fresh_dir"] = Vector3(move.x, 0.0, move.z)
	if aim != Vector3.ZERO:
		out["aim"] = aim
	_pressed.clear()
	_ledge = ""
	return out
