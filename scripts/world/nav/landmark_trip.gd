class_name LandmarkTrip
extends RefCounted
## One walker's trip by the landmarks (NavLandmarks.route made once, walked in order): the point to make for now. The route
## was asked for again every frame before, and as she came up to a gate's side the leg flipped between its near and its far
## side and she turned back and forth there; now a trip's route is kept and its points passed one by one (a point is passed
## within NavLandmarks.AT_M), made again only for a new goal or after REROUTE_S without passing one (pushed far off it).
##   var trip := LandmarkTrip.new()
##   var aim := trip.next(tree, at, to)        # `to` itself once the landmarks are behind her

const REROUTE_S := 8.0

var _pts := PackedVector3Array()
var _i := 0
var _final := Vector3.INF
var _t := 0


func next(tree: SceneTree, at: Vector3, to: Vector3) -> Vector3:
	var now := Time.get_ticks_msec()
	if _final == Vector3.INF or NavLandmarks._flat(_final, to) > 1.0 or (now - _t) > int(REROUTE_S * 1000.0):
		_final = to
		_pts = NavLandmarks.route(tree, at, to)
		_i = 0
		_t = now
	while _i < _pts.size() and NavLandmarks._flat(at, _pts[_i]) <= NavLandmarks.AT_M:
		_i += 1
		_t = now
	return _pts[_i] if _i < _pts.size() else to


func reset() -> void:
	_final = Vector3.INF
	_pts = PackedVector3Array()
	_i = 0
