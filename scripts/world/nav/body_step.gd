class_name BodyStep
extends RefCounted
## A walker's step up and over what lies low in its way (user 2026-09-29: "they should be able to ... walk over things"): the
## logs lying about, a stump, a low step, anything up to TravStepAssist.MAX_RISE (0.55 m) with room to stand on its top. The
## player's own step assist (TravStepAssist, design 7.9: the capsule rises from the ground to the top along a smoothstep over
## the last few decimetres before the face, keeping its speed) on a worker, a child or a recruit, with a probe of its own
## that leaves the walker's body out. The navigation mesh lets a path run over a low log for it (NavSource: a log no higher
## than STEP_M is not baked).
##   var step := BodyStep.new(self)
##   step.step(Vector3(v.x, 0, v.z), speed, dt)       # after the velocity is set, before move_and_slide()

## The highest step a walker takes (m): a person up on to a log, over a stump, up a low step (the player's own is 0.55, and
## it vaults what is higher); a path is let over what is no higher than STEP_M where it is a log or a stump lying about
## (WalkGrid.LOW_STEP_M, the same).
const RISE_M := 0.75
const STEP_M := 0.75

var body: CharacterBody3D
var _assist := TravStepAssist.new()
var _probe: TraversalProbe


func _init(b: CharacterBody3D, rise := RISE_M) -> void:
	body = b
	_assist.max_rise = rise
	_assist.skip_characters = true


## The body lifted this tick toward the top of what is before it along `dir` (m/s along the ground); the height added.
func step(dir: Vector3, speed: float, dt: float) -> float:
	if body == null or not body.is_inside_tree():
		return 0.0
	if _probe == null:
		var ex: Array[RID] = [body.get_rid()]
		_probe = TraversalProbe.new(body.get_world_3d().direct_space_state, null, null, {}, ex)
	return _assist.step(body, _probe, dir, speed, dt)


## Lifting the body now (it is off the floor for those ticks).
func stepping() -> bool:
	return _assist.stepping()
