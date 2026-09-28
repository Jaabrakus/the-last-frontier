extends SceneTree
## Regression check for the weapon attachment convention (see player.gd
## *_offset): with the game's hands layers, each weapon's prop bone +Z must
## point along the aim direction and +Y up, and in the two-handed musket
## carry the left palm must sit on the barrel line.
##
## WP7 (plan 8.3) adds the grips the graph-driven PlayerAnim plays, read from
## animations/actor_b_graph.json (_graph_grips):
##  - aim: each weapon's aim-idle base with its aim-tree hands layer, standing and
##    crouched (the pistol's revolver grip actor_b-r-hand-revolver-aim; the crouched
##    bow is canted sideways, limbs horizontal): prop +Z within 15 deg of the aim
##    direction once the pose's own zero-weight elevation (metrics pitch.<w>/<s>
##    zero_elev_deg; the pitch additives take the barrel to the target elevation in
##    game) is taken out: the crouched bow's aim base points 13.9 deg up at pitch weight
##    0, 16 deg from the rig forward, 7.8 deg in heading;
##  - carry: the idle role of each weapon (base clip + the role's graph layers + the
##    weapon-out finger partial), musket palm on the barrel line (the plan's carry
##    check); the musket's walk and crouch-walk carry over the stride are reported
##    for information next to the old tree's Weapon.relaxed carry: the graph's
##    walking layers (0.8-weight arm partials) put the palm 0.22-0.24 m off the
##    barrel line, a property of the graph data recorded for an owner decision in
##    tests/anim/README.md ("Documented deviations"), not gated.
##
##   Godot --headless --path . -s tests/check_weapon_axes.gd
var sk: Skeleton3D
var tree: AnimationTree

const GRAPH := "res://animations/actor_b_graph.json"
const PALM_IDLE_M := 0.06
const METRICS := "res://animations/actor_b_clip_metrics.json"

func _initialize() -> void:
	var inst: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(inst)
	sk = inst.get_node("Skeleton3D")
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	tree = AnimationTree.new()
	inst.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(inst)
	await process_frame
	var hand_bone := {"musket": "r_hand_prop_attachment", "pistol": "r_hand_prop_attachment", "bow": "l_hand_prop_attachment"}
	var axes := {"+X": Vector3.RIGHT, "-X": Vector3.LEFT, "+Y": Vector3.UP, "-Y": Vector3.DOWN, "+Z": Vector3.BACK, "-Z": Vector3.FORWARD}
	var poses := [
		["musket", "actor_b-p-rifle-idle-aim", "actor_b-p-rifle-idle-aim--hands"],
		["musket", "actor_b-p-rifle-aim-crouch-idle", "actor_b-p-rifle-aim-crouch-idle--hands"],
		["musket", "actor_b-p-stealth-idle", "actor_b-p-rifle-run-arms"],
		["pistol", "actor_b-p-pistol-aim-idle", "actor_b-pistol-aim--hands"],
		["pistol", "actor_b-p-pistol-aim-idle", "actor_b-p-pistol-aim-idle--base"],
		["bow", "actor_b-p-bow-aim-idle", "actor_b-p-bow-aim-hands-idle"],
		["bow", "actor_b-p-stealth-idle", "actor_b-p-bow-move--arms"],
	]
	for pose in poses:
		if not ap.has_animation("actor_b/" + pose[2]):
			print("MISSING ", pose[2]); continue
		_layer(ap, pose[1], pose[2])
		var rt := sk.get_bone_global_pose(sk.find_bone(hand_bone[pose[0]]))
		var r := rt.basis.orthonormalized()
		var line := "%-7s %-60s" % [pose[0], pose[1] + " + " + pose[2]]
		var best := ""
		for k in axes:
			var d: Vector3 = r * axes[k]
			line += " %s:%3.0f°" % [k, rad_to_deg(d.angle_to(Vector3(0, 0, 1)))]
		var upk := ""
		var bestup := 999.0
		for k in axes:
			var a := rad_to_deg((r * axes[k]).angle_to(Vector3.UP))
			if a < bestup: bestup = a; upk = k
		print(line, "  | up axis ", upk, " (%.0f° off vertical)" % bestup)
		var fwd_err := rad_to_deg((r * Vector3.BACK).angle_to(Vector3(0, 0, 1)))
		if pose[2].ends_with("hands") or pose[2].ends_with("hands-idle"):
			_check(fwd_err < 15.0 and upk == "+Y", "%s aim: prop +Z %.0f° from aim direction, up %s" % [pose[0], fwd_err, upk])
		if pose[2] == "actor_b-p-rifle-run-arms":
			var v := sk.get_bone_global_pose(sk.find_bone("l_palm")).origin - rt.origin
			var d := r * Vector3.BACK
			var off := (v - d * v.dot(d)).length()
			_check(off < 0.06 and v.dot(d) > 0.2, "musket carry: left palm %.2f m along the barrel, %.3f m off it" % [v.dot(d), off])
	_graph_grips(ap)
	print("WEAPON AXES OK" if fails == 0 else "WEAPON AXES FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)


var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
	print(("  ok   " if ok else "  FAIL ") + msg)


func _layer(ap: AnimationPlayer, base: String, over: String) -> void:
	var bt := AnimationNodeBlendTree.new()
	var a := AnimationNodeAnimation.new()
	a.animation = "actor_b/" + base
	bt.add_node("base", a)
	var out := "base"
	if over != "":
		var o := AnimationNodeAnimation.new()
		o.animation = "actor_b/" + over
		bt.add_node("over", o)
		var b2 := AnimationNodeBlend2.new()
		b2.filter_enabled = true
		var anim := ap.get_animation("actor_b/" + over)
		for t in anim.get_track_count():
			b2.set_filter_path(anim.track_get_path(t), true)
		bt.add_node("mix", b2)
		bt.connect_node("mix", 0, "base")
		bt.connect_node("mix", 1, "over")
		out = "mix"
	bt.connect_node("output", 0, out)
	tree.tree_root = bt
	tree.active = true
	if over != "":
		tree.set("parameters/mix/blend_amount", 1.0)
	tree.advance(0.0)
	tree.advance(0.0)


# --- WP7: the grips the graph-driven PlayerAnim plays (plan 6.9 / 8.3) ------------------------

func _graph_grips(ap: AnimationPlayer) -> void:
	var raw := FileAccess.get_file_as_string(GRAPH)
	var g: Variant = JSON.parse_string(raw) if raw != "" else null
	if not g is Dictionary:
		_check(false, "graph table %s readable" % GRAPH)
		return
	print("graph grips (%s)" % GRAPH)
	var mraw := FileAccess.get_file_as_string(METRICS)
	var mt: Variant = JSON.parse_string(mraw) if mraw != "" else null
	var pitch: Dictionary = mt.get("pitch", {}) if mt is Dictionary else {}
	for w in ["musket", "pistol", "bow"]:
		for st in ["stand", "crouch"]:
			var at: Dictionary = g.get("aim_trees", {}).get("%s/%s" % [w, st], {})
			var base := String(at.get("base", {}).get("clip", "")) if at.get("base") is Dictionary else ""
			var hands := String(at.get("hands", {}).get("clip", "")) if at.get("hands") is Dictionary else ""
			if base == "" or hands == "" or not ap.has_animation("actor_b/" + hands):
				_check(false, "%s/%s aim tree: base and hands clips (%s, %s)" % [w, st, base, hands])
				continue
			_stack(ap, base, [[hands, 1.0, false]], 0.0)
			var r := _prop(w).basis.orthonormalized()
			var upk := _axes_line(w, "%s + %s" % [base, hands], r)
			var fwd_err := rad_to_deg((r * Vector3.BACK).angle_to(Vector3(0, 0, 1)))
			# The aim direction at the pose's own zero-weight elevation (the pitch additives take
			# the barrel to the target in game): rig forward raised by zero_elev_deg.
			var z_elev := float(pitch.get("%s/%s" % [w, st], {}).get("zero_elev_deg", 0.0))
			var aim_dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(z_elev))
			var head_err := rad_to_deg((r * Vector3.BACK).angle_to(aim_dir))
			if w == "bow" and st == "crouch":
				# The crouched bow aim is canted sideways (user requirement: 90 degree cant).
				var cant := rad_to_deg((r * Vector3.UP).angle_to(Vector3.UP))
				_check(head_err < 15.0 and absf(cant - 90.0) < 20.0,
						"bow crouch aim (graph grip): prop +Z %.0f° from the aim direction at the pose's zero-weight elevation %.1f° (%.0f° from the rig forward), limbs canted %.0f° (sideways)" % [
						head_err, z_elev, fwd_err, cant])
			else:
				_check(head_err < 15.0 and upk == "+Y", "%s %s aim (graph grip %s): prop +Z %.0f° from the aim direction at the pose's zero-weight elevation %.1f° (%.0f° from the rig forward), up %s" % [
						w, st, hands.trim_prefix("actor_b-"), head_err, z_elev, fwd_err, upk])
		# Carry, lowered (aim 0): the idle role with its layers and the weapon-out fingers.
		for m in ["run", "crouch"]:
			var role: Dictionary = g.get("roles", {}).get("%s/%s/idle" % [w, m], {})
			if not role.get("clip") is String:
				continue
			var layers := _role_layers(ap, g, role, w, "crouch" if m == "crouch" else "stand")
			_stack(ap, String(role.clip), layers, 0.0)
			var rt := _prop(w)
			_axes_line(w, "%s/%s/idle carry: %s + %d layers" % [w, m, role.clip, layers.size()], rt.basis.orthonormalized())
			if w == "musket" and m == "run":
				var p := _palm_offset(rt)
				_check(p.y < PALM_IDLE_M and p.x > 0.2, "musket carry (graph idle role): left palm %.2f m along the barrel, %.3f m off it" % [p.x, p.y])
	# Musket walking carry over the stride: graph layers vs the old tree's Weapon.relaxed carry.
	for m in ["walk", "crouch"]:
		var role: Dictionary = g.get("roles", {}).get("musket/%s/fw" % m, {})
		if not role.get("clip") is String:
			continue
		var graph_layers := _role_layers(ap, g, role, "musket", "crouch" if m == "crouch" else "stand")
		var old_layers := [["actor_b-p-rifle-crouch-run-arms" if m == "crouch" else "actor_b-p-rifle-run-arms", 0.8, false]]
		var worst := [0.0, 0.0]
		for k in 8:
			var ph := k / 8.0
			_stack(ap, String(role.clip), graph_layers, ph)
			worst[0] = maxf(worst[0], _palm_offset(_prop("musket")).y)
			_stack(ap, String(role.clip), old_layers, ph)
			worst[1] = maxf(worst[1], _palm_offset(_prop("musket")).y)
		print("  info musket %s carry over the stride: left palm up to %.3f m off the barrel with the graph layers, %.3f m with the old Weapon.relaxed carry (graph-data property, owner decision pending: tests/anim/README.md)" % [
				m, worst[0], worst[1]])


## [[clip, weight, additive]] of a role's graph layers in order, then the weapon-out finger partial
## (weapon_layers.weapon_out) where it applies.
func _role_layers(ap: AnimationPlayer, g: Dictionary, role: Dictionary, w: String, st: String) -> Array:
	var out := []
	for l in role.get("layers", []):
		var clip := String(l.get("clip", ""))
		if clip == "" or not ap.has_animation("actor_b/" + clip):
			continue
		out.append([clip, float(l.get("weight", 1.0)), String(l.get("kind", "")) == "additive"])
	var wo: Dictionary = g.get("weapon_layers", {}).get("weapon_out", {}).get("clips", {}).get("%s/%s" % [w, st], {})
	if bool(wo.get("applies", false)) and ap.has_animation("actor_b/" + String(wo.get("clip", ""))):
		out.append([String(wo.clip), 1.0, false])
	return out


func _prop(w: String) -> Transform3D:
	var hand_bone := {"musket": "r_hand_prop_attachment", "pistol": "r_hand_prop_attachment", "bow": "l_hand_prop_attachment"}
	return sk.get_bone_global_pose(sk.find_bone(hand_bone[w]))


## (distance along the barrel, distance off the barrel line) of the left palm from the prop bone.
func _palm_offset(rt: Transform3D) -> Vector2:
	var v := sk.get_bone_global_pose(sk.find_bone("l_palm")).origin - rt.origin
	var d := rt.basis.orthonormalized() * Vector3.BACK
	return Vector2(v.dot(d), (v - d * v.dot(d)).length())


## Prints the prop axes against the aim direction (rig +Z); returns the axis closest to up.
func _axes_line(w: String, label: String, r: Basis) -> String:
	var axes := {"+X": Vector3.RIGHT, "-X": Vector3.LEFT, "+Y": Vector3.UP, "-Y": Vector3.DOWN, "+Z": Vector3.BACK, "-Z": Vector3.FORWARD}
	var line := "%-7s %-60s" % [w, label]
	for k in axes:
		line += " %s:%3.0f°" % [k, rad_to_deg((r * axes[k]).angle_to(Vector3(0, 0, 1)))]
	var upk := ""
	var bestup := 999.0
	for k in axes:
		var a := rad_to_deg((r * axes[k]).angle_to(Vector3.UP))
		if a < bestup:
			bestup = a
			upk = k
	print(line, "  | up axis ", upk, " (%.0f° off vertical)" % bestup)
	return upk


## base clip, then each layer [clip, weight, additive] in order (partial: Blend2 filtered to the
## clip's tracks; additive: Add2), every clip seeked to `phase` of its own length.
func _stack(ap: AnimationPlayer, base: String, layers: Array, phase: float) -> void:
	var bt := AnimationNodeBlendTree.new()
	var seeks := []
	var out := _clip_node(ap, bt, "base", base, seeks)
	for i in layers.size():
		var l: Array = layers[i]
		var src := _clip_node(ap, bt, "l%d" % i, String(l[0]), seeks)
		var mix: AnimationNode
		if bool(l[2]):
			mix = AnimationNodeAdd2.new()
		else:
			var b2 := AnimationNodeBlend2.new()
			b2.filter_enabled = true
			var anim := ap.get_animation("actor_b/" + String(l[0]))
			for t in anim.get_track_count():
				b2.set_filter_path(anim.track_get_path(t), true)
			mix = b2
		var n := "mix%d" % i
		bt.add_node(n, mix)
		bt.connect_node(n, 0, out)
		bt.connect_node(n, 1, src)
		out = n
	bt.connect_node("output", 0, out)
	tree.tree_root = bt
	tree.active = true
	for i in layers.size():
		tree.set("parameters/mix%d/%s" % [i, "add_amount" if bool(layers[i][2]) else "blend_amount"], float(layers[i][1]))
	for s in seeks:
		tree.set("parameters/%s/seek_request" % s[0], phase * float(s[1]))
	tree.advance(0.0)
	tree.advance(0.0)


func _clip_node(ap: AnimationPlayer, bt: AnimationNodeBlendTree, n: String, clip: String, seeks: Array) -> String:
	var a := AnimationNodeAnimation.new()
	a.animation = "actor_b/" + clip
	bt.add_node(n, a)
	var s := AnimationNodeTimeSeek.new()
	bt.add_node(n + "_seek", s)
	bt.connect_node(n + "_seek", 0, n)
	seeks.append([n + "_seek", ap.get_animation("actor_b/" + clip).length])
	return n + "_seek"
