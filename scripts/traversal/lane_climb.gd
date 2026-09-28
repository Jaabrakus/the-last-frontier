class_name TravLaneClimb
extends RefCounted
## CLIMB mode: ladders (design 7.8), played with the graph's ladder states under the overlay
## context `ledge=ladder`. Trunk and pole climbing were removed (user decision 2026-09-24: no
## free climbing without a source clip; the ladder clips on a round trunk did not convince).
##
## The source graph's ladder sequence (contact pass 2026-09-25; before, the fast cycles were chained
## straight from and back into the hub, whose pose is half a rung out of phase with them, so every
## hub transition put the hands and feet 11-18 cm off their rungs):
##   hub      ledge-grab = p-ladder-idle (loop)
##   up       climb-up-rh = p-ladder-climb-up (the first move, from the hub pose) -> climb-up-rh^lh =
##            p-ladder-climb-up-fast--a -> climb-up-lh^rh = fast--b -> fast--a ...; on a held request
##            the graph passes each cycle through the first moment of its ^idle state (0.1 s fade)
##   stop     the cycle's ^idle state played whole, then ledge-grab (0.4 s): climb-up-lh^idle =
##            p-ladder-climb-up^idle-flip after fast--a, climb-up-rh^idle = ^idle after fast--b or
##            climb-up; the low hand and foot come up to the high ones and the pose settles
##   down     climb-down-lh = p-ladder-climb-down -> climb-down-lh^rh = fast--a -> climb-down-rh^lh =
##            fast--b ...; stop: climb-down-rh^idle = ^idle-flip after fast--a, climb-down-lh^idle =
##            ^idle after fast--b or climb-down
##   mount    ladder-auto-climb (p-ladder-mount-bottom-start / -end) from the ground
##   top      ladder^climb-up-jump-double-ap (p-ladder-dismount--top-start / -end^walk)
##   bottom   ladder^climb-down-jump (p-ladder-dismount--bottom)
## Each move of the chain (climb-up, a, b) carries the pose two rungs (PITCH) further; a hub is
## always an even number of rungs from the last. The ladder the clips were made for has its rungs
## PITCH apart with a radius of about RUNG_R (the closed fist's hole); its top platform stands
## top_height(steps) above the ground (see the course and the level hooks).
## The root follows the ladder line at a stand-off; its height is carried by each clip's held hand
## (the table's align is anchored on that fist, traversal_moves.json align_anchor_parts) and is put
## on the rungs at every clip start: the held fist's hole on its rung's axis, the difference eased
## out with the velocity over U_EASE_S. Hands close on the rungs (TraversalIK grip: the fist's
## hole on the rung's axis) and soles stand on their tops during the clips' contact windows.

const STANDOFF_LADDER := 0.16      ## root off the rung plane (the ladder clips' fists are 0.16-0.17 m in front of the root)
const STANDOFF_TRUNK := 0.2        ## root off the bark
const PITCH := 0.295               ## the source ladder's rung spacing: hub hands to feet 4 rungs (1.185 m), a pair of fast cycles 4 rungs (1.165-1.18 m)
const RUNG_R := 0.010              ## rung radius the closed fists fit (their holes: 1.1-1.7 cm, squeezed to 0.6 cm on the fast cycles; data/traversal/ladder_grips.json)
const HUB_FOOT_REST := 0.003       ## the hub pose's soles rest on a rung top this far above the root (rendered mesh, rung plane)
const U_MIN := 0.3                 ## lowest root height above the lane's ground before the bottom dismount (the mount's hub)
const DISMOUNT_TOP_DROP := 1.5     ## fallback: the top dismount's hands land this far above its start root
const RUNG_SNAP_M := 0.08          ## a limb's reference within this of a rung is planted on it
const RUNG_FADE_M := 0.03          ## ... fading in over the last RUNG_FADE_M (a pin appearing at full weight popped the leg)
## A sole more than LAND_ABOVE_M above its rung top when its window starts is still coming down
## onto the rung (the foot that lands as a clip ends, in its join hold): it lands when its clip puts
## it within LAND_AT_M of the top, and its plant comes in over LAND_RAMP_S from LAND_LEAD_S before
## that, done by the window's end (see _rung_pins).
const LAND_ABOVE_M := 0.03
const LAND_AT_M := 0.015
const LAND_LEAD_S := 0.03
const LAND_RAMP_S := 0.1
const HUB_DWELL_S := 0.2           ## the hub plays at least its fade before a dismount
## The stick held on toward the ladder's end (user 2026-09-26: "allow me to hold up or down to go up and down the
## ladder fluently"): the stop at the end plays HURRY_RATE faster and the hub goes on after HUB_HELD_S.
const HURRY_RATE := 1.8
const HUB_HELD_S := 0.08
const CAP_EASE_S := 0.3
## A clip start: the root height keeps its velocity and position across the switch and eases onto the
## new clip's rung-anchored path over U_EASE_S (an inertialized offset that is zero at the end).
const U_EASE_S := 0.2
const HOLD_ROOM_M := 0.15          ## a step may end this far past the top / bottom hub
const JOIN_HOLD_S := 0.12          ## limbs on a rung at a clip's start / end are held this long (see _rung_pins)
const HUB_MIN_S := 0.25            ## the hub's pose settles (its fade) before the next climb starts from it

## The chain (graph states in the header): the next move while the request is held, the stop after
## each move, the fade into each, the held hand that carries each clip's height.
const NEXT := {"up": {"": "ladder_climb_up", "ladder_climb_up": "ladder_up_a", "ladder_up_a": "ladder_up_b", "ladder_up_b": "ladder_up_a"},
		"down": {"": "ladder_climb_down", "ladder_climb_down": "ladder_down_a", "ladder_down_a": "ladder_down_b", "ladder_down_b": "ladder_down_a"}}
const STOP := {"ladder_climb_up": "ladder_up_idle", "ladder_up_a": "ladder_up_idle_flip", "ladder_up_b": "ladder_up_idle",
		"ladder_climb_down": "ladder_down_idle", "ladder_down_a": "ladder_down_idle_flip", "ladder_down_b": "ladder_down_idle"}
## (graph fades: ledge-grab -> climb 0.2; climb -> its ^idle 0.1-0.2, ^idle -> fast cycle 0.1 on a held
## request, so a cycle -> cycle join fades ~0.15; a stop starts on the frame the cycle ends, 0.2; ^idle ->
## ledge-grab 0.4)
const FADE_START := 0.2
const FADE_CYCLE := 0.15
const FADE_STOP := 0.2
const FADE_HUB := 0.4
const ANCHOR := {"ladder_climb_up": "l_grip", "ladder_up_a": "r_grip", "ladder_up_b": "l_grip", "ladder_up_idle": "r_grip",
		"ladder_up_idle_flip": "l_grip", "ladder_climb_down": "r_grip", "ladder_down_a": "l_grip", "ladder_down_b": "r_grip",
		"ladder_down_idle": "l_grip", "ladder_down_idle_flip": "r_grip"}

var ctrl: Node
var lib: TravMoveLibrary
var ledges: TravLedgeGraph
var probe: TraversalProbe

var lane_id := -1
var lane := {}
var n := Vector3.BACK
var ground_y := 0.0
var u := 0.0
var cycle := ""                    ## the playing clip of the chain ("" = the hub)
var cycle_t := 0.0
var cycle_dir := ""                ## "up" / "down" while a chain plays
var hub_t := 0.0
var root := Transform3D.IDENTITY
var pins: Array = []
var content := {}
var serial := 0
var info := {}
var _pending_exit := ""            ## "top" / "bottom": the dismount the chain stopped for (after the hub's dwell)
var _cap_off := Vector3.ZERO
var _cap_v := Vector3.ZERO
var _cap_t := 1e9
var _u0 := 0.0                     ## the rung-anchored root height at the clip's start
var _u_off := 0.0                  ## position offset at the clip start (continuity), eased out
var _u_dv := 0.0                   ## velocity difference at the clip start, eased out
var _u_t := 1e9
var _u_vel := 0.0
var _u_hub0 := 0.0                 ## the lowest hub (the mount's end)
var _entry_t := 1e9                ## time since the lane was entered (its first hub's plants come in)
var _land_cache := {}              ## "limb|t0" -> _land_time() of the playing clip (cleared at every clip start)
var _grip_since := {}              ## "clip|hand|rung" -> the clip time its grip first applied (cleared at every clip start)
var _held_rungs := {}              ## hand -> the rung its grip held at full weight at the end of the last clip
var _hurry := false                ## the stop plays toward an end the stick is held to (HURRY_RATE)
var _held_hub := false             ## the stick was held in the climb's direction when this hub began
const GRIP_RAMP_S := 0.12
const ENTRY_RAMP_S := 0.12


func _init(p_ctrl: Node) -> void:
	ctrl = p_ctrl
	lib = ctrl.lib
	ledges = ctrl.ledges
	probe = ctrl.probe


func active() -> bool:
	return lane_id >= 0


static func kind_of(ln: Dictionary) -> String:
	return str(ln.get("kind", "climb"))


## The climber's outward normal for a lane seen from `from` (ladders have their own).
static func lane_normal(ln: Dictionary, from: Vector3) -> Vector3:
	var nn: Vector3 = ln.get("normal", Vector3.ZERO)
	if nn.length() > 0.1:
		return Vector3(nn.x, 0, nn.z).normalized()
	var b: Vector3 = ln.bottom
	var d := Vector3(from.x - b.x, 0, from.z - b.z)
	return d.normalized() if d.length() > 1e-3 else Vector3.BACK


static func standoff(ln: Dictionary) -> float:
	return STANDOFF_LADDER


## The root's rise over the mount from the ground (its end is the lowest hub).
static func mount_rise() -> float:
	var l := TravMoveLibrary.shared()
	return float(l.track_point("ladder_mount_bottom", "align", float(l.move("ladder_mount_bottom").get("duration", 1.3))).y)


## Height of the first rung's top above the ground (under the feet at the end of the mount).
static func first_rung_top() -> float:
	return mount_rise() + HUB_FOOT_REST


## Height above the ground of a ladder's top platform that the top dismount reaches from the hub
## `steps` hub positions (two rungs each) above the mount's (the dismount's hands land 1.40 m
## above its start root).
static func top_height(steps: int) -> float:
	var l := TravMoveLibrary.shared()
	var th: Variant = (l.move("ladder_dismount_top").get("anchor", {}) as Dictionary).get("top_h")
	return mount_rise() + 2.0 * steps * PITCH + (float(th) if th != null else DISMOUNT_TOP_DROP)


## Root position on the lane line at height uu above the lane's ground.
func line_point(uu: float) -> Vector3:
	var b: Vector3 = lane.bottom
	return Vector3(b.x, ground_y + uu, b.z) + n * standoff(lane)


## The highest root: where the top dismount's hands land on the platform top (its anchor top_h
## above the start root, ~1.4 m).
func u_max() -> float:
	var top: Vector3 = lane.top
	var drop := DISMOUNT_TOP_DROP
	if lib.has("ladder_dismount_top"):
		var th: Variant = (lib.move("ladder_dismount_top").anchor as Dictionary).get("top_h")
		if th != null:
			drop = float(th)
	return top.y - ground_y - drop


func basis() -> Basis:
	return Basis(Vector3.UP, TravMoveSelector.yaw_of(-n))


## Ground under the lane (the climber's side).
static func ground_under(p: TraversalProbe, ln: Dictionary, nn: Vector3) -> float:
	var b: Vector3 = ln.bottom
	var q := b + nn * (standoff(ln) + 0.3)
	var sup := p.support_at(Vector3(q.x, b.y + 0.3, q.z), 1.0, 4.0)
	return float(sup.y) if bool(sup.hit) else b.y


## The mount plan's geometry: the root at the end of ladder-auto-climb on the lane, and the
## start point S on the ground in front of it.
func mount_geometry(ln: Dictionary, from: Vector3) -> Dictionary:
	var nn := lane_normal(ln, from)
	var gy := ground_under(probe, ln, nn)
	var b: Vector3 = ln.bottom
	var ea := lib.track_point("ladder_mount_bottom", "align", float(lib.move("ladder_mount_bottom").duration))
	var bas := Basis(Vector3.UP, TravMoveSelector.yaw_of(-nn))
	var end_root := Vector3(b.x, gy + ea.y, b.z) + nn * standoff(ln)
	var s := end_root - bas * Vector3(ea.x, 0, ea.z)
	s.y = gy
	return {"normal": nn, "ground": gy, "end_root": end_root, "start": s, "yaw": TravMoveSelector.yaw_of(-nn), "rise": ea.y}


func enter(lid: int, uu: float, from: Vector3, fade := 0.2) -> void:
	lane_id = lid
	lane = ledges.lanes[lid]
	n = lane_normal(lane, from)
	ground_y = ground_under(probe, lane, n)
	u = uu
	_u_hub0 = minf(uu, maxf(U_MIN, mount_rise()))
	cycle = ""
	cycle_dir = ""
	cycle_t = 0.0
	hub_t = 0.0
	_u_vel = 0.0
	_u_t = 1e9
	_u_off = 0.0
	_u_dv = 0.0
	_pending_exit = ""
	_hurry = false
	# (walked into the ladder with the stick held on: the climb goes on from the mount's hub at once)
	_held_hub = (ctrl.input_state.get("move", Vector2.ZERO) as Vector2).y < -0.3
	var off: Vector3 = ctrl.body.global_position - (line_point(u) + n * 0.18)
	_cap_off = off if off.length() < 0.3 else Vector3.ZERO
	# ... and continues how it moved (the mount's capsule velocity), inertialized onto the lane.
	_cap_v = TravInertializer._clampv(ctrl._cap_vel, 3.0) if _cap_off != Vector3.ZERO or off.length() < 0.3 else Vector3.ZERO
	_cap_t = 0.0
	# (Entered from the mount, whose last pose has the fists open 3.5 cm above the rung: the hub's
	# plants come in over ENTRY_RAMP_S, the mount's feet are already on their rung.)
	_entry_t = 0.0
	_hub_content(fade, "trav_enter_ladder", "proposed")
	_pose()


func _next() -> int:
	serial += 1
	return serial


func _hub_content(fade: float, key := "graph:settle", status := "graph", pins_continue := true) -> void:
	# The hub state starts its loop from the beginning (it used to start at 0 for one tick and
	# jump to the lane's running clock on the next: a pose jump inside the switch).
	hub_t = 0.0
	var fc := lib.first_clip("ladder_idle")
	content = {"clip": fc.clip, "clip_t": 0.0, "key": "lhub:%d" % _next(), "fade": fade, "state": "ledge-grab",
			"status": "graph", "loop": true, "trace_key": key, "trace_status": status, "pins_continue": pins_continue}


## Returns an action for the controller: "" / "let_go" / "top" / "bottom".
func input(inp: Dictionary, jump: bool) -> String:
	if not active():
		return ""
	if bool(inp.get("crouch", false)) or (jump and cycle == ""):
		return "let_go"
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if _pending_exit != "":
		if (_pending_exit == "top" and mv.y >= -0.3) or (_pending_exit == "bottom" and mv.y <= 0.3):
			_pending_exit = ""
	if cycle != "":
		return ""
	if _pending_exit != "":
		if hub_t >= (HUB_HELD_S if _held_hub else HUB_DWELL_S):
			var ex := _pending_exit
			_pending_exit = ""
			return ex
		return ""
	# (The stick held on from the move before: the hub goes on at once, HUB_HELD_S.)
	var wait := HUB_HELD_S if _held_hub else HUB_MIN_S
	var dwell := HUB_HELD_S if _held_hub else HUB_DWELL_S
	if mv.y < -0.3:
		if not _room("up", u):
			if hub_t >= dwell:
				return "top"
			_pending_exit = "top"
			return ""
		# (The hub's pose settles first: after the mount the hands close on their rung in its fade.)
		if hub_t >= wait:
			_start("ladder_climb_up", "up", FADE_START)
	elif mv.y > 0.3:
		if not _room("down", u):
			if hub_t >= dwell:
				return "bottom"
			_pending_exit = "bottom"
			return ""
		if hub_t >= wait:
			_start("ladder_climb_down", "down", FADE_START)
	else:
		_held_hub = false
	return ""


## True when one more step (two rungs) in `dir` from a hub at `u_hub` stays on the ladder: up to the
## top dismount's hub, down to the mount's.
func _room(dir: String, u_hub: float) -> bool:
	var step := 2.0 * PITCH
	if dir == "up":
		return u_hub + step <= u_max() + HOLD_ROOM_M
	return u_hub - step >= _u_hub0 - HOLD_ROOM_M


## Rise of a move's root over the whole clip (its anchored align).
func _rise(id: String) -> float:
	var m := lib.move(id)
	return _align_y(id, float(m.get("duration", 0.0))) - _align_y(id, 0.0)


## Starts a clip of the chain. The root height is put on the rungs: the clip's held fist (ANCHOR) on
## the axis of the rung nearest to it; position and velocity stay continuous and the difference is
## eased out over U_EASE_S.
func _start(id: String, dir: String, fade: float) -> void:
	var m := lib.move(id)
	if m.is_empty():
		return
	var r := _rate()
	var dt0 := 1.0 / 120.0
	var v_new := (_align_y(id, dt0 * r) - _align_y(id, 0.0)) / dt0
	var ideal := u
	var an := str(ANCHOR.get(id, ""))
	if an != "":
		var s0 := lib.track_point(id, an, 0.0).y - lib.track_point(id, "align", 0.0).y
		var y_w := ground_y + u + s0
		var rung := rung_at(y_w)
		var ax_y := float((rung.a as Vector3).y)
		if absf(ax_y - y_w) < PITCH * 0.5:
			ideal = u + (ax_y - y_w)
	_u0 = ideal
	_land_cache.clear()
	_held_rungs.clear()
	for pn: Dictionary in pins:
		if str(pn.limb).ends_with("hand") and float(pn.weight) >= 0.999:
			_held_rungs[str(pn.limb)] = str((pn.shape as Dictionary).get("name", ""))
	_grip_since.clear()
	_u_off = u - ideal
	_u_dv = _u_vel - v_new
	_u_t = 0.0
	cycle = id
	cycle_dir = dir
	cycle_t = 0.0
	info = {"cycle": id, "rise": _rise(id)}
	var fc := lib.first_clip(id)
	content = {"clip": fc.clip, "clip_t": 0.0, "key": "cyc:%d" % _next(), "fade": fade, "state": fc.state, "status": "graph",
			"pins_continue": true}
	ctrl._post_request(fc.state)


func _rate() -> float:
	return (1.25 if bool(ctrl.input_state.get("sprint", false)) else 1.0) * (HURRY_RATE if _hurry else 1.0)


func tick(delta: float) -> void:
	if not active():
		return
	hub_t += delta
	_cap_t += delta
	_u_t += delta
	_entry_t += delta
	var u_before := u
	if cycle != "":
		var m := lib.move(cycle)
		var r := _rate()
		cycle_t = minf(cycle_t + delta * r, float(m.duration))
		if cycle_t >= float(m.duration) - 0.5 * delta * r:
			cycle_t = float(m.duration)
		var ease := TravInertializer.decay(Vector3(0.0, _u_off, 0.0), Vector3(0.0, _u_dv, 0.0), _u_t, U_EASE_S).y
		u = _u0 + _align_y(cycle, cycle_t) - _align_y(cycle, 0.0) + ease
		if delta > 0.0:
			_u_vel = (u - u_before) / delta
		content.clip_t = cycle_t
		if cycle_t >= float(m.duration) - 1e-6:
			_clip_done()
	else:
		var fc := lib.first_clip("ladder_idle")
		content.clip_t = fposmod(hub_t, maxf(float(fc.length), 0.1))
		_u_vel = 0.0
	_pose()


## A clip of the chain ended: the next move while the request is held and the ladder goes on, else
## the stop (the clip's ^idle state); a stop ends in the hub.
func _clip_done() -> void:
	var done := cycle
	var dir := cycle_dir
	if STOP.values().has(done):
		cycle = ""
		cycle_dir = ""
		_hurry = false
		_hub_content(FADE_HUB)
		var mv0: Vector2 = ctrl.input_state.get("move", Vector2.ZERO)
		_held_hub = (dir == "up" and mv0.y < -0.3) or (dir == "down" and mv0.y > 0.3)
		# At the end of the ladder with the stick still toward it: the dismount after the hub's dwell.
		if dir == "up" and mv0.y < -0.3 and not _room("up", u):
			_pending_exit = "top"
		elif dir == "down" and mv0.y > 0.3 and not _room("down", u):
			_pending_exit = "bottom"
		return
	var mv: Vector2 = ctrl.input_state.get("move", Vector2.ZERO)
	var want := (dir == "up" and mv.y < -0.3) or (dir == "down" and mv.y > 0.3)
	# The hub this chain would stop at after the next move (each move is one step of two rungs).
	var hub_now := u + _rise(str(STOP.get(done, "")))
	if want and _room(dir, hub_now):
		_start(str((NEXT[dir] as Dictionary)[done]), dir, FADE_CYCLE)
	else:
		_start(str(STOP[done]), dir, FADE_STOP)
		# (at the ladder's end with the stick held on: the stop hurries to the dismount)
		_hurry = want


## The chain clip's vertical travel, C1: the align tracks are key-reduced (about 10 keys/s, linear);
## a Catmull-Rom curve through the track sampled every ALIGN_KEY_S passes through the same heights
## at those times (start, end and rise unchanged) with a continuous velocity.
const ALIGN_KEY_S := 0.1

func _align_y(id: String, t: float) -> float:
	var d := float(lib.move(id).get("duration", 0.0))
	if d <= ALIGN_KEY_S:
		return float(lib.track_point(id, "align", clampf(t, 0.0, d)).y)
	var h := ALIGN_KEY_S
	var i := floori(clampf(t, 0.0, d) / h)
	var t0 := minf(i * h, d - h)
	var x := clampf((t - t0) / h, 0.0, 1.0)
	var p1 := float(lib.track_point(id, "align", t0).y)
	var p2 := float(lib.track_point(id, "align", minf(t0 + h, d)).y)
	# Ends: extrapolated neighbours (the tangent there is the end interval's slope).
	var p0 := float(lib.track_point(id, "align", t0 - h).y) if t0 - h >= -1e-6 else 2.0 * p1 - p2
	var p3 := float(lib.track_point(id, "align", t0 + 2.0 * h).y) if t0 + 2.0 * h <= d + 1e-6 else 2.0 * p2 - p1
	var x2 := x * x
	var x3 := x2 * x
	return 0.5 * (2.0 * p1 + (p2 - p0) * x + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * x2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * x3)


## The lane root's velocity this tick (the rig root inertialization at a content switch carries
## the difference between the old root's velocity and this one).
func root_velocity() -> Vector3:
	return (line_point(u) - line_point(u - _u_vel / 120.0)) * 120.0 if active() else Vector3.ZERO


func _pose() -> void:
	root = Transform3D(basis(), line_point(u))
	pins = _rung_pins()
	# The capsule: behind the root, clear of the rungs (design 13 lane stand-off); where it was
	# when the lane was entered eases into that over CAP_EASE_S (no capsule / camera jump).
	var cap := root.origin + n * 0.18
	if _cap_t < CAP_EASE_S:
		cap += TravInertializer.decay(_cap_off, _cap_v, _cap_t, CAP_EASE_S)
	ctrl.body.global_position = cap


## A rung as a TravSurfaces cylinder (across the ladder) whose top is nearest to height y.
func rung_at(y: float) -> Dictionary:
	return rung_of(lane, n, ground_y, y)


## The rung of lane `ln` (outward normal nn) whose top is nearest to height y.
static func rung_of(ln: Dictionary, nn: Vector3, _gy: float, y: float) -> Dictionary:
	var b: Vector3 = ln.bottom
	var pitch := float(ln.get("rung_pitch", PITCH))
	var off := float(ln.get("rung_offset", pitch))
	var r := float(ln.get("rung_radius", RUNG_R))
	var k := maxi(0, int(round((y - (b.y + off)) / pitch)))
	var top: Vector3 = ln.top
	k = mini(k, int(floor((top.y - b.y - off) / pitch + 1e-3)))
	var cy := b.y + off + k * pitch - r
	var side := Vector3.UP.cross(nn).normalized() * float(ln.get("width", 0.5)) * 0.5
	var c := Vector3(b.x, cy, b.z)
	return {"type": "cyl", "a": c - side, "b": c + side, "r": r, "name": "rung_%d" % k}


## The rung whose axis is nearest to height y (a closed fist's hole).
func rung_axis_at(y: float) -> Dictionary:
	return rung_at(y + float(lane.get("rung_radius", RUNG_R)))


## Hands and feet on the rungs during the playing clip's own contact windows (design 8.4): a hand
## closes on the rung whose axis is nearest its fist's hole (l/r_grip), a sole stands on the rung
## whose top is nearest to it. The clip's held hand (ANCHOR) holds its rung the whole clip.
func _rung_pins() -> Array:
	var id := cycle if cycle != "" else "ladder_idle"
	var t := cycle_t if cycle != "" else fposmod(hub_t, maxf(float(lib.first_clip("ladder_idle").length), 0.1))
	var m := lib.move(id)
	var dur := float(m.get("duration", 0.0))
	var windows := []
	for c: Dictionary in m.get("contacts", []):
		var limb := str(c.limb)
		if limb.ends_with("hand") or limb.ends_with("foot"):
			windows.append([limb, float(c.t_on), float(c.t_off)])
	var an := str(ANCHOR.get(id, ""))
	if an != "":
		windows.append([an.substr(0, 1) + "_hand", 0.0, dur])
	# Every limb on a rung at the end of a move of the chain (the held hand and foot, and the two
	# that have just arrived) is held over its last JOIN_HOLD_S: the next clip's held limbs are
	# held across the join (a hand whose grip came in only with the next clip went 1.1 cm into its
	# rung meanwhile); the limbs the next clip moves are let go by its own windows.
	if cycle != "" and not STOP.values().has(cycle):
		for limb: String in ["l_hand", "r_hand", "l_foot", "r_foot"]:
			windows.append([limb, dur - JOIN_HOLD_S, dur])
	var best := {}
	for wv: Array in windows:
		var limb: String = wv[0]
		var t_on: float = wv[1]
		var t_off: float = wv[2]
		var w := 0.0
		if t >= t_on and t <= t_off:
			w = 1.0
		elif t < t_on and t > t_on - 0.08:
			w = 1.0 - (t_on - t) / 0.08
		elif t > t_off and t < t_off + 0.1:
			w = 1.0 - (t - t_off) / 0.1
		if w <= 0.0:
			continue
		var tc := clampf(t, t_on, t_off)
		var hand := limb.ends_with("hand")
		var al := lib.track_point(id, "align", tc)
		var rung: Dictionary
		var dist := 0.0
		var above := 0.0
		if hand:
			var gname := limb.substr(0, 1) + "_grip"
			var hole := (root * (lib.track_point(id, gname, tc) - al)).y
			rung = rung_axis_at(hole)
			dist = absf(float((rung.a as Vector3).y) - hole)
		else:
			var sole := (root * (lib.track_point(id, limb, tc) - al)).y + HUB_FOOT_REST
			rung = rung_at(sole)
			above = sole - float((rung.a as Vector3).y) - float(rung.r)
			dist = absf(above)
		var tl := -1.0 if hand or cycle == "" else _land_time(id, limb, t_on, t_off)
		if tl >= 0.0:
			# A sole coming down onto its rung is planted as it lands, on the rung it lands on (by
			# its distance from the rung the weight came in 5-8 cm above the top: the climb-down's
			# left foot was pulled 5 cm down onto its rung in three frames, a 10 cm knee pop).
			var r0 := minf(tl - LAND_LEAD_S, t_off - 0.25 * LAND_RAMP_S)
			var r1 := minf(r0 + LAND_RAMP_S, t_off)
			w = clampf((t - r0) / maxf(r1 - r0, 1e-3), 0.0, 1.0) if t <= t_off else w
			if w <= 0.0:
				continue
			rung = rung_at(_sole_y(id, limb, tl))
		else:
			if dist > RUNG_SNAP_M:
				continue
			w *= 1.0 - smoothstep(RUNG_SNAP_M - RUNG_FADE_M, RUNG_SNAP_M, dist)
			# (A grip that snaps on: its weight comes in over GRIP_RAMP_S from the frame it
			# first applies, not over the 3 cm the reference hole passes in about a frame; fix
			# round 3: the climb-up's right fist needed 5.8 cm at full weight three frames after it
			# appeared, and the IK's added-motion limit let the fist lag 2.8 cm off its rung.)
			if hand:
				var gk := "%s|%s|%s" % [id, limb, str(rung.name)]
				if not _grip_since.has(gk):
					_grip_since[gk] = t
				w *= smoothstep(0.0, 1.0, clampf((t - float(_grip_since[gk])) / GRIP_RAMP_S, 0.0, 1.0)) if not pins_carry(limb, str(rung.name)) else 1.0
		if cycle == "" and _entry_t < ENTRY_RAMP_S and hand:
			# (From a small weight on: a grip pin keeps the rung's guard off the fingers closing on it.)
			w *= maxf(0.02, _entry_t / ENTRY_RAMP_S)
		w = smoothstep(0.0, 1.0, w)
		if best.has(limb) and float((best[limb] as Dictionary).weight) >= w:
			continue
		best[limb] = {"limb": limb, "weight": w, "mode": "grip" if hand else "plant", "surface": "rung", "shape": rung,
				"id": "%s:%s:%s" % [lane_id, limb, str(rung.name)]}
		# (The clip's own fist hole of the moment, data/traversal/ladder_grips.json via the runtime
		# table: the hole moves up to 1 cm within a clip and narrows to 0.6 cm where the fingers
		# squeeze; on the median hole a squeezing fist had the rung 1 cm in its fingers.)
		if hand:
			var go: Variant = _grip_offset(m, limb, tc)
			if go != null:
				(best[limb] as Dictionary)["grip_offset"] = go
	return best.values()


## A hand that held this rung at full weight when its clip started keeps it at full weight (a grip
## carried across a join does not ramp in again).
func pins_carry(limb: String, rung: String) -> bool:
	return str(_held_rungs.get(limb, "")) == rung


## World height of a chain clip's sole at clip time x (the root follows the clip's align from the
## rung-anchored start height; the start's eased offset left out).
func _sole_y(id: String, limb: String, x: float) -> float:
	return ground_y + _u0 + float(lib.track_point(id, limb, x).y) - float(lib.track_point(id, "align", 0.0).y) + HUB_FOOT_REST


## The clip time at which a sole that starts its window [t0, t1] more than LAND_ABOVE_M above its
## rung top comes within LAND_AT_M of it (t1 when it does not in the window); -1 for a sole on (or
## in) its rung at t0.
func _land_time(id: String, limb: String, t0: float, t1: float) -> float:
	var key := "%s|%s|%.4f|%.4f" % [id, limb, t0, t1]
	if _land_cache.has(key):
		return float(_land_cache[key])
	var tl := _land_scan(id, limb, t0, t1)
	_land_cache[key] = tl
	return tl


func _land_scan(id: String, limb: String, t0: float, t1: float) -> float:
	var y0 := _sole_y(id, limb, t0)
	var r0 := rung_at(y0)
	if y0 - float((r0.a as Vector3).y) - float(r0.r) <= LAND_ABOVE_M:
		return -1.0
	var x := t0
	while x < t1:
		x = minf(x + 1.0 / 120.0, t1)
		var y := _sole_y(id, limb, x)
		var r := rung_at(y)
		if y - float((r.a as Vector3).y) - float(r.r) <= LAND_AT_M:
			return x
	return t1


## The fist hole's centre in the wrist frame at clip time t (the samples of the clip's closed fist,
## linear between them, the nearest one outside them; the move's median without samples) or null.
func _grip_offset(m: Dictionary, limb: String, t: float) -> Variant:
	var tr: Array = (m.get("grip_tracks", {}) as Dictionary).get(limb, [])
	if tr.is_empty():
		var go: Array = (m.get("grip_offsets", {}) as Dictionary).get(limb, [])
		return Vector3(float(go[0]), float(go[1]), float(go[2])) if go.size() == 3 else null
	var k := 0
	while k < tr.size() - 1 and float(tr[k + 1][0]) <= t:
		k += 1
	var a: Array = tr[k]
	var va := Vector3(float(a[1]), float(a[2]), float(a[3]))
	if k + 1 >= tr.size() or t <= float(a[0]):
		return va
	var b: Array = tr[k + 1]
	var span := float(b[0]) - float(a[0])
	# (A gap of open-fist samples between two holds: the nearer hold's centre.)
	if span > 0.11:
		return va if t - float(a[0]) < float(b[0]) - t else Vector3(float(b[1]), float(b[2]), float(b[3]))
	return va.lerp(Vector3(float(b[1]), float(b[2]), float(b[3])), clampf((t - float(a[0])) / maxf(span, 1e-4), 0.0, 1.0))


## Rungs near the body as IK guards (a hand or foot passing a rung it does not hold is kept out of
## it; a fist is not pushed off the rung it closes on, TraversalIK).
func guard_rungs() -> Array:
	var out := []
	if not active():
		return out
	var b: Vector3 = lane.bottom
	var y0 := ground_y + u - 0.4
	var y1 := ground_y + u + 2.1
	var pitch := float(lane.get("rung_pitch", PITCH))
	var y := y0
	var seen := {}
	while y <= y1:
		var r := rung_at(y)
		if not seen.has(str(r.name)):
			seen[str(r.name)] = true
			out.append(r)
		y += pitch
	return out


func state() -> Dictionary:
	return {"lane": lane_id, "kind": kind_of(lane), "u": u, "u_max": u_max() if active() else 0.0, "cycle": cycle, "dir": cycle_dir}
