class_name TravMoveSelector
extends RefCounted
## Picks the SOURCE clip authored for the obstacle (design 7.1; user decision 2026-09-24 "fix
## source clips only"): every probe result ends in exactly one move (a TravMovePlan whose warped
## path fits) or in `none` with a reason code. A move only takes obstacles within h_tol of the
## height its clip was made for (traversal_moves.json authored_h, measured or the clip's name
## height where the jump's rise was not measurable), within its depth limit and from its gait
## (moving / standing); a poor fit is rejected rather than forced.
##
##   var plan := selector.select(info, ctx)
##   ctx: feet, heading, speed, gait (sprint / run / walk / idle), stance (stand / crouch),
##        profile (freerun / careful), trigger (Space pressed or buffered), alt, want_climb
##
## Steps: 0 gate (angle, trigger)  1 intent (OVER / ONTO)  2 landing / exit family  3 depth
##        4 authored height band and gait  5 fit (warp limits + path sweep; next candidate).
## Every clip plays at its own timing (rate 1.0).

var lib: TravMoveLibrary
var probe: TraversalProbe
var last_reason := ""
var last_tried: Array = []
## Standing moves whose band holds the height but were left out because the body moves (see
## TravMovePlan.approach_stop).
var last_standing: Array = []
const CACHE_MAX := 24
var _cache := {}                 ## solved candidate paths while approaching (see _fit); cleared when a move starts


## Forget the cached candidate paths (a move started: its path is now owned and changed by the
## controller; the world may have changed).
func clear_cache() -> void:
	_cache.clear()


func _init(p_lib: TravMoveLibrary = null, p_probe: TraversalProbe = null) -> void:
	lib = p_lib if p_lib else TravMoveLibrary.shared()
	probe = p_probe


func none(why: String) -> TravMovePlan:
	last_reason = why
	var p := TravMovePlan.new()
	p.reason = why
	return p


static func yaw_of(v: Vector3) -> float:
	return atan2(v.x, v.z)


## Heading squared up toward the face (at most `max_deg`, design 8.2 W0b yaw <= 15 deg).
static func squared_yaw(heading: Vector3, normal: Vector3, max_deg := 15.0) -> float:
	var h := Vector3(heading.x, 0, heading.z).normalized()
	var into := -Vector3(normal.x, 0, normal.z).normalized()
	var a := h.signed_angle_to(into, Vector3.UP)
	var lim := deg_to_rad(max_deg)
	var r := h.rotated(Vector3.UP, clampf(a, -lim, lim))
	return yaw_of(r)


func select(info: TravObstacleInfo, ctx: Dictionary) -> TravMovePlan:
	last_tried = []
	if info == null or info.is_none():
		return none(info.reason if info else "no_obstacle")
	match info.kind:
		"wall":
			return _wall(info, ctx)
		"edge":
			return _edge(info, ctx)
		"crawl":
			return _crawl(info, ctx)
		"overhead":
			return _overhead(info, ctx)
	return none("no_obstacle")


func _moving(ctx: Dictionary) -> bool:
	return float(ctx.get("speed", 0.0)) >= float(lib.setting("moving_speed", 1.0))


## Moves of `intent` whose authored band holds h, filtered by gait and stance. Sets
## last_reason = wrong_speed when the height has a move but not for this gait.
func _candidates(intent: String, ctx: Dictionary, h: float, info: TravObstacleInfo) -> Array:
	var moving := _moving(ctx)
	var crouch := str(ctx.get("stance", "stand")) == "crouch"
	var out := []
	var height_hit := false
	last_standing = []
	for id: String in lib.moves:
		var m: Dictionary = lib.moves[id]
		if not bool(m.get("enabled", true)) or str(m.get("intent", "")) != intent or not m.has("band"):
			continue
		var band: Array = m.band
		if h < float(band[0]) or h > float(band[1]):
			continue
		if intent == "over" and info.depth > float(m.get("depth_max", 1.4)):
			continue
		height_hit = true
		var gait := str(m.get("gait", "any"))
		if gait == "moving" and not moving:
			continue
		if gait == "standing" and moving:
			last_standing.append(id)
			continue
		var stance := str(m.get("stance", "any"))
		if stance == "crouch" and not crouch:
			continue
		out.append(id)
	if out.is_empty() and height_hit:
		last_reason = "wrong_speed"
	out.sort_custom(func(a, b): return int(lib.moves[a].get("priority", 0)) > int(lib.moves[b].get("priority", 0)))
	return out


func _fit(ids: Array, info: TravObstacleInfo, ctx: Dictionary, geo_extra := {}) -> TravMovePlan:
	var why := last_reason if last_reason != "" else "no_move_for_height"
	for id: String in ids:
		var m: Dictionary = lib.moves[id]
		var feet: Vector3 = ctx.get("feet", Vector3.ZERO)
		var heading: Vector3 = ctx.get("heading", Vector3.FORWARD)
		var yaw := squared_yaw(heading, info.normal) if info.normal != Vector3.ZERO else yaw_of(heading)
		# The move starts at S, not where the feet are now: on a slope the ground at S differs
		# from the ground under the feet by up to 0.3 m at the sprint lookahead, which read as
		# warp_limit until the body was ~1 m from the face (too late to slow down: a sprint vault
		# entered at 4.9 m/s instead of 2.4). Planned from the ground at the face's foot, then
		# from the ground at the solved S (review 2026-09-24).
		var sup_y := info.base_y if info.h_face >= 0.0 else info.support_y
		var geo := {"start": feet, "yaw": yaw, "solve_start": true, "support_y": sup_y,
				"top_y": info.support_y + info.h, "face_point": info.face_point, "face_normal": info.normal,
				"depth": info.depth}
		if info.landing_y != null and str(m.get("intent", "")) == "over" and info.landing != null \
				and float(info.landing) >= float(lib.setting("level_exit_min", -1.0)):
			geo["landing_y"] = info.landing_y
		geo.merge(geo_extra, true)
		# Cost (optimization check 2026-09-24): the free-run probes every physics tick while an
		# obstacle is ahead, and a warp solve costs 1.5-6 ms. With solve_start the path depends
		# on the obstacle and the (squared) heading, not on how far away the character is, so the
		# solve and its sweep are cached per obstacle / move / heading degree until a move starts.
		# (plus the feet's position along the face in 2 cm steps: a heading squared up by a few
		# degrees moves the solved start sideways with the feet.)
		var lat := int(round(feet.dot(Vector3.UP.cross(info.normal).normalized()) / 0.02)) if info.normal != Vector3.ZERO else 0
		var key := "%s|%.2f,%.2f,%.2f|%.2f,%.2f|%.3f|%.3f|%.2f|%s|%d|%d|%s" % [id, info.face_point.x, info.face_point.y, info.face_point.z,
				info.normal.x, info.normal.z, sup_y, float(info.support_y + info.h), minf(float(info.depth), 99.0), str(geo.get("landing_y")),
				int(round(rad_to_deg(yaw))), lat, str(geo_extra) if not geo_extra.is_empty() else ""]
		var hit: Dictionary = _cache.get(key, {})
		var path: TravWarpedPath = hit.get("path") if not hit.is_empty() else TravMotionWarper.solve(id, m, geo)
		if hit.is_empty() and probe != null and path.ok:
			var gs := probe.support_at(Vector3(path.origin.x, sup_y + 0.05, path.origin.z), 0.45, 0.9)
			if bool(gs.get("hit", false)) and absf(float(gs.y) - sup_y) > 0.02 and absf(float(gs.y) - sup_y) < 0.5:
				geo["support_y"] = float(gs.y)
				path = TravMotionWarper.solve(id, m, geo)
		if not hit.is_empty():
			geo = hit.get("geo", geo)
		last_tried.append({"move": id, "ok": path.ok, "reason": path.reason, "metrics": path.metrics, "cached": not hit.is_empty()})
		if hit.is_empty():
			if _cache.size() >= CACHE_MAX:
				_cache.clear()
			_cache[key] = {"path": path, "geo": geo}
			hit = _cache[key]
		if not path.ok:
			why = path.reason
			continue
		# A moving entry cannot start behind the character (it would step back): the solved start
		# relative to where the feet are now.
		var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
		var shift := Vector2(path.origin.x - feet.x, path.origin.z - feet.z).dot(Vector2(fwd.x, fwd.z))
		if _moving(ctx) and shift < -0.15:
			why = "too_close"
			last_tried[last_tried.size() - 1]["reason"] = why
			continue
		if probe != null:
			if not hit.has("blocked"):
				hit["blocked"] = probe.validate_path(path, info)
			var blocked: String = hit.blocked
			if blocked != "":
				why = blocked
				last_tried[last_tried.size() - 1]["reason"] = why
				continue
		var plan := TravMovePlan.new()
		plan.move_id = id
		plan.move = m
		plan.path = path
		plan.info = info
		plan.intent = str(m.get("intent", ""))
		plan.exit = str(m.get("exit", ""))
		plan.start = path.origin + Vector3(0, float((m.anchor as Dictionary).get("start_h", 0.0)), 0)
		plan.start.y = float(geo.support_y)
		plan.yaw = yaw
		plan.fade_in = m.get("fade_in", {})
		plan.status = str(m.get("status", "graph"))
		plan.profile = str(ctx.get("profile", "freerun"))
		plan.rate = 1.0
		plan.geo = geo
		plan.created_ms = Time.get_ticks_msec()
		if info.landing != null and plan.intent == "over" and float(info.landing) < float(lib.setting("level_exit_min", -1.0)):
			plan.exit = "fall"
		last_reason = ""
		return plan
	return none(why)


# --------------------------------------------------------------------------------------------------

func _wall(info: TravObstacleInfo, ctx: Dictionary) -> TravMovePlan:
	last_reason = ""
	var profile := str(ctx.get("profile", "freerun"))
	var heading: Vector3 = ctx.get("heading", Vector3.FORWARD)
	var lim := float(lib.setting("approach_angle_deg.%s" % profile, 40.0))
	var ang := rad_to_deg(Vector3(heading.x, 0, heading.z).normalized().angle_to(-info.normal))
	if ang > lim:
		return none("angle")
	# The obstacle's own height (above the foot of its face; review 2026-09-24: slopes).
	var h := info.h_face if info.h_face >= 0.0 else info.h
	if h < 0.35:
		return none("too_low")
	var moving := _moving(ctx)
	# Step assist (design 7.9): low clutter keeps the run going without a clip.
	var sa_over := float(lib.setting("step_assist.over_max", 0.5))
	var sa_onto := float(lib.setting("step_assist.onto_max_moving", 0.55))
	var deep := info.depth == INF or info.depth > 1.4
	# (Walking takes the authored step-on clip, p-walk-jump-up-0-5m; running and sprinting keep
	# their stride with the step assist.)
	var striding := float(ctx.get("speed", 0.0)) >= 2.5
	if striding and ((not deep and h < sa_over) or (deep and h < sa_onto and bool(info.support_area.get("knee", false)))):
		var sp := TravMovePlan.new()
		sp.kind = "step_assist"
		sp.move_id = "step_assist"
		sp.info = info
		sp.intent = "step"
		sp.status = "proposed"
		sp.exit = "run"
		return sp
	if profile == "careful" and not bool(ctx.get("trigger", false)):
		return none("no_trigger")
	# 1. Intent.
	var d_int := str(info.descriptor.get("intent", ""))
	var lmin := float(lib.setting("landing_min.%s" % profile, -4.0))
	var over_ok := info.depth <= 1.4 and info.landing != null and float(info.landing) >= lmin \
			and float(info.landing) <= 0.3 and h <= 1.96
	# ONTO moves end standing on the top: it needs room to stand (not only a knee's depth).
	var onto_ok := bool(info.support_area.get("stand", false)) and info.clearance != "none"
	var over_why := "no_landing" if info.landing == null else ("landing_too_deep" if info.landing != null and float(info.landing) < lmin else "too_high")
	var onto_why := "narrow_top" if not bool(info.support_area.get("stand", false)) else "no_clearance"
	var intent := ""
	if d_int in ["over", "onto"]:
		intent = d_int
	elif over_ok and onto_ok:
		intent = "onto" if (profile == "careful" and (bool(ctx.get("alt", false)) or bool(info.descriptor.get("prefer_onto", false)))) else "over"
	elif over_ok:
		intent = "over"
	elif onto_ok:
		intent = "onto"
	else:
		return none(over_why if info.depth <= 1.4 else onto_why)
	# 3-4. Depth and the authored height band.
	if intent == "over":
		var ids := _candidates("over", ctx, h, info)
		if ids.is_empty() and onto_ok:
			intent = "onto"
		elif ids.is_empty():
			return none(last_reason if last_reason != "" else ("too_deep_to_vault" if info.depth > 0.6 else "no_move_for_height"))
		else:
			var plan := _fit(ids, info, ctx)
			if plan.ok() or not onto_ok:
				return plan
			intent = "onto"
	var ids2 := _candidates("onto", ctx, h, info)
	if ids2.is_empty() and not last_standing.is_empty() and str(info.clearance) == "stand":
		# Only a standing move is authored for this height (the 0.98 m knee mantle) and the body
		# moves: plan it from rest; the approach brings the body to a stop at its start S. It used
		# to be selected only after the body had walked into the face, closer than S, and the move
		# then started with its hands inside the block (a 24 cm palm pop; review 2026-09-24).
		var still := ctx.duplicate()
		still["speed"] = 0.0
		still["gait"] = "idle"
		var sp := _fit(last_standing.duplicate(), info, still)
		if sp.ok():
			sp.approach_stop = true
		return sp
	if ids2.is_empty():
		return none(last_reason if last_reason != "" else "no_move_for_height")
	if str(info.clearance) != "stand":
		return none("no_clearance")
	return _fit(ids2, info, ctx)


## An overhead lip: a platform's edge over open space (the fort's firing step, 2026-09-26: "make the ramp
## climbable and the ledge we stand on"), 2.2-2.5 m over the ground. Space under it jumps up to the lip
## and climbs onto the top with a hang climb (traversal_moves.json overhead_band: the climbs offered on
## these lips, not on walls). The face under the lip is taken as OVERHEAD_FACE_M deep (the boards and the
## rim beam under them); below it the ground runs on under the platform.
const OVERHEAD_FACE_M := 0.35

func _overhead(info: TravObstacleInfo, ctx: Dictionary) -> TravMovePlan:
	last_reason = ""
	if not bool(ctx.get("trigger", false)):
		return none("no_trigger")
	if str(info.clearance) != "stand":
		return none("no_clearance")
	var moving := _moving(ctx)
	var ids := []
	var height_hit := false
	for id: String in lib.moves:
		var m: Dictionary = lib.moves[id]
		if not bool(m.get("enabled", true)) or not m.has("overhead_band"):
			continue
		var band: Array = m.overhead_band
		if info.h < float(band[0]) or info.h > float(band[1]):
			continue
		height_hit = true
		var gait := str(m.get("gait", "any"))
		if (gait == "moving" and not moving) or (gait == "standing" and moving):
			continue
		ids.append(id)
	if ids.is_empty():
		return none("wrong_speed" if height_hit else "no_move_for_height")
	ids.sort_custom(func(a, b): return int(lib.moves[a].get("priority", 0)) > int(lib.moves[b].get("priority", 0)))
	if probe != null:
		var room := probe.room_below(info, OVERHEAD_FACE_M)
		if room != "":
			return none(room)
	var extra := {"box_bottom": info.ledge_point.y - OVERHEAD_FACE_M, "open_below": true}
	# (each move's own top_shift, traversal_moves.json overhead_shift: the climb ends standing on the top)
	var out := none("no_move_for_height")
	for id: String in ids:
		var ex := extra.duplicate()
		if lib.moves[id].has("overhead_shift"):
			ex["top_shift"] = lib.moves[id].overhead_shift
		out = _fit([id], info, ctx, ex)
		if out.ok():
			return out
	return out


## Re-solves a planned move from the trigger position: the path starts exactly at the body (root
## continuity at the entry seam) and the warp absorbs the residual (design 8.2, solve_start false).
func refit(plan: TravMovePlan, feet: Vector3) -> TravMovePlan:
	if plan == null or plan.geo.is_empty():
		return plan
	var geo := plan.geo.duplicate()
	geo["start"] = feet
	geo["solve_start"] = false
	# From the ground the body stands on at the trigger (a slope: a few cm off the planned S).
	if probe != null and geo.has("top_y"):
		var gs := probe.support_at(feet + Vector3.UP * 0.05, 0.4, 0.8)
		if bool(gs.get("hit", false)) and absf(float(gs.y) - float(geo.support_y)) < 0.3:
			geo["support_y"] = float(gs.y)
	var path := TravMotionWarper.solve(plan.move_id, plan.move, geo)
	if not path.ok:
		last_reason = path.reason
		return null
	plan.path = path
	plan.geo = geo
	plan.start = feet
	return plan


## Edges: drops (step off into the fall), the one-foot gap jump and the long jump (design 7.6).
func _edge(info: TravObstacleInfo, ctx: Dictionary) -> TravMovePlan:
	var profile := str(ctx.get("profile", "freerun"))
	var heading: Vector3 = ctx.get("heading", Vector3.FORWARD)
	var feet: Vector3 = ctx.get("feet", Vector3.ZERO)
	var yaw := yaw_of(heading)
	var moving := _moving(ctx)
	var jump := profile == "freerun" or bool(ctx.get("trigger", false))
	if info.gap_distance > 0.0 and info.landing != null and moving and jump:
		var id := ""
		if info.gap_distance <= float(lib.setting("gaps.short_max", 1.5)) and absf(float(info.landing)) <= 0.5:
			id = "gap_jump"
		elif info.gap_distance <= float(lib.move("long_jump").get("gap_max", 4.0)) and float(info.landing) >= -0.8 and float(info.landing) <= 0.3:
			id = "long_jump"
		if id != "" and lib.has(id):
			var m := lib.move(id)
			var geo := {"start": feet, "yaw": yaw, "solve_start": false, "support_y": info.support_y,
					"landing_y": info.landing_y, "landing_point": info.landing_point, "edge_point": info.face_point,
					"gap": info.gap_distance, "ground_clear": false,
					"landing_min_fwd": (info.face_point - feet).dot(Vector3(heading.x, 0, heading.z).normalized()) + info.gap_distance + 0.25}
			var path := TravMotionWarper.solve(id, m, geo)
			if path.ok:
				var plan := TravMovePlan.new()
				plan.move_id = id
				plan.move = m
				plan.path = path
				plan.info = info
				plan.intent = "gap"
				plan.exit = "run"
				plan.start = feet
				plan.yaw = yaw
				plan.geo = geo
				plan.fade_in = m.get("fade_in", {})
				return plan
	var drop := info.drop
	if drop >= float(lib.setting("drops.run_off_max", 1.0)) and drop <= float(lib.setting("drops.step_off_max", 4.0)):
		var mid := ""
		if profile == "freerun" and moving:
			mid = "drop_fall"
		elif bool(ctx.get("trigger", false)) and not moving:
			mid = "drop_hop"
		if mid != "" and lib.has(mid):
			var m2 := lib.move(mid)
			var plan2 := TravMovePlan.new()
			plan2.move_id = mid
			plan2.move = m2
			plan2.info = info
			plan2.intent = "down"
			plan2.exit = "fall"
			plan2.start = feet
			plan2.yaw = yaw
			plan2.fade_in = m2.get("fade_in", {})
			return plan2
	return none("too_high" if drop > 4.0 else "no_landing")


func _crawl(info: TravObstacleInfo, ctx: Dictionary) -> TravMovePlan:
	var plan := TravMovePlan.new()
	plan.kind = "crawl"
	plan.move_id = "crawl_start"
	plan.move = lib.move("crawl_start")
	plan.info = info
	plan.intent = "crawl"
	plan.exit = "crawl"
	plan.start = ctx.get("feet", Vector3.ZERO)
	plan.yaw = yaw_of(ctx.get("heading", Vector3.FORWARD))
	plan.fade_in = plan.move.get("fade_in", {})
	plan.status = "proposed"
	return plan
