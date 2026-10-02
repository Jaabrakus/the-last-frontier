class_name FrontierPlayer
extends CharacterBody3D
## Third-person frontier player with Counter-Strike style aiming (ported from
## BowLocomotion). The mouse turns the body directly, the crosshair is always
## centered and shots converge on it. Accuracy comes from stance, movement and
## the weapon. Carries a hunting bow, a flintlock musket and a flintlock pistol (keys 1-3), and the
## thrown weapons: a throwing spear, a tomahawk and the atlatl (keys 4-6; ThrowableKit).
##
## The whole player is built in code, so it can be dropped into any scene:
##   var p := FrontierPlayer.new(); add_child(p)
##
## Animation (PlayerAnim, the bundled player graph; plan section 8, WP7): the player publishes
## wish_local / target_speed for the lower body, health with the hurt / died / respawned signals
## (apply_hit(), so Hit.deliver() works on the player; Shift+F9, F10-F12 of the debug overlay go through it),
## plays the graph's weapon switch (holster, finish, grab, then the draw; switch_weapon()), and
## through a graph start clip its body follows the clip's body speed (anim.body_speed_cap(); an
## INFERRED speed: the clip metrics' foot-contact body_profile estimate, not an authored root
## track). The "Gameplay overrides" group holds the departures from the graph: all off (graph-
## faithful) except override_start_rate_boost, which is ON by default pending the owner's decision
## (see its comment; tests/anim/README.md "Documented deviations pending owner decision").

## A hit landed (apply_hit): local_dir = where it came from (x right, y forward; unit, or zero when
## unknown), amount = damage, heavy = amount >= heavy_hit_damage (full-body hit reaction; a light
## hit plays the no-arms additive).
signal hurt(local_dir: Vector2, amount: float, heavy: bool)
## Health reached 0: the death clip plays (by direction and stance) and input is ignored until
## respawn().
signal died(local_dir: Vector2)
## respawn(): alive again, back to idle, the weapon drawn again.
signal respawned

## Shortest draw after a holster phase (s); see switch_weapon().
const MIN_DRAW_S := 0.05
## The default rig (character_scene); the level requests it early (BackgroundLoad).
const CHARACTER_SCENE := "res://characters/Actor_B.tscn"

@export_group("Movement")
@export var walk_speed := 1.6         ## Hold Alt. Slower, quieter and more accurate.
@export var run_speed := 3.6          ## Default, like CS: you run unless you hold walk.
@export var sprint_speed := 5.6       ## Hold Shift. Lowers the weapon.
@export var crouch_speed := 1.4
## While aiming, speed eases down to the pace of the aim-walk clips (measured
## Actor_B walk-fw foot speed ~1.3 m/s) so the feet don't slide.
@export var aim_walk_speed := 1.3
## Weapons aimed on the move at the jog's pace, the legs jogging (user 2026-10-01: "for the bow aim we should unlock the feet
## and have jog be able and for the throwing weapons"): no aim-walk cap for them; PlayerAnim keeps their legs on the jog.
const JOG_AIM_WEAPONS := ["bow", "spear", "tomahawk", "atlatl", "pistol"]
## Their pace aimed on the move, of the jog's (eased in with the aim): one for all of them (user 2026-10-01: the pistol fired from
## the hip kept the whole jog, "slow it down to what the other bowables and throwables are", their draw and wind-up at 0.7).
const JOG_AIM_PACE := 0.7
## While a felling stroke or a melee attack is under way the legs walk at this pace (between the aim-walk and the jog:
## like aiming a gun, not the jog's speed; GatherTools.swinging()).
@export var swing_walk_speed := 2.0
@export var ground_accel := 14.0
@export var ground_decel := 18.0
@export var air_accel := 2.5
@export var jump_velocity := 4.4
@export var stand_height := 1.6
@export var crouch_height := 1.1

@export_group("Look")
## Same units as CS sensitivity (yaw per mouse count = sens * 0.022 degrees).
@export var cs_sensitivity := 2.0
@export var invert_y := false
@export var pitch_limit_deg := 80.0

@export_group("Camera")
## SOCOM 2 style: the camera sits centered behind the player and high above
## the head, so the crosshair is over the character, who stays in the lower
## middle of the screen. The camera orbits a pivot this high above the feet.
@export var eye_height := 2.3
@export var crouch_eye_drop := 0.5
@export var shoulder_offset := 0.0
## (User 2026-10-01: "pann the camera out a little it is a little to close": 3.6 -> 4.1.)
@export var camera_distance := 4.1
## The view's width (deg). (User 2026-10-01: the musket's old right-click zoom, 70 x 0.75, is now the view all the time.)
@export var fov := 52.5
## Aiming (right click; the weapon's aim weight): the camera eases off center over the right shoulder, closer in (user
## 2026-10-01: "the new aim camera view is off center"), and zooms in by this share of the weapon's own aim zoom
## (Firearm.aim_fov_mult; the default view already has the old zoom). Shots still land under the crosshair
## (get_aim_point() casts from the camera's center).
@export var aim_shoulder_offset := 0.55
@export var aim_camera_distance := 2.4
## How much lower the camera sits over the shoulder while aiming (user 2026-10-01: "for the aim right offset lower the
## camera a little"); eased in with the shoulder offset.
@export var aim_eye_drop := 0.35
@export var aim_zoom_share := 0.4
## Seconds the camera takes to move to the shoulder and back.
@export var aim_camera_s := 0.15

@export_group("Health")
@export var max_health := 100.0
## A hit of at least this much damage is heavy: the full-body hit reaction (plan 8.1). Lighter
## hits play the no-arms additive on the upper body.
@export var heavy_hit_damage := 40.0

@export_group("Gameplay overrides")
## Animation overrides of the bundled graph's own behaviour, copied onto PlayerAnim's exports of
## the same name before its setup (off = graph-faithful; all off by default except
## override_start_rate_boost, on pending the owner's decision; see PlayerAnim.DEFAULT_ON). At run
## time use anim.set_option(name, value).
## G1: no start, stop or quick-reversal clips.
@export var override_no_transition_anims := false
## G2: 0.3 s hemisphere crossfade instead of the graph's 0.75 s.
@export var override_fast_hemisphere_fade := false
## G5: no turn-in-place clips.
@export var override_no_idle_turns := false
## G6: movement leaves a landing at once (no m2 >= 10 gate).
@export var override_immediate_land_move := false
## Aim idle -> aimed movement in 0.3 s instead of the graph's 0.5 s.
@export var override_fast_aim_to_move := false
## Plain 0.25 s stand / crouch crossfade instead of the graph's crouch change.
@export var override_crouch_crossfade := false
## 0.3 s into the fall loop instead of pre-fall's 0.5 s.
@export var override_fall_fade := false
## The grip clips drive the hands at full weight instead of the graph's hands layers.
@export var override_exact_hands_grip := false
## Thrown weapons: the wind-up plays the graph's raise clip seeked by the charge instead of the
## graph's aim-in (the aim tree weighted by the weapon's aim).
@export var override_throw_windup_raise := false
## > 0: a fade-0 lower-body join (a one-shot clip's end into its successor) fades this long
## instead of cutting as authored.
@export_range(0.0, 0.5, 0.01, "suffix:s") var join_fade_s := 0.0
## > 0: `moving` stays on this long after the stick is released (a keyboard direction change
## with a gap frame keeps the quick reversal).
@export_range(0.0, 0.3, 0.01, "suffix:s") var stick_release_grace_s := 0.0
## No holster clip before a weapon's draw: today's instant model swap (switch_weapon()).
@export var instant_weapon_switch := false
## Through a graph start clip the body accelerates at ground_accel instead of following the clip's
## body speed (anim.body_speed_cap(); inferred from the foot-contact body_profile): full speed in
## about 0.25 s, the feet slide.
@export var override_free_start_speed := false
## Through a graph stop the body keeps the quick ground_decel (at rest in about 0.2 s from a run) instead of
## following the stop clip's travel (anim.body_speed_cap()); the stop clip's legs then still travel and the
## pelvis slides back over the planted feet (user playtest 2026-09-25).
@export var override_crisp_stops := false
## Below this body speed a stop that follows its clip is at rest (m/s).
const STOP_CREEP_MPS := 0.25
## ON BY DEFAULT, pending the owner's decision (the one override that is): a graph start clip plays
## faster than the graph's align rate where its own (inferred) body speed is below the desired
## speed, up to the locomotion rate clamp 1.75 (plan D9; LocoBrain.start_rate_boost). Run W from a
## stand with the body following the start clip: full speed after 0.64 s (musket) / 0.65 s (bow),
## 2.32 / 2.43 m in the first second (before the graph start, as override_free_start_speed:
## 0.24 / 0.26 s, 2.93 / 3.15 m). Off = graph-faithful (the align rate only): 0.93 / 0.86 s,
## 1.52 / 1.80 m, and tests/smoke_test.gd's movement check (over 2 m) fails.
@export var override_start_rate_boost := true
## A weapon switch keeps the new weapon's equip_time as its whole length: the old weapon's holster
## and the new weapon's draw share it (their clips at up to 4.7x) and there is no finish / grab,
## instead of the graph's holster, finish, grab and draw at the weapons' draw speed
## (switch_weapon(); player.gd only).
@export var override_fast_weapon_switch := false

@export_group("Torch")
## The torch in the off hand (PlayerTorch, push n01b; T takes one out lit / puts it back): torches in the pack at
## the start, a fresh torch's burn time (s of real time), and whether the pistol keeps it (aimed one-handed).
@export var torch_count := 4
@export var torch_burn_s := TorchState.BURN_S
@export var torch_keep_with_pistol := true
## Torch lights cast shadows (one at a time; +0.9 ms a frame in the forest, where the sun's coarse tree shadow
## proxies also shade the ground round the torch). Off by default.
@export var torch_shadows := false
## PlayerAnim's "Torch" exports (the torch's axe and raised holds, the long gun gripped in the middle in the left
## hand), copied onto it before its setup.
@export_range(0.0, 45.0, 1.0, "suffix:deg") var torch_tilt_deg := 30.0
@export_range(0.0, 30.0, 1.0, "suffix:deg") var torch_out_deg := 14.0
@export var torch_fist := Vector3(0.28, -0.1, 0.24)
@export var torch_fist_crouch := Vector3(0.3, 0.06, 0.24)
@export var torch_raise_fist := Vector3(0.12, 0.08, 0.36)
@export_range(0.0, 1.0, 0.01) var torch_arm_swing := 0.45
@export_range(0.0, 30.0, 1.0, "suffix:deg") var gun_mid_pitch_deg := 6.0
@export_range(0.0, 30.0, 1.0, "suffix:deg") var gun_mid_pitch_crouch_deg := 3.0
@export_range(0.1, 0.8, 0.01, "suffix:m") var gun_balance_m := 0.40
@export_range(0.05, 0.5, 0.01, "suffix:s") var torch_toss_release_s := 0.16
## Switching from the musket (or the over-under) to the tomahawk or the spear keeps the gun in the left hand, gripped
## in the middle, and back is quick (QuickOffhand, push n01c); off: every switch slings the gun.
@export var quick_throwables := true

@export_group("Character")
## The rig; empty = CHARACTER_SCENE. Not preloaded (the 77 MB Actor_B animation library is in it):
## the level loads it on a worker thread while it builds the world (BackgroundLoad), and opening
## the level in the editor no longer loads it.
@export var character_scene: PackedScene
@export var model_yaw_offset_deg := 180.0   ## The rig faces +Z; the player faces -Z.
## Draw the skinned body and outfit (CharacterBodyMesh) when `body_path` exists.
## Without it the capsule mannequin is drawn instead.
@export var use_body := true
@export_file("*.glb", "*.gltf", "*.tscn", "*.scn") var body_path := "res://assets/character/actor_b_body.glb"
## Face, skin, eyes and hair from the customizer (PlayerAppearance: the saved look on the body's
## head and hands; O opens the customizer). Off: the legacy body's own head.
@export var use_appearance := true
## Debug: also draw the capsule mannequin that follows the live joints.
@export var show_mannequin := false
## Weapon model placement relative to the hand prop bones. The game's
## weapon-holding clips (aim "--hands" layers, carry "--arms" poses, reload
## parts) animate the prop bones so that prop +Z runs along the barrel and
## +Y is up (measured: within 2-12 degrees of the aim direction). The models
## face -Z, so a fixed half turn about Y maps model axes to prop axes and the
## animations place the weapon in every pose.
@export var bow_offset := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
@export var musket_offset := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
@export var pistol_offset := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)

## Headless tests and screenshots: accept fire input without a captured mouse.
var ignore_mouse_capture := false
## This machine's player (the default): its camera is the view, the mouse turns it, and it has the HUD, the E prompts,
## the equip wheel, building and the debug keys. False (set before it enters the tree): another player on the map,
## driven through `controls` (an AI's, later the network's): none of those (user 2026-09-27, AI duels).
var is_local := true
## Where its keys come from (PlayerControls): the keyboard for this machine's player, else what drives it.
var controls := PlayerControls.new()

var yaw := 0.0
var pitch := 0.0
var is_crouching := false
var is_walking := false
var is_sprinting := false
## The survival core's move_speed_mult and sprint_allowed (hunger, cold, fatigue; SurvivalBridge sets them).
var survival_speed_mult := 1.0
## Iron Man (GameSettings.iron_man): what a wound broke. The legs gone stay so for good (a new game); a broken leg until its
## wound knits.
var maim_legs := false
var broken_leg := false
## FALLS (user 2026-10-01: "fall damage with broken bones if they jump from too high up; the first set is okay to jump down"):
## the highest point since the feet left the ground; a drop past fall_safe_m hurts, FALL_DMG_PER_M a metre past it, and from
## FALL_BREAK_M past it a leg breaks (slowed until it knits). Jumping off a tree's first branches is safe (PlayerGrip sets
## fall_safe_m to that branch's height above the ground).
const FALL_SAFE_M := 4.5
const FALL_DMG_PER_M := 13.0
const FALL_BREAK_M := 3.0
## How long a fall's break slows the player without the survival rules (with them it knits as its leg wound does).
const FALL_BREAK_S := 600.0
var fall_safe_m := FALL_SAFE_M
var _fall_top := -INF
var _break_t := 0.0
var sprint_allowed := true
## Drink and tobacco (Vices): reload stages x this (a pipe: 0.92), the shot spread x this (drunk: 1.25), and the aim's
## slow sway in degrees (drunk).
var reload_time_mult := 1.0
var aim_spread_mult := 1.0
var aim_sway := 0.0
var _sway_t := 0.0
var _sway_off := Vector2.ZERO
## Dragging a carcass on foot (FootDrag) or pushing a wheelbarrow (Wheelbarrow) sets it from the load: the move speed at
## most this (m/s); no sprint.
var drag_speed_cap := INF
## Velocity in local space: x = right, y = forward (m/s).
var local_move := Vector2.ZERO
## Movement wish in local space (m/s; x = right, y = forward): the input direction x the speed the
## player heads for. Zero without input and while dead (read by AnimInputs, plan 8.1).
var wish_local := Vector2.ZERO
## Speed the player heads for (m/s): the speed band after weapon.speed_mult() and the aim cap,
## 0 without input and while dead (the lower body's walk / run choice, plan 6.6).
var target_speed := 0.0
var health := 100.0
var is_dead := false
## What a ranged hit does to a person against a beast (the hunt's numbers): multiplayer fights last a few shots (user 2026-10-01).
const HUMAN_RANGED_MULT := 0.45
## The command mode (F1: the camera over the land, the household commanded like an army: RtsMode).
var rts: RtsMode
var _death_push := Vector3.ZERO      ## the blow that may kill: the push it gives the body (PlayerRagdoll)

var collision: CollisionShape3D
var visual: Node3D
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var skeleton: Skeleton3D
var anim: PlayerAnim
var hud: FrontierHUD

var weapons: Dictionary = {}     ## "bow" / "musket" / "pistol" / "spear" / "tomahawk" / "atlatl" -> Weapon
var weapon_order := ["bow", "musket", "pistol"]
var weapon: Weapon
var weapon_key := ""

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _eye_y := 0.0
var _recoil := Vector2.ZERO      ## Camera kick (pitch, yaw) in radians, recovers over time.
## Weapon switch in progress (switch_weapon()), empty when none: {old: Weapon (its model stays in
## the hand through the holster), old_key: its graph key, key: the new weapon's graph key, t: s
## since the switch, t_finish / t_grab / t_draw: when the finish, the grab and the draw start,
## finish / grab: those stages' seconds, holstered / grabbing: stage flags, fast: the
## override_fast_weapon_switch timing}.
var _sw := {}
## Death during a switch's holster: the old weapon, whose model stays in the dead player's hand
## until respawn().
var _dead_weapon: Weapon
## Everything carried but not in the hands shows on the body (SlingRig: slung long weapons, the quiver,
## the belt pistol, the horn and pouch; data/loadout, the default preset). Off: only the held weapon shows.
@export var show_gear := true
## How the slung musket rides on the back (data/loadout/sling_styles.json): "low" (default: the source
## placement 20 cm lower along the gun, user 2026-09-25) or "high" (the source placement).
@export_enum("low", "high") var musket_sling := "low":
	set(v):
		musket_sling = v
		if gear:
			gear.set_sling_style("musket", v)
## Which kit rides on the body (data/loadout/loadout_presets.json; "" = its default, "musket_bow"). K cycles the
## kits in game (user 2026-09-25: "spears didnt we have them showing at one point": "musket_spears" and
## "woodland_hunter" carry the spear pair on the back). Display only for now: every weapon stays usable.
@export var gear_kit := "":
	set(v):
		gear_kit = v
		if gear:
			_install_gear()
## The body rig of the carried gear (null when show_gear is off).
var gear: SlingRig
## What is worn on the body (InventoryScreen, Tab): only a worn weapon can be drawn; the rest owned is in the pack.
var loadout: Loadout
var inventory_pack: Array = []
var _inv_screen: InventoryScreen
## Weapons the player has with them (roster key -> bool, absent = carried). A weapon put down in the world
## (PlayerInteractor, E) is not carried until it is taken again: its key and the wheel skip it and the gear
## rig hides it.
var carried := {}
## Hands free (H, or nothing left to hold): the weapon is put away on the body, its input is off and both
## arms swing free (PlayerAnim.hands_free). H again, or a weapon key, draws it.
var hands_free := false
## E: the interaction (highlight, prompt, take / swap / place / drop / pick up).
var interactor: PlayerInteractor
var wounds: PlayerWounds
## T: the torch in the left hand (PlayerTorch).
var torch: PlayerTorch
## Gathering: the felling axe (7) and the mattock (8), felling, bucking, breaking stone, the skills (GatherTools).
var gather: GatherTools
## The equip wheel (hold Q; EquipWheel): weapons, tools, the torch and bare hands, picked with the mouse.
var equip_wheel: EquipWheel
## Building (B): log cabins, palisades, chimneys from the pack's logs and stone (BuildMode, scripts/building/).
var building: BuildMode
## E at a dead animal's neck: drag it on foot on a short rope, the right hand free for a torch (FootDrag).
var foot_drag: FootDrag
## E at a log's end: pull it with both hands walking backward, and lay it as a barricade log (LogPull).
var log_pull: LogPull
## The Wheelbarrow being pushed (null: none; it sets drag_speed_cap from its load).
var pushing: Node = null
## Vaulting and climbing (Space at an obstacle; hold Shift to run through them): PlayerTraversal.
@export var enable_traversal := true
var traversal: PlayerTraversal
## The horse the player rides (HorseMount: E mounts, E again dismounts), or null.
var riding: Horse = null
## Kneeling over work on the ground (FieldDressing: skinning, butchering): the node that owns the body. Movement input
## is ignored, the camera orbits the kneeling body, PlayerAnim is suspended (begin_kneel / end_kneel).
var kneeling: Node = null
## Carried by a boat (BoatRider): the boat holds the body where it is (the rider places it every physics frame); walking and jumping are ignored
## unless the rider is `free` (crouched: on their own, carried while on the boat's floor); the crouch, the aim and the weapons are the player's own, so they can
## equip and shoot from the boat.
var aboard: Node = null
## Gripping a surface or a moving body (PlayerGrip, hold G): the node that owns the body while it holds on, or null.
## Movement input goes to the grip, the collision capsule is off, PlayerAnim is suspended (begin_climb / end_climb).
var climbing: Node = null
@export var enable_grip := true
var grip: PlayerGrip
## Crouched on a branch at the top of a trunk (PlayerGrip): the body is the player's own (the weapons aim, fire and throw
## as usual) but it does not walk off the branch: the move keys, sprint and jump are PlayerGrip's there, the crouch stays.
var perch: Node = null
var _pose_gun := ""              ## the weapon put on the body for kneeling or climbing, drawn again after
var _pose_mods: Array = []       ## the skeleton modifiers switched off meanwhile
## A saddled horse near the spawn when the level has none (the demo).
@export var demo_horse := true
## A wheelbarrow by the fort if the level has none (Wheelbarrow.ensure_demo).
@export var demo_wheelbarrow := true
var _rider_link: HorseRiderLink
var _rider_rig: Node3D
var _rider_rig_local: Transform3D
var _ride_gun := ""
## The customizer look on the body (PlayerAppearance), null when use_appearance is off.
var appearance: PlayerAppearance
var _ride_mods: Array = []
var _ride_eye := 0.0
var _ride_back := 0.0
var _aim_cam_w := 0.0               ## how far the camera has gone over the shoulder for the aim (0..1)
const RIDE_CAMERA_BACK := 1.8   ## m further back than on foot


func _ready() -> void:
	InputSetup.ensure()
	add_to_group("player")
	add_to_group(WildlifeSpawner.PEOPLE)   # PEOPLE: one of the humans the wild keeps off (with the household's)
	yaw = rotation.y
	health = max_health
	_build_body()
	_build_camera()
	_build_character()
	# Rest must be the game's bind pose 'null-add' (no-op with the shipped rig; see BindRest).
	BindRest.ensure_character(skeleton.get_parent())
	_build_weapons()
	if show_gear:
		_install_gear()
	if is_local:
		interactor = PlayerInteractor.install(self)
	# bleeding and blunt force (PlayerWounds): a wound's pool drains the health until it closes
	wounds = PlayerWounds.of(self)
	# (bleeding leaves a trail of drops: PlayerBloodTrail)
	PlayerBloodTrail.install(self)
	wounds.bleeding_changed.connect(func(on: bool) -> void:
		if interactor and not is_dead:
			interactor.notice("You are bleeding: rest (Z) or dress the wound" if on else "The bleeding stops", 3.0))
	torch = PlayerTorch.install(self, torch_count, torch_burn_s)
	torch.keep_with_pistol = torch_keep_with_pistol
	torch.shadows = torch_shadows
	gather = GatherTools.install(self)
	foot_drag = FootDrag.install(self)
	log_pull = LogPull.install(self)
	if is_local:
		equip_wheel = EquipWheel.install(self)
		building = BuildMode.install(self)
		rts = RtsMode.install(self)
	if enable_traversal:
		traversal = PlayerTraversal.install(self)
	if enable_grip:
		grip = PlayerGrip.install(self)
	var owns_nothing := SurvivalBridge.bare_ahead()      # (a start with nothing: no demo horse, cart or barrow stands by)
	if demo_horse and not owns_nothing:
		HorseMount.ensure_demo_horse.call_deferred(self)
	if demo_wheelbarrow and not owns_nothing:
		Wheelbarrow.ensure_demo.call_deferred(self)
	_ensure_hands_free_input()
	if is_local:
		HowTo.install(self)                # the first time each thing is done, its keys (HowTo)
		hud = FrontierHUD.new()
		hud.player = self
		add_child(hud)
		var arc := TrajectoryPreview.new()
		arc.name = "TrajectoryPreview"
		arc.player = self
		add_child(arc)
		# Animation debug overlay: F4 panels, Shift+F5, F6-F8, Shift+F9, F10-F12 tools (debug builds only; see
		# AnimDebugOverlay). The overlay owns Shift+F9, F10-F12 (hit / heavy hit / death / respawn, via apply_hit() /
		# respawn()): do not bind them again here (plan 8.1), or every press lands twice.
		AnimDebugOverlay.attach(self)
	switch_weapon("musket")
	# the shots' smoke and flash and the gathering chips compile their particle shaders now, not on first use
	Fx.warm_up.call_deferred(camera)
	if is_local and not "--no-capture" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_body() -> void:
	collision = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	collision.shape = cap
	add_child(collision)
	_set_capsule_height(stand_height)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.position = Vector3(shoulder_offset, 0, 0)
	spring_arm.spring_length = camera_distance
	spring_arm.margin = 0.15
	spring_arm.add_excluded_object(get_rid())
	camera_pivot.add_child(spring_arm)
	camera = Camera3D.new()
	camera.fov = fov
	camera.far = 1500.0
	spring_arm.add_child(camera)
	camera.current = is_local
	_eye_y = eye_height
	camera_pivot.position.y = _eye_y


func _build_character() -> void:
	if character_scene == null:
		character_scene = BackgroundLoad.take(CHARACTER_SCENE) as PackedScene
	var inst := character_scene.instantiate() as Node3D
	inst.rotation.y = deg_to_rad(model_yaw_offset_deg)
	visual.add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	# Skinned body. Its binds come from the rig's bind clip (null-add), not from the
	# live pose or the rest, so this is safe before the AnimationTree exists.
	var body: CharacterBodyMesh = null
	if use_body:
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		body = CharacterBodyMesh.attach(skeleton, aps[0] if not aps.is_empty() else null, body_path)
	if body != null and use_appearance:
		appearance = PlayerAppearance.install(self, skeleton)
	if body == null or show_mannequin:
		var mannequin := BoneMannequin.new()
		inst.add_child(mannequin)
		mannequin.build(skeleton)


func _build_weapons() -> void:
	var holder := Node.new()
	holder.name = "Weapons"
	add_child(holder)
	var defs := {
		"bow": [Bow.new(), "bow", bow_offset],
		"musket": [Musket.new(), "musket", musket_offset],
		"pistol": [FlintlockPistol.new(), "pistol", pistol_offset],
	}
	for key in weapon_order:
		var w: Weapon = defs[key][0]
		w.name = key.capitalize()
		w.player = self
		WeaponBalance.apply(w, key)   # data/weapons/ballistics.json (weapons balance hook H1)
		holder.add_child(w)
		var att := BoneAttachment3D.new()
		att.name = key + "_socket"
		att.bone_name = "l_hand_prop_attachment" if w.hand == Weapon.Hand.LEFT else "r_hand_prop_attachment"
		skeleton.add_child(att)
		var model := WeaponModels.build(defs[key][1])
		model.transform = defs[key][2]
		model.visible = false
		att.add_child(model)
		w.model = model
		w.muzzle = model.get_node("Muzzle")
		weapons[key] = w
	# Thrown weapons on keys 4-6 (spear, tomahawk, atlatl): weapons, sockets and models, balanced
	# (hook H2) and registered in `weapons` / weapon_order before PlayerAnim sees the roster, so the
	# graph's pick-up profiles animate them (throw chain, draw / holster; THROW work package).
	ThrowableKit.install(self, ThrowableKit.KEYS, true)

	var ap := skeleton.get_parent().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	anim = PlayerAnim.new()
	anim.name = "PlayerAnim"
	# Every export of PlayerAnim's "Gameplay overrides" group takes this player's export of the
	# same name (PlayerAnim is built in code, so its own exports cannot be set in the inspector).
	for f in anim.gameplay_override_names() + anim.torch_option_names():
		if f in self:
			anim.set(f, get(f))
	skeleton.get_parent().add_child(anim)
	anim.setup(self, ap, skeleton, weapons)
	quick = QuickOffhand.new(self)


## Weapon switch. The old weapon is put away at once in gameplay terms (Weapon.unequip(): lowered,
## a reload interrupted with its finished stages kept) and `weapon` is the new one; it takes no
## input until its draw is over. Animation, graph-faithful by default (options.holster; plan
## WP10, user requirement 1): the old weapon's holster (its draw clip backwards, at the speed its
## draw plays: over its equip_time; its model stays in the hand), the old weapon's holster finish
## (the empty hand back to idle; the model is put away as it starts), the new weapon's grab (draw
## step 1: the hand from idle to the new weapon) and then the new weapon's draw (Weapon.equip(),
## over its own equip_time; usable when it ends). Each stage starts on the pose the one before
## ends on (as authored); stage lengths: switch_stages(). Opt-in overrides in "Gameplay
## overrides": override_fast_weapon_switch (the old weapon's holster and the new weapon's draw
## share the new weapon's equip_time, holster_phase(); no finish or grab; the weapon usable when
## it was before the graph holster) and instant_weapon_switch (no holster: the models swap at
## once). A switch during the holster or the finish only changes the weapon drawn after it; one
## during the grab grabs the newer weapon instead; one while the old weapon is still being drawn
## holsters it from where its draw is (with override_fast_weapon_switch: swaps at once). No switch
## while dead.
func switch_weapon(key: String) -> void:
	if is_dead or riding != null or not is_usable(key):
		return
	if climbing != null:
		# on a grip the choice is only noted: the weapon stays on the body (hanging, PlayerGrip takes a one-hand weapon
		# into the free hand to aim), and is the one drawn when the climb ends
		if key != weapon_key and weapons.has(key):
			weapon_key = key
			weapon = weapons[key]
			anim.set_weapon(_anim_key(key))
			if _pose_gun != "":
				_pose_gun = key
		return
	if quick != null and quick.intercept(key):
		return
	if not _sw.is_empty():
		_retarget_switch(key)
		return
	if key == weapon_key:
		if hands_free:
			_draw_from_hands_free()
		return
	if not _hands_ready(key):
		return
	if hands_free:
		# drawing another weapon from empty hands: the put-away one stays on the body, no holster
		hands_free = false
		anim.hands_free = false
		weapon = null
		weapon_key = ""
	var old := weapon
	var old_key := weapon_key
	var drawing := old != null and old.is_equipping()
	# How much of its draw the old weapon has played (1 when drawn): a switch during the draw
	# holsters from where the draw is (UpperBody reverses the draw's own OneShot in place).
	var drawn_frac := 1.0
	if drawing and old.equip_time > 0.0:
		drawn_frac = clampf((old.equip_time - old._equip_left) / old.equip_time, 0.0, 1.0)
	if old:
		old.unequip()
	weapon_key = key
	weapon = weapons[key]
	if old and old.model and anim.holster_enabled() and (not drawing or not override_fast_weapon_switch):
		var go := anim.graph_key(old_key)
		var gn := anim.graph_key(key)
		var st := "crouch" if is_crouching else "stand"
		var sw := {}
		if override_fast_weapon_switch:
			var h := holster_phase(anim.data, go, gn, st, weapon.equip_time)
			sw = {"t_finish": h, "t_grab": h, "t_draw": h, "finish": 0.0, "grab": 0.0, "lead": 0.0, "fast": true}
		else:
			var stages := switch_stages(anim.data, go, gn, st, old.equip_time, weapon.equip_time)
			stages.holster = float(stages.holster) * drawn_frac
			sw = _plan_switch(stages)
		if float(sw.t_finish) > 0.0 and anim.play_holster(go, float(sw.t_finish)):
			sw.merge({"old": old, "old_key": go, "key": gn, "t": 0.0, "holstered": false, "grabbing": false}, true)
			_sw = sw
			# the holster clip puts it away; hidden when the finish starts (a thrown weapon's only when it was
			# in the hand: not with none left, nor right after a throw)
			old.model.visible = not (old is Throwable) or (old as Throwable).holster_shows_model()
			return
	anim.set_weapon(_anim_key(key))
	_equip_drawn()


## Stage lengths (s) of a graph weapon switch from old_key to new_key (graph keys): {holster: the
## old weapon's holster clip at the speed its draw plays over old_equip, finish: its holster
## finish at that speed, grab: the new weapon's grab at the speed its draw plays over new_equip,
## draw: new_equip, lead: how long before a forward stage's end the next one starts (its fade-in
## ends halfway through that stage's fade-out, UpperBody.chain_lead)}. A stage with no graph clip
## is 0 (the stand bow's and pistol's finish resolve to their draw clip: it plays forward from
## the held holster, UpperBody continues it on the same OneShot). A forward stage lasts at least
## its fade-in + fade-out + 2 frames (UpperBody's rule for short actions).
static func switch_stages(data: AnimGraphData, old_key: String, new_key: String, stance: String, old_equip: float,
		new_equip: float) -> Dictionary:
	var out := {"holster": 0.0, "finish": 0.0, "grab": 0.0, "draw": new_equip, "lead": 0.0}
	if data == null or old_key == "" or new_key == "":
		return out
	var fade: Array = data.tuning("oneshot_fade", [0.1, 0.15])
	var min_s := float(fade[0]) + float(fade[1]) + 2.0 / 60.0
	out.lead = UpperBody.chain_lead(float(fade[0]), float(fade[1]))
	var od := _graph_action_length(data, old_key, stance, "equip")
	var nd := _graph_action_length(data, new_key, stance, "equip")
	if od > 0.0 and old_equip > 0.0:
		out.holster = old_equip * _graph_action_length(data, old_key, stance, "holster") / od
		var fin := _graph_action_length(data, old_key, stance, "holster_finish")
		if fin > 0.0:
			out.finish = maxf(old_equip * fin / od, min_s)
	if nd > 0.0 and new_equip > 0.0 and float(out.holster) > 0.0:
		var g := _graph_action_length(data, new_key, stance, "grab")
		if g > 0.0:
			out.grab = maxf(new_equip * g / nd, min_s)
	return out


## Seconds of the holster phase of a switch from old_key to new_key that takes `total` seconds (the
## new weapon's equip_time; override_fast_weapon_switch): the old weapon's graph holster clip (its
## draw clip played backwards) and the new weapon's graph draw clip share it in proportion to their
## lengths, so both play at the same rate. 0 (switch at once) when either weapon has no graph clip.
static func holster_phase(data: AnimGraphData, old_key: String, new_key: String, stance: String, total: float) -> float:
	if data == null or old_key == "" or old_key == new_key or total <= 0.0:
		return 0.0
	var lo := _graph_action_length(data, old_key, stance, "holster")
	var ln := _graph_action_length(data, new_key, stance, "equip")
	if lo <= 0.0 or ln <= 0.0:
		return 0.0
	return total * lo / (lo + ln)


static func _graph_action_length(data: AnimGraphData, w: String, stance: String, key: String) -> float:
	var clip: Variant = data.action(w, stance, key).get("partial")
	return data.clip_length(String(clip)) if clip is String else 0.0


## Stage start times of a switch from switch_stages(): the finish at the holster's end (the
## holster holds its last pose, so no lead), the grab and the draw `lead` before the end of the
## forward stage before them.
static func _plan_switch(s: Dictionary) -> Dictionary:
	var t_finish := float(s.holster)
	var t_grab := t_finish + (float(s.finish) - float(s.lead) if float(s.finish) > 0.0 else 0.0)
	var t_draw := t_grab + (float(s.grab) - float(s.lead) if float(s.grab) > 0.0 else 0.0)
	return {"t_finish": t_finish, "t_grab": t_grab, "t_draw": t_draw, "finish": float(s.finish), "grab": float(s.grab),
			"lead": float(s.lead), "fast": false}


## True while a weapon switch runs its holster, finish or grab (the new weapon's draw not started).
func is_switching() -> bool:
	return not _sw.is_empty()


## Timing of the switch in progress (s since the switch; empty when none): {stage, t, t_finish (the
## holster's end), t_grab, t_draw (the new weapon's draw starts), fast}. For code that follows the
## switch (e.g. a sling rig parking the old weapon when its holster ends); holster_phase() is the
## override_fast_weapon_switch timing only.
func switch_timing() -> Dictionary:
	if _sw.is_empty():
		return {}
	return {"stage": switch_stage(), "t": float(_sw.t), "t_finish": float(_sw.t_finish), "t_grab": float(_sw.t_grab),
			"t_draw": float(_sw.t_draw), "fast": bool(_sw.fast)}


## Current stage of the switch in progress: "holster", "finish", "grab" or "" (none).
func switch_stage() -> String:
	if _sw.is_empty():
		return ""
	if not bool(_sw.holstered):
		return "holster"
	return "grab" if bool(_sw.grabbing) else "finish"


## A second switch while one runs: the weapon drawn after it changes; during the grab the newer
## weapon's grab starts now instead. Once the holster is over (finish, grab) PlayerAnim already
## plays the previous target's carry and grip, so it takes the newer weapon now. The weapon already
## targeted (same roster and graph key) changes nothing: its grab is not restarted.
func _retarget_switch(key: String) -> void:
	var gn := anim.graph_key(key)
	if key == weapon_key and gn == String(_sw.key):
		return
	var same_clips := gn == String(_sw.key)
	var nw: Weapon = weapons[key]
	weapon_key = key
	weapon = nw
	_sw.key = gn
	if bool(_sw.holstered):
		anim.set_weapon(_anim_key(key))
	if bool(_sw.fast):
		return
	if same_clips and bool(_sw.grabbing):
		return    # another roster weapon on the same graph clips: its grab is already playing
	var st := "crouch" if is_crouching else "stand"
	var s := switch_stages(anim.data, String(_sw.old_key), gn, st, (_sw.old as Weapon).equip_time, nw.equip_time)
	var lead := float(_sw.lead)
	_sw.grab = float(s.grab)
	if bool(_sw.grabbing):
		_sw.t_grab = float(_sw.t)
		if float(s.grab) > 0.0:
			anim.play_switch_stage(gn, "grab", float(s.grab))
	else:
		_sw.t_grab = float(_sw.t_finish) + (float(_sw.finish) - lead if float(_sw.finish) > 0.0 else 0.0)
	_sw.t_draw = float(_sw.t_grab) + (float(s.grab) - lead if float(s.grab) > 0.0 else 0.0)


## Runs the switch in progress `delta` further: its stages start at their times (see
## _plan_switch()), and at t_draw the new weapon is drawn (with the fast override over what is
## left of its equip_time, at least MIN_DRAW_S; else over its full equip_time).
func _tick_switch(delta: float) -> void:
	_sw.t = float(_sw.t) + delta
	var t := float(_sw.t) + 1e-4
	if not bool(_sw.holstered) and t >= float(_sw.t_finish):
		_holstered()
		if float(_sw.finish) > 0.0:
			anim.play_switch_stage(String(_sw.old_key), "holster_finish", float(_sw.finish))
	if bool(_sw.holstered) and not bool(_sw.grabbing) and t >= float(_sw.t_grab) and float(_sw.grab) > 0.0 and t < float(_sw.t_draw):
		_sw.grabbing = true
		anim.play_switch_stage(String(_sw.key), "grab", float(_sw.grab))
	if bool(_sw.holstered) and t >= float(_sw.t_draw):
		var fast := bool(_sw.fast)
		var used := float(_sw.t)
		var to_quick := bool(_sw.get("quick", false))
		_sw = {}
		if to_quick and quick != null:
			quick._finish_back()    # the long gun back from the left hand: no draw
			return
		var full := weapon.equip_time
		if fast:
			weapon.equip_time = maxf(full - used, MIN_DRAW_S)
		_equip_drawn()
		weapon.equip_time = full


## End of the holster: the old model is put away and the animation takes the new weapon.
func _holstered() -> void:
	_sw.holstered = true
	var old: Weapon = _sw.old
	if old and old.model:
		old.model.visible = false
	anim.set_weapon(_anim_key(weapon_key))


## The key PlayerAnim plays a roster key under (PlayerAnim.graph_key(); the roster key itself when
## the graph has no rows for it).
func _anim_key(key: String) -> String:
	var g := anim.graph_key(key) if anim else ""
	return g if g != "" else key


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := deg_to_rad(cs_sensitivity * 0.022)
		# Zoomed steady aim turns proportionally slower.
		k *= camera.fov / fov
		yaw -= event.relative.x * k
		pitch -= event.relative.y * k * (-1.0 if invert_y else 1.0)
		pitch = clampf(pitch, -deg_to_rad(pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	else:
		for i in weapon_order.size():
			var slot := "weapon_%d" % (i + 1)
			if InputMap.has_action(slot) and event.is_action_pressed(slot):
				switch_weapon(weapon_order[i])
		if event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_prev"):
			_wheel_step(1 if event.is_action_pressed("weapon_next") else -1)
		if InputMap.has_action(HANDS_FREE) and event.is_action_pressed(HANDS_FREE):
			toggle_hands_free()
		if InputMap.has_action(&"anatomy") and event.is_action_pressed(&"anatomy"):
			toggle_anatomy()
		if InputMap.has_action(INVENTORY) and event.is_action_pressed(INVENTORY) and not is_dead and riding == null \
				and (_inv_screen == null or not is_instance_valid(_inv_screen)):
			get_viewport().set_input_as_handled()
			_inv_screen = InventoryScreen.open_for(self)
		elif InputMap.has_action(SKILLS) and event.is_action_pressed(SKILLS) and not is_dead and riding == null \
				and (_inv_screen == null or not is_instance_valid(_inv_screen)):
			get_viewport().set_input_as_handled()
			_inv_screen = InventoryScreen.open_for(self, "skills")


const HANDS_FREE := &"hands_free"
const INVENTORY := &"inventory"
## K: the character screen on its Skills tab (InventoryScreen, SkillsPanel).
const SKILLS := &"skills"


## Registers H for hands free, Tab for the character screen and K for its Skills tab unless the project already has
## the actions (input_setup.gd is not changed).
static func _ensure_hands_free_input() -> void:
	for pair in [[HANDS_FREE, KEY_H], [INVENTORY, KEY_TAB], [SKILLS, KEY_K]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var e := InputEventKey.new()
		e.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], e)


## (Re)builds the body rig for gear_kit (the data's default kit when it names none).
func _install_gear() -> void:
	var data := LoadoutData.get_default()
	var id := gear_kit if not data.preset(gear_kit).is_empty() else data.default_preset()
	apply_loadout(Loadout.from_preset(id), [])


## Wears `lo` (InventoryScreen on close): the body rig shows it. Every weapon the player has stays usable
## (user 2026-09-25: "right now all unlocked"); the inventory only arranges what rides on the body. `pack`
## is kept for the screen.
func apply_loadout(lo: Loadout, pack: Array = []) -> void:
	loadout = lo
	inventory_pack = pack.duplicate(true)
	if show_gear:
		gear = SlingRig.install(self, lo, {"sling_styles": {"musket": musket_sling}})


func is_carried(key: String) -> bool:
	return bool(carried.get(key, true))


## Whether the weapon `key` can be drawn: carried, and for a thrown weapon one left to throw (none left: its
## key, the wheel and H pass it by; user 2026-09-25: no "phantom placeholder" when the tomahawks run out).
func is_usable(key: String) -> bool:
	if not weapons.has(key) or not is_carried(key):
		return false
	var w: Weapon = weapons[key]
	return not (w is Throwable and (w as Throwable).count <= 0)


## Marks a weapon as with the player or not (PlayerInteractor: put down / taken). Putting down the one in
## the hand draws the next carried weapon (no holster: it is already out of the hand), or leaves the hands
## free when there is none; with `next_in_hand` false the hands stay as they are (PlayerRagdoll: the weapon knocked
## out of them, the player down and getting up empty-handed).
func set_carried(key: String, on: bool, next_in_hand := true) -> void:
	carried[key] = on
	# the worn loadout follows: a weapon put down comes off the body, one taken goes where it fits
	var k := String(InventoryState.KIND_OF_KEY.get(key, ""))
	if loadout and k != "":
		var it := loadout.first_of_kind(k)
		if not on and not it.is_empty():
			loadout.remove_item(String(it.id))
			if show_gear:
				gear = SlingRig.install(self, loadout, {"sling_styles": {"musket": musket_sling}})
		elif on and it.is_empty():
			var r := LoadoutRules.can_carry(loadout, k)
			if bool(r.get("ok", false)) and String(r.get("action", "")) in ["stow", "count"] and not (r.get("points", []) as Array).is_empty():
				loadout.add_item(k, r.points, 1)
			elif bool(r.get("ok", false)) and String(r.get("action", "")) == "stow" and String(r.get("point", "")) != "":
				loadout.add_item(k, [String(r.point)], 1)
			if show_gear:
				gear = SlingRig.install(self, loadout, {"sling_styles": {"musket": musket_sling}})
	if on or key != weapon_key or not next_in_hand:
		return
	_leave_hand()


## The weapon in the hand is gone from it (put down, or the last one thrown): the next usable weapon is drawn
## (no holster: nothing is in the hand to put away), or the hands go free when there is none.
func _leave_hand() -> void:
	if weapon:
		weapon.unequip()
	var next := _next_carried(weapon_key)
	if next == "":
		hands_free = true
		anim.hands_free = true
		return
	var gone := weapon
	var gone_key := weapon_key
	weapon = null
	weapon_key = ""
	switch_weapon(next)
	if weapon == null:
		# the draw could not start now (the hands busy: a torch hand-over; it is held and retried, _retry_held_switch):
		# meanwhile the hands are free with the put-down weapon as the last one, as when none is left (with no weapon
		# at all, movement and the anim read a null weapon every frame; user 2026-09-28)
		weapon = gone
		weapon_key = gone_key
		hands_free = true
		anim.hands_free = true


## Seconds the hand stays empty after the last spear / tomahawk / dart is thrown before the next weapon is drawn.
const EMPTY_SWITCH_S := 0.35
var _empty_t := 0.0


## The last thrown weapon of its kind has left the hand (EMPTY): after EMPTY_SWITCH_S the next usable weapon is
## drawn, or the hands go free (user 2026-09-25: no phantom in the hand when the throwables run out).
func _switch_when_empty(delta: float) -> void:
	var t := weapon as Throwable
	if t == null or hands_free or not t.active or t.state != Throwable.State.EMPTY or t.count > 0:
		_empty_t = 0.0
		return
	_empty_t += delta
	if _empty_t >= EMPTY_SWITCH_S:
		_empty_t = 0.0
		if quick != null and quick.on_empty():
			return    # back to the long gun in the left hand
		_leave_hand()


## The next usable weapon in weapon_order after `from` ("" when none).
func _next_carried(from: String) -> String:
	var i := weapon_order.find(from)
	for n in weapon_order.size():
		i = (i + 1) % weapon_order.size()
		var k: String = weapon_order[i]
		if k != from and is_usable(k):
			return k
	return ""


## H: put the weapon in the hand away on the body (hands free), or draw it again.
## The mouse wheel: the weapons in their order, then the tools the player owns (GatherTools.ORDER; user 2026-09-26),
## round again; unusable weapons and tools not owned are passed by.
func _wheel_step(step: int) -> void:
	var ring: Array = []
	for k: String in weapon_order:
		ring.append(k)
	var tools_on := gather != null and is_instance_valid(gather)
	if tools_on:
		for t: String in GatherTools.ORDER:
			ring.append("tool:" + t)
	var cur := ("tool:" + gather.in_hand()) if tools_on and gather.in_hand() != "" else weapon_key
	var i := ring.find(cur)
	for n in ring.size():
		i = (i + step + ring.size()) % ring.size()
		var e := String(ring[i])
		if e.begins_with("tool:"):
			if gather.owns(e.trim_prefix("tool:")):
				gather.take_out(e.trim_prefix("tool:"))
				return
		elif is_usable(e):
			if tools_on and gather.in_hand() != "":
				gather.put_away()
			if e == weapon_key and hands_free:
				_draw_from_hands_free()
			else:
				switch_weapon(e)
			return


func toggle_hands_free() -> void:
	if is_dead or riding != null or is_switching():
		return
	if hands_free:
		if is_usable(weapon_key):
			_draw_from_hands_free()
		else:
			var next := _next_carried(weapon_key)
			if next != "":
				switch_weapon(next)
		return
	if weapon == null or not weapon.active or not is_carried(weapon_key):
		return
	if quick != null:
		quick.drop()    # the long gun in the left hand goes on the back with it
	if not _hands_ready(HELD_H):
		return
	hands_free = true
	anim.hands_free = true
	var gk := anim.graph_key(weapon_key)
	if gk != "":
		anim.play_holster(gk, maxf(weapon.equip_time, 0.3))
	if gear:
		gear.sling_all()
	weapon.unequip()


func _draw_from_hands_free() -> void:
	if torch_blocks():
		torch.drop_then_draw()   # the torch leaves the left hand first; PlayerTorch draws when it has let go
		return
	if not _hands_ready(weapon_key):
		return
	hands_free = false
	anim.hands_free = false
	if weapon == null:
		return
	anim.set_weapon(_anim_key(weapon_key))
	weapon.equip()


## The quick throwables (push n01c, QuickOffhand): the long gun kept in the left hand while a tomahawk or spear is
## out ("" none; SlingRig counts it in the hand, not on the back).
var offhand_key := ""
var quick: QuickOffhand


## A weapon switch, H or a draw waits for the hands (push n01c, HandHolds.ready_for_switch()): the torch goes to the
## hand the holster and the draw leave free and the long gun back from the left hand to the right; it starts by
## itself when they are (_physics_process retries `_held_switch`: a key, or HELD_H for H).
const HELD_H := "~H"
var _held_switch := ""


func _hands_ready(key: String) -> bool:
	var h: HandHolds = anim.holds if anim else null
	if h == null or h.ready_for_switch("" if key == HELD_H else key):
		if h:
			h.pending = false
		_held_switch = ""
		return true
	h.pending = true
	h.pending_key = "" if key == HELD_H else key
	_held_switch = key
	return false


func _retry_held_switch() -> void:
	if _held_switch == "":
		return
	if is_dead or riding != null:
		_held_switch = ""
		if anim and anim.holds:
			anim.holds.pending = false
		return
	var k := _held_switch
	if k == HELD_H:
		toggle_hands_free()
	elif k == weapon_key and hands_free:
		_draw_from_hands_free()
	else:
		switch_weapon(k)


## The weapon about to be drawn needs the left hand the torch is in (the bow): it stays on the body instead.
func torch_blocks() -> bool:
	return torch != null and torch.blocks(weapon)


## The switched-to weapon is drawn, or with the torch in the left hand a left-hand weapon (the bow) stays on the
## body (hands free, that weapon chosen; drawing it tosses the torch, PlayerTorch).
func _equip_drawn() -> void:
	if torch_blocks():
		hands_free = true
		anim.hands_free = true
		if gear:
			gear.sling_all()
		return
	weapon.equip()


func _physics_process(delta: float) -> void:
	_sway(delta)
	_skirt_tuck(delta)
	# Recoil kicks the view and then settles back most of the way.
	var settle := 1.0 - exp(-7.0 * delta)
	var back := _recoil * settle
	_recoil -= back
	pitch = clampf(pitch - back.x * 0.75, -deg_to_rad(pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	yaw -= back.y * 0.75

	# Dead: the body keeps its facing and the camera orbits it; input is ignored until respawn().
	var orbit := 0.0
	if is_dead or kneeling != null:
		orbit = wrapf(yaw - rotation.y, -PI, PI)
	else:
		rotation.y = yaw
	var tremble := Vector2.ZERO
	if weapon is Bow:
		tremble = (weapon as Bow).tremble_offset()
	camera_pivot.rotation = Vector3(pitch + tremble.x, tremble.y + orbit, 0)
	_retry_held_switch()
	if quick != null:
		quick.tick(delta)
	if riding != null:
		_fall_top = -INF
		_ride(delta)
		return
	if kneeling != null:
		_fall_top = -INF
		velocity = Vector3.ZERO
		target_speed = 0.0
		wish_local = Vector2.ZERO
		# knocked down (PlayerRagdoll): G by a wild horse still takes its mane, up onto its back (HorseBreaking)
		if grip and kneeling is PlayerRagdoll and controls.just_pressed(&"grip"):
			HorseBreaking.try_grab(self)
		return
	# Gripping (PlayerGrip): G held at a grippable surface; while it holds on it moves the body itself.
	if grip and grip.tick(delta):
		target_speed = 0.0
		wish_local = Vector2.ZERO
		_fall_top = -INF        # (held on: a fall is measured from where the grip lets go)
		return
	_track_fall(delta)

	var input := Vector2.ZERO if is_dead or perch != null or (aboard != null and not bool(aboard.get(&"free"))) else controls.move_vector()
	# Crouch is a toggle. Sprinting or jumping stands you back up.
	var want_crouch := is_crouching
	if controls.just_pressed(&"crouch") and not is_dead:
		want_crouch = not is_crouching
	if want_crouch and not is_dead and (controls.just_pressed(&"jump") or (controls.pressed(&"sprint") and input.y < -0.1)):
		want_crouch = false
	if perch != null:
		want_crouch = true
	if want_crouch != is_crouching:
		if want_crouch or _can_stand():
			is_crouching = want_crouch
			_set_capsule_height(crouch_height if is_crouching else stand_height)

	# (no slow walk on foot: user 2026-10-01, "remove the walk for alt"; Alt is still the horse's walking gait, Horse)
	is_walking = false
	is_sprinting = controls.pressed(&"sprint") and input.y < -0.1 \
			and not is_crouching and weapon.can_sprint() and is_on_floor() and not is_dead and sprint_allowed \
			and drag_speed_cap >= sprint_speed

	var speed := run_speed
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed
	elif is_walking:
		speed = walk_speed
	if not is_sprinting:
		speed *= weapon.speed_mult()
		if not weapon_key in JOG_AIM_WEAPONS:
			speed = lerpf(speed, minf(speed, aim_walk_speed), weapon.aim)
		else:
			speed = lerpf(speed, minf(speed, run_speed * JOG_AIM_PACE), weapon.aim)
		# (reloading the musket on the move: the aim walk's pace, its legs, UpperBody.reload_walk)
		if weapon is Firearm and (weapon as Firearm).state == Firearm.State.RELOADING and weapon_key == "musket":
			speed = minf(speed, aim_walk_speed)
		if gather != null and gather.swinging():
			speed = minf(speed, swing_walk_speed)
	speed *= survival_speed_mult * _maim_speed()
	speed = minf(speed, drag_speed_cap)
	# For the lower body (plan 8.1): the band speed whenever there is input; the analog magnitude
	# scales the wish only, as `target` below.
	var has_input := input.length_squared() > 0.0
	target_speed = speed if has_input else 0.0
	wish_local = Vector2(input.x, -input.y).limit_length(1.0) * speed if has_input else Vector2.ZERO

	var wish := global_basis * Vector3(input.x, 0.0, input.y)
	wish.y = 0.0
	var target := wish.limit_length(1.0) * speed
	# Vaulting and climbing (PlayerTraversal): the controller reads the input first; while a move plays it
	# moves the body itself.
	var owned := false
	if traversal and perch == null:
		owned = traversal.pre({"move": input, "sprint": controls.pressed(&"sprint") and not is_dead, "walk": is_walking,
				"jump": controls.just_pressed(&"jump") and not is_dead, "crouch": controls.just_pressed(&"crouch") and not is_dead,
				"crouched": is_crouching, "yaw": yaw}, delta)
	# Graph start clips (user requirement 1): through a start from standing the body moves at the
	# start clip's body speed, assuming body motion follows the animation (INFERRED
	# root motion: the clips have no root track, the speed is the metrics' foot-contact
	# body_profile estimate; up to it at once, down at ground_decel; a start whose clip overshoots
	# mid-way moves faster than the target for a moment), and reaches the target speed as the clip
	# ends (INF otherwise, and with override_free_start_speed). Stops follow the stop clip the same way
	# (user playtest 2026-09-25: stopping in 0.2 s at ground_decel under a stop clip that still travels
	# slid the pelvis back, "a whole like backwards step"): along the way the body is going, never faster
	# than it goes now; override_crisp_stops keeps ground_decel.
	if not owned:
		var cap := anim.body_speed_cap() if anim else INF
		var horiz := Vector3(velocity.x, 0.0, velocity.z)
		var stopping := false
		if cap < INF and wish.length_squared() > 1e-8:
			target = wish.normalized() * cap
		elif cap < INF and not has_input and horiz.length() > 1e-3:
			# (the stop clip's standing tail: its inferred body speed keeps a little noise, no creep under it)
			var v := minf(cap, horiz.length())
			target = horiz.normalized() * (v if v >= STOP_CREEP_MPS else 0.0)
			stopping = true
		# on the approach to a planned move: eased down to the move's entry speed at its start point
		if traversal and has_input:
			var va: float = traversal.approach_speed(horiz.length(), delta)
			if va < target.length():
				target = target.normalized() * va
		var accel := ground_accel if target.length() > horiz.length() else ground_decel
		if cap < INF and (target.length() >= horiz.length() or stopping):
			accel = INF
		if not is_on_floor():
			accel = air_accel
		# INF (follow the start clip at once) x a zero delta (Engine.time_scale 0) would be NaN.
		horiz = target if is_inf(accel) else horiz.move_toward(target, accel * delta)
		velocity.x = horiz.x
		velocity.z = horiz.z

		if is_on_floor() and perch == null:
			if controls.just_pressed(&"jump") and not is_crouching and not is_dead and (aboard == null or bool(aboard.get(&"free"))) \
					and (traversal == null or traversal.allows_jump()):
				velocity.y = jump_velocity
		else:
			velocity.y -= _gravity * delta

		if traversal and perch == null and aboard == null:
			traversal.step_assist(wish, delta)
		move_and_slide()
		local_move = Vector2(velocity.dot(global_basis.x), velocity.dot(-global_basis.z))
	if traversal:
		traversal.post(owned, delta)

	var eye_target := eye_height - (crouch_eye_drop if is_crouching else 0.0) \
			- aim_eye_drop * smoothstep(0.0, 1.0, _aim_cam_w)
	_eye_y = lerpf(_eye_y, eye_target, 1.0 - exp(-12.0 * delta))
	camera_pivot.position.y = _eye_y

	# the aim's camera: over the right shoulder and closer in while the weapon aims (not riding: the ride has its own)
	# (the aim button only: firing from the hip raises the gun's aim too, and the view stays centered for it, user 2026-10-01
	# "left click I don't want it off center")
	var aiming_cam := weapon != null and weapon.active and not hands_free and riding == null \
			and Input.is_action_pressed("aim") and weapon.aim > 0.3
	_aim_cam_w = move_toward(_aim_cam_w, 1.0 if aiming_cam else 0.0, delta / maxf(aim_camera_s, 0.01))
	if riding == null and spring_arm != null:
		spring_arm.spring_length = cam_distance_now()
		spring_arm.position.x = cam_shoulder_now()
	# (no shake while sprinting: user 2026-10-01, "the screen shake on sprint is bad")
	var fov_target := fov * (1.0 - (1.0 - weapon.fov_mult()) * aim_zoom_share)
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-10.0 * delta))

	# A switch runs its stages; the new weapon is drawn when they end (see switch_weapon()) and
	# until then takes no input, as while drawing. Dead: no weapon input either.
	if not _sw.is_empty() and not is_dead:
		_tick_switch(delta)
	if _sw.is_empty() and not is_dead:
		# (a slung weapon takes no input: with the hands free, H or everything on the back, the fire and aim buttons
		# still fired the musket, drew the bow and threw the tomahawk; user 2026-09-26)
		if weapon.active and not hands_free:
			weapon.tick(delta)
		_switch_when_empty(delta)
	# Aim calibration: turn the body so the weapon (not the chest) faces the crosshair. The
	# graph-driven PlayerAnim's AimStabilizer trim does this on the upper body instead.
	visual.rotation.y = 0.0 if anim.trims_aim() else deg_to_rad(weapon.aim_yaw_offset()) * weapon.aim


func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	var kick := Vector2(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg))
	pitch = clampf(pitch + kick.x, -deg_to_rad(pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	yaw += kick.y
	_recoil += kick


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Damage from Hit.deliver() (or the debug overlay's F9-F11). `direction` is the travel direction
## of what hit (the hit came from -direction; from `point` when that is zero). The player's own
## shots never hurt it. Emits hurt, or died when health reaches 0.
func apply_hit(damage: float, point: Vector3, direction: Vector3, source: Node = null, _part := "body") -> void:
	if is_dead or damage <= 0.0 or source == self:
		return
	# another machine's player (NetSession): this machine's own shots and blows go to that machine, which takes them; it
	# is never hurt here
	if has_meta(&"net_peer"):
		NetSession.forward_hit(self, damage, point, direction, source, _part)
		return
	var from := -direction
	if from.length_squared() < 1e-8:
		from = point - global_position
	var local := Vector2(from.dot(global_basis.x), from.dot(-global_basis.z))
	local = local.normalized() if local.length_squared() > 1e-8 else Vector2.ZERO
	# its channel through the body, on the skeleton map (a bite from an animal has none), and what it went through decides
	# the damage (Anatomy.effect: the heart, the brain, the lungs, the gut, the cord, a bone)
	var fx := {}
	if not (source is WildAnimal) and skeleton != null and direction.length_squared() > 1e-8 and PlayerWounds.kind_of(source) == "bleed":
		var an := Anatomy.attach_to(skeleton)
		if an:
			an.add_wound(point, direction, damage)
			fx = Anatomy.effect(an.last_hits, damage)
			# a ball or an arrow into a person does HUMAN_RANGED_MULT of what it does to a beast (the hunt is balanced for those):
			# a plain body shot is two or three hits and the rest bleeds out; the brain is still instant, the heart still mortal
			damage *= float(fx.dmg_mult) * HUMAN_RANGED_MULT
			if bool(fx.lethal):
				# (the brain: it is over)
				health = 0.0
				_die(local)
				return
	# what the blow does to the body if it kills: pushed the way it went (a ball hard, an arrow light)
	_death_push = direction.normalized() * clampf(damage * 0.1, 1.5, 7.0) + Vector3.UP * 1.0 if direction.length_squared() > 1e-8 \
			else Vector3.ZERO
	# a bleeding wound takes part of it now and keeps the rest as blood still to lose (PlayerWounds); blunt force all now
	var now := wounds.take(damage, source, point, direction, float(fx.get("bleed_mult", 1.0)), float(fx.get("drain_mult", 1.0))) if wounds else damage
	health = maxf(health - now, 0.0)
	if health <= 0.0:
		_die(local)
	else:
		hurt.emit(local, damage, damage >= heavy_hit_damage)
		if not fx.is_empty():
			_maim(fx)


## A wound that went through the cord or a limb's bone leaves the body maimed (Anatomy.effect): the cord below the chest takes
## the legs (crawling at a fraction of a walk; respawn clears it), a broken leg bone slows, and the cord throws the player
## down where they stand.
func _maim(fx: Dictionary) -> void:
	var iron := GameSettings.iron_man()
	var limb := String(fx.limb)
	if float(fx.mortal_s) > 0.0:
		# mortal: on their feet a few seconds yet (the heart, the cord high up): time to answer back; in Iron Man staggering
		wounds.set_mortal(float(fx.mortal_s))
		if interactor:
			interactor.notice("Mortally wounded", 3.0)
		Anatomy.slowmo(get_tree())
	if bool(fx.legs):
		# the cord: thrown down; in Iron Man the legs are gone for good
		if iron:
			maim_legs = true
		if interactor:
			interactor.notice("Your legs will not answer" if iron else "Thrown down", 4.0)
		knock_down(Vector3.ZERO)
	elif iron and (limb.contains("femur") or limb.contains("shin") or limb.contains("foot")):
		broken_leg = true
		if interactor:
			interactor.notice("%s broken" % limb, 3.0)


## The speed Iron Man's injuries leave (1 with it off, or unhurt): the legs gone for good, a leg broken until its wound has
## knit (LastingConditions), a mortal wound's stagger.
func _maim_speed() -> float:
	var iron := GameSettings.iron_man()
	var m := 1.0
	if iron and maim_legs:
		m = 0.15
	if broken_leg:
		var b := SurvivalBridge.find(get_tree())
		# (a fall's break without the survival rules knits on a clock: FALL_BREAK_S)
		var open := (b == null or b.lasting == null) and _break_t > 0.0 or (b != null and b.lasting != null and (b.lasting.has_wound("l_leg") or b.lasting.has_wound("r_leg")))
		if open:
			m = minf(m, 0.55)
		else:
			broken_leg = false
	if iron and wounds and wounds.mortal():
		m = minf(m, 0.5)
	return m


## The skeleton map under every body on or off (Anatomy): the player's, and the wild animals' near enough to see.
func toggle_anatomy() -> void:
	var on := not Anatomy.shown
	if on:
		Anatomy.attach_to(skeleton)
		for n in get_tree().get_nodes_in_group(&"wildlife"):
			var sk = n.get(&"_skel")
			if sk is Skeleton3D and n is Node3D and (n as Node3D).global_position.distance_to(global_position) < 60.0:
				Anatomy.attach_to(sk)
	Anatomy.set_shown(on, get_tree())


## Knocked down and thrown with velocity `v` (m/s): a ragdoll, then the game's get-up clip (PlayerRagdoll; user
## 2026-09-27, the mammoth's blows). False when it cannot be now (dead, riding, climbing, kneeling, mid-vault, already
## down): the caller may push the player instead.
func knock_down(v: Vector3) -> bool:
	return PlayerRagdoll.of(self).knock(v)


## A closed skirt (a petticoat) is tucked up at the front while climbing: a ladder (traversal CLIMB), a trunk or a giant
## (PlayerGrip), a branch (perch); at the back in the tandem crawl; let down again after (CharacterBodyMesh.skirt_tuck,
## skirt_tuck_back; the user 2026-09-29: "for climbing and ladder ... the skirt rolls up at the front", "for the crawl
## yoga pose we need the back skirt up towards the lower back"). The tandem partner's breeches go down to the knees.
func _skirt_tuck(delta: float) -> void:
	var body := appearance.body if appearance else null
	if body == null:
		return
	# the partner in a tandem pose (kneeling behind the crawl, the plank over Happy Baby: the lead's FrontierTandem is
	# his `kneeling`, he its companion): the breeches down at the knees (PlayerAppearance.set_pants_down)
	appearance.set_pants_down(kneeling != null and kneeling.get(&"companion") == self and bool(kneeling.get(&"joined"))
			and not str(kneeling.get(&"mode")).is_empty())
	if not body.skirt_closed:
		return
	var up := climbing != null or perch != null or (traversal != null and traversal.controller != null
			and traversal.controller.mode == TraversalController.Mode.CLIMB)
	body.skirt_tuck = move_toward(body.skirt_tuck, 1.0 if up else 0.0, delta / 0.5)
	# on all fours in the tandem crawl (FrontierTandem: `kneeling`, its mode) the back is rolled up to the lower back
	var back := kneeling != null and str(kneeling.get(&"mode")) == "crawl"
	body.skirt_tuck_back = move_toward(body.skirt_tuck_back, 1.0 if back else 0.0, delta / 0.5)
	appearance.set_rolled(body.skirt_tuck_back > 0.5)


## Too much drink: the aim wanders, slow and uneven (two waves on yaw and pitch), by `aim_sway` degrees. Only the change
## of the wave is added each frame, so the view does not drift away.
func _sway(delta: float) -> void:
	if aim_sway <= 0.0 and _sway_off == Vector2.ZERO:
		return
	_sway_t += delta
	var want := Vector2(sin(_sway_t * 0.9) + 0.4 * sin(_sway_t * 2.3 + 1.0), 0.6 * sin(_sway_t * 0.7 + 2.0) + 0.3 * sin(_sway_t * 1.9)) \
			* deg_to_rad(aim_sway) if not is_dead else Vector2.ZERO
	if aim_sway <= 0.0:
		want = _sway_off.move_toward(Vector2.ZERO, deg_to_rad(1.0) * delta)
	var d := want - _sway_off
	_sway_off = want
	yaw += d.x
	pitch += d.y


## The fall since the feet left the ground (FALLS): measured at the landing from the highest point reached.
func _track_fall(delta: float) -> void:
	_break_t = maxf(_break_t - delta, 0.0)
	if is_dead:
		_fall_top = -INF
		return
	if not is_on_floor():
		_fall_top = maxf(_fall_top, global_position.y)
		return
	if _fall_top == -INF:
		return
	var drop := _fall_top - global_position.y
	_fall_top = -INF
	var safe := fall_safe_m
	fall_safe_m = FALL_SAFE_M
	var over := drop - safe
	if over > 0.0:
		_fall_hurt(over)


## Landed `over` m past the safe drop: hurt, and from FALL_BREAK_M a leg broken (the survival rules keep it as a leg wound that
## knits; without them it mends in FALL_BREAK_S); a long fall kills.
func _fall_hurt(over: float) -> void:
	var dmg := FALL_DMG_PER_M * over + 4.0
	health = maxf(health - dmg, 0.0)
	hurt.emit(Vector2.ZERO, dmg, true)
	var b := SurvivalBridge.find(get_tree())
	if over >= FALL_BREAK_M:
		broken_leg = true
		_break_t = FALL_BREAK_S
		var side := "l_leg" if randf() < 0.5 else "r_leg"
		if b and b.lasting:
			b.lasting.hit(side, "front", "blunt", maxf(dmg, 20.0))
		if interactor:
			interactor.notice("You land hard: your %s leg is broken" % ("left" if side == "l_leg" else "right"), 4.0)
	elif interactor:
		interactor.notice("You land hard", 2.0)
	if health <= 0.0:
		if b:
			b.death_cause = "a fall"
		_death_push = Vector3.ZERO
		_die(Vector2.ZERO)


## Blood lost from a bleeding wound (PlayerWounds): the health drains; at none the player has bled to death.
func lose_blood(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		var b := SurvivalBridge.find(get_tree())
		if b:
			b.death_cause = "bleeding"
			if b.sleeper and b.sleeper.sleeping:
				b.sleeper.stop_now()
		if interactor:
			interactor.notice("You bled to death", 4.0)
		_death_push = Vector3.ZERO
		_die(Vector2.ZERO)


## Back to full health and alive where the player lies; the weapon is drawn again (the new one,
## when the player died during a switch). By design a cut (plan 6.4: LocoBrain.revive() takes idle
## with no fade; there is no graph record for a respawn): the lower body goes from the death pose
## to idle and the body turns to the camera's yaw (it kept its facing while the camera orbited
## the corpse) in one frame, as on a teleport.
func respawn() -> void:
	health = max_health
	broken_leg = false
	if wounds:
		wounds.clear()
	if not is_dead:
		return
	is_dead = false
	var rag := get_node_or_null(^"Ragdoll") as PlayerRagdoll
	if rag and rag.is_down():
		rag.recover_now()          # up from where the body lies: the player's own animation and the weapon back
	var retake := false
	if _dead_weapon != null:
		if _dead_weapon != weapon:
			if _dead_weapon.model:
				_dead_weapon.model.visible = false
			retake = true
		_dead_weapon = null
	respawned.emit()
	# Died during a switch's holster: PlayerAnim kept the old weapon's carry and grip on the corpse
	# (its model was in the hand); the new weapon's are taken now, before its draw.
	if retake:
		anim.set_weapon(_anim_key(weapon_key))
	if weapon and not weapon.active:
		weapon.equip()


## Death: lowered and quiet (a draw, reload or shot in progress is dropped, as on a switch), and
## what is in the hand stays there as the body falls: the current weapon's model, or during a
## switch's holster the old weapon (its model, and PlayerAnim keeps its carry and grip; respawn()
## takes the new one), and during the finish or grab nothing (the old model is put away and the
## new weapon is only reached by its draw). The switch ends there; respawn() draws the new weapon.
func _die(local_dir: Vector2) -> void:
	# a ragdoll, carried on by the way it was going and the blow that killed (when it cannot be: the death clip)
	var ragdolled := PlayerRagdoll.of(self).knock(_death_push + Vector3(velocity.x, 0.0, velocity.z) * 0.6, true)
	_death_push = Vector3.ZERO
	is_dead = true
	is_sprinting = false
	is_walking = false
	target_speed = 0.0
	wish_local = Vector2.ZERO
	var in_hand := weapon
	if not _sw.is_empty():
		var old: Weapon = _sw.old
		var holstered := bool(_sw.holstered)
		_sw = {}
		if not holstered:
			in_hand = old
			_dead_weapon = old
		else:
			in_hand = null
			if old and old.model and old != weapon:
				old.model.visible = false
	if weapon and weapon.active:
		weapon.unequip()
	if ragdolled:
		in_hand = null          # (slung on the body with the ragdoll)
	if in_hand and in_hand.model:
		in_hand.model.visible = not (in_hand is Throwable) or (in_hand as Throwable).death_shows_model()
	died.emit(local_dir)


## Elevation (radians, + = up) from the chest to what the crosshair is on,
## used for the aim-pitch layer so the weapon points at the target rather than
## along the camera (the camera sits above the character).
func aim_pitch() -> float:
	var chest := global_position + Vector3.UP * (1.35 if not is_crouching else 0.95)
	var d := get_aim_point() - chest
	return atan2(d.y, Vector2(d.x, d.z).length())


## The camera's distance behind and its offset to the right now: the default view's, eased toward the aim's (PlayerGrip's
## branch camera starts from these).
func cam_distance_now() -> float:
	return lerpf(camera_distance, aim_camera_distance, smoothstep(0.0, 1.0, _aim_cam_w))


func cam_shoulder_now() -> float:
	return lerpf(shoulder_offset, aim_shoulder_offset, smoothstep(0.0, 1.0, _aim_cam_w))


## Where the crosshair points in the world. Shots are launched from the muzzle
## toward this point, so they land under the crosshair (not offset by the
## shoulder camera).
func get_aim_point(max_dist := 600.0) -> Vector3:
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_dist)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else from + dir * max_dist


func _can_stand() -> bool:
	var from := global_position + Vector3.UP * crouch_height
	var to := global_position + Vector3.UP * (stand_height + 0.05)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Crouched or standing at once (PlayerGrip on a branch); standing only where there is room.
func set_crouched(on: bool) -> void:
	if on == is_crouching or (not on and not _can_stand()):
		return
	is_crouching = on
	_set_capsule_height(crouch_height if on else stand_height)


func _set_capsule_height(h: float) -> void:
	var cap := collision.shape as CapsuleShape3D
	cap.height = h
	collision.position.y = h * 0.5


# --- riding ---------------------------------------------------------------------------------

## Mounts `h` (HorseMount, E): the weapon goes onto the body, PlayerAnim and its modifiers pause, the player's
## rig sits on the saddle (HorseRiderLink plays the riding clips at the horse's phase) and the horse takes the
## riding input. The change of pose is inertialized (PlayerTraversal's TravInertializer).
func mount(h: Horse) -> bool:
	if riding != null or h == null or is_dead or is_switching() or climbing != null:
		return false
	if traversal and traversal.showing:
		return false
	if weapon and weapon.active and not hands_free:
		_ride_gun = weapon_key
		hands_free = true
		anim.hands_free = true
		if gear:
			gear.sling_all()
		weapon.unequip()
	riding = h
	spring_arm.add_excluded_object(h.get_rid())   # the horse's own body does not pull the camera in
	velocity = Vector3.ZERO
	_set_body_collision(false)
	anim.auto_process = false
	_ride_mods.clear()
	for c in skeleton.get_children():
		if c is SkeletonModifier3D and not (c is CharacterBodyMesh) and not (c is TravInertializer) and (c as SkeletonModifier3D).active:
			(c as SkeletonModifier3D).active = false
			_ride_mods.append(c)
	if traversal and traversal.inert:
		traversal.inert.start(0.4)
	_rider_rig = skeleton.get_parent() as Node3D
	while _rider_rig != null and _rider_rig.get_parent() != visual:
		_rider_rig = _rider_rig.get_parent() as Node3D
	_rider_rig_local = _rider_rig.transform
	var ap := anim.get_node(anim.anim_player) as AnimationPlayer
	_rider_link = HorseRiderLink.new()
	_rider_link.name = "RiderLink"
	h.add_child(_rider_link)
	_rider_link.attach(h, _rider_rig, ap)
	h.player_input = true
	var m := h.get_node_or_null("Mount") as HorseMount
	if m:
		m.rider = self
	return true


## Off the horse on its left (its dismount point), the player's own animation and weapon back.
func dismount() -> void:
	var h := riding
	if h == null:
		return
	h.player_input = false
	h.drive(0.0, 0.0)
	var m := h.get_node_or_null("Mount") as HorseMount
	if m:
		m.rider = null
	if _rider_link:
		_rider_link.horse = null   # no last sync onto the saddle before it goes
		_rider_link.set_physics_process(false)
		if _rider_link.blender and _rider_link.blender.tree and is_instance_valid(_rider_link.blender.tree):
			_rider_link.blender.tree.active = false
			_rider_link.blender.tree.queue_free()
		_rider_link.queue_free()
		_rider_link = null
	_rider_rig.top_level = false
	_rider_rig.transform = _rider_rig_local
	_ride_eye = 0.0
	_ride_back = 0.0
	spring_arm.spring_length = camera_distance
	spring_arm.remove_excluded_object(h.get_rid())
	var side := Horse.LEFT
	var at := h.get_dismount_point(side).origin
	riding = null
	global_position = at + Vector3.UP * 0.05
	velocity = Vector3.ZERO
	_set_body_collision(true)
	for c in _ride_mods:
		if is_instance_valid(c):
			(c as SkeletonModifier3D).active = true
	_ride_mods.clear()
	anim.auto_process = true
	if traversal and traversal.inert:
		traversal.inert.start(0.4)
	if _ride_gun != "":
		var k := _ride_gun
		_ride_gun = ""
		if hands_free and weapon_key == k and is_usable(k):
			_draw_from_hands_free()


## Kneels for work on the ground (FieldDressing): the weapon goes to the body (drawn again by end_kneel), the body
## turns to face `face_at`, PlayerAnim and the skeleton modifiers are suspended as on horseback (the caller drives the
## pose on the returned AnimationPlayer, e.g. through a HorsePhaseBlender), the traversal inertializer smooths the
## change. Returns null (nothing changed) when the player cannot kneel now.
func begin_kneel(by: Node, face_at: Vector3) -> AnimationPlayer:
	if kneeling != null or climbing != null or riding != null or is_dead or is_switching() or (traversal and traversal.showing):
		return null
	kneeling = by
	var to := face_at - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		rotation.y = atan2(-to.x, -to.z)
		yaw = rotation.y                  # the camera swings round behind the player: the work in view
	velocity = Vector3.ZERO
	return _suspend_pose()


## PlayerAnim and the skeleton modifiers off, the weapon in the hands onto the body: the caller drives the pose on the
## returned AnimationPlayer (kneeling, climbing). The traversal inertializer smooths the change.
func _suspend_pose() -> AnimationPlayer:
	if weapon and weapon.active and not hands_free:
		_pose_gun = weapon_key
		hands_free = true
		anim.hands_free = true
		if gear:
			gear.sling_all()
		weapon.unequip()
	anim.auto_process = false
	_pose_mods.clear()
	for c in skeleton.get_children():
		if c is SkeletonModifier3D and not (c is CharacterBodyMesh) and not (c is TravInertializer) and (c as SkeletonModifier3D).active:
			(c as SkeletonModifier3D).active = false
			_pose_mods.append(c)
	if traversal and traversal.inert:
		traversal.inert.start(0.35)
	return anim.get_node(anim.anim_player) as AnimationPlayer


## The player's own animation and the weapon back (end_kneel, end_climb).
func _resume_pose(inert_s := 0.35) -> void:
	for c in _pose_mods:
		if is_instance_valid(c):
			(c as SkeletonModifier3D).active = true
	_pose_mods.clear()
	anim.auto_process = true
	if traversal and traversal.inert:
		traversal.inert.start(inert_s)
	if _pose_gun != "":
		var k := _pose_gun
		_pose_gun = ""
		if hands_free and weapon_key == k and is_usable(k) and not is_dead:
			_draw_from_hands_free()


## Up from kneeling: the player's own animation and the weapon back; the camera yaw keeps the body's facing.
func end_kneel() -> void:
	if kneeling == null:
		return
	kneeling = null
	yaw = rotation.y
	_resume_pose()


## Gripping (PlayerGrip): the grip owns the body: the collision capsule off (the body goes where the hands hold),
## the pose suspended as for kneeling. Returns null (nothing changed) when the player cannot grip now.
func begin_climb(by: Node) -> AnimationPlayer:
	if climbing != null or kneeling != null or riding != null or is_dead or (traversal and traversal.showing):
		return null
	climbing = by
	_set_body_collision(false)
	return _suspend_pose()


## Off the grip (standing up on a top, or letting go): the capsule, the player's own animation and the weapon back.
func end_climb(inert_s := 0.35) -> void:
	if climbing == null:
		return
	climbing = null
	_set_body_collision(true)
	_resume_pose(inert_s)


## Riding: the body (and the camera with it) goes with the horse; the camera sits higher.
func _ride(delta: float) -> void:
	if not is_instance_valid(riding):
		riding = null
		return
	# G riding alongside a wild horse: over onto its back (HorseBreaking; on one being ridden out, G lets go)
	if grip and controls.just_pressed(&"grip") and HorseBreaking.try_grab(self):
		if riding == null:
			return
	global_position = riding.global_position
	_ride_eye = lerpf(_ride_eye, 1.25, 1.0 - exp(-4.0 * delta))
	camera_pivot.position.y = _eye_y + _ride_eye
	# the camera further back on horseback (the horse fills the view; user 2026-09-25)
	_ride_back = lerpf(_ride_back, RIDE_CAMERA_BACK, 1.0 - exp(-4.0 * delta))
	spring_arm.spring_length = camera_distance + _ride_back


func _set_body_collision(on: bool) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred(&"disabled", not on)
