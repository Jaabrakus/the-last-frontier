extends AnimTestSuite
## The torch in the off hand (push n01b; user 2026-09-25: "if we have torchs then we need to make a one hand
## animation where the rifle is held sideways along the hip ... and when the user aims they drop the torch and
## the lighting from the torch"; push n01c, user 2026-09-26: "the right hand holds the torch and the left hand holds
## the gun", the torch held like an axe, the gun gripped in the middle).
##
## Drives the player in the real level (scenes/main.tscn) and measures the FINAL pose (after every
## SkeletonModifier3D: Skeleton3D.skeleton_updated):
##  - inventory: the torches stack in the pack (InventoryState kind "torch"), T takes one out lit (light on,
##    PlayerAnim.torch_hand), T puts it back (light gone, burn time kept);
##  - the carry with the musket, idle / walk / run / sprint / stop / crouch idle / crouch walk / stand up / jump:
##    the torch in the RIGHT hand in the axe hold (upright within TORCH_TILT_MAX, the fist beside the right hip),
##    the gun in the LEFT hand alone along the left side (barrel forward and a little down, gripped in the middle
##    left of the hips: tests/torch/test_hand_holds.gd measures the fist on the skin), the right hand off the gun,
##    and no pops (the gun's muzzle and the torch's head: velocity change per frame in the character's frame);
##  - aim drops it: RMB with the musket tosses the torch (the right hand's toss), it lands ahead and to the right,
##    settles, keeps burning (its light on), the musket comes up to the two-hand aim (both prop bones together);
##  - pick up: E (tap) on the burning torch takes it back into the hand, its burn time carried on;
##  - burn out: a torch at its last seconds goes out, its stub falls, no light;
##  - rain and water (a stand-in "weather" / "water" node): heavy rain drowns it, water puts it out at once;
##  - H puts the weapon on the body and keeps the torch (in the right hand); the pistol keeps it (in the left hand,
##    aimed one-handed); the bow is drawn into the left hand beside it (the torch in the right), drawing the string
##    tosses it; a reload tosses it; mounting the horse puts it out and packs it; death lets it fall.
##   Godot --headless --fixed-fps 120 --path . -s tests/anim/run_all.gd -- --no-capture --dir=res://tests/torch --prefix=test_

## The carry (character frame: faces +Z, left +X, up +Y).
const BARREL_FWD_MIN := 0.8          ## the barrel's forward component
const BARREL_DOWN := Vector2(-0.02, 0.35)  ## its downward component (sin of the pitch below horizontal)
const BARREL_SIDE_MAX := 0.5         ## |its sideways component| (a strafe turns it with the hips)
const GRIP_LEFT_MIN := 0.12          ## the left fist on the gun this far left of the pelvis
const RIGHT_OFF_GUN_MIN := 0.2       ## the right prop this far from the gun (m)
const TORCH_TILT_MAX := 40.0         ## the torch's axis off vertical (deg); crouched TORCH_TILT_MAX_CROUCH
const TORCH_TILT_MAX_CROUCH := 50.0
const FIST_OUT_MIN := 0.12           ## the torch fist out to the right of the pelvis (m)
const FIST_UP := Vector2(-0.4, 0.3)  ## and its height from the pelvis (m)
## Pops: the velocity of the muzzle (1.1 m along the barrel) and the torch's head (0.4 m along it) relative to the
## root bone changes by at most this much per frame (m/s), after SETTLE_S of a segment.
const POP_DV_MAX := 0.9
const POP_DV_BIG := 1.6
const SETTLE_S := 0.5
## Segments: [label, seconds, held actions, tapped actions]; "big" ones change the carry (jumps, crouch changes).
const CARRY := [
	["idle", 1.2, [], []],
	["walk", 1.6, ["walk", "move_forward"], []],
	["run", 1.6, ["move_forward"], []],
	["sprint", 1.6, ["sprint", "move_forward"], []],
	["stop", 1.4, [], []],
	["crouch_idle", 1.4, [], ["crouch"]],
	["crouch_walk", 1.8, ["move_forward"], []],
	["stand_up", 1.2, [], ["crouch"]],
	["jump", 1.6, ["move_forward"], ["jump"]],
	["turn", 1.4, ["move_left"], []],
	["-", 0.6, [], []],
]
const BIG := ["crouch_idle", "stand_up", "jump", "stop"]

var _p: FrontierPlayer
var _sk: Skeleton3D
var _ids := {}
var _rec := false
var _label := "-"
var _t := 0.0
var _rows: Array = []
var _prev := {}
var _last := {}


class FakeWeather extends Node:
	var rain := 1.0


class FakeWater extends Node:
	var on := true
	func is_under_water(_pos: Vector3) -> bool:
		return on


func describe() -> String:
	return "torch: T / pack, the torch in the right hand like an axe and the musket in the left gripped in the middle (no pops), aim tosses it (burning on the ground), E picks it up, burn out, rain / water, pistol keeps it (left hand), bow beside it, reload, horse, death"


func timeout_s() -> float:
	return 600.0


func run(ctx: AnimTestContext) -> void:
	_p = await ctx.level()
	if _p == null:
		return
	ctx.allow_error("loops in the graph")
	_sk = _p.skeleton
	for n in ["r_hand_prop_attachment", "l_hand_prop_attachment", "neck", "pelvis", "spined", "root"]:
		_ids[n] = _sk.find_bone(n)
	_sk.skeleton_updated.connect(_on_updated)
	ctx.check(_p.torch != null, "the player has a PlayerTorch")
	ctx.check(InputMap.has_action(PlayerTorch.ACTION) and _key_of(PlayerTorch.ACTION) == KEY_T, "T is the torch key")
	await _equip(ctx, "musket")
	await _inventory(ctx)
	await _carry(ctx)
	if String(ctx.arg("only_carry", "")) == "1":
		_sk.skeleton_updated.disconnect(_on_updated)
		_dump(ctx)
		return
	await _drop_on_aim(ctx)
	await _pickup(ctx)
	await _hands_free(ctx)
	await _burn_out(ctx)
	await _rain_and_water(ctx)
	await _pistol(ctx)
	await _bow(ctx)
	await _reload(ctx)
	await _horse(ctx)
	await _death(ctx)
	_sk.skeleton_updated.disconnect(_on_updated)
	FootSlip._release_all()
	_dump(ctx)


func _dump(ctx: AnimTestContext) -> void:
	var out := String(ctx.arg("json_out", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			var rows: Array = []
			for r: Dictionary in _rows:
				rows.append({"label": r.label, "t": r.t, "barrel": [r.barrel.x, r.barrel.y, r.barrel.z], "tilt": r.tilt,
						"dv_muzzle": r.dv_muzzle, "dv_head": r.dv_head, "gap": r.gap, "state": r.get("state", ""),
						"fist": [r.fist.x, r.fist.y, r.fist.z], "axis": r.get("axis", []), "lp": r.get("lp", []), "sw": r.get("sw", [])})
			f.store_string(JSON.stringify({"rows": rows}))
			ctx.info("wrote " + out)


# --- the pack, T ----------------------------------------------------------------------------------------------

func _inventory(ctx: AnimTestContext) -> void:
	var t := _p.torch
	var n0 := t.count()
	ctx.check(n0 == _p.torch_count, "the pack starts with torch_count torches (%d)" % n0)
	var inv := InventoryState.from_player(_p)
	ctx.check(inv.pack_count("torch") == n0, "the inventory's pack shows them as one stack (x%d)" % inv.pack_count("torch"))
	ctx.check(InventoryState.name_of("torch") != "torch", "the torch has a display name (%s)" % InventoryState.name_of("torch"))
	await _tap(ctx, PlayerTorch.ACTION)
	await ctx.seconds(0.6)
	ctx.check(t.holding() and t.held.lit and _p.anim.torch_ik.side == "r", "T: a torch in the right hand, lit (%s)" % _p.anim.torch_ik.side)
	ctx.check(_p.anim.mid_ik.in_left(), "the musket went to the left hand first (handoff %.2f)" % _p.anim.mid_ik.progress)
	ctx.check(t.count() == n0 - 1, "one torch less in the pack (%d)" % t.count())
	ctx.check(_p.anim.torch_hand, "PlayerAnim.torch_hand on")
	ctx.check(t.fire != null and t.fire.light.visible and t.fire.light.light_energy > 0.3,
			"its light is on (energy %.2f, range %.1f m)" % [t.fire.light.light_energy if t.fire else 0.0, t.fire.light.omni_range if t.fire else 0.0])
	ctx.check(t.fire != null and t.fire.light.distance_fade_enabled and t.fire.light.omni_range <= TorchFire.LIGHT_RANGE,
			"the light is limited: range <= %.0f m, distance fade" % TorchFire.LIGHT_RANGE)
	ctx.check(InventoryState.from_player(_p).pack_count("torch") == n0 - 1, "the pack's stack follows (x%d)" % (n0 - 1))
	ctx.check(t.hud_text().begins_with("Torch"), "HUD line: '%s'" % t.hud_text())
	var left := t.held.burn_left
	Input.action_press(PlayerTorch.ACTION)          # (a hold puts it away since 2026-09-27; a tap raises it)
	await ctx.seconds(PlayerTorch.HOLD_S + 0.15)
	Input.action_release(PlayerTorch.ACTION)
	await ctx.seconds(0.4)
	# (the musket comes back to both hands at the unhurried pace: HandHolds.RELAXED_HANDOFF_S)
	for i in 120:
		if _p.anim.mid_ik.progress <= 0.0:
			break
		await ctx.frames(1)
	ctx.check(not t.holding() and t.count() == n0, "T held: put out and back in the pack (%d)" % t.count())
	ctx.check(not _p.anim.torch_hand, "PlayerAnim.torch_hand off")
	ctx.check(_p.anim.torch_ik.torch_weight <= 0.0 and _p.anim.mid_ik.progress <= 0.0 and _p.anim.left_grip.enabled,
			"the torch hold is off, the musket back in both hands")
	var lit := 0
	for f in ctx.tree.get_nodes_in_group(TorchFire.GROUP):
		if is_instance_valid(f) and not f.is_queued_for_deletion() and (f as TorchFire).light.visible:
			lit += 1
	ctx.check(lit == 0, "no torch light left burning (%d)" % lit)
	var kept := false
	for b: float in t.pack:
		if absf(b - left) < 0.5:
			kept = true
	ctx.check(kept, "its burn time kept in the pack (%.1f s)" % left)
	await _tap(ctx, PlayerTorch.ACTION)
	await ctx.seconds(0.8)
	ctx.check(t.holding() and absf(t.held.burn_left - left) < 1.5, "T takes the used torch first (%.1f s left)" % (t.held.burn_left if t.held else -1.0))


# --- the carry -------------------------------------------------------------------------------------------------

func _carry(ctx: AnimTestContext) -> void:
	await _start_clear(ctx)
	if not _p.torch.holding():
		_p.torch.take_out()
	await ctx.seconds(0.8)
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
		var rows := _rows.filter(func(r: Dictionary) -> bool: return r.label == lab and float(r.t) >= SETTLE_S)
		if rows.is_empty():
			ctx.fail("%s: no frames" % lab)
			continue
		var crouch := lab.begins_with("crouch")
		var worst := {"fwd": 1.0, "down_lo": 1.0, "down_hi": -1.0, "side": 0.0, "grip_x": 9.0, "gap": 9.0, "tilt": 0.0,
				"fist_x": 9.0, "fist_y_lo": 9.0, "fist_y_hi": -9.0, "dv_muzzle": 0.0, "dv_head": 0.0}
		for r: Dictionary in rows:
			worst.fwd = minf(worst.fwd, r.barrel.z)
			worst.down_lo = minf(worst.down_lo, -r.barrel.y)
			worst.down_hi = maxf(worst.down_hi, -r.barrel.y)
			worst.side = maxf(worst.side, absf(r.barrel.x))
			worst.grip_x = minf(worst.grip_x, float(r.grip_left))
			worst.gap = minf(worst.gap, float(r.gap))
			worst.tilt = maxf(worst.tilt, float(r.tilt))
			worst.fist_x = minf(worst.fist_x, r.fist.x)
			worst.fist_y_lo = minf(worst.fist_y_lo, r.fist.y)
			worst.fist_y_hi = maxf(worst.fist_y_hi, r.fist.y)
			worst.dv_muzzle = maxf(worst.dv_muzzle, float(r.dv_muzzle))
			worst.dv_head = maxf(worst.dv_head, float(r.dv_head))
		ctx.info("%-12s barrel fwd %.2f down %.2f..%.2f side %.2f | grip %.2f m left | right hand %.2f m off | torch tilt %.0f deg, fist %.2f out %.2f..%.2f up | dv muzzle %.2f head %.2f m/s (%d frames)" % [
				lab, worst.fwd, worst.down_lo, worst.down_hi, worst.side, worst.grip_x, worst.gap, worst.tilt, worst.fist_x,
				worst.fist_y_lo, worst.fist_y_hi, worst.dv_muzzle, worst.dv_head, rows.size()])
		ctx.metric("carry_" + lab, worst)
		var air := lab == "jump"
		ctx.check(worst.fwd >= BARREL_FWD_MIN and worst.side <= BARREL_SIDE_MAX,
				"%s: the gun points forward along the left side (fwd %.2f, side %.2f)" % [lab, worst.fwd, worst.side])
		ctx.check(air or (worst.down_lo >= BARREL_DOWN.x and worst.down_hi <= BARREL_DOWN.y),
				"%s: the barrel a little below level (%.2f..%.2f)" % [lab, worst.down_lo, worst.down_hi])
		ctx.check(worst.grip_x >= GRIP_LEFT_MIN, "%s: the left fist on the gun at the left hip (%.2f m to the hips' left)" % [lab, worst.grip_x])
		ctx.check(worst.gap >= RIGHT_OFF_GUN_MIN, "%s: the right hand is off the gun (%.2f m)" % [lab, worst.gap])
		ctx.check(worst.tilt <= (TORCH_TILT_MAX_CROUCH if crouch or air else TORCH_TILT_MAX), "%s: the torch held upright (%.0f deg off vertical)" % [lab, worst.tilt])
		ctx.check(worst.fist_x >= FIST_OUT_MIN and worst.fist_y_lo >= FIST_UP.x and worst.fist_y_hi <= FIST_UP.y,
				"%s: the torch fist beside the right hip (%.2f out, %.2f..%.2f up from the pelvis)" % [lab, worst.fist_x, worst.fist_y_lo, worst.fist_y_hi])
		var dv_max := POP_DV_BIG if lab in BIG else POP_DV_MAX
		ctx.check(worst.dv_muzzle <= dv_max and worst.dv_head <= dv_max,
				"%s: no pops (muzzle %.2f, torch head %.2f <= %.1f m/s per frame)" % [lab, worst.dv_muzzle, worst.dv_head, dv_max])


# --- aim drops it, E picks it up ----------------------------------------------------------------------------------

func _drop_on_aim(ctx: AnimTestContext) -> void:
	await _start_clear(ctx)
	var t := _p.torch
	if not t.holding():
		t.take_out()
	await ctx.seconds(1.0)
	var start := _p.global_transform
	Input.action_press("aim")
	var tossed := false
	var released_at := -1.0
	for i in 90:
		await ctx.frames(1)
		tossed = tossed or _p.anim.torch_tossing()
		if not t.holding() and released_at < 0.0:
			released_at = i / float(Engine.physics_ticks_per_second)
	ctx.check(tossed, "RMB with the musket plays the toss")
	ctx.check(released_at > 0.05 and released_at < 0.45, "the torch leaves the hand %.2f s after the aim starts" % released_at)
	var d := t.last_dropped
	ctx.check(d != null and is_instance_valid(d), "a DroppedTorch is on its way")
	if d == null or not is_instance_valid(d):
		Input.action_release("aim")
		return
	await ctx.seconds(2.5)
	var local := start.affine_inverse() * d.global_position
	ctx.check(d.settled(), "it settles on the ground (frozen)")
	ctx.check(local.z < -0.3 and local.z > -3.0 and local.x > 0.0 and Vector2(local.x, local.z).length() < 3.0,
			"it lands a little ahead and to the right (%.2f right, %.2f ahead)" % [local.x, -local.z])
	ctx.check(d.state.lit and d.fire.light.visible and d.fire.light.light_energy > 0.3, "it keeps burning, its light on the ground")
	ctx.check(absf(d.global_position.y - _p.global_position.y) < 0.3, "on the ground (%.2f m)" % (d.global_position.y - _p.global_position.y))
	ctx.check(_p.weapon.aim > 0.95, "the musket is up (aim %.2f)" % _p.weapon.aim)
	ctx.check(_p.anim.right_arm.weight <= 0.0 and _p.anim.torch_ik.torch_weight <= 0.0 and not _p.anim.torch_hand
			and _p.anim.mid_ik.progress <= 0.0, "the torch arm is off, the gun back on the right prop (the aim's own arms)")
	var gap := (_last.get("lp", Vector3.INF) as Vector3).distance_to(_last.get("rp", Vector3.ZERO) as Vector3)
	ctx.check(gap < 0.06, "both hands on the gun in the aim (the prop bones %.3f m apart)" % gap)
	Input.action_release("aim")
	await ctx.seconds(0.8)


func _pickup(ctx: AnimTestContext) -> void:
	var t := _p.torch
	var d := t.last_dropped
	if d == null or not is_instance_valid(d):
		ctx.fail("pick up: no torch on the ground")
		return
	var left := d.state.burn_left
	# stand 1.2 m from it, facing it
	var to := d.global_position - _p.global_position
	to.y = 0.0
	var at := d.global_position - to.normalized() * 1.2
	_p.global_position = Vector3(at.x, _p.global_position.y, at.z)
	_p.velocity = Vector3.ZERO
	_p.yaw = atan2(-to.x, -to.z)
	_p.pitch = deg_to_rad(-20.0)
	await ctx.seconds(0.4)
	ctx.check(_p.interactor.target == d, "the interactor targets the burning torch")
	ctx.check(_p.interactor._label.text.contains("Take the torch"), "prompt '%s'" % _p.interactor._label.text)
	await _tap(ctx, "interact", 5)
	await ctx.seconds(0.9)
	ctx.check(t.holding() and t.held.lit and _p.anim.torch_ik.side == "r", "E (tap): the torch back in the right hand, burning")
	ctx.check(not is_instance_valid(d) or d.is_queued_for_deletion(), "gone from the ground")
	ctx.check(t.held != null and t.held.burn_left < left and t.held.burn_left > left - 5.0,
			"its burn time carried on (%.1f -> %.1f s)" % [left, t.held.burn_left if t.held else -1.0])
	ctx.check(_p.anim.torch_hand, "the torch arm back on")


## H with the torch: the weapon goes onto the body, the torch stays; H again draws it, the torch kept.
func _hands_free(ctx: AnimTestContext) -> void:
	var t := _p.torch
	if not t.holding():
		t.take_out()
	await ctx.seconds(0.5)
	# (H is read in the player's _unhandled_input: a scripted action press sends no event)
	_p.toggle_hands_free()
	await ctx.seconds(1.2)
	ctx.check(_p.hands_free and t.holding() and _p.anim.torch_ik.side == "r", "H: the musket onto the body, the torch kept in the right hand")
	ctx.check(_p.anim.left_arm.enabled and _p.anim.left_arm.source_key == "free", "the left arm swings free meanwhile")
	_p.toggle_hands_free()
	for i in 400:
		await ctx.frames(1)
		if not _p.hands_free and _p.weapon.active and not _p.weapon.is_equipping():
			break
	await ctx.seconds(0.5)
	ctx.check(not _p.hands_free and _p.weapon_key == "musket" and t.holding(), "H again: the musket drawn, the torch kept")
	ctx.check(_p.anim.mid_ik.in_left() and _p.anim.torch_ik.side == "r", "the musket in the left hand again, the torch in the right")


# --- the fire ---------------------------------------------------------------------------------------------------

func _burn_out(ctx: AnimTestContext) -> void:
	var t := _p.torch
	if not t.holding():
		t.take_out()
	await ctx.seconds(0.3)
	t.held.burn_left = 1.2
	await ctx.seconds(0.6)
	ctx.check(t.holding() and t.held.strength() < 0.8, "dying down in its last seconds (%.2f)" % (t.held.strength() if t.held else -1.0))
	await ctx.seconds(1.2)
	ctx.check(not t.holding(), "burnt out: the stub leaves the hand")
	var d := t.last_dropped
	ctx.check(d != null and is_instance_valid(d) and d.state.burnt_out() and not d.state.lit, "the stub on the ground is burnt out")
	ctx.check(d != null and is_instance_valid(d) and not d.fire.light.visible, "no light from it")
	ctx.check(d != null and is_instance_valid(d) and d.interact_prompt(_p) == "", "nothing to take from a burnt-out stub")
	await ctx.seconds(0.5)


func _rain_and_water(ctx: AnimTestContext) -> void:
	var t := _p.torch
	t.take_out()
	await ctx.seconds(0.5)
	# the game's weather drives it: DayNight (not built headless, so a bare one here) joins the group at setup
	# and its weather's rain is what the torch reads
	var dn := DayNight.new()
	var sun := DirectionalLight3D.new()
	sun.visible = false
	dn.add_child(sun)
	ctx.add_node(dn)
	dn.setup(null, Environment.new(), sun, null)
	dn.clock.running = false
	ctx.check(dn.is_in_group(TorchState.WEATHER_GROUP), "DayNight is in the weather group")
	dn.weather.rain = 0.8
	var r := TorchState.rain_at(_p.get_tree(), _p.global_position)
	ctx.check(is_equal_approx(r, 0.8), "the weather's rain reaches the torch (%.2f)" % r)
	dn.weather.rain = 0.0
	dn.queue_free()
	await ctx.frames(2)
	var w := FakeWeather.new()
	w.add_to_group(TorchState.WEATHER_GROUP)
	ctx.add_node(w)
	var drown := TorchState.DROWN_S * TorchState.RAIN_HEAVY / w.rain
	await ctx.seconds(drown * 0.5)
	ctx.check(t.holding() and t.held.lit and t.held.wet > 0.3, "heavy rain soaks it (wet %.2f)" % (t.held.wet if t.held else -1.0))
	await ctx.seconds(drown * 0.6 + 0.5)
	ctx.check(t.holding() and not t.held.lit and t.held.out_reason == "rain", "heavy rain puts it out (%s)" % (t.held.out_reason if t.held else "-"))
	w.rain = 0.0
	await ctx.seconds(0.5)
	await _tap(ctx, PlayerTorch.ACTION)
	await ctx.seconds(0.3)
	ctx.check(t.holding() and t.held.lit, "out of the rain T lights it again")
	w.queue_free()
	var water := FakeWater.new()
	water.add_to_group(TorchState.WATER_GROUP)
	ctx.add_node(water)
	await ctx.seconds(0.5)
	ctx.check(t.holding() and not t.held.lit and t.held.out_reason == "water", "under water it goes out at once")
	water.queue_free()
	await ctx.seconds(0.3)
	t.put_away()
	await ctx.seconds(0.2)


# --- the other weapons and the rest -------------------------------------------------------------------------------

func _pistol(ctx: AnimTestContext) -> void:
	await _equip(ctx, "pistol")
	var t := _p.torch
	t.take_out()
	await ctx.seconds(0.8)
	Input.action_press("aim")
	await ctx.seconds(1.0)
	ctx.check(t.holding(), "the pistol's aim keeps the torch (one-handed)")
	ctx.check(_p.weapon.aim > 0.9, "the pistol is up (aim %.2f)" % _p.weapon.aim)
	ctx.check(_p.anim.torch_ik.side == "l" and _p.anim.left_arm.enabled and _p.anim.left_arm.source_key.begins_with("torch"),
			"the left arm holds the torch meanwhile")
	var tilt := rad_to_deg(_p.anim.torch_ik.last_torch_axis.angle_to(Vector3.UP))
	ctx.check(tilt <= TORCH_TILT_MAX, "the torch upright while the pistol aims (%.0f deg off vertical)" % tilt)
	Input.action_release("aim")
	await ctx.seconds(0.6)


func _bow(ctx: AnimTestContext) -> void:
	var t := _p.torch
	if not t.holding():
		t.take_out()
	await _equip(ctx, "bow")
	await ctx.seconds(0.8)
	ctx.check(_p.weapon_key == "bow" and not _p.hands_free and _p.weapon.active and t.holding() and _p.anim.torch_ik.side == "r",
			"choosing the bow with the torch: the bow in the left hand, the torch in the right (%s)" % _p.anim.torch_ik.side)
	Input.action_press("fire")
	var gone := false
	for i in 90:
		await ctx.frames(1)
		gone = gone or not t.holding()
	ctx.check(gone, "drawing the bow (LMB) tosses the torch")
	await ctx.seconds(1.2)
	ctx.check(not _p.hands_free and _p.weapon.active, "and the bow is drawn")
	Input.action_release("fire")
	await ctx.seconds(0.6)
	# with the bow out, a torch taken goes into the right hand beside it
	t.take_out()
	await ctx.seconds(1.0)
	ctx.check(t.holding() and not _p.hands_free and _p.weapon_key == "bow" and _p.anim.torch_ik.side == "r",
			"a torch taken with the bow out goes into the right hand, the bow stays in the left")
	await _equip(ctx, "musket")
	ctx.check(not _p.hands_free and _p.weapon_key == "musket" and t.holding() and _p.anim.mid_ik.in_left(),
			"the musket drawn with the torch kept (the gun in the left hand)")


func _reload(ctx: AnimTestContext) -> void:
	var t := _p.torch
	if not t.holding():
		t.take_out()
	await ctx.seconds(0.8)
	var f := _p.weapon as Firearm
	f.loaded = false
	f.state = Firearm.State.EMPTY
	await _tap(ctx, "reload")
	var gone := false
	for i in 90:
		await ctx.frames(1)
		gone = gone or not t.holding()
	ctx.check(gone, "a reload tosses the torch (both hands on the musket)")
	await ctx.seconds(1.0)
	var d := t.last_dropped
	ctx.check(d != null and is_instance_valid(d) and d.state.lit, "burning on the ground meanwhile")
	await ctx.seconds(8.0)


func _horse(ctx: AnimTestContext) -> void:
	var t := _p.torch
	var h: Horse = null
	for n in ctx.tree.current_scene.find_children("*", "Horse", true, false):
		h = n as Horse
		break
	if h == null:
		ctx.warn("no horse in the level: mounting not checked")
		return
	t.take_out()
	await ctx.seconds(0.6)
	var n0 := t.count()
	_p.global_position = h.global_position + Vector3(1.5, 0.1, 0)
	await ctx.seconds(0.2)
	ctx.check(_p.mount(h), "mounts the horse")
	await ctx.seconds(0.3)
	ctx.check(not t.holding() and t.count() == n0 + 1, "mounting puts the torch out and packs it (%d)" % t.count())
	await _tap(ctx, PlayerTorch.ACTION)
	await ctx.seconds(0.2)
	ctx.check(not t.holding(), "no torch on horseback")
	_p.dismount()
	await ctx.seconds(0.8)


func _death(ctx: AnimTestContext) -> void:
	var t := _p.torch
	t.take_out()
	await ctx.seconds(0.6)
	_p.apply_hit(10000.0, _p.global_position + Vector3.FORWARD, Vector3.BACK)
	await ctx.seconds(0.3)
	ctx.check(_p.is_dead and not t.holding(), "death lets the torch fall")
	var d := t.last_dropped
	ctx.check(d != null and is_instance_valid(d) and d.state.lit, "it burns where it fell")
	_p.respawn()
	await ctx.seconds(1.0)


# --- helpers --------------------------------------------------------------------------------------------------

func _equip(ctx: AnimTestContext, key: String) -> void:
	_p.switch_weapon(key)
	for i in 600:
		await ctx.frames(1)
		if not _p.is_switching() and _p.weapon_key == key and not (_p.weapon and _p.weapon.is_equipping()):
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


static func _key_of(action: StringName) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return (e as InputEventKey).physical_keycode
	return 0


## The final pose (after every modifier), in the character's frame (skeleton space: faces +Z, left +X).
func _on_updated() -> void:
	var rp := _sk.get_bone_global_pose(_ids.r_hand_prop_attachment)
	var lp := _sk.get_bone_global_pose(_ids.l_hand_prop_attachment)
	_last = {"rp": rp.origin, "lp": lp.origin}
	if not _rec:
		_prev.clear()
		return
	var dt := maxf(float(_p.anim._last_dt), 1e-4)
	_t += dt
	# the gun where its model is (the left hand's, GunMiddleCarryIK): +Z the muzzle's way
	var m: Node3D = _p.weapons.musket.model
	var mx: Transform3D = _sk.global_transform.affine_inverse() * m.global_transform
	var barrel := (mx.basis * Vector3.FORWARD).normalized()
	var butt := mx * Vector3(0.0, 0.0, 0.29)
	var ti := _p.anim.torch_ik
	var axis := ti.last_torch_axis
	# the pops relative to the root bone: the clips' own root travel (keyed at 10-15 Hz like everything else) moves
	# the whole body and is not the hold's
	var root := _sk.get_bone_global_pose(_ids.root).origin
	var muzzle := mx * Vector3(0.0, 0.035, -1.298) - root
	var head := ti.last_flame - root
	var pg := _sk.get_bone_global_pose(_ids.pelvis)
	var pelvis := pg.origin
	# the hips' left, flattened (TorchCarryIK.yaw_frame: the pelvis' forward and up from its rest)
	var pr := _sk.get_bone_global_rest(_ids.pelvis).basis.orthonormalized().inverse()
	var hips: Array = TorchCarryIK.yaw_frame(pg.basis, (pr * Vector3.BACK).normalized(), (pr * Vector3.UP).normalized())
	var grip_left := (_p.anim.mid_ik.last_left.origin - pelvis).dot(hips[1] as Vector3)
	var gap := rp.origin.distance_to(Geometry3D.get_closest_point_to_segment(rp.origin, butt, muzzle + root))
	var dvm := 0.0
	var dvh := 0.0
	if not _prev.is_empty() and _prev.label == _label:
		var vm := (muzzle - (_prev.muzzle as Vector3)) / dt
		var vh := (head - (_prev.head as Vector3)) / dt
		if _prev.has("vm"):
			dvm = (vm - (_prev.vm as Vector3)).length()
			dvh = (vh - (_prev.vh as Vector3)).length()
		_prev = {"label": _label, "muzzle": muzzle, "head": head, "vm": vm, "vh": vh}
	else:
		_prev = {"label": _label, "muzzle": muzzle, "head": head}
	_rows.append({"label": _label, "t": _t, "state": String(_p.anim.loco.state), "barrel": barrel, "grip_left": grip_left, "gap": gap,
			"tilt": rad_to_deg(axis.angle_to(Vector3.UP)), "fist": ti.last_fist, "axis": [axis.x, axis.y, axis.z], "lp": [lp.origin.x, lp.origin.y, lp.origin.z],
			"sw": [_p.anim.right_arm.weight, ti.torch_weight, _p.anim.right_arm.source_key], "dv_muzzle": dvm, "dv_head": dvh})
