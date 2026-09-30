class_name TravStepAssist
extends RefCounted
## Step assist under 0.55 m (design 7.9): low clutter (stumps, logs, roots, the fallen log's end,
## low steps) is stepped onto without a clip, so free-running does not stall. Called by the
## player's ground movement before move_and_slide() when the traversal controller does not own
## the body (hook in design 16: `traversal.step_assist(delta)`); the preview runner calls it the
## same way. The capsule rises from the ground to the top over the last max(0.35, v * 0.12) m
## before the face along a smoothstep, keeping its horizontal speed; LocoBrain stays in MOVE.
## TraversalIK may place the stepping foot on the top (weight 0 -> 1 -> 0 over the step).
##
##   var sa := TravStepAssist.new()
##   sa.step(body, probe, wish_dir, speed, delta)     # returns the height it added this tick
##   (while sa.stepping() the ground movement keeps its ground acceleration: the lifted capsule
##   is off the floor for those ticks)

const MAX_RISE := 0.55
## The highest step this assist takes (m); MAX_RISE for the player, a body of its own (BodyStep: a worker, an animal) sets it.
var max_rise := MAX_RISE
## The body's radius (m): the probe points run from its edge (the player's capsule 0.3; a bison 0.5).
var radius := RADIUS
## A character under the probe (a parent, a child, an animal) is not a step (BodyStep: a walker beside another).
var skip_characters := false
## Only a rise with a steep face in front of it is a step (the player's: a slope is walked, not stepped).
var require_face := false
const MIN_RISE := 0.06
const RADIUS := 0.3               ## the player capsule radius
const REFINE := 7                 ## bisection steps of the face distance between two probes (1 mm)

var last := {}                    ## debug: {face_d, top, rise}
var _active := false
var _base_y := 0.0                ## the ground height the running step started from
var _face := Vector3.INF          ## a point of the running step's face (at the body's height)
var _top_y := 0.0


## Seam fix 2026-09-24 (user complaint "snapping / teleporting"): the body used to stay on the
## ground until the last centimetres before the face and then rise the whole step in ONE tick
## (37 cm at the fallen log's end): the floor snap of move_and_slide() pulled the raised body back
## to the ground every tick, the face distance only took the probe spacing's values (0.3, 0.2,
## 0.12 m: the rise came in 3-13 cm stairs), and the rise was re-based on the current height every
## tick. Now the face distance is refined between the probes and remembered once the capsule's
## front has passed it, the rise follows one smoothstep from the height the step started at to the
## top while the capsule's CENTRE comes up to the face, the body is held at the top until its
## centre stands over it, and a tick that lifts the body points its velocity up so
## move_and_slide() does not snap it back down.
func step(body: CharacterBody3D, probe: TraversalProbe, dir: Vector3, speed: float, delta: float) -> float:
	last = {}
	var was := _active
	_active = false
	dir.y = 0.0
	if dir.length() < 0.1 or (not body.is_on_floor() and not was):
		return 0.0
	dir = dir.normalized()
	var p := body.global_position
	var base := minf(_base_y, p.y) if was else p.y
	var L := maxf(0.35, maxf(speed, 1.0) * 0.12)
	var face_d := INF
	var top := -INF
	var d_miss := 0.0
	for d: float in [0.01, 0.06, 0.12, 0.2, 0.3, 0.42, 0.55, 0.7]:
		if d > L + 0.06:
			break
		var hit := _top_at(probe, p, dir, d, base)
		if hit.is_empty():
			d_miss = d
			continue
		if float(hit.rise) >= max_rise:
			return 0.0
		if float(hit.rise) > MIN_RISE and float(hit.ny) > 0.7:
			face_d = d
			top = float(hit.y)
			break
		d_miss = d
	if face_d < INF and d_miss > 0.0:
		# The face lies between the last probe without a top and this one: bisect.
		var lo := d_miss
		var hi := face_d
		for k in REFINE:
			var mid := (lo + hi) * 0.5
			var h2 := _top_at(probe, p, dir, mid, base)
			if not h2.is_empty() and float(h2.rise) > MIN_RISE and float(h2.rise) < max_rise and float(h2.ny) > 0.7:
				hi = mid
			else:
				lo = mid
		face_d = hi
	if face_d < INF and (d_miss > 0.0 or not was or _face == Vector3.INF):
		if not was:
			# Room to stand on the top.
			var over := p + dir * (radius + face_d + 0.12)
			var cl := probe.ray(Vector3(over.x, top + 0.05, over.z), Vector3(over.x, top + 1.5, over.z))
			if not cl.is_empty():
				return 0.0
			# A step has a face: a ray forward at half its height meets a steep surface (a slope's ground is no step: the player walks
			# up it on the floor, where a rise of 6 cm every 35 cm would have lifted the body in stairs, user 2026-09-30 "jittery")
			if require_face:
				var ry := base + clampf((top - base) * 0.5, 0.03, 0.3)
				var ro := Vector3(p.x, ry, p.z)
				var fr := probe.ray(ro, ro + dir * (radius + face_d + 0.2))
				if fr.is_empty() or absf((fr.normal as Vector3).y) > 0.5:
					return 0.0
		_face = p + dir * (radius + face_d)
		_top_y = top
	elif was and _face != Vector3.INF:
		# The capsule's front is past the face: the remembered face and top.
		top = _top_y
	else:
		_face = Vector3.INF
		return 0.0
	# Centre to face along the travel.
	var face_c := (_face - p).dot(dir)
	if face_c > radius + L + 0.2:
		_face = Vector3.INF
		return 0.0
	if p.y >= top - 0.03 and face_c < 0.05:
		var under := probe.ray(Vector3(p.x, top + 0.2, p.z), Vector3(p.x, top - 0.06, p.z))
		if not under.is_empty() or face_c < -radius:
			# Up: the centre stands over the top, whose floor takes over.
			_face = Vector3.INF
			return 0.0
	var u := clampf(1.0 - (face_c - 0.05) / (radius + L - 0.05), 0.0, 1.0)
	var want := base + (top - base) * smoothstep(0.0, 1.0, u)
	if face_c <= 0.05:
		want = top + 0.005
	var dy := maxf(0.0, want - p.y)
	if dy > 0.0:
		body.global_position.y += dy
		# (Pointing up, the velocity keeps move_and_slide()'s floor snap from pulling the body back.)
		body.velocity.y = maxf(body.velocity.y, 0.001)
	elif want >= p.y - 0.01:
		body.velocity.y = maxf(body.velocity.y, 0.0)
	_active = true
	_base_y = base
	last = {"face_d": face_d, "face_c": face_c, "top": top, "rise": top - p.y, "dy": dy, "base": base}
	return dy


## True while a step is lifting the body (the ground movement keeps its ground acceleration: the
## lifted capsule is not on the floor for those ticks).
func stepping() -> bool:
	return _active


## The top under the probe point `d` ahead of the capsule's front: {y, rise (above base), ny} or {}.
func _top_at(probe: TraversalProbe, p: Vector3, dir: Vector3, d: float, base: float) -> Dictionary:
	var q := p + dir * (radius + d)
	var h := probe.ray(q + Vector3.UP * (max_rise + 0.1), q - Vector3.UP * 0.1)
	if h.is_empty() or (skip_characters and h.get("collider") is CharacterBody3D):
		return {}
	var hy: float = (h.position as Vector3).y
	return {"y": hy, "rise": hy - base, "ny": (h.normal as Vector3).y}
