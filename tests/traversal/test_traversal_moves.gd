extends SceneTree
## Every source-clip move family on the course, measured on the rendered body (user fix list
## 2026-09-24; blind spots closed after the review of 2026-09-25). Runs each route of
## TravTestUtil.routes() on scenes/traversal_course.tscn with the live preview (AnimationTree
## crossfades with the graph's fades, root and pose inertialization, TraversalIK, the body mesh)
## over its traversal window (every non-OFF frame, and the OFF frames within 0.5 s of one) and checks:
##   1 contacts  planted palm / sole (full-weight IK plant) gap to its surface within
##               [-PEN_TOL, GAP_TOL] on the CPU-skinned mesh (a plant that is not over its
##               surface counts with its true distance); every hand / foot vertex at most PEN_TOL
##               inside any collider (OFF frames: the feet may dip into the floor as far as the
##               preview's plain locomotion does); a planted palm / sole slides at most SLIDE_TOL;
##               every other body region (shins, thighs and coat, arms, torso, head and hat, gear)
##               at most BODY_PEN_TOL inside any collider (a cloth allowance); the soles as animated
##               before the IK at most PRE_SOLE_TOL inside any collider (the IK must not hide a
##               reference that stands a foot under the ground); a sole on a surface that the
##               animation holds still slides at most SKATE_TOL
##   2 pops      no one-frame jump over LIMB_D2_TOL (pelvis PELVIS_D2_TOL, spine, head) of a key bone
##               that the IK or the inertializer makes; the IK adds at most IK_ADD_TOL per frame to a
##               bone's speed and IK_TURN_TOL to its turn; the inertializer turns a bone at most
##               IN_TURN_TOL faster than the animation; no bone turns over ANG_TOL and 1.5 x the
##               animation + 5 rad/s
##   3 seams     at every content switch: rendered pelvis / capsule / camera second difference (a
##               one-frame jump) and limb second difference; pelvis and capsule velocity jump; the
##               tolerances widen to 1.25 x the moves' own maxima AS ANIMATED (before the inertializer
##               and the IK)
##   4 motion    the expected moves and modes happen (the clip authored for each obstacle)
## Writes data/traversal/reports/move_metrics.json and prints one block per route.
##
##   Godot --headless --fixed-fps 120 --path . -s tests/traversal/test_traversal_moves.gd -- [route=name] [verbose] [dump]
## (--fixed-fps 120: one physics tick per rendered frame, so the pose is sampled every tick.)
## With `momentum` (vault speed push 2026-09-26): the vaults at speed with momentum on (TravMomentum: the move's
## clock runs faster; TravTestUtil.momentum_routes()), the same checks, the pops and seams measured per frame of
## the move's clock (a frame at rate r: second differences / r^2, per-frame speeds / r; the contacts, slides
## and penetrations as they are). Writes data/traversal/reports/momentum_metrics.json.

const GAP_TOL := 0.02
const PEN_TOL := 0.01
const SLIDE_TOL := 0.04          ## m: travel of a planted palm / sole's touching vertex (review 2026-09-24)
const PELVIS_D2_TOL := 0.012     ## m per frame^2 at 120 fps: a 1.2 cm one-frame jump
const CAPSULE_D2_TOL := 0.012
const CAMERA_D2_TOL := 0.01
const LIMB_D2_TOL := 0.045
const PELVIS_DV_TOL := 1.2       ## m/s: velocity jump straddling the seam frame
const ANG_TOL := 25.0            ## rad/s (design 2.1)
## Fix round 3 (review 2026-09-25):
const BODY_PEN_TOL := 0.03       ## m: body regions other than hands and feet (cloth allowance)
const PRE_SOLE_TOL := 0.03       ## m: a sole as animated before the IK inside a collider
const SKATE_TOL := 0.04          ## m: a sole on a surface sliding while the animation holds it still
const FLOOR_TOL := 0.005         ## m: OFF frames, the feet into the floor beyond the locomotion's own dip
const IK_ADD_TOL := 0.02         ## m per frame: speed the IK adds to a bone
const IK_TURN_TOL := 15.0        ## rad/s: turn the IK adds to a bone
const IN_TURN_TOL := 15.0        ## rad/s: turn the inertializer adds to a bone
const REPORT := "res://data/traversal/reports/move_metrics.json"
const REPORT_MOMENTUM := "res://data/traversal/reports/momentum_metrics.json"

var failures := 0
var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	change_scene_to_file("res://scenes/traversal_course.tscn")
	while current_scene == null or not current_scene.has_method("run_route"):
		await process_frame
	var course: Node = current_scene
	while not course.ready_done:
		await physics_frame
	# (The source moves at their own timing; with `momentum`, the vaults at speed on their faster clock.)
	var momentum := _args.has("momentum")
	course.controller.momentum = momentum
	var util := TravTestUtil.new(course)
	util.attach(true)
	var mc := TravMeshContacts.build(course.actor.body_mesh)
	mc.build_regions(0.03)
	util.mc = mc
	# Every collider of the course (review 2026-09-24): penetration of any of them counts.
	var world_shapes := []
	for node in course.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs.get_parent() is Area3D or cs.get_parent() is CharacterBody3D:
			continue
		var wsh: Variant = TravSurfaces.from_shape(cs)
		if wsh != null:
			world_shapes.append(wsh)
	util.world_shapes = world_shapes
	# The preview's own locomotion (no foot IK): its feet's dip into the floor (OFF frames may dip
	# that far).
	await util.run(TravTestUtil.loco_route())
	var loco_base := TravTestUtil.loco_baseline(util.frames, mc, world_shapes)
	print("locomotion baseline (feet into the floor, plain locomotion): l %.3f r %.3f m  (%s | %s)" % [float(loco_base.l_foot), float(loco_base.r_foot),
			str(loco_base.get("l_foot_at", "")), str(loco_base.get("r_foot_at", ""))])
	var only := str(_args.get("route", ""))
	var report := {"meta": {"generator": "tests/traversal/test_traversal_moves.gd", "fps": 120, "gap_tol": GAP_TOL, "pen_tol": PEN_TOL,
			"pelvis_d2_tol": PELVIS_D2_TOL, "capsule_d2_tol": CAPSULE_D2_TOL, "camera_d2_tol": CAMERA_D2_TOL,
			"limb_d2_tol": LIMB_D2_TOL, "pelvis_dv_tol": PELVIS_DV_TOL, "ang_tol": ANG_TOL, "slide_tol": SLIDE_TOL,
			"penetration": "every course collider near the body (review 2026-09-24)",
			"body_pen_tol": BODY_PEN_TOL, "pre_sole_tol": PRE_SOLE_TOL, "skate_tol": SKATE_TOL, "floor_tol": FLOOR_TOL, "ik_add_tol": IK_ADD_TOL,
			"ik_turn_tol": IK_TURN_TOL, "in_turn_tol": IN_TURN_TOL, "window_s": TravTestUtil.WINDOW_S, "loco_baseline": loco_base,
			"body": CharacterBodyMesh.DEFAULT_PATH, "note": "contacts measured on the CPU-skinned rendered mesh (all hand / shoe vertices; other body regions decimated to 3 cm); window = non-OFF frames and OFF frames within 0.5 s of one; natural maxima from the pose before the inertializer and the IK"},
			"routes": {}}
	for r: Dictionary in (TravTestUtil.momentum_routes() if momentum else TravTestUtil.routes()):
		if only != "" and not str(r.name).begins_with(only):
			continue
		var res: Dictionary = await util.run(r)
		var cm := TravTestUtil.contact_metrics(util.frames, mc, world_shapes, loco_base)
		var pm := TravTestUtil.pop_metrics(util.frames, LIMB_D2_TOL, momentum)
		var sm := util.seam_metrics(util.frames, 120.0, momentum)
		var why: Array = res.why.duplicate()
		print("\n== %s (%s)  moves %s  frames %d %s" % [r.name, r.family, res.started, res.frames, "" if why.is_empty() else "<- " + ", ".join(why)])
		for mv: String in cm:
			var M: Dictionary = cm[mv]
			var line := "   contacts %-22s" % mv
			for limb: String in M.planted:
				var P: Dictionary = M.planted[limb]
				line += " %s %s..%s (%d%s) slide %s" % [limb, TravTestUtil.fmt(P.gap_min), TravTestUtil.fmt(P.gap_max), int(P.n),
						", %d off top" % int(P.off_top) if int(P.get("off_top", 0)) > 0 else "", TravTestUtil.fmt(P.get("slide", 0.0))]
				if float(P.gap_max) > GAP_TOL or float(P.gap_min) < -PEN_TOL:
					why.append("%s %s planted gap %s..%s" % [mv, limb, TravTestUtil.fmt(P.gap_min), TravTestUtil.fmt(P.gap_max)])
				if float(P.get("slide", 0.0)) > SLIDE_TOL:
					why.append("%s %s planted slide %s" % [mv, limb, TravTestUtil.fmt(P.slide)])
					if _args.has("dump") and P.has("min_detail"):
						print("      %s min gap frame %d: %s" % [limb, int(P.min_frame), P.min_detail])
					if _args.has("dump") and P.has("max_detail"):
						print("      %s max gap %s" % [limb, P.max_detail])
			line += " | pen %s %s | knee pen %s" % [TravTestUtil.fmt(M.pen_all), M.pen_at, TravTestUtil.fmt(M.knee_pen)]
			if float(M.pen_all) > PEN_TOL:
				why.append("%s penetration %s (%s)" % [mv, TravTestUtil.fmt(M.pen_all), M.pen_at])
			if float(M.floor_excess) > FLOOR_TOL:
				why.append("%s feet into the floor %s beyond the locomotion's own (%s)" % [mv, TravTestUtil.fmt(M.floor_excess), M.floor_at])
			var bw := ""
			var bw_d := 0.0
			for reg: String in M.body:
				var B: Array = M.body[reg]
				if float(B[0]) > bw_d:
					bw_d = float(B[0])
					bw = "%s %s in %s frame %d (%s)" % [reg, TravTestUtil.fmt(B[0]), B[1], int(B[2]), B[3]]
			line += " | body %s" % (bw if bw != "" else "-")
			if bw_d > BODY_PEN_TOL:
				why.append("%s body %s" % [mv, bw])
			var ps: Array = M.pre_sole
			line += " | pre-IK sole %s" % TravTestUtil.fmt(ps[0])
			if float(ps[0]) > PRE_SOLE_TOL:
				why.append("%s pre-IK sole %s %s in %s frame %d (%s)" % [mv, ps[1], TravTestUtil.fmt(ps[0]), ps[2], int(ps[3]), ps[4]])
			var sk2: Array = M.skate
			line += " | skate %s" % TravTestUtil.fmt(sk2[0])
			if float(sk2[0]) > SKATE_TOL:
				why.append("%s stance skate %s %s over %d frames to frame %d (%s)" % [mv, sk2[1], TravTestUtil.fmt(sk2[0]), int(sk2[2]), int(sk2[3]), sk2[4]])
				if _args.has("dump") and sk2.size() > 5:
					print("      skate trace: %s" % str(sk2[5]))
				if _args.has("dump") and M.has("pen_frame"):
					var f: Dictionary = util.frames[int(M.pen_frame)]
					var cp := TravContactProbes.shared()
					var sk: Skeleton3D = course.actor.skeleton
					var idx := cp.indices(str(M.pen_limb), sk.find_bone)
					var pp := cp.eval_globals(str(M.pen_limb), f.globals, idx)
					var worst := 0.0
					for sh: Dictionary in f.guards:
						var q := PackedVector3Array()
						for v in pp:
							q.append((f.sk as Transform3D) * v)
						worst = maxf(worst, float(TravSurfaces.penetration(sh, q).depth))
					print("      pen frame %d vertex %d: probe-set penetration %.4f, guards %s, ik %s" % [int(M.pen_frame), int(M.pen_vertex), worst,
							(f.guards as Array).map(func(x): return x.get("name", "")), f.ik_report])
			print(line)
		# Pops over the whole window (fix round 3): what the IK and the inertializer add.
		var pp: Array = pm.pipe_pop
		var pa: Array = pm.ik_add
		var pt: Array = pm.ik_turn
		var pn: Array = pm.in_turn
		var pw: Array = pm.turn
		print("   pops: pipeline d2 %s %s (%s) | IK adds %s cm/frame %s | IK turn %s rad/s %s | inertializer turn %s %s | turn %s %s" % [
				TravTestUtil.fmt(float(pp[0]) * 100.0, 1), pp[1], pp[3], TravTestUtil.fmt(float(pa[0]) * 100.0, 1), pa[1],
				TravTestUtil.fmt(pt[0], 1), pt[1], TravTestUtil.fmt(pn[0], 1), pn[1], TravTestUtil.fmt(pw[0], 1), pw[1]])
		if float(pp[0]) > 0.0:
			why.append("pop %s %s cm (%s) frame %d %s" % [pp[1], TravTestUtil.fmt(float(pp[0]) * 100.0, 1), pp[3], int(pp[2]), pp[4]])
		if float(pa[0]) > IK_ADD_TOL:
			why.append("IK adds %s cm/frame to %s frame %d %s" % [TravTestUtil.fmt(float(pa[0]) * 100.0, 1), pa[1], int(pa[2]), pa[3]])
		if float(pt[0]) > IK_TURN_TOL:
			why.append("IK turns %s %s rad/s faster frame %d %s" % [pt[1], TravTestUtil.fmt(pt[0], 1), int(pt[2]), pt[3]])
		if float(pn[0]) > IN_TURN_TOL:
			why.append("inertializer turns %s %s rad/s faster frame %d %s" % [pn[1], TravTestUtil.fmt(pn[0], 1), int(pn[2]), pn[3]])
		if float(pw[0]) > 0.0:
			why.append("%s turns at %s rad/s frame %d %s" % [pw[1], TravTestUtil.fmt(pw[0], 1), int(pw[2]), pw[3]])
		for s: Dictionary in sm.seams:
			var bad := []
			if not bool(s.get("traversal", true)):
				continue
			# A landing is an impact (the fall stops): its body and pelvis deceleration is the
			# landing clip's job, not a seam pop; its pose continuity is still checked.
			var impact := str(s.mode) == "AIR>MOVE" or str(s.to).begins_with("land_")
			var nat_pel := PELVIS_D2_TOL
			var nat_cap := CAPSULE_D2_TOL
			for mv3 in s.get("moves", []):
				var nm3: Dictionary = sm.natural.get(mv3 if mv3 != "" else "loco", {})
				nat_pel = maxf(nat_pel, 1.25 * float(nm3.get("pelvis_d2", 0.0)))
				nat_cap = maxf(nat_cap, 1.25 * float(nm3.get("capsule_d2", 0.0)))
			s["pelvis_tol"] = nat_pel
			if float(s.pelvis_d2) > nat_pel and not impact:
				bad.append("pelvis")
			if float(s.capsule_d2) > nat_cap and not impact:
				bad.append("capsule")
			if float(s.camera_d2) > CAMERA_D2_TOL:
				bad.append("camera")
			# Limbs and joint rotation: no worse than the moves' own motion on either side (a slap
			# of the hand on the top is fast by nature), and at least the absolute limits.
			var nat_limb := LIMB_D2_TOL
			var nat_ang := ANG_TOL
			for mv2 in s.get("moves", []):
				var nm: Dictionary = sm.natural.get(mv2 if mv2 != "" else "loco", {})
				nat_limb = maxf(nat_limb, 1.25 * float(nm.get("limb_d2", 0.0)))
				nat_ang = maxf(nat_ang, 1.25 * float(nm.get("ang", 0.0)))
			s["limb_tol"] = nat_limb
			s["ang_tol"] = nat_ang
			if float(s.limb_d2) > nat_limb:
				bad.append("limb " + str(s.limb_at))
			if float(s.pelvis_dv) > PELVIS_DV_TOL and not impact:
				bad.append("pelvis dv")
			if float(s.ang_max) > nat_ang:
				bad.append("angular")
			if not bad.is_empty():
				why.append("seam %s -> %s: %s" % [s.from, s.to, ", ".join(bad)])
				if _args.has("dump") and int(s.get("limb_frame", -1)) >= 0:
					util.dump(util.frames, sm.pos, str(s.limb_at), int(s.limb_frame))
				if _args.has("dump") and bad.any(func(x): return str(x).begins_with("pelvis")):
					util.dump(util.frames, sm.pos, "pelvis", int(s.get("pelvis_frame", s.frame)))
			if _args.has("verbose") or not bad.is_empty():
				print("   seam %-28s -> %-28s fade %.2f | pelvis d2 %s dv %s | capsule d2 %s dv %s | camera d2 %s | limb d2 %s (%s) | ang %s %s" % [
						str(s.from).left(28), str(s.to).left(28), float(s.fade), TravTestUtil.fmt(s.pelvis_d2, 4), TravTestUtil.fmt(s.pelvis_dv, 2),
						TravTestUtil.fmt(s.capsule_d2, 4), TravTestUtil.fmt(s.capsule_dv, 2), TravTestUtil.fmt(s.camera_d2, 4),
						TravTestUtil.fmt(s.limb_d2, 4), s.limb_at, TravTestUtil.fmt(s.ang_max, 1), "" if bad.is_empty() else "<- " + ", ".join(bad)])
		var ticks := {}
		for i in range(1, util.frames.size()):
			var dtk := int(util.frames[i].tick) - int(util.frames[i - 1].tick)
			ticks[dtk] = int(ticks.get(dtk, 0)) + 1
		print("   physics ticks per recorded frame: %s; natural maxima %s" % [ticks, sm.natural])
		var worst := {"pelvis_d2": 0.0, "capsule_d2": 0.0, "camera_d2": 0.0, "limb_d2": 0.0, "pelvis_dv": 0.0, "ang_max": 0.0}
		for s: Dictionary in sm.seams:
			if not bool(s.get("traversal", true)):
				continue
			for k: String in worst:
				worst[k] = maxf(float(worst[k]), float(s[k]))
		print("   seams %d: worst pelvis d2 %s capsule d2 %s camera d2 %s limb d2 %s pelvis dv %s ang %s" % [sm.seams.size(),
				TravTestUtil.fmt(worst.pelvis_d2, 4), TravTestUtil.fmt(worst.capsule_d2, 4), TravTestUtil.fmt(worst.camera_d2, 4),
				TravTestUtil.fmt(worst.limb_d2, 4), TravTestUtil.fmt(worst.pelvis_dv, 2), TravTestUtil.fmt(worst.ang_max, 1)])
		var ok := why.is_empty()
		if not ok:
			failures += 1
		print("   %s %s" % ["ok" if ok else "FAIL", "" if ok else "; ".join(why)])
		report.routes[r.name] = {"family": r.family, "ok": ok, "why": why, "moves": res.started, "modes": res.modes,
				"contacts": _jsonable(cm), "pops": _jsonable(pm), "seams": _jsonable(sm.seams), "seam_worst": worst, "natural": _jsonable(sm.natural)}
	if only == "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/traversal/reports"))
		var f := FileAccess.open(REPORT_MOMENTUM if momentum else REPORT, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " ", false) + "\n")
		f.close()
	print("\nTRAVERSAL MOVES %s (%d route failure(s))" % ["OK" if failures == 0 else "FAILED", failures])
	quit(0 if failures == 0 else 1)


static func _jsonable(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k in v:
			d[str(k)] = _jsonable(v[k])
		return d
	if v is Array:
		return (v as Array).map(func(x): return _jsonable(x))
	if v is float:
		if is_inf(v) or is_nan(v):
			return null
		return snappedf(v, 0.0001)
	if v is Vector3:
		return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
	return v
