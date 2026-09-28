class_name TorchState
extends RefCounted
## One torch's fire over its life (push n01b): lit or not, how much burn time is left, how big the fire is now.
## The same state goes with the torch from the pack to the hand, onto the ground (DroppedTorch) and back.
##
##   var s := TorchState.new(TorchState.BURN_S)
##   s.light()
##   s.tick(delta, rain, sheltered, under_water)     # every frame while it exists
##   s.strength()                                     # 0..1: the fire's size (TorchFire, the light)
##
## Burn: BURN_S of real time at full fire (a fat-pine splint torch burns 20-40 minutes; at the game's 48-minute
## day that is 25-50 game minutes, a player's night walk needs longer). It catches over IGNITE_S, burns full,
## over the last GUTTER_FRAC it dies down and sputters, and goes out when the time is up.
## Weather (DayNight's WeatherSystem, in the "weather" group with rain_intensity(pos) -> 0..1; any node of the group
## with that method or a `rain` property counts, rain_at() takes the most): heavy rain (over RAIN_HEAVY) that nothing
## solid overhead keeps off (sheltered(): a roof; the trees' canopies have no colliders) drowns the fire over DROWN_S
## (at RAIN_HEAVY; faster in harder rain) and burns it faster meanwhile; a flame under water (a node in the "water"
## group with is_under_water(pos), or an Area3D in it that holds the point) goes out at once.

const BURN_S := 360.0            ## default burn time, s of real time (6 minutes; user to confirm)
const IGNITE_S := 1.2
const GUTTER_FRAC := 0.12        ## the last 12 % of the burn: the fire dies down
const RAIN_HEAVY := 0.5
const DROWN_S := 20.0            ## s of heavy rain on the flame to put it out
const WEATHER_GROUP := &"weather"
const WATER_GROUP := &"water"

var burn_total := BURN_S
var burn_left := BURN_S
var lit := false
## 0..1: how soaked the head is (rain); the fire drowns at 1.
var wet := 0.0
## Why the fire went out last: "" (never lit / still lit), "burnt", "rain", "water", "snuffed".
var out_reason := ""
var _age := 0.0
var _seed := 0.0


func _init(total := BURN_S) -> void:
	burn_total = maxf(total, 1.0)
	burn_left = burn_total
	_seed = randf() * 100.0


## Lights it (a torch with no burn time left does not light). True when it burns.
func light() -> bool:
	if burn_left <= 0.0:
		return false
	if not lit:
		lit = true
		_age = 0.0
		wet = 0.0
		out_reason = ""
	return true


## Puts it out (a torch put back in the pack, a snuff).
func snuff(reason := "snuffed") -> void:
	if lit:
		lit = false
		out_reason = reason


func burnt_out() -> bool:
	return burn_left <= 0.0


## 0..1 of the burn used.
func used() -> float:
	return 1.0 - clampf(burn_left / burn_total, 0.0, 1.0)


## Advances the fire. rain: 0..1 on it; sheltered: something overhead keeps the rain off; under_water: the
## flame is in water.
func tick(delta: float, rain := 0.0, sheltered := false, under_water := false) -> void:
	if not lit:
		return
	_age += delta
	if under_water:
		burn_left = maxf(burn_left - 1.0, 0.0)
		snuff("water")
		return
	var heavy := rain >= RAIN_HEAVY and not sheltered
	var rate := 1.0 + (1.5 * rain if heavy else 0.0)
	burn_left = maxf(burn_left - delta * rate, 0.0)
	if heavy:
		wet = minf(wet + delta * rain / (DROWN_S * RAIN_HEAVY), 1.0)
	else:
		wet = maxf(wet - delta / (DROWN_S * 2.0), 0.0)
	if burn_left <= 0.0:
		snuff("burnt")
	elif wet >= 1.0:
		snuff("rain")


## The fire's size now, 0..1: the catch, the full fire, the dying down and sputter at the end, less when soaked.
func strength() -> float:
	if not lit:
		return 0.0
	var s := smoothstep(0.0, IGNITE_S, _age) * 0.85 + 0.15
	var left := burn_left / burn_total
	if left < GUTTER_FRAC:
		var g := left / GUTTER_FRAC
		s *= lerpf(0.3, 1.0, g)
		if g < 0.5:
			# sputters: short dips
			var d := sin(_age * 7.3 + _seed) * sin(_age * 3.1 + _seed * 2.0)
			s *= 1.0 - 0.5 * smoothstep(0.55, 0.95, d) * (1.0 - g * 2.0)
	s *= 1.0 - 0.6 * wet
	return clampf(s, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"burn_total": burn_total, "burn_left": burn_left, "lit": lit, "wet": wet}


static func from_dict(d: Dictionary) -> TorchState:
	var s := TorchState.new(float(d.get("burn_total", BURN_S)))
	s.burn_left = float(d.get("burn_left", s.burn_total))
	s.lit = bool(d.get("lit", false))
	s.wet = float(d.get("wet", 0.0))
	return s


## Rain on `pos` (0..1): the most any node of the "weather" group tells (rain_intensity(pos) or a `rain`
## property; DayNight's weather in game); 0 without one.
static func rain_at(tree: SceneTree, pos: Vector3) -> float:
	if tree == null:
		return 0.0
	var most := 0.0
	for n in tree.get_nodes_in_group(WEATHER_GROUP):
		if n.has_method("rain_intensity"):
			most = maxf(most, float(n.call("rain_intensity", pos)))
			continue
		var r: Variant = n.get("rain")
		if r != null:
			most = maxf(most, float(r))
	return clampf(most, 0.0, 1.0)


## Whether `pos` is under water: a node of the "water" group that says so (is_under_water(pos)), or an Area3D
## of the group whose shapes hold the point.
static func under_water(world: World3D, tree: SceneTree, pos: Vector3) -> bool:
	if tree == null:
		return false
	var areas := false
	for n in tree.get_nodes_in_group(WATER_GROUP):
		if n.has_method("is_under_water"):
			if bool(n.call("is_under_water", pos)):
				return true
		elif n is Area3D:
			areas = true
	if not areas or world == null:
		return false
	var q := PhysicsPointQueryParameters3D.new()
	q.position = pos
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in world.direct_space_state.intersect_point(q, 8):
		var c: Object = hit.get("collider")
		if c is Node and (c as Node).is_in_group(WATER_GROUP):
			return true
	return false


## Something solid within `up` m over `pos` keeps the rain off (a roof, a thick trunk or rock overhang).
static func sheltered(world: World3D, pos: Vector3, exclude: Array = [], up := 12.0) -> bool:
	if world == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.UP * up)
	q.exclude = exclude
	return not world.direct_space_state.intersect_ray(q).is_empty()
