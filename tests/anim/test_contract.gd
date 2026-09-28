extends AnimTestSuite
## WP7 (plan section 10 test_contract; section 8 integration): the gameplay <-> animation
## contract of scripts/player/player.gd, the weapons and PlayerAnim.
##
## 1. Members. Every player / weapon member, method and signal that PlayerAnim, AnimInputs,
##    UpperBody, the debug overlay, FootSlip and the gameplay scripts use exists, methods and
##    signals with the right arity (a method's argument count range from its default arguments;
##    a signal's argument count and types).
## 2. Level (scenes/main.tscn):
##    - AnimInputs.sample() on the real player needs no fallback, and a scripted run gives
##      non-default wish_local / target_speed (plan 8.1) that PlayerAnim sees;
##    - PlayerAnim is connected once to the player's hurt / died / respawned signals, and the
##      weapons' fired / action_started / action_cancelled;
##    - apply_hit(): light and heavy hits (direction from -direction, heavy >= heavy_hit_damage;
##      heavy = the full-body HIT state), death (DEATH, input ignored, no weapon switch), respawn
##      (alive, idle, weapon drawn again); Hit.deliver() reaches it; the player's own shots are
##      ignored;
##    - F9-F12 (AnimDebugOverlay, debug builds) go through apply_hit() / respawn() and are inert
##      with debug_build off; player.gd does not bind them itself (plan 8.1 WP8 note);
##    - weapon switch, graph-faithful by default: the old weapon's holster (its draw clip
##      backwards at its draw's speed, the weapon in the hand until the hand puts it on the body:
##      the gear rig parks it when the palm comes within SlingRig.REACH_ATTACH_M of its place, or at
##      the holster's end), its holster finish (the hand back to idle, no model), the new weapon's
##      grab, then its draw over its own equip_time (the rig's copy taken off the body when the
##      drawing hand reaches it, by SlingRig.REACH_PHASE_MAX of the draw), stage by
##      stage at FrontierPlayer.switch_stages()' times, no clip faster than the weapons' draws; a
##      second switch during the holster only changes the weapon drawn after it; one during the
##      finish or the grab (PlayerAnim already on the first target) moves PlayerAnim to the newer
##      weapon, which is then held in its own grip; pressing the targeted weapon again changes
##      nothing (the grab is not restarted); the opt-in overrides override_fast_weapon_switch (the
##      old timing: holster + draw within the new weapon's equip_time) and
##      PlayerAnim.instant_weapon_switch (the models swap at once); death during the holster keeps
##      the old weapon in the hand (its model, and PlayerAnim on its carry grip; also when it comes
##      before the rig began the put-away), during the finish
##      / grab leaves the hand empty; respawn draws the new weapon;
##    - start from standing: through the graph start clip the body speed follows
##      PlayerAnim.body_speed_cap() (the clip's inferred body speed) and reaches the target speed as
##      the start ends; override_free_start_speed lifts the cap; override_start_rate_boost (on by
##      default, pending the owner's decision) off = the graph's align rate, a slower start;
##    - PlayerAnim.graph_key(): a roster key the graph has no rows for plays the key its weapon's
##      signals are bound with;
##    - the capsule mannequin follows the stabilized (post-modifier) torso: its capsule endpoints
##      equal the BoneAttachment3D positions of the torso bones within 1 mm while the
##      AimStabilizer turns the upper body (aimed strafe);
##    - kept behaviour: the SOCOM 2 camera (centred, high: eye_height 2.3, camera_distance 3.6,
##      shoulder_offset 0), the skeleton's modifiers in order PropFlipGuard, AimStabilizer, and the
##      skinned body's CharacterBodyMesh (when it is drawn) last;
##    - every property of PlayerAnim's "Gameplay overrides" export group exists on the player with
##      the same default (graph-faithful: all off / 0, except PlayerAnim.DEFAULT_ON, on pending the
##      owner's decision) and reaches PlayerAnim when set on the player before its _ready; the same for
##      its "Torch" group (push n01b: the torch arm and the one-hand hip carry), with PlayerAnim's defaults, and
##      the ones TorchCarryIK reads reach it.

## [name, min args, max args] of methods; [name] of properties; [name, [arg types]] of signals.
const PLAYER_PROPS := ["weapon", "weapon_key", "weapons", "weapon_order", "velocity", "local_move", "wish_local",
		"target_speed", "is_crouching", "is_walking", "is_sprinting", "is_dead", "health", "max_health",
		"heavy_hit_damage", "run_speed", "walk_speed", "sprint_speed", "crouch_speed", "aim_walk_speed", "yaw", "pitch",
		"camera", "skeleton", "anim", "hud", "visual", "ignore_mouse_capture", "bow_offset", "musket_offset",
		"pistol_offset", "eye_height", "camera_distance", "shoulder_offset", "stand_height", "crouch_height",
		"jump_velocity", "show_mannequin", "use_body", "character_scene"]
const PLAYER_METHODS := [["is_on_floor", 0, 0], ["aim_pitch", 0, 0], ["get_aim_point", 0, 1], ["switch_weapon", 1, 1],
		["apply_hit", 3, 5], ["respawn", 0, 0], ["add_recoil", 2, 2], ["horizontal_speed", 0, 0], ["holster_phase", 5, 5],
		["is_switching", 0, 0], ["switch_stage", 0, 0], ["switch_stages", 6, 6], ["switch_timing", 0, 0], ["get_world_3d", 0, 0], ["get_rid", 0, 0]]
const PLAYER_SIGNALS := [["hurt", [TYPE_VECTOR2, TYPE_FLOAT, TYPE_BOOL]], ["died", [TYPE_VECTOR2]], ["respawned", []]]
const WEAPON_PROPS := ["aim", "active", "equip_time", "aim_in_time", "aim_out_time", "hand", "model", "muzzle", "player",
		"clips", "relaxed", "spread", "display_name", "move_speed_mult"]
const WEAPON_METHODS := [["wants_aim", 0, 0], ["is_steady_aiming", 0, 0], ["is_busy", 0, 0], ["charge_amount", 0, 0],
		["speed_mult", 0, 0], ["equip", 0, 0], ["unequip", 0, 0], ["tick", 1, 1], ["can_sprint", 0, 0], ["fov_mult", 0, 0],
		["launch_origin", 0, 0], ["is_equipping", 0, 0], ["aim_yaw_offset", 0, 0], ["aim_pitch_offset", 0, 0],
		["target_spread", 0, 0], ["status_text", 0, 0], ["ammo_text", 0, 0], ["progress", 0, 0]]
const WEAPON_SIGNALS := [["fired", []], ["action_started", [TYPE_STRING, TYPE_FLOAT]], ["action_cancelled", []]]
const FIREARM_PROPS := ["state", "loaded", "reserve", "reload_stages", "fire_on_release", "ready_aim"]
const FIREARM_METHODS := [["start_reload", 0, 0]]
const FIREARM_SIGNALS := [["shot_cancelled", []], ["sfx", [TYPE_STRING_NAME, TYPE_VECTOR3]]]
const BOW_PROPS := ["state", "charge", "held", "hand_nock_time", "hand_capacity", "quiver", "draw_time", "grab_time"]
const BOW_METHODS := [["is_drawn", 0, 0], ["fatigue", 0, 0], ["tremble_offset", 0, 0], ["shot_speed", 0, 0],
		["add_arrows", 1, 1]]
const BOW_SIGNALS := [["sfx", [TYPE_STRING_NAME, TYPE_VECTOR3]]]
const ANIM_METHODS := [["setup", 4, 4], ["set_weapon", 1, 1], ["play_holster", 2, 2], ["holster_enabled", 0, 0],
		["play_switch_stage", 3, 3], ["graph_key", 1, 1], ["body_speed_cap", 0, 0], ["gameplay_override_names", 0, 0],
		["trims_aim", 0, 0], ["play_hit", 1, 2], ["play_death", 0, 1], ["revive", 0, 0], ["debug_snapshot", 0, 0],
		["set_option", 2, 2], ["is_ready", 0, 0], ["manual_step", 1, 1], ["sample_inputs", 1, 1]]
const ANIM_PROPS := ["data", "upper", "loco", "stabilizer", "inputs", "player", "auto_process", "instant_weapon_switch"]
const ANIM_SIGNALS := [["anim_transition", [TYPE_STRING_NAME, TYPE_STRING_NAME, TYPE_DICTIONARY]]]
## Mannequin check: torso bones of the stabilized upper body (upper_base subtree).
const TORSO := ["spinea", "spineb", "spinec", "spined", "neck", "heada", "l_clavicle", "r_clavicle", "l_shoulder",
		"r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist"]
const DEBUG_ACTIONS := ["debug_hit_light", "debug_hit_heavy", "debug_death", "debug_respawn"]


func describe() -> String:
	return "WP7 contract: player / weapon / PlayerAnim members and arities; wish_local / target_speed; health, hits, death, respawn, F9-F12; graph weapon switch stages and overrides; start root motion; mannequin on the stabilized torso"


func timeout_s() -> float:
	return 480.0


func run(ctx: AnimTestContext) -> void:
	_members(ctx)
	var player = await ctx.level()
	if player == null:
		return
	_kept(ctx, player)
	if String(ctx.arg("parts", "")) == "switches":
		await _switches(ctx, player)
		return
	await _forwarding(ctx, player)
	await _inputs(ctx, player)
	await _signals(ctx, player)
	await _hits(ctx, player)
	await _debug_keys(ctx, player)
	await _switches(ctx, player)
	await _start_speed(ctx, player)
	_graph_keys(ctx, player)
	await _mannequin(ctx, player)


# --- 1. members -------------------------------------------------------------------------------

func _members(ctx: AnimTestContext) -> void:
	var p := FrontierPlayer.new()
	var weapons := [Bow.new(), Musket.new(), FlintlockPistol.new()]
	var a := PlayerAnim.new()
	var missing := []
	_check_obj(p, "FrontierPlayer", PLAYER_PROPS, PLAYER_METHODS, PLAYER_SIGNALS, missing)
	for w: Weapon in weapons:
		var cls := String(w.get_script().get_global_name())
		_check_obj(w, cls, WEAPON_PROPS, WEAPON_METHODS, WEAPON_SIGNALS, missing)
		if w is Firearm:
			_check_obj(w, cls, FIREARM_PROPS, FIREARM_METHODS, FIREARM_SIGNALS, missing)
		if w is Bow:
			_check_obj(w, cls, BOW_PROPS, BOW_METHODS, BOW_SIGNALS, missing)
	_check_obj(a, "PlayerAnim", ANIM_PROPS, ANIM_METHODS, ANIM_SIGNALS, missing)
	# Enum / constant members used by name.
	for c in [["Firearm.State.AIMING", Firearm.State.has("AIMING")], ["Firearm.State.READY", Firearm.State.has("READY")],
			["Bow.State.HOLDING", Bow.State.has("HOLDING")], ["Weapon.Hand.LEFT", Weapon.Hand.has("LEFT")]]:
		if not c[1]:
			missing.append(c[0])
	ctx.check(missing.is_empty(), "every player / weapon / PlayerAnim member, method (arity) and signal (arity, types) used exists: %s" % [
			"all present" if missing.is_empty() else ", ".join(missing)])
	p.free()
	for w in weapons:
		w.free()
	a.free()


func _check_obj(o: Object, cls: String, props: Array, methods: Array, sigs: Array, missing: Array) -> void:
	for n: String in props:
		if not n in o:
			missing.append("%s.%s" % [cls, n])
	var ml := {}
	for m in o.get_method_list():
		ml[String(m.name)] = m
	for m: Array in methods:
		if not ml.has(m[0]):
			missing.append("%s.%s()" % [cls, m[0]])
			continue
		var info: Dictionary = ml[m[0]]
		var n_args: int = (info.args as Array).size()
		var n_def: int = (info.default_args as Array).size()
		if n_args - n_def > int(m[1]) or n_args < int(m[2]):
			missing.append("%s.%s() takes %d..%d args, used with %d..%d" % [cls, m[0], n_args - n_def, n_args, m[1], m[2]])
	var sl := {}
	for s in o.get_signal_list():
		sl[String(s.name)] = s
	for s: Array in sigs:
		if not sl.has(s[0]):
			missing.append("%s signal %s" % [cls, s[0]])
			continue
		var args: Array = sl[s[0]].args
		var want: Array = s[1]
		var ok := args.size() == want.size()
		for i in mini(args.size(), want.size()):
			ok = ok and int(args[i].type) == int(want[i])
		if not ok:
			missing.append("%s signal %s%s, used as %s" % [cls, s[0], args.map(func(x): return type_string(int(x.type))),
					want.map(func(x): return type_string(int(x)))])


# --- 2. level ---------------------------------------------------------------------------------

## A second player with overrides set in its inspector exports: every one reaches its PlayerAnim.
func _forwarding(ctx: AnimTestContext, player: Node) -> void:
	var p2 := FrontierPlayer.new()
	p2.name = "ContractPlayer2"
	var probe := PlayerAnim.new()
	var names := probe.gameplay_override_names()
	var torch_names := probe.torch_option_names()
	probe.free()
	var want := {}
	for f in names:
		var v: Variant = p2.get(f)
		want[f] = (not bool(v)) if v is bool else 0.07
		p2.set(f, want[f])
	# the "Torch" options (push n01b): each changed a little on the player
	var torch_want := {}
	for f in torch_names:
		var v: Variant = p2.get(f)
		torch_want[f] = (v as Vector3) + Vector3(0.01, 0.01, 0.01) if v is Vector3 else float(v) * 0.9
		p2.set(f, torch_want[f])
	p2.position = Vector3(0, -50, 0)
	ctx.add_node(p2, player.get_parent())
	await ctx.frames(2)
	var a2: PlayerAnim = p2.anim
	var bad := []
	for f in names:
		if a2 == null or not is_equal_approx(float(a2.get(f)), float(want[f])):
			bad.append(f)
	ctx.check(a2 != null and a2.is_ready() and bad.is_empty() and names.size() >= 12,
			"player exports of all %d 'Gameplay overrides' (%s) set before _ready reach its PlayerAnim (%s)" % [names.size(),
			", ".join(names), "ok" if bad.is_empty() else "not forwarded: " + ", ".join(bad)])
	var tbad := []
	for f in torch_names:
		var got: Variant = a2.get(f) if a2 != null else null
		if got == null or (got is Vector3 and not (got as Vector3).is_equal_approx(torch_want[f])) \
				or (not (got is Vector3) and not is_equal_approx(float(got), float(torch_want[f]))):
			tbad.append(f)
	# and the ones TorchCarryIK reads reach it (PlayerAnim.TORCH_IK_OPTIONS)
	for f: String in PlayerAnim.TORCH_IK_OPTIONS:
		var ik: Variant = a2.torch_ik.get(String(PlayerAnim.TORCH_IK_OPTIONS[f])) if a2 != null and a2.torch_ik != null else null
		if ik == null or str(ik) != str(torch_want[f]):
			tbad.append(f + " (TorchCarryIK)")
	ctx.check(a2 != null and tbad.is_empty() and torch_names.size() >= 6,
			"player exports of all %d 'Torch' options (%s) set before _ready reach its PlayerAnim (%s)" % [torch_names.size(),
			", ".join(torch_names), "ok" if tbad.is_empty() else "not forwarded: " + ", ".join(tbad)])
	if a2 != null and a2.is_ready():
		ctx.check(not a2.holster_enabled() and is_equal_approx(a2.loco.join_fade_s, 0.07) and is_equal_approx(a2.loco.release_grace_s, 0.07)
				and a2.body_speed_cap() == INF and not a2.loco.start_rate_boost,
				"... and take effect: holster off (instant_weapon_switch), LocoBrain join_fade_s / release_grace_s 0.07, no start speed cap, start rate boost off (the graph's align rate)")
	p2.queue_free()
	await ctx.frames(2)
	player.camera.current = true


func _kept(ctx: AnimTestContext, player: Node) -> void:
	ctx.check(is_equal_approx(float(player.eye_height), 2.3) and is_equal_approx(float(player.camera_distance), 3.6)
			and is_equal_approx(float(player.shoulder_offset), 0.0) and is_equal_approx(float(player.spring_arm.position.x), 0.0),
			"SOCOM 2 camera kept: eye_height %.2f, camera_distance %.2f, shoulder_offset %.2f" % [float(player.eye_height),
			float(player.camera_distance), float(player.shoulder_offset)])
	var a0: PlayerAnim = player.anim
	var fwd := []
	var ov_names := a0.gameplay_override_names()
	for f in ov_names:
		if not f in player or bool(player.get(f)) != (f in PlayerAnim.DEFAULT_ON) or not is_equal_approx(float(a0.get(f)), float(player.get(f))):
			fwd.append(f)
	for f in PlayerAnim.OVERRIDE_FLAGS + ["instant_weapon_switch", "join_fade_s", "stick_release_grace_s", "override_free_start_speed",
			"override_start_rate_boost"]:
		if not f in ov_names:
			fwd.append("%s (not in the group)" % f)
	ctx.check(fwd.is_empty() and not bool(player.override_fast_weapon_switch) and a0.loco.start_rate_boost == bool(player.override_start_rate_boost),
			"every PlayerAnim 'Gameplay overrides' export (%d) is on the player, off / 0 by default (graph-faithful) except %s (on, pending the owner's decision), and equal on both; the player's own override_fast_weapon_switch is off (%s)" % [
			ov_names.size(), PlayerAnim.DEFAULT_ON, "ok" if fwd.is_empty() else ", ".join(fwd)])
	# the "Torch" options (push n01b): on the player with PlayerAnim's defaults, and equal on both
	var tdef := []
	var tprobe := PlayerAnim.new()
	for f in a0.torch_option_names():
		if not f in player or str(player.get(f)) != str(tprobe.get(f)) or str(player.get(f)) != str(a0.get(f)):
			tdef.append(f)
	tprobe.free()
	ctx.check(tdef.is_empty(), "every PlayerAnim 'Torch' export (%d) is on the player with the same default (%s)" % [
			a0.torch_option_names().size(), "ok" if tdef.is_empty() else ", ".join(tdef)])
	var sk: Skeleton3D = player.skeleton
	var mods := []
	for c in sk.get_children():
		if c is SkeletonModifier3D:
			mods.append(c)
	var names := mods.map(func(m: Node) -> String: return String(m.get_script().get_global_name()) if m.get_script() else m.get_class())
	var a: PlayerAnim = player.anim
	var ig := mods.find(a.upper.prop_guard)
	var ist := mods.find(a.stabilizer)
	ctx.check(ig >= 0 and ist > ig, "skeleton modifiers: PropFlipGuard, then AimStabilizer (%s)" % [names])
	var body := -1
	for i in mods.size():
		if mods[i] is CharacterBodyMesh:
			body = i
	if body >= 0:
		ctx.check(body == mods.size() - 1, "the skinned body's CharacterBodyMesh modifier stays last (%s)" % [names])
	else:
		ctx.info("no CharacterBodyMesh in this level (use_body off or asset missing): %s" % [names])


func _inputs(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	var s := AnimInputs.sample(player, null, 1.0 / Engine.physics_ticks_per_second)
	ctx.check(s.fallbacks.is_empty(), "AnimInputs.sample() on the real player needs no fallback (fallbacks: %s)" % [s.fallbacks])
	ctx.check(player.wish_local == Vector2.ZERO and player.target_speed == 0.0, "standing: wish_local and target_speed are 0")
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await ctx.frames(30)
	var wl: Vector2 = player.wish_local
	var ts: float = player.target_speed
	var band: float = player.run_speed * player.weapon.speed_mult()
	ctx.near(ts, band, 1e-4, "W+A: target_speed = run speed x weapon.speed_mult() (m/s)")
	ctx.check(wl.y > 0.1 and wl.x < -0.1 and absf(wl.length() - ts) < 1e-3,
			"W+A: wish_local points forward-left with the target speed as length (%s)" % wl)
	ctx.check(a.inputs != null and a.inputs.fallbacks.is_empty() and a.inputs.wish_local.is_equal_approx(wl)
			and is_equal_approx(a.inputs.target_speed, ts), "PlayerAnim's sample carries the player's wish_local / target_speed")
	Input.action_press("walk")
	await ctx.frames(4)
	ctx.near(float(player.target_speed), player.walk_speed * player.weapon.speed_mult(), 1e-4, "Alt held: target_speed = walk speed x weapon.speed_mult() (m/s)")
	Input.action_release("walk")
	Input.action_release("move_left")
	Input.action_release("move_forward")
	await ctx.frames(2)
	ctx.check(player.wish_local == Vector2.ZERO and player.target_speed == 0.0, "released: wish_local and target_speed back to 0")
	await ctx.frames(60)


func _signals(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	for s in ["hurt", "died", "respawned"]:
		var n := 0
		for c in player.get_signal_connection_list(s):
			if (c.callable as Callable).get_object() == a:
				n += 1
		ctx.check(n == 1, "PlayerAnim is connected once to player.%s (%d)" % [s, n])
	for k in player.weapons:
		var w: Weapon = player.weapons[k]
		for s in ["fired", "action_started", "action_cancelled"]:
			var n := 0
			for c in w.get_signal_connection_list(s):
				if (c.callable as Callable).get_object() == a:
					n += 1
			ctx.check(n == 1, "PlayerAnim is connected once to %s.%s (%d)" % [k, s, n])


func _hits(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	var got := []
	var on_hurt := func(d: Vector2, amount: float, heavy: bool) -> void: got.append(["hurt", d, amount, heavy])
	var on_died := func(d: Vector2) -> void: got.append(["died", d])
	var on_resp := func() -> void: got.append(["respawned"])
	player.hurt.connect(on_hurt)
	player.died.connect(on_died)
	player.respawned.connect(on_resp)
	var hp0: float = player.health
	ctx.near(hp0, float(player.max_health), 1e-6, "starts at max_health")
	var b: Basis = player.global_basis
	# Light hit from the front: the projectile travels backward along the body (direction = +back).
	player.apply_hit(10.0, player.global_position + Vector3.UP * 1.3 - b.z, b.z, null, "body")
	ctx.check(got.size() == 1 and got[0][0] == "hurt" and (got[0][1] as Vector2).is_equal_approx(Vector2(0, 1))
			and is_equal_approx(float(got[0][2]), 10.0) and not bool(got[0][3]),
			"light hit from the front: hurt((0, 1), 10, heavy false) (%s)" % [got])
	ctx.near(float(player.health), hp0 - 10.0, 1e-6, "light hit takes 10 health")
	await ctx.frames(3)
	ctx.check(a.loco.state != LocoBrain.HIT, "light hit: no full-body HIT (the no-arms additive only; state %s)" % a.loco.state)
	# Heavy hit from the right.
	got.clear()
	player.apply_hit(45.0, player.global_position, -b.x, null, "body")
	ctx.check(got.size() == 1 and (got[0][1] as Vector2).is_equal_approx(Vector2(1, 0)) and bool(got[0][3]),
			"heavy hit from the right: hurt((1, 0), 45, heavy true) (%s)" % [got])
	await ctx.frames(3)
	ctx.check(a.loco.state == LocoBrain.HIT, "heavy hit: the full-body HIT state (%s)" % a.loco.state)
	# Own shots, zero damage: ignored.
	var hp1: float = player.health
	player.apply_hit(50.0, player.global_position, b.z, player, "body")
	player.apply_hit(0.0, player.global_position, b.z, null, "body")
	ctx.check(player.health == hp1 and got.size() == 1, "the player's own shots and zero damage are ignored")
	# Hit.deliver() on the player's collider.
	var col: CollisionShape3D = player.collision
	ctx.check(Hit.deliver(col, 5.0, player.global_position, b.z, null) and is_equal_approx(float(player.health), hp1 - 5.0),
			"Hit.deliver() on the player's collision shape reaches apply_hit()")
	await ctx.frames(150)
	# Death.
	got.clear()
	var key0: String = player.weapon_key
	player.apply_hit(1.0e5, player.global_position, b.z, null, "body")
	ctx.check(bool(player.is_dead) and got.size() == 1 and got[0][0] == "died" and (got[0][1] as Vector2).is_equal_approx(Vector2(0, 1)),
			"lethal hit: is_dead and died((0, 1)) (%s)" % [got])
	await ctx.frames(3)
	ctx.check(a.loco.state == LocoBrain.DEATH, "death: the DEATH state (%s)" % a.loco.state)
	var w: Weapon = player.weapon
	ctx.check(not w.active and w.aim == 0.0 and w.model.visible, "death: weapon lowered and inactive, its model still in the hand")
	var pos0: Vector3 = player.global_position
	var yaw_body: float = player.rotation.y
	Input.action_press("move_forward")
	Input.action_press("jump")
	player.yaw += 0.5
	await ctx.frames(30)
	Input.action_release("move_forward")
	Input.action_release("jump")
	var moved := Vector2(player.global_position.x - pos0.x, player.global_position.z - pos0.z).length()
	ctx.check(moved < 0.05 and player.wish_local == Vector2.ZERO and player.target_speed == 0.0,
			"dead: movement input ignored (moved %.3f m)" % moved)
	ctx.check(is_equal_approx(float(player.rotation.y), yaw_body) and absf(wrapf(float(player.camera_pivot.rotation.y) - 0.5, -PI, PI)) < 1e-3,
			"dead: the body keeps its facing while the camera orbits it")
	player.switch_weapon("bow" if key0 != "bow" else "pistol")
	ctx.check(String(player.weapon_key) == key0, "dead: no weapon switch")
	got.clear()
	player.respawn()
	await ctx.frames(20)
	ctx.check(not bool(player.is_dead) and is_equal_approx(float(player.health), float(player.max_health))
			and got.size() == 1 and got[0][0] == "respawned", "respawn(): alive at full health, respawned emitted")
	ctx.check(a.loco.state != LocoBrain.DEATH and player.weapon.active and player.weapon.model.visible,
			"respawn: out of DEATH (%s), the weapon drawn again" % a.loco.state)
	player.yaw = player.rotation.y
	await ctx.frames(120)
	player.hurt.disconnect(on_hurt)
	player.died.disconnect(on_died)
	player.respawned.disconnect(on_resp)


func _debug_keys(ctx: AnimTestContext, player: Node) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/player.gd")
	var bound := []
	for act in DEBUG_ACTIONS:
		if src.contains('"%s"' % act):
			bound.append(act)
	for k in ["KEY_F9", "KEY_F10", "KEY_F11", "KEY_F12"]:
		if src.contains(k):
			bound.append(k)
	ctx.check(bound.is_empty(), "player.gd does not bind F9-F12 itself (the overlay owns them): %s" % [bound])
	var o := AnimDebugOverlay.attach(player)
	if not OS.is_debug_build() or o == null:
		ctx.info("not a debug build: the overlay (F9-F12) is not created; nothing to test")
		return
	var a: PlayerAnim = player.anim
	var hurts := []
	var on_hurt := func(d: Vector2, amount: float, heavy: bool) -> void: hurts.append([d, amount, heavy])
	player.hurt.connect(on_hurt)
	o.debug_build = true
	var hp: float = player.health
	o.run_action("debug_hit_light")
	ctx.check(hurts.size() == 1 and not bool(hurts[0][2]) and float(player.health) < hp,
			"F9 (debug build): a light hit through player.apply_hit() (%s; %s)" % [hurts, o.last_action])
	await ctx.frames(3)
	o.run_action("debug_hit_heavy")
	await ctx.frames(3)
	ctx.check(hurts.size() == 2 and bool(hurts[1][2]) and a.loco.state == LocoBrain.HIT,
			"F10: a heavy hit through apply_hit(), full-body HIT (%s)" % a.loco.state)
	await ctx.frames(120)
	o.run_action("debug_death")
	await ctx.frames(3)
	ctx.check(bool(player.is_dead) and a.loco.state == LocoBrain.DEATH, "F11: death through apply_hit() (%s)" % a.loco.state)
	o.run_action("debug_respawn")
	await ctx.frames(10)
	ctx.check(not bool(player.is_dead) and float(player.health) == float(player.max_health) and a.loco.state != LocoBrain.DEATH,
			"F12: respawn() (%s)" % a.loco.state)
	# Release build: inert (keys and actions).
	o.debug_build = false
	hurts.clear()
	var hp2: float = player.health
	o.run_action("debug_hit_heavy")
	o.run_action("debug_death")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_F10
	e.keycode = KEY_F10
	e.pressed = true
	o._unhandled_input(e)
	await ctx.frames(3)
	ctx.check(hurts.is_empty() and float(player.health) == hp2 and not bool(player.is_dead),
			"F9-F12 are inert with debug_build off (release builds)")
	o.debug_build = OS.is_debug_build()
	player.hurt.disconnect(on_hurt)
	await ctx.frames(60)


func _switches(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	var hz := float(Engine.physics_ticks_per_second)
	player.switch_weapon("musket")
	await ctx.frames(240)
	ctx.check(a.holster_enabled() and not player.override_fast_weapon_switch, "graph default: options.holster on (instant_weapon_switch and override_fast_weapon_switch off)")
	for pair in [["musket", "bow"], ["bow", "pistol"], ["pistol", "musket"], ["musket", "pistol"]]:
		player.switch_weapon(pair[0])
		await ctx.frames(240)
		var old: Weapon = player.weapons[pair[0]]
		var nw: Weapon = player.weapons[pair[1]]
		var st := "crouch" if player.is_crouching else "stand"
		var s := FrontierPlayer.switch_stages(a.data, pair[0], pair[1], st, old.equip_time, nw.equip_time)
		var plan := FrontierPlayer._plan_switch(s)
		var clips := {"holster": String(a.data.action(pair[0], st, "holster").get("partial", "")),
				"finish": String(a.data.action(pair[0], st, "holster_finish").get("partial", "")),
				"grab": String(a.data.action(pair[1], st, "grab").get("partial", "")),
				"draw": String(a.data.action(pair[1], st, "equip").get("partial", ""))}
		# Fastest a switch clip may play: the faster of the two weapons' draws (+5 %).
		var max_rate := 1.05 * maxf(a.data.clip_length(clips.holster) / old.equip_time, a.data.clip_length(clips.draw) / nw.equip_time)
		player.switch_weapon(pair[1])
		ctx.check(player.weapon == nw and player.is_switching() and player.switch_stage() == "holster" and _in_hand(player, pair[0])
				and not nw.model.visible and not old.active, "%s -> %s: `weapon` is the new one at once, the old model stays in the hand for the holster" % pair)
		var tm: Dictionary = player.switch_timing()
		ctx.check(is_equal_approx(float(tm.get("t_finish", -1.0)), float(plan.t_finish)) and is_equal_approx(float(tm.get("t_draw", -1.0)), float(plan.t_draw)),
				"%s -> %s: switch_timing() reports the stage times (%s)" % [pair[0], pair[1], tm])
		var seen := {}
		var fastest := [0.0, ""]
		var t_fin := -1.0
		var t_draw := -1.0
		var t_ready := -1.0
		var model_ok := true
		var model_bad := ""
		var tl := []
		var last_row := ""
		var left := [-1.0, INF]      # [s, the palm's gap to its place (m)] when the old weapon left the hand for the body
		var taken := -1.0            # s the new weapon's draw took it off the body
		for f in range(1, int((float(plan.t_draw) + nw.equip_time) * hz) + 40):
			await ctx.frames(1)
			var t := f / hz
			var stage: String = player.switch_stage()
			var row := "%s | old %s | new %s" % [stage, _gear_row(player, pair[0]), _gear_row(player, pair[1])]
			if row != last_row:
				tl.append("%.3f %s" % [t, row])
				last_row = row
			for o in a.upper.snapshot().active_oneshots:
				var c := String(o.clip)
				var r := float(o.rate)
				for k in clips:
					if c == clips[k] and ((k == "holster" and r < 0.0) or (k != "holster" and r > 0.0)):
						seen[k] = true
				if absf(r) > fastest[0]:
					fastest = [absf(r), c.trim_prefix("actor_b-")]
			if t_fin < 0.0 and stage in ["finish", "grab"]:
				t_fin = t
			if t_draw < 0.0 and stage == "" and nw.active:
				t_draw = t
			if t_ready < 0.0 and nw.active and not nw.is_equipping():
				t_ready = t
			# Models (with the gear rig, SlingRig: its copy follows the hand): the old one in the hand through
			# the holster until the hand has put it on the body, none in the hand through the finish and grab,
			# the new one from its draw once the hand takes it off the body (SlingRig REACH: until then
			# nothing shows in the hand).
			var ok_now := true
			var og := _gear_entry(player, pair[0])
			if left[0] < 0.0 and og != null and og.mode == SlingRig.Mode.HOLSTER and og.park_t >= 0.0:
				left = [t, og.hol_min]
			if stage == "holster":
				ok_now = (_in_hand(player, pair[0]) or left[0] >= 0.0) and not nw.model.visible
			elif stage in ["finish", "grab"]:
				ok_now = not old.model.visible and not nw.model.visible
			elif nw.active:
				var ng := _gear_entry(player, pair[1])
				if taken < 0.0 and _in_hand(player, pair[1]) and not (ng != null and ng.mode == SlingRig.Mode.REACH):
					taken = t
				if taken >= 0.0:
					ok_now = _in_hand(player, pair[1]) and not old.model.visible
				elif player.get("gear") == null:
					ok_now = false
				else:
					ok_now = ng != null and ng.mode == SlingRig.Mode.REACH and not nw.model.visible and not old.model.visible
			if not ok_now and model_ok:
				model_bad = "first at %.3f s, stage '%s': old in hand %s (model %s), new in hand %s (model %s, active %s)" % [t, stage,
						_in_hand(player, pair[0]), old.model.visible, _in_hand(player, pair[1]), nw.model.visible, nw.active]
			model_ok = model_ok and ok_now
		ctx.check(bool(seen.get("holster", false)) and (float(s.finish) <= 0.0 or bool(seen.get("finish", false)))
				and (float(s.grab) <= 0.0 or bool(seen.get("grab", false))) and bool(seen.get("draw", false)),
				"%s -> %s: the graph stages play: holster (draw clip backwards), finish %s, grab %s, draw (%s)" % [pair[0], pair[1],
				clips.finish.trim_prefix("actor_b-"), clips.grab.trim_prefix("actor_b-"), seen.keys()])
		ctx.check(model_ok, "%s -> %s: the old weapon in the hand through the holster until the hand puts it on the body, none in the hand through the finish and grab, the new one from its draw once the hand takes it%s" % [
				pair[0], pair[1], (" (" + model_bad + ")") if model_bad != "" else ""])
		# The gear rig puts the old weapon on the body when the palm comes within reach of its place, or
		# at the holster's end (the draw clip backwards: the hand is at the body there), and takes the new
		# one when the drawing hand reaches it, by SlingRig.REACH_PHASE_MAX of the draw at the latest.
		ctx.check(player.get("gear") == null or left[0] >= 0.0 and (float(left[1]) <= SlingRig.REACH_ATTACH_M + 1e-4 or left[0] >= float(plan.t_finish) - 1.5 / hz),
				"%s -> %s: the old weapon leaves the hand within reach of its place on the body or at the holster's end (%.3f s, palm %.3f m from it; holster ends %.3f s)" % [
				pair[0], pair[1], left[0], left[1], plan.t_finish])
		ctx.check(player.get("gear") == null or taken >= 0.0 and taken - float(plan.t_draw) <= SlingRig.REACH_PHASE_MAX * nw.equip_time + 1.5 / hz,
				"%s -> %s: the drawing hand takes the new weapon off the body %.3f s into its draw (at most REACH_PHASE_MAX of %.2f s)" % [
				pair[0], pair[1], taken - float(plan.t_draw), nw.equip_time])
		if not model_ok:
			for r in tl:
				ctx.info("  %s -> %s gear %s" % [pair[0], pair[1], r])
		ctx.near(t_fin, float(plan.t_finish), 1.5 / hz, "%s -> %s: holster over the old weapon's equip_time (at its draw's speed; s)" % pair)
		ctx.near(t_draw, float(plan.t_draw), 1.5 / hz, "%s -> %s: the draw starts after the finish and the grab (switch_stages(); s)" % pair)
		ctx.near(t_ready, float(plan.t_draw) + nw.equip_time, 1.5 / hz, "%s -> %s: the new weapon is usable when its draw over its equip_time ends (s)" % pair)
		ctx.at_most(fastest[0], max_rate, "%s -> %s: no switch clip plays faster than the weapons' draws (x real time; fastest %s)" % [pair[0], pair[1], fastest[1]])
	# A second switch during the holster only changes the weapon drawn after it.
	player.switch_weapon("musket")
	await ctx.frames(240)
	player.switch_weapon("pistol")
	await ctx.frames(5)
	player.switch_weapon("bow")
	var pistol_shown := false
	for f in 300:
		await ctx.frames(1)
		pistol_shown = pistol_shown or player.weapons["pistol"].model.visible
	ctx.check(String(player.weapon_key) == "bow" and player.weapon.model.visible and not pistol_shown and not player.weapons["musket"].model.visible
			and String(a.upper.weapon) == "bow", "second switch during the holster: the bow is drawn after it, the pistol never shown")
	# A second switch during the finish or the grab (the holster is over, so PlayerAnim already plays
	# the first target): PlayerAnim takes the newer weapon, which is then held in its own grip.
	player.switch_weapon("musket")
	await _settle_switch(ctx, player)
	player.switch_weapon("bow")
	await _settle_switch(ctx, player)
	await ctx.frames(120)
	var bow_grip := _grip(player, player.weapons["bow"])
	for stage in ["finish", "grab"]:
		player.switch_weapon("musket")
		await _settle_switch(ctx, player)
		await ctx.frames(30)
		player.switch_weapon("pistol")
		var n := 0
		while player.switch_stage() != stage and n < 400:
			await ctx.frames(1)
			n += 1
		await ctx.frames(2)
		var at: String = player.switch_stage()
		player.switch_weapon("bow")
		await ctx.frames(2)
		var anim_now := String(a.upper.weapon)
		await _settle_switch(ctx, player)
		await ctx.frames(120)
		var err := _deg_between(bow_grip, _grip(player, player.weapons["bow"]))
		ctx.check(at == stage and anim_now == "bow" and String(player.weapon_key) == "bow" and String(a.upper.weapon) == "bow"
				and String(a.get("_weapon")) == "bow" and player.weapon.model.visible and not player.weapons["pistol"].model.visible
				and not player.weapons["musket"].model.visible,
				"second switch during the %s (musket -> pistol, then bow): PlayerAnim takes the bow at once (%s) and plays it after the draw (%s), only the bow shown" % [
				stage, anim_now, a.upper.weapon])
		ctx.at_most(err, 3.0, "... the bow is held in its own grip after a second switch during the %s: l_hand_prop in the l_wrist frame vs a plain switch to the bow (deg)" % stage)
	# Pressing the targeted weapon again changes nothing: the grab is not restarted.
	player.switch_weapon("musket")
	await _settle_switch(ctx, player)
	await ctx.frames(30)
	for stage in ["holster", "grab"]:
		player.switch_weapon("musket" if stage == "holster" else "pistol")
		await _settle_switch(ctx, player)
		await ctx.frames(30)
		var target := "pistol" if stage == "holster" else "musket"
		player.switch_weapon(target)
		var n2 := 0
		while player.switch_stage() != stage and n2 < 400:
			await ctx.frames(1)
			n2 += 1
		await ctx.frames(4)
		var tm0: Dictionary = player.switch_timing()
		player.switch_weapon(target)
		var tm1: Dictionary = player.switch_timing()
		await ctx.frames(2)
		ctx.check(player.switch_stage() == stage and not tm0.is_empty() and is_equal_approx(float(tm1.t_grab), float(tm0.t_grab))
				and is_equal_approx(float(tm1.t_draw), float(tm0.t_draw)), "pressing the targeted weapon (%s) again during its %s changes nothing (t_grab %.3f -> %.3f, t_draw %.3f -> %.3f s)" % [
				target, stage, float(tm0.get("t_grab", -1.0)), float(tm1.get("t_grab", -1.0)), float(tm0.get("t_draw", -1.0)), float(tm1.get("t_draw", -1.0))])
		await _settle_switch(ctx, player)
	# Back to the bow for the next check (a switch to the musket during its draw).
	player.switch_weapon("bow")
	await _settle_switch(ctx, player)
	await ctx.frames(30)
	# A switch during the draw holsters from where the draw is (no instant swap).
	player.switch_weapon("musket")
	var w8 := 0
	while (player.is_switching() or not player.weapons["musket"].is_equipping()) and w8 < 400:
		await ctx.frames(1)
		w8 += 1
	await ctx.frames(int(0.2 * hz))
	ctx.check(player.weapons["musket"].is_equipping(), "the musket's draw started after its switch stages and still plays 0.2 s later")
	player.switch_weapon("pistol")
	var rev := false
	for f in 20:
		await ctx.frames(1)
		for o in a.upper.snapshot().active_oneshots:
			rev = rev or (float(o.rate) < 0.0 and String(o.clip) == String(a.data.action("musket", "stand", "holster").get("partial", "")))
	ctx.check(rev and player.is_switching(), "switch during the draw: the musket's draw reverses where it is (the holster)")
	await ctx.frames(300)
	# Gameplay override: the old timing (holster + draw within the new weapon's equip_time).
	player.override_fast_weapon_switch = true
	player.switch_weapon("musket")
	await ctx.frames(240)
	var h := FrontierPlayer.holster_phase(a.data, "musket", "bow", "stand", player.weapons["bow"].equip_time)
	player.switch_weapon("bow")
	var ready := -1.0
	var fin := -1.0
	for f in range(1, 200):
		await ctx.frames(1)
		if fin < 0.0 and not player.is_switching():
			fin = f / hz
		if ready < 0.0 and player.weapon.active and not player.weapon.is_equipping():
			ready = f / hz
	ctx.near(fin, h, 1.5 / hz, "override_fast_weapon_switch: holster phase = holster_phase() (s)")
	ctx.near(ready, player.weapons["bow"].equip_time, 1.5 / hz, "override_fast_weapon_switch: the bow is usable after its equip_time, as before the graph holster (s)")
	player.override_fast_weapon_switch = false
	# Gameplay override: instant switch.
	a.instant_weapon_switch = true
	await ctx.frames(3)
	player.switch_weapon("musket")
	ctx.check(not player.is_switching() and player.weapons["musket"].model.visible and not player.weapons["bow"].model.visible,
			"instant_weapon_switch (override): models swap at once, no holster")
	await ctx.frames(150)
	a.instant_weapon_switch = false
	await ctx.frames(3)
	ctx.check(a.holster_enabled(), "instant_weapon_switch off again: holster back on")
	# Death during a switch (plan 8.1): what is in the hand stays there. The holster: the old weapon
	# (its model, and PlayerAnim keeps its carry grip until respawn); the finish / grab: nothing.
	player.switch_weapon("musket")
	await _settle_switch(ctx, player)
	await ctx.frames(120)
	var musket_grip := _grip(player, player.weapons["musket"])
	for stage in ["holster", "finish", "grab"]:
		player.switch_weapon("musket")
		await _settle_switch(ctx, player)
		await ctx.frames(30)
		player.switch_weapon("bow")
		var n := 0
		while player.switch_stage() != stage and n < 400:
			await ctx.frames(1)
			n += 1
		var mk: Weapon = player.weapons["musket"]
		var bw: Weapon = player.weapons["bow"]
		player.apply_hit(1.0e5, player.global_position, player.global_basis.z, null, "body")
		await ctx.frames(60)
		if stage == "holster":
			var gerr := _deg_between(musket_grip, _grip(player, mk))
			ctx.check(bool(player.is_dead) and not player.is_switching() and _in_hand(player, "musket") and not bw.model.visible
					and String(a.upper.weapon) == "musket",
					"death during the switch's holster: the old musket stays in the hand, and PlayerAnim on the musket (%s), the bow hidden (dead %s, switching %s, musket in hand %s, bow model %s)" % [
					a.upper.weapon, player.is_dead, player.is_switching(), _in_hand(player, "musket"), bw.model.visible])
			ctx.at_most(gerr, 3.0, "... the dead player holds the musket in its own carry grip (r_hand_prop in the r_wrist frame vs the musket carry; deg)")
		else:
			ctx.check(bool(player.is_dead) and not player.is_switching() and not mk.model.visible and not bw.model.visible,
					"death during the switch's %s: the hand stays empty (neither model shown)" % stage)
		player.respawn()
		await ctx.frames(int((bw.equip_time + 0.2) * hz))
		ctx.check(not bool(player.is_dead) and String(player.weapon_key) == "bow" and bw.active and _in_hand(player, "bow") and not mk.model.visible
				and String(a.upper.weapon) == "bow", "respawn after a death during the %s: the bow drawn (PlayerAnim %s), the musket put away" % [stage, a.upper.weapon])
		player.yaw = player.rotation.y
		await ctx.frames(60)


## The gear rig's entry of the weapon `key` that is not on the body (in or on its way to / from a hand), or null.
static func _gear_entry(player: Node, key: String) -> SlingRig.Entry:
	var g: SlingRig = player.get("gear")
	if g == null:
		return null
	for e: SlingRig.Entry in g.entries_of(g.item_for_key(key)):
		if e.mode != SlingRig.Mode.STOWED:
			return e
	return null


## The gear rig's state of the weapon `key` (test report): the hand model, then each entry not on the body.
static func _gear_row(player: Node, key: String) -> String:
	var w: Weapon = player.weapons[key]
	var out := "model %s" % ("on" if w.model and w.model.visible else "off")
	var g: SlingRig = player.get("gear")
	if g == null:
		return out
	var id := g.item_for_key(key)
	for e: SlingRig.Entry in g.entries_of(id):
		if e.mode == SlingRig.Mode.STOWED:
			continue
		out += " %s %s ph %.2f" % [SlingRig.Mode.keys()[e.mode], e.role, e.phase]
		if e.flyer and is_instance_valid(e.flyer):
			out += " copy %s" % ("on" if e.flyer.visible else "off")
		if e.mode == SlingRig.Mode.HOLSTER:
			out += " park %.2f hol_min %.3f hol_start %.3f" % [e.park_t, e.hol_min, e.hol_start]
		elif e.mode == SlingRig.Mode.REACH:
			out += " reach_min %.3f" % e.reach_min
	return out


## Whether the weapon `key` shows in a hand: its own model, or, with the gear rig on the body (SlingRig),
## the rig's copy of it being drawn or put away (the rig hides the hand model while its copy does that).
static func _in_hand(player: Node, key: String) -> bool:
	var w: Weapon = player.weapons[key]
	if w.model and w.model.visible:
		return true
	var g: SlingRig = player.get("gear")
	if g == null:
		return false
	var id := g.item_for_key(key)
	if id == "":
		return false
	for e: SlingRig.Entry in g.entries_of(id):
		if e.mode in [SlingRig.Mode.IN_HAND, SlingRig.Mode.HOLSTER, SlingRig.Mode.REACH] and e.flyer and is_instance_valid(e.flyer) and e.flyer.visible:
			return true
	return false


## Waits (at most 5 s) until the lower body has stood in IDLE for 0.3 s (a stop is over).
func _stand(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	await ctx.frames(3)
	var n := 0
	while not (a.loco.state == LocoBrain.IDLE and a.loco.time_in_state >= 0.3) and n < 600:
		await ctx.frames(1)
		n += 1


## Waits (at most max_frames) until no switch runs and the weapon's draw is over.
func _settle_switch(ctx: AnimTestContext, player: Node, max_frames := 600) -> void:
	var n := 0
	while (player.is_switching() or player.weapon.is_equipping()) and n < max_frames:
		await ctx.frames(1)
		n += 1


## A weapon's grip: its prop bone in its wrist's frame (prop <- palm <- wrist; read outside
## skeleton_updated, so before the modifiers, the same way for every sample).
static func _grip(player: Node, w: Weapon) -> Basis:
	var sk: Skeleton3D = player.skeleton
	var side := "l" if w.hand == Weapon.Hand.LEFT else "r"
	var wr := sk.get_bone_global_pose(sk.find_bone(side + "_wrist"))
	var pr := sk.get_bone_global_pose(sk.find_bone(side + "_hand_prop_attachment"))
	return (wr.affine_inverse() * pr).basis.orthonormalized()


static func _deg_between(a: Basis, b: Basis) -> float:
	return rad_to_deg((a.inverse() * b).get_rotation_quaternion().get_angle())


## Start from standing: through the graph start clip the body follows the clip's root-motion speed
## (PlayerAnim.body_speed_cap()) and reaches the target speed as the start ends;
## override_free_start_speed lifts the cap (player.gd's own acceleration).
func _start_speed(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	player.switch_weapon("musket")
	await ctx.frames(240)
	var over := 0.0
	var capped := 0
	var in_start := 0
	var at_end := -1.0
	var tgt := 0.0
	var hz := float(Engine.physics_ticks_per_second)
	var p0: Vector3 = player.global_position
	var d1 := -1.0
	var t90 := -1.0
	Input.action_press("move_forward")
	for f in 360:
		await ctx.frames(1)
		var cap := a.body_speed_cap()
		tgt = float(player.target_speed)
		if f + 1 == int(hz):
			d1 = Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
		if t90 < 0.0 and tgt > 0.0 and float(player.horizontal_speed()) >= 0.9 * tgt:
			t90 = (f + 1) / hz
		if a.loco.state == LocoBrain.START:
			in_start += 1
			if cap < INF:
				capped += 1
				# The body follows the cap one physics tick late (it is read before the tree advances).
				over = maxf(over, float(player.horizontal_speed()) - cap)
		elif in_start > 0 and at_end < 0.0:
			at_end = float(player.horizontal_speed())
	Input.action_release("move_forward")
	await ctx.frames(120)
	ctx.check(in_start > 20 and capped == in_start, "W from standing: the graph start state plays (%d frames) and caps the body speed every frame of it" % in_start)
	ctx.at_most(over, 0.15, "through the start the body speed stays within one tick of the start clip's root-motion speed (m/s over the cap)")
	ctx.near(at_end, tgt, 0.25, "the start ends at the target speed (m/s; %.2f)" % tgt)
	# override_start_rate_boost (on by default, pending the owner's decision) off: the graph's align
	# rate only, the body still on the start clip, a slower start.
	a.override_start_rate_boost = false
	player.yaw += PI    # back along the path just run (room in front)
	await _stand(ctx, player)
	p0 = player.global_position
	var d1s := -1.0
	var t90s := -1.0
	var capped_s := true
	Input.action_press("move_forward")
	for f in 360:
		await ctx.frames(1)
		if f + 1 == int(hz):
			d1s = Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
		if t90s < 0.0 and float(player.target_speed) > 0.0 and float(player.horizontal_speed()) >= 0.9 * float(player.target_speed):
			t90s = (f + 1) / hz
		if a.loco.state == LocoBrain.START:
			capped_s = capped_s and a.body_speed_cap() < INF
	Input.action_release("move_forward")
	await ctx.frames(120)
	ctx.info("musket W from standing, first second / time to 90 %% of %.2f m/s: override_start_rate_boost on (default) %.2f m / %.2f s, off (graph align rate) %.2f m / %.2f s" % [
			tgt, d1, t90, d1s, t90s])
	ctx.check(not a.loco.start_rate_boost and capped_s and d1s > 0.0 and d1s < d1,
			"override_start_rate_boost off: LocoBrain plays the graph's align rate, the body still follows the start clip, and the start is slower (%.2f m < %.2f m in the first second)" % [d1s, d1])
	a.override_start_rate_boost = true
	a.override_free_start_speed = true
	player.yaw += PI
	await _stand(ctx, player)
	Input.action_press("move_forward")
	var fast := -1.0
	var uncapped := true
	for f in 60:
		await ctx.frames(1)
		if fast < 0.0 and float(player.horizontal_speed()) >= 0.9 * float(player.target_speed) and float(player.target_speed) > 0.0:
			fast = f / float(Engine.physics_ticks_per_second)
		if a.loco.state == LocoBrain.START:
			uncapped = uncapped and a.body_speed_cap() == INF
	Input.action_release("move_forward")
	# (a stop after it follows the stop clip: override_crisp_stops is the stop's own override)
	ctx.check(uncapped and fast > 0.0 and fast < 0.35,
			"override_free_start_speed: no cap, 90 %% of the target speed after %.2f s (ground_accel)" % fast)
	a.override_free_start_speed = false
	await ctx.frames(120)


## PlayerAnim.graph_key(): graph keys map to themselves, unknown keys to "", and a roster key the
## graph has no rows for (a weapon installed under another key) to the key its signals are bound with.
func _graph_keys(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	player.weapons["contract_alias"] = player.weapons["musket"]
	ctx.check(a.graph_key("musket") == "musket" and a.graph_key("bow") == "bow" and a.graph_key("nope") == ""
			and a.graph_key("contract_alias") == "musket", "graph_key(): musket, bow, unknown '' and a roster alias -> the key its weapon is bound with (%s)" % a.graph_key("contract_alias"))
	player.weapons.erase("contract_alias")


func _mannequin(ctx: AnimTestContext, player: Node) -> void:
	var a: PlayerAnim = player.anim
	var sk: Skeleton3D = player.skeleton
	var m := BoneMannequin.new()
	sk.get_parent().add_child(m)
	m.build(sk)
	var att := {}
	for n in TORSO:
		var b := sk.find_bone(n)
		if b < 0:
			continue
		var ba := BoneAttachment3D.new()
		ba.bone_name = n
		sk.add_child(ba)
		att[b] = ba
	player.switch_weapon("musket")
	await ctx.frames(150)
	# Aimed strafe left: the stabilizer turns the upper body a lot (plan 6.11).
	Input.action_press("aim")
	Input.action_press("move_left")
	var worst := 0.0
	var worst_at := ""
	var corr := 0.0
	var pre_diff := 0.0
	var n := 0
	for f in 90:
		await ctx.frames(1)
		if f < 60:
			continue
		# Pre-modifier pose (read outside skeleton_updated) for contrast.
		for b in att:
			pre_diff = maxf(pre_diff, sk.get_bone_global_pose(b).origin.distance_to(sk.global_transform.affine_inverse() * (att[b] as Node3D).global_position))
		await ctx.idle_frames(1)
		corr = maxf(corr, a.stabilizer.last_correction_deg())
		var inv := sk.global_transform.affine_inverse()
		for s in m._segments:
			if not att.has(s[0]) or not att.has(s[1]):
				continue
			var mi: MeshInstance3D = s[2]
			var pa: Vector3 = inv * (att[s[0]] as Node3D).global_position
			var pb: Vector3 = inv * (att[s[1]] as Node3D).global_position
			var half: Vector3 = mi.transform.basis.y.normalized() * (pb - pa).length() * 0.5
			var e := maxf((mi.transform.origin - half).distance_to(pa), (mi.transform.origin + half).distance_to(pb))
			n += 1
			if e > worst:
				worst = e
				worst_at = "%s-%s" % [sk.get_bone_name(s[0]), sk.get_bone_name(s[1])]
		for j in m._joints:
			if att.has(j[0]):
				var e2: float = (j[1] as MeshInstance3D).position.distance_to(inv * (att[j[0]] as Node3D).global_position)
				if e2 > worst:
					worst = e2
					worst_at = "joint %s" % sk.get_bone_name(j[0])
	Input.action_release("aim")
	Input.action_release("move_left")
	ctx.check(n > 0, "mannequin torso segments compared (%d samples)" % n)
	ctx.at_least(corr, 10.0, "aimed strafe: the AimStabilizer turns the upper body (deg)")
	ctx.at_least(pre_diff, 0.01, "the pre-modifier torso differs from the stabilized one (m; so the check can tell them apart)")
	ctx.at_most(worst, 0.001, "mannequin capsule endpoints and joints = BoneAttachment3D positions of the stabilized torso (m) [%s]" % worst_at)
	m.queue_free()
	for b in att:
		(att[b] as Node).queue_free()
	await ctx.frames(30)
