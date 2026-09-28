extends RefCounted
## WP5 test harness (not a suite; run_all only picks up test_*.gd): the Actor_B rig, the player
## tree built by TreeBuilder from the real graph table, the lower selector L driven by hand (a
## scripted lower body in place of LocoBrain), UpperBody and its AimStabilizer.
##
##   const UpperRig := preload("res://tests/anim/upper_rig.gd")
##   var h = UpperRig.new()
##   if not h.setup(ctx, {"weapon": "musket"}): return
##   h.set_lower(&"idle__stand")
##   h.step(30)                      # UpperBody.tick, L.update/write, advance, post_advance
##   await h.frame()                 # skeleton update: stabilizer runs, h.captured is filled
##
## With h.attach_loco() a LocoBrain (WP4) drives L instead, in the PlayerAnim frame order (plan
## 3.1, WP5 report): LocoBrain.tick, UpperBody.tick(carry_inputs), L.update/write, advance,
## post_advance. Movement comes from h.move() (inputs only; the body does not move).
##
## Skeleton space = world here (the rig sits at the origin); the rig faces +Z, +X is its left.

const DT := 1.0 / 60.0

var ctx: AnimTestContext
var rig: RigFixture
var data: AnimGraphData
var idx: TreeIndex
var tree: AnimationTree
var L: XFadeSelector
var upper: UpperBody
var stab: AimStabilizer
var inp := AnimInputs.new()
var lower_state := &"IDLE"
## Lower context handed to UpperBody.tick (hemisphere / direction weights of bank inputs).
var lower := {}
## Bones whose skeleton-space pose skeleton_updated records (post-modifier) into `captured`.
var capture_bones := PackedStringArray()
var captured := {}
var updates := 0
var time := 0.0
## LocoBrain in the loop (attach_loco()); null = the lower body is set by hand.
var loco: LocoBrain
## LocoBrain.transitioned log: {t, from, to, info}.
var loco_log: Array = []


## opts: weapon (musket), stance ("stand" | "crouch"), stabilizer (true), data (AnimGraphData),
## build (TreeBuilder opts). Returns false (after a failed check) when the tree does not build.
func setup(p_ctx: AnimTestContext, opts := {}) -> bool:
	ctx = p_ctx
	rig = ctx.rig()
	if rig == null:
		return false
	data = opts.get("data") if opts.get("data") != null else AnimGraphData.load_files()
	if data == null:
		ctx.fail("graph table loads")
		return false
	idx = TreeBuilder.build(data, rig.ap, rig.sk, opts.get("build", {}))
	if not idx.errors.is_empty() or idx.tree_root == null:
		ctx.fail("TreeBuilder builds the player tree: %s" % [idx.errors])
		return false
	rig.play(AnimationNodeBlendTree.new())
	tree = rig.tree
	idx.install(tree)
	L = XFadeSelector.new(tree, "L", idx.L_inputs, idx.L_seek)
	upper = UpperBody.new(data, tree, idx)
	upper.set_lower_selector(L)
	if opts.get("stabilizer", true):
		stab = upper.attach_stabilizer(rig.sk)
	rig.sk.skeleton_updated.connect(_on_updated)
	inp.on_floor = true
	inp.alive = true
	inp.dt = DT
	inp.crouched = String(opts.get("stance", "stand")) == "crouch"
	set_weapon(StringName(opts.get("weapon", "musket")))
	aim_at(0.0)
	tree.advance(0.0)
	tree.advance(0.0)
	return true


func set_weapon(w: StringName) -> void:
	inp.weapon_key = w
	upper.set_weapon(w)


## Weapon, stance, aim elevation and aim phase at once: no fades, no crouch-change additive.
func snap(w: StringName, st: String, aim_phase := 0.0, elev_deg := 0.0) -> void:
	inp.weapon_key = w
	inp.crouched = st == "crouch"
	aim_at(elev_deg)
	upper.set_weapon(w)
	upper.snap(inp)
	# A clip-set member (THROW) plays its leader's aim input.
	upper.A.set_immediate(StringName(idx.aim.get("%s/%s" % [w, st], {}).get("input", "A__%s__%s" % [w, st])), aim_phase)


func stance() -> String:
	return "crouch" if inp.crouched else "stand"


## Lower input at full weight (seek: normalized phase, < 0 = keep) and the state UpperBody sees.
func set_lower(id: StringName, seek := 0.0, state := &"IDLE") -> void:
	L.set_immediate(id, seek)
	lower_state = state
	lower = {}


## Bank input hemisphere (0 fw, 1 bw) and direction weights; also handed to the carry weights.
func set_bank(id: StringName, hemi: String, w_neg: float, w_pos: float) -> void:
	var rec := idx.lower_record(id)
	if rec.has("hemi_param"):
		tree.set(rec.hemi_param, 1.0 if hemi == "bw" else 0.0)
	idx.set_bank_weights(tree, id, hemi, w_neg, w_pos)
	lower = {"hemi_w": {String(id): {"fw": 1.0 if hemi == "fw" else 0.0, "bw": 1.0 if hemi == "bw" else 0.0}},
			"dir_w": {String(id): {hemi: [w_neg, w_pos]}}}


## Aim elevation (deg) from the stance's chest point, and the matching crosshair point at `dist`
## straight ahead (+Z).
func aim_at(elev_deg: float, dist := 25.0) -> void:
	var chest := Vector3(0.0, data.chest_height(stance()), 0.0)
	var d := Vector3(0.0, sin(deg_to_rad(elev_deg)), cos(deg_to_rad(elev_deg)))
	inp.aim_point = rig.sk.global_transform * (chest + d * dist)
	inp.aim_elev_deg = elev_deg


func step(n := 1, dt := DT) -> void:
	for i in n:
		inp.dt = dt
		if loco != null:
			loco.tick(inp, inp.events, dt, inp.weapon_key, upper.aim_stance(inp))
			inp.events.clear()
			lower_state = loco.state
			upper.tick(inp, loco.state, dt, loco.carry_inputs())
		else:
			upper.tick(inp, lower_state, dt, lower)
		L.update(dt)
		L.write()
		tree.advance(dt)
		upper.post_advance()
		time += dt


## Puts a LocoBrain (WP4) on the same tree, L and W selectors and snaps it to the inputs' idle /
## aim idle; step() then runs it first each frame (PlayerAnim order).
func attach_loco() -> LocoBrain:
	loco = LocoBrain.new(data, tree, idx, L, upper.W)
	# A method callable, not a lambda: a lambda capturing this harness would form a reference
	# cycle with the brain (both RefCounted) and leak at exit.
	loco.transitioned.connect(_on_loco_transition)
	loco.snap(inp, inp.weapon_key, upper.aim_stance(inp))
	lower_state = loco.state
	return loco


func _on_loco_transition(from: StringName, to: StringName, info: Dictionary) -> void:
	loco_log.append({"t": time, "from": from, "to": to, "info": info})


## Movement inputs for LocoBrain (local plane: x right, y forward; the body stays in place).
func move(dir := Vector2.ZERO, speed := 0.0) -> void:
	var v := dir.normalized() * speed if dir.length() > 1e-6 else Vector2.ZERO
	inp.wish_local = v
	inp.velocity_local = v
	inp.target_speed = speed if v != Vector2.ZERO else 0.0
	inp.speed = v.length()


## One idle frame: the skeleton updates (the stabilizer runs) and `captured` is refreshed.
func frame() -> void:
	var n := updates
	await ctx.idle_frames(1)
	if updates == n:
		await ctx.idle_frames(1)


func _on_updated() -> void:
	updates += 1
	for b in capture_bones:
		var bi := rig.sk.find_bone(b)
		if bi >= 0:
			captured[b] = rig.sk.get_bone_global_pose(bi)


func param(path: String) -> Variant:
	return tree.get(path if path.begins_with("parameters/") else "parameters/" + path)


func oneshot_active(node: String) -> bool:
	return bool(tree.get("parameters/%s/active" % node))


## Blend weight a OneShot currently gives its shot (1 at full weight, fading in / out between).
func oneshot_weight(node: String) -> float:
	var rec: Dictionary = idx.oneshots.get(node, {})
	if rec.is_empty() or not oneshot_active(node):
		return 0.0
	var fi := float(tree.get("parameters/%s/fade_in_remaining" % node))
	var fo := float(tree.get("parameters/%s/fade_out_remaining" % node))
	var w := 1.0
	if fi > 0.0 and float(rec.fade[0]) > 0.0:
		w = minf(w, 1.0 - fi / float(rec.fade[0]))
	if fo > 0.0 and float(rec.fade[1]) > 0.0:
		w = minf(w, fo / float(rec.fade[1]))
	return w


## Barrel ray of a weapon from `captured` (its prop bone must be in capture_bones):
## [origin, direction] in skeleton space (+Z of the prop bone = barrel, the Frontier convention).
func barrel(w: String) -> Array:
	var t: Transform3D = captured.get(data.prop_bone(w), Transform3D())
	return [t.origin, (t.basis * Vector3.BACK).normalized()]
