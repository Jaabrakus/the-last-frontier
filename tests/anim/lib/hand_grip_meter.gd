extends RefCounted
## HandGripMeter (CROUCH_HANDS shared harness, part ch-harness-hands): measures where the hands are
## on the weapon, per frame, on the player's FINAL pose (read in Skeleton3D.skeleton_updated, after
## every SkeletonModifier3D) and on the pose BEFORE the modifiers (read in the AnimationTree's
## mixer_applied, right after the tree applied the animation; Godot restores that pose after each
## skeleton update, so only skeleton_updated sees the modified one).
## Used by tests/anim/test_hand_grips.gd and tests/anim/tools/hand_grip_strips.gd. Changes nothing
## in the game (read-only: signals and bone reads).
##
## Definitions (documented in graph_analysis/crouch_hands/hands_diagnosis.md):
##  - PALM POINT: the left palm's skin, where it touches a held object. C = origin of the rig's
##    l_palm bone (mid-palm: 5.2 cm from the wrist joint, 3.0 cm behind the middle knuckle);
##    N = the palm normal, a fixed l_palm-local axis (palm_n_local): the direction from C to the
##    source grip's centre line in the standing aim grip clip (actor_b-p-rifle-idle-aim--hands);
##    P = C + N * PALM_SKIN (the soft tissue in front of the bone, measured on the skinned body).
##  - MUSKET FORESTOCK: the Brown Bess's fore-end, derived from the model's own meshes (model space:
##    origin at the wrist of the stock, barrel to -Z): from the front of the lock (the most forward
##    vertex standing out on the lock side, x > LOCK_X) to the fore end (the most forward wood
##    vertex); the cross-section is the bundle the hand closes round: wood bottom to barrel top,
##    wood half width, an ellipse per z. palm_gap = signed distance from P to that surface
##    (negative: inside the wood), plus the distance beyond either end.
##  - LeftGrip: a Marker3D "LeftGrip" on the model, when one exists (hands builders may add one):
##    |P - marker| is reported too.
##  - SOURCE FORESTOCK (intent): where the source game's rifle fore-end lies in the right-hand prop
##    frame (r_hand_prop_attachment; +Z = barrel, +Y = up): a cylinder along +Z through the centre
##    of the left hand's closed grip in the source's own two-hand grips (reference poses: the
##    standing and crouched aim --hands clips and the standing carry idle role), radius = the palm
##    point's mean distance from that line there, z range [min ref z - 0.05, max ref z + 0.20]
##    (the source rifle's length is not in the data: an assumption, 0.21 .. 0.59 m ahead of the
##    right hand's prop bone; the Brown Bess fore-end runs 0.24 .. 1.19 m).
##    src_d = the palm point's distance from that cylinder on the pose before the modifiers (the
##    source animation as the graph plays it; the prop bone takes its final local pose, which
##    PropFlipGuard sets during actions: both hands are then in the same frame as authored).
##  - ik_shift: how far the modifiers moved the palm point in the right-hand prop frame
##    (final vs before the modifiers). AimStabilizer turns both arms' drivers rigidly about the
##    hips, so it leaves this at 0; only a left-hand IK (or any non-rigid arm change) moves it.
##  - elbow swivel: the elbow's angle about the shoulder -> wrist line (0 = the elbow hangs toward
##    the skeleton's -Y); swivel_delta = final - before (an IK that flips the elbow shows here).
##  - right hand: distance from the r_palm origin to the stock's wrist (the model origin region,
##    z in [-0.03, 0.07]) minus the wrist's half width.

## Palm soft tissue in front of the l_palm bone origin along N (m). Measured on the skinned body
## (assets/character/actor_b_body.glb, bind pose): see tests/anim/tools/hand_grip_probe.gd.
const PALM_SKIN := 0.023
## A vertex standing out this far on the lock side (+X) marks the lock (the forestock's rear end).
const LOCK_X := 0.0235
const LEFT := ["l_shoulder", "l_elbow", "l_wrist", "l_palm", "l_indexa", "l_indexb", "l_indexc", "l_middlea",
		"l_middleb", "l_middlec", "l_ringa", "l_ringb", "l_ringc", "l_pinkyb", "l_pinkyc", "l_thumba", "l_thumbb",
		"l_thumbc"]
const RIGHT := ["r_palm", "r_hand_prop_attachment", "l_hand_prop_attachment", "upper_base"]
## Finger joints that close round the object (for the wrap centre and the finger gap).
const WRAP := ["l_indexb", "l_middleb", "l_ringb", "l_thumbb", "l_indexc", "l_middlec", "l_thumbc"]
const TIPS := ["l_indexc", "l_middlec", "l_ringc"]

var sk: Skeleton3D
var player: Node
var bone := {}                    ## name -> index
var palm_n_local := Vector3.ZERO  ## l_palm-local palm normal
var src_xy := Vector2.ZERO        ## source forestock centre line (right prop frame)
var src_r := 0.0
var src_z0 := 0.0
var src_z1 := 0.0
var refs := []                    ## reference grips: {name, palm (prop frame), centre}
var stock := {}                   ## musket forestock profile (model space), see build_stock()
var stock_info := ""

var _pre := {}                    ## name -> Transform3D (skeleton space), before the modifiers
var _pre_frame := -1
var _sink: Callable
var _connected := false


func _init(p_player: Node) -> void:
	player = p_player
	sk = player.skeleton
	for n in LEFT + RIGHT:
		bone[n] = sk.find_bone(n)


# --- set-up: reference grips and the source forestock ---------------------------------------

## Poses a scratch Actor_B (characters/Actor_B.tscn, its own AnimationTree) with the source's
## two-hand grips and derives palm_n_local and the source forestock. Returns false on failure.
func calibrate(tree: SceneTree) -> bool:
	var inst: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	tree.root.add_child(inst)
	var rsk: Skeleton3D = inst.get_node("Skeleton3D")
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	var at := AnimationTree.new()
	inst.add_child(at)
	at.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	at.anim_player = at.get_path_to(ap)
	at.root_node = at.get_path_to(inst)
	var poses := [
		["aim_stand", "actor_b-p-rifle-idle-aim", ["actor_b-p-rifle-idle-aim--hands"]],
		["aim_crouch", "actor_b-p-rifle-aim-crouch-idle", ["actor_b-p-rifle-aim-crouch-idle--hands"]],
		["carry_idle", "actor_b-p-stealth-idle", ["actor_b-p-rifle-run-arms"]],
	]
	var ok := true
	var sum := Vector2.ZERO
	var zs := []
	var got := []
	for p in poses:
		if not ap.has_animation("actor_b/" + String(p[1])):
			ok = false
			continue
		stack(at, ap, String(p[1]), p[2], 0.0)
		var g := _globals(rsk)
		var prop: Transform3D = g.r_hand_prop_attachment
		var inv := prop.affine_inverse()
		var c := Vector2.ZERO
		for n in WRAP:
			var q: Vector3 = inv * (g[n] as Transform3D).origin
			c += Vector2(q.x, q.y)
		var pc: Vector3 = inv * (g.l_palm as Transform3D).origin
		c = (c + Vector2(pc.x, pc.y)) / float(WRAP.size() + 1)
		got.append([p[0], g, inv, c])
		sum += c
	if got.is_empty():
		inst.queue_free()
		return false
	src_xy = sum / float(got.size())
	# Palm normal from the standing aim grip: C -> the centre line, in l_palm's own frame.
	var g0: Dictionary = got[0][1]
	var inv0: Transform3D = got[0][2]
	var c0: Vector3 = inv0 * (g0.l_palm as Transform3D).origin
	var to_axis_prop := Vector3(src_xy.x - c0.x, src_xy.y - c0.y, 0.0).normalized()
	var to_axis_skel := (g0.r_hand_prop_attachment as Transform3D).basis.orthonormalized() * to_axis_prop
	palm_n_local = ((g0.l_palm as Transform3D).basis.orthonormalized().inverse() * to_axis_skel).normalized()
	var rs := 0.0
	for r in got:
		var g: Dictionary = r[1]
		var inv: Transform3D = r[2]
		var pp: Vector3 = inv * palm_point(g)
		rs += Vector2(pp.x, pp.y).distance_to(src_xy)
		zs.append(pp.z)
		refs.append({"name": r[0], "palm": pp, "centre": r[3]})
	src_r = rs / float(got.size())
	src_z0 = maxf(0.12, float(zs.min()) - 0.05)
	src_z1 = float(zs.max()) + 0.20
	inst.queue_free()
	return ok


## Plays `base` with `layers` (clip names; partial layers over the clip's own tracks at weight 1,
## or [clip, weight, additive]) on `at`, every clip seeked to `phase` of its length.
static func stack(at: AnimationTree, ap: AnimationPlayer, base: String, layers: Array, phase: float) -> void:
	var bt := AnimationNodeBlendTree.new()
	var seeks := []
	var out := _clip(ap, bt, "base", base, seeks)
	var amounts := []
	for i in layers.size():
		var l: Variant = layers[i]
		var clip: String = String(l[0]) if l is Array else String(l)
		var w: float = float(l[1]) if l is Array else 1.0
		var add: bool = bool(l[2]) if l is Array and l.size() > 2 else false
		if not ap.has_animation("actor_b/" + clip):
			continue
		var src := _clip(ap, bt, "l%d" % i, clip, seeks)
		var mix: AnimationNode
		if add:
			mix = AnimationNodeAdd2.new()
		else:
			var b2 := AnimationNodeBlend2.new()
			b2.filter_enabled = true
			var anim := ap.get_animation("actor_b/" + clip)
			for t in anim.get_track_count():
				b2.set_filter_path(anim.track_get_path(t), true)
			mix = b2
		var n := "mix%d" % i
		bt.add_node(n, mix)
		bt.connect_node(n, 0, out)
		bt.connect_node(n, 1, src)
		out = n
		amounts.append([n, "add_amount" if add else "blend_amount", w])
	bt.connect_node("output", 0, out)
	at.tree_root = bt
	at.active = true
	for a in amounts:
		at.set("parameters/%s/%s" % [a[0], a[1]], a[2])
	for s in seeks:
		at.set("parameters/%s/seek_request" % s[0], phase * float(s[1]))
	at.advance(0.0)
	at.advance(0.0)


static func _clip(ap: AnimationPlayer, bt: AnimationNodeBlendTree, n: String, clip: String, seeks: Array) -> String:
	var a := AnimationNodeAnimation.new()
	a.animation = "actor_b/" + clip
	bt.add_node(n, a)
	var s := AnimationNodeTimeSeek.new()
	bt.add_node(n + "_seek", s)
	bt.connect_node(n + "_seek", 0, n)
	seeks.append([n + "_seek", ap.get_animation("actor_b/" + clip).length])
	return n + "_seek"


func _globals(s: Skeleton3D) -> Dictionary:
	var g := {}
	for n in LEFT + RIGHT:
		g[n] = s.get_bone_global_pose(s.find_bone(n))
	return g


## The palm point (skeleton space) of a pose dictionary.
func palm_point(g: Dictionary) -> Vector3:
	var t: Transform3D = g.l_palm
	return t.origin + (t.basis.orthonormalized() * palm_n_local).normalized() * PALM_SKIN


# --- the musket's forestock from its meshes ------------------------------------------------

## Builds the forestock profile of `model` (model space). Returns false when it finds no wood.
func build_stock(model: Node3D) -> bool:
	var wood := []      # [z, y, |x|]
	var other := []     # every vertex: [z, y, x]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) in ["Ramrod", "Cock", "Frizzen"]:
			continue
		var xf := model.global_transform.affine_inverse() * mi.global_transform
		if not mi.is_inside_tree():
			xf = _local_to(model, mi)
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			var is_wood := _is_wood(mat)
			var arr := mesh.surface_get_arrays(s)
			for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
				var q := xf * v
				other.append([q.z, q.y, q.x])
				if is_wood:
					wood.append([q.z, q.y, absf(q.x)])
	if wood.is_empty():
		stock_info = "no wood surface found"
		return false
	var muzzle := model.get_node_or_null("Muzzle") as Node3D
	var axis_y := muzzle.position.y if muzzle else 0.035
	var z_front := INF
	for w in wood:
		z_front = minf(z_front, w[0])
	var z_rear := -INF
	var lock_z := INF
	for o in other:
		if o[2] > LOCK_X and o[0] < 0.0 and o[0] > -0.6:
			lock_z = minf(lock_z, o[0])
	z_rear = lock_z if lock_z < INF else -0.15
	# Rings (1 mm) of the wood bottom / half width and of the bundle top (<= 2.5 cm above the bore).
	var bot := {}
	var half := {}
	var top := {}
	for w in wood:
		var k := int(round(w[0] * 1000.0))
		bot[k] = minf(bot.get(k, INF), w[1])
		half[k] = maxf(half.get(k, 0.0), w[2])
	for o in other:
		if absf(o[2]) <= 0.02 and o[1] <= axis_y + 0.025 and o[1] > axis_y - 0.005:
			var k := int(round(o[0] * 1000.0))
			top[k] = maxf(top.get(k, -INF), o[1])
	stock = {"z_front": z_front, "z_rear": z_rear, "axis_y": axis_y, "bot": _curve(bot), "half": _curve(half),
			"top": _curve(top)}
	var zm := (z_front + z_rear) * 0.5
	stock_info = "forestock z %.3f .. %.3f (model; %.2f m long), bore y %.3f; at z %.2f: bottom %.3f top %.3f half width %.3f" % [
			z_front, z_rear, z_rear - z_front, axis_y, zm, _at(stock.bot, zm), _at(stock.top, zm), _at(stock.half, zm)]
	return true


static func _local_to(model: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c: Node = n
	while c != model and c != null:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


static func _is_wood(mat: Material) -> bool:
	if mat == null:
		return false
	var nm := mat.resource_name.to_lower()
	if nm != "":
		return nm.contains("walnut") or nm.contains("wood") or nm.contains("stock")
	if mat is BaseMaterial3D:
		var c := (mat as BaseMaterial3D).albedo_color
		return (mat as BaseMaterial3D).metallic < 0.3 and c.r > c.g and c.g > c.b and c.r < 0.6
	return false


## {k: v} (k = mm) -> sorted [[z, v], ...]
static func _curve(d: Dictionary) -> Array:
	var ks := d.keys()
	ks.sort()
	var out := []
	for k in ks:
		out.append([k / 1000.0, float(d[k])])
	return out


## Linear interpolation of a [[z, v]] curve (clamped at the ends).
static func _at(c: Array, z: float) -> float:
	if c.is_empty():
		return NAN
	if z <= c[0][0]:
		return c[0][1]
	for i in range(1, c.size()):
		if z <= c[i][0]:
			var t: float = (z - c[i - 1][0]) / maxf(c[i][0] - c[i - 1][0], 1e-6)
			return lerpf(c[i - 1][1], c[i][1], t)
	return c[c.size() - 1][1]


## Signed distance (m) from a model-space point to the forestock surface, and the stock frame
## data: {gap, z, radial, dir (model-space unit vector from the centre line to q, across)}.
func stock_distance(q: Vector3) -> Dictionary:
	var zf: float = stock.z_front
	var zr: float = stock.z_rear
	var zq := clampf(q.z, zf, zr)
	var dz := absf(q.z - zq)
	var b0 := _at(stock.bot, zq)
	var t0 := _at(stock.top, zq)
	var a := maxf(_at(stock.half, zq), 0.005)
	var b := maxf((t0 - b0) * 0.5, 0.005)
	var cy := (t0 + b0) * 0.5
	var u := q.x
	var v := q.y - cy
	var radial := sqrt(u * u + v * v)
	var rdir := minf(a, b)
	if radial > 1e-6:
		rdir = 1.0 / sqrt(pow(u / (radial * a), 2.0) + pow(v / (radial * b), 2.0))
	var gap := radial - rdir
	if dz > 0.0:
		gap = sqrt(pow(maxf(gap, 0.0), 2.0) + dz * dz)
	return {"gap": gap, "z": q.z, "radial": radial, "centre": Vector3(0.0, cy, zq), "a": a, "b": b}


# --- per-frame capture ---------------------------------------------------------------------

## Starts capturing: `sink` is called once per skeleton update with a record (see measure()).
func start(sink: Callable) -> void:
	_sink = sink
	if _connected:
		return
	_connected = true
	player.anim.mixer_applied.connect(_on_applied)
	sk.skeleton_updated.connect(_on_updated)


func stop() -> void:
	if not _connected:
		return
	_connected = false
	if is_instance_valid(player) and is_instance_valid(player.anim) and player.anim.mixer_applied.is_connected(_on_applied):
		player.anim.mixer_applied.disconnect(_on_applied)
	if is_instance_valid(sk) and sk.skeleton_updated.is_connected(_on_updated):
		sk.skeleton_updated.disconnect(_on_updated)


func _on_applied() -> void:
	_pre = _globals(sk)
	_pre_frame = Engine.get_process_frames()


func _on_updated() -> void:
	if not sk.is_inside_tree() or _pre.is_empty():
		return
	var rec := measure(_globals(sk), _pre)
	rec.pre_age = Engine.get_process_frames() - _pre_frame
	if _sink.is_valid():
		_sink.call(rec)


## One frame: `post` = final pose, `pre` = before the modifiers (dictionaries of skeleton-space
## transforms). Musket metrics only while the musket model is shown.
func measure(post: Dictionary, pre: Dictionary) -> Dictionary:
	var rec := {}
	var prop_post: Transform3D = (post.r_hand_prop_attachment as Transform3D).orthonormalized()
	var prop_src: Transform3D = ((pre.r_palm as Transform3D) * ((post.r_palm as Transform3D).affine_inverse() * (post.r_hand_prop_attachment as Transform3D))).orthonormalized()
	var p_post := palm_point(post)
	var p_pre := palm_point(pre)
	var pp_post := prop_post.affine_inverse() * p_post
	var pp_src := prop_src.affine_inverse() * p_pre
	rec.palm_prop = pp_post
	rec.src_palm_prop = pp_src
	rec.ik_shift = pp_post.distance_to(pp_src)
	# Source intent: distance of the source palm point from the source forestock.
	var zc := clampf(pp_src.z, src_z0, src_z1)
	var rgap := Vector2(pp_src.x, pp_src.y).distance_to(src_xy) - src_r
	rec.src_d = sqrt(pow(maxf(rgap, 0.0), 2.0) + pow(pp_src.z - zc, 2.0)) if absf(pp_src.z - zc) > 0.0 else absf(rgap)
	# check_weapon_axes' figure: l_palm origin off the prop +Z line (the "22 cm").
	var lp: Vector3 = prop_post.affine_inverse() * (post.l_palm as Transform3D).origin
	rec.palm_off_line = Vector2(lp.x, lp.y).length()
	rec.palm_along = lp.z
	rec.swivel = _swivel(post)
	rec.elbow_off = _elbow_off(post)
	rec.swivel_pre = _swivel(pre)
	rec.swivel_delta = rad_to_deg(wrapf(deg_to_rad(rec.swivel - rec.swivel_pre), -PI, PI))
	rec.weapon = String(player.weapon_key)
	# The musket's metrics whenever its model is shown (also while it is holstered or drawn during
	# a weapon switch, when weapon_key already names the other weapon).
	var mw = player.weapons.get("musket")
	var model: Node3D = mw.model if mw else null
	rec.model_visible = model != null and model.is_visible_in_tree()
	if rec.model_visible and not stock.is_empty():
		var off: Transform3D = player.musket_offset
		var to_model := (prop_post * off).affine_inverse()
		var q := to_model * p_post
		var sd := stock_distance(q)
		rec.palm_gap = sd.gap
		rec.palm_z = -q.z
		# Palm normal vs the stock: N against the direction from C to the centre line.
		var cpos: Vector3 = (post.l_palm as Transform3D).origin
		var n := ((post.l_palm as Transform3D).basis.orthonormalized() * palm_n_local).normalized()
		var centre_skel: Vector3 = (prop_post * off) * (sd.centre as Vector3)
		var to_c := centre_skel - cpos
		to_c -= (prop_post.basis * Vector3.BACK) * to_c.dot(prop_post.basis * Vector3.BACK)
		rec.palm_normal_deg = rad_to_deg(n.angle_to(to_c)) if to_c.length() > 1e-4 else 0.0
		var fg := 0.0
		for f in TIPS:
			fg += float(stock_distance(to_model * (post[f] as Transform3D).origin).gap)
		rec.finger_gap = fg / TIPS.size()
		# Right hand vs the wrist of the stock (model origin region).
		var rq := to_model * (post.r_palm as Transform3D).origin
		var wz := clampf(rq.z, -0.03, 0.07)
		rec.rhand_gap = maxf(Vector3(rq.x, rq.y, rq.z - wz).length() - 0.02, 0.0)
		var lg := model.get_node_or_null("LeftGrip") as Node3D
		if lg == null:
			lg = model.find_child("LeftGrip", true, false) as Node3D
		if lg:
			rec.leftgrip_d = q.distance_to(_local_to(model, lg).origin)
		# Staleness of the weapon node against the current prop bone (m).
		rec.node_lag = model.global_transform.origin.distance_to((sk.global_transform * prop_post * off).origin)
	return rec


## Distance (m) of the elbow from the shoulder -> wrist line (0 for a straight arm: its swivel says little).
func _elbow_off(g: Dictionary) -> float:
	var s: Vector3 = (g.l_shoulder as Transform3D).origin
	var e: Vector3 = (g.l_elbow as Transform3D).origin
	var ax := ((g.l_wrist as Transform3D).origin - s).normalized()
	return ((e - s) - ax * (e - s).dot(ax)).length()


## Elbow swivel (deg) about the shoulder -> wrist line, in upper_base's frame; 0 = toward its -Y
## (or -Z when the arm lies along Y).
func _swivel(g: Dictionary) -> float:
	# In upper_base's frame: AimStabilizer turns upper_base (and so both arms) rigidly, which must
	# not count as a swivel.
	var ub: Transform3D = (g.upper_base as Transform3D).orthonormalized().affine_inverse()
	var s: Vector3 = ub * (g.l_shoulder as Transform3D).origin
	var e: Vector3 = ub * (g.l_elbow as Transform3D).origin
	var wr: Vector3 = ub * (g.l_wrist as Transform3D).origin
	var ax := (wr - s).normalized()
	var ref := Vector3.DOWN - ax * ax.dot(Vector3.DOWN)
	if ref.length() < 0.2:
		ref = Vector3.FORWARD - ax * ax.dot(Vector3.FORWARD)
	ref = ref.normalized()
	var v := (e - s) - ax * (e - s).dot(ax)
	if v.length() < 1e-4:
		return 0.0
	return rad_to_deg(ref.signed_angle_to(v.normalized(), ax))
