class_name Boat
extends Node3D
## A small boat on the water (data/boats/boats.json; user 2026-09-29: "add sailing ... lets do a rowboat and battle canoes of
## that period"). Its own light physics, no rigid body: it floats at the water's surface (WaterSurface), the current carries it,
## the crew's strokes push it, the keel holds it from slipping sideways, the shallows scrape it and a bank holds it.
##   drive(throttle, steer)   the helm: throttle -1..1 (the crew strokes / backs water), steer -1..1 (+ turns to the right)
##   crew_on                  how many of its seats are stroking (the player's seat and whoever else is aboard); the more, the
##                            faster it goes and the harder it is to turn (a war canoe's ten paddlers)
## Its forward is +Z, as everything in the project's.
##   stroke_phase()           0..1 through the current stroke; the drive is in its first STROKE_DRIVE and the pull comes in
##                            surges (a rowboat leaps at each stroke), averaging the crew's full push
## Headless (tests): no model; the physics all the same.

const GROUP := &"boats"
const STROKE_DRIVE := 0.4
## A person's weight aboard (kg).
const CREW_KG := 75.0
const GRAVITY_BOB := 0.02

var id := "rowboat"
var spec: Dictionary = {}
## Over the ground (flat), m/s.
var vel := Vector3.ZERO
var yaw_rate := 0.0
var throttle := 0.0
var steer := 0.0
var crew_on := 1
var cargo_kg := 0.0
## What it was built to (BoatBuild.stats: speed_mult, leak_l_per_h, wear_mult ...): empty for a boat with no maker's grade.
var grade := {}
## How much of its hull is on the ground (0 floating .. 1 aground) and whether it is on water at all.
var grounded := 0.0
var afloat := true
var _t := 0.0
var _stroke := 0.0
var _flat_y := 0.0


static func spec_of(boat_id: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/boats/boats.json"))
	return (d as Dictionary).get(boat_id, {}) if d is Dictionary else {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/boats/boats.json"))
	if d is Dictionary:
		for k: String in d:
			if not k.begins_with("_"):
				out.append(k)
	return out


## A boat of kind `boat_id` put on the water at (x, z), facing `yaw` (radians, forward +Z when 0).
static func make(boat_id: String, at: Vector3, yaw := 0.0) -> Boat:
	var b := Boat.new()
	b.id = boat_id
	b.spec = spec_of(boat_id)
	b.name = "Boat_" + boat_id
	b.rotation.y = yaw
	b.position = at
	b.crew_on = mini(int(b.spec.get("crew", 1)), 1)
	return b


func _ready() -> void:
	add_to_group(GROUP)
	if spec.is_empty():
		spec = spec_of(id)
	process_physics_priority = 5
	_settle()


func forward() -> Vector3:
	var f := basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


func right() -> Vector3:
	var r := basis.x
	return Vector3(r.x, 0.0, r.z).normalized()


func num(key: String, dflt := 0.0) -> float:
	var v := float(spec.get(key, dflt))
	if key == "max_mps" and not grade.is_empty():
		v *= float(grade.get("speed_mult", 1.0))   # a truer hull is quicker
	return v


func speed() -> float:
	return vel.dot(forward())


## The helm.
func drive(t: float, s: float) -> void:
	throttle = clampf(t, -1.0, 1.0)
	steer = clampf(s, -1.0, 1.0)


func stroke_phase() -> float:
	return _stroke


## The mass afloat (kg): the hull, the crew and what it carries.
func total_kg() -> float:
	return num("mass_kg", 100.0) + crew_on * CREW_KG + cargo_kg


## The push of the crew's strokes now (N, along the boat): surges through each stroke, its average the crew's full push.
func push_n() -> float:
	if absf(throttle) < 0.01:
		return 0.0
	var p := _stroke / STROKE_DRIVE
	var surge := sin(PI * p) / (2.0 / PI * STROKE_DRIVE) if p < 1.0 else 0.0
	# backing water is weaker than pulling ahead
	return throttle * (1.0 if throttle > 0.0 else 0.55) * float(crew_on) * num("stroke_n", 100.0) * surge


## The push that holds it at max_mps with all its seats stroking: the water's drag on it goes as the speed squared.
func drag_coef() -> float:
	var mx := maxf(num("max_mps", 2.0), 0.1)
	return float(int(spec.get("crew", 1))) * num("stroke_n", 100.0) / (mx * mx)


func _physics_process(delta: float) -> void:
	step(delta)


func step(dt: float) -> void:
	if dt <= 0.0 or spec.is_empty():
		return
	_t += dt
	if absf(throttle) > 0.01:
		_stroke = fposmod(_stroke + dt / maxf(num("stroke_s", 2.0), 0.2), 1.0)
	else:
		_stroke = 0.0
	var p := position
	var fwd := forward()
	var side := right()
	var cur := WaterSurface.current_at(p.x, p.z)
	afloat = WaterSurface.surface_at(p.x, p.z) != WaterSurface.NO_WATER
	grounded = _aground()
	var m := total_kg()
	# relative to the water (the ground when there is none)
	var rel := vel - cur if afloat else vel
	var vf := rel.dot(fwd)
	var vs := rel.dot(side)
	# the crew: the push, the water's drag (the more the faster it goes), the scrape of the shallows
	var a := (push_n() - drag_coef() * vf * absf(vf) - num("drag", 0.8) * m * 0.02 * vf) / m
	vf += a * dt
	vf -= vf * clampf(grounded * num("ground_drag", 4.0) * dt, 0.0, 0.95)
	if not afloat:
		vf -= vf * clampf(num("ground_drag", 4.0) * 3.0 * dt, 0.0, 0.95)   # dragged over the bank
	# the keel holds it from slipping sideways
	vs -= vs * clampf(num("side_drag", 8.0) * dt, 0.0, 1.0)
	# turning: the paddles and the way on it; the crew helps, the boat's length hinders (turn_dps is for a full crew)
	var way := clampf(absf(vf) / 1.6, 0.0, 1.0)
	var crew_full := float(maxi(int(spec.get("crew", 1)), 1))
	var want := steer * deg_to_rad(num("turn_dps", 60.0)) * (0.35 + 0.65 * way) * (0.5 + 0.5 * clampf(float(crew_on) / crew_full, 0.0, 1.0))
	if vf < -0.05:
		want = -want   # going astern it turns the other way
	yaw_rate = lerpf(yaw_rate, want, clampf(3.0 * dt, 0.0, 1.0))
	rotation.y += yaw_rate * dt   # forward is +Z and right +X: a growing yaw turns it to the right
	var f2 := forward()
	var s2 := right()
	rel = f2 * vf + s2 * vs
	vel = rel + (cur if afloat else Vector3.ZERO)
	vel.y = 0.0
	var to := p + vel * dt
	# the shore holds it: past the water and the bank's first rise it goes no further
	if afloat and WaterSurface.surface_at(to.x, to.z) == WaterSurface.NO_WATER and FrontierTerrain.height_at(to.x, to.z) > WaterSurface.surface_at(p.x, p.z) + 0.6:
		vel = Vector3.ZERO
		to = p
	position = Vector3(to.x, position.y, to.z)
	_settle()


## How much of the hull is over the shallows (0 afloat all along .. 1 all of it aground): the water's depth under the bow,
## the middle and the stern against the draft.
func _aground() -> float:
	var draft := num("draft", 0.2)
	var half := num("length", 4.0) * 0.5
	var f := forward()
	var g := 0.0
	for k in [-0.8, 0.0, 0.8]:
		var q: Vector3 = position + f * half * k
		var s := WaterSurface.surface_at(q.x, q.z)
		var depth := 0.0 if s == WaterSurface.NO_WATER else maxf(s - FrontierTerrain.height_at(q.x, q.z), 0.0)
		g += clampf(1.0 - depth / maxf(draft, 0.01), 0.0, 1.0) / 3.0
	return g


## Sits it on the water (or the ground) with a little bob and the lean of its turn.
func _settle() -> void:
	var p := position
	var s := WaterSurface.surface_at(p.x, p.z)
	var ground := FrontierTerrain.height_at(p.x, p.z)
	var draft := num("draft", 0.2)
	if s == WaterSurface.NO_WATER:
		_flat_y = ground + draft * 0.4
	else:
		_flat_y = maxf(s - draft * 0.3, ground + draft * 0.4)
	var bob := sin(_t * 1.7) * GRAVITY_BOB * (1.0 - grounded)
	position.y = _flat_y + bob
	var roll := clampf(-yaw_rate * absf(speed()) * 0.05, -0.15, 0.15) + sin(_t * 1.3 + 1.0) * 0.012 * (1.0 - grounded)
	var pitch := sin(_t * 1.1) * 0.01 * (1.0 - grounded)
	var yaw := rotation.y
	rotation = Vector3(pitch, yaw, roll)
