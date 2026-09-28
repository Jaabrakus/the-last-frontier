class_name TravMotionWarper
extends RefCounted
## Motion warping for traversal moves (design 8.1-8.5): maps a clip chain's measured contacts
## onto a detected obstacle and produces the character's root trajectory over the move.
##
##   var path := TravMotionWarper.solve(move, geo)      # move = runtime table entry
##   if path.ok: root = path.transform_at(t_move)
##
## geo (world space):
##   start        Vector3  the character's feet position when the move starts
##   yaw          float    move facing (clip +Z maps to (sin yaw, 0, cos yaw))
##   solve_start  bool     true: place the start point S on the approach line so that the
##                         primary contact lands at the lip + inset (planning, design 8.2);
##                         false: start exactly at `start` (the trigger tick) and let the warp
##                         absorb the residual
##   support_y    float    ground height under the start
##   top_y        float    obstacle top / lip height (null for moves without a top)
##   face_point   Vector3  a point on the approach face (at the top edge)
##   face_normal  Vector3  outward horizontal normal of that face
##   depth        float    top depth D along -face_normal (INF for deep tops)
##   landing_y    float    landing height beyond the far edge (OVER moves; null = none)
##   lip_point    Vector3  optional exact primary contact point (hang moves on a LedgeGraph lip)
##   hand_inset   float    optional override of the move's hand_inset
##   momentum     Dictionary  optional TravMomentum.prepare() of a move entered faster than its clip
##                         ({u, rate, ...}): the forward axis follows TravMomentum.forward_plan (the body
##                         keeps its speed; the plants hold within their limbs' reach) and the plants are
##                         shaped for it (TravMomentum.shape_pins)
##
## The warp is a per-sample offset delta(t) in the move frame found by one least-squares solve
## per axis (a pentadiagonal SPD system):
##   minimise  sum_i a_i (delta_i - r_i)^2          contact targets (hands / knees / feet on
##                                                    their surfaces; the start; the landing)
##           + sum_i b_i (delta_i+1 - delta_i)^2    held while a limb is planted (no spatial
##                                                    warp under a planted contact, design T5)
##           + c   sum_i (second difference)^2      smooth easing between contacts
## Support feet release their vertical hold PUSH_S before takeoff and landing feet take it
## LAND_S after touchdown, so the height change can start in the push-off (foot IK keeps the
## foot down, design 8.4). Contact-free flights whose height changes by more than 0.1 m follow a
## ballistic arc between their end points (design 8.5).

const W_HAND := 1000.0
const W_KNEE := 600.0
const W_FOOT := 300.0
const W_START := 2000.0
const B_HOLD := 1.0e5
const C_SMOOTH := 1.0
const EPS := 1.0e-6
const PUSH_S := 0.15
const LAND_S := 0.1
const KNEE_R := 0.0      ## the knee track is the kneecap's surface (mesh probes)
const G := 9.81
const W_CLEAR := 3000.0
const CLEAR_ITERS := 6
const LONG_PATH_N := 200
const CLEAR_MARGIN := 0.03
const CLEAR_TOL := 0.003
const CLEAR_DONE_M := 0.01
const CLEAR_SPREAD := 2          ## a clearance correction is asked of this many samples on each side too
const GROUND_MARGIN := 0.02
const HAND_HOLD_MAX := 0.12
const HAND_ARRIVE_M := 0.03      ## a hand plant starts when the warped hand is this close above the top
const SMOOTH_PASSES := 2
const FLIGHT_BLEND_S := 0.08     ## a ballistic flight blends in / out of the root's own motion over this
const W_MOMENTUM := 1000.0       ## momentum: the body's forward path (TravMomentum.forward_plan), per sample
const MOM_LIFT_MAX_M := 0.35      ## momentum: the most a clearance lifts the body before it may push it along instead
const HAND_CLEAR_H := 0.03       ## a hand this far below its contact height is under the top
const HAND_INSET_MIN := 0.02     ## the closest a hand is put to the lip (fingers over the edge)
const CLEAR_POINTS := ["l_foot", "r_foot", "l_heel", "r_heel", "l_ball", "r_ball", "l_knee", "r_knee", "pelvis",
		"l_elbow", "r_elbow"]
## Body parts the tracks do not carry, for the clearance (fix round 3, 2026-09-25; review: the
## rendered shins, forearms, thighs with the coat and the head went 4-15 cm into the obstacles while
## every tracked point was clear): [name, track a, track b, u, radius] = the point lerp(a, b, u) with
## the flesh and cloth around it.
const BODY_POINTS := [
	["l_shin", "l_knee", "l_heel", 0.5, 0.05], ["r_shin", "r_knee", "r_heel", 0.5, 0.05],
	["l_kneecap", "l_knee", "l_knee", 0.0, 0.065], ["r_kneecap", "r_knee", "r_knee", 0.0, 0.065],
	["l_thigh", "pelvis", "l_knee", 0.6, 0.09], ["r_thigh", "pelvis", "r_knee", 0.6, 0.09],
	["l_forearm", "l_elbow", "l_hand", 0.45, 0.045], ["r_forearm", "r_elbow", "r_hand", 0.45, 0.045],
	["l_cuff", "l_elbow", "l_hand", 0.75, 0.045], ["r_cuff", "r_elbow", "r_hand", 0.75, 0.045],
	["head", "head_top", "head_top", 0.0, 0.1],
	# The coat's skirt behind and under the hips (the coat is skinned to the thighs: at a vault's
	# landing on the far side of a wall, its tail swung 10 cm into the wall's top while every
	# tracked point was clear): the pelvis track offset in the move frame (+Z forward).
	["coat", "pelvis", "pelvis", 0.0, 0.08, Vector3(0.0, -0.4, -0.18)],
]
## ... their surface may enter a solid by this much (the test's cloth allowance is 3 cm)
const BODY_ALLOW := 0.02
## The front of the shoe, measured on the rendered mesh: its tip 7.8 cm past the ball joint along the
## heel -> ball line (u 1.51) and 0.7 cm under it, its front-bottom at u 1.38 and 2.8 cm under the
## line: sole points of the clearance too (fix round 3: a foot stepping onto a top went toe first
## 4.8 cm into its face while the tracked sole points were clear). [name, heel, ball, u, v (along the
## line's up)].
const SOLE_POINTS := [["l_toe", "l_heel", "l_ball", 1.51, -0.007], ["r_toe", "r_heel", "r_ball", 1.51, -0.007],
		["l_toe_low", "l_heel", "l_ball", 1.38, -0.028], ["r_toe_low", "r_heel", "r_ball", 1.38, -0.028]]
## A sole (the rendered sole's contact point, heel, ball) may be this far inside the ground, top or
## landing it is over; the clearance lifts the reference where it is deeper (fix round 3: the
## reconstructed paths put standing feet 7-23 cm under the ground in the push-offs and run-outs, and
## the IK dragged the feet along the surface to hide it).
const SOLE_TOL := 0.01
## Moves whose reference soles are kept out of the ground / tops / landings (not drops, not the
## ladder's lane).
const SOLE_FLOOR_INTENTS := ["over", "onto", "beam", "squeeze", "land", "crawl", "shimmy", "gap"]
const TRACK_NAMES := ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee", "pelvis", "head_top",
		"l_heel", "r_heel", "l_ball", "r_ball", "l_elbow", "r_elbow"]


static func solve(move_id: String, move: Dictionary, geo: Dictionary) -> TravWarpedPath:
	var t_us0 := Time.get_ticks_usec()
	var p := TravWarpedPath.new()
	p.move_id = move_id
	# Momentum (TravMomentum): the body keeps the speed it came with (a forward path solved after the first
	# solution, which places the contacts).
	var mom: Dictionary = geo.get("momentum", {}) if geo.get("momentum") is Dictionary else {}
	var mom_fp := {}
	p.move = move
	p.status = str(move.get("status", "graph"))
	var tr: Dictionary = move.track
	p.hz = float(tr.hz)
	p.n = int(tr.n)
	p.duration = float(move.duration)
	p.align = _uniform_end(_vec3s(tr.align), p.hz, p.duration)
	for nm in TRACK_NAMES:
		if tr.has(nm):
			p.points[nm] = _uniform_end(_vec3s(tr[nm]), p.hz, p.duration)
	p.windows = move.get("windows", {})
	p.exit_kind = str(move.get("exit", ""))
	p.yaw = float(geo.get("yaw", 0.0))
	p.basis = Basis(Vector3.UP, p.yaw)
	var anchor: Dictionary = move.get("anchor", {})
	var start_h := float(anchor.get("start_h", 0.0))
	var start: Vector3 = geo.get("start", Vector3.ZERO)
	var support_y := float(geo.get("support_y", start.y))
	var top_y: Variant = geo.get("top_y")
	var landing_y: Variant = geo.get("landing_y")
	var fwd := p.basis * Vector3(0, 0, 1)
	var n := p.n
	var t_us1 := Time.get_ticks_usec()

	# --- start point S (design 8.2) ---------------------------------------------------------
	var origin := Vector3(start.x, support_y - start_h, start.z)
	var prim: Variant = anchor.get("primary")
	var inset := float(geo.get("hand_inset", move.get("hand_inset", 0.1)))
	var face_n: Vector3 = geo.get("face_normal", -fwd)
	face_n.y = 0.0
	face_n = face_n.normalized() if face_n.length() > 1e-4 else -fwd
	var into := -face_n
	var target_c: Variant = null
	var prim_grip: Variant = _grip_of(move, prim)
	if prim != null and prim_grip != null:
		# A lip grip: the contact point sits dz behind the lip edge (negative: in front).
		inset = float((prim_grip as Dictionary).dz)
		p.metrics["inset"] = inset
		p.metrics["grip"] = prim_grip
	elif prim != null:
		inset = _wall_safe_inset(p, move, prim as Dictionary, inset)
		inset = _hand_approach_inset(p, move, prim as Dictionary, inset)
		p.metrics["inset"] = inset
	if prim != null and top_y != null:
		var pr: Dictionary = prim
		var ppos := Vector3(float(pr.pos[0]), float(pr.pos[1]), float(pr.pos[2]))
		# The primary contact's reference point at its onset (move frame).
		var ti := _idx(p, float(pr.t))
		var ref_c: Vector3 = (p.points[str(pr.limb)] as PackedVector3Array)[ti] if p.points.has(str(pr.limb)) else ppos
		var ref_h := p.basis * Vector3(ref_c.x, 0, ref_c.z)
		if geo.has("lip_point") and geo.lip_point != null:
			var lp: Vector3 = geo.lip_point
			target_c = Vector3(lp.x, float(top_y), lp.z)
			if bool(geo.get("solve_start", true)):
				origin.x = lp.x - ref_h.x
				origin.z = lp.z - ref_h.z
		elif geo.has("face_point"):
			var fp: Vector3 = geo.face_point
			var depth := float(geo.get("depth", INF))
			var ins := minf(inset, depth * 0.5) if depth < INF and prim_grip == null else inset
			if bool(geo.get("solve_start", true)):
				var h := fwd
				var denom := h.dot(into)
				if absf(denom) < 0.2:
					p.ok = false
					p.reason = "angle"
					return p
				var s := (ins - (start + ref_h - fp).dot(into)) / denom
				# Back off when a support foot (heel / toe) would stand inside the face before the
				# first contact; the flight / W0b window then carries the difference (design 8.2).
				var worst := -INF
				var tf: Variant = p.windows.get("first_support")
				for c: Dictionary in move.get("contacts", []):
					if str(c.surface) != "support":
						continue
					var side := str(c.limb).substr(0, 2)
					for nm in [side + "heel", side + "ball", str(c.limb)]:
						if not p.points.has(nm):
							continue
						var q: Vector3 = (p.points[nm] as PackedVector3Array)[mini(int(c.i1), n - 1)]
						var wq := start + fwd * s + p.basis * Vector3(q.x, 0, q.z)
						worst = maxf(worst, (wq - fp).dot(into) + CLEAR_MARGIN)
				if worst > 0.0 and tf != null:
					s -= worst / denom
					p.metrics["start_backoff"] = worst
				origin.x = start.x + h.x * s
				origin.z = start.z + h.z * s
				p.metrics["start_shift"] = s
			var c0 := origin + ref_h
			# The contact point: the reference contact, pushed to the inset line behind the face.
			var d_in := (c0 - fp).dot(into)
			var c := c0 + into * (ins - d_in)
			target_c = Vector3(c.x, float(top_y), c.z)
	p.origin = origin

	# --- constraints --------------------------------------------------------------------------
	var a := [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
	var r := [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
	var b := [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
	for ax in 3:
		a[ax].resize(n)
		r[ax].resize(n)
		b[ax].resize(maxi(n - 1, 0))
		a[ax].fill(0.0)
		r[ax].fill(0.0)
		b[ax].fill(0.0)
	var binv := p.basis.inverse()
	var add := func(ax: int, i: int, w: float, v: float) -> void:
		a[ax][i] += w
		r[ax][i] += w * v
	# The start: no warp at t = 0 (the move begins at S with the feet on the support, or at the
	# hub pose it starts from), and none in W0a (start -> takeoff: time only, design 8.2).
	for ax in 3:
		add.call(ax, 0, W_START, 0.0)
	var i_to := _idx(p, float(p.windows.get("takeoff", 0.0)))
	if not bool(geo.get("free_start", false)):
		for i in range(0, mini(i_to, n - 1)):
			for ax in 3:
				b[ax][i] = maxf(b[ax][i], B_HOLD)
	# Explicit end targets (lanes, limb tops): the root at the last sample.
	if geo.has("end_root") or geo.has("end_xz"):
		var er: Vector3 = geo.get("end_root", geo.get("end_xz"))
		var want_e: Vector3 = binv * (er - origin) - p.align[n - 1]
		for k in range(maxi(0, n - 3), n):
			add.call(0, k, W_HAND * 2.0, want_e.x)
			add.call(2, k, W_HAND * 2.0, want_e.z)
			if geo.has("end_root"):
				add.call(1, k, W_HAND * 2.0, want_e.y)
	# A loop (beam / crawl / shimmy walk) ends at the height it started: the survey's odometry
	# drifts a few cm per cycle (beam_loop -6 cm), which would sink the feet into the support by
	# the end of the cycle and pop the next one back up.
	if bool(move.get("loop", false)) and not geo.has("end_root") and p.align.size() == n and n > 3:
		var dy: float = (p.align[0] as Vector3).y - (p.align[n - 1] as Vector3).y
		for k in range(maxi(0, n - 3), n):
			add.call(1, k, W_HAND, dy)
	var contacts: Array = move.get("contacts", [])
	var top_h: Variant = anchor.get("top_h")
	var o_top: Variant = null
	if top_y != null and top_h != null:
		o_top = float(top_y) - (origin.y + float(top_h))
	var end_h: Variant = anchor.get("end_h")
	var o_land: Variant = null
	if landing_y != null and end_h != null:
		o_land = float(landing_y) - (origin.y + float(end_h))
	p.metrics["dh_top"] = o_top
	p.metrics["dh_land"] = o_land
	var t_first: Variant = p.windows.get("first_support")
	for c: Dictionary in contacts:
		var surf := str(c.surface)
		var i0 := int(c.i0)
		var i1 := mini(int(c.i1), n - 1)
		var limb := str(c.limb)
		var kind := str(c.kind)
		if surf == "free" or surf == "ground":
			continue
		var pts: PackedVector3Array = p.points.get(limb, PackedVector3Array())
		# Horizontal hold for every planted contact.
		for i in range(i0, i1):
			b[0][i] = maxf(b[0][i], B_HOLD)
			b[2][i] = maxf(b[2][i], B_HOLD)
		var vtarget: Variant = null
		var w := W_FOOT
		var v_i0 := i0
		var v_i1 := i1
		match surf:
			"support":
				vtarget = support_y
				if t_first != null and float(c.t_off) >= float(t_first) - 0.05:
					v_i1 = maxi(i0, i1 - int(PUSH_S * p.hz))
			"top", "hang":
				if top_y != null:
					vtarget = float(top_y) + (KNEE_R if kind == "knee" else 0.0)
					if c.has("grip"):
						vtarget = float(top_y) + float((c.grip as Dictionary).dy)
				w = W_HAND if kind == "hand" else (W_KNEE if kind == "knee" else W_FOOT)
			"landing":
				if landing_y != null:
					vtarget = float(landing_y)
					v_i0 = mini(i1, i0 + int(LAND_S * p.hz))
			"wall":
				pass
		if vtarget != null and not pts.is_empty():
			for i in range(v_i0, v_i1 + 1):
				# delta_up so that the limb's reference height lands on the surface at every
				# sample: no vertical hold here, so a reference that drifts while the limb is
				# planted (the survey's align under re-grips and pushes) is corrected, not kept.
				add.call(1, i, w, float(vtarget) - (origin.y + pts[i].y))
		elif surf == "wall":
			for i in range(i0, i1):
				b[1][i] = maxf(b[1][i], B_HOLD)
	# Planted hands hold their WORLD position horizontally, not the warp offset: the reconstructed
	# align drifts under a hanging or pushing hand (the 3 m climb's hands moved 7-27 cm across
	# the lip while planted, the chest climb's 5-6 cm), so a constant offset slid the hand along
	# the top and the IK only fixed its height. The hold term b (x[i+1] - x[i] - g[i])^2 takes
	# g = the hand's reference step reversed, so the body moves under the planted hand instead;
	# overlapping planted contacts share the step (feet keep g = 0) (review 2026-09-24).
	if bool(move.get("hand_world_hold", true)):
		var hold_n := PackedInt32Array()
		hold_n.resize(n)
		hold_n.fill(0)
		var gx := PackedFloat64Array()
		var gz := PackedFloat64Array()
		gx.resize(n)
		gz.resize(n)
		gx.fill(0.0)
		gz.fill(0.0)
		var any_hand := false
		for c: Dictionary in contacts:
			var surf2 := str(c.surface)
			if surf2 == "free" or surf2 == "ground":
				continue
			var i0h := int(c.i0)
			var i1h := mini(int(c.i1), n - 1)
			for i in range(i0h, i1h):
				hold_n[i] += 1
			if str(c.kind) != "hand" or not surf2 in ["top", "hang"]:
				continue
			var hp: PackedVector3Array = p.points.get(str(c.limb), PackedVector3Array())
			if hp.is_empty():
				continue
			any_hand = true
			for i in range(i0h, i1h):
				gx[i] += hp[i].x - hp[i + 1].x
				gz[i] += hp[i].z - hp[i + 1].z
		if any_hand:
			for i in n - 1:
				if hold_n[i] == 0 or (gx[i] == 0.0 and gz[i] == 0.0):
					continue
				var fx: float = b[0][i] * gx[i] / hold_n[i]
				var fz: float = b[2][i] * gz[i] / hold_n[i]
				r[0][i] -= fx
				r[0][i + 1] += fx
				r[2][i] -= fz
				r[2][i + 1] += fz
	# An overhead lip (geo top_shift {t0, t1, d}, a platform's edge over open ground): the body moves d m in over
	# the top between t0 and t1, while its hand holds the lip (the lip grip keeps the hand's depth at the edge), so
	# the climb ends standing on the top. The hang climb's source clip ends with its root over the lip and a foot
	# 7 cm out over the drop (the walkway, 2026-09-26): on a wall's deep top that stood on the edge, on the
	# walkway's edge the capsule slid off. A smoothstep ramp added to the holds' steps (the planted hand's and
	# foot's world holds carry it).
	var tsh: Variant = geo.get("top_shift")
	if tsh is Dictionary and float((tsh as Dictionary).get("d", 0.0)) != 0.0:
		var i0s := _idx(p, float(tsh.t0))
		var i1s := maxi(i0s + 1, _idx(p, float(tsh.t1)))
		var sh_m: Vector3 = binv * (into * float(tsh.d))
		for i in range(i0s, mini(i1s, n - 1)):
			var u0 := smoothstep(0.0, 1.0, float(i - i0s) / float(i1s - i0s))
			var u1 := smoothstep(0.0, 1.0, float(i + 1 - i0s) / float(i1s - i0s))
			var st := sh_m * (u1 - u0)
			var bw := maxf(maxf(b[0][i], b[2][i]), W_HAND)
			b[0][i] = bw
			b[2][i] = bw
			r[0][i] -= bw * st.x
			r[0][i + 1] += bw * st.x
			r[2][i] -= bw * st.z
			r[2][i + 1] += bw * st.z
		p.metrics["top_shift"] = float(tsh.d)
	# The primary contact's horizontal target.
	if target_c != null and prim != null:
		var pr: Dictionary = prim
		var ti := _idx(p, float(pr.t))
		var pts: PackedVector3Array = p.points.get(str(pr.limb), PackedVector3Array())
		if not pts.is_empty():
			var want: Vector3 = binv * ((target_c as Vector3) - origin)
			var dx := want.x - pts[ti].x
			var dz := want.z - pts[ti].z
			add.call(0, ti, W_HAND, dx)
			add.call(2, ti, W_HAND, dz)
			p.metrics["primary_offset"] = [dx, dz]
	# ONTO moves end standing on the top: the lower foot of the last samples on the top (the
	# reconstructed chains drift; the exits run off the contact rule, design 8.1 confidence).
	if top_y != null and str(move.get("intent", "")) == "onto" and str(move.get("exit", "")) != "hang" \
			and str(move.get("class", "")) not in ["hang", "hub"] and not bool(geo.get("no_end_top", false)):
		var lfp: PackedVector3Array = p.points.get("l_foot", PackedVector3Array())
		var rfp: PackedVector3Array = p.points.get("r_foot", PackedVector3Array())
		if not lfp.is_empty() and not rfp.is_empty():
			for k in range(maxi(0, n - 4), n):
				var yref := minf(lfp[k].y, rfp[k].y)
				add.call(1, k, W_FOOT * 3.0, float(top_y) - (origin.y + yref))
	# Extra (annotated) contacts: a limb held on a world point over [t_on, t_off] (design 8.4
	# hero annotations; ladder top dismount hands on the platform edge). Pinned by IK too.
	for xc: Dictionary in geo.get("extra_contacts", []):
		var limb := str(xc.limb)
		var pts: PackedVector3Array = p.points.get(limb, PackedVector3Array())
		if pts.is_empty():
			continue
		var i0 := _idx(p, float(xc.t_on))
		var i1 := _idx(p, float(xc.t_off))
		var want: Vector3 = binv * ((xc.point as Vector3) - origin)
		var w := float(xc.get("weight", W_HAND))
		for i in range(i0, i1 + 1):
			add.call(0, i, w, want.x - pts[i].x)
			add.call(2, i, w, want.z - pts[i].z)
			add.call(1, i, w, want.y - pts[i].y)
		for i in range(i0, i1):
			for ax in 3:
				b[ax][i] = maxf(b[ax][i], B_HOLD * 0.1)
	# OVER: the landing feet must clear the far edge (W2a forward stretch).
	if geo.has("face_point") and float(geo.get("depth", INF)) < INF and str(move.get("intent", "")) == "over":
		var fp: Vector3 = geo.face_point
		var far_d := float(geo.depth) + 0.15
		for c: Dictionary in contacts:
			if str(c.surface) != "landing":
				continue
			var pts: PackedVector3Array = p.points.get(str(c.limb), PackedVector3Array())
			var i0 := int(c.i0)
			var wpos := origin + p.basis * pts[i0]
			var d := (wpos - fp).dot(into)
			if d < far_d:
				var need: Vector3 = binv * (into * (far_d - d))
				for i in range(i0, mini(int(c.i1), n - 1) + 1):
					add.call(2, i, W_FOOT, need.z)
					add.call(0, i, W_FOOT * 0.2, need.x)
				p.metrics["landing_push"] = far_d - d
				break

	# Gap jumps: the first landing foot lands beyond the gap's far edge (design 7.6).
	if geo.has("landing_min_fwd"):
		var lmf := float(geo.landing_min_fwd)
		for c: Dictionary in contacts:
			if str(c.surface) != "landing":
				continue
			var pts2: PackedVector3Array = p.points.get(str(c.limb), PackedVector3Array())
			if pts2.is_empty():
				continue
			var i0 := int(c.i0)
			var dz := lmf - pts2[i0].z
			if dz > 0.0:
				for i in range(i0, mini(int(c.i1), n - 1) + 1):
					add.call(2, i, W_HAND, dz)
				p.metrics["landing_push"] = dz
			break

	# --- solve, then clearance passes (design 6.2 J / 13: no body point inside the obstacle) -----
	var box: Variant = _obstacle_box(geo, move)
	if box != null and bool((box as Dictionary).has_box):
		# Hands that will be planted on the top: clear of the box until their first contact (fix
		# round 3: the sprint vault's hand came up through the front of a wall 4 cm taller than
		# authored, 5.8 cm under its top, and the guard threw it up onto the top).
		var hu := {}
		for c: Dictionary in move.get("contacts", []):
			if str(c.kind) == "hand" and str(c.surface) == "top" and p.points.has(str(c.limb)):
				hu[str(c.limb)] = mini(int(hu.get(str(c.limb), p.n)), int(c.i0))
		(box as Dictionary)["hand_until"] = hu
	var clear_w := 0
	var t_us2 := Time.get_ticks_usec()
	# Cost: a clearance pass pins every axis of a violating sample at its current value plus the
	# correction; an axis whose corrections were all zero keeps its solution (the pins equal it),
	# so only the axes that moved are solved again.
	var sol: Array = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
	var dirty := [true, true, true]
	var prev_left := INF
	var iters := 0
	# (Long paths (the 3 m climbs, 200-242 samples) take two clearance passes less: every pass costs
	# about a millisecond there, and the solve budget is 6 ms; fix round 3.)
	var iters_max := CLEAR_ITERS if n < LONG_PATH_N else CLEAR_ITERS - 2
	# (Momentum takes one solve more: its forward path comes from the first solution.)
	var mom_pending := not mom.is_empty()
	var it := -1 if mom_pending else 0
	while it <= iters_max:
		iters += 1
		for ax in 3:
			if dirty[ax]:
				sol[ax] = _solve_axis(a[ax], r[ax], b[ax], n)
		var dx: PackedFloat64Array = sol[0]
		var dy: PackedFloat64Array = sol[1]
		var dz: PackedFloat64Array = sol[2]
		p.delta.resize(n)
		for i in n:
			p.delta[i] = Vector3(dx[i], dy[i], dz[i])
		if mom_pending:
			# (The forward axis is the momentum path alone, from the first solution: its primary contact
			# and what its plants hold; the plants' holds are the path's own now, within their limbs'
			# reach. The clearance passes that follow see it and keep the body clear of the obstacle.)
			mom_pending = false
			mom_fp = _momentum_targets(p, move, mom, a, r, b, add)
			dirty = [false, false, true, 0.0, 0.0]
			it += 1
			continue
		_ballistic_flights(p, move, (box as Dictionary).get("need_y", PackedFloat64Array()) if box != null else PackedFloat64Array())
		# (The clearance checks the path as it will be played: after the root smoothing, which
		# flattened a lift of a few samples to a third of it; fix round 3.)
		_smooth_root(p)
		if box == null or it == iters_max:
			break
		dirty = [false, false, false, 0.0, 0.0]
		var added := _clearance(p, box as Dictionary, add, dirty)
		clear_w += added
		# Done when nothing was added, or (after two passes) when what is left is under
		# CLEAR_DONE_M (inside the 3 cm margin, still clear of the obstacle itself) or no longer
		# shrinks (contacts hold those samples; more passes only cost time).
		# (What is left: the sum of the violations, not the worst one: a violation the contacts hold
		# in place kept the worst one from shrinking and stopped the passes with fixable ones left, the
		# 1.5 m mantle's toe 5 cm inside the block's face; fix round 3.)
		var left := float(dirty[4]) if dirty.size() > 4 else float(dirty[3])
		if added == 0 or (it >= 1 and (float(dirty[3]) < CLEAR_DONE_M or left > prev_left * 0.8)):
			break
		prev_left = left
		it += 1
	p.metrics["clearance_constraints"] = clear_w
	p.metrics["clearance_passes"] = iters
	var t_us3 := Time.get_ticks_usec()
	_metrics(p, move, geo, o_top, o_land)
	_pins(p, move, geo)
	if not mom_fp.is_empty():
		TravMomentum.shape_pins(p, mom_fp, float(TravMomentum.config(move).get("lift_m", TravMomentum.LIFT_M)))
	var ex := str(move.get("exit", ""))
	if ex in ["run", "idle"] and (str(move.get("intent", "")) == "onto" or move_id == "ladder_dismount_top") \
			and top_y != null and geo.has("face_point"):
		p.up_t = _up_time(p, float(top_y), geo.face_point, into)
	if ex in ["run", "idle"]:
		if str(move.get("intent", "")) == "onto" and top_y != null:
			p.exit_y = float(top_y)
		elif landing_y != null:
			p.exit_y = float(landing_y)
		else:
			p.exit_y = support_y
	p.build_capsule()
	p.metrics["cost_us"] = {"setup": t_us1 - t_us0, "constraints": t_us2 - t_us1, "solve_clear": t_us3 - t_us2,
			"finish": Time.get_ticks_usec() - t_us3}
	return p


## Up (TravWarpedPath.up_t): the first sample from which to the end both feet are over the top: their balls past
## the lip (UP_IN_M behind the face) and not under the top's height (UP_TOL_M; a foot lifted in a step, a walk-off
## at the ladder's top, still counts), plus UP_SETTLE_S; -1 when the move does not end so.
const UP_IN_M := 0.02
const UP_TOL_M := 0.08
const UP_SETTLE_S := 0.1

static func _up_time(p: TravWarpedPath, top_y: float, fp: Vector3, into: Vector3) -> float:
	var names := ["l_ball", "r_ball"]
	for nm in names:
		if not p.points.has(nm):
			return -1.0
	var fp_d := fp.dot(into)
	var first := -1
	for i in range(p.n - 1, -1, -1):
		var ok := true
		for nm: String in names:
			var w: Vector3 = p.origin + p.basis * ((p.points[nm] as PackedVector3Array)[i] + p.delta[i])
			# (over the top and not under it; a foot lifted in a step still counts)
			if w.dot(into) - fp_d < UP_IN_M or w.y < top_y - UP_TOL_M:
				ok = false
				break
		if not ok:
			break
		first = i
	if first < 0 or first >= p.n - 1:
		return -1.0
	return minf(first / p.hz + UP_SETTLE_S, p.duration)


## Momentum (TravMomentum; vault speed push 2, 2026-09-26): the forward axis (move frame +Z) of a move entered
## faster than its clip is rebuilt as the body's forward path (TravMomentum.forward_plan, from the first
## solution: its primary contact and plants): a target per sample, no holds (the path keeps each plant within
## its limb's reach, the IK holds the limb in the world), smoothed like the rest of the warp. Returns the plan.
static func _momentum_targets(p: TravWarpedPath, move: Dictionary, mom: Dictionary, a: Array, r: Array, b: Array, add: Callable) -> Dictionary:
	var n := p.n
	var pel: PackedVector3Array = p.points.get("pelvis", p.align)
	var pz := PackedFloat64Array()
	var bz := PackedFloat64Array()
	pz.resize(n)
	bz.resize(n)
	for i in n:
		pz[i] = pel[i].z
		bz[i] = p.delta[i].z
	var fp := TravMomentum.forward_plan(p.move_id, pz, bz, float(mom.get("u", 0.0)), int(move.get("momentum_trim", 0)), p.hz, true,
			float(mom.get("u0", -1.0)))
	var F: PackedFloat64Array = fp.F
	# (in place: the arrays of the solve, not copies)
	a[2].fill(0.0)
	r[2].fill(0.0)
	b[2].fill(0.0)
	add.call(2, 0, W_START, 0.0)
	for i in range(1, n):
		add.call(2, i, W_MOMENTUM, F[i] - pz[i])
	p.metrics["momentum"] = {"u": float(mom.get("u", 0.0)), "rate": float(mom.get("rate", 1.0)), "trim": int(move.get("momentum_trim", 0)),
			"end": int(fp.end), "released": (fp.release as Dictionary).size(), "capped": int(fp.capped), "extra": F[n - 1] - (pz[n - 1] + bz[n - 1])}
	p.metrics["DBG_F"] = F
	p.metrics["DBG_base"] = bz
	p.metrics["DBG_pel"] = pz
	return fp


## Seam and kink smoothing (user fix 2026-09-24: no pops during a move): the reference align is
## rebuilt from contacts, so its velocity jumps where the planted limb changes and where parts
## join (up to ~1.6 m/s). The root path (align + delta) is low-passed with two passes of a
## [1, 2, 1] / 4 filter (about 17 ms each at 60 Hz), end samples kept, so the entry and exit
## seams stay where they are; the IK holds the planted limbs on their surfaces.
## What is smoothed is the WORLD PELVIS (root + the pose's pelvis offset; seam fix 2026-09-24):
## where the clip's own root bone jumps in velocity at a 0 s part join, the root path carries the
## opposite jump so that the body moves on continuously (the table's part joins, the rise of
## _rise_catch); low-passing the root itself spread that jump over the filter and the body jerked
## by the difference (up to 2-3 cm at the 3 m climb's joins). Smoothing the pelvis keeps the root's
## compensation exact and removes the kinks of the body's motion, whichever part they come from.
static func _smooth_root(p: TravWarpedPath) -> void:
	var n := p.n
	if n < 5:
		return
	var pel: PackedVector3Array = p.points.get("pelvis", PackedVector3Array())
	var rel := PackedVector3Array()
	rel.resize(n)
	if pel.size() == n:
		for i in n:
			rel[i] = pel[i] - p.align[i]
	var R := PackedVector3Array()
	R.resize(n)
	for i in n:
		R[i] = p.align[i] + p.delta[i] + rel[i]
	for pass_i in SMOOTH_PASSES:
		var S := R.duplicate()
		for i in range(1, n - 1):
			S[i] = (R[i - 1] + R[i] * 2.0 + R[i + 1]) * 0.25
		R = S
	for i in n:
		p.delta[i] = R[i] - p.align[i] - rel[i]


## The tracks' last sample is at the move's end time, not at (n - 1) / hz (the table clamps it):
## the path samples uniformly, so that sample is re-placed on the uniform grid by extrapolating the
## last interval. Otherwise the end became a stub of zero velocity when the duration is a
## multiple of the sample time (a duplicate sample): every exit's root and capsule stopped for a
## tick (a 1.3 cm capsule pop at the running knee mantle's exit), and the end smoothing slowed the
## last samples.
static func _uniform_end(a: PackedVector3Array, hz: float, duration: float) -> PackedVector3Array:
	var n := a.size()
	if n < 3:
		return a
	var t_prev := (n - 2) / hz
	var span := duration - t_prev
	if span >= 1.0 / hz - 1e-6:
		return a
	if span > 1e-4:
		a[n - 1] = a[n - 2] + (a[n - 1] - a[n - 2]) * ((1.0 / hz) / span)
	else:
		a[n - 1] = a[n - 2] * 2.0 - a[n - 3]
	return a


static func _idx(p: TravWarpedPath, t: float) -> int:
	return clampi(int(round(t * p.hz)), 0, p.n - 1)


static func _vec3s(flat: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(flat.size() / 3)
	for i in out.size():
		out[i] = Vector3(float(flat[3 * i]), float(flat[3 * i + 1]), float(flat[3 * i + 2]))
	return out


## Least squares with holds and smoothing: (A + B + C + eps) x = A r, banded LDL^T (bandwidth 2).
static func _solve_axis(a: PackedFloat64Array, r: PackedFloat64Array, b: PackedFloat64Array, n: int) -> PackedFloat64Array:
	var d0 := PackedFloat64Array()
	var d1 := PackedFloat64Array()
	var d2 := PackedFloat64Array()
	d0.resize(n)
	d1.resize(n)
	d2.resize(n)
	d0.fill(EPS)
	d1.fill(0.0)
	d2.fill(0.0)
	var rhs := PackedFloat64Array()
	rhs.resize(n)
	for i in n:
		d0[i] += a[i]
		rhs[i] = r[i]
	for i in n - 1:
		var w := b[i]
		d0[i] += w
		d0[i + 1] += w
		d1[i] -= w
	for i in range(1, n - 1):
		var c := C_SMOOTH
		d0[i - 1] += c
		d0[i] += 4.0 * c
		d0[i + 1] += c
		d1[i - 1] -= 2.0 * c
		d1[i] -= 2.0 * c
		d2[i - 1] += c
	# LDL^T: l1[i] = L[i][i-1], l2[i] = L[i][i-2].
	var D := PackedFloat64Array()
	var l1 := PackedFloat64Array()
	var l2 := PackedFloat64Array()
	D.resize(n)
	l1.resize(n + 2)
	l2.resize(n + 2)
	l1.fill(0.0)
	l2.fill(0.0)
	for j in n:
		var dj := d0[j]
		if j >= 1:
			dj -= l1[j] * l1[j] * D[j - 1]
		if j >= 2:
			dj -= l2[j] * l2[j] * D[j - 2]
		D[j] = dj
		if j + 2 < n:
			l2[j + 2] = d2[j] / dj
		if j + 1 < n:
			var num := d1[j]
			if j >= 1:
				num -= l2[j + 1] * l1[j] * D[j - 1]
			l1[j + 1] = num / dj
	var y := PackedFloat64Array()
	y.resize(n)
	for i in n:
		var v := rhs[i]
		if i >= 1:
			v -= l1[i] * y[i - 1]
		if i >= 2:
			v -= l2[i] * y[i - 2]
		y[i] = v
	var x := PackedFloat64Array()
	x.resize(n)
	for k in n:
		var i := n - 1 - k
		var v := y[i] / D[i]
		if i + 1 < n:
			v -= l1[i + 1] * x[i + 1]
		if i + 2 < n:
			v -= l2[i + 2] * x[i + 2]
		x[i] = v
	return x


## Flights whose root height changes by more than 0.1 m follow a ballistic arc (design 8.5):
## the vertical offset is rewritten so that root_y(t) = y0 + v0 tau - g tau^2 / 2 between the
## flight's end samples (continuous with the contacts on both sides).
## need_y: per sample, the lowest vertical offset the clearance asks for (a sole or knee lifted out
## of a face inside a flight; -1e9 where none): the arc does not pass under it (fix round 3: the
## arc replaced the clearance's lift and left the 1.5 m mantle's toe 5 cm inside the block).
static func _ballistic_flights(p: TravWarpedPath, move: Dictionary, need_y := PackedFloat64Array()) -> void:
	var flights: Array = p.windows.get("flights", [])
	var vmax := 0.0
	for f: Array in flights:
		var i0 := _idx(p, float(f[0]))
		var i1 := _idx(p, float(f[1]))
		if i1 - i0 < 3:
			continue
		var y0 := p.align[i0].y + p.delta[i0].y
		var y1 := p.align[i1].y + p.delta[i1].y
		if absf(y1 - y0) < 0.1 and not move.has("flight"):
			continue
		var T := (i1 - i0) / p.hz
		var v0 := (y1 - y0 + 0.5 * G * T * T) / T
		vmax = maxf(vmax, v0)
		var fl: Dictionary = move.get("flight", {}) if move.get("flight") is Dictionary else {}
		if str(fl.get("profile", "")) == "rise_catch" and p.points.has("pelvis"):
			# (The ballistic v0 above still gates the height: flight.vy_max, selection unchanged.)
			_rise_catch(p, fl, i1)
			continue
		# The root's own vertical velocity just before and just after the flight (one-sided).
		var vb := (y0 - (p.align[i0 - 1].y + p.delta[i0 - 1].y)) * p.hz if i0 >= 1 else v0
		var ve := ((p.align[mini(i1 + 1, p.n - 1)].y + p.delta[mini(i1 + 1, p.n - 1)].y) - y1) * p.hz if i1 + 1 < p.n else v0 - G * T
		# The arc is blended in from the take-off's own motion and out into the catch / landing's
		# over FLIGHT_BLEND_S at each end (smoothstep weights: position AND velocity continuous at
		# both ends). The bare arc switched the root's vertical velocity in one sample (7.2 m/s
		# after 3.1 m/s at the 3 m climb's take-off), a velocity jump right before the part join.
		var nb := mini(int(round(FLIGHT_BLEND_S * p.hz)), (i1 - i0) / 3)
		for i in range(i0 + 1, i1):
			var tau := (i - i0) / p.hz
			var y := y0 + v0 * tau - 0.5 * G * tau * tau
			if nb > 1 and i - i0 < nb:
				var w := smoothstep(0.0, 1.0, float(i - i0) / nb)
				y = lerpf(y0 + vb * tau, y, w)
			if nb > 1 and i1 - i < nb:
				var w2 := smoothstep(0.0, 1.0, float(i1 - i) / nb)
				y = lerpf(y1 - ve * ((i1 - i) / p.hz), y, w2)
			var d := p.delta[i]
			d.y = y - p.align[i].y
			if need_y.size() == p.n and need_y[i] > -1e8:
				d.y = maxf(d.y, need_y[i])
			p.delta[i] = d
	p.metrics["flight_vy"] = vmax


## A jump up to a catch whose rise the clip's own root bone only partly carries (the 3 m hang
## climb: its begin -> mid -> end parts join at 0 s, the mid part's root bone starts rising at
## 3 m/s from rest, and the missing align of the source adds about 0.8 m more). The ballistic ROOT
## arc used before added the arc's velocity to the pose's own rise: the pelvis accelerated upward
## in the air (0.8 -> 9 m/s between 0.19 and 0.36 s) with velocity kinks at the take-off and at
## both 0 s joins (pelvis dv 1.7 / 1.4 m/s; user complaint "snapping", 2026-09-24).
## The WORLD PELVIS is rebuilt instead, and the root follows it (root_y = pelvis_y - the pose's
## own pelvis height), so the pose's velocity jumps at the joins are absorbed by the root:
##   push     rise_t0 -> takeoff_t: the pelvis velocity ramps (smoothstep) from its own to V_to,
##            starting with zero acceleration at the part join;
##   flight   takeoff_t -> catch (the flight window's end, the hands' first support): constant
##            deceleration `decel`, arriving exactly at the pelvis height of the catch pose;
##   catch    catch -> catch + absorb_s: the leftover upward speed is absorbed by the arms (the
##            hands are held on the lip by the IK; the pelvis overshoots and settles, an
##            inertialization onto the hang path).
## V_to follows from the height to rise. Position and velocity are continuous everywhere; the
## part joins sit where the acceleration is small (the push starts at the join; the flight's
## deceleration is limited).
static func _rise_catch(p: TravWarpedPath, fl: Dictionary, i_c: int) -> void:
	var pel: PackedVector3Array = p.points.pelvis
	var i_a := _idx(p, float(fl.get("rise_t0", 0.2)))
	var i_to := _idx(p, float(fl.get("takeoff_t", 0.28)))
	var i_e := mini(p.n - 2, i_c + int(round(float(fl.get("absorb_s", 0.15)) * p.hz)))
	if i_a < 1 or i_to <= i_a or i_c <= i_to + 1 or i_e <= i_c:
		return
	var hz := p.hz
	var W := func(i: int) -> float: return pel[i].y + p.delta[i].y
	var P_a: float = W.call(i_a)
	var V_a: float = (P_a - float(W.call(i_a - 1))) * hz
	var P_c: float = W.call(i_c)
	var V_w: float = (float(W.call(i_c + 1)) - P_c) * hz
	var Tp := (i_to - i_a) / hz
	var Tf := (i_c - i_to) / hz
	var g := float(fl.get("decel", 30.0))
	var V_to := (P_c - P_a - V_a * Tp * 0.5 + 0.5 * g * Tf * Tf) / (Tp * 0.5 + Tf)
	var V_c := V_to - g * Tf
	var P_to := P_a + V_a * Tp + (V_to - V_a) * Tp * 0.5
	var Y := PackedFloat64Array()
	Y.resize(i_e - i_a + 1)
	for i in range(i_a, i_e + 1):
		var y: float
		if i <= i_to:
			var t := (i - i_a) / hz
			var u := t / Tp
			# The velocity ramps V_a -> V_to along smoothstep(u): its integral is u^3 - u^4 / 2.
			y = P_a + V_a * t + (V_to - V_a) * Tp * (u * u * u - 0.5 * u * u * u * u)
		elif i <= i_c:
			var tau := (i - i_to) / hz
			y = P_to + V_to * tau - 0.5 * g * tau * tau
		else:
			var tc := (i - i_c) / hz
			y = float(W.call(i)) + TravInertializer.decay(Vector3.ZERO, Vector3(0.0, V_c - V_w, 0.0), tc, (i_e - i_c) / hz).y
		Y[i - i_a] = y
	for i in range(i_a + 1, i_e + 1):
		var d := p.delta[i]
		d.y = Y[i - i_a] - pel[i].y
		p.delta[i] = d
	p.metrics["rise_v_takeoff"] = V_to
	p.metrics["rise_v_catch"] = V_c


static func _metrics(p: TravWarpedPath, move: Dictionary, geo: Dictionary, o_top: Variant, o_land: Variant) -> void:
	var maxd := 0.0
	var maxh := 0.0
	for d in p.delta:
		maxd = maxf(maxd, d.length())
		maxh = maxf(maxh, Vector2(d.x, d.z).length())
	p.metrics["max_delta"] = maxd
	p.metrics["max_delta_h"] = maxh
	# W0b forward scale: path length takeoff -> first support vs the warped one.
	var tw: Variant = p.windows.get("first_support")
	var to := float(p.windows.get("takeoff", 0.0))
	if tw != null and float(tw) > to + 0.03:
		var i0 := _idx(p, to)
		var i1 := _idx(p, float(tw))
		var ref := Vector2(p.align[i1].x - p.align[i0].x, p.align[i1].z - p.align[i0].z).length()
		var wa := p.align[i1] + p.delta[i1]
		var wb := p.align[i0] + p.delta[i0]
		var warped := Vector2(wa.x - wb.x, wa.z - wb.z).length()
		p.metrics["sf_w0b"] = warped / ref if ref > 0.05 else 1.0
	# Limits (design 7.1.2): the vertical warp of the top against the class limits.
	var dh: Array = move.get("dh", [])
	# (An overhead lip, geo open_below: the heights of the move's overhead_band instead.)
	if bool(geo.get("open_below", false)) and move.has("overhead_band") and (move.get("anchor", {}) as Dictionary).has("top_h"):
		var th := float((move.anchor as Dictionary).top_h)
		dh = [float(move.overhead_band[0]) - th, float(move.overhead_band[1]) - th]
	if o_top != null and dh.size() == 2:
		if float(o_top) < float(dh[0]) - 1e-3 or float(o_top) > float(dh[1]) + 1e-3:
			p.ok = false
			p.reason = "warp_limit"
	var sf: Variant = p.metrics.get("sf_w0b")
	# (A momentum path covers more ground there by design: TravMomentum.forward_plan keeps its plants in reach.)
	if sf != null and not bool(geo.get("solve_start", true)) and not geo.has("momentum"):
		var lim: Array = [0.8, 1.4]
		if float(sf) < float(lim[0]) - 0.05 or float(sf) > float(lim[1]) + 0.05:
			p.ok = false
			p.reason = "warp_limit"
	if p.metrics.has("flight_vy") and move.has("flight"):
		if float(p.metrics.flight_vy) > float((move.flight as Dictionary).get("vy_max", 5.5)) + 1e-3:
			p.ok = false
			p.reason = "too_high"


## IK plant windows (design 8.4): every planted hand or foot contact on a surface; the IK puts
## the limb's rendered surface (mesh probes) on the surface's shape (TravWarpedPath.surfaces).
## The support foot rolls off in the push-off and the landing foot absorbs the landing; a hand
## is held only while the clip keeps it near its contact point (then the clip has let go).
static func _pins(p: TravWarpedPath, move: Dictionary, geo: Dictionary) -> void:
	for xc: Dictionary in geo.get("extra_contacts", []):
		p.pins.append({"limb": str(xc.limb), "kind": str(xc.get("kind", "hand")), "surface": str(xc.get("surface", "top")),
				"t_on": float(xc.t_on), "t_off": float(xc.t_off)})
	var tf: Variant = p.windows.get("first_support")
	for c: Dictionary in move.get("contacts", []):
		var surf := str(c.surface)
		# "rung": annotated ladder-rung contacts (no vertical target here; the controller gives
		# the pin the lane's rung shape, TravTraversalController._rung_feet).
		if not surf in ["support", "top", "hang", "landing", "rung"]:
			continue
		var kind := str(c.kind)
		if kind == "knee":
			continue
		var limb := str(c.limb)
		var t_on := float(c.t_on)
		var t_off := float(c.t_off)
		if surf == "support" and tf != null and t_off >= float(tf) - 0.05 and not bool(c.get("annotated", false)):
			t_off = maxf(t_on, t_off - PUSH_S)
		if surf == "landing":
			t_on = minf(t_off, t_on + LAND_S)
		if kind == "hand" and surf in ["top", "hang"] and geo.get("top_y") != null and p.points.has(limb):
			# (The plant starts when the warped hand arrives on the top: where the reference's
			# support phase was lifted out of the ground (vault_idle, fix round 3), its hand came
			# down onto the top 0.13 s after the contact window opened, 25 cm above it, and the plant
			# dragged it down against the IK's added-motion limit: a 3.6 cm gap.)
			var top_h := float(geo.top_y) + HAND_ARRIVE_M
			if p.point_at(limb, t_on).y > top_h:
				var ta := t_on
				while ta < t_off - 0.05 and p.point_at(limb, ta).y > top_h:
					ta += 1.0 / p.hz
				if ta < t_off - 0.05:
					t_on = ta
		if kind == "hand" and not bool(c.get("annotated", false)):
			var pos := p.point_at(limb, t_on)
			var tt := t_on + 0.1
			while tt < t_off:
				if p.point_at(limb, tt).distance_to(pos) > HAND_HOLD_MAX:
					t_off = maxf(t_on + 0.05, tt - 1.0 / p.hz)
					break
				tt += 1.0 / p.hz
		var pin := {"limb": limb, "kind": kind, "surface": "top" if surf == "hang" else surf, "t_on": t_on, "t_off": t_off}
		if c.has("grip") and geo.has("face_normal"):
			var fnm: Vector3 = geo.face_normal
			fnm.y = 0.0
			pin["mode"] = "lip"
			pin["into"] = -fnm.normalized()
		p.pins.append(pin)
	_merge_split_plants(p)


## One stance split in two windows (a speed spike of a few samples in the reference): consecutive
## plants of the same limb on the same surface, less than MERGE_GAP_S apart and within MERGE_M of
## each other, are one plant (fix round 3, 2026-09-25: the raised beam's exit crossfaded the left
## foot between two such windows; the hold was dropped at the crossover and re-locked where the
## foot had drifted, a 6 cm slide of a standing foot).
const MERGE_GAP_S := 0.12
const MERGE_M := 0.03

static func _merge_split_plants(p: TravWarpedPath) -> void:
	var out: Array = []
	for pin: Dictionary in p.pins:
		var merged := false
		for q: Dictionary in out:
			if str(q.limb) != str(pin.limb) or str(q.surface) != str(pin.surface) or str(q.get("mode", "plant")) != str(pin.get("mode", "plant")):
				continue
			if str(pin.get("mode", "plant")) != "plant":
				continue
			var gap := float(pin.t_on) - float(q.t_off)
			if gap < 0.0 or gap > MERGE_GAP_S:
				continue
			# (The foot's ball or heel stays put; its contact point moves when it rolls onto the toes.)
			var still := p.point_at(str(pin.limb), float(q.t_off)).distance_to(p.point_at(str(pin.limb), float(pin.t_on))) <= MERGE_M
			if str(pin.limb).ends_with("foot"):
				for sub: String in ["ball", "heel"]:
					var nm: String = str(pin.limb).substr(0, 2) + sub
					if p.points.has(nm) and p.point_at(nm, float(q.t_off)).distance_to(p.point_at(nm, float(pin.t_on))) <= MERGE_M:
						still = true
			if not still:
				continue
			q.t_off = maxf(float(q.t_off), float(pin.t_off))
			merged = true
			break
		if not merged:
			out.append(pin)
	p.pins = out


## The lip-grip offsets of the primary contact (traversal_runtime.json contacts[].grip), or null.
static func _grip_of(move: Dictionary, prim: Variant) -> Variant:
	if prim == null:
		return null
	var pr: Dictionary = prim
	for c: Dictionary in move.get("contacts", []):
		if str(c.limb) == str(pr.limb) and absf(float(c.t_on) - float(pr.t)) < 1e-4 and c.has("grip"):
			return c.grip
	return null


## Inset of the primary hand behind the face, reduced when feet braced on the face ('wall'
## contacts while the hands are planted) would otherwise end up inside it.
static func _wall_safe_inset(p: TravWarpedPath, move: Dictionary, prim: Dictionary, inset: float) -> float:
	var ppos := Vector3(float(prim.pos[0]), float(prim.pos[1]), float(prim.pos[2]))
	var release: Variant = p.windows.get("release")
	var worst := -INF
	for c: Dictionary in move.get("contacts", []):
		if str(c.surface) != "wall" or str(c.kind) != "foot":
			continue
		if float(c.t_on) < float(prim.t) or (release != null and float(c.t_on) > float(release)):
			continue
		worst = maxf(worst, float(c.pos[2]) - ppos.z)
	if worst == -INF:
		return inset
	return clampf(minf(inset, -CLEAR_MARGIN - worst), minf(0.03, inset), inset)


## Inset of the primary hand behind the face, reduced so that the hands, while they rise to the
## top before their first contact, pass in FRONT of the face and not through the block (user
## complaint "snapping": the 0.98 m standing mantle's hands came up 7 cm behind the face and 15 cm
## under the top with the proposed 12 cm inset; the IK guards pushed them out and then flipped the
## push face, a 24 cm palm pop). Hands that grab the lip with their fingers keep at least
## HAND_INSET_MIN.
static func _hand_approach_inset(p: TravWarpedPath, move: Dictionary, prim: Dictionary, inset: float) -> float:
	var pl := str(prim.limb)
	if not pl.ends_with("hand") or not p.points.has(pl):
		return inset
	var ti := _idx(p, float(prim.t))
	var ref_c: Vector3 = (p.points[pl] as PackedVector3Array)[ti]
	var face_z := ref_c.z - inset
	var worst := 0.0
	for c: Dictionary in move.get("contacts", []):
		if str(c.kind) != "hand" or not str(c.surface) in ["top"]:
			continue
		var hp: PackedVector3Array = p.points.get(str(c.limb), PackedVector3Array())
		if hp.is_empty():
			continue
		var i_on := mini(int(c.i0), p.n - 1)
		var yc := hp[i_on].y
		for i in i_on:
			if hp[i].y < yc - HAND_CLEAR_H:
				worst = maxf(worst, hp[i].z - face_z + CLEAR_MARGIN)
	if worst <= 0.0:
		return inset
	p.metrics["hand_approach_backoff"] = worst
	return maxf(minf(inset, HAND_INSET_MIN), inset - worst)


static func _obstacle_box(geo: Dictionary, move: Dictionary = {}) -> Variant:
	var sup := float(geo.get("support_y", 0.0))
	var soles := bool(geo.get("sole_floor", str(move.get("intent", "")) in SOLE_FLOOR_INTENTS))
	var out := {"has_box": false, "support": sup, "landing": geo.get("landing_y"), "ground": bool(geo.get("ground_clear", true)),
			"clear_from": float(geo.get("clear_from", 0.0)), "soles": soles, "body": geo.get("body_clear", move.get("body_clear", false)),
			"open_below": bool(geo.get("open_below", false))}
	var fn: Vector3 = geo.get("face_normal", Vector3.ZERO)
	fn.y = 0.0
	if geo.has("face_point") and geo.get("top_y") != null and fn.length() > 1e-4:
		out.merge({"has_box": true, "fp": geo.face_point, "into": -fn.normalized(), "depth": float(geo.get("depth", INF)),
				"top": float(geo.top_y), "bottom": float(geo.get("box_bottom", sup - 0.5))}, true)
	elif geo.has("edge_point") and geo.has("gap"):
		# A gap: the support up to its near edge, nothing over it, the landing beyond (the soles).
		var fwd := Basis(Vector3.UP, float(geo.get("yaw", 0.0))) * Vector3(0, 0, 1)
		out.merge({"gap_from": geo.edge_point, "gap_dir": fwd, "gap_len": float(geo.gap)}, true)
		if not bool(out.ground) and not soles:
			return null
	elif not bool(out.ground) and not soles:
		return null
	return out


## The height a sole must not go below at world point w (d: its distance past the box's face along
## into), or -INF where nothing is under it (over the box, which the box test handles; over a gap;
## past a box with no landing known).
static func _sole_floor(box: Dictionary, w: Vector3, d: float) -> float:
	var sup := float(box.support)
	var land: Variant = box.landing
	if bool(box.has_box):
		var depth := float(box.depth)
		if d < -CLEAR_MARGIN:
			return sup
		if d > depth + CLEAR_MARGIN:
			return float(land) if land != null else -INF
		# (A platform over open ground, box open_below: the ground runs on under it.)
		return sup if bool(box.get("open_below", false)) and w.y < float(box.bottom) else -INF
	if box.has("gap_len"):
		var e := (w - (box.gap_from as Vector3)).dot(box.gap_dir as Vector3)
		if e < 0.0:
			return sup
		if e < float(box.gap_len):
			return -INF
		return float(land) if land != null else -INF
	return sup


## Adds clearance targets for samples where a track point (feet, knees, pelvis) is inside the
## obstacle; the cheaper of lifting over the top or backing out of the face. Returns the count.
static func _clearance(p: TravWarpedPath, box: Dictionary, add: Callable, dirty: Array = [true, true, true, 0.0]) -> int:
	var has_box := bool(box.has_box)
	var fp: Vector3 = box.get("fp", Vector3.ZERO)
	var into: Vector3 = box.get("into", Vector3.ZERO)
	var depth: float = box.get("depth", INF)
	var top: float = box.get("top", 0.0)
	var bottom: float = box.get("bottom", -INF)
	var sup: float = box.support
	var land: Variant = box.landing
	var land_y := float(land) if land != null else 0.0
	var ground := bool(box.ground)
	var open_below := bool(box.get("open_below", false))
	var binv := p.basis.inverse()
	var count := 0
	var i_from := int(round(float(box.get("clear_from", 0.0)) * p.hz))
	# Hoisted (cost: this runs over every sample and body point once per clearance pass).
	var tracks: Array = []
	var sole: Array = []
	var rad := PackedFloat32Array()
	for nm: String in CLEAR_POINTS:
		if p.points.has(nm):
			tracks.append(p.points[nm])
			sole.append(nm.ends_with("_foot") or nm.ends_with("_heel") or nm.ends_with("_ball"))
			rad.append(0.0)
	for sp: Array in SOLE_POINTS:
		if not p.points.has(str(sp[1])) or not p.points.has(str(sp[2])):
			continue
		var ha: PackedVector3Array = p.points[str(sp[1])]
		var hb: PackedVector3Array = p.points[str(sp[2])]
		var tt := PackedVector3Array()
		tt.resize(p.n)
		for i in p.n:
			var dd := (hb[i] - ha[i]).normalized()
			var upp := (Vector3.UP - dd * Vector3.UP.dot(dd)).normalized()
			tt[i] = ha[i].lerp(hb[i], float(sp[3])) + upp * float(sp[4])
		tracks.append(tt)
		sole.append(true)
		rad.append(0.0)
	# body: true (every body point) or a list of the body points' names without the side (a move
	# that needs only some of them: each point costs a track in every clearance pass).
	var body_sel: Variant = box.get("body", false)
	for bp: Array in (BODY_POINTS if (body_sel is Array or bool(body_sel)) else []):
		if not p.points.has(str(bp[1])) or not p.points.has(str(bp[2])):
			continue
		if body_sel is Array and not (body_sel as Array).has(str(bp[0]).trim_prefix("l_").trim_prefix("r_")):
			continue
		var pa: PackedVector3Array = p.points[str(bp[1])]
		var pb: PackedVector3Array = p.points[str(bp[2])]
		var tv := PackedVector3Array()
		tv.resize(p.n)
		var bofs: Vector3 = bp[5] if bp.size() > 5 else Vector3.ZERO
		for i in p.n:
			tv[i] = pa[i].lerp(pb[i], float(bp[3])) + bofs
		tracks.append(tv)
		sole.append(false)
		rad.append(float(bp[4]))
	var until := PackedInt32Array()
	until.resize(tracks.size())
	until.fill(p.n)
	var hand := PackedByteArray()
	hand.resize(tracks.size())
	for limb: String in (box.get("hand_until", {}) as Dictionary):
		tracks.append(p.points[limb])
		sole.append(false)
		rad.append(0.0)
		until.append(maxi(0, int(box.hand_until[limb]) - 1))
		hand.append(1)
	var np := tracks.size()
	var soles := bool(box.get("soles", false))
	# A move keeping its momentum (TravMomentum: the body's forward path is planned at the entry speed) clears the
	# obstacle by LIFTING only: pushing the body back or forward along the move (the cheapest correction otherwise)
	# made a run vault pulse slow-fast-slow over the top (0.7 m wall: 1.8 / 5.2 / 1.7 m/s against a flat 3.0 m/s
	# plan; user 2026-09-26: "some things are fast somethings are slow"); a lift over MOM_LIFT_MAX_M falls back.
	var mom := p.metrics.has("momentum")
	var origin := p.origin
	var bas := p.basis
	var fp_d := fp.dot(into)
	# Cost (fix round 3: the sole, body and coat points tripled the solve): the tracks' world
	# positions without the root correction are the same in every pass (cached in the box), each
	# pass adds the root correction per sample; tracks outer, samples inner, with the per-sample
	# worst kept in arrays. Same rule as per sample over the tracks.
	if not box.has("_wb") or int(box.get("_wb_n", -1)) != np:
		var wb := []
		var wys := []
		var wds := []
		for k0 in np:
			var tk0: PackedVector3Array = tracks[k0]
			var wk0 := PackedVector3Array()
			wk0.resize(p.n)
			var wy0 := PackedFloat64Array()
			wy0.resize(p.n)
			var wd0 := PackedFloat64Array()
			wd0.resize(p.n)
			for i0 in p.n:
				var q0 := origin + bas * tk0[i0]
				wk0[i0] = q0
				wy0[i0] = q0.y
				wd0[i0] = q0.dot(into) - fp_d
			wb.append(wk0)
			wys.append(wy0)
			wds.append(wd0)
		box["_wb"] = wb
		box["_wy"] = wys
		box["_wd"] = wds
		box["_wb_n"] = np
	var wbs: Array = box._wb
	var wys2: Array = box._wy
	var wds2: Array = box._wd
	var bdi := PackedVector3Array()
	bdi.resize(p.n)
	var bdy := PackedFloat64Array()
	bdy.resize(p.n)
	var bdd := PackedFloat64Array()
	bdd.resize(p.n)
	for i1 in range(i_from, p.n):
		var b1 := bas * p.delta[i1]
		bdi[i1] = b1
		bdy[i1] = b1.y
		bdd[i1] = b1.dot(into)
	var wl_arr := PackedFloat64Array()
	wl_arr.resize(p.n)
	wl_arr.fill(0.0)
	var worst_arr := PackedVector3Array()
	worst_arr.resize(p.n)
	# (_sole_floor inlined: the call and its dictionary reads per sole point and sample were a third
	# of the pass.)
	var has_land := land != null
	var has_gap := box.has("gap_len")
	var gap_from: Vector3 = box.get("gap_from", Vector3.ZERO)
	var gap_dir: Vector3 = box.get("gap_dir", Vector3.ZERO)
	var gap_len := float(box.get("gap_len", 0.0))
	for k in np:
		var wbk: PackedVector3Array = wbs[k]
		var wyk: PackedFloat64Array = wys2[k]
		var wdk: PackedFloat64Array = wds2[k]
		var sk := bool(sole[k])
		var hk := hand[k] == 1
		var r := rad[k]
		var gm := GROUND_MARGIN if r <= 0.0 else r - BODY_ALLOW
		# (A sole may stand on the top and touch the face: its margin is -SOLE_TOL; a tracked bone
		# point keeps CLEAR_MARGIN, a body point its radius less BODY_ALLOW.)
		var m := -SOLE_TOL if sk else (0.01 if hk else (CLEAR_MARGIN if r <= 0.0 else r - BODY_ALLOW))
		for i in range(i_from, mini(p.n, until[k])):
			var wy := wyk[i] + bdy[i]
			var d := wdk[i] + bdd[i] if has_box else -INF
			# The ground in front of the face and the landing beyond the far edge (design 13: no body
			# point below the support; the soles may touch it, SOLE_TOL).
			if sk:
				if soles:
					var gs := sup
					if has_box:
						if d >= -CLEAR_MARGIN:
							gs = (land_y if has_land else -INF) if d > depth + CLEAR_MARGIN else (sup if open_below and wy < bottom else -INF)
					elif has_gap:
						var e := (wbk[i] + bdi[i] - gap_from).dot(gap_dir)
						if e >= 0.0:
							gs = -INF if e < gap_len else (land_y if has_land else -INF)
					if gs > -INF and wy < gs - SOLE_TOL - 1e-3:
						var lift1 := gs - SOLE_TOL - wy
						if lift1 > wl_arr[i]:
							wl_arr[i] = lift1
							worst_arr[i] = Vector3.UP * lift1
			elif ground and not hk:
				var gy := sup
				if has_box and d > depth + CLEAR_MARGIN and land != null:
					gy = land_y
				elif has_box and d > -CLEAR_MARGIN and d < depth + CLEAR_MARGIN:
					gy = sup if open_below and wy < bottom else -INF
				if wy < gy + gm - 1e-3:
					var lift0 := gy + gm - wy
					if lift0 > wl_arr[i]:
						wl_arr[i] = lift0
						worst_arr[i] = Vector3.UP * lift0
			if not has_box:
				continue
			if d <= -m or d >= depth + m or wy >= top + m or wy < bottom - r:
				continue
			var lift := top + m - wy
			var back := d + m
			var fwdp := depth + m - d if depth < INF else INF
			var corr := Vector3.UP * lift
			var cost := lift
			if not mom or lift > MOM_LIFT_MAX_M:
				if back < cost:
					corr = -into * back
					cost = back
				if fwdp < cost:
					corr = into * fwdp
					cost = fwdp
			if cost > wl_arr[i]:
				wl_arr[i] = cost
				worst_arr[i] = corr
	for i in range(i_from, p.n):
		var wl := wl_arr[i]
		var worst := worst_arr[i]
		var di := p.delta[i]
		# Violations under CLEAR_TOL (inside the 3 cm margin, not the obstacle) are left: the passes
		# otherwise keep re-adding millimetre corrections until CLEAR_ITERS.
		if wl > CLEAR_TOL:
			var dm: Vector3 = binv * worst
			if worst.y > 0.0:
				if not box.has("need_y") or (box.need_y as PackedFloat64Array).size() != p.n:
					var ny := PackedFloat64Array()
					ny.resize(p.n)
					ny.fill(-1e9)
					box["need_y"] = ny
				box.need_y[i] = maxf(float(box.need_y[i]), di.y + dm.y)
			# (Only along the correction: pinning the other axes at their current values too made the
			# passes fight, a lift of one pass pinned against by the back-off of the next. And over the
			# neighbouring samples too: the root smoothing (_smooth_root) flattened a one-sample lift to
			# a tenth of it; fix round 3.)
			for ax2 in 3:
				if absf(dm[ax2]) > 1e-6:
					for k2 in range(-CLEAR_SPREAD, CLEAR_SPREAD + 1):
						var j2 := i + k2
						if j2 < i_from or j2 >= p.n:
							continue
						var wk := W_CLEAR * (1.0 - 0.25 * absf(k2))
						add.call(ax2, j2, wk, p.delta[j2][ax2] + dm[ax2])
			for ax in 3:
				if absf(dm[ax]) > 1e-6:
					dirty[ax] = true
			if dirty.size() > 3:
				dirty[3] = maxf(float(dirty[3]), wl)
			if dirty.size() > 4:
				dirty[4] = float(dirty[4]) + wl
			count += 1
	return count
