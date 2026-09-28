class_name HandHolds
extends RefCounted
## Which hand holds what (push n01c; user 2026-09-26: "we should switch it then the right hand holds the torch and the
## left hand holds the gun which makes it looks better allows us to do the one hand middle hold", "yes i want the
## middle grip on the crouch walk as well", "allows user to have the right hand to throwables and easily switch back
## to rifle"). PlayerAnim asks it every step, before the arm modifiers run.
##
## The torch goes in the hand the weapon does not need (wanted_side()):
##   long gun (musket, over-under), bow, hands free, no weapon: the RIGHT hand (a long gun in the LEFT hand, gripped in
##   the middle: GunMiddleCarryIK; the bow in the left hand as always);
##   pistol, tomahawk, spear, atlatl: the LEFT hand (the weapon in the right);
##   during a weapon switch: the hand the holster or the draw does not use (the left, the bow's the right).
## When the wanted hand changes the torch changes hands:
##   - a pass (TorchCarryIK.pass_to(): the fists meet in front of the belly, PASS_S);
##   - with the long gun in the left hand, an exchange through the left fist: going OUT (a switch away from the long
##     gun, H) the right fist brings the torch to the left fist, which holds both for a moment, then the right hand
##     takes the wrist of the stock and the left hand keeps the torch; coming IN (a long gun drawn with the torch in
##     the left hand) the reverse. player.gd waits for the hands (ready_for_switch()) before a switch or H starts.
## The torch's holds (TorchCarryIK): the axe hold by default (the tomahawk's carry arm, the fist beside the hip, the
## torch angled a little forward and out, flame up), raised while T is held (`raise_wanted`, PlayerTorch: the source's
## one-hand throw raise, the fist beside the shoulder, the flame above the head), the toss (aiming a long gun, drawing
## the bow, reloading: the torch hand swings down, torch_released lets go; PlayerTorch drops it).
## The long gun in the left hand, gripped in the middle (mid_wanted()): with a torch in the right hand (or one on its
## way: `torch_pending`), in the crouch-walk one-hand hold (PlayerAnim.one_hand), and with a one-hand throwable in the
## right hand (`offhand`, FrontierPlayer.offhand_key: the quick throwables).
## The aim waits for the hands (Weapon.aim_hold): while the torch is being tossed or the gun is not yet back in the
## right hand.

## The axe hold's arm: the tomahawk's one-hand carry (THROW2 carry_overrides tomahawk rows: the machete carry arm
## actor_b-p-knife--arm under the knife ready arm, over the locomotion's own swing), [clip, weight, sample s]; the
## weights blend with the locomotion's swing (axe_swing) so the arm hangs lower than the tomahawk's (the user's "arm
## hangs relaxed at the side"); TorchCarryIK places the fist.
const AXE_HOLD := {"stand": [["actor_b-p-knife--arm", 0.3, 0.0], ["atk-actor_b-knife-v-thug-hit1-intro", 0.25, 0.0]],
		"crouch": [["actor_b-p-knife--arm", 0.3, 0.0], ["atk-actor_b-knife-v-thug-hit1-intro", 0.2, 0.0],
			["actor_b-p-melee-tell-idle--arms", 0.15, 0.0]]}
## How much of the locomotion's own arm swing the axe hold keeps (PlayerAnim.torch_arm_swing).
var axe_swing := 0.45
## The raised hold's arm (user 2026-09-26: "raised torch moves behind instead of in front"; the throw raise it used
## cocks the arm back behind the head): the source's flashlight held up and forward, a left arm (mirrored for the right
## hand), [clip, weight]; TorchCarryIK places the fist in front of the shoulder.
const RAISE_HOLD := [["actor_b-fist-caut-flashlight-up-fw--part", 0.8], ["actor_b-fist-caut-flashlight--fw--part", 0.2]]
## The toss: the source's lowered flashlight arm (a left arm: mirrored for the right hand).
const TOSS_CLIP := "actor_b-fist-ambi-flashlight-down-fw--part"
## The torch mode's throw (user 2026-09-27: "i was hoping torch had the throwing animation", in either hand): the
## source's one-hand throw, the tomahawk's (a right arm: mirrored for the left hand). While the mode throws
## (`throw_wanted`) the arm winds up into THROW_AIM over THROW_WIND_S; the throw (play_throw()) plays THROW_RELEASE
## through (release-start, then release-end: the follow-through), the torch let go at THROW_RELEASE_AT, the hand at
## its fastest (Throwable.RELEASE_PHASE of the chain); torch_released there.
const THROW_AIM := {"stand": "actor_b-p-1h-aim-throw-idle", "crouch": "actor_b-p-1h-aim-crouch-throw-idle"}
const THROW_RELEASE := {"stand": ["actor_b-p-1h-aim-throw-release-start", "actor_b-p-1h-aim-throw-release-end"],
		"crouch": ["actor_b-p-1h-aim-crouch-throw-release-start", "actor_b-p-1h-aim-crouch-throw-release-end"]}
const THROW_WIND_S := 0.22
const THROW_RELEASE_AT := Throwable.THROW_CHAIN_LEN * Throwable.RELEASE_PHASE
## The long gun's arm in the left hand: the source's one-hand rifle arms, mirrored from the right: standing the
## one-hand hold at the hip (actor_b-rifle-idle-no-aim--part), crouch-moving the one-hand crouch-move hold
## (actor_b-p-rifle-cover-low-left-fw--arms, at the stride's phase). The fist: GunMiddleCarryIK.GRIPS (its grip).
const GUN_ARM_STAND := "actor_b-rifle-idle-no-aim--part"
const GUN_ARM_CROUCH := PlayerAnim.ONE_HAND_LOW_ARM
## Seconds for hold-T's raise and lower.
const RAISE_S := 0.28
## Seconds for the gun in the left hand to move out and up off the knees when a jump takes off (and back on landing).
const AIR_S := 0.16
## Seconds a handoff takes when nothing hurries it (the crouch-walk one-hand hold coming on and going).
const RELAXED_HANDOFF_S := 0.5
## Seconds the handoff back to the right hand takes when a jump takes off (every rifle jump is two-handed).
const TAKEOFF_HANDOFF_S := 0.15
## The aim may start once the gun's handoff back to the right hand is below this (the right hand has the stock).
const AIM_READY_PROGRESS := 0.45

var pa: PlayerAnim
var torch_ik: TorchCarryIK
var mid_ik: GunMiddleCarryIK

## Set by PlayerTorch every tick: a torch in a hand, one asked for (T) that waits for the hands, T held (raise).
var torch_held := false
var torch_pending := false
var raise_wanted := false
## The long gun held in the left hand while a one-hand throwable is out (FrontierPlayer.offhand_key's weapon).
var offhand: Weapon = null
## Seconds the handoff stays quick (QuickOffhand's way back: the gun to the right hand ready to aim).
var hurry_t := 0.0
## A weapon switch or H waits for the hands (FrontierPlayer sets it while it polls ready_for_switch()): the torch goes
## to the hand the switch leaves free, the gun back to the right hand. `pending_key`: the weapon to draw ("" for H).
var pending := false
var pending_key := ""

## "" / "out" (the torch into the left gun fist, then the gun back to the right hand) / "in" (the gun into the left
## fist beside the torch, then the torch to the right hand), and its step.
var exchange := ""
var exchange_step := 0
## Seconds into the torch toss (-1: none), the hand tossing, and whether it has let go.
var toss_t := -1.0
var toss_side := "l"
var toss_released := false
## The torch mode is throwing (PlayerTorch sets it): the arm wound up (`windup`, eased 0..1); seconds into the throw
## (-1: none), the hand throwing, whether it has let go.
var throw_wanted := false
var windup := 0.0
var throw_t := -1.0
var throw_side := "r"
var throw_released := false
## Eased hold-T raise 0..1, the torch hand's left gun-fist weight (TorchCarryIK.gun_fist), the crouch.
var raise := 0.0
var _crouch := 0.0
var _gun_fist_w := 0.0
var _low_phase := 0.0
var _mid_gun: Weapon = null


func _init(p_pa: PlayerAnim, p_torch: TorchCarryIK, p_mid: GunMiddleCarryIK) -> void:
	pa = p_pa
	torch_ik = p_torch
	mid_ik = p_mid


# --- decisions ----------------------------------------------------------------------------------------------

## The hand the torch belongs in now (see the header).
func wanted_side() -> String:
	var p := pa.player
	if pending:
		return _switch_side(pending_key)
	if p != null and p.is_switching():
		# the holster and the draw are the right hand's (the bow's the left's)
		var st := p.switch_stage()
		var k := String(p._sw.get("old_key", "")) if st == "holster" else String(p._sw.get("key", ""))
		return "r" if k == "bow" else "l"
	var w := String(pa._weapon)
	if pa.hands_free or w == "":
		return "r"
	if p != null and p.weapon != null and p.weapon.is_equipping():
		return "r" if w == "bow" else "l"
	return "r" if w in ["musket", "bow"] else "l"


## The long gun wanted in the left hand, gripped in the middle.
func mid_wanted(ctx: Dictionary) -> bool:
	if offhand != null:
		return true
	if pending and exchange == "":
		return false
	if not bool(ctx.long_gun):
		return false
	if toss_t >= 0.0 and toss_side == "r":
		return true     # the right hand is tossing the torch: the gun stays in the left until its arm is back
	if exchange == "out":
		return exchange_step < 2
	if exchange == "in":
		return true
	if not bool(ctx.gun_free):
		return false
	if bool(ctx.one_hand):
		return true
	var torch := torch_held or torch_pending
	if not torch:
		return false
	# every rifle jump is two-handed, except with the torch: the gun stays in the left hand
	return torch_ik.side == "r" or torch_pending or torch_ik.passing()


## The hands are arranged for a weapon switch or H to start: the torch (if any) in the left hand (the right hand
## holsters and draws; the bow's hand is the left, so the torch goes right for it: `key`), no pass or exchange running,
## the gun not in the left hand. PlayerAnim / player.gd poll it; it starts what is needed.
func ready_for_switch(key := "") -> bool:
	if not torch_held:
		return mid_ik.progress <= 0.0 or offhand != null
	return torch_ik.side == _switch_side(key) and not torch_ik.passing() and exchange == "" and mid_ik.progress <= 0.0


## The torch's hand while a switch to `key` ("" = H) holsters: the left (the right hand holsters), the right when the
## bow (a left-hand weapon) is put away or drawn.
func _switch_side(key: String) -> String:
	return "r" if key == "bow" or String(pa._weapon) == "bow" else "l"


## A torch may come into the hand now (T pressed): the gun already in the left hand when a long gun is out; not while
## a quick throwable is out beside the gun (QuickOffhand takes the gun back first) or a switch runs.
func ready_for_torch() -> bool:
	if offhand != null or (pa.player != null and pa.player.is_switching()):
		return false
	var long_gun := String(pa._weapon) in PlayerAnim.LEFT_GRIP_WEAPONS
	if long_gun and not pa.hands_free:
		return mid_ik.in_left()
	return true


## The hand a torch taken out now goes to.
func take_side() -> String:
	return wanted_side()


## The hand the torch is in (or going to).
func torch_side() -> String:
	return torch_ik.side


# --- per step -------------------------------------------------------------------------------------------------

## Decides the holds for this step and poses the arms it owns. ctx: long_gun, gun_free, busy, aiming, one_hand,
## airborne, crouch (bool), moving. Returns {"l": owned, "r": owned} (PlayerAnim leaves those arms alone).
func step(dt: float, ctx: Dictionary) -> Dictionary:
	var crouch := bool(ctx.crouch)
	_crouch = move_toward(_crouch, 1.0 if crouch else 0.0, dt / PlayerAnim.STANCE_ARM_XFADE_S)
	var torch := torch_held or toss_t >= 0.0
	# the torch's hand
	if torch_held and toss_t < 0.0 and not torch_ik.passing() and exchange == "":
		var want := wanted_side()
		if want != torch_ik.side:
			if torch_ik.side == "r" and mid_ik.progress > 0.0:
				exchange = "out"
				exchange_step = 0
			elif torch_ik.side == "l" and want == "r" and bool(ctx.long_gun) and bool(ctx.gun_free):
				exchange = "in"
				exchange_step = 0
			else:
				torch_ik.gun_fist = false
				torch_ik.pass_to(want)
	_step_exchange(dt)
	# the long gun in the left hand
	var mid := mid_wanted(ctx)
	if bool(ctx.airborne) and not torch and offhand == null:
		mid = false
	mid_ik.on = mid
	# the handoff's pace: quick for a jump's take-off, the aim, the torch and the quick throwables; unhurried when the
	# crouch-walk one-hand hold comes on or goes by itself (the gun swings 0.5 m and turns: 0.3 s read as a snap)
	var wpn: Weapon = pa.player.weapon if pa.player != null else null
	var aim_wanted := wpn != null and wpn.active and wpn.wants_aim()
	hurry_t = maxf(hurry_t - dt, 0.0)
	var calm := not torch_held and not torch_pending and toss_t < 0.0 and offhand == null and not aim_wanted \
			and not pending and hurry_t <= 0.0
	if bool(ctx.airborne) and not mid:
		mid_ik.handoff_s = TAKEOFF_HANDOFF_S
	else:
		mid_ik.handoff_s = RELAXED_HANDOFF_S if calm else GunMiddleCarryIK.HANDOFF_S
	var gun_model := _mid_model()
	if gun_model != mid_ik.gun:
		if mid_ik.gun != null and is_instance_valid(mid_ik.gun) and mid_ik.progress > 0.0:
			pass    # keep the one in the hand until the handoff is back
		else:
			mid_ik.gun = gun_model
			if _mid_gun != null and _mid_gun.model != null:
				mid_ik.gun_offset = _gun_offset(_mid_gun)
				mid_ik.gun_kind = "over_under" if _mid_gun is OverUnderMusket else "musket"
	mid_ik.crouch = smoothstep(0.0, 1.0, _crouch)
	mid_ik.air = move_toward(mid_ik.air, 1.0 if bool(ctx.airborne) else 0.0, dt / AIR_S)
	mid_ik.exchange = move_toward(mid_ik.exchange, 1.0 if exchange != "" else 0.0, dt / 0.25)
	mid_ik.advance(dt)
	# the torch
	raise = move_toward(raise, 1.0 if raise_wanted and torch_held and toss_t < 0.0 and not torch_ik.passing() \
			and exchange == "" else 0.0, dt / RAISE_S)
	torch_ik.raise = smoothstep(0.0, 1.0, raise)
	torch_ik.crouch = smoothstep(0.0, 1.0, _crouch)
	torch_ik.torch_on = torch_held and not toss_released
	torch_ik.gun_fist = _gun_fist_w > 0.5
	for s: String in ["l", "r"]:
		torch_ik.hand_in[s] = move_toward(float(torch_ik.hand_in[s]), 1.0, dt / 0.2)
	var owned := {"l": false, "r": false}
	if torch:
		_torch_arms(dt, owned)
	# the gun arm (left) while the gun is in the left hand or on its way
	if (mid_ik.progress > 0.0 or mid) and not owned.l:
		_gun_arm(dt, ctx)
		owned.l = true
	# the right arm with the gun in the left hand and no torch there: free (the crouch-walk one-hand hold, the
	# exchange's end); the quick throwables keep the throwable's own right arm (PlayerAnim's)
	if not owned.r and (mid or mid_ik.progress > 0.0) and offhand == null and not torch:
		pa.right_arm.enabled = mid_ik.progress >= 0.5
		pa.right_arm.fade_s = LeftArmPose.FADE_S
		pa.right_arm.set_sources("free", pa._relax_sources())
		pa.right_arm.advance(dt)
		owned.r = true
	# the aim waits for the hands
	var w := pa.player.weapon if pa.player != null else null
	if w != null:
		var hold := (toss_t >= 0.0 and not toss_released) or (bool(ctx.long_gun) and mid_ik.progress > AIM_READY_PROGRESS)
		# the bow's string hand holds the torch: the draw waits for the toss (PlayerTorch tosses on the press)
		if w is Bow and torch_held and torch_ik.side == "r":
			hold = true
		w.aim_hold = hold
	torch_ik.advance(dt)
	return owned


## The gun model the left hand holds: the long gun out (or the quick throwables' one).
func _mid_model() -> Node3D:
	var w: Weapon = offhand
	if w == null and pa.player != null and String(pa._weapon) in PlayerAnim.LEFT_GRIP_WEAPONS:
		w = pa.player.weapon
	_mid_gun = w
	return w.model if w != null else null


static func _gun_offset(w: Weapon) -> Transform3D:
	var p := w.player
	if p != null and "musket_offset" in p:
		return p.musket_offset
	return Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)


## The exchange's steps (see the header).
func _step_exchange(dt: float) -> void:
	if exchange == "":
		_gun_fist_w = move_toward(_gun_fist_w, 0.0, dt / 0.2)
		return
	if not torch_held:
		exchange = ""
		return
	if exchange == "out":
		match exchange_step:
			0:
				# wait for the left fist to come in, then the right fist brings the torch to it
				_gun_fist_w = 1.0
				if mid_ik.exchange >= 0.8:
					torch_ik.gun_fist = true
					torch_ik.pass_to("l")
					exchange_step = 1
			1:
				if not torch_ik.passing():
					exchange_step = 2     # mid_wanted() lets the gun go back to the right hand
			2:
				# the left hand lets go of the gun and keeps the torch: its torch hold comes in from here
				if mid_ik.progress <= 0.35 and _gun_fist_w > 0.0:
					torch_ik.restart_hand("l")
					_gun_fist_w = 0.0
					torch_ik.gun_fist = false
				if mid_ik.progress <= 0.0:
					exchange = ""
	elif exchange == "in":
		match exchange_step:
			0:
				# the left hand (with the torch) closes on the gun's middle; the right hand lets go of the stock
				_gun_fist_w = move_toward(_gun_fist_w, 1.0, dt / 0.2)
				if mid_ik.in_left() and mid_ik.exchange >= 0.8:
					torch_ik.gun_fist = true
					torch_ik.pass_to("r")
					exchange_step = 1
			1:
				if not torch_ik.passing():
					_gun_fist_w = 0.0
					torch_ik.gun_fist = false
					exchange = ""


## The torch arm(s): the hold of the torch's hand (axe / raised), both arms through a pass, the toss.
func _torch_arms(dt: float, owned: Dictionary) -> void:
	var sides: Array = [torch_ik.side]
	if torch_ik.passing():
		sides.append(torch_ik.pass_from)
	for s: String in sides:
		if s == "l" and torch_ik.gun_fist:
			continue    # the left fist holds the gun too: GunMiddleCarryIK's arm
		var arm: LeftArmPose = pa.left_arm if s == "l" else pa.right_arm
		var mirror := s == "l"
		var st := "crouch" if _crouch >= 0.5 else "stand"
		var hold := _hold_sources(st, mirror)
		var grip := pa._clip_sources(TorchCarryIK.GRIP_CLIP)
		for src: Dictionary in grip:
			src.part = "hand"
			src.mirror = mirror
			src.w = 1.0
		if throw_t >= 0.0 and s == throw_side:
			_throw_arm(dt, arm, grip, mirror, st)
		elif toss_t >= 0.0 and s == toss_side:
			_toss_arm(dt, arm, hold, grip, mirror)
		else:
			# wound up while the torch mode throws: the throw's cocked arm over the hold, the fist the clip's
			windup = move_toward(windup, 1.0 if throw_wanted and s == torch_ik.side and not torch_ik.passing() else 0.0,
					dt / THROW_WIND_S)
			var w := smoothstep(0.0, 1.0, windup)
			if w > 0.0:
				for src: Dictionary in hold:
					src.w = float(src.w) * maxf(1.0 - w, 0.001)
				for src: Dictionary in pa._clip_sources(String(THROW_AIM[st])):
					src.w = w * 2.0
					src.mirror = mirror
					src.part = "arm"
					hold.append(src)
			if s == torch_ik.side:
				torch_ik.upright = 1.0 - w
			arm.enabled = true
			arm.fade_s = LeftArmPose.FADE_S
			arm.set_sources("torch_%s_%s" % [st, s], hold + grip, PlayerAnim.STANCE_ARM_XFADE_S)
		arm.advance(dt)
		owned[s] = true
	if throw_t >= 0.0 and throw_side not in sides:
		# the torch has left the hand: the throwing arm follows through, then fades back
		var arm3: LeftArmPose = pa.left_arm if throw_side == "l" else pa.right_arm
		_throw_arm(dt, arm3, [], throw_side == "l", "crouch" if _crouch >= 0.5 else "stand")
		arm3.advance(dt)
		owned[throw_side] = true
	if toss_t >= 0.0 and toss_side not in sides:
		# the torch has left the hand: the tossing arm fades back (below)
		var arm2: LeftArmPose = pa.left_arm if toss_side == "l" else pa.right_arm
		_toss_arm(dt, arm2, [], [], toss_side == "l")
		arm2.advance(dt)
		owned[toss_side] = true


## The hold's arm sources for stance `st`: the axe hold over the locomotion's swing, blended into the raised hold.
func _hold_sources(st: String, mirror: bool) -> Array:
	var out: Array = []
	var r := smoothstep(0.0, 1.0, raise)
	for e: Array in AXE_HOLD[st]:
		for src: Dictionary in pa._clip_sources(String(e[0])):
			src.time = float(e[2])
			src.w = float(e[1]) * (1.0 - r) + 1e-4
			src.part = "arm"
			src.mirror = mirror
			out.append(src)
	for src: Dictionary in pa._relax_sources():
		src.w = float(src.w) * axe_swing * (1.0 - r) + 1e-4
		src.part = "arm"
		out.append(src)
	if r > 0.0:
		for e: Array in RAISE_HOLD:
			for src: Dictionary in pa._clip_sources(String(e[0])):
				src.w = r * 1.5 * float(e[1])
				src.part = "arm"
				src.mirror = not mirror     # the flashlight clips are a left arm
				out.append(src)
	return out


## The toss: the hold swung into TOSS_CLIP over the release time, torch_released there, then the arm fades back to
## the pose underneath.
func _toss_arm(dt: float, arm: LeftArmPose, hold: Array, grip: Array, mirror: bool) -> void:
	toss_t += dt
	var rel := pa.torch_toss_release_s
	var u := smoothstep(0.0, 1.0, clampf(toss_t / maxf(rel, 0.01), 0.0, 1.0))
	var toss: Array = []
	for src: Dictionary in hold:
		src.w = float(src.w) * maxf(1.0 - u, 0.001)
		toss.append(src)
	for src: Dictionary in pa._clip_sources(TOSS_CLIP):
		src.w = maxf(u, 0.001) * 2.0
		src.mirror = not mirror     # TOSS_CLIP is a left arm
		src.part = "arm"
		toss.append(src)
	if not toss_released:
		arm.enabled = true
		arm.fade_s = LeftArmPose.FADE_S
		arm.set_sources("torch_toss", toss + grip, 0.05)
		torch_ik.upright = 1.0 - u
	if not toss_released and toss_t >= rel:
		toss_released = true
		pa.torch_released.emit()
	if toss_released:
		# let go: the arm back to what is underneath (the aim, the reload, the draw)
		arm.enabled = false
		arm.fade_s = 0.14
		torch_ik.torch_on = false
		torch_ik.fade_s = 0.1
		if arm.weight <= 0.0:
			toss_t = -1.0
			toss_released = false
			torch_ik.fade_s = TorchCarryIK.FADE_S
			torch_ik.upright = 1.0


## The throw: THROW_RELEASE played through from the wound-up arm, the torch let go at THROW_RELEASE_AT
## (torch_released), the follow-through, then the arm back to what is underneath.
func _throw_arm(dt: float, arm: LeftArmPose, grip: Array, mirror: bool, st: String) -> void:
	throw_t += dt
	var clips: Array = THROW_RELEASE[st]
	var a0 := pa._clip_sources(String(clips[0]))
	var a1 := pa._clip_sources(String(clips[1]))
	var l0: float = (a0[0].anim as Animation).length if not a0.is_empty() else 0.2
	var l1: float = (a1[0].anim as Animation).length if not a1.is_empty() else 0.6
	var srcs: Array = a0 if throw_t < l0 else a1
	for src: Dictionary in srcs:
		src.time = throw_t if throw_t < l0 else minf(throw_t - l0, l1)
		src.w = 2.0
		src.mirror = mirror
		src.part = "arm"
	if throw_t < l0 + l1:
		arm.enabled = true
		arm.fade_s = LeftArmPose.FADE_S
		arm.set_sources("torch_throw", srcs + (grip if not throw_released else []), 0.04)
		torch_ik.upright = 0.0
	if not throw_released and throw_t >= THROW_RELEASE_AT:
		throw_released = true
		windup = 0.0
		pa.torch_released.emit()
	if throw_released:
		torch_ik.torch_on = false
		torch_ik.fade_s = 0.1
	if throw_t >= l0 + l1:
		arm.enabled = false
		arm.fade_s = 0.2
		if arm.weight <= 0.0:
			throw_t = -1.0
			throw_released = false
			torch_ik.fade_s = TorchCarryIK.FADE_S
			torch_ik.upright = 1.0


## Starts the throw of the torch hand (the torch mode's). False when no torch is in a hand, or a toss or throw runs.
func play_throw() -> bool:
	if not torch_held or toss_t >= 0.0 or throw_t >= 0.0:
		return false
	throw_t = 0.0
	throw_released = false
	throw_side = torch_ik.side
	exchange = ""
	return true


## Starts the toss of the torch hand. False when no torch is in a hand or a toss is running.
func play_toss() -> bool:
	if not torch_held or toss_t >= 0.0:
		return false
	toss_t = 0.0
	toss_released = false
	toss_side = torch_ik.side
	exchange = ""
	return true


## The left arm holding the long gun: the source's one-hand rifle arm mirrored (standing the hip hold, crouch-moving
## the low hold at the stride's phase), the fingers of the grip in use (GunMiddleCarryIK.grip_info()).
func _gun_arm(dt: float, ctx: Dictionary) -> void:
	var arm := pa.left_arm
	var crouch := _crouch >= 0.5
	var clip := GUN_ARM_CROUCH if crouch else GUN_ARM_STAND
	if bool(ctx.moving):
		_low_phase = pa.loco.phase()
	var srcs := pa._clip_sources(clip, _low_phase if crouch else 0.0)
	for src: Dictionary in srcs:
		src.mirror = true
		src.part = "arm"
	var gi := mid_ik.grip_info()
	var grip := pa._clip_sources(String(gi.clip))
	for src: Dictionary in grip:
		src.part = "hand"
		src.mirror = bool(gi.mirror)
	# in with the handoff (the left hand closes on the gun over its first third), out as it lets go
	arm.enabled = mid_ik.on or mid_ik.progress > 0.35
	arm.fade_s = GunMiddleCarryIK.HANDOFF_S * 0.5
	arm.set_sources("gun_mid_" + ("crouch" if crouch else "stand"), srcs + grip, PlayerAnim.STANCE_ARM_XFADE_S)
	arm.advance(dt)


## The quick throwables' gun leaves the left hand for the back at once (QuickOffhand.drop()).
func drop_offhand() -> void:
	offhand = null
	mid_ik.on = false
	mid_ik.snap()


## Takes the wanted weights at once (back from a traversal move or the saddle).
func snap() -> void:
	mid_ik.snap()
	torch_ik.snap()
	exchange = ""
	_gun_fist_w = 0.0
