class_name PlayerTorch
extends Node
## The torch in the off hand (push n01b; user 2026-09-25: "fix torchs in one hand, so if we have torchs then we
## need to make a one hand animation where the rifle is held sideways along the hip ... and when the user aims
## they drop the torch and the lighting from the torch").
##
## T (action "torch"; push n01c, user 2026-09-26; the keys since 2026-09-27: "tap t to open tap t to toggle torch
## higher hold t to put away torch", "double tap to cycle and then we have the hold t to cancel"): a TAP takes a torch
## from the pack, lit, or, with one in the hand, raises it beside the shoulder, the flame above the head, to light
## farther (TorchFire.raised: its range up to a fifth longer), and lowers it again to the axe hold (the raise waits
## DOUBLE_S: a second tap makes a double tap instead); HOLDING T (HOLD_S, the E key's tap / hold convention: edges from
## is_action_pressed and a was-down flag) puts the held one out and back into the pack (its burn time kept); a DOUBLE
## TAP opens the torch mode (PlayerInteractor.begin_torch_place): setting it (a ghost torch where the crosshair is,
## pushed into the ground or wedged in a wall) or, double-tapped again, throwing it (an arc to where the crosshair
## lands); a tap of T sets or throws it, a hold keeps it in the hand. The torches in the pack stack (InventoryState
## kind "torch"; the inventory's right-click on the stack takes one out or puts it away: toggle()). The hand:
## HandHolds (the right hand with a long gun, the bow or empty hands, the left with the
## pistol and the thrown weapons); with a long gun out the left hand first takes the gun in the middle, then the right
## hand brings up the torch (`pending`: it comes into the hand when HandHolds.ready_for_torch()). While it is held:
##  - PlayerAnim.torch_hand: HandHolds holds it (TorchCarryIK: the axe hold, raised on hold-T) and a long gun in the
##    left hand, gripped in the middle (GunMiddleCarryIK);
##  - aiming a long gun (RMB, or LMB to shoulder), drawing the bow, or reloading a firearm tosses it a little ahead
##    and out to the torch hand's side (PlayerAnim.play_torch_toss(): the arm swings down, torch_released lets go);
##    the aim waits for it (Weapon.aim_hold); it lands, keeps burning and lights the ground where it lies
##    (DroppedTorch); a tap of E picks it up again;
##  - the pistol and the thrown weapons keep it (one-handed; keep_with_pistol off: the pistol's aim tosses it too);
##  - the bow is held in the left hand, the torch in the right: drawing the bow (LMB / RMB) tosses the torch first;
##  - mounting a horse puts it out and packs it; a vault or climb, and death, let it fall where the hand is;
##  - it burns down (TorchState: burn_s of real time), dies in heavy rain or water, and a burnt-out stub falls.
## The light: TorchFire (no shadows by default: `shadows`, FrontierPlayer.torch_shadows; TorchFire.budget_shadows keeps
## them to one light, the held torch first).

signal changed

const ACTION := &"torch"
const KEY := KEY_T
## Seconds a toss may wait for the animation to let go before it lets go by itself.
const TOSS_TIMEOUT_S := 0.6
## How far ahead / out to the left / up (m/s, the player's frame) a toss throws the torch, on top of the hand's
## own velocity, per reason.
const TOSS_VEL := {"aim": Vector3(1.1, 1.4, 1.6), "bow": Vector3(1.1, 1.4, 1.6), "reload": Vector3(0.8, 0.8, 0.8)}
const POLL_S := 0.25
## T held this long is a hold (the raise), shorter a tap (as the E key's HOLD_S).
const HOLD_S := 0.3
## A second tap of T within this long is a double tap (the torch mode).
const DOUBLE_S := 0.3
## A thrown torch: the launch angle over the line to where it lands (deg), the farthest throw (m), the speeds tried.
const THROW_ANGLE := 30.0
const THROW_MAX := 15.0
const THROW_SPEED := Vector2(2.0, 22.0)
## The throw's path in steps of this long (s), at most this many.
const THROW_DT := 1.0 / 60.0
const THROW_STEPS := 150

var player: FrontierPlayer
## Burn seconds left of each torch in the pack (a stack; the most used one is taken first).
var pack: Array[float] = []
## The torch in the left hand (null when none).
var held: TorchState
var model: Node3D
var fire: TorchFire
var socket: Node3D
## Burn time of a fresh torch (s; FrontierPlayer.torch_burn_s).
var burn_s := TorchState.BURN_S
## The pistol keeps the torch (aimed one-handed); off: its aim tosses it like a long gun's.
var keep_with_pistol := true
## Torch lights cast shadows (at most TorchFire.MAX_SHADOWED: the held torch first). Off by default: +0.55 ms a
## frame without, +1.4 ms with (night forest, 1600x900, tests/torch/tools/torch_cost.gd), and in the forest the sun's
## tree shadow proxies (coarse cards of the cell's commonest species) blacked out the ground round the torch.
var shadows := false
## The last torch that left the hand (tests, the debug view).
var last_dropped: DroppedTorch
var _tossing := false
var _toss_reason := ""
var _toss_t := 0.0
var _was_down := false
var _down_t := 0.0
var _held_long := false
## A torch asked for (T) that waits for the hands (HandHolds.ready_for_torch(): the gun into the left hand first).
var pending := false
var _pending_state: TorchState = null
var _pending_t := 0.0
## The raise wanted (T held), read by HandHolds.
var raise_held := false
var _fire_was := false
var _aim_was := false
var _positions: Array = []     ## the torch's last grip positions [pos, t] (the release velocity)
var _t := 0.0
var _poll := 0.0
var _rain := 0.0
var _sheltered := false
var _under := false
var _draw_after := false
var _budget_t := 0.0
## Raised (a tap of T toggles it; HandHolds reads raise_held).
var raised := false
## Double tap: seconds left for a second tap of T, the first tap's raise waiting on it, the second press's release
## not a tap, and the torch mode asked for (opened once the torch is in the hand).
var _tap_wait := 0.0
var _raise_wait := false
var _swallow := false
var _place_asked := false
## The torch mode is up (PlayerInteractor: setting or throwing the torch): T is its key.
var placing := false
## Where a throw goes (throw_at()): solved again from the hand as it lets go.
var _throw_at := Vector3.INF
## The click that set or threw the torch is still held: the weapon takes no fire from it (blocks_fire()).
var hold_fire := false
## The torch put away for a traversal move (a vault, a climb), taken out again when the move is over (user
## 2026-09-26: "fix the vault for the torch equip just sling the torch or unequip and equip when the animation is
## over"; it used to fall from the hand).
var _move_stow: TorchState = null


static func install(p: FrontierPlayer, count := 4, p_burn_s := TorchState.BURN_S) -> PlayerTorch:
	var t := PlayerTorch.new()
	t.name = "Torch"
	t.player = p
	t.burn_s = p_burn_s
	for i in count:
		t.pack.append(p_burn_s)
	p.add_child(t)
	return t


static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY
	InputMap.action_add_event(ACTION, e)


func _ready() -> void:
	ensure_input()
	if player and player.anim and not player.anim.torch_released.is_connected(_on_released):
		player.anim.torch_released.connect(_on_released)
	if DisplayServer.get_name() != "headless":
		_warm_up.call_deferred()


## Frames the warm-up torch is drawn for.
const WARM_FRAMES := 4

## Compiles the torch's shaders while the level loads (user 2026-09-26: "when i press T to turn on the torch the whole
## game freezes"; measured: a 425 ms frame and a 136 ms one on the first T with a cold shader cache, none after). The
## first torch lit draws the torch model, the flame, smoke and ember materials, and the first omni light in view
## switches every visible material onto its lit-by-omni pipeline; each compiled on the spot. Here a whole lit torch is
## drawn for WARM_FRAMES frames right in front of the camera, shrunk to a speck, its light at a trace of energy and its
## crackle silent, then freed: nothing to see or hear, and the pipelines are ready when T is pressed.
func _warm_up() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return
	var m := TorchModels.build()
	m.scale = Vector3.ONE * 0.01
	var f := TorchFire.new()
	f.energy = 0.001
	(m.get_node("Flame") as Node3D).add_child(f)
	cam.add_child(m)
	m.position = Vector3(0.0, 0.0, -0.5)
	if f.crackle:
		f.crackle.volume_db = -80.0
		f.crackle.stop()
	for i in WARM_FRAMES:
		await get_tree().process_frame
	if is_instance_valid(m):
		m.queue_free()


# --- state --------------------------------------------------------------------------------------------------

## Torches in the pack.
func count() -> int:
	return pack.size()


## A torch is in the left hand (also while it is being tossed, until it leaves the hand).
func holding() -> bool:
	return held != null


func tossing() -> bool:
	return _tossing


## Adds `n` fresh torches to the pack.
func add_torches(n: int) -> void:
	for i in n:
		pack.append(burn_s)
	changed.emit()


## HUD line: the torch in the hand (burn time left) and the pack's count.
func hud_text() -> String:
	var s := ""
	if held != null:
		var left := int(ceil(held.burn_left))
		s = "Torch %d:%02d%s" % [left / 60, left % 60, "" if held.lit else " (out)"]
	if count() > 0:
		s += ("  " if s != "" else "") + "Torches x%d" % count()
	return s


# --- actions ------------------------------------------------------------------------------------------------

## T: take one out and light it, or put the held one away.
func toggle() -> void:
	if _tossing:
		return
	if pending:
		_cancel_pending()
		return
	if holding():
		if held.lit or held.burnt_out() or not _relight():
			put_away()
	else:
		take_out()


## Whether a torch can come into the hand now.
func can_take() -> bool:
	return player != null and not player.is_dead and player.riding == null and not holding() \
			and not (player.traversal != null and player.traversal.showing)


## A torch from the pack into the hand (HandHolds' choice), lit (the one with the least burn left first). With a long
## gun out it waits for the left hand to take the gun (`pending`, a short handoff) unless `now`. False when none.
func take_out(now := false) -> bool:
	if not can_take() or (pack.is_empty() and _pending_state == null):
		return false
	if _pending_state == null:
		var i := 0
		for k in pack.size():
			if pack[k] < pack[i]:
				i = k
		var left: float = pack[i]
		pack.remove_at(i)
		_pending_state = TorchState.new(burn_s)
		_pending_state.burn_left = minf(left, burn_s)
		changed.emit()
	var holds := _holds()
	if not now and player.quick != null and player.quick.active():
		player.quick.back()    # a quick throwable beside the gun in the left hand: put away first (the torch waits)
	if not now and holds != null and not holds.ready_for_torch():
		pending = true
		_pending_t = 0.0
		return true
	var s := _pending_state
	_pending_state = null
	pending = false
	s.light()
	_hold(s)
	_sfx(&"torch_ignite")
	return true


## A torch asked for is not taken after all (the torch goes back into the pack).
func _cancel_pending() -> void:
	pending = false
	if _pending_state != null:
		if not _pending_state.burnt_out():
			pack.append(_pending_state.burn_left)
		_pending_state = null
		changed.emit()


## The held torch put out and back into the pack (its burn time kept; a burnt-out one is thrown away).
func put_away() -> void:
	if not holding() or _tossing:
		return
	var s := held
	s.snuff()
	_unhold()
	if not s.burnt_out():
		pack.append(s.burn_left)
	_sfx(&"torch_snuff")
	changed.emit()


## Lets go of the torch: "aim" / "bow" / "reload" toss it (PlayerAnim's toss; it leaves the hand at
## torch_released), anything else ("fall": a vault, death, a burnt-out stub) lets it fall from the hand at once.
func drop(reason := "fall") -> void:
	if not holding() or _tossing:
		return
	var anim_ok: bool = player.anim != null and player.anim.auto_process
	if reason == "throw" and anim_ok and player.anim.play_torch_throw():
		_tossing = true
		_toss_reason = reason
		_toss_t = 0.0
		return
	if TOSS_VEL.has(reason) and anim_ok and player.anim.play_torch_toss():
		_tossing = true
		_toss_reason = reason
		_toss_t = 0.0
		return
	_toss_reason = reason
	_release()


## The held torch set down to stand at `xf` (the model's transform; PlayerInteractor's hold E: pushed upright into
## the ground, or wedged into a wall, the palisade or a tree), burning on there; a tap of E takes it up again. Null
## when there is no torch in the hand to set.
func set_down(xf: Transform3D) -> DroppedTorch:
	if not holding() or _tossing:
		return null
	var s := held
	var scene := player.get_tree().current_scene if player.get_tree() else null
	if scene == null:
		return null
	_unhold()
	var d := DroppedTorch.spawn(scene, xf, Vector3.ZERO, Vector3.ZERO, s)
	d.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	d.freeze = true
	last_dropped = d
	_sfx(&"torch_toss")
	changed.emit()
	return d


## The held torch thrown to land at `at` (the torch mode's throw): the toss's swing, and from the hand as it lets go
## the throw that carries it there (throw_velocity()); it lands and burns on where it lies (DroppedTorch).
func throw_at(at: Vector3) -> void:
	if not holding() or _tossing:
		return
	_throw_at = at
	drop("throw")


## The weapon in the hand takes no fire / aim input (Weapon._fire_input_enabled): the torch mode is up, or the click
## that set or threw the torch is still held.
func blocks_fire() -> bool:
	if hold_fire and not Input.is_action_pressed(&"fire"):
		hold_fire = false
	return placing or hold_fire


## The launch velocity that throws a torch from `from` to land at `to` (THROW_ANGLE over the line to it, the speed
## found against its fall under gravity and the torch's damping; the farthest THROW_MAX).
static func throw_velocity(from: Vector3, to: Vector3) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d := flat.length()
	if d < 0.05:
		return Vector3.UP
	var dir := flat / d
	var a := deg_to_rad(THROW_ANGLE) + atan2(to.y - from.y, d)
	a = clampf(a, deg_to_rad(10.0), deg_to_rad(70.0))
	var launch := (dir * cos(a) + Vector3.UP * sin(a)).normalized()
	var lo := THROW_SPEED.x
	var hi := THROW_SPEED.y
	for i in 18:
		var mid := (lo + hi) * 0.5
		if _throw_reach(from, launch * mid, to.y) < d:
			lo = mid
		else:
			hi = mid
	return launch * (lo + hi) * 0.5


## How far out (m, flat) a throw from `from` at `vel` is when it comes down to height `y`.
static func _throw_reach(from: Vector3, vel: Vector3, y: float) -> float:
	var p := from
	var v := vel
	var g := _gravity()
	var k := _damp()
	for i in THROW_STEPS:
		v = v * maxf(1.0 - k * THROW_DT, 0.0) + Vector3.DOWN * g * THROW_DT
		var q := p + v * THROW_DT
		if v.y < 0.0 and q.y <= y:
			var t := (p.y - y) / maxf(p.y - q.y, 1e-6)
			var at := p.lerp(q, t)
			return Vector2(at.x - from.x, at.z - from.z).length()
		p = q
	return Vector2(p.x - from.x, p.z - from.z).length()


## A throw's path from `from` at `vel`, THROW_DT apart, till it comes down below `floor_y` (for the arc drawn).
static func throw_path(from: Vector3, vel: Vector3, floor_y := -INF) -> PackedVector3Array:
	var out := PackedVector3Array([from])
	var p := from
	var v := vel
	var g := _gravity()
	var k := _damp()
	for i in THROW_STEPS:
		v = v * maxf(1.0 - k * THROW_DT, 0.0) + Vector3.DOWN * g * THROW_DT
		p += v * THROW_DT
		out.append(p)
		if v.y < 0.0 and p.y < floor_y:
			break
	return out


static func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


static func _damp() -> float:
	return DroppedTorch.LINEAR_DAMP + float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))


## Tosses the torch and then draws the weapon kept on the body (the bow: FrontierPlayer._draw_from_hands_free()).
func drop_then_draw() -> void:
	if not holding() or _tossing:
		return
	_draw_after = true
	drop("bow")


## E on a torch on the ground: into the hand (HandHolds' choice; with a long gun out the left hand takes the gun in
## the middle first), relit when it is out but not burnt out; with a torch already in the hand this one is put out
## and packed.
func take_from_ground(d: DroppedTorch) -> void:
	if d == null or not is_instance_valid(d) or d.state == null or d.state.burnt_out():
		return
	var s := d.state
	d.queue_free()
	if holding() or pending or not can_take():
		s.snuff()
		pack.append(s.burn_left)
		_sfx(&"torch_snuff")
		changed.emit()
		return
	var holds := _holds()
	if holds != null and not holds.ready_for_torch():
		_pending_state = s
		pending = true
		_pending_t = 0.0
		return
	if not s.lit:
		s.light()
	_hold(s)


# --- per frame ----------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	# T (user 2026-09-27: "tap t to open tap t to toggle torch higher hold t to put away torch", double taps for the
	# placement): a tap takes one out (lit) or, with one in the hand, raises / lowers it (after DOUBLE_S: a second tap
	# is a double tap, the placement, instead); a hold puts it away; the placement reads T itself
	var down := Input.is_action_pressed(ACTION) and not player.is_dead and _can_use_keys()
	if placing:
		_tap_wait = 0.0
		_raise_wait = false
		_swallow = false
		_held_long = down        # (a T still held as the mode goes is no hold or tap here)
	elif down and not _was_down and _tap_wait > 0.0:
		_tap_wait = 0.0
		_raise_wait = false
		_swallow = true
		_place_asked = true
	elif down and not _swallow:
		_down_t = _down_t + delta if _was_down else 0.0
		if _was_down and not _held_long and _down_t >= HOLD_S:
			_held_long = true
			if pending:
				_cancel_pending()
			elif holding():
				put_away()
			else:
				take_out()
	elif not down and _was_down:
		if _swallow:
			_swallow = false
		elif not _held_long:
			_tap_wait = DOUBLE_S
			if holding() and not _tossing:
				_raise_wait = true       # raised / lowered unless a second tap comes
			elif not pending:
				take_out()               # (at once; a second tap sets it)
		_held_long = false
	_was_down = down
	if _tap_wait > 0.0:
		_tap_wait -= delta
		if _tap_wait <= 0.0 and _raise_wait:
			_raise_wait = false
			if holding() and not _tossing:
				if held.lit or held.burnt_out() or not _relight():
					raised = not raised
	if _place_asked and holding() and not pending and not _tossing:
		_place_asked = false
		if player.interactor:
			player.interactor.begin_torch_place()
	elif _place_asked and not holding() and not pending:
		_place_asked = false
	raise_held = raised and holding()
	_step_pending(delta)
	var fire_down := Input.is_action_pressed(&"fire") if InputMap.has_action(&"fire") else false
	var aim_down := Input.is_action_pressed(&"aim") if InputMap.has_action(&"aim") else false
	var fire_edge := fire_down and not _fire_was
	var aim_edge := aim_down and not _aim_was
	_fire_was = fire_down
	_aim_was = aim_down
	if player.anim:
		player.anim.torch_hand = holding()
		if player.anim.holds:
			player.anim.holds.torch_held = holding()
			player.anim.holds.torch_pending = pending
			player.anim.holds.raise_wanted = raise_held
			player.anim.holds.throw_wanted = placing and player.interactor != null and player.interactor.torch_mode == "throw"
	_budget_t -= delta
	if _budget_t <= 0.0:
		_budget_t = POLL_S
		TorchFire.budget_shadows(get_tree(), player.camera.global_position if player.camera else player.global_position,
				TorchFire.MAX_SHADOWED if shadows else 0)
	if _move_stow != null and not (player.traversal != null and player.traversal.showing) and not holding() and not pending:
		var back := _move_stow
		_move_stow = null
		if player.is_dead or player.riding != null or back.burnt_out():
			if not back.burnt_out():
				pack.append(back.burn_left)
			changed.emit()
		else:
			_pending_state = back
			take_out()      # the usual handoff: the long gun to the left hand, the torch into the right
	if not holding():
		return
	if _tossing:
		_toss_t += delta
		if _toss_t >= TOSS_TIMEOUT_S:
			_release()
		_track(delta)
		return
	# the fire
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_S
		var fp := flame_position()
		_rain = TorchState.rain_at(get_tree(), fp)
		_sheltered = _rain > 0.0 and TorchState.sheltered(player.get_world_3d(), fp, [player.get_rid()])
		_under = TorchState.under_water(player.get_world_3d(), get_tree(), fp)
	var was_lit := held.lit
	held.tick(delta, _rain, _sheltered, _under)
	if model:
		TorchModels.set_burn(model, held.strength(), held.used())
	if fire and _holds():
		fire.raised = _holds().raise
	if was_lit and not held.lit:
		_sfx(&"torch_snuff")
		_notice("The torch burnt out." if held.burnt_out() else "The torch went out.")
	if held.burnt_out():
		drop("fall")
		return
	_track(delta)
	# what the hands do next
	if player.riding != null:
		put_away()
		return
	if player.is_dead:
		drop("fall")
		return
	if player.traversal != null and player.traversal.showing:
		# a vault or a climb: the torch is put away for the move (still lit) and taken out again after it
		var s := held
		_unhold()
		_move_stow = s
		changed.emit()
		return
	var w := player.weapon
	if w == null:
		return
	if placing or hold_fire:
		return      # (the torch mode's clicks are its own)
	if w is Bow:
		# the bow in the left hand, the torch in the right: drawing the string tosses the torch first (the draw waits:
		# Weapon.aim_hold)
		if w.active and not player.hands_free and not player.is_switching() and (fire_edge or aim_edge) \
				and not player.is_dead and _can_use_keys():
			drop("bow")
		elif player.hands_free and (fire_edge or aim_edge) and not player.is_dead and _can_use_keys():
			drop_then_draw()
		return
	if not w.active or player.hands_free:
		return
	if w is Firearm and (w as Firearm).state == Firearm.State.RELOADING:
		drop("reload")
	elif w is Musket and w.wants_aim():
		drop("aim")
	elif w is FlintlockPistol and not keep_with_pistol and w.wants_aim():
		drop("aim")


## Where the flame is (world).
func flame_position() -> Vector3:
	var f := model.get_node_or_null("Flame") as Node3D if model else null
	return f.global_position if f else player.global_position + Vector3.UP * 1.8


## Whether the weapon in the hand can be taken out with the torch held: every one can since push n01c (the torch
## goes to the hand the weapon does not need; the bow in the left hand, the torch in the right).
func blocks(_w: Weapon) -> bool:
	return false


func _can_use_keys() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.ignore_mouse_capture or PadInput.active


# --- internals ----------------------------------------------------------------------------------------------

func _hold(s: TorchState) -> void:
	held = s
	_tossing = false
	_positions.clear()
	# the torch's node on the skeleton: TorchCarryIK places it in the fist holding it every frame (either hand, and
	# from one to the other through a pass); the model's grip at its origin, the head up its +Y
	socket = player.skeleton.get_node_or_null("torch_socket") as Node3D
	if socket == null or socket is BoneAttachment3D:
		socket = Node3D.new()
		socket.name = "torch_socket"
		player.skeleton.add_child(socket)
	model = TorchModels.build()
	socket.add_child(model)
	var holds := _holds()
	if player.anim and player.anim.torch_ik:
		var ik := player.anim.torch_ik
		ik.socket = socket
		if holds != null and not ik.passing() and ik.torch_weight <= 0.0:
			ik.side = holds.take_side()
		ik.upright = 1.0
		_place_now(ik)
	fire = TorchFire.new()
	fire.state = s
	fire.held = true
	(model.get_node("Flame") as Node3D).add_child(fire)
	TorchModels.set_burn(model, s.strength(), s.used())
	if player.anim:
		player.anim.torch_hand = true
	changed.emit()


func _unhold() -> void:
	held = null
	raised = false
	_tossing = false
	if model and is_instance_valid(model):
		model.queue_free()
	model = null
	fire = null
	if player.anim:
		player.anim.torch_hand = false


func _on_released() -> void:
	if _tossing:
		_release()


## The torch leaves the hand where it is now, with the hand's velocity and the toss's push.
func _release() -> void:
	if not holding():
		return
	var s := held
	var xf := model.global_transform if model and model.is_inside_tree() else player.global_transform
	# a toss: the body's own velocity and the push (the toss swings the hand down, a flick; its velocity at the
	# end of the swing points down and back); a fall: the hand's velocity
	var push: Vector3 = TOSS_VEL.get(_toss_reason, Vector3.ZERO)
	var vel := _hand_velocity() if push == Vector3.ZERO else player.velocity
	if _toss_reason == "throw" and _throw_at != Vector3.INF:
		vel = throw_velocity(xf.origin, _throw_at)     # (solved again from where the hand lets go)
		_throw_at = Vector3.INF
	var b := player.global_basis
	# the player faces -Z; push is (x out to the torch hand's side, y up, z ahead)
	var out := -b.x if _toss_side() == "l" else b.x
	vel += out * push.x + Vector3.UP * push.y + -b.z * push.z
	var spin := b.x * (5.0 if push != Vector3.ZERO or _toss_reason == "throw" else 1.5) + Vector3.UP * randf_range(-1.0, 1.0)
	var scene := player.get_tree().current_scene if player.get_tree() else null
	_unhold()
	if scene:
		last_dropped = DroppedTorch.spawn(scene, xf.orthonormalized(), vel, spin, s)
		if _toss_reason == "throw":
			last_dropped.mark_thrown(player)
	_sfx(&"torch_toss")
	var draw := _draw_after
	_draw_after = false
	changed.emit()
	if draw and player.hands_free and player.weapon is Bow and player.is_usable(player.weapon_key):
		player._draw_from_hands_free()


## The hands' planner (null before the animation is set up).
func _holds() -> HandHolds:
	return player.anim.holds if player and player.anim else null


## The hand tossing (or holding) the torch.
func _toss_side() -> String:
	var h := _holds()
	if h == null:
		return "l"
	return h.toss_side if h.toss_t >= 0.0 else h.torch_side()


## A torch asked for comes into the hand once HandHolds is ready (the gun in the left hand); it gives up after
## PENDING_MAX_S or when the player aims, dies, rides or climbs meanwhile.
const PENDING_MAX_S := 1.5


func _step_pending(delta: float) -> void:
	if not pending:
		return
	_pending_t += delta
	var h := _holds()
	var w := player.weapon
	var aim := w != null and w.active and w.wants_aim()
	if not can_take() or aim or _pending_t > PENDING_MAX_S or h == null:
		_cancel_pending()
		return
	if h.ready_for_torch():
		take_out(true)


## Puts the model at its hand's grip at once (the first frame, before the IK has placed it).
func _place_now(ik: TorchCarryIK) -> void:
	var sk := player.skeleton
	var b := sk.find_bone(ik.side + "_hand_prop_attachment")
	if b >= 0 and socket:
		socket.transform = sk.get_bone_global_pose(b) * TorchCarryIK.HAND_OFFSET


func _track(_delta: float) -> void:
	if model == null or not model.is_inside_tree():
		return
	_positions.append([model.global_position, _t])
	while _positions.size() > 4:
		_positions.pop_front()


func _hand_velocity() -> Vector3:
	if _positions.size() < 2:
		return player.velocity
	var a: Array = _positions[0]
	var b: Array = _positions[_positions.size() - 1]
	var dt := float(b[1]) - float(a[1])
	return ((b[0] as Vector3) - (a[0] as Vector3)) / dt if dt > 1e-4 else player.velocity


## A torch in the hand that went out (rain, water) lights again unless it is still under water or in the rain.
func _relight() -> bool:
	if held == null or held.lit or held.burnt_out() or _under or (_rain >= TorchState.RAIN_HEAVY and not _sheltered):
		return false
	held.light()
	_sfx(&"torch_ignite")
	return true


func _notice(text: String) -> void:
	if player.interactor and player.interactor.has_method("notice"):
		player.interactor.notice(text)


func _sfx(id: StringName) -> void:
	if not Sfx.config(id).is_empty() and Sfx.has(id):
		Sfx.play_3d(id, flame_position() if model else player.global_position + Vector3.UP * 1.2)
