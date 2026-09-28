class_name TraversalIK
extends SkeletonModifier3D
## Contact IK for traversal (design 8.4; user fix 2026-09-24: planted palm or foot within 2 cm of
## the surface, no penetration beyond 1 cm). A SkeletonModifier3D placed after the animation
## (AnimationPlayer / AnimationTree write the pose first) and before CharacterBodyMesh, which
## keeps itself the last modifier (it drives the helper bones from the final pose).
##
##   var ik := TraversalIK.new(); skeleton.add_child(ik)      # the body modifier moves behind it
##   ik.pins = path.pins_at(t)      # [{limb, weight, mode: "plant", shape (TravSurfaces)}]
##   ik.guards = path.guard_shapes  # shapes no hand / foot may enter
##
## Every limb is measured on its RENDERED surface: the mesh-calibrated probe vertices
## (TravContactProbes: palm and fingers, shoe sole) evaluated with the body's skin weights.
##   plant  the lowest probe point that lies over the surface's top is moved onto it (a hand that
##          would hang over a box edge is first slid onto the top's footprint), blended by weight;
##   guard  any probe point inside a guard shape is pushed out along the surface normal.
##   lift   a fixed upward offset of a free limb (TravMomentum: a palm that lets go of the top early, at speed,
##          lifted off it instead of skimming along it), added to the limb's other pins as they fade.
##   hold   (world-locked contact; user complaints "snapping" and "planted slide", 2026-09-24)
##          while a plant or lip grip is at full weight, the vertex that touched when the plant
##          began keeps its WORLD position along the surface: the body moves under the planted palm
##          or sole (root and pose inertialization at seams, a reconstructed path that drifts, a
##          clip whose planted limb creeps). A heel or toe that rolls off the surface hands the
##          hold to the vertex that touches then, where it is; a clip that drags its planted limb
##          farther than HOLD_MAX_M drags the hold point along (no spring back at the release).
##          The hold fades with the pin's weight at the release.
## The limb moves by an analytic two-bone solve (shoulder-elbow-wrist, hip-knee-ankle); the
## wrist / ankle keeps its animated world rotation and the fingers and toes follow rigidly, so
## the pose of the hand or foot is the clip's. With no pins and no guards the pose is untouched.

const CHAINS := {
	"l_hand": ["l_shoulder", "l_elbow", "l_wrist"],
	"r_hand": ["r_shoulder", "r_elbow", "r_wrist"],
	"l_foot": ["l_upper_leg", "l_knee", "l_ankle"],
	"r_foot": ["r_upper_leg", "r_knee", "r_ankle"],
}
const SKIN := 0.003          ## planted surfaces sit this far under the probes (touching, not floating)
## ... and a hand this much more: the probes of the thumb base and the wrist's heel ride the forearm
## twist helpers, which only CharacterBodyMesh drives (after this modifier) and the probes stand the
## wrist in for; the rendered vertices sat up to 0.9 cm below where the probes said (fix round 3).
const HAND_SKIN := 0.006
const HAND_FOOTPRINT_M := 0.04
const GUARD_LIMBS := ["l_hand", "r_hand", "l_foot", "r_foot"]
const GUARD_ITERS := 2
const GUARD_REACH_M := 0.32      ## end bone to the farthest guard vertex (fingertips / toes) + margin (any limb)
## ... per limb (perf 2026-09-25: the dense guard sets reach 0.155 m from the wrist and 0.206 m from
## the ankle on the ladder, 3 m climb and sprint vault routes; + 4.5 cm for a frame's corrections)
const GUARD_REACH_HAND_M := 0.2
const GUARD_REACH_FOOT_M := 0.25
const JUMP_SPEED := 4.0          ## m/s: faster changes of a limb's correction (3.3 cm per frame at 120 Hz) are eased as jumps
## A jump of a limb's (weighted) correction is inertialized over EASE_S: a pin that switches
## surface or rung, starts or ends at full weight, a hold that re-locks, the lowest vertex that
## switches (user complaint "snapping", 2026-09-24: a ladder hub's grip pulled the hand 24 cm in one
## frame, an old exponential ease let 28 % of a jump through in the first frame).
const EASE_S := 0.15
const GRIP_EDGE_M := 0.0
## Centre of the closed fist's hole in the wrist bone's frame: the largest empty circle of the
## RENDERED hand (every vertex, projected along the rung) that the fist encloses, measured over the
## holds of the ladder clips (idle, climb-up / -down, the fast cycles, the ^idle stops; contact pass
## 2026-09-25). The hole's radius is 1.1-1.7 cm and its centre moves +-0.6 cm between the clips:
## a grip pin carries its clip's own centre (grip_offset, data/traversal/ladder_grips.json via
## the runtime table), this is the default. A rung of radius 1.0 cm (the course's, TravLaneClimb.RUNG_R) sits in the fist.
## (The offsets used before put a point 7 cm outside the fist on the rung: the fists floated on top
## of and behind the rungs.)
const GRIP_OFFSET := {"l_hand": Vector3(0.0011, -0.0462, 0.0578), "r_hand": Vector3(0.0009, 0.0427, -0.0581)}
const HOLD_W := 0.999            ## a plant is held from full weight on
const HOLD_MAX_M := 0.06         ## farther than this the hold point is dragged along with the clip
const ROLL_M := 0.01             ## the held vertex has rolled off when it is this far above the lowest

var pins: Array = []
var guards: Array = []
## World-locked plants (see "hold" above); off = the plants only correct the height.
var hold := true
## Tests: keep the final skeleton-space globals of every bone (after this modifier), and call
## `recorder` (Callable(globals: Array, skeleton_xform: Transform3D)) every update.
var record_globals := false
var last_globals: Array = []
var last_skeleton_xform := Transform3D.IDENTITY
var recorder: Callable
## Diagnostics of the last update: limb -> {gap_before, gap_after, corr}.
var report := {}
var probes: TravContactProbes
var cost_usec := 0
## Set by the actor while the body falls toward the ground: the IK measures the lowest point of the
## soles as the animation poses them (before any correction), world height, in sole_min_y (INF when
## not measured). The actor lifts the falling pose so its feet meet the ground as the capsule does.
var measure_soles := false
var sole_min_y := INF
## Exit holds (pins with exit_hold, TraversalController._exit_holds): a standing foot held through
## the hand-back is let go over EXIT_REL_S once the locomotion lifts its sole more than EXIT_LIFT_M
## above the surface (measured before the correction, the frame before).
const EXIT_LIFT_M := 0.02
const EXIT_REL_S := 0.12
var _exit_rel := {}              ## pin id -> seconds since its foot lifted (absent: not lifted)
var _exit_gap := {}              ## pin id -> the foot's gap above its surface last frame

var _bones := {}
var _key := ""
var _corr_prev := {}
var _holds := {}                 ## limb -> {id, i (probe vertex), p (world point), d (last hold correction)}
var _pole := {}                  ## limb -> {frame, base (last frame's side), pole (this frame's)}: the bend side (skeleton space)
var _guard_face := {}            ## "limb|shape" -> the face (world normal) the limb was pushed out through
var _guard_rel := {}             ## limb -> {prev (last push), rem0, t}: an ended guard push easing out
var _guard_tr := {}              ## "limb|shape" -> {v_old, t, frame}: a push moving over to another face
var _guard_last := {}            ## "limb|shape" -> the push applied last frame
var _fist_last := {}             ## hand -> the rung its grip pin holds (or held last)
var _fist_releasing := {}        ## hand -> true: its grip ended, its fingers may still wrap the rung
var _jc := {}                    ## limb -> added-motion limit state {frame, a (applied joint corrections), bo (B, C shown), bp (B, C animated), prev}
var _pre_rot := {}               ## limb -> [upper, lower, end] local rotations as the IK received them this update
const GUARD_REL_M := 0.01        ## a guard push that drops by more than this in a frame is eased out
const POLE_MIN_M := 0.03         ## a joint closer than this to the root-end line gives no reliable bend side
const POLE_RATE := 8.0           ## rad/s: the solved bend side turns toward the clip's at most this fast
## ... and while a correction moves the limb (contact pass 2026-09-25: the side kept while the 3 m
## climb's arm hung straight snapped 90 deg onto the clip's when the arm bent again, the elbow
## turned at 189 rad/s, a 22 cm jump in one frame)
const POLE_RATE_CORR := 20.0
const POLE_SETTLED_M := 0.01     ## a joint this close to the limb's line shows no side worth turning back to
const STICKY_M := 0.06           ## a guard keeps its push face until another face is this much shallower
const ARRIVAL_REACH_M := 0.06    ## a hand planted on a box is lifted this far before it crosses the side face
const GUARD_SWITCH_IN_S := 0.05  ## a push that changes face: the new face's push comes in over this ...
const GUARD_SWITCH_OUT_S := 0.08 ## ... then the old face's goes over this
## Added-motion limit (fix round 3, 2026-09-25; review: the IK's corrections made single-frame knee /
## elbow snaps inside moves the seam checks never looked at: a foot guard release dropped the tall
## vault's knee correction 5.7 cm in one frame, a sole pushed 5 mm out of a rung top bent a nearly
## straight leg 4-6 cm, a grip switch turned the shoulder at 31 rad/s). After every correction of a
## frame, each chain's upper and lower joint corrections (the local rotations produced against the ones
## received, as rotation vectors) are moved from last frame's toward this frame's solve only as far as
## keeps the knee / elbow and the ankle / wrist moving at most JOINT_V faster than the animation moves
## them (skeleton space). A correction that cancels the animation's motion (a planted foot held while
## the clip's foot slides, a guard holding a sinking sole on the ground) is not limited; one that ADDS
## motion (a push that starts or ends in a frame, a straight leg bent several cm for a few mm at the
## sole, a bend side that flips) is spread over the frames it needs. The end bone keeps the world
## rotation the solve gave it.
const JOINT_V := 1.8             ## m/s: 1.5 cm per frame at 120 Hz on top of the animation's own motion
const JOINT_W := 12.0            ## rad/s: ... and the upper / lower bone turn at most this much faster than the animation turns them


## The move clock's rate of the content the IK corrects (TravMomentum; TravPreviewActor.time_scale): its
## eases and added-motion limits are times and speeds of the move's clock, so on a clock 3x as fast they
## run 3x as fast in real time (held to their real-time values, the plants of a vault at speed lagged:
## palms 6-7 cm off the top at the sprint vault's plant).
var time_scale := 1.0


## True while a plant pin holds `limb` at full weight.
func _planted_full(limb: String) -> bool:
	for p: Dictionary in pins:
		if str(p.get("limb", "")) == limb and float(p.get("weight", 0.0)) >= HOLD_W and str(p.get("mode", "plant")) == "plant":
			return true
	return false


## Seconds of the move's clock this frame.
func _dt() -> float:
	return maxf(get_process_delta_time(), 1.0 / 240.0) * maxf(time_scale, 1.0)


func _ready() -> void:
	probes = TravContactProbes.shared()


## Forget every per-limb state (eased corrections, holds, bend sides, guard faces): the body was
## placed elsewhere (a teleport).
func reset() -> void:
	_guard_rel.clear()
	_corr_prev.clear()
	_holds.clear()
	_pole.clear()
	_guard_face.clear()
	_guard_tr.clear()
	_guard_last.clear()
	_fist_last.clear()
	_fist_releasing.clear()
	_jc.clear()
	_exit_rel.clear()
	_exit_gap.clear()


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var t0 := Time.get_ticks_usec()
	report.clear()
	sole_min_y = INF
	if measure_soles and probes != null and probes.ok:
		var gxs := sk.global_transform
		for fl: String in ["l_foot", "r_foot"]:
			for v in probes.eval_world(fl, sk, gxs):
				sole_min_y = minf(sole_min_y, v.y)
	if (not pins.is_empty() or not guards.is_empty() or not _corr_prev.is_empty() or not _guard_rel.is_empty() or not _pole.is_empty() \
			or not _jc.is_empty()) and influence > 0.0 and probes != null and probes.ok:
		if _bones.is_empty():
			for limb: String in CHAINS:
				var ids := []
				for bn: String in CHAINS[limb]:
					ids.append(sk.find_bone(bn))
				_bones[limb] = ids
		# The pose as received (the joint easing at the end measures the corrections against it).
		for limb: String in CHAINS:
			var idr: Array = _bones[limb]
			if idr.has(-1):
				continue
			_pre_rot[limb] = [sk.get_bone_pose_rotation(idr[0]), sk.get_bone_pose_rotation(idr[1]), sk.get_bone_pose_rotation(idr[2])]
		var gx := sk.global_transform
		var inv := gx.affine_inverse()
		var done := {}
		var active := {}
		for pin: Dictionary in pins:
			active[str(pin.limb)] = true
		for limb: String in _holds.keys():
			if not active.has(limb):
				_holds.erase(limb)
		# Limbs whose pin ended: their last correction is inertialized out over EASE_S (all of it,
		# not only the part faster than JUMP_SPEED: a released foot's 6 cm correction dropped 3 cm in
		# one frame at the standing mantle's exit, the knee swung 7 cm).
		for limb: String in _corr_prev.keys():
			if active.has(limb) or not CHAINS.has(limb):
				continue
			_release(limb)
			var rest := _ease(limb, Vector3.ZERO)
			if rest.length() < 1e-4 and float((_corr_prev[limb] as Dictionary).t) >= EASE_S:
				_corr_prev.erase(limb)
				continue
			_move_limb(sk, limb, inv.basis * rest, 1.0)
		# Per limb, every pin's correction weighted by its pin weight (a limb can have two pins
		# while the actor fades one content's plants out and the next one's in: the IK targets
		# crossfade instead of switching), then eased as one correction.
		var by_limb := {}
		for pin: Dictionary in pins:
			var limb := str(pin.limb)
			if not CHAINS.has(limb) or pin.get("shape") == null:
				continue
			if not by_limb.has(limb):
				by_limb[limb] = []
			(by_limb[limb] as Array).append(pin)
		for limb: String in by_limb:
			var total := Vector3.ZERO
			var any := false
			# Only the strongest pin of a limb drives its hold (a lift never does: the plant it follows keeps it).
			var lead: Dictionary = by_limb[limb][0]
			for pin: Dictionary in by_limb[limb]:
				if str(pin.get("mode", "plant")) != "lift" and (str(lead.get("mode", "plant")) == "lift" \
						or float(pin.get("weight", 0.0)) > float(lead.get("weight", 0.0))):
					lead = pin
			var limb_pts := PackedVector3Array()     # (skinned once per limb, shared by its pins)
			for pin: Dictionary in by_limb[limb]:
				var w := clampf(float(pin.get("weight", 1.0)), 0.0, 1.0) * influence
				if bool(pin.get("exit_hold", false)):
					var pid := str(pin.get("id", ""))
					if not _exit_rel.has(pid) and float(_exit_gap.get(pid, 0.0)) > EXIT_LIFT_M:
						_exit_rel[pid] = 0.0
					if _exit_rel.has(pid):
						if int(_exit_gap.get(pid + "|f", -1)) != Engine.get_process_frames():
							_exit_rel[pid] = float(_exit_rel[pid]) + _dt()
						# (Below full weight from the first frame of the release: a lifting foot is no plant.
						# The pin shows the weight it has now: the tests read it.)
						if not pin.has("w0"):
							pin["w0"] = float(pin.get("weight", 1.0))
						w = clampf(float(pin.w0), 0.0, 1.0) * influence * minf(0.99, 1.0 - smoothstep(0.0, EXIT_REL_S, float(_exit_rel[pid])))
						pin["weight"] = w
				if w <= 0.0:
					continue
				if limb_pts.is_empty() and not str(pin.get("mode", "plant")) in ["grip", "lift"]:
					limb_pts = _world_probes(sk, gx, limb)
				var r := _pin_correction(sk, gx, limb, pin, w, pin == lead, limb_pts)
				if bool(pin.get("exit_hold", false)) and (r.get("report", {}) as Dictionary).has("gap_before"):
					_exit_gap[str(pin.get("id", ""))] = float(r.report.gap_before)
					_exit_gap[str(pin.get("id", "")) + "|f"] = Engine.get_process_frames()
				if not bool(r.ok):
					continue
				any = true
				total += (r.corr as Vector3) * w
				var rep: Dictionary = r.report
				if not report.has(limb) or w >= 0.5:
					report[limb] = rep
			if not any:
				_release(limb)
			var out := _ease(limb, total if any else Vector3.ZERO)
			if out.length() > 1e-5:
				_move_limb(sk, limb, inv.basis * out, 1.0)
			if any:
				done[limb] = true
				if report.has(limb):
					(report[limb] as Dictionary)["corr"] = out.length()
		# The shape each limb is being planted on (a guard of the same shape pushes that limb out
		# through its top: the plant lifts the hand onto the top, a guard that pushed it back out of
		# the front face fought the plant and the hand jumped when the plant won, a 10 cm palm pop).
		var planting := {}
		# The box a hand grips by its lip: a guard of that box pushes the hand out through its top
		# when that is the shallower way out (the fingers wrap over the lip; a fingertip that dipped
		# a few mm under the top was pushed out through the FACE by the depth of the grip: the 3 m
		# climb's right palm jumped 5.6 cm off the lip at the hang -> climb-up join), and through
		# the face otherwise (a hand still rising along the face before the catch).
		var gripping := {}
		# The rung a fist closes on (grip): its guard would push the fingers off the rung they
		# wrap (contact pass 2026-09-25: the ladder's rungs are guards for the limbs passing them).
		var fisted := {}
		for pin: Dictionary in pins:
			if float(pin.get("weight", 0.0)) > 0.0 and pin.get("shape") != null and str(pin.get("mode", "plant")) == "plant":
				planting[str(pin.limb)] = str((pin.shape as Dictionary).get("name", ""))
			elif float(pin.get("weight", 0.0)) > 0.0 and pin.get("shape") != null and str(pin.get("mode", "")) == "lip":
				gripping[str(pin.limb)] = str((pin.shape as Dictionary).get("name", ""))
			elif float(pin.get("weight", 0.0)) > 0.0 and pin.get("shape") != null and str(pin.get("mode", "")) == "grip":
				fisted["%s|%s" % [str(pin.limb), str((pin.shape as Dictionary).get("name", ""))]] = true
				_fist_last[str(pin.limb)] = str((pin.shape as Dictionary).get("name", ""))
				_fist_releasing.erase(str(pin.limb))
		# A fist that has just let go of its rung is not pushed off it while its fingers still wrap
		# it (pushed out by the guard, the opening hand jumped 2-3 cm in a frame): its guard applies
		# again once the hand is clear of that rung.
		for limb2: String in _fist_last.keys():
			if not fisted.has("%s|%s" % [limb2, _fist_last[limb2]]):
				fisted["%s|%s" % [limb2, _fist_last[limb2]]] = true
				_fist_releasing[limb2] = true
		# Guards (cost: the dense guard sets are skinned on the CPU): a limb whose end bone is
		# farther than GUARD_REACH_M from every guard shape cannot touch it and is skipped; a
		# limb's points are skinned once per iteration and moved with its corrections; the second
		# iteration only revisits the limbs the first one corrected.
		var todo: Array = GUARD_LIMBS.duplicate()
		var gsum := {}
		var frame_now := Engine.get_process_frames()
		var dt_now := _dt()
		for it in GUARD_ITERS:
			var again := []
			for limb: String in todo:
				var end_w := gx * sk.get_bone_global_pose(int(_bones[limb][2])).origin
				var near := []
				var released_rung := str(_fist_last.get(limb, "")) if _fist_releasing.has(limb) and it == 0 else ""
				for shape: Dictionary in guards:
					if released_rung != "" and str(shape.get("name", "")) == released_rung:
						# (Clear of the rung it let go of: its guard is on again from the next frame.)
						var pts_r := _world_probes(sk, gx, _guard_set(limb))
						if float(TravSurfaces.penetration(shape, pts_r).depth) <= 0.0005:
							_fist_last.erase(limb)
							_fist_releasing.erase(limb)
						continue
					if float(TravSurfaces.sdf(shape, end_w)[0]) < (GUARD_REACH_HAND_M if limb.ends_with("hand") else GUARD_REACH_FOOT_M) \
							and not fisted.has("%s|%s" % [limb, str(shape.get("name", ""))]):
						near.append(shape)
				if near.is_empty():
					continue
				var pts2 := _world_probes(sk, gx, _guard_set(limb))
				var chain_root := gx * sk.get_bone_global_pose(int(_bones[limb][0])).origin
				# (The bounding sphere of the limb's points: a near shape it does not reach is not
				# tested point by point; perf 2026-09-25, the ladder's rungs.)
				var bc := Vector3.ZERO
				for v in pts2:
					bc += v
				bc /= maxf(1.0, float(pts2.size()))
				var br2 := 0.0
				for v in pts2:
					br2 = maxf(br2, bc.distance_squared_to(v))
				var br := sqrt(br2)
				for shape: Dictionary in near:
					var gkey := "%s|%s" % [limb, str(shape.get("name", ""))]
					# (A hand planted on a box is lifted up to ARRIVAL_REACH_M in front of its face.)
					var reach_s := br + (ARRIVAL_REACH_M if limb.ends_with("hand") and str(shape.type) == "box" else 0.0) + 0.001
					if float(TravSurfaces.sdf(shape, bc)[0]) > reach_s:
						if it == 0:
							_guard_face.erase(gkey)
							_guard_tr.erase(gkey)
							_guard_last.erase(gkey)
						continue
					var pen := TravSurfaces.penetration_from(shape, pts2, chain_root)
					if float(pen.depth) <= 0.0005 and it == 0 and limb.ends_with("hand") \
							and planting.get(limb, "") == str(shape.get("name", "")) and str(shape.type) == "box":
						# A hand arriving at the top it is planted on, still in front of the side face
						# and below the top: lifted in anticipation (see TravSurfaces.arrival_lift),
						# so the push up through the top that starts when it crosses the face starts
						# from zero.
						var lift := TravSurfaces.arrival_lift(shape, pts2, chain_root, ARRIVAL_REACH_M)
						if lift > 0.0005:
							pen = {"depth": lift, "n": ((shape.xform as Transform3D).basis.y).normalized(), "i": 0, "arrival": true}
					if float(pen.depth) <= 0.0005:
						if it == 0:
							_guard_face.erase(gkey)
							_guard_tr.erase(gkey)
							_guard_last.erase(gkey)
						continue
					# The face a limb is pushed out through stays the same while it is inside (the
					# entry face flips when the shoulder or hip crosses the top's plane: a hand
					# thrown 10-20 cm in one frame), unless another face is much shallower.
					var gf: Variant = _guard_face.get(gkey)
					var prev_face: Variant = gf
					if gf == null and str(shape.type) == "box" and not pen.has("arrival") and limb.ends_with("hand"):
						# A push that starts: out through the face the limb just crossed, the
						# shallowest (TravSurfaces.min_exit); the sticky rule below keeps it.
						pen = TravSurfaces.min_exit(shape, pts2)
					if planting.get(limb, "") == str(shape.get("name", "")) and str(shape.type) == "box":
						var up_n := ((shape.xform as Transform3D).basis.y).normalized()
						var d_up := TravSurfaces.depth_along(shape, pts2, up_n)
						if d_up >= 0.0:
							pen = {"depth": d_up, "n": up_n, "i": 0}
						gf = null
					elif planting.get(limb, "") == str(shape.get("name", "")) and str(shape.type) == "cyl":
						# A sole being planted on a rung: out through its top, like the plant (pushed
						# out of the nearest side, a foot arriving from below was thrown down, then up:
						# a 12 cm knee pop; contact pass 2026-09-25).
						var d_upc := TravSurfaces.depth_along(shape, pts2, Vector3.UP)
						if d_upc >= 0.0:
							pen = {"depth": d_upc, "n": Vector3.UP, "i": 0}
						gf = null
					elif gripping.get(limb, "") == str(shape.get("name", "")) and str(shape.type) == "box":
						var up_g := ((shape.xform as Transform3D).basis.y).normalized()
						var d_upg := TravSurfaces.depth_along(shape, pts2, up_g)
						# (A push already running keeps its face while it holds: the sticky rule below.)
						if d_upg >= 0.0 and d_upg <= float(pen.depth):
							pen = {"depth": d_upg, "n": up_g, "i": 0}
					if gf != null and (gf as Vector3).dot(pen.n) < 0.99:
						var d_keep := TravSurfaces.depth_along(shape, pts2, gf as Vector3)
						if d_keep >= 0.0 and d_keep <= float(pen.depth) + STICKY_M:
							pen = {"depth": d_keep, "n": gf, "i": 0}
					_guard_face[gkey] = pen.n
					var corr2 := (pen.n as Vector3) * (float(pen.depth) + SKIN + (HAND_SKIN if limb.ends_with("hand") else 0.0)) * float(shape.get("w", 1.0))
					# A push that changes its face (the sticky rule gave up, or a plant took over)
					# moves over in two phases instead of in one frame (a hand pushed 9 cm out of a
					# block's front, then 3 cm up through its top, jumped 10 cm; seam fix 2026-09-24):
					# the new face's push comes in while the old push is held as it was, then the old
					# one goes (with the new one complete, nothing is inside the shape).
					if prev_face != null and (prev_face as Vector3).dot(pen.n) < 0.99 and str(shape.type) == "box" \
							and it == 0 and _guard_last.has(gkey) and limb.ends_with("hand"):
						_guard_tr[gkey] = {"v_old": _guard_last[gkey], "t": 0.0, "frame": frame_now}
					var gt: Dictionary = _guard_tr.get(gkey, {})
					if not gt.is_empty() and it == 0:
						if int(gt.frame) != frame_now:
							gt.frame = frame_now
							gt.t = float(gt.t) + dt_now
						var tt := float(gt.t)
						if tt >= GUARD_SWITCH_IN_S + GUARD_SWITCH_OUT_S:
							_guard_tr.erase(gkey)
						else:
							var w_new := smoothstep(0.0, 1.0, tt / GUARD_SWITCH_IN_S)
							var w_old := 1.0 - smoothstep(0.0, 1.0, (tt - GUARD_SWITCH_IN_S) / GUARD_SWITCH_OUT_S)
							corr2 = corr2 * w_new + (gt.v_old as Vector3) * w_old
					if it == 0:
						_guard_last[gkey] = corr2
					_move_limb(sk, limb, inv.basis * corr2, influence)
					gsum[limb] = (gsum.get(limb, Vector3.ZERO) as Vector3) + corr2 * influence
					for i in pts2.size():
						pts2[i] += corr2 * influence
					bc += corr2 * influence
					if not again.has(limb):
						again.append(limb)
					var r: Dictionary = report.get(limb, {})
					r["guard"] = float(r.get("guard", 0.0)) + float(pen.depth)
					r["guard_at"] = "%s n%s" % [str(shape.get("name", "")), str((pen.n as Vector3).snapped(Vector3.ONE * 0.01))]
					report[limb] = r
			todo = again
			if todo.is_empty():
				break
		# A guard's push that ends (the limb came out of the shape: a hand rising above the top it
		# was pushed out of the front of) is inertialized out along its own direction instead of
		# dropping in one frame (the 1.5 m mantle's palm jumped 7.6 cm when it rose above the top).
		var dt := _dt()
		var frame := Engine.get_process_frames()
		for limb: String in GUARD_LIMBS:
			var g: Vector3 = gsum.get(limb, Vector3.ZERO)
			var st: Dictionary = _guard_rel.get(limb, {})
			if st.is_empty():
				if g == Vector3.ZERO:
					continue
				st = {"prev": Vector3.ZERO, "rem0": Vector3.ZERO, "t": EASE_S, "frame": -1}
				_guard_rel[limb] = st
			var rem: Vector3
			if int(st.frame) == frame:
				# Another skeleton update in the same frame (seeks): the same step again.
				rem = (st.rem0 as Vector3) * (1.0 - smoothstep(0.0, 1.0, float(st.t) / EASE_S))
			else:
				st.frame = frame
				var shown_prev: Vector3 = (st.prev as Vector3) + (st.rem0 as Vector3) * (1.0 - smoothstep(0.0, 1.0, float(st.t) / EASE_S))
				st.t = minf(float(st.t) + dt, EASE_S)
				rem = (st.rem0 as Vector3) * (1.0 - smoothstep(0.0, 1.0, float(st.t) / EASE_S))
				# (For a free hand, any drop of the push by more than GUARD_REL_M in a frame, not only
				# a push that nearly ended: a hand pushed 9 cm out of a block's front whose deep
				# points rose above the top dropped to a 2.6 cm push in one frame, a 6 cm palm pop;
				# the eased remainder only holds the limb further out, never inside. Feet and pinned
				# limbs keep the old rule: a held remainder lifted feet that were about to plant off
				# their surfaces and slid them while planted.)
				var drop_ok := g.length() < shown_prev.length() if (not active.has(limb) and limb.ends_with("hand")) \
						else g.length() < 0.3 * shown_prev.length()
				if drop_ok and (shown_prev - g - rem).length() > GUARD_REL_M:
					st.rem0 = shown_prev - g
					st.t = 0.0
					rem = st.rem0
				st.prev = g
			if rem.y > 0.0 and limb.ends_with("hand") and _planted_full(limb):
				# (A palm planted at full weight is not lifted off its surface by a guard's release:
				# the plant holds its height. The sprint vault at speed brought the hands to the top
				# through its front edge; the release of that push held them 5 cm over the top all
				# through the plant.)
				rem.y = 0.0
			if rem.length() > 1e-4:
				_move_limb(sk, limb, inv.basis * rem, 1.0)
				var rr: Dictionary = report.get(limb, {})
				rr["guard_release"] = rem.length()
				report[limb] = rr
			elif g == Vector3.ZERO and float(st.t) >= EASE_S:
				_guard_rel.erase(limb)
		# A limb that no correction touched this frame, whose solved bend side (last frame) is not
		# the clip's: the side keeps turning toward the clip's (a solve that only turns the joint
		# about the limb's line) until they agree, instead of snapping back when the last
		# correction ended (the tall vault's elbow, held on the far side while the arm was nearly
		# straight, jumped 8 cm when its guard release ended).
		for limb: String in _pole.keys():
			var ps: Dictionary = _pole[limb]
			var again_frame := int(ps.get("forced", -1)) == frame     # (another skeleton update this frame)
			if int(ps.frame) == frame and not again_frame:
				continue
			var last: Vector3 = ps.base if again_frame else ps.pole
			if (int(ps.frame) < frame - 1 and not again_frame) or not _bones.has(limb) or _pole_settled(sk, limb, last):
				_pole.erase(limb)
				continue
			_move_limb(sk, limb, Vector3.ZERO, 1.0, true)
			if _pole.has(limb):
				(_pole[limb] as Dictionary)["forced"] = frame
		_ease_joints(sk)
	cost_usec = Time.get_ticks_usec() - t0
	if record_globals or recorder.is_valid():
		last_globals = TravMeshContacts.live_globals(sk)
		last_skeleton_xform = sk.global_transform
		if recorder.is_valid():
			recorder.call(last_globals, last_skeleton_xform)


## Added-motion limit (see JOINT_V): per chain, the upper and lower joint corrections (rotation
## vectors of the local rotations produced against the ones received) move from last frame's toward
## this frame's solve by the largest share alpha (bisection) that keeps the knee / elbow (B), the
## ankle / wrist (C) and the far points of the foot / hand (ball and heel, middle fingertip and
## thumb tip, rigid with C) within JOINT_V * dt of the speed the animation moves them at, and the
## upper and lower bones' rotations within JOINT_W * dt of the animation's turn (WORLD space: what is
## seen; in skeleton space a body moving at 5 cm per frame hid a knee thrown 3.8 cm faster):
##   |B(alpha) - B_shown_last| <= |B_anim - B_anim_last| + JOINT_V dt   (and C, the far points)
##   angle(R(alpha), R_shown_last) <= angle(R_anim, R_anim_last) + JOINT_W dt   (upper, lower bone)
## (the position test alone let a forearm roll about its own axis at 33 rad/s at the 3 m climb's
## catch). A correction appearing on a limb that had none starts from the animation's pose. The end
## bone is re-set to the world rotation the solve gave it.
func _ease_joints(sk: Skeleton3D) -> void:
	var dt := _dt()
	var frame := Engine.get_process_frames()
	var lim := JOINT_V * dt
	var gw := sk.global_transform.orthonormalized()
	for limb: String in CHAINS:
		if not _pre_rot.has(limb):
			continue
		var ids: Array = _bones[limb]
		var pr: Array = _pre_rot[limb]
		var u0: Quaternion = pr[0]
		var l0: Quaternion = pr[1]
		var tu := _rotvec(sk.get_bone_pose_rotation(ids[0]) * u0.inverse())
		var tl := _rotvec(sk.get_bone_pose_rotation(ids[1]) * l0.inverse())
		var st: Dictionary = _jc.get(limb, {})
		var par := sk.get_bone_parent(int(ids[0]))
		# (World space: the chain's parent and root in the world, this frame.)
		var P := (gw.basis * (sk.get_bone_global_pose(par).basis if par >= 0 else Basis.IDENTITY)).orthonormalized()
		var A := gw * sk.get_bone_global_pose(int(ids[0])).origin
		var pl := sk.get_bone_pose_position(int(ids[1]))
		var pe := sk.get_bone_pose_position(int(ids[2]))
		# The far points of the hand / foot, rigid with C this frame (the end keeps its world rotation).
		var c_now := gw * sk.get_bone_global_pose(int(ids[2])).origin
		var far := PackedVector3Array()
		for fb: int in _far_bones(sk, limb):
			far.append(gw * sk.get_bone_global_pose(fb).origin - c_now)
		var pre := _chain_fk(P, A, pl, pe, u0, l0, far)
		if st.is_empty():
			if tu.length() < 1e-6 and tl.length() < 1e-6:
				continue
			st = {"frame": -1, "a": [Vector3.ZERO, Vector3.ZERO], "bo": pre, "bp": pre}
			st["prev"] = {"a": st.a, "bo": st.bo, "bp": st.bp}
			_jc[limb] = st
		if int(st.frame) != frame:
			# (A new frame: last frame's result is the base; another skeleton update in the same frame, a
			# seek, recomputes from the same base.)
			st.prev = {"a": st.a, "bo": st.bo, "bp": st.bp}
			st.frame = frame
		var pv: Dictionary = st.prev
		var a0: Array = pv.a
		var bo: Array = pv.bo
		var bp: Array = pv.bp
		if bo.size() != pre.size():
			bo = pre
			bp = pre
		var allow := []
		for k in pre.size():
			if k == 2 or k == 3:
				allow.append(_ang(pre[k], bp[k]) + JOINT_W * dt)
			else:
				allow.append(((pre[k] as Vector3) - (bp[k] as Vector3)).length() + lim)
		var du: Vector3 = tu - (a0[0] as Vector3)
		var dl: Vector3 = tl - (a0[1] as Vector3)
		var alpha := 1.0
		var fk := _chain_fk(P, A, pl, pe, _quat(tu) * u0, _quat(tl) * l0, far)
		if not _within(fk, bo, allow):
			var lo_a := 0.0
			var hi_a := 1.0
			for it in 8:
				var mid := (lo_a + hi_a) * 0.5
				var f2 := _chain_fk(P, A, pl, pe, _quat((a0[0] as Vector3) + du * mid) * u0, _quat((a0[1] as Vector3) + dl * mid) * l0, far)
				if not _within(f2, bo, allow):
					hi_a = mid
				else:
					lo_a = mid
			alpha = lo_a
		var au: Vector3 = (a0[0] as Vector3) + du * alpha
		var al: Vector3 = (a0[1] as Vector3) + dl * alpha
		if alpha < 1.0:
			var e_glob := sk.get_bone_global_pose(ids[2]).basis.orthonormalized()
			sk.set_bone_pose_rotation(ids[0], (_quat(au) * u0).normalized())
			sk.set_bone_pose_rotation(ids[1], (_quat(al) * l0).normalized())
			var gl := sk.get_bone_global_pose(ids[1]).basis.orthonormalized()
			sk.set_bone_pose_rotation(ids[2], (gl.inverse() * e_glob).get_rotation_quaternion())
			fk = _chain_fk(P, A, pl, pe, _quat(au) * u0, _quat(al) * l0, far)
			var rj: Dictionary = report.get(limb, {})
			rj["joint_alpha"] = alpha
			report[limb] = rj
		st.a = [au, al]
		st.bo = fk
		st.bp = pre
		if tu.length() < 1e-6 and tl.length() < 1e-6 and au.length() < 1e-5 and al.length() < 1e-5:
			_jc.erase(limb)


## Knee / elbow (B), ankle / wrist (C) and the upper and lower bones' global rotations of a chain
## whose upper bone sits at A under a parent of global basis P, for local rotations qu (upper) and ql
## (lower); pl, pe: the lower and end bones' local positions (skeleton space). [B, C, Ru, Rl].
static func _chain_fk(P: Basis, A: Vector3, pl: Vector3, pe: Vector3, qu: Quaternion, ql: Quaternion, far := PackedVector3Array()) -> Array:
	var Ru := P * Basis(qu.normalized())
	var B := A + Ru * pl
	var Rl := Ru * Basis(ql.normalized())
	var C := B + Rl * pe
	var out := [B, C, Ru.get_rotation_quaternion(), Rl.get_rotation_quaternion()]
	for o in far:
		out.append(C + o)
	return out


static func _ang(a: Quaternion, b: Quaternion) -> float:
	return a.angle_to(b)


## The shown chain `f` is within `allow` of last frame's shown chain `bo` (see _ease_joints).
static func _within(f: Array, bo: Array, allow: Array) -> bool:
	for k in f.size():
		if k == 2 or k == 3:
			if (f[k] as Quaternion).angle_to(bo[k]) > float(allow[k]):
				return false
		elif ((f[k] as Vector3) - (bo[k] as Vector3)).length() > float(allow[k]):
			return false
	return true


## The bones at the far end of a hand or foot (the limiter's far points): ball and heel, the middle
## fingertip and the thumb tip.
func _far_bones(sk: Skeleton3D, limb: String) -> Array:
	var key := limb + "|far"
	if not _bones.has(key):
		var sd := limb.substr(0, 2)
		var names := ["ball", "heel"] if limb.ends_with("foot") else ["middlec", "thumbc"]
		var ids := []
		for nm: String in names:
			var b := sk.find_bone(sd + nm)
			if b >= 0:
				ids.append(b)
		_bones[key] = ids
	return _bones[key]


static func _rotvec(q: Quaternion) -> Vector3:
	q = q.normalized()
	if q.w < 0.0:
		q = -q
	var s := Vector3(q.x, q.y, q.z).length()
	if s < 1e-9:
		return Vector3.ZERO
	return Vector3(q.x, q.y, q.z) / s * (2.0 * atan2(s, q.w))


static func _quat(r: Vector3) -> Quaternion:
	var a := r.length()
	if a < 1e-9:
		return Quaternion.IDENTITY
	return Quaternion(r / a, a)


## One pin's correction of its limb (unweighted, world): {ok, corr, report}. grip: the rung's axis
## through the fist's hole; lip: the hand's edge onto the lip, held along it; plant: the lowest
## point over the surface onto it (a hand hanging off the edge slid onto the top by its palm), the
## touching vertex held in place along the surface.
func _pin_correction(sk: Skeleton3D, gx: Transform3D, limb: String, pin: Dictionary, w: float, use_hold := true,
		probe_pts := PackedVector3Array()) -> Dictionary:
	var shape: Dictionary = pin.shape
	var mode := str(pin.get("mode", "plant"))
	if mode == "lift":
		return {"ok": true, "corr": Vector3.UP * float(pin.get("lift", 0.0)), "report": {"mode": "lift"}}
	if mode == "grip" and limb.ends_with("hand"):
		var wb := int(_bones[limb][2])
		var center := gx * (sk.get_bone_global_pose(wb) * (pin.get("grip_offset", GRIP_OFFSET[limb]) as Vector3))
		var a: Vector3 = shape.a
		var ab: Vector3 = (shape.b as Vector3) - a
		var on := a + ab * clampf((center - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var gcorr := on - center
		gcorr -= ab.normalized() * gcorr.dot(ab.normalized())
		# Held along the rung (world-locked like a plant; contact pass 2026-09-25: a fist whose clip
		# sways sideways slid 5.7 cm along its rung).
		if use_hold:
			gcorr += _hold(limb, pin, PackedVector3Array([center]), gcorr, 0, Vector3.UP, w, ab.normalized())
		return {"ok": true, "corr": gcorr, "report": {"mode": "grip", "surface": str(shape.get("name", "")), "hole_off": (on - center).length(),
				"hold": (gcorr - (on - center) + ab.normalized() * (on - center).dot(ab.normalized())).length()}}
	var pts := probe_pts.duplicate() if not probe_pts.is_empty() else _world_probes(sk, gx, limb)
	var corr := Vector3.ZERO
	if mode == "lip" and limb.ends_with("hand") and str(shape.type) == "box":
		var lraw := _lip_correction(sk, gx, limb, pts, shape, pin.get("into", Vector3.ZERO))
		var into: Vector3 = pin.get("into", Vector3.ZERO)
		into.y = 0.0
		# Held along the lip (the lip correction owns the depth and the height).
		var tan := Vector3.UP.cross(into).normalized() if into.length() > 1e-4 else Vector3.ZERO
		if tan != Vector3.ZERO and use_hold:
			lraw += _hold(limb, pin, pts, lraw, _lowest(pts), Vector3.UP, w, tan)
		return {"ok": true, "corr": lraw, "report": {"mode": "lip", "surface": str(shape.get("name", ""))}}
	if limb.ends_with("hand"):
		var palm := gx * sk.get_bone_global_pose(_palm_bone(sk, limb)).origin
		corr = TravSurfaces.footprint_push(shape, palm, float(pin.get("footprint", HAND_FOOTPRINT_M)))
		if corr != Vector3.ZERO:
			for i in pts.size():
				pts[i] += corr
	elif shape.has("foot_band"):
		# A foot on a narrow beam, log or branch (contact pass 2026-09-25): the sole's centre is
		# slid sideways onto the walkable band of the top (the balance clips step up to 0.2 m
		# beside their line; on a log that foot stood on the flank, 2.4 cm off the surface).
		corr = TravSurfaces.band_push(shape, pts, float(shape.foot_band))
		if corr != Vector3.ZERO:
			for i in pts.size():
				pts[i] += corr
	# (A rung is planted on from above: measured radially over its whole upper half, the touching
	# point jumped between the front and the back of the rung as a lifting foot left it, and the
	# plant pushed the foot 2-3 cm forward and back on alternate frames, ladder cycles.)
	var tg := TravSurfaces.top_gap(shape, pts, 0.0, true)
	if int(tg.over) == 0:
		return {"ok": false}
	var pushed := corr     # (already applied to pts)
	var dn := SKIN * 0.5 + (HAND_SKIN if limb.ends_with("hand") else 0.0) - float(tg.gap)
	if bool(pin.get("exit_hold", false)):
		# (A held exit foot the locomotion lifts is not pulled down by more than EXIT_LIFT_M while its
		# hold lets go: pulled onto the surface all the way, a run's lifting foot was held 11 cm down
		# and the knee jumped 5 cm at the release; fix round 3.)
		dn = maxf(dn, SKIN * 0.5 - EXIT_LIFT_M)
	corr += (tg.n as Vector3) * dn
	if use_hold:
		corr += _hold(limb, pin, pts, corr - pushed, int(tg.i), tg.n, w)
	return {"ok": true, "corr": corr, "report": {"mode": "plant", "gap_before": float(tg.gap), "surface": str(shape.get("name", ""))}}


## A limb's correction ends (its pin ended, or no pin applies this frame): all of it is
## inertialized out over EASE_S from where it was.
func _release(limb: String) -> void:
	var st0: Dictionary = _corr_prev.get(limb, {})
	if st0.is_empty() or bool(st0.get("released", false)):
		return
	st0["released"] = true
	var out_prev: Vector3 = (st0.raw as Vector3) - (st0.rem0 as Vector3) * (1.0 - smoothstep(0.0, 1.0, float(st0.t) / EASE_S))
	st0.raw = Vector3.ZERO
	st0.rem0 = -out_prev
	st0.t = 0.0


## The applied (weighted) correction of a limb, continuous in time: a change faster than
## JUMP_SPEED is a jump, whose excess becomes a remainder that is inertialized away over EASE_S
## ((1 - smoothstep(t / EASE_S)): it starts with zero velocity), while continuous changes pass
## through unlagged (a filter on the correction itself would trail a moving plant by speed x
## lag, 2-3 cm on a landing or a ladder cycle). A limb's correction starts from zero and, when its
## pin ends, eases back to zero the same way.
func _ease(limb: String, raw: Vector3) -> Vector3:
	var dt := _dt()
	var st: Dictionary = _corr_prev.get(limb, {})
	if st.is_empty():
		st = {"raw": Vector3.ZERO, "rem0": Vector3.ZERO, "t": EASE_S, "frame": -1}
		_corr_prev[limb] = st
	if raw != Vector3.ZERO:
		st["released"] = false
	var frame := Engine.get_process_frames()
	if int(st.frame) == frame:
		# A second skeleton update in the same frame: the same step again.
		return raw - (st.rem0 as Vector3) * (1.0 - smoothstep(0.0, 1.0, float(st.t) / EASE_S))
	st.frame = frame
	var d: Vector3 = raw - (st.raw as Vector3)
	var lim := JUMP_SPEED * dt
	var t := float(st.t) + dt
	var rem: Vector3 = (st.rem0 as Vector3) * (1.0 - smoothstep(0.0, 1.0, t / EASE_S))
	if d.length() > lim:
		st.rem0 = rem + (d - d.normalized() * lim)
		st.t = 0.0
		rem = st.rem0
	else:
		st.t = minf(t, EASE_S)
	st.raw = raw
	return raw - rem


## The world-locked hold of a planted limb (see "hold" in the header): the correction, along the
## surface (normal n; or only along `along` when given), that keeps the held vertex where it was
## when the plant reached full weight. pts: the limb's probes before `corr`, i_low: the lowest one.
func _hold(limb: String, pin: Dictionary, pts: PackedVector3Array, corr: Vector3, i_low: int, n: Vector3, w: float,
		along := Vector3.ZERO) -> Vector3:
	if not hold or i_low < 0 or i_low >= pts.size():
		return Vector3.ZERO
	var id := str(pin.get("id", ""))
	var frame := Engine.get_process_frames()
	var lk: Dictionary = _holds.get(limb, {})
	if lk.is_empty() or str(lk.id) != id:
		if w < HOLD_W:
			_holds.erase(limb)
			return Vector3.ZERO
		if not lk.is_empty() and int(lk.get("full", -9)) >= frame - 1:
			# The limb was held at full weight up to the last frame: the plant continues under the
			# next segment's pin (a chained beam / crawl / shimmy segment), with the same hold.
			lk.id = id
		else:
			_holds[limb] = {"id": id, "i": i_low, "p": pts[i_low] + corr, "d": Vector3.ZERO, "full": frame}
			return Vector3.ZERO
	if w >= HOLD_W:
		lk["full"] = frame
	var i := int(lk.i)
	var prev_d: Vector3 = lk.d
	if i != i_low and (pts[i] - pts[i_low]).dot(n) > ROLL_M:
		# Rolled off (heel up, toe off): the vertex that touches now is held where it is shown
		# (with last frame's hold applied, so the limb does not jump back).
		lk.i = i_low
		lk.p = pts[i_low] + corr + prev_d
		i = i_low
	var cur := pts[i] + corr
	var d: Vector3 = (lk.p as Vector3) - cur
	if along != Vector3.ZERO:
		d = along * d.dot(along)
	else:
		d -= n * d.dot(n)
	var l := d.length()
	# (A standing foot held through the hand-back stays where it stands, however far the idle pose
	# would put it: the legs follow by IK until the locomotion lifts it.)
	var hmax := float(pin.get("hold_max", HOLD_MAX_M))
	if l > hmax:
		# The clip drags its planted limb farther than a hold should stretch it: drag the hold
		# point along (a slow slide, not a spring back at the release).
		d *= hmax / l
		lk.p = cur + d
	lk.d = d
	return d


static func _lowest(pts: PackedVector3Array) -> int:
	var bi := -1
	var by := INF
	for i in pts.size():
		if pts[i].y < by:
			by = pts[i].y
			bi = i
	return bi


## Correction that puts a gripping hand's edge (GRIP_EDGE_M in front of the palm) on the box's
## lip: horizontally along `into` (the edge onto the face plane), vertically onto the top.
func _lip_correction(sk: Skeleton3D, gx: Transform3D, limb: String, pts: PackedVector3Array, shape: Dictionary, into: Vector3) -> Vector3:
	var xf: Transform3D = shape.xform
	var h: Vector3 = shape.half
	var top := (xf * Vector3(0, h.y, 0)).y
	into.y = 0.0
	if into.length() < 1e-4:
		return Vector3.ZERO
	into = into.normalized()
	# The face: the box side whose outward normal is -into.
	var loc := xf.basis.inverse() * -into
	var ax := 0 if absf(loc.x) >= absf(loc.z) else 2
	var off := Vector3.ZERO
	off[ax] = h[ax] * signf(loc[ax])
	var face_pt := xf * off
	var palm := gx * sk.get_bone_global_pose(_palm_bone(sk, limb)).origin
	var edge_d := (palm - face_pt).dot(into) - GRIP_EDGE_M
	var ye := INF
	for v in pts:
		if (v - face_pt).dot(into) >= edge_d:
			ye = minf(ye, v.y)
	if ye == INF:
		return Vector3.ZERO
	return -into * edge_d + Vector3.UP * (top - ye + SKIN * 0.5 + HAND_SKIN)


func _palm_bone(sk: Skeleton3D, limb: String) -> int:
	var key := limb + "_palm"
	if not _bones.has(key):
		_bones[key] = sk.find_bone(limb.substr(0, 1) + "_palm")
	return int(_bones[key])


## The probe set a limb's guards are checked with: the dense guard set (guard cells + the contact
## probes, TravContactProbes) when there is one.
func _guard_set(limb: String) -> String:
	if probes.has_limb(limb + "_dense_guard"):
		return limb + "_dense_guard"
	return limb + "_guard" if probes.has_limb(limb + "_guard") else limb


func _world_probes(sk: Skeleton3D, gx: Transform3D, limb: String) -> PackedVector3Array:
	return probes.eval_world(limb, sk, gx)


## Moves the limb's end bone by `delta` (skeleton space) with the two-bone chain, weight w.
func _move_limb(sk: Skeleton3D, limb: String, delta: Vector3, w: float, force := false) -> void:
	if delta.length() < 1e-5 and not force:
		return
	var ids: Array = _bones[limb]
	if ids.has(-1):
		return
	var end := sk.get_bone_global_pose(ids[2]).origin
	# The bend side (elbow / knee) must not flip between frames: a nearly straight limb, or a pose
	# blended between two bend directions, makes the side from the current joint unstable (a knee
	# swung 25 cm in one frame at the shimmy exit). The side of the last solve is kept unless the
	# joint's own side agrees with it, and while the joint's side is unreliable. When no correction
	# touches the limb any more (force: the pole-only solves at the end of the update), the kept
	# side turns toward the clip's at POLE_RATE instead of snapping to it (a side kept against the
	# clip's while the arm was nearly straight jumped the elbow 8 cm when the tall vault's last
	# tiny correction ended). (Turning at POLE_RATE while corrected lagged a lip hand's elbow
	# behind its moving line; its guards then pushed it 6 cm, the 3 m climb: while corrected the
	# side turns at the faster POLE_RATE_CORR.)
	var a := sk.get_bone_global_pose(ids[0]).origin
	var b := sk.get_bone_global_pose(ids[1]).origin
	var u := (end + delta - a).normalized()
	var side := (b - a) - u * (b - a).dot(u)
	var frame := Engine.get_process_frames()
	var st: Dictionary = _pole.get(limb, {})
	var base := Vector3.ZERO
	if not st.is_empty():
		if int(st.frame) == frame:
			base = st.base            # (another call this frame: from the same last-frame side)
		elif int(st.frame) == frame - 1:
			base = st.pole
	var target := side.normalized() if side.length() > POLE_MIN_M else Vector3.ZERO
	var pole := target
	if base != Vector3.ZERO:
		var bp := base - u * base.dot(u)
		bp = bp.normalized() if bp.length() > 1e-4 else Vector3.ZERO
		if target == Vector3.ZERO:
			pole = bp
		elif force and bp != Vector3.ZERO:
			# (No correction this frame: turn toward the clip's side.)
			var ang := bp.angle_to(target)
			var mx := POLE_RATE * _dt()
			if ang > mx:
				var axis := bp.cross(target)
				axis = axis.normalized() if axis.length() > 1e-4 else u
				pole = bp.rotated(axis, mx)
		elif bp != Vector3.ZERO and target.dot(bp) < 0.0:
			pole = bp
		elif bp != Vector3.ZERO:
			var ang2 := bp.angle_to(target)
			var mx2 := POLE_RATE_CORR * _dt()
			if ang2 > mx2:
				var axis2 := bp.cross(target)
				axis2 = axis2.normalized() if axis2.length() > 1e-4 else u
				pole = bp.rotated(axis2, mx2)
	if pole != Vector3.ZERO:
		pole = (pole - u * pole.dot(u))
		pole = pole.normalized() if pole.length() > 1e-4 else Vector3.ZERO
	if pole != Vector3.ZERO:
		_pole[limb] = {"frame": frame, "base": base, "pole": pole}
	solve_live(sk, ids[0], ids[1], ids[2], end, end + delta, w, pole)


## The clip's bend side of a limb agrees with `pole` (or the joint is too close to the limb's line
## for the side to show: under POLE_SETTLED_M).
func _pole_settled(sk: Skeleton3D, limb: String, pole: Vector3) -> bool:
	var ids: Array = _bones[limb]
	if ids.has(-1):
		return true
	var a := sk.get_bone_global_pose(ids[0]).origin
	var b := sk.get_bone_global_pose(ids[1]).origin
	var c := sk.get_bone_global_pose(ids[2]).origin
	var u := (c - a).normalized()
	var side := (b - a) - u * (b - a).dot(u)
	if side.length() < POLE_SETTLED_M:
		return true
	var pp := pole - u * pole.dot(u)
	return pp.length() < 1e-4 or pp.angle_to(side) < 0.02


## Two-bone solve on the live skeleton (skeleton space). `contact` is the current end-effector
## point; the end bone keeps its global rotation and moves rigidly with it.
static func solve_live(sk: Skeleton3D, ua: int, lb: int, ec: int, contact: Vector3, target: Vector3, w: float, pole_hint := Vector3.ZERO) -> void:
	var gu := sk.get_bone_global_pose(ua)
	var gl := sk.get_bone_global_pose(lb)
	var ge := sk.get_bone_global_pose(ec)
	var off := contact - ge.origin
	var res := solve(gu, gl, ge, target - off, pole_hint)
	if res.is_empty():
		return
	var pu := sk.get_bone_parent(ua)
	var parent_u := sk.get_bone_global_pose(pu) if pu >= 0 else Transform3D.IDENTITY
	var new_u: Transform3D = res.upper
	var new_l: Transform3D = res.lower
	var lu_old := sk.get_bone_pose_rotation(ua)
	var lu_new := (parent_u.basis.orthonormalized().inverse() * new_u.basis.orthonormalized()).get_rotation_quaternion()
	sk.set_bone_pose_rotation(ua, lu_old.slerp(lu_new, w))
	var gu2 := sk.get_bone_global_pose(ua)
	var ll_old := sk.get_bone_pose_rotation(lb)
	var ll_new := (gu2.basis.orthonormalized().inverse() * new_l.basis.orthonormalized()).get_rotation_quaternion()
	sk.set_bone_pose_rotation(lb, ll_old.slerp(ll_new, w))
	# End bone: keep the animated global rotation.
	var gl2 := sk.get_bone_global_pose(lb)
	var le := (gl2.basis.orthonormalized().inverse() * ge.basis.orthonormalized()).get_rotation_quaternion()
	sk.set_bone_pose_rotation(ec, le)


## Analytic two-bone IK on global transforms (skeleton space). Returns {upper, lower, end}
## transforms (end keeps its rotation) reaching as close to `t_end` as the bone lengths allow;
## the bend plane keeps the current elbow / knee side.
static func solve(gu: Transform3D, gl: Transform3D, ge: Transform3D, t_end: Vector3, pole_hint := Vector3.ZERO) -> Dictionary:
	var A := gu.origin
	var B := gl.origin
	var C := ge.origin
	var ab := A.distance_to(B)
	var bc := B.distance_to(C)
	if ab < 1e-4 or bc < 1e-4:
		return {}
	var at_vec := t_end - A
	var at_len := at_vec.length()
	if at_len < 1e-4:
		return {}
	var u := at_vec / at_len
	var d := clampf(at_len, absf(ab - bc) + 1e-4, ab + bc - 1e-4)
	var pole := (B - A) - u * (B - A).dot(u)
	if pole_hint != Vector3.ZERO:
		var ph := pole_hint - u * pole_hint.dot(u)
		if ph.length() > 1e-4:
			pole = ph
	if pole.length() < 1e-4:
		pole = (C - A).cross(Vector3.UP).cross(u)
		if pole.length() < 1e-4:
			pole = Vector3.FORWARD.cross(u)
	pole = pole.normalized()
	var x := (ab * ab - bc * bc + d * d) / (2.0 * d)
	var h := sqrt(maxf(ab * ab - x * x, 0.0))
	var B2 := A + u * x + pole * h
	var C2 := A + u * d
	var r1 := _arc(B - A, B2 - A)
	var upper := Transform3D(Basis(r1) * gu.basis, A)
	var bc_rot := Basis(r1) * (C - B)
	var r2 := _arc(bc_rot, C2 - B2)
	var lower := Transform3D(Basis(r2) * Basis(r1) * gl.basis, B2)
	var end := Transform3D(ge.basis, C2)
	return {"upper": upper, "lower": lower, "end": end, "reach": d, "wanted": at_len}


static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	var an := a.normalized()
	var bn := b.normalized()
	var c := an.cross(bn)
	var dp := clampf(an.dot(bn), -1.0, 1.0)
	if c.length() < 1e-7:
		if dp > 0.0:
			return Quaternion.IDENTITY
		var ortho := an.cross(Vector3.RIGHT)
		if ortho.length() < 1e-4:
			ortho = an.cross(Vector3.UP)
		return Quaternion(ortho.normalized(), PI)
	return Quaternion(c.normalized(), acos(dp))
