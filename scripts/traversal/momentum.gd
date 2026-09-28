class_name TravMomentum
extends RefCounted
## Vaults keep the body's speed at a steady tempo (user 2026-09-26, after the first momentum push: "the sprint
## vault some things are fast somethings are slow it should just be normal speed yo"; before it: "when we vault the
## char model should not slow down"). The source clips were made for the source game's gaits (the sprint vault
## enters at about 2.4 m/s and moves 1.8 m/s on average, the standing vault 1.6 / 1.4 m/s; Frontier runs at 3.3-3.6
## and sprints at 5.6 m/s). The first push ran each vault's clock at a rate per sample (up to 3.6-4.5 x where the
## clip's own body was slow, capped by the joints' speed): the hand plant and the leg swing fast-forwarded while
## the flight played near its own tempo. A move with a `momentum` block (traversal_moves.json) entered faster than
## its clip now plays like this:
##
##  - TIME: ONE constant rate for the whole move, chosen once at the entry from the entry speed (1 up to the
##    clip's own entry speed, rising to rate_max, 1.25, at rate_full_speed, a sprint): the pose never changes its
##    tempo inside the move (TravWarpedPath.rate holds that one value at every sample);
##  - SPACE: the root is motion-warped along the move's forward axis (forward_plan(), targets of the warp solve):
##    the pelvis crosses at entry speed / rate in move time, the entry speed in real time, wherever nothing holds
##    it back, and never slower than the clip's own travel. A planted hand or foot holds its WORLD position
##    (TraversalIK's hold) while the body goes on past it, as far as that limb reaches (measure(): per sample, how
##    far the body may move ahead of the clip's pose before the arm or leg would stretch past REACH_K of its
##    length). A hand that runs out of reach lets go of the top early and is lifted off it (an IK "lift" pin): at
##    a sprint the palm is on the top for about 0.1 s, as a runner's is. A foot that runs out of reach after the
##    hand plants (the landing's stance, the run-out) ends the move there: the locomotion takes the body over in
##    that step, at the gait phase of the planted foot (exit_gait()). A foot that would run out of reach before the
##    first hand plant (the standing vault's standing foot) moves the move's start later into its clip (trim);
##  - the move is started earlier on the approach by the extra ground the body covers before the hand plant
##    (prepare().trigger), so the hands still land on the top's edge (the warp's primary contact) and the feet land
##    on the ground beyond it.
##
## CARRY (user 2026-09-27, on the vaults played up to 2.3 x: "the animation speeds up it should just be normal speed",
## "the vault should be at the jog speed they lose speed back to jog not sprint and if they hold sprint again they
## rev back up"): a move whose momentum block sets carry_max carries at most that speed through it (the vaults: 2.5
## m/s, a jog) at its clip's own tempo (rate_max 1). The approach still does not brake; from the entry speed the
## body eases down to the carried speed over the run-in to the first hand plant (at most EASE_MAX_S), goes over at
## it and is handed back at it: the locomotion then speeds up again to the gait held (Shift: the sprint).
## Below ACTIVE_RATIO x its clip's own entry speed (a walk) a move plays exactly as authored. The approach does not
## brake for a move with momentum (max_entry_speed()). The clips are not changed; only where the root carries
## them, and one uniform playback rate.

const MIN_SPEED := 1.0            ## m/s: a moving entry (the pelvis lead applies from here)
const ACTIVE_RATIO := 1.05        ## the warp and the tempo apply above this x the clip's own entry speed
const RATE_MAX := 2.5             ## the fastest uniform tempo (momentum.rate_max overrides)
const RATE_FULL_SPEED := 5.6      ## m/s: the tempo reaches rate_max here, a sprint (momentum.rate_full_speed)
const REACH_K := 0.95             ## a held limb may stretch to this share of its length
const FOOT_ON_M := 0.03           ## a sole this close to the ground ...
const FOOT_SLOW := 0.6            ## ... moving slower than this (m/s, the clip's own) stands on it ...
const FOOT_MIN_N := 3             ## ... for at least this many samples
const HAND_MIN_S := 0.05          ## a hand plant cut shorter than this (move time) is dropped
## The take-off foot lets go once the body is this far ahead of the clip's pose over it (m): the leg cannot reach back
## much farther than the clip has it at push-off (the reach table allowed ~30 cm and the rendered foot was dragged
## 34-41 cm at the 0.9 m wall's run and sprint).
const FOOT_PRE_ROOM_M := 0.05
const LIFT_M := 0.08              ## a palm let go early is lifted this far off the top (momentum.lift_m)
const HOLD_MAX_M := 1.0           ## the IK holds a planted limb this far (its reach limits the warp first)
const TRIM_MAX_S := 0.15          ## the latest a move may start into its clip
const SPEED_MAX := 7.0            ## m/s: the fastest entry a move with momentum takes (momentum.speed_max)
const EASE_MAX_S := 0.3           ## a carried move eases from the entry speed to its carry over at most this (move time)
const CHAINS := {"l_hand": ["l_shoulder", "l_elbow", "l_wrist"], "r_hand": ["r_shoulder", "r_elbow", "r_wrist"],
		"l_foot": ["l_upper_leg", "l_knee", "l_ankle"], "r_foot": ["r_upper_leg", "r_knee", "r_ankle"]}

## move id -> {limb: PackedFloat32Array}: per path sample, how far (m, along the move's forward) the body may be
## ahead of the clip's pose while that limb stays where the clip has it; filled by measure().
static var _reach := {}
## move id -> [{limb, kind, surface, i0, i1}]: the clip's hand and foot contacts (the table's, and every sole
## standing on the ground: the table annotates one stance per foot, the run-outs stand on more).
static var _stance := {}
static var _trims := {}           ## "id|samples" -> the move started that far into its clip


## Measures, once per move with momentum, how far each limb reaches (the warp's limits) and where the clip's
## feet stand. `ap` plays the clips as `prefix + clip` (the player's and the preview's AnimationPlayer:
## "actor_b/"); `sk` gives the bones' rest and hierarchy (forward kinematics of the clip; the skeleton's pose
## is not touched).
static func measure(lib: TravMoveLibrary, ap: AnimationPlayer, prefix: String, sk: Skeleton3D) -> void:
	if lib == null or ap == null or sk == null:
		return
	var ids := {}
	for limb: String in CHAINS:
		for bn: String in CHAINS[limb]:
			ids[bn] = sk.find_bone(bn)
	for id: String in lib.moves:
		var m: Dictionary = lib.moves[id]
		if config(m).is_empty() or _reach.has(id):
			continue
		var tr: Dictionary = m.get("track", {})
		var hz := float(tr.get("hz", 60.0))
		var n := int(tr.get("n", 0))
		var parts: Array = m.get("parts", [])
		if n < 2 or parts.is_empty():
			continue
		var vals := {}
		for limb: String in CHAINS:
			vals[limb] = []
			(vals[limb] as Array).resize(n)
			(vals[limb] as Array).fill(0.0)
		var tracks := {}
		for i in n:
			var t := minf(i / hz, float(m.get("duration", 0.0)))
			var k := 0
			while k < parts.size() - 1 and t >= float(parts[k + 1].t0) - TravWarpedPath.PART_EPS:
				k += 1
			var pd: Dictionary = parts[k]
			var a := ap.get_animation(prefix + str(pd.clip))
			if a == null:
				continue
			if not tracks.has(a.get_instance_id()):
				tracks[a.get_instance_id()] = _track_map(a)
			var tm: Dictionary = tracks[a.get_instance_id()]
			var ct := clampf(t - float(pd.t0), 0.0, a.length)
			var cache := {}
			for limb: String in CHAINS:
				var ch: Array = CHAINS[limb]
				if int(ids[ch[0]]) < 0 or int(ids[ch[1]]) < 0 or int(ids[ch[2]]) < 0:
					continue
				var A := _fk(sk, a, tm, ct, int(ids[ch[0]]), cache).origin
				var B := _fk(sk, a, tm, ct, int(ids[ch[1]]), cache).origin
				var C := _fk(sk, a, tm, ct, int(ids[ch[2]]), cache).origin
				(vals[limb] as Array)[i] = _reach_fwd(A, B, C)
		var res := {}
		for limb: String in CHAINS:
			res[limb] = PackedFloat32Array(vals[limb])
		_reach[id] = res
		_stance[id] = _stances(m)


## Bone name -> [position, rotation, scale] track indices of an animation (-1: none).
static func _track_map(a: Animation) -> Dictionary:
	var out := {}
	for j in a.get_track_count():
		var bn := String(a.track_get_path(j)).get_slice(":", 1)
		if bn == "":
			continue
		if not out.has(bn):
			out[bn] = [-1, -1, -1]
		match a.track_get_type(j):
			Animation.TYPE_POSITION_3D:
				out[bn][0] = j
			Animation.TYPE_ROTATION_3D:
				out[bn][1] = j
			Animation.TYPE_SCALE_3D:
				out[bn][2] = j
	return out


## Skeleton-space transform of `bone` in clip `a` at clip time t (the rest where a track is missing).
static func _fk(sk: Skeleton3D, a: Animation, tm: Dictionary, t: float, bone: int, cache: Dictionary) -> Transform3D:
	if cache.has(bone):
		return cache[bone]
	var rest := sk.get_bone_rest(bone)
	var pos := rest.origin
	var rot := rest.basis.get_rotation_quaternion()
	var scl := rest.basis.get_scale()
	var tj: Array = tm.get(sk.get_bone_name(bone), [-1, -1, -1])
	if int(tj[0]) >= 0:
		pos = a.position_track_interpolate(int(tj[0]), t)
	if int(tj[1]) >= 0:
		rot = a.rotation_track_interpolate(int(tj[1]), t)
	if int(tj[2]) >= 0:
		scl = a.scale_track_interpolate(int(tj[2]), t)
	var local := Transform3D(Basis(rot) * Basis.from_scale(scl), pos)
	var par := sk.get_bone_parent(bone)
	var g := local if par < 0 else _fk(sk, a, tm, t, par, cache) * local
	cache[bone] = g
	return g


## How far (m, skeleton +Z: the move's forward) the chain's root A may move while its end C stays, before the
## chain A-B-C would stretch past REACH_K of its length.
static func _reach_fwd(A: Vector3, B: Vector3, C: Vector3) -> float:
	var L := REACH_K * (A.distance_to(B) + B.distance_to(C))
	var v := A - C
	var disc := v.z * v.z - v.length_squared() + L * L
	if disc < 0.0:
		return 0.0
	return maxf(0.0, -v.z + sqrt(disc))


## The clip's contacts: the table's hand and foot contacts, and every stance of a sole on the start's or the
## landing's ground (within FOOT_ON_M, slower than FOOT_SLOW, FOOT_MIN_N samples or more), merged per foot.
static func _stances(m: Dictionary) -> Array:
	var tr: Dictionary = m.get("track", {})
	var n := int(tr.get("n", 0))
	var hz := float(tr.get("hz", 60.0))
	var out: Array = []
	for c: Dictionary in m.get("contacts", []):
		var surf := str(c.surface)
		if not (str(c.kind) in ["hand", "foot"] and surf in ["top", "hang", "support", "landing"]):
			continue
		out.append({"limb": str(c.limb), "kind": str(c.kind), "surface": surf, "i0": int(c.i0), "i1": mini(int(c.i1), n - 1)})
	var an: Dictionary = m.get("anchor", {})
	var g0 := float(an.get("start_h", 0.0))
	var g1 := float(an.get("end_h", g0))
	for side: String in ["l", "r"]:
		if not tr.has(side + "_ball") or not tr.has(side + "_heel"):
			continue
		var ball := TravMotionWarper._vec3s(tr[side + "_ball"])
		var heel := TravMotionWarper._vec3s(tr[side + "_heel"])
		var on := []
		for i in n:
			var y := minf(ball[i].y, heel[i].y)
			var j0 := maxi(i - 1, 0)
			var j1 := mini(i + 1, n - 1)
			var vb := Vector2(ball[j1].x - ball[j0].x, ball[j1].z - ball[j0].z).length() * hz / maxf(j1 - j0, 1)
			var vh := Vector2(heel[j1].x - heel[j0].x, heel[j1].z - heel[j0].z).length() * hz / maxf(j1 - j0, 1)
			var near := minf(absf(y - g0), absf(y - g1)) < FOOT_ON_M
			on.append(near and minf(vb, vh) < FOOT_SLOW)
		var i := 0
		while i < n:
			if not bool(on[i]):
				i += 1
				continue
			var j := i
			while j + 1 < n and bool(on[j + 1]):
				j += 1
			if j - i + 1 >= FOOT_MIN_N:
				var y0 := minf(ball[i].y, heel[i].y)
				var s := {"limb": side + "_foot", "kind": "foot", "surface": "support" if absf(y0 - g0) <= absf(y0 - g1) else "landing",
						"i0": i, "i1": j, "found": true}
				var merged := false
				for c: Dictionary in out:
					if str(c.limb) == str(s.limb) and int(c.i0) <= j + 1 and int(c.i1) >= i - 1:
						c.i0 = mini(int(c.i0), i)
						c.i1 = maxi(int(c.i1), j)
						merged = true
						break
				if not merged:
					out.append(s)
			i = j + 1
	return out


## The move's momentum settings (traversal_moves.json `momentum`), {} when it has none.
static func config(move: Dictionary) -> Dictionary:
	var m: Variant = move.get("momentum")
	return m if m is Dictionary and bool((m as Dictionary).get("enabled", true)) else {}


## True when a move entered at speed v keeps it: it has momentum and the body is faster than the clip's own entry.
static func active(move: Dictionary, v: float) -> bool:
	if config(move).is_empty():
		return false
	return v >= maxf(MIN_SPEED, float(move.get("entry_speed", 0.0)) * ACTIVE_RATIO)


## The move's one playback rate for entry speed v: 1 at the clip's own entry speed, rate_max at rate_full_speed.
static func rate_for(move: Dictionary, v: float) -> float:
	if not active(move, v):
		return 1.0
	var cfg := config(move)
	var r_max := float(cfg.get("rate_max", RATE_MAX))
	# One tempo for the whole move, matched to the run-up (user 2026-09-26: "we just wanted the animation and the
	# lead up to be at a consistent speed"): the entry speed over the clip's own entry speed, so the move plays as
	# fast as it is entered, the same all through (its flight shortens with it: no float after the top).
	return clampf(v / maxf(float(move.get("entry_speed", 0.0)), 0.1), 1.0, r_max)


## The fastest entry speed (m/s) the move takes: the approach cap. Without momentum the clip's own entry speed
## (the approach eases the body down to it, as before).
static func max_entry_speed(move: Dictionary) -> float:
	var cfg := config(move)
	if cfg.is_empty():
		return float(move.get("entry_speed", 0.0))
	return float(cfg.get("speed_max", SPEED_MAX))


## How far behind its root the move's first pose stands its pelvis (m, along the move's forward; the sprint
## vault's first pose stands it 14 cm behind): a moving entry is solved that much ahead of the feet, so its first
## pelvis is where the body's is (started at the feet, the pelvis was inertialized back: the model stopped for a
## moment at a walk or a jog, and fell to 1.3 m/s from a run). 0 for a standing entry or without momentum.
static func pelvis_lead(move: Dictionary, speed: float, trim := 0) -> float:
	if config(move).is_empty() or speed < MIN_SPEED:
		return 0.0
	var tr: Dictionary = move.get("track", {})
	var pel: Array = tr.get("pelvis", [])
	var al: Array = tr.get("align", [])
	if pel.size() < trim * 3 + 3 or al.size() < 3:
		return 0.0
	return clampf(float(al[2]) - float(pel[trim * 3 + 2]), -0.3, 0.3)


## How the move plays at entry speed v: {move (trimmed when it starts later into its clip), rate, u (the body's
## forward speed in move time), trim (samples), lead (the pelvis lead of the move as played: the solve starts
## that far ahead of the feet), trigger (how far before the planned start point S, solved at the clip's own
## timing, the move starts: the pelvis lead plus the extra ground the body covers before the first hand plant),
## pre (that extra), active}. Without momentum (or below its speed) the move as authored, with its pelvis lead.
static func prepare(move_id: String, move: Dictionary, v: float) -> Dictionary:
	var lead0 := pelvis_lead(move, v)
	var out := {"move": move, "rate": 1.0, "u": v, "trim": 0, "lead": lead0, "trigger": lead0, "pre": 0.0, "active": false}
	if not active(move, v) or not _reach.has(move_id):
		return out
	var tr: Dictionary = move.get("track", {})
	var hz := float(tr.get("hz", 60.0))
	var n := int(tr.get("n", 0))
	var r := rate_for(move, v)
	var u := minf(v / r, float(config(move).get("carry_max", INF)))
	var u0 := v / r               # (the speed the move starts at: eased down to u before the first hand plant)
	var pel := _z(tr.get("pelvis", []), n)
	var zero := PackedFloat64Array()
	zero.resize(n)
	zero.fill(0.0)
	# The earliest start into the clip that no foot's reach holds back before the first hand plant.
	var trim := 0
	var fp := {}
	for s in int(TRIM_MAX_S * hz) + 1:
		var fs := forward_plan(move_id, pel.slice(s), zero.slice(s), u, s, hz, false, u0)
		if s == 0:
			fp = fs
		if not bool(fs.pre_capped):
			trim = s
			fp = fs
			break
	var i_on := int(fp.i_on)
	var F: PackedFloat64Array = fp.F
	var al: Array = tr.get("align", [])
	var al0 := float(al[2]) if al.size() >= 3 else 0.0
	# (The body's pelvis at the first hand plant: where the plan from S has the clip's; the plan's own lead is
	# al0 - pel[0], the pelvis at the feet.)
	var pre := 0.0
	if i_on > 0 and i_on < F.size():
		pre = (F[i_on] - F[0]) - (pel[i_on + trim] - pel[0])
	out.move = _trimmed(move_id, move, trim)
	out.rate = r
	out.u = u
	out.u0 = u0
	out.trim = trim
	out.lead = pelvis_lead(move, v, trim)
	out.trigger = clampf(al0 - pel[0], 0.0, 0.3) + pre
	out.pre = pre
	out.active = true
	return out


## The move as started `s` samples into its clip (the parts, tracks, contacts and windows shifted; the part
## that starts before it plays from that far into its clip, part clip_t0). Cached.
static func _trimmed(move_id: String, move: Dictionary, s: int) -> Dictionary:
	if s <= 0:
		return move
	var key := "%s|%d" % [move_id, s]
	if _trims.has(key):
		return _trims[key]
	var tr: Dictionary = move.get("track", {})
	var hz := float(tr.get("hz", 60.0))
	var n := int(tr.get("n", 0))
	var ts := s / hz
	var m := move.duplicate()
	var t2 := tr.duplicate()
	for k: String in tr:
		if tr[k] is Array and (tr[k] as Array).size() == n * 3:
			t2[k] = (tr[k] as Array).slice(s * 3)
	t2["n"] = n - s
	m["track"] = t2
	m["duration"] = float(move.get("duration", 0.0)) - ts
	var parts: Array = []
	for p: Dictionary in move.get("parts", []):
		var q := p.duplicate()
		var t0 := float(p.t0) - ts
		var ln := float(p.get("length", 0.0))
		if t0 + ln <= 1e-4:
			continue
		if t0 < 0.0:
			q["clip_t0"] = float(p.get("clip_t0", 0.0)) - t0
			q["length"] = ln + t0
			t0 = 0.0
		q["t0"] = snappedf(t0, 1e-4)
		parts.append(q)
	m["parts"] = parts
	var cs: Array = []
	for c: Dictionary in move.get("contacts", []):
		if int(c.get("i1", 0)) < s:
			continue
		var q2 := c.duplicate()
		q2["i0"] = maxi(int(c.get("i0", 0)) - s, 0)
		q2["i1"] = int(c.get("i1", 0)) - s
		q2["t_on"] = maxf(float(c.get("t_on", 0.0)) - ts, 0.0)
		q2["t_off"] = float(c.get("t_off", 0.0)) - ts
		cs.append(q2)
	m["contacts"] = cs
	var w: Dictionary = (move.get("windows", {}) as Dictionary).duplicate(true)
	for k2: String in w.keys():
		if w[k2] is float or w[k2] is int:
			w[k2] = maxf(float(w[k2]) - ts, 0.0)
		elif w[k2] is Array:
			var fl: Array = []
			for f: Variant in w[k2]:
				if f is Array and (f as Array).size() == 2 and float(f[1]) - ts > 0.0:
					fl.append([maxf(float(f[0]) - ts, 0.0), float(f[1]) - ts])
			w[k2] = fl
	m["windows"] = w
	var an: Dictionary = (move.get("anchor", {}) as Dictionary).duplicate(true)
	if an.get("primary") is Dictionary:
		var pr: Dictionary = an.primary
		pr["t"] = maxf(float(pr.get("t", 0.0)) - ts, 0.0)
		if pr.has("t_off"):
			pr["t_off"] = float(pr.t_off) - ts
	m["anchor"] = an
	m["momentum_trim"] = s
	_trims[key] = m
	return m


static func _z(flat: Array, n: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(n)
	for i in n:
		out[i] = float(flat[i * 3 + 2]) if i * 3 + 2 < flat.size() else (out[i - 1] if i > 0 else 0.0)
	return out


## The body's forward path through the move (move frame +Z, per sample): {F (the pelvis's forward position),
## i_on (the first hand plant), release {stance index: sample the hand lets go at}, end (the sample the move
## hands back at, -1: its end), pre_capped (a foot's reach held the body back before the first hand plant),
## capped (samples the body was held back at), stances (this move's, shifted by trim)}.
##   pel   the clip's pelvis forward position per sample (the reference track)
##   base  the warp's forward offset solved without momentum (0 when planning): the primary contact's target and
##         what the plants hold
##   u     the body's forward speed in move time (entry speed / rate, at most the move's carry_max)
##   u0    the speed the move starts at (< 0: u), eased down to u over the samples before the first hand plant
##         (at most EASE_MAX_S)
##   trim  how far into the clip the move starts (the stance and reach tables are the untrimmed clip's)
## The pelvis goes on at max(u, the clip's own speed) wherever no planted limb holds it; a planted limb lets the
## body move ahead of the clip's pose by at most its reach at that sample. `primary`: the path meets the solved
## primary contact (the first hand plant's forward offset base[i_on]), the difference spread evenly over the
## approach.
static func forward_plan(move_id: String, pel: PackedFloat64Array, base: PackedFloat64Array, u: float, trim: int, hz: float,
		primary := true, u0 := -1.0) -> Dictionary:
	var n := pel.size()
	var st: Array = []
	for c: Dictionary in _stance.get(move_id, []):
		if int(c.i1) - trim < 0:
			continue
		var q := c.duplicate()
		q["i0"] = maxi(int(c.i0) - trim, 0)
		q["i1"] = mini(int(c.i1) - trim, n - 1)
		st.append(q)
	var reach: Dictionary = _reach.get(move_id, {})
	var i_on := n
	var hand_off := -1
	for c: Dictionary in st:
		if str(c.kind) == "hand":
			i_on = mini(i_on, int(c.i0))
			hand_off = maxi(hand_off, int(c.i1))
	var P := PackedFloat64Array()
	P.resize(n)
	for i in n:
		P[i] = pel[i] + (base[i] if i < base.size() else 0.0)
	var F := PackedFloat64Array()
	F.resize(n)
	F[0] = P[0]
	var anchor := {}
	var release := {}
	var end := -1
	var pre_capped := false
	var capped := 0
	var step := u / hz
	var ease_n := float(mini(i_on, int(EASE_MAX_S * hz))) if u0 > u else 0.0
	for i in range(1, n):
		if ease_n > 0.0:
			step = lerpf(u0, u, smoothstep(0.0, ease_n, float(i))) / hz
		# (Before the first hand plant the clip's own motion: the solved base ramps onto the primary contact there.)
		var dv := (P[i] - P[i - 1]) if i > i_on else (pel[i] - pel[i - 1])
		var want := F[i - 1] + maxf(step, dv)
		var lim := INF
		var stop := false
		for k in st.size():
			var c: Dictionary = st[k]
			var i0 := int(c.i0)
			var i1 := int(c.i1)
			if i < i0 or i > i1 or release.has(k):
				continue
			var ref := pel if i1 <= i_on else P
			if not anchor.has(k):
				anchor[k] = (F[i0] - ref[i0]) if i0 < i else (want - ref[i])
				if i0 == i:
					continue
			var ra: PackedFloat32Array = reach.get(str(c.limb), PackedFloat32Array())
			var room := float(ra[i + trim]) if i + trim < ra.size() else 0.0
			var cap := ref[i] + float(anchor[k]) + room
			if want <= cap + 1e-6:
				continue
			if str(c.kind) == "hand":
				release[k] = i
			elif hand_off >= 0 and i0 >= hand_off:
				stop = true
			elif i1 <= i_on:
				# the take-off foot: it pushes off and lifts when the body passes its reach (checked on the final
				# path below), it does not hold the body back (user 2026-09-26: "some things are fast somethings
				# are slow"; holding back made the run's 0.7 m wall dip to 70 %)
				pass
			else:
				lim = minf(lim, cap)
				if i <= i_on:
					pre_capped = true
		if stop:
			end = i - 1
			break
		if lim < want:
			capped += 1
		F[i] = minf(want, lim)
	if end > 0:
		for i in range(end + 1, n):
			F[i] = F[i - 1] + (F[end] - F[end - 1])
	if primary and i_on > 0 and i_on < n:
		var err := P[i_on] - F[i_on]
		for i in range(1, n):
			F[i] += err * minf(float(i) / i_on, 1.0)
	# The take-off foot (a foot stance ending by the first hand plant) lets go where the final path (after the
	# primary contact's correction) carries the body past its reach: the plant ends there and the foot swings
	# on with the clip's pose (no skating; the harness measured 40 cm at a sprint while it was dragged).
	for k in st.size():
		var c: Dictionary = st[k]
		if str(c.kind) != "foot" or release.has(k) or int(c.i1) > i_on:
			continue
		var i0 := int(c.i0)
		var ra: PackedFloat32Array = reach.get(str(c.limb), PackedFloat32Array())
		var a0 := F[i0] - pel[i0]
		for i in range(i0 + 1, mini(int(c.i1), n - 1) + 1):
			var room := minf(float(ra[i + trim]) if i + trim < ra.size() else 0.0, FOOT_PRE_ROOM_M)
			if F[i] > pel[i] + a0 + room + 1e-6:
				release[k] = i
				break
	return {"F": F, "i_on": i_on, "release": release, "end": end, "pre_capped": pre_capped, "capped": capped, "stances": st}


## The path's plants as the momentum path holds them (after TravMotionWarper._pins): a hand that runs out of
## reach lets go when it does (its plant ends there; shorter than HAND_MIN_S it is dropped) and a "lift" pin lifts
## the palm off the top until the clip's own release; every stance of a foot the table does not annotate is
## planted too (with the body going on past it, a sole the clip holds on the ground would skate); every plant is
## held up to HOLD_MAX_M (the reach limited the warp); the move hands back at fp.end.
static func shape_pins(p: TravWarpedPath, fp: Dictionary, lift_m := LIFT_M) -> void:
	var hz := p.hz
	var st: Array = fp.get("stances", [])
	var rel: Dictionary = fp.get("release", {})
	var end := int(fp.get("end", -1))
	if end > 0 and end < p.n - 1:
		p.end_t = end / hz
	var te := p.end_time()
	var out: Array = []
	for pin: Dictionary in p.pins:
		out.append(pin)
	for k: int in rel:
		var c: Dictionary = st[k]
		var limb := str(c.limb)
		var t_rel := (int(rel[k]) - 1) / hz
		var c_on := int(c.i0) / hz
		var c_off := int(c.i1) / hz
		var lift_on := t_rel
		for pin: Dictionary in out.duplicate():
			if str(pin.limb) != limb or str(pin.get("mode", "plant")) != "plant":
				continue
			if float(pin.t_off) < c_on - 0.02 or float(pin.t_on) > c_off + 0.02:
				continue
			pin.t_off = minf(float(pin.t_off), t_rel)
			if float(pin.t_off) - float(pin.t_on) < HAND_MIN_S:
				out.erase(pin)
				lift_on = minf(lift_on, float(pin.t_on))
		if str(c.kind) == "hand" and c_off > lift_on + 0.03 and lift_m > 0.0:
			out.append({"limb": limb, "kind": "hand", "surface": str(c.get("surface", "top")), "mode": "lift", "lift": lift_m,
					"t_on": lift_on, "t_off": c_off})
	for k in st.size():
		var c: Dictionary = st[k]
		if str(c.kind) != "foot" or not bool(c.get("found", false)):
			continue
		var t_on := int(c.i0) / hz
		var t_off := minf(int(c.i1) / hz, te)
		if rel.has(k):
			t_off = minf(t_off, (int(rel[k]) - 1) / hz)   # a released take-off foot: its plant ends where it lets go
		if t_off <= t_on:
			continue
		var covered := false
		for pin: Dictionary in out:
			if str(pin.limb) == str(c.limb) and str(pin.get("mode", "plant")) == "plant" and float(pin.t_on) <= t_off + 0.02 \
					and float(pin.t_off) >= t_on - 0.02:
				pin.t_on = minf(float(pin.t_on), t_on)
				pin.t_off = maxf(float(pin.t_off), t_off)
				covered = true
		if not covered:
			out.append({"limb": str(c.limb), "kind": "foot", "surface": str(c.surface), "t_on": t_on, "t_off": t_off})
	# The take-off foot is not pinned at speed (a foot plant ending by the first hand plant): the body passes over it
	# faster than the clip does, so the plant held it on the ground while the leg swung on (dragged 30-45 cm in 50 ms
	# at the 0.9 m wall's run and sprint); it follows the clip's own push-off instead. Walk-speed moves are not
	# shaped here and keep their plants.
	var t_hand := float(int(fp.get("i_on", 0))) / hz
	for pin: Dictionary in out.duplicate():
		if str(pin.get("mode", "plant")) == "plant" and str(pin.limb).ends_with("foot") and float(pin.t_off) <= t_hand + 0.02:
			out.erase(pin)
	for pin: Dictionary in out:
		if str(pin.get("mode", "plant")) == "plant":
			pin["hold_max"] = HOLD_MAX_M
	p.pins = out


## A plan about to start at entry speed v: the one playback rate on its path (every sample), the metrics;
## returns the rate.
static func apply(p: TravMovePlan, v: float) -> float:
	if p == null or p.path == null:
		return 1.0
	var mom: Dictionary = p.geo.get("momentum", {})
	if mom.is_empty():
		p.path.rate = PackedFloat32Array()
		return 1.0
	var r := float(mom.get("rate", 1.0))
	var rt := PackedFloat32Array()
	rt.resize(p.path.n)
	rt.fill(r)
	p.path.rate = rt
	p.rate = r
	var m: Dictionary = p.path.metrics.get("momentum", {})
	m["v_in"] = v
	m["rate"] = r
	p.path.metrics["momentum"] = m
	return r


## The gait the locomotion goes on in after a move handed back before its end (TravWarpedPath.end_t): the foot
## the move's last stance stands on (left plant 0, right plant 0.5 of the gait cycle) and how long it has stood
## there (real seconds); {} when no foot stands at the hand-back.
static func exit_gait(p: TravWarpedPath) -> Dictionary:
	if p == null or p.end_t <= 0.0:
		return {}
	var te := p.end_time()
	var best := {}
	for pin: Dictionary in p.pins:
		var limb := str(pin.get("limb", ""))
		if not limb.ends_with("foot") or str(pin.get("mode", "plant")) != "plant":
			continue
		if float(pin.t_on) <= te + 1e-4 and float(pin.t_off) >= te - 1e-4 and (best.is_empty() or float(pin.t_on) > float(best.t_on)):
			best = pin
	if best.is_empty():
		return {}
	return {"plant": 0.0 if str(best.limb).begins_with("l") else 0.5, "since_s": p.real_time(float(best.t_on), te)}
