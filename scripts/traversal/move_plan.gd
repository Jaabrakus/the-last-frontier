class_name TravMovePlan
extends RefCounted
## A selected traversal move (design 7.1 step 5): the move, its warped path, the obstacle it
## was planned for, and how it starts and ends. Produced by TravMoveSelector, run by
## TraversalController.

var move_id := ""
var move := {}
var path: TravWarpedPath
var info: TravObstacleInfo
var kind := "move"          ## move / step_assist / long_jump / hang / climb / beam / crawl / drop
var intent := ""            ## over / onto / hang / down / gap / climb / beam / crawl
var exit := ""              ## run / idle / fall / hang / climb / beam
var start := Vector3.ZERO   ## start point S (feet)
var yaw := 0.0
var rate := 1.0             ## playback rate (setting A: graph rates; B: free-run rate match)
var rate_w0a := 1.0
var fade_in := {}           ## {key, s, status}
var status := "graph"
var reason := ""
var then := ""              ## a move chained after this one (jump_hang -> hang_climb_up)
var ledge_id := -1
var ledge_s := 0.0
var lane_id := -1
var beam_id := -1
var launch := Vector3.ZERO  ## long jump: the assisted launch velocity
var profile := "freerun"
var geo := {}               ## the warp inputs (re-solved from the trigger position when needed)
var created_ms := 0
## A standing move planned while the body still moves (the only move authored for the obstacle is
## a standing one): the approach brings the body to rest at `start`, then the move is selected
## and started as usual (TraversalController.approach()).
var approach_stop := false


func ok() -> bool:
	return reason == "" and (path == null or path.ok)


func to_dict() -> Dictionary:
	return {"move": move_id, "kind": kind, "intent": intent, "exit": exit, "start": [start.x, start.y, start.z],
			"yaw": yaw, "rate": rate, "fade_in": fade_in, "status": status, "reason": reason, "then": then,
			"path": path.to_dict() if path else {}, "info": info.to_dict() if info else {}}
