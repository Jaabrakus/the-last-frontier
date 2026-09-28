class_name OverUnderRig
extends RefCounted
## Drives the over-under's moving parts from its turnover clock and barrel state
## (weapons_balance_design.md 2.6, "code-driven model nodes"). Standing times; crouched in
## brackets (the source crouch clip strokes 0.033 s earlier):
##
##   0.00-0.067 (0.033) s   Cock      back to half cock (thumb; mostly hidden by the lock)
##   0.05-0.10 (0.016-0.066) s  Catch  pressed and released
##   0.067-0.467 (0.033-0.433) s  Barrels  180 deg about the swivel (local Z), smoothstep
##   1.00 s                 Cock      to full cock
##   fired barrel           Frizzen   open from its shot until 1.0 s into its Priming step
##
## The turnover clock and progress come from the weapon (OverUnderMusket.turn_clock /
## turn_progress); the windows from its `mechanism` block. The rig never changes gameplay
## state: it only poses nodes, so a model without some node still plays.

const COCK_FULL := 0.0
const COCK_HALF := deg_to_rad(-18.0)
const COCK_FIRED := deg_to_rad(-40.0)      ## flint on the frizzen (the musket's convention)
const COCK_SPEED := deg_to_rad(420.0)      ## thumb speed when cocking (rad/s)
const FRIZZEN_OPEN := deg_to_rad(-70.0)
const FRIZZEN_OPEN_SPEED := deg_to_rad(3000.0)   ## thrown open by the flint
const FRIZZEN_CLOSE_SPEED := deg_to_rad(500.0)
const CATCH_PRESSED := deg_to_rad(-14.0)
const FRIZZEN_CLOSE_AT := 1.0              ## s into the Priming step (the cue list's frizzen_close)
const PRIME_HALF_COCK_AT := 0.05
const PRIME_FULL_COCK_AT := 1.35

var model: Node3D
var barrels_node: Node3D
var cock: Node3D
var catch_node: Node3D
var frizzens: Array[Node3D] = [null, null]
var muzzles: Array[Marker3D] = [null, null]
var pans: Array[Marker3D] = [null, null]

var cock_angle := 0.0
var frizzen_angle: Array[float] = [0.0, 0.0]
var catch_angle := 0.0
var barrels_angle := 0.0

var _rest := {}


## Finds the moving nodes of `m` (an OverUnderModel). False when there is no Barrels node.
func bind(m: Node3D) -> bool:
	model = m
	_rest.clear()
	barrels_node = m.get_node_or_null("Barrels") as Node3D
	cock = m.get_node_or_null("Cock") as Node3D
	catch_node = m.get_node_or_null("Catch") as Node3D
	if barrels_node:
		frizzens = [barrels_node.get_node_or_null("FrizzenA") as Node3D,
				barrels_node.get_node_or_null("FrizzenB") as Node3D]
		muzzles = [barrels_node.get_node_or_null("MuzzleA") as Marker3D,
				barrels_node.get_node_or_null("MuzzleB") as Marker3D]
		pans = [barrels_node.get_node_or_null("PanA") as Marker3D,
				barrels_node.get_node_or_null("PanB") as Marker3D]
	for n: Node3D in [barrels_node, cock, catch_node, frizzens[0], frizzens[1]]:
		if n:
			_rest[n] = n.transform
	return barrels_node != null


## Muzzle marker of physical barrel i (null without the model).
func muzzle_of(i: int) -> Marker3D:
	return muzzles[i] if i >= 0 and i < 2 else null


func pan_of(i: int) -> Marker3D:
	return pans[i] if i >= 0 and i < 2 else null


## Poses every node for weapon `w` (an OverUnderMusket) after its tick. snap: jump to targets.
func update(w: Object, delta: float, snap := false) -> void:
	if model == null:
		return
	var b: OverUnderBarrels = w.barrels
	var mech: Dictionary = w.mechanism
	var st := "crouch" if bool(w.turn_crouched) else "stand"
	var turning := bool(w.turning)
	var t := float(w.turn_clock)
	# Barrels: the half turn.
	if turning:
		barrels_angle = (float(w.turn_from_top) + float(w.turn_progress)) * PI
	else:
		barrels_angle = float(b.top) * PI
	_pose(barrels_node, Basis(Vector3.BACK, barrels_angle))
	# Catch: pressed while the barrels are released.
	var target := 0.0
	if turning:
		var win: Array = mech.get("catch_s", {}).get(st, [0.05, 0.10])
		var a := float(win[0])
		var e := float(win[1])
		var m := (a + e) * 0.5
		if t > a and t < e:
			target = CATCH_PRESSED * (smoothstep(a, m, t) if t < m else 1.0 - smoothstep(m, e, t))
	catch_angle = target
	_pose(catch_node, Basis(Vector3.RIGHT, catch_angle))
	# Cock.
	var state := int(w.state)
	var goal := _cock_goal(w, b, turning, t, mech, state)
	if snap or goal == COCK_FIRED and state in [Firearm.State.HANGFIRE, Firearm.State.RECOIL]:
		cock_angle = goal
	else:
		cock_angle = move_toward(cock_angle, goal, COCK_SPEED * delta)
	_pose(cock, Basis(Vector3.RIGHT, cock_angle))
	# Frizzens.
	for i in 2:
		var open := _frizzen_open(w, b, i, state)
		var g := FRIZZEN_OPEN if open else 0.0
		if snap:
			frizzen_angle[i] = g
		else:
			var speed := FRIZZEN_OPEN_SPEED if open else FRIZZEN_CLOSE_SPEED
			frizzen_angle[i] = move_toward(frizzen_angle[i], g, speed * delta)
		_pose(frizzens[i], Basis(Vector3.RIGHT, frizzen_angle[i]))


func _cock_goal(w: Object, b: OverUnderBarrels, turning: bool, t: float, mech: Dictionary, state: int) -> float:
	if turning:
		return COCK_FULL if t >= float(mech.get("full_cock_s", 1.0)) else COCK_HALF
	match state:
		Firearm.State.HANGFIRE, Firearm.State.RECOIL:
			return COCK_FIRED
		Firearm.State.RELOADING:
			var wb := int(w.work_barrel)
			if wb != b.top:
				return COCK_HALF                  # charging the barrel underneath: lock on safety
			if int(w.work_step) == OverUnderBarrels.PRIME_STEP:
				var e := float(w.work_elapsed)
				if e < PRIME_HALF_COCK_AT:
					return COCK_FIRED
				return COCK_FULL if e >= PRIME_FULL_COCK_AT else COCK_HALF
			return COCK_FIRED
		Firearm.State.EMPTY:
			return COCK_HALF if b.is_charged(b.top) else COCK_FIRED
	if w.get("half_cocked") == true:
		return COCK_HALF                          # a cut turnover: still owes its full cock
	return COCK_FULL


func _frizzen_open(w: Object, b: OverUnderBarrels, i: int, state: int) -> bool:
	if i == b.top and state == Firearm.State.HANGFIRE:
		return true                                # the flint has thrown it open
	if b.is_ready(i):
		return false
	if b.stage[i] < OverUnderBarrels.PRIME_STEP:
		return true
	# Charged, not primed: open until the Priming step closes it.
	return not (int(w.work_barrel) == i and int(w.work_step) == OverUnderBarrels.PRIME_STEP
			and float(w.work_elapsed) >= FRIZZEN_CLOSE_AT)


func _pose(n: Node3D, local: Basis) -> void:
	if n == null or not _rest.has(n):
		return
	var r: Transform3D = _rest[n]
	n.transform = Transform3D(r.basis * local, r.origin)
