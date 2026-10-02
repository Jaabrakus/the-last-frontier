extends SceneTree
## Our clips beside the source clips they stand in for, measured (user 2026-10-01: "put all the original animations next to our
## updated version, run an analysis to see if they match"). For every replacement (data/anim_author/locomotion_clips.json,
## downgraded_clips.json, traversal_clips.json) and the reload: at 30 points over each clip's own length,
##   rot_deg   the mean angle between the two clips' local rotations, over the body's main bones
##   pos_cm    the mean distance between the main joints, the hips taken as the origin (root travel left out)
##   corr      how alike the motion's shape is over time: per bone, the correlation of its turn away from its own mean (1: the same
##             motion in step, 0: unrelated), averaged over the bones that move
## and how ours was made (`lineage`, from the authoring tools), which the numbers do not tell: a clip edited from the source's data is
## derived from it however far it ends up.
## Controls: a clip against itself (0), and pairs of different source motions (what "a different motion" scores).
##   Godot --headless --path . -s tools/anim_author/provenance_compare.gd
## writes user://provenance_compare.json and prints a table.

const MAIN := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck", "headb", "l_clavicle", "r_clavicle", "l_shoulder", "r_shoulder",
		"l_elbow", "r_elbow", "l_wrist", "r_wrist", "l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle", "r_ankle"]
const JOINTS := ["headb", "l_wrist", "r_wrist", "l_elbow", "r_elbow", "l_ankle", "r_ankle", "l_knee", "r_knee", "spined"]
const N := 30

var sk: Skeleton3D
var libs := {}


func _initialize() -> void:
	var ch := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(ch)
	sk = ch.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var src := _lib("res://animations/Actor_B.res")
	var pairs: Array = []
	# controls
	pairs.append(["control: identical", "actor_b-p-walk-fw", src, "actor_b-p-walk-fw", src, "the same clip"])
	pairs.append(["control: different motion", "actor_b-p-walk-fw", src, "actor_b-p-run-fw", src, "two different source motions"])
	pairs.append(["control: different motion", "actor_b-p-relax-idle", src, "actor_b-p-crouch-idle", src, "two different source motions"])
	pairs.append(["control: different motion", "actor_b-p-rifle-idle-aim", src, "actor_b-p-bow-aim-idle", src, "two different source motions"])
	# our replacements
	var loc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim_author/locomotion_clips.json")).clips
	for name: String in loc:
		var o: Dictionary = loc[name]
		pairs.append([_group_loco(String(o.clip)), name, src, String(o.clip), _lib("res://animations_extra/Frontier_Locomotion.res"), _lineage_loco(String(o.clip))])
	var dg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim_author/downgraded_clips.json")).clips
	for name: String in dg:
		pairs.append([_group_dg(name), name, src, String(dg[name].clip), _lib("res://animations_extra/Frontier_Downgraded.res"), _lineage_dg(name)])
	var trv: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim_author/traversal_clips.json")).clips
	for name: String in trv:
		var c := String(trv[name]).get_slice("/", 1)
		pairs.append(["traversal (vault, climb)", name, src, c, _lib("res://animations_extra/Frontier_Traversal.res"),
				"derived: the source clip's own data, edited (Blender kit: legs together / arm calm, de-jittered)"])
	# the reload: ours (pose solver from key poses) against the source's rifle reload steps
	var own := _lib("res://animations_extra/Frontier_Own.res")
	for p in [["own-musket-load-bite", "actor_b-p-rifle-idle-aim-reload-begin--part"], ["own-musket-load-ram", "actor_b-p-rifle-idle-aim-reload-mid--part"],
			["own-musket-load-return", "actor_b-p-rifle-idle-aim-reload-over--part"]]:
		pairs.append(["reload (authored)", p[1], src, p[0], own, "body posed by our solver from key poses; fingers from source clips: right hand from the first key of atk-actor_b-knife-v-thug-hit1-intro (author_reload.gd:263-264, :298), both hands eased onto frame 0 of actor_b-p-rifle-run-arms (crouch: actor_b-p-rifle-crouch-run-arms) over the last 0.3 s (:1150-1180)"])
	var rows: Array = []
	# the forward jogs against what they were made from: the source sprint (two of its cycles to one of the jog's), the best
	# phase found (the jog was phase-matched to the sprint when it was made)
	var met: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://animations/actor_b_clip_metrics.json")).clips
	for d in ["fw", "fw-lt", "fw-rt"]:
		var jl := _lib("res://animations_extra/Frontier_Locomotion.res")
		var jn: String = "own-jog-%s-k100" % d
		var sn: String = "actor_b-p-sprint-" + d
		if not jl.has_animation(jn) or not src.has_animation(sn):
			continue
		var spr := src.get_animation(sn)
		var cyc := spr.length / float(int(met[sn].travel.cycles))
		var best: Array = []
		for k in 24:
			var m := _compare_cycle(spr, cyc * float(k) / 24.0, cyc, jl.get_animation(jn))
			if best.is_empty() or m[0] < best[0]:
				best = m
		rows.append({"group": "jogs vs the sprint they came from", "source": sn, "ours": jn,
				"lineage": "derived: the source sprint retimed to the jog's stride, upper body downgraded", "rot_deg": best[0], "pos_cm": best[1], "corr": best[2]})
	for p: Array in pairs:
		var a: AnimationLibrary = p[2]
		var b: AnimationLibrary = p[4]
		if not a.has_animation(StringName(p[1])) or not b.has_animation(StringName(p[3])):
			continue
		var m := _compare(a.get_animation(StringName(p[1])), b.get_animation(StringName(p[3])))
		rows.append({"group": p[0], "source": p[1], "ours": p[3], "lineage": p[5], "rot_deg": m[0], "pos_cm": m[1], "corr": m[2]})
	var f := FileAccess.open("user://provenance_compare.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t"))
	f.close()
	for r: Dictionary in rows:
		print("CMP %-28s %-48s %-40s rot %5.1f deg  pos %5.1f cm  corr %.2f" % [r.group, r.source.trim_prefix("actor_b-p-"),
				String(r.ours).trim_prefix("actor_b-p-"), r.rot_deg, r.pos_cm, r.corr])
	print("CMP_FILE ", ProjectSettings.globalize_path("user://provenance_compare.json"))
	quit()


func _lib(p: String) -> AnimationLibrary:
	if not libs.has(p):
		libs[p] = load(p) as AnimationLibrary
	return libs[p]


static func _group_loco(c: String) -> String:
	for k: Array in [["own-land", "landings"], ["own-aimwalk", "aim walks"], ["own-jog", "jogs"], ["own-start", "jog starts"],
			["own-stop", "jog stops"], ["own-arms", "jump / fall"]]:
		if c.begins_with(k[0]):
			return k[1]
	return "other"


static func _lineage_loco(c: String) -> String:
	if c.begins_with("own-land"):
		return "derived: the source landing, its squat scaled down"
	if c.begins_with("own-aimwalk"):
		return "derived: the source aim walk's upper body, our jog's legs (themselves from the source sprint) retimed on it"
	if c.begins_with("own-jog"):
		return "derived: the source sprint retimed to the jog, upper body downgraded"
	if c.begins_with("own-start") or c.begins_with("own-stop"):
		return "derived: the source start/stop with our jog eased in"
	if c.begins_with("own-arms"):
		return "derived: the source jump/fall with its arms varied and legs narrowed"
	return "derived"


static func _group_dg(n: String) -> String:
	if n.contains("bow-aim") or n.contains("bow-blocked"):
		return "bow aim (head upright)"
	if n.contains("walk") or n.contains("sprint"):
		return "walk / sprint cycles"
	return "weapon equip / grips"


static func _lineage_dg(n: String) -> String:
	if n.contains("bow-aim") or n.contains("bow-blocked"):
		return "derived: the source clip with the head turned upright"
	if n.contains("walk") or n.contains("sprint"):
		return "derived: the source cycle, upper body stiffened and de-jittered"
	return "derived: the source clip with its finger squeezes evened out, arms de-jittered"


## As _compare(), with a's samples taken over one cycle of `cyc` s from `shift` (b over its own length).
func _compare_cycle(a: Animation, shift: float, cyc: float, b: Animation) -> Array:
	var a2 := Animation.new()
	a2.length = cyc
	for ti in a.get_track_count():
		if a.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
			continue
		var nt := a2.add_track(Animation.TYPE_ROTATION_3D)
		a2.track_set_path(nt, a.track_get_path(ti))
		for i in N:
			var u := float(i) / float(N - 1)
			a2.rotation_track_insert_key(nt, u * cyc, a.rotation_track_interpolate(ti, fposmod(shift + u * cyc, a.length)))
	return _compare(a2, b)


## [rot_deg, pos_cm, corr] of b against a, each at N points over its own length.
func _compare(a: Animation, b: Animation) -> Array:
	var rot := 0.0
	var rn := 0
	var curves_a := {}
	var curves_b := {}
	var pos := 0.0
	var pn := 0
	for i in N:
		var u := float(i) / float(N - 1)
		var ta := u * a.length
		var tb := u * b.length
		for bn: String in MAIN:
			var ia := a.find_track(NodePath("Skeleton3D:" + bn), Animation.TYPE_ROTATION_3D)
			var ib := b.find_track(NodePath("Skeleton3D:" + bn), Animation.TYPE_ROTATION_3D)
			if ia < 0 or ib < 0:
				continue
			var qa := a.rotation_track_interpolate(ia, ta).normalized()
			var qb := b.rotation_track_interpolate(ib, tb).normalized()
			rot += rad_to_deg(qa.angle_to(qb))
			rn += 1
			if not curves_a.has(bn):
				curves_a[bn] = []
				curves_b[bn] = []
			(curves_a[bn] as Array).append(qa)
			(curves_b[bn] as Array).append(qb)
		var pa := _joints(a, ta)
		var pb := _joints(b, tb)
		for j: String in JOINTS:
			pos += (pa[j] as Vector3).distance_to(pb[j]) * 100.0
			pn += 1
	var cs := 0.0
	var cn := 0
	for bn: String in curves_a:
		var ca := _swing(curves_a[bn])
		var cb := _swing(curves_b[bn])
		var r := _pearson(ca, cb)
		if not is_nan(r):
			cs += r
			cn += 1
	return [rot / maxf(rn, 1), pos / maxf(pn, 1), cs / cn if cn > 0 else NAN]


## A bone's turn away from its own mean over the samples (deg), signed by the side of its main axis of change.
static func _swing(qs: Array) -> Array:
	var acc := Vector4.ZERO
	var ref: Quaternion = qs[0]
	for q: Quaternion in qs:
		var s := q if q.dot(ref) >= 0.0 else -q
		acc += Vector4(s.x, s.y, s.z, s.w)
	acc = acc.normalized()
	var mean := Quaternion(acc.x, acc.y, acc.z, acc.w)
	# the main axis of change: the largest deviation's axis; each sample's deviation projected on it
	var axis := Vector3.ZERO
	var big := 0.0
	for q: Quaternion in qs:
		var d := (mean.inverse() * q).normalized()
		if d.w < 0.0:
			d = -d
		var v := Vector3(d.x, d.y, d.z)
		if v.length() > big:
			big = v.length()
			axis = v.normalized()
	var out := []
	for q: Quaternion in qs:
		var d := (mean.inverse() * q).normalized()
		if d.w < 0.0:
			d = -d
		out.append(rad_to_deg(2.0 * asin(clampf(Vector3(d.x, d.y, d.z).dot(axis), -1.0, 1.0))))
	return out


static func _pearson(a: Array, b: Array) -> float:
	var n := a.size()
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += a[i]
		mb += b[i]
	ma /= n
	mb /= n
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in n:
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)
	if saa < 1.0 or sbb < 1.0:      # (a bone that barely moves in either: no shape to compare)
		return NAN
	return sab / sqrt(saa * sbb)


## The main joints at t, the hips as the origin (rotations and rest offsets; the root's travel left out).
func _joints(a: Animation, t: float) -> Dictionary:
	var g := {}
	var out := {}
	var pel := sk.find_bone("pelvis")
	var pg := _global(a, t, pel, g)
	for j: String in JOINTS:
		var b := sk.find_bone(j)
		if b >= 0:
			out[j] = pg.affine_inverse() * _global(a, t, b, g).origin
	return out


func _global(a: Animation, t: float, b: int, cache: Dictionary) -> Transform3D:
	if cache.has(b):
		return cache[b]
	var r := sk.get_bone_rest(b)
	var ri := a.find_track(NodePath("Skeleton3D:" + sk.get_bone_name(b)), Animation.TYPE_ROTATION_3D)
	var x := Transform3D(Basis(a.rotation_track_interpolate(ri, t).normalized()) if ri >= 0 else r.basis, r.origin)
	var par := sk.get_bone_parent(b)
	var g := x if par < 0 else _global(a, t, par, cache) * x
	cache[b] = g
	return g
