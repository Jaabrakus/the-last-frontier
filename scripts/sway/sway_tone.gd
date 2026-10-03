class_name SwayTone
extends AudioStreamPlayer
## The soft tone that rises as a Sway lock fills (SwayCaster; docs/main_story.md 11.4: "a tone rises as it fills"): no
## sound in the library fits (data/sway/moves.json "sfx"), so it is made here, a sine and a quiet fifth from BASE_HZ up
## an octave by `level` (the lock's fill), faded in and out (`on`), quiet under everything (VOLUME_DB, the SFX bus).
## Only while it sounds does it fill its buffer (a few hundred frames a frame). Not made headless.

const RATE := 22050.0
const BASE_HZ := 196.0
const VOLUME_DB := -21.0
const FADE_S := 0.06

var on := false
var level := 0.0
var _gen: AudioStreamGenerator
var _pb: AudioStreamGeneratorPlayback
var _ph := 0.0
var _ph2 := 0.0
var _amp := 0.0
var _hz := BASE_HZ


func _ready() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = RATE
	_gen.buffer_length = 0.1
	stream = _gen
	volume_db = VOLUME_DB
	if AudioServer.get_bus_index(&"SFX") >= 0:
		bus = &"SFX"


func _process(_dt: float) -> void:
	if not on and _amp <= 0.0005:
		if playing:
			stop()
			_pb = null
		return
	if not playing:
		play()
		_pb = get_stream_playback() as AudioStreamGeneratorPlayback
	if _pb == null:
		return
	var want_hz := BASE_HZ * pow(2.0, clampf(level, 0.0, 1.0))
	var want_amp := 0.3 if on else 0.0
	var step_amp := 1.0 / (RATE * FADE_S)
	var n := _pb.get_frames_available()
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		_amp = move_toward(_amp, want_amp, step_amp)
		_hz = lerpf(_hz, want_hz, 0.0015)
		_ph = fmod(_ph + _hz / RATE, 1.0)
		_ph2 = fmod(_ph2 + _hz * 1.5 / RATE, 1.0)
		var s := (sin(TAU * _ph) + 0.25 * sin(TAU * _ph2)) * _amp
		buf[i] = Vector2(s, s)
	if n > 0:
		_pb.push_buffer(buf)
