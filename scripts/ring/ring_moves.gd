class_name RingMoves
extends Node
## The movement set of Tidebreak's % ring (round 3, smash_r3 spec §4, §5.3-5.4, §14.3; MOVE's file, stubbed by SEAMS): the
## double jump, fast fall and crouch, the guard's roll and duck, the air dodge, the teeter, the edge and the Rise, the camera's
## framing, for one body (the player, a bot). A Node child named NODE_NAME of the body, installed only in a stock-rules ring
## (RingRules.stock_on()): THE GATE per body is `RingMoves.of(body) != null`, so with none the open world, the duel and the
## classic ring move exactly as before. Every number in data/ring/movement.json.
##
##   install(body) / of(body)     put one on the body (once) / the body's, or null
##   pre(intent, dt) -> bool      the body's own frame first: true when it moved the body itself (the controller skips its
##                                own move). intent: NpcPad.intent()'s keys, or intent_from_keys() for the player
##   profile()                    the body's ring numbers (self_up_mult: the self-cast lifts scaled to the ring's gravity)
##   the state                    can_cast(), airborne(), off_deck(), helpless(), on_ledge(), on_spout(), intangible(),
##                                in_landing_lag(); jumps_left, dodge_ready, rise_ready, ledge_safe_left()
##   asked of it                  dodge(dir), land_lag(s), ride_spout(pos, max_s) (left_spout when it ends),
##                                leave_spout(), cam_bias() (the camera's framing wish)
##   simulate(state, plan, dt, horizon)   (static) the bots' look-ahead: where a plan of inputs takes a body
## Until MOVE fills it every answer is today's: nothing moved, casting allowed, on the deck, no jumps of its own.

## kind: jump, double_jump, dodge, rise, grab, climb, ledge_jump, ledge_roll, ledge_attack, break_fall, roll, duck, scramble.
signal moved(kind: String)
## The spout let the body go (a key, or its time up).
signal left_spout

const NODE_NAME := "RingMoves"

## Jumps left in this airtime (the double jump's).
var jumps_left := 0
## The air dodge is there to use in this airtime.
var dodge_ready := false
## The Rise is there to use (off the deck, the double jump spent).
var rise_ready := false
## The body this moves.
var body: CharacterBody3D


## A RingMoves on `body` (one only: the one it has, else a new one). Only a stock-rules ring calls it.
static func install(b: Node) -> RingMoves:
	var m := of(b)
	if m != null or b == null or not is_instance_valid(b):
		return m
	m = RingMoves.new()
	m.name = NODE_NAME
	m.body = b as CharacterBody3D
	b.add_child(m)
	return m


## The body's RingMoves, or null (the gate: none outside a stock-rules ring).
static func of(b: Node) -> RingMoves:
	if b == null or not is_instance_valid(b):
		return null
	return b.get_node_or_null(NODE_NAME) as RingMoves


## The body's frame before its controller's: true when this moved it (the controller then skips its own move).
func pre(_intent: Dictionary, _dt: float) -> bool:
	return false


## The player's intent this frame from his keys (NpcPad.intent()'s keys).
func intent_from_keys() -> Dictionary:
	return {}


## The body's ring numbers: self_up_mult (the self-cast lifts scaled to the ring's gravity).
func profile() -> Dictionary:
	return {"self_up_mult": 1.0}


## A cast may start now (not in a dodge, a hang, landing lag, helpless).
func can_cast() -> bool:
	return true


func airborne() -> bool:
	return false


## Over the water (feet under the lip, or outside the deck's rectangle).
func off_deck() -> bool:
	return false


## After the Rise: no more air moves until he lands or grabs the edge.
func helpless() -> bool:
	return false


func on_ledge() -> bool:
	return false


func on_spout() -> bool:
	return false


## Hits pass through him now (a dodge's window, a first grab).
func intangible() -> bool:
	return false


func in_landing_lag() -> bool:
	return false


## Seconds of the edge's first-grab safety left.
func ledge_safe_left() -> float:
	return 0.0


## A dodge along `dir` (flat; ZERO: in place).
func dodge(_dir: Vector3) -> void:
	pass


## `s` seconds of landing lag.
func land_lag(_s: float) -> void:
	pass


## On the respawn spout at `pos` for at most `max_s` (left_spout as it ends).
func ride_spout(_pos: Vector3, _max_s: float) -> void:
	pass


## Off the spout now (a key, a cast).
func leave_spout() -> void:
	pass


## The camera's framing wish ({}: as today).
func cam_bias() -> Dictionary:
	return {}


## The bots' look-ahead: where `plan` (inputs over time) takes a body from `state` in steps of `dt` up to `horizon` s ({}:
## no answer yet).
static func simulate(_state: Dictionary, _plan: Variant, _dt: float, _horizon: float) -> Dictionary:
	return {}
