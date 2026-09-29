class_name WeatherFx
extends Node3D
## What the weather does around the player (cloud engine, 2026-09-26), from DayNight.weather every frame:
##   rain       GPU particles (thin streaks falling with the wind) in a box that follows the camera, as many as
##              the rain rate asks (amount_ratio), lit by the scene's light level; the rain's sound bed
##   lightning  a shadowless DirectionalLight3D from the flash for the stroke's pulses (only visible while lit)
##   thunder    each stroke's thunder after the light, delayed by the sound's travel (distance / 343 m/s): a crack
##              and rumble close by, a low roll far off, nothing beyond THUNDER_MAX_M
## The sounds are synthesised by tools/sfx/weather.py (audio/sfx/weather/); missing files are skipped. The rain
## does not know about roofs yet: it falls through the cabin and the blockhouses.

const RAIN_AMOUNT := {"high": 7000, "medium": 4500, "low": 2500}
const RAIN_BOX := Vector3(17.0, 1.0, 17.0)       ## half extents of the spawn box above the camera
const RAIN_HEIGHT := 13.0
const RAIN_SPEED := 10.5                          ## m/s, a raindrop's fall
const THUNDER_MAX_M := 26000.0
const LIGHTNING_ENERGY := 3.5
const SND := "res://audio/sfx/weather/%s_%02d.wav"
const THUNDER_NEAR_M := 3500.0

var day_night: Node
var _rain: GPUParticles3D
var _rain_proc: ParticleProcessMaterial
var _rain_draw: StandardMaterial3D
var _light: DirectionalLight3D
var _rain_audio: AudioStreamPlayer
var _thunder_players: Array[AudioStreamPlayer] = []
var _near: Array[AudioStream] = []
var _far: Array[AudioStream] = []
var _pending: Array[Dictionary] = []
var _rain_level := 0.0
## 0 rain .. 1 snow: while the survival core says it snows (SnowCover sets it), the precipitation falls as SnowFall's
## flakes and the rain streaks and their sound stop.
var snow_mix := 0.0
## Thunder sounds started so far (tests).
var thunder_played := 0


func setup(dn: Node) -> void:
	day_night = dn
	top_level = true
	_build_rain()
	_build_light()
	_build_audio()


func _process(delta: float) -> void:
	if day_night == null or day_night.weather == null:
		return
	var w: WeatherSystem = day_night.weather
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	_update_rain(w, cam, delta)
	_update_lightning(w)
	_update_thunder(w, delta)


# --- rain ------------------------------------------------------------------------------------------------------------

func _build_rain() -> void:
	var q := "high"
	if day_night.rig and "settings" in day_night.rig and day_night.rig.settings:
		q = String(day_night.rig.settings.quality)
	_rain_proc = ParticleProcessMaterial.new()
	_rain_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_proc.emission_box_extents = RAIN_BOX
	_rain_proc.direction = Vector3.DOWN
	_rain_proc.spread = 2.0
	_rain_proc.initial_velocity_min = RAIN_SPEED * 0.9
	_rain_proc.initial_velocity_max = RAIN_SPEED * 1.1
	_rain_proc.gravity = Vector3(0.0, -2.0, 0.0)
	_rain_proc.particle_flag_align_y = true
	_rain_proc.scale_min = 0.7
	_rain_proc.scale_max = 1.2
	_rain_draw = StandardMaterial3D.new()
	_rain_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain_draw.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_rain_draw.billboard_keep_scale = true
	_rain_draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rain_draw.albedo_color = Color(0.72, 0.76, 0.82, 0.22)
	# drops right at the lens would be long bright lines: they fade in from 1 m to 3 m
	_rain_draw.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_rain_draw.distance_fade_min_distance = 1.0
	_rain_draw.distance_fade_max_distance = 3.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.014, 0.6)
	quad.material = _rain_draw
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = int(RAIN_AMOUNT.get(q, 7000))
	_rain.lifetime = (RAIN_HEIGHT + 3.0) / RAIN_SPEED
	_rain.local_coords = false
	_rain.process_material = _rain_proc
	_rain.draw_pass_1 = quad
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_rain.visibility_aabb = AABB(Vector3(-24.0, -24.0, -24.0), Vector3(48.0, 40.0, 48.0))
	_rain.emitting = false
	_rain.amount_ratio = 0.0
	add_child(_rain)


func _update_rain(w: WeatherSystem, cam: Camera3D, delta: float) -> void:
	_rain_level = move_toward(_rain_level, w.rain * (1.0 - snow_mix), delta * 0.5)
	var on := _rain_level > 0.01
	if _rain.emitting != on:
		_rain.emitting = on
	if not on:
		if _rain_audio and _rain_audio.playing:
			_rain_audio.stop()
		return
	_rain.amount_ratio = clampf(_rain_level * 1.1, 0.0, 1.0)
	var wind := Vector3(w.wind_ground_dir.x, 0.0, w.wind_ground_dir.y) * (1.5 + 6.0 * w.wind_ground_strength)
	_rain_proc.gravity = Vector3(wind.x, -2.0, wind.z)
	if cam:
		# spawn upwind so the slanted streaks cover the view
		_rain.global_position = cam.global_position + Vector3(0.0, RAIN_HEIGHT, 0.0) - wind * 0.8
	# lit by the scene: the fog's light level (DayNight keeps it with the sky; under the trees ForestLight's rain_light),
	# a flash lights every drop
	var lvl := 0.25
	if day_night.env:
		var forest: Node = day_night.get("forest")
		var fog_e: float = forest.rain_light if forest and forest.enabled else day_night.env.fog_light_energy
		lvl = clampf(fog_e * 0.9, 0.04, 0.8)
	lvl += w.ground_flash * 1.5
	_rain_draw.albedo_color = Color(0.72 * lvl + 0.05, 0.76 * lvl + 0.05, 0.82 * lvl + 0.06, 0.2 + 0.2 * _rain_level)
	if _rain_audio and _rain_audio.stream:
		if not _rain_audio.playing:
			_rain_audio.play(randf() * maxf(_rain_audio.stream.get_length() - 1.0, 0.0))
		_rain_audio.volume_db = linear_to_db(clampf(_rain_level, 0.001, 1.0)) - 6.0


# --- lightning -------------------------------------------------------------------------------------------------------

func _build_light() -> void:
	_light = DirectionalLight3D.new()
	_light.name = "LightningLight"
	_light.shadow_enabled = false
	_light.light_color = Color(0.78, 0.83, 1.0)
	_light.light_specular = 0.3
	_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_light.light_energy = 0.0
	_light.visible = false
	add_child(_light)


func _update_lightning(w: WeatherSystem) -> void:
	var e := w.ground_flash * LIGHTNING_ENERGY
	_light.visible = e > 0.01
	if _light.visible:
		_light.light_energy = e
		var d := w.flash_dir
		d.y = maxf(d.y, 0.15)
		d = d.normalized()
		_light.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)


# --- sound -----------------------------------------------------------------------------------------------------------

func _build_audio() -> void:
	for i in range(1, 4):
		var n := SND % ["thunder_near", i]
		var f := SND % ["thunder_far", i]
		if ResourceLoader.exists(n):
			_near.append(load(n))
		if ResourceLoader.exists(f):
			_far.append(load(f))
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.name = "Thunder%d" % i
		add_child(p)
		_thunder_players.append(p)
	var rl := SND % ["rain_loop", 1]
	if ResourceLoader.exists(rl):
		_rain_audio = AudioStreamPlayer.new()
		_rain_audio.name = "RainLoop"
		var st: AudioStream = load(rl)
		if st is AudioStreamWAV:
			var wav := st as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_rain_audio.stream = st
		if AudioServer.get_bus_index(&"Ambience") >= 0:
			_rain_audio.bus = &"Ambience"   # with the thunder and the forest bed (its level, the gunfire duck)
		add_child(_rain_audio)


func _update_thunder(w: WeatherSystem, delta: float) -> void:
	for t: Dictionary in w.thunder:
		if float(t.distance) < THUNDER_MAX_M:
			_pending.append(t.duplicate())
	w.thunder.clear()
	for i in range(_pending.size() - 1, -1, -1):
		var t: Dictionary = _pending[i]
		t.delay = float(t.delay) - delta
		if float(t.delay) <= 0.0:
			_pending.remove_at(i)
			_play_thunder(float(t.distance), float(t.power))


func _play_thunder(dist: float, power: float) -> void:
	var near := dist < THUNDER_NEAR_M
	var pool := _near if near and not _near.is_empty() else _far
	if pool.is_empty():
		return
	var p: AudioStreamPlayer = null
	for q in _thunder_players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _thunder_players[0]
	if AudioServer.get_bus_index(&"Ambience") >= 0:
		p.bus = &"Ambience"
	p.stream = pool[randi() % pool.size()]
	# louder close by, the far roll falls off with distance and lower
	var db := linear_to_db(clampf(power, 0.2, 1.0)) - 20.0 * log(maxf(dist, 800.0) / 800.0) / log(10.0) * 0.6
	p.volume_db = clampf(db + (2.0 if near else 0.0), -40.0, 3.0)
	p.pitch_scale = clampf(1.05 - dist / 60000.0, 0.8, 1.05) * randf_range(0.95, 1.05)
	p.play()
	thunder_played += 1
