extends AnimTestSuite
## The legs under a firearm's reload (user 2026-10-03: "the current reload legs for pistol and guns need to be replaced with
## the jog ones"; FrontierPlayer.reload_jog, UpperBody.reload_walk, PlayerAnim's legs_aim). In the level, each firearm (the
## musket, the pistol, the over-under) emptied and reloaded:
##  1. standing still: the idle's legs (LocoBrain IDLE, not aimed) and the body still;
##  2. moving standing, forward (W) and sideways (A): the jog bank as the bow and the pistol aimed on the move have it
##     (LocoBrain in the "run" mode, a run-* graph state or the jog's own start idle^run-*, not aimed); the player's target
##     and body speed at run_speed x JOG_AIM_PACE (not the busy crawl, not the aim walk's pace); the jog's stride played at
##     the body's speed (LocoBrain.ratio not clamped); the planted-foot slip (FootSlip) at most SLIP_MARGIN over the pistol
##     aimed on the jog (the jog aim the reload now matches, measured first in the same run);
##  3. crouched and moving: the crouch walk or its start (mode "crouch") at the crouch's busy pace (crouch_speed x speed_mult());
##  4. a sprint (Shift with W) still ends the reload.
## Also the anim-input rule alone (UpperBody.reload_walk: only the crouched musket's reload keeps the aim stance).
##
##   Godot --headless --fixed-fps 120 --path . -s tests/anim/run_all.gd -- --no-capture --only=test_reload_legs

const GUNS := ["musket", "pistol", "over_under"]
const DIRS := {"W": ["move_forward"], "A": ["move_left"]}
## The jog's bank (or the crouch walk's) on at least this share of the window's frames (the rest: a hemisphere fade).
const JOG_FRAC := 0.95
const SPEED_TOL := 0.06          ## m/s
const SLIP_MARGIN := 0.1         ## m/s over the jog aim's median
const STILL_S := 0.4
const SETTLE_S := 1.3            ## from the key press: the jog's start is over (about 1.1 s at the 0.7 pace)
const MEASURE_S := 0.9

var _ref_slip := NAN


func describe() -> String:
	return "reload legs: each firearm reloaded still -> idle, moving standing -> the jog bank at run_speed x JOG_AIM_PACE (no clamp, slip as the jog aim's), crouched -> crouch walk, sprint ends it"


func timeout_s() -> float:
	return 600.0


func run(ctx: AnimTestContext) -> void:
	var player = await ctx.level()
	if player == null:
		return
	_rule(ctx, player.anim.upper)
	OverUnderKit.install(player, true)
	var hb := Hotbar.find(player)
	if hb != null:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make("weapon", "over_under"))
	await _jog_aim_reference(ctx, player)
	for key: String in GUNS:
		await _gun(ctx, player, key)


# --- the rule alone ---------------------------------------------------------------------------------------------

func _rule(ctx: AnimTestContext, ub: UpperBody) -> void:
	for key in ["musket", "pistol", "over_under"]:
		for crouched in [false, true]:
			var inp := AnimInputs.new()
			inp.busy = true
			inp.crouched = crouched
			inp.weapon_key = StringName(key)
			inp.speed = 2.0
			inp.wish_local = Vector2(0.0, 2.0)
			var want: bool = key == "musket" and crouched
			ctx.check(ub.reload_walk(inp) == want, "reload_walk(%s, %s, moving) = %s" % [key, "crouched" if crouched else "standing", want])
	var still := AnimInputs.new()
	still.busy = true
	still.crouched = true
	still.weapon_key = &"musket"
	ctx.check(not ub.reload_walk(still), "reload_walk(musket, crouched, still) = false: the idle's legs")


# --- the level ----------------------------------------------------------------------------------------------------

func _equip(ctx: AnimTestContext, player: Node, key: String) -> void:
	if String(player.weapon_key) != key:
		player.switch_weapon(key)
		await ctx.frames(30)
	var w8 := 0
	while (player.is_switching() or player.weapon.is_equipping()) and w8 < 900:
		await ctx.frames(1)
		w8 += 1


## Empties the gun in hand and starts its reload (the over-under: both barrels fired, its R chain).
static func _reload(w: Firearm) -> void:
	if w.state == Firearm.State.RELOADING:
		w._interrupt_reload()
	if w is OverUnderMusket:
		var ou := w as OverUnderMusket
		ou.barrels.restore({"top": 0, "stage": [0, 0], "load_in": [false, false]})
		ou.half_cocked = false
		ou._mirror()
	else:
		w.loaded = false
		w._stage = 0
	w.reserve = maxi(w.reserve, 6)
	w.state = Firearm.State.EMPTY
	w.start_reload()


## Puts the player at the start of a clear lane, facing so that `dir` travels along it.
static func _place(player: Node, dir: String) -> bool:
	var start = FootSlip._clear_start(player, 9.0)
	if start == null:
		return false
	var iv := Vector2(-1.0, 0.0) if dir == "A" else Vector2(0.0, -1.0)
	player.global_position = Vector3(start.x, 0.05, start.y)
	player.velocity = Vector3.ZERO
	player.yaw = FootSlip._heading(FootSlip.TRAVEL) - FootSlip._heading(Vector3(iv.x, 0.0, iv.y))
	player.pitch = 0.0
	return true


static func _press(actions: Array, on: bool) -> void:
	for a: String in actions:
		if on:
			Input.action_press(a)
		else:
			Input.action_release(a)


func _stop(ctx: AnimTestContext, player: Node) -> void:
	FootSlip._release_all()
	var w8 := 0
	while player.horizontal_speed() > 0.05 and w8 < 240:
		await ctx.frames(1)
		w8 += 1
	await ctx.frames(30)


## The speed the player should go at: `base` with the player's own multipliers after the band (survival, maim, a drag cap).
static func _expect(player: Node, base: float) -> float:
	return minf(base * float(player.survival_speed_mult) * float(player._maim_speed()), float(player.drag_speed_cap))


## Samples the window: {jog, crouch, clamped, n, target, body, slip}.
func _window(ctx: AnimTestContext, player: Node, seconds: float) -> Dictionary:
	var loco: LocoBrain = player.anim.loco
	var meter := FootSlip.new(player, player.skeleton)
	meter.start()
	var n := int(seconds * Engine.physics_ticks_per_second)
	var jog := 0
	var crouch := 0
	var clamped := 0
	var target := 0.0
	var body := 0.0
	var states := {}
	for i in n:
		await ctx.frames(1)
		var gs := String(loco.graph_state)
		states["%s/%s/%s%s" % [loco.state, loco.mode, gs, " aimed" if loco.aimed else ""]] = true
		# (the jog bank, or the jog's own start from standing: idle^run-fwd / -bkwd)
		var jog_gs := (loco.state == LocoBrain.MOVE and gs.begins_with("run-")) or (loco.state == LocoBrain.START and gs.begins_with("idle^run-"))
		if jog_gs and loco.mode == &"run" and not loco.aimed:
			jog += 1
		# (the crouch walk, or its start)
		if loco.state in [LocoBrain.MOVE, LocoBrain.START] and loco.mode == &"crouch":
			crouch += 1
		# (LocoBrain.ratio is the move bank's: only while it plays)
		if loco.state == LocoBrain.MOVE and absf(loco.ratio - loco.ratio_raw) > 1e-3:
			clamped += 1
		target += float(player.target_speed)
		body += float(player.horizontal_speed())
	meter.stop()
	var slip: Dictionary = meter.result()
	return {"jog": float(jog) / n, "crouch": float(crouch) / n, "clamped": clamped, "n": n, "target": target / n,
			"body": body / n, "slip": float(slip.get("median_mps", NAN)), "states": states.keys(), "ratio": loco.ratio}


## The pistol aimed on the jog (LMB held, the shot then cancelled with RMB): the legs and pace the reload is to match.
func _jog_aim_reference(ctx: AnimTestContext, player: Node) -> void:
	await _equip(ctx, player, "pistol")
	var w: Firearm = player.weapon
	w.loaded = true
	w.state = Firearm.State.READY
	if not ctx.check(_place(player, "W"), "a clear lane for the jog aim"):
		return
	await ctx.frames(40)
	Input.action_press("fire")
	_press(DIRS.W, true)
	await ctx.seconds(SETTLE_S)
	var r := await _window(ctx, player, MEASURE_S)
	Input.action_press("aim")
	await ctx.frames(3)
	Input.action_release("fire")
	Input.action_release("aim")
	await _stop(ctx, player)
	_ref_slip = float(r.slip)
	var pace := _expect(player, float(player.run_speed) * FrontierPlayer.JOG_AIM_PACE)
	ctx.info("jog aim (pistol, W): jog %.2f, target %.2f, body %.2f m/s, ratio %.2f, slip %.3f m/s; states %s"
			% [r.jog, r.target, r.body, r.ratio, r.slip, r.states])
	ctx.metric("jog_aim_pistol_slip_mps", snappedf(r.slip, 0.001))
	ctx.check(float(r.jog) >= JOG_FRAC and absf(float(r.target) - pace) <= SPEED_TOL,
			"reference: the pistol aimed on the move jogs at the jog aim's pace (%.2f of frames, %.2f m/s)" % [r.jog, r.target])


func _gun(ctx: AnimTestContext, player: Node, key: String) -> void:
	await _equip(ctx, player, key)
	await FootSlip._set_crouch(ctx.tree, player, false, ctx)
	if not ctx.check(String(player.weapon_key) == key and player.weapon is Firearm, "%s in hand" % key):
		return
	var w: Firearm = player.weapon
	var loco: LocoBrain = player.anim.loco
	var pace := _expect(player, float(player.run_speed) * FrontierPlayer.JOG_AIM_PACE)
	for dir: String in DIRS:
		if not ctx.check(_place(player, dir), "%s: a clear lane" % key):
			return
		await ctx.frames(40)
		_reload(w)
		await ctx.frames(2)
		ctx.check(w.state == Firearm.State.RELOADING, "%s: reloading" % key)
		# 1. still: the idle's legs
		await ctx.seconds(STILL_S)
		ctx.check(loco.state == LocoBrain.IDLE and not loco.aimed and player.horizontal_speed() < 0.05,
				"%s reloading still: the idle's legs (%s, aimed %s, %.2f m/s)" % [key, loco.state, loco.aimed, player.horizontal_speed()])
		# 2. moving standing: the jog's legs at the jog aim's pace
		_press(DIRS[dir], true)
		await ctx.seconds(SETTLE_S)
		var r := await _window(ctx, player, MEASURE_S)
		var still_reloading := w.state == Firearm.State.RELOADING
		ctx.info("%s reload %s: jog %.2f, target %.2f, body %.2f m/s (want %.2f), ratio %.2f, clamped %d, slip %.3f m/s; states %s"
				% [key, dir, r.jog, r.target, r.body, pace, r.ratio, r.clamped, r.slip, r.states])
		ctx.metric("reload_%s_%s_slip_mps" % [key, dir], snappedf(r.slip, 0.001))
		ctx.metric("reload_%s_%s_speed_mps" % [key, dir], snappedf(r.body, 0.001))
		ctx.check(still_reloading, "%s reload %s: still reloading through the window" % [key, dir])
		ctx.check(float(r.jog) >= JOG_FRAC, "%s reload %s: the jog bank (run mode, not aimed) on %.2f of the frames" % [key, dir, r.jog])
		ctx.check(absf(float(r.target) - pace) <= SPEED_TOL and absf(float(r.body) - pace) <= SPEED_TOL,
				"%s reload %s: run_speed x JOG_AIM_PACE = %.2f m/s (target %.2f, body %.2f)" % [key, dir, pace, r.target, r.body])
		ctx.check(int(r.clamped) == 0, "%s reload %s: the stride played at the body's speed (ratio %.2f, clamped on %d frames)" % [key, dir, r.ratio, r.clamped])
		if not is_nan(_ref_slip):
			ctx.at_most(float(r.slip), _ref_slip + SLIP_MARGIN, "%s reload %s: planted-foot slip vs the jog aim's %.3f m/s" % [key, dir, _ref_slip])
		# 4. a sprint ends it (forward only)
		if dir == "W":
			ctx.check(w.state == Firearm.State.RELOADING, "%s: reloading when Shift is pressed" % key)
			Input.action_press("sprint")
			await ctx.frames(12)
			ctx.check(w.state != Firearm.State.RELOADING, "%s: a sprint ends the reload (%s)" % [key, Firearm.State.keys()[w.state]])
			Input.action_release("sprint")
		await _stop(ctx, player)
	# 3. crouched: the crouch walk at the crouch's busy pace
	if not ctx.check(_place(player, "W"), "%s: a clear lane (crouched)" % key):
		return
	await FootSlip._set_crouch(ctx.tree, player, true, ctx)
	if not ctx.check(bool(player.is_crouching), "%s: crouched" % key):
		return
	_reload(w)
	await ctx.frames(2)
	_press(DIRS.W, true)
	await ctx.seconds(SETTLE_S)
	var c := await _window(ctx, player, MEASURE_S)
	var crawl := _expect(player, float(player.crouch_speed) * w.speed_mult())
	ctx.info("%s reload crouched W: crouch %.2f, target %.2f (want %.2f), body %.2f m/s; states %s" % [key, c.crouch, c.target, crawl, c.body, c.states])
	ctx.check(w.state == Firearm.State.RELOADING, "%s crouched: still reloading" % key)
	ctx.check(float(c.crouch) >= JOG_FRAC, "%s reload crouched: the crouch walk or its start (crouch mode) on %.2f of the frames" % [key, c.crouch])
	ctx.check(absf(float(c.target) - crawl) <= SPEED_TOL, "%s reload crouched: the crouch's busy pace %.2f m/s (target %.2f)" % [key, crawl, c.target])
	await _stop(ctx, player)
	if w.state == Firearm.State.RELOADING:
		w._interrupt_reload()
	await FootSlip._set_crouch(ctx.tree, player, false, ctx)
