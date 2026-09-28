class_name AmbienceBed
extends Node
## Forest ambience around the player, added to the level by frontier_level.gd.
##
##   wind       60 s stereo loop, 2D, fades in over 2 s from a random point in the loop
##   birds      a call 25-70 m away and 5-12 m up, chosen by the sun's height from real recordings
##              (birds_rec.py; public domain / CC0, 2026-09-26): by day vireo, chickadee, robin, jay, crow,
##              woodpeckers, grouse drumming, turkey; in the afternoon's low sun, dusk and dawn the thrushes (wood
##              thrush, veery, hermit thrush) and the whip-poor-will; at night the whip-poor-will and owls (barred,
##              great horned; the perched owls near the player are BirdLife's). Without the recordings: the
##              synthesized BIRDS (thrush, chickadee, warbler, crow, woodpecker, weights 30/25/20/15/10).
##   creaks     a pine trunk creaking 12-30 m away every 18-45 s
##   flag       looping flutter at the fort flag
##   scare()    called on musket and pistol shots (group "ambience"): 60 % of the time a
##              flock takes off from the tree line, and the birds stay quiet for 12-25 s

const BIRDS := [["bird_thrush", 30.0], ["bird_chickadee", 25.0], ["bird_warbler", 20.0],
		["crow_caw", 15.0], ["woodpecker_drum", 10.0]]
## Real recordings by time of day: [id, weight]; the interval (s) between calls per band.
const DAY_BIRDS := [["bird_rec_red_eyed_vireo", 18.0], ["bird_rec_chickadee", 16.0], ["bird_rec_robin", 12.0],
		["bird_rec_blue_jay", 12.0], ["bird_rec_crow", 12.0], ["bird_rec_pileated_woodpecker", 8.0],
		["bird_rec_wood_thrush", 8.0], ["woodpecker_drum", 5.0], ["bird_rec_ruffed_grouse", 5.0], ["bird_rec_wild_turkey", 4.0]]
const DUSK_BIRDS := [["bird_rec_wood_thrush", 30.0], ["bird_rec_veery", 22.0], ["bird_rec_hermit_thrush", 20.0],
		["bird_rec_robin", 12.0], ["bird_rec_whip_poor_will", 8.0], ["bird_rec_crow", 6.0]]
const NIGHT_BIRDS := [["bird_rec_whip_poor_will", 40.0], ["bird_rec_barred_owl", 32.0], ["bird_rec_great_horned_owl", 28.0]]
const INTERVAL := {"day": Vector2(5.0, 14.0), "dusk": Vector2(4.0, 11.0), "night": Vector2(12.0, 30.0)}
const FLAG_POS := Vector3(-5.1, 9.3, -2.0)     ## frontier_level._fort flag.
const WIND_FADE_IN := 2.0

var player: Node3D

var _wind: AudioStreamPlayer
var _flag: AudioStreamPlayer3D
var _bird_in := 0.0
var _creak_in := 0.0
var _quiet := 0.0                 ## Seconds the birds stay silent after a shot.
var _rig: EnvironmentRig
## The sun's height to use instead of the clock's (tests; INF = the clock).
var sun_override := INF


func _ready() -> void:
	add_to_group(&"ambience")
	_bird_in = randf_range(3.0, 8.0)
	_creak_in = randf_range(18.0, 45.0)
	_wind = Sfx.make_player_2d(&"forest_wind_loop", self)
	if _wind:
		var level := _wind.volume_db
		_wind.volume_db = -60.0
		_wind.play(randf() * maxf(_wind.stream.get_length() - 1.0, 0.0))
		create_tween().tween_property(_wind, "volume_db", level, WIND_FADE_IN) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flag = Sfx.make_player_3d(&"flag_flutter_loop", self)
	if _flag:
		_flag.global_position = FLAG_POS
		_flag.play(randf() * maxf(_flag.stream.get_length() - 0.5, 0.0))


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_quiet = maxf(_quiet - delta, 0.0)
	_bird_in -= delta
	if _bird_in <= 0.0:
		var band := band()
		var iv: Vector2 = INTERVAL[band]
		_bird_in = randf_range(iv.x, iv.y)
		if _quiet <= 0.0:
			var far := 70.0 if band != "night" else 140.0
			Sfx.play_3d(StringName(_pick_bird(band)), _around(25.0, far) + Vector3.UP * randf_range(5.0, 12.0))
	_creak_in -= delta
	if _creak_in <= 0.0:
		_creak_in = randf_range(18.0, 45.0)
		Sfx.play_3d(&"tree_creak", _around(12.0, 30.0) + Vector3.UP * 4.0)


## Gunshot: a flock may take off from the tree line, and the birds go quiet for a while.
func scare() -> void:
	if player == null or not is_instance_valid(player):
		return
	if randf() < 0.6 and _quiet <= 0.0:
		Sfx.play_3d(&"birds_flush", _around(25.0, 45.0) + Vector3.UP * randf_range(8.0, 12.0),
				0.0, 1.0, {"delay": randf_range(0.4, 1.0)})
	_quiet = maxf(_quiet, randf_range(12.0, 25.0))


## "day", "dusk" (the afternoon's low sun, dusk and dawn: the thrushes' hour) or "night", by the sun's height.
func band() -> String:
	var el := sun_elevation()
	if el < -6.0:
		return "night"
	if el < 22.0:
		return "dusk"
	return "day"


func sun_elevation() -> float:
	if sun_override != INF:
		return sun_override
	if _rig == null or not is_instance_valid(_rig):
		_rig = get_tree().current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig if get_tree().current_scene else null
	if _rig and _rig.clock_driver and _rig.clock_driver.clock:
		return _rig.clock_driver.clock.sun_elevation_deg()
	return WorldClock.DEFAULT_SUN_ELEVATION_DEG


func _pick_bird(band := "day") -> String:
	var table: Array = {"day": DAY_BIRDS, "dusk": DUSK_BIRDS, "night": NIGHT_BIRDS}[band]
	var have: Array = table.filter(func(b: Array) -> bool: return Sfx.has(StringName(b[0])))
	if have.is_empty():
		have = BIRDS if band != "night" else []
		if have.is_empty():
			return "bird_thrush"
	var total := 0.0
	for b: Array in have:
		total += float(b[1])
	var r := randf() * total
	for b: Array in have:
		r -= float(b[1])
		if r <= 0.0:
			return b[0]
	return have[0][0]


## A point on the ground at a random bearing, `near`-`far` metres from the player.
func _around(near: float, far: float) -> Vector3:
	var a := randf() * TAU
	var p := player.global_position + Vector3(sin(a), 0.0, cos(a)) * randf_range(near, far)
	p.y = 0.0
	return p
