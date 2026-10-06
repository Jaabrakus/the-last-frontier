class_name NpcPad
extends RefCounted
## A bot's virtual pad in Tidebreak's % ring (round 3, smash_r3 spec §9.1, §14.3; MOVE's file, stubbed by SEAMS): the bot's
## mind presses and holds keys here, and its body moves through the same RingMoves.pre(intent, dt) as the player's keys, so a
## bot never writes its own velocity in the ring.
##   press(key)       a key pressed this frame (jump, jump_short, dodge, fast_fall, guard, ledge): read once by intent()
##   hold(key, on)    a key held (jump, down, guard)
##   move, di         the wanted flat direction and the steer (world, flat)
##   intent()         this frame's intent: {move, jump, jump_short, jump_held, dodge, dodge_dir, fast_fall, down_held,
##                    guard_held, guard_pressed, ledge, di}; the presses are used up by reading it

## The keys intent() returns.
const KEYS := ["move", "jump", "jump_short", "jump_held", "dodge", "dodge_dir", "fast_fall", "down_held", "guard_held",
		"guard_pressed", "ledge", "di"]

## The wanted flat direction (world).
var move := Vector3.ZERO
## The steer in hitstun (world, flat).
var di := Vector3.ZERO
## The dodge's direction when one is pressed (ZERO: in place).
var dodge_dir := Vector3.ZERO

var _pressed := {}
var _held := {}


## `key` pressed this frame (read once by intent()).
func press(key: String) -> void:
	_pressed[key] = true


## `key` held (on) or let go.
func hold(key: String, on: bool) -> void:
	if on:
		_held[key] = true
	else:
		_held.erase(key)


## This frame's intent (the presses used up).
func intent() -> Dictionary:
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
		"ledge": bool(_pressed.get("ledge", false)),
		"di": di,
	}
	_pressed.clear()
	return out
