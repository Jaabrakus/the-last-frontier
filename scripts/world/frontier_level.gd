extends Node3D
## Test level: a small colonial stockade fort in a forest clearing, with a
## shooting range outside the north gate. Everything is built in code by the environment
## builders below; this script only wires them together, adds the player and the audio.
##
##   Fort: 32 m square palisade, gate in the north wall, two blockhouses,
##         a cabin, a storehouse, crates, barrels and a flag.
##   Range: firing line just outside the gate, straw dummies at 10-120 m,
##          one moving dummy, straw trusses for cover.
##   Forest: trees all around, leaving the range lane clear.
##
## Environment build order (look-dev spec, graph_analysis/visual/lookdev_spec.md, section 11):
##   WorldSettings.from_args()        quality preset (quality=low|medium|high, default high)
##   EnvironmentRig.build()           sky, sun, fog, post, viewport settings     (package A)
##   FrontierTerrain.build()          ground, grass, ground colliders            (package B)
##   RiverWater                       the river's water where it has ground (WorldRiver), wading, drinking
##   FrontierStructures.build()       fort, range, dummies, props (scripts/world/structures/, D)
##   FrontierVegetation.build()       trees, undergrowth, logs, rocks            (package C)
##   SurvivalBridge                   hunger, warmth, rest, the kit; the core's clock drives the sky (scripts/survival_game)
##   ForageField.build()              berries, nuts and herbs where they grow (scripts/forage; its own seed)
##   WildlifeSpawner                  deer, bucks, foxes, wolves (scripts/wildlife; off in -s tool / test runs)
##   FishLife                         the river's fish near the player: rising, schooling, spooking, taking bait
##   FishingGear                      fishing: the rod and line, the spear (8 the gear button)
##   BirdLife, Fireflies              owls, flocks, fireflies (scripts/wildlife; off in -s tool / test runs)
## The level's rng (seed 1776) is shared by the structures and the vegetation, in that order.

const FORT_HALF := FrontierStructures.FORT_HALF
const GATE_HALF := FrontierStructures.GATE_HALF
const FIRING_LINE_Z := FrontierStructures.FIRING_LINE_Z
const RANGE_DISTANCES := FrontierStructures.RANGE_DISTANCES

var rng := RandomNumberGenerator.new()
var settings: WorldSettings
var environment_rig: EnvironmentRig
var terrain: FrontierTerrain
var structures: FrontierStructures
var vegetation: FrontierVegetation


func _ready() -> void:
	StartupProfile.mark("boot")
	# Faster loading: the player's rig (77 MB of animation) and the level's meshes, textures and
	# sounds load on worker threads while the world is built (BackgroundLoad, StartupPrefetch).
	BackgroundLoad.request(FrontierPlayer.CHARACTER_SCENE)
	StartupPrefetch.start(get_tree())
	rng.seed = 1776
	settings = WorldSettings.from_args()
	environment_rig = EnvironmentRig.new()
	environment_rig.name = "EnvironmentRig"
	add_child(environment_rig)
	environment_rig.build(settings)
	StartupProfile.mark("environment")
	terrain = FrontierTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(settings)
	StartupProfile.mark("terrain")
	# the river's water where it has ground (WorldRiver: the open land east of the fort)
	if WorldRiver.has_water():
		var river := RiverWater.new()
		river.name = "River"
		add_child(river)
	structures = FrontierStructures.new()
	structures.name = "Structures"
	add_child(structures)
	structures.build(settings, rng)
	StartupProfile.mark("structures")
	vegetation = FrontierVegetation.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.build(settings, rng)
	StartupProfile.mark("vegetation")
	var player := FrontierPlayer.new()
	player.name = "Player"
	for preview_arg in ["--tandem-preview", "--tandem-preview-yoga"]:
		if preview_arg in OS.get_cmdline_user_args():
			player.show_gear = false # clean previews of the tandem poses
	add_child(player)
	player.global_position = Vector3(0, 0.1, 6)
	# In-world tandem poses (isolated feature branch). Uses the existing pose handoff.
	# (a broken feature script must not stop the level: the game would show a gray screen)
	var tandem_script := load("res://features/tandem/frontier_tandem.gd") as GDScript
	if tandem_script != null and tandem_script.can_instantiate():
		var tandem: Node = tandem_script.new()
		tandem.player = player
		player.add_child(tandem)
	else:
		push_error("Tandem poses did not load; the level goes on without them.")
	StartupProfile.mark("player")
	environment_rig.track(player)
	_audio(player)
	StartupProfile.mark("audio")
	# survival (scripts/survival_game): the core (needs, the clock, the kit) through its one bridge; the core drives
	# the sky's clock (off in -s tool / test runs unless they pass survival=on)
	if SurvivalBridge.enabled():
		var survival := SurvivalBridge.new()
		survival.name = "Survival"
		survival.setup(player, environment_rig)
		add_child(survival)
	StartupProfile.mark("survival")
	# forage (scripts/forage): berries, nuts and herbs where they grow; the deer feed on them too
	var forage := ForageField.new()
	forage.name = "Forage"
	add_child(forage)
	forage.build(vegetation)
	StartupProfile.mark("forage")
	# wildlife (scripts/wildlife): deer herds, a lone buck, foxes and a wolf pack in the woods round the fort
	if WildlifeSpawner.enabled():
		var wildlife := WildlifeSpawner.new()
		wildlife.name = "Wildlife"
		wildlife.setup(player, vegetation, environment_rig)
		add_child(wildlife)
	# fish (scripts/wildlife/fish): the river's fish near the player, each with its own ways, to the water's numbers
	# (the spawner's when there is one)
	if WorldRiver.has_water():
		var fishes := FishLife.new()
		fishes.name = "Fish"
		fishes.setup(player, environment_rig)
		add_child(fishes)
	# fishing (scripts/fishing): the rod and line, the spear; the gear button (8)
	FishingGear.install(player)
	# birds and fireflies (scripts/wildlife): owls in the trees at night, flocks by day and at a shot, fireflies at dusk
	# death and saves (scripts/save): dying drops the pack and wakes you where you last slept; autosave, F5 / F9, the
	# last save continued at launch (off in -s tool / test runs unless they pass save=on)
	if SaveGame.enabled():
		var death := DeathRule.new()
		death.name = "Death"
		death.player = player
		add_child(death)
		var saves := SaveGame.new()
		saves.name = "SaveGame"
		saves.setup(self, death)
		add_child(saves)
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
	# the menus (scripts/ui/menu): the settings' volumes and look onto the player, and Esc's pause menu (not in -s tool
	# and test runs)
	if not SaveGame._is_script_run():
		GameSettings.apply_to(player)
		PauseMenu.install(self, player)
	StartupProfile.watch(self)


## Sound (scripts/audio/): buses and voice pool, the forest ambience, and the listeners that
## voice the player's footsteps and weapons. Missing sound files are skipped.
func _audio(player: FrontierPlayer) -> void:
	Sfx.setup(self)
	var bed := AmbienceBed.new()
	bed.name = "AmbienceBed"
	bed.player = player
	add_child(bed)
	var steps := Footsteps.new()
	steps.name = "Footsteps"
	steps.player = player
	player.add_child(steps)
	var weapons := WeaponAudio.new()
	weapons.name = "WeaponAudio"
	weapons.player = player
	player.add_child(weapons)
