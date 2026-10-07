class_name ThuyVanR1Level
extends Node3D
## R1, the Đá Trắng reach, in the Thủy Vân look (scenes/thuyvan_r1.tscn; the launcher tools/thuyvan/play_thuyvan.command
## with "r1"): the vista dressed to the Trường Sơn sheet (docs/thuyvan/plan/look/vista_spec.md) that the player can walk.
## A trimmed copy of ThuyVanLevel (the Still Water greybox) on the region "r1" (data/world/maps/r1/region.json):
##   ground     T4's bake, packed (ThuyVanTerrain: FrontierTerrain's ground on tv_terrain and the painted splat)
##   water      ThuyVanWater (the channels, pounds and falls of water.json in the Thủy Vân river shader); WorldRiver serves
##              the main channel's nodes for the player's river functions
##   dressing   ThuyVanDressing (D1-D21: karst ranks, gorge walls, white stones, the rope bridge and needle, the Two
##              Heights, cliff and stilt houses, the clan house, waystone and flags, banners, lanterns, the survey camp,
##              cairns, mist, PAINT's trees and grass cards)
##   look       ThuyVanLook on the clock's day cycle (the region's "look": "cycle"; owner_answers.md 7)
## Kept from the greybox: the environment rig and clock (the region's latitude, season, start hour), the player with no
## firearms dressed as Mountain Folk, the ambience and footsteps, survival (a new game on the region's day), the pause menu.
## Left out (they need the frontier's species or river: plan M1 ports them): the frontier vegetation, forage, fish,
## birds and fireflies, RiverWater, the year layers and the cordon. No saving.
##
##   F9   S0 <-> S1: the Silent Reach runs or stills (WorldRiver.reach_state and the water's still band)

const Region := preload("res://scripts/world/world_region.gd")
const TerrainScript := preload("res://scripts/thuyvan/world/thuyvan_terrain.gd")
const WaterScript := preload("res://scripts/thuyvan/world/thuyvan_water.gd")
const DressingScript := preload("res://scripts/thuyvan/world/thuyvan_dressing.gd")
const REGION := "r1"
const WELCOME_S := 7.0

var settings: WorldSettings
var environment_rig: EnvironmentRig
var look: ThuyVanLook
var terrain: FrontierTerrain
var water: Node3D
var dressing: Node3D
var player: FrontierPlayer
var survival: SurvivalBridge
var state := "S0"
var _look_key := ""


func _ready() -> void:
	Region.set_region(REGION)
	StartupProfile.mark("boot")
	BackgroundLoad.request(FrontierPlayer.CHARACTER_SCENE)
	StartupPrefetch.start(get_tree())
	settings = WorldSettings.from_args()
	var info := Region.info()
	FrontierTerrain.open_ground = true
	environment_rig = EnvironmentRig.new()
	environment_rig.name = "EnvironmentRig"
	add_child(environment_rig)
	environment_rig.build(settings)
	set_clock(float(info.get("day_of_year", 135.0)), float(info.get("start_hour", 13.0)))
	look = ThuyVanLook.attach(environment_rig)
	StartupProfile.mark("environment")
	terrain = TerrainScript.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(settings)
	StartupProfile.mark("terrain")
	water = WaterScript.new()
	water.name = "Water"
	add_child(water)
	water.call("build", String(info.get("water", "res://data/world/maps/r1/water.json")))
	dressing = DressingScript.new()
	dressing.name = "Dressing"
	add_child(dressing)
	dressing.call("build", settings)
	StartupProfile.mark("dressing")
	_follow_look(true)
	player = FrontierPlayer.new()
	player.name = "Player"
	player.no_firearms = true
	add_child(player)
	_place_player(info)
	StartupProfile.mark("player")
	environment_rig.track(player)
	_audio(player)
	if SurvivalBridge.enabled():
		var pack: Array = player.inventory_pack.duplicate(true)
		survival = SurvivalBridge.new()
		survival.name = "Survival"
		survival.setup(player, environment_rig)
		add_child(survival)
		player.inventory_pack = pack
		survival.new_game(SurvivalBridge.BACKGROUND, {"start_day": String(info.get("start_day", "may_mid")),
				"start_hour": float(info.get("start_hour", 13.0))})
	StartupProfile.mark("survival")
	HitchLog.install(self)
	set_state("S0")
	ThuyVanPreset.dress(player)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(player):
			ThuyVanPreset.dress(player))
	if not SaveGame._is_script_run():
		GameSettings.apply_to(player)
		PauseMenu.install(self, player)
		get_tree().create_timer(2.0).timeout.connect(_welcome)
	StartupProfile.watch(self)


func _process(_delta: float) -> void:
	_follow_look()


## The dressing's mist and the water's tint follow the look the day cycle shows (rebuilt only when its keys change).
func _follow_look(force := false) -> void:
	if look == null or look.current.is_empty():
		return
	var key := str(look.current.get("keys", [])) + str(look.current.get("mist_bands_m", []))
	if key == _look_key and not force:
		return
	_look_key = key
	dressing.call("set_look", look.current)
	water.call("set_sky_tint", look.current.get("water_sky_tint", Color(0.7, 0.85, 0.95)))


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


func set_clock(doy: float, hour: float) -> void:
	var c := clock()
	if c == null:
		return
	c.latitude_deg = float(Region.info().get("latitude_deg", 21.0))
	c.set_date(doy)
	c.set_time(hour)


func clock() -> WorldClock:
	return environment_rig.clock_driver.clock if environment_rig and environment_rig.clock_driver else null


## The player at the region's player_at ([x, z]: the east bridge head), facing player_face.
func _place_player(info: Dictionary) -> void:
	var a: Array = info.get("player_at", [912.0, -1236.0])
	var f: Array = info.get("player_face", [820.0, -1215.0])
	var at := Vector3(float(a[0]), 0.0, float(a[1]))
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	player.global_position = at
	var d := Vector3(float(f[0]), 0.0, float(f[1])) - at
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw


func set_state(s: String) -> void:
	state = s
	WorldRiver.reach_state = s
	if water:
		water.call("set_still_band", WorldRiver.still_band())


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F9 and not k.shift_pressed:
		set_state("S1" if state == "S0" else "S0")
		if player and player.interactor:
			player.interactor.notice("The river is still." if state == "S1" else "The river runs.", 3.0)
		get_viewport().set_input_as_handled()


func _welcome() -> void:
	if not is_instance_valid(player) or player.interactor == null:
		return
	var info := Region.info()
	player.interactor.notice("%s, %s.   Cross the rope bridge; F9 stills the river." % [
			String(info.get("name", "Đá Trắng")), String(info.get("title", "the reach"))], WELCOME_S)


func _exit_tree() -> void:
	WorldRiver.reach_state = ""
	Region.set_region("")
	FrontierTerrain.open_ground = false
