extends AnimTestSuite
## Which hand holds what (push n01c; user 2026-09-26: "the right hand holds the torch and the left hand holds the
## gun which makes it looks better allows us to do the one hand middle hold", "yes i want the middle grip on the
## crouch walk as well", "allows user to have the right hand to throwables and easily switch back to rifle", "for the
## one hand hold the left hand doesn grip it properly").
##
## In the real level (scenes/main.tscn), on the FINAL pose (Skeleton3D.skeleton_updated) and the skinned hand
## (tests/torch/lib/grip_gauge.gd: the body's own skin against the gun's own meshes):
##  1. the rig's mirror (LeftArmPose mirrors the right arm's clips onto the left): the left arm's local rests equal
##     the right's, their offsets negated;
##  2. the torch carry with the musket, idle / walk / run / sprint / crouch-walk / turn / jump: the torch in the
##     RIGHT hand, the LEFT fist really round the gun at its middle (palm gap <= PALM_MAX_M, the four fingers on the
##     wood, no skin deeper than DEPTH_MAX_M in it, the palm GRIP_Z along the barrel), the gun level along the left
##     side, muzzle forward, clear of the legs and the ground (CLEAR_M);
##  3. hold T raises the torch beside the shoulder (flame above the head), letting go lowers it; a tap puts it out,
##     another lights it;
##  4. the aim drops the torch and ends in the two-hand grip (the gun back on the right prop, the left hand on the
##     fore-end), no pop of the muzzle on the way;
##  5. the torch's hand per weapon: the right with the musket, the bow and empty hands; the left with the pistol, the
##     tomahawk and the spear;
##  6. the crouch-walk one-hand hold without a torch: the left fist round the middle, the right hand free; stopping
##     and aiming go back to both hands;
##  7. the quick throwables: musket -> tomahawk and -> spear keeps the gun in the left hand (not on the back), the
##     throwable is drawn and thrown, and back to the musket the aim is ready within BACK_MAX_S; the pistol takes the
##     normal switch (the gun on the back).
##   Godot --headless --fixed-fps 120 --path . -s tests/anim/run_all.gd -- --no-capture --dir=res://tests/torch --prefix=test_hand \
##       [parts=carry,raise,aim,hands,crouch,quick]

const Gauge := preload("res://tests/torch/lib/grip_gauge.gd")

## The left fist on the gun.
const PALM_MAX_M := 0.01
const DEPTH_MAX_M := 0.008
const GRIP_Z := Vector2(0.33, 0.47)
## The gun: forward (its barrel's forward component), below level at most (sin), to the left of the hips (m).
const FWD_MIN := 0.8
const DOWN_MAX := 0.3
const LEFT_MIN := 0.12
## Clear of the legs (capsules: thigh THIGH_R, shin SHIN_R, the gun GUN_R) and the ground (the muzzle's height above
## the lower foot), m.
const CLEAR_M := 0.0
const THIGH_R := 0.075
const SHIN_R := 0.055
const GUN_R := 0.022
const GROUND_MIN := 0.12
## The torch fist beside the right hip: out to the right of the pelvis at least (m); upright within (deg).
const TORCH_OUT_MIN := 0.12
const TORCH_TILT_MAX := 45.0
## Hold-T: the flame this far above the head bone at least (m).
const RAISE_ABOVE := 0.05
## The muzzle's velocity change per frame through the aim drop at most (m/s, in the root's frame; the plain two-hand
## aim's own start, no torch, measures ~10 in its first frames).
const POP_DV_MAX := 6.0
## Back to the musket from a quick throwable: aim ready within (s).
const BACK_MAX_S := 0.5
const CARRY := [
	["idle", 1.0, [], []],
	["walk", 1.4, ["walk", "move_forward"], []],
	["run", 1.4, ["move_forward"], []],
	["sprint", 1.4, ["sprint", "move_forward"], []],
	["turn", 1.2, ["move_left"], []],
	["crouch_walk", 1.8, ["move_forward"], ["crouch"]],
	["crouch_idle", 1.2, [], []],
	["stand", 1.0, [], ["crouch"]],
	["jump", 1.6, ["move_forward"], ["jump"]],
	["-", 0.5, [], []],
]
const SETTLE_S := 0.45

var _p: FrontierPlayer
var _sk: Skeleton3D
var _g = null
var _ids := {}
var _rec := false
var _label := "-"
var _t := 0.0
var _rows: Array = []
var _prev := {}
var _last := {}


func describe() -> String:
	return "hands: torch in the right hand with a long gun (the left fist round the gun's middle, measured on the skin), hold-T raise, aim drop, torch hand per weapon, crouch-walk middle grip, quick throwables"


func timeout_s() -> float:
	return 600.0


func run(ctx: AnimTestContext) -> void:
	_p = await ctx.level()
	if _p == null:
		return
	ctx.allow_error("loops in the graph")
	_sk = _p.skeleton
	for n in ["r_hand_prop_attachment", "l_hand_prop_attachment", "pelvis", "root", "headb", "r_shoulder",
			"l_upper_leg", "l_knee", "l_ankle", "r_upper_leg", "r_knee", "r_ankle", "l_ball", "r_ball"]:
		_ids[n] = _sk.find_bone(n)
	_mirror(ctx)
	_g = Gauge.new()
	_g.watch(_sk)
	_sk.skeleton_updated.connect(_on_updated)
	await _equip(ctx, "musket")
	# parts=carry,raise,aim,hands,crouch,quick (all by default)
	var parts := String(ctx.arg("parts", "carry,raise,aim,hands,crouch,quick")).split(",")
	if "carry" in parts:
		await _torch_carry(ctx)
	if "raise" in parts:
		await _raise_and_tap(ctx)
	if "aim" in parts:
		await _aim_drop(ctx)
	if "hands" in parts:
		await _torch_hands(ctx)
	if "crouch" in parts:
		await _crouch_walk_hold(ctx)
	if "quick" in parts:
		await _quick_throwables(ctx)
	_sk.skeleton_updated.disconnect(_on_updated)
	FootSlip._release_all()


# --- 1. the mirror ----------------------------------------------------------------------------------------------

func _mirror(ctx: AnimTestContext) -> void:
	var worst_q := 0.0
	var worst_p := 0.0
	for part in ["shoulder", "elbow", "wrist", "palm", "indexa", "middleb", "thumbc"]:
		var l := _sk.find_bone("l_" + part)
		var r := _sk.find_bone("r_" + part)
		if l < 0 or r < 0:
			continue
		var lr := _sk.get_bone_rest(l)
		var rr := _sk.get_bone_rest(r)
		worst_q = maxf(worst_q, rad_to_deg(lr.basis.get_rotation_quaternion().angle_to(rr.basis.get_rotation_quaternion())))
		worst_p = maxf(worst_p, (lr.origin + rr.origin).length())
	ctx.check(worst_q < 1.0 and worst_p < 0.002,
			"the arms' rests mirror (local rotations equal within %.2f deg, offsets negated within %.4f m)" % [worst_q, worst_p])


# --- 2. the torch carry -------------------------------------------------------------------------------------------

func _torch_carry(ctx: AnimTestContext) -> void:
	await _start_clear(ctx)
	var t := _p.torch
	if not t.holding():
		await _tap(ctx, PlayerTorch.ACTION)
	for i in 240:
		await ctx.frames(1)
		if t.holding() and not t.pending and _p.anim.mid_ik.in_left():
			break
	await ctx.seconds(0.5)
	ctx.check(t.holding() and _p.anim.torch_ik.side == "r", "T with the musket: the torch in the RIGHT hand (%s)" % _p.anim.torch_ik.side)
	ctx.check(_p.anim.mid_ik.progress >= 1.0, "and the musket in the LEFT hand (handoff %.2f)" % _p.anim.mid_ik.progress)
	if not _gauge_ready(ctx):
		return
	_rows.clear()
	_rec = true
	for seg: Array in CARRY:
		_label = String(seg[0])
		_t = 0.0
		for a: String in seg[2]:
			Input.action_press(a)
		for a: String in seg[3]:
			await _tap(ctx, a)
		await ctx.seconds(float(seg[1]))
		for a: String in seg[2]:
			Input.action_release(a)
	_rec = false
	_label = "-"
	for seg: Array in CARRY:
		var lab := String(seg[0])
		if lab == "-":
			continue
		_summarise(ctx, lab, true)


## Per segment: the worst of the grip, the gun's line and clearance, the torch.
func _summarise(ctx: AnimTestContext, lab: String, torch: bool) -> void:
	var rows := _rows.filter(func(r: Dictionary) -> bool: return r.label == lab and float(r.t) >= SETTLE_S and r.has("palm"))
	if rows.is_empty():
		ctx.fail("%s: no frames" % lab)
		return
	var w := {"palm": 0.0, "depth": 0.0, "closed": 4, "z_lo": 9.0, "z_hi": 0.0, "fwd": 1.0, "down": 0.0, "left": 9.0,
			"clear": 9.0, "ground": 9.0, "t_out": 9.0, "tilt": 0.0}
	for r: Dictionary in rows:
		w.palm = maxf(w.palm, float(r.palm))
		w.depth = maxf(w.depth, float(r.depth))
		w.closed = mini(w.closed, int(r.closed))
		w.z_lo = minf(w.z_lo, float(r.grip_z))
		w.z_hi = maxf(w.z_hi, float(r.grip_z))
		w.fwd = minf(w.fwd, float(r.fwd))
		w.down = maxf(w.down, float(r.down))
		w.left = minf(w.left, float(r.left))
		if float(r.clear) < w.clear:
			w.clear = float(r.clear)
			w.leg = String(r.get("leg", ""))
		w.ground = minf(w.ground, float(r.ground))
		if torch:
			w.t_out = minf(w.t_out, float(r.t_out))
			w.tilt = maxf(w.tilt, float(r.tilt))
	ctx.info("%-12s palm %.1f cm, depth %.1f cm, fingers %d/4, grip %.2f..%.2f m | gun fwd %.2f down %.2f left %.2f, leg clear %.1f cm, muzzle %.2f m up%s (%d frames)" % [
			lab, w.palm * 100.0, w.depth * 100.0, w.closed, w.z_lo, w.z_hi, w.fwd, w.down, w.left, w.clear * 100.0,
			w.ground, (" | torch %.2f out, tilt %.0f" % [w.t_out, w.tilt]) if torch else "", rows.size()])
	ctx.metric("hold_" + lab + ("_torch" if torch else ""), w)
	ctx.check(w.palm <= PALM_MAX_M and w.closed == 4 and w.depth <= DEPTH_MAX_M,
			"%s: the left fist grips the gun (palm %.1f cm off the wood, %d/4 fingers on it, %.1f cm deep at most)" % [
			lab, w.palm * 100.0, w.closed, w.depth * 100.0])
	ctx.check(w.z_lo >= GRIP_Z.x and w.z_hi <= GRIP_Z.y, "%s: at the gun's middle (%.2f..%.2f m from the wrist of the stock)" % [lab, w.z_lo, w.z_hi])
	var air := lab == "jump"
	ctx.check(w.fwd >= FWD_MIN and (air or w.down <= DOWN_MAX) and w.left >= LEFT_MIN,
			"%s: the gun along the left side, muzzle forward (fwd %.2f, down %.2f, %.2f m left of the hips)" % [lab, w.fwd, w.down, w.left])
	ctx.check(w.clear >= CLEAR_M and w.ground >= GROUND_MIN,
			"%s: clear of the legs (%.1f cm; nearest %s) and the ground (%.2f m up)" % [lab, w.clear * 100.0,
			String(w.get("leg", "")), w.ground])
	if torch:
		var crouch := lab.begins_with("crouch")
		ctx.check(w.t_out >= TORCH_OUT_MIN and w.tilt <= TORCH_TILT_MAX + (10.0 if crouch or air else 0.0),
				"%s: the torch in the right hand beside the hip, upright (%.2f m out, %.0f deg)" % [lab, w.t_out, w.tilt])


# --- 3. tap T to raise and lower, hold T to put away (the keys since 2026-09-27) ---------------------------------

func _raise_and_tap(ctx: AnimTestContext) -> void:
	await _start_clear(ctx)
	var t := _p.torch
	if not t.holding():
		t.take_out()
		await ctx.seconds(1.2)
	await _tap(ctx, PlayerTorch.ACTION)
	await ctx.seconds(PlayerTorch.DOUBLE_S + HandHolds.RAISE_S + 0.4)
	var head := (_last.get("head", Vector3.ZERO) as Vector3)
	var flame := _p.anim.torch_ik.last_flame
	ctx.check(t.holding() and _p.anim.holds.raise >= 0.99, "a tap of T raises the torch (raise %.2f)" % _p.anim.holds.raise)
	ctx.check(flame.y >= head.y + RAISE_ABOVE, "the flame above the head (%.2f m above)" % (flame.y - head.y))
	ctx.check(t.fire != null and t.fire.raised > 0.9, "the raised light reaches farther (raised %.2f)" % (t.fire.raised if t.fire else 0.0))
	await _tap(ctx, PlayerTorch.ACTION)
	await ctx.seconds(PlayerTorch.DOUBLE_S + HandHolds.RAISE_S + 0.3)
	ctx.check(t.holding() and _p.anim.holds.raise <= 0.01, "another tap lowers it to the axe hold, still lit (raise %.2f)" % _p.anim.holds.raise)
	Input.action_press(PlayerTorch.ACTION)
	await ctx.seconds(PlayerTorch.HOLD_S + 0.15)
	Input.action_release(PlayerTorch.ACTION)
	await ctx.seconds(0.5)
	ctx.check(not t.holding(), "holding T puts it out")
	await _tap(ctx, PlayerTorch.ACTION)
	for i in 240:
		await ctx.frames(1)
		if t.holding() and not t.pending:
			break
	await ctx.seconds(0.4)
	ctx.check(t.holding() and t.held.lit and _p.anim.torch_ik.side == "r", "tap T lights one in the right hand")


# --- 4. the aim drops it ------------------------------------------------------------------------------------------

func _aim_drop(ctx: AnimTestContext) -> void:
	await _start_clear(ctx)
	var t := _p.torch
	if not t.holding():
		t.take_out()
	await ctx.seconds(1.2)
	_rows.clear()
	_label = "aim"
	_t = 0.0
	_rec = true
	Input.action_press("aim")
	var gone_at := -1.0
	for i in 150:
		await ctx.frames(1)
		if not t.holding() and gone_at < 0.0:
			gone_at = i / float(Engine.physics_ticks_per_second)
	_rec = false
	ctx.check(gone_at > 0.0 and gone_at < 0.5, "the aim drops the torch (%.2f s)" % gone_at)
	ctx.check(t.last_dropped != null and is_instance_valid(t.last_dropped), "it lies on the ground, burning")
	ctx.check(_p.weapon.aim > 0.95, "the musket is up (aim %.2f)" % _p.weapon.aim)
	ctx.check(_p.anim.mid_ik.progress <= 0.0 and _p.anim.holds.toss_t < 0.0,
			"the gun back on the right prop, the toss over (handoff %.2f)" % _p.anim.mid_ik.progress)
	var gap := (_last.get("lp", Vector3.INF) as Vector3).distance_to(_last.get("rp", Vector3.ZERO) as Vector3)
	ctx.check(gap < 0.06, "both hands on the gun in the aim (the prop bones %.3f m apart)" % gap)
	var dv := 0.0
	var at := {}
	for r: Dictionary in _rows:
		if float(r.get("dv", 0.0)) > dv:
			dv = float(r.dv)
			at = r
	ctx.check(dv <= POP_DV_MAX, "no pop of the muzzle from the carry to the aim (%.2f m/s per frame at %.2f s: %s)" % [dv,
			float(at.get("t", 0.0)), String(at.get("why", ""))])
	Input.action_release("aim")
	await ctx.seconds(0.8)


# --- 5. the torch's hand per weapon --------------------------------------------------------------------------------

func _torch_hands(ctx: AnimTestContext) -> void:
	var t := _p.torch
	for want: Array in [["pistol", "l"], ["tomahawk", "l"], ["spear", "l"], ["bow", "r"], ["musket", "r"]]:
		var key := String(want[0])
		if not _p.is_usable(key):
			ctx.warn("%s not carried: not checked" % key)
			continue
		if not t.holding():
			t.take_out()
			await ctx.seconds(1.2)
		await _equip(ctx, key)
		await ctx.seconds(0.6)
		ctx.check(t.holding() and _p.anim.torch_ik.side == String(want[1]) and not _p.anim.torch_ik.passing(),
				"%s: the torch in the %s hand (%s)" % [key, "left" if want[1] == "l" else "right", _p.anim.torch_ik.side])
	if not t.holding():
		t.take_out()
		await ctx.seconds(1.2)
	_p.toggle_hands_free()
	await ctx.seconds(1.4)
	ctx.check(_p.hands_free and t.holding() and _p.anim.torch_ik.side == "r", "hands free: the torch in the right hand (%s)" % _p.anim.torch_ik.side)
	_p.toggle_hands_free()
	await _settle_switch(ctx)
	t.put_away()
	await ctx.seconds(0.5)


# --- 6. the crouch-walk one-hand hold ------------------------------------------------------------------------------

func _crouch_walk_hold(ctx: AnimTestContext) -> void:
	await _start_clear(ctx)
	var t := _p.torch
	if t.holding():
		t.put_away()
	var relax := _p.anim.relax_after_s
	_p.anim.relax_after_s = 0.3
	await ctx.seconds(0.6)
	await _tap(ctx, "crouch")
	await ctx.seconds(0.8)
	_gauge_ready(ctx)
	_rows.clear()
	_label = "crouch_walk_1h"
	_t = 0.0
	_rec = true
	Input.action_press("move_forward")
	await ctx.seconds(2.2)
	ctx.check(_p.anim.one_hand and _p.anim.mid_ik.progress >= 1.0,
			"crouch-walking: the one-hand hold, the gun in the LEFT hand (handoff %.2f)" % _p.anim.mid_ik.progress)
	ctx.check(_p.anim.right_arm.enabled and _p.anim.right_arm.source_key == "free", "the right hand free (%s)" % _p.anim.right_arm.source_key)
	Input.action_release("move_forward")
	_rec = false
	_summarise(ctx, "crouch_walk_1h", false)
	await ctx.seconds(1.4)
	ctx.check(_p.anim.mid_ik.progress <= 0.0 and not _p.anim.one_hand, "stopping: both hands on the gun again (handoff %.2f)" % _p.anim.mid_ik.progress)
	Input.action_press("move_forward")
	await ctx.seconds(1.6)
	Input.action_press("aim")
	await ctx.seconds(0.9)
	var gap := (_last.get("lp", Vector3.INF) as Vector3).distance_to(_last.get("rp", Vector3.ZERO) as Vector3)
	ctx.check(_p.weapon.aim > 0.9 and _p.anim.mid_ik.progress <= 0.0 and gap < 0.06,
			"aiming from it: the two-hand aim (aim %.2f, prop bones %.3f m apart)" % [_p.weapon.aim, gap])
	Input.action_release("aim")
	Input.action_release("move_forward")
	_p.anim.relax_after_s = relax
	await _tap(ctx, "crouch")
	await ctx.seconds(0.8)


# --- 7. quick throwables ----------------------------------------------------------------------------------------------

func _quick_throwables(ctx: AnimTestContext) -> void:
	_gauge_ready(ctx)
	for key in ["tomahawk", "spear"]:
		if not _p.is_usable(key):
			ctx.warn("%s not carried: the quick switch not checked" % key)
			continue
		await _start_clear(ctx)
		await _equip(ctx, "musket")
		var musket: Weapon = _p.weapons.musket
		_p.switch_weapon(key)
		for i in 240:
			await ctx.frames(1)
			if _p.weapon_key == key and _p.weapon.active and not _p.weapon.is_equipping():
				break
		await ctx.seconds(0.3)
		var item: String = _p.gear.item_for_key("musket") if _p.gear else ""
		ctx.check(_p.weapon_key == key and _p.offhand_key == "musket" and _p.anim.mid_ik.progress >= 1.0 and musket.model.visible,
				"musket -> %s: the %s drawn, the musket kept in the LEFT hand (handoff %.2f)" % [key, key, _p.anim.mid_ik.progress])
		ctx.check(item == "" or _p.gear.mode_of(item) == SlingRig.Mode.HELD, "the musket is in the hand, not on the back")
		ctx.check(_g != null and _g.model == musket.model and _grip_ok(), "the left fist round the musket's middle meanwhile (%s)" % Gauge.line(_g.measure() if _g else {}))
		var n0: int = (_p.weapon as Throwable).count
		Input.action_press("fire")
		await ctx.seconds(0.7)
		Input.action_release("fire")
		await ctx.seconds(1.2)
		ctx.check((_p.weapon as Throwable).count == n0 - 1, "the %s thrown with the gun in the left hand (%d -> %d)" % [key, n0, (_p.weapon as Throwable).count])
		ctx.check(_p.anim.mid_ik.progress >= 1.0, "the gun stayed in the left hand through the throw")
		_p.switch_weapon("musket")
		var ready := -1.0
		for i in 240:
			await ctx.frames(1)
			if ready < 0.0 and _p.weapon_key == "musket" and _p.weapon.active and not _p.weapon.aim_hold \
					and not _p.weapon.is_equipping():
				ready = i / float(Engine.physics_ticks_per_second)
				Input.action_press("aim")
			if ready >= 0.0 and _p.weapon.aim > 0.95:
				break
		ctx.check(ready >= 0.0 and ready <= BACK_MAX_S, "back to the musket: aim ready in %.2f s (<= %.1f)" % [ready, BACK_MAX_S])
		await ctx.seconds(0.3)
		var gap := (_last.get("lp", Vector3.INF) as Vector3).distance_to(_last.get("rp", Vector3.ZERO) as Vector3)
		ctx.check(_p.weapon.aim > 0.9 and gap < 0.06 and _p.offhand_key == "", "and the two-hand aim (prop bones %.3f m apart)" % gap)
		Input.action_release("aim")
		await ctx.seconds(0.6)
	# the pistol: the normal switch (the musket onto the back)
	if _p.is_usable("pistol"):
		await _equip(ctx, "pistol")
		var item2: String = _p.gear.item_for_key("musket") if _p.gear else ""
		ctx.check(_p.offhand_key == "" and _p.anim.mid_ik.progress <= 0.0 and (item2 == "" or _p.gear.mode_of(item2) == SlingRig.Mode.STOWED),
				"musket -> pistol: the normal switch, the musket on the back")
		await _equip(ctx, "musket")


# --- helpers ----------------------------------------------------------------------------------------------------

func _gauge_ready(ctx: AnimTestContext) -> bool:
	var m := _p.anim.mid_ik
	var gun: Node3D = _p.weapons.musket.model
	if _g.model != gun and not _g.setup(_p, gun, -m.balance_m):
		ctx.fail("grip gauge: " + String(_g.info))
		return false
	return true


func _grip_ok() -> bool:
	var m: Dictionary = _g.measure()
	return not m.is_empty() and float(m.palm_gap) <= PALM_MAX_M and int(m.closed) == 4 and float(m.depth) <= DEPTH_MAX_M


func _equip(ctx: AnimTestContext, key: String) -> void:
	_p.switch_weapon(key)
	await _settle_switch(ctx)
	if _p.weapon_key != key:
		_p.switch_weapon(key)
		await _settle_switch(ctx)


func _settle_switch(ctx: AnimTestContext) -> void:
	for i in 720:
		await ctx.frames(1)
		if not _p.is_switching() and _p._held_switch == "" and not (_p.weapon and _p.weapon.is_equipping()) \
				and not _p.anim.torch_ik.passing() and _p.anim.holds.exchange == "":
			break
	await ctx.seconds(0.3)


func _start_clear(ctx: AnimTestContext) -> void:
	FootSlip._release_all()
	var start = FootSlip._clear_start(_p, 24.0)
	if start != null:
		_p.global_position = Vector3(start.x, 0.05, start.y)
	_p.velocity = Vector3.ZERO
	_p.yaw = FootSlip._heading(FootSlip.TRAVEL)
	_p.pitch = 0.0
	if _p.is_crouching:
		await _tap(ctx, "crouch")
	await ctx.seconds(0.6)


func _tap(ctx: AnimTestContext, action: String, frames := 4) -> void:
	Input.action_press(action)
	await ctx.frames(frames)
	Input.action_release(action)
	await ctx.frames(1)


## The final pose (skeleton space: the character faces +Z, its left is +X).
func _on_updated() -> void:
	var rp := _sk.get_bone_global_pose(_ids.r_hand_prop_attachment)
	var lp := _sk.get_bone_global_pose(_ids.l_hand_prop_attachment)
	_last = {"rp": rp.origin, "lp": lp.origin, "head": _sk.get_bone_global_pose(_ids.headb).origin}
	if not _rec:
		_prev.clear()
		return
	var dt := maxf(float(_p.anim._last_dt), 1e-4)
	_t += dt
	var row := {"label": _label, "t": _t}
	var root := _sk.get_bone_global_pose(_ids.root).origin
	# the muzzle: the gun's model (it is where the hands put it)
	var musket: Weapon = _p.weapons.get("musket")
	row.why = "handoff %.2f, toss %.2f, aim %.2f, state %s" % [_p.anim.mid_ik.progress, _p.anim.holds.toss_t,
			_p.weapon.aim if _p.weapon else 0.0, _p.anim.loco.state]
	if not (musket and musket.model and musket.model.is_visible_in_tree()):
		_prev.clear()
	if musket and musket.model and musket.model.is_visible_in_tree():
		var mx: Transform3D = _sk.global_transform.affine_inverse() * musket.model.global_transform
		var muzzle := mx * Vector3(0.0, 0.035, -1.298)
		var butt := mx * Vector3(0.0, -0.06, 0.29)
		var toe := mx * Vector3(0.0, -0.147, 0.29)
		var pos := muzzle - root
		if not _prev.is_empty() and _prev.label == _label:
			var v := (pos - (_prev.p as Vector3)) / dt
			if _prev.has("v"):
				row.dv = (v - (_prev.v as Vector3)).length()
			_prev = {"label": _label, "p": pos, "v": v}
		else:
			_prev = {"label": _label, "p": pos}
		if _p.anim.mid_ik.progress >= 1.0 and _g != null and _g.ok and _g.model == musket.model:
			var m: Dictionary = _g.measure()
			row.palm = maxf(float(m.palm_gap), 0.0)
			row.depth = float(m.depth)
			row.closed = int(m.closed)
			row.grip_z = float(m.grip_z)
			var dir := (muzzle - butt).normalized()
			row.fwd = dir.z
			row.down = -dir.y
			var pel := _sk.get_bone_global_pose(_ids.pelvis).origin
			row.left = ((muzzle + butt) * 0.5 - pel).x
			var clear := INF
			for leg: Array in [["l_upper_leg", "l_knee", THIGH_R], ["l_knee", "l_ankle", SHIN_R], ["r_upper_leg", "r_knee", THIGH_R],
					["r_knee", "r_ankle", SHIN_R]]:
				var a := _sk.get_bone_global_pose(_ids[leg[0]]).origin
				var b := _sk.get_bone_global_pose(_ids[leg[1]]).origin
				var ps := Geometry3D.get_closest_points_between_segments(a, b, butt, muzzle)
				var c := (ps[0] as Vector3).distance_to(ps[1] as Vector3) - float(leg[2]) - GUN_R
				if c < clear:
					clear = c
					row.leg = "%s-%s at %.2f m from the butt" % [leg[0], leg[1], (ps[1] as Vector3).distance_to(butt)]
			row.clear = clear
			var foot := minf(_sk.get_bone_global_pose(_ids.l_ball).origin.y, _sk.get_bone_global_pose(_ids.r_ball).origin.y)
			row.ground = minf(muzzle.y, toe.y) - foot
			var ti := _p.anim.torch_ik
			if ti.torch_weight > 0.99 and ti.side == "r" and not ti.passing():
				row.t_out = -(rp.origin - pel).x
				row.tilt = rad_to_deg(ti.last_torch_axis.angle_to(Vector3.UP))
	_rows.append(row)
