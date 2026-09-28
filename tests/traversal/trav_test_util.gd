class_name TravTestUtil
extends RefCounted
## Shared by the traversal tests and tools: the course routes (one per move family), a frame
## recorder on the live preview (final pose after TraversalIK, per skeleton update, plus the pose
## as animated before TravInertializer and before TraversalIK), and the metrics the user asked for
## (2026-09-24) with the blind spots of the review of 2026-09-25 closed:
##   window     every non-OFF frame (MOVE, AIR, CLIMB, BEAM, CRAWL, SIDLE) and the OFF frames within
##              WINDOW_S of one (the approach and the exit blend belong to the move; the review found
##              the log's step-on float and the tree stand's walk into the trunk in OFF frames)
##   contacts   every planted palm / sole (full-weight IK plant) measured on the RENDERED mesh (all
##              hand / shoe vertices, CPU-skinned with the body's weights and driven helper bones):
##              gap to the surface's top and planted slide; every hand / foot vertex against every
##              collider near the body; every other body region (shins, thighs with the coat's skirt,
##              forearms, upper arms, torso, head with hat and hair, gear), decimated to 3 cm, against
##              every collider; the soles as animated before the IK against every collider (the IK
##              must not hide a reference that puts a standing foot under the ground); a sole on a
##              surface that slides while the animation holds it still (stance skate).
##              In OFF frames the feet may dip into the floor the capsule stands on as far as the
##              preview's own locomotion does (it has no foot IK; loco_baseline()).
##   pops       every window frame: a one-frame jump (second difference) of a key bone that the IK or
##              the inertializer makes, motion the IK adds on top of the animation, a bone turned
##              much faster than the animation turns it.
##   seams      pose continuity and root / pelvis velocity at every content switch; the moves' own
##              maxima that widen a seam's tolerance are taken from the animation before the
##              inertializer and the IK (their pops cannot widen it).
## Recording runs the course headless at a fixed 120 fps (one physics tick per frame).

const KEY_BONES := ["pelvis", "headb", "l_palm", "r_palm", "l_ball", "r_ball", "l_heel", "r_heel", "l_knee", "r_knee",
		"l_elbow", "r_elbow"]
const LIMB_BONES := {"l_hand": "l_palm", "r_hand": "r_palm", "l_foot": "l_ball", "r_foot": "r_ball"}
## Pop checks: positions (d2, added speed) and rotations (angular speed).
const POP_BONES := ["pelvis", "spined", "headb", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist",
		"l_palm", "r_palm", "l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle", "r_ankle", "l_heel", "r_heel",
		"l_ball", "r_ball", "l_indexc", "r_indexc", "l_middlec", "r_middlec", "l_thumbc", "r_thumbc", "l_pinkyd", "r_pinkyd"]
const CORE_BONES := {"pelvis": 0.012, "spined": 0.015, "headb": 0.02}
const ANG_BONES := ["pelvis", "spined", "headb", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist",
		"l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball"]
const WINDOW_S := 0.5
const FPS := 120.0

var course: Node
var frames: Array = []
var events: Array = []
var recording := false
var world_shapes: Array = []      ## colliders (TravSurfaces) for the per-frame pre-IK sole check
var mc: TravMeshContacts          ## rendered-body skinning (set by the strict test)
var cap_raw: TravPoseCapture
var cap_pre: TravPoseCapture
var _bone_idx := {}
var _pop_idx := PackedInt32Array()
var _cam_prev := Vector3.ZERO


## Route steps (see traversal_course.gd run_route). expect: moves that must start; any: at least
## one of them must start; modes: modes that must be entered.
static func routes() -> Array:
	var sprint := {"move": Vector2(0, -1), "sprint": true}
	var run := {"move": Vector2(0, -1)}
	var walk := {"move": Vector2(0, -1), "walk": true}
	var up := {"move": Vector2(0, -1)}
	var down := {"move": Vector2(0, 1)}
	var right := {"move": Vector2(1, 0)}
	return [
		{"name": "vault_sprint", "family": "vault", "steps": [{"station": "A_vaults"}, {"input": sprint, "for": 6.0}], "expect": ["vault_sprint"]},
		{"name": "vault_idle", "family": "vault", "steps": [{"station": "B_vault_idle"}, {"input": walk, "for": 3.5, "tap_every": 0.1}], "expect": ["vault_idle"]},
		{"name": "step_on", "family": "vault", "steps": [{"station": "B_step_on"}, {"input": walk, "for": 2.6, "tap_every": 0.1}], "expect": ["step_on"]},
		{"name": "vault_tall", "family": "vault", "steps": [{"station": "B_tall"}, {"input": walk, "for": 5.0, "tap_every": 0.1}], "expect": ["vault_tall_fall"]},
		{"name": "mantle_knee_run", "family": "climb", "steps": [{"station": "C_knee"}, {"input": sprint, "for": 3.2}], "expect": ["mantle_1m_run"]},
		{"name": "mantle_1_5m", "family": "climb", "steps": [{"station": "C_knee_1_5"}, {"input": sprint, "for": 4.5}], "expect": ["mantle_1_5m"]},
		{"name": "climb_chest", "family": "climb", "steps": [{"station": "C_chest"}, {"input": sprint, "for": 5.5}], "expect": ["climb_chest"]},
		{"name": "climb_hang_3m", "family": "climb", "steps": [{"station": "C_hang_3m"}, {"input": sprint, "for": 6.5}], "expect": ["climb_hang_3m"]},
		{"name": "mantle_knee_idle", "family": "climb", "steps": [{"station": "D_mantle_idle"}, {"input": walk, "for": 4.0, "tap_every": 0.1}], "expect": ["mantle_1m_idle"]},
		{"name": "drop_and_land", "family": "drop", "steps": [{"station": "C_knee_1_5"}, {"input": sprint, "for": 4.6}], "expect": ["drop_fall"], "any": ["land_run", "land_idle", "land_soft"]},
		{"name": "ladder_up", "family": "ladder", "steps": [{"station": "E_ladder"}, {"input": run, "for": 3.0, "until": "CLIMB"}, {"input": up, "for": 9.0}, {"input": run, "for": 1.0}],
				"expect": ["ladder_mount_bottom", "ladder_dismount_top"], "modes": ["CLIMB"]},
		# (Contact pass 2026-09-25: the ladder plays the graph's sequence, a climb from the hub and a
		# stop into it take their clips' time; the descent runs until the bottom dismount has ended.)
		{"name": "ladder_down", "family": "ladder", "steps": [{"station": "E_ladder"}, {"input": run, "for": 6.0, "until": "CLIMB"}, {"input": up, "for": 1.3}, {"wait": 1.6},
				{"input": down, "for": 9.0, "until": "OFF"}, {"wait": 0.5}],
				"expect": ["ladder_mount_bottom", "ladder_dismount_bottom"], "modes": ["CLIMB"]},
		# (Fix round 3, 2026-09-25: the review's continuous-input beam routes are back. The body walks
		# onto the log from the ground and off its far end with the input held all the way; a log or
		# branch end over lower ground is left with a step or drop off the end and a landing.)
		{"name": "beam_log", "family": "beam", "steps": [{"station": "F_log"}, {"input": walk, "for": 12.0}],
				"modes": ["BEAM"], "expect": ["beam_enter", "beam_loop"], "any": ["beam_exit", "drop_fall", "drop_hop"]},
		{"name": "beam_raised", "family": "beam", "steps": [{"station": "F_beam"}, {"input": walk, "for": 9.0}], "modes": ["BEAM"], "expect": ["beam_enter", "beam_exit"]},
		{"name": "tree_stand", "family": "ladder", "steps": [{"station": "G_tree"}, {"input": run, "for": 3.0, "until": "CLIMB"}, {"input": up, "for": 8.0}],
				"expect": ["ladder_mount_bottom", "ladder_dismount_top"], "modes": ["CLIMB"]},
		{"name": "tree_branch", "family": "beam", "steps": [{"station": "G_branch"}, {"input": walk, "for": 10.0}],
				"modes": ["BEAM"], "expect": ["beam_enter", "beam_loop"], "any": ["drop_fall", "drop_hop"]},
		{"name": "gap_jumps", "family": "gap", "steps": [{"station": "H_gaps"}, {"input": sprint, "for": 4.5}], "expect": ["gap_jump"], "any": ["long_jump"]},
		{"name": "crouch_under", "family": "crawl", "steps": [{"station": "J_tunnel"}, {"input": run, "for": 7.0}], "modes": ["CRAWL"], "expect": ["crawl_start", "crawl_end"]},
		{"name": "wall_shimmy", "family": "shimmy", "steps": [{"station": "K_sidle"}, {"input": walk, "for": 3.5, "until": "SIDLE"}, {"input": right, "for": 23.0}],
				"modes": ["SIDLE"], "expect": ["shimmy_enter", "shimmy_loop"]},
		{"name": "squeeze", "family": "squeeze", "steps": [{"station": "L_squeeze"}, {"input": walk, "for": 11.0}], "expect": ["squeeze"]},
	]


## Routes of the vaults at speed with momentum (TravMomentum; tests/traversal/test_traversal_moves.gd --
## momentum): the sprint vault walls and the standing vault's wall at a sprint (free-run) and at a run (Space).
static func momentum_routes() -> Array:
	var sprint := {"move": Vector2(0, -1), "sprint": true}
	var run := {"move": Vector2(0, -1)}
	return [
		{"name": "vault_sprint", "family": "vault", "steps": [{"station": "A_vaults"}, {"input": sprint, "for": 6.0}], "expect": ["vault_sprint"]},
		{"name": "vault_sprint_run", "family": "vault", "steps": [{"station": "A_vaults"}, {"input": run, "for": 6.0, "tap_every": 0.1}], "expect": ["vault_sprint"]},
		{"name": "vault_idle_sprint", "family": "vault", "steps": [{"station": "B_vault_idle"}, {"input": sprint, "for": 3.5}], "expect": ["vault_idle"]},
		{"name": "vault_idle_run", "family": "vault", "steps": [{"station": "B_vault_idle"}, {"input": run, "for": 3.5, "tap_every": 0.1}], "expect": ["vault_idle"]},
	]


## The preview's plain locomotion on flat ground (no move ahead): its feet's own dip into the floor
## (loco_baseline()).
static func loco_route() -> Dictionary:
	return {"name": "loco_baseline", "family": "loco", "steps": [{"station": "Z_loco"}, {"input": {"move": Vector2(0, -1), "walk": true}, "for": 2.5},
			{"input": {"move": Vector2(0, -1)}, "for": 2.5}, {"input": {"move": Vector2(0, -1), "sprint": true}, "for": 3.0}, {"wait": 1.5}]}


func _init(p_course: Node = null) -> void:
	course = p_course


## captures: put the raw / pre-IK pose captures into the skeleton (the strict test's pop and
## pre-IK sole checks need them).
func attach(captures := false) -> void:
	var c: TraversalController = course.controller
	c.traversal_started.connect(func(p): events.append({"kind": "start", "move": p.move_id if p else "", "frame": frames.size()}))
	c.traversal_finished.connect(func(p, ex): events.append({"kind": "finish", "move": p.move_id if p else "-", "exit": ex, "frame": frames.size()}))
	c.traversal_cancelled.connect(func(p, why): events.append({"kind": "cancel", "move": p.move_id if p else "-", "why": why, "frame": frames.size()}))
	c.mode_changed.connect(func(o, n): events.append({"kind": "mode", "from": o, "to": n, "frame": frames.size()}))
	var ik: TraversalIK = course.actor.ik
	ik.recorder = _record
	var sk: Skeleton3D = course.actor.skeleton
	for b in KEY_BONES:
		_bone_idx[b] = sk.find_bone(b)
	for b in POP_BONES:
		_pop_idx.append(sk.find_bone(b))
	if captures:
		cap_raw = TravPoseCapture.new()
		cap_raw.name = "TestCaptureRaw"
		sk.add_child(cap_raw)
		sk.move_child(cap_raw, course.actor.inert.get_index())
		cap_pre = TravPoseCapture.new()
		cap_pre.name = "TestCapturePre"
		sk.add_child(cap_pre)
		sk.move_child(cap_pre, course.actor.ik.get_index())


func _record(globals: Array, sk_xform: Transform3D) -> void:
	if not recording:
		return
	var c: TraversalController = course.controller
	var st := c.anim_state()
	var ik: TraversalIK = course.actor.ik
	var pins := []
	for p: Dictionary in ik.pins:
		pins.append(p.duplicate())
	var last_mv := str(st.get("move", ""))
	if last_mv == "" and not frames.is_empty():
		last_mv = str(frames[frames.size() - 1].get("move_or_last", ""))
	var rec := {"move_or_last": last_mv, "globals": globals, "sk": sk_xform, "mode": c.mode_name(), "move": str(st.get("move", "")),
			"key": str(course.actor.last.get("key", "")), "clip": str(st.get("clip", "")), "fade": float(st.get("fade_s", 0.0)),
			"w_in": float(course.actor.last.get("w_in", 1.0)), "pins": pins, "guards": ik.guards.duplicate(),
			"capsule": course.runner.global_position, "camera": course.camera.global_position if course.camera else Vector3.ZERO,
			"ik_usec": ik.cost_usec, "ik_report": ik.report.duplicate(true), "t_move": float(st.get("t_move", 0.0)), "tick": Engine.get_physics_frames(), "pframe": Engine.get_process_frames(),
			"rate": float(st.get("rate", 1.0)),
			"step": course.runner.has_method("stepping") and course.runner.stepping()}
	# The pop bones as shown (post), before the IK (pre) and as animated (raw), world space.
	rec["post_p"] = _positions(globals, sk_xform)
	rec["post_q"] = _rotations(globals, sk_xform)
	if cap_raw != null and cap_pre != null and not cap_raw.last.is_empty() and not cap_pre.last.is_empty():
		rec["pre_p"] = _positions(cap_pre.last, sk_xform)
		rec["pre_q"] = _rotations(cap_pre.last, sk_xform)
		rec["raw_p"] = _positions(cap_raw.last, sk_xform)
		rec["raw_q"] = _rotations(cap_raw.last, sk_xform)
		if mc != null:
			rec["pre_sole"] = _pre_soles(cap_pre.last, sk_xform, rec)
	# The skeleton can update more than once per tick (seeks); keep the last (rendered) one.
	if not frames.is_empty() and int(frames[frames.size() - 1].tick) == int(rec.tick):
		frames[frames.size() - 1] = rec
	else:
		frames.append(rec)


func _positions(g: Array, x: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(_pop_idx.size())
	for k in _pop_idx.size():
		out[k] = x * (g[_pop_idx[k]] as Transform3D).origin
	return out


func _rotations(g: Array, x: Transform3D) -> Array:
	var out := []
	out.resize(_pop_idx.size())
	var xb := x.basis.orthonormalized()
	for k in _pop_idx.size():
		out[k] = (xb * (g[_pop_idx[k]] as Transform3D).basis.orthonormalized()).get_rotation_quaternion()
	return out


## The deepest foot vertex of the pose before the IK inside a collider near the body (and the
## move's own shapes: rungs): {l_foot: [depth, shape], r_foot: [...]}.
func _pre_soles(g_pre: Array, x: Transform3D, rec: Dictionary) -> Dictionary:
	var g := mc.full_globals(g_pre)
	var shapes := _near_shapes(rec, x * (g[int(_bone_idx.pelvis)] as Transform3D).origin)
	var out := {}
	for limb in ["l_foot", "r_foot"]:
		var pts := mc.skin(limb, g)
		for i in pts.size():
			pts[i] = x * pts[i]
		var best := 0.0
		var who := ""
		for sh: Dictionary in shapes:
			var pen := TravSurfaces.penetration(sh, pts)
			if float(pen.depth) > best:
				best = float(pen.depth)
				who = str(sh.get("name", ""))
		out[limb] = [best, who]
	return out


## Colliders near the body (within 2.2 m of the pelvis) and the frame's pin and guard shapes.
func _near_shapes(rec: Dictionary, pel: Vector3) -> Array:
	var shapes := []
	var names := {}
	for p: Dictionary in rec.pins:
		var sh: Dictionary = p.get("shape", {})
		if not sh.is_empty() and not names.has(str(sh.get("name", ""))) and str(sh.type) != "plane":
			names[str(sh.get("name", ""))] = true
			shapes.append(sh)
	for sh: Dictionary in rec.guards:
		if not names.has(str(sh.get("name", ""))) and str(sh.type) != "plane":
			names[str(sh.get("name", ""))] = true
			shapes.append(sh)
	for sh: Dictionary in world_shapes:
		if not names.has(str(sh.get("name", ""))) and float(TravSurfaces.sdf(sh, pel)[0]) < 2.2:
			names[str(sh.get("name", ""))] = true
			shapes.append(sh)
	return shapes


func run(route: Dictionary) -> Dictionary:
	frames = []
	events = []
	recording = true
	await course.run_route(route.steps)
	recording = false
	var started := []
	var modes := []
	for e: Dictionary in events:
		if e.kind == "start":
			started.append(e.move)
		elif e.kind == "mode":
			modes.append(e.to)
	var why := []
	for m: String in route.get("expect", []):
		if not started.has(m):
			why.append("missing move " + m)
	var any: Array = route.get("any", [])
	if not any.is_empty() and not any.any(func(x): return started.has(x)):
		why.append("none of " + str(any))
	for m: String in route.get("modes", []):
		if not modes.has(m):
			why.append("missing mode " + m)
	for e: Dictionary in events:
		if e.kind == "cancel" and str(e.why) != "teleport":
			why.append("cancel " + str(e.why))
	return {"started": started, "modes": modes, "why": why, "frames": frames.size()}


# --------------------------------------------------------------------------------------------------
# Window: the frames that belong to traversal
# --------------------------------------------------------------------------------------------------

## Per frame: {win (in the window), off, after (an OFF frame after a traversal, within WINDOW_S),
## exit_ik (an OFF frame whose exit IK still runs), phase ("" / "approach" / "exit"), near (the move
## of the traversal it belongs to)}.
static func window(fr: Array) -> Array:
	var n := fr.size()
	var w := int(round(WINDOW_S * FPS))
	var out := []
	out.resize(n)
	var last_i := -100000
	var last_mv := ""
	for i in n:
		var f: Dictionary = fr[i]
		var off := str(f.mode) == "OFF"
		if not off:
			last_i = i
			last_mv = str(f.move).get_slice(":", 0)
		out[i] = {"win": not off, "off": off, "after": off and i - last_i <= w, "exit_ik": false, "phase": "", "near": last_mv if off and i - last_i <= w else ""}
		if off and i - last_i <= w:
			out[i].win = true
			out[i].phase = "exit"
			out[i].exit_ik = not (f.guards as Array).is_empty() or not (f.pins as Array).is_empty()
	var next_i := 100000
	var next_mv := ""
	for i in range(n - 1, -1, -1):
		var f: Dictionary = fr[i]
		if str(f.mode) != "OFF":
			next_i = i
			next_mv = str(f.move).get_slice(":", 0)
		elif next_i - i <= w and not bool(out[i].after):
			out[i].win = true
			out[i].phase = "approach"
			out[i].near = next_mv
	return out


# --------------------------------------------------------------------------------------------------
# Contacts on the rendered mesh
# --------------------------------------------------------------------------------------------------

## The preview's own locomotion (no foot IK) on flat ground: how far its soles dip into the floor
## the capsule stands on, per foot (m). OFF frames of a route may dip that far.
static func loco_baseline(fr: Array, mc: TravMeshContacts, world_shapes: Array) -> Dictionary:
	var out := {"l_foot": 0.0, "r_foot": 0.0}
	for f: Dictionary in fr:
		if str(f.mode) != "OFF":
			continue
		var floor_sh := _floor_of(f, world_shapes)
		if floor_sh.is_empty():
			continue
		var g := mc.full_globals(f.globals)
		var sk: Transform3D = f.sk
		for limb in ["l_foot", "r_foot"]:
			var pts := mc.skin(limb, g)
			for i in pts.size():
				pts[i] = sk * pts[i]
			var dep := float(TravSurfaces.penetration(floor_sh, pts).depth)
			if dep > float(out[limb]):
				out[limb] = dep
				out[limb + "_at"] = "%s speed %.2f" % [str(f.key), Vector2((f.capsule as Vector3).x, (f.capsule as Vector3).z).length() * 0.0 + (fr[maxi(0, fr.find(f) - 1)].capsule as Vector3).distance_to(f.capsule) * FPS]
	return out


## The collider the capsule stands on (the top under its bottom point, within 10 cm), or {}.
static func _floor_of(f: Dictionary, world_shapes: Array) -> Dictionary:
	var cp: Vector3 = f.capsule
	var best := 0.1
	var out := {}
	for sh: Dictionary in world_shapes:
		var tg := TravSurfaces.top_gap(sh, PackedVector3Array([cp]))
		if int(tg.over) == 0:
			continue
		var d := absf(float(tg.gap))
		if d < best:
			best = d
			out = sh
	return out


## Per move (the traversal a window frame belongs to; "<move>(approach)" / "<move>(exit)" for OFF
## frames): {planted: {limb: {n, gap_max, gap_min, off_top, slide}}, pen_all / pen_at (hand / foot
## vertices in any collider), floor_pen (OFF frames: feet in the floor, see loco_baseline),
## body: {region: [depth, shape, frame, clip]}, pre_sole: [depth, limb, shape, frame, clip],
## skate: [slide, limb, frames, frame, clip], knee_pen, frames}.
##   world_shapes  every collider of the scene (TravSurfaces): penetration is measured against the
##                 ones near the body too, not only the move's own surfaces (review 2026-09-24)
## A planted limb that is not over its surface's top is measured by its true distance. slide = the
## horizontal travel of the vertex that touched when the plant began, while it stays within 1 cm
## of the surface. skate = the same for a sole within 5 mm of a surface while the animation moves
## that foot at under SKATE_V (the clip holds it still): outside a plant window, nothing may slide
## a standing foot (review 2026-09-25: a guard-held sole the reference put under the ground skated
## 33-57 cm along it).
const SKATE_V := 0.3
const SKATE_TOUCH := 0.005

static func contact_metrics(fr: Array, mc: TravMeshContacts, world_shapes: Array = [], loco_base := {}) -> Dictionary:
	var out := {}
	var slide_state := {}
	var skate_state := {}
	var win := window(fr)
	var sk_b: Skeleton3D = mc.skeleton
	var pel_i := sk_b.find_bone("pelvis")
	var foot_bones := {"l_foot": [sk_b.find_bone("l_ball"), sk_b.find_bone("l_heel")], "r_foot": [sk_b.find_bone("r_ball"), sk_b.find_bone("r_heel")]}
	var do_regions := not mc.regions.is_empty()
	for fi in fr.size():
		var f: Dictionary = fr[fi]
		var wf: Dictionary = win[fi]
		if not bool(wf.win):
			slide_state.clear()
			skate_state.clear()
			continue
		var off := bool(wf.off)
		var mv := str(f.move).get_slice(":", 0)
		if off:
			mv = "%s(%s)" % [str(wf.near), str(wf.phase)]
		if str(f.mode) == "AIR" or off:
			# (No plant over these frames: the next plant is a new one.)
			slide_state.clear()
		var shapes := []
		var names := {}
		for p: Dictionary in f.pins:
			var sh: Dictionary = p.shape
			if not names.has(str(sh.get("name", ""))):
				names[str(sh.get("name", ""))] = true
				shapes.append(sh)
		for sh: Dictionary in f.guards:
			if not names.has(str(sh.get("name", ""))):
				names[str(sh.get("name", ""))] = true
				shapes.append(sh)
		var pel: Vector3 = (f.sk as Transform3D) * (f.globals[pel_i] as Transform3D).origin
		for sh: Dictionary in world_shapes:
			if not names.has(str(sh.get("name", ""))) and float(TravSurfaces.sdf(sh, pel)[0]) < 2.2:
				names[str(sh.get("name", ""))] = true
				shapes.append(sh)
		if not out.has(mv):
			out[mv] = {"planted": {}, "pen_all": 0.0, "pen_at": "", "knee_pen": 0.0, "frames": 0, "floor_pen": 0.0, "floor_at": "", "floor_excess": -1.0,
					"body": {}, "pre_sole": [0.0, "", "", -1, ""], "skate": [0.0, "", 0, -1, ""]}
		var M: Dictionary = out[mv]
		M.frames = int(M.frames) + 1
		var g := mc.full_globals(f.globals)
		var sk: Transform3D = f.sk
		var world := {}
		for limb in ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee"]:
			var pts := mc.skin(limb, g)
			for i in pts.size():
				pts[i] = sk * pts[i]
			world[limb] = pts
		var clip := str(f.clip).trim_prefix("actor_b-")
		# --- planted gap and slide (full-weight plants)
		var full := {}
		for p: Dictionary in f.pins:
			if float(p.weight) < 0.999:
				continue
			var limb := str(p.limb)
			full[limb] = true
			var tg := TravSurfaces.top_gap(p.shape, world[limb])
			var P: Dictionary = M.planted.get(limb, {"n": 0, "gap_max": -INF, "gap_min": INF, "surface": str(p.get("surface", "")), "off_top": 0, "slide": 0.0})
			if int(tg.over) == 0:
				var dmin := INF
				var imin := -1
				var wl: PackedVector3Array = world[limb]
				for vi in wl.size():
					var dv := float(TravSurfaces.sdf(p.shape, wl[vi])[0])
					if dv < dmin:
						dmin = dv
						imin = vi
				tg = {"gap": dmin, "i": imin, "over": 0, "n": Vector3.UP}
				P.off_top = int(P.off_top) + 1
			var wls: PackedVector3Array = world[limb]
			if not slide_state.has(limb):
				var k0 := 0
				var d0 := INF
				for vi in wls.size():
					var dv := float(TravSurfaces.sdf(p.shape, wls[vi])[0])
					if dv < d0:
						d0 = dv
						k0 = vi
				slide_state[limb] = {"k": k0, "p": wls[k0]}
			var ss: Dictionary = slide_state[limb]
			var vk: Vector3 = wls[int(ss.k)]
			if float(TravSurfaces.sdf(p.shape, vk)[0]) < 0.01:
				P.slide = maxf(float(P.slide), Vector2(vk.x - (ss.p as Vector3).x, vk.z - (ss.p as Vector3).z).length())
			P.n = int(P.n) + 1
			if float(tg.gap) > float(P.gap_max):
				P.gap_max = float(tg.gap)
				P["max_detail"] = "frame %d t_move %.3f clip %s surface %s shape %s" % [fi, float(f.get("t_move", 0.0)), clip, str(p.get("surface", "")),
						str((p.shape as Dictionary).get("name", ""))]
			if float(tg.gap) < float(P.gap_min):
				P.gap_min = float(tg.gap)
				P["min_frame"] = fi
				P["min_detail"] = "frame %d t_move %.3f clip %s shape %s" % [fi, float(f.get("t_move", 0.0)), clip, str((p.shape as Dictionary).get("name", ""))]
			M.planted[limb] = P
		for limb in slide_state.keys():
			if not full.has(limb):
				slide_state.erase(limb)
		# --- hand / foot vertices in any collider (OFF frames: the feet may dip into the floor as far
		# as the preview's own locomotion does)
		var floor_sh := _floor_of(f, world_shapes) if off else {}
		for limb in ["l_hand", "r_hand", "l_foot", "r_foot"]:
			for sh: Dictionary in shapes:
				if not world_shapes.is_empty() and str(sh.type) == "plane":
					continue
				var pen := TravSurfaces.penetration(sh, world[limb])
				if off and limb.ends_with("foot") and not floor_sh.is_empty() and str(sh.get("name", "")) == str(floor_sh.get("name", "")):
					var ex := float(pen.depth) - float(loco_base.get(limb, 0.0))
					if ex > float(M.floor_excess):
						M.floor_excess = ex
						M.floor_pen = float(pen.depth)
						M.floor_at = "%s in %s frame %d (%s, loco %.3f)" % [limb, str(sh.get("name", "")), fi, str(wf.phase), float(loco_base.get(limb, 0.0))]
					continue
				if float(pen.depth) > float(M.pen_all):
					M.pen_all = float(pen.depth)
					M.pen_at = "%s in %s (%s%s) frame %d" % [limb, str(sh.get("name", "")), clip, (", " + str(wf.phase)) if off else "", fi]
					M["pen_frame"] = fi
					M["pen_limb"] = limb
		for limb in ["l_knee", "r_knee"]:
			for sh: Dictionary in shapes:
				if str(sh.type) == "plane":
					continue
				M.knee_pen = maxf(float(M.knee_pen), float(TravSurfaces.penetration(sh, world[limb]).depth))
		# --- body regions (shins, thighs and coat, arms, torso, head and hat, gear)
		if do_regions:
			for reg: String in mc.regions:
				var R: Dictionary = mc.regions[reg]
				var near := []
				for sh: Dictionary in shapes:
					if str(sh.type) == "plane":
						continue
					for b: int in R.dom:
						var bo: Vector3 = sk * (g[b] as Transform3D).origin
						if float(TravSurfaces.sdf(sh, bo)[0]) < float(R.dom[b]) + 0.01:
							near.append(sh)
							break
				if near.is_empty():
					continue
				var pts := mc.skin_region(reg, g)
				for i in pts.size():
					pts[i] = sk * pts[i]
				for sh: Dictionary in near:
					var d := float(TravSurfaces.penetration(sh, pts).depth)
					var cur: Array = (M.body as Dictionary).get(reg, [0.0, "", -1, ""])
					if d > float(cur[0]):
						M.body[reg] = [d, str(sh.get("name", "")), fi, "%s%s" % [clip, (" " + str(wf.phase)) if off else ""]]
		# --- the soles as animated before the IK (moves; OFF frames while the exit IK runs, less
		# the locomotion's own dip into the floor; while an entry still crossfades from locomotion,
		# less that dip too: the blend of the loop's pose)
		if f.has("pre_sole") and (not off or bool(wf.exit_ik)):
			var loco_w := 1.0 if off or float(f.get("w_in", 1.0)) < 0.999 else 0.0
			for limb in ["l_foot", "r_foot"]:
				var ps: Array = (f.pre_sole as Dictionary).get(limb, [0.0, ""])
				var depth := float(ps[0])
				if loco_w > 0.0 and str(ps[1]) != "" and (not off or (not floor_sh.is_empty() and str(ps[1]) == str(floor_sh.get("name", "")))):
					depth -= float(loco_base.get(limb, 0.0)) * loco_w
				if depth > float(M.pre_sole[0]):
					M.pre_sole = [depth, limb, str(ps[1]), fi, "%s t %.3f" % [clip, float(f.get("t_move", 0.0))]]
		# --- stance skate: a sole on a surface that slides while the animation holds the foot still
		if f.has("raw_p") and fi > 0 and (fr[fi - 1] as Dictionary).has("raw_p"):
			var rp: PackedVector3Array = f.raw_p
			var rq: PackedVector3Array = (fr[fi - 1] as Dictionary).raw_p
			for limb in ["l_foot", "r_foot"]:
				var kb := POP_BONES.find(limb.substr(0, 2) + "ball")
				var kh := POP_BONES.find(limb.substr(0, 2) + "heel")
				var vb := Vector2(rp[kb].x - rq[kb].x, rp[kb].z - rq[kb].z).length() * FPS
				var vh := Vector2(rp[kh].x - rq[kh].x, rp[kh].z - rq[kh].z).length() * FPS
				var wl: PackedVector3Array = world[limb]
				var touching := PackedInt32Array()
				if minf(vb, vh) < SKATE_V:
					var hit := PackedByteArray()
					hit.resize(wl.size())
					for sh: Dictionary in shapes:
						if str(sh.type) == "plane":
							continue
						var dd := dists(sh, wl)
						for vi in wl.size():
							if dd[vi] < SKATE_TOUCH:
								hit[vi] = 1
					for vi in wl.size():
						if hit[vi] == 1:
							touching.append(vi)
				if touching.is_empty():
					skate_state.erase(limb)
					continue
				var E: Dictionary = skate_state.get(limb, {"first": {}, "n": 0, "f0": fi, "trace": []})
				skate_state[limb] = E
				E.n = int(E.n) + 1
				var ds := []
				for vi in touching:
					if not (E.first as Dictionary).has(vi):
						E.first[vi] = wl[vi]
					var p0: Vector3 = E.first[vi]
					ds.append(Vector2(wl[vi].x - p0.x, wl[vi].z - p0.z).length())
				ds.sort()
				var net: float = ds[ds.size() / 2]
				(E.trace as Array).append("f%d n%d net %.3f v %.2f" % [fi, touching.size(), net, minf(vb, vh)])
				if int(E.n) >= 3 and net > float(M.skate[0]):
					M.skate = [net, limb, int(E.n), fi, "%s t %.3f" % [clip, float(f.get("t_move", 0.0))], (E.trace as Array).slice(-12)]
	return out


## Signed distance of each point to a shape (TravSurfaces.sdf, the box inlined).
static func dists(sh: Dictionary, pts: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(pts.size())
	if str(sh.type) == "box":
		var inv := (sh.xform as Transform3D).affine_inverse()
		var h: Vector3 = sh.half
		for i in pts.size():
			var q := inv * pts[i]
			var d := q.abs() - h
			var o := Vector3(maxf(d.x, 0.0), maxf(d.y, 0.0), maxf(d.z, 0.0))
			out[i] = o.length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0)
		return out
	for i in pts.size():
		out[i] = float(TravSurfaces.sdf(sh, pts[i])[0])
	return out


# --------------------------------------------------------------------------------------------------
# Pops: what the IK and the inertializer add to the animation
# --------------------------------------------------------------------------------------------------

## Over the window frames: {pipe_pop: [d2, bone, frame, source, label] (a one-frame jump of a key bone
## over tol whose larger part the IK or the inertializer made), ik_add: [cm per frame, bone, frame,
## label] (the IK moves the bone faster than the animation moves it), ik_turn / in_turn: [rad/s,
## bone, frame, label] (the IK / the inertializer turns the bone faster than the animation turns it),
## turn: [rad/s, bone, frame, label] (a bone turning over 25 rad/s and over 1.5 x the animation + 5)}.
## per_rate: a frame of a move on a faster clock (TravMomentum, the frame's anim_state rate r) is measured per
## frame of the move's clock: its second differences and velocity jumps over a fixed number of frames / r^2,
## its per-frame additions and turn rates / r (the same motion played r x faster moves r x as far per frame
## and changes its speed r^2 x as fast per frame; a pop is a jump beyond that). The rate of a frame is the
## highest over the RATE_TRAIL_S before it (a hand-back's inertialization carries the move's motion on).
static func pop_metrics(fr: Array, limb_tol := 0.045, per_rate := false) -> Dictionary:
	var win := window(fr)
	var rt := rates(fr, per_rate)
	var out := {"pipe_pop": [0.0, "", -1, "", ""], "ik_add": [0.0, "", -1, ""], "ik_turn": [0.0, "", -1, ""], "in_turn": [0.0, "", -1, ""],
			"turn": [0.0, "", -1, ""]}
	var n := fr.size()
	# A landing is an impact (the fall stops in a frame): its body's deceleration is the landing's, not
	# a pop (the seam check exempts the pelvis and the capsule there too); the limbs are still checked.
	var impact := {}
	for i in range(1, n):
		var a0: Dictionary = fr[i - 1]
		var b0: Dictionary = fr[i]
		if (str(a0.mode) == "AIR" and str(b0.mode) != "AIR") or (str(b0.key).begins_with("land_") and not str(a0.key).begins_with("land_")):
			for k in range(i - 1, mini(n, i + 3)):
				impact[k] = true
	for i in range(3, n):
		if not bool(win[i].win):
			continue
		var f: Dictionary = fr[i]
		var a: Dictionary = fr[i - 1]
		var b: Dictionary = fr[i - 2]
		if not (f.has("pre_p") and a.has("pre_p") and b.has("pre_p")):
			continue
		var lab := "%s %s %s t %.3f" % [str(f.mode), str(f.key), str(f.clip).trim_prefix("actor_b-"), float(f.get("t_move", 0.0))]
		var rs := rt[i]
		for k in POP_BONES.size():
			var bn: String = POP_BONES[k]
			var P2: Vector3 = (f.post_p as PackedVector3Array)[k]
			var P1: Vector3 = (a.post_p as PackedVector3Array)[k]
			var P0: Vector3 = (b.post_p as PackedVector3Array)[k]
			var Q2: Vector3 = (f.pre_p as PackedVector3Array)[k]
			var Q1: Vector3 = (a.pre_p as PackedVector3Array)[k]
			var Q0: Vector3 = (b.pre_p as PackedVector3Array)[k]
			var R2: Vector3 = (f.raw_p as PackedVector3Array)[k]
			var R1: Vector3 = (a.raw_p as PackedVector3Array)[k]
			var R0: Vector3 = (b.raw_p as PackedVector3Array)[k]
			var dp := (P2 - 2.0 * P1 + P0).length() / (rs * rs)
			var tol := float(CORE_BONES.get(bn, limb_tol))
			# (At a landing the legs stop dead on the ground as well: the impact, like the body's.)
			var foot_b := bn.ends_with("_ball") or bn.ends_with("_heel") or bn.ends_with("_ankle") or bn.ends_with("_knee")
			if dp > tol and not ((CORE_BONES.has(bn) or foot_b) and impact.has(i)):
				var dk := ((P2 - Q2) - 2.0 * (P1 - Q1) + (P0 - Q0)).length() / (rs * rs)
				var di := ((Q2 - R2) - 2.0 * (Q1 - R1) + (Q0 - R0)).length() / (rs * rs)
				if maxf(dk, di) > 0.5 * dp and dp > float(out.pipe_pop[0]):
					out.pipe_pop = [dp, bn, i, "ik" if dk >= di else "inertializer", lab]
			if not CORE_BONES.has(bn):
				var add := ((P2 - P1).length() - (Q2 - Q1).length()) / rs
				if add > float(out.ik_add[0]):
					out.ik_add = [add, bn, i, lab]
		for bn2: String in ANG_BONES:
			var k2 := POP_BONES.find(bn2)
			var wp := ((a.post_q[k2]) as Quaternion).angle_to(f.post_q[k2]) * FPS / rs
			var wq := ((a.pre_q[k2]) as Quaternion).angle_to(f.pre_q[k2]) * FPS / rs
			var wr := ((a.raw_q[k2]) as Quaternion).angle_to(f.raw_q[k2]) * FPS / rs
			if wp - wq > float(out.ik_turn[0]):
				out.ik_turn = [wp - wq, bn2, i, lab]
			if wq > 20.0 and wq - wr > float(out.in_turn[0]):
				out.in_turn = [wq - wr, bn2, i, lab]
			if wp > 25.0 and wp > 1.5 * wr + 5.0 and wp > float(out.turn[0]):
				out.turn = [wp, bn2, i, lab]
	return out


const RATE_TRAIL_S := 0.3

## Per frame, the move clock's rate the frame is measured at (see pop_metrics; all 1 without per_rate).
static func rates(fr: Array, per_rate: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(fr.size())
	out.fill(1.0)
	if not per_rate:
		return out
	var k := int(round(RATE_TRAIL_S * FPS))
	for i in fr.size():
		var r := 1.0
		for j in range(maxi(0, i - k), i + 1):
			r = maxf(r, float((fr[j] as Dictionary).get("rate", 1.0)))
		out[i] = r
	return out


# --------------------------------------------------------------------------------------------------
# Seams: pose continuity, pelvis / capsule velocity, angular speed
# --------------------------------------------------------------------------------------------------

## per_rate: as pop_metrics (a frame on a faster clock measured per frame of the move's clock).
func seam_metrics(fr: Array, fps := 120.0, per_rate := false) -> Dictionary:
	var n := fr.size()
	if n < 5:
		return {"seams": [], "moves": {}}
	var rs := rates(fr, per_rate)
	var pos := {}
	for b: String in KEY_BONES:
		var arr := PackedVector3Array()
		arr.resize(n)
		pos[b] = arr
	var rot := {}
	for b: String in KEY_BONES:
		rot[b] = []
	var cap := PackedVector3Array()
	var cam := PackedVector3Array()
	for i in n:
		var f: Dictionary = fr[i]
		var sk: Transform3D = f.sk
		for b: String in KEY_BONES:
			var gt := sk * (f.globals[int(_bone_idx[b])] as Transform3D)
			pos[b][i] = gt.origin
			(rot[b] as Array).append(gt.basis.orthonormalized().get_rotation_quaternion())
		cap.append(f.capsule)
		cam.append(f.camera)
	var d2 := func(arr: PackedVector3Array, i: int) -> float:
		if i < 2 or i >= arr.size():
			return 0.0
		var r := maxf(maxf(rs[i], rs[i - 1]), rs[i - 2])
		return (arr[i] - 2.0 * arr[i - 1] + arr[i - 2]).length() / (r * r)
	# Seam frames: content key or mode changes.
	var seams := []
	for i in range(1, n):
		var a: Dictionary = fr[i - 1]
		var b: Dictionary = fr[i]
		if (a.key != b.key or a.mode != b.mode) and i >= 3:
			var trav := not (str(a.key).begins_with("loco:") and str(b.key).begins_with("loco:"))
			seams.append({"frame": i, "traversal": trav, "moves": [str(a.get("move_or_last", a.move)).get_slice(":", 0), str(b.get("move_or_last", b.move)).get_slice(":", 0), "loco"], "from": str(a.key), "to": str(b.key), "mode": "%s>%s" % [a.mode, b.mode],
					"fade": float(b.fade), "move": str(b.move if b.move != "" else a.move).get_slice(":", 0)})
	var seam_frames := {}
	var res := []
	for si in seams.size():
		var s: Dictionary = seams[si]
		var i0 := int(s.frame)
		var i1 := mini(n - 1, i0 + int(ceil(float(s.fade) * fps)) + 2)
		# A seam's window ends before the next seam: that seam is measured under its own rules (a
		# fall exit's fade window ran into the landing's impact, which the landing seam exempts).
		if si + 1 < seams.size():
			i1 = mini(i1, maxi(i0, int(seams[si + 1].frame) - 1))
		for k in range(i0 - 2, i1 + 1):
			seam_frames[k] = true
		var worst := {"pelvis": 0.0, "headb": 0.0, "limbs": 0.0, "capsule": 0.0, "camera": 0.0, "ang": 0.0}
		var limb_at := ""
		var limb_frame := -1
		var pelvis_frame := i0
		for k in range(maxi(2, i0 - 1), i1 + 1):
			if d2.call(pos.pelvis, k) > float(worst.pelvis):
				pelvis_frame = k
			worst.pelvis = maxf(worst.pelvis, d2.call(pos.pelvis, k))
			worst.headb = maxf(worst.headb, d2.call(pos.headb, k))
			for b in ["l_palm", "r_palm", "l_ball", "r_ball", "l_heel", "r_heel", "l_knee", "r_knee", "l_elbow", "r_elbow"]:
				var v: float = d2.call(pos[b], k)
				if v > float(worst.limbs):
					worst.limbs = v
					limb_at = b
					limb_frame = k
			worst.capsule = maxf(worst.capsule, d2.call(cap, k))
			worst.camera = maxf(worst.camera, d2.call(cam, k))
			for b: String in KEY_BONES:
				var q0: Quaternion = rot[b][k - 1]
				var q1: Quaternion = rot[b][k]
				worst.ang = maxf(worst.ang, q0.angle_to(q1) * fps / maxf(rs[k], rs[k - 1]))
		var vel := func(arr: PackedVector3Array, a: int, b: int) -> Vector3:
			a = clampi(a, 0, arr.size() - 1)
			b = clampi(b, 0, arr.size() - 1)
			return (arr[b] - arr[a]) * (fps / maxf(b - a, 1))
		# Velocity jump straddling the seam frame (3-frame means just before and just after).
		var r_s := 1.0
		for k in range(maxi(0, i0 - 4), mini(n, i0 + 4)):
			r_s = maxf(r_s, rs[k])
		var dv_p: float = ((vel.call(pos.pelvis, i0, i0 + 3) as Vector3) - (vel.call(pos.pelvis, i0 - 4, i0 - 1) as Vector3)).length() / (r_s * r_s)
		var dv_c: float = ((vel.call(cap, i0, i0 + 3) as Vector3) - (vel.call(cap, i0 - 4, i0 - 1) as Vector3)).length() / (r_s * r_s)
		s["pelvis_d2"] = worst.pelvis
		s["head_d2"] = worst.headb
		s["limb_d2"] = worst.limbs
		s["limb_at"] = limb_at
		s["limb_frame"] = limb_frame
		s["pelvis_frame"] = pelvis_frame
		s["capsule_d2"] = worst.capsule
		s["camera_d2"] = worst.camera
		s["ang_max"] = worst.ang
		s["pelvis_dv"] = dv_p
		s["capsule_dv"] = dv_c
		res.append(s)
	# The moves' own (non-seam) maxima, which widen the seam tolerances: measured on the pose AS
	# ANIMATED (before TravInertializer and TraversalIK; fix round 3, 2026-09-25: measured on the final
	# pose, the IK's own pops widened the tolerances of the seams they sat next to). Frames recorded
	# without the captures fall back to the final pose.
	var nat := {}
	var rawpos := {}
	var rawrot := {}
	for b: String in KEY_BONES:
		var kb := POP_BONES.find(b)
		var arr2 := PackedVector3Array()
		arr2.resize(n)
		var qs := []
		qs.resize(n)
		for i in n:
			var f: Dictionary = fr[i]
			if f.has("raw_p") and kb >= 0:
				arr2[i] = (f.raw_p as PackedVector3Array)[kb]
				qs[i] = (f.raw_q as Array)[kb]
			else:
				arr2[i] = pos[b][i]
				qs[i] = rot[b][i]
		rawpos[b] = arr2
		rawrot[b] = qs
	for k in range(2, n):
		if seam_frames.has(k):
			continue
		var mv := str((fr[k] as Dictionary).move).get_slice(":", 0)
		if mv == "":
			mv = "loco"
		if not nat.has(mv):
			nat[mv] = {"pelvis_d2": 0.0, "limb_d2": 0.0, "capsule_d2": 0.0, "ang": 0.0}
		for b: String in KEY_BONES:
			nat[mv].ang = maxf(nat[mv].ang, (rawrot[b][k - 1] as Quaternion).angle_to(rawrot[b][k]) * fps / maxf(rs[k], rs[k - 1]))
		nat[mv].pelvis_d2 = maxf(nat[mv].pelvis_d2, d2.call(rawpos.pelvis, k))
		nat[mv].capsule_d2 = maxf(nat[mv].capsule_d2, d2.call(cap, k))
		for b in ["l_palm", "r_palm", "l_ball", "r_ball", "l_heel", "r_heel", "l_knee", "r_knee", "l_elbow", "r_elbow"]:
			nat[mv].limb_d2 = maxf(nat[mv].limb_d2, d2.call(rawpos[b], k))
	return {"seams": res, "natural": nat, "pos": pos}


## Frame-by-frame dump around a frame (debugging a seam).
func dump(fr: Array, pos: Dictionary, bone: String, center: int, span := 4) -> void:
	for k in range(maxi(0, center - span), mini(fr.size(), center + span + 1)):
		var f: Dictionary = fr[k]
		var pins := []
		for p: Dictionary in f.pins:
			pins.append("%s:%.2f" % [p.limb, float(p.weight)])
		print("      f%d %s key %s w_in %.2f t_move %.3f %s pos %s pins %s ik %s" % [k, f.mode, f.key, float(f.w_in), float(f.t_move),
				bone, str(pos[bone][k]), pins, f.ik_report])


static func fmt(v: Variant, digits := 3) -> String:
	if v == null:
		return "-"
	if v is float and (is_inf(v) or is_nan(v)):
		return "-"
	return ("%." + str(digits) + "f") % float(v)
