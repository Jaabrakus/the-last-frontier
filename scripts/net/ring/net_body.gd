class_name NetBody
extends RefCounted
## A body's state on the wire, and a remote body played back from it (docs/tidebreak/ring_netcode.md, "Bodies").
##   capture(b, t)  its owner's state of body `b` at host time `t`: an Array, its slots the S_* below (one Variant array, the
##                  smallest the RPC layer sends: a dictionary would carry every key's name each time)
##   push(s)        a state come in for this remote body (kept in order of its time; one older than the newest shown is
##                  dropped, a repeat too)
##   apply(b, at)   the puppet `b` put where its owner's body was at host time `at` (the caller's now less INTERP_S): its
##                  place and velocity between the two states around `at` (extrapolated along the newest's velocity at most
##                  EXTRAP_S when none is newer), its facing and aim turned the short way, its keys held (its legs' pace),
##                  its RingMoves' puppet state (RingMoves.puppet_state: the clip, the mode, the flags) from the older of
##                  the two (a state is never shown before its time); `aim` the point its owner's crosshair was on (his
##                  NetBendCaster's streamed_aim: what a cast of his asks after its run); his % (the newest state's: the
##                  % ring's HUD here shows his machine's number, RingRules.mirror_pct)
## A puppet does nothing of its own: its RingMoves in puppet mode moves nothing, its keys only feed its legs' animation.

## How far behind the owner a remote body is shown (s): two states at 30 a second always around it, one lost still covered.
const INTERP_S := 0.1
## The longest a puppet is carried along its last velocity with no newer state (s); then it waits there.
const EXTRAP_S := 0.15
## The states kept (s of the newest).
const KEEP_S := 1.0
## The keys a puppet holds from its owner's (their bits, in this order): his legs' pace, and E (his guard held up:
## SwayCaster.guard_held).
const KEYS := [&"move_left", &"move_right", &"move_forward", &"move_back", &"sprint", &"bend_guard"]

## The state's slots.
const S_T := 0
const S_P := 1
const S_V := 2
const S_RY := 3
const S_YAW := 4
const S_PITCH := 5
const S_KEYS := 6
const S_RM := 7
const S_AIM := 8
const S_PCT := 9

var states: Array = []
var shown_t := -INF
## The point the owner's crosshair was on at the state shown (INF none).
var aim := Vector3.INF


## Body `b`'s state now, at host time `t`.
static func capture(b: Node3D, t: float) -> Array:
	var v := (b as CharacterBody3D).velocity if b is CharacterBody3D else Vector3.ZERO
	var yaw := float(b.get(&"yaw")) if &"yaw" in b else b.rotation.y
	var pitch := float(b.get(&"pitch")) if &"pitch" in b else 0.0
	var keys := 0
	var c: Variant = b.get(&"controls") if &"controls" in b else null
	if c is PlayerControls:
		for i in KEYS.size():
			if (c as PlayerControls).pressed(KEYS[i]):
				keys |= 1 << i
	var rm := RingMoves.of(b)
	var bc := BendCaster.of(b)
	var aim_at := bc.aim_point() if bc != null and bc.valid() else Vector3.INF
	var rr := RingRules.current() if RingRules.stock_on() else null
	var pct := rr.pct_of(b) if rr != null and rr.team_of(b) >= 0 else -1.0
	return [t, b.global_position, v, b.rotation.y, yaw, pitch, keys, rm.puppet_state() if rm != null else [], aim_at, pct]


## A state come in (its time first).
func push(s: Array) -> void:
	if s.size() <= S_RM:
		return
	var t := float(s[S_T])
	if t <= shown_t - KEEP_S:
		return
	var i := states.size()
	while i > 0 and float((states[i - 1] as Array)[S_T]) > t:
		i -= 1
	if i > 0 and is_equal_approx(float((states[i - 1] as Array)[S_T]), t):
		return
	states.insert(i, s)
	var newest := float((states.back() as Array)[S_T])
	while states.size() > 2 and float((states[0] as Array)[S_T]) < newest - KEEP_S:
		states.pop_front()


## The newest state (empty: none yet).
func newest() -> Array:
	return states.back() if not states.is_empty() else []


## Puppet `b` as its owner's body was at host time `at`. False: no state yet.
func apply(b: Node3D, at: float) -> bool:
	if states.is_empty():
		return false
	var s0: Array = states[0]
	var s1: Array = []
	for s: Array in states:
		if float(s[S_T]) <= at:
			s0 = s
		else:
			s1 = s
			break
	var p: Vector3 = s0[S_P]
	var v: Vector3 = s0[S_V]
	var ry := float(s0[S_RY])
	var yaw := float(s0[S_YAW])
	var pitch := float(s0[S_PITCH])
	var t0 := float(s0[S_T])
	if not s1.is_empty() and float(s1[S_T]) > t0 and at >= t0:
		var f := clampf((at - t0) / (float(s1[S_T]) - t0), 0.0, 1.0)
		p = p.lerp(s1[S_P], f)
		v = v.lerp(s1[S_V], f)
		ry = lerp_angle(ry, float(s1[S_RY]), f)
		yaw = lerp_angle(yaw, float(s1[S_YAW]), f)
		pitch = lerpf(pitch, float(s1[S_PITCH]), f)
	elif s1.is_empty():
		p += v * clampf(at - t0, 0.0, EXTRAP_S)
	shown_t = maxf(shown_t, minf(at, t0))
	b.global_position = p
	if b is CharacterBody3D:
		(b as CharacterBody3D).velocity = v
	if &"yaw" in b:
		b.set(&"yaw", yaw)
	if &"pitch" in b:
		b.set(&"pitch", pitch)
	var c: Variant = b.get(&"controls") if &"controls" in b else null
	if c is PlayerControls:
		var keys := int(s0[S_KEYS])
		for i in KEYS.size():
			(c as PlayerControls).set_held(KEYS[i], (keys & (1 << i)) != 0)
	var rm := RingMoves.of(b)
	if rm != null:
		rm.set_puppet_state(s0[S_RM] as Array, ry)
	aim = s0[S_AIM] if s0.size() > S_AIM and s0[S_AIM] is Vector3 else Vector3.INF
	var newest_s: Array = states.back()
	if newest_s.size() > S_PCT and float(newest_s[S_PCT]) >= 0.0 and RingRules.stock_on():
		RingRules.current().mirror_pct(b, float(newest_s[S_PCT]))    # (his %: his machine's, shown here)
	return true


## Whether `at` lies past the newest state by more than the extrapolation covers (its owner has gone quiet).
func stale(at: float) -> bool:
	return states.is_empty() or at - float((states.back() as Array)[S_T]) > EXTRAP_S + 0.5
