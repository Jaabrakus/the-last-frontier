class_name ThuyVanLevel
extends Node3D
## Thủy Vân's Still Water greybox (scenes/thuyvan_preview.tscn; plan phase 1, T5; the launcher is
## tools/thuyvan/play_thuyvan.command): today's valley and river re-lit as a tropical early-rains morning, played as an
## ordinary Mountain Folk body with no guns, and a reach of the river that stops when the world goes from S0 to S1.
## A trimmed copy of frontier_level.gd. The region (WorldRegion "r1_grey": data/world/maps/r1_grey/) is set before anything
## of the world is read, so the squares, the river (with its still reach) and the year layers are the region's; the
## ground is today's baked valley.
##
## Kept, as the frontier builds them: the environment rig (the clock set from the region: latitude ~21 N, the early rains,
## the morning), the terrain (grown over: no fort, FrontierTerrain.open_ground), the river, the vegetation, survival (a new
## game on the region's day), forage, the fish, fishing, birds and fireflies, the ambience and the footsteps, the pause
## menu.
## Left out: the fort and its structures and furnishing, the household, the tandem and puppy features, the story (its
## director and slice), the wonder sky, the wildlife spawner (its animals are North American), the Sway, farming, snow,
## fire, co-op, the music, the weapon sounds, and SaveGame (no saving in the greybox: the frontier's saves are never
## touched; the pause menu says saving is off).
##
##   F9   S0 <-> S1 in place (a raw key, not an input action): the river's still reach (WorldRiver.reach_state: the flow,
##        the water's look and sound, the fish), the year layer (StoryLayer S0 / S1), the held mist (ThuyVanStillReach)
##        and the cordon (ThuyVanCordon: S1 only)
## The player: FrontierPlayer.no_firearms (no musket or pistol, no gun gear; the bow, the thrown weapons, the tools and
## every world screen stay) dressed as Mountain Folk (ThuyVanPreset; the look on file is not changed).
## The level's rng (seed 1776) is the vegetation's.

const Region := preload("res://scripts/world/world_region.gd")
const REGION := "r1_grey"
const STATES := ["S0", "S1"]
const START_STATE := "S0"
## The greybox's place card at the start (the HUD's notice), and how long it shows.
const WELCOME_S := 7.0

var rng := RandomNumberGenerator.new()
var settings: WorldSettings
var environment_rig: EnvironmentRig
## The Thủy Vân look (ThuyVanLook), when the region names one; null otherwise.
var look: ThuyVanLook
var terrain: FrontierTerrain
var vegetation: FrontierVegetation
var river: RiverWater
var player: FrontierPlayer
var survival: SurvivalBridge
var fish: FishLife
var still: ThuyVanStillReach
var cordon: ThuyVanCordon
## The world's state now ("S0" running, "S1" still) and its year layer.
var state := ""
var layer: StoryLayer


func _ready() -> void:
	Region.set_region(REGION)
	StartupProfile.mark("boot")
	BackgroundLoad.request(FrontierPlayer.CHARACTER_SCENE)
	StartupPrefetch.start(get_tree())
	rng.seed = 1776
	settings = WorldSettings.from_args()
	var info := Region.info()
	FrontierTerrain.open_ground = true          # (no fort in Thủy Vân: its clearing and the range lane grown over)
	environment_rig = EnvironmentRig.new()
	environment_rig.name = "EnvironmentRig"
	add_child(environment_rig)
	environment_rig.build(settings)
	set_clock(float(info.get("day_of_year", 135.0)), float(info.get("start_hour", 6.25)))
	# the Thủy Vân look over the rig (sky, sun, fog, grade), only when the region's block names one ("look": a
	# direction or "cycle"); without it the rig is the frontier's, as before
	look = ThuyVanLook.attach(environment_rig)
	StartupProfile.mark("environment")
	terrain = FrontierTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(settings)
	StartupProfile.mark("terrain")
	if WorldRiver.has_water():
		river = RiverWater.new()
		river.name = "River"
		add_child(river)
	vegetation = FrontierVegetation.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.build(settings, rng)
	StartupProfile.mark("vegetation")
	player = FrontierPlayer.new()
	player.name = "Player"
	player.no_firearms = true
	add_child(player)
	_place_player(info)
	StartupProfile.mark("player")
	environment_rig.track(player)
	_audio(player)
	StartupProfile.mark("audio")
	# survival: the core's new game on the region's day and morning (the bridge's own start is the frontier's September)
	if SurvivalBridge.enabled():
		var pack: Array = player.inventory_pack.duplicate(true)
		survival = SurvivalBridge.new()
		survival.name = "Survival"
		survival.setup(player, environment_rig)
		add_child(survival)
		player.inventory_pack = pack
		survival.new_game(SurvivalBridge.BACKGROUND, {"start_day": String(info.get("start_day", "may_mid")),
				"start_hour": float(info.get("start_hour", 6.25))})
	StartupProfile.mark("survival")
	HitchLog.install(self)
	var forage := ForageField.new()
	forage.name = "Forage"
	add_child(forage)
	forage.build(vegetation)
	StartupProfile.mark("forage")
	if WorldRiver.has_water():
		fish = FishLife.new()
		fish.name = "Fish"
		fish.setup(player, environment_rig)
		add_child(fish)
	FishingGear.install(player)
	if BirdLife.enabled():
		var birds := BirdLife.new()
		birds.name = "BirdLife"
		birds.setup(player, vegetation, environment_rig)
		add_child(birds)
		var ff := Fireflies.new()
		ff.name = "Fireflies"
		ff.player = player
		ff.environment_rig = environment_rig
		add_child(ff)
	StartupProfile.mark("wildlife")
	# the still reach's stones and held mist, and S1's cordon
	var reaches := WorldRiver.reaches()
	still = ThuyVanStillReach.new()
	still.name = "StillReach"
	still.setup(reaches[0] if not reaches.is_empty() else {})
	add_child(still)
	cordon = ThuyVanCordon.new()
	cordon.name = "Cordon"
	cordon.setup(player, StoryLayer.load_layer("S1").get("cordon", {}))
	add_child(cordon)
	set_state(START_STATE, true)
	# the body: Mountain Folk (again a moment on, after the survival kit has dressed what it dresses)
	ThuyVanPreset.dress(player)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(player):
			ThuyVanPreset.dress(player))
	if not SaveGame._is_script_run():
		GameSettings.apply_to(player)
		PauseMenu.install(self, player)
		get_tree().create_timer(2.0).timeout.connect(_welcome)
	StartupProfile.watch(self)


## Sound (scripts/audio/): buses and voice pool, the ambience, the footsteps. No music, no weapon sounds.
func _audio(p: FrontierPlayer) -> void:
	Sfx.setup(self)
	var bed := AmbienceBed.new()
	bed.name = "AmbienceBed"
	bed.player = p
	add_child(bed)
	var steps := Footsteps.new()
	steps.name = "Footsteps"
	steps.player = p
	p.add_child(steps)


## The sky's clock at the region (its latitude) on day `doy` at `hour` (no clock headless). With survival on, the core's
## calendar drives it from then on (the same day: the region's start_day).
func set_clock(doy: float, hour: float) -> void:
	var c := clock()
	if c == null:
		return
	c.latitude_deg = float(Region.info().get("latitude_deg", 21.0))
	c.set_date(doy)
	c.set_time(hour)


func clock() -> WorldClock:
	return environment_rig.clock_driver.clock if environment_rig and environment_rig.clock_driver else null


## The player on the region's start place by the river (player_at), facing player_face.
func _place_player(info: Dictionary) -> void:
	var at := _river_point(info.get("player_at", {"river_z": -14.0, "river_d": -24.0}))
	var face := _river_point(info.get("player_face", {"river_z": -95.0, "river_d": 0.0}))
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	player.global_position = at
	var d := face - at
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw


## {river_z, river_d} (d m along x from the river's centre at z) as a point on the map (y 0).
static func _river_point(v: Variant) -> Vector3:
	if v is Dictionary:
		var z := float((v as Dictionary).get("river_z", 0.0))
		return Vector3(WorldRiver.x_at(z) + float((v as Dictionary).get("river_d", 0.0)), 0.0, z)
	return Vector3.ZERO


## The world's state in place: the river's still reach, the year layer, the held mist, the cordon. `instant`: no fades
## (the start, the shots, the tests).
func set_state(s: String, instant := false) -> void:
	if s == state or not s in STATES:
		return
	state = s
	WorldRiver.reach_state = s
	for other: String in STATES:
		var old := get_node_or_null(StoryLayer.NODE_PREFIX + other)
		if other != s and old != null:
			remove_child(old)
			old.queue_free()
	layer = StoryLayer.apply(self, s)
	var band := WorldRiver.still_band()
	if river:
		river.still_snap = instant
	if still:
		still.set_still(not band.is_empty(), instant)
	if cordon:
		cordon.set_active(s == "S1")


func toggle_state() -> void:
	set_state("S1" if state == "S0" else "S0")
	if player and player.interactor:
		player.interactor.notice("The river is still." if state == "S1" else "The river runs.", 3.0)


## F9 (a raw key: the input map is the loop's): S0 <-> S1. Shift+F9 is the animation debug overlay's.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F9 and not k.shift_pressed:
		toggle_state()
		get_viewport().set_input_as_handled()


func _welcome() -> void:
	if not is_instance_valid(player) or player.interactor == null:
		return
	var info := Region.info()
	player.interactor.notice("%s, %s. The early rains.   Walk to the river; F9 stills the water." % [
			String(info.get("name", "Đá Trắng")), String(info.get("title", "the reach"))], WELCOME_S)


func _exit_tree() -> void:
	# (the next scene, the frontier's main menu or level, reads today's world again)
	WorldRiver.reach_state = ""
	Region.set_region("")
	FrontierTerrain.open_ground = false
