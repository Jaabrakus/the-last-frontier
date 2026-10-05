class_name RingLevel
extends Node3D
## The Tidebreak level (scenes/ring.tscn; the owner, 2026-10-04: the elemental ring sport "Tidebreak", 1v1 first, its team
## structure kept for 3v3; "switch to a elemental avatar the last airbender type of game"): a light scene, NOT the world.
## It builds only what a match needs (the lines of frontier_level.gd that matter here, nothing else):
##   EnvironmentRig   the sky, sun, fog and post (named "EnvironmentRig"), its clock held near noon (ring.json clock_hour)
##                    in clear weather
##   RingArena        the deck over its tank, the ropes, the grates, the stones in their sockets, the stands (RingArena)
##   the player       a FrontierPlayer with no demo horse or wheelbarrow, `arena` set BEFORE it enters the tree (the
##                    contract: player.gd's own arena switch, no guns or throwables, when it has one; a no-op until then),
##                    on spawn(0) (the demo's musket rack and spear barrel taken away: no guns in the arena game); no
##                    fall hurts here (fall_safe_m held high every physics frame, rules.json fall_safe_m: the tank is
##                    the fall, and a launch's landing never hurts)
##   the bending      SwayCaster.install_free, Bending.of(player) (its water meter: the grates are its pools)
##   sound            Sfx, the player's Footsteps (the deck's stone and wood); MusicDirector outside script runs (the
##                    match's own fight cue is RingMode's)
##   settings         GameSettings.apply_to(player) outside script runs (the mouse, the field of view, the volumes)
## WorldRiver.off is set while it stands (no river, and nothing that would read FrontierTerrain's baked data: its 19 MB
## never loads here) and put back as it leaves; FrontierTerrain.open_ground is false (the fort's flat zone is 0 under the
## ring at the origin, so any height_at asked here is 0 without the data).
## The match: MatchSetup.take() at the start (the menu's Begin, or the user arg mode=ring); when a match is asked for (or
## the scene is opened outside a script run) RingMode is installed (its RingRules and RingMenu with it) and the HUD set for
## the arena (FrontierHUD.set_arena, when it has it). A script run without mode=ring (tests/ring/test_ring.gd, the stills)
## gets the bare ring.
## install_mode(node): the match (RingMode) put under the level. first_frame_ms: the time of the first frame (logged
## as "RING first_frame_ms=<ms>").

const DATA_PATH := RingArena.DATA_PATH

var settings: WorldSettings
var environment_rig: EnvironmentRig
var ring: RingArena
var player: FrontierPlayer
var music: Node
var mode: Node
## ms since the engine started when the first frame came (-1 until then).
var first_frame_ms := -1.0


func _ready() -> void:
	StartupProfile.mark("boot")
	process_physics_priority = -10            # (before the player: its fall is judged with the safe drop already raised)
	WorldRiver.off = true
	FrontierTerrain.open_ground = false
	BackgroundLoad.request(FrontierPlayer.CHARACTER_SCENE)
	settings = WorldSettings.from_args()
	environment_rig = EnvironmentRig.new()
	environment_rig.name = "EnvironmentRig"
	add_child(environment_rig)
	environment_rig.build(settings)
	_hold_the_sky()
	StartupProfile.mark("environment")
	ring = RingArena.make(self)
	StartupProfile.mark("structures")
	player = FrontierPlayer.new()
	player.name = "Player"
	player.demo_horse = false
	player.demo_wheelbarrow = false
	player.set(&"arena", true)                # (the contract with player.gd: before _ready builds the weapons)
	add_child(player)
	place(player, ring.spawn(0))
	_no_demo_props.call_deferred()
	StartupProfile.mark("player")
	environment_rig.track(player)
	_audio(player)
	StartupProfile.mark("audio")
	SwayCaster.install_free(player)
	Bending.of(player)
	if not SaveGame._is_script_run():
		GameSettings.apply_to(player)
	if MatchSetup.take() or not SaveGame._is_script_run():
		RingMode.install(self, player, ring)
	StartupProfile.watch(self)
	_first_frame.call_deferred()


func _exit_tree() -> void:
	WorldRiver.off = false


func _physics_process(_dt: float) -> void:
	if player != null and is_instance_valid(player):
		player.fall_safe_m = RingRules.num("fall_safe_m", 100.0)


## `body` (the player, or anyone with a yaw) stood at `xf`: on the deck, facing as it faces, still.
static func place(body: Node3D, xf: Transform3D) -> void:
	body.global_position = xf.origin + Vector3.UP * 0.1
	var f := -xf.basis.z
	var yaw := atan2(-f.x, -f.z)
	if body is FrontierPlayer:
		var p := body as FrontierPlayer
		p.velocity = Vector3.ZERO
		p.yaw = yaw
		p.rotation.y = yaw
		p.pitch = 0.0
	else:
		body.rotation.y = yaw
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO


## The match (RingMode) under the level; the one before it, if any, taken away.
func install_mode(node: Node) -> void:
	if mode != null and is_instance_valid(mode) and mode != node:
		mode.queue_free()
	mode = node
	if node.get_parent() == null:
		add_child(node)


## Noon, clear (ring.json clock_hour): the clock stopped there (DayNight, when drawn; headless has no clock).
func _hold_the_sky() -> void:
	if environment_rig == null or environment_rig.clock_driver == null:
		return
	var clock: WorldClock = environment_rig.clock_driver.clock
	if clock != null:
		clock.running = false
		clock.set_time(RingArena.num("clock_hour", 12.25))
	if environment_rig.clock_driver.has_method(&"force_weather"):
		environment_rig.clock_driver.force_weather("clear")


## Sound (scripts/audio/): the buses and voices, the player's footsteps, the music outside script runs (or with music=on).
func _audio(p: FrontierPlayer) -> void:
	Sfx.setup(self)
	if not SaveGame._is_script_run() or "music=on" in OS.get_cmdline_user_args():
		var md := MusicDirector.new()
		md.name = "MusicDirector"
		md.player = p
		add_child(md)
		music = md
	var steps := Footsteps.new()
	steps.name = "Footsteps"
	steps.player = p
	p.add_child(steps)


## No guns in the arena game (the owner, 2026-10-04): the demo's musket rack and spear barrel the player's interactor sets
## beside a spawn (PlayerInteractor._ensure_demo_props, deferred from the player's _ready, so this comes after it) taken
## away with what stands in them.
func _no_demo_props() -> void:
	for n: Node in get_children():
		if (n is WeaponRack and String(n.name).begins_with("Demo")) or n is PlacedWeapon:
			n.queue_free()


func _first_frame() -> void:
	await get_tree().process_frame
	first_frame_ms = Time.get_ticks_usec() / 1000.0
	print("RING first_frame_ms=%.0f" % first_frame_ms)
