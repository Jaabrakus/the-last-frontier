class_name PlayerTraversal
extends TravPreviewActor
## Vaulting and climbing on the player (user 2026-09-25: "we need the climb animations in the game"): the
## TraversalController measures the world and plays the Actor_B moves authored for each obstacle
## (graph_analysis/traversal/READY_FOR_INTEGRATION.md); this node shows them on the player's own skeleton with
## the seam rules of TravPreviewActor (its fade stack, root and pose inertialization, TraversalIK plants).
##
## While a move plays it owns the pose: PlayerAnim is suspended (auto_process off) and its modifiers are off;
## the character rig follows the move's root. When the controller hands the body back, PlayerAnim resumes and
## the pose change is inertialized (TravInertializer), the rig returns to the player's own placement over
## RIG_RETURN_S. The weapon in the hands goes onto the body for the move and is drawn again after it.
##
## Momentum (user 2026-09-26: "also when we vault the char model should not slow down", then "some things are
## fast somethings are slow it should just be normal speed"; TravMomentum): a vault keeps the speed it is entered
## with at one steady tempo; the rendered root starts the move moving as the body moved (it started from rest, a
## stop of the model in the first frames), the rig's return after it is an offset that decays in the body's frame
## (it was eased from where the move left it in the world: the model stood still while the body ran on), and the
## locomotion goes on in the step of the move's last pose (or of the foot it hands back on).
##
## Only the moves that pass the strict test are offered: the player's own copy of the move table has
## DISABLED_MOVES switched off (enabled: false; the data is kept).

## Families not offered yet (READY_FOR_INTEGRATION.md: planted feet off the ground, head into the wall, coat into
## the rock).
const DISABLED_MOVES := ["gap_jump", "long_jump", "shimmy_enter", "shimmy_idle", "shimmy_start", "shimmy_loop",
		"shimmy_stop", "shimmy_exit", "squeeze"]
## Moves offered on overhead lips only (their overhead_band: a platform's edge over open ground, the fort's
## firing step), not on walls: the hang climb's forearm went 14 cm into a 3 m wall (READY_FOR_INTEGRATION.md).
const OVERHEAD_ONLY_MOVES := ["climb_hang_3m", "climb_hang_3m_idle"]
const EXIT_INERT_S := 0.3
const RIG_RETURN_S := 0.25

var player: FrontierPlayer
var controller: TraversalController
var world_ready := false
## A move (or its exit) is on the skeleton now.
var showing := false
var _rig_local: Transform3D
var _rig_back := -1.0                ## seconds into the rig's return to the player (-1: not returning)
var _rig_off: Transform3D            ## the rig's offset from its own placement at the hand-back (the body's frame)
var _rig_last: Transform3D           ## where the rig was shown last tick (a move's root starts from there)
var _rig_ret_s := RIG_RETURN_S       ## this return's length
var _momentum := false               ## the move playing keeps the body's speed (TravMomentum)
var _rig_seen := false
var _gun_away := ""                  ## the weapon put away for the move, drawn again after it
var _mods_off: Array = []            ## PlayerAnim's modifiers switched off while a move plays


static func install(p: FrontierPlayer) -> PlayerTraversal:
	var t := PlayerTraversal.new()
	t.name = "Traversal"
	t.player = p
	p.add_child(t)
	t.adopt()
	return t


## Instead of TravPreviewActor.build(): the player's own rig, skeleton and AnimationPlayer.
func adopt() -> void:
	lib = TravMoveLibrary.shared()
	skeleton = player.skeleton
	rig = skeleton.get_parent() as Node3D
	while rig != null and rig.get_parent() != player.visual:
		rig = rig.get_parent() as Node3D
	if rig == null:
		rig = skeleton.get_parent() as Node3D
	_rig_local = rig.transform
	anim_player = player.anim.get_node(player.anim.anim_player) as AnimationPlayer
	inert = TravInertializer.new()
	inert.name = "TravInertializer"
	skeleton.add_child(inert)
	var names := PackedStringArray()
	for c in lib.clips():
		names.append(_anim_name(c))
	inert.set_bones_from_clips(skeleton, anim_player, names)
	var cub := PackedStringArray()
	var her := PackedStringArray()
	for id: String in lib.moves:
		var ci := str((lib.moves[id] as Dictionary).get("clip_interpolation", ""))
		if ci == "cubic" or ci == "hermite":
			for p: Dictionary in (lib.moves[id] as Dictionary).get("parts", []):
				(cub if ci == "cubic" else her).append(_anim_name(str(p.clip)))
	if not cub.is_empty():
		TravInertializer.smooth_clip_tracks(anim_player, cub)
	if not her.is_empty():
		TravInertializer.resample_player_hermite(anim_player, her)
	# (how far the limbs of the moves with momentum reach, and where their feet stand: the warp's limits)
	TravMomentum.measure(lib, anim_player, str(LIB) + "/", skeleton)
	ik = TraversalIK.new()
	ik.name = "TraversalIK"
	skeleton.add_child(ik)
	# right after the animation and PlayerAnim's own stance inertializer, before the arm layers and the body
	var first := 0
	for i in skeleton.get_child_count():
		if skeleton.get_child(i) is StanceInertializer:
			first = i + 1
	skeleton.move_child(inert, first)
	skeleton.move_child(ik, first + 1)
	_build_tree()
	tree.active = false
	call_deferred(&"_bake_world")


## The level's ledges and beams, once its colliders are in the physics space.
func _bake_world() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var level := get_tree().current_scene
	if level == null or not is_instance_valid(player):
		return
	var own := TravMoveLibrary.new()
	own.load_table(TravMoveLibrary.TABLE)
	for id in DISABLED_MOVES:
		if own.moves.has(id):
			(own.moves[id] as Dictionary)["enabled"] = false
	for id in OVERHEAD_ONLY_MOVES:
		if own.moves.has(id):
			(own.moves[id] as Dictionary).erase("band")
	var registry := TravShapeRegistry.new()
	var baker := TravLedgeBaker.new(registry, own.settings)
	var ledges := baker.bake(level, player.get_world_3d().direct_space_state)
	controller = TraversalController.new()
	controller.name = "TraversalController"
	player.add_child(controller)
	controller.setup(player, {"library": own, "registry": registry, "ledges": ledges})
	# (the stick ends a climb onto a top once the feet are on it: user 2026-09-26 "as long as you dont lock
	# movement when climb up something")
	controller.input_exit = true
	world_ready = true


## Per physics tick, from the player: the controller's input step. True while the controller owns the body
## (the player skips its own movement).
func pre(input: Dictionary, delta: float) -> bool:
	if not world_ready or player.is_dead:
		return false
	controller.pre_step(input, delta)
	return controller.owns_body()


## After the player's movement (or instead of it): advance the controller and show its state.
func post(owned: bool, delta: float) -> void:
	if not world_ready:
		return
	if owned:
		controller.physics_step(delta)
	else:
		controller.tick(delta)
	var st := controller.anim_state()
	var on := str(st.get("mode", "OFF")) != "OFF" and st.has("clip") and str(st.clip) != ""
	if on and not showing:
		_begin()
	elif not on and showing:
		_end(st)
	if showing:
		pending_plan = controller.pending
		approach = controller.approach()
		show_state(st, player, delta)
	else:
		if _rig_back >= 0.0:
			_rig_back += delta
			var u := smoothstep(0.0, 1.0, clampf(_rig_back / _rig_ret_s, 0.0, 1.0))
			var to: Transform3D = rig.get_parent().global_transform * _rig_local
			rig.global_transform = to * _rig_off.interpolate_with(Transform3D.IDENTITY, u)
			if u >= 1.0:
				rig.transform = _rig_local
				_rig_back = -1.0
		# the exit's held feet, and the guards of an obstacle close ahead (at the locomotion's own clock)
		time_scale = 1.0
		_apply_ik(st.get("pins", []), st.get("guards", []))
		_rig_last = rig.global_transform
		_rig_seen = true


## Speed limit on the approach to a planned move (the move's entry speed at its start point), or INF.
func approach_speed(v_now: float, delta: float) -> float:
	if not world_ready:
		return INF
	var ap := controller.approach()
	if ap.is_empty():
		return INF
	var ve := float(ap.speed)
	var d := float(ap.dist)
	var a := TraversalController.APPROACH_DECEL
	if d > 0.02 and v_now > ve:
		a = maxf(a, (v_now * v_now - ve * ve) / (2.0 * d))
	return sqrt(ve * ve + 2.0 * a * maxf(0.0, d - v_now * delta))


## The player may jump on its own (no move is playing or about to).
func allows_jump() -> bool:
	return not world_ready or controller.mode == TraversalController.Mode.OFF


func _begin() -> void:
	showing = true
	_rig_back = -1.0
	_momentum = controller.momentum_active()
	# the weapon onto the body for the move
	if player.weapon and player.weapon.active and not player.hands_free:
		_gun_away = player.weapon_key
		player.hands_free = true
		player.anim.hands_free = true
		if player.gear:
			var held := player.gear.item_in_hand()
			if _momentum and held != "":
				# (a move at speed, TravMomentum: the hands are on the top within 0.1 s, before a put-away
				# could play; played, the gun flew about the planted hand; the sling rig's traversal rule)
				player.gear.snap_stowed(held)
				player.gear.last_slung = held
			else:
				player.gear.sling_all()
		player.weapon.unequip()
	player.anim.auto_process = false
	_mods_off.clear()
	for c in skeleton.get_children():
		if c is SkeletonModifier3D and c != inert and c != ik and not (c is CharacterBodyMesh) and (c as SkeletonModifier3D).active:
			(c as SkeletonModifier3D).active = false
			_mods_off.append(c)
	# the locomotion pose stands in the fade stack as the content before: the move's entry is inertialized
	# from it (pose and root; TravPreviewActor.play_content "inertialize")
	_stack = [{"clip": "actor_b-p-relax-idle", "t": 0.0, "rate": 1.0, "loop": true, "fade": 0.0, "w_t": 0.0, "key": "loco:player"}]
	_key = "loco:player"
	_move_key = ""
	_fade_pins = []
	_ramp_t = 1.0
	_ramp_len = 0.0
	_yaw = TravInertializer.yaw_of(rig.global_transform.basis)
	# (From where the rig was shown last tick: the body has already stepped onto the move's path this
	# tick, and a root reset there jumped the model a tick's travel, 9 cm at a sprint. A move at speed
	# starts it moving as the body moved: from rest the model stopped for its first frames. A move at its
	# clip's own timing starts it from rest as before: its root starts slower than the body, and the
	# carried speed ran it ahead of the take-off foot, a 4.9 cm slide at the running knee mantle.)
	var cv := controller.capsule_velocity() if _momentum else Vector3.ZERO
	inert.root_reset(_rig_last if _rig_seen else rig.global_transform, Vector3(cv.x, 0.0, cv.z))
	entry_inertialize = true
	tree.active = true


func _end(st: Dictionary) -> void:
	showing = false
	tree.active = false
	for c in _mods_off:
		if is_instance_valid(c):
			(c as SkeletonModifier3D).active = true
	_mods_off.clear()
	player.anim.auto_process = true
	_match_gait(st)
	# (The pelvis and root positions' velocity is not carried: the move's root may lag its pelvis (the
	# reconstructed align), and at the hand-back the root jumps to the body's speed; carried, the pelvis's
	# speed over the slow root was added on top: the model surged 13 cm ahead of the body and fell back,
	# a dip to 2.4 m/s from a run 0.2 s after a vault. Their offsets still decay.)
	inert.start(EXIT_INERT_S, TravInertializer.FULL, _root_bones())
	var to: Transform3D = rig.get_parent().global_transform * _rig_local
	_rig_off = to.affine_inverse() * rig.global_transform
	_rig_back = 0.0
	# (After a move at speed the rig's offset decays over the pose's exit inertialization: the root
	# stands ahead of the pelvis where the pose's pelvis stands back, and over the same time the two
	# cancel; over 0.25 s against 0.3 s the model fell 6 cm behind the body at a sprint.)
	_rig_ret_s = EXIT_INERT_S if _momentum else RIG_RETURN_S
	_stack.clear()
	_key = ""
	if _gun_away != "":
		var k := _gun_away
		_gun_away = ""
		if player.hands_free and player.weapon_key == k and player.is_usable(k):
			player._draw_from_hands_free()


func _root_bones() -> Array:
	var out := []
	for bn in ["root", "pelvis"]:
		var b := skeleton.find_bone(bn)
		if b >= 0:
			out.append(b)
	return out


## The locomotion's step after a move that runs out (a vault's run exit): the gait phase of the move's last
## pose (its table loco_match.exit, measured on the source run / sprint / walk loops) for the gait the body
## leaves at (the preview's gait thresholds).
func _match_gait(st: Dictionary) -> void:
	var loco: LocoBrain = player.anim.loco if player.anim else null
	if loco == null:
		return
	var ex: Dictionary = st.get("exit", {})
	var lm: Dictionary = ex.get("loco_match", {})
	var v := player.horizontal_speed()
	var gait := "sprint" if v > 4.2 else ("run" if v > 2.2 else ("walk" if v > 0.4 else ""))
	if gait == "":
		return
	var clip := str((lib.loco.get(gait, {}) as Dictionary).get("clip", ""))
	if ex.has("gait_plant"):
		# (A move handed back before its end, on a foot it stands on, TravMomentum.exit_gait: that foot's plant
		# (left 0, right 0.5) and on through the step for as long as it has stood, at the gait loop's own step
		# time at this speed.)
		var g := float(ex.gait_plant)
		var ld: Dictionary = lib.loco.get(gait, {})
		var pl: Dictionary = loco.data.plants(clip) if clip != "" else {}
		var cycles := float((pl.get("l", []) as Array).size())
		if cycles > 0.0 and float(ld.get("length", 0.0)) > 0.0 and float(ld.get("bank_speed", 0.0)) > 0.0:
			var cycle_s := float(ld.length) / cycles / (v / float(ld.bank_speed))
			g += float(ex.get("gait_since_s", 0.0)) / cycle_s
		loco.match_gait_phase(fposmod(g, 1.0))
		return
	if not lm.has(gait) or clip == "":
		return
	loco.match_gait_phase(loco.gait_phase(clip, float((lm[gait] as Dictionary).get("phase", 0.0))))
