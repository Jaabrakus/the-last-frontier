class_name TraversalController
extends Node
## Traversal controller, SOURCE CLIPS ONLY (user decision 2026-09-24 "fix source clips only";
## design 5.2 / 5.3 where it does not conflict). It measures the world (TraversalProbe), picks the
## Actor_B move authored for the obstacle (TravMoveSelector), warps the move's clip chain onto
## the obstacle (TravMotionWarper: the measured hand / foot / knee contacts meet the detected
## surfaces at their contact frames, the warp eased over the clip's own warp windows), owns the
## body while the move plays at the clip's own timing, and hands it back with a refreshed floor
## state. It never drives the animation system: it publishes what should play (anim_state(),
## signals, graph requests) for the rebuilt PlayerAnim / LocoBrain (hooks: graph_analysis/
## traversal/traversal_source_moves.md) or the standalone preview (TravPreviewActor).
##
## Moves (all Actor_B clips): vaults (sprint 4-part chain, standing, tall with the fall exit,
## step-on 0.5 m), jump-ups / climb-ups (knee 0.8 / 1.0 / 1.35 m, chest 2 m, the 3 m jump to hang
## with the hang climb-up), gap jumps (1.5 m one-foot, long jump), drops (step off, standing hop)
## with the landing clip, ladders, balance beams / logs / thick branches, crouch-under, wall
## shimmy on narrow ledges, squeeze-through. No hang navigation or free climbing (no clips).
##
## API (the player hook or the preview driver):
##   setup(body, world := {})   body: CharacterBody3D; world: {registry, ledges, library}
##   request(intent)            {jump: true} (Space, buffered 150 ms)
##   can_traverse(ctx := {})    probe + select for the body's current state (null = none; the
##                              reason in last_none)
##   start(plan) -> bool        begin a move (owns the body)
##   tick(delta) -> Dictionary  advance the current mode; returns anim_state()
##   finish(exit := "")         hand the body back (velocity, floor refresh, design 8.6)
##   cancel(reason := "")       stop (before the commit point: back to locomotion; after: release)
##   pre_step(input, delta)     per-physics-tick input (free-run triggers, ladder / shimmy / beam)
##   owns_body(), is_traversing(), is_supported(), anim_state(), debug_snapshot()
## Signals: traversal_requested, traversal_started, traversal_state_changed, traversal_contact,
## traversal_finished, traversal_cancelled, mode_changed, graph_request.
##
## input (per tick): {move: Vector2 (x right, y = -forward, as Input.get_vector), sprint, walk,
##                    jump (just pressed), crouch (just pressed), crouched (held), yaw}
## Free-run (Shift held): vaults, mantles, climb-ups, gap jumps and drops start on their own at
## the planned start point S and chain. Careful (Shift released): Space triggers them.

signal traversal_requested(plan: TravMovePlan)
signal traversal_started(plan: TravMovePlan)
signal traversal_state_changed(info: Dictionary)
signal traversal_contact(kind: String, limb: String, pos: Vector3, surface: String)
signal traversal_finished(plan: TravMovePlan, exit_kind: String)
signal traversal_cancelled(plan: TravMovePlan, reason: String)
signal mode_changed(old_mode: String, new_mode: String)
signal graph_request(request: String, record: Dictionary)

enum Mode { OFF, MOVE, AIR, CLIMB, BEAM, CRAWL, SIDLE }
const HOP_S := 0.35
const MODE_NAMES := ["OFF", "MOVE", "AIR", "CLIMB", "BEAM", "CRAWL", "SIDLE"]

var body: CharacterBody3D
var lib: TravMoveLibrary
var registry: TravShapeRegistry
var ledges: TravLedgeGraph
var probe: TraversalProbe
var selector: TravMoveSelector
var lane: TravLaneClimb

var mode := Mode.OFF
var plan: TravMovePlan            ## the playing segment (MOVE, BEAM, CRAWL, SIDLE)
var pending: TravMovePlan         ## planned, waiting for the start point S
var t_move := 0.0
## The move clock's rate this tick (TravMomentum: a vault entered faster than its clip plays at one
## uniform rate, at most 1.25; 1 = the clip's own timing).
var rate := 1.0
## Moves with a momentum block keep the body's speed (TravMomentum; user 2026-09-26: "also when we vault the
## char model should not slow down", then "some things are fast somethings are slow it should just be
## normal speed"): one steady tempo, the root warped to carry the body on. false: every clip at its own
## timing and the approach eases the body down to each clip's entry speed, as before
## (tests/traversal/test_traversal_moves.gd measures the source moves that way; with `momentum`, and
## tests/traversal/test_vault_momentum.gd on the player, with it).
var momentum := true
var profile := "freerun"
var last_none := ""
var committed := false
var enabled := true
## The stick ends a climb onto a top once the body stands on it (_input_exit; the player's controller: the preview
## course plays every move to its end).
var input_exit := false
var input_state := {}
var serial := 0                   ## content serial: every segment is a new crossfade key
var timing := {}                  ## usec of the last probe / select / solve (optimisation check)

var _jump_buffer := 0.0
var _part := -1
var _fired := {}
var _yaw := 0.0
var _root := Transform3D.IDENTITY
var _pins: Array = []
var _guards: Array = []
var _state := {}
var _handback_ticks := 0
var _history: Array = []
var _air := {}
var _drop_cooldown := 0.0
## Running off an edge plays no drop move (drop_fall): the body runs off and our own fall (FallPose) steps it off (set by PlayerAnim
## while our fall is on). The standing hop (drop_hop) stays.
var own_run_off := false
var _mount := {}
var _content_key := ""
var _beam := {}                   ## BEAM director {beam, dir, shape}
var _beam_block := {}             ## beam id -> seconds (no re-entry right after leaving it)
var _beam_drop := {}              ## {edge, dir, drop, t}: a balance walk ended at a log / branch end over lower ground
var _crawl := {}
var _sidle := {}
var _last_exit := {}              ## the last hand-back {exit, move, loco_phase}
var _exit_ik := {}                ## IK kept on after a hand-back, fading with the exit fade {pins, guards, t, len}
var _cap_vel := Vector3.ZERO      ## the body's (capsule's) velocity over the last tick: every seam continues it
var _cap_last := Vector3.INF
var _approach := {}               ## see approach()
var _latched := false             ## careful: a move asked for with Space stays wanted on the approach
## An overhead lip's jump starts at most this far (m) before its solved start; pressed earlier, the press waits for the body to get there.
const OVERHEAD_EARLY_M := 0.5
var _leftover_s := 0.0            ## real time of the last move tick past the move's end (see _segment_tick)
const CAP_VEL_MAX := 8.0          ## m/s: clamp of a carried capsule velocity (a teleport is no velocity)
## m/s^2: the approach deceleration the player's ground movement should use (at least; more when
## a move is found late): gentle and early, so a slowdown to a move reads as a natural approach
## (user 2026-09-24: the sprint vault's brake to its 2.4 m/s entry read as a stop).
const APPROACH_DECEL := 3.2
const AIR_TURN_RATE := 6.0        ## 1/s: an airborne body turns its facing toward its travel at this rate
## m/s: a landing this fast (horizontally) takes the running landing (slower: the idle landing, which
## stops the body; tried at 2.0 for a walk off a branch's end, the idle landing slid its stance foot
## 23 cm at 1.6 m/s)
const LAND_RUN_SPEED := 1.5
const LAND_SOFT_SPEED := 3.0      ## m/s: a landing this fast (horizontally) takes the soft landing into a run
const AIR_ROOT_SETTLE_S := 0.4    ## a fall exit's root settles from the move's root onto the body over this


func setup(p_body: CharacterBody3D, world := {}) -> void:
	body = p_body
	lib = world.get("library", TravMoveLibrary.shared())
	registry = world.get("registry", TravShapeRegistry.new())
	ledges = world.get("ledges", TravLedgeGraph.new())
	var ex: Array[RID] = [body.get_rid()]
	probe = TraversalProbe.new(body.get_world_3d().direct_space_state, registry, ledges, lib.settings, ex)
	selector = TravMoveSelector.new(lib, probe)
	lane = TravLaneClimb.new(self)
	_yaw = body.rotation.y + PI


func set_world(p_registry: TravShapeRegistry, p_ledges: TravLedgeGraph) -> void:
	registry = p_registry
	ledges = p_ledges
	if probe:
		probe.registry = registry
		probe.ledges = ledges
	lane = TravLaneClimb.new(self)


func mode_name() -> String:
	return MODE_NAMES[mode]


func owns_body() -> bool:
	if mode == Mode.AIR and _air.has("hop") and float(_air.get("t", 0.0)) <= float(_air.hop.T):
		return true
	return mode in [Mode.MOVE, Mode.CLIMB, Mode.BEAM, Mode.CRAWL, Mode.SIDLE]


func is_traversing() -> bool:
	return mode != Mode.OFF


func is_supported() -> bool:
	if mode in [Mode.CLIMB, Mode.BEAM, Mode.CRAWL, Mode.SIDLE]:
		return true
	if mode == Mode.MOVE and plan and plan.path:
		return plan.exit != "fall" or t_move < plan.path.duration * 0.5
	return body.is_on_floor() if body else false


func body_yaw() -> float:
	return _yaw - PI


func handback_ticks() -> int:
	return _handback_ticks


## The body's (capsule's) velocity over the last tick: the velocity a move carries at its seams.
func capsule_velocity() -> Vector3:
	return _cap_vel


func request(intent: Dictionary) -> void:
	if bool(intent.get("jump", false)):
		_jump_buffer = float(lib.setting("input.space_buffer_s", 0.15))
	for k in intent:
		input_state[k] = intent[k]


func _set_mode(m: int) -> void:
	if m == mode:
		return
	var old: String = MODE_NAMES[mode]
	mode = m
	mode_changed.emit(old, MODE_NAMES[m])


# --------------------------------------------------------------------------------------------------
# Context and planning
# --------------------------------------------------------------------------------------------------

func _heading(input: Dictionary) -> Vector3:
	var v := Vector3(body.velocity.x, 0, body.velocity.z)
	if v.length() > 1.0:
		return v.normalized()
	var mv: Vector2 = input.get("move", Vector2.ZERO)
	var yaw := float(input.get("yaw", body.rotation.y))
	var wish := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
	if wish.length() > 0.1:
		return wish.normalized()
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD


func context(input := {}) -> Dictionary:
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	var sprint := bool(input.get("sprint", false))
	var gait := "idle"
	if speed >= 4.6 or (sprint and speed > 2.0):
		gait = "sprint"
	elif speed >= 2.055:
		gait = "run"
	elif speed >= 0.35:
		gait = "walk"
	var mv: Vector2 = input.get("move", Vector2.ZERO)
	return {"feet": body.global_position, "heading": _heading(input), "speed": speed, "gait": gait,
			"stance": "crouch" if bool(input.get("crouched", false)) else "stand",
			"profile": "freerun" if sprint else "careful", "trigger": _jump_buffer > 0.0 or _latched,
			"alt": bool(input.get("walk", false)), "want_climb": mv.y < -0.3 or sprint}


## Probe and select for the body's current state; the earliest start point wins.
func can_traverse(ctx := {}) -> TravMovePlan:
	if ctx.is_empty():
		ctx = context(input_state)
	var t0 := Time.get_ticks_usec()
	var feet: Vector3 = ctx.feet
	var heading: Vector3 = ctx.heading
	var speed := float(ctx.speed)
	var careful := str(ctx.profile) != "freerun"
	var best: TravMovePlan = null
	var why := ""
	var ahead := probe.probe_ahead(feet, heading, speed, careful)
	var t1 := Time.get_ticks_usec()
	var p1 := selector.select(ahead, ctx) if not ahead.is_none() else null
	var t2 := Time.get_ticks_usec()
	timing = {"probe_usec": t1 - t0, "select_usec": t2 - t1}
	if p1 != null and p1.ok() and p1.kind != "step_assist":
		best = p1
	elif p1 != null:
		why = p1.reason
	if ahead.is_none():
		why = ahead.reason
	var mp := _lane_plan(ctx)
	if mp != null and (best == null or feet.distance_to(mp.start) < feet.distance_to(best.start)):
		best = mp
	if best == null and p1 != null and p1.kind == "step_assist":
		best = p1
	# A lip overhead (a platform's edge over open ground: the fort's firing step), on Space only.
	if best == null and bool(ctx.get("trigger", false)):
		var over := probe.probe_overhead(feet, heading, speed, careful)
		if not over.is_none():
			var p4 := selector.select(over, ctx)
			if p4.ok():
				best = p4
			elif why == "" or why == "no_obstacle":
				why = p4.reason
	if best == null:
		var edge := probe.probe_edge(feet, heading, speed)
		if not edge.is_none():
			var p3 := selector.select(edge, ctx)
			if p3.ok():
				best = p3
			elif why == "" or why == "no_obstacle":
				why = p3.reason
	if best == null:
		var low := probe.probe_ceiling(feet, heading)
		if low.kind == "crawl":
			best = selector.select(low, ctx)
	last_none = "" if best else (why if why != "" else "no_obstacle")
	timing["total_usec"] = Time.get_ticks_usec() - t0
	return best


const LANE_SIDE_M := 0.3            ## a ladder is mounted from at most this far beside its rails

## A ladder ahead (design 7.8): mounted when the heading is within 25 deg of the ladder and the
## stick is held into it (0.15 s free-run, 0.2 s careful) or Space.
func _lane_plan(ctx: Dictionary) -> TravMovePlan:
	var feet: Vector3 = ctx.feet
	var heading: Vector3 = ctx.heading
	heading.y = 0.0
	if heading.length() < 1e-3:
		return null
	heading = heading.normalized()
	var best_id := -1
	var best_d := INF
	for id: int in ledges.lanes:
		var ln: Dictionary = ledges.lanes[id]
		if TravLaneClimb.kind_of(ln) != "ladder":
			continue
		var b: Vector3 = ln.bottom
		if absf(b.y - feet.y) > 1.2:
			continue
		var nn := TravLaneClimb.lane_normal(ln, feet)
		var to := Vector3(b.x - feet.x, 0, b.z - feet.z)
		var d := to.length() - TravLaneClimb.standoff(ln)
		if d > 1.6 or d < -0.2:
			continue
		# (In front of the ladder: Space 1.5 m beside the fort's walkway ladder mounted it, the mount sliding the
		# body sideways onto it, 2026-09-26.)
		if absf(to.dot(Vector3.UP.cross(nn).normalized())) > float(ln.get("width", 0.5)) * 0.5 + LANE_SIDE_M:
			continue
		if rad_to_deg(heading.angle_to(-nn)) > float(lib.setting("input.mount_angle_deg", 25.0)) + 5.0:
			continue
		if d < best_d:
			best_d = d
			best_id = id
	if best_id < 0:
		return null
	var g := lane.mount_geometry(ledges.lanes[best_id], feet)
	var m := lib.move("ladder_mount_bottom")
	var p := TravMovePlan.new()
	p.kind = "mount"
	p.move_id = "ladder_mount_bottom"
	p.move = m
	p.intent = "climb"
	p.exit = "climb"
	p.lane_id = best_id
	p.yaw = float(g.yaw)
	p.start = g.start
	p.fade_in = m.get("fade_in", {})
	p.status = "graph"
	p.geo = {"start": g.start, "yaw": g.yaw, "solve_start": false, "support_y": g.ground, "end_root": g.end_root,
			"ground_clear": true}
	p.path = TravMotionWarper.solve("ladder_mount_bottom", m, p.geo)
	p.ledge_s = float(g.rise)
	p.geo["lane_normal"] = g.normal
	_mount_rungs(p)
	return p


## The mount steps onto the first rungs (its landing feet): planted on the rung under the sole,
## and the rungs are guards, as on the lane (contact pass 2026-09-25: the mount ended with the
## right foot 1.4 cm inside the first rung, and the hub's guard threw it out in one frame).
func _mount_rungs(p: TravMovePlan) -> void:
	if not ledges.lanes.has(p.lane_id) or p.path == null:
		return
	var ln: Dictionary = ledges.lanes[p.lane_id]
	var nn: Vector3 = p.geo.get("lane_normal", TravLaneClimb.lane_normal(ln, p.start))
	var rungs := {}
	for pin: Dictionary in p.path.pins:
		if not str(pin.limb).ends_with("foot") or not str(pin.surface) in ["landing", "rung"]:
			continue
		var y := p.path.point_at(str(pin.limb), (float(pin.t_on) + float(pin.t_off)) * 0.5).y + TravLaneClimb.HUB_FOOT_REST
		var rung := TravLaneClimb.rung_of(ln, nn, float(p.geo.get("support_y", 0.0)), y)
		if absf(float((rung.a as Vector3).y) + float(rung.r) - y) > 0.05:
			continue
		pin["shape"] = rung
		pin["surface"] = "rung"
		rungs[str(rung.name)] = rung
	# (Surfaces and guards through the plan's geometry: _resolve_surfaces rebuilds both at the start.)
	var ex: Dictionary = (p.geo.get("extra_surfaces", {}) as Dictionary).duplicate()
	for k: String in rungs:
		ex[k] = rungs[k]
	if not ex.is_empty():
		p.geo["extra_surfaces"] = ex


# --------------------------------------------------------------------------------------------------
# Per-tick entry points
# --------------------------------------------------------------------------------------------------

func pre_step(input: Dictionary, delta: float) -> void:
	if not enabled or body == null:
		return
	input_state = input
	if bool(input.get("jump", false)):
		_jump_buffer = float(lib.setting("input.space_buffer_s", 0.15))
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if _handback_ticks > 0:
		_handback_ticks -= 1
	_drop_cooldown = maxf(0.0, _drop_cooldown - delta)
	for k in _beam_block.keys():
		_beam_block[k] = float(_beam_block[k]) - delta
		if float(_beam_block[k]) <= 0.0:
			_beam_block.erase(k)
	profile = "freerun" if bool(input.get("sprint", false)) else "careful"
	match mode:
		Mode.OFF:
			_off_step(input, delta)
		Mode.MOVE:
			_input_exit(input)
		Mode.CLIMB:
			match lane.input(input, _jump_buffer > 0.0):
				"let_go":
					_jump_buffer = 0.0
					let_go()
				"top":
					_lane_top()
				"bottom":
					_lane_bottom()


func physics_step(delta: float) -> Dictionary:
	return tick(delta)


## A climb onto a top ends on the stick once the body stands on it (user 2026-09-26: "as long as you dont lock
## movement when climb up something"): from the path's up_t (both feet on the top for the rest of the move) the
## move hands back at this tick (TravWarpedPath.end_t) and the locomotion takes the stick; its standing feet are
## held through the exit fade as at any exit.
func _input_exit(input: Dictionary) -> void:
	if not input_exit or plan == null or plan.path == null or not (plan.exit in ["run", "idle"]) \
			or not (plan.intent == "onto" or plan.move_id == "ladder_dismount_top"):
		return
	var mv: Vector2 = input.get("move", Vector2.ZERO)
	if mv.length() < 0.3 or plan.path.up_t < 0.0 or t_move < plan.path.up_t:
		return
	if t_move >= plan.path.end_time() - 0.05:
		return
	plan.path.end_t = t_move


func _off_step(input: Dictionary, delta: float) -> void:
	_approach = {}
	var mv: Vector2 = input.get("move", Vector2.ZERO)
	if mv.length() < 0.2 and _jump_buffer <= 0.0:
		pending = null
		_mount = {}
		_latched = false
		return
	var ctx := context(input)
	if not _beam_drop.is_empty() and _beam_drop_step(ctx, delta):
		return
	if _try_sidle(ctx) or _try_squeeze(ctx):
		return
	var speed := float(ctx.speed)
	var p := can_traverse(ctx)
	if p == null or p.kind == "step_assist":
		pending = null
		_mount = {}
		_latched = false
		_approach = _scan_entries(ctx)
		return
	# Careful: a move planned with Space stays wanted while the body walks up to it.
	if profile == "careful" and _jump_buffer > 0.0:
		_latched = true
	if p.approach_stop:
		# A standing move ahead of a moving body: come to rest at S (approach()); the move is
		# selected and started from rest.
		if pending == null or pending.move_id != p.move_id:
			traversal_requested.emit(p)
		pending = p
		_approach = _approach_of(p, ctx)
		return
	if p.move_id == "drop_fall" and own_run_off:
		return
	if p.move_id in ["drop_fall", "drop_hop"]:
		var edge_d := (p.info.face_point - (ctx.feet as Vector3)).dot(ctx.heading) if p.info else 0.0
		if (edge_d <= speed * delta * 2.0 + 0.08 or p.move_id == "drop_hop") and _drop_cooldown <= 0.0:
			_jump_buffer = 0.0
			traversal_requested.emit(p)
			_start_air_clip(p)
		return
	if p.kind == "mount":
		if _mount.get("lane", -1) != p.lane_id:
			_mount = {"lane": p.lane_id, "t": 0.0}
		_mount.t = float(_mount.t) + delta
		var hold := float(lib.setting("input.mount_hold_s" if profile == "freerun" else "input.mount_hold_careful_s", 0.15))
		if float(_mount.t) < hold and _jump_buffer <= 0.0:
			return
	if pending == null or pending.move_id != p.move_id:
		traversal_requested.emit(p)
	pending = p
	_approach = _approach_of(p, ctx)
	var to_s := Vector3(p.start.x - ctx.feet.x, 0, p.start.z - ctx.feet.z)
	var h: Vector3 = ctx.heading
	var along := to_s.dot(h)
	var reach := maxf(speed * delta, 0.02)
	# A move with momentum starts `lead` before S (TravMomentum.prepare): by its first pose's pelvis offset (the
	# pelvis is where the body is, so the entry's root and pose offsets cancel) and, entered faster than its
	# clip, by the extra ground the body covers before the hands reach the top.
	var prep := TravMomentum.prepare(p.move_id, p.move, speed) if momentum else {}
	var lead := float(prep.get("trigger", 0.0))
	var fwd_m := Basis(Vector3.UP, p.yaw) * Vector3(0, 0, 1)
	var face_d := INF
	if p.info and p.info.kind == "wall":
		face_d = ((p.info.face_point - (ctx.feet as Vector3)) * Vector3(1, 0, 1)).dot(-p.info.normal)
	var blocked := face_d <= 0.3 + 0.05 + reach and along > reach
	if p.kind == "mount":
		blocked = body.is_on_wall() or to_s.length() <= 0.12
	# (A jump up to an overhead lip starts on the Space press, from where the body is: the lip is 0.3-0.8 m
	# ahead and the jump's flight carries the difference.)
	var overhead := p.info != null and p.info.kind == "overhead"
	# (Seen from further than OVERHEAD_EARLY_M before S, the Space press is held (_latched) and the jump starts when the body
	# reaches S; started where it was pressed, the flight carried the difference: a leap from metres away, user 2026-09-30 "the
	# user flies into the leap from far away".)
	if overhead and along > reach + lead + OVERHEAD_EARLY_M and not blocked:
		_latched = true
		return
	if p.kind == "crawl" or p.intent == "gap" or overhead or along <= reach + lead or speed < 0.3 or blocked:
		if profile == "careful" and _jump_buffer <= 0.0 and p.kind not in ["crawl", "mount"]:
			return
		if p.kind == "mount":
			p = _refit_mount(p, ctx.feet)
		elif p.kind != "crawl" and p.intent != "gap":
			var past_s := along - lead < -0.03
			if past_s and speed < float(lib.setting("moving_speed", 1.0)):
				# Standing closer than S (walked up to the face, then Space): keep the planned path
				# from S; the body and the rendered root ease back to it over the entry fade,
				# instead of starting the clip with its hands inside the obstacle.
				pass
			else:
				# Start exactly where the body is: the root is continuous at the entry seam and the
				# warp absorbs the residual (at most v * dt when triggered at S).
				var t0 := Time.get_ticks_usec()
				# (A move with momentum: solved from its pelvis lead ahead of the feet; entered faster than
				# its clip, as it plays (TravMomentum.prepare: its move started later into the clip when a
				# standing foot would hold the body back, the forward path in the solve's geo). Dropped for
				# the move as authored when that path is blocked or lands off the landing's ground.)
				var from: Vector3 = ctx.feet + fwd_m * float(prep.get("lead", 0.0))
				var planned := p
				var authored := p.move
				p.geo.erase("momentum")
				if bool(prep.get("active", false)):
					p.move = prep.move
					p.geo["momentum"] = {"u": float(prep.u), "u0": float(prep.get("u0", prep.u)), "rate": float(prep.rate),
							"trim": int(prep.trim), "pre": float(prep.pre)}
				p = selector.refit(planned, from)
				if planned.geo.has("momentum") and (p == null or not _momentum_ok(p)):
					planned.geo.erase("momentum")
					planned.move = authored
					p = selector.refit(planned, ctx.feet + fwd_m * TravMomentum.pelvis_lead(authored, speed))
				timing["solve_usec"] = Time.get_ticks_usec() - t0
				if p == null:
					last_none = selector.last_reason
					return
		_jump_buffer = 0.0
		start(p)


## Where the next move will start and how fast the body should arrive there (the player's ground
## movement eases its speed onto this, as preview_runner.gd does): {point, dist, speed, yaw, move}
## or {} (nothing ahead). It covers every entry (review 2026-09-24: only planned MOVE plans were
## speed matched; beam, crawl and ladder entries jumped 1.9-3.5 m/s): planned moves (vaults,
## climb-ups, jumps, ladder mounts; standing moves the body comes to rest for) and the entries
## that are not planned moves: a beam's end, a crouch-under roof, a squeeze gap and a narrow
## ledge ahead. `speed` is the clip's own entry speed (traversal_runtime.json entry_speed; every
## clip plays at rate 1), 0 for a standing move.
func approach() -> Dictionary:
	return _approach


func _approach_of(p: TravMovePlan, ctx: Dictionary) -> Dictionary:
	var feet: Vector3 = ctx.feet
	var h: Vector3 = ctx.heading
	var to_s := Vector3(p.start.x - feet.x, 0, p.start.z - feet.z)
	# (A move with momentum takes the body's speed up to its fastest entry, TravMomentum.)
	var sp := 0.0 if p.approach_stop else (TravMomentum.max_entry_speed(p.move) if momentum else float(p.move.get("entry_speed", 0.0)))
	return {"point": p.start, "dist": maxf(0.0, to_s.dot(h)), "speed": sp, "yaw": p.yaw, "move": p.move_id, "kind": p.kind}


## A momentum path (TravMomentum) is kept only when the path's torso sweep is clear and its landing stands
## on the landing's ground (within 8 cm of its height).
func _momentum_ok(p: TravMovePlan) -> bool:
	if p.path == null or not p.path.ok:
		return false
	if probe.validate_path(p.path, p.info) != "":
		return false
	if p.geo.get("landing_y") != null:
		var lp := p.path.point_at("pelvis", p.path.end_time())
		var g := probe.support_at(Vector3(lp.x, float(p.geo.landing_y) + 0.3, lp.z), 0.2, 1.0)
		if not bool(g.get("hit", false)) or absf(float(g.y) - float(p.geo.landing_y)) > 0.08:
			return false
	return true


func _entry_approach(point: Vector3, feet: Vector3, h: Vector3, move_id: String, yaw: float) -> Dictionary:
	var d := Vector3(point.x - feet.x, 0, point.z - feet.z)
	var m := lib.move(move_id)
	# (A clip that starts from standing, traversal_moves.json entry_rest: the body comes to rest.)
	var sp := 0.0 if bool(m.get("entry_rest", false)) else float(m.get("entry_speed", 0.0))
	return {"point": point, "dist": maxf(0.0, d.dot(h)), "speed": sp, "yaw": yaw, "move": move_id, "kind": "entry"}


## Where a beam's enter starts from one of its ends (cached; the geometry is static): the first
## point along the beam, from BEAM_ENTRY_MIN_M in, where the enter's foot plants are supported
## (_plants_supported: on a log the enter's trailing foot needs the log under it, 0.4-0.5 m in).
const BEAM_ENTRY_MIN_M := 0.15
var _beam_entry := {}

func _beam_entry_point(id: int, p0: Vector3, p1: Vector3) -> Variant:
	var key := "%d|%s" % [id, str(p0.snapped(Vector3.ONE * 0.01))]
	if _beam_entry.has(key):
		return _beam_entry[key]
	var dir := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
	var L := dir.length()
	var found: Variant = null
	if L > 0.3:
		dir /= L
		var yaw := TravMoveSelector.yaw_of(dir)
		var s := BEAM_ENTRY_MIN_M
		while s < minf(1.2, L * 0.5):
			var q := p0.lerp(p1, s / L)
			if _plants_supported("beam_enter", q, yaw):
				# (A little past the first supported point: the approach stops the body there.)
				found = p0.lerp(p1, minf(s + 0.05, L * 0.5) / L)
				break
			s += 0.05
	_beam_entry[key] = found
	return found


## Entries ahead that start by position rather than as planned moves (see approach()), within
## the distance the body needs to slow down to them.
func _scan_entries(ctx: Dictionary) -> Dictionary:
	var feet: Vector3 = ctx.feet
	var h: Vector3 = ctx.heading
	h.y = 0.0
	var speed := float(ctx.speed)
	if h.length() < 1e-3 or speed < 0.3:
		return {}
	h = h.normalized()
	var reach := speed * speed / (2.0 * APPROACH_DECEL) + 1.0
	var best := {}
	var consider := func(a: Dictionary) -> void:
		var d := Vector3((a.point as Vector3).x - feet.x, 0, (a.point as Vector3).z - feet.z)
		var along := d.dot(h)
		if along < -0.05 or along > reach or absf(d.cross(h).y) > 0.6:
			return
		if best.is_empty() or float(a.dist) < float(best.dist):
			best.merge(a, true)
	# Beams (the end the body walks onto, at walking height of the feet).
	for id: int in ledges.beams:
		if _beam_block.has(id):
			continue
		var bm: Dictionary = ledges.beams[id]
		for e: Array in [[bm.a, bm.b], [bm.b, bm.a]]:
			var p0: Vector3 = e[0]
			var p1: Vector3 = e[1]
			var dir := Vector3(p1.x - p0.x, 0, p1.z - p0.z).normalized()
			if absf(p0.y - feet.y) > 0.6 or dir.dot(h) < cos(deg_to_rad(25.0)):
				continue
			var ep: Variant = _beam_entry_point(id, p0, p1)
			if ep == null:
				continue
			var ea := _entry_approach(ep as Vector3, feet, h, "beam_enter", TravMoveSelector.yaw_of(dir))
			ea["beam"] = id
			consider.call(ea)
	# Squeeze gaps and narrow ledges.
	for id: int in ledges.volumes:
		var v: Dictionary = ledges.volumes[id]
		if str(v.kind) != "squeeze" or not lib.has("squeeze"):
			continue
		var ax: Vector3 = v.axis
		if ax.dot(h) < 0.8:
			continue
		var entry: Vector3 = v.get("entry", (v.center as Vector3) - ax * ((v.size as Vector3).z * 0.5))
		consider.call(_entry_approach(Vector3(entry.x, feet.y, entry.z), feet, h, "squeeze", float(v.get("clip_yaw", TravMoveSelector.yaw_of(ax)))))
	if lib.has("shimmy_enter"):
		for c: Dictionary in ledges.query_near(feet + h * minf(reach, 2.0) * 0.5, minf(reach, 2.0) * 0.5 + 0.6):
			var lg := ledges.ledge(int(c.ledge_id))
			if str(lg.get("kind", "")) != "narrow":
				continue
			var n: Vector3 = lg.normal
			var pts: PackedVector3Array = lg.points
			if h.dot(-n) < cos(deg_to_rad(35.0)) or absf(pts[0].y - feet.y) > 0.25:
				continue
			consider.call(_entry_approach(pts[0] + n * 0.05, feet, h, "shimmy_enter", TravMoveSelector.yaw_of(-n)))
	# A crouch-under roof: the crawl starts 0.7 m before the roof's edge (probe_ceiling).
	if lib.has("crawl_start"):
		var sup := probe.support_at(feet)
		var lo := float(lib.setting("clearance.crouch_under_min", 1.07))
		var hi := float(lib.setting("clearance.crouch_under_max", 1.4))
		var d := 0.8
		while d <= reach + 0.7:
			var q := feet + h * d
			var up := probe.ray(Vector3(q.x, float(sup.y) + 0.2, q.z), Vector3(q.x, float(sup.y) + 2.0, q.z))
			if not up.is_empty():
				var ch: float = (up.position as Vector3).y - float(sup.y)
				if ch >= lo and ch <= hi:
					consider.call(_entry_approach(feet + h * (d - 0.7), feet, h, "crawl_start", TravMoveSelector.yaw_of(h)))
				break
			d += 0.25
	return best


func _refit_mount(p: TravMovePlan, feet: Vector3) -> TravMovePlan:
	var geo := p.geo.duplicate()
	geo["start"] = Vector3(feet.x, float(geo.support_y), feet.z)
	p.geo = geo
	p.path = TravMotionWarper.solve(p.move_id, p.move, geo)
	p.start = geo.start
	_mount_rungs(p)
	return p


func start(p: TravMovePlan) -> bool:
	if p == null or not p.ok():
		return false
	pending = null
	_latched = false
	_approach = {}
	selector.clear_cache()
	_mount = {}
	if p.kind == "crawl":
		return _crawl_begin(p)
	if p.path == null:
		return false
	return _begin_segment(p, Mode.MOVE)


## Starts a path segment: surfaces for the IK, the capsule ease from where the body is.
func _begin_segment(p: TravMovePlan, m: int, carry_velocity := true, carry_horizontal := false) -> bool:
	plan = p
	t_move = 0.0
	_part = -1
	_fired.clear()
	committed = false
	_yaw = p.yaw
	serial += 1
	_resolve_surfaces(p)
	if mode == m and m in [Mode.BEAM, Mode.CRAWL, Mode.SIDLE]:
		# The next segment of a chain: continue from the rendered root (the loops drift a few cm
		# off the line / support; the difference eases out instead of popping).
		var off := _root.origin - p.path.root_at(0.0)
		if off.length() < 0.25:
			p.path.root_offset0 = off
	# The capsule continues where the body was AND how it moved (the loco velocity, or the last
	# segment's capsule velocity); position and velocity differences are inertialized onto the path.
	# A move entered faster than its clip plays at its one rate (TravMomentum); the carried velocity is
	# converted to move time (the path's velocities are per second of the move's clock).
	rate = 1.0
	if momentum and m == Mode.MOVE and carry_velocity and p.geo.has("momentum"):
		var fwd := Basis(Vector3.UP, p.yaw) * Vector3(0, 0, 1)
		rate = TravMomentum.apply(p, maxf(0.0, Vector3(_cap_vel.x, 0.0, _cap_vel.z).dot(fwd)))
	p.path.capsule_offset0 = body.global_position - p.path.capsule_at(0.0)
	p.path.capsule_vel0 = TravInertializer._clampv(_cap_vel, CAP_VEL_MAX) / rate - p.path.capsule_velocity_at(0.0) if carry_velocity else Vector3.ZERO
	if not carry_velocity and carry_horizontal:
		var dvh := _cap_vel - p.path.capsule_velocity_at(0.0)
		p.path.capsule_vel0 = TravInertializer._clampv(Vector3(dvh.x, 0.0, dvh.z), CAP_VEL_MAX)
	p.path.ease_s = clampf(float(p.path.windows.get("first_support", 0.3) if p.path.windows.get("first_support") != null else 0.3), 0.2, 0.4)
	# (On a faster clock the capsule's entry ease keeps its real-time length: compressed into the first
	# 0.07 s, the path's own offset from the body, 14 cm at the sprint vault, made the capsule jerk.)
	p.path.ease_s *= rate
	body.velocity = Vector3.ZERO
	_set_mode(m)
	_trace(str(p.fade_in.get("key", "trav_enter")), str(p.fade_in.get("status", "proposed")), float(p.fade_in.get("s", 0.1)), "")
	traversal_started.emit(p)
	_update_segment()
	return true


## The IK surfaces of a planned move: the support under the start, the obstacle's collision
## shape (top), the landing under the landing point; guards = all of them.
func _resolve_surfaces(p: TravMovePlan) -> void:
	var path := p.path
	var s := {}
	var start: Vector3 = p.geo.get("start", body.global_position)
	var sup := probe.support_at(start + Vector3.UP * 0.05, 0.4, 3.0)
	s["support"] = _shape_or_plane(sup, float(p.geo.get("support_y", sup.y)), "support")
	if p.geo.has("support_shape"):
		s["support"] = p.geo.support_shape
	if p.info and p.info.shape_node and p.geo.get("top_y") != null:
		var ts: Variant = TravSurfaces.from_shape(p.info.shape_node)
		s["top"] = ts if ts != null else TravSurfaces.plane(float(p.geo.top_y), "top")
	elif p.geo.get("top_y") != null:
		s["top"] = TravSurfaces.plane(float(p.geo.top_y), "top")
	if p.geo.get("landing_y") != null:
		var lp: Vector3 = p.geo.get("landing_point", path.point_at("pelvis", path.duration))
		var ls := probe.support_at(Vector3(lp.x, float(p.geo.landing_y) + 0.3, lp.z), 0.2, 1.0)
		s["landing"] = _shape_or_plane(ls, float(p.geo.landing_y), "landing")
	# Extra surfaces a segment brings with it (the sidle wall): kept as surfaces and guards. They
	# used to be added before this call and were dropped by it, so nothing kept the shimmy's feet
	# and hands out of the wall (6-25 cm inside it; review 2026-09-24).
	for k: String in p.geo.get("extra_surfaces", {}):
		s[k] = p.geo.extra_surfaces[k]
	# Each support / landing foot plant on the surface under its own planned contact, when the
	# move's generic one is not there: the beam enter's first foot is still on the ground or the
	# platform, the exit's last one already on it (they were pinned to the beam and skipped by the
	# IK: 2-23 cm off, 2 cm into the platform; review 2026-09-24). Only a surface within 0.15 m of
	# the planned contact's height is taken.
	for pin: Dictionary in path.pins:
		if pin.has("shape") or not str(pin.surface) in ["support", "landing"] or not str(pin.limb).ends_with("foot"):
			continue
		var gen: Dictionary = s.get(str(pin.surface), {})
		if not gen.is_empty() and str(gen.type) == "plane":
			continue
		var q := path.point_at(str(pin.limb), 0.5 * (float(pin.t_on) + float(pin.t_off)))
		if not gen.is_empty() and int(TravSurfaces.top_gap(gen, PackedVector3Array([q])).over) > 0:
			continue
		var ph := probe.support_at(q + Vector3.UP * 0.05, 0.3, 0.35)
		if bool(ph.get("hit", false)) and absf(float(ph.y) - q.y) < 0.15:
			var psh := _shape_or_plane(ph, float(ph.y), "%s_%s" % [pin.surface, pin.limb])
			pin["shape"] = psh
			if str(psh.type) != "plane":
				s["%s_%s" % [pin.surface, pin.limb]] = psh
	path.surfaces = s
	var guards := []
	var names := {}
	for k: String in s:
		var sh: Dictionary = s[k]
		var key := str(sh.get("name", k))
		if names.has(key) or str(sh.type) == "plane":
			continue
		names[key] = true
		guards.append(sh)
	path.guard_shapes = guards


func _shape_or_plane(hit: Dictionary, y: float, name: String) -> Dictionary:
	if bool(hit.get("hit", false)) and hit.get("collider") != null:
		var node := TravShapeRegistry.resolve(hit.collider, int(hit.get("shape", 0)))
		var sh: Variant = TravSurfaces.from_shape(node)
		if sh != null and str((sh as Dictionary).type) == "box":
			return sh
		# Height fields and meshes (the level's terrain): the ground's local plane, sloped where
		# the terrain is (review 2026-09-24).
		if absf(float(hit.y) - y) < 0.15:
			return TravSurfaces.ground_plane(Vector3(0, float(hit.y), 0) + Vector3(float(hit.get("x", 0.0)), 0, float(hit.get("z", 0.0))), hit.get("normal", Vector3.UP), name)
	return TravSurfaces.plane(y, name)


func tick(delta: float) -> Dictionary:
	var r := _tick(delta)
	var bp := body.global_position
	if _cap_last != Vector3.INF and delta > 0.0:
		_cap_vel = (bp - _cap_last) / delta
	_cap_last = bp
	return r


func _tick(delta: float) -> Dictionary:
	match mode:
		Mode.MOVE, Mode.BEAM, Mode.CRAWL, Mode.SIDLE:
			_segment_tick(delta)
		Mode.CLIMB:
			lane.tick(delta)
			_root = lane.root
			_pins = lane.pins
			# (The rungs near the body are guards: a hand or foot moving past a rung it does not
			# hold stays out of it; contact pass 2026-09-25.)
			_guards = lane.guard_rungs()
			_yaw = TravMoveSelector.yaw_of(-lane.n)
			_sync_content(lane.content)
		Mode.AIR:
			_air_tick(delta)
	if not _exit_ik.is_empty() and mode in [Mode.OFF, Mode.AIR]:
		_exit_ik.t = float(_exit_ik.t) + delta
		var holds := (_exit_ik.pins as Array).any(func(q): return bool((q as Dictionary).get("exit_hold", false)))
		# (Held standing feet stay held while the body stands; once it moves, the locomotion lifts them
		# and the IK lets them go, or EXIT_HOLD_MAX_S after it started moving they are let go.)
		if holds and mode == Mode.OFF and _exit_standing() and float(_exit_ik.t) >= float(_exit_ik.len):
			_exit_ik.t = float(_exit_ik.len)
		if float(_exit_ik.t) >= float(_exit_ik.len) + (EXIT_HOLD_MAX_S + 0.15 if holds else 0.0):
			_exit_ik = {}
	elif owns_body():
		_exit_ik = {}
	return anim_state()


func _segment_tick(delta: float) -> void:
	if plan == null or plan.path == null:
		finish("idle")
		return
	rate = plan.path.rate_at(t_move)
	var dm := delta * rate
	var t_end := plan.path.end_time()
	# (The part of the tick past the end: the hand-back moves the body on for it at its exit velocity; at
	# 3x a clamped last tick lost up to a whole tick of travel, a 1-tick dip at every exit.)
	_leftover_s = maxf(0.0, t_move + dm - t_end) / maxf(rate, 1e-3)
	t_move = minf(t_move + dm, t_end)
	if t_move >= t_end - 0.5 * dm:
		t_move = t_end
	if mode == Mode.SIDLE:
		_sidle_steer()
	_update_segment()
	if mode == Mode.CRAWL and plan.move_id == "crawl_loop" and _roof_ends_within(0.45):
		# The end clip stands up early: start it as the roof ends ahead (proposed).
		_crawl_next(true)
		return
	# (Within half a tick of the end is the end: the table's durations are rounded, and a last tick
	# of a few microseconds held the body still for a tick, a 1.3-1.8 cm capsule pop at the exit.)
	if t_move >= t_end - 0.5 * dm:
		_segment_done()


func _update_segment() -> void:
	var path := plan.path
	_root = path.transform_at(t_move)
	_pins = path.pins_at(t_move)
	_guards = path.guard_shapes
	# Guards that ease in over the entry fade (the squeeze's rock faces: the blended locomotion arm
	# swings into them; pushed out at once it jumped 20 cm in a frame).
	if t_move < 0.5 and _guards.any(func(g): return (g as Dictionary).has("ramp_s")):
		var gl := []
		for g: Dictionary in _guards:
			if g.has("ramp_s"):
				var g2 := g.duplicate()
				g2["w"] = smoothstep(0.0, float(g.ramp_s), t_move)
				gl.append(g2)
			else:
				gl.append(g)
		_guards = gl
	body.global_position = path.capsule_at(t_move)
	var pa := path.part_at(t_move)
	if int(pa.part) != _part:
		_part = int(pa.part)
		var parts: Array = plan.move.get("parts", [])
		var pd: Dictionary = parts[_part]
		var key := str(plan.fade_in.get("key", "trav_enter")) if _part == 0 else "graph:" + str(pd.get("record", "auto"))
		var st := str(plan.fade_in.get("status", "proposed")) if _part == 0 else str(pd.get("fade_status", pd.get("status", "graph")))
		var fade := float(plan.fade_in.get("s", 0.1)) if _part == 0 else float(pd.get("fade_s", 0.0))
		_emit_state({"state": str(pd.get("state", "")), "clip": str(pd.clip), "fade_s": fade, "key": key,
				"status": st, "request": pd.get("request"), "move": plan.move_id, "part": _part})
		if _part > 0 and pd.get("request") != null:
			graph_request.emit(str(pd.request), {"record": pd.get("record"), "fade_s": fade, "state": pd.get("state")})
	for i in path.pins.size():
		var pin: Dictionary = path.pins[i]
		if not _fired.has(i) and t_move >= float(pin.t_on):
			_fired[i] = true
			if not committed and str(pin.surface) in ["top", "hang"]:
				committed = true
			traversal_contact.emit(str(pin.kind), str(pin.limb), path.point_at(str(pin.limb), float(pin.t_on)), str(pin.surface))


func _segment_done() -> void:
	match mode:
		Mode.BEAM:
			_beam_next()
			return
		Mode.CRAWL:
			_crawl_next()
			return
		Mode.SIDLE:
			_sidle_next()
			return
	var p := plan
	match p.exit:
		"climb":
			plan = null
			lane.enter(p.lane_id, float(p.ledge_s), body.global_position - Basis(Vector3.UP, p.yaw) * Vector3.BACK)
			_set_mode(Mode.CLIMB)
			# (The lane's root and plants from the switch's own frame: the mount's last root was
			# shown with the hub's content, and the lane's 1.3 cm away the frame after, uneased.)
			_root = lane.root
			_pins = lane.pins
			_guards = lane.guard_rungs()
			_sync_content(lane.content)
		_:
			finish(p.exit)


## Hand the body back (design 8.6): velocity from the path, floor state refreshed in this tick.
## keep_pins: the move ends in place without an exit clip (a balance walk that stops at the end
## of a log): its planted feet stay held, fading with the exit fade.
func finish(exit := "", keep_pins := false) -> void:
	var held := []
	if keep_pins:
		for pn: Dictionary in _pins:
			if float(pn.get("weight", 0.0)) > 0.0 and str(pn.get("limb", "")).ends_with("foot"):
				held.append(pn.duplicate())
	elif exit != "fall" and plan != null and not plan.move.has("air_exit") and not _fast_exit(plan):
		held = _exit_holds(plan)
	var p := plan
	var v := Vector3.ZERO
	var v_end := Vector3.ZERO
	if p and p.path:
		# The capsule's own end velocity (the body continues exactly as it moved; the pelvis
		# velocity used before differed from the capsule's, a velocity jump at every exit).
		var te := p.path.end_time()
		v = p.path.capsule_velocity_at(te) * p.path.rate_at(te)
		v_end = v
		if exit != "fall":
			v.y = 0.0
		else:
			v.y = minf(v.y, 0.0)
			if p.intent == "over" and p.info:
				# The graph's fall exit (vault^fall) was carried over the far side by the
				# unexported align: hop the body clear of the far edge in HOP_S, then let it fall.
				var into := -p.info.normal
				var far: float = (p.info.face_point - body.global_position).dot(into) + minf(p.info.depth, 1.4) + 0.4
				var vh := Vector3(v.x, 0, v.z)
				var need := maxf(far / HOP_S, 1.0)
				if vh.dot(into) < need:
					vh += into * (need - vh.dot(into))
				v = Vector3(vh.x, maxf(v.y, 2.0), vh.z)
	if exit != "fall":
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		if not body.is_on_floor():
			body.apply_floor_snap()
	body.velocity = v
	if exit != "fall" and _leftover_s > 0.0 and p and p.path and p.path.rate.size() > 0:
		# (a move on a faster clock handed back mid-tick: the rest of the tick at the exit velocity)
		body.global_position += Vector3(v.x, 0.0, v.z) * minf(_leftover_s, 1.0 / 30.0)
	_leftover_s = 0.0
	rate = 1.0
	_handback_ticks = 2
	_set_mode(Mode.OFF)
	plan = null
	# The guards stay on over the exit fade (the outgoing pose is still blended in); the plants
	# end with the move (the warp puts the last planted feet on their surface).
	_exit_ik = {"pins": held, "guards": _guards.duplicate(), "t": 0.0, "len": 0.2, "at": body.global_position}
	_pins = []
	_guards = []
	var ex := exit if exit != "" else (p.exit if p else "idle")
	var lm: Dictionary = p.move.get("loco_match", {}).get("exit", {}) if p else {}
	if p and p.move.has("air_exit"):
		var ae: Dictionary = p.move.air_exit
		_trace("graph:" + str(ae.get("record", "fall")), str(ae.get("status", "graph")), float(ae.get("fade_s", 0.2)), str(ae.get("request", "")))
		graph_request.emit(str(ae.get("request", "fall")), ae)
		# The hop starts as the capsule moved at the end of the move (its velocity difference to
		# the hop is inertialized over the hop: the capsule jumped 9 cm in a frame before).
		# (The body starts the hop moving as the capsule moved: its velocity this tick is that.)
		body.velocity = v_end
		_air = {"clip": str(ae.clip), "t": 0.0, "move": p.move_id, "yaw": p.yaw, "air_len": float(ae.get("length", 0.6)),
				"root_off": _root.origin - body.global_position,
				"hop": {"p0": body.global_position, "v": v, "T": HOP_S, "v0": TravInertializer._clampv(v_end - v, CAP_VEL_MAX)}}
		_set_mode(Mode.AIR)
		serial += 1
		_emit_state({"state": str(ae.get("state", "")), "clip": str(ae.clip), "fade_s": float(ae.get("fade_s", 0.2)),
				"key": "graph:" + str(ae.get("record", "fall")), "status": str(ae.get("status", "graph")), "move": p.move_id + ":air"})
		traversal_finished.emit(p, ex)
		return
	if ex == "fall":
		_air = {"clip": "", "t": 0.0, "move": p.move_id if p else "fall", "yaw": _yaw}
		_set_mode(Mode.AIR)
	var exit_rec: Dictionary = {}
	if p:
		var parts: Array = p.move.get("parts", [])
		if not parts.is_empty():
			exit_rec = (parts[parts.size() - 1] as Dictionary).get("exit_record", {}) if parts[parts.size() - 1].get("exit_record") != null else {}
	var fade := float(exit_rec.get("fade_s", 0.2)) if not exit_rec.is_empty() else 0.2
	if ex == "idle" and exit_rec.is_empty():
		fade = 0.4
	fade = maxf(fade, 0.2)
	_exit_ik.len = fade
	_exit_ik["exit"] = ex
	_last_exit = {"exit": ex, "move": p.move_id if p else "", "loco_match": lm, "fade_s": fade}
	if p and p.path and p.path.end_t > 0.0:
		# (handed back before its end, TravMomentum: the step of the foot it stands on, PlayerTraversal._match_gait)
		var eg := TravMomentum.exit_gait(p.path)
		if not eg.is_empty():
			_last_exit["gait_plant"] = float(eg.plant)
			_last_exit["gait_since_s"] = float(eg.since_s)
	_trace("trav_exit_" + ex, "graph" if not exit_rec.is_empty() else "proposed", fade, "")
	serial += 1
	_emit_state({"state": {"run": "run-fw", "idle": "idle", "fall": "fall"}.get(ex, ex), "clip": "", "fade_s": fade,
			"key": "exit:%s:%d" % [ex, serial], "status": "graph", "move": p.move_id if p else "", "loco_match": lm})
	traversal_finished.emit(p, ex)


## A move with momentum hands the body back running at speed (TravMomentum): no foot stands to be held (a run
## exit holds a foot at most EXIT_HOLD_RUNNING_M, 7 ms at a sprint; held, the lifting foot hung 2 cm over the
## ground for those frames).
func _fast_exit(p: TravMovePlan) -> bool:
	return p.path != null and p.geo.has("momentum") and p.path.rate.size() > 0


## The playing move keeps the body's speed (TravMomentum: its path was solved for the entry speed).
func momentum_active() -> bool:
	return mode == Mode.MOVE and plan != null and plan.geo.has("momentum") and plan.path != null and plan.path.rate.size() > 0


## The feet standing at the end of a move stay planted through the hand-back (fix round 3,
## 2026-09-25: the exit blend slid standing feet 4-6 cm): every full-weight foot plant, and a foot
## the path ends on its surface without one, held world-locked (TraversalIK exit_hold) until the
## locomotion lifts it (its sole more than TraversalIK.EXIT_LIFT_M above the surface) or
## EXIT_HOLD_MAX_S after the exit fade.
const EXIT_HOLD_MAX_S := 0.4
const EXIT_FOOT_ON_M := 0.02
## A body that has moved this far from where the move handed it back no longer stands where its
## held feet are (fix round 3: forward held on after the tree stand's idle exit, the body crept
## 25 cm toward the trunk while both feet stayed held, the leg overstretched and the foot lifted).
const EXIT_HOLD_MOVE_M := 0.06
## A moving body's held foot stays where it stands up to this far (then it is dragged): the exit's
## pose offset (up to 13 cm at a foot, decaying over the exit inertialization) must not slide a
## stance foot; the hold lets go when the locomotion lifts the foot.
const EXIT_HOLD_MOVING_M := 0.15
## ... after a standing exit; after a run exit a foot is held at most EXIT_HOLD_RUNNING_M (held
## farther, the run's stance foot was dragged 15 cm behind the body and pulled 8 cm up out of the
## run's dip, faster than the IK may add motion: 1.5 cm under the top).
const EXIT_HOLD_RUNNING_M := 0.04

func _exit_standing() -> bool:
	if Vector2(body.velocity.x, body.velocity.z).length() >= 0.3:
		return false
	var at: Vector3 = _exit_ik.get("at", body.global_position)
	return Vector2(body.global_position.x - at.x, body.global_position.z - at.z).length() < EXIT_HOLD_MOVE_M

func _exit_holds(p: TravMovePlan) -> Array:
	var out := []
	var have := {}
	for pn: Dictionary in _pins:
		var limb := str(pn.get("limb", ""))
		if limb.ends_with("foot") and float(pn.get("weight", 0.0)) >= 0.999 and str(pn.get("mode", "plant")) == "plant":
			var q := pn.duplicate()
			q["exit_hold"] = true
			q["weight"] = 1.0
			out.append(q)
			have[limb] = true
	if p.path == null:
		return out
	var d := p.path.end_time()
	for limb: String in ["l_foot", "r_foot"]:
		if have.has(limb) or not p.path.points.has(limb):
			continue
		var q := p.path.point_at(limb, d)
		var best := {}
		var best_g := EXIT_FOOT_ON_M
		for k: String in p.path.surfaces:
			var sh: Dictionary = p.path.surfaces[k]
			var tg := TravSurfaces.top_gap(sh, PackedVector3Array([q]))
			if int(tg.over) > 0 and absf(float(tg.gap)) < best_g:
				best_g = absf(float(tg.gap))
				best = sh
		if not best.is_empty():
			out.append({"limb": limb, "weight": 1.0, "mode": "plant", "surface": "exit", "shape": best, "exit_hold": true,
					"id": "%s:%s@exit" % [p.move_id, limb]})
	return out


## The body was placed elsewhere (a respawn, a station): nothing carries over from where it was
## (held exit feet, the carried capsule velocity). Cancels a running move like cancel("teleport").
func teleported() -> void:
	if mode != Mode.OFF:
		cancel("teleport")
	_exit_ik = {}
	_beam_drop = {}
	_cap_last = Vector3.INF
	_cap_vel = Vector3.ZERO
	pending = null
	_approach = {}


func cancel(reason := "") -> void:
	var p := plan
	if reason == "teleport":
		_cap_last = Vector3.INF
		_cap_vel = Vector3.ZERO
		_exit_ik = {}
	if mode in [Mode.MOVE, Mode.BEAM, Mode.CRAWL, Mode.SIDLE] and committed:
		finish("fall" if not body.is_on_floor() else "idle")
	else:
		if mode == Mode.CLIMB:
			lane.lane_id = -1
		_set_mode(Mode.OFF)
		plan = null
		pending = null
		_pins = []
		_guards = []
	_beam = {}
	_crawl = {}
	_sidle = {}
	_trace("trav_cancel" if not committed else "trav_abort", "proposed", 0.2, reason)
	traversal_cancelled.emit(p, reason)


func let_go() -> void:
	if mode == Mode.CLIMB:
		body.velocity = lane.n * 1.2 + Vector3.UP * 0.5
		lane.lane_id = -1
	_post_request("fall")
	_handback_ticks = 2
	_pins = []
	_guards = []
	_air = {"clip": "", "t": 0.0, "move": "let_go", "yaw": _yaw}
	_set_mode(Mode.AIR)
	_emit_state({"state": "fall", "clip": "", "fade_s": 0.2, "key": "graph:fall", "status": "graph"})
	traversal_finished.emit(null, "fall")


# --------------------------------------------------------------------------------------------------
# CLIMB (ladders, TravLaneClimb)
# --------------------------------------------------------------------------------------------------

func _lane_top() -> void:
	var ln: Dictionary = lane.lane
	var top: Vector3 = ln.top
	var m := lib.move("ladder_dismount_top")
	var yaw := TravMoveSelector.yaw_of(-lane.n)
	# The platform's face behind the ladder, measured (it was assumed 0.1 m behind the rungs; a
	# ladder needs ~0.2 m toe room: the course's rungs 5 cm off the wall put the toes 5-17 cm into
	# the platform; review 2026-09-24).
	var face := Vector3(top.x, top.y, top.z) - lane.n * 0.1
	var fh := probe.ray(Vector3(top.x, top.y - 0.04, top.z) + lane.n * 0.05, Vector3(top.x, top.y - 0.04, top.z) - lane.n * 0.8)
	if not fh.is_empty():
		face = Vector3((fh.position as Vector3).x, top.y, (fh.position as Vector3).z)
	# The hands hold the platform top in the clip's own two windows (hero annotation in
	# traversal_moves.json), the feet leave the rungs for the top: no invented contacts.
	# The hands land where the clip puts them relative to the rungs (0.6 m past the rung line in
	# the source): the inset behind the face is the authored one, not a default 10 cm.
	var prim: Dictionary = (m.anchor as Dictionary).get("primary", {})
	var inset := 0.1
	if not prim.is_empty():
		var ref := lib.track_point("ladder_dismount_top", str(prim.limb), float(prim.t)) - lib.track_point("ladder_dismount_top", "align", 0.0)
		inset = clampf(ref.z - (face - lane.root.origin).dot(-lane.n), 0.0, 0.6)
	var geo := {"start": lane.root.origin, "yaw": yaw, "solve_start": false,
			"support_y": lane.root.origin.y + float((m.anchor as Dictionary).get("start_h", 0.0)),
			"landing_y": top.y, "top_y": top.y, "face_point": face, "face_normal": lane.n, "depth": INF,
			"ground_clear": false, "free_start": true, "box_bottom": lane.ground_y, "hand_inset": inset,
			"extra_surfaces": _lane_rungs()}
	var np := TravMovePlan.new()
	np.move_id = "ladder_dismount_top"
	np.move = m
	np.path = TravMotionWarper.solve("ladder_dismount_top", m, geo)
	# The first hold (the hands reaching the platform from the ladder) is at its edge: the palms may
	# stand as close as DISMOUNT_EDGE_M to it, with the wrists and forearms in front of the face (fix
	# round 3: held 4 cm behind the edge by the IK's palm footprint, the forearms and cuffs went
	# 3.9 cm into the platform's edge). The second hold, further in, keeps the footprint.
	if np.path != null and np.path.ok:
		for pn: Dictionary in np.path.pins:
			if str(pn.limb).ends_with("hand") and float(pn.t_on) < DISMOUNT_EDGE_UNTIL_S:
				pn["footprint"] = DISMOUNT_EDGE_M
	np.intent = "climb"
	# The dismount hands back into a run only with room ahead (fix round 3, review 2026-09-25: on the
	# tree's 1.2 m stand it ran on into the trunk, the body 26-30 cm inside it): a solid within
	# EXIT_ROOM_M of where it ends, at knee to head height, and it ends standing.
	np.exit = "run" if _room_ahead(np.path.root_at(np.path.duration), -lane.n, top.y) else "idle"
	np.yaw = yaw
	np.fade_in = {"key": "graph:ladder^climb-up-jump-double-ap", "s": 0.2, "status": "graph"}
	np.geo = geo
	np.info = TravObstacleInfo.new()
	var hit := probe.support_at(Vector3(top.x, top.y + 0.1, top.z) - lane.n * 0.5, 0.3, 0.5)
	if bool(hit.get("hit", false)):
		np.info.shape_node = TravShapeRegistry.resolve(hit.collider, int(hit.get("shape", 0)))
	_rung_feet(np)
	_post_request("ladder^climb-up-jump-double-ap")
	lane.lane_id = -1
	start(np)


const EXIT_ROOM_M := 1.2
const DISMOUNT_EDGE_UNTIL_S := 0.7
const DISMOUNT_EDGE_M := 0.005

## True when nothing solid stands within EXIT_ROOM_M ahead of `from` (along `dir`) at knee, chest and
## head height above `floor_y`.
func _room_ahead(from: Vector3, dir: Vector3, floor_y: float) -> bool:
	dir.y = 0.0
	if dir.length() < 1e-3:
		return true
	dir = dir.normalized()
	for h: float in [0.5, 1.1, 1.6]:
		var a := Vector3(from.x, floor_y + h, from.z)
		if not probe.ray(a, a + dir * EXIT_ROOM_M).is_empty():
			return false
	return true


func _lane_bottom() -> void:
	var m := lib.move("ladder_dismount_bottom")
	var yaw := TravMoveSelector.yaw_of(-lane.n)
	var st := lane.root.origin + lane.n * 0.27 - Vector3.UP * lib.track_point("ladder_dismount_bottom", "l_foot", 0.0).y
	var geo := {"start": st, "yaw": yaw, "solve_start": false, "support_y": st.y + float((m.anchor as Dictionary).get("start_h", 0.0)),
			"landing_y": lane.ground_y, "ground_clear": true, "extra_surfaces": _lane_rungs()}
	var np := TravMovePlan.new()
	np.move_id = "ladder_dismount_bottom"
	np.move = m
	np.path = TravMotionWarper.solve("ladder_dismount_bottom", m, geo)
	np.intent = "climb"
	np.exit = "idle"
	np.yaw = yaw
	np.fade_in = {"key": "graph:ladder^climb-down-jump", "s": 0.2, "status": "graph"}
	np.geo = geo
	_rung_feet(np)
	_post_request("ladder^climb-down-jump")
	lane.lane_id = -1
	start(np)


## The rungs near the body as surfaces of a dismount (guards: the hands letting go of the rungs and
## the feet stepping off them stay out of them; contact pass 2026-09-25).
func _lane_rungs() -> Dictionary:
	var out := {}
	for r: Dictionary in lane.guard_rungs():
		out[str(r.name)] = r
	return out


## A dismount's feet start on rungs, not on the ground a probe finds below the ladder: every foot
## "support" window is planted on the rung whose top is within 5 cm of the planned sole, or left
## free (guarded) when no rung is there.
func _rung_feet(np: TravMovePlan) -> void:
	var keep := []
	for pin: Dictionary in np.path.pins:
		if str(pin.surface) in ["support", "rung"] and str(pin.limb).ends_with("foot"):
			var y := np.path.point_at(str(pin.limb), (float(pin.t_on) + float(pin.t_off)) * 0.5).y
			var rung := lane.rung_at(y)
			if absf(float(rung.a.y) + float(rung.r) - y) > 0.05:
				continue
			pin["shape"] = rung
			pin["surface"] = "rung"
		keep.append(pin)
	np.path.pins = keep


# --------------------------------------------------------------------------------------------------
# Segment moves: a move id played from the current root (beams, crouch-under, shimmy, landings)
# --------------------------------------------------------------------------------------------------

func _segment(move_id: String, start_pos: Vector3, yaw: float, support_y: float, extra := {}) -> TravMovePlan:
	var m := lib.move(move_id)
	var geo := {"start": start_pos, "yaw": yaw, "solve_start": false, "support_y": support_y + float((m.anchor as Dictionary).get("start_h", 0.0)) * 0.0,
			"ground_clear": false}
	geo.merge(extra, true)
	var np := TravMovePlan.new()
	np.move_id = move_id
	np.move = m
	np.path = TravMotionWarper.solve(move_id, m, geo)
	np.intent = str(m.get("intent", ""))
	np.exit = str(m.get("exit", ""))
	np.yaw = yaw
	np.geo = geo
	np.fade_in = m.get("fade_in", {})
	np.status = str(m.get("status", "graph"))
	np.start = start_pos
	return np


## Travel of a move's reference (end align, move frame).
func _travel(move_id: String) -> Vector3:
	var ea: Array = lib.move(move_id).get("end_align", [0, 0, 0])
	return Vector3(float(ea[0]), float(ea[1]), float(ea[2]))


# --------------------------------------------------------------------------------------------------
# BEAM (design 9.5): enter -> loops -> exit along the beam line, feet planted on the beam
# --------------------------------------------------------------------------------------------------

func enter_beam(beam_id: int) -> void:
	if mode != Mode.OFF or _beam_block.has(beam_id) or not ledges.beams.has(beam_id):
		return
	var bm: Dictionary = ledges.beams[beam_id]
	var a: Vector3 = bm.a
	var b: Vector3 = bm.b
	var ab := b - a
	var dirh := Vector3(ab.x, 0, ab.z).normalized()
	var v := Vector3(body.velocity.x, 0, body.velocity.z)
	var fwd := v if v.length() > 0.3 else (Basis(Vector3.UP, float(input_state.get("yaw", body.rotation.y))) * Vector3.FORWARD)
	var sgn := 1.0 if fwd.dot(dirh) >= 0.0 else -1.0
	var p := body.global_position
	var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var q := a + ab * u
	var shape: Variant = null
	if str(bm.get("shape", "")) != "":
		var n := get_node_or_null(NodePath(str(bm.shape)))
		shape = TravSurfaces.from_shape(n) if n else null
	if shape == null:
		shape = TravSurfaces.box(q - Vector3.UP * 0.1, Vector3(float(bm.width), 0.2, ab.length()), TravMoveSelector.yaw_of(dirh), "beam")
		(shape as Dictionary).xform = Transform3D(Basis(Vector3.UP, TravMoveSelector.yaw_of(dirh)), (a + b) * 0.5 - Vector3.UP * 0.1)
	# The feet planted on it are slid sideways onto its walkable band (TraversalIK): the balance
	# clips step up to 0.2 m beside their line (contact pass 2026-09-25: the enter's first foot
	# stood on a log's flank, 2.4 cm off its surface).
	shape = (shape as Dictionary).duplicate()
	(shape as Dictionary)["foot_band"] = _foot_band(shape)
	var yaw := TravMoveSelector.yaw_of(dirh * sgn)
	# The enter starts only where its foot plants have something under them (contact pass
	# 2026-09-25): its trailing foot pushes off 0.37 m behind the start, which on a log's end was
	# 0.4 m above the ground (planted in the air, 10 cm off). A body that stepped onto the log walks
	# on until the enter fits.
	if not _plants_supported("beam_enter", Vector3(q.x, q.y, q.z), yaw):
		return
	# What the beam runs onto at its ends (the platforms of a raised beam): guards, so a swinging
	# or planted foot of the last loop does not sink into the platform it walks onto (a loop's
	# foot went 1.6 cm into it; the plants there use the platform, TravController._resolve_surfaces).
	var ends := {}
	var seen := {str((shape as Dictionary).get("name", "")): true}
	for ep: Vector3 in [a - dirh * 0.35, b + dirh * 0.35]:
		var s := probe.support_at(Vector3(ep.x, q.y + 0.05, ep.z), 0.0, 0.2)
		if not bool(s.get("hit", false)):
			continue
		var es := _shape_or_plane(s, float(s.y), "beam_end_%d" % ends.size())
		if str(es.type) == "box" and not seen.has(str(es.get("name", ""))):
			seen[str(es.get("name", ""))] = true
			ends["beam_end_%d" % ends.size()] = es
	_beam = {"beam": beam_id, "dir": dirh * sgn, "shape": shape, "end": b if sgn > 0.0 else a, "y": q.y, "ends": ends}
	var np := _segment("beam_enter", Vector3(q.x, q.y, q.z), yaw, q.y, _beam_geo())
	_begin_segment(np, Mode.BEAM)


## Geometry extras of a beam segment: the beam as the support, the platforms at its ends as guards.
func _beam_geo() -> Dictionary:
	var g := {"support_shape": _beam.shape}
	if not (_beam.get("ends", {}) as Dictionary).is_empty():
		g["extra_surfaces"] = (_beam.ends as Dictionary).duplicate()
	return g


## Half-width of the band of a beam's top a planted foot's sole centre is kept on (TraversalIK):
## a box's narrow side less BEAM_FOOT_EDGE_M, half the radius of a log or branch.
const BEAM_FOOT_EDGE_M := 0.04
const PLANT_REACH_M := 0.1        ## a planned foot plant this close (sideways) to a support counts as supported
const PLANT_DY_M := 0.05          ## ... within this of the plant's height

static func _foot_band(shape: Dictionary) -> float:
	match str(shape.get("type", "")):
		"box":
			var h: Vector3 = shape.half
			return maxf(0.03, minf(h.x, h.z) - BEAM_FOOT_EDGE_M)
		"cyl":
			return float(shape.r) * 0.5
	return INF


## True when every foot plant of `move_id` started at `start_pos` facing `yaw` (the table's
## contact positions, unwarped) has a support under it: a surface within PLANT_DY_M of the plant's
## height, at the plant or up to PLANT_REACH_M toward the move's line (the IK slides a foot that
## far onto a narrow top). Beam segments start and end only where their steps land on something
## (contact pass 2026-09-25: the beam exit stepped 0.3 m sideways off a raised beam into the air).
func _plants_supported(move_id: String, start_pos: Vector3, yaw: float) -> bool:
	var m := lib.move(move_id)
	if m.is_empty():
		return false
	var bas := Basis(Vector3.UP, yaw)
	var left_w := bas * Vector3(1, 0, 0)          # (move frame: +X is the character's left)
	for c: Dictionary in m.get("contacts", []):
		if str(c.get("kind", "")) != "foot" or not str(c.get("surface", "")) in ["support", "landing"]:
			continue
		var pos: Array = c.pos
		var lp := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		var q := start_pos + bas * lp
		var toward := -left_w * signf(lp.x) if absf(lp.x) > 1e-3 else Vector3.ZERO
		var found := false
		for k in 3:
			var qq := q + toward * (PLANT_REACH_M * k * 0.5)
			var s := probe.support_at(qq + Vector3.UP * 0.1, 0.0, 0.3)
			if bool(s.get("hit", false)) and absf(float(s.y) - q.y) <= PLANT_DY_M:
				found = true
				break
		if not found:
			return false
	return true


func _beam_next() -> void:
	var dirv: Vector3 = _beam.dir
	var root := _root.origin
	var end: Vector3 = _beam.end
	var remaining := (end - root).dot(dirv)
	var loop_d := _travel("beam_loop").z
	var exit_d := _travel("beam_exit").z
	var mv: Vector2 = input_state.get("move", Vector2.ZERO)
	var bm: Dictionary = ledges.beams.get(int(_beam.beam), {})
	var a: Vector3 = bm.get("a", root)
	var b: Vector3 = bm.get("b", root)
	var ab := b - a
	# (On the beam's LINE, not clamped to its ends: the last loop may carry the body onto the
	# platform the beam runs onto, and the exit starts there.)
	var q := a + ab * ((root - a).dot(ab) / maxf(ab.length_squared(), 1e-6))
	var start_pos := Vector3(q.x, float(_beam.y), q.z)
	var yaw := TravMoveSelector.yaw_of(dirv)
	var next := ""
	if plan.move_id == "beam_exit":
		_beam_block[int(_beam.beam)] = 1.5
		_beam = {}
		finish("idle")
		return
	# Every segment's steps land on something (contact pass 2026-09-25). The exit steps 0.3 m to
	# the side into a wide stance: it is played where both feet have support (at the end of a
	# beam, on the platform it runs onto; the loops carry the body there), and at the end of a log
	# over lower ground or of a branch that ends in the air (no supported exit) the balance walk
	# ends in place, into standing, instead of stepping into the air.
	var want := mv.y < -0.3
	var exit_ok := _plants_supported("beam_exit", start_pos, yaw)
	var loop_ok := want and _plants_supported("beam_loop", start_pos, yaw)
	if exit_ok and (not want or remaining < loop_d * 0.5 + exit_d):
		next = "beam_exit"
	elif loop_ok:
		next = "beam_loop"
	elif exit_ok:
		next = "beam_exit"
	else:
		# (The planted feet stay held while the pose settles into standing: the IK plants fade
		# with the exit fade instead of dropping their corrections at the hand-back.)
		# At the end of a log over lower ground or of a branch that ends in the air, walked on: the
		# body walks the last steps to the end and drops off it (_beam_drop_step).
		var edge := Vector3(end.x, float(_beam.y), end.z)
		var drop := _drop_below(edge, dirv)
		_beam_drop = {"edge": edge, "dir": dirv, "drop": drop, "t": 0.0} if want and drop >= BEAM_DROP_MIN_M and drop <= BEAM_DROP_MAX_M else {}
		_beam_block[int(_beam.beam)] = 1.5
		_beam = {}
		finish("idle", true)
		return
	var np := _segment(next, start_pos, yaw, float(_beam.y), _beam_geo())
	np.fade_in = {"key": "trav_beam_" + next, "s": 0.0 if next == "beam_loop" and plan.move_id == "beam_loop" else 0.2, "status": "proposed"}
	_begin_segment(np, Mode.BEAM)


## The end of a log or branch over lower ground (fix round 3, 2026-09-25; review: the balance walk
## ended in place and the locomotion walked off the end with no clip, the branch's 2.9 m in the run
## loop): walked on to the end, the body drops off it with the drop move (drop_fall: off the edge,
## the fall, then the landing clip, as off any ledge), whatever the walk profile.
const BEAM_DROP_MIN_M := 0.25
const BEAM_DROP_MAX_M := 4.0

func _drop_below(edge: Vector3, dirv: Vector3) -> float:
	var past := edge + dirv * 0.45
	var g := probe.support_at(Vector3(past.x, edge.y - 0.05, past.z), 0.0, BEAM_DROP_MAX_M + 1.0)
	if not bool(g.get("hit", false)):
		return INF
	return edge.y - float(g.y)


func _beam_drop_step(ctx: Dictionary, delta: float) -> bool:
	_beam_drop.t = float(_beam_drop.t) + delta
	var edge: Vector3 = _beam_drop.edge
	var dirv: Vector3 = _beam_drop.dir
	var feet: Vector3 = ctx.feet
	var mv: Vector2 = input_state.get("move", Vector2.ZERO)
	var heading: Vector3 = ctx.heading
	if float(_beam_drop.t) > 3.0 or mv.length() < 0.2 or heading.dot(dirv) < 0.7 or absf(feet.y - edge.y) > 0.3 \
			or Vector2(feet.x - edge.x, feet.z - edge.z).length() > 1.5 or not lib.has("drop_fall"):
		_beam_drop = {}
		return false
	var edge_d := (edge - feet).dot(dirv)
	var speed := float(ctx.speed)
	if edge_d > speed * delta * 2.0 + 0.08:
		return false
	var info := TravObstacleInfo.new()
	info.kind = "edge"
	info.support_y = edge.y
	info.face_point = edge
	info.normal = dirv
	info.drop = float(_beam_drop.drop)
	# (A high end, a branch in the air: the jump down off it (drop_hop) clears the end; stepped off
	# with the run-off clip at a walk, the trailing leg dragged 15 cm through the branch's round end.)
	var mid := "drop_hop" if lib.has("drop_hop") else "drop_fall"
	var m := lib.move(mid)
	var dp := TravMovePlan.new()
	dp.move_id = mid
	dp.move = m
	dp.info = info
	dp.intent = "down"
	dp.exit = "fall"
	dp.start = feet
	dp.yaw = TravMoveSelector.yaw_of(dirv)
	dp.fade_in = m.get("fade_in", {})
	_beam_drop = {}
	_jump_buffer = 0.0
	traversal_requested.emit(dp)
	_start_air_clip(dp)
	return true


# --------------------------------------------------------------------------------------------------
# CRAWL (design 7.8): crouch-under start -> loops -> end
# --------------------------------------------------------------------------------------------------

func _crawl_begin(p: TravMovePlan) -> bool:
	var dirv := Vector3(sin(p.yaw), 0, cos(p.yaw))
	_crawl = {"dir": dirv}
	var np := _segment("crawl_start", body.global_position, p.yaw, body.global_position.y)
	_begin_segment(np, Mode.CRAWL)
	return true


func _crawl_next(force_end := false) -> void:
	if plan.move_id == "crawl_end":
		_crawl = {}
		finish("idle")
		return
	var dirv: Vector3 = _crawl.dir
	var root := _root.origin
	var ground := probe.support_at(Vector3(root.x, body.global_position.y + 0.3, root.z), 0.3, 1.0)
	var gy := float(ground.y) if bool(ground.get("hit", false)) else body.global_position.y
	var loop_d := _travel("crawl_loop").z
	var next := "crawl_end" if force_end or _roof_ends_within(loop_d * 0.5) else "crawl_loop"
	var np := _segment(next, Vector3(root.x, gy, root.z), TravMoveSelector.yaw_of(dirv), gy)
	np.fade_in = {"key": "trav_crawl_" + next, "s": 0.0 if next == "crawl_loop" and plan.move_id == "crawl_loop" else 0.25, "status": "proposed"}
	_begin_segment(np, Mode.CRAWL)


## True when the low roof over the crawl ends within `d` ahead of the root.
func _roof_ends_within(d: float) -> bool:
	var dirv: Vector3 = _crawl.get("dir", Vector3.FORWARD)
	var root := _root.origin
	var y := body.global_position.y
	var here := probe.ray(Vector3(root.x, y + 0.2, root.z), Vector3(root.x, y + 1.45, root.z))
	var ahead := root + dirv * d
	var there := probe.ray(Vector3(ahead.x, y + 0.2, ahead.z), Vector3(ahead.x, y + 1.45, ahead.z))
	return not here.is_empty() and there.is_empty() or (here.is_empty() and there.is_empty())


# --------------------------------------------------------------------------------------------------
# SIDLE (wall shimmy on a narrow ledge, graph wall-shimmy-*-right): enter -> idle / move -> exit
# --------------------------------------------------------------------------------------------------

## A narrow ledge (TravLedge kind narrow) whose start is under the body while it walks into its wall.
func _try_sidle(ctx: Dictionary) -> bool:
	if not lib.has("shimmy_enter"):
		return false
	var feet: Vector3 = ctx.feet
	for c: Dictionary in ledges.query_near(feet, 0.6):
		var lg := ledges.ledge(int(c.ledge_id))
		if str(lg.get("kind", "")) != "narrow":
			continue
		var n: Vector3 = lg.normal
		var h: Vector3 = ctx.heading
		if h.dot(-n) < cos(deg_to_rad(35.0)) or float(c.s) > 0.4 or absf((c.point as Vector3).y - feet.y) > 0.25:
			continue
		var pts: PackedVector3Array = lg.points
		# The sidle moves to the character's right while it faces the wall (the source clips are -r).
		var right := Vector3.UP.cross(-n).normalized() * -1.0
		var along := (pts[pts.size() - 1] - pts[0]).normalized()
		if along.dot(right) < 0.5:
			continue
		# The root stands SIDLE_STANDOFF in front of the wall face (the clips' toes reach 0.35 m in
		# front of the root): measured from the wall, not from the marker line, which may run
		# anywhere on the shelf (the course's runs along its middle, 0.15 m from the wall, which
		# put the toes 10-25 cm into the wall; review 2026-09-24).
		var wall_hit := _wall_hit(c.point as Vector3, n)
		var start_pos := (c.point as Vector3) + n * 0.05
		if not wall_hit.is_empty():
			start_pos = _on_sidle_line(c.point as Vector3, wall_hit.position as Vector3, n)
		start_pos.y = feet.y
		# The feet stand on the narrow shelf; the root (align) is over its edge, where a probe
		# straight down finds the ground below: the support surface is the shelf itself.
		var shelf_pt := ((wall_hit.position as Vector3) + n * 0.15) if not wall_hit.is_empty() else (c.point as Vector3) - n * 0.1
		shelf_pt.y = (c.point as Vector3).y
		var sup := probe.support_at(shelf_pt + Vector3.UP * 0.05, 0.1, 0.5)
		var wall: Variant = null
		if not wall_hit.is_empty():
			wall = TravSurfaces.from_shape(TravShapeRegistry.resolve(wall_hit.collider, int(wall_hit.shape)))
		# Boxes the feet stand on (the shelf, and what the ledge runs onto at its end): guards,
		# so no shoe vertex sinks into them while the support is the shelf-height plane.
		var guards_extra := {}
		var shelf_box := _shape_or_plane(sup, feet.y, "support")
		if str(shelf_box.type) == "box":
			guards_extra["shelf"] = shelf_box
		# ... and the platforms at both ends of the ledge (the enter steps off one, the exit onto
		# the other).
		var seen := {str(shelf_box.get("name", "-")): true}
		var line_off := shelf_pt - Vector3((c.point as Vector3).x, shelf_pt.y, (c.point as Vector3).z)
		var k_ep := 0
		for ep: Vector3 in [pts[0] - along * 0.5, pts[0] + along * 0.2, pts[pts.size() - 1] - along * 0.2, pts[pts.size() - 1] + along * 0.5, feet]:
			var q := Vector3(ep.x, shelf_pt.y, ep.z) + (line_off if ep != feet else Vector3.ZERO)
			var eb := _shape_or_plane(probe.support_at(q + Vector3.UP * 0.05, 0.1, 0.5), feet.y, "support_%d" % k_ep)
			k_ep += 1
			if str(eb.type) == "box" and not seen.has(str(eb.get("name", ""))):
				seen[str(eb.get("name", ""))] = true
				guards_extra["shelf_%d" % k_ep] = eb
		_sidle = {"ledge": int(c.ledge_id), "n": n, "right": along, "end": pts[pts.size() - 1], "y": feet.y, "guards": guards_extra,
				"shelf_y": float(sup.y) if bool(sup.get("hit", false)) else feet.y,
				"wall": wall, "wall_point": wall_hit.get("position", Vector3.INF), "support": _shape_or_plane(sup, feet.y, "support")}
		var np := _segment("shimmy_enter", start_pos, TravMoveSelector.yaw_of(-n), feet.y, _sidle_geo("shimmy_enter"))
		_begin_segment(np, Mode.SIDLE)
		return true
	return false


const SIDLE_STANDOFF := 0.40      ## root to wall face (toes reach ~0.35 m in front of the root)


func _wall_hit(p: Vector3, n: Vector3) -> Dictionary:
	return probe.ray(p + Vector3.UP * 0.9 + n * 0.3, p + Vector3.UP * 0.9 - n * 1.2)


## A point moved (horizontally) onto the sidle line: SIDLE_STANDOFF in front of the wall face.
func _on_sidle_line(p: Vector3, wall_pt: Vector3, n: Vector3) -> Vector3:
	var d := Vector3(p.x - wall_pt.x, 0, p.z - wall_pt.z).dot(n)
	return p + n * (SIDLE_STANDOFF - d)


## Geometry extras of a sidle segment: the support (a plane at the shelf height: the shelf, the
## platform the ledge runs onto, the level the exit steps onto) and the wall as a surface and guard.
func _sidle_geo(move_id: String) -> Dictionary:
	# A plane at the shelf's height: the shelf box ends where the ledge runs onto the next
	# platform, and a pin over the platform then found no support (feet 2-17 cm off at the stop).
	var g := {"support_shape": TravSurfaces.plane(float(_sidle.get("shelf_y", _sidle.y)), "support")}
	var ex: Dictionary = (_sidle.get("guards", {}) as Dictionary).duplicate()
	if _sidle.get("wall") != null:
		ex["wall"] = _sidle.wall
	if not ex.is_empty():
		g["extra_surfaces"] = ex
	return g


## The exit (p-ledge-idle-r-exit) turns right and walks 0.86 m forward, past where the wall was:
## it needs the wall to end there. True when the exit path, from `root`, is clear.
func _sidle_exit_clear(root: Vector3) -> bool:
	var n: Vector3 = _sidle.n
	var ea := _travel("shimmy_exit")
	var basis := Basis(Vector3.UP, TravMoveSelector.yaw_of(-n))
	for u: float in [0.5, 0.75, 1.0]:
		var q := root + basis * (ea * u)
		for dy: float in [0.3, 1.0, 1.5]:
			if probe.point_solid(Vector3(q.x, float(_sidle.y) + dy, q.z)):
				return false
	return true


func _sidle_steer() -> void:
	pass


func _sidle_next() -> void:
	var mv: Vector2 = input_state.get("move", Vector2.ZERO)
	var root := _root.origin
	var end: Vector3 = _sidle.end
	var right: Vector3 = _sidle.right
	var remaining := (end - root).dot(right)
	var loop_d := absf(_travel("shimmy_loop").x)
	var cur := plan.move_id
	var next := ""
	match cur:
		"shimmy_exit":
			_sidle = {}
			finish("idle")
			return
		"shimmy_enter", "shimmy_stop", "shimmy_idle":
			if remaining < loop_d + 0.2 and _sidle_exit_clear(Vector3(root.x, float(_sidle.y), root.z)):
				next = "shimmy_exit"
			elif mv.x > 0.3 and remaining > loop_d + 0.2:
				next = "shimmy_start"
			else:
				# The ledge ends but the wall does not (no room for the exit): hold on the ledge.
				next = "shimmy_idle"
		"shimmy_start", "shimmy_loop":
			next = "shimmy_loop" if mv.x > 0.3 and remaining > loop_d + 0.2 else "shimmy_stop"
	var n: Vector3 = _sidle.n
	var start := Vector3(root.x, float(_sidle.y), root.z)
	# Back onto the sidle line: each loop drifts ~3 cm off the wall (the survey's odometry); the
	# rest eases out with the chained segment's root offset.
	if _sidle.get("wall_point", Vector3.INF) != Vector3.INF:
		start = _on_sidle_line(start, _sidle.wall_point, n)
	var np := _segment(next, start, TravMoveSelector.yaw_of(-n), float(_sidle.y), _sidle_geo(next))
	var md := lib.move(next)
	np.fade_in = md.get("fade_in", {"key": "graph", "s": 0.2, "status": "graph"})
	if next == "shimmy_idle":
		np.path.duration = minf(np.path.duration, 0.5)
	_begin_segment(np, Mode.SIDLE)


# --------------------------------------------------------------------------------------------------
# SQUEEZE (TravVolume squeeze): the one source clip, played through the gap along its axis
# --------------------------------------------------------------------------------------------------

const SQUEEZE_WALL_RAMP_S := 0.05

func _try_squeeze(ctx: Dictionary) -> bool:
	if not lib.has("squeeze"):
		return false
	var feet: Vector3 = ctx.feet
	for id: int in ledges.volumes:
		var v: Dictionary = ledges.volumes[id]
		if str(v.kind) != "squeeze":
			continue
		var c: Vector3 = v.center
		var ax: Vector3 = v.axis
		var sz: Vector3 = v.size
		var entry: Vector3 = v.get("entry", c - ax * (sz.z * 0.5))
		var d := Vector3(feet.x - entry.x, 0, feet.z - entry.z)
		# The squeeze starts from rest at its entry (approach() slows the body to the clip's
		# 0.03 m/s there): a body still walking starts it only on reaching the entry (it used to
		# start 0.35 m early at 1.5 m/s, its arm swinging 22 cm into the rock).
		var reach := 0.35 if float(ctx.speed) < 0.4 else 0.06 + float(ctx.speed) * 0.05
		if d.length() > reach or (ctx.heading as Vector3).dot(ax) < 0.8:
			continue
		var yaw := float(v.get("clip_yaw", TravMoveSelector.yaw_of(ax)))
		# The gap's side walls are guards: the clip's hands and fingers reach past the reference
		# points the gap was sized from (the right hand went 15 cm into the rock; review 2026-09-24).
		var walls := {}
		var side := Vector3.UP.cross(ax).normalized()
		for sgn: float in [-1.0, 1.0]:
			for dy: float in [1.0, 1.5]:
				var o := Vector3(c.x, feet.y + dy, c.z)
				var wh := probe.ray(o, o + side * sgn * (sz.x * 0.5 + 0.6))
				if wh.is_empty():
					continue
				var wsh: Variant = TravSurfaces.from_shape(TravShapeRegistry.resolve(wh.collider, int(wh.shape)))
				if wsh != null:
					# (Barely eased in: the squeeze starts from rest at its entry with the hands clear of
					# the rock, and the arm the entry fade swings out against it is held on its face from
					# the start; eased in over the whole fade it went 5 cm into the rock meanwhile.
					# Contact pass 2026-09-25.)
					(wsh as Dictionary)["ramp_s"] = SQUEEZE_WALL_RAMP_S
					walls["gap_wall_%s" % str((wsh as Dictionary).get("name", sgn))] = wsh
		var np := _segment("squeeze", Vector3(entry.x, feet.y, entry.z), yaw, feet.y, {"extra_surfaces": walls})
		_begin_segment(np, Mode.MOVE)
		return true
	return false


# --------------------------------------------------------------------------------------------------
# AIR: drops and fall exits over the body's own physics; the landing clip on touchdown
# --------------------------------------------------------------------------------------------------

func _start_air_clip(p: TravMovePlan) -> void:
	var clip := str((p.move.get("parts", [{}]) as Array)[0].get("clip", ""))
	_air = {"clip": clip, "t": 0.0, "move": p.move_id, "yaw": TravMoveSelector.yaw_of(p.info.normal if p.info else Vector3.FORWARD),
			"air_len": float(p.move.get("duration", 0.7))}
	plan = null
	_drop_cooldown = 0.6
	if p.move_id == "drop_hop":
		var fwd := Vector3(sin(p.yaw), 0, cos(p.yaw))
		var hop_v := fwd * 1.6 + Vector3.UP * 1.2
		if Vector2(body.velocity.x, body.velocity.z).length() > 0.3:
			# (From a walk, off a branch's end: the hop's velocity comes in over HOP_S on a kinematic
			# arc from the body's own, instead of in one tick: a 1.6 cm capsule jump; fix round 3.)
			var hp := {"p0": body.global_position, "v": hop_v, "T": HOP_S, "v0": TravInertializer._clampv(body.velocity - hop_v, CAP_VEL_MAX)}
			if p.info and p.info.drop < INF and p.info.drop > 0.0:
				hp["floor"] = p.info.face_point.y - p.info.drop
			_air["hop"] = hp
		body.velocity = hop_v
	elif p.move_id == "drop_fall":
		# Off the edge on a ballistic path until the capsule has cleared it: the capsule's round
		# bottom used to roll over the edge (and the floor snap pulled it down), a 3.3-3.6 cm
		# one-frame drop of the capsule and the pelvis at every run-off (review 2026-09-24).
		var hv := Vector3(body.velocity.x, 0, body.velocity.z)
		var sp := hv.length()
		if sp > 0.5 and p.info:
			var edge_d := maxf(0.0, (p.info.face_point - body.global_position).dot(hv / sp))
			var hT := clampf((edge_d + 0.42) / sp, 0.05, 0.4)
			_air["hop"] = {"p0": body.global_position, "v": hv, "T": hT, "v0": Vector3.ZERO}
			# (The hop is kinematic: over a low drop it must end on the ground below the edge; a log's
			# 0.4 m end was hopped 9 cm through the ground; fix round 3.)
			if p.info.drop < INF and p.info.drop > 0.0:
				_air.hop["floor"] = p.info.face_point.y - p.info.drop
	_set_mode(Mode.AIR)
	traversal_started.emit(p)
	serial += 1
	_emit_state({"state": str((p.move.get("parts", [{}]) as Array)[0].get("state", "")), "clip": clip,
			"fade_s": float(p.fade_in.get("s", 0.2)), "key": str(p.fade_in.get("key", "trav_enter_drop")),
			"status": str(p.fade_in.get("status", "proposed")), "move": p.move_id})


func _air_tick(delta: float) -> void:
	if _air.is_empty():
		_air = {"clip": "", "t": 0.0, "move": "fall", "yaw": _yaw}
	_air.t = float(_air.t) + delta
	var vh := Vector3(body.velocity.x, 0, body.velocity.z)
	if vh.length() > 0.5:
		_air["yaw"] = lerp_angle(float(_air.get("yaw", _yaw)), TravMoveSelector.yaw_of(vh), clampf(AIR_TURN_RATE * delta, 0.0, 1.0))
	if _air.has("hop") and (float(_air.t) <= float(_air.hop.T) or not bool(_air.get("hop_done", false))):
		# The fall exit's hop over the far edge is kinematic (the obstacle is not collided with
		# until the body is past it), then the body's own physics take the fall.
		var hv: Vector3 = _air.hop.v
		var tt := float(_air.t)
		var hT := float(_air.hop.T)
		var v0: Vector3 = _air.hop.get("v0", Vector3.ZERO)
		var hp := (_air.hop.p0 as Vector3) + hv * tt + Vector3.DOWN * 4.905 * tt * tt + TravInertializer.decay(Vector3.ZERO, v0, tt, hT)
		var hvel := hv + Vector3.DOWN * 9.81 * tt + TravInertializer.decay_vel(Vector3.ZERO, v0, tt, hT)
		if _air.hop.has("floor") and hp.y <= float(_air.hop.floor):
			# Down on the ground below the edge before the hop's time: the physics take the landing.
			hp.y = float(_air.hop.floor)
			_air["hop_done"] = true
			_air.hop.T = minf(hT, tt)
		body.global_position = hp
		body.velocity = hvel
		_air["left_ground"] = true
		if tt > hT:
			# The tick the hop ends is still moved on its arc (the body stood still for a tick,
			# a 4.7 cm capsule pop); from the next tick the body's own physics continue it, and
			# the floor state is only read after they ran (it was stale from before the move: a
			# landing in mid-air).
			_air["hop_done"] = true
		return
	if not body.is_on_floor():
		_air["left_ground"] = true
	var airborne := bool(_air.get("left_ground", false)) and float(_air.t) > 0.12
	if body.is_on_floor() and body.velocity.y <= 0.0 and airborne:
		_land()


## Touchdown after a drop or a fall exit: LocoBrain's landing clip, feet on the real ground.
func _land() -> void:
	var v := Vector3(body.velocity.x, 0, body.velocity.z)
	var yaw := TravMoveSelector.yaw_of(v) if v.length() > 0.5 else float(_air.get("yaw", _yaw))
	var id := "land_run" if v.length() > LAND_RUN_SPEED else "land_idle"
	# A fast running landing takes the soft landing into a run (p-land-soft^run, made for about
	# 4.6 m/s): the medium landing (0.4 m/s) stopped a 5.8 m/s run-off dead in one frame
	# (proposed selection by speed; in game LocoBrain owns the landing).
	if v.length() >= LAND_SOFT_SPEED and lib.has("land_soft"):
		id = "land_soft"
	_air = {}
	if not lib.has(id):
		_set_mode(Mode.OFF)
		_emit_state({"state": "run-fw", "clip": "", "fade_s": 0.2, "key": "loco:land", "status": "graph"})
		traversal_finished.emit(null, "land")
		return
	var feet := body.global_position
	var np := _segment(id, feet, yaw, feet.y)
	# A landing is an impact: the landing clip takes the body's fall (carried into the capsule, a
	# fall at 5 m/s would overshoot the landing and come back); a running landing keeps its
	# horizontal momentum.
	_begin_segment(np, Mode.MOVE, false, id == "land_soft")


# --------------------------------------------------------------------------------------------------
# Animation interface
# --------------------------------------------------------------------------------------------------

func _post_request(req: String) -> void:
	graph_request.emit(req, {})
	_trace("graph:" + req, "graph", 0.2, req)


func _sync_content(c: Dictionary) -> void:
	var key := str(c.get("key", ""))
	if key == _content_key or key == "":
		return
	_content_key = key
	_emit_state({"state": str(c.get("state", "")), "clip": str(c.get("clip", "")), "fade_s": float(c.get("fade", 0.2)),
			"key": str(c.get("trace_key", key)), "status": str(c.get("trace_status", c.get("status", "graph"))),
			"move": key.get_slice(":", 0), "loop": bool(c.get("loop", false))})


func _emit_state(d: Dictionary) -> void:
	_state = d
	_history.append({"t": Time.get_ticks_msec(), "key": d.get("key", ""), "status": d.get("status", ""),
			"state": d.get("state", ""), "fade_s": d.get("fade_s", 0.0)})
	if _history.size() > 256:
		_history.pop_front()
	traversal_state_changed.emit(d)


func _trace(key: String, status: String, fade: float, request: String) -> void:
	_history.append({"t": Time.get_ticks_msec(), "key": key, "status": status, "fade_s": fade, "request": request})
	if _history.size() > 256:
		_history.pop_front()


## The obstacle of the move the body walks up to (the pending plan), as a guard for the hands and
## feet within APPROACH_GUARD_M of it (fix round 3, 2026-09-25: the locomotion's swing foot went
## 1.7 cm toe first into the standing mantle's block on the last step before the move, where
## nothing guarded it).
const APPROACH_GUARD_M := 1.0
var _approach_guard := {}         ## {plan, shape}

func _approach_guards() -> Array:
	if pending == null and _approach.has("beam"):
		# (Walking onto a log's end: the log, fix round 3: the swing foot went 6-14 cm into its end.)
		return _beam_approach_guard(int(_approach.beam))
	if pending == null or pending.info == null or pending.info.shape_node == null or not is_instance_valid(pending.info.shape_node):
		return []
	if _approach_guard.get("plan") != pending:
		var sh: Variant = TravSurfaces.from_shape(pending.info.shape_node)
		_approach_guard = {"plan": pending, "shape": sh if sh != null and str((sh as Dictionary).type) == "box" else {}}
	var shp: Dictionary = _approach_guard.shape
	if shp.is_empty() or float(TravSurfaces.sdf(shp, body.global_position + Vector3.UP * 0.3)[0]) > APPROACH_GUARD_M:
		return []
	return [shp]


## A part join where a foot comes down on its surface (a support or landing plant starting within
## JOIN_CONTACT_S of it): the pose inertialization there does not carry the legs' velocity.
const JOIN_CONTACT_S := 0.15

func _join_contact(part: int) -> bool:
	if part <= 0 or plan == null or plan.path == null:
		return false
	var parts: Array = plan.move.get("parts", [])
	if part >= parts.size():
		return false
	var tj := float((parts[part] as Dictionary).get("t0", -1.0))
	if tj < 0.0:
		return false
	for pn: Dictionary in plan.path.pins:
		# (A foot that comes down there: its plant starts after the move's start, just before or after
		# the join; not the take-off foot standing since the start, the long jump's 0.1 s part.)
		var ton := float(pn.t_on)
		if str(pn.limb).ends_with("foot") and str(pn.surface) in ["support", "landing"] and ton > 0.05 \
				and ton >= tj - JOIN_CONTACT_S and ton <= tj + JOIN_CONTACT_S:
			return true
	return false


func _beam_approach_guard(id: int) -> Array:
	var bm: Dictionary = ledges.beams.get(id, {})
	if str(bm.get("shape", "")) == "":
		return []
	if _approach_guard.get("beam") != id:
		var n := get_node_or_null(NodePath(str(bm.shape)))
		var sh: Variant = TravSurfaces.from_shape(n) if n else null
		_approach_guard = {"beam": id, "shape": sh if sh != null else {}}
	var shp: Dictionary = _approach_guard.shape
	if shp.is_empty() or float(TravSurfaces.sdf(shp, body.global_position + Vector3.UP * 0.3)[0]) > APPROACH_GUARD_M:
		return []
	return [shp]


## What should play now: the content and the Actor_B root (world), the IK pins and guards.
##   {mode, root, pins, guards, clip, clip_t, key (crossfade key), fade_s, state, status, move,
##    exit (after a hand-back: {exit, move, loco_match, fade_s})}
func anim_state() -> Dictionary:
	var d := {"mode": mode_name(), "root": _root, "pins": _pins, "guards": _guards, "state": _state.get("state", ""),
			"fade_s": float(_state.get("fade_s", 0.0)), "key": _state.get("key", ""), "status": _state.get("status", ""),
			"exit": _last_exit}
	if not _exit_ik.is_empty() and mode in [Mode.OFF, Mode.AIR]:
		var k := 1.0 - smoothstep(0.0, float(_exit_ik.len), float(_exit_ik.t))
		# (Held standing feet: at full weight until the IK releases them as the locomotion lifts them,
		# or EXIT_HOLD_MAX_S after the exit fade.)
		var kh := 1.0 - smoothstep(float(_exit_ik.len) + EXIT_HOLD_MAX_S, float(_exit_ik.len) + EXIT_HOLD_MAX_S + 0.15, float(_exit_ik.t))
		var ps := []
		var standing := _exit_standing()
		for p0: Dictionary in _exit_ik.pins:
			var q := p0.duplicate()
			q.weight = float(q.weight) * (kh if bool(q.get("exit_hold", false)) else k)
			# (A standing body keeps its feet where they stand; a moving one only holds a foot the
			# locomotion keeps still, and lets it go once it lifts.)
			if bool(q.get("exit_hold", false)):
				q["hold_max"] = 0.35 if standing else (EXIT_HOLD_RUNNING_M if str(_exit_ik.get("exit", "")) == "run" else EXIT_HOLD_MOVING_M)
			if float(q.weight) > 0.0:
				ps.append(q)
		d["pins"] = ps
		d["guards"] = _exit_ik.guards if k > 0.0 else []
	if mode == Mode.OFF and (d.guards as Array).is_empty():
		d["guards"] = _approach_guards()
	match mode:
		Mode.MOVE, Mode.BEAM, Mode.CRAWL, Mode.SIDLE:
			if plan and plan.path:
				var pa := plan.path.part_at(t_move)
				d["clip"] = pa.clip
				d["clip_t"] = pa.clip_t
				d["part"] = pa.part
				d["move"] = plan.move_id
				d["t_move"] = t_move
				d["key"] = "%s:%d:%d" % [plan.move_id, serial, int(pa.part)]
				d["fade_s"] = float(plan.fade_in.get("s", 0.1)) if int(pa.part) == 0 else float(pa.fade_s)
				if int(pa.part) > 0 and str((plan.move.parts[int(pa.part)] as Dictionary).get("fade_status", "")).begins_with("override"):
					# A 0 s graph seam whose poses differ: instant switch + pose inertialization.
					d["inertialize"] = d.fade_s
					d["fade_s"] = 0.0
				elif int(pa.part) == 0 and bool(plan.fade_in.get("inertialize", false)):
					# An entry the move asks to inertialize (traversal_moves.json fade_in.inertialize):
					# pose and root over the same time (the squeeze, whose root is not at its feet).
					d["inertialize"] = d.fade_s
					d["fade_s"] = 0.0
				d["loco_match"] = plan.move.get("loco_match", {})
				d["join_contact"] = _join_contact(int(pa.part))
				# Forward difference: at a part join this is the new part's root velocity (the
				# inertialization carries the old one).
				var dt := 1.0 / 120.0
				var t1 := minf(t_move + dt, plan.path.duration)
				d["root_vel"] = (plan.path.root_at(t1) - plan.path.root_at(t1 - dt)) / dt * rate
				# The move clock's rate (TravMomentum): the actor runs the move's fades in move time; a
				# content's fade (and inertialization) as the real time its move-time window takes, so
				# it ends where it ends at the clip's own timing (divided by one rate, the entry's fade
				# lagged the clock that sped up behind it and the sprint vault's hands met the wall top
				# half blended, 10-13 cm inside it).
				d["rate"] = rate
				if plan.path.rate.size() > 0:
					var pt0 := 0.0 if int(pa.part) == 0 else float((plan.move.parts[int(pa.part)] as Dictionary).get("t0", 0.0))
					var fw := float(d.fade_s)
					if int(pa.part) == 0 and plan.path.windows.get("first_support") != null:
						# (the entry's fade ends before the first hand or knee support: 0.6 of the way there)
						fw = minf(fw, 0.6 * float(plan.path.windows.first_support))
					d["fade_real"] = plan.path.real_time(pt0, pt0 + fw)
					if d.has("inertialize"):
						d["inertialize_real"] = plan.path.real_time(pt0, pt0 + float(d.inertialize))
		Mode.CLIMB:
			var c: Dictionary = lane.content
			d["clip"] = c.get("clip", "")
			d["clip_t"] = float(c.get("clip_t", 0.0))
			d["key"] = str(c.get("key", ""))
			d["fade_s"] = float(c.get("fade", 0.2))
			d["move"] = str(c.get("key", "")).get_slice(":", 0)
			d["loop"] = bool(c.get("loop", false))
			# (The lane's clip switches keep their plants: see TravLaneClimb._rung_pins.)
			d["pins_continue"] = bool(c.get("pins_continue", false))
			d["sub"] = lane.state()
			d["root_vel"] = lane.root_velocity()
		Mode.AIR:
			var clip := str(_air.get("clip", ""))
			var cl := float(_air.get("air_len", 0.0))
			if clip == "" or float(_air.get("t", 0.0)) > cl:
				clip = str((lib.loco.get("fall", {}) as Dictionary).get("clip", "actor_b-p-fall"))
				d["clip_t"] = fposmod(float(_air.get("t", 0.0)) - cl, 1.0)
				d["key"] = "loco:fall:%d" % serial
				d["fade_s"] = 0.2
			else:
				d["clip_t"] = float(_air.get("t", 0.0))
				d["key"] = "air:%s:%d" % [str(_air.get("move", "")), serial]
			d["clip"] = clip
			d["move"] = str(_air.get("move", "")) + ":air"
			# The facing turns toward the travel smoothly (_air_tick): switched at a speed threshold it
			# jumped (the tall vault's fall exit swung the pelvis 6 cm in a frame). The root starts
			# where the move's root was relative to the body (the fall exit's clip continues the
			# move's pose on the move's root) and settles onto the body over the air clip.
			var yaw := float(_air.get("yaw", _yaw))
			var off: Vector3 = _air.get("root_off", Vector3.ZERO)
			var ot := float(_air.get("t", 0.0))
			var ol := maxf(float(_air.get("air_len", 0.0)), AIR_ROOT_SETTLE_S)
			d["root"] = Transform3D(Basis(Vector3.UP, yaw), body.global_position + off * (1.0 - smoothstep(0.0, ol, ot)))
			d["root_vel"] = body.velocity
			# The ground under a falling body is a guard in the last moments of the fall: the feet
			# (lower than the capsule's bottom in the fall pose) meet it before the body and stop on
			# it, instead of being pushed out of it by the landing's guards in one frame (a 9 cm
			# foot / knee pop at every landing).
			if body.velocity.y < -0.5 and probe:
				var g := probe.support_at(body.global_position + Vector3.UP * 0.1, 0.1, 0.6)
				if bool(g.get("hit", false)):
					var gg := (d.get("guards", []) as Array).duplicate()
					gg.append(_shape_or_plane(g, float(g.y), "ground_below"))
					d["guards"] = gg
					# (The fall poses' soles hang 2-9 cm below the capsule: the actor lifts the pose so
					# they meet the ground as the capsule does; fix round 3.)
					d["ground_below"] = float(g.y)
	# Weapon hook (integration, weapons are not changed here): the move's policy from
	# traversal_moves.json ("keep_parts": the weapon layer keeps its parts, the arms that the clip
	# uses are overridden; "sling": holster / sling for the move) and the hands the IK holds on a
	# surface this frame (a supporting-hand weapon IK must let go of these).
	var policy := "none"
	match mode:
		Mode.MOVE, Mode.BEAM, Mode.CRAWL, Mode.SIDLE:
			if plan:
				policy = str(plan.move.get("weapon_policy", "sling"))
		Mode.CLIMB:
			policy = "sling"
		Mode.AIR:
			policy = str(lib.move(str(_air.get("move", ""))).get("weapon_policy", "keep_parts")) if lib.has(str(_air.get("move", ""))) else "keep_parts"
	var busy := []
	for p: Dictionary in d.pins:
		if str(p.limb).ends_with("hand") and float(p.get("weight", 0.0)) > 0.0 and not busy.has(str(p.limb)):
			busy.append(str(p.limb))
	d["weapon"] = policy
	d["hands_busy"] = busy
	return d


func debug_snapshot() -> Dictionary:
	return {"mode": mode_name(), "move": plan.move_id if plan else "", "t_move": t_move,
			"pending": pending.move_id if pending else "", "none": last_none, "committed": committed,
			"lane": lane.state() if lane and lane.active() else {}, "state": _state, "handback_ticks": _handback_ticks,
			"timing": timing, "history": _history.slice(-12)}
