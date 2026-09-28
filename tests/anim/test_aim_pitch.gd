extends AnimTestSuite
## WP5 (plan sections 6.9, 6.11 and 10): aim pitch in AIM_IDLE. For every weapon x stance the lower
## body plays the full-body aim base (aimidle__<w>__<s>, in step with the aim tree), U_aim = 1,
## and the aim elevation sweeps -40..+40 deg in 10 deg steps toward a crosshair point 25 m ahead.
##   - graph pitch (trim off): the aim-up / aim-down additives (graph C8+248 / C8+252), weighted
##     through the measured calibration (metrics pitch.<w>/<s>, measured at the aim base's t = 0),
##     put the barrel's elevation within 2.5 deg of the elevation of the muzzle -> crosshair line
##     at that phase; over the rest of the loop the aim idle's authored breathing adds to it
##     (reported); the aim clips' baked yaw offset is reported;
##   - with the AimStabilizer trim (default; Frontier requirement: the weapon stays on the
##     crosshair, replacing the per-weapon aim_yaw / aim_pitch offsets) the barrel direction is
##     within 2.5 deg of the muzzle -> crosshair direction (plan threshold), also for a 4 m target;
##   - the trim's pitch part stays small (the additives do the pitch; <= 4 deg);
##   - the crouched bow is held sideways (the prop's up axis 90 +- 10 deg from vertical about the
##     arrow, from actor_b-p-bow-aim-crouch-idle), the standing bow near upright (< 35 deg, the
##     authored cant), the firearms upright (< 15 deg);
##   - blocked (graph C8+172): an obstacle closer than half the weapon's length drives the
##     blocked pose to 1 within 0.6 s and turns the trim off (trim weight 1 - blocked);
##   - beyond the plan's range (the camera allows +-80 deg, player.gd pitch_limit_deg): with the
##     trim, within 2.5 deg up to +-60; from +-70 the pitch additives' solve range and the trim
##     clamps (AimStabilizer trim_max_yaw_deg 25 / trim_max_pitch_deg 12, proposed values for
##     the owner to confirm) saturate and the barrel leaves the crosshair: documented tolerance
##     EXTREME_TOL_DEG, reported per weapon with the trim (the torso's twist against the legs).
## Barrel = the weapon's prop bone +Z (Frontier convention: prop +Z = barrel, +Y = up; the models
## hang off it with a fixed half turn about Y), read after the stabilizer (skeleton_updated).

const UpperRig := preload("res://tests/anim/upper_rig.gd")
const TOL_DEG := 2.5
const TRIM_PITCH_MAX_DEG := 4.0
const ELEVS := [-40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0]
## Outside the plan's +-40: within TOL_DEG up to +-60, EXTREME_TOL_DEG up to +-80 (documented).
const EXTREME_ELEVS := [-80.0, -70.0, -60.0, -50.0, 50.0, 60.0, 70.0, 80.0]
const EXTREME_TOL_DEG := 15.0


func describe() -> String:
	return "AIM_IDLE pitch: barrel vs crosshair direction, 3 weapons x 2 stances x -40..+40 deg (graph pitch; trim)"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	h.capture_bones = PackedStringArray(["l_hand_prop_attachment", "r_hand_prop_attachment"])
	h.inp.weapon_aim = 1.0
	h.inp.wants_aim = true
	var summary := []
	for w in _barrel_weapons(h.data):
		for st in ["stand", "crouch"]:
			h.inp.crouched = st == "crouch"
			h.set_weapon(StringName(w))
			h.step(1)
			h.set_lower(StringName("aimidle__%s__%s" % [w, st]), h.upper.aim_phase(w, st), &"AIM_IDLE")
			# Settle: selector fades, and the crouch-change additive (1 s) a stance change plays.
			h.step(80)
			var res := {}
			for trim in [false, true]:
				h.stab.aim_trim = trim
				var worst := {"dir": 0.0, "elev": 0.0, "elev_run": 0.0, "yaw_min": INF, "yaw_max": -INF, "trim_pitch": 0.0, "trim_yaw": 0.0}
				for e in ELEVS:
					h.aim_at(e)
					h.step(12)
					await h.frame()
					var m := _measure(h, w)
					worst.dir = maxf(worst.dir, m.dir)
					worst.elev_run = maxf(worst.elev_run, absf(m.elev))
					worst.yaw_min = minf(worst.yaw_min, m.yaw)
					worst.yaw_max = maxf(worst.yaw_max, m.yaw)
					if trim:
						var td: Vector2 = h.stab.last_trim_deg()
						worst.trim_pitch = maxf(worst.trim_pitch, absf(td.y))
						worst.trim_yaw = maxf(worst.trim_yaw, absf(td.x))
					else:
						# The calibration's phase: aim tree and full-body aim base at t = 0.
						h.upper.A.seek(StringName("A__%s__%s" % [w, st]), 0.0)
						h.L.seek(StringName("aimidle__%s__%s" % [w, st]), 0.0)
						h.step(1, 0.0)
						await h.frame()
						worst.elev = maxf(worst.elev, absf(_measure(h, w).elev))
				res[trim] = worst
			var g: Dictionary = res[false]
			var t: Dictionary = res[true]
			ctx.at_most(g.elev, TOL_DEG, "%s/%s graph pitch (trim off, aim base at t = 0): barrel elevation vs muzzle->crosshair, worst over -40..+40 (deg)" % [w, st])
			ctx.info("%s/%s trim off: over the aim idle loop the elevation error reaches %.2f deg (authored breathing); barrel yaw off the crosshair %.1f..%.1f deg (the aim clip's baked stance)" % [
					w, st, g.elev_run, g.yaw_min, g.yaw_max])
			ctx.at_most(t.dir, TOL_DEG, "%s/%s with the aim trim: barrel direction vs muzzle->crosshair, worst over -40..+40 (deg)" % [w, st])
			ctx.at_most(t.trim_pitch, TRIM_PITCH_MAX_DEG, "%s/%s trim pitch part stays small (deg)" % [w, st])
			ctx.metric("%s_%s_graph_elev_err_deg" % [w, st], g.elev)
			ctx.metric("%s_%s_trim_dir_err_deg" % [w, st], t.dir)
			summary.append("%s/%s graph elev %.2f (loop %.2f) yaw %.1f..%.1f | trim dir %.4f (trim yaw %.1f pitch %.1f)" % [
					w, st, g.elev, g.elev_run, g.yaw_min, g.yaw_max, t.dir, t.trim_yaw, t.trim_pitch])
			# Cant at level aim (Frontier: the sideways crouched bow).
			h.aim_at(0.0)
			h.step(12)
			await h.frame()
			var cant := _cant(h, w)
			if w == "bow" and st == "crouch":
				ctx.near(absf(cant), 90.0, 10.0, "bow/crouch held sideways: cant (deg) %.1f" % cant)
			elif w == "bow":
				ctx.at_most(absf(cant), 35.0, "bow/stand held near upright (the authored archer's cant; today's game 13-20 deg): |cant| (deg)")
			else:
				ctx.at_most(absf(cant), 15.0, "%s/%s held upright: |cant| (deg)" % [w, st])
			# Near target (4 m, lever arm of the muzzle): still on the crosshair with the trim.
			h.stab.aim_trim = true
			h.aim_at(10.0, 4.0)
			h.step(12)
			await h.frame()
			var near := _measure(h, w)
			ctx.at_most(near.dir, TOL_DEG, "%s/%s with the aim trim, 4 m target at +10 deg (deg)" % [w, st])
	for s in summary:
		ctx.info(s)
	await _extreme(ctx, h)
	# Blocked: a wall 0.3 m ahead of the chest with the musket (1.5 m).
	h.snap(&"musket", "stand", 0.0, 0.0)
	h.set_lower(&"aimidle__musket__stand", 0.0, &"AIM_IDLE")
	h.stab.aim_trim = true
	h.inp.blocked_hit_m = 0.3
	h.step(36)
	var blk: StringName = h.idx.aim["musket/stand"].get("blk", &"")
	ctx.at_least(float(h.tree.get(blk)) if blk != &"" else 0.0, 0.99, "blocked 0.3 m (musket 1.5 m): blocked pose on within 0.6 s")
	await h.frame()
	ctx.at_most(h.stab.last_trim_deg().length(), 0.1, "blocked: the trim is off (deg)")
	h.inp.blocked_hit_m = INF
	h.step(36)
	ctx.at_most(float(h.tree.get(blk)) if blk != &"" else 0.0, 0.01, "unblocked: blocked pose off within 0.6 s")


## {dir: angle barrel vs muzzle->target, elev: barrel elevation - line elevation, yaw: barrel yaw
## - line yaw (+ = left)}, degrees.
func _measure(h, w: String) -> Dictionary:
	var b: Array = h.barrel(w)
	var o: Vector3 = b[0]
	var f: Vector3 = b[1]
	var tgt: Vector3 = h.rig.sk.global_transform.affine_inverse() * h.inp.aim_point
	var d := (tgt - o).normalized()
	return {"dir": rad_to_deg(f.angle_to(d)),
			"elev": rad_to_deg(asin(clampf(f.y, -1.0, 1.0)) - asin(clampf(d.y, -1.0, 1.0))),
			"yaw": rad_to_deg(wrapf(atan2(f.x, f.z) - atan2(d.x, d.z), -PI, PI))}


## Roll of the weapon about its barrel: the prop's up axis (+Y) from vertical (as tests/aim_alignment.gd).
func _cant(h, w: String) -> float:
	var t: Transform3D = h.captured.get(h.data.prop_bone(w), Transform3D())
	var fwd := (t.basis * Vector3.BACK).normalized()
	var up_m := (t.basis * Vector3.UP).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	return rad_to_deg(atan2(up_m.dot(side), up_m.dot(fwd.cross(side).normalized() * -1.0)))


## +-50..+-80 deg (camera limit 80) with the trim: the closed-loop residual learns each frame the
## skeleton updates, so every step awaits a frame.
func _extreme(ctx: AnimTestContext, h) -> void:
	h.stab.aim_trim = true
	var worst60 := 0.0
	var worst60_at := ""
	var worst80 := 0.0
	var worst80_at := ""
	for w in _barrel_weapons(h.data):
		for st in ["stand", "crouch"]:
			h.snap(StringName(w), st, 0.0, 0.0)
			h.set_lower(StringName("aimidle__%s__%s" % [w, st]), 0.0, &"AIM_IDLE")
			h.step(30)
			var line := "%s/%s beyond +-40:" % [w, st]
			for e in EXTREME_ELEVS:
				h.aim_at(e)
				for f in 30:
					h.step(1)
					await h.frame()
				var m := _measure(h, w)
				var td: Vector2 = h.stab.last_trim_deg()
				line += "  %+.0f: %.1f deg (trim yaw %.0f pitch %.0f)" % [e, m.dir, td.x, td.y]
				var at := "%s/%s at %+.0f deg" % [w, st, e]
				if absf(e) <= 60.0 + 1e-6:
					if m.dir > worst60:
						worst60 = m.dir
						worst60_at = at
				elif m.dir > worst80:
					worst80 = m.dir
					worst80_at = at
			ctx.info(line)
	ctx.at_most(worst60, TOL_DEG, "with the aim trim up to +-60 deg (beyond the plan's +-40): barrel vs crosshair, worst (deg) [%s]" % worst60_at)
	ctx.at_most(worst80, EXTREME_TOL_DEG, "+-70..80 deg (camera limit; the trim clamps saturate): barrel vs crosshair, documented tolerance, worst (deg) [%s]" % worst80_at)
	ctx.metric("extreme_pitch_worst_deg", worst80)


## The weapons with a barrel to aim (THROW: the thrown weapons, clip set "throw", have none; the
## weapon lays the held object on the throw line itself; tests/anim/test_throw_anim.gd covers them).
static func _barrel_weapons(d: AnimGraphData) -> PackedStringArray:
	var out := PackedStringArray()
	for w in d.weapons():
		if String(d.graph.get("profiles", {}).get(w, {}).get("clip_set", "")) != "throw":
			out.append(w)
	return out
